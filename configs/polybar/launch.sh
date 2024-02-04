#!/usr/bin/env bash
#
# https://github.com/polybar/polybar/wiki
#################################################
SELECTED_BAR=top

# Terminate already running bar instances
killall -q polybar

# Wait until the processes have been shut down
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 1; done

# Launch bar(s):
####### default launcher:
#polybar --reload "$SELECTED_BAR" &
####### alternative, per-monitor launcher: (from https://github.com/kostarakonjac1331/dots2/blob/master/polybar/launch.sh)
# for multi-mon launcher logic, see also https://github.com/polybar/polybar/issues/763
w="$(find /sys/class/net/ -maxdepth 1 -mindepth 1 -name 'wl*' -printf '%f' -quit)"

# note we pass env vars that are to be referenced in polybar config (WIRELESS/MONITOR...):
#for m in $(polybar --list-monitors | cut -d':' -f1); do
for m in $(xrandr --listmonitors | awk '/^\s+[0-9]+:\s+/{print $NF}'); do
    WIRELESS="$w" MONITOR="$m" polybar --reload "$SELECTED_BAR" &
    #WIRELESS="$w" MONITOR="$m" polybar --reload mainbar1 &
done

# note you might appreciate 'pin-workspaces = true' config w/ multi-setup
####### /launch bars


echo 'Bar(s) launched...'
