# 命令手册

统一入口是 `sh tv8h56.sh <命令>`，可以先运行 `help`。修改命令都需要现有 Root 权限；`--apply` 是工具要求的明确操作参数。

| 命令 | 行为 | 权限 / 恢复 |
| --- | --- | --- |
| `status` | 系统版本、UID、已知修改记录；不创建状态目录 | 普通 shell 可用；不是完整设备取证 |
| `doctor` | 检查 BusyBox 基础工具、机型目录、SELinux 与系统目标文件 | 普通 shell 可先运行；不 remount |
| `backup --partition N --usb-mount PATH --confirm-sensitive-backup` | 单分区读取并校验导出 | Root；没有写回分区命令 |
| `route [--preview] NET GW IFACE` | 校验并打印命令，不执行网络修改 | 普通 shell |
| `route --apply NET GW IFACE` | 添加路由，不覆盖已有路由 | Root；`--remove` 撤销 |
| `route --remove NET GW IFACE` | 删除精确指定的路由 | Root；先确认这条确由自己添加 |
| `bootvideo disable --apply` | 保留原 inode，原子替换为直接退出脚本 | Root；`bootvideo restore --apply` |
| `home set COMPONENT --apply` | 修改单条 DEFAULT_HOMEPAGE，下一次开机生效 | Root；`home restore --apply` |
| `home launch COMPONENT` | 当前会话打开桌面，不修改 XML | Root；使用正常 HOME 行为切换 |
| `startup home COMPONENT --apply` | 保存自动桌面，设置主页属性并启动对应 Activity | Root；`startup home off --apply` 停止未来执行 |
| `startup route NET GW IFACE --apply` | 保存自动路由 | Root；`startup route off --apply` 停止未来执行 |
| `startup install --apply` | 安装 Root 专属运行文件与 boot-shell 钩子 | Root；`startup remove --apply` |
| `startup show` | 显示 Root 专属配置（含自行配置的网络参数） | Root；输出不要公开 |
| `startup-run` | 手动执行配置好的启动任务 | Root；正常由开机钩子调用，可用来检查输出 |

## 系统文件怎么保存和恢复

工具只支持三个固定目标：`/system/bin/bootvideo`、`/system/pcfg/8H56_Q3A/config/general_config.xml` 和 `/system/bin/hisi_boot_shell.sh`。不会接受任意系统路径参数。

修改前在同目录为原文件建立 `.tv8h56-original` 硬链接，保留原 inode 及其元数据；生成临时文件并检查后，用 rename 替换正式路径。`/data/tv8h56/state` 保存修改前后 SHA-256。已有原件、记录冲突、链接失败、空间不足、哈希失败时会停下，不覆盖已有备份。

恢复会核对备份与当前文件哈希：当前文件若被其他工具改过，会拒绝覆盖。原件通过 rename 恢复，其原有权限、所有者和 inode 元数据随之恢复。工具修改 `/system` 挂载状态时，会在正常退出和可捕捉信号退出时恢复此前的只读状态；原本可写则维持原状态。

断电、内核崩溃、强制结束无法依赖 shell trap 恢复。如果上次操作中断，先看目标文件、`.tv8h56-original`、`.tv8h56-new`、`/data/tv8h56/state/*.record` 与挂载状态。`operation.lock` 可能残留：确认没有任务在运行后才手动删除**空**锁目录，不要清空整个状态目录。部分提交阶段中断可能需要人工核对，不承诺所有中断状态自动恢复。

## 桌面配置支持什么格式

只处理单行、唯一的简单 XML 项：`<item name="DEFAULT_HOMEPAGE" value="包名/Activity"/>`，标签名可不同，其他属性顺序或复杂结构将被拒绝。这里只改 DEFAULT_HOMEPAGE，不改无实测作用的 BOOT_AD。检查已安装包，不保证指定 Activity 一定存在；先用 `home launch` 验证。正常业务配置中的其他字节保留。

## 启动任务与旧版 Root 队列

启动配置是固定四项键值，不会被 `source` 或 `eval`。仅支持桌面组件、NAS 网段、网关、接口。运行文件及目录归 Root、目录 0700 / 文件 0600。不能通过 `/data/local/tmp` 投递任意脚本获得 Root；本版也不提供通用的 shell→Root 命令桥。

这提供的是“开机执行固定 Root 任务”，不是给所有 App 安装通用 su。原先的 dsh Root 队列如果已安装在电视上，需要另行核对和移除；本版不自动猜测旧钩子位置，也不改动无关开机逻辑。

移除本版钩子会保留私有运行文件和配置。先取消自动任务，再恢复主页 XML、删除自己添加的路由，最后移除钩子。仅执行 `startup remove` 不会逆转此前设置的持久属性；下一次正常开机是否由框架重设属性需要现场核验。

安装器会拒绝直接覆盖不同版本的运行文件。升级时先移除旧钩子，备份并核对私有状态，再按新版本说明更新运行文件；没有自动迁移机制。
