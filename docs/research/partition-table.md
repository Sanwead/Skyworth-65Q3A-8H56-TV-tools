# 单机分区记录：未独立核验

> 以下为上传包中的型号级记录，不含镜像。编号、大小、权限、内核与 SELinux 状态未由本次审查复现，禁止据此自动写回。名称并不表示分区无敏感数据；包括 cache 在内的镜像都应保密。

# TV-8H56 分区表（24 分区，blkdevparts）

| # | 名称 | 设备 | 大小 |
| --- | --- | --- | --- |
| 1 | fastboot | mmcblk0p1 | 1M |
| 2 | bootargs | p2 | 1M |
| 3 | recovery | p3 | 40M |
| 4 | panelparam | p4 | 8M |
| 5 | deviceinfo | p5 | 2M |
| 6 | logo | p6 | 20M |
| 7 | param | p7 | 20M |
| 8 | kernel | p8 | 40M |
| 9 | dtb | p9 | 1M |
| 10 | atf | p10 | 2M |
| 11 | trustedcore | p11 | 25M |
| 12 | securestore | p12 | 10M |
| 13 | versioninfo | p13 | 1M |
| 14 | misc | p14 | 1M |
| 15 | tconparam | p15 | 80M |
| 16 | system | p16 | 1400M |
| 17 | skyworth | p17 | 200M |
| 18 | skyota | p18 | 801M |
| 19 | dtv | p19 | 80M |
| 20 | atv | p20 | 20M |
| 21 | factory | p21 | 100M |
| 22 | ca | p22 | 1M |
| 23 | cache | p23 | 50M |
| 24 | userdata | p24 | 4.45G |

设备节点权限全部为 root:root 600——无 root 无法直读，备份必须走 root 通道。
内核 3.18.16_s5（2022-11 构建），SELinux Disabled（cmdline selinux=0）。
