param(
    [switch]$Worker
)

Add-Type -AssemblyName System.Windows.Forms

$TargetLetters = @("E", "I")
$VBox = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"

# ============================================================
# STAGE 1
# Main script E: par hai, actual eject worker TEMP se chalega.
# Isliye script khud E: ko lock nahi karegi.
# ============================================================

if (-not $Worker) {

    $TempScript = Join-Path $env:TEMP "Garuda-HDD-Eject-Worker.ps1"

    Copy-Item `
        -LiteralPath $PSCommandPath `
        -Destination $TempScript `
        -Force

    Start-Process `
        -FilePath "powershell.exe" `
        -ArgumentList @(
            "-NoProfile",
            "-NonInteractive",
            "-ExecutionPolicy", "Bypass",
            "-STA",
            "-WindowStyle", "Hidden",
            "-File", "`"$TempScript`"",
            "-Worker"
        ) `
        -WindowStyle Hidden

    exit
}

# Never keep E: / I: as current directory
Set-Location "$env:SystemDrive\"

# ============================================================
# Native Windows safe-removal API
# ============================================================

if (-not ("NativeDeviceEject" -as [type])) {

    Add-Type @"
using System;
using System.Text;
using System.Runtime.InteropServices;

public enum PNP_VETO_TYPE
{
    PNP_VetoTypeUnknown = 0,
    PNP_VetoLegacyDevice = 1,
    PNP_VetoPendingClose = 2,
    PNP_VetoWindowsApp = 3,
    PNP_VetoWindowsService = 4,
    PNP_VetoOutstandingOpen = 5,
    PNP_VetoDevice = 6,
    PNP_VetoDriver = 7,
    PNP_VetoIllegalDeviceRequest = 8,
    PNP_VetoInsufficientPower = 9,
    PNP_VetoNonDisableable = 10,
    PNP_VetoLegacyDriver = 11,
    PNP_VetoInsufficientRights = 12
}

public static class NativeDeviceEject
{
    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)]
    public static extern int CM_Locate_DevNodeW(
        out uint pdnDevInst,
        string pDeviceID,
        uint ulFlags
    );

    [DllImport("cfgmgr32.dll")]
    public static extern int CM_Get_Parent(
        out uint pdnDevInst,
        uint dnDevInst,
        uint ulFlags
    );

    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)]
    public static extern int CM_Get_Device_IDW(
        uint dnDevInst,
        StringBuilder Buffer,
        int BufferLen,
        uint ulFlags
    );

    [DllImport("cfgmgr32.dll", CharSet = CharSet.Unicode)]
    public static extern int CM_Request_Device_EjectW(
        uint dnDevInst,
        out PNP_VETO_TYPE pVetoType,
        StringBuilder pszVetoName,
        int ulNameLength,
        uint ulFlags
    );
}
"@
}

function Get-TargetDrives {

    return @(
        $TargetLetters | Where-Object {
            Test-Path "$_`:\"
        }
    )
}

function Get-DeviceId {

    param([uint32]$DevNode)

    $Buffer = New-Object System.Text.StringBuilder 512

    $Result = [NativeDeviceEject]::CM_Get_Device_IDW(
        $DevNode,
        $Buffer,
        $Buffer.Capacity,
        0
    )

    if ($Result -ne 0) {

        return $null
    }

    return $Buffer.ToString()
}

function Invoke-UsbSafeEject {

    param(
        [string]$DiskPnPDeviceID
    )

    [uint32]$Node = 0

    $Locate = [NativeDeviceEject]::CM_Locate_DevNodeW(
        [ref]$Node,
        $DiskPnPDeviceID,
        0
    )

    if ($Locate -ne 0) {

        return [PSCustomObject]@{
            Success  = $false
            VetoType = "DiskNodeNotFound"
            VetoName = $DiskPnPDeviceID
        }
    }

    # USBSTOR\Disk... is normally a child.
    # Walk upward until actual USB\VID_xxxx device is found.
    $UsbNode = $null
    $UsbID = $null

    for ($i = 0; $i -lt 10; $i++) {

        $CurrentID = Get-DeviceId $Node

        if ($CurrentID -match '^USB\\VID_') {

            $UsbNode = $Node
            $UsbID = $CurrentID

            break
        }

        [uint32]$Parent = 0

        $ParentResult = [NativeDeviceEject]::CM_Get_Parent(
            [ref]$Parent,
            $Node,
            0
        )

        if ($ParentResult -ne 0) {

            break
        }

        $ParentID = Get-DeviceId $Parent

        # Never climb into host PCI / ACPI / ROOT devices.
        if (
            $ParentID -match '^PCI\\' -or
            $ParentID -match '^ACPI\\' -or
            $ParentID -match '^ROOT\\'
        ) {

            break
        }

        $Node = $Parent
    }

    if ($null -eq $UsbNode) {

        return [PSCustomObject]@{
            Success  = $false
            VetoType = "USBParentNotFound"
            VetoName = $DiskPnPDeviceID
        }
    }

    [PNP_VETO_TYPE]$Veto =
        [PNP_VETO_TYPE]::PNP_VetoTypeUnknown

    $VetoName = New-Object System.Text.StringBuilder 512

    $Result = [NativeDeviceEject]::CM_Request_Device_EjectW(
        $UsbNode,
        [ref]$Veto,
        $VetoName,
        $VetoName.Capacity,
        0
    )

    return [PSCustomObject]@{
        Success  = ($Result -eq 0)
        VetoType = $Veto.ToString()
        VetoName = if ($VetoName.Length -gt 0) {
            $VetoName.ToString()
        }
        else {
            $UsbID
        }
    }
}

# ============================================================
# Check E:/I:
# ============================================================

$Present = Get-TargetDrives

if ($Present.Count -eq 0) {

    [System.Windows.Forms.MessageBox]::Show(
        "E: and I: are already disconnected.",
        "Garuda HDD",
        "OK",
        "Information"
    )

    exit
}

# ============================================================
# SAFETY: Never eject while any VM is running
# ============================================================

if (-not (Test-Path $VBox)) {

    [System.Windows.Forms.MessageBox]::Show(
        "VirtualBox could not be located.`n`nNothing was ejected.",
        "Cannot Verify VM State",
        "OK",
        "Error"
    )

    exit
}

$RunningVMs = @(& $VBox list runningvms 2>$null)

if ($RunningVMs.Count -gt 0) {

    [System.Windows.Forms.MessageBox]::Show(
        "A VirtualBox VM is still running.`n`n$($RunningVMs -join "`n")`n`nShut it down first.",
        "Cannot Eject HDD",
        "OK",
        "Warning"
    )

    exit
}

# ============================================================
# Confirm E: and I: belong to SAME physical disk
# ============================================================

$DiskNumbers = @()

foreach ($Letter in $Present) {

    try {

        $Partition = Get-Partition `
            -DriveLetter $Letter `
            -ErrorAction Stop

        $DiskNumbers += $Partition.DiskNumber
    }
    catch {}
}

$DiskNumbers = @($DiskNumbers | Sort-Object -Unique)

if ($DiskNumbers.Count -ne 1) {

    [System.Windows.Forms.MessageBox]::Show(
        "Safety check failed.`n`nE: and I: were not resolved to one physical disk.`n`nNothing was ejected.",
        "Safety Check",
        "OK",
        "Error"
    )

    exit
}

$DiskNumber = $DiskNumbers[0]

$Disk = Get-CimInstance `
    Win32_DiskDrive `
    -Filter "Index=$DiskNumber"

if ($null -eq $Disk) {

    [System.Windows.Forms.MessageBox]::Show(
        "Could not identify physical Disk $DiskNumber.",
        "Disk Detection Failed",
        "OK",
        "Error"
    )

    exit
}

# Must be USB / USBSTOR
if (
    $Disk.InterfaceType -ne "USB" -and
    $Disk.PNPDeviceID -notmatch '^USBSTOR\\'
) {

    [System.Windows.Forms.MessageBox]::Show(
        "Disk $DiskNumber does not appear to be the expected USB HDD.`n`nNothing was ejected.",
        "Safety Check Failed",
        "OK",
        "Error"
    )

    exit
}

# ============================================================
# Confirmation
# ============================================================

$Answer = [System.Windows.Forms.MessageBox]::Show(
    "Garuda HDD detected as physical Disk $DiskNumber.`n`nE: and I: will be safely ejected together.`n`nOllama and unused VirtualBox processes may be closed.`n`nContinue?",
    "Safely Eject Garuda HDD",
    "YesNo",
    "Warning"
)

if ($Answer -ne [System.Windows.Forms.DialogResult]::Yes) {

    exit
}

# ============================================================
# Stop Garuda Guard
# ============================================================

Get-CimInstance Win32_Process `
    -ErrorAction SilentlyContinue |
Where-Object {
    $_.CommandLine -like "*Garuda-Guard.ps1*"
} |
ForEach-Object {

    Stop-Process `
        -Id $_.ProcessId `
        -Force `
        -ErrorAction SilentlyContinue
}

# ============================================================
# Temporarily stop HDD watcher
# ============================================================

$WatcherTask = "Garuda HDD Protection Watcher"
$WatcherWasRunning = $false

try {

    $Task = Get-ScheduledTask `
        -TaskName $WatcherTask `
        -ErrorAction Stop

    if ($Task.State -eq "Running") {

        $WatcherWasRunning = $true

        Stop-ScheduledTask `
            -TaskName $WatcherTask `
            -ErrorAction SilentlyContinue
    }

}
catch {}

# ============================================================
# Stop Ollama because models are on I:
# ============================================================

Get-Service -ErrorAction SilentlyContinue |
Where-Object {
    $_.Name -match "ollama" -or
    $_.DisplayName -match "ollama"
} |
ForEach-Object {

    Stop-Service `
        -Name $_.Name `
        -Force `
        -ErrorAction SilentlyContinue
}

Get-Process -ErrorAction SilentlyContinue |
Where-Object {
    $_.ProcessName -like "ollama*"
} |
Stop-Process `
    -Force `
    -ErrorAction SilentlyContinue

# ============================================================
# Close Explorer windows browsing E:/I:
# ============================================================

$Shell = New-Object -ComObject Shell.Application

foreach ($Window in @($Shell.Windows())) {

    try {

        $Path = $Window.Document.Folder.Self.Path

        if (
            $Path -like "E:\*" -or
            $Path -like "I:\*" -or
            $Path -eq "E:\" -or
            $Path -eq "I:\"
        ) {

            $Window.Quit()
        }

    }
    catch {}
}

# ============================================================
# Close leftover VirtualBox processes
# VM running check already passed.
# ============================================================

$VBoxProcesses = @(
    "VirtualBox",
    "VirtualBoxVM",
    "VBoxHeadless",
    "VBoxSVC",
    "vboxwebsrv"
)

foreach ($Name in $VBoxProcesses) {

    Get-Process `
        -Name $Name `
        -ErrorAction SilentlyContinue |
    ForEach-Object {

        try {

            $null = $_.CloseMainWindow()
        }
        catch {}
    }
}

Start-Sleep -Milliseconds 700

foreach ($Name in $VBoxProcesses) {

    Get-Process `
        -Name $Name `
        -ErrorAction SilentlyContinue |
    Stop-Process `
        -Force `
        -ErrorAction SilentlyContinue
}

# Give Windows time to release handles / flush writes
Start-Sleep -Seconds 2

# ============================================================
# Request SAFE eject on actual USB parent
# ============================================================

$Result = Invoke-UsbSafeEject `
    -DiskPnPDeviceID $Disk.PNPDeviceID

# ============================================================
# Wait for BOTH E: and I: to disappear
# ============================================================

$Deadline = (Get-Date).AddSeconds(15)

do {

    Start-Sleep -Milliseconds 500

    $Remaining = Get-TargetDrives

} while (
    $Remaining.Count -gt 0 -and
    (Get-Date) -lt $Deadline
)

# ============================================================
# Fallback to normal Explorer eject verb
# ============================================================

if ($Remaining.Count -gt 0) {

    foreach ($Letter in $Remaining) {

        try {

            $Item = $Shell.Namespace(17).ParseName("$Letter`:")

            if ($null -ne $Item) {

                $Item.InvokeVerb("Eject")
            }

        }
        catch {}
    }

    $Deadline = (Get-Date).AddSeconds(10)

    do {

        Start-Sleep -Milliseconds 500

        $Remaining = Get-TargetDrives

    } while (
        $Remaining.Count -gt 0 -and
        (Get-Date) -lt $Deadline
    )
}

# ============================================================
# Restart HDD watcher
# ============================================================

if ($WatcherWasRunning) {

    Start-ScheduledTask `
        -TaskName $WatcherTask `
        -ErrorAction SilentlyContinue
}

# ============================================================
# Final result
# ============================================================

if ($Remaining.Count -eq 0) {

    [System.Windows.Forms.MessageBox]::Show(
        "Garuda HDD safely ejected.`n`nE: and I: are no longer mounted.`n`nYou can unplug the HDD now.",
        "Safe To Unplug",
        "OK",
        "Information"
    )

}
else {

    $RemainingText = (
        $Remaining |
        ForEach-Object {
            "$_`:"
        }
    ) -join ", "

    [System.Windows.Forms.MessageBox]::Show(
        "Windows still has $RemainingText mounted.`n`nThe disk was NOT force-removed.`n`nPnP result: $($Result.VetoType)`n$($Result.VetoName)`n`nDo not unplug it yet.",
        "HDD Still In Use",
        "OK",
        "Warning"
    )
}

exit
