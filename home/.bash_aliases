# bash aliases:
#
# !!! please note aliases should be used by humans only, not by scripts.
# !!! they are subject to constant change.
# !!! also be careful aliasing builtins such as 'mkdir' to 'mkdir -p'
#
# for more general aliases/aliases accessible from subshells, see https://superuser.com/a/1420612/179401
#
#
# note that fasd generates its own aliases (check from its init cache somewhere in homedir), eg
    #alias a='fasd -a'
    #alias s='fasd -si'
    #alias sd='fasd -sid'
    #alias sf='fasd -sif'
    #alias d='fasd -d'
    #alias f='fasd -f'
    #alias z='fasd_cd -d'
    #alias zz='fasd_cd -d -i'
##################################
#__THEME_LOC="$HOME/.themes/Numix/gtk-2.0/gtkrc"
#
#alias eclipse='env GTK2_RC_FILES=/usr/share/themes/Clearlooks/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-eclipse "$BASE_PROGS_DIR/eclipse-jee-kepler-x86_64/eclipse/eclipse"'
#alias eclipse='env GTK2_RC_FILES=/usr/share/themes/Greybird/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "$BASE_PROGS_DIR/eclipse-java-luna-SR1-linux-gtk-x86_64/eclipse/eclipse"'
alias sts2='env GTK2_RC_FILES=$HOME/.themes/Numix/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "$BASE_PROGS_DIR/eclipse/sts2"'
alias eclipse='env GTK2_RC_FILES=$HOME/.themes/Numix/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "$BASE_PROGS_DIR/eclipse/eclipse"'
alias mat='env GTK2_RC_FILES=$HOME/.themes/Numix/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-eclipse "$BASE_PROGS_DIR/mat/MemoryAnalyzer"'
#alias sts='env GTK2_RC_FILES=/usr/share/themes/Greybird/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "$BASE_PROGS_DIR/spring-tool-suite-3.6.2.RELEASE-e4.4.1-linux-gtk-x86_64/sts-bundle/sts-3.6.2.RELEASE/STS"'
alias sts='env GTK2_RC_FILES=$HOME/.themes/Numix/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "$BASE_PROGS_DIR/eclipse/sts"'
#alias idea='env GTK2_RC_FILES=$HOME/.themes/Numix/gtk-2.0/gtkr:/home/laur/.gtkrc-2.0-IDE "$BASE_PROGS_DIR/idea/idea"'
alias soapui='( cd $BASE_PROGS_DIR/soapui && env GTK2_RC_FILES=$HOME/.themes/Numix/gtk-2.0/gtkr:/home/laur/.gtkrc-2.0-IDE "./soapui/bin/soapui.sh" )'
alias giteye='env GTK2_RC_FILES=$HOME/.themes/Numix/gtk-2.0/gtkr:/home/laur/.gtkrc-2.0-IDE "$BASE_PROGS_DIR/GitEye/GitEye"'
#alias sts='env GTK2_RC_FILES=/usr/share/themes/Clearlooks/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "$BASE_PROGS_DIR/spring-tool-suite-3.6.2.RELEASE-e4.4.1-linux-gtk-x86_64/sts-bundle/sts-3.6.2.RELEASE/STS"'
alias fileroller='file-roller'
alias vscode='$BASE_PROGS_DIR/VSCode-linux-x64/Code'  # MS Visual Code (editor)
#alias franz='$BASE_PROGS_DIR/franz/franz'  # client that manages loads of different chat clients (via their web frontends)
alias mattermost='$BASE_PROGS_DIR/mattermost/mattermost'
alias pastebinit='pastebinit -P'
alias uptime='uptime --pretty'
alias xo='xdg-open'
alias printer-config='system-config-printer'
alias equalizer='qpaeq'  # qpaeq = pulseaudio-equalizer
alias firefox='GTK_THEME=Arc-Darker firefox'  # Arc-Dark renders some elements in firefox unreadable (https://github.com/horst3180/arc-theme/issues/714)
alias pcat='pygmentize -f terminal256 -O style=native -g'  # syntax highlighter with python3-pygments
alias pycat='pcat'
alias googler='googler --lang en'
alias goo='googler'
alias define='googler -n 4 define'
alias py3='python3'
alias ipy='ipython3 --no-banner --no-confirm-exit'
alias dunc='ncdu'  # never remember it; if it starts w/ 'du', it'll be more likely to find
alias wheresthespace='ncdu -x /'  # what's taking up the space? -x avoids cross-fs
alias dfpy=pydf
alias tgo='tmux new-session -A -f no-detach-on-destroy -s'  # start a new tmux session of provided name, or attach to it if already exists
#alias got='tgo'  # unused IMO
alias ngo='nvim --listen /tmp/nvim_$USER' # start the _main_/master nvim process, listening on given socket; that socket will be used by nvr (neovim-remote)
alias gist='gist --private --copy'
alias tkremind='tkremind -m -b1'
alias lofi='mpv --no-video https://youtu.be/jfKfPfyJRdk'  # play lo-fi music
alias pdx=plandex
pdxn() { [[ "$#" -eq 1 ]] || { err 'need one arg - new plan name to create'; return 1; }; plandex new -n "$1"; }

# note following uses the 'none' driver, now effectively superseded by 'docker' driver:   # https://minikube.sigs.k8s.io/docs/drivers/none/
#alias mkstart='CHANGE_MINIKUBE_NONE_USER=true sudo -E minikube start --driver=none --extra-config=apiserver.service-node-port-range=80-32767 --apiserver-ips 127.0.0.1 --apiserver-name localhost'
# ...and this is using docker driver:
alias mkstart='minikube start --driver=docker'
alias kon='kubeon'
alias kof='kubeoff'

# $tm <sessname> to either create or attach, or $tm to search from avail sessions w/ fzf;
#tm() {
  #[[ -n "$TMUX" ]] && change="switch-client" || change="attach-session"
  #if [ $1 ]; then
     #tmux $change -t "$1" 2>/dev/null || (tmux new-session -d -s $1 && tmux $change -t "$1"); return
  #fi
  #session=$(tmux list-sessions -F "#{session_name}" 2>/dev/null | fzf --exit-0) &&  tmux $change -t "$session" || echo "No sessions found."
#}
##################################
#alias clean_failed_mvn="$(find ~/.m2 -name *.lastUpdated -delete)"
#alias amq="$BASE_PROGS_DIR/apache-activemq-5.10.0/bin/activemq > /tmp/activemq.log 2>&1 &"
#alias ulogout="sudo pkill -KILL -u $1"  # user logout
alias logout="pkill -TERM -u $(whoami) & sleep 5 && pkill -KILL -u $(whoami) && exit 0"  # perhaps consider $ killall5
#alias logout="pkill -u $USER"   # by default pkill sends SIGTERM signal
#alias logout='kill -9 -1' # kill all processes *you* can kill
#alias logout="loginctl terminate-user $USER" # kill all processes *you* can kill
command -v batcat > /dev/null 2>&1 && alias bat=batcat  # on ubuntu/debian, bat installs as batcat command
command -v nsxiv > /dev/null 2>&1 && alias sxiv=nsxiv
alias fd="fd --hidden --exclude '.git'"  # TODO: consider adding --no-ignore option to bypass gitignore, fdignore et al
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='grep -E --color=auto'
alias igrep='grep -i --color=auto'
command -v ncal > /dev/null 2>&1 && alias cal='ncal -bM -A 1 -B 1'  # same as [ncal -bM3]
alias caly='cal -y'  # year view
alias gagenda='gcalcli agenda "$(date "+%F %R")"  "$(date -d tomorrow "+%F 00:00")" --details=url --details=end --military'
#alias gag=gagenda
alias gagt='gcalcli agenda "$(date -d tomorrow "+%F 00:00")"  "$(date -d "+2 days" "+%F 00:00")" --details=url --details=end --military'
alias calw='gcalcli calw --details=end --military --monday'
alias galw=calw
alias gagw=calw
alias calm='gcalcli calm --details=end --military --monday'
alias galm=calm
alias gagm=calm
alias c='clear'
alias cp='cp -rp'  # TODO: add -i for overwrite prompt? what about scripts that use cp?
alias scp='scp -rp'
alias sync-monit='watch -d grep -e Dirty: -e Writeback: /proc/meminfo'  # or  $ sar -r 1
alias dig='dig +search'  # https://serverfault.com/questions/434581/why-can-host-and-nslookup-resolve-a-name-but-dig-cannot/899996
if command -v duf > /dev/null 2>&1; then
    # duf --hide network
    # duf --only local
    # duf --hide network --hide-fs tmpfs
    # to see everything, including fuse:  $ duf --all
    alias dfh='command duf --hide network --hide-fs tmpfs'
elif command -v pydf > /dev/null 2>&1; then
    alias dfh='command pydf -h --local'
    alias pydf=dfh
else
    alias dfh='df -h --local -x tmpfs -x devtmpfs -x nfs'  # note we're ignoring tmp & nfs filesystems
fi
#alias less="less -IRKFX" # handled by the $LESS env var
alias nano='nano --mouse'
alias sysinfo='inxi -Fxxxz'
alias rtv='tuir'
###############################
alias ls='ls -Fh --color=auto --group-directories-first'
alias ll='ls -l'
alias lr='ls -lr'
alias lsr='ls -lr'
alias ltr='ls -ltr'
alias lrt='ls -ltr'
alias lstr='ls -ltr'
alias lsrt='ls -ltr'
alias lt='ls -lt'
alias lst='ls -lt'
alias la='ls -lA'
alias lar='ls -lAr'
alias lra='ls -lAr'
alias lat='ls -lAt'
alias lta='ls -lAt'
alias ltar='ls -lAtr'
alias lrta='ls -lAtr'
alias lrat='ls -lAtr'
alias ltra='ls -lAtr'
alias latr='ls -lAtr'
alias lart='ls -lAtr'
#alias l='ls -CF'
############################### /ls
alias eza='eza --color=auto --group-directories-first'
alias elt='eza -lr'  # note we provide reversal flag to match 'ls -lt'; guess sorting directions differ?
alias eltr='eza -l'  # note we omit reversal flag to match 'ls -ltr'; guess sorting directions differ?
############################### /eza
alias vdiff='vimdiff'
alias mkdir='mkdir -p'
alias rmrf='rm -rf'
alias psef='ps -ef'
# note -E is tricky; stuff like PROMPT_COMMAND might refer to functions not avail for root:
alias gosu='sudo -E su'
alias su='su --login'  # so env vars would be cleared
alias lns='ln -s'
alias svim='sudoedit'
alias snvim='sudoedit'
alias root='sudo su'

if command -v lsd > /dev/null 2>&1; then
    alias t1='lsd -L --tree --depth=1'
    alias t2='lsd -L --tree --depth=2'
    alias t3='lsd -L --tree --depth=3'
    alias t4='lsd -L --tree --depth=4'
    alias t5='lsd -L --tree --depth=5'
else
    alias t1='tree -lL 1'
    alias t2='tree -lL 2'
    alias t3='tree -lL 3'
    alias t4='tree -lL 4'
    alias t5='tree -lL 5'
fi

#
# hate the typos:
alias ehco='echo'
alias mut='neomutt'
alias utt='neomutt'
alias mutt='neomutt'
alias vifm='vifmrun'  # latter being our script
alias cim='nvim'
alias vin='nvim'
command -v vim > /dev/null 2>&1 || alias vim='nvim'  # yup
command -v nvim > /dev/null 2>&1 || alias nvim='vim'
alias bim='nvim'
alias nbim='nvim'
alias nivm='nvim'
alias nvmi='nvim'
alias nvi='nvim'
alias vmi='nvim'
alias xs='cd'
alias vf='cd'
#alias cs='cd'  # conscript and/or coursier use 'cs'
alias ct='cd'
alias sd='cd'
alias fin='find'
alias ffin='ffind'
alias sduo='sudo'
alias gir='git'
alias gti='git'
alias igt='git'
alias guit='git'
alias gtio='gito'
alias suod='sudo'
alias mkdri='mkdir'
alias mkdr='mkdir'
alias mkdi='mkdir'
alias mkd='mkdir'
alias mkcs='mkcd'
alias cd-='cd -'
alias -- -='cd -'

# git:
alias gitst='git st'
alias gitfe='git fe'
alias gitdd='git dd'
alias gitco='git co'
alias gitrst='git rst'
alias gitau='git au'
alias gitlg='git lg'
alias gitlgp='git lg -p'
alias gitcom='git com'
alias gita='git a'
alias gitaa='git aa'
alias gitb='git b'
alias gitp='git pull'
alias gitpsh='git push'
alias gitdi='silent_background git difftool --dir-diff'                    # diff only unstaged files
alias gitdi-all='silent_background git difftool --dir-diff HEAD'           # also diff staged files
alias gitdi-staged='silent_background git difftool --dir-diff --cached'    # --cached == --staged, as in diff only staged files
alias gitdi-stged='gitdi-staged'
alias gitdi-prev='silent_background git difftool --dir-diff HEAD^ HEAD'    # local last commit against current index (as in last commit; shows what was changed with last commit); does NOT include current uncommited changes);
alias gitdi-commit='silent_background git showtool'  # diff specific commit, or HEAD, if no arg was given
#alias gitdi-stashed='silent_background git difftool --dir-diff stash@{0}^!'  # diff stash against its parent;
alias gitdi-stashed='silent_background git difftool --dir-diff stash@{0}^ stash@{0}'  # diff stash against its parent;
alias git-root='is_git && __grt="$(get_git_root)" && [[ -n "$__grt" ]] && cd -- "$__grt" && unset __grt || { err "are you in a git repo?"; unset __grt; }'  # go to project root
alias grt='git-root'
alias gpushall='is_git || err "not in a git repo" && { git push --tags && git checkout master && git push && git checkout develop && git push; }'
# forgit aliases: (https://github.com/wfxr/forgit)
alias gr='forgit::reset::head'    # git reset
alias gR='forgit::checkout::file' # git co -- ...
alias gin='gitin'

# gh pr-related aliases, TODO confirm:
prcreate() { gh pr create -B "$1" -f; }
prmerge() { gh pr merge --merge --delete-branch=false "$1"; }
prlist() { gh pr list --state open; }
prcheck() { gh pr checkout "$1" && gh pr diff; }

# ------------------------------------
# Docker alias and functions
# from https://github.com/tcnksm/docker-alias/blob/master/zshrc
# TODO: move to bash_functions
# ------------------------------------

# Get latest created container ID
alias dl='docker ps -lq'

# Get container processes
alias dps='docker ps'

# Get processes included stop container
alias dpa='docker ps --all'
alias dpsa='dpa'

# Get images
alias di='docker images'

# Get container IP
alias dip='docker inspect --format "{{ .NetworkSettings.IPAddress }}"'

# Run deamonized container, e.g., $dkd base_image /bin/echo hello
alias dkd='docker run -d -P'

# Run interactive container, e.g., $dki base_image /bin/bash
alias dki='docker run -i -t -P'

_running_dock_by_name() {
    local input opt OPTIND single name_to_id name line fzf_selection id

    while getopts 's' opt; do
        case "$opt" in
           s) single=1
              ;;
           *)
              return 1
              ;;
        esac
    done
    shift "$((OPTIND-1))"

    input="$*"

    if [[ "$single" == 1 ]]; then
        declare -A name_to_id

        while read -r line; do
            name="$(cut -d' ' -f2- <<< "$line")"
            fzf_selection+="${name}\n"
            name_to_id[$name]="$(cut -d' ' -f1 <<< "$line")"
        done < <(docker ps --no-trunc --format '{{.ID}} {{.Names}}' | grep -i "$input")  # note we don't use docker-ps's --filter option, as using grep gives us case-insensitivity

        readonly fzf_selection="${fzf_selection:0:$(( ${#fzf_selection} - 2 ))}"  # strip the trailing newline
        name="$(echo -e "$fzf_selection" | fzf --select-1)" || return 1
        [[ -z "$name" ]] && return 1
        id="${name_to_id[$name]}"
        [[ -z "$id" ]] && { err "no docker found by name [$input]"; return 1; }
        echo -n "$id"
        return 0
        #fzf --select-1 --multi --exit-0 --print0 <<< "${name_to_id[@]}"
    else
        # note following still displays the entire [ps] output, not just container IDs
        docker ps --no-trunc | grep -i "$input"
    fi
}

# Execute interactive container, e.g., $dex base /bin/bash
# note: docker exec  runs command in an (already) RUNNING container
#alias dex="docker exec -i -t"
dex() { docker exec -it "$(_running_dock_by_name -s "$1")" "${@:2}"; }

# Stop all containers
dstop() { docker stop $(docker ps --no-trunc -aq); }

# Remove all (all, not just running!) containers
drm() { docker rm $(docker ps --no-trunc -aq); }
# TODO: rename drm() to drma(), and use drm() to delete specific containers only?

# Stop & remove all containers
alias drmf='docker stop $(docker ps --no-trunc -aq) && docker rm $(docker ps --no-trunc -aq)'

# Remove all images
dri() { docker rmi $(docker images -q); }

# Dockerfile build, e.g., $dbu tcnksm/test
dbu() { docker build --tag="$1" .; }

# Show all alias related docker
dalias() { alias | grep 'docker' | sed "s/^\([^=]*\)=\(.*\)/\1 => \2/;s/['|\']//g" | sort; }

# Bash into running container
dbash() { docker exec -it "$(_running_dock_by_name -s "$1")" bash -l; }

# docker (better use functions in bash_funtions.sh):
alias drmi='docker rmi $(docker images --filter "dangling=true" -q --no-trunc)'
# ------------------------------------
# AWS aliases (for aws-okta):
alias aod='aws-okta exec dev --'
alias aon='aws-okta exec nonprod --'
alias aop='aws-okta exec prod --'

# ...and for saml2aws (which replaces/supersedes aws-okta):
#alias aod='saml2aws exec --exec-profile dev --'
#alias aon='saml2aws exec --exec-profile nonprod --'
#alias aop='saml2aws exec --exec-profile prod --'
# ------------------------------------


# Directory navigation aliases:
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias .......='cd ../../../../../..'
alias ........='cd ../../../../../../..'
#alias downloads='cd ~/Downloads'
alias dl='cd ~/Downloads'
alias dls='cd ~/Downloads'
alias music='cd ~/Music'
alias muss='cd ~/Music'
#alias videos='cd ~/Videos'
alias vids='cd ~/Videos'
alias vid='cd ~/Videos'
#alias documents='cd ~/Documents'
alias docs='cd ~/Documents'
alias doc='cd ~/Documents'
#alias dox='cd /data/Dropbox/Documents'  # ! note the difference of endpoint; only useful on non-personal setups;
alias pics='cd ~/Pictures'
alias shots='cd ~/Pictures/screenshots/$HOSTNAME'
alias scripts='cd /data/dev/scripts'
alias proj='cd /data/dev/projects'
alias progs='cd $BASE_PROGS_DIR'
alias dev='cd /data/dev'
alias data='cd /data/'
alias tmp='cd /tmp/'
alias temp='cd /tmp/'


alias install='sudo apt-get install'
alias uninstall='sudo apt-get remove'
alias uinstall='sudo apt-get remove'
alias reinstall='sudo apt-get --reinstall install'

alias send-clipboard='kdeconnect-cli --name "$PHONE_NAME" --send-clipboard'  # PHONE_NAME defined in env vars

alias neofetch=fastfetch
