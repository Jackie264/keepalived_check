***Sat Dec 7 更新***

优化代码、增加了对于NATMAPT的判断和控制，让BACKUP/MASTER切换后自动启用NATMAP。

Tue Dec 3更新：增加 DHCPv6\RA\NDP 相关判断及控制内容，确保backup状态下本机仍可以获得IPv6地址的同时，禁用DHCPv6服务，不会产生与master同时分发IPv6地址给客户端。

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
