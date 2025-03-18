#!/bin/sh

# Load OpenWrt UCI functions
. /lib/functions.sh

# Define flag file
FLAG_FILE="/tmp/sync_leases_first_run"

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

# Add timeout to rsync command
rsync -az --timeout=10 "$SOURCE_IP:$SOURCE_FILE" "$TMP_FILE" >/dev/null 2>&1

if [ $? -ne 0 ]; then
	logger "Failed to fetch DHCP leases from master ($SOURCE_IP), rsync exited with error"
	exit 1
fi

#if cmp -s "$TMP_FILE" "$TARGET_FILE"; then
#	logger "DHCP leases are identical, skipping sync"
#	rm -f "$TMP_FILE"
#	exit 0
#else
#	logger "DHCP leases changed, updating local file"
#	mv "$TMP_FILE" "$TARGET_FILE"
#fi

# Compute current leases file hash
CURRENT_HASH=$(md5sum "$TMP_FILE" | awk '{print $1}')

# If the status file does not exist, initialize it
if [ ! -f "$SYNC_STATUS_FILE" ]; then
	echo "$CURRENT_HASH" > "$SYNC_STATUS_FILE"
	logger "Leases sync: First sync, proceeding"
	mv "$TMP_FILE" "$TARGET_FILE"
	exit 0
fi

# Read previous hash
PREVIOUS_HASH=$(cat "$SYNC_STATUS_FILE")

if [ "$CURRENT_HASH" = "$PREVIOUS_HASH" ]; then
	# If identical, check if it's the first time logging this state
	if [ ! -f "$SYNC_STATUS_FILE.identical_logged" ]; then
		logger "DHCP leases are identical, skipping sync"
		touch "$SYNC_STATUS_FILE.identical_logged"
	fi
	rm -f "$TMP_FILE"
	exit 0
else
	# If different, sync the leases
	logger "DHCP leases changed, updating local file"
	mv "$TMP_FILE" "$TARGET_FILE"
	echo "$CURRENT_HASH" > "$SYNC_STATUS_FILE"
	rm -f "$SYNC_STATUS_FILE.identical_logged"
fi
