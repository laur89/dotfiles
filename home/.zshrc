#!/bin/zsh
# from https://github.com/marlonrichert/zsh-launchpad/blob/main/.config/zsh/.zshrc
#
# notes:
# - good starter when coming from bash: https://www.bash2zsh.com/zsh_refcard/refcard.pdf
# - you should always load the module zsh/complist before autoloading compinit
#   - why tho?
# commands:
#   - zsh -o SOURCE_TRACE -lic ''
#     - print traces of files that get sourced
#
# see also:
# - https://grml.org/zsh/zsh-lovers.html
# - https://github.com/Phantas0s/.dotfiles/blob/master/zsh/zshrc
# - https://github.com/oryband/dotfiles/blob/master/.zshrc
#   - loads of zinit usage/examples
#   - uses loiccoyle/zsh-github-copilot, sgpt (shell-gpt)...
# - https://github.com/zdharma-continuum/zinit-configs
# - https://github.com/scanny/dotfiles/blob/master/link/.zshrc
# - https://github.com/danielnachun/dotfiles/blob/master/dot_zshrc.tmpl
##############################


# Enable additional glob operators. (Globbing = pattern matching)
# https://zsh.sourceforge.io/Doc/Release/Expansion.html#Filename-Generation
setopt EXTENDED_GLOB

# Enable ** and *** as shortcuts for **/* and ***/*, respectively:
# https://zsh.sourceforge.io/Doc/Release/Expansion.html#Recursive-Globbing
setopt GLOB_STAR_SHORT

setopt NUMERIC_GLOB_SORT  # Sort numbers numerically, not lexicographically.
setopt NO_CLOBBER  # Don't let > silently overwrite files. To overwrite, use >! instead.
# setopt HIST_ALLOW_CLOBBER

#setopt HIST_BEEP              # Beep when accessing non-existent history.

setopt INTERACTIVE_COMMENTS  # Treat comments pasted into the command line as comments, not code.
#
# TODO: verify what following 2 opts do:
setopt HASH_LIST_ALL  # Whenever a command completion or spelling correction is attempted, make sure the entire command path is hashed first. This makes the first completion slower but avoids false reports of spelling errors. 
setopt HIST_VERIFY  # Whenever the user enters a line with history expansion, don’t execute the line directly; instead, perform history expansion and reload the line into the editing buffer. 

# Don't treat non-executable files in your $path as commands. This makes sure
# they don't show up as command completions. Settinig this option can impact
# performance on older systems, but should not be a problem on modern ones.
# trial and error needed whether this is beneficial:
#setopt HASH_EXECUTABLES_ONLY


# This lets you change to any dir without having to type `cd`, that is, by just
# typing its name. Be warned, though: This can misfire if there exists an alias,
# function, builtin or command with the same name.
# In general, I would recommend you use only the following without `cd`:
#   ..  to go one dir up
#   ~   to go to your home dir
#   ~-2 to go to the 2nd mostly recently visited dir
#   /   to go to the root dir
setopt AUTO_CD

setopt GLOB_DOTS     # no special treatment for file names with a leading dot
setopt NO_AUTO_MENU  # require an extra TAB press to open the completion menu
setopt RM_STAR_SILENT  # do not query the user before executing ‘rm *’ or ‘rm path/*’
setopt RC_QUOTES  # allow double-single-quote to signify a single quote within singly quoted strings; i.e. allow 'Henry''s Garage' instead of 'Henry'\''s Garage'.
#setopt MAGIC_EQUAL_SUBST  # All unquoted arguments of the form ‘anything=expression’ appearing after the command name have filename expansion (that is, where expression has a leading ‘~’ or ‘=’) performed on expression as if it were a parameter assignment

setopt AUTO_PUSHD           # Push the current directory visited on the stack.
setopt PUSHD_IGNORE_DUPS    # Do not store duplicates in the stack.
setopt PUSHD_SILENT         # Do not print the directory stack after pushd or popd.

# TODO: reconsider whether we want these dirstack aliases:
# dirstack idea from https://thevaluable.dev/zsh-install-configure-mouseless/ :
alias d='dirs -v'  # display the dirs on the stack prefixed w/ a number
for index ({1..9}) alias "$index"="cd +${index}"; unset index  # quick dirstack navigation aliases, i.e. run "number commands" to navigate the stack

################ HISTORY
# := assigns the variable if it's unset or null and then substitutes its value.
# TODO: decide on file location:
HISTFILE=$ZDOTDIR/history
#HISTFILE=${XDG_DATA_HOME:=~/.local/share}/zsh/history
#HISTFILE=~/.zsh_history

SAVEHIST=100000  # zsh saves this many lines from the in-memory history list to the history file upon shell exit

# Max number of history entries to keep in memory.
HISTSIZE=$(( 1.2 * SAVEHIST ))  # Zsh recommended value
#HISTSIZE=10000


setopt HIST_FCNTL_LOCK  # Use modern file-locking mechanisms, for better safety & performance.

setopt HIST_IGNORE_ALL_DUPS  # Delete an old recorded event if a new event is a duplicate.
setopt HIST_IGNORE_DUPS          # Do not record an event that was just recorded again.
setopt HIST_IGNORE_SPACE         # Do not record an event starting with a space.
setopt HIST_SAVE_NO_DUPS         # Do not write a duplicate event to the history file.
setopt HIST_REDUCE_BLANKS        # strip superfluous blanks
setopt SHARE_HISTORY             # Share history between all sessions.
setopt INC_APPEND_HISTORY  # history file is updated immediately after a command is entered
# TODO: isn't there overlap between APPENDHISTORY & INC_APPEND_HISTORY?:
setopt APPENDHISTORY  # ensures that each command entered in the current session is appended to the history file immediately after execution

setopt EXTENDED_HISTORY  # records the time when each command was executed along with the command itself
setopt HIST_EXPIRE_DUPS_FIRST    # Expire a duplicate event first when trimming history.
setopt HIST_FIND_NO_DUPS         # Do not display a previously found event.

#HISTTIMEFORMAT="%d/%m/%Y %H:%M] "  # TODO review - isn't this bash option??
################ /HISTORY

### PLUGINS
# TODO: as alternative to zinit, consider zim: https://github.com/zimfw/zimfw
### Added by Zinit's installer (slightly modified by us)  # https://github.com/zdharma-continuum/zinit#manual
#if [[ ! -f $BASE_PROGS_DIR/zinit/zinit.zsh ]]; then
    #print -P "%F{33} %F{220}Installing %F{33}ZDHARMA-CONTINUUM%F{220} Initiative Plugin Manager (%F{33}zdharma-continuum/zinit%F{220})…%f"
    #command mkdir -p "$HOME/.local/share/zinit" && command chmod g-rwX "$BASE_PROGS_DIR/zinit"
    #command git clone https://github.com/zdharma-continuum/zinit "$BASE_PROGS_DIR/zinit" && \
        #print -P "%F{33} %F{34}Installation successful.%f%b" || \
        #print -P "%F{160} The clone has failed.%f%b"
#fi
ZINIT_HOME="$BASE_PROGS_DIR/zinit"
if [[ -f "${ZINIT_HOME}/zinit.zsh" ]]; then
source "${ZINIT_HOME}/zinit.zsh"
# note the following 2 lines are needed if sourcing zinit.zsh _after_ compinit, see https://github.com/zdharma-continuum/zinit#manual :
#autoload -Uz _zinit
#(( ${+_comps} )) && _comps[zinit]=_zinit

# Load a few important annexes (specialized Zinit extensions), without Turbo
# (this is currently required for annexes)
zinit light-mode for \
    zdharma-continuum/zinit-annex-as-monitor \
    zdharma-continuum/zinit-annex-bin-gem-node \
    zdharma-continuum/zinit-annex-patch-dl \
    zdharma-continuum/zinit-annex-rust

### /End of Zinit's installer chunk


### fzf-driven history select   # https://github.com/joshskidmore/zsh-fzf-history-search#zinit
zinit ice lucid wait'0'
zinit light joshskidmore/zsh-fzf-history-search

#ZSH_FZF_HISTORY_SEARCH_BIND='^r'
ZSH_FZF_HISTORY_SEARCH_END_OF_LINE=''  # place cursor end of line after completion; empty=false
### /fzf-hist

# other plugins:
zinit ice depth=1; zinit light jeffreytse/zsh-vi-mode

# TODO: think we should install bd as shell-agnostic and also use in bash?:
zinit ice pick"bd.zsh"; zinit light Tarrasch/zsh-bd

zinit light paulirish/git-open
zinit light djui/alias-tips

# prompt {{{
# starship:
#zinit ice from"gh-r" as"program" bpick"*x86_64-unknown-linux-gnu*" pick"starship"; zinit light starship/starship
#eval "$(starship init zsh)"
# ...or p10k:  # https://github.com/romkatv/powerlevel10k#zinit
zinit ice depth=1; zinit light romkatv/powerlevel10k
# }}}


if [[ -x /usr/bin/dircolors ]]; then
    if [[ -f "$BASE_PROGS_DIR/LS_COLORS/lscolors.sh" ]]; then
        source "$BASE_PROGS_DIR/LS_COLORS/lscolors.sh"
    else
        [[ -r "$HOME/.dircolors" ]] && eval "$(dircolors -b "$HOME/.dircolors")" || eval "$(dircolors -b)"
    fi
fi
# /other plugins:


# prezto {{{
# Set case-sensitivity for completion, history lookup, etc:
zstyle ':prezto:*:*' case-sensitive 'no'
# Color output (auto set to 'no' on dumb terminals):
zstyle ':prezto:*:*' color 'yes'

# common helper funcionts used by other modules:
zinit snippet PZTM::helper  # https://github.com/sorin-ionescu/prezto/tree/master/modules/helper

# general shell options and defines environment variables; note it also enables url-quote-magic
# that romkatv recommends not to: https://www.reddit.com/r/zsh/comments/dybjfe/using_urlquotemagic/f81bxys/
# also collides/sets some opts we set here, but overall it's a good addition so keeping it:
zinit snippet PZTM::environment  # https://github.com/sorin-ionescu/prezto/tree/master/modules/environment

# sets term window & tab titles:
zinit snippet PZTM::terminal  # https://github.com/sorin-ionescu/prezto/tree/master/modules/terminal

# editor module changes a lot; makes sense if we don't use a stand-alone vi/emacs
# mode plugin IMHO; it does provide other stuff tho, e.g. dot expansion (.... -> ../..)
zinit snippet PZTM::editor  # https://github.com/sorin-ionescu/prezto/tree/master/modules/editor

#zinit ice svn silent; zinit snippet PZT::modules/gpg  # https://github.com/sorin-ionescu/prezto/tree/master/modules/gpg

# defines general aliases & functions;
# this module needs to be loaded _before_ the PZTM::completion module
#zinit ice svn silent pick"init.zsh" lucid; zinit snippet PZT::modules/utility  # https://github.com/sorin-ionescu/prezto/tree/master/modules/utility
# }}}


fi  # /does-zinit.zsh-exist?
### /PLUGINS


### KEYBINDS
unsetopt FLOW_CONTROL  # Enable the use of Ctrl-Q and Ctrl-S for keyboard shortcuts.
# note https://github.com/sorin-ionescu/prezto/blob/master/modules/environment/init.zsh does this as follows, what's the difference?:
# [[ -r ${TTY:-} && -w ${TTY:-} && $+commands[stty] == 1 ]] && stty -ixon <$TTY >$TTY

# Alt-Q
# - On the main prompt: Push aside your current command line, so you can type a
#   new one. The old command line is re-inserted when you press Alt-G or
#   automatically on the next command line.
# - On the continuation prompt: Move all entered lines to the main prompt, so
#   you can edit the previous lines.
bindkey '^[q' push-line-or-edit

# enable vi mode; keep at the bottom(ish) to make sure no plugin overwrites it
# related plugins:
# - https://github.com/jeffreytse/zsh-vi-mode
# - https://github.com/softmoth/zsh-vim-mode
#bindkey -v  # commented out as we're trying out jeffreytse/zsh-vi-mode plugin
#export KEYTIMEOUT=1  # makes the switch between cmd<->ins modes quicker

# map 'v' to edit our current command line in $EDITOR:
#autoload -Uz edit-command-line
#zle -N edit-command-line
#bindkey -M vicmd v edit-command-line
### /KEYBINDS


### COMMANDS



# zmv lets you batch rename (or copy or link) files by using pattern matching.
# https://zsh.sourceforge.io/Doc/Release/User-Contributions.html#index-zmv
autoload -Uz -- zmv
alias zmv='zmv -Mv'
alias zcp='zmv -Cv'
alias zln='zmv -Lv'


# Associate file name .extensions with programs to open them.
# This lets you open a file just by typing its name and pressing enter.
# Note that the dot is implicit; `gz` below stands for files ending in .gz
alias -s {css,gradle,html,js,json,md,patch,properties,txt,xml,yml}=$PAGER
alias -s gz='gzip -l'
alias -s {log,out}='tail -F'


READNULLCMD=$PAGER  # Use `< file` to quickly view the contents of any text file
### /COMMANDS

########################################## mise
if command -v mise >/dev/null 2>/dev/null; then
    eval -- "$(mise activate zsh)"  # https://mise.jdx.dev/installing-mise.html#zsh
fi
########################################## /mise

#
#
# think it's best to load compinit last, but unsure why
autoload -Uz compinit; compinit
zinit cdreplay -q  # needs to be after compinit call; see https://github.com/zdharma-continuum/zinit#calling-compinit-without-turbo-mode

########################################## zoxide
# needs to be at the end of file, as it must be _after_ compinit is called.
# zoxide settings:  (https://github.com/ajeetdsouza/zoxide)
#export _ZO_DATA_DIR="$BASE_DATA_DIR/.zoxide"
export _ZO_RESOLVE_SYMLINKS=1
command -v zoxide > /dev/null && eval -- "$(zoxide init zsh)"
# alternatively, source it via zinit:
#zinit ice has'zoxide'; zinit light ajeetdsouza/zoxide
########################################## /zoxide


# other examples to consider:
# Define functions and completions.
#function md() { [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1" }
#compdef _directories md
#
#
#------ TODO: think debian default config gave also these:


zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
eval "$(dircolors -b)"
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' list-colors ''
zstyle ':completion:*' list-prompt %SAt %p: Hit TAB for more, or the character to insert%s
zstyle ':completion:*' matcher-list '' 'm:{a-z}={A-Z}' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' menu select=long
zstyle ':completion:*' select-prompt %SScrolling active: current selection at %p%s
zstyle ':completion:*' use-compctl false
zstyle ':completion:*' verbose true

zstyle ':completion:*:*:kill:*:processes' list-colors '=(#b) #([0-9]#)*=0=01;31'
zstyle ':completion:*:kill:*' command 'ps -u $USER -o pid,%cpu,tty,cputime,cmd'
