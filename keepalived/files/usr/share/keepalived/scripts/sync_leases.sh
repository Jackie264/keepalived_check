#!/bin/sh

# 延迟 60 秒执行
sleep 60

# 备用路由器的租约文件路径
LEASE_FILE="/tmp/dhcp.leases"

# 主路由器的 IP 地址
MASTER_IP="<master-router-ip>"

# 从主路由器同步租约文件到备用路由器
rsync -avz root@$MASTER_IP:"$LEASE_FILE" "$LEASE_FILE"
if [ $? -eq 0 ]; then
	logger "DHCP leases synced successfully from master router ($MASTER_IP)"
else
	logger "Failed to sync DHCP leases from master router ($MASTER_IP)"
fi
