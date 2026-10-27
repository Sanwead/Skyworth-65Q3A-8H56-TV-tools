# 备份与恢复

`backup` 每次读取一个分区，编号 1–23；固定设备前缀 `/dev/block/mmcblk0p`，拒绝 p24。工具不会写回任何分区。

依赖 `/system/bin/busybox` 的 `readlink`、`blockdev`、`df`、`awk`、`dd`、`wc`、`sha256sum` 等工具。USB 路径必须是 `/mnt/usb/` 下已在 `/proc/mounts` 出现的真实块设备挂载点。预留 64 MiB 额外空间；FAT 文件上限可能使大分区无法备份。

```text
sh tv8h56.sh backup --partition N --usb-mount ACTUAL_USB_MOUNT --confirm-sensitive-backup
```

成功目录包含 `partition.img`、`SHA256SUMS`、`COMPLETE.txt`、`PRIVATE.txt` 和 `error.log`。失败会保留未完成材料供私下检查；没有 `COMPLETE.txt` 就不能当作已成功导出。已有备份不覆盖，同时只能运行一个备份；供电稳定后手动核对并处理残留锁。

镜像、校验清单和日志全部留在私有存储。deviceinfo、securestore、ca、factory、cache 等分区可能有身份、密钥、授权与个人数据；system 等还包含原厂版权内容。FAT 上的权限和脚本 umask 不能代替加密。

活跃分区读取不是一致快照；文件哈希相符不代表能够恢复或开机。本包不提供通用反向 dd。完整分区恢复需要针对实机确认分区编号、大小、固件、校准和可信官方恢复手段，不能仅凭这里的参考表操作。

`bootvideo restore`、`home restore`、`startup remove` 是三个固定文件的恢复，与整机刷回固件不同。恢复出厂通常擦除数据，不能承诺还原被修改的 system 文件。
