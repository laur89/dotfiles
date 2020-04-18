#!/bin/bash
#
# ~/.xinitrc
#
# Executed by startx (run your window manager from here) or DM;
# Mul execute'ib siit DM või .profile
##################################

#export GTK2_RC_FILES="$HOME/.gtkrc-2.0" # seda vist pole vaja
#if test -z "$DBUS_SESSION_BUS_ADDRESS"; then
#    exec dbus-launch --sh-syntax --exit-with-session
#fi
#eval $(/usr/bin/gnome-keyring-daemon --start --components=gpg,pkcs11,secrets,ssh)
#export GPG_AGENT_INFO SSH_AUTH_SOCK

input="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
systemctl --user import-environment DISPLAY  # make sure display env var is set

case "$input" in
    dwm)
        source "$HOME/.common_startup" &
        report "waiting for couple of time to give .common_startup some time to spin up services..."
        sleep 5
        exec start_dwm
        #exec ck-launch-session dbus-launch --sh-syntax --exit-with-session /usr/local/bin/start_dwm
        #exec /usr/local/bin/start_dwm
        #exec dbus-launch --sh-syntax --exit-with-session start_dwm
        ;;
    i3)
        # generate our config:
        update-conf.py -f "$HOME/.config/i3/config" || err "i3 config install failed w/ $?"

        if is_windows; then
            i3 &
            #sleep 1
            source "$HOME/.common_startup"
        else  # both native & virt:
            source "$HOME/.common_startup"
            exec i3
            #exec i3 --shmlog-size=26214400  # enable logging; to enable logging on the fly, do:  i3-msg 'debuglog on; shmlog on; reload'
            # to obtain log:     DISPLAY=:0 i3-dump-log
        fi
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
    none | nil | console | terminal)
        if command -v uxterm; then
            exec uxterm
        else
            exec xterm
        fi
        ;;
    *)
        err "incorrect option [$input]"
        sleep 2
        exit 1
        ;;
esac

