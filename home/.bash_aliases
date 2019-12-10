# bash aliases:
#
# !!! please note aliases should be used by humans only, not by scripts.
# !!! they are subject to constant change.
# !!! also be careful aliasing builtins such as 'mkdir' to 'mkdir -p'
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
#alias eclipse='env GTK2_RC_FILES=/usr/share/themes/Clearlooks/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-eclipse "/data/progs/eclipse-jee-kepler-x86_64/eclipse/eclipse"'
#alias eclipse='env GTK2_RC_FILES=/usr/share/themes/Greybird/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "/data/progs/eclipse-java-luna-SR1-linux-gtk-x86_64/eclipse/eclipse"'
alias sts2='env GTK2_RC_FILES=$HOME/.themes/Numix/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "/data/progs/eclipse/sts2"'
alias eclipse='env GTK2_RC_FILES=$HOME/.themes/Numix/gtk-2.0/gtkr:/home/laur/.gtkrc-2.0-IDE "/data/progs/eclipse/eclipse"'
#alias sts='env GTK2_RC_FILES=/usr/share/themes/Greybird/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "/data/progs/spring-tool-suite-3.6.2.RELEASE-e4.4.1-linux-gtk-x86_64/sts-bundle/sts-3.6.2.RELEASE/STS"'
alias sts='env GTK2_RC_FILES=$HOME/.themes/Numix/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "/data/progs/eclipse/sts"'
#alias idea='env GTK2_RC_FILES=/usr/share/themes/Greybird/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "/data/progs/idea/idea-IU-139.1117.1/bin/idea.sh"'
alias idea='env GTK2_RC_FILES=$HOME/.themes/Numix/gtk-2.0/gtkr:/home/laur/.gtkrc-2.0-IDE "/data/progs/idea/idea"'
alias soapui='( cd /data/progs/soapui && env GTK2_RC_FILES=$HOME/.themes/Numix/gtk-2.0/gtkr:/home/laur/.gtkrc-2.0-IDE "./soapui/bin/soapui.sh" )'
alias giteye='env GTK2_RC_FILES=$HOME/.themes/Numix/gtk-2.0/gtkr:/home/laur/.gtkrc-2.0-IDE "/data/progs/GitEye/GitEye"'
#alias sts='env GTK2_RC_FILES=/usr/share/themes/Clearlooks/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "/data/progs/spring-tool-suite-3.6.2.RELEASE-e4.4.1-linux-gtk-x86_64/sts-bundle/sts-3.6.2.RELEASE/STS"'
alias eclim='env GTK2_RC_FILES=/usr/share/themes/Clearlooks/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "/data/progs/spring-tool-suite-3.6.2.RELEASE-e4.4.1-linux-gtk-x86_64/sts-bundle/sts-3.6.2.RELEASE/eclimd"'
#alias skype='LD_PRELOAD=/data/progs/custom_builds/skypetab-ng/libskypetab-ng.so   skype'
alias fileroller='file-roller'
alias vscode='/data/progs/VSCode-linux-x64/Code'  # MS Visual Code (editor)
#alias franz='/data/progs/franz/franz'  # client that manages loads of different chat clients (via their web frontends)
alias mattermost='/data/progs/mattermost/mattermost'
alias pastebinit='pastebinit -P'
alias uptime='uptime --pretty'
alias xo='xdg-open'
alias printer-config='system-config-printer'
alias equalizer='qpaeq'  # qpaeq = pulseaudio-equalizer
alias firefox='GTK_THEME=Arc-Darker firefox'  # Arc-Dark renders some elements in firefox unreadable (https://github.com/horst3180/arc-theme/issues/714)
alias pcat='pygmentize -f terminal256 -O style=native -g'  # syntax highlighter with python3-pygments
alias pycat='pcat'
alias goo='googler'
alias define='googler -n 4 define'
alias py3='python3'
alias dunc='ncdu'  # never remember it; if it starts w/ 'du', it'll be more likely to find
alias tgo='tmux new -A -s' # start a new tmux session, or attach to it if already exists
alias got='tgo'

alias mkstart='CHANGE_MINIKUBE_NONE_USER=true sudo -E minikube start --extra-config=apiserver.service-node-port-range=80-32767 --vm-driver=none --apiserver-ips 127.0.0.1 --apiserver-name localhost'

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
#alias amq="/data/progs/apache-activemq-5.10.0/bin/activemq > /tmp/activemq.log 2>&1 &"
#alias ulogout="sudo pkill -KILL -u $1"  # user logout
alias logout="pkill -TERM -u $(whoami) & sleep 5 && pkill -KILL -u $(whoami) && exit 0"
#alias logout="pkill -u $USER"   # by default pkill sends SIGTERM signal
#alias logout='kill -9 -1' # kill all processes *you* can kill
alias fd="fd --hidden --exclude '.git'"
alias grep='grep --color=auto'
alias fgrep='fgrep --color=auto'
alias egrep='grep -E --color=auto'
alias cal='ncal -bM -A 1 -B 1'
alias c='clear'
alias cp='cp -rp'  # TODO: add -i for overwrite prompt? what about scripts that use cp?
alias scp='scp -rp'
alias dig='dig +search'  # https://serverfault.com/questions/434581/why-can-host-and-nslookup-resolve-a-name-but-dig-cannot/899996
alias dfh='df -h'
#alias less="less -IRKFX" # handled by the $LESS env var
alias ls='ls -h --color=auto --group-directories-first'
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
alias vdiff='vimdiff'
alias mkdir='mkdir -p'
alias rmrf='rm -rf'
alias psef='ps -ef'
# note -E is tricky; stuff like PROMPT_COMMAND might refer to functions not avail for root:
alias gosu='sudo -E su'
alias su='su --login'  # so env vars would be cleared
alias lns='ln -s'
alias svim='sudo nvim'
alias snvim='sudo nvim'
alias root='sudo su'
alias lsd='{ ls | tr "\n" " "; echo; } | lolcat -a -d 150 -s 60'

alias t1='tree -L 1'
alias t2='tree -L 2'
alias t3='tree -L 3'
alias t4='tree -L 4'
alias t5='tree -L 5'

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
#alias cs='cd'  # conscript (http://www.foundweekends.org/conscript/) uses 'cs'
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
alias dopbox='dropbox'
alias drpbox='dropbox'
alias dropvox='dropbox'
alias dorpbox='dropbox'

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
alias gitdi='git difftool --dir-diff'                    # diff only unstaged files
alias gitdi-all='git difftool --dir-diff HEAD'           # also diff staged files
alias gitdi-staged-only='git difftool --dir-diff --cached'    # --cached == --staged, as in diff only staged files
alias gitdi-prev='git difftool --dir-diff HEAD^ HEAD'    # local last commit against current index (as in last commit; shows what was changed with last commit); does NOT include current uncommited changes);
alias gitdi-commit='git showtool'  # diff specific commit, or HEAD, if no arg was given
#alias gitdi-stashed='git difftool --dir-diff stash@{0}^!'  # diff stash against its parent;
alias gitdi-stashed='git difftool --dir-diff stash@{0}^ stash@{0}'  # diff stash against its parent;
alias git-root='is_git && __grt="$(git rev-parse --show-toplevel)" && [[ -n "$__grt" ]] && cd -- "$__grt" && unset __grt || { err "are you in a git repo?"; unset __grt; }'  # go to project root
alias grt='git-root'
alias gpushall='is_git || err "not in a git repo" && { git push --tags && git checkout master && git push && git checkout develop && git push; }'
# forgit aliases: (https://github.com/wfxr/forgit)
alias gr='forgit::reset::head'  # git reset
alias gR='forgit::restore'      # git co -- ...
alias gin='gitin'

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
alias dpa='docker ps -a'
alias dpsa='dpa'

# Get images
alias di='docker images'

# Get container IP
alias dip='docker inspect --format "{{ .NetworkSettings.IPAddress }}"'

# Run deamonized container, e.g., $dkd base_image /bin/echo hello
alias dkd='docker run -d -P'

# Run interactive container, e.g., $dki base_image /bin/bash
alias dki='docker run -i -t -P'

# Execute interactive container, e.g., $dex base /bin/bash
# note: docker exec  runs command in an (already) RUNNING container
#alias dex="docker exec -i -t"
dex() { docker exec -it $(docker ps -qf "name=$1") "${@:2}"; }

# Stop all containers
dstop() { docker stop $(docker ps -aq); }

# Remove all containers
drm() { docker rm $(docker ps -aq); }
# TODO: rename drm() to drma(), and use drm() to delete specific containers only?

# Stop & remove all containers
alias drmf='docker stop $(docker ps -aq) && docker rm $(docker ps -aq)'

# Remove all images
dri() { docker rmi $(docker images -q); }
alias drmi='dri'

# Dockerfile build, e.g., $dbu tcnksm/test
dbu() { docker build -t=$1 .; }

# Show all alias related docker
dalias() { alias | grep 'docker' | sed "s/^\([^=]*\)=\(.*\)/\1 => \2/"| sed "s/['|\']//g" | sort; }

# Bash into running container
dbash() { docker exec -it $(docker ps -qf "name=$1") bash; }

# docker (better use functions in bash_funtions.sh):
#alias drmi='docker rmi $(docker images --filter "dangling=true" -q --no-trunc)'
# ------------------------------------


# Directory navigation aliases:
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias .......='cd ../../../../../..'
alias ........='cd ../../../../../../..'
alias downloads='cd /home/laur/Downloads'
alias dl='cd /home/laur/Downloads'
alias dls='cd /home/laur/Downloads'
alias music='cd /home/laur/Music'
alias muss='cd /home/laur/Music'
alias videos='cd /home/laur/Videos'
alias vids='cd /home/laur/Videos'
alias vid='cd /home/laur/Videos'
alias documents='cd /home/laur/Documents'
alias docs='cd /home/laur/Documents'
alias doc='cd /home/laur/Documents'
alias dox='cd /data/Dropbox/Documents'  # ! note the difference of endpoint; only useful on non-personal setups;
alias pics='cd /data/Dropbox/Pictures'
alias shots='cd /data/Dropbox/Pictures/screenshots/$HOSTNAME'
alias drop='cd /data/Dropbox/'
alias scripts='cd /data/dev/scripts'
alias proj='cd /data/dev/projects'
alias prog='cd /data/progs'
alias progs='cd /data/progs'
alias deps='cd /data/progs/deps'
alias dev='cd /data/dev'
alias data='cd /data/'
alias tmp='cd /tmp/'
alias temp='cd /tmp/'


alias install='sudo apt-get install'
alias uninstall='sudo apt-get remove'
alias uinstall='sudo apt-get remove'
alias reinstall='sudo apt-get --reinstall install'
alias update='sudo apt-get update'
