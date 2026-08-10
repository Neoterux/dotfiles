#!/bin/sh

#handle() {
#  case $1 in
#    windowtitle*)
      # Extract the window ID from the line
#      window_id=${1#*>>}

      # Fetch the list of windows and parse it using jq to find the window by its decimal ID
#      window_info=$(hyprctl clients -j | jq --arg id "0x$window_id" '.[] | select(.address == ($id))')

      # Extract the title from the window info
#      window_title=$(echo "$window_info" | jq '.title')

      # Check if the title matches the characteristics of the Bitwarden popup window
#      if [[ "$window_title" == *"(Bitwarden - Free Password Manager) - Bitwarden"* ]]; then
      
        # echo $window_id, $window_title
        # hyprctl dispatch togglefloating address:0x$window_id
        # hyprctl dispatch resizewindowpixel exact 20% 40%,address:0x$window_id
        # hyprctl dispatch movewindowpixel exact 40% 30%,address:0x$window_id

 #       hyprctl --batch "dispatch togglefloating address:0x$window_id ; dispatch resizewindowpixel exact 20% 40%,address:0x$window_id ; dispatch movewindowpixel exact 40% 30%,address:0x$window_id"        
#      fi
#      ;;
#  esac
#}

# Listen to the Hyprland socket for events and process each line with the handle function
#socat -U - UNIX-CONNECT:"$XDG_RUNTIME_DIR"/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do handle "$line"; done

#!/usr/bin/env bash

handle_windowtitlev2 () {
  # Description: emitted when a window title changes.
  # Format: `WINDOWADDRESS,WINDOWTITLE`
  windowaddress=${1%,*}
  windowtitle=${1#*,}

  case $windowtitle in
    *"(Bitwarden"*"Password Manager) - Bitwarden"*)
      hyprctl --batch \
        "dispatch togglefloating address:0x$windowaddress;"\
        "dispatch resizewindowpixel exact 20% 54%,address:0x$windowaddress;"\
        "dispatch centerwindow"
      ;;
#   specificwindowtitle) commands;;
  esac
}

handle() {
  # $1 Format: `EVENT>>DATA`
  # example: `workspace>>2`

  event=${1%>>*}
  data=${1#*>>}

  case $event in
    windowtitlev2) handle_windowtitlev2 "$data";;
#   anyotherevent) handle_otherevent "$data";;
    *) echo "unhandled event: $event" ;;
  esac
}

socat -U - UNIX-CONNECT:$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock | while read -r line; do handle "$line"; done
