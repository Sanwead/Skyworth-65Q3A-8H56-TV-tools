# TV-8H56

[English](README.en.md)

针对 **创维 65Q3A / 8H56** 的工具与记录。

## 功能

| 功能 | 怎么用 |
| --- | --- |
| 检查设备 | 查看系统版本、当前权限和工具是否齐全 |
| 分区备份 | 把指定分区导出到 U 盘，自动检查大小和 SHA-256 |
| 开机视频广告开关 | 替换开机播放器，并保留原文件；一个命令恢复 |
| 第三方桌面 | 设置开机主页，也可以恢复原配置 |
| 启动任务 | 每次开机设置指定桌面，安装后无需保留 U 盘 |

当前版本 **0.2.0**，同型号不同固件请先运行 `doctor`。

## 设备信息

| 项目 | 记录 |
| --- | --- |
| 型号 / 机芯 | 创维 65Q3A / 8H56 |
| 芯片 | HiSilicon Hi3751V551 |
| 系统 | Android 5.1.1，SDK 22 |
| 固件 | 022.011.100 |
| 内核 | 3.18.16_s5 |
| SELinux | Disabled |

系统修改要求上述目录布局，SELinux 状态为 Disabled。

## 使用方法

准备电脑、ADB 和普通数据 U 盘，另行安装桌面 APK。

入口：

```text
sh tv8h56.sh help
```

在电视上通过 `sh` 运行。将项目的 `scripts` 文件夹传到电视：

```sh
adb push scripts /data/local/tmp/tv8h56
adb shell sh /data/local/tmp/tv8h56/tv8h56.sh status
adb shell sh /data/local/tmp/tv8h56/tv8h56.sh doctor
```

`status` 查看设备信息，`doctor` 检查运行条件。修改操作在 **Root** 会话中执行，获取方式见 [U 盘 Root 入口](docs/USB-ROOT.md)。

下面的命令都在电视的 Root shell 中运行。`TOOL` 改成实际放置工具的位置；如果使用 U 盘，把它指向 U 盘里的入口。

```sh
TOOL=/data/local/tmp/tv8h56/tv8h56.sh
sh "$TOOL" doctor
```

临时目录用于检查。安装启动任务前，在 Root 会话中将已核对的文件复制到私有目录。目标目录已存在时，停止并核对其内容：

```sh
mkdir -m 700 /data/tv8h56-kit &&
cp /data/local/tmp/tv8h56/*.sh /data/tv8h56-kit/ &&
chmod 600 /data/tv8h56-kit/*.sh &&
TOOL=/data/tv8h56-kit/tv8h56.sh
```

使用 U 盘时，`cp` 来源改为 U 盘内的 `tv8h56/scripts/*.sh`。复制前核对文件来源。安装源目录须归 Root 所有，目录权限为 0700，文件权限为 0600。

### 1. 备份

将 p16（本机记录为 system）备份到 U 盘：

```sh
sh "$TOOL" backup --partition 16 --usb-mount /mnt/usb/sda1 --confirm-sensitive-backup
```

核对 [分区表](docs/research/partition-table.md) 和实际 U 盘挂载路径。每次备份创建新目录，以 `COMPLETE.txt` 标记导出校验完成。支持 p1 至 p23，按对应编号逐个备份。

### 2. 关闭开机视频广告

```sh
sh "$TOOL" bootvideo disable --apply
```

将 `/system/bin/bootvideo` 替换为直接退出的脚本，原播放器保存在同目录。

恢复：

```sh
sh "$TOOL" bootvideo restore --apply
```

### 3. 设置第三方桌面

安装好 Emotn UI 后：

```sh
sh "$TOOL" home set com.oversea.aslauncher/com.oversea.aslauncher.ui.main.MainActivity --apply
```

修改开机主页配置，下一次启动生效。验证桌面能否启动：

```sh
sh "$TOOL" home launch com.oversea.aslauncher/com.oversea.aslauncher.ui.main.MainActivity
```

恢复原配置：

```sh
sh "$TOOL" home restore --apply
```

保留 `com.tianci.movieplatform`。

### 4. 设置开机桌面任务

保存桌面设置并安装启动入口：

```sh
sh "$TOOL" startup home com.oversea.aslauncher/com.oversea.aslauncher.ui.main.MainActivity --apply
sh "$TOOL" startup install --apply
```

运行文件保存在 `/data/tv8h56/bin`，启动入口写入原有 boot-shell 脚本。安装后可移除 U 盘。配置文件由 Root 管理，启动时执行指定桌面任务。

取消自动桌面任务，或移除启动入口：

```sh
sh "$TOOL" startup home off --apply
sh "$TOOL" startup remove --apply
```

`startup home off` 取消开机桌面任务，`startup remove` 移除启动入口。恢复主页 XML 使用 `home restore --apply`，已写入的持久属性另行处理。各命令的作用见 [命令说明](docs/COMMANDS.md)。

## 注意事项

- 修改前备份系统文件，操作期间保持供电。恢复时使用保存的原文件。
- `com.tianci.movieplatform` 涉及本机启动流程，予以保留。
- 使用实际 U 盘挂载路径。文中示例为 `/mnt/usb/sda1`。
- 按系统实际 ABI 和 Android 版本选择 APK。ABI 可通过 `adb shell getprop ro.product.cpu.abi` 查询。
- 分区镜像按私有数据保存，其中可能包含设备密钥、身份信息和账户数据。
- 维护结束后，在电视设置中关闭 ADB 调试。

## 目录

```text
scripts/           统一入口和独立工具
examples/          U 盘启动示例
docs/COMMANDS.md   完整命令表
docs/USB-ROOT.md   原机型的 U 盘 Root 操作说明
docs/BACKUP.md     备份和恢复细节
docs/research/     广告生态、启动组件、分区与候选域名
LICENSE            MIT
```

候选域名清单收录 33 个域名，包含共享 CDN 和业务域名。

## 许可

[MIT](LICENSE) · Copyright © 2026 Sanwead

脚本和文档采用 MIT 许可。修改、分发和商用时保留版权及许可声明。

Laudate omnissiah, fontem omnis scientiae
