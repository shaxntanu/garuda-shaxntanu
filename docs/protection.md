# Protection and safe removal

Three separate mechanisms handle connection, an unexpected drive loss, and planned removal.

## A. Connection watcher

The watcher checks E: and I: every 250 ms. When either volume appears, it displays one visible Yes/No dialog for that connection session.

Selecting No launches nothing. It does not start VirtualBox, Focus Mode, or the Guard, and leaves the HDD available to Windows and Ollama.

Selecting Yes starts one Guard instance and then starts Focus Mode. The watcher will not prompt again until both E: and I: have disappeared and the drive is connected again.

## B. Guard

The Guard protects a running Garuda session if E: disappears:

1. Wait 3 seconds to allow for a brief interruption.
2. If E: is still missing, request an ACPI shutdown.
3. Wait 5 seconds.
4. If VirtualBox still reports the VM as running, force it off.

The Guard exits after handling a loss. The watcher continues monitoring for the next connection.

This only reduces risk. If the physical HDD is removed while data is being written, or if the guest does not respond before the forced power-off, the guest filesystem can be damaged. The Guard cannot guarantee data integrity.

## C. Controlled eject

Use the eject shortcut only after Garuda is shut down. The script follows this sequence:

1. Copy itself to a temporary worker so the source file on E: does not hold the drive open.
2. Confirm a target volume is present and refuse removal if any VirtualBox VM is running.
3. Resolve E: and I: to the same current physical disk and verify that it appears to be USB.
4. Ask for confirmation.
5. Stop the Guard and pause the watcher task if it was running.
6. Stop Ollama, close Explorer windows using E: or I:, and close leftover VirtualBox processes after the VM check.
7. Follow the disk's PnP parent chain from the storage child to its USB parent, avoiding PCI, ACPI, and ROOT devices.
8. Request safe removal through the Windows Configuration Manager API. If that does not remove the volume, try Explorer's Eject command.
9. Wait for both E: and I: to disappear, then restart the watcher if it was running.

The script does not force-dismount the filesystem or force-remove the device. If Windows reports that the disk is still in use, close the application holding it and run the eject process again. Do not unplug it until the success message appears and both drive letters are gone.

The former illegal-device-request failure occurred when removal targeted the USB storage child. The current script follows the child to the USB parent before requesting removal.
