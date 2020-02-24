#!/usr/bin/env bash
# base from http://mrtango.planetcrazy.de/dynamic-screen-definitions-in-i3wm.html
#####################################

# import common:
if ! type __COMMONS_LOADED_MARKER > /dev/null 2>&1; then
    if [[ -r "$_SCRIPTS_COMMONS" ]]; then
        source "$_SCRIPTS_COMMONS"
    else
        echo -e "\n    ERROR: common file [$_SCRIPTS_COMMONS] not found! Abort."
        exit 1
    fi
fi

###############


#### Entry ####

xrandr --listactivemonitors | awk '$1 ~ /^0/ {print "set $mainscreen " $4}'
xrandr --listactivemonitors | awk '$1 ~ /^1/ {print "set $sidescreen " $4}'

exit 0

