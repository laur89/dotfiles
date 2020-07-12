#!/bin/bash
# base version taken from https://github.com/rastasheep/dotfiles/blob/master/script/bootstrap
#
# Base installation script intended to be executed on freshly installed
# Debian testing(!) release netinstall installation.
#
# Note that this is very user-specific installation, which is largely based on the
# configuration & scripts pulled via the homeshick repositories defined in this scipt.
# If you're not familiar with homeshick, then some of the variables/concepts in this
# script might not be straight-forward (eg 'castle' is essentially a git repo managed
# by homeshick).
#
#------------------------
#---   Configuration  ---
#------------------------
readonly TMP_DIR='/tmp'
readonly CLANG_LLVM_LOC='http://releases.llvm.org/6.0.0/clang+llvm-6.0.0-x86_64-linux-gnu-debian8.tar.xz'  # http://llvm.org/releases/download.html;  https://apt.llvm.org/building-pkgs.php
readonly I3_REPO_LOC='https://www.github.com/Airblader/i3'            # i3-gaps
readonly I3_LOCK_LOC='https://github.com/PandorasFox/i3lock-color'    # i3lock-color
readonly I3_LOCK_FANCY_LOC='https://github.com/meskarune/i3lock-fancy'    # i3lock-fancy
readonly NERD_FONTS_REPO_LOC='https://github.com/ryanoasis/nerd-fonts'
readonly PWRLINE_FONTS_REPO_LOC='https://github.com/powerline/fonts'
readonly POLYBAR_REPO_LOC='https://github.com/polybar/polybar.git'    # polybar
readonly VIM_REPO_LOC='https://github.com/vim/vim.git'                # vim - yeah.
readonly NVIM_REPO_LOC='https://github.com/neovim/neovim.git'         # nvim - yeah.
readonly RAMBOX_REPO_LOC='https://github.com/ramboxapp/community-edition.git'  # closed source franz alt.
readonly KEEPASS_REPO_LOC='https://github.com/keepassx/keepassx.git'  # keepassX - open password manager forked from keepass project
readonly GOFORIT_REPO_LOC='https://github.com/mank319/Go-For-It.git'  # go-for-it -  T-O-D-O  list manager
readonly COPYQ_REPO_LOC='https://github.com/hluk/CopyQ.git'           # copyq - awesome clipboard manager
readonly SYNERGY_REPO_LOC='https://github.com/symless/synergy-core.git'    # synergy - share keyboard&mouse between computers on same LAN
readonly ORACLE_JDK_LOC='http://download.oracle.com/otn-pub/java/jdk/8u172-b11/a58eab1ec242421181065cdc37240b08/jdk-8u172-linux-x64.tar.gz'
#readonly ORACLE_JDK_LOC='http://download.oracle.com/otn-pub/java/jdk/10.0.1+10/fb4372174a714e6b8c52526dc134031e/jdk-10.0.1_linux-x64_bin.tar.gz'
                                                                          #       http://www.oracle.com/technetwork/java/javase/downloads/index.html
                                                                          # jdk8: http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html
                                                                          # jdk9: https://jdk9.java.net/  /  https://jdk9.java.net/download/
                                                                          # jdk10: http://www.oracle.com/technetwork/java/javase/downloads/jdk10-downloads-4416644.html
                                                                          # archive: http://www.oracle.com/technetwork/java/javase/archive-139210.html
readonly SKYPE_LOC='http://www.skype.com/go/getskype-linux-deb'       # https://www.skype.com/en/get-skype/
readonly JDK_LINK_LOC="/usr/local/jdk_link"      # symlink linking to currently active java installation
readonly JDK_INSTALLATION_DIR="/usr/local/javas" # dir containing all the installed java versions
readonly PRIVATE_KEY_LOC="$HOME/.ssh/id_rsa"
readonly SHELL_ENVS="$HOME/.bash_env_vars"       # location of our shell vars; expected to be pulled in via homesick;
                                                 # note that contents of that file are somewhat important, as some
                                                 # (script-related) configuration lies within.
readonly NFS_SERVER_SHARE='/data'            # default node to share over NFS
readonly SSH_SERVER_SHARE='/data'            # default node to share over SSH

readonly BUILD_DOCK='deb-build-box'              # name of the build container
readonly DEB_STABLE=buster                   # current _stable_ release codename
#------------------------
#--- Global Variables ---
#------------------------
IS_SSH_SETUP=0       # states whether our ssh keys are present. 1 || 0
__SELECTED_ITEMS=''  # only select_items() *writes* into this one.
PROFILE=''
MODE=''              # which operation mode we're in; will be defined as 1 || 0 || 2, needs to be first set to empty!
GIT_RLS_LOG=''       # log of all installed/fetched assets from git releases/latest page; will be defined later on;
declare -a PACKAGES_IGNORED_TO_INSTALL=()  # list of all packages that failed to install during the setup
declare -a PACKAGES_FAILED_TO_INSTALL=()
LOGGING_LVL=0                   # execution logging level (full install mode logs everything);
                                # don't set log level too soon; don't want to persist bullshit.
                                # levels are currently 0, 1 and 10; 0 being no logging, 1 being the lowest (from lvl 1 to 9 only execute() errors are logged)
NON_INTERACTIVE=0               # whether script's running non-attended
EXECUTION_LOG="$HOME/installation-execution-$(date +%d-%b-%y--%R).log" \
        || readonly EXECUTION_LOG="$HOME/installation-exe.log"  # do not create logfile here! otherwise cleanup()
                                                                # picks it up and reports of its existence, opening
                                                                # up for false positives.
SYSCTL_CHANGED=0       # states whether sysctl config got changed

#------------------------
#--- Global Constants ---
#------------------------
readonly BASE_DATA_DIR="/data"  # try to keep this value in sync with equivalent defined in $SHELL_ENVS;
readonly BASE_PROGS_DIR="$BASE_DATA_DIR/progs"
readonly BASE_DEPS_LOC="$BASE_PROGS_DIR/deps"             # hosting stuff like homeshick, bash-git-prompt...
readonly BASE_BUILDS_DIR="$BASE_PROGS_DIR/custom_builds"  # hosts our built progs and/or their .deb packages;
readonly BASE_HOMESICK_REPOS_LOC="$BASE_DEPS_LOC/homesick/repos"
readonly COMMON_DOTFILES="$BASE_HOMESICK_REPOS_LOC/dotfiles"
readonly COMMON_PRIVATE_DOTFILES="$BASE_HOMESICK_REPOS_LOC/private-common"
readonly SOME_PACKAGE_IGNORED_EXIT_CODE=199
PRIVATE_CASTLE=''  # installation specific private castle location (eg for 'work' or 'personal')

readonly SELF="${0##*/}"

declare -A COLORS=(
    [RED]=$'\033[0;31m'
    [GREEN]=$'\033[0;32m'
    [BLUE]=$'\033[0;34m'
    [PURPLE]=$'\033[0;35m'
    [CYAN]=$'\033[0;36m'
    [WHITE]=$'\033[0;37m'
    [YELLOW]=$'\033[0;33m'
    [OFF]=$'\033[0m'
    [BOLD]=$'\033[1m'
)
readonly NPMRC_BAK="$TMP_DIR/npmrc.bak.$RANDOM"  # temp location where we _might_ move our npmrc to for the duration of this script;
#-----------------------
#---    Functions    ---
#-----------------------


print_usage() {

    printf "${SELF}:  install/provision system.
        usage: $SELF [-NFSU]  work|personal
    "
}


validate_and_init() {

    # need to define PRIVATE_CASTLE here, as otherwise 'single-step' mode of this
    # script might fail. be sure the repo names are in sync with the repos actually
    # pulled in fetch_castles().
    case "$PROFILE" in
        work)
            if [[ "$__ENV_VARS_LOADED_MARKER_VAR" == loaded ]] && ! __is_work; then
                confirm "you selected [${COLORS[RED]}${COLORS[BOLD]}$PROFILE${COLORS[OFF]}] profile on non-work machine; sure you want to continue?" || exit
            fi

            PRIVATE_CASTLE="$BASE_HOMESICK_REPOS_LOC/work_dotfiles"
            ;;
        personal)
            if [[ "$__ENV_VARS_LOADED_MARKER_VAR" == loaded ]] && __is_work; then
                confirm "you selected [${COLORS[RED]}${COLORS[BOLD]}$PROFILE${COLORS[OFF]}] profile on work machine; sure you want to continue?" || exit
            fi

            PRIVATE_CASTLE="$BASE_HOMESICK_REPOS_LOC/personal-dotfiles"
            ;;
        *)
            err "unsupported PROFILE [$PROFILE]"
            print_usage
            exit 1 ;;
    esac

    check_connection || { err "no internet connection. abort."; exit 1; }

    report "private castle defined as [$PRIVATE_CASTLE]"

    # verify we have our key(s) set up and available:
    if is_ssh_key_available; then
        _sanitize_ssh
        IS_SSH_SETUP=1
    else
        report "ssh keys not present at the moment, be prepared to enter user & passwd for private git repos."
        report "(unless they're pulled from elsewhere)"
        IS_SSH_SETUP=0
    fi

    # ask for the admin password upfront:
    report "enter sudo password:"
    sudo -v || { clear; err "is user in sudoers file? is sudo installed? if not, then [su && apt-get install sudo]"; exit 2; }
    clear

    # keep-alive: update existing `sudo` time stamp
    while true; do sudo -n true; sleep 30; kill -0 "$$" || exit; done 2>/dev/null &

    # we need to make sure our system clock is roughly right; otherwise stuff like apt-get might start failing:
    #is_native || execute "rdate -s tick.greyware.com"
    #is_native || execute "tlsdate -V -n -H encrypted.google.com"
    update_clock || exit 1
}


# check dependencies required for this installation script
check_dependencies() {
    local dir prog perms exec_to_pkg

    readonly perms=764  # can't be 777, nor 766, since then you'd be unable to ssh into;
    exec_to_pkg=(
        [gpg]=gnupg
    )

    for prog in \
            git cmp wc wget curl tar unzip atool \
            realpath dirname basename head tee \
            gpg mktemp file date alien id html2text \
                ; do
        if ! command -v "$prog" >/dev/null; then
            report "[$prog] not installed yet, installing..."
            [[ -n "${exec_to_pkg[$prog]}" ]] && prog=${exec_to_pkg[$prog]}

            install_block "$prog" || { err "unable to install required prog [$prog] this script depends on. abort."; exit 1; }
            report "...done"
        fi
    done

    # TODO: need to create dev/ already here, since both dotfiles and private-common
    # either point to it, or point at something in it; not a good solution.
    # better finalise scripts and move them to the public/common dotfiles repo.
    #
    #
    # verify required dirs are existing and have $perms perms:
    for dir in \
            "$BASE_DATA_DIR" \
            "$BASE_DATA_DIR/dev" \
                ; do
        if ! [[ -d "$dir" ]]; then
            if confirm -d Y "[$dir] mountpoint/dir does not exist; simply create a directory instead? (answering 'no' aborts script)"; then
                execute "sudo mkdir '$dir'" || { err "unable to create [$dir] directory. abort."; exit 1; }
            else
                err "expected [$dir] to be already-existing dir. abort"
                exit 1
            fi
        fi

        execute "sudo chown $USER:$USER -- '$dir'" || { err "unable to change [$dir] ownership to [$USER:$USER]. abort."; exit 1; }
        execute "sudo chmod $perms -- '$dir'" || { err "unable to change [$dir] permissions to [$perms]. abort."; exit 1; }
    done
}


setup_udev() {
    local udev_src udev_target file tmpfile

    readonly udev_src="$COMMON_PRIVATE_DOTFILES/backups/udev"
    readonly udev_target='/etc/udev/rules.d/'
    readonly tmpfile="$TMP_DIR/udev_setup-$RANDOM"

    if ! [[ -d "$udev_target" ]]; then
        err "[$udev_target] is not a dir; skipping udev file(s) installation."
        return 1
    elif ! [[ -d "$udev_src" ]]; then
        err "[$udev_src] is not a dir; skipping udev file(s) installation."
        return 1
    fi

    is_dir_empty "$udev_src" && return 0
    for file in "$udev_src/"*; do
        execute "cp -- '$file' '$tmpfile'" || return 1
        execute "sed --follow-symlinks -i 's/{USER_PLACEHOLDER}/$USER/g' $tmpfile" || return 1
        execute "sudo mv -- '$tmpfile' $udev_target/" || { err "moving [$tmpfile] to [$udev_src] failed"; return 1; }
    done
}


# TODO: shouldn't it be COMMON_PRIVATE_DOTFILES/backups?
setup_systemd() {
    local sysd_src sysd_target file tmpfile

    readonly sysd_src="$PRIVATE_CASTLE/backups/systemd"
    readonly sysd_target='/etc/systemd/system'
    readonly tmpfile="$TMP_DIR/sysd_setup-$RANDOM"

    if ! [[ -d "$sysd_target" ]]; then
        err "[$sysd_target] is not a dir; skipping systemd file(s) installation."
        return 1
    elif ! [[ -d "$sysd_src" ]]; then
        err "[$sysd_src] is not a dir; skipping systemd file(s) installation."
        return 1
    fi

    is_dir_empty "$sysd_src" && return 0
    for file in "$sysd_src/"*; do
        execute "cp -- '$file' '$tmpfile'" || return 1
        execute "sed --follow-symlinks -i 's/{USER_PLACEHOLDER}/$USER/g' $tmpfile" || return 1
        execute "sudo mv -- '$tmpfile' $sysd_target/" || { err "moving [$tmpfile] to [$sysd_src] failed"; return 1; }
    done
}


setup_hosts() {
    local hosts_file_dest file current_hostline tmpfile

    readonly hosts_file_dest="/etc"
    readonly tmpfile="$TMP_DIR/hosts"
    readonly file="$PRIVATE_CASTLE/backups/hosts"

    _extract_current_hostname_line() {
        local file current

        readonly file="$1"
        #current="$(grep '\(127\.0\.1\.1\)\s\+\(.*\)\s\+\(\w\+\)' $file)"
        readonly current="$(grep "$HOSTNAME" "$file")"
        if ! is_single "$current"; then
            err "[$file] contained either more or less than 1 line(s) containing our hostname. check manually."
            return 1
        fi

        echo "$current"
        return 0
    }

    if ! [[ -d "$hosts_file_dest" ]]; then
        err "[$hosts_file_dest] is not a dir; skipping hosts file installation."
        return 1
    fi

    if [[ -f "$file" ]]; then
        [[ -f "$hosts_file_dest/hosts" ]] || { err "system hosts file is missing!"; return 1; }
        current_hostline="$(_extract_current_hostname_line $hosts_file_dest/hosts)" || return 1
        execute "cp -- '$file' '$tmpfile'" || { err; return 1; }
        execute "sed --follow-symlinks -i 's/{HOSTS_LINE_PLACEHOLDER}/$current_hostline/g' $tmpfile" || { err; return 1; }

        backup_original_and_copy_file --sudo "$tmpfile" "$hosts_file_dest"
        execute "rm -- '$tmpfile'"
    else
        err "expected configuration file at [$file] does not exist; won't install it."
        return 1
    fi

    unset _extract_current_hostname_line
}


setup_sudoers() {
    local sudoers_dest file tmpfile

    readonly sudoers_dest="/etc/sudoers.d"
    readonly tmpfile="$TMP_DIR/sudoers-$RANDOM"
    readonly file="$COMMON_PRIVATE_DOTFILES/backups/sudoers"

    if ! [[ -d "$sudoers_dest" ]]; then
        err "[$sudoers_dest] is not a dir; skipping sudoers file installation."
        return 1
    elif ! [[ -f "$file" ]]; then
        err "expected configuration file at [$file] does not exist; won't install it."
        return 1
    fi

    execute "cp -- '$file' '$tmpfile'" || return 1
    execute "sed --follow-symlinks -i 's/{USER_PLACEHOLDER}/$USER/g' $tmpfile" || return 1
    execute "sudo chown root:root $tmpfile" || return 1
    execute "sudo chmod 0440 $tmpfile" || return 1

    execute "sudo mv -f -- $tmpfile $sudoers_dest/sudoers" || return 1
}


# https://wiki.debian.org/UnattendedUpgrades for unattended-upgrades setup
setup_apt() {
    local apt_dir file

    readonly apt_dir='/etc/apt'

    [[ -d "$apt_dir" ]] || { err "[$apt_dir] is not a dir; skipping apt conf installation."; return 1; }

    for file in \
            sources.list \
            preferences \
            apt.conf \
                ; do
        file="$COMMON_DOTFILES/backups/apt_conf/$file"

        [[ -f "$file" ]] || { err "expected configuration file at [$file] does not exist; won't install it."; continue; }
        backup_original_and_copy_file --sudo "$file" "$apt_dir"
    done

    # copy to apt.conf.d/:
    for file in \
            02periodic \
                ; do
        file="$COMMON_DOTFILES/backups/apt_conf/$file"

        [[ -f "$file" ]] || { err "expected configuration file at [$file] does not exist; won't install it."; continue; }
        execute "sudo cp -- '$file' '$apt_dir/apt.conf.d'"
    done

    retry 2 "sudo apt-get --yes update" || err "apt-get update failed with $?"
}


setup_crontab() {
    local cron_dir weekly_crondir tmpfile file i

    readonly cron_dir="/etc/cron.d"  # where crontab will be installed at
    readonly tmpfile="$TMP_DIR/crontab"
    readonly file="$PRIVATE_CASTLE/backups/crontab"
    readonly weekly_crondir='/etc/cron.weekly'

    if ! [[ -d "$cron_dir" ]]; then
        err "[$cron_dir] is not a dir; skipping crontab installation."
        return 1
    fi

    if [[ -f "$file" ]]; then
        execute "cp -- '$file' '$tmpfile'" || return 1
        execute "sed --follow-symlinks -i 's/{USER_PLACEHOLDER}/$USER/g' $tmpfile" || return 1
        #backup_original_and_copy_file --sudo "$tmpfile" "$cron_dir"  # don't create backup - dont wanna end up with 2 crontabs
        execute "sudo cp -- '$tmpfile' '$cron_dir'"

        execute "rm -- '$tmpfile'"
    else
        err "expected configuration file at [$file] does not exist; won't install it."
    fi

    # install weekly scripts:
    if ! [[ -d "$weekly_crondir" ]]; then
        err "[$weekly_crondir] is not a dir; skipping weekly scripts installation."
    else
        for i in \
                dnsmasq-hosts-update \
                    ; do
            i="$BASE_DATA_DIR/dev/scripts/$i"
            if ! [[ -f "$i" ]]; then
                err "[$i] does not exist, can't dump in $weekly_crondir..."
                continue
            fi

            create_link --sudo "$i" "${weekly_crondir}/"
        done
    fi
}


# pass '-s' or '--sudo' as first arg to execute as sudo
#
backup_original_and_copy_file() {
    local sudo file dest_dir filename i old_suffixes

    [[ "$1" == -s || "$1" == --sudo ]] && { shift; readonly sudo=sudo; }
    readonly file="$1"          # full path of the file to be copied
    readonly dest_dir="${2%/}"  # full path of the destination directory to copy to

    readonly filename="$(basename -- "$file")"

    $sudo test -d "$dest_dir" || { err "second arg [$dest_dir] was not a dir" "$FUNCNAME"; return 1; }
    [[ "$dest_dir" == *.d ]] && err "sure we want to be backing up in [$dest_dir]?" "$FUNCNAME"

    # back up the destination file, if it already exists and differs from new content:
    if $sudo test -e "$dest_dir/$filename" && ! $sudo cmp -s "$file" "$dest_dir/$filename"; then
        declare -a old_suffixes

        # collect older .orig files' suffixes and increment latest value for the new file:
        while IFS= read -r -d $'\0' i; do
            i="${i##*.}"
            is_digit "$i" && old_suffixes+=("$i")
        done < <($sudo find -L "$dest_dir/" -maxdepth 1 -mindepth 1 -type f -regextype posix-extended -regex ".*/${filename}\.orig\.[0-9]+$" -print0)

        i=0  # default
        if [[ ${#old_suffixes[@]} -gt 0 ]]; then
            i="$(printf '%d\n' "${old_suffixes[@]}" | sort -rn | head -n1)"  # take largest (ie latest) suffix value
            is_digit "$i" || { err "last found suffix was not digit: [$i]; setting suffix to RANDOM"; i="$RANDOM"; } && (( i++ ))  # note (( i++ )) errors if i=0, but it increments just fine
        fi

        execute "$sudo cp -- '$dest_dir/$filename' '$dest_dir/${filename}.orig.$i'"  # TODO: should we mv instead?
    fi

    execute "$sudo cp -- '$file' '$dest_dir'"
}


# !! note the importance of optional trailing slash for $install_dir param;
clone_or_pull_repo() {
    local user repo install_dir hub

    readonly user="$1"
    readonly repo="$2"
    install_dir="$3"  # if has trailing / then $repo won't be appended, eg pass './' to clone to PWD
    readonly hub=${4:-'github.com'}  # OPTIONAL; defaults to github.com;

    [[ -z "$install_dir" ]] && { err "need to provide target directory." "$FUNCNAME"; return 1; }
    [[ "$install_dir" != */ ]] && install_dir="${install_dir}/$repo"

    if ! [[ -d "$install_dir/.git" ]]; then
        execute "git clone --recursive -j8 https://$hub/$user/${repo}.git $install_dir" || return 1

        execute "pushd $install_dir" || return 1
        execute "git remote set-url origin git@${hub}:$user/${repo}.git" || { popd; return 1; }
        execute "git remote set-url --push origin git@${hub}:$user/${repo}.git" || { popd; return 1; }
        execute "popd"
    elif is_ssh_key_available; then
        execute "pushd $install_dir" || return 1
        execute "git pull" || { popd; return 1; }  # TODO: retry?
        execute "git submodule update --init --recursive" || { popd; return 1; }  # make sure to pull submodules
        execute "popd"
    fi
}


install_nfs_server() {
    local nfs_conf client_ip share

    readonly nfs_conf="/etc/exports"

    confirm "wish to install & configure nfs server?" || return 1
    is_laptop && ! confirm "you're on laptop; sure you wish to install nfs server?" && return 1

    install_block 'nfs-kernel-server' || { err "unable to install nfs-kernel-server. aborting nfs server install/config."; return 1; }

    if ! [[ -f "$nfs_conf" ]]; then
        err "[$nfs_conf] is not a file; skipping nfs server installation."
        return 1
    fi

    while true; do
        confirm "$(report "add ${client_ip:+another }client IP for the exports list?")" || break

        read -r -p "enter client ip: " client_ip

        [[ "$client_ip" =~ ^[0-9.]+$ ]] || { err "not a valid ip: [$client_ip]"; continue; }

        read -r -p "enter share to expose (leave blank to default to [$NFS_SERVER_SHARE]): " share

        share=${share:-"$NFS_SERVER_SHARE"}
        [[ "$share" != /* ]] && { err "share needs to be defined as full path."; continue; }
        [[ -d "$share" ]] || { err "[$share] is not a valid dir."; continue; }

        # TODO: automate multi client/range options:
        # entries are basically:         directory machine1(option11,option12) machine2(option21,option22)
        # to set a range of ips, then:   directory 192.168.0.0/255.255.255.0(ro)
        if ! grep -q "${share}.*${client_ip}" "$nfs_conf"; then
            report "adding [$share] for $client_ip to $nfs_conf"
            execute "echo $share ${client_ip}\(rw,sync,no_subtree_check\) | sudo tee --append $nfs_conf > /dev/null"
        else
            report "an entry for exposing [$share] to $client_ip is already present in $nfs_conf"
        fi
    done

    # exports the shares:
    execute 'sudo exportfs -ra' || err

    return 0
}


install_nfs_client() {
    local fstab mountpoint nfs_share default_mountpoint server_ip prev_server_ip
    local mounted_shares used_mountpoints

    readonly fstab="/etc/fstab"
    readonly default_mountpoint="/mnt/nfs"

    declare -a mounted_shares=()
    declare -a used_mountpoints=()

    confirm "wish to install & configure nfs client?" || return 1

    install_block 'nfs-common' || { err "unable to install nfs-common. aborting nfs client install/config."; return 1; }

    [[ -f "$fstab" ]] || { err "[$fstab] does not exist; cannot add fstab entry!"; return 1; }

    while true; do
        confirm "$(report "add ${server_ip:+another }nfs server entry to fstab?")" || break

        read -r -p "enter server ip${prev_server_ip:+ (leave blank to default to [$prev_server_ip])}: " server_ip
        [[ -z "$server_ip" ]] && server_ip="$prev_server_ip"
        [[ "$server_ip" =~ ^[0-9.]+$ ]] || { err "not a valid ip: [$server_ip]"; continue; }

        read -r -p "enter local mountpoint to mount nfs share to (leave blank to default to [$default_mountpoint]): " mountpoint
        [[ -z "$mountpoint" ]] && mountpoint="$default_mountpoint"
        list_contains "$mountpoint" "${used_mountpoints[*]}" && { report "selected mountpoint [$mountpoint] has already been used for previous definition"; continue; }
        create_mountpoint "$mountpoint" || continue

        read -r -p "enter remote share to mount (leave blank to default to [$NFS_SERVER_SHARE]): " nfs_share
        [[ -z "$nfs_share" ]] && nfs_share="$NFS_SERVER_SHARE"
        list_contains "${server_ip}${nfs_share}" "${mounted_shares[*]}" && { report "selected [${server_ip}:${nfs_share}] has already been used for previous definition"; continue; }
        [[ "$nfs_share" != /* ]] && { err "remote share needs to be defined as full path."; continue; }

        if ! grep -q "${server_ip}:${nfs_share}.*${mountpoint}" "$fstab"; then
            report "adding [${server_ip}:$nfs_share] mounting to [$mountpoint] in $fstab"
            execute "echo ${server_ip}:${nfs_share} ${mountpoint} nfs noauto,x-systemd.automount,x-systemd.mount-timeout=10,_netdev,x-systemd.device-timeout=10,timeo=14,rsize=8192,wsize=8192 0 0 \
                    | sudo tee --append $fstab > /dev/null"
        else
            err "an nfs share entry for [${server_ip}:${nfs_share}] in $fstab already exists."
        fi

        prev_server_ip="$server_ip"
        used_mountpoints+=("$mountpoint")
        mounted_shares+=("${server_ip}${nfs_share}")
    done

    return 0
}


# as for security, look:
#  - https://linux-audit.com/audit-and-harden-your-ssh-configuration/
#  - https://www.debian.org/doc/manuals/securing-debian-howto/
#  - https://wiki.debian.org/SELinux/Setup
#  - http://adeptus-mechanicus.com/codex/sudoctrl/sudoctrl.html
#  - https://vincent.bernat.ch/en/blog/2017-linux-bridge-isolation
#  - https://github.com/CISOfy/lynis - security audit script
install_ssh_server() {
    local sshd_confdir config banner

    readonly sshd_confdir="/etc/ssh"
    readonly config="$COMMON_PRIVATE_DOTFILES/backups/sshd_config"
    readonly banner="$COMMON_PRIVATE_DOTFILES/backups/ssh_banner"

    confirm "wish to install & configure ssh server?" || return 1
    is_laptop && ! confirm "you're on laptop; sure you wish to install ssh server?" && return 1

    install_block 'openssh-server' || { err "unable to install openssh-server. aborting sshd install/config."; return 1; }

    [[ -d "$sshd_confdir" ]] || { err "[$sshd_confdir] is not a dir; skipping sshd conf installation."; return 1; }

    # install sshd config:
    if [[ -f "$config" ]]; then
        backup_original_and_copy_file --sudo "$config" "$sshd_confdir"
    else
        err "expected configuration file at [$config] does not exist; aborting sshd configuration."
        return 1
    fi

    # install ssh banner:
    if [[ -f "$banner" ]]; then
        backup_original_and_copy_file --sudo "$banner" "$sshd_confdir"
    else
        err "expected sshd banner file at [$banner] does not exist; won't install it."
        #return 1  # don't return, it's just a banner.
    fi

    execute "sudo systemctl start sshd.service"
    #execute "systemctl enable sshd.service"  # TODO: this is not required, is it?

    return 0
}


create_mountpoint() {
    local mountpoint

    readonly mountpoint="$1"

    [[ -z "$mountpoint" ]] && { err "cannot pass empty mountpoint arg to $FUNCNAME"; return 1; }

    [[ -d "$mountpoint" ]] || execute "sudo mkdir -p -- '$mountpoint'" || { err "couldn't create [$mountpoint]"; return 1; }
    [[ -d "$mountpoint" ]] || { err "mountpoint [$mountpoint] is not a dir"; return 1; }  # sanity
    execute "sudo chmod 777 -- '$mountpoint'" || { err; return 1; }

    return 0
}


install_sshfs() {
    local fuse_conf mountpoint default_mountpoint fstab server_ip remote_user ssh_port sel_ips_to_user
    local prev_server_ip used_mountpoints mounted_shares ssh_share identity_file

    readonly fuse_conf="/etc/fuse.conf"
    readonly default_mountpoint="/mnt/ssh"
    readonly fstab="/etc/fstab"
    readonly ssh_port=443
    readonly identity_file="$HOME/.ssh/id_rsa_only_for_server_connect"
    declare -a mounted_shares=()
    declare -a used_mountpoints=()

    declare -A sel_ips_to_user

    confirm "wish to install and configure sshfs?" || return 1
    [[ -f "$fstab" ]] || { err "[$fstab] does not exist; cannot add fstab entry!"; return 1; }
    if ! [[ -f "$identity_file" ]]; then
        confirm "[$identity_file] ssh key does not exist; still continue?" || return 1
    fi
    install_block 'sshfs' || { err "unable to install sshfs. aborting sshfs install/config."; return 1; }

    # note that 'user_allow_other' uncommenting makes sense only if our related fstab
    # entry has the 'allow_other' opt:
    if ! [[ -r "$fuse_conf" && -f "$fuse_conf" ]]; then
        err "[$fuse_conf] is not readable; cannot uncomment '#user_allow_other' prop in it."
    elif grep -q '^#user_allow_other' "$fuse_conf"; then  # hasn't been uncommented yet
        execute "sudo sed -i --follow-symlinks 's/#user_allow_other/user_allow_other/g' $fuse_conf"
        [[ $? -ne 0 ]] && { err "uncommenting '#user_allow_other' in [$fuse_conf] failed"; return 2; }
    elif grep -q 'user_allow_other' "$fuse_conf"; then
        true  # do nothing; already uncommented, all good;
    else
        err "[$fuse_conf] appears not to contain config value 'user_allow_other'; check manually what's up; not aborting"
    fi

    while true; do
        confirm "$(report "add ${prev_server_ip:+another }sshfs entry to fstab?")" || break

        read -r -p "enter server ip${prev_server_ip:+ (leave blank to default to [$prev_server_ip])}: " server_ip
        [[ -z "$server_ip" ]] && server_ip="$prev_server_ip"
        [[ "$server_ip" =~ ^[0-9.]+$ ]] || { err "not a valid ip: [$server_ip]"; continue; }

        read -r -p "enter remote user to log in as (leave blank to default to your local user, [$USER]): " remote_user
        [[ -z "$remote_user" ]] && remote_user="$USER"

        read -r -p "enter local mountpoint to mount sshfs share to (leave blank to default to [$default_mountpoint]): " mountpoint
        [[ -z "$mountpoint" ]] && mountpoint="$default_mountpoint"
        list_contains "$mountpoint" "${used_mountpoints[*]}" && { report "selected mountpoint [$mountpoint] has already been used for previous definition"; continue; }
        create_mountpoint "$mountpoint" || continue

        read -r -p "enter remote share to mount (leave blank to default to [$SSH_SERVER_SHARE]): " ssh_share
        [[ -z "$ssh_share" ]] && ssh_share="$SSH_SERVER_SHARE"
        list_contains "${server_ip}${ssh_share}" "${mounted_shares[*]}" && { report "selected [${server_ip}:${ssh_share}] has already been used for previous definition"; continue; }
        [[ "$ssh_share" != /* ]] && { err "remote share needs to be defined as full path."; continue; }

        if ! grep -q "${remote_user}@${server_ip}:${ssh_share}.*${mountpoint}" "$fstab"; then
            report "adding [${server_ip}:$ssh_share] mounting to [$mountpoint] in $fstab..."
            # TODO: you might want to add 'default_permissions,uid=USER_ID_N,gid=USER_GID_N' to the mix as per https://wiki.archlinux.org/index.php/SSHFS:
            execute "echo ${remote_user}@${server_ip}:${ssh_share} $mountpoint fuse.sshfs port=${ssh_port},noauto,x-systemd.automount,_netdev,users,idmap=user,follow_symlinks,IdentityFile=${identity_file},allow_other,reconnect 0 0 \
                    | sudo tee --append $fstab > /dev/null"

            sel_ips_to_user["$server_ip"]="$remote_user"
        else
            err "an ssh share entry for [${server_ip}:${ssh_share}] in $fstab already exists."
        fi

        prev_server_ip="$server_ip"
        used_mountpoints+=("$mountpoint")
        mounted_shares+=("${server_ip}${ssh_share}")
    done

    #report "sudo ssh-ing to entered IPs [${!sel_ips_to_user[*]}], so our root would have the remote in the /root/.ssh/known_hosts ..."
    #report "select [yes] if asked whether to add entry to known hosts"

    for server_ip in "${!sel_ips_to_user[@]}"; do
        remote_user="${sel_ips_to_user[$server_ip]}"
        #report "testing ssh connection to ${remote_user}@${server_ip}..."
        #execute "sudo ssh -p ${ssh_port} -o ConnectTimeout=7 ${remote_user}@${server_ip} echo ok"

        if [[ -f "${identity_file}.pub" ]]; then
            if confirm "try to ssh-copy-id public key to [$server_ip]?"; then
                # install public key on ssh server:
                # TODO: shouldn't we employ $ssh_port here?
                ssh-copy-id -i "${identity_file}.pub" ${remote_user}@${server_ip} || err "ssh-copy-id to [${remote_user}@${server_ip}] failed with $?"
            fi
        fi

        # add $server_ip to root's known_hosts, if not already present:
        check_progs_installed  ssh-keygen ssh-keyscan || { err "some necessary ssh tools not installed, check that out"; return 1; }
        if [[ -z "$(sudo ssh-keygen -F "$server_ip")" ]]; then
            execute "sudo ssh-keyscan -H '$server_ip' >> /root/.ssh/known_hosts" || err "adding host [$server_ip] to /root/.ssh/known_hosts failed"
        fi
        # note2: also could circumvent known_hosts issue by adding 'StrictHostKeyChecking=no'; it does add a bit insecurity tho
    done

    return 0
}


#function setup_ssh_config() {
    #local ssh_confdir ssh_conf

    #ssh_confdir="/etc/ssh"
    #ssh_conf="$COMMON_DOTFILES/backups/ssh_config"

    ## install ssh config:
    ######################
    #if ! [[ -d "$ssh_confdir" ]]; then
        #err "$ssh_confdir is not a dir; skipping ssh conf installation."
        #return 1
    #fi

    #if [[ -f "$ssh_conf" ]]; then
        #backup_original_and_copy_file --sudo "$ssh_conf" "$ssh_confdir"
    #else
        #err "expected ssh configuration file at [$ssh_conf] does not exist; aborting ssh (client) configuration."
        #return 1
    #fi

    #return 0
#}


# "deps" as in git repos/py modules et al our system setup depends on;
# if equivalent is avaialble at deb repos, its installation should be
# moved to  install_from_repo()
#
# aslo, should we extract python modules out?
install_deps() {
    _install_tmux_deps() {
        local dir plugins_dir

        readonly plugins_dir="$HOME/.tmux/plugins"

        if ! [[ -d "$plugins_dir/tpm" ]]; then
            clone_or_pull_repo "tmux-plugins" "tpm" "$plugins_dir"
            report "don't forget to install tmux plugins by running <prefix + I> in tmux later on." && sleep 4
        elif ! is_dir_empty "$plugins_dir"; then
            # update all the tmux plugins, including the plugin manager itself:
            execute "pushd $plugins_dir" || return 1

            for dir in *; do
                if [[ -d "$dir" ]]; then
                    execute "pushd $dir" || continue
                    is_git && execute "git pull"
                    execute "popd"
                fi
            done

            execute "popd"
        fi
    }

    _install_laptop_deps() {  # TODO: does this belong in install_deps()?
        is_laptop || return

        __install_wifi_driver() {
            local wifi_info rtl_driver

            __install_rtlwifi_new() {  # custom driver installation, pulling from github
                local repo tmpdir

                repo="https://github.com/lwfinger/rtlwifi_new.git"

                report "installing rtlwifi_new for card [$rtl_driver]"
                tmpdir="$TMP_DIR/realtek-driver-${RANDOM}"
                execute "git clone -j8 $repo $tmpdir" || return 1
                execute "pushd $tmpdir" || return 1
                execute "make clean" || return 1

                #create_deb_install_and_store realtek-wifi-github  # doesn't work with checkinstall
                execute "sudo make install"

                execute "popd"
                execute "sudo rm -rf -- $tmpdir"
            }

            # consider using   lspci -vnn | grep -A5 WLAN | grep -qi intel
            readonly wifi_info="$(sudo lshw -C network | grep -iA 5 'Wireless interface')"

            if grep -iq 'vendor.*Intel' <<< "$wifi_info"; then
                report "we have intel wifi; installing intel drivers..."
                install_block "firmware-iwlwifi"
            elif grep -iq 'vendor.*Realtek' <<< "$wifi_info"; then
                report "we have realtek wifi; installing realtek drivers..."
                rtl_driver="$(grep -Poi '\s+driver=\Krtl\w+(?=\s+\S+)' <<< "$(sudo lshw -C network)")"
                is_single "$rtl_driver" || { err "realtek driver from lshw output was [$rtl_driver]"; return 1; }

                #install_block "firmware-realtek"                     # either from repos, or...
                __install_rtlwifi_new; unset __install_rtlwifi_new    # ...this

                # add config to solve the intermittent disconnection problem; YMMV (https://github.com/lwfinger/rtlwifi_new/issues/126):
                #     note: 'ips, swlps, fwlps' are power-saving options.
                #     note2: ant_sel=1 or =2
                #execute "echo options $rtl_driver ant_sel=1 fwlps=0 | sudo tee /etc/modprobe.d/$rtl_driver.conf"
                execute "echo options $rtl_driver ant_sel=1 msi=1 ips=0 | sudo tee /etc/modprobe.d/$rtl_driver.conf"

                execute "sudo modprobe -r $rtl_driver" || { err "unable removing modprobe [$rtl_driver]"; return 1; }
                execute "sudo modprobe $rtl_driver" || { err "unable adding modprobe [$rtl_driver]; make sure secure boot is turned off in BIOS"; return 1; }
            else
                err "can't detect Intel nor Realtek wifi; what card do you have?"
            fi
        }

        # xinput is for input device configuration; see  https://wiki.archlinux.org/index.php/Libinput
        install_block '
            libinput-tools
            xinput
            blueman
            xfce4-power-manager
        '

        # batt output (requires spark):
        clone_or_pull_repo "laur89" "Battery" "$BASE_DEPS_LOC"  # https://github.com/laur89/Battery
        create_link "${BASE_DEPS_LOC}/Battery/battery" "$HOME/bin/battery"

        __install_wifi_driver && sleep 5; unset __install_wifi_driver  # keep last, as this _might_ restart wifi kernel module
    }

    # bash-git-prompt:
    clone_or_pull_repo "magicmonty" "bash-git-prompt" "$BASE_DEPS_LOC"
    create_link "${BASE_DEPS_LOC}/bash-git-prompt" "$HOME/.bash-git-prompt"

    # git-flow-completion:  # https://github.com/bobthecow/git-flow-completion
    clone_or_pull_repo "bobthecow" "git-flow-completion" "$BASE_DEPS_LOC"
    create_link "${BASE_DEPS_LOC}/git-flow-completion" "$HOME/.git-flow-completion"

    # bars (as in bar-charts) in shell:
    #  note: see also https://github.com/sindresorhus/sparkly-cli
    clone_or_pull_repo "holman" "spark" "$BASE_DEPS_LOC"  # https://github.com/holman/spark
    create_link "${BASE_DEPS_LOC}/spark/spark" "$HOME/bin/spark"

    # imgur uploader:
    clone_or_pull_repo "ram-on" "imgurbash2" "$BASE_DEPS_LOC"  # https://github.com/ram-on/imgurbash2
    create_link "${BASE_DEPS_LOC}/imgurbash2/imgurbash2" "$HOME/bin/imgurbash2"

    # imgur uploader 2:
    clone_or_pull_repo "tangphillip" "Imgur-Uploader" "$BASE_DEPS_LOC"  # https://github.com/tangphillip/Imgur-Uploader
    create_link "${BASE_DEPS_LOC}/Imgur-Uploader/imgur" "$HOME/bin/imgur-uploader"

    # fuzzy file finder/command completer etc:
    clone_or_pull_repo "junegunn" "fzf" "$BASE_DEPS_LOC"  # https://github.com/junegunn/fzf
    create_link "${BASE_DEPS_LOC}/fzf" "$HOME/.fzf"
    execute "$HOME/.fzf/install --all" || err "could not install fzf"

    # fasd - shell navigator similar to autojump:
    # note we're using whjvenyl's fork instead of original clvv, as latter
    # was last updated 2015 (orig: https://github.com/clvv/fasd.git)
    clone_or_pull_repo "whjvenyl" "fasd" "$BASE_DEPS_LOC"  # https://github.com/whjvenyl/fasd
    create_link "${BASE_DEPS_LOC}/fasd/fasd" "$HOME/bin/fasd"

    # maven bash completion:
    clone_or_pull_repo "juven" "maven-bash-completion" "$BASE_DEPS_LOC"  # https://github.com/juven/maven-bash-completion
    create_link "${BASE_DEPS_LOC}/maven-bash-completion" "$HOME/.maven-bash-completion"

    # vifm filetype icons: https://github.com/cirala/vifm_devicons.git
    clone_or_pull_repo "cirala" "vifm_devicons" "$BASE_DEPS_LOC"
    create_link "${BASE_DEPS_LOC}/vifm_devicons" "$HOME/.vifm_devicons"

    # diff-so-fancy - human-readable git diff:  # https://github.com/so-fancy/diff-so-fancy
    if execute "wget -O $TMP_DIR/d-s-f 'https://raw.githubusercontent.com/so-fancy/diff-so-fancy/master/third_party/build_fatpack/diff-so-fancy'"; then
        git config core.pager | grep -q diff-so-fancy || err "git config core.pager not set for diff-so-fancy; configure it"
        test -s $TMP_DIR/d-s-f && execute "mv -- $TMP_DIR/d-s-f $HOME/bin/diff-so-fancy && chmod +x $HOME/bin/diff-so-fancy" || err "fetched diff-so-fancy file is null"
    else
        err "diff-so-fancy fetch failed"
    fi

    # forgit - fzf-fueled git tool:  # https://github.com/wfxr/forgit
    if ! execute "wget -O $HOME/.forgit 'https://raw.githubusercontent.com/wfxr/forgit/master/forgit.plugin.zsh'"; then
        err "forgit fetch failed"
    fi

    # dynamic colors loader: (TODO: deprecated by pywal right?)
    #clone_or_pull_repo "sos4nt" "dynamic-colors" "$BASE_DEPS_LOC"  # https://github.com/sos4nt/dynamic-colors
    #create_link "${BASE_DEPS_LOC}/dynamic-colors" "$HOME/.dynamic-colors"
    #create_link "${BASE_DEPS_LOC}/dynamic-colors/bin/dynamic-colors" "$HOME/bin/dynamic-colors"

    # base16 shell colors:
    #clone_or_pull_repo "chriskempson" "base16-shell" "$BASE_DEPS_LOC"  # https://github.com/chriskempson/base16-shell
    #create_link "${BASE_DEPS_LOC}/base16-shell" "$HOME/.config/base16-shell"

    # tmux plugin manager:
    _install_tmux_deps; unset _install_tmux_deps

    # conscript (scala apps distribution manager):  # http://www.foundweekends.org/conscript/setup.html
                                                    # TODO: check https://github.com/foundweekends/conscript/issues/124 (reason we exec with -i)
    execute -i 'wget https://raw.githubusercontent.com/foundweekends/conscript/master/setup.sh -O - | sh'

    # install scala apps (requires conscript):
    if [[ "$PATH" == *conscript* ]]; then  # (assuming conscript is installed and executable is on our PATH)
        execute 'cs foundweekends/giter8'  # https://github.com/foundweekends/giter8
                                           #   note its conf is in bash_env_vars
    else
        err "[conscript] not on \$PATH; if it's the initial installation, then just re-run ${FUNCNAME}()"
    fi

    # sdkman:  # https://sdkman.io/
    execute "curl -s 'https://get.sdkman.io' | bash"  # TODO depends whether win or linux


    py_install wheel    # https://pypi.org/project/wheel/  (wheel is py packaging standard; TODO: as per https://stackoverflow.com/a/56504270/1803648, this pkg should soon be provided by default)

    # TODO: following are not deps, are they?:
    # git-playback; install _either_ of these two (ie either from jianli or mmozuras):
    py_install git-playback   # https://github.com/jianli/git-playback

    # whatportis: query applications' default port:
    py_install whatportis     # https://github.com/ncrocfer/whatportis

    # git-playback:   # https://github.com/mmozuras/git-playback
    #clone_or_pull_repo "mmozuras" "git-playback" "$BASE_DEPS_LOC"
    #create_link "${BASE_DEPS_LOC}/git-playback/git-playback.sh" "$HOME/bin/git-playback-sh"


    # this needs apt-get install  python-imaging ?:
    py_install img2txt.py    # https://github.com/hit9/img2txt  (for ranger)
    py_install ueberzug      # https://github.com/seebye/ueberzug  (display images in terminal)
    py_install scdl          # https://github.com/flyingrub/scdl (soundcloud downloader)
    py_install rtv           # https://github.com/michael-lazar/rtv (reddit reader)  # TODO: active development has ceased
    py_install tldr          # https://github.com/tldr-pages/tldr-python-client [tldr (short manpages) reader]
                                                                                      #   note its conf is in bash_env_vars
    #py_install maybe         # https://github.com/p-e-w/maybe (check what command would do)
    py_install httpstat       # https://github.com/reorx/httpstat  curl wrapper to get request stats (think chrome devtools)
    py_install tendo          # https://github.com/pycontribs/tendo  py utils, eg singleton (lockfile management)
    py_install awscli         # https://docs.aws.amazon.com/en_pv/cli/latest/userguide/install-linux.html#install-linux-awscli

    # colorscheme generator:
    # see also complementing script @ https://github.com/dylanaraps/bin/blob/master/wal-set
    py_install pywal          # https://github.com/dylanaraps/pywal/wiki/Installation

    # consider also perl alternative @ https://github.com/pasky/speedread
    #rb_install speed_read  # https://github.com/sunsations/speed_read  (spritz-like terminal speedreader)  TODO: install appears to be timing out? or at least takes forever;
    rb_install gist        # https://github.com/defunkt/gist  (pastebinit for gists)

    py_install update-conf.py # https://github.com/rarylson/update-conf.py  (generate config files from conf.d dirs)

    # rbenv & ruby-build: {                             # https://github.com/rbenv/rbenv-installer
    #   ruby-build recommended deps (https://github.com/rbenv/ruby-build/wiki):
    install_block '
        autoconf
        bison
        build-essential
        libssl-dev
        libyaml-dev
        libreadline6-dev
        zlib1g-dev
        libncurses5-dev
        libffi-dev
        libgdbm6
        libgdbm-dev
    '
    execute 'curl -fsSL https://github.com/rbenv/rbenv-installer/raw/master/bin/rbenv-installer | bash'
    # note rbenv-doctor can be ran to verify installation:  $ curl -fsSL https://github.com/rbenv/rbenv-installer/raw/master/bin/rbenv-doctor | bash
    # }

    # some py deps requred by scripts:  # TODO: should we not install these via said scripts' requirements.txt file instead?
    py_install exchangelib vobject icalendar arrow
    # note: if exchangelib fails with something like
                #In file included from src/kerberos.c:19:0:
                #src/kerberosbasic.h:17:27: fatal error: gssapi/gssapi.h: No such file or directory
                ##include <gssapi/gssapi.h>
                                            #^
                #compilation terminated.
                #error: command 'x86_64-linux-gnu-gcc' failed with exit status 1
    # you'd might wanna install  libkrb5-dev (or whatever ver avail at the time)   https://github.com/ecederstrand/exchangelib/issues/404

    # flashfocus - flash window when focus changes  https://github.com/fennerm/flashfocus
    install_block 'libxcb-render0-dev'
    py_install flashfocus


    # work deps:  # TODO remove block?
    #if [[ "$PROFILE" == work ]]; then
        ## cx toolbox/vagrant env deps:  # TODO: deprecate? at least try to find what is _really_ required.
        #rb_install \
            #puppet puppet-lint bundler nokogiri builder
    #fi

    # laptop deps:
    is_native && is_laptop && _install_laptop_deps; unset _install_laptop_deps


    # install npm_modules:
    # https://github.com/FredrikNoren/ungit
    # https://github.com/dominictarr/JSON.sh
    # https://github.com/sindresorhus/speed-test
    # https://github.com/sindresorhus/fast-cli
    # https://github.com/riyadhalnur/weather-cli
    #
    execute "$NPM_PRFX npm install -g \
        ungit \
        JSON.sh \
        speed-test \
        fast-cli \
        weather-cli \
    "
}


setup_dirs() {
    local dir

    # create dirs:
    for dir in \
            $HOME/bin \
            $HOME/.npm-packages \
            $BASE_DATA_DIR/.calendars \
            $BASE_DATA_DIR/.calendars/work \
            $BASE_DATA_DIR/.rsync \
            $BASE_DATA_DIR/.repos \
            $BASE_DATA_DIR/tmp \
            $BASE_DATA_DIR/vbox_vms \
            $BASE_PROGS_DIR \
            $BASE_DEPS_LOC \
            $BASE_BUILDS_DIR \
            $BASE_DATA_DIR/dev \
            $BASE_DATA_DIR/mail \
            $BASE_DATA_DIR/mail/work \
            $BASE_DATA_DIR/mail/personal \
            $BASE_DATA_DIR/Downloads \
            $BASE_DATA_DIR/Downloads/Transmission \
            $BASE_DATA_DIR/Downloads/Transmission/incomplete \
            $BASE_DATA_DIR/Videos \
            $BASE_DATA_DIR/Music \
            $BASE_DATA_DIR/Documents \
                ; do
        if ! [[ -d "$dir" ]]; then
            report "[$dir] does not exist, creating..."
            execute "mkdir -- $dir"
        fi
    done

    # create logdir ($CUSTOM_LOGDIR comes from $SHELL_ENVS):
    if ! [[ -d "$CUSTOM_LOGDIR" ]]; then
        [[ -z "$CUSTOM_LOGDIR" ]] && { err "[CUSTOM_LOGDIR] env var was missing. abort."; sleep 5; return 1; }

        report "[$CUSTOM_LOGDIR] does not exist, creating..."
        execute "sudo mkdir -- $CUSTOM_LOGDIR"
        execute "sudo chmod 777 -- $CUSTOM_LOGDIR"
    fi
}


install_homesick() {

    clone_or_pull_repo "andsens" "homeshick" "$BASE_HOMESICK_REPOS_LOC" || return 1

    # add the link, since homeshick is not installed in its default location (which is $HOME):
    create_link "$BASE_DEPS_LOC/homesick" "$HOME/.homesick" || return 1
}


# homeshick specifics
#
# pass   -H   flag to set up path to our githooks
clone_or_link_castle() {
    local castle user hub homesick_exe opt OPTIND set_hooks

    while getopts "H" opt; do
        case "$opt" in
            H) set_hooks=1 ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    readonly castle="$1"
    readonly user="$2"
    readonly hub="$3"  # domain of the git repo, ie github.com/bitbucket.org...

    readonly homesick_exe="$BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick"

    [[ -z "$castle" || -z "$user" || -z "$hub" ]] && { err "either user, repo or castle name were missing"; sleep 2; return 1; }
    [[ -e "$homesick_exe" ]] || { err "expected to see homesick script @ [$homesick_exe], but didn't. skipping cloning|linking castle [$castle]"; return 1; }

    if [[ -d "$BASE_HOMESICK_REPOS_LOC/$castle" ]]; then
        if is_ssh_key_available; then
            report "[$castle] already exists; pulling & linking"
            retry 3 "$homesick_exe pull $castle" || { err "pulling castle [$castle] failed with $?"; return 1; }  # TODO: should we exit here?
        else
            report "[$castle] already exists; linking..."
        fi

        execute "$homesick_exe link $castle" || { err "linking castle [$castle] failed with $?"; return 1; }  # TODO: should we exit here?
    else
        report "cloning ${castle}..."
        if is_ssh_key_available; then
            retry 3 "$homesick_exe clone git@${hub}:$user/${castle}.git" || { err "cloning castle [$castle] failed with $?"; return 1; }
        else
            # note we clone via https, not ssh:
            retry 3 "$homesick_exe clone https://${hub}/$user/${castle}.git" || { err "cloning castle [$castle] failed with $?"; return 1; }

            # change just cloned repo remote from https to ssh:
            execute "pushd $BASE_HOMESICK_REPOS_LOC/$castle" || return 1
            execute "git remote set-url origin git@${hub}:$user/${castle}.git"
            execute "popd"
        fi

        # note this assumes $castle repo has a .githooks symlink at its root that points to dir that contains the actual hooks!
        if [[ "$set_hooks" -eq 1 ]]; then
            execute "pushd $BASE_HOMESICK_REPOS_LOC/$castle" || { err "pushd failure - git hook installation failed!"; return 1; }
            execute 'git config core.hooksPath .githooks' || err "git hook installation failed!"
            execute "popd"
        fi
    fi

    # just in case verify whether our ssh keys got cloned in:
    if [[ "$IS_SSH_SETUP" -eq 0 ]] && is_ssh_key_available; then
        _sanitize_ssh
        IS_SSH_SETUP=1
    fi
}


fetch_castles() {
    local castle user hub

    # common private:
    clone_or_link_castle -H private-common layr bitbucket.org || { err "failed pulling private dotfiles; it's required!"; return 1; }

    # common public castles:
    clone_or_link_castle -H dotfiles laur89 github.com || { err "failed pulling public dotfiles; it's required!"; return 1; }

    # !! if you change private repos, make sure you update PRIVATE_CASTLE definitions @ validate_and_init()!
    case "$PROFILE" in
        work)
            export GIT_SSL_NO_VERIFY=1
            local host user repo u
            host=git.nonprod.williamhill.plc
            user=laliste
            repo="$(basename -- "$PRIVATE_CASTLE")"
            if clone_or_link_castle -H "$repo" "$user" "$host"; then
                pushd "$PRIVATE_CASTLE"
                for u in "git@$host:$user/$repo.git"  "git@github.com:laur89/work-dots-mirror.git"; do
                    if ! grep -iq "pushurl.*$u" .git/config; then  # need if-check as 'set-url --add' is not idempotent
                        git remote set-url --add --push origin "$u"
                    fi
                done
                popd
            else
                err "failed pulling work dotfiles; won't abort"
            fi

            unset GIT_SSL_NO_VERIFY
            ;;
        personal)
            clone_or_link_castle -H "$(basename -- "$PRIVATE_CASTLE")" layr bitbucket.org || err "failed pulling personal dotfiles; won't abort"
            ;;
        *)
            err "unexpected \$PROFILE [$PROFILE]"; exit 1
            ;;
    esac

    #while true; do
        #if confirm "$(report 'want to clone another castle?')"; then
            #echo -e "enter git repo domain (eg [github.com], [bitbucket.org]):"
            #read -r hub

            #echo -e "enter username:"
            #read -r user

            #echo -e "enter castle name (repo name, eg [dotfiles]):"
            #read -r castle

            #execute "clone_or_link_castle $castle $user $hub"
        #else
            #break
        #fi
    #done
}


# check whether ssh key(s) were pulled with homeshick; if not, offer to create one:
verify_ssh_key() {

    [[ "$IS_SSH_SETUP" -eq 1 ]] && return 0
    err "expected ssh keys to be there after cloning repo(s), but weren't."

    if confirm -d N "do you wish to generate set of ssh keys?"; then
        generate_key
    else
        return
    fi

    if is_ssh_key_available; then
        IS_SSH_SETUP=1
    else
        err "didn't find the key at [$PRIVATE_KEY_LOC] after generating keys."
    fi
}


# note: as homesick (and some of its managed castles) are paramount for the whole
# setup logic, then script should abort if this function returns non-0.
setup_homesick() {
    local https_castles

    install_homesick || return 1
    fetch_castles || return 1

    # just in case check if any of the castles are still tracking https instead of ssh:
    readonly https_castles="$($BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick list | grep '\bhttps://\b')"
    if [[ -n "$https_castles" ]]; then
        report "fyi, these homesick castles are for some reason still tracking https remotes:"
        report "$https_castles"
    fi
}


# creates symlink of our personal '.bash_env_vars' to /etc
setup_global_env_vars() {
    local global_env_var_loc real_file_locations file

    declare -ar real_file_locations=(
        "$SHELL_ENVS"
    )
    readonly global_env_var_loc='/etc'  # so our env vars would have user-agnostic location as well;
                                        # that location will be used by various scripts.

    for file in "${real_file_locations[@]}"; do
        if ! [[ -f "$file" ]]; then
            err "[$file] does not exist. can't link it to ${global_env_var_loc}/"
            continue
        fi

        create_link --sudo "$file" "${global_env_var_loc}/"
    done
}


# force private assets' (such as netrc) permissions private (only accessible by its owner);
# note this list would be best kept in sync with files in our common post-checkout githook;
setup_private_asset_perms() {
    local i

    for i in \
            ~/.netrc \
            "$GNUPGHOME" \
                ; do
        [[ -e "$i" ]] || { err "expected to find [$i], but it doesn't exist; is it normal?"; continue; }
        [[ -d "$i" && "$i" != */ ]] && i+='/'
        find -L "$i" -maxdepth 25 \( -type f -o -type d \) -exec chmod 'u=rwX,g=,o=' -- '{}' \+
    done
}


setup_global_prompt() {
    local global_bashrc ps1

    readonly global_bashrc="/etc/bash.bashrc"
    readonly ps1='PS1="\[\033[0;37m\]\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[\[\033[0;31m\]\342\234\227\[\033[0;37m\]]\342\224\200\")[$(if [[ ${EUID} -eq 0 ]]; then echo "\[\033[0;33m\]\u\[\033[0;37m\]@\[\033\[\033[0;31m\]\h"; else echo "\[\033[0;33m\]\u\[\033[0;37m\]@\[\033[0;96m\]\h"; fi)\[\033[0;37m\]]\342\224\200[\[\033[0;32m\]\w\[\033[0;37m\]]\n\[\033[0;37m\]\342\224\224\342\224\200\342\224\200\342\225\274 \[\033[0m\]"  # own_def_marker'

    if ! sudo test -f $global_bashrc; then
        err "[$global_bashrc] doesn't exist; cannot add PS1 (prompt) definition to it!"
        return 1
    fi

    # just in case delete previous global PS1 def:
    execute "sudo sed -i --follow-symlinks '/^PS1=.*# own_def_marker$/d' \"$global_bashrc\""
    execute "echo '$ps1' | sudo tee --append $global_bashrc > /dev/null"

    #if ! sudo grep -q '^PS1=.*# own_def_marker$' $global_bashrc; then
        ## PS1 hasn't been defined yet:
        #execute "echo '$ps1' | sudo tee --append $global_bashrc > /dev/null"
    #fi
}


# setup system config files (the ones not living under $HOME, ie not managed by homesick)
# has to be invoked AFTER homeschick castles are cloned/pulled!
#
# note that this block overlaps logically a bit with post_install_progs_setup() (not really tho, as p_i_p_s() requires specific progs to be installed beforehand)
setup_config_files() {

    setup_apt
    setup_crontab
    setup_sudoers
    #setup_ssh_config   # better stick to ~/.ssh/config, rite?  # TODO
    setup_hosts
    setup_systemd
    is_native && setup_udev
    setup_global_env_vars
    setup_private_asset_perms
    setup_global_prompt
    is_native && swap_caps_lock_and_esc
    override_locale_time
}


install_acpi_events() {
    local event_file  system_acpi_eventdir  src_eventfiles_dir

    readonly system_acpi_eventdir="/etc/acpi/events"
    readonly src_eventfiles_dir="$COMMON_DOTFILES/backups/acpi_event_triggers"

    if ! [[ -d "$system_acpi_eventdir" ]]; then
        err "[$system_acpi_eventdir] dir does not exist; acpi event triggers won't be installed"
        return 1
    elif ! [[ -d "$src_eventfiles_dir" ]]; then
        err "[$src_eventfiles_dir] dir does not exist; acpi event triggers won't be installed (since trigger files cannot be found)"
        return 1
    fi

    for event_file in $src_eventfiles_dir/* ; do
        if [[ -f "$event_file" ]]; then
            execute "sudo cp -- $event_file $system_acpi_eventdir"
        fi
    done

    return 0
}


# network manager wrapper script;
install_nm_dispatchers() {
    local dispatchers nm_wrapper_dest f

    readonly nm_wrapper_dest="/etc/NetworkManager/dispatcher.d"
    readonly dispatchers=(
        "$BASE_DATA_DIR/dev/scripts/network_manager_SSID_checker_wrapper.sh"
    )

    if ! [[ -d "$nm_wrapper_dest" ]]; then
        err "[$nm_wrapper_dest] dir does not exist; network-manager dispatcher script(s) won't be installed"
        return 1
    fi

    for f in "${dispatchers[@]}"; do
        if ! [[ -f "$f" ]]; then
            err "[$f] does not exist; this netw-manager dispatcher won't be installed"
            continue
        fi

        # do not create .orig backup!
        execute "sudo cp -- '$f' $nm_wrapper_dest/"
    done
}


source_shell_conf() {
    local i

    # source own functions and env vars:
    if [[ "$__ENV_VARS_LOADED_MARKER_VAR" != "loaded" ]]; then
        for i in \
                "$SHELL_ENVS" \
                    ; do  # note the sys-specific env_vars_overrides! also make sure env_vars are fist to be imported;
            if [[ -r "$i" ]]; then
                source "$i"
            fi
        done

        if [[ -d "$HOME/.bash_env_vars_overrides" ]]; then
            for i in "$HOME/.bash_env_vars_overrides/"*; do
                [[ -f "$i" ]] && source "$i"
            done
        fi

        unset i
    fi

    if ! type __BASH_FUNS_LOADED_MARKER > /dev/null 2>&1; then
        # skip common funs import - we don't need 'em, and might cause conflicts:
        #[[ -r "$HOME/.bash_functions" ]] && source "$HOME/.bash_functions"

        if [[ -d "$HOME/.bash_funs_overrides" ]]; then
            for i in "$HOME/.bash_funs_overrides/"*; do
                [[ -f "$i" ]] && source "$i"
            done

            unset i
       fi
    fi
}


setup() {
    setup_homesick || { err "homesick setup failed; as homesick is necessary, script will exit"; exit 1; }
    verify_ssh_key
    source_shell_conf  # so we get our env vars after dotfiles are pulled in

    if [[ -z "$GIT_RLS_LOG" ]]; then
        [[ -n "$CUSTOM_LOGDIR" ]] && readonly GIT_RLS_LOG="$CUSTOM_LOGDIR/git-releases-install.log" || GIT_RLS_LOG="$TMP_DIR/.git-rls-log.tmp"  # log of all installed debs/binaries from git releases/latest page
    fi

    setup_dirs  # has to come after $SHELL_ENVS sourcing so the env vars are in place
    setup_config_files
    setup_additional_apt_keys_and_sources

    [[ "$PROFILE" == work && -s ~/.npmrc ]] && mv -- ~/.npmrc "$NPMRC_BAK"  # work npmrc might define private registry
    # following npm hack is superseded by temporarily getting rid of ~/.npmrc above:
    #if [[ "$MODE" -eq 1 && "$PROFILE" == work && -z "$NODE_EXTRA_CA_CERTS" ]]; then
        #NPM_PRFX+=' NODE_TLS_REJECT_UNAUTHORIZED=0'  # certs might've not been init'd yet; NODE_TLS_REJECT_UNAUTHORIZED not working, so far only '$npm config set strict-ssl' false has had any effect
        #local _cert="$TMP_DIR/wh_${RANDOM}.crt"
        #curl -s --fail --connect-timeout 2 --max-time 4 --insecure --output "$_cert" \
                #https://git.nonprod.williamhill.plc/profiles/profile_wh_sslcerts/raw/master/files/wh_chain_sc1wnpresc03.crt \
                #&& export NODE_EXTRA_CA_CERTS=$_cert
    #fi
}


# logic to pull current time from a pre-configured site, and set it as our system
# clock time if ours deviates from it by some margin.
# This is needed on vbox systems during install-time, the time can deviate quite a bit.
update_clock() {
    local src remote_time t diff

    src='https://www.google.com/'  # external source whose http headers to extract time from
    remote_time="$(curl --fail --insecure -X HEAD --silent --head "$src" 2>&1 \
            | grep -ioP '^date:\s*\K.*' | { read -r t; date +%s -d "$t"; })"

    is_digit "$remote_time" || { err "resolved remote [$src] time was not digit: [$remote_time]"; return 1; }
    diff="$(( $(date +%s) - remote_time ))"

    if [[ "${diff#-}" -gt 30 ]]; then
        report "system time diff to remote source is [$diff] - updating clock..."
        # IIRC, input format to date -s here is important:
        execute "sudo date -s '$(date -d @$remote_time '+%Y-%m-%d %H:%M:%S')'" || { err "setting system time failed w/ $?"; return 1; }
    fi

    return 0
}


# note apt-key adv needs gnupg to be installed
setup_additional_apt_keys_and_sources() {

    # mopidy: (from https://docs.mopidy.com/en/latest/installation/debian/):
    execute 'wget -q -O - https://apt.mopidy.com/mopidy.gpg | sudo apt-key add -'
    execute "sudo wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/${DEB_STABLE}.list"

    # docker:  (from https://docs.docker.com/install/linux/docker-ce/debian/):
    # note we have to use hard-coded stable codename instead of testing or testing codename,
    # as https://download.docker.com/linux/debian/dists/ doesn't have 'em;
    execute 'curl -fsSL https://download.docker.com/linux/debian/gpg | sudo apt-key add -'
    #execute "sudo add-apt-repository \
        #'deb [arch=amd64] https://download.docker.com/linux/debian \
        #$DEB_STABLE \
        #stable'
    #"
    execute "echo deb [arch=amd64] https://download.docker.com/linux/debian $DEB_STABLE stable | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null"


    # spotify: (from https://www.spotify.com/es/download/linux/):
    # note it's avail also as a snap: $snap install spotify
    execute 'curl -sS https://download.spotify.com/debian/pubkey.gpg | sudo apt-key add -'
    execute 'echo deb http://repository.spotify.com stable non-free | sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null'

    # seafile-client: (from https://download.seafile.com/published/seafile-user-manual/syncing_client/install_linux_client.md):
    #     seafile-drive instructions would be @ https://download.seafile.com/published/seafile-user-manual/drive_client/drive_client_for_linux.md
    execute 'wget -O - https://linux-clients.seafile.com/seafile.key | sudo apt-key add -'
    execute "echo 'deb [arch=amd64] https://linux-clients.seafile.com/seafile-deb/$DEB_STABLE/ stable main' | sudo tee /etc/apt/sources.list.d/seafile.list > /dev/null"

    # mono: (from https://www.mono-project.com/download/stable/#download-lin-debian):
    # later on installed by 'mono-complete' pkg
    execute 'sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys 3FA7E0328081BFF6A14DA29AA6A19B38D3D831EF'
    execute "echo 'deb https://download.mono-project.com/repo/debian stable-$DEB_STABLE main' | sudo tee /etc/apt/sources.list.d/mono-official-stable.list > /dev/null"  # stable branch
    #execute "echo 'deb https://download.mono-project.com/repo/debian preview-$DEB_STABLE main' | sudo tee /etc/apt/sources.list.d/mono-official-preview.list > /dev/null" # preview branch

    # charles: (from https://www.charlesproxy.com/documentation/installation/apt-repository/):
    execute 'wget -q -O - https://www.charlesproxy.com/packages/apt/PublicKey | sudo apt-key add -'
    execute 'echo deb https://www.charlesproxy.com/packages/apt/ charles-proxy main | sudo tee /etc/apt/sources.list.d/charles.list > /dev/null'

    # yarn:  (from https://yarnpkg.com/en/docs/install#debian-stable):
    execute 'curl -sS https://dl.yarnpkg.com/debian/pubkey.gpg | sudo apt-key add -'
    execute 'echo "deb https://dl.yarnpkg.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/yarn.list > /dev/null'

    # kubectl:  (from https://kubernetes.io/docs/tasks/tools/install-kubectl/#install-kubectl-on-linux):
    execute 'curl -sS https://packages.cloud.google.com/apt/doc/apt-key.gpg | sudo apt-key add -'  # ! note it's google packages key, not specific to kubectl!
    execute 'echo "deb https://apt.kubernetes.io/ kubernetes-xenial main" | sudo tee /etc/apt/sources.list.d/kubernetes.list > /dev/null'

    execute 'sudo apt-get --yes update'
}


# see https://wiki.debian.org/Locale#First_day_of_week
# to add additional locales, follow same page from "Manually" title;
# tl;dr: uncomment wanted locale in /etc/locale.gen and run $ locale-gen as root;
override_locale_time() {
    local conf_file

    readonly conf_file='/etc/default/locale'

    [[ -f "$conf_file" ]] || { err "cannot override locale time: [$conf_file] does not exist; abort;"; return 1; }

    # just in case delete all same definitions, regardless of its value:
    execute "sudo sed -i --follow-symlinks '/^LC_TIME\s*=/d' '$conf_file'" || return 1
    execute "echo 'LC_TIME=\"en_GB.UTF-8\"' | sudo tee --append $conf_file > /dev/null"  # en-gb gives us 24h clock

    return 0
}


# can also exec 'setxkbmap -option' caps:escape or use dconf-editor; also could use $loadkeys
# or switch it via XKB options (see https://wiki.archlinux.org/index.php/Keyboard_configuration_in_Xorg)
#
# to see current active keyboard setting:    setxkbmap -print -verbose 10
swap_caps_lock_and_esc() {
    local conf_file

    readonly conf_file='/usr/share/X11/xkb/symbols/pc'

    [[ -f "$conf_file" ]] || { err "cannot swap esc<->caps: [$conf_file] does not exist; abort;"; return 1; }

    # map caps to esc:
    if ! grep -q 'key <ESC>.*Caps_Lock' "$conf_file"; then
        # hasn't been replaced yet
        if ! execute "sudo sed -i --follow-symlinks 's/.*key.*ESC.*Escape.*/    key <ESC>  \{    \[ Caps_Lock        \]   \};/g' $conf_file"; then
            err "replacing esc<->caps @ [$conf_file] failed"
            return 2
        fi
    fi

    # map esc to caps:
    if ! grep -q 'key <CAPS>.*Escape' "$conf_file"; then
        # hasn't been replaced yet
        if ! execute "sudo sed -i --follow-symlinks 's/.*key.*CAPS.*Caps_Lock.*/    key <CAPS> \{    \[ Escape     \]   \};/g' $conf_file"; then
            err "replacing esc<->caps @ [$conf_file] failed"
            return 2
        fi
    fi

    return 0
}


install_altiris() {
    local rpm_loc altiris_loc

    rpm_loc="/usr/bin/rpm"
    # alt_loc from   https://williamhill.jira.com/wiki/display/TRAD/Developer+Machines :
    altiris_loc='https://williamhill.jira.com/wiki/download/attachments/21528849/altiris_install.sh'

    [[ "$PROFILE" != work ]] && { err "won't install it in [$PROFILE] profile; only in work profile."; return 1; }

    if ! command -v rpm >/dev/null; then
        install_block 'rpm' || return 1
        execute "sudo mv $rpm_loc ${rpm_loc}.orig" || return 1

        echo -e '#!/bin/sh\n/usr/bin/rpm.orig --nodeps --force-debian $@' | sudo tee $rpm_loc > /dev/null \
            || return 1
        execute "sudo chmod +x -- $rpm_loc"
    fi

    # download and execute altiris script:
    # !!! note the required cookie for jira to validate your session:
    execute " \
        wget --no-check-certificate \
            --no-cookies \
            --header 'Cookie: studio.crowd.tokenkey=sy1UCiW0EIXwN5lf7tUMLA00' \
            -O $TMP_DIR/altiris_install.sh \
            -- $altiris_loc \
    " || { err "couldn't find altiris script; read wiki."; return 1; }

    execute "chmod +x -- $TMP_DIR/altiris_install.sh"
    execute "sudo $TMP_DIR/altiris_install.sh" || {
        err "something's wrong; if it failed at rollout.sh, then you probably need to install libc6:i386"
        err "(as per https://williamhill.jira.com/wiki/display/TRAD/Altiris+on+Ubuntu)"
        return 1
    }

    execute "pushd /opt/altiris/notification/nsagent/bin" || return 1
    execute "sudo ./aex-configure -configure" || return 1

    execute "sudo mkdir -p /etc/rc.d/init.d" || return 1
    execute "sudo ln -s -- /lib/lsb/init-functions /etc/rc.d/init.d/functions" || return 1

    execute "sudo /etc/init.d/altiris start" || return 1
    # refresh policies:
    execute "sudo /opt/altiris/notification/nsagent/bin/aex-refreshpolicies"
    execute "sudo /opt/altiris/notification/nsagent/bin/aex-sendbasicinv" || { err 'apparently cannot send basic inventory'; return 1; }
}


install_symantec_endpoint_security() {
    local sep_loc jce_loc tmpdir tarball dir jars

    sep_loc='https://williamhillorg-my.sharepoint.com/personal/leighhall_williamhill_co_uk/_layouts/15/guestaccess.aspx?guestaccesstoken=B5plVjedQluwT7BgUH50bG3rs99cJaCg6lckbkGdS6I%3d&docid=2_15a1ca98041134ad8b2e4d93286806892'
    jce_loc='http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip'

    [[ "$PROFILE" != work ]] && { err "won't install it in [$PROFILE] profile; only in work profile."; return 1; }
    [[ -d "$JDK_LINK_LOC" ]] || { err "expected [$JDK_LINK_LOC] to link to existing jdk installation."; return 1; }

    tmpdir="$(mktemp -d "symantec-endpoint-sec-tempdir-XXXXX" -p $TMP_DIR)" || { err "unable to create tempdir with \$ mktemp"; return 1; }
    execute "pushd $tmpdir" || return 1

    # fetch & install SEP:
    execute "wget -- $sep_loc" || return 1
    tarball="$(ls)"
    extract "$tarball" || { err "extracting [$tarball] failed."; return 1; }
    dir="$(find . -mindepth 1 -maxdepth 1 -type d)"
    [[ -d "$dir" ]] || { err "couldn't find unpacked SEP directory"; return 1; }

    execute "sudo $dir/install.sh" || return 1

    execute "rm -- $tarball"
    execute "sudo rm -rf -- $dir" || return 1

    # fetch & install the jdk crypto extensions (JCE):
    execute "wget --no-check-certificate \
        --no-cookies \
        --header 'Cookie: oraclelicense=accept-securebackup-cookie' \
        -- $jce_loc" || { err "unable to wget $jce_loc."; return 1; }

    tarball="$(basename -- $jce_loc)"
    extract "$tarball" || { err "extracting [$tarball] failed."; return 1; }
    dir="$(find . -mindepth 1 -maxdepth 1 -type d)"
    [[ -d "$dir" ]] || { err "couldn't find unpacked jce directory"; return 1; }
    jars="$(find "$dir" -mindepth 1 -type f -name '*.jar')" || { err "looks like we didn't find any .jar files under [$dir]"; return 1; }
    execute "sudo cp $jars $JDK_LINK_LOC/jre/lib/security" || return 1

    # cleanup:
    execute "popd"
    execute "sudo rm -rf -- $tmpdir"
}


install_progs() {

    execute "sudo apt-get --yes update"

    install_webdev
    install_from_repo
    install_own_builds  # has to be after install_from_repo()

    is_native && install_nvidia

    # TODO: delete?:
    #if [[ "$PROFILE" == work ]]; then
        #install_altiris
        #install_symantec_endpoint_security
    #fi

    post_install_progs_setup
}


# to force ver: apt-get install linux-image-amd64:version
# check avail vers: apt-cache showpkg linux-image-amd64
upgrade_kernel() {
    local package_line kernels_list arch

    # install kernel meta-packages:
    # NOTE: these meta-packages only required, if using non-stable debian;
    # they keep the kernel and headers in sync; also note 'linux-image-amd64'
    # always pulls in latest kernel by default.
    if is_64_bit; then
        report "first installing kernel meta-packages..."
        install_block '
            linux-image-amd64
            linux-headers-amd64
        '
        readonly arch="amd64"
    else
        err "verified we're not running 64bit system. make sure it's correct. skipping kernel meta-package installation."
        sleep 5
    fi

    if is_noninteractive || [[ "$MODE" -ne 0 ]]; then return 0; fi  # only ask for custom kernel ver when we're in manual mode (single task), or we're in noninteractive node

    declare -a kernels_list=()

    # search for available kernel images:
    while IFS= read -r package_line; do
        kernels_list+=( $(echo "$package_line" | cut -d' ' -f1) )
    done < <(apt-cache search --names-only "^linux-image-[0-9]+\.[0-9]+\.[0-9]+.*$arch\$" | sort -n)

    [[ -z "${kernels_list[*]}" ]] && { err "apt-cache search didn't find any kernel images. skipping kernel upgrade"; sleep 5; return 1; }

    while true; do
       echo
       report "note kernel was just updated, but you can select different ver:"
       report "select kernel to install: (select none to skip kernel change)\n"
       select_items "${kernels_list[*]}" 1

       if [[ -n "$__SELECTED_ITEMS" ]]; then
          report "installing ${__SELECTED_ITEMS}..."
          execute "sudo apt-get --yes install $__SELECTED_ITEMS"
          break
       else
          confirm "no items were selected; skip kernel change?" && break
       fi
    done

    unset __SELECTED_ITEMS
}


# 'own build' as in everything from not the debian repository; either build from
# source, or fetch from the interwebs and install/configure manually.
#
# note single-task counterpart would be __choose_prog_to_build()
install_own_builds() {

    #prepare_build_container

    #install_vim  # note: can't exclude it as-is, as it also configures vim (if you ever want to go nvim-only)
    #install_neovim
    #install_keepassxc
    #install_goforit
    #install_copyq
    #install_rambox
    #install_franz
    install_ferdi
    install_slack_term
    install_ripgrep
    install_vnote
    #install_rebar
    install_lazygit
    install_lazydocker
    #install_gitin
    install_fd
    #install_synergy  # currently installing from repo
    install_i3
    install_polybar
    #install_oracle_jdk  # start using sdkman (or something similar)
    install_gruvbox_gtk_theme
    #install_weeslack
    install_veracrypt

    #install_dwm
    is_native && install_i3lock
    #is_native && install_i3lock_fancy
    is_native && install_betterlockscreen
    [[ "$PROFILE" == work ]] && install_work_builds
}


install_work_builds() {
    install_aws_okta
    install_saml2aws
    install_aia
    install_kustomize
    install_k9s
    install_popeye
    install_octant
    #install_kops
    install_kubectx
    install_kube_ps1
    install_sops
    is_native && install_bloomrpc
    install_postman
    install_terraform
    install_terragrunt
    install_minikube
    is_native && install_bluejeans
}


# build container exec
bc_exe() {
    local cmds

    cmds="$*"
    execute "docker exec -it $(docker ps -qf "name=$BUILD_DOCK") bash -c '$cmds'" || return 1
}


# build container install
bc_install() {
    local progs

    declare -ra progs=("$@")
    bc_exe "DEBIAN_FRONTEND=noninteractive apt-get --yes install ${progs[*]}" || return 1
}


prepare_build_container() {  # TODO container build env not used atm
    if [[ -z "$(docker ps -qa -f name="$BUILD_DOCK" --format '{{.Names}}')" ]]; then  # container hasn't been created
        #execute "docker create -t --name '$BUILD_DOCK' debian:testing-slim" || return 1  # alternative to docker run
        execute "docker run -dit --name '$BUILD_DOCK' -v '$BASE_BUILDS_DIR:/out' debian:testing-slim" || return 1
        bc_exe "apt-get --yes update"
        bc_install git checkinstall build-essential devscripts equivs cmake || return 1
    fi

    if [[ -z "$(docker ps -qa -f status=running -f name="$BUILD_DOCK" --format '{{.Names}}')" ]]; then
        execute "docker start '$BUILD_DOCK'" || return 1
    fi

    bc_exe "apt-get --yes update"
    return 0
}


# note that jdk will be installed under $JDK_INSTALLATION_DIR
install_oracle_jdk() {
    local tarball tmpdir dir

    tmpdir="$(mktemp -d "jdk-tempdir-XXXXX" -p $TMP_DIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }

    report "fetcing [$ORACLE_JDK_LOC]"
    execute "pushd -- $tmpdir" || return 1

    execute "curl -L -b 'oraclelicense=a' \
        '$ORACLE_JDK_LOC' -O" || { err "curling [$ORACLE_JDK_LOC] failed."; return 1; }

    readonly tarball="$(basename -- "$ORACLE_JDK_LOC")"
    extract "$tarball" || { err "extracting [$tarball] failed."; return 1; }
    dir="$(find . -mindepth 1 -maxdepth 1 -type d)"
    [[ -d "$dir" ]] || { err "couldn't find unpacked jdk directory"; return 1; }

    [[ -d "$JDK_INSTALLATION_DIR" ]] || execute "sudo mkdir -- $JDK_INSTALLATION_DIR"
    [[ -d "$JDK_INSTALLATION_DIR/$(basename -- "$dir")" ]] && { report "ver [$(basename -- "$dir")] java already installed"; return 0; }
    report "installing fetched JDK to [$JDK_INSTALLATION_DIR]"
    execute "sudo mv -- $dir $JDK_INSTALLATION_DIR/" || { err "could not move extracted jdk dir [$dir] to [$JDK_INSTALLATION_DIR]"; return 1; }

    # change ownership to root:
    execute "sudo chown -R root:root $JDK_INSTALLATION_DIR/$(basename -- "$dir")"

    # create link:
    create_link --sudo "$JDK_INSTALLATION_DIR/$(basename -- "$dir")" "$JDK_LINK_LOC"

    execute "popd"
    execute "sudo rm -rf -- $tmpdir"
    return 0
}


switch_jdk_versions() {
    local avail_javas active_java

    [[ -d "$JDK_INSTALLATION_DIR" ]] || { err "[$JDK_INSTALLATION_DIR] does not exist. abort."; return 1; }
    readonly avail_javas="$(find "$JDK_INSTALLATION_DIR" -mindepth 1 -maxdepth 1 -type d)"
    [[ $? -ne 0 || -z "$avail_javas" ]] && { err "discovered no java installations @ [$JDK_INSTALLATION_DIR]"; return 1; }
    if [[ -h "$JDK_LINK_LOC" ]]; then
        active_java="$(realpath -- "$JDK_LINK_LOC")"
        if [[ "$avail_javas" == "$active_java" ]]; then
            report "only one active jdk installation, [$active_java] is available, and that is already linked by [$JDK_LINK_LOC]"
            return 0
        fi

        readonly active_java="$(basename -- "$active_java")"
    fi

    while true; do
        [[ -n "$active_java" ]] && echo && report "current active java: [$active_java]\n"
        report "select java ver to use (select none to skip the change)\n"
        select_items "$avail_javas" 1

        if [[ -n "$__SELECTED_ITEMS" ]]; then
            [[ -d "$__SELECTED_ITEMS" ]] || { err "[$__SELECTED_ITEMS] is not a valid dir; try again."; continue; }
            report "selecting [$__SELECTED_ITEMS]..."
            create_link --sudo "$__SELECTED_ITEMS" "$JDK_LINK_LOC"
            break
        else
            confirm "no items were selected; skip jdk change?" && return
        fi
    done
}


# disabled as davmail's available in repo
# fetches the latest davmail
#install_davmail() {  # https://sourceforge.net/projects/davmail/files/
    #local tmpdir davmail_url davmail_dl page ver inst_loc

    #is_server && { report "we're server, skipping davmail installation."; return; }

    #tmpdir="$(mktemp -d "davmail-XXXXX" -p $TMP_DIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }
    #readonly davmail_url='https://sourceforge.net/projects/davmail/files/latest/download?source=files'
    #readonly inst_loc="$BASE_PROGS_DIR/davmail"

    #report "setting up davmail"

    #execute "pushd -- $tmpdir" || return 1
    #page="$(wget "$davmail_url" --user-agent="Mozilla/5.0 (X11; Linux x86_64; rv:50.0) Gecko/20100101 Firefox/50.0" -q -O -)" || { err "wgetting [$davmail_url] failed"; return 1; }
    #davmail_dl="$(grep -Po '.*a href="\Khttp.*davmail.*davmail.*\.zip.*(?=".*class.*direct-download.*$)' <<< "$page")" || { err "parsing davmail download link failed"; return 1; }
    #is_valid_url "$davmail_dl" || { err "[$davmail_dl] is not a valid download link"; return 1; }

    #ver="$(grep -Po '.*davmail.*davmail/\K[0-9]+\.[0-9]+\.[-0-9]+(?=/.*$)' <<< "$davmail_dl")"
    #[[ -z "$ver" ]] && { err "unable to parse davmail ver from url. abort."; return 1; }
    #[[ -e "$inst_loc/installations/$ver" ]] && { report "[$ver] already exists, skipping"; return 0; }

    #report "fetching [$davmail_dl]"
    #execute "wget '$davmail_dl' -O davmail.zip" || { err "wgetting [$davmail_dl] failed."; return 1; }
    #execute "unzip davmail.zip" || { err "extracting downloaded file failed."; return 1; }  # since file extension is unknown
    #execute "rm -- 'davmail.zip'" || { err "removing downloaded file failed"; return 1; }
    #execute "mkdir -p -- '$inst_loc/installations/$ver'" || { err "davmail dir creation failed"; return 1; }

    #execute "mv -- ./* '$inst_loc/installations/$ver'"
    #execute "pushd -- $inst_loc" || return 1
    #[[ -h davmail ]] && rm -- davmail
    #execute "ln -fs 'installations/$ver/davmail.sh' davmail"

    #execute "popd; popd"
    #execute "sudo rm -rf -- '$tmpdir'"

    #return 0
#}



fetch_release_from_git() {
    local opt loc id OPTIND args

    args=()
    while getopts "UsF:" opt; do
        case "$opt" in
            U) args+=("-U") ;;
            s) args+=("-s") ;;
            F) args+=("-F" "$OPTARG") ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    loc="https://github.com/$1/$2/releases/latest"
    id="github-$1-$2"

    fetch_release_from_any "${args[@]}" -r -I "$id" "$loc" "$3" "$4"
}

resolve_dl_urls() {
    local opt OPTIND multi loc grep_tail page dl_url urls domain u

    while getopts "M" opt; do
        case "$opt" in
            M) multi=1 ;;  # ie multiple urls/results are allowed (but not required!)
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    loc="$1"
    grep_tail="$2"

    page="$(wget "$loc" -q -O -)" || { err "wgetting [$loc] failed with $?"; return 1; }
    dl_url="$(grep -Po '.*a href="\K'"$grep_tail"'(?=")' <<< "$page" | sort --unique)"

    if [[ -z "$dl_url" ]]; then
        err "no urls found from [$loc] for pattern [$grep_tail]"
        return 1
    elif [[ "$multi" -ne 1 ]] && ! is_single "$dl_url"; then
        err "multiple urls found from [$loc] for pattern [$grep_tail], but expecting a single result"
        return 1
    fi

    domain="$(grep -Po '^https?://([^/]+)(?=)' <<< "$loc")"
    while IFS= read -r u; do
        if [[ -n "$u" && "$u" == /* ]]; then
            u="${domain}$u"  # convert to fully qualified url
        fi

        u="$(html2text -width 1000000 <<< "$u")"
        is_valid_url "$u" || { err "[$u] is not a valid download link"; return 1; }
        urls+="$u"$'\n'
    done <<< "$dl_url"

    echo "$urls"
}

# Fetch a file from a given page, and return full path to the file.
# Note we will automaticaly extract the asset if it's archived/compressed; pass -U
# to skip that step.
#
# -U     - skip extracting if archive and pass compressed/tarred ball as-is.
# -s     - skip adding fetched asset in $GIT_RLS_LOG
# -F     - $file output pattern to grep for in order to filter for specific
#          single file from unpacked tarball (meaning it's pointless when -U is given);
#          as it stands, the _first_ file matching given filetype is returned, even if there were more.
# -I     - entity identifier (for logging/version tracking et al)
# -r     - if href grep should be relative, ie start with / (note user should not prefix w/ / themselves)
#
# $1 - url to extract the asset url from;
# $2 - build/file regex to be used (for grep -Po) to parse correct item from git /releases page src;
#      note it matches 'til the very end of url (ie you should only provide the latter bit);
# $3 - optional output file name; if given, downloaded file will be renamed to this; note name, not path!
fetch_release_from_any() {
    local opt noextract skipadd file_filter id relative loc tmpdir file loc dl_url OPTIND

    while getopts "UsF:I:r" opt; do
        case "$opt" in
            U) readonly noextract=1 ;;
            s) readonly skipadd=1 ;;
            F) readonly file_filter="$OPTARG" ;;
            I) readonly id="$OPTARG" ;;
            r) readonly relative='TRUE' ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"


    readonly loc="$1"
    tmpdir="$(mktemp -d "release-from-external-${id}-XXXXX" -p $TMP_DIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }

    dl_url="$(resolve_dl_urls "$loc" "${relative:+/}.*$2")" || return 1  # note we might be looking for a relative url

    if [[ "$skipadd" -ne 1 ]] && grep -Fq "$dl_url" "$GIT_RLS_LOG" 2>/dev/null; then
        report "[$dl_url] already encountered, skipping installation..."
        return 2
    fi

    report "fetching [$dl_url]..."
    execute "wget --content-disposition -q --directory-prefix=$tmpdir '$dl_url'" || { err "wgetting [$dl_url] failed with $?"; return 1; }
    file="$(find "$tmpdir" -type f)"
    [[ -f "$file" ]] || { err "couldn't find single downloaded file in [$tmpdir]"; return 1; }

    if [[ "$noextract" -ne 1 ]] && grep -qiE "archive|compressed" <<< "$(file --brief "$file")"; then
        execute "pushd -- $tmpdir" || return 1
        aunpack --quiet "$file" || { err "couldn't extract [$file]"; popd; return 1; }
        execute "rm -f -- '$file'" || { err; popd; return 1; }

        if [[ -n "$file_filter" ]]; then
            while IFS= read -r -d $'\0' file; do
                grep -q "$file_filter" <<< "$(file -iLb "$file")" && break  # TODO: provide -E flag to grep?
                unset file
            done < <(find "$tmpdir" -type f -print0)
        else
            file="$(find "$tmpdir" -type f)"
        fi

        [[ -f "$file" ]] || { err "couldn't find single extracted/uncompressed file in [$tmpdir]"; popd; return 1; }
        execute "popd"
    fi

    if [[ -n "$3" && "$(basename -- "$file")" != "$3" ]]; then
        execute "mv -- '$file' '$tmpdir/$3'" || { err "renaming [$file] to [$tmpdir/$3] failed"; return 1; }
        file="$tmpdir/$3"
    fi

    if [[ "$skipadd" -ne 1 ]]; then
        # we're assuming here that installation succeeded from here on:
        add_to_dl_log "$id" "$dl_url"
    fi

    #sanitize_apt "$tmpdir"  # think this is not really needed...
    echo "$file"  # note returned should be indeed path, even if only relative (ie './xyz'), not cleaned, "pure" filename
    return 0
}


# Fetch a .deb file from given github /releases page, and install it
#
# $1 - git user
# $2 - git repo
# $3 - build/file regex to be used (for grep -P) to parse correct item from git /releases page src.
install_deb_from_git() {
    local deb

    deb="$(fetch_release_from_git "$1" "$2" "$3")" || return 1
    # TODO: note apt doesn't have --yes option!
    #execute "sudo apt install '$deb'" || { err "installing [$1/$2] failed w/ $?"; return 1; }
    execute "sudo apt-get --yes install '$deb'" || { err "installing [$1/$2] failed w/ $?"; return 1; }
    execute "rm -rf -- '$deb'"
}


# Fetch and extract a tarball from given github /releases page.
# Note it'll be fetched and extracted into current $pwd.
#
# pass   -S   flag to create tmp directory where extraction should happen; takes the
#             tmpdir extraction requirement off the caller;
#
# $1 - git user
# $2 - git repo
# $3 - build/file regex to be used (for grep -P) to parse correct item from git /releases page src.
#
# @returns {string} path to root dir of extraction result, IF we found a single dir
#                   in PWD.
fetch_extract_tarball_from_git() {
    local opt i OPTIND standalone tmpdir

    while getopts "S" opt; do
        case "$opt" in
            S) standalone=1 ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    i="$(fetch_release_from_git -U "$1" "$2" "$3")" || return $?
    if [[ "$standalone" == 1 ]]; then
        tmpdir="$(mktemp -d "$1-$2-build-XXXXX" -p "$TMP_DIR")" || { err "unable to create tempdir with \$ mktemp"; return 1; }
        execute "pushd -- $tmpdir" || return 1
    fi

    execute "aunpack --extract --quiet '$i'" > /dev/null || { err "extracting [$i] failed w/ $?"; [[ "$standalone" == 1 ]] && popd; return 1; }

    i="$(find "$(pwd -P)" -mindepth 1 -maxdepth 1 -type d)"
    [[ -d "$i" ]] && echo "$i"
    [[ "$standalone" == 1 ]] && popd
    # do NOT remove $tmpdir
    return 0
}


# Fetch a file from given github /releases page, and install the binary
#
# -d /target/dir    - dir to install pulled binary in, optional
# -n binary_name    - what to name pulled binary to, optional; TODO: should it not be mandatory - otherwise filename changes w/ each new version?
# $1 - git user
# $2 - git repo
# $3 - build/file regex to be used (for grep -P) to parse correct item from git /releases page src.
install_bin_from_git() {
    local opt bin target name OPTIND

    target='/usr/local/bin'  # default
    while getopts "n:d:" opt; do
        case "$opt" in
            n) name="$OPTARG" ;;
            d) target="$OPTARG" ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    [[ -d "$target" ]] || { err "[$target] not a dir, can't install [$1/$2]"; return 1; }

    bin="$(fetch_release_from_git -F 'application/x-executable' "$1" "$2" "$3" "$name")" || return 1
    execute "chmod +x '$bin'" || return 1
    execute "sudo mv -- '$bin' '$target'" || { err "installing [$bin] in [$target] failed"; return 1; }
}


install_franz() {  # https://github.com/meetfranz/franz/blob/master/docs/linux.md
    #install_block 'libx11-dev libxext-dev libxss-dev libxkbfile-dev'
    install_bin_from_git -n franz meetfranz franz x86_64.AppImage
}


# Franz nag-less fork; found it from this franz thread: https://github.com/meetfranz/franz/issues/1167
# might also consider open-source fork of rambox: https://github.com/TheGoddessInari/hamsket
install_ferdi() {  # https://github.com/getferdi/ferdi
    #install_bin_from_git -n ferdi getferdi ferdi .AppImage
    install_deb_from_git getferdi ferdi _amd64.deb
}


# TODO: looks like StevensNJD4/LazyMan is no more
# maybe consider one of following:
#  - https://github.com/tarkah/lazystream
#  - https://github.com/actionbronson/LazyMan
install_lazyman() {  # https://github.com/StevensNJD4/LazyMan
    true
}


# see also https://github.com/wee-slack/wee-slack/
install_slack_term() {  # https://github.com/erroneousboat/slack-term
    install_bin_from_git -n slack-term erroneousboat slack-term slack-term-linux-amd64
}


install_rebar() {  # https://github.com/erlang/rebar3
    install_bin_from_git -n rebar3 erlang rebar3 rebar3
}


install_ripgrep() {  # https://github.com/BurntSushi/ripgrep
    install_deb_from_git BurntSushi ripgrep _amd64.deb
}


# note it's no longer actively maintained; consider replacing w/ https://github.com/Versent/saml2aws
# tag: aws
install_aws_okta() {  # https://github.com/segmentio/aws-okta
    install_deb_from_git segmentio aws-okta _amd64.deb
}

install_saml2aws() {  # https://github.com/Versent/saml2aws
    install_bin_from_git -n saml2aws -d "$HOME/bin" Versent saml2aws '_linux_amd64.tar.gz'
}

# kubernetes aws-iam-authenticator (k8s)
# tag: aws, k8s, kubernetes, auth
                          # https://docs.aws.amazon.com/eks/latest/userguide/install-aws-iam-authenticator.html
install_aia() {  # https://github.com/kubernetes-sigs/aws-iam-authenticator
    install_bin_from_git -n aws-iam-authenticator -d "$HOME/bin" kubernetes-sigs aws-iam-authenticator _linux_amd64
}

# kubernetes configuration customizer
# tag: aws, k8s, kubernetes, kubernetes-config, k8s-config
install_kustomize() {  # https://github.com/kubernetes-sigs/kustomize
    install_bin_from_git -n kustomize -d "$HOME/bin" kubernetes-sigs kustomize _linux_amd64.tar.gz
}

# kubernetes (k8s) cli management
# tag: aws, k8s, kubernetes
install_k9s() {  # https://github.com/derailed/k9s
    install_bin_from_git -n k9s -d "$HOME/bin"  derailed  k9s  _Linux_x86_64.tar.gz
}

# kubernetes (k8s) config/resource sanitizer
# tag: aws, k8s, kubernetes
install_popeye() {  # https://github.com/derailed/popeye
    install_bin_from_git -n popeye -d "$HOME/bin"  derailed  popeye  _Linux_x86_64.tar.gz
}

# kubernetes cluster analyzer for better comprehension (introspective tooling, cluster
# navigation, object management)
# tag: aws, k8s, kubernetes
install_octant() {  # https://github.com/vmware-tanzu/octant
    install_deb_from_git  vmware-tanzu  octant  _Linux-64bit.deb
}

# kubernetes (k8s) operations - Production Grade K8s Installation, Upgrades, and Management
# tag: aws, k8s, kubernetes
# see also: kubebox,k9s,https://github.com/hjacobs/kube-ops-view
install_kops() {  # https://github.com/kubernetes/kops/
    install_bin_from_git -n kops -d "$HOME/bin"  kubernetes  kops  kops-linux-amd64
}

# kubectx - kubernetes contex swithcher
# tag: aws, k8s, kubernetes
install_kubectx() {  # https://github.com/ahmetb/kubectx
    local COMPDIR

    install_bin_from_git -n kubectx -d "$HOME/bin"  ahmetb  kubectx  kubectx.*_linux_x86_64
    install_bin_from_git -n kubectx -d "$HOME/bin"  ahmetb  kubectx  kubens.*_linux_x86_64

    # kubectx/kubens completion scripts: (note there's corresponding entry in ~/.bashrc)
    clone_or_pull_repo "ahmetb" "kubectx" "$BASE_DEPS_LOC"
    COMPDIR=$(pkg-config --variable=completionsdir bash-completion)
    [[ -d "$COMPDIR" ]] || { err "[$COMPDIR] not a dir, cannot install kube{ctx,ns} shell completion"; return 1; }
    create_link --sudo "${BASE_DEPS_LOC}/kubectx/completion/kubens.bash" "$COMPDIR/kubens"
    create_link --sudo "${BASE_DEPS_LOC}/kubectx/completion/kubectx.bash" "$COMPDIR/kubectx"
}

# kube-ps1 - kubernets shell prompt
# tag: aws, k8s, kubernetes
install_kube_ps1() {  # https://github.com/jonmosco/kube-ps1
    clone_or_pull_repo "jonmosco" "kube-ps1" "$BASE_DEPS_LOC"
    # note there's corresponding entry in ~/.bashrc
}

# tool for managing secrets (SOPS: Secrets OPerationS)
# tag: aws
install_sops() {  # https://github.com/mozilla/sops
    install_deb_from_git mozilla sops _amd64.deb
}


install_bloomrpc() {  # https://github.com/uw-labs/bloomrpc/releases
    install_deb_from_git uw-labs bloomrpc _amd64.deb  # TODO deb pkg has unmet deps that aren't automatically installed (similar to ferdi)
    #install_bin_from_git -n bloomrpc uw-labs bloomrpc x86_64.AppImage
}

# if build fails, you might be able to salvage something by:
#   sed -i 's/-Werror//g' Makefile
install_grpc_cli() {  # https://github.com/grpc/grpc/blob/master/doc/command_line_tool.md
    local tmpdir f

    tmpdir="$(mktemp -d 'grpc-cli-tempdir-XXXXX' -p $TMP_DIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }
    execute "pushd -- '$tmpdir'" || return 1
    execute "git clone -b '$(curl --fail -L https://grpc.io/release)' https://github.com/grpc/grpc" || return 1
    execute 'pushd -- grpc' || return 1
    execute 'git submodule update --init' || return 1

    install_block 'libgflags-dev' || return 1
    execute 'make -j8 grpc_cli' || return 1
    f="$(find . -mindepth 1 -type f -name 'grpc_cli')"
    [[ -f "$f" ]] || { err "couldn't find grpc_cli"; return 1; }
    execute "mv -- '$f' '$BASE_BUILDS_DIR'" || return 1

    execute "popd; popd" || return 1
    execute "rm -rf -- '$tmpdir'"
}

# db/database visualisation tool (for mysql/mariadb)
# remember intellij idea also has a db tool!
install_dbeaver() {  # https://dbeaver.io/download/
    local loc dest

    readonly loc='https://dbeaver.io/files/dbeaver-ce_latest_amd64.deb'
    readonly dest="$TMP_DIR/dbeaver-$RANDOM.deb"

    execute "wget -O '$dest' '$loc'" || { err "wgetting [$loc] failed."; return 1; }
    execute "sudo apt-get --yes install '$dest'" || return 1
    execute "rm -f -- '$dest'"
}


# perforce git mergetool, alternative to meld;
# TODO: ver/url resolution unresolved, currenlty hard-coding version!
install_p4merge() {  # https://www.perforce.com/downloads/visual-merge-tool
    local loc dest

    readonly loc='http://www.perforce.com/downloads/perforce/r19.2/bin.linux26x86_64/p4v.tgz'
    readonly dest="$TMP_DIR/dbeaver-$RANDOM.deb"

    execute "wget -O '$dest' '$loc'" || { err "wgetting [$loc] failed."; return 1; }
    execute "sudo apt-get --yes install '$dest'" || return 1
    execute "rm -f -- '$dest'"
}


# redis manager
install_redis_desktop_mngr() {  # https://snapcraft.io/install/redis-desktop-manager/debian
    snap_install redis-desktop-manager
}


# other mentions/alternatives:
#   https://github.com/pbek/QOwnNotes  (also c++, qt-based like vnotes)
#   https://github.com/laurent22/joplin/
#   https://github.com/notable/notable/
#   https://github.com/BoostIO/Boostnote
install_vnote() {  # https://github.com/tamlok/vnote/releases
    install_bin_from_git -n vnote tamlok vnote x86_64.AppImage
}


install_postman() {  # https://learning.getpostman.com/docs/postman/launching-postman/installation-and-updates/
    local tmpdir dir dsk target

    target="$BASE_PROGS_DIR/Postman"
    tmpdir="$(mktemp -d 'postman-tempdir-XXXXX' -p $TMP_DIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }
    wget --directory-prefix=$tmpdir --content-disposition 'https://dl.pstmn.io/download/channel/canary/linux_64' || return 1
    execute "pushd -- '$tmpdir'" || return 1
    execute "aunpack --quiet *" || { err "extracting postman tarball failed w/ $?"; popd; rm -rf -- "$tmpdir"; return 1; }
    execute "popd"

    dir="$(find "$tmpdir" -maxdepth 1 -mindepth 1 -type d)"
    [[ -d "$dir" ]] || { err "couldn't find single extracted dir in [$tmpdir]"; return 1; }
    [[ -d "$target" ]] && { execute "rm -rf -- '$target'" || return 1; }
    execute "mv -- '$dir' '$target'" || return 1
    execute "rm -rf -- '$tmpdir'"

    # install .desktop:
    dsk="$HOME/.local/share/applications"
    [[ -d "$dsk" ]] || { err "[$dsk] not a dir"; return 1; }
    echo "[Desktop Entry]
Encoding=UTF-8
Name=PostmanCanary
Exec=$target/PostmanCanary %U
Icon=$target/app/resources/app/assets/icon.png
Terminal=false
Type=Application
Categories=Development;
" > "$dsk/PostmanCanary.desktop" || { err "unable to create Postman .desktop in [$dsk]"; return 1; }
}


install_weeslack() {  # https://github.com/wee-slack/wee-slack
    install_block 'weechat-python python3-websocket' || return 1

    execute "mkdir -p $HOME/.weechat/python/autoload" || return 1
    execute 'pushd ~/.weechat/python' || return 1
    execute 'curl -O https://raw.githubusercontent.com/wee-slack/wee-slack/master/wee_slack.py' || return 1
    execute 'ln -s ../wee_slack.py autoload'  # in order to start wee-slack automatically when weechat starts
    execute 'popd' || return 1
}


install_terraform() {  # https://www.terraform.io/downloads.html
    local bin target

    target='/usr/local/bin'

    bin="$(fetch_release_from_any -I "terraform" 'https://www.terraform.io/downloads.html' '_linux_amd64.zip')" || return $?
    execute "chmod +x -- '$bin'" || return 1
    execute "sudo mv -- '$bin' '$target'" || { err "installing [$bin] in [$target] failed"; return 1; }
    return 0
}

install_terragrunt() {  # https://github.com/gruntwork-io/terragrunt/
    install_bin_from_git -n terragrunt gruntwork-io terragrunt terragrunt_linux_amd64
}

# download mirrors:
#   96 - UK
#   1208 - france
#   1285 - netherlands
#   1186 - netherlands2
#   1156 - sweden
#   1099 - czech
#   1190 - germany
#   17   - germany2
#
install_eclipse_mem_analyzer() {  # https://www.eclipse.org/mat/downloads.php
    local tmpdir target loc page dl_url file mirror

    tmpdir="$(mktemp -d "eclipse-mem-ana-XXXXX" -p $TMP_DIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }
    target="$BASE_PROGS_DIR/mat"
    loc='https://www.eclipse.org/mat/downloads.php'
    mirror=96

    page="$(wget "$loc" -q -O -)" || { err "wgetting [$loc] failed with $?"; return 1; }
    loc="$(grep -Po '.*a href="\K.*linux.gtk.x86_64.zip(?=")' <<< "$page")" || { err "parsing download link from [$loc] content failed"; return 1; }
    is_valid_url "$loc" || { err "[$loc] is not a valid link"; return 1; }
    loc+="&mirror_id=$mirror"
    # now need to parse link again from the download page...
    page="$(wget "$loc" -q -O -)" || { err "wgetting [$loc] failed with $?"; return 1; }
    dl_url="$(grep -Po 'If the download doesn.t start.*a href="\K.*(?=")' <<< "$page")" || { err "parsing final download link from [$loc] content failed"; return 1; }
    is_valid_url "$dl_url" || { err "[$dl_url] is not a valid download link"; return 1; }

    report "fetching [$dl_url]..."
    execute "wget --content-disposition -q --directory-prefix=$tmpdir '$dl_url'" || { err "wgetting [$dl_url] failed with $?"; return 1; }
    file="$(find "$tmpdir" -type f)"
    [[ -f "$file" ]] || { err "couldn't find single downloaded file in [$tmpdir]"; return 1; }

    grep -qiE 'archive|compressed' <<< "$(file --brief "$file")" || { err "looks like [$file] is not an archive"; return 1; }
    execute "pushd -- $tmpdir" || return 1
    aunpack --quiet "$file" || { err "couldn't extract [$file]"; popd; return 1; }
    execute "popd"
    file="$(find "$tmpdir" -maxdepth 1 -mindepth 1 -type d)"
    [[ -d "$file" ]] || { err "couldn't find single extracted dir in [$tmpdir]"; return 1; }
    [[ -d "$target" ]] && { execute "rm -rf -- '$target'" || return 1; }
    execute "mv -- '$file' '$target'" || return 1
    execute "rm -rf -- '$tmpdir'"
    create_link "$target/MemoryAnalyzer" "$HOME/bin/MemoryAnalyzer"
}

install_visualvm() {  # https://github.com/oracle/visualvm
    local target dir

    target="$BASE_PROGS_DIR/visualvm"

    dir="$(fetch_extract_tarball_from_git -S oracle visualvm 'visualvm_[-0-9.]+\.zip')" || return 1
    [[ -d "$dir" ]] || { err "couldn't find unpacked visualvm dir"; return 1; }

    [[ -d "$target" ]] && { execute "rm -rf -- '$target'" || return 1; }
    execute "mv -- '$dir' '$target'" || return 1
    create_link "$target/bin/visualvm" "$HOME/bin/visualvm"
}


# see https://gist.github.com/johnduarte/15851f5bbe85884bc0b947a9d54b441b
install_bluejeans_via_rpm() {  # https://www.bluejeans.com/downloads#desktop
    local rpm

    rpm="$(fetch_release_from_any -I bluejeans 'https://www.bluejeans.com/downloads#desktop' 'BlueJeans.rpm')" || return $?
    execute "sudo alien --install --to-deb '$rpm'" || return 1
    return 0
}

install_bluejeans() {  # https://www.bluejeans.com/downloads#desktop
    local deb

    deb="$(fetch_release_from_any -I bluejeans 'https://www.bluejeans.com/downloads#desktop' 'BlueJeans.deb')" || return $?
    execute "sudo apt-get --yes install '$deb'" || return 1
    return 0
}


# https://github.com/kubernetes/minikube
install_minikube() {  # https://kubernetes.io/docs/tasks/tools/install-minikube/
    # from github releases...:
    install_deb_from_git kubernetes minikube 'minikube_[-0-9.]+.*_amd64.deb'

    # ...or from k8s page:  (https://minikube.sigs.k8s.io/docs/start/):
    #curl -LO https://storage.googleapis.com/minikube/releases/latest/minikube_latest_amd64.deb
    #sudo dpkg -i minikube_latest_amd64.deb
}


# found as apt fd-find package, but executable is named fdfind not fd!
install_fd() {  # https://github.com/sharkdp/fd
    install_deb_from_git sharkdp fd 'fd_[-0-9.]+_amd64.deb'
}


install_lazygit() {  # https://github.com/jesseduffield/lazygit
    install_bin_from_git -n lazygit -d "$HOME/bin" jesseduffield lazygit '_Linux_x86_64.tar.gz'
}


install_lazydocker() {  # https://github.com/jesseduffield/lazydocker
    install_bin_from_git -n lazydocker -d "$HOME/bin" jesseduffield lazydocker '_Linux_x86_64.tar.gz'
}


# TODO: remove for lazygit?
install_gitin() {  # https://github.com/isacikgoz/gitin
    install_bin_from_git -n gitin -d "$HOME/bin" isacikgoz gitin '_linux_amd64.tar.gz'
}


install_rambox() {  # https://github.com/ramboxapp/community-edition/wiki/Install-on-Linux
    local tmpdir tarball rambox_url rambox_dl page dir ver inst_loc

    is_server && { report "we're server, skipping rambox installation."; return; }

    tmpdir="$(mktemp -d "rambox-XXXXX" -p $TMP_DIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }
    readonly rambox_url='http://rambox.pro/#download'
    readonly inst_loc="$BASE_PROGS_DIR/rambox"

    report "setting up rambox"
    install_block 'libappindicator1' || { err "rambox deps install_block failed" "$FUNCNAME"; return 1; }

    execute "pushd -- $tmpdir" || return 1
    page="$(wget "$rambox_url" -q -O -)" || { err "wgetting [$rambox_url] failed"; return 1; }
    rambox_dl="$(grep -Po '.*a href="\Khttp.*linux_64.*deb(?=".*$)' <<< "$page")" || { err "parsing rambox download link failed"; return 1; }
    is_valid_url "$rambox_dl" || { err "[$rambox_dl] is not a valid download link"; return 1; }

    report "fetching [$rambox_dl]"
    execute "wget '$rambox_dl'" || { err "wgetting [$rambox_dl] failed."; return 1; }
    tarball="$(find . -type f)"
    [[ -f "$tarball" ]] || { err "couldn't find downloaded file"; return 1; }
    execute "tar xzf '$tarball'" || { err "extracting [$tarball] failed."; return 1; }  # since file extension is unknown
    execute "rm -- '$tarball'" || { err "removing [$tarball] failed"; return 1; }
    dir="$(find . -mindepth 1 -maxdepth 1 -type d)"
    [[ -d "$dir" ]] || { err "couldn't find unpacked rambox"; return 1; }
    ver="$(basename -- "$dir")"
    [[ -e "$inst_loc/installations/$ver" ]] && { report "[$ver] already exists, skipping"; return 0; }
    [[ -d "$inst_loc/installations" ]] || execute "mkdir -p -- '$inst_loc/installations'" || { err "rambox dir creation failed"; return 1; }

    mv -- "$dir" "$inst_loc/installations/"
    execute "pushd -- $inst_loc" || return 1
    clear_old_vers
    [[ -h rambox ]] && rm -- rambox
    create_link "installations/$ver/rambox" rambox
    create_link "$inst_loc/rambox" "$HOME/bin/rambox"

    execute "popd; popd"
    execute "sudo rm -rf -- '$tmpdir'"

    return 0
}


# builds rambox from source  (atm not used, as using AppImage or tarball)
build_and_install_rambox() {  # https://github.com/ramboxapp/community-edition
    local expected_sencha_loc tmpdir

    is_server && { report "we're server, skipping rambox installation."; return; }

    readonly expected_sencha_loc="$HOME/bin/Sencha"
    tmpdir="$(mktemp -d "sencha-XXXXX" -p $TMP_DIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }

    is_x || { err "won't install rambox; need to be in graphical env for that."; return 1; }

    function __fetch_and_install_sencha() {
        local zip sencha_url sencha_dl page installer

        readonly sencha_url='https://www.sencha.com/products/extjs/cmd-download/'

        page="$(wget "$sencha_url" -q -O -)" || { err "wgetting [$sencha_url] failed"; return 1; }
        sencha_dl="$(grep -Po '.*a id=.link_linux_64.*href="\K.*(?=".*$)' <<< "$page")" || { err "parsing sencha download link failed"; return 1; }
        is_valid_url "$sencha_dl" || { err "[$sencha_dl] is not a valid download link"; return 1; }

        report "fetching [$sencha_dl]"
        execute "wget '$sencha_dl'" || { err "wgetting [$sencha_dl] failed."; return 1; }
        zip="$(basename -- "$sencha_dl")"
        extract "$zip" || { err "extracting [$zip] failed."; return 1; }
        execute "rm -- '$zip'" || { err "removing [$zip] failed"; return 1; }
        installer="$(find . -mindepth 1 -maxdepth 1 -type f)"
        [[ -f "$installer" ]] || { err "couldn't find unpacked sencha installer"; return 1; }
        execute "$installer" || { err "executing [$installer] failed."; return 1; }
        rm -r -- * || { err "[$tmpdir] cleanup failed;"; return 1; }

        return 0
    }

    execute "pushd -- $tmpdir" || return 1

    report "setting up rambox"
    if [[ ! -d "$expected_sencha_loc" ]] || confirm "sencha found @ [$expected_sencha_loc]; want to fetch latest anyways?"; then
        __fetch_and_install_sencha || { err "fetching or installing sencha failed"; return 1; }
    fi
    [[ -d "$expected_sencha_loc" ]] || { err "couldn't find sencha @ [$expected_sencha_loc]"; return 1; }

    # install deps
    install_block '
        nodejs-legacy
        npm
        git
    ' || { err "rambox deps install_block failed" "$FUNCNAME"; return 1; }
    execute 'npm install electron-prebuilt -g' || return 1
    execute "git clone -j8 $RAMBOX_REPO_LOC $tmpdir" || return 1
    execute 'npm install' || { err "npm install failed" "$FUNCNAME"; return 1; }
    # TODO set up env.conf
    execute 'mv -- env-sample.js  env.js'
    execute 'npm run sencha:compile' || { err "sencha:compile failed"; return 1; }

    execute "popd"
    execute "sudo rm -rf -- '$tmpdir'"
}


install_skype() {  # https://wiki.debian.org/skype
                   # https://www.skype.com/en/get-skype/
    local skypeFile skype_downloads_dir

    is_server && { report "we're server, skipping skype installation."; return; }
    readonly skypeFile="$TMP_DIR/skype-install.deb"
    readonly skype_downloads_dir="$BASE_DATA_DIR/Downloads/skype_dl"

    report "setting up skype"

    if is_64_bit; then
        execute "sudo dpkg --add-architecture i386"
        execute "sudo apt-get --yes update"
        execute "sudo apt-get -f --yes install"
    fi

    execute "wget -O $skypeFile -- $SKYPE_LOC" || { err; return 1; }
    execute "sudo dpkg -i $skypeFile"  #|| { err; return 1; }  # do not exit on err!; TODO: instead of this install-and-fix, directly install file via apt-get?
    execute "sudo apt-get -f --yes install" || { err; return 1; }

    # store the .deb, just in case:
    execute "mv $skypeFile $BASE_BUILDS_DIR"

    # create target dir for skype file transfers;
    # ! needs to be configured in skype!
    [[ -d "$skype_downloads_dir" ]] || execute "mkdir '$skype_downloads_dir'"
}


install_webdev() {
    is_server && { report "we're server, skipping webdev env installation."; return; }

    # first get nvm (node version manager) :  # https://github.com/nvm-sh/nvm#git-install
    clone_or_pull_repo nvm-sh nvm "$HOME/.nvm/"  # note repo dest needs to be exactly @ ~/.nvm, ie do not symlink
    execute "source '$HOME/.nvm/nvm.sh'" || err "sourcing ~/.nvm/nvm.sh failed"
    if ! command -v node >/dev/null 2>&1; then  # only proceed if node hasn't already been installed
        execute "nvm install stable" || err "installing nodejs 'stable' version failed"
        execute "nvm alias default stable" || err "setting [nvm default stable] failed"
        execute "nvm use default" || err "[nvm use default] failed"
    fi

    # update npm:
    execute "$NPM_PRFX npm install npm@latest -g" && sleep 0.2

    # install npm modules:  # TODO review what we want to install
    execute "$NPM_PRFX npm install -g \
        nwb \
        @vue/cli \
        typescript \
    "

    # install ruby modules:          # sass: http://sass-lang.com/install
    # TODO sass deprecated, use https://github.com/sass/dart-sass instead
    #rb_install sass

    # install yarn:  https://yarnpkg.com/en/docs/install#debian-stable
    execute "sudo apt-get --no-install-recommends --yes install yarn"

    # install rails:
    # this would install it globally; better install new local ver by
    # rbenv install <ver> && rbenv global <ver> && gem install rails
    #rb_install rails
}


# building instructions from https://github.com/symless/synergy-core/wiki/Compiling
# TODO: latest built binaries also avail from https://symless.com/synergy/downloads
install_synergy() {
    local tmpdir

    readonly tmpdir="$TMP_DIR/synergy-build-${RANDOM}"

    report "installing synergy build dependencies..."
    install_block '
        build-essential
        qtcreator
        qtbase5-dev
        cmake
        xorg-dev
        libssl-dev
        libx11-dev
        libsodium-dev
        libgl1-mesa-glx
        libegl1-mesa
        libcurl4-openssl-dev
        libavahi-compat-libdnssd-dev
        qtdeclarative5-dev
        libqt5svg5-dev
        libsystemd-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }

    execute "git clone -j8 $SYNERGY_REPO_LOC $tmpdir" || return 1
    execute "pushd $tmpdir" || return 1
    execute "git checkout v2-dev" || return 1  # see https://github.com/symless/synergy-core/wiki/Getting-Started
    export BOOST_ROOT="/home/$USER/boost"  # TODO: unsure if this is needed

    report "building synergy"
    execute "mkdir build" || return 1
    execute "pushd build" || return 1
    execute "cmake .." || { err "[cmake ..] for synergy failed w/ $?"; return 1; }
    execute "make" || { err "[make] for synergy failed w/ $?"; return 1; }
    build_deb  synergy || err "build_deb for synergy failed"  # TODO: unsure if has to be ran from build/ or root dir;

    execute "popd;popd"
    execute "sudo rm -rf -- '$tmpdir'"
    return 0
}

build_and_install_synergy_TODO_container_edition() {

    prepare_build_container || { err "preparation of build container [$BUILD_DOCK] failed" "$FUNCNAME"; return 1; }
    bc_install \
        build-essential \
        qtcreator \
        qtbase5-dev \
        cmake \
        xorg-dev \
        libssl-dev \
        libx11-dev \
        libsodium-dev \
        libgl1-mesa-glx \
        libegl1-mesa \
        libcurl4-openssl-dev \
        libavahi-compat-libdnssd-dev \
        qtdeclarative5-dev \
        libqt5svg5-dev \
        libsystemd-dev || return 1

    bc_exe 'git clone -j8 https://github.com/symless/synergy-core.git /tmp/syn || exit 1
            pushd /tmp/syn || exit 1
            git checkout v2-dev || exit 1
            export BOOST_ROOT="/home/$USER/boost"

            mkdir build || exit 1
            pushd build || exit 1
            cmake .. || exit 1
            make -j8 || exit 1
            #checkinstall -D --default --fstrans=yes --pkgname=keepassxc --pkgversion=0.0.1 --install=no --pakdir=/out || exit 1

            #popd
            #rm -rf /tmp/syn || exit 1'
}


# building instructions from https://copyq.readthedocs.io/en/latest/build-source-code.html
install_copyq() {
    local tmpdir

    readonly tmpdir="$TMP_DIR/copyq-build-${RANDOM}"

    report "building copyq"

    report "installing copyq build dependencies..."
    install_block '
        cmake
        qtbase5-private-dev
        qtscript5-dev
        qttools5-dev
        qttools5-dev-tools
        libqt5svg5-dev
        libxfixes-dev
        libxtst-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }

    execute "git clone -j8 $COPYQ_REPO_LOC $tmpdir" || return 1
    execute "pushd $tmpdir" || return 1

    execute 'cmake -DCMAKE_BUILD_TYPE=Release -DCMAKE_INSTALL_PREFIX=/usr/local .' || { err; popd; return 1; }
    execute "make" || { err; popd; return 1; }

    create_deb_install_and_store copyq

    execute "popd"
    execute "sudo rm -rf -- $tmpdir"
    return 0
}


# runs checkinstall in current working dir, and copies the created
# .deb file to $BASE_BUILDS_DIR/
create_deb_install_and_store() {
    local opt cmd ver pkg_name OPTIND

    while getopts "C:" opt; do
        case "$opt" in
            C) readonly cmd="$OPTARG" ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    pkg_name="$1"
    ver="${2:-'0.0.1'}"  # OPTIONAL

    check_progs_installed checkinstall || return 1
    report "creating .deb and installing with checkinstall..."

    # note --fstrans=no is because of checkinstall bug; see  https://bugs.debian.org/cgi-bin/bugreport.cgi?bug=717778
    execute "sudo checkinstall \
        -D --default --fstrans=no \
        --pkgname=$pkg_name --pkgversion=$ver \
        --pakdir=$BASE_BUILDS_DIR $cmd" || { err "checkinstall run failed. abort."; return 1; }

    return 0
}


# building instructions from https://github.com/mank319/Go-For-It
install_goforit() {
    local tmpdir

    readonly tmpdir="$TMP_DIR/goforit-build-${RANDOM}"
    report "building goforit..."

    execute "git clone -j8 $GOFORIT_REPO_LOC $tmpdir" || return 1

    execute "mkdir $tmpdir/build"
    execute "pushd $tmpdir/build" || return 1
    execute 'cmake ..' || { err; popd; return 1; }
    execute "make" || { err; popd; return 1; }

    create_deb_install_and_store goforit

    execute "popd"
    execute "sudo rm -rf -- '$tmpdir'"
    return 0
}


# TODO: not used atm; still not sure what runtime deps are required on the host
# instructions from  https://github.com/keepassxreboot/keepassxc/wiki/Set-up-Build-Environment-on-Linux
#                    https://github.com/keepassxreboot/keepassxc/wiki/Building-KeePassXC
# runtime dependencies from https://keepassxc.org/project
build_and_install_keepassxc_TODO_container_edition() {

    bc_install libxi-dev libxtst-dev qtbase5-dev \
            libqt5x11extras5-dev qttools5-dev qttools5-dev-tools \
            libgcrypt20-dev zlib1g-dev libyubikey-dev libykpers-1-dev || return 1

    bc_exe 'git clone -j8 https://github.com/keepassxreboot/keepassxc.git /tmp/kxc || exit 1
            pushd /tmp/kxc || exit 1

            mkdir build
            cd build
            cmake -DWITH_XC_AUTOTYPE=ON -DWITH_XC_HTTP=ON -DWITH_XC_YUBIKEY=ON' \
            '    -DCMAKE_BUILD_TYPE=Release .. || exit 1
            make -j8 || exit 1
            checkinstall -D --default --fstrans=yes --pkgname=keepassxc --pkgversion=0.0.1 --install=no --pakdir=/out || exit 1

            popd
            rm -rf /tmp/kxc || exit 1'
}


# downloads official AppImage and installs it.
#                    https://github.com/keepassxreboot/keepassxc/wiki/Set-up-Build-Environment-on-Linux
#                    https://github.com/keepassxreboot/keepassxc/wiki/Building-KeePassXC
#                    https://keepassxc.org/download
# note latest builds also avail from  https://github.com/keepassxreboot/keepassxc/releases/latest
install_keepassxc() {
    local tmpdir kxc_url kxc_dl page ver inst_loc img

    is_server && { report "we're server, skipping keepassxc installation."; return; }

    tmpdir="$(mktemp -d "keepassxc-XXXXX" -p $TMP_DIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }
    readonly kxc_url='https://keepassxc.org/download'
    readonly inst_loc="$BASE_PROGS_DIR/keepassxc"

    report "setting up keepassxc"

    execute "pushd -- $tmpdir" || return 1
    page="$(wget "$kxc_url" --user-agent="Mozilla/5.0 (X11; Linux x86_64; rv:50.0) Gecko/20100101 Firefox/50.0" -q -O -)" || { err "wgetting [$kxc_url] failed"; return 1; }
    kxc_dl="$(grep -Po '.*a href="\Khttps.*github.*keepassxreboot/keepassxc.*KeePassXC-.*x86_64\.AppImage(?=".*$)' <<< "$page")" || { err "parsing keepassxc download link failed"; return 1; }
    is_valid_url "$kxc_dl" || { err "[$kxc_dl] is not a valid download link"; return 1; }

    ver="$(grep -Po '.*releases/download/\K[0-9]+\.[0-9]+\.[-0-9]+(?=/.*$)' <<< "$kxc_dl")"
    [[ -z "$ver" ]] && { err "unable to parse keepassxc ver from url. abort."; return 1; }
    [[ -e "$inst_loc/installations/$ver" ]] && { report "[$ver] already exists, skipping"; return 0; }

    report "fetching [$kxc_dl]"
    execute "wget '$kxc_dl'" || { err "wgetting [$kxc_dl] failed."; return 1; }
    img="$(find . -type f -name '*.AppImage')"
    [[ -f "$img" ]] || { err "couldn't find downloaded appimage"; return 1; }
    execute "chmod +x '$img'" || return 1

    execute "mkdir -p -- '$inst_loc/installations/$ver'" || { err "keepassxc dir creation failed"; return 1; }
    execute "mv -- $img '$inst_loc/installations/$ver'"
    execute "pushd -- $inst_loc" || return 1
    [[ -h keepassxc ]] && rm -- keepassxc
    create_link "installations/$ver/$img" keepassxc
    create_link "$inst_loc/keepassxc" "$HOME/bin/keepassxc"

    execute "popd; popd"
    execute "sudo rm -rf -- '$tmpdir'"

    return 0
}


# building instructions from https://github.com/keepassx/keepassx
install_keepassx() {
    local tmpdir

    readonly tmpdir="$TMP_DIR/keepassx-build-${RANDOM}"
    report "building keepassx..."

    export QT_SELECT=qt5  # without defining this, autotype was not working (even the settings were missing for it)

    report "installing keepassx build dependencies..."
    install_block '
        build-essential
        cmake
        qtbase5-dev
        libqt5x11extras5-dev
        qttools5-dev
        qttools5-dev-tools
        libgcrypt20-dev
        zlib1g-dev
        libxi-dev
        libxtst-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }

    execute "git clone -j8 $KEEPASS_REPO_LOC $tmpdir" || return 1

    execute "mkdir $tmpdir/build"
    execute "pushd $tmpdir/build" || return 1
    execute 'cmake ..' || { err; popd; return 1; }
    execute "make" || { err; popd; return 1; }

    create_deb_install_and_store keepassx

    execute "popd"
    execute "sudo rm -rf -- '$tmpdir'"
    return 0
}


# https://github.com/PandorasFox/i3lock-color
# this is a depency for i3lock-fancy.
install_i3lock() {
    local tmpdir

    readonly tmpdir="$TMP_DIR/i3lock-build-${RANDOM}/build"
    report "building i3lock..."

    report "installing i3lock build dependencies..."

    install_block '
      autoconf
      automake
      libev-dev
      libxcb-composite0
      libxcb-composite0-dev
      libxcb-xinerama0
      libxcb-randr0
      libxcb-xinerama0-dev
      libxcb-xkb-dev
      libxcb-image0-dev
      libxcb-util0-dev
      libxkbcommon-x11-dev
      libjpeg62-turbo-dev
      libpam0g-dev
      pkg-config
      xcb-proto
      libxcb-xrm-dev
      libxcb-randr0-dev
      libxkbcommon-dev
      libcairo2-dev
      libxcb1-dev
      libxcb-dpms0-dev' || { err 'failed to install i3lock build deps. abort.'; return 1; }

    # clone the repository
    execute "git clone -j8 $I3_LOCK_LOC '$tmpdir'" || return 1
    execute "pushd $tmpdir" || return 1
    execute "git tag -f 'git-$(git rev-parse --short HEAD)'" || return 1
    build_deb i3lock-color || err "build_deb() for i3lock-color failed"
    execute 'sudo dpkg -i ../i3lock-color_*.deb'

    # old, checkinstall-compliant logic:
    ## compile & install:
    #execute 'autoreconf --install' || return 1
    #execute './configure' || return 1
    #execute 'make' || return 1
    #create_deb_install_and_store i3lock

    execute "popd"
    execute "sudo rm -rf -- '$tmpdir'"

    return 0
}


install_i3lock_fancy() {
    local tmpdir

    readonly tmpdir="$TMP_DIR/i3lock-fancy-build-${RANDOM}/build"
    report "building i3lock-fancy..."

    # clone the repository
    execute "git clone -j8 $I3_LOCK_FANCY_LOC '$tmpdir'" || return 1
    execute "pushd $tmpdir" || return 1
    #build_deb -D '--parallel' i3lock-fancy || err "build_deb() for i3lock-fancy failed"
    #echo "got these: $(ls -lat ../*.deb)"
    #exit
    #execute 'sudo dpkg -i ../i3lock-fancy_*.deb'

    # old, checkinstall-compliant logic:
    ## compile & install:
    #execute 'autoreconf --install' || return 1
    #execute './configure' || return 1
    #execute 'make' || return 1

    # TODO: note this guy will already install it! the makefile of fancy is odd...
    create_deb_install_and_store i3lock-fancy

    execute "popd"
    execute "sudo rm -rf -- '$tmpdir'"

    return 0
}


install_betterlockscreen() {  # https://github.com/pavanjadhaw/betterlockscreen
    wget -O ~/bin/betterlockscreen "https://raw.githubusercontent.com/pavanjadhaw/betterlockscreen/master/betterlockscreen" || return 1
    execute "chmod u+x ~/bin/betterlockscreen"
}


# https://github.com/Airblader/i3/wiki/Building-from-source
# see also https://github.com/maestrogerardo/i3-gaps-deb for debian pkg building logic
install_i3() {
    local tmpdir

    _apply_patches() {
        local f

        f="$TMP_DIR/i3-patch-${RANDOM}.patch"
        #curl --fail -o "$f" 'https://raw.githubusercontent.com/ashinkarov/i3-extras/master/window-icons/window-icons.patch' || { err "window-icons-patch download failed"; return 1; }
        curl --fail -o "$f" 'https://raw.githubusercontent.com/laur89/i3-extras/master/window-icons/window-icons.patch' || { err "window-icons-patch download failed"; return 1; }
        report "patching window-icons..."
        patch -p1 < "$f" || { err "applying window-icons.patch failed"; return 1; }

        curl --fail -o "$f" 'https://raw.githubusercontent.com/laur89/i3-extras/master/i3-v-h-split-label-swap.patch' || { err "i3-v-h-split-label-swap-patch download failed"; return 1; }
        report "patching v-h split label..."
        patch -p1 < "$f" || { err "applying i3-v-h-split-label-swap-patch failed"; return 1; }

        # TODO: fix back to maestrogerardo repo once my PR #23 is accepted:
        #curl --fail -o "$f" 'https://raw.githubusercontent.com/maestrogerardo/i3-gaps-deb/master/patches/0001-debian-Disable-sanitizers.patch' || { err "disable-sanitizers-patch download failed"; return 1; }
        curl --fail -o "$f" 'https://raw.githubusercontent.com/laur89/i3-gaps-deb/master/patches/0001-debian-Disable-sanitizers.patch' || { err "disable-sanitizers-patch download failed"; return 1; }
        report "patching removal of debian sanitizers..."
        patch --forward -r - -p1 < "$f" || { err "applying disable-sanitizers.patch failed"; return 1; }
    }

    # from https://github.com/maestrogerardo/i3-gaps-deb/blob/master/i3-gaps-deb
    _fix_rules() {
        report "Fix i3 debian/rules file..."
        cat <<EOF >>debian/rules
override_dh_install:
override_dh_installdocs:
override_dh_installman:
	dh_install -O--parallel
EOF
    }

    readonly tmpdir="$TMP_DIR/i3-gaps-build-${RANDOM}/build"
    report "building i3-gaps... (note install_i3_deps() will be called in the end)"; sleep 2

    report "installing i3 build dependencies..."
    install_block '
        gcc
        make
        dh-autoreconf
        libxcb-keysyms1-dev
        libpango1.0-dev
        libxcb-util0-dev
        xcb
        libxcb1-dev
        libxcb-icccm4-dev
        libyajl-dev
        libev-dev
        libxcb-xkb-dev
        libxcb-cursor-dev
        libxkbcommon-dev
        libxcb-xinerama0-dev
        libxkbcommon-x11-dev
        libstartup-notification0-dev
        libxcb-randr0-dev
        libxcb-xrm0
        libxcb-xrm-dev
        libxcb-shape0-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }


    # clone the repository
    execute "git clone -j8 $I3_REPO_LOC '$tmpdir'" || return 1
    execute "pushd $tmpdir" || return 1

    _apply_patches  # TODO: should we bail on error?
    _fix_rules

    # alternatively, install build-deps based on what's in debian/control:
    # (note mk-build-deps needs equivs pkg)
    sudo mk-build-deps \
            -t 'apt-get -o Debug::pkgProblemResolver=yes --no-install-recommends -qqy' \
            -i -r debian/control || { err "automatic build-dep resolver for i3 failed w/ [$?]"; return 1; }
    # alternatively, could also do $ sudo apt-get -y build-dep i3-wm

    build_deb || { err "build_deb() for i3 failed"; return 1; }
    execute 'sudo dpkg -i ../i3-wm_*.deb'
    execute 'sudo dpkg -i ../i3_*.deb'

    # TODO: deprecated, check-install based way:
    ## compile & install
    #execute 'autoreconf --force --install' || return 1
    #execute 'rm -rf build/' || return 1
    #execute 'mkdir -p build && pushd build/' || return 1

    ## Disabling sanitizers is important for release versions!
    ## The prefix and sysconfdir are, obviously, dependent on the distribution.
    #execute '../configure --prefix=/usr/local --sysconfdir=/etc --disable-sanitizers' || return 1
    #execute 'make'
    #create_deb_install_and_store i3-gaps
    #execute "popd"

    # --------------------------
    # install required perl modules (eg for i3-save-tree):
    #execute "pushd AnyEvent-I3" || return 1
    # TODO: libanyevent-i3-perl from repo?
    #build_deb i3-anyevent || err "build_deb() for i3-anyevent failed"
    install_block 'libanyevent-i3-perl' # alternative to building it ourselves

    # TODO: deprecated, check-install based way:
    #execute 'perl Makefile.PL'
    #execute 'make'
    #create_deb_install_and_store i3-anyevent
    #install_block "libjson-any-perl"
    #execute "popd"
    # --------------------------

    execute "popd"
    execute "sudo rm -rf -- '$tmpdir'"

    install_i3_deps
    install_i3_conf
    return 0
}


# TODO: this installation method is dirty; consider https://github.com/pipxproject/pipx
#
# just fyi: to install local copy in dev mode:
#      /usr/bin/env python3 -m pip install --user --upgrade --force-reinstall --editable .
#
# pass -g opt to install from github; in that case 2 args are to be provided - user & repo,
# and we can install one pkg at a time.
py_install() {
    local opt OPTIND github pkg

    while getopts "g" opt; do
        case "$opt" in
            g) github=1 ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    pkg="$*"
    [[ "$github" -eq 1 ]] && pkg="git+ssh://git@github.com/$1/$2.git"  # append @branch for a specific branch
    execute "/usr/bin/env python3 -m pip install --user --upgrade $pkg"
}


rb_install() {
    execute "gem install --user-install $*"
}


snap_install() {
    execute "sudo snap install $*"
}

install_i3_conf() {
    local conf

    conf="$HOME/.config/i3/config"  # conf file _to be_ generated;

    py_install update-conf.py || { err "update-conf.py install failed"; return 1; }
    update-conf.py -f "$conf" || { err "i3 config install failed w/ $?"; return 1; }
}

install_i3_deps() {
    local f
    f="$TMP_DIR/i3-dep-${RANDOM}"

    py_install i3ipc      # https://github.com/altdesktop/i3ipc-python

    # rofi-tmux:
    #py_install rofi-tmux  # https://github.com/viniarck/rofi-tmux  # TODO use this as soon as/if our PR is accepted; or not, it's rather slow to start
    #py_install -g laur89 rofi-tmux  # https://github.com/laur89/rofi-tmux (note it includes i3 integration); aka rtf;  this version is extension of the original
    clone_or_pull_repo "laur89" "rofi-tmux" "$BASE_DEPS_LOC"
    #execute "pip3 install --user -r ${BASE_DEPS_LOC}/rofi-tmux/requirements.txt"  # as we're not installing rft w/ pip, we need to manually install deps
    create_link "${BASE_DEPS_LOC}/rofi-tmux/rft/main.py" "$HOME/bin/rft"

    # install i3-quickterm   # https://github.com/lbonn/i3-quickterm
    #curl --output "$f" 'https://raw.githubusercontent.com/lbonn/i3-quickterm/master/i3-quickterm' \  # TODO: enable this one if/when PR is accepted
    curl --fail --output "$f" 'https://raw.githubusercontent.com/laur89/i3-quickterm/master/i3-quickterm' \
            && execute "chmod +x -- '$f'" && execute "mv -- '$f' $HOME/bin/i3-quickterm" || err "installing i3-quickterm failed /w $?"


    # install i3-cycle-windows   # https://github.com/DavsX/dotfiles/blob/master/bin/i3_cycle_windows
    # this script defines a 'next' window, so we could bind it to someting like super+mouse_wheel;
    curl --fail --output "$f" 'https://raw.githubusercontent.com/DavsX/dotfiles/master/bin/i3_cycle_windows' \
            && execute "chmod +x -- '$f'" && execute "mv -- '$f' $HOME/bin/i3-cycle-windows" || err "installing i3-cycle-windows failed /w $?"


    # create links of our own i3 scripts on $PATH:
    create_symlinks "$BASE_DATA_DIR/dev/scripts/i3" "$HOME/bin"


    execute "sudo rm -rf -- '$f'"
}


# the ./build.sh version
# https://github.com/polybar/polybar/wiki/Compiling
# https://github.com/polybar/polybar
install_polybar() {
    local tmpdir

    tmpdir="$(mktemp -d "polybar-build-XXXXX" -p $TMP_DIR)" || { err "unable to create tempdir with \$ mktemp"; return 1; }

    report "installing polybar build dependencies..."

    # note: clang is installed because of  https://github.com/polybar/polybar/issues/572
    install_block '
        clang
        cmake
        cmake-data
        pkg-config
        python3-sphinx
        libcairo2-dev
        libxcb1-dev
        libxcb-util0-dev
        libxcb-randr0-dev
        libxcb-composite0-dev
        python-xcbgen
        xcb-proto
        libxcb-image0-dev
        libxcb-ewmh-dev
        libxcb-icccm4-dev

        libxcb-xkb-dev
        libxcb-xrm-dev
        libxcb-cursor-dev
        libasound2-dev
        libpulse-dev
        libjsoncpp-dev
        libmpdclient-dev
        libcurl4-openssl-dev
        libnl-genl-3-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }

    #execute "git clone --recursive -j8 $POLYBAR_REPO_LOC '$tmpdir'" || return 1
    execute "pushd $tmpdir" || return 1
    fetch_extract_tarball_from_git polybar polybar '\d+\.\d+\.tar' || return 1
    execute "pushd *" || return 1
    execute "./build.sh --auto --all-features --no-install" || return 1

    execute "pushd build/" || return 1
    create_deb_install_and_store polybar  # TODO: note still using checkinstall
    execute "popd; popd; popd"
    execute "sudo rm -rf -- '$tmpdir'"
    return 0
}


install_dwm() {
    local build_dir

    readonly build_dir="$HOME/.dwm/w0ngBuild/source6.0"

    clone_or_link_castle dwm-setup laur89 github.com
    [[ -d "$build_dir" ]] || { err "[$build_dir] is not a dir. skipping dwm installation."; return 1; }

    report "installing dwm build dependencies..."
    install_block '
        suckless-tools
        build-essential
        libx11-dev
        libxinerama-dev
        libpango1.0-dev
        libxtst-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }

    execute "pushd $build_dir" || return 1
    report "installing dwm..."
    execute "sudo make clean install"
    execute "popd"
    return 0
}


# see https://wiki.debian.org/Packaging/Intro?action=show&redirect=IntroDebianPackaging
# and https://vincent.bernat.ch/en/blog/2019-pragmatic-debian-packaging
#
# https://github.com/phusion/debian-packaging-for-the-modern-developer/tree/master/tutorial-1
#
# see also pbuilder, https://wiki.debian.org/SystemBuildTools
build_deb() {
    local opt pkg_name configure_extra dh_extra deb OPTIND

    while getopts "C:D:" opt; do
        case "$opt" in
            C) readonly configure_extra="$OPTARG" ;;
            D) readonly dh_extra="$OPTARG" ;;
            *) fail "unexpected arg passed to ${FUNCNAME}()" ;;
        esac
    done
    shift "$((OPTIND-1))"

    pkg_name="$1"

    if ! [[ -d debian ]]; then
        report "no debian/ in pwd, generating scaffolding..."
        execute 'mkdir -- debian' || return 1

        # create compat:
        execute 'echo 11 > debian/compat' || return 1  # compat 11 is from debian 9+

        # create changelog:
        echo "$pkg_name (0.0-0) UNRELEASED; urgency=medium

  * New upstream release

 -- la.packager.eu <la@packager.eu>  $(date --rfc-email)
" > debian/changelog || return 1
        # OR use dhc:  $ dch --create -v 0.0-0 --package $pkg_name

        # create control:
        echo "Source: $pkg_name
Maintainer: Laur Aliste <laur.aliste@packager.eu>

Package: $pkg_name
Architecture: any
Description: custom-built $pkg_name package
" > debian/control || return 1

        # create rules:
        #printf '#!/usr/bin/make -f

#DISTRIBUTION = $(shell grep -Po "^PRETTY_NAME=.*Linux\s+\K.*(?=\")" /etc/os-release)
#VERSION = 0.0.1
#PACKAGEVERSION = $(VERSION)-0~$(DISTRIBUTION)0

#%%:
	#dh $@

#override_dh_auto_clean:
#override_dh_auto_test:
#override_dh_auto_build:
#override_dh_auto_install:
	#./configure --prefix=/usr
	#make
	#make install DESTDIR=debian/memcached

#override_dh_gencontrol:
	#dh_gencontrol -- -v$(PACKAGEVERSION)' > debian/rules || return 1
        printf '#!/usr/bin/make -f

#DISTRIBUTION = $(shell sed -n "s/^VERSION_CODENAME=//p" /etc/os-release)
#DISTRIBUTION = $(shell grep -Po "^PRETTY_NAME=.*Linux\s+\K.*(?=\\")" /etc/os-release)
DISTRIBUTION = testing
VERSION = 0.0.1
PACKAGEVERSION = $(VERSION)-0~$(DISTRIBUTION)0

%%:
	dh $@ %s

override_dh_auto_test:
override_dh_auto_configure:
	dh_auto_configure -- %s --disable-sanitizers
override_dh_gencontrol:
	dh_gencontrol -- -v$(PACKAGEVERSION)' "$dh_extra" "$configure_extra" > debian/rules || return 1
    fi

    # note built .deb will end up in a parent dir:
    execute 'debuild -us -uc -b' || return 1

    # install:  # can't install here, as we don't know which debs to select
    #deb="$(find ../ -mindepth 1 -maxdepth 1 -type f -name '*.deb')"
    #[[ -f "$deb" ]] || { err "couldn't find built [$pkg_name] .deb in parent dir"; return 1; }
    #execute "sudo dpkg -i '$deb'" || { err "installing built .deb [$deb] failed"; return 1; }
}


setup_nvim() {
    nvim_post_install_configuration

    if [[ "$MODE" -eq 1 ]]; then
        execute "sudo apt-get --yes remove vim vim-runtime gvim vim-tiny vim-common vim-gui-common"  # no vim pls
        nvim +PlugInstall +qall
    fi

    # YCM installation AFTER the first nvim launch (nvim launch pulls in ycm plugin, among others)!
    install_YCM
    py_install neovim-remote     # https://github.com/mhinz/neovim-remote
}


# https://github.com/neovim/neovim/wiki/Installing-Neovim
#install_neovim() {  # the AppImage version
    #local tmpdir nvim_confdir inst_loc nvim_url

    #tmpdir="$(mktemp -d "nvim-download-XXXXX" -p $TMP_DIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }
    #readonly nvim_confdir="$HOME/.config/nvim"
    #readonly inst_loc="$BASE_PROGS_DIR/neovim"
    #nvim_url='https://github.com/neovim/neovim/releases/download/nightly/nvim.appimage'

    #report "setting up nvim..."

    #execute "pushd -- $tmpdir" || return 1
    #execute "curl -LO $nvim_url" || { err "curling latest nvim appimage failed"; return 1; }
    #execute "chmod +x nvim.appimage" || return 1

    #execute "mkdir -p -- '$inst_loc/'" || { err "neovim dir creation failed"; return 1; }
    #execute "mv -- nvim.appimage '$inst_loc/'" || return 1
    #create_link "$inst_loc/nvim.appimage" "$HOME/bin/nvim"

    #execute "popd" || { err; return 1; }
    #execute "sudo rm -rf -- '$tmpdir'"

    ## post-install config:

    ## create links (as per https://neovim.io/doc/user/nvim_from_vim.html):
    #create_link "$HOME/.vim" "$nvim_confdir"
    #create_link "$HOME/.vimrc" "$nvim_confdir/init.vim"

    ## as per https://github.com/neovim/neovim/wiki/Installing-Neovim:
    #execute "sudo pip2 install --upgrade neovim"
    #execute "sudo pip3 install --upgrade neovim"
    ##install_block 'python-neovim python3-neovim'

    #return 0
#}

# https://github.com/neovim/neovim/wiki/Building-Neovim
# https://github.com/neovim/neovim/wiki/Installing-Neovim
#install_neovim() {  # the build-from-source version
    #local tmpdir nvim_confdir

    #readonly tmpdir="$TMP_DIR/nvim-build-${RANDOM}"
    #readonly nvim_confdir="$HOME/.config/nvim"

    #report "setting up nvim..."

    ## first find whether we have deb packages from other times:
    #if confirm "do you wish to install nvim from our previous build .deb package, if available?"; then
        #install_from_deb neovim || return 1
    #else
        #report "building neovim..."

        #report "installing neovim build dependencies..."  # https://github.com/neovim/neovim/wiki/Building-Neovim#build-prerequisites
        #install_block '
            #libtool
            #libtool-bin
            #autoconf
            #automake
            #cmake
            #g\+\+
            #pkg-config
            #unzip
        #' || { err 'failed to install neovim build deps. abort.'; return 1; }

        #execute "git clone -j8 $NVIM_REPO_LOC $tmpdir" || return 1
        #execute "pushd $tmpdir" || { err; return 1; }

        ## TODO: checkinstall fails with neovim (bug in checkinstall afaik):
        #execute "make clean" || { err; return 1; }
        ##execute "make CMAKE_BUILD_TYPE=Release" || { err; return 1; }
        ##create_deb_install_and_store neovim || { err; return 1; }

        ## note it'll be installed into separate location; eases with uninstall; requires it setting on $PATH;
        #execute "sudo make CMAKE_EXTRA_FLAGS='-DCMAKE_INSTALL_PREFIX=/usr/local/neovim' CMAKE_BUILD_TYPE=Release" || { err; return 1; }  # TODO  remove this once checkinstall issue is resolved;
        #execute "sudo make install" || { err; return 1; }  # TODO  remove this once checkinstall issue is resolved;

        #execute "popd"
        #execute "sudo rm -rf -- $tmpdir"
    #fi

    ## post-install config:

    ## create links (as per https://neovim.io/doc/user/nvim_from_vim.html):
    #create_link "$HOME/.vim" "$nvim_confdir"
    #create_link "$HOME/.vimrc" "$nvim_confdir/init.vim"

    ## as per https://github.com/neovim/neovim/wiki/Installing-Neovim:
    ##execute "sudo pip2 install --upgrade neovim"
    ##execute "sudo pip3 install --upgrade neovim"
    #install_block 'python-neovim python3-neovim'

    #return 0
#}


#install_vim() {

    #report "setting up vim..."

    #build_and_install_vim || return 1
    #vim_post_install_configuration

    #report "launching vim, so the initialization could be done (pulling in plugins et al. simply exit vim when it's done.)"
    #echo 'initialising vim; simply exit when plugin fetching is complete. (quit with  :qa!)' | \
        #vim -  # needs to be non-root

    ## YCM installation AFTER the first vim launch (vim launch pulls in ycm plugin, among others)!
    #install_YCM
#}


# NO plugin config should go here (as it's not guaranteed they've been installed by this time)
nvim_post_install_configuration() {
    local i nvim_confdir

    readonly nvim_confdir="$HOME/.config/nvim"

    execute "sudo mkdir -p /root/.config"
    create_link --sudo "$nvim_confdir" "/root/.config/"  # root should use same conf

    _setup_vim_sessions_dir() {
        local stored_vim_sessions vim_sessiondir

        readonly stored_vim_sessions="$BASE_DATA_DIR/.vim_sessions"
        readonly vim_sessiondir="$nvim_confdir/sessions"

        # link sessions dir, if stored @ $BASE_DATA_DIR: (related to the 'xolox/vim-session' plugin)
        # note we don't want sessions in homesick, as they're likely to be machine-dependent.
        if [[ -d "$stored_vim_sessions" ]]; then
            # refresh link:
            execute "rm -rf -- $vim_sessiondir"
        else  # $stored_vim_sessions does not exist; init it anyways
            if [[ -d "$vim_sessiondir" ]]; then
                execute "mv -- $vim_sessiondir $stored_vim_sessions"
            else
                execute "mkdir -- $stored_vim_sessions"
            fi
        fi

        create_link "$stored_vim_sessions" "$vim_sessiondir"
    }

    _setup_vim_sessions_dir
}


# TODO: deprecate?
# NO plugin config should go here (as it's not guaranteed they've been installed by this time)
vim_post_install_configuration() {
    local i

    # generate links for root, if not existing:
    for i in \
            .vim \
            .vimrc \
            .vimrc.first \
            .vimrc.last \
                ; do
        i="$HOME/$i"

        if [[ ! -f "$i" && ! -d "$i" ]]; then
            err "[$i] does not exist - can't link to /root/"
            continue
        else
            create_link --sudo "$i" "/root/"
        fi
    done

    function _setup_vim_sessions_dir() {
        local stored_vim_sessions vim_sessiondir

        readonly stored_vim_sessions="$BASE_DATA_DIR/.vim_sessions"
        readonly vim_sessiondir="$HOME/.vim/sessions"

        # link sessions dir, if stored @ $BASE_DATA_DIR: (related to the 'xolox/vim-session' plugin)
        # note we don't want sessions in homesick, as they're likely to be machine-dependent.
        if [[ -d "$stored_vim_sessions" ]]; then
            # refresh link:
            execute "rm -rf -- $vim_sessiondir"
        else  # $stored_vim_sessions does not exist; init it anyways
            if [[ -d "$vim_sessiondir" ]]; then
                execute "mv -- $vim_sessiondir $stored_vim_sessions"
            else
                execute "mkdir -- $stored_vim_sessions"
            fi
        fi

        create_link "$stored_vim_sessions" "$vim_sessiondir"
    }

    _setup_vim_sessions_dir

    unset _setup_vim_sessions_dir
}


# building instructions from https://github.com/Valloric/YouCompleteMe/wiki/Building-Vim-from-source
build_and_install_vim() {
    local tmpdir expected_runtimedir python_confdir python3_confdir i

    readonly tmpdir="$TMP_DIR/vim-build-${RANDOM}"
    readonly expected_runtimedir='/usr/local/share/vim/vim81'  # depends on the ./configure --prefix
    readonly python_confdir='/usr/lib/python2.7/config-x86_64-linux-gnu'
    readonly python3_confdir='/usr/lib/python3.6/config-3.6m-x86_64-linux-gnu'

    report "building vim..."

    for i in "$python_confdir" "$python3_confdir"; do
        [[ -d "$i" ]] || err "[$i] is not a valid dir; will install vim, but you'll need to recompile"
    done

    report "removing already installed vim components..."
    execute "sudo apt-get --yes remove vim vim-runtime gvim vim-tiny vim-common vim-gui-common"

    report "installing vim build dependencies..."
    install_block '
        libncurses5-dev
        libgnome2-dev
        libgnomeui-dev
        libgtk2.0-dev
        libatk1.0-dev
        libbonoboui2-dev
        libcairo2-dev
        libx11-dev
        libxpm-dev
        libxt-dev
        python-dev
        python3-dev
        ruby-dev
        lua5.1
        lua5.1-dev
        libperl-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }

    execute "git clone -j8 $VIM_REPO_LOC $tmpdir" || return 1
    execute "pushd $tmpdir" || return 1

            #--enable-pythoninterp=yes \
            #--with-python-config-dir=$python_confdir \
    execute "./configure \
            --with-features=huge \
            --enable-multibyte \
            --enable-rubyinterp=yes \
            --enable-python3interp=yes \
            --with-python3-config-dir=$python3_confdir \
            --enable-perlinterp=yes \
            --enable-luainterp=yes \
            --enable-gui=gtk2 \
            --enable-cscope \
            --prefix=/usr/local \
    " || { err 'vim configure build phase failed.'; return 1; }

    execute "make VIMRUNTIMEDIR=$expected_runtimedir" || { err 'vim make failed'; return 1; }
    #!(make sure rutimedir is correct; at this moment 74 was)
    create_deb_install_and_store vim || { err; return 1; }  # TODO: remove checkinstall

    execute "popd"
    execute "sudo rm -rf -- $tmpdir"
    if ! [[ -d "$expected_runtimedir" ]]; then
        err "[$expected_runtimedir] is not a dir; these match 'vim' under [$(dirname -- "$expected_runtimedir")]:"
        err "$(find "$(dirname -- "$expected_runtimedir")" -maxdepth 1 -mindepth 1 -type d -name 'vim*' -print)"
        return 1
    fi

    return 0
}


# note: instructions & info here: https://github.com/Valloric/YouCompleteMe
# note2: available in deb repo as 'ycmd'
install_YCM() {  # the quick-and-not-dirty install.py way
    local ycm_plugin_root

    readonly ycm_plugin_root="$HOME/.config/nvim/bundle/YouCompleteMe"

    # sanity
    if ! [[ -d "$ycm_plugin_root" ]]; then
        err "expected vim plugin YouCompleteMe to be already pulled"
        err "you're either missing vimrc conf or haven't started vim yet (first start pulls all the plugins)."
        return 1
    fi

    # install deps
    install_block '
        build-essential
        cmake
        python3-dev
    '

    # install YCM
    execute "pushd -- $ycm_plugin_root" || return 1
    execute --ignore-errs "python3 ./install.py --all" || return 1
    execute "popd"
}


# note: instructions & info here: https://github.com/Valloric/YouCompleteMe#full-installation-guide
# note2: available in deb repo as 'ycmd'
#install_YCM() {  # the manual, full-installation-guide way
    #local ycm_root ycm_build_root libclang_root ycm_plugin_root ycm_third_party_rootdir

    #readonly ycm_root="$BASE_BUILDS_DIR/YCM"
    #readonly ycm_build_root="$ycm_root/ycm_build"
    #readonly libclang_root="$ycm_root/llvm"
    #readonly ycm_plugin_root="$HOME/.vim/bundle/YouCompleteMe"
    #readonly ycm_third_party_rootdir="$ycm_plugin_root/third_party/ycmd/third_party"

    #function __fetch_libclang() {
        #local tmpdir tarball dir

        #tmpdir="$(mktemp -d "ycm-tempdir-XXXXX" -p $TMP_DIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }
        #readonly tarball="$(basename -- "$CLANG_LLVM_LOC")"

        #execute "pushd -- $tmpdir" || return 1
        #report "fetching [$CLANG_LLVM_LOC]"
        #execute "wget '$CLANG_LLVM_LOC'" || { err "wgetting [$CLANG_LLVM_LOC] failed."; return 1; }
        #extract "$tarball" || { err "extracting [$tarball] failed."; return 1; }
        #dir="$(find . -mindepth 1 -maxdepth 1 -type d)"
        #[[ -d "$dir" ]] || { err "couldn't find unpacked clang directory"; return 1; }
        #[[ -d "$libclang_root" ]] && execute "sudo rm -rf -- '$libclang_root'"
        #execute "mv -- '$dir' '$libclang_root'"

        #execute "popd"
        #execute "sudo rm -rf -- '$tmpdir'"

        #return 0
    #}

    ## sanity
    #if ! [[ -d "$ycm_plugin_root" ]]; then
        #err "expected vim plugin YouCompleteMe to be already pulled"
        #err "you're either missing vimrc conf or haven't started vim yet (first start pulls all the plugins)."
        #return 1
    #fi

    #[[ -d "$ycm_root" ]] || execute "mkdir -- '$ycm_root'"

    ## first make sure we have libclang:
    #if [[ -d "$libclang_root" ]]; then
        #if ! confirm "found existing libclang at [$libclang_root]; use this one? (answering 'no' will fetch new version)"; then
            #__fetch_libclang || { err "fetching libclang failed; aborting YCM installation."; return 1; }
        #fi
    #else
        #__fetch_libclang || { err "fetching libclang failed; aborting YCM installation."; return 1; }
    #fi
    #unset __fetch_libclang  # to keep the inner function really an inner one (ie private).

    ## clean previous builddir, if existing:
    #[[ -d "$ycm_build_root" ]] && execute "sudo rm -rf -- '$ycm_build_root'"

    ## build:
    #execute "mkdir -- '$ycm_build_root'"
    #execute "pushd -- '$ycm_build_root'" || return 1
    #execute "cmake -G 'Unix Makefiles' \
        #-DPATH_TO_LLVM_ROOT=$libclang_root \
        #. \
        #~/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp \
    #"
    #execute 'cmake --build . --target ycm_core --config Release'
    #execute "popd"

    #############
    ## set up support for additional languages:
    ##     C# (assumes you have mono installed):
    #execute "pushd $ycm_third_party_rootdir/OmniSharpServer" || return 1
    #execute "xbuild /property:Configuration=Release /p:NoCompilerStandardLib=false"  # https://github.com/Valloric/YouCompleteMe/issues/2188
    #execute "popd"

    ##     js:
    #execute "pushd $ycm_third_party_rootdir/tern_runtime" || return 1
    #execute "$NPM_PRFX npm install --production"
    #execute "popd"

    ##     go:
    ## TODO
#}


# consider also https://github.com/whitelynx/artwiz-fonts-wl
# consider also https://github.com/slavfox/Cozette
#
# note pango 1.44+ drops FreeType support, thus losing support for traditional
# BDF/PCF bitmap fonts; eg Terminess Powerline from powerline fonts.
# consider patching yourself: https://www.reddit.com/r/archlinux/comments/f5ciqa/terminus_bitmap_font_with_powerline_symbols/fhyeuws/
#
# https://github.com/dse/bitmapfont2ttf/blob/master/bin/bitmapfont2ttf
# https://gitlab.freedesktop.org/xorg/app/fonttosfnt
install_fonts() {
    local dir

    report "installing fonts..."

    install_block '
        fonts-powerline
        ttf-mscorefonts-installer
        xfonts-75dpi
        xfonts-75dpi-transcoded
        xfonts-100dpi
        xfonts-100dpi-transcoded
        xfonts-mplus
        xfonts-base
        xbitmaps
    '

    is_native && install_block 'fontforge gucharmap'

    # https://github.com/ryanoasis/nerd-fonts#option-3-install-script
    install_nerd_fonts() {
        local tmpdir fonts i

        readonly tmpdir="$TMP_DIR/nerd-fonts-${RANDOM}"
        fonts=(
            Hack
            SourceCodePro
            AnonymousPro
            Terminus
            Ubuntu
            UbuntuMono
            DejaVuSansMono
            DroidSansMono
            InconsolataGo
            Inconsolata
            Iosevka
        )

        report "installing nerd-fonts..."

        execute "git clone --recursive -j8 $NERD_FONTS_REPO_LOC '$tmpdir'" || return 1
        execute "pushd $tmpdir" || return 1
        for i in "${fonts[@]}"; do
            execute --ignore-errs "./install.sh '$i'"
        done

        execute "popd"
        execute "sudo rm -rf -- '$tmpdir'"
        return 0
    }

    # https://github.com/powerline/fonts
    # note this is same as 'fonts-powerline' pkg
    install_powerline_fonts() {
        local tmpdir

        readonly tmpdir="$TMP_DIR/powerline-fonts-${RANDOM}"
        report "installing powerline-fonts..."

        execute "git clone --depth=1 -j8 $PWRLINE_FONTS_REPO_LOC '$tmpdir'" || return 1
        execute "pushd $tmpdir" || return 1
        execute "./install.sh" || return 1

        execute "popd"
        execute "sudo rm -rf -- '$tmpdir'"
        return 0
    }

    # https://github.com/stark/siji   (bitmap font icons)
    install_siji() {
        local tmpdir

        readonly tmpdir="$TMP_DIR/siji-font-$RANDOM"

        execute "git clone -j8 https://github.com/stark/siji $tmpdir" || { err 'err cloning siji font'; return 1; }
        execute "pushd $tmpdir" || return 1

        execute "./install.sh" || { err "siji-font install.sh failed with $?"; return 1; }

        execute "popd"
        execute "sudo rm -rf -- '$tmpdir'"
        return 0
    }

    # see  https://wiki.archlinux.org/index.php/Font_configuration#Disable_bitmap_fonts
    enable_bitmap_rendering() {
        local file

        readonly file='/etc/fonts/conf.d/70-no-bitmaps.conf'

        [[ -f "$file" ]] || { report "[$file] does not exist; cannot enable bitmap font render"; return 0; }
        execute "sudo rm -- '$file'"
        return $?
    }

    enable_bitmap_rendering; unset enable_bitmap_rendering
    install_nerd_fonts; unset install_nerd_fonts
    #install_powerline_fonts; unset install_powerline_fonts  # commented out as we're installing it via apt
    install_siji; unset install_siji

    # TODO: guess we can't use xset when xserver is not yet running:
    #execute "xset +fp ~/.fonts"
    #execute "mkfontscale ~/.fonts"
    #execute "mkfontdir ~/.fonts"
    #execute "pushd ~/.fonts" || return 1

    ## also install fonts in sub-dirs:
    #for dir in * ; do
        #if [[ -d "$dir" ]]; then
            #execute "pushd $dir" || return 1
            #execute "xset +fp $PWD"
            #execute "mkfontscale"
            #execute "mkfontdir"
            #execute "popd"
        #fi
    #done

    #execute "xset fp rehash"
    #execute "fc-cache -fv"
    #execute "popd"
}


# majority of packages get installed at this point;
install_from_repo() {
    local block blocks block1 block2 block3 block4 block5 extra_apt_params
    local block1_nonwin block2_nonwin block3_nonwin

    declare -A extra_apt_params=(
    )

    declare -ar block1_nonwin=(
        smartmontools
        pm-utils
        ntfs-3g
        erlang
        acpid
        lm-sensors
        psensor
        xsensors
        hardinfo
        inxi
        macchanger
        nftables
        firewalld
        fail2ban
        udisks2
        udiskie
    )
    # old/deprecated block1_nonwin:
    #    ufw - iptables frontend, debian now on nftables instead
    #    gufw
    #

    # consider apulse instead of pulseaudio;
    # TODO: xorg needs to be pulled into non-win (but still has to be installed for virt!) block:
    declare -ar block1=(
        xorg
        x11-apps
        xinit
        alsa-utils
        pulseaudio
        pavucontrol
        pulsemixer
        pulseaudio-equalizer
        pasystray
        ca-certificates
        aptitude
        gdebi
        snapd
        sudo
        libnotify-bin
        dunst
        rofi
        compton
        dosfstools
        checkinstall
        build-essential
        devscripts
        equivs
        cmake
        ruby
        ipython3
        python3
        python3-dev
        python3-venv
        python3-pip
        python-dev
        python-flake8
        python3-flake8
        msbuild
        mono-complete
        curl
        httpie
        lshw
        fuse
        fuseiso
    )

    # for .NET dev, consider also nuget pkg;
    declare -ar block2_nonwin=(
        netdata
        wireshark
        iptraf
        rsync
        gparted
        openvpn
        network-manager-openvpn-gnome
        gnome-disk-utility
        cups
        cups-browsed
        cups-filters
        system-config-printer
    )

    # TODO: do we want ntp? on systemd systems we have systemd-timesyncd
    declare -ar block2=(
        dnsutils
        dnstracer
        dnsmasq
        resolvconf
        network-manager
        network-manager-gnome
        jq
        crudini
        htop
        glances
        iotop
        ncdu
        pydf
        nethogs
        tcpdump
        tcpflow
        ngrep
        nload
        ntp
        ncat
        remind
        tkremind
        wyrd
        tree
        synaptic
        apt-file
        apt-show-versions
        apt-xapian-index
        unattended-upgrades
        apt-listchanges
        debian-goodies
        git
        tig
        git-flow
        git-cola
        git-extras
        zenity
        gxmessage
        gnome-keyring
        policykit-1-gnome
        seahorse
        libsecret-tools
        gsimplecal
        khal
        vdirsyncer
        calcurse
        galculator
        atool
        file-roller
        rar
        unrar
        zip
        p7zip
        dos2unix
        qt4-qtconfig
        lxappearance
        gtk2-engines-murrine
        gtk2-engines-pixbuf
        gnome-themes-standard
        arc-theme
        numix-gtk-theme
        numix-icon-theme
        meld
        at-spi2-core
        pastebinit
        synergy
        keepassxc
        gnupg
        dirmngr
        direnv
    )


    # fyi:
        #- [gnome-keyring???-installi vaid siis, kui mingi jama]
        #- !! gksu no moar recommended; pkexec advised; to use pkexec, you need to define its
        #     action in /usr/share/polkit-1/actions.

        # socat for mopidy+ncmpcpp visualisation;
        # at-spi2-core is some gnome accessibility provider; without it some py apps (eg meld) complain;

    declare -ar block3_nonwin=(
        spotify-client
        mopidy
        mopidy-soundcloud
        mopidy-spotify
        mopidy-youtube
        socat
        youtube-dl
        mpc
        ncmpcpp
        ncmpc
        audacity
        mpv
        gimp
        xss-lock
        filezilla
        transmission
        transmission-remote-cli
        transmission-remote-gtk
        etckeeper
    )

    declare -ar block3=(
        firefox/unstable
        chromium
        chromium-sandbox
        rxvt-unicode-256color
        colortest-python
        seafile-gui
        seafile-cli
        geany
        libreoffice
        zathura
        feh
        sxiv
        geeqie
        gthumb
        imagemagick
        pinta
        inkscape
        xsel
        wmctrl
        xdotool
        exuberant-ctags
        shellcheck
        ranger
        vifm
        bat
        screenfetch
        neofetch
        maim
        ffmpeg
        ffmpegthumbnailer
        vokoscreen
        peek
        screenkey
        mediainfo
        screenruler
        lynx
        elinks
        links2
        w3m
        tmux
        neovim/unstable
        python3-pynvim/unstable
        libxml2-utils
        pidgin
        weechat
        lxrandr
        arandr
        copyq
        googler
        msmtp
        davmail
        thunderbird
        lightning
        neomutt
        notmuch
        abook
        isync
    )
    # old/deprecated block3:
    #         spacefm-gtk3
    #         kazam (doesn't play well w/ i3)
    #

    declare -ar block4=(
        atool
        highlight
        python3-pygments
        urlview
        silversearcher-ag
        locate
        cowsay
        cowsay-off
        toilet
        lolcat
        figlet
        redshift
        geoclue-2.0
        docker-ce
        docker-ce-cli
        containerd.io
        docker-compose
        python-docker
        docker-swarm
        mitmproxy
        charles-proxy
    )
    # old/deprecated block4:


    # some odd libraries
    declare -ar block5=(
        libjson-perl
    )

    blocks=()
    is_native && blocks=(block1_nonwin block2_nonwin block3_nonwin)
    blocks+=(block1 block2 block3 block4 block5)

    execute "sudo apt-get --yes update"
    for block in "${blocks[@]}"; do
        install_block "$(eval echo "\${$block[@]}")" "${extra_apt_params[$block]}"
        if [[ "$?" -ne 0 && "$?" -ne "$SOME_PACKAGE_IGNORED_EXIT_CODE" ]]; then
            err "one of the main-block installation failed. these are the packages that have failed to install so far:"
            echo -e "[${PACKAGES_FAILED_TO_INSTALL[*]}]"
            confirm -d Y "continue with setup? answering no will exit script" || exit 1
        fi
    done


    if [[ "$PROFILE" == work ]]; then
        if is_native; then
            install_block '
                remmina
                samba-common-bin
                smbclient

                virtualbox
                virtualbox-dkms
            '
        fi

        install_block '
            ruby-dev
            kubectl
        '

        # remmina is remote desktop for windows; rdesktop, remote vnc;
    fi

    if is_virtualbox; then
        install_vbox_guest
    fi

    if is_native && is_laptop; then
        install_block pulseaudio-module-bluetooth
    fi
}

# install/update the guest-utils/guest-additions.
#
# note it's preferrable to do it this way as opposed to installing
# {virtualbox-guest-utils virtualbox-guest-x11} packages from apt, as additions
# are rather related to vbox version, so better use the one that's shipped w/ it.
#
# make sure guest additions CD is inserted: @ host: Devices->Insert Guest Additions CD...
#
# see https://www.virtualbox.org/manual/ch04.html#additions-linux
install_vbox_guest() {
    local tmp_mount bin label

    tmp_mount="$TMP_DIR/cdrom-mount-tmp-$RANDOM"
    bin="$tmp_mount/VBoxLinuxAdditions.run"

    is_virtualbox || return 0
    install_block 'virtualbox-guest-dkms' || return 1

    execute "mkdir $tmp_mount" || return 1
    execute "sudo mount /dev/cdrom $tmp_mount" || { err "mounting guest-utils from /dev/cdrom to [$tmp_mount] failed w/ $? - is image mounted in vbox and in expected slot?"; return 1; }
    [[ -x "$bin" ]] || { err "[$bin] not a file"; return 1; }
    label="$(grep --text -Po '^label=.\K.*(?="$)' "$bin")"  # or grep for 'INSTALLATION_VER'?

    if is_single "$label"; then
        if grep -Fq "$label" "$GIT_RLS_LOG" 2>/dev/null; then
            report "[$label] already encountered, skipping installation..."
            return 2
        fi
    else
        err "found vbox additions ver was unexpected: [$label]; will continue w/ installation"
    fi

    # append '--nox11' if installing in non-gui system:
    execute "sudo sh $bin"  # do not catch status, seems to always exit /w 2
    execute "sudo umount $tmp_mount" || err "unmounting cdrom from [$tmp_mount] failed w/ $?"

    if is_single "$label"; then
        add_to_dl_log "vbox-guest-additions" "$label"
    fi
}


# offers to install nvidia drivers, if NVIDIA card is detected.
#
# in order to reinstall the dkms part, purge both nvidia-driver &
# nvidia-xconfig, and then reinstall.
#
# - Note if you see some flickering, it might be caused by compton and its settings.
#   eg based on info from https://github.com/chjj/compton/issues/152,
#    set glx-swap-method to 1;
# - also, you might want to select 'Force Full Composition Pipeline' from
#   nvidia-settings -> x server Disp Conf -> Advanced... -> tick the box
#
# https://wiki.debian.org/NvidiaGraphicsDrivers
install_nvidia() {
    # TODO: consider  lspci -vnn | grep VGA | grep -i nvidia
    if sudo lshw | grep -iA 5 'display' | grep -iq 'vendor.*NVIDIA'; then
        if confirm -d N "we seem to have NVIDIA card; want to install nvidia drivers?"; then  # TODO: should we default to _not_ installing in non-interactive mode?
            # TODO: also install  nvidia-detect ?
            report "installing NVIDIA drivers..."
            install_block 'nvidia-driver  nvidia-xconfig'
            #execute "sudo nvidia-xconfig"  # should not be required as of Stretch
            return $?
        else
            report "we chose not to install nvidia drivers..."
        fi
    else
        report "we don't have a nvidia card; skipping installing their drivers..."
    fi
}


# provides the possibility to cherry-pick out packages.
# this might come in handy, if few of the packages cannot be found/installed.
install_block() {
    local list_to_install extra_apt_params dry_run_failed exit_sig exit_sig_install_failed pkg sig

    declare -ar list_to_install=( $1 )
    readonly extra_apt_params="$2"  # optional
    declare -a dry_run_failed=()
    exit_sig=0  # default

    report "installing these packages:\n${list_to_install[*]}\n"

    # extract packages, which, for whatever reason, cannot be installed:
    for pkg in ${list_to_install[*]}; do
        # TODO: is there any point for this?:
        #result="$(apt-cache search  --names-only "^$pkg\$")" || { err "apt-cache search failed for \"$pkg\""; packages_not_found+=( $pkg ); continue; }
        #if [[ -z "$result" ]]; then
            #packages_not_found+=( $pkg )
            #continue
        #fi
        execute "sudo apt-get -qq --dry-run --no-install-recommends install $extra_apt_params $pkg"
        sig=$?

        if [[ "$sig" -ne 0 ]]; then
            execute 'sudo apt-get --yes update'
            execute 'sudo apt-get --yes autoremove'

            if execute "sudo apt-get -qq --dry-run --no-install-recommends install $extra_apt_params $pkg"; then
                #sleep 0.1
                execute "sudo DEBIAN_FRONTEND=noninteractive apt-get --yes install --no-install-recommends $extra_apt_params $pkg" || { exit_sig_install_failed=$?; PACKAGES_FAILED_TO_INSTALL+=("$pkg"); }
            else
                dry_run_failed+=( $pkg )
            fi
        else
            execute "sudo DEBIAN_FRONTEND=noninteractive apt-get --yes install --no-install-recommends $extra_apt_params $pkg" || { exit_sig_install_failed=$?; PACKAGES_FAILED_TO_INSTALL+=("$pkg"); }
        fi
    done

    if [[ "${#dry_run_failed[@]}" -ne 0 ]]; then
        err "either these packages could not be found from the repo, or some other issue occurred; skipping installing these packages. this will be logged:"
        err "${dry_run_failed[*]}"

        PACKAGES_IGNORED_TO_INSTALL+=( "${dry_run_failed[@]}" )
        exit_sig="$SOME_PACKAGE_IGNORED_EXIT_CODE"
    fi

    #if [[ -z "${list_to_install[*]}" ]]; then
        #err "all packages got removed. skipping install block."
        #return 1
    #fi

    #sleep 1  # just in case sleep for a bit
    #execute "sudo apt-get --yes install $extra_apt_params ${list_to_install[*]}"
    #exit_sig_install_failed=$?

    #[[ -n "$exit_sig" ]] && return $exit_sig || return $exit_sig_install_failed
    [[ -n "$exit_sig_install_failed" ]] && return $exit_sig_install_failed || return $exit_sig
}


choose_step() {
    if [[ -n "$MODE" ]]; then
       case "$MODE" in
           0) choose_single_task ;;
           1) full_install ;;
           2) quick_refresh ;;
           *) exit 1 ;;
       esac
    else  # mode not provided
       report "what do you want to do?"
       select_items 'full-install single-task update' 1
       case "$__SELECTED_ITEMS" in
          'full-install' ) full_install ;;
          'single-task'  ) choose_single_task ;;
          'update'       ) quick_refresh ;;
          '') exit 0 ;;
          *) err "unsupported choice [$__SELECTED_ITEMS]"
              exit 1
              ;;
       esac
    fi
}


# basically offers steps from setup() & install_progs():
choose_single_task() {
    local choices

    LOGGING_LVL=1
    readonly MODE=0

    source_shell_conf

    [[ -n "$CUSTOM_LOGDIR" ]] && readonly GIT_RLS_LOG="$CUSTOM_LOGDIR/git-releases-install.log" || GIT_RLS_LOG="$TMP_DIR/.git-rls-log.tmp"  # log of all installed debs/binaries from git releases/latest page
    command -v nvm >/dev/null && execute 'nvm use default'

    # note choices need to be valid functions
    declare -ar choices=(
        setup
        setup_homesick

        generate_key
        switch_jdk_versions
        install_nm_dispatchers
        install_acpi_events
        install_deps
        install_fonts
        upgrade_kernel
        install_nvidia
        install_webdev
        install_from_repo
        install_ssh_server_or_client
        install_nfs_server_or_client
        __choose_prog_to_build
    )

    report "what do you want to do?"

    select_items "${choices[*]}" 1
    [[ -z "$__SELECTED_ITEMS" ]] && return

    $__SELECTED_ITEMS
}


# meta-function;
# offerst steps from install_own_builds():
#
# note full-install counterpart would be install_own_builds()
__choose_prog_to_build() {
    local choices

    declare -ar choices=(
        install_YCM
        install_keepassx
        install_keepassxc
        install_goforit
        install_copyq
        install_rambox
        install_franz
        install_ferdi
        install_slack_term
        install_ripgrep
        install_rebar
        install_lazygit
        install_lazydocker
        install_fd
        install_gitin
        install_synergy
        install_dwm
        install_i3
        install_i3_deps
        install_i3lock
        install_i3lock_fancy
        install_betterlockscreen
        install_polybar
        install_oracle_jdk
        install_skype
        install_altiris
        install_symantec_endpoint_security
        install_aws_okta
        install_saml2aws
        install_aia
        install_kustomize
        install_k9s
        install_popeye
        install_octant
        install_kops
        install_kubectx
        install_kube_ps1
        install_sops
        install_bloomrpc
        install_grpc_cli
        install_dbeaver
        install_p4merge
        install_redis_desktop_mngr
        install_eclipse_mem_analyzer
        install_visualvm
        install_vnote
        install_postman
        install_weeslack
        install_terraform
        install_terragrunt
        install_bluejeans
        install_minikube
        install_gruvbox_gtk_theme
        install_veracrypt
        install_vbox_guest
    )

    report "what do you want to build/install?"

    select_items "${choices[*]}" 1
    [[ -z "$__SELECTED_ITEMS" ]] && return
    #prepare_build_container || { err "preparation of build container [$BUILD_DOCK] failed" "$FUNCNAME"; return 1; }

    $__SELECTED_ITEMS
}


full_install() {

    LOGGING_LVL=10
    readonly MODE=1

    setup

    is_windows || upgrade_kernel  # keep this check is_windows(), not is_native();
    install_fonts
    install_progs
    install_deps
    ! is_noninteractive && is_native && install_ssh_server_or_client
    ! is_noninteractive && is_native && install_nfs_server_or_client
    [[ "$PROFILE" == work ]] && exe_work_funs

    remind_manually_installed_progs
}


# quicker update than full_install() to be executed periodically
quick_refresh() {
    LOGGING_LVL=1
    readonly MODE=2

    setup
    install_progs  # TODO: consider replacing by only install_own_builds()
    install_deps
}


# execute work-defined shell functions, likely in ~/.bash_funs_overrides/;
# note we seek functions by a pre-defined prefix;
exe_work_funs() {
    local f

    # version where we resolve & execute _all_ functions:
    #while read -r f; do
        #is_function "$f" || continue
        #execute "$f"
    #done< <(declare -F | awk '{print $NF}' | grep '^w_')

    # another ver where we execute pre-defined set of funs:
    for f in \
            w_dl_cert \
                ; do
        is_function "$f" || continue
        execute "$f"
    done
}


# programs that cannot be installed automatically should be reminded of
remind_manually_installed_progs() {
    local progs i

    declare -ar progs=(
        lazyman2
        'intelliJ toolbox'
        'sdkman - jdk, maven, gradle...'
        'any custom certs'
        'ublock origin additional configs (est, social media, ...)'
        'ublock whitelist (should be saved somewhere)'
        'import keepass-xc browser plugin config'
        'install tridactyl native messenger/executable'
        'setup default keyring via seahorse'
    )

    for i in "${progs[@]}"; do
        if ! command -v "$i" >/dev/null; then
            report "    don't forget [$i]"
        fi
    done

    [[ "$PROFILE" == work ]] && report "don't forget to install docker root CA"
}


# as per    https://confluence.jetbrains.com/display/IDEADEV/Inotify+Watches+Limit
increase_inotify_watches_limit() {
    _sysctl_conf '60-jetbrains.conf' 'fs.inotify.max_user_watches' 524288
}


# as per    https://wiki.archlinux.org/index.php/Linux_Containers#Enable_support_to_run_unprivileged_containers_(optional)
#
# this is needed eg for electron v5+ to enable sandboxing; eg see
#    https://github.com/electron/electron/issues/17972
#    https://github.com/notable/notable/issues/792
#    https://github.com/electron/electron/issues/16631
enable_unprivileged_containers_for_regular_users() {
    _sysctl_conf '70-enable-unprivileged-containers.conf' 'kernel.unprivileged_userns_clone' 1
}

_sysctl_conf() {
    local sysctl_dir sysctl_conf property value

    readonly sysctl_dir='/etc/sysctl.d'
    readonly sysctl_conf="${sysctl_dir}/$1"
    readonly property="$2"
    readonly value="$3"

    [[ -d "$sysctl_dir" ]] || { err "[$sysctl_dir] is not a dir. can't change our sysctl value for [$1]"; return 1; }
    grep -q "^$property\s*=\s*$value\$" "$sysctl_conf" && return  # value already set, nothing to do

    # just in case delete all same prop definitions, regardless of its value:
    [[ -f "$sysctl_conf" ]] && execute "sudo sed -i --follow-symlinks '/^$property/d' '$sysctl_conf'"

    execute "echo $property = $value | sudo tee --append $sysctl_conf > /dev/null"

    # mark our sysctl config has changed:
    SYSCTL_CHANGED=1
}


# note: if you don't want to install docker from the debian's own repo (docker.io),
# follow this instruction:  https://docs.docker.com/engine/installation/linux/debian/
#
# (refer to proglist2 if docker complains about memory swappiness not supported.)
#
# add our user to docker group so it could be run as non-root:
setup_docker() {

    # see https://github.com/docker/for-linux/issues/58 (without it container exits with 139):
    _add_kernel_option() {
        local conf param line
        conf='/etc/default/grub'
        param='vsyscall=emulate'

        [[ -f "$conf" ]] || { err "[$conf] grub conf not a file"; return 1; }
        readonly line="$(grep -Po '^GRUB_CMDLINE_LINUX_DEFAULT="\K.*(?="$)' "$conf")"
        if ! is_single "$line"; then
            err "[$conf] contained either more or less than 1 line(s) containing kernel opt: [$line]"
            return 1
        fi

        grep -q "$param" <<< "$line" && report "vsyscall opt already set in [$conf]" && return 0

        execute "sudo sed -i --follow-symlinks 's/^GRUB_CMDLINE_LINUX_DEFAULT.*$/GRUB_CMDLINE_LINUX_DEFAULT=\"$line $param\"/g' $conf" || { err; return 1; }
        execute 'sudo update-grub'
    }

    addgroup_if_missing docker               # add user to docker group
    #execute "sudo gpasswd -a ${USER} docker"  # add user to docker group
    #execute "newgrp docker"  # log us into the new group; !! will stop script execution
    _add_kernel_option

    execute "sudo service docker restart"  # TODO: we should only restart service if something was _really_ changed
}


## increase the max nr of open file in system. (for intance node might compline otherwise).
## see https://github.com/paulmillr/chokidar/issues/45
## and http://stackoverflow.com/a/21536041/1803648
#function increase_ulimit() {
    #readonly ulimit=3000
    #execute "newgrp docker"  # log us into the new group; !! will stop script execution
#}


# puts networkManager to manage our network interfaces;
# alternatively, you can remove your interface name from /etc/network/interfaces
# (bottom) line; eg from 'iface wlan0 inet dhcp' to 'iface inet dhcp'
#
# make sure resolvconf pkg is installed for seamless resolv config updates & dnsmasq usage (as per https://unix.stackexchange.com/a/406724/47501)
#
# see also wiki.debian.org/NetworkManager
enable_network_manager() {
    local nm_conf nm_conf_dir dnsmasq_conf dnsmasq_conf_dir i

    readonly nm_conf="$COMMON_DOTFILES/backups/networkmanager.conf"
    readonly nm_conf_dir='/etc/NetworkManager/conf.d'
    readonly dnsmasq_conf="$COMMON_DOTFILES/backups/dnsmasq.conf"
    readonly dnsmasq_conf_dir='/etc/dnsmasq.d'

    [[ -d "$nm_conf_dir" ]] || { err "[$nm_conf_dir] does not exist; are you using NetworkManager? if not, this config logic should be removed."; return 1; }
    [[ -f "$nm_conf" ]] || { err "[$nm_conf] does not exist; cannot update config"; return 1; }
    execute "sudo cp -- '$nm_conf' '$nm_conf_dir'" || return 1

    # old ver, directly updating /etc/NetworkManager/NetworkManager.conf:
    #sudo crudini --merge "$net_manager_conf_file" <<'EOF'
#[ifupdown]
#managed=true

#[main]
#dns=default
#rc-manager=resolvconf
#EOF
    #[[ $? -ne 0 ]] && { err "updating [$net_manager_conf_file] exited w/ failure"; return 1; }


    # update dnsmasq conf:  TODO: refactor out from this fun?
    # note: to check dnsmasq conf/performance, see
    #     dig +short chaos txt hits.bind
    #     dig +short chaos txt misses.bind
    #     dig +short chaos txt cachesize.bind
    [[ -d "$dnsmasq_conf_dir" ]] || { err "[$dnsmasq_conf_dir] does not exist"; return 1; }
    [[ -f "$dnsmasq_conf" ]] || { err "[$dnsmasq_conf] does not exist; cannot update config"; return 1; }
    execute "sudo cp -- '$dnsmasq_conf' '$dnsmasq_conf_dir'" || return 1


    # old ver, directly updating /etc/dnsmasq.conf:
    #execute "sudo sed -i --follow-symlinks '/^cache-size=/d' '$dnsmasq_conf'"
    #execute "echo cache-size=10000 | sudo tee --append $dnsmasq_conf > /dev/null"

    #execute "sudo sed -i --follow-symlinks '/^local-ttl=/d' '$dnsmasq_conf'"
    #execute "echo local-ttl=10 | sudo tee --append $dnsmasq_conf > /dev/null"

    ## lock dnsmasq to be exposed only to localhost:
    #execute "sudo sed -i --follow-symlinks '/^listen-address=/d' '$dnsmasq_conf'"
    #execute "echo listen-address=::1,127.0.0.1 | sudo tee --append $dnsmasq_conf > /dev/null"


    # TODO: not sure about this bit:
    #if [[ "$PROFILE" != work ]]; then
        #execute "sudo sed -i --follow-symlinks '/^server=/d' '$dnsmasq_conf'"
        #for i in 1.1.1.1   8.8.8.8; do
            #execute "echo server=$i | sudo tee --append $dnsmasq_conf > /dev/null"
        #done

        ## no-resolv stops dnsmasq from reading /etc/resolv.conf, and makes it only rely on servers defined in $dnsmasq_conf
        #if ! grep -q '^no-resolv$' "$dnsmasq_conf"; then
            #execute "echo no-resolv | sudo tee --append $dnsmasq_conf > /dev/null"
        #fi
    #fi
}


# https://github.com/numixproject/numix-gtk-theme
#
# consider also numix-gtk-theme & numix-icon-theme straight from the repo
#
# another themes to consider: flatabolous (https://github.com/anmoljagetia/Flatabulous)  (hosts also flat icons);
#                             ultra-flat (https://www.gnome-look.org/content/show.php/Ultra-Flat?content=167473)
install_gtk_numix() {
    local theme_repo tmpdir

    readonly theme_repo='https://github.com/numixproject/numix-gtk-theme.git'
    readonly tmpdir="$TMP_DIR/numix-theme-build-${RANDOM}"

    check_progs_installed  glib-compile-schemas  gdk-pixbuf-pixdata || { err "those need to be on path for numix build to succeed."; return 1; }
    report "installing numix build dependencies..."
    rb_install sass || return 1

    execute "git clone -j8 $theme_repo $tmpdir" || return 1
    execute "pushd $tmpdir" || return 1

    execute "make" || { err; popd; return 1; }

    create_deb_install_and_store numix

    execute "popd"
    execute "sudo rm -rf -- '$tmpdir'"
    return 0
}


install_gruvbox_gtk_theme() {
    clone_or_pull_repo "3ximus" "gruvbox-gtk" "$HOME/.themes"  # https://github.com/3ximus/gruvbox-gtk.git
}

install_veracrypt() {
    local tmpdir dl_urls u i vers dl_url ver_to_url file

    dl_urls="$(resolve_dl_urls -M "https://www.veracrypt.fr/en/Downloads.html" '.*Debian-\d+-amd64.deb')" || return 1

    vers=()
    declare -A ver_to_url

    while IFS= read -r u; do
        grep -qi console <<< "$u" && continue  # we want GUI version, not console
        i="$(grep -oP 'Debian-\K\d+(?=-amd64.deb$)' <<< "$u")"
        if is_digit "$i"; then
            vers+=("$i")
            ver_to_url["$i"]="$u"
        fi
    done <<< "$dl_urls"


    if [[ ${#vers[@]} -eq 0 ]]; then
        err "no valid versions found from veracrypt dl urls"
        return 1
    fi

    i="$(printf '%d\n' "${vers[@]}" | sort -rn | head -n1)"  # take largest (ie latest) version
    is_digit "$i" || { err "latest found version was not digit: [$i]" return 1; }

    dl_url=${ver_to_url[$i]}

    if grep -Fq "$dl_url" "$GIT_RLS_LOG" 2>/dev/null; then
        report "[$dl_url] already encountered, skipping installation..."
        return 2
    fi

    tmpdir="$(mktemp -d "veracrypt-XXXXX" -p $TMP_DIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }
    report "fetching [$dl_url]..."
    execute "wget --content-disposition -q --directory-prefix=$tmpdir '$dl_url'" || { err "wgetting [$dl_url] failed with $?"; return 1; }
    file="$(find "$tmpdir" -type f)"
    [[ -f "$file" ]] || { err "couldn't find single downloaded file in [$tmpdir]"; return 1; }

    execute "sudo apt-get --yes install '$file'" || { err "installing veracrypt failed w/ $?"; return 1; }

    add_to_dl_log 'veracrypt' "$dl_url"
}


# add additional ntp servers
configure_ntp_for_work() {
    local conf servers i

    readonly conf='/etc/ntp.conf'
    declare -ar servers=('server gibntp01.prod.williamhill.plc'
                         'server gibntp02.prod.williamhill.plc'
                        )

    [[ "$PROFILE" == work ]] || return
    [[ -f "$conf" ]] || { err "[$conf] is not a valid file. is ntp installed?"; return 1; }

    for i in "${servers[@]}"; do
        if ! grep -q "^$i\$" "$conf"; then
            report "adding [$i] to $conf"
            execute "echo $i | sudo tee --append $conf > /dev/null"
        fi
    done
}


# configure pulseaudio/equalizer
#
# see https://wiki.debian.org/PulseAudio#Dynamically_enable.2Fdisable
# to dynamically enable/disable pulseaudio;
configure_pulseaudio() {
    local conf conf_lines i

    readonly conf='/etc/pulse/default.pa'
    declare -a conf_lines=('load-module module-equalizer-sink'
                           'load-module module-dbus-protocol'
                          )

    # make bluetooth (headset) device connection possible:
    # http://askubuntu.com/questions/801404/bluetooth-connection-failed-blueman-bluez-errors-dbusfailederror-protocol-no
    # https://zach-adams.com/2014/07/bluetooth-audio-sink-stream-setup-failed/
    is_laptop && conf_lines+=('load-module module-bluetooth-discover')

    [[ -f "$conf" ]] || { err "[$conf] is not a valid file."; return 1; }

    for i in "${conf_lines[@]}"; do
        if ! grep -q "^$i\$" "$conf"; then
            report "adding [$i] to $conf"
            execute "echo $i | sudo tee --append $conf > /dev/null"
        fi
    done

}


setup_seafile_cli() {
    local confdir datadir

    readonly confdir="$HOME/.config/ccnet"
    readonly datadir='/data/Seafile'

    [[ -d "$datadir" ]] || { err "[$datadir] is not a valid dir; please set up via gui first" "$FUNCNAME"; return 1; }
}


# from  TODO find debian url for nftables
enable_fw() {
    execute 'sudo systemctl enable nftables.service'
}


# change DefaultAuthType to None, so printer configuration wouldn't require basic auth
setup_cups() {
    local conf_file conf2 group should_restart

    readonly conf_file='/etc/cups/cupsd.conf'
    readonly conf2='/etc/cups/cups-files.conf'
    should_restart=0

    [[ -f "$conf_file" ]] || { err "cannot configure cupsd: [$conf_file] does not exist; abort;"; return 1; }

    # this bit (auth change/disabling) comes likely from https://serverfault.com/a/800901 or https://askubuntu.com/a/1142110
    if ! grep -q 'DefaultAuthType' "$conf_file"; then
        err "[$conf_file] does not contain [DefaultAuthType], see what's what"
        return 1
    elif ! grep -Eq '^DefaultAuthType\s+None' "$conf_file"; then  # hasn't been changed yet
        execute "sudo sed -i --follow-symlinks 's/^DefaultAuthType/#DefaultAuthType/g' $conf_file"  # comment out existing value
        execute "echo 'DefaultAuthType None' | sudo tee --append '$conf_file' > /dev/null"
        should_restart=1
    fi

    # add our user to a group so we're allowed to modify printers & whatnot: {{{
    #   see https://unix.stackexchange.com/a/513983/47501
    #   and https://ro-che.info/articles/2016-07-08-debugging-cups-forbidden-error
    [[ -f "$conf2" ]] || { err "cannot configure our user for cups: [$conf2] does not exist; abort;"; return 1; }
    group="$(grep ^SystemGroup "$conf2" | awk '{print $NF}')" || { err "grepping group from [$conf2] failed w/ $?"; return 1; }
    is_single "$group" || { err "found SystemGroup in [$conf2] was unexpected: [$group]"; return 1; }
    [[ "$group" == root || "$group" == sys ]] && { err "found SystemGroup is [$group] - verify we want to be added to that group"; return 1; }
    addgroup_if_missing "$group"
    # }}}

    [[ "$should_restart" -eq 1 ]] && execute 'sudo service cups restart'
}


# ff & extension configs/customisation
setup_firefox() {
    local conf_dir profile

    conf_dir="$HOME/.mozilla/firefox"

    # install tridactyl native messenger:  https://github.com/tridactyl/tridactyl#extra-features
    execute 'curl -fsSl https://raw.githubusercontent.com/tridactyl/tridactyl/master/native/install.sh -o /tmp/trinativeinstall.sh && bash /tmp/trinativeinstall.sh master'


    # install custom css/styling {  # see also https://github.com/MrOtherGuy/firefox-csshacks
    [[ -d "$conf_dir" ]] || { err "[$conf_dir] not a dir"; return 1; }
    profile="$(find "$conf_dir" -mindepth 1 -maxdepth 1 -type d -name '*default-release')"
    [[ -d "$profile" ]] || { err "[$profile] not a dir"; return 1; }
    [[ -d "$profile/chrome" ]] || execute "mkdir -- '$profile/chrome'" || return 1
    execute "pushd $profile/chrome" || return 1
    clone_or_pull_repo  MrOtherGuy  firefox-csshacks  './'


    execute "popd"
    # }
}


addgroup_if_missing() {
    local group
    readonly group="$1"

    id -Gn "$USER" | grep -q "\b$group\b" || execute "sudo adduser $USER $group"
}


# https://minikube.sigs.k8s.io/docs/reference/drivers/none/
setup_minikube() {  # TODO: unfinished
    true
    #execute 'sudo minikube config set vm-driver none'  # make 'none' the default driver:
    #execute 'minikube config set memory 4096'  # set default allocated memory (default is 2g i believe, see https://minikube.sigs.k8s.io/docs/start/linux/)

    # TODO: consider these for starting:
#CHANGE_MINIKUBE_NONE_USER=true sudo -E minikube start --vm-driver=none
#sudo minikube start --extra-config=apiserver.service-node-port-range=80-32767 --vm-driver=none --apiserver-ips 127.0.0.1 --apiserver-name localhost
}


# configs & settings that can/need to be installed  AFTER  the related programs have
# been installed.
#
# note that this block overlaps logically a bit with setup_config_files() (though
# that function should contain configuration that doesn't depend on some programs
# being installed beforehand; also, should be mostly dependent on config files being
# pulled with homesick);
post_install_progs_setup() {

    is_native && install_acpi_events   # has to be after install_progs(), so acpid is already insalled and events/ dir present;
    enable_network_manager
    is_native && install_nm_dispatchers  # has to come after install_progs; otherwise NM wrapper dir won't be present  # TODO: do we want to install these only on native systems?
    #is_native && execute --ignore-errs "sudo alsactl init"  # TODO: cannot be done after reboot and/or xsession.
    is_native && execute "mopidy local scan"            # update mopidy library
    is_native && execute "sudo sensors-detect --auto"   # answer enter for default values (this is lm-sensors config)
    increase_inotify_watches_limit         # for intellij IDEA
    enable_unprivileged_containers_for_regular_users
    setup_docker
    setup_nvim
    is_native && addgroup_if_missing wireshark               # add user to wireshark group, so it could be run as non-root;
                                                # (implies wireshark is installed with allowing non-root users
                                                # to capture packets - it asks this during installation); see https://code.wireshark.org/review/gitweb?p=wireshark.git;a=blob_plain;f=debian/README.Debian
                                                # if wireshark is installed manually/interactively, then installer asks whether
                                                # non-root users should be allowed to dump packets; this can later be reconfigured
                                                # by running  $ sudo dpkg-reconfigure wireshark-common
                                                # TODO: in order to avoid this extra step, see how to preseed debconf database
                                                # basically: install manually, then extract debconf stuff: $debconf-get-selections | grep wireshark
                                                # then before auto-install, set it via :$ echo ttf-mscorefonts-installer msttcorefonts/accepted-mscorefonts-eula select true | sudo debconf-set-selections
                                                # see also https://unix.stackexchange.com/a/96227

    #execute "newgrp wireshark"                  # log us into the new group; !! will stop script execution
    is_native && addgroup_if_missing vboxusers   # add user to vboxusers group (to be able to pass usb devices for instance); (https://wiki.archlinux.org/index.php/VirtualBox#Add_usernames_to_the_vboxusers_group)
    is_virtualbox && addgroup_if_missing vboxsf  # add user to vboxsf group (to be able to access mounted shared folders);
    #execute "newgrp vboxusers"                  # log us into the new group; !! will stop script execution
    configure_ntp_for_work  # TODO: confirm if ntp needed in WSL
    configure_pulseaudio  # TODO see if works in WSL
    #setup_seafile_cli  # TODO https://github.com/haiwen/seafile/issues/1855 & https://github.com/haiwen/seafile/issues/1854
    is_native && enable_fw
    is_native && setup_cups
    #addgroup_if_missing fuse  # not needed anymore?
    setup_firefox

    command -v kubectl >/dev/null && execute 'kubectl completion bash | sudo tee /etc/bash_completion.d/kubectl'  # add kubectl bash completion
    command -v minikube >/dev/null && setup_minikube

    [[ "$SYSCTL_CHANGED" -eq 1 ]] && execute "sudo sysctl -p --system"
}


install_ssh_server_or_client() {
    report "installing ssh. what do you want to do?"

    while true; do
        select_items "client-side server-side" 1

        if [[ -n "$__SELECTED_ITEMS" ]]; then
            break
        else
            confirm "no items were selected; exit?" && return || continue
        fi
    done

    case "$__SELECTED_ITEMS" in
        'server-side' ) install_ssh_server ;;
        'client-side' ) install_sshfs ;;
    esac
}


install_nfs_server_or_client() {
    report "installing nfs. what do you want to do?"

    while true; do
        select_items "client-side server-side" 1

        if [[ -n "$__SELECTED_ITEMS" ]]; then
            break
        else
            confirm "no items were selected; exit?" && return || continue
        fi
    done

    case "$__SELECTED_ITEMS" in
        "server-side" ) install_nfs_server ;;
        "client-side" ) install_nfs_client ;;
    esac
}

add_to_dl_log() {
    local id url

    id="$1"
    url="$2"

    [[ -f "$GIT_RLS_LOG" ]] && sed --follow-symlinks -i "/^$id:/d" "$GIT_RLS_LOG"
    echo -e "${id}:\t$url" >> "$GIT_RLS_LOG"
}

###################
# UTILS (contains no setup-related logic)
###################

confirm() {
    local msg yno opt OPTIND default timeout

    timeout=2  # default
    while getopts "d:t:" opt; do
        case "$opt" in
           d)
              default="$OPTARG"
                ;;
           t)
              timeout="$OPTARG"
                ;;
           *) print_usage; return 1 ;;
        esac
    done
    shift "$((OPTIND-1))"

    readonly msg=${1:+"\n$1"}

    while true; do
        [[ -n "$msg" ]] && echo -e "$msg"

        if is_noninteractive; then
            read -r -t "$timeout" yno
            if [[ $? -gt 128 ]]; then yno="$default"; fi  # read timed out
        else
            read -r yno
        fi

        case "$(echo "$yno" | tr '[:lower:]' '[:upper:]')" in
            Y | YES )
                report "Ok, continuing..." "->";
                return 0
                ;;
            N | NO )
                echo "Abort.";
                return 1
                ;;
            *)
                err "incorrect answer; try again. (y/n accepted)" "->"
                ;;
        esac
    done
}


err() {
    local msg caller_name

    readonly msg="$1"
    readonly caller_name="$2"  # OPTIONAL

    [[ "$LOGGING_LVL" -ge 10 ]] && echo -e "    ERR LOG: ${caller_name:+[$caller_name]: }$msg" >> "$EXECUTION_LOG"
    >&2 echo -e "${COLORS[RED]}${caller_name:-"error"}:${COLORS[OFF]} ${msg:-"Abort"}" 1>&2
}


report() {
    local msg caller_name

    readonly msg="$1"
    readonly caller_name="$2"  # OPTIONAL

    [[ "$LOGGING_LVL" -ge 10 ]] && echo -e "OK LOG: ${caller_name:+[$caller_name]: }$msg" >> "$EXECUTION_LOG"
    >&2 echo -e "${COLORS[YELLOW]}${caller_name:-"INFO"}:${COLORS[OFF]} ${msg:-'--info lvl message placeholder--'}"
}


# issues when installing downloaded deb files (at least when they've already been installed beforehand?);
# NOTE: unsure if this is really needed for our use-case;
# see https://askubuntu.com/a/908825
# see https://unix.stackexchange.com/questions/468807/strange-error-in-apt-get-download-bug
sanitize_apt() {
    local target

    target="$1"

    if ! [[ -e "$target" ]]; then
        err "tried to sanitize [$target] for apt, but it doesn't exist"
        return 1
    fi

    execute "sudo chown -R _apt:root '$target'"
    execute "sudo chmod -R 700 '$target'"
}


_sanitize_ssh() {

    if ! [[ -d "$HOME/.ssh" ]]; then
        err "tried to sanitize [~/.ssh], but dir doesn't exist."
        return 1
    fi

    find -L "$HOME/.ssh/" -maxdepth 25 \( -type f -o -type d \) -exec chmod 'u=rwX,g=,o=' -- '{}' \+
}


is_ssh_key_available() {
    [[ -f "$PRIVATE_KEY_LOC" ]]
}


check_connection() {
    local timeout ip

    readonly timeout=3  # in seconds
    readonly ip='https://www.google.com'

    # Check whether the client is connected to the internet:
    # TODO: keep '--no-check-certificate' by default?
    wget --no-check-certificate -q --spider --timeout=$timeout -- "$ip" > /dev/null 2>&1  # works in networks where ping is not allowed
}


generate_key() {
    local mail valid_mail_regex

    readonly valid_mail_regex='^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+$'

    if is_ssh_key_available; then
        confirm -d N "key @ [$PRIVATE_KEY_LOC] already exists; still generate key?" || return 1
    fi

    if ! command -v ssh-keygen >/dev/null; then
        err "ssh-keygen is not installed; won't generate ssh key."
        return 1
    fi

    report "generating ssh key..."
    while ! [[ "$mail" =~ $valid_mail_regex ]]; do
        report "enter your (valid) mail (eg [username@server.com]):"
        read -r mail
    done

    execute "ssh-keygen -t rsa -b 4096 -C '$mail' -f '$PRIVATE_KEY_LOC'"
}


# required for common point of logging and exception catching.
#
# provide '-i' or '--ignore-errs' as first arg to avoid returning non-zero code or
# logging ERR to exec logfile on unsuccessful execution.
execute() {
    local cmd exit_sig ignore_errs

    [[ "$1" == -i || "$1" == --ignore-errs ]] && { shift; readonly ignore_errs=1; } || readonly ignore_errs=0
    readonly cmd="$1"

    >&2 echo -e "${COLORS[GREEN]}-->${COLORS[OFF]} executing [${COLORS[YELLOW]}${cmd}${COLORS[OFF]}]"
    # TODO: collect and log command execution stderr?
    # TODO: eval?! seriously, were i drunk?
    eval "$cmd"
    readonly exit_sig=$?

    if [[ "$exit_sig" -ne 0 && "$ignore_errs" -ne 1 ]]; then
        [[ "$LOGGING_LVL" -ge 1 ]] && echo -e "    ERR CMD: [$cmd] (exited with code [$exit_sig])" >> "$EXECUTION_LOG"
        return $exit_sig
    fi

    [[ "$LOGGING_LVL" -ge 10 ]] && echo "OK CMD: $cmd" >> "$EXECUTION_LOG"
    return 0
}


select_items() {
    local DMENU nr_of_dmenu_vertical_lines dmenurc options options_dmenu
    local i prompt msg choices num is_single_selection selections

    # original version stolen from http://serverfault.com/a/298312
    declare -ar options=( $1 )
    readonly is_single_selection="$2"

    readonly dmenurc="$HOME/.dmenurc"
    readonly nr_of_dmenu_vertical_lines=40
    declare -a selections=()

    [[ -r "$dmenurc" ]] && source "$dmenurc" || DMENU="dmenu -i "

    function __menu() {
        local i

        echo -e "\n---------------------"
        echo "Available options:"
        for i in "${!options[@]}"; do
            printf '%3d%s) %s\n' "$((i+1))" "${choices[i]:- }" "${options[i]}"
        done
        [[ "$msg" ]] && echo "$msg"; :
    }

    if [[ "$is_single_selection" -eq 1 ]]; then
        if is_x && command -v dmenu > /dev/null 2>&1; then
            for i in "${options[@]}"; do
                options_dmenu+="$i\n"
            done
            __SELECTED_ITEMS="$(echo -e "$options_dmenu" | $DMENU -l $nr_of_dmenu_vertical_lines -p 'select item')"
            return
        fi
        readonly prompt="Check an option, only 1 item can be selected (again to uncheck, ENTER when done): "
    else
        readonly prompt="Check an option, multiple items allowed (again to uncheck, ENTER when done): "
    fi

    while __menu && read -rp "$prompt" num && [[ "$num" ]]; do
        [[ "$num" != *[![:digit:]]* ]] &&
        (( num > 0 && num <= ${#options[@]} )) ||
        { msg="Invalid option: $num"; continue; }
        ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"

        if [[ "$is_single_selection" -eq 1 ]]; then
            # un-select others to enforce single item only:
            for i in "${!choices[@]}"; do
                [[ "$i" -ne "$num" ]] && choices[i]=''
            done
        fi

        [[ "${choices[num]}" ]] && choices[num]='' || choices[num]='+'
    done

    for i in "${!options[@]}"; do
        [[ -n "${choices[i]}" ]] && selections+=( ${options[i]} )
    done

    __SELECTED_ITEMS="${selections[*]}"

    unset __menu  # to keep the inner function really an inner one (ie private).
}


remove_items_from_list() {
    local orig_list elements_to_remove i j

    [[ "$#" -ne 2 ]] && { err "exactly 2 args required" "$FUNCNAME"; return 1; }

    declare -a orig_list=( $1 )
    declare -ar elements_to_remove=( $2 )

    for i in "${!orig_list[@]}"; do
        for j in "${elements_to_remove[@]}"; do
            [[ "$j" == "${orig_list[i]}" ]] && unset orig_list[i]
        done
    done

    echo "${orig_list[*]}"
}


extract() {
    local file

    readonly file="$*"

    if [[ -z "$file" ]]; then
        err "gimme file to extract plz." "$FUNCNAME"
        return 1
    elif [[ ! -f "$file" || ! -r "$file" ]]; then
        err "[$file] is not a regular file or read rights not granted." "$FUNCNAME"
        return 1
    fi

    case "$file" in
        *.tar.bz2) tar xjf "$file"
                ;;
        *.tar.gz) tar xzf "$file"
                ;;
        *.tar.xz) tar xpvf "$file"
                ;;
        *.bz2) bunzip2 -k -- "$file"
                ;;
        *.rar) unrar x "$file"
                ;;
        *.gz) gunzip -kd -- "$file"
                ;;
        *.tar) tar xf "$file"
                ;;
        *.tbz2) tar xjf "$file"
                ;;
        *.tgz) tar xzf "$file"
                ;;
        *.zip) unzip -- "$file"
                ;;
        *.7z) 7z x -- "$file"
                ;;
        *.Z) uncompress -- "$file"
                ;;
        *) err "'$file' cannot be extracted; this filetype is not supported." "$FUNCNAME"
           return 1
                ;;
    esac
}


is_server() {
    [[ "$HOSTNAME" == *"server"* ]] && return 0 || return 1
}


# Checks whether system is a laptop.
#
# @returns {bool}   true if system is a laptop.
is_laptop() {
    local pwr_supply_dir
    readonly pwr_supply_dir="/sys/class/power_supply"

    # sanity:
    [[ -d "$pwr_supply_dir" ]] || { err "$pwr_supply_dir is not a valid dir! cannot decide if we're a laptop; assuming we're not. abort." "$FUNCNAME"; sleep 5; return 1; }

    find "$pwr_supply_dir" -mindepth 1 -maxdepth 1 -name 'BAT*' -print -quit | grep -q .
    return $?
}


# Checks whether system is running in WSL.
#
# @returns {bool}   true if we're running inside Windows.
is_windows() {
    if [[ -z "$_IS_WIN" ]]; then
        [[ -f /proc/version ]] || { err "/proc/version not a file, cannot test is_windows"; return 2; }
        grep -qE "(Microsoft|WSL)" /proc/version &>/dev/null
        readonly _IS_WIN=$?
    fi

    return $_IS_WIN
}


# Checks whether system is virtualized (including WSL); TODO: unsure if it detects WSL;
#
# @returns {bool}   true if we're running in virt mode.
is_virt() {
    if [[ -z "$_IS_VIRT" ]]; then
        [[ -f /proc/cpuinfo ]] || { err "/proc/cpuinfo not a file, cannot test virtualization"; return 2; }
        grep -qE '^flags.*\s+hypervisor' /proc/cpuinfo &>/dev/null  # detects all virtualizations, including WSL
        readonly _IS_VIRT=$?
    fi

    return $_IS_VIRT
}


# Checks whether system is running in _virtualbox_ (not just in any virtualization)
#
# @returns {bool}   true if we're running in a virtualbox vm
is_virtualbox() {
    if [[ -z "$_IS_VIRTUALBOX" ]]; then
        lspci | grep -qi virtualbox
        readonly _IS_VIRTUALBOX=$?
    fi

    return $_IS_VIRTUALBOX
}


# Checks whether we're running native, ie we're not running in
# vbox, hyper-v, wsl et al.
#
# @returns {bool}   true if we're native.
is_native() {
    if [[ -z "$_IS_NATIVE" ]]; then
        ! is_windows && ! is_virt
        readonly _IS_NATIVE=$?
    fi

    return $_IS_NATIVE
}


is_64_bit() {
    [[ "$(uname -m)" == x86_64 ]] && return 0 || return 1
}


# Checks whether we're in a git repository.
#
# @returns {bool}  true, if we are in git repo.
is_git() {
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        return 0
    fi

    return 1
}


# Checks whether we're in graphical environment.
#
# @returns {bool}  true, if we're currently in graphical env.
function is_x() {
    local exit_code

    if command -v xset > /dev/null 2>&1; then
        xset q &>/dev/null
        exit_code="$?"
    elif command -v wmctrl > /dev/null 2>&1; then
        wmctrl -m &>/dev/null
        exit_code="$?"
    else
        err "can't check, neither [xset] nor [wmctrl] are installed" "$FUNCNAME"
        return 2
    fi

    [[ "$exit_code" -eq 0 && -n "$DISPLAY" ]] && return 0 || return 1
}


# Checks whether given url is a valid url.
#
# @param {string}  url   url which validity to test.
#
# @returns {bool}  true, if provided url was a valid url.
function is_valid_url() {
    local url regex

    readonly url="$1"

    readonly regex='(https?|ftp|file)://[-A-Za-z0-9\+&@#/%?=~_|!:,.;]*[-A-Za-z0-9\+&@#/%=~_|]'

    [[ "$url" =~ $regex ]] && return 0 || return 1
}


# pass '-s' or '--sudo' as first arg to execute as sudo
#
# second arg, the target, should end with a slash if a containing dir is meant to be
# passed, not a literal path to the link-to-be-created.
create_link() {
    local src target sudo

    [[ "$1" == -s || "$1" == --sudo ]] && { shift; readonly sudo=sudo; }

    readonly src="$1"
    target="$2"

    if [[ "$target" == */ ]] && $sudo test -d "$target"; then
        target="${target}$(basename -- "$src")"
    fi
    #if $sudo test -d "$target"; then
        #[[ "$target" != */ ]] && target+='/'
        #target="${target}$(basename -- "$src")"
    #fi

    $sudo test -h "$target" && execute "$sudo rm -- '$target'"  # only remove $target if it's already a symlink
    execute "${sudo:+$sudo }ln -s -- '$src' '$target'"

    return 0
}


__is_work() {
    [[ "$HOSTNAME" == "$WORK_DESKTOP_HOSTNAME" || "$HOSTNAME" == "$WORK_LAPTOP_HOSTNAME" ]] \
            && return 0 \
            || return 1
}


# Checks whether the element is contained in an array/list.
#
# @param {string}        element to check.
# @param {string list}   string list to check passed element in. NOT a bash array!
#
# @returns {bool}  true if array contains the element.
list_contains() {
    local array element i

    readonly element="$1"
    declare -ar array=( $2 )

    [[ "$#" -ne 2 ]] && { err "exactly 2 args required" "$FUNCNAME"; return 1; }
    #[[ -z "$element" ]]    && { err "element to check can't be empty string." "$FUNCNAME"; return 1; }  # it can!
    [[ -z "${array[@]}" ]] && { err "array/list to check from can't be empty." "$FUNCNAME"; return 1; }

    for i in "${array[@]}"; do
        [[ "$i" == "$element" ]] && return 0
    done

    return 1
}


# Checks whether the passed programs are installed on the system.
#
# @param {string...}   list of programs whose existence to check. NOT a bash array!
#
# @returns {bool}  true if ALL the passed programs are installed.
check_progs_installed() {
    local msg msg_beginning i progs_missing

    declare -a progs_missing=()

    # Check whether required programs are installed:
    for i in "$@"; do
        if ! cmd_avail "$i"; then
            progs_missing+=( "$i" )
        fi
    done

    if [[ "${#progs_missing[@]}" -gt 0 ]]; then
        [[ "${#progs_missing[@]}" -eq 1 ]] && readonly msg_beginning="[1] required program appears" || readonly msg_beginning="[${#progs_missing[@]}] required programs appear"
        readonly msg="$msg_beginning not to be installed on the system:\n\t$(build_comma_separated_list "${progs_missing[@]}")\n\nAbort.\n"
        err "$msg"

        return 1
    fi

    return 0
}


# Checks whether _any_ of the passed programs are installed on the system.
#
# @param {string...}   list of programs whose existence to check. NOT a bash array!
#
# @returns {bool}  true if ANY of the passed programs is installed.
cmd_avail() {
    command -v -- "$@" > /dev/null 2>&1
}


# Retries a command on failure.
#
# @param {digit}  retries  number of retries (if 0, then no retries will be made)
# @param {string...}  cmd  command to run
#
# @returns {bool}  false, if command failed to execute successfully after
#                  given attempts.
retry() {
    local -r -i max_attempts="$1"; shift
    local -r cmd="$*"
    local -i attempt_num=1

    until $cmd; do
        if (( attempt_num > max_attempts )); then
            err "Attempt $attempt_num failed and there are no more attempts left!"
            return 1
        else
            report "Attempt $attempt_num failed! Trying again in $attempt_num seconds..."
            sleep $(( attempt_num++ ))
        fi
    done
}


# Builds comma separated list.
#
# @param {string...}   list of elements to build string from.
#
# @returns {string}  comma separated list, eg "a, b, c"
build_comma_separated_list() {
    local list

    list="$*"
    echo "${list// /, }"
    return 0
}


# Copies given text to system clipboard.
#
# @param {string}  input   text to put to the clipboard.
#
# @returns {bool}  true, if copying to clipboard succeeded.
copy_to_clipboard() {
    local input

    readonly input="$1"

    { command -v xsel >/dev/null 2>/dev/null && echo -n "$input" | xsel --clipboard; } \
        || { command -v copyq >/dev/null 2>/dev/null && copyq add "$input" && copyq select 0; } \
        || { command -v xclip >/dev/null 2>/dev/null && echo -n "$input" | xclip -selection clipboard; } \
        || return 1

    return 0
}


# Create links of files in given directory, into antther dir.
#
# @param {string}  src  directory whose contents should be linked to dest
# @param {string}  dest directory where links of files in $src should be created in.
create_symlinks() {
    local src dest

    src="$1"
    dest="$2"

    [[ -d "$src" && -d "$dest" ]] || { err "either given [$src] or [$dest] are not valid dirs"; return 1; }

    # Create symlink of every file (note target file will be overwritten no matter what):
    find "$src" -maxdepth 1 -mindepth 1 -type f -printf 'ln -sf -- "%p" "$dest"\n' | dest="$dest" bash
}


# Removes too old installations from given dir.
#
# @param {string}  src_dir                 directory where installations are kept
# @param {int}     number_of_olds_to_keep  how many old vers should we keep?
clear_old_vers() {
    local src_dir number_of_olds_to_keep nodes i

    src_dir="${1:-./installations}"   # default to ./installations
    number_of_olds_to_keep=${2:-2}    # default to 2 newest to keep

    [[ -d "$src_dir" ]] || { err "dir [$src_dir] is not a valid dir"; return 1; }
    is_digit "$number_of_olds_to_keep" || { err "\$number_of_olds_to_keep is not a digit"; return 1; }
    declare -a nodes

    while IFS= read -r i; do
        nodes+=("$(grep -Poi '^\d+\.\d+\s\K.*' <<< "$i")")
    done < <(find "$src_dir" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\n' | sort -nr)
    [[ ${#nodes[@]} -le "$number_of_olds_to_keep" ]] && return

    for ((i=number_of_olds_to_keep;i<${#nodes[@]};i++)); do
        execute "sudo rm -rf -- '${nodes[i]}'"
    done
}


# Tests whether given directory is empty.
#
# @param {string}  dir   directory whose emptiness to test.
#
# @returns {bool}  true, if directory IS empty.
function is_dir_empty() {
    local dir

    readonly dir="$1"

    [[ -d "$dir" ]] || { err "[$dir] is not a valid dir." "$FUNCNAME"; return 2; }
    find "$dir" -mindepth 1 -maxdepth 1 -print -quit | grep -q . && return 1 || return 0
}


# Checks whether the argument is a non-negative digit.
#
# @param {digit}  arg   argument to check.
#
# @returns {bool}  true if argument is a valid (and non-negative) digit.
is_digit() {
    [[ "$*" =~ ^[0-9]+$ ]]
}


is_noninteractive() {
    [[ "$NON_INTERACTIVE" -eq 1 ]]
}


# Checks whether the provided function name is actually a defined function.
#
# @param {string}   fun     name of the function whose validity to check.
#
# @returns {bool}    true, if provided function name is a valid function.
is_function() {
    local _type fun

    readonly fun="$1"

    _type="$(type -t -- "$fun" 2> /dev/null)"
    [[ "$?" -eq 0 && "$_type" == function ]]
}



# Verifies given string is non-empty, non-whitespace-only and on a single line.
#
# @param {string}  s  string to validate.
#
# @returns {bool}  true, if passed string is non-empty, and on a single line.
is_single() {
    local s

    readonly s="$(tr -d '[:blank:]' <<< "$*")"  # make sure not to strip newlines
    [[ -n "$s" && "$(wc -l <<< "$s")" -eq 1 ]]
}

pushd() {
    command pushd "$@" > /dev/null
}

popd() {
    command popd > /dev/null
}


cleanup() {
    [[ "$__CLEANUP_EXECUTED_MARKER" -eq 1 ]] && return  # don't invoke more than once.

    [[ -s "$NPMRC_BAK" ]] && mv -- "$NPMRC_BAK" ~/.npmrc   # move back

    # shut down the build container:
    if command -v docker >/dev/null 2>&1 && [[ -n "$(docker ps -qa -f status=running -f name="$BUILD_DOCK" --format '{{.Names}}')" ]]; then
        execute "docker stop '$BUILD_DOCK'" || err "[cleanup] stopping build container [$BUILD_DOCK] failed"
    fi

    if [[ -n "${PACKAGES_IGNORED_TO_INSTALL[*]}" ]]; then
        echo -e "    ERR INSTALL: [cleanup] dry run failed for these packages: [${PACKAGES_IGNORED_TO_INSTALL[*]}]" >> "$EXECUTION_LOG"
    fi
    if [[ -n "${PACKAGES_FAILED_TO_INSTALL[*]}" ]]; then
        echo -e "    ERR INSTALL: [cleanup] failed installing these packages: [${PACKAGES_FAILED_TO_INSTALL[*]}]" >> "$EXECUTION_LOG"
    fi

    if [[ -e "$EXECUTION_LOG" ]]; then
        sed -i --follow-symlinks '/^\s*$/d' "$EXECUTION_LOG"  # strip empty lines

        echo -e "\n\n___________________________________________"
        echo -e "\tscript execution log can be found at [$EXECUTION_LOG]"
        grep -q '    ERR' "$EXECUTION_LOG" && echo -e "${COLORS[RED]}    NOTE: log contains errors.${COLORS[OFF]}"
        copy_to_clipboard "$EXECUTION_LOG" && echo -e '(logfile location has been copied to clipboard)'
        echo -e "___________________________________________"
    fi

    readonly __CLEANUP_EXECUTED_MARKER=1  # states cleanup() has been invoked;
}


#----------------------------
#---  Script entry point  ---
#----------------------------
while getopts "NFSU" OPT_; do
    case "$OPT_" in
        N) NON_INTERACTIVE=1
            ;;
        F) MODE=1  # full install
            ;;
        S) MODE=0  # single task
            ;;
        U) MODE=2  # update/quick_refresh
            ;;
        *) print_usage; exit 1 ;;
    esac
done
shift "$((OPTIND-1))"; unset OPT_

readonly PROFILE="$1"   # work | personal

[[ "$EUID" -eq 0 ]] && { err "don't run as root."; exit 1; }
trap "cleanup; exit" EXIT HUP INT QUIT PIPE TERM;

validate_and_init
check_dependencies
choose_step

exit


# ISSUES:
# if no sound, make sure alsa is defaulting to right card:
# aplay -l   and check card number; probably it's defaulting to 0;
# you want it to use the PCH device; if somehtings wrong, then
# create either /etc/asound.conf or $HOME/.asoundrc with these 3 lines:
    #defaults.ctl.card 1
    #defaults.pcm.card 1
    #defaults.timer.card 1
# in that case you probably need to change the device xfce4-volumed is controlling

# TODOS:
# - if apt-get update fails, then we should fail script fast?
# - provide -Q option for quick execution; eg skip massive font installation
#   and other dependency builds;
