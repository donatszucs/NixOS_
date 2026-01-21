#!/bin/sh

# Options
shutdown=" Shutdown"
reboot=" Reboot"
lock=" Lock"
suspend=" Suspend"
logout=" Logout"

# Rofi Command
rofi_cmd() {
	rofi -dmenu \
		-mesg "Power Menu"
}

# Pass variables to rofi dmenu
run_rofi() {
	echo -e "$lock\n$suspend\n$logout\n$reboot\n$shutdown" | rofi_cmd
}

# Execute Command
run_cmd() {
	if [[ "$1" == "--shutdown" ]]; then
		systemctl poweroff
	elif [[ "$1" == "--reboot" ]]; then
		systemctl reboot
	elif [[ "$1" == "--suspend" ]]; then
		systemctl suspend
	elif [[ "$1" == "--logout" ]]; then
		hyprctl dispatch exit
	elif [[ "$1" == "--lock" ]]; then
		swaylock # or hyprlock if you have it
	fi
}

# Actions
chosen="$(run_rofi)"
case ${chosen} in
    $shutdown)
		run_cmd --shutdown
        ;;
    $reboot)
		run_cmd --reboot
        ;;
    $lock)
		run_cmd --lock
        ;;
    $suspend)
		run_cmd --suspend
        ;;
    $logout)
		run_cmd --logout
        ;;
esac