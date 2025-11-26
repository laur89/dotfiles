# ~/.profile: executed by the command interpreter for login shells.
# This file is not read by bash(1), if ~/.bash_profile or ~/.bash_login
# exists.
# see /usr/share/doc/bash/examples/startup-files for examples.
# the files are located in the bash-doc package.

# the default umask is set in /etc/profile; for setting the umask
# for ssh logins, install and configure the libpam-umask package.
#umask 0077  # keep this in sync with what we set via systemd & install_system bootstrap!

# if running bash
#if [ -n "$BASH_VERSION" ]; then
    ## include .bashrc if it exists
    #if [ -f "$HOME/.bashrc" ]; then
        #source "$HOME/.bashrc"
    #fi

    ## show avail vars via   $ systemctl --user show-environment
#fi

# set PATH so it includes user's private bin if it exists
# currently done from bashrc
#if [ -d "$HOME/bin" ] ; then
    #PATH="$HOME/bin:$PATH"
#fi

##############################################
# siit alates kõik enda defineeritud:
##############################################

# source own functions and env vars:

if [[ "$__ENV_VARS_LOADED_MARKER_VAR" != 'loaded' ]]; then
    for i in \
            "$HOME/.bash_env_vars" \
                ; do  # note the sys-specific env_vars_overrides! also make sure env_vars are fist to be imported;
        if [[ -r "$i" ]]; then
            source "$i"
        #else
            #echo -e "file [$i] to be sourced does not exist or is not readable!"
        fi
    done
fi

# this needs to be outside env_vars, unless you're gonna load those every time bashrc is loaded;
case "$TERM" in
    xterm* | rxvt-unicode-256color) export TERM=xterm-256color ;;
esac

select_wm() {
    echo '============'
    read -r -t 10 -p 'Enter DE/WM: ' __xsession_
    if [ $? -gt 128 ]; then __xsession_=i3; fi  # read timed out, default to something
}

# start X; note the ssh-agent:
# https://wiki.archlinux.org/title/Xinit#Autostart_X_at_login
#   - per this article, we could check here as if [ -z "$DISPLAY" ] && [ "$XDG_VTNR" -le 3 ]  to use graphical logins on more than one virtual terminal
#   - XDG_VTNR is alternative to $(tty) usage
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

