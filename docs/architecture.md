# Architecture

## Host and storage

Windows 11 remains the host operating system. It runs VirtualBox and mediates all guest CPU, memory, display, and storage access.

The internal disk is an NVMe SSD of about 1 TB. It contains the EFI/System partition, Microsoft Reserved partition, C: for Windows, and a Recovery partition. The Garuda VM does not directly access this disk.

One external USB HDD holds two mounted partitions:

| Volume | Approximate size | Contents |
| --- | ---: | --- |
| E: | 762 GB | Garuda VM files and the approximately 120 GB dynamically allocated VDI |
| I: | 237 GB | Ollama models |

The HDD was last observed as Disk 1. Windows disk numbers can change after devices are added or removed. The eject script resolves E: and I: to their current partition disk number at runtime and checks that both point to the same USB disk. It never assumes Disk 1.

The VDI is stored at E:\GarudaVM\Garuda Linux.vdi. Ollama model storage is at I:\Ollama\models. Removing the physical HDD removes both drive letters.

## VirtualBox guest

The VM is named Garuda Linux and is configured with:

- 16384 MB RAM and 8 vCPUs
- 100% CPU execution cap and high VM process priority
- 128 MB VRAM, VMSVGA, and 3D acceleration
- EFI firmware and a dynamically allocated VDI of about 120 GB
- Fullscreen startup

The host has 24 GB RAM, an Intel Core i7-13620H CPU with 10 cores and 16 logical processors, and an NVIDIA GeForce RTX 5050 Laptop GPU. The VM receives 16 GB RAM, leaving around 8 GB of physical memory outside the VM. Windows and VirtualBox still schedule CPU execution. Resources are not permanently partitioned.

VMSVGA and VirtualBox 3D acceleration provide virtual graphics support. They do not give Garuda direct RTX or CUDA access. The external mechanical HDD remains a storage bottleneck.

## Startup flow

The logon task starts the watcher in the interactive user session. The watcher checks E: and I: every 250 ms and prompts once when either appears. Selecting No leaves the HDD mounted for Windows and Ollama. Selecting Yes starts one Guard instance and then Focus Mode.

Focus Mode verifies that VirtualBox and the VDI are available and that the VM is powered off. It saves the active Windows power plan, switches to High Performance, starts the VM, watches for shutdown, and restores the saved plan. Fullscreen is stored in VirtualBox extra data. The default Host + F shortcut is Right Ctrl + F unless the Host Key has been changed.

Focus Mode does not disable Windows security services, kernel services, GPU drivers, networking, or filesystem services. Windows remains a functioning host.

## Guard behavior

The Guard monitors E: once per second. If E: disappears, it waits 3 seconds and checks again. If it is still missing, the script requests an ACPI power-button shutdown, waits 5 seconds, and powers off the VM only if VirtualBox still reports it as running.

This is a mitigation layer. It cannot guarantee data integrity. Removing the physical HDD while guest writes are in progress can corrupt the filesystem. The forced power-off can also damage guest data if the guest does not respond to ACPI shutdown.

## Controlled eject flow

The eject script is deployed on E:, but it first copies itself to a hidden worker under the current user's temporary directory and runs that worker. This lets the original script stop holding its own source volume open.

The worker then:

1. Confirms E: or I: is mounted and refuses to proceed if any VirtualBox VM is running.
2. Resolves both drive letters to one physical disk and checks that it is a USB device.
3. Asks for confirmation, stops the Guard, and pauses the watcher task if it was running.
4. Stops Ollama because its model files are on I:, closes Explorer windows using E: or I:, then closes unused VirtualBox processes.
5. Starts with the disk's runtime device node. Windows exposes storage through a child device such as USBSTOR. The script follows parent nodes until it finds a USB\VID_xxxx parent. This is a generic device-class pattern, not a saved device ID. It stops before climbing into PCI, ACPI, or ROOT host devices.
6. Calls the Windows Configuration Manager safe-eject API for that USB parent. If needed, it tries Explorer's Eject command as a fallback.
7. Waits for both E: and I: to disappear, restarts the watcher if it had been running, then reports success or explains that the disk is still mounted.

The USB storage and parent identifiers are read from Windows at runtime. The repository does not store a machine's PnP instance IDs or hardware serials. If Windows refuses removal, the script does not force a dismount. Close the application holding the disk and try again. Unplug only after the success message and disappearance of both volumes.

## Disk performance

The VM disk sits on an external mechanical HDD connected over USB. Random I/O and seek-heavy work will be slower than on an internal SSD. Focus Mode does not change that hardware limit.
