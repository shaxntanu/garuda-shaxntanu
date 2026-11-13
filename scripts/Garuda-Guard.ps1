# Garuda VM Protection Guard Script
# Monitors the external drive and gracefully shuts down the VM if the drive disappears.

$VBox = "${env:ProgramFiles}\Oracle\VirtualBox\VBoxManage.exe"
$VM = "Garuda Linux"
$Drive = "E:"
$GraceSeconds = 3

Write-Host "[Guard] Monitoring $Drive for VM: $VM"

while ($true) {

    if (-not (Test-Path "$Drive\")) {

        Write-Warning "[Guard] $Drive disappeared!"

        # Grace period for transient USB issues
        Start-Sleep -Seconds $GraceSeconds

        if (-not (Test-Path "$Drive\")) {

            Write-Warning "[Guard] $Drive still missing after grace period. Shutting down VM..."

            # Request graceful shutdown via ACPI power button
            & $VBox controlvm $VM acpipowerbutton

            Start-Sleep -Seconds 5

            # Check if VM is still running
            $vmInfo = & $VBox showvminfo $VM --machinereadable |
                Select-String "VMState="

            if ($vmInfo -match 'running') {

                Write-Warning "[Guard] VM did not respond to ACPI shutdown. Forcing power-off..."

                & $VBox controlvm $VM poweroff

            }
            else {

                Write-Host "[Guard] VM shut down gracefully."
            }

            Write-Host "[Guard] Exiting. Watcher will resume monitoring."

            break

        }
        else {

            Write-Host "[Guard] $Drive recovered during grace period. Continuing monitoring."
        }
    }

    Start-Sleep -Seconds 1
}
