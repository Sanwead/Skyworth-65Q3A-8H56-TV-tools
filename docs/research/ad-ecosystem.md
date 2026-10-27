# 广告生态：原作者单机观察，未复现

上传文档将 `/system/bin/bootvideo` 与开机广告关联，并记载 BootVideo_main → BootVideoLogic::playBootVideo() → BootVideoPlatformHisi::playDirect(path) → HiPlayer 的调用名称。这些名称是研究摘要，不是随包提供的原厂代码；没有二进制、反编译代码或原始日志支持本次独立复核。

文档记录 `dzpb.coocaa.com` 上的 `/adnotify` 路径、酷开主页内的 `tencent_odk_player` 名称以及 `com.tianci.ad`，并声称部分片源采用裸 IP。本版删去无助于复现的具体 IP 片段，不重新访问这些服务，不认定这些服务目前的用途。

原文提及 `com.tianci.movieplatform` 私有目录下的 `files/ad_cache`、`files/tad_cache`、`files/vrom`、`cache/imagepipeline_cache`、`databases/omgad.db`、`databases/cache`。这些仅作为位置记录，不能作为删除清单；数据库、缓存和日志可能含个人数据及正常业务数据。本包不含这些文件。

原文认为 BOOT_AD 配置、单独卸载广告包、仅阻断域名、清缓存和短时断网无法稳定解决其单机问题。本次未验证这些结论，也不再将替换播放器、清库或卸载系统应用列为通用有效方案。

`ad-domains.txt` 原样保留 33 个去重公共域名，仅修订注释。它包含可能承载支付、视频和共享 CDN 的域名；不应整表直接封锁，也不能原样当作 hosts 文件。没有检查可达性、广告归属或误伤范围。
