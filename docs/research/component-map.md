# 启动服务与组件：原作者单机观察，未复现

以下服务、路径和包名来自上传文档，未附可供本次复核的原始日志或固件：

| 对象 | 原文记录 | 审阅处理 |
| --- | --- | --- |
| bigfish-setup | Root 运行 `/system/etc/init.bigfish.sh`，涉及模块、权限及 boa | 不修改，不插入早启动脚本 |
| boot-shell | `/system/bin/hisi_boot_shell.sh`，在 `dev.bootcomplete=1` 时触发，可能 source USB 的 `hi_boot_shell.sh` | 未核验；按高风险自动执行入口处理，不提供安装器 |
| android_ir_user / teecd / cpu-strategy / bigfish-powerctl | Root 服务 | 仅保留名称，不停用 |
| bootvideo | `/system/bin/bootvideo`，关联开机视频 | 替换入口禁用 |
| sky_M5_update / skyhdcpburn | 属性触发的 flash 写入服务 | 不调用、不尝试写 flash |
| services.odex / DEFAULT_HOMEPAGE | 原文称 framework 读取机型 XML 后写主页属性并启动主页 | 未复现，不附反编译产物，不自动修改 |

原文列出的候选广告关联包：`com.tianci.ad`、`com.tianci.push`、`com.coocaa.sysreport`、`com.coocaa.app_browser`、`com.coocaa.screensaver`、`com.tianci.de`。这些不是经本次验证的安全卸载名单，故不提供批量卸载命令。

原文记录 `com.tianci.movieplatform` 与开机依赖有关，卸载曾导致启动失败。本版也不保留原早启动模板中对它的周期强杀。
