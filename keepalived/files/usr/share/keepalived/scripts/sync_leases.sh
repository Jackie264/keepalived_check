#!/bin/sh

# Load OpenWrt UCI functions
. /lib/functions.sh

# Define flag file
LOCAL_LEASES_FILE="/tmp/dhcp.leases"
SYNC_STATUS_FILE="/tmp/leases_sync_status"

# Function to get the peer LAN IP from keepalived config
get_peer_lan_ip() {
	local lan_instance peer_name peer_ip

	config_load keepalived
	config_foreach find_lan_vrrp vrrp_instance

	if [ -z "$lan_instance" ]; then
		logger "Error: Could not find vrrp_instance with interface 'br-lan' in Keepalived configuration."
		return 1
	fi

	config_get peer_name "$lan_instance" unicast_peer
	if [ -z "$peer_name" ]; then
		logger "Error: Could not find unicast_peer for LAN vrrp_instance ($lan_instance) in Keepalived configuration."
		return 1
	fi

	config_foreach find_peer_address peer

	if [ -n "$peer_ip" ]; then
		echo "$peer_ip"
		return 0
	else
		logger "Error: Could not find IP address for peer ($peer_name)."
		return 1
	fi
}

find_lan_vrrp() {
	local section="$1"
	local iface
	config_get iface "$section" interface
	[ "$iface" = "br-lan" ] && lan_instance="$section"
}

find_peer_address() {
	local section="$1"
	local name
	config_get name "$section" name
	if [ "$name" = "$peer_name" ]; then
		config_get peer_ip "$section" address
	fi
}

PEER_IP=$(get_peer_lan_ip)

if [ -z "$PEER_IP" ]; then
    logger "sync_leases: 错误: 无法确定对端 LAN IP，退出同步。"
    exit 1
fi

# 检查本地租约文件是否存在
if [ ! -f "$LOCAL_LEASES_FILE" ]; then
    logger "sync_leases: 本地租约文件 $LOCAL_LEASES_FILE 不存在，跳过同步。"
    exit 0
fi

# Compute current leases file hash
CURRENT_HASH=$(md5sum "$TMP_FILE" | awk '{print $1}')

# If the status file does not exist, initialize it
if [ ! -f "$SYNC_STATUS_FILE" ]; then
    logger "sync_leases: 首次运行或状态文件丢失，执行同步..."
else
    # 读取上一次同步的哈希值
    PREVIOUS_HASH=$(cat "$SYNC_STATUS_FILE")
    # 如果哈希值相同，则文件未改变，无需同步
    if [ "$CURRENT_HASH" = "$PREVIOUS_HASH" ]; then
        logger "sync_leases: DHCP 租约文件未变化，跳过同步。"
        exit 0
    fi
    logger "sync_leases: DHCP 租约文件已更新，准备同步到 $PEER_IP。"
fi

rsync -az --timeout=10 "$LOCAL_LEASES_FILE" "root@$PEER_IP:$LOCAL_LEASES_FILE" >/dev/null 2>&1

# 检查 rsync 命令的执行结果
if [ $? -eq 0 ]; then
    logger "sync_leases: 成功将 DHCP 租约同步到 Backup 主机 ($PEER_IP)。"
    # 同步成功后，更新状态文件中的哈希值
    echo "$CURRENT_HASH" > "$SYNC_STATUS_FILE"
else
    logger "sync_leases: 错误: 将 DHCP 租约同步到 Backup 主机 ($PEER_IP) 失败。"
    exit 1
fi

exit 0
