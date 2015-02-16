# good source: http://tldp.org/LDP/abs/html/sample-bashrc.html
#
#
# find files or dirs:
function ffind() {
    local SRC SRCDIR
    SRC="$1"

    [[ -z "$SRC" ]] && { echo -e "src term required.\n$FUNCNAME filename [location]"; return 1;  }
    [[ "$#" -gt 2 ]] && { echo -e "too many args.\n$FUNCNAME filename [location]"; return 1;  }
    [[ "$#" == 2 ]] && { SRCDIR="$2"; }

    if [[ -n "$SRCDIR" ]]; then
        find "$SRCDIR" -iname '*'"$SRC"'*' 2>/dev/null
    else
        find / -iname '*'"$SRC"'*' 2>/dev/null
    fi
}

# Find a file with a pattern in name (inside wd);
# essentially same as ffind(), but a bit simplified:
function ff() {
    find . -type f -iname '*'"$*"'*'  -ls
}

# find top 5/x biggest files:
function ffindtopbig() {
    local itmesToShow
    [[ -n "$1" ]] && itmesToShow="$1" || itmesToShow="5"

    find . -type f -exec ls -s {} \; | sort -n -r | head -$itmesToShow 2>/dev/null

}

# find top 5/x smallest files:
function ffindtopsmall() {
    local itmesToShow
    [[ -n "$1" ]] && itmesToShow="$1" || itmesToShow="5"

    find . -type f -exec ls -s {} \; | sort -n | head -$itmesToShow 2>/dev/null

}

# find  files bigger than x mb:
function ffindbiggerthan() {
    local size
    [[ -n "$1" ]] && size="$1" || size="1024"

    find . -size +${size}M 2>/dev/null

}

# find  files smalles than x mb:
function ffindsmallerthan() {
    local size
    [[ -n "$1" ]] && size="$1" || size="1024"

    find . -size -${size}M 2>/dev/null
}

#  Find a pattern in a set of files and highlight them:
#+ (needs a recent version of egrep).
function ffstr() {
    local grepcase OPTIND usage
    OPTIND=1
    grepcase=""
    usage="fstr: find string in files.
Usage: fstr [-i] \"pattern\" [\"filename pattern\"] "
    while getopts :it opt
    do
        case "$opt" in
           i) grepcase="-i " ;;
           *) echo "$usage"; return ;;
        esac
    done
    shift $(( $OPTIND - 1 ))
    if [ "$#" -lt 1 ]; then
        echo "$usage"
        return;
    fi
    find . -type f -name "${2:-*}" -print0 | \
xargs -0 egrep --color=always -sn ${grepcase} "$1" 2>&- | more

}

function swap() {
    # Swap 2 files around, if they exist (from Uzi's bashrc):
    local TMPFILE=/tmp/swap_function_tmpFile.$$

    [ $# -ne 2 ] && echo "swap: 2 arguments needed" && return 1
    [ ! -e $1 ] && echo "swap: $1 does not exist" && return 1
    [ ! -e $2 ] && echo "swap: $2 does not exist" && return 1

    mv "$1" $TMPFILE
    mv "$2" "$1"
    mv $TMPFILE "$2"
}

# list current directory and search for a name
function lgrep() {
    [[ $# != 1 ]] && { echo -e "$FUNCNAME filename"; return 1; }
    ls -A | grep --color=auto -i "$1"
}

# Make your directories and files access rights sane.
function sanitize() { chmod -R u=rwX,g=rX,o= "$@"; }

function my_ip() # Get IP adress on ethernet.
{
    MY_IP=$(/sbin/ifconfig eth0 | awk '/inet/ { print $2 } ' |
      sed -e s/addr://)
    echo ${MY_IP:-"Not connected"}
}

function compress() {
    local usage
    usage="$FUNCNAME  fileOrDir  [zip|tar] "

    [[ $# == 1 || $# == 2 ]] || { echo -e "$usage"; return 1; }
    [[ -f "$1" || -d "$1" ]] || { echo -e "$usage"; return 1; }

    if [[ "$#" == 2 ]]; then
        case $2 in
            zip) makezip "$1" ;;
            tar) maketar "$1" ;;
            *) echo -e "$usage"; return 1;
            ;;
        esac
    else
        # default to tar
        maketar "$1"
    fi
}

# alias for compress
function pack() {
    compress $@
}

# Creates an archive (*.tar.gz) from given directory.
function maketar() { tar cvzf "${1%%/}.tar.gz"  "${1%%/}/"; }

# Create a ZIP archive of a file or folder.
function makezip() { zip -r "${1%%/}.zip" "$1" ; }

function extract() {
    if [[ -z "$1" ]] ; then
        echo "gimme filename plz"
        return 1
    elif [[ -f "$1" ]] ; then
      case "$1" in
        *.tar.bz2)   tar xjf $1     ;;
        *.tar.gz)    tar xzf $1     ;;
        *.bz2)       bunzip2 $1     ;;
        *.rar)       unrar e $1     ;;
        *.gz)        gunzip $1      ;;
        *.tar)       tar xf $1      ;;
        *.tbz2)      tar xjf $1     ;;
        *.tgz)       tar xzf $1     ;;
        *.zip)       unzip $1       ;;
        *.Z)         uncompress $1  ;;
        *.7z)        7z x $1        ;;
        *)     echo "'$1' cannot be extracted via extract()"
               return 1
        ;;
         esac
     else
         echo "'$1' is not a valid file"
         return 1
     fi
}

fontreset() {
    mkfontscale ~/.fonts
    mkfontdir ~/.fonts
    xset +fp ~/.fonts
    xset fp rehash
}

# TODO: rewrite this one, looks supid:
up() {
  local d=""
  limit=$1
  for ((i=1 ; i <= limit ; i++))
    do
      d=$d/..
    done
  d=$(echo $d | sed 's/^\///')
  if [ -z "$d" ]; then
    d=..
  fi
  cd $d
}

# clock - A bash clock that can run in your terminal window:
clock (){
    while true; do
        clear
        echo "======="
        echo " $(date +"%R") " # echo for padding
        echo "======="
        sleep 1
    done
}


