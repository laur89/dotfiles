# good source to begin with: http://tldp.org/LDP/abs/html/sample-bashrc.html
#
#
# =====================================================================
# find files or dirs:
function ffind() {
    local SRC SRCDIR INAME_ARG opt usage OPTIND file_type filetypeOptionCounter
    usage="$FUNCNAME: find files by name.
    Usage: $FUNCNAME [-i] [-f] [-d] [-l] \"fileName pattern\" [top_level_dir_to_search_from]
        -i  filename is case insensitive
        -f  search for regular files
        -d  search for directories
        -l  search for symbolic links"
    filetypeOptionCounter=0

    while getopts "ifdl" opt; do
        case "$opt" in
           i) INAME_ARG="-iname"
              shift $((OPTIND-1))
                ;;
           f | d | l) file_type="-type $opt"
              let filetypeOptionCounter+=1
              shift $((OPTIND-1))
                ;;
           *) echo -e "$usage"; return 1 ;;
        esac
    done

    SRC="$1"
    SRCDIR="$2"
    if [[ "$#" -lt 1 || "$#" -gt 2 || -z "$SRC" ]]; then
        echo -e "$usage"
        return 1;
    elif [[ "$filetypeOptionCounter" -gt 1 ]]; then
        echo -e "-f, -d and -l flags are exclusive.\n"
        echo -e "$usage"
        return 1
    fi

    find "${SRCDIR:-.}" $file_type "${INAME_ARG:--name}" '*'"$SRC"'*' 2>/dev/null
}

function ffindproc() {
    [[ -z "$1" ]] && { echo -e "process name required"; return 1; }
    # last grep for re-coloring:
    ps -ef | grep -i "$1" | grep -v '\bgrep\b' | grep -i --color=auto "$1"

    # TODO: add also exact match option?:
    #   grep '\$1\b'
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

    find . -type f -exec ls -s --block-size=M {} \; | sort -n -r | head -$itmesToShow 2>/dev/null
}

# find top 5/x smallest files:
function ffindtopsmall() {
    local itmesToShow
    [[ -n "$1" ]] && itmesToShow="$1" || itmesToShow="5"

    find . -type f -exec ls -s --block-size=K {} \; | sort -n | head -$itmesToShow 2>/dev/null
}

# find  files bigger than x mb:
function ffindbiggerthan() {
    local size
    [[ -n "$1" ]] && size="$1" || size="1024"

    find . -size +${size}M -exec ls -s --block-size=M {} \; | sort -nr  2>/dev/null
}

# find  files smalles than x mb:
function ffindsmallerthan() {
    local size
    [[ -n "$1" ]] && size="$1" || size="1024"

    find . -size -${size}M -exec ls -s --block-size=M {} \; | sort -n 2>/dev/null
}

#  Find a pattern in a set of files and highlight them:
#+ (needs a recent version of egrep).
function ffstr() {
    local grepcase OPTIND usage opt
    OPTIND=1
    usage="fstr: find string in files.
Usage: fstr [-i] \"pattern\" [\"filename pattern\"] "

    while getopts "i" opt; do
        case "$opt" in
           i) grepcase=" -i "
              shift $(( $OPTIND - 1 ))
              ;;
           *) echo "$usage"; return ;;
        esac
    done

    if [ "$#" -lt 1 ]; then
        echo "$usage"
        return;
    fi

    find . -type f -iname "${2:-*}" -print0 | \
        xargs -0 egrep --color=always -sn ${grepcase} "$1" 2>&- | more
}

function swap() {
    # Swap 2 files around, if they exist (from Uzi's bashrc):
    local TMPFILE="/tmp/swap_function_tmpFile.$RANDOM"

    [ $# -ne 2 ] && echo "swap: 2 arguments needed" && return 1
    [ ! -e "$1" ] && echo "swap: $1 does not exist" && return 1
    [ ! -e "$2" ] && echo "swap: $2 does not exist" && return 1

    mv "$1" $TMPFILE
    mv "$2" "$1"
    mv $TMPFILE "$2"
}

# list current directory and search for a name
function lgrep() {
    [[ $# != 1 ]] && { echo -e "$FUNCNAME name_to_grep"; return 1; }
    ls -lA | grep --color=auto -i "$1"
    #[[ -z "$@" ]] && { echo -e "$FUNCNAME filename_pattern"; return 1; }
    #ls -A | grep --color=auto -i "\'$@\'"
}

# Make your directories and files access rights sane.
function sanitize() { chmod -R u=rwX,g=rX,o= "$@"; }

function my_ip() { # Get IP adress on ethernet.
    local MY_IP=$(/sbin/ifconfig eth0 | awk '/inet/ { print $2 } ' |
      sed -e s/addr://)
    echo ${MY_IP:-"Not connected"}
}

function compress() {
    local usage file type
    file="$1"
    type="$2"
    usage="$FUNCNAME  fileOrDir  [zip|tar|rar] "

    [[ $# == 1 || $# == 2 ]] || { echo -e "$usage"; return 1; }
    [[ -e "$file" ]] || { echo -e "$file doesn't exist.\n\n$usage"; return 1; }

    if [[ -n "$type" ]]; then
        case "$type" in
            zip) makezip "$file"
                ;;
            tar) maketar "$file"
                ;;
            rar) makerar "$file"
                ;;
            *) echo -e "$usage"; return 1;
                ;;
        esac
    else
        # default to tar
        maketar "$file"
    fi
}

# alias for compress
function pack() { compress $@; }

# Creates an archive (*.tar.gz) from given directory.
function maketar() { tar cvzf "${1%%/}.tar.gz"  "${1%%/}/"; }

# Create a rar archive.
function makerar() { rar a -r -rr10 -m4 "${1%%/}.rar"  "${1%%/}/"; }

# Create a ZIP archive of a file or folder.
function makezip() { zip -r "${1%%/}.zip" "$1"; }

# alias for extract
function unpack() { extract $@; }

function extract() {
    local file="$1"
    local file_without_extension="${file%.*}"

    if [[ -z "$file" ]]; then
        echo "gimme file to extract plz."
        return 1
    elif [[ -f "$file" ]]; then
        case "$file" in
            *.tar.bz2)   file_without_extension="${file_without_extension%.*}"
                         mkdir "$file_without_extension" && tar xjf $file -C $file_without_extension
                         ;;
            *.tar.gz)    file_without_extension="${file_without_extension%.*}"
                         mkdir "$file_without_extension" && tar xzf $file -C $file_without_extension
                         ;;
            *.bz2)       bunzip2 -k $file
                         ;;
            *.rar)       mkdir "$file_without_extension" && unrar x $file ${file_without_extension}/
                         ;;
            *.gz)        gunzip -kd $file
                         ;;
            *.tar)       mkdir "$file_without_extension" && tar xf $file -C $file_without_extension
                         ;;
            *.tbz2)      mkdir "$file_without_extension" && tar xjf $file -C $file_without_extension
                         ;;
            *.tgz)       mkdir "$file_without_extension" && tar xzf $file -C $file_without_extension
                         ;;
            *.zip)       mkdir "$file_without_extension" && unzip $file -d $file_without_extension
                         ;;
                         # TODO these last 2 are unverified how and where they'd unpack:
            *.Z)         uncompress $file  ;;
            *.7z)        7z x $file        ;;
            *)           echo "'$file' cannot be extracted via  ${FUNCNAME}()"
                         return 1
                         ;;
        esac
     else
         echo "'$file' is not a valid file"
         return 1
     fi
}

fontreset() {
    fc-cache -fv
    mkfontscale ~/.fonts
    mkfontdir ~/.fonts
    xset +fp ~/.fonts
    xset fp rehash
}

# alias for fontreset:
resetfont() { fontreset; }

# TODO: rewrite this one, looks supid:
up() {
  local d=""
  local limit=$1
  for ((i=1 ; i <= limit ; i++)); do
      d="$d/.."
  done
  d="$(echo $d | sed 's/^\///')"
  [[ -z "$d" ]] && d=".."

  cd $d
}

# clock - A bash clock that can run in your terminal window:
clock() {
    while true; do
        clear
        echo "=========="
        echo " $(date +"%R:%S") " # echo for padding
        echo "=========="
        sleep 1
    done
}

xmlformat() {
    [[ -z "$@" ]] && { echo -e "$FUNCNAME  <filename>"; return 1; }
    xmllint --format $@ | vim  "+set foldlevel=99" -;
}

function xmlf() { xmlformat $@; } # alias for xmlformat;

function createUsbIso() {
    local file device mountpoint cleaned_devicename
    file="$1"
    device="$2"
    cleaned_devicename="${device%/}" # strip trailing slash
    cleaned_devicename="${cleaned_devicename##*/}"  # strip everything before last slash(slash included)

    if [[ -z "$file" || -z "$device" || -z "$cleaned_devicename" ]]; then
        echo -e "either file or device weren't provided"
        return 1;
    elif [[ ! -f "$file" ]]; then
        echo -e "$file is not a regular file"
        return 1;
    elif [[ ! -e "$device" ]]; then
        echo -e "$device does not exist"
        return 1;
    elif ! ls /dev | grep "\b$cleaned_devicename\b";then
        echo -e "$device does not exist in /dev"
        return 1;
    elif [[ "${device:$(( ${#device} - 1)):1}" =~ ^[0-9:]+$ ]]; then
        echo -e "please don't provide partition, but a drive, e.g. /dev/sdh instad of /dev/sdh1"
        return 1
    fi

    #echo "please provide passwd for running fdisk -l to confirm the selected device is the right one:"
    #sudo fdisk -l $device
    lsblk | grep --color=auto "$cleaned_devicename\|MOUNTPOINT"

    if ! confirm  "\nis selected device - $device - the correct one? (y/n)"; then
        return 1
    fi

    # find if device is mounted:
     #lsblk -o name,size,mountpoint /dev/sda
    mountpoint="$(lsblk -o mountpoint $device | sed -n 3p)"
    if [[ -n "$mountpoint" ]]; then
        echo -e "$device appears to be mounted at $mountpoint, trying to unmount..."
        if ! umount "$mountpoint"; then
            echo -e "something went wrong with unmounting... abort"
            return 1
        fi
        echo -e "...success."
    fi

    echo -e "Running dd, this might take a while..."
    sudo dd if="$file" of="$device" bs=4M
    sync
    #eject $device
}


#=================================
# utils
#
function confirm() {
    local msg yno
    msg="$1"

    while : ; do
        echo -e "$msg"
        read yno
        case $yno in
            [yY] | YEs | YES | Yes | yes )
                echo "Ok, continuing...";
                return 0
                ;;
            [nN] | NO | No | no )
                echo "Abort.";
                return 1
                ;;
            *)
                echo -e "Incorrect answer; try again."
                ;;
        esac
    done
}
