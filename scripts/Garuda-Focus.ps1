$ErrorActionPreference = "Stop"

$VM = "Garuda Linux"
$VBox = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
$VDI = "E:\GarudaVM\Garuda Linux.vdi"

Clear-Host

Write-Host ""
Write-Host "============================================" -ForegroundColor Cyan
Write-Host "           GARUDA FOCUS MODE" -ForegroundColor Cyan
Write-Host "============================================" -ForegroundColor Cyan
Write-Host ""
Write-Host "16 GB RAM | 8 vCPU | 100% CPU cap" -ForegroundColor DarkCyan
Write-Host "High Priority | VMSVGA | 3D Acceleration" -ForegroundColor DarkCyan
Write-Host ""

# ------------------------------------------------------------
# Verify VirtualBox
# ------------------------------------------------------------

if (-not (Test-Path $VBox)) {

    Write-Host "[ERROR] VBoxManage.exe not found." -ForegroundColor Red

    Read-Host "Press Enter"

    exit 1
}

# ------------------------------------------------------------
# Verify external Garuda drive / VDI
# ------------------------------------------------------------

if (-not (Test-Path $VDI)) {

    Write-Host "[ERROR] Garuda VDI not found:" -ForegroundColor Red
    Write-Host $VDI -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Make sure the external HDD is connected." -ForegroundColor Yellow

    Read-Host "Press Enter"

    exit 1
}

Write-Host "[OK] External Garuda storage detected." -ForegroundColor Green

# ------------------------------------------------------------
# Verify VM state
# ------------------------------------------------------------

$VMState = (& $VBox showvminfo $VM --machinereadable |
    Select-String '^VMState=').ToString()

if ($VMState -notmatch '"poweroff"') {

    Write-Host "[ERROR] VM is not fully powered off." -ForegroundColor Red
    Write-Host "Current state: $VMState" -ForegroundColor Yellow

    Read-Host "Press Enter"

    exit 1
}

Write-Host "[OK] Garuda VM is powered off." -ForegroundColor Green

# ------------------------------------------------------------
# Save current Windows power plan
# ------------------------------------------------------------

$PowerOutput = (powercfg /getactivescheme) -join " "

$PreviousPlan = [regex]::Match(
    $PowerOutput,
    '[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}'
).Value

if ($PreviousPlan) {

    Write-Host "[OK] Current Windows power plan saved." -ForegroundColor Green
}
else {

    Write-Host "[WARN] Could not detect current power plan." -ForegroundColor Yellow
}

try {

    # --------------------------------------------------------
    # Put Windows host into performance mode
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "[+] Enabling Windows High Performance mode..." -ForegroundColor Cyan

    powercfg /setactive SCHEME_MIN | Out-Null

    Write-Host "[OK] High Performance enabled." -ForegroundColor Green

    # --------------------------------------------------------
    # Start Garuda
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "[+] Starting Garuda Linux..." -ForegroundColor Cyan

    & $VBox startvm $VM --type gui

    if ($LASTEXITCODE -ne 0) {

        throw "VirtualBox failed to start Garuda Linux."
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Green
    Write-Host "         GARUDA FOCUS MODE ACTIVE" -ForegroundColor Green
    Write-Host "============================================" -ForegroundColor Green
    Write-Host ""
    Write-Host "Windows is now acting primarily as the VM host." -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Garuda resources:" -ForegroundColor White
    Write-Host "  RAM ............... 16 GB"
    Write-Host "  vCPU .............. 8"
    Write-Host "  CPU Cap ........... 100%"
    Write-Host "  Process Priority .. HIGH"
    Write-Host "  Graphics .......... VMSVGA + 3D"
    Write-Host ""
    Write-Host "Do NOT close this window while using Garuda." -ForegroundColor Yellow
    Write-Host "It will restore the Windows power plan when Garuda shuts down." -ForegroundColor DarkGray
    Write-Host ""

    # --------------------------------------------------------
    # Monitor VM
    # --------------------------------------------------------

    Start-Sleep -Seconds 5

    while ($true) {

        Start-Sleep -Seconds 3

        try {

            $VMState = (& $VBox showvminfo $VM --machinereadable |
                Select-String '^VMState=').ToString()
        }
        catch {

            break
        }

        if (
            $VMState -match '"poweroff"' -or
            $VMState -match '"saved"' -or
            $VMState -match '"aborted"'
        ) {

            break
        }
    }

}
finally {

    # --------------------------------------------------------
    # Restore Windows
    # --------------------------------------------------------

    Write-Host ""
    Write-Host "[+] Garuda stopped." -ForegroundColor Cyan

    if ($PreviousPlan) {

        powercfg /setactive $PreviousPlan | Out-Null

        Write-Host "[OK] Original Windows power plan restored." -ForegroundColor Green
    }

    Write-Host ""
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "          GARUDA FOCUS MODE ENDED" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
}

Start-Sleep -Seconds 3
