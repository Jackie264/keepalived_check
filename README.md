*Sat Dec 7 update*

**Optimized code**
> Added checks and controls for NATMAPT to automatically enable NATMAP after switching between BACKUP and MASTER.

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

```
logic_restart() {
    # load keepalived_check.sh
    /path/to/keepalived_check.sh || true
```
##### Add the script to Cron to execute every minute.
```
* * * * * /path/to/keepalived_check.sh
```
