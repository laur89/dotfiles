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
alias franz='/data/progs/franz/franz'  # client that manages loads of different chat clients (via their web frontends)
alias pastebinit='pastebinit -P'
alias xo='xdg-open'
alias printer-config='system-config-printer'
alias equalizer='qpaeq'  # qpaeq = pulseaudio-equalizer
alias firefox='GTK_THEME=Arc-Darker firefox'  # Arc-Dark renders some elements in firefox unreadable (https://github.com/horst3180/arc-theme/issues/714)
##################################
#alias clean_failed_mvn="$(find ~/.m2 -name *.lastUpdated -delete)"
#alias amq="/data/progs/apache-activemq-5.10.0/bin/activemq > /tmp/activemq.log 2>&1 &"
#alias ulogout="sudo pkill -KILL -u $1"  # user logout
alias logout="pkill -TERM -u $(whoami) & sleep 5 && pkill -KILL -u $(whoami) && exit 0"
#alias logout="pkill -u $USER"   # by default pkill sends SIGTERM signal
#alias logout='kill -9 -1' # kill all processes *you* can kill
alias grep="grep --color=auto"
alias fgrep='fgrep --color=auto'
alias egrep='egrep --color=auto'
alias c="clear"
alias cp="cp -rp"
#alias less="less -IRKFX" # handled by the $LESS env var
alias ls="ls -h --color=auto --group-directories-first"
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
alias vdiff="vimdiff"
alias mkdir='mkdir -p'
alias rmrf='rm -rf'
alias psef='ps -ef'
alias gosu='sudo -E su'
alias su='su --login'  # so env vars would be cleared
alias lns='ln -s'
alias svim='sudo vim'
alias root='sudo su'

alias t1='tree -L 1'
alias t2='tree -L 2'
alias t3='tree -L 3'
alias t4='tree -L 4'
alias t5='tree -L 5'

#
# hate the typos:
alias mut="mutt"
alias utt="mutt"
alias cim='vim'
alias vin='vim'
alias bim='vim'
alias nbim='nvim'
alias nivm='nvim'
alias nvmi='nvim'
alias nvi='nvim'
alias xs='cd'
alias vf='cd'
alias cs='cd'
alias ct='cd'
alias sd='cd'
alias fin='find'
alias ffin='ffind'
alias sduo='sudo'
alias gir='git'
alias gti='git'
alias igt='git'
alias guit='git'
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
alias gitco='git co'
alias gitrst='git rst'
alias gitau='git au'
alias gitlg='git lg'
alias gitlgp='git lg -p'
alias gitcom='git com'
alias gita='git a'
alias gitaa='git aa'
alias gitb='git b'
alias gitdi='git-root && git difftool --dir-diff && cd - > /dev/null 2>&1'                    # diff only unstaged files
alias gitdi-all='git-root && git difftool --dir-diff HEAD && cd - > /dev/null 2>&1'           # also diff staged files
alias gitdi-staged-only='git-root && git difftool --dir-diff --cached && cd - > /dev/null 2>&1'    # --cached == --staged, as in diff only staged files
alias gitdi-prev='git-root && git difftool --dir-diff HEAD^ HEAD && cd - > /dev/null 2>&1'    # local last commit against current index (as in last commit; shows what was changed with last commit); does NOT include current uncommited changes);
#alias gitdi-stashed='git difftool --dir-diff stash@{0}^!'  # diff stash against its parent;
alias gitdi-stashed='git-root && git difftool --dir-diff stash@{0}^ stash@{0} && cd - > /dev/null 2>&1'  # diff stash against its parent;
alias git-root='is_git && __grt="$(git rev-parse --show-toplevel)" && [[ -n "$__grt" ]] && cd -- "$__grt" && unset __grt || { err "are you in a git repo?"; unset __grt; }'  # go to project root
alias grt='git-root'
alias gpushall='is_git || err "not in a git repo" && { git push --tags && git checkout master && git push && git checkout develop && git push; }'

# docker (better use functions in bash_funtions.sh):
#alias drmi='docker rmi $(docker images --filter "dangling=true" -q --no-trunc)'


# Directory navigation aliases:
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias .......='cd ../../../../../..'
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
alias upgrade='sudo apt-get update && sudo apt-get upgrade'
