# Garuda on an external HDD

This repository documents a Windows 11 host running Garuda Linux in VirtualBox. The VM disk and Ollama models share one external USB HDD. The Windows scripts ask before starting Garuda and help prepare the drive for safe removal.

## Architecture

~~~mermaid
flowchart TD
    HDD[External USB HDD]
    E[E: about 762 GB<br/>Garuda VM files]
    I[I: about 237 GB<br/>Ollama models]
    Watcher[Fast HDD Watcher]
    Prompt{Launch Garuda?}
    Normal[Windows and Ollama use the HDD]
    Guard[Garuda Guard]
    Focus[Garuda Focus Mode]
    VBox[VirtualBox]
    Guest[Garuda Linux]
    Eject[Controlled eject after shutdown]
    Verify[Verify no VM is running]
    Safe[Safely eject the USB device]
    Gone[Wait for E: and I: to disappear]

    HDD --> E
    HDD --> I
    HDD --> Watcher
    Watcher --> Prompt
    Prompt -- No --> Normal
    Prompt -- Yes --> Guard
    Prompt -- Yes --> Focus
    Focus --> VBox --> Guest
    E --> VBox
    Eject --> Verify --> Safe --> Gone
~~~

E: and I: are partitions on the same physical HDD. Ejecting the device removes both letters.

## Current system profile

| Part | Configuration |
| --- | --- |
| Windows host | Windows 11, 24 GB RAM |
| CPU | Intel Core i7-13620H, 10 cores and 16 logical processors |
| GPU | NVIDIA GeForce RTX 5050 Laptop GPU |
| Hypervisor | Oracle VirtualBox 7.2.20 |
| Guest | Garuda Linux, VM named Garuda Linux |
| Guest memory and CPUs | 16384 MB RAM, 8 vCPUs, 100% CPU execution cap |
| Guest process priority | High |
| Guest graphics | VMSVGA, 128 MB VRAM, 3D acceleration enabled |
| Firmware and disk | EFI, approximately 120 GB dynamically allocated VDI |
| Display | Fullscreen opens by default |

The host keeps about 8 GB of physical RAM outside the VM. Windows remains the host scheduler, so CPU time is not statically divided between Windows and Garuda. VirtualBox 3D acceleration does not pass the NVIDIA GPU or CUDA through to the guest.

## Host and guest roles

Windows handles the external drive, VirtualBox, the connection prompt, the power plan, Ollama, and safe removal. Garuda runs as a guest from a VDI file on E:. The guest does not own the physical disks or have direct access to the host GPU.

## Storage

The internal Windows disk is documented generically:

~~~text
Disk 0: Internal NVMe SSD (~1 TB)
├── EFI/System partition
├── Microsoft Reserved partition
├── C: Windows 11
└── Recovery partition
~~~

The external USB HDD currently appears as Disk 1. Windows can renumber disks, so the eject script finds the physical disk from the mounted volumes each time.

~~~text
External USB HDD (~1 TB)
├── E: ~762 GB
│   └── Garuda VM files, including E:\GarudaVM\Garuda Linux.vdi
└── I: ~237 GB
    └── Ollama models in I:\Ollama\models
~~~

The Garuda VM uses a VDI file through Windows and VirtualBox. It does not access or pass through the internal NVMe disk. The external mechanical HDD is an I/O bottleneck, so boot, updates, and file operations can take longer than they would on an SSD.

## What happens when the HDD is connected

The watcher checks E: and I: every 250 ms. It shows one Yes/No prompt per connection session.

- **No:** nothing launches. The HDD stays available to Windows and Ollama.
- **Yes:** the watcher starts one Guard instance, then starts Focus Mode. Focus Mode checks the VM and VDI, switches Windows to High Performance, and starts Garuda in VirtualBox.

The watcher does not start Garuda on its own. Focus Mode leaves Windows security, networking, storage, and other host services running.

## Protection and safe removal

The Guard watches E:. If E: stays missing for 3 seconds, it requests an ACPI shutdown and waits 5 seconds. It forces the VM off only if VirtualBox still reports it running. This reduces risk from a disconnect, but a forced power-off or a drive removed during writes can still damage guest data.

After Garuda is fully shut down, use the eject shortcut on E:. The eject script refuses to continue while any VirtualBox VM is running, resolves E: and I: to their shared USB disk, stops Ollama and relevant host processes, then requests safe removal. It does not force-dismount a busy filesystem. Wait for the success message and for both drive letters to disappear before unplugging the HDD.

## Daily workflow

1. Connect the external HDD.
2. Select No to use it with Windows and Ollama, or Yes to start Garuda.
3. When finished, shut Garuda down from inside the guest with sudo poweroff.
4. Wait for VirtualBox to report the VM off and Focus Mode to restore the previous Windows power plan.
5. Run E:\Eject Garuda HDD.lnk.
6. Unplug only after the success message appears and E: and I: are gone.

## Repository scripts

| Script | Purpose |
| --- | --- |
| [Garuda-HDD-Watcher.ps1](scripts/Garuda-HDD-Watcher.ps1) | Prompts once when E: or I: appears |
| [Garuda-Guard.ps1](scripts/Garuda-Guard.ps1) | Requests shutdown if E: disappears during a session |
| [Garuda-Focus.ps1](scripts/Garuda-Focus.ps1) | Checks and starts the VM, then restores the prior power plan |
| [Garuda-Eject.ps1](scripts/Garuda-Eject.ps1) | Prepares the shared USB HDD for safe removal |
| [Install-Garuda-WatcherTask.ps1](scripts/Install-Garuda-WatcherTask.ps1) | Registers the interactive logon task |
| [Create-Eject-Shortcut.ps1](scripts/Create-Eject-Shortcut.ps1) | Creates the local eject shortcut |

The repository contains source copies only. See [installation](docs/installation.md), [architecture](docs/architecture.md), [protection](docs/protection.md), and [troubleshooting](docs/troubleshooting.md) for setup and recovery details.
