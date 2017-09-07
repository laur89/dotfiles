#!/bin/bash
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here) or DM;
# Mul execute'ib siit DM või .profile
##################################

DEFAULT_SESSION="start_dwm"
#export GTK2_RC_FILES="$HOME/.gtkrc-2.0" # seda vist pole vaja
#if test -z "$DBUS_SESSION_BUS_ADDRESS"; then
#    exec dbus-launch --sh-syntax --exit-with-session
#fi
#eval $(/usr/bin/gnome-keyring-daemon --start --components=gpg,pkcs11,secrets,ssh)
#export GPG_AGENT_INFO SSH_AUTH_SOCK

input="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
source "$HOME/.common_startup"

case "$input" in
    dwm)
        report "waiting for couple of time to give .common_startup some time to spin up services..."
        sleep 5
        exec start_dwm
        #exec ck-launch-session dbus-launch --sh-syntax --exit-with-session /usr/local/bin/start_dwm
        #exec /usr/local/bin/start_dwm
        #exec dbus-launch --sh-syntax --exit-with-session start_dwm
        ;;
    i3)
        exec i3
        ;;
    kde)
        exec startkde
        ;;
    xfce4)
        exec startxfce4
        ;;
    icewm)
        icewmbg &
        icewmtray &
        exec icewm
        ;;
    wmaker)
        exec wmaker
        ;;
    blackbox)
        exec blackbox
        ;;
    fluxbox | flux | fb)
        exec startfluxbox
        ;;
    bspwm | bs)
        sxhkd &
        exec bspwm
        ;;
    none | nil | console)
        exec xterm
        ;;
    *)
        exec "$DEFAULT_SESSION"
        ;;
esac

