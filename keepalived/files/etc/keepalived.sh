#!/bin/sh

# Log Keepalived state change
logger "Keepalived state changed: TYPE=$TYPE, NAME=$NAME, ACTION=$ACTION"

# Check if natmap installed
natmap_installed=true
if ! command -v natmap >/dev/null 2>&1; then
	logger "natmap is not installed, skipping natmap control"
	natmap_installed=false
fi

# Start natmap if necessary
start_natmap_if_needed() {
	# Check natmap status
	if service natmap status | grep -q "running"; then
		logger "natmap service is already running, skipping start"
	else
		logger "***** Starting natmap service *****"
		/etc/init.d/natmap start 2>/dev/null || logger "Error starting natmap"
	fi
}

# Stop natmap if necessary
stop_natmap_if_needed() {
	logger "***** Stopping natmap service *****"
	/etc/init.d/natmap stop 2>/dev/null || logger "Error stopping natmap"
}

# Check if cloudflared installed
cloudflared_installed=true
if ! command -v cloudflared >/dev/null 2>&1; then
	logger "cloudflared is not installed, skipping cloudflared control"
	cloudflared_installed=false
fi

# Start cloudflared if necessary
start_cloudflared_if_needed() {
	# Check cloudflared status
	if service cloudflared status | grep -q "running"; then
		logger "cloudflared service is already running, skipping start"
	else
		logger "***** Starting cloudflared service *****"
		/etc/init.d/cloudflared start 2>/dev/null || logger "Error starting cloudflared"
	fi
}

# Stop cloudflared if necessary
stop_cloudflared_if_needed() {
	logger "***** Stopping cloudflared service *****"
	/etc/init.d/cloudflared stop 2>/dev/null || logger "Error stopping cloudflared"
}

# Check and update UCI settings
check_and_update() {
	local config_key=$1
	local target_value=$2
	local current_value
	current_value=$(uci get "$config_key" 2>/dev/null)

	if [ "$current_value" != "$target_value" ]; then
		logger "Updating $config_key from $current_value to $target_value"
		uci set "$config_key"="$target_value"
		uci commit "${config_key%%.*}" 2>/dev/null || logger "Error committing config"
		else
		logger "$config_key is already set to $target_value, skipping"
	fi
}

# Function to Enable natmap
enable_natmap() {
	if [ "$natmap_installed" = true ]; then
		check_and_update "natmap.@global[0].enable" "1"
		start_natmap_if_needed "$ACTION"
	fi
}

# Function to Disable natmap
disable_natmap() {
	if [ "$natmap_installed" = true ]; then
		check_and_update "natmap.@global[0].enable" "0"
		stop_natmap_if_needed "$ACTION"
	fi
}

# Function to Enable cloudflared
enable_cloudflared() {
	if [ "$cloudflared_installed" = true ]; then
		check_and_update "cloudflared.config.enabled" "1"
		start_cloudflared_if_needed "$ACTION"
	fi
}

# Function to Disable cloudflared
disable_cloudflared() {
	if [ "$cloudflared_installed" = true ]; then
		check_and_update "cloudflared.config.enabled" "0"
		stop_cloudflared_if_needed "$ACTION"
	fi
}

# Function to enable DHCPv4 add DHCP option
enable_dhcpv4_add_option() {
	uci batch <<-EOF
		delete dhcp.lan.ignore
		add_list dhcp.lan.dhcp_option='3,192.88.9.1'
		add_list dhcp.lan.dhcp_option='6,192.88.9.1'
		commit dhcp.lan
	EOF
	logger "*** Enable DHCPv4 and DHCP option ***"
}

# Function to add DHCP RA flags
add_dhcpv6_ra_flags() {
	uci batch <<-EOF
		add_list dhcp.lan.ra_flags=managed-config
		add_list dhcp.lan.ra_flags=other-config
		add_list dhcp.lan.ra_flags=home-agent
		commit dhcp.lan
	EOF
	logger "*** Setting DHCP RA flags ***"
}

# Function to disable DHCPv4 and clear option
disable_dhcpv4_clear_option() {
	uci batch <<-EOF
		set dhcp.lan.ignore=1
		del_list dhcp.lan.dhcp_option='3,192.88.9.1'
		del_list dhcp.lan.dhcp_option='6,192.88.9.1'
		commit dhcp.lan
	EOF
	logger "*** Cleared DHCP option ***"
}

# Function to clear DHCP RA flags
clear_dhcpv6_ra_flags() {
	uci batch <<-EOF
		del_list dhcp.lan.ra_flags=managed-config
		del_list dhcp.lan.ra_flags=other-config
		del_list dhcp.lan.ra_flags=home-agent
		commit dhcp.lan
	EOF
	logger "*** Cleared DHCP RA flags ***"
}

# Restart dnsmasq if necessary
restart_dnsmasq_if_needed() {
	logger "***** Restarting dnsmasq service *****"
	/etc/init.d/dnsmasq restart 2>/dev/null || logger "Error restarting dnsmasq"
}

# Restart odhcpd if necessary
restart_odhcpd_if_needed() {
	logger "***** Restarting odhcpd service *****"
	/etc/init.d/odhcpd restart 2>/dev/null || logger "Error restarting odhcpd"
}

# Check if keepalived is shutting down
if [ "$ACTION" = "shutdown" ]; then
#	disable_dhcpv4_clear_option "$ACTION"
	clear_dhcpv6_ra_flags "$ACTION"
	disable_cloudflared "$ACTION"
	disable_natmap "$ACTION"
	logger "*** Keepalived is shutting down, removing state files ***"
	rm -f /tmp/keepalived_initial_start
	exit 0
fi

# Check if keepalived is starting up
if [ "$ACTION" = "startup" ]; then
	logger "***** Keepalived is starting, marking initial start *****"
	touch /tmp/keepalived_initial_start
	exit 0
fi

# Only handle GROUP events to avoid duplicate triggers
if [ "$TYPE" != "GROUP" ]; then
	exit 0
fi

if [ "$TYPE" = "GROUP" ]; then
	case "$ACTION" in
		NOTIFY_MASTER)
			echo "MASTER" > /tmp/keepalived_state
			;;
		NOTIFY_BACKUP)
			echo "BACKUP" > /tmp/keepalived_state
			;;
	esac
fi

# Handle delayed execution for NOTIFY_BACKUP after startup
if [ -f /tmp/keepalived_initial_start ] && [ "$ACTION" = "NOTIFY_BACKUP" ]; then
	logger "*** Detected initial NOTIFY_BACKUP after Keepalived start, delaying execution ***"
	sleep 5

	# Check final state
	CURRENT_STATE=$(cat /tmp/keepalived_state)
	rm -f /tmp/keepalived_initial_start

	if [ "$CURRENT_STATE" = "BACKUP" ]; then
		logger "*** After delay, Keepalived is still in BACKUP state, executing NOTIFY_BACKUP logic ***"
	else
		logger "*** After delay, Keepalived is no longer in BACKUP state, skipping NOTIFY_BACKUP execution ***"
		exit 0
	fi
fi

# --- LOGIC CHANGE HIGHLIGHT ---
# Master主机会主动同步leases文件给Backup主机
master_initiates_sync() {
	local sync_direction=$1
	local peer_ip=$(/etc/keepalived/scripts/sync_leases.sh get_peer_ip) # 假设 sync_leases.sh 可以获取对端 IP

	if [ -z "$peer_ip" ]; then
		logger "master_initiates_sync: Error: Could not determine peer LAN IP, skipping sync."
		return 1
	fi

	# 新增逻辑：Master 在启动时，先尝试从对端拉取
	if [ "$sync_direction" = "PULL_ON_MASTER_START" ]; then
		logger "Executing sync_leases.sh to pull DHCP leases from peer ($peer_ip) in MASTER startup"
		# 尝试从对端拉取，如果对端存在且活跃
		/etc/keepalived/scripts/sync_leases.sh pull "$peer_ip" & # 后台执行，避免阻塞
	elif [ "$sync_direction" = "NOTIFY_MASTER" ]; then
		logger "Executing sync_leases.sh to push DHCP leases to peer ($peer_ip) in MASTER state"
		# 正常 MASTER 运行时推送
		/etc/keepalived/scripts/sync_leases.sh push "$peer_ip" & # 后台执行
	fi
}
# --- END OF MODIFIED BLOCK ---


# Process Keepalived state directly from the ACTION
if [ "$ACTION" = "NOTIFY_MASTER" ]; then
	logger "Keepalived state is MASTER, enabling services"

	# 优先：Master 启动时尝试从对端拉取租约文件
	# 这一步应该在 dnsmasq 启动之前完成，确保它能加载到最新的租约
	master_initiates_sync "PULL_ON_MASTER_START" #
	# 给拉取操作一些时间
	sleep 1 #
	
	# Enable DHCPv4
	enable_dhcpv4_add_option "$ACTION"
	restart_dnsmasq_if_needed

	# Enable DHCPv6
	check_and_update "dhcp.lan.dhcpv6" "server"
	check_and_update "dhcp.lan.ra" "server"
	add_dhcpv6_ra_flags "$ACTION"
	restart_odhcpd_if_needed

	# Master 启动完成后，再设置定时任务进行周期性推送
 	schedule_sync_leases "$ACTION"
  
	# Disable cloudflared
	disable_cloudflared "$ACTION"

	# Enable natmap
	enable_natmap "$ACTION"

elif [ "$ACTION" = "NOTIFY_BACKUP" ]; then
	logger "Keepalived state is BACKUP, disabling services"

	# Disable natmap
	disable_natmap "$ACTION"

	# Enable cloudflared
	enable_cloudflared "$ACTION"

	# Disable DHCPv4
	disable_dhcpv4_clear_option "$ACTION"
	restart_dnsmasq_if_needed "$ACTION"

	# Disable DHCPv6
	check_and_update "dhcp.lan.dhcpv6" "disabled"
	check_and_update "dhcp.lan.ra" "disabled"
	clear_dhcpv6_ra_flags "$ACTION"
	restart_odhcpd_if_needed

	# --- MODIFIED BLOCK ---
	# Backup router now only removes the cron job
	schedule_sync_leases "$ACTION"
	# --- END OF MODIFICATION ---

elif [ "$ACTION" = "NOTIFY_FAULT" ]; then
	logger "Keepalived state is FAULT, disabling services"

	# Disable natmap
	disable_natmap "$ACTION"

	# Disable cloudflared
	disable_cloudflared "$ACTION"

	# --- MODIFIED BLOCK ---
	# Remove schedule on FAULT state
	schedule_sync_leases "$ACTION"
	# --- END OF MODIFICATION ---
fi
