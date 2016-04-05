# bash aliases:
#
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
alias vscode='/data/progs/VSCode-linux-x64/Code' # MS Visual Code (editor)
alias pubkey='cat ~/.ssh/id_rsa.pub | xsel --clipboard'
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
alias ls="ls --color=auto"
alias ll='ls -hl'
alias lr='ls -hlr'
alias lsr='ls -hlr'
alias ltr='ls -hltr'
alias lrt='ls -hltr'
alias lstr='ls -hltr'
alias lsrt='ls -hltr'
alias lt='ls -hlt'
alias lst='ls -hlt'
alias la='ls -hlA'
alias lar='ls -hlAr'
alias lra='ls -hlAr'
alias lat='ls -hlAt'
alias lta='ls -hlAt'
alias ltar='ls -hlAtr'
alias lrta='ls -hlAtr'
alias lrat='ls -hlAtr'
alias ltra='ls -hlAtr'
alias latr='ls -hlAtr'
alias lart='ls -hlAtr'
#alias l='ls -CF'
alias vdiff="vimdiff"
alias mkdir='mkdir -p'
alias rmrf='rm -rf'
alias psef='ps -ef'
alias gosu='sudo -E su'

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
alias xs='cd'
alias vf='cd'
alias cs='cd'
alias ct='cd'
alias sd='cd'

# git:
alias gti='git'
alias igt='git'
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
#alias gitdi='git di'
alias gitdi='git difftool --dir-diff'                    # diff only unstaged files
alias gitdi-all='git difftool --dir-diff HEAD'           # also diff staged files
alias gitdi-staged-only='git difftool --dir-diff --cached'    # --cached == --staged, as in diff only staged files
alias gitdi-prev='git difftool --dir-diff HEAD^ HEAD'    # local last commit against current index (as in last commit; shows what was changed with last commit); does NOT include current uncommited changes);
#alias gitdi-stashed='git difftool --dir-diff stash@{0}^!'  # diff stash against its parent;
alias gitdi-stashed='git difftool --dir-diff stash@{0}^ stash@{0}'  # diff stash against its parent;

alias mkdri='mkdir'
alias mkdr='mkdir'
alias mkdi='mkdir'
alias mkd='mkdir'
alias mkcs='mkcd'
alias dopbox='dropbox'
alias drpbox='dropbox'
alias dropbx='dropbox'
alias dropvox='dropbox'
alias dorpbox='dropbox'
alias suod='sudo'

# Directory navigation aliases:
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias ......='cd ../../../../..'
alias downloads='cd /home/laur/Downloads'
alias dl='cd /home/laur/Downloads'
alias dls='cd /home/laur/Downloads'
alias dwn='cd /home/laur/Downloads'
alias music='cd /home/laur/Music'
alias muss='cd /home/laur/Music'
alias videos='cd /home/laur/Videos'
alias vids='cd /home/laur/Videos'
alias vid='cd /home/laur/Videos'
alias documents='cd /home/laur/Documents'
alias docs='cd /home/laur/Documents'
alias doc='cd /home/laur/Documents'
alias dox='cd /data/Dropbox/Documents' # ! note the difference of endpoint; only useful on personal setups;
alias pics='cd /data/Dropbox/Pictures'
alias drop='cd /data/Dropbox/'
alias scripts='cd /data/dev/scripts'
alias proj='cd /data/dev/projects'
alias prog='cd /data/progs'
alias progs='cd /data/progs'
alias dev='cd /data/dev'
alias data='cd /data/'
alias git-root='is_git && cd $(git rev-parse --show-toplevel) || err "not a git repo."'  # go to project root
alias grt='git-root'
#TODO:
#alias ffind="eval set ffind"
#alias ffind="ffind"

alias lns='ln -s'
alias svim='sudo vim'
alias root='sudo su'

alias install='sudo apt-get install'
alias uninstall='sudo apt-get remove'
alias uinstall='sudo apt-get remove'
alias reinstall='sudo apt-get --reinstall install'
alias update='sudo apt-get update'
alias upgrade='sudo apt-get update && sudo apt-get upgrade'
alias xo='xdg-open'
