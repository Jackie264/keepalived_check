#!/bin/sh

# Path to Keepalived configuration file
KEEPALIVED_CONF="/etc/config/keepalived"

# Function to get the peer LAN IP from keepalived config
get_peer_lan_ip() {
	local lan_instance_name=$(uci show keepalived | grep "vrrp_instance.*\.interface='br-lan'" | cut -d'.' -f2)
	if [ -n "$lan_instance_name" ]; then
		local peer_name=$(uci get keepalived."$lan_instance_name".unicast_peer)
		if [ -n "$peer_name" ]; then
			uci get keepalived."$peer_name".address
		else
			logger "Error: Could not find unicast_peer for LAN vrrp_instance ($lan_instance_name) in Keepalived configuration."
			return 1
		fi
	else
		logger "Error: Could not find vrrp_instance with interface 'br-lan' in Keepalived configuration."
		return 1
	fi
}

FLAG_FILE="/tmp/sync_leases_first_run"

# Delay only on the first run
if [ ! -f "$FLAG_FILE" ]; then
	sleep 5
	touch "$FLAG_FILE"
fi

# Get the peer LAN IP from the configuration
SOURCE_IP=$(get_peer_lan_ip)

if [ -z "$SOURCE_IP" ]; then
	logger "Error: Could not determine peer LAN IP from Keepalived configuration."
	exit 1
fi

SOURCE_FILE="/tmp/dhcp.leases"
TARGET_FILE="/tmp/dhcp.leases"
TMP_FILE="/tmp/dhcp.leases.tmp"

rsync -az "$SOURCE_IP:$SOURCE_FILE" "$TMP_FILE" >/dev/null 2>&1

if [ $? -ne 0 ]; then
	logger "Failed to fetch DHCP leases from master ($SOURCE_IP)"
	exit 1
fi

if cmp -s "$TMP_FILE" "$TARGET_FILE"; then
	logger "DHCP leases are identical, skipping sync"
	rm -f "$TMP_FILE"
	exit 0
else
	logger "DHCP leases changed, updating local file"
	mv "$TMP_FILE" "$TARGET_FILE"
fi
