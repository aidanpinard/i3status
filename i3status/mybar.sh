#!/bin/sh

# i3 config in ~/.config/i3/config :
# bar {
#   status_command exec /home/aidan/bin/i3status/i3status//mybar.sh
# }

trap 'kill $(jobs -p)' EXIT SIGINT SIGTERM

bg_bar_color="#000000"
delay=1

#GLOBALS

# Music Rotation
CURRENT_POS=0
CHAR_LIMIT=30
CURRENT_STRING=""

# CPU Frequency
CPU_PREV_TOTAL=0
CPU_PREV_IDLE=0

# Network
last_time=0
last_rx=0
last_tx=0
ifaces=$(ls /sys/class/net | grep -E '^(eno|enp|ens|enx|eth|wlan|wlp)')

# System Update
LAST_UPDATE=1970-01-01-00
UPDATES=0

# Helpers
readable_mibps() {
  local bytes=$1
  local kib=$(( bytes >> 10 ))
  if [ $kib -lt 0 ]; then
    echo "? K"
  elif [ $kib -gt 1024 ]; then
    local mib_int=$(( kib >> 10 ))
    local mib_dec=$(( kib % 1024 * 976 / 10000 ))
    if [ "$mib_dec" -lt 10 ]; then
      mib_dec="0${mib_dec}"
    fi
    echo "${mib_int}.${mib_dec}MiB/s"
  else
    echo "${kib}KiB/s"
  fi
}

readable_mbps() {
  local bytes=$1
  local kbps=$(( bytes >> 7 ))
  if [ $kbps -lt 0 ]; then
    echo "? K"
  elif [ $kbps -gt 1000 ]; then
    local mbps_int=$(( kbps / 1000 ))
    local mbps_dec=$(awk "BEGIN { printf \"%d\", ((($kbps%1000)/10)+5)/10 }")
    echo "${mbps_int}.${mbps_dec}Mbps"
  else
    echo "${kbps}Kbps"
  fi
}


# Rotate a string anf trim it.
# @params {int} $1 rotation amount, ex: 20
# @params {int} $2 trim amount, ex: 50
# @params {string} $3 string to rotate, ex: "hello world"
rotate_left_and_trim() {
  local rot_amt=$1
  local trim_amt=$2
  local str=$3
  rot_amt=$(echo "$rot_amt ${#str}" | awk '{print ($1%$2)}')
  local front_str=$(echo "$str" | cut -b "-${rot_amt}")
  local back_str=$(echo "$str" | cut -b "$((rot_amt+1))-")
  str="${back_str}${front_str}"
  str=$(echo $str | cut -b "-$((trim_amt-1))")
  echo "$str"
}

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

# Status bar Functions

vpn() {
  local bg="#424242" # grey darken-3
  local icon=""
  if nmcli con show --active | \grep --color=auto -i tun0 > /dev/null; then
    bg="#E53935" # rouge
    icon=""
  fi

  separator $bg $bg_separator_previous # background left previous block
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
  local time=$(date +%s)
  local rx=0 tx=0 tmp_rx tmp_tx

  for iface in $ifaces; do
    read tmp_rx < "/sys/class/net/${iface}/statistics/rx_bytes"
    read tmp_tx < "/sys/class/net/${iface}/statistics/tx_bytes"
    rx=$(( rx + tmp_rx ))
    tx=$(( tx + tmp_tx ))
  done

  local interval=$(( $time - $last_time ))
  if [ $interval -gt 0 ]; then
    if [[ $(</dev/shm/usemb) == "0" ]]; then
      rate="$(readable_mbps $(( (tx - last_tx) / interval )))  $(readable_mbps $(( (rx - last_rx) / interval ))) "
    else
      rate="$(readable_mibps $(( (tx - last_tx) / interval )))  $(readable_mibps $(( (rx - last_rx) / interval ))) "
    fi
  else
    rate=" "
  fi

  last_time=$time
  last_rx=$rx
  last_tx=$tx
  
  separator $bg $bg_separator_previous
  bg_separator_previous=$bg
  echo -n ",{"
  echo -n "\"name\":\"id_network\","      
  echo -n "\"full_text\":\" ${rate} \","
  echo -n "\"background\":\"$bg\","
  common
  echo -n "},"
}

music_previous() {
  local music_status=$(playerctl status)
  if [[ "$music_status" -ne "Playing" && "$music_status" -ne "Paused" ]]; then
    return
  fi
  
  local bg="#d14081" # magenta pantone
  local icon=""
  if [[ "$music_status" == "Paused" ]]; then
    bg="#2b2d42" # space cadet
  fi

  separator $bg $bg_separator_previous # background left previous block
  bg_separator_previous=$bg

  echo -n ",{"
  echo -n "\"name\":\"id_music_previous\","
  echo -n "\"full_text\":\" ${icon}\","
  echo -n "\"background\":\"$bg\","
  common
  echo -n "}"
}

now_playing() {
  local music_status=$(playerctl status)
  if [[ "$music_status" -ne "Playing" && "$music_status" -ne "Paused" ]]; then
    return
  fi

  local bg="#d14081" # magenta pantone
  local icon=""
  if [[ $music_status == "Paused" ]]; then
    icon=""
    bg="#2b2d42" # space cadet
  fi

  local output=$(playerctl metadata --format "{{artist}} - {{title}}" )
  
  if [[ $output == $CURRENT_STRING ]]; then
    if (( CURRENT_POS > "${#output}}" )); then
      CURRENT_POS=0
      output=$(echo "$output" | cut -b "-$CHAR_LIMIT")
    else
      CURRENT_POS=$((CURRENT_POS+3))
      output=$(rotate_left_and_trim $CURRENT_POS $CHAR_LIMIT "$CURRENT_STRING")
    fi
  else 
    CURRENT_STRING=$output
    CURRENT_POS=0
    output=$(echo "$output" | cut -b "-$CHAR_LIMIT")
  fi

  echo -n ",{"
  echo -n "\"name\":\"id_now_playing\","
  echo -n "\"full_text\":\" ${icon} $output \","
  echo -n "\"background\":\"$bg\","
  common
  echo -n "}"
}

music_next() {
  local music_status=$(playerctl status)
  if [[ "$music_status" -ne "Playing" && "$music_status" -ne "Paused" ]]; then
    return
  fi
  
  local bg="#d14081" # magenta pantone
  local icon=""
  if [[ "$music_status" == "Paused" ]]; then
    bg="#2b2d42" # space cadet
  fi

  echo -n ",{"
  echo -n "\"name\":\"id_music_next\","
  echo -n "\"full_text\":\"${icon} \","
  echo -n "\"background\":\"$bg\","
  common
  echo -n "},"
}

cpu_temp() {
  local bg="#3949AB"
  separator $bg $bg_separator_previous

  local temp=$(sensors k10temp-pci-00c3 | awk '/Tdie:/ { printf "%.1f", $2 }')
  local icon=""
  if (( $(echo $temp | awk '{print ($1 >= 75.0) }') )); then
    icon=""
  fi
  echo -n ",{"
  echo -n "\"name\":\"id_cpu_temp\","
  echo -n "\"full_text\":\" $icon $temp°\","
  echo -n "\"background\":\"$bg\","
  common
  echo -n "}"
}

disk_usage() {
  local bg="#3949AB"
  
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
  local bg="#3949AB"

  echo -n ",{"
  echo -n "\"name\":\"id_memory\","
  echo -n "\"full_text\":\"  $(free -b | awk '/Mem:/ { printf "%.1f", ($2-$7)*100/$2 }')%\","
  echo -n "\"background\":\"$bg\","
  common
  echo -n "}"
}

cpu_usage() {
  local bg="#3949AB"

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
  echo -n "\"background\":\"$bg\","
  common
  echo -n "},"
  bg_separator_previous=$bg
}

battery() {
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
  bg_separator_previous="#000000"
	echo -n ",["
  vpn
  network_activity
  music_previous
  now_playing
  music_next
  cpu_temp
  disk_usage
  memory
  cpu_usage
  battery
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
  
  # network click
  elif [[ $line == *"name"*"id_network"* ]]; then
      if [[ $line == *"button\":3"* ]]; then
      if [[ $(</dev/shm/usemb) == "0" ]]; then
        echo "1" > /dev/shm/usemb
      else
        echo "0" > /dev/shm/usemb
      fi
    else
      xterm -e bandwhich &
    fi

  # Previous Music
  elif [[ $line == *"name"*"id_music_previous"* ]]; then
    playerctl previous

  # Now Playing
  elif [[ $line == *"name"*"id_now_playing"* ]]; then
    playerctl play-pause

  # Next Music
  elif [[ $line == *"name"*"id_music_next"* ]]; then
    playerctl next

  # CPU
  elif [[ $line == *"name"*"id_cpu_usage"* ]] \
    || [[ $line == *"name"*"id_memory"* ]] \
    || [[ $line == *"name"*"id_disk_usage"* ]]; then
    xterm -e htop &

  # VOLUME
  elif [[ $line == *"name"*"id_volume"* ]]; then
    xterm -e alsamixer &

  # TIME
  elif [[ $line == *"name"*"id_time"* ]]; then
    xterm -e /home/aidan/bin/i3status/i3status/click_time.sh &

  # CHECK UPDATES
  elif [[ $line == *"name"*"id_systemupdate"* ]]; then
    xterm -e /home/aidan/bin/i3status/i3status/click_checkupdates.sh &
    systemupdate > /dev/null

  # TURN OFF DISPLAY
  elif [[ $line == *"name"*"id_display_off"* ]]; then
    sleep 1
    xset dpms force off

  # LOGOUT
  elif [[ $line == *"name"*"id_logout"* ]]; then
    i3-nagbar -t warning -m 'Log out ?' -b 'yes' 'i3-msg exit' > /dev/null &

  fi  
done
