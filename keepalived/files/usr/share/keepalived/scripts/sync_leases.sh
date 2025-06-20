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

# 新增：直接返回对端IP，供外部调用
if [ "$1" = "get_peer_ip" ]; then
    get_peer_lan_ip
    exit $?
fi

PEER_IP=$(get_peer_lan_ip)

if [ -z "$PEER_IP" ]; then
    logger "sync_leases: 错误: 无法确定对端 LAN IP，退出同步。"
    exit 1
fi

# Function to pull leases from peer
pull_leases() {
    local source_ip=$1
    logger "sync_leases: 尝试从对端 ($source_ip) 拉取 DHCP 租约文件..."
    rsync -az --timeout=10 "root@$source_ip:$LOCAL_LEASES_FILE" "$LOCAL_LEASES_FILE" >/dev/null 2>&1
    if [ $? -eq 0 ]; then
        logger "sync_leases: 成功从对端 ($source_ip) 拉取 DHCP 租约。"
        # 拉取成功后，更新状态文件中的哈希值
        CURRENT_HASH=$(md5sum "$LOCAL_LEASES_FILE" 2>/dev/null | awk '{print $1}')
        echo "$CURRENT_HASH" > "$SYNC_STATUS_FILE"
        return 0
    else
        logger "sync_leases: 错误: 从对端 ($source_ip) 拉取 DHCP 租约失败。"
        return 1
    fi
}

# Function to push leases to peer
push_leases() {
    local dest_ip=$1

    # 检查本地租约文件是否存在且不为空
    if [ ! -s "$LOCAL_LEASES_FILE" ]; then # -s 检查文件是否存在且大小大于零
        logger "sync_leases: 本地租约文件 $LOCAL_LEASES_FILE 不存在或为空，跳过推送。"
        exit 0
    fi

    # 计算当前租约文件哈希值
    CURRENT_HASH=$(md5sum "$LOCAL_LEASES_FILE" | awk '{print $1}')

    # 如果状态文件不存在，初始化它
    if [ ! -f "$SYNC_STATUS_FILE" ]; then
        logger "sync_leases: 首次运行或状态文件丢失，执行推送..."
    else
        # 读取上一次同步的哈希值
        PREVIOUS_HASH=$(cat "$SYNC_STATUS_FILE")
        # 如果哈希值相同，则文件未改变，无需同步
        if [ "$CURRENT_HASH" = "$PREVIOUS_HASH" ]; then
            logger "sync_leases: DHCP 租约文件未变化，跳过推送。"
            exit 0
        fi
        logger "sync_leases: DHCP 租约文件已更新，准备推送至 $dest_ip。"
    fi

    logger "sync_leases: 尝试将 DHCP 租约推送到对端 ($dest_ip)。"
    rsync -az --timeout=10 "$LOCAL_LEASES_FILE" "root@$dest_ip:$LOCAL_LEASES_FILE" >/dev/null 2>&1

    # 检查 rsync 命令的执行结果
    if [ $? -eq 0 ]; then
        logger "sync_leases: 成功将 DHCP 租约推送到对端主机 ($dest_ip)。"
        # 同步成功后，更新状态文件中的哈希值
        echo "$CURRENT_HASH" > "$SYNC_STATUS_FILE"
        return 0
    else
        logger "sync_leases: 错误: 将 DHCP 租约推送到对端主机 ($dest_ip) 失败。"
        return 1
    fi
}

# Main logic based on arguments
case "$1" in
    pull)
        pull_leases "$PEER_IP"
        ;;
    push)
        push_leases "$PEER_IP"
        ;;
    *)
        logger "sync_leases: Usage: $0 [pull|push|get_peer_ip]"
        exit 1
        ;;
esac

exit 0
