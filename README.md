使用场景：网络中采用keepalived实现双机热备高可用。
复杂应用：需要当BACKUP状态时，禁用dnsmasq的DHCPv4\DHCPv6\RA服务，切换为MASTER时，启用DHCPv4\DHCPv6\RA（考虑到可能同时安装了AdGuardHome\passwall2插件需要用到dnsmasq，因此非禁用dnsmasq服务本身）。

在passwall2的helper_dnsmasq.sh中调用
```
logic_restart() {
    # load keepalived_check.sh
    /path/to/keepalived_check.sh || true
```
将脚本加入 Cron 每分钟执行一次
```
* * * * * /path/to/keepalived_check.sh
```
