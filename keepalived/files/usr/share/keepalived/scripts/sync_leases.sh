#!/bin/sh
#sync_leases.sh

# 主路由器的租约文件
LEASE_FILE="/tmp/dhcp.leases"

# 备用路由器的目标路径
BACKUP_IP="<backup-router-ip>"
REMOTE_PATH="/tmp/dhcp.leases"

# 检查租约文件是否存在
if [ -f "$LEASE_FILE" ]; then
    # 使用 rsync 同步文件到备用路由器
    rsync -avz "$LEASE_FILE" root@$BACKUP_IP:"$REMOTE_PATH"
    if [ $? -eq 0 ]; then
        logger "DHCP leases synced successfully to backup router ($BACKUP_IP)"
    else
        logger "Failed to sync DHCP leases to backup router ($BACKUP_IP)"
    fi
else
    logger "DHCP lease file not found: $LEASE_FILE"
fi
