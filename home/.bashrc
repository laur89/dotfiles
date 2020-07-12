#set -x
# ~/.bashrc: executed by bash(1) for non-login shells.
# see /usr/share/doc/bash/examples/startup-files (in the package bash-doc)
# for examples

# If not running interactively, don't do anything
case $- in
    *i*) ;;
      *) return;;
esac

# don't put duplicate lines or lines starting with space in the history.
# See bash(1) for more options
#HISTCONTROL=ignoreboth

# append to the history file, don't overwrite it
shopt -s histappend

# for setting history length see HISTSIZE and HISTFILESIZE in bash(1)
#HISTSIZE=1000
#HISTFILESIZE=2000

# check the window size after each command and, if necessary,
# update the values of LINES and COLUMNS.
shopt -s checkwinsize

# If set, the pattern "**" used in a pathname expansion context will
# match all files and zero or more directories and subdirectories.
#shopt -s globstar

# make less more friendly for non-text input files, see lesspipe(1)
#[ -x /usr/bin/lesspipe ] && eval "$(SHELL=/bin/sh lesspipe)"

# set variable identifying the chroot you work in (used in the prompt below)
if [ -z "${debian_chroot:-}" ] && [ -r /etc/debian_chroot ]; then
    debian_chroot=$(cat /etc/debian_chroot)
fi

# set a fancy prompt (non-color, unless we know we "want" color)
case "$TERM" in
    xterm-color|*-256color) color_prompt=yes;;
esac

# uncomment for a colored prompt, if the terminal has the capability; turned
# off by default to not distract the user: the focus in a terminal window
# should be on the output of commands, not on the prompt
#force_color_prompt=yes

if [ -n "$force_color_prompt" ]; then
    if [ -x /usr/bin/tput ] && tput setaf 1 >&/dev/null; then
    # We have color support; assume it's compliant with Ecma-48
    # (ISO/IEC-6429). (Lack of such support is extremely rare, and such
    # a case would tend to support setf rather than setaf.)
    color_prompt=yes
    else
    color_prompt=
    fi
fi

if [ "$color_prompt" = yes ]; then
    #PS1='${debian_chroot:+($debian_chroot)}\[\033[01;32m\]\u@\h\[\033[00m\]:\[\033[01;34m\]\w\[\033[00m\]\$ '
    # prompt w/o show-vi-prompt:
    #PS1="\[\033[0;37m\]\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[\[\033[0;31m\]\342\234\227\[\033[0;37m\]]\342\224\200\")[$(if [[ ${EUID} == 0 ]]; then echo '\[\033[0;31m\]\h'; else echo '\[\033[0;33m\]\u\[\033[0;37m\]@\[\033[0;96m\]\h'; fi)\[\033[0;37m\]]\342\224\200[\[\033[0;32m\]\w\[\033[0;37m\]]\n\[\033[0;37m\]\342\224\224\342\224\200\342\224\200\342\225\274 \[\033[0m\]"
    # prompt w/ show-vi-prompt:
    PS1="\[\033[0;37m\]\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[\[\033[0;31m\]\342\234\227\[\033[0;37m\]]\342\224\200\")[$(if [[ ${EUID} == 0 ]]; then echo '\[\033[0;31m\]\h'; else echo '\[\033[0;33m\]\u\[\033[0;37m\]@\[\033[0;96m\]\h'; fi)\[\033[0;37m\]]\342\224\200[\[\033[0;32m\]\w\[\033[0;37m\]]\n"
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls and also add handy aliases
if [ -x /usr/bin/dircolors ]; then
    test -r ~/.dircolors && eval "$(dircolors -b ~/.dircolors)" || eval "$(dircolors -b)"
    alias ls='ls --color=auto'
    #alias dir='dir --color=auto'
    #alias vdir='vdir --color=auto'

    #alias grep='grep --color=auto'
    #alias fgrep='fgrep --color=auto'
    #alias egrep='egrep --color=auto'
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

if [ -f ~/.bash_aliases ]; then
    . ~/.bash_aliases
fi

# enable programmable completion features (you don't need to enable
# this, if it's already enabled in /etc/bash.bashrc and /etc/profile
# sources /etc/bash.bashrc).
if ! shopt -oq posix; then
  if [ -f /usr/share/bash-completion/bash_completion ]; then
    . /usr/share/bash-completion/bash_completion
  elif [ -f /etc/bash_completion ]; then
    . /etc/bash_completion
  fi
fi

##############################################
# siit alates kõik enda defineeritud:
##############################################
# good source http://tldp.org/LDP/abs/html/sample-bashrc.html
#
#

##########################################
# shell opts:
#override history size:
export HISTSIZE=  # blank for unlimited
export HISTFILESIZE=  # blank for unlimited

# ignore dups:
#export HISTCONTROL=ignoredups
export HISTCONTROL=ignoreboth
export HISTIGNORE='ls:bg:fg:c:lt:lat:latr:ltr:fhd:fh*:history*'  # ignore commands from history
export HISTTIMEFORMAT='%F %T '

# Change the file location because certain bash sessions truncate .bash_history file upon close.
# http://superuser.com/questions/575479/bash-history-truncated-to-500-lines-on-each-login
export HISTFILE=~/.bash_history_eternal
# Force prompt to write history after every command.
# http://superuser.com/questions/20900/bash-history-loss
export PROMPT_COMMAND="history -a; $PROMPT_COMMAND"

shopt -u mailwarn       # disable mail notification:
shopt -s cdspell        # try to correct typos in path
shopt -s dotglob        # include dotfiles in path expansion
shopt -s hostcomplete   # try to autocomplete hostnames
shopt -s huponexit      # send SIGHUP on when interactive login shell exits
shopt -s globstar       # ** in pathname expansion will match all files and zero or more directories and subdirs
shopt -s autocd         # if you type dir name, it's interpreted as an argument to cd
set -o vi               # needs to be added *before* fzf is sourced, otherwise fzf is screwed:
                        #     https://github.com/junegunn/fzf#key-bindings-for-command-line
stty -ixon              # disable ctrl+s/ctrl+q;

unset MAILCHECK         # avoid delays;
##########################################

# source own functions and env vars:

if [[ "$__ENV_VARS_LOADED_MARKER_VAR" != "loaded" ]]; then
    for i in \
            $HOME/.bash_env_vars \
                ; do  # note the sys-specific env_vars_overrides! also make sure env_vars are fist to be imported;
        if [[ -r "$i" ]]; then
            source "$i"
        #else
            #echo -e "file \"$i\" to be sourced does not exist or is not readable!"
        fi
    done

    if [[ -d "$HOME/.bash_env_vars_overrides" ]]; then
        for i in $HOME/.bash_env_vars_overrides/*; do
            [[ -f "$i" ]] && source "$i"
        done
    fi

    unset i
fi

# this needs to be outside env_vars, unless you're gonna load those every time bashrc is loaded;
case "$TERM" in
    xterm* | rxvt-unicode-256color )
        export TERM=xterm-256color
    ;;
esac

if ! type __BASH_FUNS_LOADED_MARKER > /dev/null 2>&1; then
    [[ -r "$HOME/.bash_functions" ]] && source "$HOME/.bash_functions"

    if [[ -d "$HOME/.bash_funs_overrides" ]]; then
        for i in $HOME/.bash_funs_overrides/*; do
            [[ -f "$i" ]] && source "$i"
        done

        unset i
    fi
fi

# sys-specific aliases:
if [[ -d "$HOME/.bash_aliases_overrides" ]]; then
    for i in $HOME/.bash_aliases_overrides/*; do
        [[ -f "$i" ]] && source "$i"
    done

    unset i
fi

# source homeshick:
[[ -e "$HOME/.homesick/repos/homeshick" ]] && source "$HOME/.homesick/repos/homeshick/homeshick.sh"
[[ -e "$HOME/.homesick/repos/homeshick" ]] && source "$HOME/.homesick/repos/homeshick/completions/homeshick-completion.bash"

# bash-git-prompt conf:
# see provide'ib promptile git repo info; override'ib üleval defineeritud PS1 (põmst sama asjaga kui olen ümber modinud)
# (modi repo asub @ https://github.com/magicmonty/bash-git-prompt)

##########################################
# prompt: ################################
# if using bash-git-prompt; ...
GIT_PROMPT_START="\[\033[0;37m\]\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[\[\033[0;31m\]\342\234\227\[\033[0;37m\]]\342\224\200\")[$(if [[ "${EUID}" -eq 0 ]]; then echo '\[\033[0;31m\]\h'; else echo '\[\033[0;33m\]\u\[\033[0;37m\]@\[\033[0;96m\]\h'; fi)\[\033[0;37m\]]\342\224\200[\[\033[0;32m\]\w\[\033[0;37m\]]"
#GIT_PROMPT_END="\n\[\033[0;37m\]\342\224\224\342\224\200\342\224\200\342\225\274 \[\033[0m\]"
GIT_PROMPT_END='\n'  # used when we're showing vi mode in prompt (expects counterpart/extra config in inputrc)
[[ -e "$HOME/.bash-git-prompt/gitprompt.sh" ]] && source "$HOME/.bash-git-prompt/gitprompt.sh"
# ...and prompt without the bash-git-prompt would be:
#   PS1="\[\033[0;37m\]\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[\[\033[0;31m\]\342\234\227\[\033[0;37m\]]\342\224\200\")[$(if [[ ${EUID} == 0 ]]; then echo '\[\033[0;31m\]\h'; else echo '\[\033[0;33m\]\u\[\033[0;37m\]@\[\033[0;96m\]\h'; fi)\[\033[0;37m\]]\342\224\200[\[\033[0;32m\]\w\[\033[0;37m\]]\n\[\033[0;37m\]\342\224\224\342\224\200\342\224\200\342\225\274 \[\033[0m\]"
#
# ...or powerline:
#pwrLineLoc=/usr/local/lib/python2.7/dist-packages/powerline/bindings/bash/powerline.sh
#if [[ -f "$pwrLineLoc" ]]; then
    #source $pwrLineLoc
#fi


##########################################
#ruby env (rbenv) - enable shims and autocompletion:  (as per `rbenv init` instructions)
command -v rbenv >/dev/null 2>/dev/null && eval "$(rbenv init -)"

# add local ruby gems to path: (https://guides.rubygems.org/faqs/#user-install)
# note this needs to exec after rbenv has set the version!
if command -v ruby >/dev/null && command -v gem >/dev/null; then
    _rb_pth="$(ruby -r rubygems -e 'puts Gem.user_dir')/bin"
    [[ :$PATH: != *:"$_rb_pth":* ]] && export PATH="$_rb_pth:$PATH"
    unset _rb_pth
fi

##########################################
# git-flow-competion:
[[ -e "$HOME/.git-flow-completion" ]] && source "$HOME/.git-flow-completion/git-flow-completion.bash"

##########################################
# maven-bash-completion:
[[ -e "$HOME/.maven-bash-completion/bash_completion.bash" ]] && source "$HOME/.maven-bash-completion/bash_completion.bash"

##########################################
# dynamic colors:
#source "$HOME/.dynamic-colors/completions/dynamic-colors.bash"

##########################################
# base16-shell:  (to run, use  $ base16 (tab completion)  # https://github.com/chriskempson/base16-shell
#BASE16_SHELL=$HOME/.config/base16-shell/
#[ -n "$PS1" ] && [ -s $BASE16_SHELL/profile_helper.sh ] && eval "$($BASE16_SHELL/profile_helper.sh)"

##########################################
if ! ssh-add -l > /dev/null 2>&1; then
    ssh-add
fi
##########################################

# compile .ssh/config
##########################################
__check_for_change_and_compile_ssh_config() {
    local stored_md5sum ssh_config ssh_configdir modified current_md5sum stored_md5sum_exist

    readonly stored_md5sum="$_PERSISTED_TMP/.last_known_sshconfigdir_md5sum"
    readonly ssh_config="$HOME/.ssh/config"
    readonly ssh_configdir="$HOME/.ssh/config.d"  # dir holding the ssh config files that will be
                                                  # merged into a single $ssh_config

    if [[ -d "$ssh_configdir" ]] && ! is_dir_empty "$ssh_configdir"; then
        cd "$ssh_configdir" || return 1  # move to $ssh_configdir, since we execute find relative to curr dir;
        current_md5sum="$(find -L . -type f -exec md5sum -- '{}' \+ | sort -k 34 | md5sum)" || { err 'md5summing configdir failed' "$FUNCNAME"; return 1; }
        test -e "$stored_md5sum"; stored_md5sum_exist=$?

        if [[ "$stored_md5sum_exist" -eq 0 && "$(cat -- "$stored_md5sum")" != "$current_md5sum" ]] \
                || ! [[ -e "$ssh_config" ]]; then
            # cat, not move ssh/config, as it's likely a symlink!
            [[ -f "$ssh_config" ]] && cat -- "$ssh_config" > "${ssh_config}.bak.$(date -Ins)"
            cat -- "$ssh_configdir"/* > "$ssh_config"
            sanitize_ssh "$HOME/.ssh"
            modified=1
        fi

        # avoid pointless $stored_md5sum writing:
        [[ "$modified" -eq 1 || "$stored_md5sum_exist" -ne 0 ]] && echo "$current_md5sum" > "$stored_md5sum"
    fi

    return 0
}

__check_for_change_and_compile_ssh_config &
disown $!
##########################################
# fzf
[ -f ~/.fzf.bash ] && source ~/.fzf.bash

# Replace default shell autocompeltes:  https://github.com/junegunn/fzf#settings
####################
# Use fd (https://github.com/sharkdp/fd) instead of the default find
# command for listing path candidates.
# - The first argument to the function ($1) is the base path to start traversal
# - See the source code (completion.{bash,zsh}) for the details.
_fzf_compgen_path() {
  fd --hidden --follow --exclude '.git' . "$1"
}

# Use fd to generate the list for directory completion
_fzf_compgen_dir() {
  fd --type d --hidden --follow --exclude '.git' . "$1"
}
##########################################
# fasd init caching and loading:  (https://github.com/clvv/fasd)
fasd_cache="$HOME/.fasd-init-bash.cache"
if command -v fasd > /dev/null && [[ "$(command -v fasd)" -nt "$fasd_cache" || ! -s "$fasd_cache" ]]; then
    fasd --init posix-alias bash-hook bash-ccomp bash-ccomp-install >| "$fasd_cache"
fi

[[ -s "$fasd_cache" ]] && source "$fasd_cache"
unset fasd_cache
##########################################
# forgit  (https://github.com/wfxr/forgit)
[[ -s "$HOME/.forgit" ]] && source "$HOME/.forgit"
##########################################
# nvm (node version manager):  (https://github.com/nvm-sh/nvm#git-install)
# note . nvm.sh makes new shell startup slow (https://github.com/nvm-sh/nvm/issues/1277);
# that's why we need to work around this:
#   https://www.reddit.com/r/node/comments/4tg5jg/lazy_load_nvm_for_faster_shell_start/d5ib9fs/
#   https://gist.github.com/fl0w/07ce79bd44788f647deab307c94d6922
export NVM_DIR="$HOME/.nvm"  # do not change location, keep _non-linked_ .nvm/ under ~
#declare -a __NODE_GLOBALS=($(find "$NVM_DIR/versions/node/" -maxdepth 3 -mindepth 3 -type l -wholename '*/bin/*' | xargs -n1 basename | sort | uniq))
mapfile -t __NODE_GLOBALS < <(find "$NVM_DIR/versions/node/"*/bin/ -maxdepth 1 -mindepth 1 -type l -print0 | xargs --null -n1 basename | sort | uniq)
__NODE_GLOBALS+=(node nvm)

# instead of using --no-use flag, load nvm lazily:
_load_nvm() {
    [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
    [ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
}

for cmd in "${__NODE_GLOBALS[@]}"; do
    eval "function ${cmd}(){ unset -f ${__NODE_GLOBALS[*]}; _load_nvm; unset -f _load_nvm; ${cmd} \$@; }"
done
unset cmd __NODE_GLOBALS

#   from https://stackoverflow.com/a/50378304/1803648
# Run 'nvm use' automatically every time there's
# a .nvmrc file in git project root. Also, revert to default
# version when entering a directory without .nvmrc
#
_enter_dir() {
    local d
    d=$(git rev-parse --show-toplevel 2>/dev/null)

    if [[ "$d" == "$PREV_PWD" ]]; then
        return
    elif [[ -n "$d" && -f "$d/.nvmrc" ]]; then
        nvm use
        NVM_DIRTY=1
    elif [[ "$NVM_DIRTY" == 1 ]]; then
        nvm use default
        NVM_DIRTY=0
    fi
    PREV_PWD="$d"
}

[[ -s "$NVM_DIR/nvm.sh" ]] && export PROMPT_COMMAND="$PROMPT_COMMAND;_enter_dir"
##########################################
# generate .Xauth to be passed to (and used by) GUI docker gui containers:
export XAUTH='/tmp/.docker.xauth'
if [[ ! -s "$XAUTH" && -n "$DISPLAY" ]]; then  # TODO: also check for is_x()?
    touch "$XAUTH"
    xauth nlist "$DISPLAY" | sed -e 's/^..../ffff/' | xauth -f "$XAUTH" nmerge -
fi
##########################################
# kubectx and kubens bash completion:
[[ :$PATH: != *:"${BASE_DEPS_LOC}/kubectx":* ]] && export PATH="${BASE_DEPS_LOC}/kubectx:$PATH"
##########################################
# kubernetes/k8s shell prompt: (https://github.com/jonmosco/kube-ps1)
test -f "${BASE_DEPS_LOC}/kube-ps1/kube-ps1.sh" && source "${BASE_DEPS_LOC}/kube-ps1/kube-ps1.sh"
##########################################
# NPM tab-completion; instruction from https://docs.npmjs.com/cli-commands/completion.html
###-begin-npm-completion-###
#
# npm command completion script
#
# Installation: npm completion >> ~/.bashrc  (or ~/.zshrc)
# Or, maybe: npm completion > /usr/local/etc/bash_completion.d/npm
#

if type complete &>/dev/null; then
  _npm_completion () {
    local words cword
    if type _get_comp_words_by_ref &>/dev/null; then
      _get_comp_words_by_ref -n = -n @ -n : -w words -i cword
    else
      cword="$COMP_CWORD"
      words=("${COMP_WORDS[@]}")
    fi

    local si="$IFS"
    IFS=$'\n' COMPREPLY=($(COMP_CWORD="$cword" \
                           COMP_LINE="$COMP_LINE" \
                           COMP_POINT="$COMP_POINT" \
                           npm completion -- "${words[@]}" \
                           2>/dev/null)) || return $?
    IFS="$si"
    if type __ltrim_colon_completions &>/dev/null; then
      __ltrim_colon_completions "${words[cword]}"
    fi
  }
  complete -o default -F _npm_completion npm
elif type compdef &>/dev/null; then
  _npm_completion() {
    local si=$IFS
    compadd -- $(COMP_CWORD=$((CURRENT-1)) \
                 COMP_LINE=$BUFFER \
                 COMP_POINT=0 \
                 npm completion -- "${words[@]}" \
                 2>/dev/null)
    IFS=$si
  }
  compdef _npm_completion npm
elif type compctl &>/dev/null; then
  _npm_completion () {
    local cword line point words si
    read -Ac words
    read -cn cword
    let cword-=1
    read -l line
    read -ln point
    si="$IFS"
    IFS=$'\n' reply=($(COMP_CWORD="$cword" \
                       COMP_LINE="$line" \
                       COMP_POINT="$point" \
                       npm completion -- "${words[@]}" \
                       2>/dev/null)) || return $?
    IFS="$si"
  }
  compctl -K _npm_completion npm
fi
###-end-npm-completion-###
##########################################
# single nvim instance per tmux _window_  (from https://www.reddit.com/r/neovim/comments/aex45u/integrating_nvr_and_tmux_to_use_a_single_tmux_per/)
if [[ -n "$TMUX" ]]; then
    export NVIM_LISTEN_ADDRESS="/tmp/nvim_${USER}"
fi

nvr() {
    if [[ -n "$TMUX" ]]; then
        local pane_id
        pane_id=$(tmux list-panes -F '#{pane_id} #{pane_current_command}' | grep nvim | cut -f1 -d' ' | head -n1)
        if [[ $pane_id ]]; then
            tmux select-pane -t "$pane_id"
        fi
    fi

    command nvr -s "$@"
}
##########################################
# note following is added by script from https://get.sdkman.io/:
#THIS MUST BE AT THE END OF THE FILE FOR SDKMAN TO WORK!!!
export SDKMAN_DIR="$HOME/.sdkman"
if [[ -s "$SDKMAN_DIR/bin/sdkman-init.sh" ]]; then
    source "$SDKMAN_DIR/bin/sdkman-init.sh"
fi

##########################################
