# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
umask 0077  # keep this in sync with what we set via systemd!

# if running bash
if [ -n "$BASH_VERSION" ]; then
    # include .bashrc if it exists
    if [ -f "$HOME/.bashrc" ]; then
        source "$HOME/.bashrc"
    fi

    # show avail vars via   $ systemctl --user show-environment
fi

# set PATH so it includes user's private bin if it exists
# currently done from bashrc
#if [ -d "$HOME/bin" ] ; then
    #PATH="$HOME/bin:$PATH"
#fi

##############################################
# siit alates kõik enda defineeritud:
##############################################
select_wm() {
    echo '============'
    read -r -t 10 -p 'Enter DE/WM: ' __xsession_
    if [ $? -gt 128 ]; then __xsession_=i3; fi  # read timed out, default to something
}

# start X; note the ssh-agent:
#if [ -z "$DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" -eq 1 ]; then
if [ -z "$DISPLAY" ] && [ "$(tty)" == '/dev/tty1' ]; then
    if is_windows; then
        # we're not starting any servers, so need to define DISPLAY to connect to:
        export DISPLAY=:0.0
        #export LIBGL_ALWAYS_INDIRECT=1  # for WSL

        select_wm
        #ssh-agent "$HOME/.xinitrc" "$__xsession_"
        exec "$HOME/.xinitrc" "$__xsession_"
    else
        # note ssh-agent ver should be used when we _don't_ use gnome-keyring (or equivalent):
        #exec ssh-agent startx "$HOME/.xinitrc" "$__xsession_" # -- -logverbose 6

        # TODO: this is our xinitrc version, not using systemd nor ~/.xsession:
        #select_wm
        #exec startx "$HOME/.xinitrc" "$__xsession_" # -- -logverbose 6

        exec startx
    fi

    unset __xsession_
fi

# provides automatic logout; for debugging puroposes:
#export TMOUT=120

