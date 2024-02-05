#!/usr/bin/env bash
#
# https://github.com/polybar/polybar/wiki
#################################################
readonly SELF=polybar-launcher
readonly _IF_DIR='/sys/class/net/'
SELECTED_BAR=top
TRAY_MONITOR_PREFERENCE=(
    DisplayPort-3
    DisplayPort-5
    eDP
)

source /etc/.global-bash-init; _init || exit 1  # needs to be very first for the env vars

# Terminate already running bar instances
polybar-msg cmd quit  # requires IPC to be enabled
#killall -q polybar

# Wait until the processes have been shut down
while pgrep -u "$UID" -x polybar >/dev/null; do sleep 1; done

# Launch bar(s):
####### default launcher:
#polybar --reload "$SELECTED_BAR" &
####### alternative, per-monitor launcher: (from https://github.com/kostarakonjac1331/dots2/blob/master/polybar/launch.sh)
# for multi-mon launcher logic, see also https://github.com/polybar/polybar/issues/763
[[ -d "$_IF_DIR" ]] || err_display "[$_IF_DIR] not a dir" "$SELF"
#w="$(find "$_IF_DIR" -maxdepth 1 -mindepth 1 -name 'wl*' -printf '%f' -quit)"
w="$(find -L "$_IF_DIR" -maxdepth 2 -mindepth 2 \
    -type d -name wireless -printf '%h' -quit 2>/dev/null | xargs -n1 basename)"

# TODO: shouldn't we be using "xrandr --listactivemonitors"?
IFS= readarray -t MONITORS < <(xrandr --listmonitors | awk '/^\s+[0-9]+:\s+/{print $NF}')  # or:  polybar --list-monitors | cut -d':' -f1

tray_output="${MONITORS[0]}"  # default
for m in "${TRAY_MONITOR_PREFERENCE[@]}"; do
    list_contains "$m" "${MONITORS[@]}" && tray_output="$m" && break
done

# note we pass env vars that are to be referenced in polybar config (WIRELESS/MONITOR...):
for m in "${MONITORS[@]}"; do
    #WIRELESS="$w" MONITOR="$m" polybar --reload "$SELECTED_BAR" &
    #WIRELESS="$w" MONITOR="$m" polybar --reload bar2 &  # in case you're running more than one bar

    unset WIRELESS  MONITOR
    export WIRELESS="$w"  MONITOR="$m"
    silent_background  polybar --reload "$SELECTED_BAR"
done

# note you might appreciate 'pin-workspaces = true' config w/ multi-setup
####### /launch bars


echo 'Bar(s) launched...'
