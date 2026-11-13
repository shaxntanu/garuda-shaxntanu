# Installation and recovery

These steps describe the current Windows and VirtualBox setup. The scripts in this repository are source copies. The VM disk, VirtualBox state, Ollama models, and generated shortcut stay local.

## 1. Prepare the VM

Install VirtualBox on Windows and connect the external USB HDD. Confirm that E: contains the Garuda VM files and I: contains Ollama models. Use Disk Management or the PowerShell check below to verify both letters belong to the same physical disk:

~~~powershell
Get-Partition -DriveLetter E, I |
    Select-Object DriveLetter, DiskNumber, Size
~~~

The output should show the same DiskNumber for both volumes. Do not rely on a fixed disk number; Windows can renumber disks.

If registering an existing VM, use its configuration file:

~~~powershell
$VBox = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
& $VBox registervm "E:\GarudaVM\Garuda Linux\Garuda Linux.vbox"
~~~

For a new VM, create one named Garuda Linux, enable EFI, create or attach the VDI on E:, and keep its configuration with the Garuda Linux folder.

## 2. Set the VM profile

The VM must be fully powered off before changing its hardware settings. Check the state first:

~~~powershell
$VBox = "$env:ProgramFiles\Oracle\VirtualBox\VBoxManage.exe"
$VM = "Garuda Linux"

& $VBox showvminfo $VM --machinereadable |
    Select-String '^VMState='
~~~

Apply the current profile only when the state is poweroff:

~~~powershell
& $VBox modifyvm $VM `
    --memory 16384 `
    --cpus 8 `
    --cpu-execution-cap 100 `
    --graphicscontroller vmsvga `
    --vram 128 `
    --accelerate-3d on `
    --nested-paging on `
    --vm-process-priority high

& $VBox setextradata $VM "GUI/Fullscreen" "true"
~~~

Verify the settings:

~~~powershell
& $VBox showvminfo $VM |
    Select-String -Pattern "priority|Memory size|Number of CPUs|CPU exec cap|VRAM|Graphics Controller|3D Acceleration"
~~~

Expected values are 16384 MB RAM, 8 CPUs, 100% CPU execution cap, high priority, 128 MB VRAM, VMSVGA, and enabled 3D acceleration. The graphics setting is virtualized graphics, not NVIDIA GPU passthrough. Unless changed, the fullscreen toggle is Host + F, which is Right Ctrl + F.

## 3. Copy the scripts to Windows

From the repository root, run PowerShell and copy the scripts to their deployed locations:

~~~powershell
$Scripts = Join-Path (Get-Location) "scripts"

Copy-Item "$Scripts\Garuda-Guard.ps1" "$env:USERPROFILE\Desktop\"
Copy-Item "$Scripts\Garuda-Focus.ps1" "$env:USERPROFILE\Desktop\"
Copy-Item "$Scripts\Garuda-HDD-Watcher.ps1" "$env:USERPROFILE\Garuda-HDD-Watcher.ps1"
Copy-Item "$Scripts\Garuda-Eject.ps1" "E:\Garuda-Eject.ps1"
~~~

Run the task installer from an elevated PowerShell session:

~~~powershell
.\scripts\Install-Garuda-WatcherTask.ps1
~~~

The scheduled task uses an interactive logon because the watcher displays a visible dialog. A non-interactive task can leave the dialog in an invisible session. It starts at user logon and runs the watcher hidden.

## 4. Create the local eject shortcut

With E: mounted, run the helper:

~~~powershell
.\scripts\Create-Eject-Shortcut.ps1
~~~

It creates E:\Eject Garuda HDD.lnk locally. Do not commit that generated shortcut. You may hide the script on E: if desired:

~~~powershell
attrib +h "E:\Garuda-Eject.ps1"
~~~

The shortcut remains visible. If Explorer is set to show hidden items, the script may still appear faded.

## 5. Test startup and safe removal

1. Start or restart the watcher task and connect the HDD.
2. Select No first. Confirm the HDD remains mounted and VirtualBox does not launch.
3. Shut down any running VM normally. Safely eject the HDD, reconnect it, and select Yes.
4. Confirm Focus Mode starts the VM. Shut Garuda down from inside the guest with sudo poweroff.
5. Wait until VirtualBox reports poweroff, then test the eject shortcut. Unplug only after the success message appears and E: and I: disappear.

Never test the Guard by physically disconnecting a running VM. The protection script reduces risk but cannot prevent damage from an abrupt storage loss.

## 6. Verify Garuda

Inside the guest, check available memory and CPUs:

~~~bash
free -h
nproc
lscpu | grep -E '^CPU\(s\)|Model name'
~~~

Expect about 15 to 16 GiB of visible RAM and 8 CPUs. Check Guest Additions if shared features are needed:

~~~bash
systemctl status vboxservice
pacman -Q virtualbox-guest-utils
~~~

If needed:

~~~bash
sudo pacman -S virtualbox-guest-utils
sudo systemctl enable --now vboxservice
~~~

## Recovery overview

If Windows or the external HDD is replaced, reconnect the same volumes, register the existing VM configuration in VirtualBox, copy the current scripts to the locations above, and register the interactive watcher task again. Keep a separate backup of the VDI. This repository does not contain VM disks, snapshots, or Ollama models.
