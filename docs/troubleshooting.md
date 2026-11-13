# Troubleshooting

## The connection prompt does not appear

Check the scheduled task:

~~~powershell
Get-ScheduledTask -TaskName "Garuda HDD Protection Watcher" |
    Select-Object TaskName, State,
    @{N="LogonType";E={$_.Principal.LogonType}}
~~~

Expected values are State Running and LogonType Interactive. Interactive logon matters because the watcher shows a Yes/No dialog. A non-interactive task can leave the dialog in an invisible session.

Confirm that the task points to the deployed watcher at the current user's profile path and that both drive letters are assigned as expected.

## The prompt appears slowly

The watcher checks every 250 ms after Windows exposes E: or I:. The remaining delay comes from Windows detecting and mounting the device. Earlier 2-second and 5-second loops and an extra 3-second sleep are obsolete.

## VirtualBox starts after selecting No

The current watcher has no VirtualBox launch path for No. Check for duplicate or outdated watcher tasks and confirm that the installed copy matches scripts/Garuda-HDD-Watcher.ps1. Restart the task after replacing the file.

## Focus Mode does not launch

Confirm that Garuda-Focus.ps1 is on the Desktop, the drive is mounted as E:, the VDI exists at E:\GarudaVM\Garuda Linux.vdi, and VirtualBox is installed under Program Files. The VM must be fully powered off before Focus Mode starts it.

Focus Mode changes the Windows power plan while Garuda runs and restores the plan that was active before launch. It does not stop Windows security or system services.

## Check the VM profile

Run:

~~~powershell
$VBox = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
& $VBox showvminfo "Garuda Linux" |
    Select-String -Pattern "priority|Memory size|Number of CPUs|CPU exec cap|VRAM|Graphics Controller|3D Acceleration"
~~~

Expected: 16384 MB RAM, 8 CPUs, 100% cap, 128 MB VRAM, VMSVGA, enabled 3D acceleration, and high process priority.

## Fullscreen does not start

Reapply the extra data while the VM is powered off:

~~~powershell
$VBox = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
& $VBox setextradata "Garuda Linux" "GUI/Fullscreen" "true"
~~~

The default Host + F toggle is Right Ctrl + F unless the Host Key has changed.

## Eject reports PNP_VetoIllegalDeviceRequest

The older method targeted the USB storage child. The current eject script walks from that child to the USB parent before requesting safe removal. Make sure the deployed E:\Garuda-Eject.ps1 is the current repository version.

## Eject reports an open handle or another veto

Windows is still using the disk. Close the application or Explorer window that holds E: or I:, wait for any file operation to finish, then retry. The script does not force-dismount the filesystem. Do not unplug the HDD while either volume is mounted.

## Eject shortcut opens a terminal or does nothing

Check that E:\Garuda-Eject.ps1 exists and the shortcut target is powershell.exe with the script path on E:. Recreate the shortcut by running scripts/Create-Eject-Shortcut.ps1 while E: is mounted.

## The eject script is visible

Run attrib +h "E:\Garuda-Eject.ps1". If Explorer shows hidden items, the file may appear faded. The shortcut remains visible.

## Drive letters or disk number changed

The scripts expect the Garuda volume on E: and Ollama models on I:. Restore those letters in Disk Management. The eject script finds the physical disk number at runtime, so the number itself can change.
