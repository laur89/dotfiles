#!/usr/bin/env bash
#
# https://github.com/jaagr/polybar/wiki
#################################################

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 1; done

# Launch bar(s):
####### default launcher:
#polybar --reload top &
####### alternative, per-monitor launcher: (from https://github.com/kostarakonjac1331/dots2/blob/master/polybar/launch.sh)
w="$(ls /sys/class/net/ | grep ^wl | awk 'NR==1{print $1}')"

#for m in $(polybar --list-monitors | cut -d":" -f1); do
for m in $(xrandr --listmonitors | awk '/^ /{print $NF}'); do
    WIRELESS="$w" MONITOR="$m" polybar --reload top &
    #WIRELESS="$w" MONITOR="$m" polybar --reload mainbar1 &
done

# note you might appreciate 'pin-workspaces = true' config w/ multi-setup
####### /launch bars


echo 'Bar(s) launched...'
