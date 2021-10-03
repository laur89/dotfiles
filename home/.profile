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

    # likely bashrc updated our env vars, make them visible to systemd
    # user services: (https://wiki.archlinux.org/index.php/systemd/User#Environment_variables)
    systemctl --user import-environment
    # show avail vars via   $ systemctl --user show-environment
fi


# note we also have some init in .bashrc
if command -v pyenv >/dev/null 2>/dev/null; then
    eval "$(pyenv init --path)"
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
if [ -z "$DISPLAY" ] && [ "$(tty)" == '/dev/tty1' ]; then
    echo '============'
    read -r -t 10 -p 'Enter DE/WM: ' __xsession_
    if [ $? -gt 128 ]; then __xsession_=i3; fi  # read timed out, default to something

    if is_windows; then
        # we're not starting any servers, so need to define DISPLAY to connect to:
        export DISPLAY=:0.0
        #export LIBGL_ALWAYS_INDIRECT=1  # for WSL

        #ssh-agent "$HOME/.xinitrc" "$__xsession_"
        exec "$HOME/.xinitrc" "$__xsession_"
    else
        # note ssh-agent ver should be used when we _don't_ use gnome-keyring (or equivalent):
        #exec ssh-agent startx "$HOME/.xinitrc" "$__xsession_" # -- -logverbose 6
        exec startx "$HOME/.xinitrc" "$__xsession_" # -- -logverbose 6
    fi

    unset __xsession_
fi

# provides automatic logout; for debugging puroposes:
#export TMOUT=120

