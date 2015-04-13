# bash aliases:
__THEME_LOC="$HOME/.themes/Numix/gtk-2.0/gtkrc"
#
#alias eclipse='env GTK2_RC_FILES=/usr/share/themes/Clearlooks/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-eclipse "/data/progs/eclipse-jee-kepler-x86_64/eclipse/eclipse"'
alias eclipse='env GTK2_RC_FILES=/usr/share/themes/Greybird/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "/data/progs/eclipse-java-luna-SR1-linux-gtk-x86_64/eclipse/eclipse"'
#alias sts='env GTK2_RC_FILES=/usr/share/themes/Greybird/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "/data/progs/spring-tool-suite-3.6.2.RELEASE-e4.4.1-linux-gtk-x86_64/sts-bundle/sts-3.6.2.RELEASE/STS"'
alias sts='env GTK2_RC_FILES=$__THEME_LOC:/home/laur/.gtkrc-2.0-IDE "/data/progs/eclipse/sts"'
#alias idea='env GTK2_RC_FILES=/usr/share/themes/Greybird/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "/data/progs/idea/idea-IU-139.1117.1/bin/idea.sh"'
alias idea='env GTK2_RC_FILES=$__THEME_LOC:/home/laur/.gtkrc-2.0-IDE "/data/progs/idea/idea"'
alias giteye='env GTK2_RC_FILES=$__THEME_LOC:/home/laur/.gtkrc-2.0-IDE "/data/progs/GitEye/GitEye"'
#alias sts='env GTK2_RC_FILES=/usr/share/themes/Clearlooks/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "/data/progs/spring-tool-suite-3.6.2.RELEASE-e4.4.1-linux-gtk-x86_64/sts-bundle/sts-3.6.2.RELEASE/STS"'
alias eclim='env GTK2_RC_FILES=/usr/share/themes/Clearlooks/gtk-2.0/gtkrc:/home/laur/.gtkrc-2.0-IDE "/data/progs/spring-tool-suite-3.6.2.RELEASE-e4.4.1-linux-gtk-x86_64/sts-bundle/sts-3.6.2.RELEASE/eclimd"'
#alias clean_failed_mvn="$(find ~/.m2 -name *.lastUpdated -delete)"
#alias amq="/data/progs/apache-activemq-5.10.0/bin/activemq > /tmp/activemq.log 2>&1 &"
alias logout="pkill -KILL -u $USER"
alias grep="grep --color=auto"
alias c="clear"
alias cp="cp -rp"
alias less="less -IR"
alias ls="ls --color=auto"
alias ll='ls -l'
alias lr='ls -ltr'
alias ltr='ls -ltr'
alias lrt='ls -ltr'
alias lt='ls -lt'
alias la='ls -lAt'
alias lat='ls -lAt'
alias lta='ls -lAt'
alias ltar='ls -lAtr'
alias ltra='ls -lAtr'
alias latr='ls -lAtr'
#alias l='ls -CF'
alias vdiff="vimdiff"
#
# hate the typos:
alias mut="mutt"
alias utt="mutt"
alias cim='vim'
alias xs='cd'
alias vf='cd'
alias cs='cd'
alias gitst='git st'
alias gitdi='git di'

# Directory navigation aliases:
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias downloads='cd /home/laur/Downloads'
alias dl='cd /home/laur/Downloads'
alias dls='cd /home/laur/Downloads'
alias dwn='cd /home/laur/Downloads'
alias music='cd /home/laur/Music'
alias videos='cd /home/laur/Videos'
alias vids='cd /home/laur/Videos'
alias vid='cd /home/laur/Videos'
alias documents='cd /home/laur/Documents'
alias docs='cd /home/laur/Documents'
alias doc='cd /home/laur/Documents'
alias pics='cd /data/Dropbox/Pictures'
alias scripts='cd /data/dev/scripts'
alias proj='cd /data/dev/projects'
alias prog='cd /data/progs'
alias progs='cd /data/progs'
alias dev='cd /data/dev'
alias data='cd /data/'

# mkdir and cd into it:
mkcd () { mkdir -p "$@" && cd "$@"; }


alias lns='ln -s'
alias svim='sudo vim'
alias root='sudo su'

alias install='sudo apt-get install'
alias uninstall='sudo apt-get remove'
alias uinstall='sudo apt-get remove'
alias reinstall='sudo apt-get --reinstall install'
alias update='sudo apt-get update'
alias upgrade='sudo apt-get update && sudo apt-get upgrade'
