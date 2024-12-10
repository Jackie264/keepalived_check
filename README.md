*Sat Dec 7 update*

**Optimized Features:**
#### *1.	Reduced Redundant Operations:*
> The check_and_update function centralizes the configuration check and update process. UCI commands are executed only when changes are required.\
> Each service’s status is independently checked and logged.
 
#### *2.	Clear Logs and Outputs:*
> Each configuration item’s state is explicitly logged, recording whether changes are necessary to improve debugging and readability.\
> Configurations already in the target state are skipped to avoid unnecessary operations.
 
#### *3.	Combined odhcpd Restart:*
> The restart_odhcpd function consolidates restarts for DHCPv6, RA, and NDP after adjustments.
 
#### *4.	Clear Logical Structure:*
> The main logic is divided into MASTER and BACKUP sections.\
> If natmap is not installed, related operations are skipped without affecting the configuration of other services.


*Tue Dec 3 update：*

#### New Additions for DHCPv6, RA, and NDP:
> Includes checks and controls to ensure the backup node can still obtain an IPv6 address while disabling the DHCPv6 service to prevent it from simultaneously distributing IPv6 addresses with the master node.

#### Usage Scenario:
> Applicable for high-availability setups using Keepalived for dual-node failover.

#### Complex Application:
> When in BACKUP mode, DNSMASQ’s DHCPv4, DHCPv6, and RA services are disabled. Upon switching to MASTER, these services are enabled.\
> This ensures compatibility with setups where DNSMASQ is required by plugins such as AdGuardHome and Passwall2, avoiding disabling the DNSMASQ service itself.

#### Invoked in helper_dnsmasq.sh under Passwall2.
 
增加 DHCPv6\RA\NDP 相关判断及控制内容，确保backup状态下本机仍可以获得IPv6地址的同时，禁用DHCPv6服务，不会产生与master同时分发IPv6地址给客户端。

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
