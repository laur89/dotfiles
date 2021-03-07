#!/usr/bin/env bash
# base from http://mrtango.planetcrazy.de/dynamic-screen-definitions-in-i3wm.html
#####################################

source /etc/.global-bash-init
_init || exit 1
###############


#### Entry ####

xrandr --listactivemonitors | awk '$1 ~ /^0/ {print "set $mainscreen " $4}'
xrandr --listactivemonitors | awk '$1 ~ /^1/ {print "set $sidescreen " $4}'

exit 0

