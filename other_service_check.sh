#!/bin/sh
# other_service_check.sh

echo "Running other_service_check.sh at $(date)"
logger "Running other_service_check.sh at $(date)"

# Restart odhcpd if necessary
restart_odhcpd_if_needed() {
    if [ "$1" = true ]; then
        echo "Restarting odhcpd service"
        logger "Restarting odhcpd service"
        /etc/init.d/odhcpd restart
    fi
}

# Restart natmap if necessary
restart_natmap_if_needed() {
    if [ "$1" = true ]; then
        echo "Restarting natmap service"
        logger "Restarting natmap service"
        /etc/init.d/natmap restart
    fi
}

# Check and update UCI settings
check_and_update() {
    local config_key=$1
    local target_value=$2
    local current_value
    current_value=$(uci get "$config_key" 2>/dev/null)

    if [ "$current_value" = "$target_value" ]; then
        echo "$config_key is already set to $target_value, skipping"
        logger "$config_key is already set to $target_value, skipping"
        return 1
    else
        echo "Updating $config_key from $current_value to $target_value"
        logger "Updating $config_key from $current_value to $target_value"
        uci set "$config_key=$target_value"
        uci commit "${config_key%%.*}"
        return 0
    fi
}

# Check if natmap is installed
check_natmap_installed() {
    if ! [ -x "$(command -v natmap)" ]; then
        echo "natmap is not installed, skipping natmap control"
        logger "natmap is not installed, skipping natmap control"
        return 1
    fi
    return 0
}

# Update services based on Keepalived state
update_services() {
    local state="$1"
    echo "Detected Keepalived state: $state"
    logger "Detected Keepalived state: $state"

    restart_odhcpd=false
    restart_natmap=false

    # Check if natmap is installed before controlling it
    check_natmap_installed && natmap_installed=true || natmap_installed=false

    if [ "$state" = "MASTER" ]; then
        echo "Keepalived state is MASTER, enabling services"
        logger "Keepalived state is MASTER, enabling services"

        # Enable natmap if installed and not already enabled
        if [ "$natmap_installed" = true ]; then
            check_and_update "natmap.@global[0].enable" "1" && restart_natmap=true
        fi

        # Enable DHCPv4 if not already enabled
        check_and_update "dhcp.lan.ignore" "0"

        # Enable DHCPv6 if not already enabled
        check_and_update "dhcp.lan.dhcpv6" "server" && restart_odhcpd=true

        # Enable RA if not already enabled
        check_and_update "dhcp.lan.ra" "server" && restart_odhcpd=true

        # Enable NDP if not already enabled
        check_and_update "dhcp.lan.ndp" "relay" && restart_odhcpd=true

    elif [ "$state" = "BACKUP" ]; then
        echo "Keepalived state is BACKUP, disabling services"
        logger "Keepalived state is BACKUP, disabling services"

        # Disable natmap if installed and not already disabled
        if [ "$natmap_installed" = true ]; then
            check_and_update "natmap.@global[0].enable" "0" && restart_natmap=true
        fi

        # Disable DHCPv4 if not already disabled
        check_and_update "dhcp.lan.ignore" "1"

        # Disable DHCPv6 if not already disabled
        check_and_update "dhcp.lan.dhcpv6" "disabled" && restart_odhcpd=true

        # Disable RA if not already disabled
        check_and_update "dhcp.lan.ra" "disabled" && restart_odhcpd=true

        # Disable NDP if not already disabled
        check_and_update "dhcp.lan.ndp" "disabled" && restart_odhcpd=true
    else
        echo "Unknown Keepalived state: $state, skipping service adjustments"
        logger "Unknown Keepalived state: $state, skipping service adjustments"
    fi

    # Restart services if needed
    restart_odhcpd_if_needed "$restart_odhcpd"
    restart_natmap_if_needed "$restart_natmap"
}

# Main script execution
# For demonstration, let's assume the state is passed as an argument
update_services "$1"
