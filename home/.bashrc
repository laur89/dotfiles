#set -x
# see also: https://github.com/mrzool/bash-sensible
#
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
    #PS1="\[\033[0;37m\]\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[\[\033[0;31m\]\342\234\227\[\033[0;37m\]]\342\224\200\")[$(if [[ ${EUID} == 0 ]]; then echo '\[\033[0;31m\]\h'; else echo '\[\033[0;33m\]\u\[\033[0;37m\]@\[\033[0;96m\]\h'; fi)\[\033[0;37m\]]\342\224\200[\[\033[0;32m\]\w\[\033[0;37m\]]\$(__py_virtualenv_ps1)\$(kube_ps1)\n\[\033[0;37m\]\342\224\224\342\224\200\342\224\200\342\225\274 \[\033[0m\]"
    # prompt w/ show-vi-prompt:
    PS1="\[\033[0;37m\]\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[\[\033[0;31m\]\342\234\227\[\033[0;37m\]]\342\224\200\")[$(if [[ ${EUID} == 0 ]]; then echo '\[\033[0;31m\]\h'; else echo '\[\033[0;33m\]\u\[\033[0;37m\]@\[\033[0;96m\]\h'; fi)\[\033[0;37m\]]\342\224\200[\[\033[0;32m\]\w\[\033[0;37m\]]\$(__py_virtualenv_ps1)\$(kube_ps1)\n"
else
    PS1='${debian_chroot:+($debian_chroot)}\u@\h:\w\$ '
fi
unset color_prompt force_color_prompt

export PROMPT_SEGMENT_PREFIX=$'\342\224\200['  # TODO: standardize and use everywhere; note no need to provide color here, can use the default set by prompt
export PROMPT_SEGMENT_SUFFIX=$'\033[0;37m]'    # TODO: standardize and use everywhere


# If this is an xterm set the title to user@host:dir
case "$TERM" in
xterm*|rxvt*)
    PS1="\[\e]0;${debian_chroot:+($debian_chroot)}\u@\h: \w\a\]$PS1"
    ;;
*)
    ;;
esac

# enable color support of ls
if [[ -x /usr/bin/dircolors ]]; then
    if [[ -f "$BASE_PROGS_DIR/LS_COLORS/lscolors.sh" ]]; then
        source "$BASE_PROGS_DIR/LS_COLORS/lscolors.sh"
    else
        [[ -r "$HOME/.dir_colors" ]] && eval "$(dircolors -b "$HOME/.dir_colors")" || eval "$(dircolors -b)"
    fi
fi

# colored GCC warnings and errors
export GCC_COLORS='error=01;31:warning=01;35:note=01;36:caret=01;32:locus=01:quote=01'

# Alias definitions.
# You may want to put all your additions into a separate file like
# ~/.bash_aliases, instead of adding them here directly.
# See /usr/share/doc/bash-doc/examples in the bash-doc package.

[[ ! -f ~/.bash_aliases ]] || source ~/.bash_aliases

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
#umask 0077  # rw by owner alone -- should be set via systemd conf (or perhaps ~/.profile) instead!

##########################################
# shell opts:
#override history size:
#export HISTSIZE=  # blank for unlimited
#export HISTFILESIZE=  # blank for unlimited
export HISTSIZE=10000  # don't go -1 here: processing massive histfiles can be slow af
export HISTFILESIZE=50000

# ignore dups:
#export HISTCONTROL=ignoredups
export HISTCONTROL=ignoreboth:erasedups
export HISTIGNORE='?:??:fhd:history:lat:ltr:latr:;*'  # ignore commands from history
export HISTTIMEFORMAT='%F %T '

# ---------------------------------------
# nuke non-consecutive dupes:
# from https://debian-administration.org/article/543/Bash_eternal_history#comment_19
# WIP
# TODO: what if HISTTIMEFORMAT is set, making hist entries 2 lines long?
# TODO: dedup should perhaps be called w/ nice of 19? - yup, better convert to script & run via cron instead from .bashrc
_dedup() {
    local temp
    temp="/tmp/.${RANDOM}-bash-hist-dupd"

    [[ -f "$1" ]] || return;
    #awk ' !x[$0]++' "$1" > "$temp" || return 1               # keeps first repeated value
    tac "$1" | awk '!x[$0]++' | tac > "$temp" || return 1     # keep the last repeated value
    mv -- "$temp" "$1"
    # -----------------------
    # OR:

    local ptrns reversed
    ptrns="/tmp/.${RANDOM}-bash-hist-grep-ptrns"
    reversed="/tmp/.${RANDOM}-bash-hist-reversed"
    # cleanup to follow if histfile entry is on 2 lines (one being timestamp):
    #awk '!x[$0]++' "$1" | grep -Ev '^#[0-9]{10}$' > "$ptrns" || return 1
    #grep -Ev '^#[0-9]{10}$' "$1" | sort -u > "$ptrns" || return 1  # order of patterns does not matter right?
    #grep -Ev '^#[0-9]{10}$' "$1" | awk '!x[$0]++' > "$ptrns" || return 1  # uniqueing w/ preserving the order

    #tac "$1" | grep -f "$ptrns" --fixed-strings --line-regexp --max-count=1 -A 1 | tac > "$temp" || return 1
    tac -- "$1" > "$reversed"
    grep -Ev '^#[0-9]{10}$' "$reversed" | awk '!x[$0]++' > "$ptrns" || return 1  # uniqueing w/ preserving the order; note we grep -v the timestamp-lines of hist entries
    cat -- "$ptrns" | xargs -n1 -I '{}' -- grep -e '{}' --fixed-strings --line-regexp --max-count=1 -A 1 -- "$reversed" | tac > "$temp" || return 1
    mv -- "$temp" "$1"
    rm -- "$ptrns" "$reversed"

    #----
    # dedup ~/.bash_history_eternal: (keepin the last entry in case of dupes)
    # note we sort from 7th field (includes the cat-prepended index)
    cat -n -- "$1" | sort -rk7 | sort -uk7 | sort -nk1 | cut -f2- > "$temp" || return 1
    #cat -n -- "$1" | sort -rk7 | sort -uk7 | sort -nk1 | awk '{for(i=2; i<=NF; ++i) printf "%s ", $i; print ""}' > "$temp" || return 1
    mv -- "$temp" "$1"
}

#echo "Remove duplicate entries in $HISTFILE"
#wc -l "$HISTFILE"
#_dedup "$HISTFILE"
#wc -l "$HISTFILE"
# ---------------------------------------

# Change the file location because certain bash sessions truncate .bash_history file upon close.
# http://superuser.com/questions/575479/bash-history-truncated-to-500-lines-on-each-login
export HISTFILE=~/.bash_hist
# Force prompt to write history after every command.
# http://superuser.com/questions/20900/bash-history-loss
# see also this comment: https://unix.stackexchange.com/a/419779/47501
#
#export PROMPT_COMMAND="history -a; history -c; history -r; $PROMPT_COMMAND"  <-- immediately propagate to all open shells; fyi makes every command slow if our histfile is massive!
# note the eternal history bit is from https://debian-administration.org/article/543/Bash_eternal_history
#  (link dead, see archive @ http://web.archive.org/web/20200925232709/https://debian-administration.org/article/543/Bash_eternal_history)
[[ ";${PROMPT_COMMAND};" != *';history -a;'* ]] && export PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}"'history -a;echo $USER "$(history 1)" >> ~/.bash_history_eternal'

shopt -u mailwarn       # disable mail notification:
shopt -s cdspell        # try to correct typos in path
shopt -s extglob        # enable extended pattern matching features
shopt -s dotglob        # include dotfiles in path expansion
shopt -s nullglob       # unmatching globs to expand into empty string/list instead of being left unexpanded
shopt -s hostcomplete   # try to autocomplete hostnames
shopt -s huponexit      # send SIGHUP on when interactive login shell exits
shopt -s globstar       # ** in pathname expansion will match all files and zero or more directories and subdirs
shopt -s autocd         # if you type dir name, it's interpreted as an argument to cd
shopt -s cmdhist        # bash attempts to save all lines of a multi-line command in same history entry;
shopt -s lithist        # if cmdhist is enabled, then multiline commands are saved in history with embedded newlines rather than using semicolon separators;
set -o vi               # needs to be added *before* fzf is sourced, otherwise fzf is screwed:
                        #     https://github.com/junegunn/fzf#key-bindings-for-command-line
stty -ixon              # disable ctrl+s/ctrl+q;
set -o pipefail
set -o noclobber        # do not allow overwriting existing files w/ > redirection; use >| to explicitly overwrite

unset MAILCHECK         # avoid delays;
##########################################
if ! type __BASH_FUNS_LOADED_MARKER > /dev/null 2>&1; then
    [[ ! -f "$HOME/.bash_functions" ]] || source "$HOME/.bash_functions"

    if [[ -d "$HOME/.bash_funs_overrides" ]]; then
        for i in "$HOME/.bash_funs_overrides/"*; do
            [[ ! -f "$i" ]] || source "$i"
        done
    fi
fi

# sys-specific aliases:
if [[ -d "$HOME/.bash_aliases_overrides" ]]; then
    for i in "$HOME/.bash_aliases_overrides/"*; do
        [[ ! -f "$i" ]] || source "$i"
    done
fi

# source homeshick:
i="$HOME/.homesick/repos/homeshick"
if [[ -e "$i" ]]; then
    source "$i/homeshick.sh"
    source "$i/completions/homeshick-completion.bash"
fi

# bash-git-prompt conf:
# see provide'ib promptile git repo info; override'ib üleval defineeritud PS1 (põmst sama asjaga kui olen ümber modinud)
# (modi repo asub @ https://github.com/magicmonty/bash-git-prompt)
#
# alternatively consider https://github.com/starship/starship

########################################## bash-prompt
# if using bash-git-prompt; ...

i="$BASE_PROGS_DIR/bash-git-prompt/gitprompt.sh"
if [[ -f "$i" ]]; then
    # add lazy-loaded/dynamic extra content to git-prompt, eg kube-ps1:
    # !! note this guy's only called/shown when we're in git repo, unless GIT_PROMPT_ONLY_IN_REPO=0 !!
    #prompt_callback() {  # function called by bash-git-prompt for additional dynamic content
    #    echo -n " $(kube_ps1)"
    #}

    [[ "$PS1" != *'\n' ]] && GIT_PROMPT_START="$PS1" || GIT_PROMPT_START="${PS1:0:$(( ${#PS1} - 2 ))}"   # note we strip the trailing newline
    #GIT_PROMPT_END="\n\[\033[0;37m\]\342\224\224\342\224\200\342\224\200\342\225\274 \[\033[0m\]"  # this would be used if we didn't show vi mode in inputrc
    GIT_PROMPT_END='\n'  # used when we're showing vi mode in prompt (expects counterpart/extra config in inputrc)
    GIT_PROMPT_ONLY_IN_REPO=1  # show prompt only if in git repo; if !=1, then eg prompt_callback() gets called&shown everywhere, not only in repos
    #GIT_PROMPT_THEME=Solarized  # list all w/  $ git_prompt_list_themes
    source "$i"
fi

# ...and prompt without the bash-git-prompt would be:
#   PS1="\[\033[0;37m\]\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[\[\033[0;31m\]\342\234\227\[\033[0;37m\]]\342\224\200\")[$(if [[ ${EUID} == 0 ]]; then echo '\[\033[0;31m\]\h'; else echo '\[\033[0;33m\]\u\[\033[0;37m\]@\[\033[0;96m\]\h'; fi)\[\033[0;37m\]]\342\224\200[\[\033[0;32m\]\w\[\033[0;37m\]]\n\[\033[0;37m\]\342\224\224\342\224\200\342\224\200\342\225\274 \[\033[0m\]"
#
# ...or powerline:
#pwrLineLoc=/usr/local/lib/python2.7/dist-packages/powerline/bindings/bash/powerline.sh
#if [[ -f "$pwrLineLoc" ]]; then
    #source $pwrLineLoc
#fi

########################################## /bash-prompt
#ruby env (rbenv) - enable shims and autocompletion:  (as per `rbenv init` instructions)
#command -v rbenv >/dev/null 2>/dev/null && eval "$(rbenv init -)"

# add local ruby gems to path: # https://guides.rubygems.org/faqs/#i-installed-gems-with---user-install-and-their-commands-are-not-available
# note this needs to exec after rbenv (or other shim-based ver manager) has set the version, assuming we use shim-based solution
if command -v ruby >/dev/null && command -v gem >/dev/null; then
    i="$(ruby -r rubygems -e 'puts Gem.user_dir')/bin"
    [[ "$i" != /bin && -d "$i" && :$PATH: != *:"$i":* ]] && export PATH="$i:$PATH"
fi

##########################################
# gradle bash completion: (see https://github.com/gradle/gradle-completion/blob/master/README.md#installation-for-bash-32)
# to allow completion of implicit tasks:
#export GRADLE_COMPLETION_UNQUALIFIED_TASKS="true"

##########################################
# dynamic colors:
#source "$HOME/.dynamic-colors/completions/dynamic-colors.bash"

##########################################
# base16-shell:  (to run, use  $ base16 (tab completion)  # https://github.com/chriskempson/base16-shell
#BASE16_SHELL=$HOME/.config/base16-shell/
#[ -n "$PS1" ] && [ -s $BASE16_SHELL/profile_helper.sh ] && eval "$($BASE16_SHELL/profile_helper.sh)"

##########################################
# this business shouldn't be needed if gnome-keyring is functioning a-ok:
#if ! ssh-add -l > /dev/null 2>&1; then
    #ssh-add
#fi
##########################################
# https://github.com/junegunn/fzf#setting-up-shell-integration
command -v fzf > /dev/null && eval -- "$(fzf --bash)"

# Replace default shell autocomplete:  https://github.com/junegunn/fzf#customizing-completion-source-for-paths-and-directories
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

####################
# set additional commands for fzf-completion:
# note it _might_ conflict w/ fzf-tab-completion (from another project) if used;
#_fzf_setup_completion path ag rg git kubectl

# TODO: see also about setting _fzf_comprun()?
########################################## forgit  # https://github.com/wfxr/forgit
i="$BASE_PROGS_DIR/forgit/forgit.plugin.sh"
[[ ! -f "$i" ]] || source "$i"
########################################## mise  # https://mise.jdx.dev/installing-mise.html#bash
command -v mise &>/dev/null && eval -- "$(mise activate bash)"
########################################## /mise

# some nvim plugins require node to be on PATH; configure a constant link so plugins et al can be pointed at it;
# idea is to have access to node executable prior to loading anything from asdf.
#
# note we have equivalent logic in install_system.sh as well!
# not needed when using mise, as it provides a constant tool shim location for us to use.
#
# eg some nvim plugin(s) might reference $NODE_LOC
#if [[ -d "$ASDF_DATA_DIR/installs/nodejs" ]]; then
#    _latest_node_ver="$(find "$ASDF_DATA_DIR/installs/nodejs/" -maxdepth 1 -mindepth 1 -type d | sort -n | tail -n 1)/bin/node"
#    if [[ ! -f "$NODE_LOC" ]] || [[ "$(realpath -- "$NODE_LOC")" != "$_latest_node_ver" ]]; then
#        [[ -x "$_latest_node_ver" ]] && ln -sf -- "$_latest_node_ver" "$NODE_LOC"
#    fi
#    unset _latest_node_ver
#fi
########################################## /mise
# kubernetes/k8s shell prompt: (https://github.com/jonmosco/kube-ps1)
KUBE_PS1_PREFIX="$PROMPT_SEGMENT_PREFIX"
KUBE_PS1_SUFFIX="$PROMPT_SEGMENT_SUFFIX"
KUBE_PS1_SYMBOL_USE_IMG=true
KUBE_PS1_SYMBOL_PADDING=false
#KUBE_PS1_SYMBOL_DEFAULT=$'\u2388'
i="$BASE_PROGS_DIR/kube-ps1/kube-ps1.sh"
[[ -f "$i" ]] && source "$i" && kubeoff  # note we default to kubeoff; for better automatic prompt filtering check out this issue/comment: https://github.com/jonmosco/kube-ps1/issues/115#issuecomment-724971405
##########################################
# customize python virtualenv prompt
export VIRTUAL_ENV_DISABLE_PROMPT=1  # disable the default virtualenv prompt change (as it doesn't play nice w/ multiline prompts)
__py_virtualenv_ps1() {  # called by PS1
    echo -n "${VIRTUAL_ENV:+${PROMPT_SEGMENT_PREFIX}${COLORS[BOLD]}venv:${COLORS[CYAN]}${VIRTUAL_ENV##*/}${PROMPT_SEGMENT_SUFFIX}}"
}
########################################## fzf-tab-completion
# replace default bash tab completion menu w/ fzf: (https://github.com/lincheney/fzf-tab-completion)
# note: commented out (at least) 'til these are solved:
#   https://github.com/lincheney/fzf-tab-completion/issues/17
#   https://github.com/lincheney/fzf-tab-completion/issues/15
#ftc="$BASE_PROGS_DIR/fzf-tab-completion/bash/fzf-bash-completion.sh"
#if [[ -f "$ftc" ]]; then
    #source "$ftc"
    #bind -x '"\t": fzf_bash_completion'
#fi
#unset ftc
########################################## zoxide (needs to be at the end of bashrc)
#export _ZO_DATA_DIR="$BASE_DATA_DIR/.zoxide"
export _ZO_RESOLVE_SYMLINKS=1
command -v zoxide > /dev/null && eval -- "$(zoxide init bash)"
########################################## /zoxide

########################################## memy  # https://github.com/andrewferrier/memy
command -v memy &> /dev/null && source <(memy hook bash)
########################################## /memy

########################################## ai
# aichat; see https://github.com/sigoden/aichat/blob/main/scripts/shell-integration/integration.bash
i="$BASE_PROGS_DIR/aichat-shell-scripts/shell-integration/integration.bash"
command -v aichat > /dev/null && [[ -f "$i" ]] && source "$i"
########################################## /ai

# needs to be at the end:  https://github.com/rcaloras/bash-preexec
i="$BASE_PROGS_DIR/bash-preexec/bash-preexec.sh"
[[ ! -f "$i" ]] || source "$i"

### from here on, only bash-preexec dependents should be sourced:

# fancy-ctrl-z:
# depends on bash-preexec
# NOTE! it messes up fzf's alt+c binding!
i="$BASE_DATA_DIR/dev/scripts/bash-fancy-ctrl-z"
[[ ! -f "$i" ]] || source "$i"

# atuin: (you can see automated setup logic @ https://setup.atuin.sh/)
# depends on bash-preexec
#
# Note:
# - binds ctrl+r and others
# - as per automated setup logic, atuin is sourced _after_ bash-preexec
command -v atuin > /dev/null && eval -- "$(atuin init bash --disable-up-arrow)"

i="$XDG_CONFIG_HOME/shell/extra_bashrc.sh"
[[ ! -f "$i" ]] || source "$i"
i="$XDG_CONFIG_HOME/shell/common_shell.sh"
[[ ! -f "$i" ]] || source "$i"

unset i
