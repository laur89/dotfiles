#!/bin/bash
#
# good source to begin with: http://tldp.org/LDP/abs/html/sample-bashrc.html
# TODO: check this!: https://github.com/Cloudef/dotfiles-ng/blob/master/#ARCHCONFIG/shell/functions
#
#
# =====================================================================
# import common:
if [[ -f "$_SCRIPTS_COMMONS" && -r "$_SCRIPTS_COMMONS" ]]; then
    source "$_SCRIPTS_COMMONS"
else
    echo -e "\nError: common file \"$_SCRIPTS_COMMONS\" not found!! Many functions will be unusable!!!"
    # !do not exit, or you won't be able to open shell without the commons file being
    # present!
fi
# =====================================================================

# find files or dirs:
function ffind() {
    local SRC SRCDIR INAME_ARG IREGEX_ARG opt usage OPTIND file_type filetypeOptionCounter usegrep found_files_list parameterised_files_list file index
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
              IREGEX_ARG="-iregex" # TODO: deleteme?
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

    if [[ -n "$SRCDIR" ]]; then
        if [[ ! -d "$SRCDIR" ]]; then
            echo -e "provided directory to search from is not a directory. abort."
            return 1
        elif [[ "${SRCDIR:$(( ${#SRCDIR} - 1)):1}" != "/" ]]; then
            SRCDIR="${SRCDIR}/" # add trailing slash if missing; required for gnu find
        fi
    fi

    if [[ "$SRC" == *\.\** ]]; then
        echo -e "only use asterisks (*) for wildcards, not .*"
        return 1
    elif [[ "$SRC" == *\** ]]; then
        #echo -e "please don't use asterisks in filename pattern; searchterm is already padded with wildcards on both sides."
        #return 1
        usegrep="false"
    fi


    # grep is for coloring only:
    #find "${SRCDIR:-.}" $file_type "${INAME_ARG:--name}" '*'"$SRC"'*' | grep -i --color=auto "$SRC" 2>/dev/null
    if [[ "$usegrep" == "false" ]]; then
        find "${SRCDIR:-.}" $file_type "${INAME_ARG:--name}" '*'"$SRC"'*' 2>/dev/null # old; TODO: deleteme if new one proves better
        # TODO: try to make this one work:
        #find "${SRCDIR:-.}" $file_type "${IREGEX_ARG:--regex}" ".*${SRC}.*" -printf '%P\0' 2>/dev/null | xargs -r0 ls --color=auto -1d
    else
        find "${SRCDIR:-.}" $file_type "${INAME_ARG:--name}" '*'"$SRC"'*' 2>/dev/null | grep -i --color=auto "$SRC"
    fi

    ##### from here on, hackeroo begins:
    #found_files_list=()
    #parameterised_files_list=()

    ## TODO: store found files in args:
    #while IFS= read -r -d '' file; do
        #found_files_list+=( "$file" )
    #done <   <(find "${SRCDIR:-.}" $file_type "${INAME_ARG:--name}" '*'"$SRC"'*' -print0 2>/dev/null)

    #index=1
    #clear
    #for file in ${found_files_list[@]}; do
        #if [[ "$index" -le 20 ]]; then
            #parameterised_files_list+=( "\"$file\"" )
            #file="$index\t$file"
            #let index+=1
        #fi

        #if [[ "$usegrep" == "false" ]]; then
            #echo -e "$file"
        #else
            #echo -e "$file" | grep -i --color=auto "$SRC"
        #fi
    #done

    ##if [[ "${#parameterised_files_list[@]}" != 0 ]]; then
        ## TODO: handles filenames with spaces, but otherwise... dangerous:
        #echo -e "${parameterised_files_list[@]}"
    ##fi
}

# Find a file with a pattern in name (inside wd);
# essentially same as ffind(), but a bit simplified:
function ff() {
    find . -type f -iname '*'"$*"'*'  -ls
}

function ffindproc() {
    [[ -z "$1" ]] && { echo -e "process name required"; return 1; }
    # last grep for re-coloring:
    ps -ef | grep -i "$1" | grep -v '\bgrep\b' | grep -i --color=auto "$1"

    # TODO: add also exact match option?:
    #   grep '\$1\b'
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

    find . -size +${size}M -exec ls -s --block-size=M {} \; | sort -nr 2>/dev/null
}

# find  files smalles than x mb:
function ffindsmallerthan() {
    local size
    [[ -n "$1" ]] && size="$1" || size="1024"

    find . -size -${size}M -exec ls -s --block-size=M {} \; | sort -n 2>/dev/null
}

# mkdir and cd into it:
function mkcd() { mkdir -p "$@" && cd "$@"; }

function aptsearch() {
    [[ -z "$@" ]] && { echo -e "provide partial package name to search for."; return 1; }
    aptitude search "$@"
    #apt-cache search "$@"
}

function aptsrc() { aptsearch "$@"; } #alias

#  Find a pattern in a set of files and highlight them:
#+ (needs a recent version of egrep).
function ffstr() {
    local grepcase OPTIND usage opt
    OPTIND=1
    usage="$FUNCNAME: find string in files.
Usage: fstr [-i] \"pattern\" [filename pattern] "

    while getopts "i" opt; do
        case "$opt" in
           i) grepcase=" -i "
              shift $(( $OPTIND - 1 ))
              ;;
           *) echo "$usage";
              return 1
              ;;
        esac
    done

    if [[ "$#" -lt 1 ]] || [[ "$#" -gt 2 ]]; then
        echo "$usage"
        return 1;
    fi

    find . -type f -iname '*'"${2:-*}"'*' -print0 | \
        xargs -0 egrep --color=always -sn ${grepcase} "$1" 2>&- | more
}

function swap() {
    # Swap 2 files around, if they exist (from Uzi's bashrc):
    local TMPFILE file_size space_left_on_target i

    TMPFILE="/tmp/${FUNCNAME}_function_tmpFile.$RANDOM"

    count_params 2 $# equal || return 1
    [[ ! -e "$1" ]] && echo "${FUNCNAME}(): $1 does not exist" && return 1
    [[ ! -e "$2" ]] && echo "${FUNCNAME}(): $2 does not exist" && return 1
    [[ "$1" == "$2" ]] && echo "${FUNCNAME}(): source and destination cannot be the same" && return 1

    # check write perimssions:
    for i in "$TMPFILE" "$1" "$2"; do
        i="$(dirname "$i")"
        if [[ ! -w "$i" ]]; then
            err "$i doesn't have write permission. abort." "$FUNCNAME"
            return 1
        fi
    done

    # check if $1 fits into /tmp:
    file_size="$(get_size "$1")"
    space_left_on_target="$(space_left "$TMPFILE")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        echo -e "${FUNCNAME}(): $1 size is ${file_size}MB, but $(dirname "$TMPFILE") has only ${space_left_on_target}MB free space left. abort."
        return 1
    fi

    if ! mv "$1" "$TMPFILE"; then
        err "moving $1 to $TMPFILE failed. abort." "$FUNCNAME"
        return 1
    fi

    # check if $2 fits into $1:
    file_size="$(get_size "$2")"
    space_left_on_target="$(space_left "$1")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        echo -e "${FUNCNAME}(): $2 size is ${file_size}MB, but $(dirname "$1") has only ${space_left_on_target}MB free space left. abort."
        # undo:
        mv "$TMPFILE" "$1"
        return 1
    fi

    if ! mv "$2" "$1"; then
        err "moving $2 to $1 failed. abort." "$FUNCNAME"
        # undo:
        mv "$TMPFILE" "$1"
        return 1
    fi

    # check if $1 fits into $2:
    file_size="$(get_size "$TMPFILE")"
    space_left_on_target="$(space_left "$2")"
    if [[ "$file_size" -ge "$space_left_on_target" ]]; then
        echo -e "${FUNCNAME}(): $1 size is ${file_size}MB, but $(dirname "$2") has only ${space_left_on_target}MB free space left. abort."
        # undo:
        mv "$1" "$2"
        mv "$TMPFILE" "$1"
        return 1
    fi

    if ! mv "$TMPFILE" "$2"; then
        err "moving $1 to $2 failed. abort." "$FUNCNAME"
        # undo:
        mv "$1" "$2"
        mv "$TMPFILE" "$1"
        return 1
    fi
}

# list current directory and search for a file/dir by name:
function lgrep() {
    local SRC SRCDIR usage

    SRC="$1"
    SRCDIR="$2"
    usage="$FUNCNAME  name_to_grep [dir_to_look_from]"
    if [[ "$#" -lt 1 || "$#" -gt 2 || -z "$SRC" ]]; then
        echo -e "$usage"
        return 1;
    elif [[ -n "$SRCDIR" ]]; then
        if [[ ! -d "$SRCDIR" ]]; then
            echo -e "provided directory to list and grep from is not a directory. abort."
            echo -e "\n$usage"
            return 1
        elif [[ ! -r "$SRCDIR" ]]; then
            echo -e "provided directory to list and grep from is not readable. abort."
            return 1
        fi
    fi

    ls -lA "${SRCDIR:-.}" | grep --color=auto -i "$SRC"
    #[[ $# != 1 ]] && { echo -e "$FUNCNAME name_to_grep [dir_to_look_from]"; return 1; }

    #[[ -z "$@" ]] && { echo -e "$FUNCNAME filename_pattern"; return 1; }
    #ls -A | grep --color=auto -i "\'$@\'"
}

# Make your directories and files access rights sane.
# (sane as in rw for owner, r for group, none for others)
function sanitize() {
    [[ -z "$@" ]] && { echo -e "provide a file/dir name plz."; return 1; }
    [[ ! -e "$@" ]] && { echo -e "\"$@\" does not exist."; return 1; }
    chmod -R u=rwX,g=rX,o= "$@";
}

function sanitize_ssh() {
    local dir="$@"

    [[ -z "$dir" ]] && { echo -e "provide a file/dir name plz."; return 1; }
    [[ ! -e "$dir" ]] && { echo -e "\"$dir\" does not exist."; return 1; }

    chmod -R u=rwX,g=,o= "$dir";
}

function ssh_sanitize() { sanitize_ssh "$@"; } # alias for sanitize_ssh

function my_ip() { # Get internal & external ip addies:
    local internal_ip external_ip connected_interface

    connected_interface="$(find_connected_if)"

    if [[ -n "$connected_interface" ]]; then
        external_ip="$(dig +short myip.opendns.com @resolver1.opendns.com 2>/dev/null)"
        internal_ip="$(/sbin/ifconfig "$connected_interface" | awk '/inet/ { print $2 } ' | sed -e s/addr://)"
        echo "${internal_ip:-"Not connected"} @ $connected_interface"
        echo "${external_ip:-"Not connected"}"
        return 0
    fi

    echo "Not connected"
}

function myip() { my_ip; } # alias for my_ip
function whatsmyip() { my_ip; } # alias for my_ip

function compress() {
    local usage file type
    file="$1"
    type="$2"
    usage="$FUNCNAME  fileOrDir  [zip|tar|rar] "

    [[ $# -eq 1 || $# -eq 2 ]] || { echo -e "$usage"; return 1; }
    [[ -e "$file" ]] || { echo -e "$file doesn't exist.\n\n$usage"; return 1; }

    if [[ -n "$type" ]]; then
        case "$type" in
            zip) makezip "$file"
                ;;
            tar) maketar "$file"
                ;;
            rar) makerar "$file"
                ;;
            *) echo -e "$usage";
               return 1;
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

# helper wrapper for uncompressing archives. it uncompresses into new directory, which
# name is the same as the archive's, minus the file extension. this avoids the situations
# where gazillion files are being extracted into workin dir. note that if the dir
# already exists, then unpacking fails (since mkdir fails).
function extract() {
    local file="$1"
    local file_without_extension="${file%.*}"

    if [[ -z "$file" ]]; then
        echo "gimme file to extract plz."
        return 1
    elif [[ ! -r "$file" ]]; then
         echo "'$file' is not a valid file or read rights not granted."
         return 1
    fi

    case "$file" in
        *.tar.bz2)   file_without_extension="${file_without_extension%.*}" # because two extensions
                        mkdir "$file_without_extension" && tar xjf $file -C $file_without_extension
                        ;;
        *.tar.gz)    file_without_extension="${file_without_extension%.*}" # because two extensions
                        mkdir "$file_without_extension" && tar xzf $file -C $file_without_extension
                        ;;
        *.tar.xz)    file_without_extension="${file_without_extension%.*}" # because two extensions
                        mkdir "$file_without_extension" && tar xpvf $file -C $file_without_extension
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

    echo -e "extracted $file contents into $file_without_extension"
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
    local file device mountpoint cleaned_devicename usage
    file="$1"
    device="$2"

    cleaned_devicename="${device%/}" # strip trailing slash
    cleaned_devicename="${cleaned_devicename##*/}"  # strip everything before last slash(slash included)
    usage="$FUNCNAME  image.file  device"

    if [[ -z "$file" || -z "$device" || -z "$cleaned_devicename" ]]; then
        echo -e "either file or device weren't provided"
        echo -e "$usage"
        return 1;
    elif [[ ! -f "$file" ]]; then
        echo -e "$file is not a regular file"
        echo -e "$usage"
        return 1;
    elif [[ ! -e "$device" ]]; then
        echo -e "$device does not exist"
        echo -e "$usage"
        return 1;
    elif ! ls /dev | grep "\b$cleaned_devicename\b";then
        echo -e "$device does not exist in /dev"
        echo -e "$usage"
        return 1;
    #elif [[ "${cleaned_devicename:$(( ${#cleaned_devicename} - 1)):1}" =~ ^[0-9:]+$ ]]; then
        #echo -e "please don't provide partition, but a drive, e.g. /dev/sdh instad of /dev/sdh1"
        #echo -e "$usage"
        #return 1
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
            echo -e "something went wrong with unmounting."
            echo -e "please unmount the device and try again."
            return 1
        fi
        echo -e "...success."
    fi

    echo -e "Please provide sudo passwd for running dd:"
    sudo echo -e "Running dd, this might take a while..."
    sudo dd if="$file" of="$device" bs=4M
    sync
    #eject $device
}

#######################
## Setup github repo ##
#######################
function mkgit() {
   local GITHUB="Cloudef"
   local dir="$1"
   local gitname="$2"

   # check dir
   [[ -n "$dir" ]] || {
      echo "usage: mkgit <dir> [name]"
      return
   }

   # use dir name if, no gitname specified
   [[ -n "$gitname" ]] || gitname="$dir"
   [[ -d "$dir"     ]] || mkdir "$dir"

   # bail out, if already git repo
   [[ -d "$dir/.git" ]] && {
      echo "already a git repo: $dir"
      return
   }

   cd "$dir"
   git init || return
   touch README; git add README
   git commit -a -m 'inital setup - automated'
   git remote add origin "git@github.com:$GITHUB/$gitname.git"
   git push -u origin master
}

######################################
## Open file inside git tree on vim ##
######################################
vimo() {
   local match=
   local gtdir=
   local cwd=$PWD
   git ls-files &>/dev/null || return # test if git
   gtdir="$(git rev-parse --show-toplevel )"
   [[ "$cwd" != "$gtdir" ]] && pushd "$gtdir" &> /dev/null # git root
   [[ -n "$@" ]] && { match="$(git ls-files | grep "$@")"; } ||
                      match="$(git ls-files)"
   [[ $(echo "$match" | wc -l) -gt 1 ]] && match="$(echo "$match" | bemenu -i -l 20 -p "vim")"
   match="$gtdir/$match" # convert to absolute
   [[ "$cwd" != "$gtdir" ]] && popd &> /dev/null # go back
   [[ -f "$match" ]] || return
   vim "$match"
}

function sethometime() {
    timedatectl set-timezone Europe/Tallinn
}

function setesttime() { sethometime; }
function setestoniatime() { sethometime; }

function setgibtime() {
    timedatectl set-timezone Europe/Gibraltar
}

function setspaintime() {
    timedatectl set-timezone Europe/Madrid
}

########################
## Print window class ##
########################
xclass() {
   xprop |awk '
   /^WM_CLASS/{sub(/.* =/, "instance:"); sub(/,/, "\nclass:"); print}
   /^WM_NAME/{sub(/.* =/, "title:"); print}'
}

################
## Smarter CD ##
################
goto() {
   [[ -d "$1" ]] && { cd "$1"; } || cd "$(dirname "$1")";
}

####################
## Copy && Follow ##
####################
cpf() {
   cp "$@" && goto "$_";
}

####################
## Move && Follow ##
####################
mvf() {
   mv "$@" && goto "$_";
}

#####################################
## Take screenshot of main monitor ##
#####################################
shot() {
   local mon=$@
   local file="$HOME/shot-$(date +'%H:%M-%d-%m-%Y').png"
   [[ -n "$mon" ]] || mon=0
   ffcast -x $mon % scrot -g %wx%h+%x+%y "$file"
}

###################
## Capture video ##
###################
capture() {
   ffcast -w ffmpeg -f alsa -ac 2 -i hw:0,2 -f x11grab -s %s -i %D+%c -acodec pcm_s16le -vcodec huffyuv $@
}

##############################################
## Colored Find                             ##
## NOTE: Searches current tree recrusively. ##
##############################################
f() {
   find . -iregex ".*$@.*" -printf '%P\0' | xargs -r0 ls --color=auto -1d
}
