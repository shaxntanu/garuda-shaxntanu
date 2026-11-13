$TaskName = "Garuda HDD Protection Watcher"
$WatcherPath = "$env:USERPROFILE\Garuda-HDD-Watcher.ps1"
$UserId = "$env:USERDOMAIN\$env:USERNAME"

# Stop existing task if present
Stop-ScheduledTask `
    -TaskName $TaskName `
    -ErrorAction SilentlyContinue

# Kill only stale watcher PowerShell processes
Get-CimInstance Win32_Process |
Where-Object {
    $_.CommandLine -like "*Garuda-HDD-Watcher.ps1*"
} |
ForEach-Object {

    Stop-Process `
        -Id $_.ProcessId `
        -Force `
        -ErrorAction SilentlyContinue
}

$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -STA -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$WatcherPath`""

$Trigger = New-ScheduledTaskTrigger `
    -AtLogOn `
    -User $UserId

$Principal = New-ScheduledTaskPrincipal `
    -UserId $UserId `
    -LogonType Interactive `
    -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet `
    -StartWhenAvailable `
    -MultipleInstances IgnoreNew `
    -ExecutionTimeLimit ([TimeSpan]::Zero)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Principal $Principal `
    -Settings $Settings `
    -Force

Start-ScheduledTask `
    -TaskName $TaskName
