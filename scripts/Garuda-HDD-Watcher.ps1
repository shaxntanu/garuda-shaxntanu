Add-Type -AssemblyName System.Windows.Forms

$Guard = "$env:USERPROFILE\Desktop\Garuda-Guard.ps1"
$Focus = "$env:USERPROFILE\Desktop\Garuda-Focus.ps1"

$WasConnected = $false

function Test-GarudaDrive {

    return (
        (Test-Path "E:\") -or
        (Test-Path "I:\")
    )
}

while ($true) {

    $Connected = Test-GarudaDrive

    # ========================================================
    # JUST CONNECTED
    # ========================================================

    if ($Connected -and -not $WasConnected) {

        # Mark immediately so E: and I: mounting separately
        # cannot trigger two prompts.
        $WasConnected = $true

        $Answer = [System.Windows.Forms.MessageBox]::Show(
            "External Garuda HDD connected.`n`nDo you want to launch Garuda Linux in Focus Mode?`n`nChoose No to use the HDD normally with Windows / Ollama.",
            "Garuda HDD Connected",
            [System.Windows.Forms.MessageBoxButtons]::YesNo,
            [System.Windows.Forms.MessageBoxIcon]::Question
        )

        # ====================================================
        # YES ONLY
        # ====================================================

        if ($Answer -eq [System.Windows.Forms.DialogResult]::Yes) {

            # Start one protection guard
            $ExistingGuard = Get-CimInstance Win32_Process |
                Where-Object {
                    $_.CommandLine -like "*Garuda-Guard.ps1*"
                }

            if (-not $ExistingGuard -and (Test-Path $Guard)) {

                Start-Process powershell.exe `
                    -ArgumentList @(
                        "-NoProfile",
                        "-ExecutionPolicy", "Bypass",
                        "-WindowStyle", "Hidden",
                        "-File", "`"$Guard`""
                    ) `
                    -WindowStyle Hidden
            }

            # Start Focus Mode
            if (Test-Path $Focus) {

                Start-Process powershell.exe `
                    -ArgumentList @(
                        "-NoProfile",
                        "-ExecutionPolicy", "Bypass",
                        "-File", "`"$Focus`""
                    )
            }
            else {

                [System.Windows.Forms.MessageBox]::Show(
                    "Garuda-Focus.ps1 was not found.`n`n$Focus`n`nVirtualBox was NOT launched.",
                    "Focus Mode Missing",
                    "OK",
                    "Error"
                )
            }
        }

        # NO -> nothing at all.
        # No Guard.
        # No Focus Mode.
        # No VirtualBox.
    }

    # ========================================================
    # FULLY DISCONNECTED
    # ========================================================

    if (-not $Connected -and $WasConnected) {

        $WasConnected = $false
    }

    # Fast detection: maximum ~250 ms script-side delay
    Start-Sleep -Milliseconds 250
}
