***Sat Dec 7 更新***

优化代码、增加了对于NATMAPT的判断和控制，让BACKUP/MASTER切换后自动启用NATMAP。

>优化后的特性：
	1.	减少冗余操作：
	•	check_and_update 函数集中检查和更新配置。只有在需要更改时才执行 uci 设置命令。
	•	对每项服务状态进行独立检测并记录日志。
	2.	明确日志与输出：
	•	明确输出每个配置项的状态，记录是否需要更改，提升调试和可读性。
	•	跳过已经符合目标状态的设置，避免多余操作。
	3.	合并 odhcpd 重启：
	•	restart_odhcpd 在 DHCPv6、RA 和 NDP 三项调整后统一执行重启。
	4.	清晰的逻辑结构：
	•	主逻辑分为 MASTER 和 BACKUP 两部分。
	•	未安装 natmap 时，仅跳过与其相关的操作，不影响其他服务的设置。

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
