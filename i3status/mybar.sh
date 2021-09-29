#!/bin/sh

# i3 config in ~/.config/i3/config :
# bar {
#   status_command exec /home/aidan/bin/i3status/i3status//mybar.sh
# }

bg_bar_color="#000000"
delay="1"

# Initialization of needed globals
rx=$(cat /sys/class/net/wlan0/statistics/rx_bytes)
rx+=$(cat /sys/class/net/enp2s0/statistics/rx_bytes)
tx=$(cat /sys/class/net/wlan0/statistics/tx_bytes)
tx+=$(cat /sys/class/net/enp2s0/statistics/tx_bytes)

# Print a left caret separator
# @params {string} $1 text color, ex: "#FF0000"
# @params {string} $2 background color, ex: "#FF0000"
separator() {
  echo -n "{"
  echo -n "\"full_text\":\"\"," # CTRL+Ue0b2
  echo -n "\"separator\":false,"
  echo -n "\"separator_block_width\":0,"
  echo -n "\"border\":\"$bg_bar_color\","
  echo -n "\"border_left\":0,"
  echo -n "\"border_right\":0,"
  echo -n "\"border_top\":2,"
  echo -n "\"border_bottom\":2,"
  echo -n "\"color\":\"$1\","
  echo -n "\"background\":\"$2\""
  echo -n "}"
}

common() {
  echo -n "\"border\": \"$bg_bar_color\","
  echo -n "\"separator\":false,"
  echo -n "\"separator_block_width\":0,"
  echo -n "\"border_top\":2,"
  echo -n "\"border_bottom\":2,"
  echo -n "\"border_left\":0,"
  echo -n "\"border_right\":0"
}

myvpn_on() {
  local bg="#424242" # grey darken-3
  local icon=""
  if nmcli con show --active | \grep --color=auto -i tun0 > /dev/null; then
    bg="#E53935" # rouge
    icon=""
  fi
  separator $bg "#000000" # background left previous block
  bg_separator_previous=$bg
  echo -n ",{"
  echo -n "\"name\":\"id_vpn\","      
  echo -n "\"full_text\":\" ${icon} VPN \","
  echo -n "\"background\":\"$bg\","
  common
  echo -n "},"
}

network_activity() {
  local bg="#008000" # green
  local up_icon=""
  local down_icon=""
  #return  
  
  local rxtmp=$(cat /sys/class/net/wlan0/statistics/rx_bytes)
  rxtmp+=$(cat /sys/class/net/enp2s0/statistics/rx_bytes)
  local txtmp=$(cat /sys/class/net/wlan0/statistics/tx_bytes)
  txtmp+=$(cat /sys/class/net/enp2s0/statistics/tx_bytes)

  down_speed=$(~/bin/i3status/i3status/convert-to-bps $rx $rxtmp $delay)
  up_speed=$(~/bin/i3status/i3status/convert-to-bps $tx $txtmp $delay)

  rx=$rxtmp
  tx=$txtmp
  
  separator $bg $bg_separator_previous
  bg_separator_previous=$bg
  echo -n ",{"
  echo -n "\"name\":\"id_network\","      
  echo -n "\"full_text\":\" ${up_speed} ${up_icon} ${down_speed} ${down_icon} \","
  echo -n "\"background\":\"$bg\","
  common
  echo -n "},"
}

disk_usage() {
  local bg="#3949AB"
  separator $bg $bg_separator_previous
  echo -n ",{"
  echo -n "\"name\":\"id_disk_usage\","
  echo -n "\"full_text\":\"  $(/home/aidan/bin/i3status/i3status/disk.py)%\","
  echo -n "\"background\":\"$bg\","
  common
  echo -n "}"
}

memory() {
  echo -n ",{"
  echo -n "\"name\":\"id_memory\","
  echo -n "\"full_text\":\"  $(/home/aidan/bin/i3status/i3status/memory.py)%\","
  echo -n "\"background\":\"#3949AB\","
  common
  echo -n "}"
}

cpu_usage() {
  echo -n ",{"
  echo -n "\"name\":\"id_cpu_usage\","
  echo -n "\"full_text\":\"  $(/home/aidan/bin/i3status/i3status/cpu.py)% \","
  echo -n "\"background\":\"#3949AB\","
  common
  echo -n "},"
  bg_separator_previous="#3949AB"
}

battery1() {
  if [ -f /sys/class/power_supply/BAT1/uevent ]; then
    local bg="#D69E2E"
    separator $bg $bg_separator_previous
    bg_separator_previous=$bg
    prct=$(cat /sys/class/power_supply/BAT1/uevent | grep "POWER_SUPPLY_CAPACITY=" | cut -d'=' -f2)
    charging=$(cat /sys/class/power_supply/BAT1/uevent | grep "POWER_SUPPLY_STATUS" | cut -d'=' -f2) # POWER_SUPPLY_STATUS=Discharging|Charging
    icon=""
    if [ "$charging" == "Charging" ]; then
      icon=""
    fi
    echo -n ",{"
    echo -n "\"name\":\"battery0\","
    echo -n "\"full_text\":\" ${icon} ${prct}% \","
    echo -n "\"color\":\"#000000\","
    echo -n "\"background\":\"$bg\","
    common
    echo -n "},"
  fi
}

volume() {
  local bg="#673AB7"
  separator $bg $bg_separator_previous
  bg_separator_previous=$bg
  vol=$(pamixer --get-volume)
  echo -n ",{"
  echo -n "\"name\":\"id_volume\","
  if [ $vol -le 0 ]; then
    echo -n "\"full_text\":\"  ${vol}% \","
  else
    echo -n "\"full_text\":\"  ${vol}% \","
  fi
  echo -n "\"background\":\"$bg\","
  common
  echo -n "},"
}

mydate() {
  local bg="#E0E0E0"
  separator $bg $bg_separator_previous
  echo -n ",{"
  echo -n "\"name\":\"id_time\","
  echo -n "\"full_text\":\"  $(date "+%a %d/%m %H:%M") \","
  echo -n "\"color\":\"#000000\","
  echo -n "\"background\":\"$bg\","
  common
  echo -n "},"
  separator $bg_bar_color $bg
}

systemupdate() {
  local nb=$(checkupdates &>/dev/null | wc -l)
  if (( $nb > 0)); then
    echo -n ",{"
    echo -n "\"name\":\"id_systemupdate\","
    echo -n "\"full_text\":\"  ${nb}\""
    echo -n "}"
  fi
}

logout() {
  echo -n ",{"
  echo -n "\"name\":\"id_logout\","
  echo -n "\"full_text\":\"  \""
  echo -n "}"
}

# https://github.com/i3/i3/blob/next/contrib/trivial-bar-script.sh
echo '{ "version": 1, "click_events":true }'     # Send the header so that i3bar knows we want to use JSON:
echo '['                    # Begin the endless array.
echo '[]'                   # We send an empty first array of blocks to make the loop simpler:

# Now send blocks with information forever:
(while :;
do
	echo -n ",["
  myvpn_on
  network_activity
  disk_usage
  memory
  cpu_usage
  battery1
  volume
  mydate
  systemupdate
  logout
  echo "]"
	sleep "$delay"
done) &

# click events
while read line;
do
  # echo $line > /home/you/gitclones/github/i3/tmp.txt
  # {"name":"id_vpn","button":1,"modifiers":["Mod2"],"x":2982,"y":9,"relative_x":67,"relative_y":9,"width":95,"height":22}

  # VPN click
  if [[ $line == *"name"*"id_vpn"* ]]; then
    xterm -e /home/aidan/bin/i3status/i3status/click_vpn.sh &

  # CHECK UPDATES
  elif [[ $line == *"name"*"id_systemupdate"* ]]; then
    xterm -e /home/aidan/bin/i3status/i3status/click_checkupdates.sh &

  # CPU
  elif [[ $line == *"name"*"id_cpu_usage"* ]]; then
    xterm -e htop &

  # TIME
  elif [[ $line == *"name"*"id_time"* ]]; then
    xterm -e /home/aidan/bin/i3status/i3status/click_time.sh &

  # VOLUME
  elif [[ $line == *"name"*"id_volume"* ]]; then
    xterm -e alsamixer &

  # LOGOUT
  elif [[ $line == *"name"*"id_logout"* ]]; then
    i3-nagbar -t warning -m 'Log out ?' -b 'yes' 'i3-msg exit' > /dev/null &

  fi  
done
