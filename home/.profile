# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 022

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc"
    fi
fi

# set PATH so it includes user's private bin if it exists
# currently done from bashrc
#if [ -d "$HOME/bin" ] ; then
    #PATH="$HOME/bin:$PATH"
#fi

##############################################
# siit alates kõik enda defineeritud:
##############################################
# start X; note the ssh-agent:
#if [ -z "$DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ]; then
if [ -z "$DISPLAY" ] && [ "$(tty)" == "/dev/tty1" ]; then
    echo -e "Enter DE/WM:"
    echo '============'
    read -r session
    # note ssh-agent ver should be used when we _don't_ use gnome-keyring (or equivalent):
    #exec ssh-agent startx "$HOME/.xinitrc" "$session" # -- -logverbose 6
    exec startx "$HOME/.xinitrc" "$session" # -- -logverbose 6
fi

# provides automatic logout; for debugging puroposes:
#export TMOUT=120

