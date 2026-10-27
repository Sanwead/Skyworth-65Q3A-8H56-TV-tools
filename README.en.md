# TV-8H56

[简体中文](README.md)

Tools and notes for the **Skyworth 65Q3A / 8H56**.

## Features

| Feature | Operation |
| --- | --- |
| Device checks | Display system version, current privileges and available tools |
| Partition backup | Export a selected partition to USB and verify its size and SHA-256 |
| Boot video ad control | Replace the boot video player, retain the original and restore it with one command |
| Third-party launcher | Set the boot launcher and restore the original configuration |
| Startup tasks | Set the selected launcher at boot; the USB drive can be removed after installation |

Current version: **0.2.0**. Run `doctor` first on a different firmware version.

## Device

| Item | Recorded value |
| --- | --- |
| Model / board | Skyworth 65Q3A / 8H56 |
| SoC | HiSilicon Hi3751V551 |
| System | Android 5.1.1, SDK 22 |
| Firmware | 022.011.100 |
| Kernel | 3.18.16_s5 |
| SELinux | Disabled |

System modifications require the directory layout above and SELinux set to Disabled.

## Usage

Prepare a computer, ADB and a standard USB data drive. Install the launcher APK separately.

Entry point:

```text
sh tv8h56.sh help
```

Run the tools with `sh` on the TV. Transfer the project's `scripts` directory:

```sh
adb push scripts /data/local/tmp/tv8h56
adb shell sh /data/local/tmp/tv8h56/tv8h56.sh status
adb shell sh /data/local/tmp/tv8h56/tv8h56.sh doctor
```

`status` displays device information. `doctor` checks the operating requirements. Run modification commands in a **Root** session; see [USB Root entry](docs/USB-ROOT.md) for access.

Run the following commands in the TV's Root shell. Set `TOOL` to the actual script location, including its USB path when applicable.

```sh
TOOL=/data/local/tmp/tv8h56/tv8h56.sh
sh "$TOOL" doctor
```

Use the temporary directory for inspection. Before installing startup tasks, copy the verified files into a private directory from the Root session. If the destination already exists, stop and inspect its contents:

```sh
mkdir -m 700 /data/tv8h56-kit &&
cp /data/local/tmp/tv8h56/*.sh /data/tv8h56-kit/ &&
chmod 600 /data/tv8h56-kit/*.sh &&
TOOL=/data/tv8h56-kit/tv8h56.sh
```

For USB, change the `cp` source to `tv8h56/scripts/*.sh` on the drive. Verify the file source before copying. The installation source directory must be owned by Root, with directory permissions 0700 and file permissions 0600.

### 1. Backup

Export p16 (recorded as system on this device) to USB:

```sh
sh "$TOOL" backup --partition 16 --usb-mount /mnt/usb/sda1 --confirm-sensitive-backup
```

Check the [partition table](docs/research/partition-table.md) and the actual USB mount path. Each backup creates a new directory. `COMPLETE.txt` marks a verified export. Partitions p1 through p23 are supported; export each by its number.

### 2. Disable boot video ads

```sh
sh "$TOOL" bootvideo disable --apply
```

Replaces `/system/bin/bootvideo` with a script that exits immediately. The original player is retained in the same directory.

Restore:

```sh
sh "$TOOL" bootvideo restore --apply
```

### 3. Set a third-party launcher

After installing Emotn UI:

```sh
sh "$TOOL" home set com.oversea.aslauncher/com.oversea.aslauncher.ui.main.MainActivity --apply
```

Updates the boot launcher configuration for the next startup. Check whether the launcher starts:

```sh
sh "$TOOL" home launch com.oversea.aslauncher/com.oversea.aslauncher.ui.main.MainActivity
```

Restore the original configuration:

```sh
sh "$TOOL" home restore --apply
```

Keep `com.tianci.movieplatform` installed.

### 4. Configure the startup launcher task

Save the launcher setting and install the startup hook:

```sh
sh "$TOOL" startup home com.oversea.aslauncher/com.oversea.aslauncher.ui.main.MainActivity --apply
sh "$TOOL" startup install --apply
```

Runtime files are stored in `/data/tv8h56/bin`. The startup hook is added to the existing boot-shell script. The USB drive can then be removed. Root manages the configuration, and the selected launcher task runs at startup.

Disable the startup launcher task or remove the hook:

```sh
sh "$TOOL" startup home off --apply
sh "$TOOL" startup remove --apply
```

`startup home off` disables the startup launcher task. `startup remove` removes the hook. Restore the launcher XML with `home restore --apply`; handle previously written persistent properties separately. See the [command reference](docs/COMMANDS.md) for each command's operation.

## Notes

- Back up system files before modification and maintain power during the operation. Use the saved originals for restoration.
- Keep `com.tianci.movieplatform` installed; it is involved in this device's boot process.
- Use the actual USB mount path. The examples use `/mnt/usb/sda1`.
- Select APKs for the system's ABI and Android version. Query the ABI with `adb shell getprop ro.product.cpu.abi`.
- Store partition images privately. They may contain device keys, identifiers and account data.
- Turn off ADB debugging in the TV settings after maintenance.

## Layout

```text
scripts/           Main entry point and standalone tools
examples/          USB startup example
docs/COMMANDS.md   Command reference
docs/USB-ROOT.md   USB Root procedure for the recorded device
docs/BACKUP.md     Backup and restoration details
docs/research/     Ad components, startup services, partitions and candidate domains
LICENSE            MIT
```

The candidate domain list contains 33 domains, including shared CDNs and service domains.

## License

[MIT](LICENSE) · Copyright © 2026 Sanwead

The scripts and documentation are licensed under MIT. Retain the copyright and license notice when modifying, distributing or using them commercially.

Laudate omnissiah, fontem omnis scientiae
