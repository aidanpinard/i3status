#!/bin/sh

# i3 config in ~/.config/i3/config :
# bar {
#   status_command exec /home/aidan/bin/i3status/i3status//mybar.sh
# }

bg_bar_color="#000000"
delay=1

CPU_PREV_TOTAL=0
CPU_PREV_IDLE=0
LAST_UPDATE=1970-01-01-00
UPDATES=0

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
  
  down_speed=$(~/bin/i3status/i3status/binaries/network-speed rx 0)
  up_speed=$(~/bin/i3status/i3status/binaries/network-speed tx 0)
  
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
  local used=0
  local avail=0
  local temp=0
  while read -r i
  do 
      temp=$(echo -n $i | awk '{print $2}')
      used=$(( $used+$temp ))
      temp=$(echo -n $i | awk '{print $3}')
      avail=$(( $avail+$temp ))
  done <<<$(df --output=source,used,avail | \grep --color=auto '/dev/*')
  echo -n ",{"
  echo -n "\"name\":\"id_disk_usage\","
  echo -n "\"full_text\":\"  $(awk "BEGIN {printf \"%.1f\", ${used}*100/${avail}}")%\","
  echo -n "\"background\":\"$bg\","
  common
  echo -n "}"
}

memory() {
  echo -n ",{"
  echo -n "\"name\":\"id_memory\","
  echo -n "\"full_text\":\"  $(free -b | awk '/Mem:/ { printf "%.1f", ($2-$7)*100/$2 }')%\","
  echo -n "\"background\":\"#3949AB\","
  common
  echo -n "}"
}

cpu_usage() {
  # Get the total CPU statistics, discarding the 'cpu ' prefix.
  CPU=($(sed -n 's/^cpu\s//p' /proc/stat))
  IDLE=${CPU[3]} # Just the idle CPU time.
 
  # Calculate the total CPU time.
  TOTAL=0
  for VALUE in "${CPU[@]:0:8}"; do
    TOTAL=$((TOTAL+VALUE))
  done
 
  # Calculate the CPU usage since we last checked.
  DIFF_IDLE=$((IDLE-PREV_IDLE))
  DIFF_TOTAL=$((TOTAL-PREV_TOTAL))
  DIFF_USAGE=$(awk "BEGIN {printf \"%.1f\", (1000 * ($DIFF_TOTAL - $DIFF_IDLE) / $DIFF_TOTAL+5)/10}")
 
  # Remember the total and idle CPU times for the next check.
  PREV_TOTAL="$TOTAL"
  PREV_IDLE="$IDLE"

  echo -n ",{"
  echo -n "\"name\":\"id_cpu_usage\","
  echo -n "\"full_text\":\"  $DIFF_USAGE% \","
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
    elif (( $prct >= 75 && $prct < 90 )); then
      icon=""
    elif (( $prct >= 50 && $prct < 75 )); then
      icon=""
    elif (( $prct >= 25 && $prct < 50 )); then
      icon=""
    elif (( $prct < 25 )); then
      icon=""
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
  TODAY=$(date +%Y-%m-%d-%H)
  if [[ "$TODAY" > "$LAST_UPDATE" ]]; then
    UPDATES=$(checkupdates 2> /dev/null | wc -l || checkupdates 2> /dev/null | wc -l)
    local aur_updates=$(checkupdates-aur 2>/dev/null | wc -l || checkupdates-aur 2>/dev/null | wc -l)
    UPDATES=$((UPDATES + aur_updates))
    if (( $UPDATES == 0 )); then
      LAST_UPDATE="$TODAY"
    fi
  fi
  if (( $UPDATES > 0)); then
    echo -n ",{"
    echo -n "\"name\":\"id_systemupdate\","
    echo -n "\"full_text\":\"  ${UPDATES}\""
    echo -n "}"
  fi
}

display_off() {
  echo -n ",{"
  echo -n "\"name\":\"id_display_off\","
  echo -n "\"full_text\":\"  \""
  echo -n "}"
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
  display_off
  logout
  echo "]"
	sleep "$delay"
done) &

# click events
while read line;
do
  # VPN click
  if [[ $line == *"name"*"id_vpn"* ]]; then
    xterm -e /home/aidan/bin/i3status/i3status/click_vpn.sh &

  # CHECK UPDATES
  elif [[ $line == *"name"*"id_systemupdate"* ]]; then
    xterm -e /home/aidan/bin/i3status/i3status/click_checkupdates.sh &
    systemupdate > /dev/null

  # CPU
  elif [[ $line == *"name"*"id_cpu_usage"* ]]; then
    xterm -e htop &

  # TIME
  elif [[ $line == *"name"*"id_time"* ]]; then
    xterm -e /home/aidan/bin/i3status/i3status/click_time.sh &

  # VOLUME
  elif [[ $line == *"name"*"id_volume"* ]]; then
    xterm -e alsamixer &
  
  # TURN OFF DISPLAY
  elif [[ $line == *"name"*"id_display_off"* ]]; then
    sleep 1
    xset dpms force off

  # LOGOUT
  elif [[ $line == *"name"*"id_logout"* ]]; then
    i3-nagbar -t warning -m 'Log out ?' -b 'yes' 'i3-msg exit' > /dev/null &

  fi  
done
