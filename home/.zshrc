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
# - https://github.com/crivotz/dot_files/blob/master/linux/zinit/zshrc
# - https://github.com/zdharma-continuum/zinit-configs
# - https://github.com/scanny/dotfiles/blob/master/link/.zshrc
# - https://github.com/danielnachun/dotfiles/blob/master/dot_zshrc.tmpl
# - https://github.com/sainnhe/dotfiles/blob/master/.zshrc
# - https://github.com/kdheepak/dotfiles/blob/main/zshrc
# - as alternative to zinit, consider zim: https://github.com/zimfw/zimfw
##############################

#zmodload zsh/zprof  # for debugging shell startup speed

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

# install native cdr: (https://zsh.sourceforge.io/Doc/Release/User-Contributions.html#Recent-Directories)
autoload -Uz chpwd_recent_dirs cdr add-zsh-hook
add-zsh-hook chpwd chpwd_recent_dirs

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

########################################## fzf
# https://github.com/junegunn/fzf#setting-up-shell-integration
# Set up fzf key bindings and fuzzy completion  # TODO: unsure we want this; et it overrides fzf-tab's ctrl+r
command -v fzf > /dev/null && source <(fzf --zsh)
# alternatively, some people source .zsh scripts from fzf themselves:
#zinit ice lucid wait'0c' multisrc"shell/{completion,key-bindings}.zsh" id-as="junegunn/fzf_completions" pick="/dev/null"
########################################## /fzf

### fzf-driven history select   # https://github.com/joshskidmore/zsh-fzf-history-search#zinit
zinit ice lucid wait'0'
zinit light joshskidmore/zsh-fzf-history-search

#ZSH_FZF_HISTORY_SEARCH_BIND='^r'
ZSH_FZF_HISTORY_SEARCH_END_OF_LINE=''  # place cursor end of line after completion; empty=false
### /fzf-hist

# other plugins:
ZVM_FAST_ESCAPE=y
zinit ice depth=1; zinit light laur89/zsh-vi-mode  # https://github.com/jeffreytse/zsh-vi-mode  # TODO: currently using own fork of zsh-vi-mode 'til a PR gets merged upstream:
# note source of other cool vi-mode plugins is https://github.com/zsh-vi-more

zinit ice pick"bd.zsh"; zinit light Tarrasch/zsh-bd  # https://github.com/Tarrasch/zsh-bd
zinit light paulirish/git-open  # https://github.com/paulirish/git-open

# TODO: alias-tips makes post-cmd-execution prompt refresh slow!
#       alias-finder, recommended in alias-tips issues, is told to be 10x faster tho: https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/alias-finder
#zinit light djui/alias-tips  # https://github.com/djui/alias-tips
zinit snippet OMZP::alias-finder

zinit snippet OMZP::colored-man-pages  # TODO: is this needed?
#zinit snippet OMZP::copypath
#zinit snippet OMZP::jump  # TODO: any point ove cdr or zoxide?
#zinit snippet OMZP::dirhistory

# prompt {{{
# p10k:  # https://github.com/romkatv/powerlevel10k#zinit
zinit ice depth=1; zinit light romkatv/powerlevel10k
# }}}

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
#zinit snippet PZTM::editor  # https://github.com/sorin-ionescu/prezto/tree/master/modules/editor

#zinit ice svn silent; zinit snippet PZT::modules/gpg  # https://github.com/sorin-ionescu/prezto/tree/master/modules/gpg

# defines general aliases & functions;
# this module needs to be loaded _before_ the PZTM::completion module
#zinit ice svn silent pick"init.zsh" lucid; zinit snippet PZT::modules/utility  # https://github.com/sorin-ionescu/prezto/tree/master/modules/utility
# }}}  /prezto


# completion {{{
zinit ice wait="0b" lucid blockf; zinit light zsh-users/zsh-completions  # TODO: why use blockf ice mod?
# note completion PZT module by default adds  zsh-users/zsh-completions to our fpath
#zinit ice wait="0b" silent pick"init.zsh" blockf; zinit snippet PZTM::completion  # TODO: why use blockf ice mod?

unsetopt CORRECT   # note CORRECT tries to correct the spelling of commands
setopt COMPLETE_IN_WORD  # # Complete from both ends of a word.  # TODO: do we want this?
setopt ALWAYS_TO_END  # Move cursor to the end of a completed word.
setopt AUTO_LIST  # Automatically list choices on ambiguous completion.
setopt AUTO_PARAM_SLASH  # If completed parameter is a directory, add a trailing slash.
setopt COMPLETE_ALIASES

# Enable additional glob operators. (Globbing = pattern matching)
# https://zsh.sourceforge.io/Doc/Release/Expansion.html#Filename-Generation
setopt EXTENDED_GLOB

setopt FLOW_CONTROL
#setopt MENU_COMPLETE  # instead of listing possibilites or beeping, insert the first match immediately
setopt NO_AUTO_MENU  # require an extra TAB press to open the completion menu; note this opt is overridden by MENU_COMPLETE

setopt NO_NOMATCH  # NOMATCH would print an error instead of leaving unchanged if pattern for filename generation has no matches
setopt PATH_DIRS  # Perform path search even on command names with slashes.

unsetopt FLOW_CONTROL  # Enable the use of Ctrl-Q and Ctrl-S for keyboard shortcuts.
# note https://github.com/sorin-ionescu/prezto/blob/master/modules/environment/init.zsh does this as follows, what's the difference?:
# [[ -r ${TTY:-} && -w ${TTY:-} && $+commands[stty] == 1 ]] && stty -ixon <$TTY >$TTY


# set LS_COLOR after plugins, as some prezto stuff (e.g. completion module) might set it
if [[ -x /usr/bin/dircolors ]]; then
    if [[ -f "$BASE_PROGS_DIR/LS_COLORS/lscolors.sh" ]]; then
        source "$BASE_PROGS_DIR/LS_COLORS/lscolors.sh"
    else
        [[ -r "$HOME/.dircolors" ]] && eval "$(dircolors -b "$HOME/.dircolors")" || eval "$(dircolors -b)"
    fi
fi


# opts from https://github.com/crivotz/dot_files/blob/master/linux/zinit/zshrc#L89 (TODO: needed/wanted?)
zstyle ':completion:*' completer _expand _complete _ignored _approximate
# mathcer-list be set to a list of match specifications that are to be applied everywhere, see https://zsh.sourceforge.io/Doc/Release/Completion-Widgets.html#Completion-Matching-Control :
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Z}'
zstyle ':completion:*' menu no
zstyle ':completion:*' select-prompt '%SScrolling active: current selection at %p%s'
zstyle ':completion:*:descriptions' format '[%d]'
zstyle ':completion:*:processes' command 'ps -au$USER'
zstyle ':completion:complete:*:options' sort false
zstyle ':fzf-tab:complete:_zlua:*' query-string input
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,comm,cmd -w -w"
zstyle ':fzf-tab:complete:kill:argument-rest' extra-opts --preview='ps --pid=$in[(w)1] -o cmd --no-headers -w -w' --preview-window=down:3:wrap
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always $realpath'
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':completion:*:git-checkout:*' sort false
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}

# get rid of the prefix-dot (e.g. on kill <TAB>), see https://github.com/Aloxaf/fzf-tab/discussions/511
zstyle ':fzf-tab:*' prefix ''

# TODO: new zstyles:
# to sort by mtime:
#zstyle ':completion:*:vim:*' file-sort modification

zstyle ':fzf-tab:complete:git-(add|diff|restore):*' fzf-preview \
	'git diff $word | delta'

# }}} /completion

# suggestions {{{  # from https://github.com/crivotz/dot_files/blob/master/linux/zinit/zshrc#L75
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
zinit ice wait="0a" lucid atload="_zsh_autosuggest_start"; zinit light zsh-users/zsh-autosuggestions
# }}} /suggestions

# consider also enahncd:
# see also option to use zoxide as its backend: https://github.com/babarot/enhancd/issues/231
#zinit ice wait="0b" lucid; zinit light babarot/enhancd
#export ENHANCD_FILTER=fzf:fzy:peco

# highlighting {{{  # from https://github.com/crivotz/dot_files/blob/master/linux/zinit/zshrc#L107
# note zpcompinit & zpcdreplay replace our usual compinit/replay lines
zinit ice wait="0c" lucid atinit="zpcompinit;zpcdreplay"
zinit light zdharma-continuum/fast-syntax-highlighting
# }}} /highlighting

# fzf tab  # https://github.com/Aloxaf/fzf-tab
# !!! needs to be loaded _after_ compinit, but before plugins which will wrap
#     widgets, such as zsh-autosuggestions or fast-syntax-highlighting;
#     note atm our compinit is ran by some other plug's zinit "zpcompinit;zpcdreplay"
zinit ice wait="1" lucid; zinit light Aloxaf/fzf-tab

# bunch of themes in https://github.com/sainnhe/dotfiles/blob/master/.zsh-theme/README.md
#zinit snippet https://github.com/sainnhe/dotfiles/raw/master/.zsh-theme/gruvbox-material-dark.zsh


fi  # /does-zinit.zsh-exist?
### /PLUGINS
#


### KEYBINDS

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

########################################## mise  # https://mise.jdx.dev/installing-mise.html#zsh
if command -v mise >/dev/null 2>/dev/null; then
    eval -- "$(mise activate zsh)"
fi
########################################## /mise

#########################################################################
# FANCY-CTRL-Z
# from https://github.com/crivotz/dot_files/blob/master/linux/zinit/zshrc
#      which in turn is derivative of https://github.com/ohmyzsh/ohmyzsh/blob/master/plugins/fancy-ctrl-z/fancy-ctrl-z.plugin.zsh
# note bash version is https://gist.github.com/sebastiancarlos/762ac6da14a3180f7ce2409889a6de81
#########################################################################
function fg-fzf() {
  job="$(jobs | fzf -0 -1 | sed -E 's/\[(.+)\].*/\1/')" && echo '' && fg %$job
}

function fancy-ctrl-z () {
  if [[ $#BUFFER -eq 0 ]]; then
    BUFFER=" fg-fzf"
    zle accept-line -w
  else
    zle push-input -w
    zle clear-screen -w
  fi
}
zle -N fancy-ctrl-z
bindkey '^Z' fancy-ctrl-z
#########################################################################

#
#
# think it's best to load compinit last, but unsure why
# note compinit & cdreplay are commented out, as are invoked by zinit's "zpcompinit;zpcdreplay"
#autoload -Uz compinit; compinit
#zinit cdreplay -q  # needs to be after compinit call; see https://github.com/zdharma-continuum/zinit#calling-compinit-without-turbo-mode

########################################## zoxide  # https://github.com/ajeetdsouza/zoxide
# needs to be at the end of file, as it must be _after_ compinit is called.    TODO: compinit seq dependency
#export _ZO_DATA_DIR="$BASE_DATA_DIR/.zoxide"
export _ZO_RESOLVE_SYMLINKS=1
command -v zoxide > /dev/null && eval -- "$(zoxide init zsh)"
# alternatively, source it via zinit:
#zinit ice has'zoxide'; zinit light ajeetdsouza/zoxide
########################################## /zoxide


########################################## atuin  # https://github.com/atuinsh/atuin
# Note: binds ctrl+r and others
command -v atuin > /dev/null && source <(atuin init zsh)
# or:
#eval -- "$(atuin init zsh)"
# or:
#zinit light atuinsh/atuin  # quite pointless tho, see https://github.com/atuinsh/atuin/blob/main/atuin.plugin.zsh
                            # although it can help time it, e.g. for ^R rebindings
########################################## /atuin


# other examples to consider:
# Define functions and completions.
#function md() { [[ $# == 1 ]] && mkdir -p -- "$1" && cd -- "$1" }
#compdef _directories md
#
#
#------ TODO: think debian default config gave also these: (are these done by running $ compinstall ?)


zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format 'Completing %d'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' menu select=2
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

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh
