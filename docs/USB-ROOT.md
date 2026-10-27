# U 盘 Root 入口

原设备记录：厂商 `boot-shell` 会以 Root 运行 `/system/bin/hisi_boot_shell.sh`，并可能执行 U 盘根目录的 `hi_boot_shell.sh`。本项目用它启动自己的维护脚本；能否触发仍取决于固件。

## 准备

1. 用普通数据 U 盘，先确认电视能识别和挂载。不要格式化包含重要数据的 U 盘。
2. 把解压后的项目复制到 U 盘，目录名改为 `tv8h56`；确保能找到 `tv8h56/scripts/tv8h56.sh`。
3. 把 `examples/hi_boot_shell.sh` 复制到 U 盘根目录，文件名就叫 `hi_boot_shell.sh`，保持 UTF-8 / LF / 无 BOM。
4. 按实际挂载路径修改里面的 `USB_MOUNT`。默认 `/mnt/usb/sda1` 只是常见位置。

默认入口只运行 `status`。你可以把最后一条工具命令换成下面任意**一条**，先执行检查，再做备份，之后才修改：

```sh
/system/bin/sh "$TOOL" doctor
/system/bin/sh "$TOOL" backup --partition 16 --usb-mount "$USB_MOUNT" --confirm-sensitive-backup
/system/bin/sh "$TOOL" bootvideo disable --apply
/system/bin/sh "$TOOL" home set com.oversea.aslauncher/com.oversea.aslauncher.ui.main.MainActivity --apply
```

每次只安排一个操作，执行后查看结果，再决定下一步。如果需要保留输出，可以在选定命令后添加 `> "$USB_MOUNT/tv8h56-result.private.txt" 2>&1`；这个文件只留在自己手里，不要提交仓库。

安装内部启动任务前，在 Root 入口中先把已核对的工具放进私有目录。下面作为一组运行；目录已存在就停止，先人工核对，不自动覆盖：

```sh
KIT=/data/tv8h56-kit
mkdir -m 700 "$KIT" || exit 1
cp "$USB_MOUNT"/tv8h56/scripts/*.sh "$KIT"/ || exit 1
chmod 600 "$KIT"/*.sh || exit 1
/system/bin/sh "$KIT/tv8h56.sh" startup install --apply
```

只从自己控制且已核对的 U 盘复制。私有目录能防止普通 shell 在安装过程中替换源文件，但不会替你验证来源本身。

## 触发

在已经开机的电视上，原作者使用过下面两条命令重触发服务（两条依次运行，观察前一条是否报错）：

```sh
adb shell setprop dev.bootcomplete 0
adb shell setprop dev.bootcomplete 1
```

属性写入失败时停止，核对固件和 Root 状态。重新上电前先正常关机，操作期间保持供电。

电视若不能捕获输出，先从默认只读检查开始，不要直接执行修改。Root 探针不代表任何固件都存在该入口。

## 用完

移走 U 盘根目录的 `hi_boot_shell.sh`，或拔掉 U 盘。不要保留会在每次触发时反复修改系统的入口。本机制会以 Root 信任 U 盘里的代码，所以只使用自己控制的 U 盘和刚核对过的项目文件。

启动任务安装到内部存储后不需要 U 盘，但不会向普通 ADB shell 提供任意 Root 命令。以后仍需修改系统时，使用原有可信 Root 会话或重新准备这个明确操作的 U 盘入口。
