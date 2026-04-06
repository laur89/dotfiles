#!/usr/bin/env bash
#
# common logic to be sourced to both .bashrc & .zshrc
# ###################################################

########################################## nvr
# TODO: instead of any nvr functions here, consider https://github.com/carlocab/tmux-nvr instead
#
# single nvim instance per tmux window OR session  (from https://www.reddit.com/r/neovim/comments/aex45u/integrating_nvr_and_tmux_to_use_a_single_tmux_per/)
#  some ideas also taken from https://github.com/carlocab/tmux-nvr/blob/main/bin/nvr-tmux
# just as a reminder - there might also be (n)vim config that sets $GIT_EDITOR to use nvr
#
# TODO: nvr doesn't start... look here for the socket issue: https://github.com/mhinz/neovim-remote/issues/134
# TODO 2: NVIM_LISTEN_ADDRESS is deprecated in nvim, but still supported by nvr
#
# NOTE: currenlty looks like nvim will complain if NVIM_LISTEN_ADDRESS is
#       defined globally in shell, and not just for nvr that still supports it;
#       see https://github.com/carlocab/tmux-nvr/issues/9
#if [[ -n "$TMUX" ]]; then
    #export NVR_TMUX_BIND_SESSION=1  # if 1, then single nvim per tmux session; otherwise single nvim per tmux window

    ## note NVIM_LISTEN_ADDRESS env var is referenced in vim config, so don't change the value carelessly!
    #NVIM_LISTEN_ADDRESS="/tmp/.nvim_userdef_${USER}_"
    #if [[ "$NVR_TMUX_BIND_SESSION" == 1 ]]; then
        #export NVIM_LISTEN_ADDRESS+="sess_$(tmux display -p '#{session_id}').sock"
    #else
        #export NVIM_LISTEN_ADDRESS+="sess_win_$(tmux display -p '#{session_id}_#{window_id}').sock"
    #fi
#fi

## TODO: we might have to move this into a script on $PATH for git_editor settings to work et al
#nvr() {
    #if [[ -S "$NVIM_LISTEN_ADDRESS" ]]; then
        #if [[ -n "$TMUX" ]]; then
            #local pane_id window_id

            ## Use nvr to get the tmux pane_id
            #pane_id="$(command nvr --remote-expr 'get(environ(), "TMUX_PANE")')"
            ## Activate the pane containing our nvim server
            #command tmux select-pane -t"$pane_id"

            #if [[ "$NVR_TMUX_BIND_SESSION" == 1 ]]; then
                ## Find the window containing $pane_id (this feature requires tmux 3.2+!)
                #window_id="$(command tmux list-panes -s -F '#{window_id}' -f "#{m:$pane_id,#{pane_id}}")"
                ## Activate the window
                #command tmux select-window -t"$window_id"
            #fi
        #fi

        #command nvr -s "$@"
    #else
        #nvim -- "$@"
    #fi
#}
##export -f nvr  # note zsh has no "export -f" equivalent

##### OR instead use logic lifted from https://github.com/carlocab/tmux-nvr/blob/main/tmux-nvr.plugin.zsh (well, close to it anyway):
# note this depends on we using the carlocab/tmux-nvr plugin, as its nvim-listen.sh
# is who originally sets/defines the NVIM_LISTEN_ADDRESS env var.
#
# !! note we place [~/.config/tmux/plugins/tmux-nvr/bin] on our PATH in env vars !!
#if [[ -n "$TMUX" ]]; then
    #eval -- "$(tmux show-environment -s NVIM_LISTEN_ADDRESS 2>/dev/null)"
#else
    #[[ -d /tmp/.nvr ]] || mkdir -p -m 700 "/tmp/.nvr-$USER"  # -m 700 sets permissions so that only you have access to this directory
    #export NVIM_LISTEN_ADDRESS=/tmp/.nvr-$USER/nvimsocket
#fi
########################################## /nvr


GPG_TTY=$(tty)
export GPG_TTY  # to make sure git tag properly launches pinentry; instructed by gpg manual: https://www.gnupg.org/documentation/manuals/gnupg/Invoking-GPG_002dAGENT.html

