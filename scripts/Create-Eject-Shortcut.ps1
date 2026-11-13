$ShortcutPath = "E:\Eject Garuda HDD.lnk"
$ScriptPath = "E:\Garuda-Eject.ps1"

$WshShell = New-Object -ComObject WScript.Shell
$Shortcut = $WshShell.CreateShortcut($ShortcutPath)

$Shortcut.TargetPath = "powershell.exe"

$Shortcut.Arguments =
    "-NoProfile -NonInteractive -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File `"$ScriptPath`""

$Shortcut.WorkingDirectory = "$env:SystemDrive\"

$Shortcut.IconLocation =
    "$env:SystemRoot\System32\shell32.dll,27"

$Shortcut.Save()
