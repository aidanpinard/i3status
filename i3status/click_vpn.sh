#!/bin/sh

# Actually works for ProtonVPN
# we are connected if tun0 exists
if nmcli con show --active | \grep --color=auto -i tun0 > /dev/null; then
  # we are connected, so propose disconnection
  connection=$(nmcli con show --active| \grep --color=auto -i vpn | cut -f 1 -d " ")
  notify-send -a WeVPN "VPN off" "Disconnecting from $connection"
  nmcli con down $connection
else
  notify-send -a WeVPN "VPN on" "Connecting to US_miami-UDP"
  nmcli con up US_miami-UDP
fi
