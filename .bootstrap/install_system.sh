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
readonly TMPDIR='/tmp'
readonly CLANG_LLVM_LOC='http://llvm.org/releases/3.9.0/clang+llvm-3.9.0-x86_64-linux-gnu-debian8.tar.xz'  # http://llvm.org/releases/download.html
readonly VIM_REPO_LOC='https://github.com/vim/vim.git'                # vim - yeah.
readonly NVIM_REPO_LOC='https://github.com/neovim/neovim.git'         # nvim - yeah.
readonly KEEPASS_REPO_LOC='https://github.com/keepassx/keepassx.git'  # keepassX - open password manager forked from keepass project
readonly GOFORIT_REPO_LOC='https://github.com/mank319/Go-For-It.git'  # go-for-it -  T-O-D-O  list manager
readonly COPYQ_REPO_LOC='https://github.com/hluk/CopyQ.git'           # copyq - awesome clipboard manager
readonly SYNERGY_REPO_LOC='https://github.com/synergy/synergy.git'    # synergy - share keyboard&mouse between computers on same LAN
readonly ORACLE_JDK_LOC='http://download.oracle.com/otn-pub/java/jdk/8u112-b15/jdk-8u112-linux-x64.tar.gz' # jdk8: http://www.oracle.com/technetwork/java/javase/downloads/jdk8-downloads-2133151.html
                                                                                                           # jdk7: http://www.oracle.com/technetwork/java/javase/downloads/jdk7-downloads-1880260.html
                                                                                                           # jdk9: https://jdk9.java.net/  /  https://jdk9.java.net/download/
readonly SKYPE_LOC='http://www.skype.com/go/getskype-linux-deb'       # http://www.skype.com/en/download-skype/skype-for-computer/
readonly JDK_LINK_LOC="/usr/local/jdk_link"      # symlink linking to currently active java installation
readonly JDK_INSTALLATION_DIR="/usr/local/javas" # dir containing all the installed java versions
readonly PRIVATE_KEY_LOC="$HOME/.ssh/id_rsa"
readonly SHELL_ENVS="$HOME/.bash_env_vars"       # location of our shell vars; expected to be pulled in via homesick;
                                                 # note that contents of that file are somewhat important, as some
                                                 # (script-related) configuration lies within.
readonly NFS_SERVER_SHARE="/data"            # default node to share over NFS
readonly SSH_SERVER_SHARE="/data"            # default node to share over SSH
#------------------------
#--- Global Variables ---
#------------------------
IS_SSH_SETUP=0       # states whether our ssh keys are present. 1 || 0
__SELECTED_ITEMS=''  # only select_items() *writes* into this one.
MODE=''
FULL_INSTALL=0                  # whether script is performing full install or not. 1 || 0
declare -a PACKAGES_IGNORED_TO_INSTALL=()  # list of all packages that failed to install during the setup
declare -a PACKAGES_FAILED_TO_INSTALL=()
LOGGING_LVL=0                   # execution logging level (full install mode logs everything);
                                # don't set log level too soon; don't want to persist bullshit.
                                # levels are currently 0, 1 and 10, 1 being the lowest (least amount of events logged.)
EXECUTION_LOG="$HOME/installation-execution-$(date +%d-%b-%y--%R).log" \
        || readonly EXECUTION_LOG="$HOME/installation-exe.log"  # do not create logfile here! otherwise cleanup() picks it up and reports of its existence;

#------------------------
#--- Global Constants ---
#------------------------
readonly BASE_DATA_DIR="/data"  # try to keep this value in sync with equivalent defined in $SHELL_ENVS;
readonly BASE_DEPS_LOC="$BASE_DATA_DIR/progs/deps"  # hosting stuff like homeshick, bash-git-prompt...
readonly BASE_BUILDS_DIR="$BASE_DATA_DIR/progs/custom_builds"  # hosts our built progs and/or their .deb packages;
readonly BASE_HOMESICK_REPOS_LOC="$BASE_DEPS_LOC/homesick/repos"
readonly COMMON_DOTFILES="$BASE_HOMESICK_REPOS_LOC/dotfiles"
readonly COMMON_PRIVATE_DOTFILES="$BASE_HOMESICK_REPOS_LOC/private-common"
readonly SOME_PACKAGE_IGNORED_EXIT_CODE=199
PRIVATE_CASTLE=''  # installation specific private castle location (eg for 'work' or 'personal')

readonly SELF="${0##*/}"

declare -Ar COLORS=(
    [RED]=$'\033[0;31m'
    [YELLOW]=$'\033[0;33m'
    [OFF]=$'\033[0m'
    [BOLD]=$'\033[1m'
)
#-----------------------
#---    Functions    ---
#-----------------------


function print_usage() {

    printf "${SELF}:  install/provision system.
        usage: $SELF  work|personal
    "
}


function validate_and_init() {

    # need to define PRIVATE_CASTLE here, as otherwis 'single-step' mode of this
    # script might fail. be sure the repo names are in sync with the repos actually
    # pulled in fetch_castles().
    case $MODE in
        work)
            if [[ "$__ENV_VARS_LOADED_MARKER_VAR" == loaded ]] && ! __is_work; then
                confirm "you selected [${COLORS[RED]}${COLORS[BOLD]}$MODE${COLORS[OFF]}] mode on non-work machine; sure you want to continue?" || exit
            fi

            PRIVATE_CASTLE="$BASE_HOMESICK_REPOS_LOC/work_dotfiles"
            ;;
        personal)
            if [[ "$__ENV_VARS_LOADED_MARKER_VAR" == loaded ]] && __is_work; then
                confirm "you selected [${COLORS[RED]}${COLORS[BOLD]}$MODE${COLORS[OFF]}] mode on work machine; sure you want to continue?" || exit
            fi

            PRIVATE_CASTLE="$BASE_HOMESICK_REPOS_LOC/personal-dotfiles"
            ;;
        *)
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
        IS_SSH_SETUP=0
    fi

    # ask for the admin password upfront:
    report "enter sudo password:"
    sudo -v || { clear; err "is user in sudoers file? is sudo installed? if not, then \"su && apt-get install sudo\""; exit 2; }
    clear

    # keep-alive: update existing `sudo` time stamp
    while true; do sudo -n true; sleep 30; kill -0 "$$" || exit; done 2>/dev/null &
}


# check dependencies required for this installation script
function check_dependencies() {
    local dir prog perms

    readonly perms=764  # can't be 777, nor 766, since then you'd be unable to ssh into;

    for prog in git wget tar realpath dirname basename tee; do
        if ! command -v "$prog" >/dev/null; then
            report "[$prog] not installed yet, installing..."
            install_block "$prog" || { err "unable to install required prog [$prog] this script depends on. abort."; exit 1; }
            report "...done"
        fi
    done

    # TODO: need to create dev/ already here, since both dotfiles and private-common
    # either point to it, or point at something in it; not a good solution.
    # best finalise scripts and move them to the public/common dotfiles repo.
    #
    #
    # verify required dirs are existing and have $perms perms:
    for dir in \
            $BASE_DATA_DIR \
            $BASE_DATA_DIR/dev \
                ; do
        if ! [[ -d "$dir" ]]; then
            if confirm "[$dir] mountpoint/dir does not exist; simply create a directory instead? (answering 'no' aborts script)"; then
                execute "sudo mkdir $dir" || { err "unable to create [$dir] directory. abort."; exit 1; }
            else
                err "expected [$dir] to be already-existing dir. abort"
                exit 1
            fi
        fi

        execute "sudo chown $USER:$USER $dir" || { err "unable to change [$dir] ownership to [$USER:$USER]. abort."; exit 1; }
        execute "sudo chmod $perms -- $dir" || { err "unable to change [$dir] permissions to [$perms]. abort."; exit 1; }
    done
}


function setup_hosts() {
    local hosts_file_dest file current_hostline tmpfile

    readonly hosts_file_dest="/etc"
    readonly tmpfile="$TMPDIR/hosts"
    readonly file="$PRIVATE_CASTLE/backups/hosts"

    function _extract_current_hostname_line() {
        local file current

        readonly file="$1"
        #current="$(grep '\(127\.0\.1\.1\)\s\+\(.*\)\s\+\(\w\+\)' $file)"
        readonly current="$(grep "$HOSTNAME" "$file")"
        if [[ -z "$current" || "$(echo "$current" | wc -l)" -ne 1 ]]; then
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
        readonly current_hostline="$(_extract_current_hostname_line $hosts_file_dest/hosts)" || return 1
        execute "cp -- $file $tmpfile" || { err; return 1; }
        execute "sed -i 's/{HOSTS_LINE_PLACEHOLDER}/$current_hostline/g' $tmpfile" || { err; return 1; }

        backup_original_and_copy_file "$tmpfile" "$hosts_file_dest"
        execute "rm -- $tmpfile"
    else
        err "expected configuration file at [$file] does not exist; won't install it."
        return 1
    fi

    unset _extract_current_hostname_line
}


function setup_sudoers() {
    local sudoers_dest file tmpfile

    readonly sudoers_dest="/etc"
    readonly tmpfile="$TMPDIR/sudoers"
    readonly file="$COMMON_DOTFILES/backups/sudoers"

    if ! [[ -d "$sudoers_dest" ]]; then
        err "[$sudoers_dest] is not a dir; skipping sudoers file installation."
        return 1
    fi

    if [[ -f "$file" ]]; then
        execute "cp -- $file $tmpfile" || return 1
        execute "sed -i 's/{USER_PLACEHOLDER}/$USER/g' $tmpfile" || return 1
        backup_original_and_copy_file "$tmpfile" "$sudoers_dest"

        execute "rm -- '$tmpfile'"
    else
        err "expected configuration file at [$file] does not exist; won't install it."
        return 1
    fi
}


function setup_apt() {
    local apt_dir file

    readonly apt_dir="/etc/apt"

    if ! [[ -d "$apt_dir" ]]; then
        err "[$apt_dir] is not a dir; skipping apt conf installation."
        return 1
    fi

    for file in \
            sources.list \
            preferences \
            apt.conf \
                ; do
        file="$COMMON_DOTFILES/backups/$file"

        if [[ -f "$file" ]]; then
            backup_original_and_copy_file "$file" "$apt_dir"
        else
            err "expected configuration file at [$file] does not exist; won't install it."
        fi
    done
}


function setup_crontab() {
    local cron_dir tmpfile file

    readonly cron_dir="/etc/cron.d"  # where crontab will be installed at
    readonly tmpfile="$TMPDIR/crontab"
    readonly file="$PRIVATE_CASTLE/backups/crontab"

    if ! [[ -d "$cron_dir" ]]; then
        err "[$cron_dir] is not a dir; skipping crontab installation."
        return 1
    fi

    if [[ -f "$file" ]]; then
        execute "cp -- '$file' '$tmpfile'" || return 1
        execute "sed -i 's/{USER_PLACEHOLDER}/$USER/g' $tmpfile" || return 1
        #backup_original_and_copy_file "$tmpfile" "$cron_dir"  # don't create backup - dont wanna end up with 2 crontabs
        execute "sudo cp -- '$tmpfile' '$cron_dir'"

        execute "rm -- '$tmpfile'"
    else
        err "expected configuration file at [$file] does not exist; won't install it."
    fi
}


function backup_original_and_copy_file() {
    local file dest_dir filename

    readonly file="$1"          # full path of the file to be copied
    readonly dest_dir="${2%/}"  # full path of the destination directory to copy to

    readonly filename="$(basename -- "$file")"

    [[ -d "$dest_dir" ]] || { err "second arg [$dest_dir] was not a dir" "$FUNCNAME"; return 1; }
    # back up the destination file, if it's already existing:
    if [[ -f "$dest_dir/$filename" && ! -e "$dest_dir/${filename}.orig" ]]; then
        execute "sudo cp -- '$dest_dir/$filename' '$dest_dir/${filename}.orig'"
    fi

    execute "sudo cp -- '$file' '$dest_dir'"
}


function clone_or_pull_repo() {
    local user repo install_dir hub

    readonly user="$1"
    readonly repo="$2"
    readonly install_dir="$3"
    readonly hub=${4:-"github.com"}  # OPTIONAL; if not provided, defaults to github.com;

    [[ -z "$install_dir" ]] && { err "need to provide target directory." "$FUNCNAME"; return 1; }

    if ! [[ -d "$install_dir/$repo" ]]; then
        execute "git clone https://$hub/$user/${repo}.git $install_dir/$repo" || return 1

        execute "pushd $install_dir/$repo" || return 1
        execute "git remote set-url origin git@${hub}:$user/${repo}.git"
        execute "git remote set-url --push origin git@${hub}:$user/${repo}.git"
        execute "popd"
    elif is_ssh_key_available; then
        execute "pushd $install_dir/$repo" || return 1
        execute "git pull"
        execute "popd"
    fi
}


function install_nfs_server() {
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
        if confirm "$(report "add client IP for the exports list (who will access [$NFS_SERVER_SHARE])?")"; then
            echo -e "enter client ip:"
            read -r client_ip

            [[ "$client_ip" =~ ^[0-9.]+$ ]] || { err "not a valid ip: [$client_ip]"; continue; }

            echo -e "enter share to expose (leave blank to default to [$NFS_SERVER_SHARE]):"
            read -r share

            share=${share:-"$NFS_SERVER_SHARE"}
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
        else
            break
        fi
    done

    # exports the shares:
    execute 'sudo exportfs -ra' || err

    return 0
}


function install_nfs_client() {
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
        if confirm "$(report "add ${server_ip:+another} nfs server entry to fstab?")"; then
            echo -e "enter server ip: ${prev_server_ip:+(leave blank to default to [$prev_server_ip])}"
            read -r server_ip
            [[ -z "$server_ip" ]] && server_ip="$prev_server_ip"
            [[ "$server_ip" =~ ^[0-9.]+$ ]] || { err "not a valid ip: [$server_ip]"; continue; }

            echo -e "enter local mountpoint to mount nfs share to (leave blank to default to [${default_mountpoint}]):"
            read -r mountpoint
            [[ -z "$mountpoint" ]] && mountpoint="$default_mountpoint"
            create_mountpoint "$mountpoint" || continue
            list_contains "$mountpoint" "${used_mountpoints[*]}" && { report "selected mountpoint [$mountpoint] has already been used for previous definition"; continue; }

            echo -e "enter remote share to mount (leave blank to default to [${NFS_SERVER_SHARE}]):"
            read -r nfs_share
            [[ -z "$nfs_share" ]] && nfs_share="$NFS_SERVER_SHARE"
            [[ "$nfs_share" != /* ]] && { err "remote share needs to be defined as full path."; continue; }
            list_contains "${server_ip}${nfs_share}" "${mounted_shares[*]}" && { report "selected [${server_ip}:${nfs_share}] has already been used for previous definition"; continue; }

            if ! grep -q "${server_ip}:${nfs_share}.*${mountpoint}" "$fstab"; then
                report "adding [${server_ip}:$nfs_share] mounting to [$mountpoint] in $fstab"
                execute "echo ${server_ip}:${nfs_share} ${mountpoint} nfs noauto,x-systemd.automount,_netdev,x-systemd.device-timeout=10,timeo=14,rsize=8192,wsize=8192 0 0 \
                        | sudo tee --append $fstab > /dev/null"
            else
                report "an nfs share entry for [${server_ip}:${nfs_share}] in $fstab already exists."
            fi

            prev_server_ip="$server_ip"
            used_mountpoints+=("$mountpoint")
            mounted_shares+=("${server_ip}${nfs_share}")
        else
            break
        fi
    done

    return 0
}


function install_ssh_server() {
    local sshd_confdir config banner

    readonly sshd_confdir="/etc/ssh"
    readonly config="$COMMON_PRIVATE_DOTFILES/backups/sshd_config"
    readonly banner="$COMMON_PRIVATE_DOTFILES/backups/ssh_banner"

    confirm "wish to install & configure ssh server?" || return 1
    is_laptop && ! confirm "you're on laptop; sure you wish to install ssh server?" && return 1

    install_block 'openssh-server' || { err "unable to install openssh-server. aborting sshd install/config."; return 1; }

    if ! [[ -d "$sshd_confdir" ]]; then
        err "[$sshd_confdir] is not a dir; skipping sshd conf installation."
        return 1
    fi

    # install sshd config:
    if [[ -f "$config" ]]; then
        backup_original_and_copy_file "$config" "$sshd_confdir"
    else
        err "expected configuration file at [$config] does not exist; aborting sshd configuration."
        return 1
    fi


    # install ssh banner:
    if [[ -f "$banner" ]]; then
        backup_original_and_copy_file "$banner" "$sshd_confdir"
    else
        err "expected sshd banner file at [$banner] does not exist; won't install it."
        #return 1  # don't return, it's just a banner.
    fi

    execute "sudo systemctl start sshd.service"
    #execute "systemctl enable sshd.service"  # TODO: this is not required, is it?

    return 0
}


function create_mountpoint() {
    local mountpoint

    readonly mountpoint="$1"

    [[ -z "$mountpoint" ]] && { err "cannot pass empty mountpoint arg to $FUNCNAME"; return 1; }

    [[ -d "$mountpoint" ]] || execute "sudo mkdir -- $mountpoint" || { err "couldn't create [$mountpoint]"; return 1; }
    execute "sudo chmod 777 -- $mountpoint" || { err; return 1; }

    return 0
}


function install_sshfs() {
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
    if ! [[ -f "$identity_file" ]]; then
        confirm "[$identity_file] ssh key does not exist; still continue?" || return 1
    fi
    install_block 'sshfs' || { err "unable to install sshfs. aborting sshfs install/config."; return 1; }

    # note that 'user_allow_other' uncommenting makes sense only if our related fstab
    # entry has the 'allow_other' opt:
    if ! [[ -r "$fuse_conf" && -f "$fuse_conf" ]]; then
        err "[$fuse_conf] is not readable; cannot uncomment \"\#user_allow_other\" prop in it."
    elif grep -q '#user_allow_other' "$fuse_conf"; then
        # hasn't been uncommented yet
        execute "sudo sed -i 's/#user_allow_other/user_allow_other/g' $fuse_conf"
        [[ $? -ne 0 ]] && { err "uncommenting '#user_allow_other' in $fuse_conf failed"; return 2; }
    elif grep -q 'user_allow_other' "$fuse_conf"; then
        true  # do nothing; already uncommented, all good;
    else
        err "[$fuse_conf] appears not to contain config value \"user_allow_other\"; check manually."
    fi

    # add us to the fuse group:
    execute "sudo gpasswd -a $USER fuse"

    [[ -f "$fstab" ]] || { err "[$fstab] does not exist; cannot add fstab entry!"; return 1; }

    while true; do
        if confirm "$(report "add ${server_ip:+another} sshfs entry to fstab?")"; then
            echo -e "enter server ip: ${prev_server_ip:+(leave blank to default to [$prev_server_ip])}"
            read -r server_ip
            [[ -z "$server_ip" ]] && server_ip="$prev_server_ip"
            [[ "$server_ip" =~ ^[0-9.]+$ ]] || { err "not a valid ip: [$server_ip]"; continue; }

            echo -e "enter remote user to log in as (leave blank to default to your local user, [$USER]):"
            read -r remote_user
            [[ -z "$remote_user" ]] && remote_user="$USER"

            echo -e "enter local mountpoint to mount sshfs share to (leave blank to default to [$default_mountpoint]):"
            read -r mountpoint
            [[ -z "$mountpoint" ]] && mountpoint="$default_mountpoint"
            create_mountpoint "$mountpoint" || continue
            list_contains "$mountpoint" "${used_mountpoints[*]}" && { report "selected mountpoint [$mountpoint] has already been used for previous definition"; continue; }

            echo -e "enter remote share to mount (leave blank to default to [${SSH_SERVER_SHARE}]):"
            read -r ssh_share
            [[ -z "$ssh_share" ]] && ssh_share="$SSH_SERVER_SHARE"
            [[ "$ssh_share" != /* ]] && { err "remote share needs to be defined as full path."; continue; }
            list_contains "${server_ip}${ssh_share}" "${mounted_shares[*]}" && { report "selected [${server_ip}:${ssh_share}] has already been used for previous definition"; continue; }

            if ! grep -q "${remote_user}@${server_ip}:${ssh_share}.*${mountpoint}" "$fstab"; then
                report "adding [${server_ip}:$ssh_share] mounting to [$mountpoint] in $fstab"
                execute "echo ${remote_user}@${server_ip}:${ssh_share} $mountpoint fuse.sshfs port=${ssh_port},noauto,x-systemd.automount,_netdev,users,idmap=user,IdentityFile=${identity_file},allow_other,reconnect 0 0 \
                        | sudo tee --append $fstab > /dev/null"

                sel_ips_to_user["$server_ip"]="$remote_user"
            else
                report "an ssh share entry for [${server_ip}:${ssh_share}] in $fstab already exists."
            fi

            prev_server_ip="$server_ip"
            used_mountpoints+=("$mountpoint")
            mounted_shares+=("${server_ip}${ssh_share}")
        else
            break
        fi
    done

    report "ssh-ing to entered IPs [${!sel_ips_to_user[*]}], so our root would have the remote in the /root/.ssh/known_hosts ..."
    report "select [yes] if asked whether to add entry to known hosts"

    for server_ip in "${!sel_ips_to_user[@]}"; do
        remote_user="${sel_ips_to_user[$server_ip]}"
        report "testing ssh connection to ${remote_user}@${server_ip}..."
        execute "sudo ssh -p ${ssh_port} -o ConnectTimeout=7 ${remote_user}@$server_ip echo ok"
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
        #backup_original_and_copy_file "$ssh_conf" "$ssh_confdir"
    #else
        #err "expected ssh configuration file at [$ssh_conf] does not exist; aborting ssh (client) configuration."
        #return 1
    #fi

    #return 0
#}


# "deps" as in git repos/py modules et al our system setup depends on;
# if equivalent is avaialble at deb repos, its installation should be
# moved to  install_from_repo()
function install_deps() {
    function _install_tmux_deps() {
        local dir plugins_dir

        readonly plugins_dir="$HOME/.tmux/plugins"

        if ! [[ -d "$plugins_dir/tpm" ]]; then
            clone_or_pull_repo "tmux-plugins" "tpm" "$plugins_dir"
            report "don't forget to install tmux plugins by running <prefix + I> in tmux later on." && sleep 4
        else
            # update all the tmux plugins, including the plugin manager itself:
            execute "pushd $plugins_dir" || return 1

            for dir in *; do
                if [[ -d "$dir" ]] && is_ssh_key_available; then
                    execute "pushd $dir" || return 1
                    is_git && execute "git pull"
                    execute "popd"
                fi
            done

            execute "popd"
        fi
    }

    # bash-git-prompt:
    clone_or_pull_repo "magicmonty" "bash-git-prompt" "$BASE_DEPS_LOC"
    create_link "${BASE_DEPS_LOC}/bash-git-prompt" "$HOME/.bash-git-prompt"

    # git-flow-completion:  # https://github.com/bobthecow/git-flow-completion
    clone_or_pull_repo "bobthecow" "git-flow-completion" "$BASE_DEPS_LOC"
    create_link "${BASE_DEPS_LOC}/git-flow-completion" "$HOME/.git-flow-completion"

    # bars (as in bar-charts) in shell:
    clone_or_pull_repo "holman" "spark" "$BASE_DEPS_LOC"  # https://github.com/holman/spark
    create_link "${BASE_DEPS_LOC}/spark/spark" "$HOME/bin/spark"

    # imgur screenshooter-uploader:
    clone_or_pull_repo "jomo" "imgur-screenshot" "$BASE_DEPS_LOC"  # https://github.com/jomo/imgur-screenshot.git
    create_link "${BASE_DEPS_LOC}/imgur-screenshot/imgur-screenshot.sh" "$HOME/bin/imgur-screenshot"

    # fuzzy file finder/command completer etc:
    clone_or_pull_repo "junegunn" "fzf" "$BASE_DEPS_LOC"  # https://github.com/junegunn/fzf
    create_link "${BASE_DEPS_LOC}/fzf" "$HOME/.fzf"
    execute "$HOME/.fzf/install --all" || err "could not install fzf"

    # fasd - shell navigator similar to autojump:
    clone_or_pull_repo "clvv" "fasd" "$BASE_DEPS_LOC"  # https://github.com/clvv/fasd.git
    create_link "${BASE_DEPS_LOC}/fasd/fasd" "$HOME/bin/fasd"

    # tmux plugin manager:
    _install_tmux_deps

    # TODO: these are not deps, are they?:
    execute "sudo pip install --upgrade git-playback"   # https://github.com/jianli/git-playback

    # this needs apt-get install  python-imaging ?:
    execute "sudo pip  install --upgrade img2txt.py"    # https://github.com/hit9/img2txt  (for ranger)
    execute "sudo pip3 install --upgrade scdl"          # https://github.com/flyingrub/scdl (soundcloud downloader)
    execute "sudo pip  install --upgrade rtv"           # https://github.com/michael-lazar/rtv (reddit reader)


    # work deps:
    if [[ "$MODE" == work ]] && ! is_laptop; then  # TODO: do we want to include != laptop?
        # cx toolbox/vagrant env deps:
        execute "sudo gem install \
            puppet puppet-lint bundler nokogiri builder \
        "
    fi

    # laptop deps:
    if is_laptop; then
        # batt output (requires spark):
        clone_or_pull_repo "Goles" "Battery" "$BASE_DEPS_LOC"  # https://github.com/Goles/Battery
        create_link "${BASE_DEPS_LOC}/Battery/battery" "$HOME/bin/battery"
    fi

    unset _install_tmux_deps
}


function setup_dirs() {
    local dir

    # create dirs:
    for dir in \
            $BASE_DATA_DIR/.rsync \
            $BASE_DATA_DIR/tmp \
            $BASE_DATA_DIR/vbox_vms \
            $BASE_DATA_DIR/progs \
            $BASE_DEPS_LOC \
            $BASE_BUILDS_DIR \
            $BASE_DATA_DIR/dev \
            $BASE_DATA_DIR/mail \
            $BASE_DATA_DIR/mail/work \
            $BASE_DATA_DIR/Dropbox \
            $BASE_DATA_DIR/Downloads \
            $BASE_DATA_DIR/Downloads/Transmission \
            $BASE_DATA_DIR/Downloads/Transmission/incomplete \
            $BASE_DATA_DIR/Videos \
            $BASE_DATA_DIR/Music \
            $BASE_DATA_DIR/Documents \
                ; do
        if ! [[ -d "$dir" ]]; then
            report "[$dir] does not exist, creating..."
            execute "mkdir $dir"
        fi
    done

    # create logdir ($CUSTOM_LOGDIR comes from $SHELL_ENVS):
    if ! [[ -d "$CUSTOM_LOGDIR" ]]; then
        [[ -z "$CUSTOM_LOGDIR" ]] && { err "\$CUSTOM_LOGDIR env var was missing. abort."; sleep 5; return 1; }

        report "[$CUSTOM_LOGDIR] does not exist, creating..."
        execute "sudo mkdir -- $CUSTOM_LOGDIR"
        execute "sudo chmod 777 -- $CUSTOM_LOGDIR"
    fi
}


function install_homesick() {

    clone_or_pull_repo "andsens" "homeshick" "$BASE_HOMESICK_REPOS_LOC"

    # add the link, since homeshick is not installed in its default location (which is $HOME):
    create_link "$BASE_DEPS_LOC/homesick" "$HOME/.homesick"
}


# homeshick specifics
function clone_or_link_castle() {
    local castle user hub homesick_exe

    readonly castle="$1"
    readonly user="$2"
    readonly hub="$3"  # domain of the git repo, ie github.com/bitbucket.org...

    readonly homesick_exe="$BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick"

    [[ -z "$castle" || -z "$user" || -z "$hub" ]] && { err "either user, repo or castle name were missing"; sleep 2; return 1; }
    [[ -e "$homesick_exe" ]] || { err "expected to see homesick script @ $homesick_exe, but didn't. skipping cloning castle $castle"; return 1; }

    if [[ -d "$BASE_HOMESICK_REPOS_LOC/$castle" ]]; then
        if is_ssh_key_available; then
            report "[$castle] already exists; pulling & linking"
            execute "$homesick_exe pull $castle"
        else
            report "[$castle] already exists; linking..."
        fi

        execute "$homesick_exe link $castle"
    else
        report "cloning ${castle}..."
        if is_ssh_key_available; then
            execute "$homesick_exe clone git@${hub}:$user/${castle}.git"
        else
            # note we clone via https, not ssh:
            execute "$homesick_exe clone https://${hub}/$user/${castle}.git"

            # change just cloned repo remote from https to ssh:
            execute "pushd $BASE_HOMESICK_REPOS_LOC/$castle" || return 1
            execute "git remote set-url origin git@${hub}:$user/${castle}.git"
            execute "popd"
        fi
    fi

    # just in case verify whether our ssh keys got cloned in:
    if [[ "$IS_SSH_SETUP" -eq 0 ]] && is_ssh_key_available; then
        _sanitize_ssh
        IS_SSH_SETUP=1
    fi
}


function fetch_castles() {
    local castle user hub

    # common public castles:
    clone_or_link_castle dotfiles laur89 github.com

    # common private:
    clone_or_link_castle private-common layr bitbucket.org

    # !! if you change private repos, make sure you update PRIVATE_CASTLE definitions @ validate_and_init()!
    case "$MODE" in
        work)
            clone_or_link_castle "$(basename -- "$PRIVATE_CASTLE")" laliste git.nonprod.williamhill.plc
            ;;
        personal)
            clone_or_link_castle "$(basename -- "$PRIVATE_CASTLE")" layr bitbucket.org
            ;;
    esac

    while true; do
        if confirm "$(report 'want to clone another castle?')"; then
            echo -e "enter git repo domain (eg \"github.com\", \"bitbucket.org\"):"
            read -r hub

            echo -e "enter username:"
            read -r user

            echo -e "enter castle name (repo name, eg \"dotfiles\"):"
            read -r castle

            execute "clone_or_link_castle $castle $user $hub"
        else
            break
        fi
    done
}


# check whether ssh key(s) were pulled with homeshick; if not, offer to create one:
function verify_ssh_key() {

    [[ "$IS_SSH_SETUP" -eq 1 ]] && return 0
    err "expected ssh keys to be there after cloning repo(s), but weren't."

    if confirm "do you wish to generate set of ssh keys?"; then
        generate_key
    else
        return
    fi

    if is_ssh_key_available; then
        IS_SSH_SETUP=1
    else
        err "didn't find the key at $PRIVATE_KEY_LOC after generating keys."
    fi
}


function setup_homesick() {
    local https_castles

    install_homesick
    fetch_castles

    # just in case check if any of the castles are still tracking https instead of ssh:
    readonly https_castles="$($BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick list | grep '\bhttps://\b')"
    if [[ -n "$https_castles" ]]; then
        report "fyi, these homesick castles are for some reason still tracking https remotes:"
        report "$https_castles"
    fi
}


# creates symlink of our personal '.bash_env_vars' to /etc
function setup_global_env_vars() {
    local global_env_var_loc real_file_locations file

    declare -ar real_file_locations=(
        "$SHELL_ENVS"
    )
    readonly global_env_var_loc='/etc'  # so our env vars would have user-agnostic location as well;
                                        # that location will be used by various scripts.

    for file in "${real_file_locations[@]}"; do
        if ! [[ -f "$file" ]]; then
            err "[$file] does not exist. can't link it to ${global_env_var_loc}/"
            return 1
        fi

        create_link --sudo "$file" "${global_env_var_loc}/"
    done

    # don't create; otherwise gobal_env_var will prevent loading env_var_overrides in our .bashrc!
    #if ! [[ -d "$(dirname -- $global_env_var)" ]]; then
        #err "$(dirname -- $global_env_var) is not a dir; can't install globally for all the users."
    #else
        #if ! [[ -h "$global_env_var" ]]; then
            #execute "sudo ln -s -- $SHELL_ENVS $global_env_var"
        #fi
    #fi

    #if sudo test -f $root_bashrc; then
        #if ! sudo grep -q "source $SHELL_ENVS" $root_bashrc; then
            ## hasn't been sourced in $root_bashrc yet:
            #execute "echo source $SHELL_ENVS | sudo tee --append $root_bashrc > /dev/null"
        #fi
    #else
        #err "[$root_bashrc] doesn't exist; cannot source [$SHELL_ENVS] from it!"
        #return 1
    #fi
}


# netrc file has to be accessible only by its owner.
function setup_netrc_perms() {
    local rc_loc perms

    readonly rc_loc="$HOME/.netrc"
    readonly perms=600

    if [[ -e "$rc_loc" ]]; then
        execute "chmod $perms -- $(realpath -- "$rc_loc")" || err "setting [$rc_loc] perms failed"  # realpath, since we cannot change perms via symlink
    else
        err "expected to find [$rc_loc], but it doesn't exist. if you're not using netrc, better remove related logic from ${SELF}."
        return 1
    fi
}


function setup_global_prompt() {
    local global_bashrc ps1

    readonly global_bashrc="/etc/bash.bashrc"
    readonly ps1='PS1="\[\033[0;37m\]\342\224\214\342\224\200\$([[ \$? != 0 ]] && echo \"[\[\033[0;31m\]\342\234\227\[\033[0;37m\]]\342\224\200\")[$(if [[ ${EUID} -eq 0 ]]; then echo "\[\033[0;33m\]\u\[\033[0;37m\]@\[\033\[\033[0;31m\]\h"; else echo "\[\033[0;33m\]\u\[\033[0;37m\]@\[\033[0;96m\]\h"; fi)\[\033[0;37m\]]\342\224\200[\[\033[0;32m\]\w\[\033[0;37m\]]\n\[\033[0;37m\]\342\224\224\342\224\200\342\224\200\342\225\274 \[\033[0m\]"  # own_def_marker'

    if ! sudo test -f $global_bashrc; then
        err "[$global_bashrc] doesn't exist; cannot add PS1 (prompt) definition to it!"
        return 1
    fi

    # just in case delete previous global PS1 def:
    execute "sudo sed -i '/^PS1=.*# own_def_marker$/d' \"$global_bashrc\""
    execute "echo '$ps1' | sudo tee --append $global_bashrc > /dev/null"

    #if ! sudo grep -q '^PS1=.*# own_def_marker$' $global_bashrc; then
        ## PS1 hasn't been defined yet:
        #execute "echo '$ps1' | sudo tee --append $global_bashrc > /dev/null"
    #fi
}


# setup system config files (the ones not living under $HOME, ie not managed by homesick)
# has to be invoked AFTER homeschick castles are cloned/pulled!
#
# note that this block overlaps logically a bit with post_install_progs_setup()
function setup_config_files() {

    setup_apt
    setup_crontab
    setup_sudoers
    #setup_ssh_config   # better stick to ~/.ssh/config, rite?  # TODO
    setup_hosts
    setup_global_env_vars
    setup_netrc_perms
    setup_global_prompt
    swap_caps_lock_and_esc
}


function install_acpi_events() {
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
# runs other script that writes info to /tmp and manages locking logic for laptops (security, kinda)
function install_SSID_checker() {
    local nm_wrapper_loc  nm_wrapper_dest

    readonly nm_wrapper_loc="$BASE_DATA_DIR/dev/scripts/network_manager_SSID_checker_wrapper.sh"
    readonly nm_wrapper_dest="/etc/NetworkManager/dispatcher.d"

    if ! [[ -f "$nm_wrapper_loc" ]]; then
        err "[$nm_wrapper_loc] does not exist; SSID checker won't be installed"
        return 1
    elif ! [[ -d "$nm_wrapper_dest" ]]; then
        err "[$nm_wrapper_dest] dir does not exist; SSID checker won't be installed"
        return 1
    fi

    # do not create .orig backup!
    execute "sudo cp -- $nm_wrapper_loc $nm_wrapper_dest/"
    return $?
}


function setup() {

    setup_homesick
    verify_ssh_key
    execute "source $SHELL_ENVS"  # so we get our env vars after dotfiles are pulled in

    setup_dirs  # has to come after $SHELL_ENVS sourcing so the env vars are in place
    setup_config_files
    setup_additional_apt_keys_and_sources
    [[ "$FULL_INSTALL" -ne 1 ]] && post_install_progs_setup  # since with FULL_INSTALL=1, it'll get executed from other block
}


function setup_additional_apt_keys_and_sources() {

    # mopidy:
    # mopidy key: (from https://docs.mopidy.com/en/latest/installation/debian/):
    execute 'wget -q -O - http://apt.mopidy.com/mopidy.gpg | sudo apt-key add -'
    # add mopidy source:
    execute 'sudo wget -q -O /etc/apt/sources.list.d/mopidy.list https://apt.mopidy.com/jessie.list'


    # spotify: (from https://www.spotify.com/es/download/linux/):
    execute 'sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys BBEBDCB318AD50EC6865090613B00F1FD2C19886'
    execute 'echo deb http://repository.spotify.com stable non-free | sudo tee /etc/apt/sources.list.d/spotify.list > /dev/null'


    # update sources (will be done anyway on full install):
    [[ "$FULL_INSTALL" -ne 1 ]] && execute 'sudo apt-get --yes update'
}


# can also exec 'setxkbmap -option' caps:escape or use dconf-editor;
# or switch it via XKB options (see https://wiki.archlinux.org/index.php/Keyboard_configuration_in_Xorg)
#
# to see current active keyboard setting:    setxkbmap -print -verbose 10
function swap_caps_lock_and_esc() {
    local conf_file

    readonly conf_file="/usr/share/X11/xkb/symbols/pc"

    [[ -f "$conf_file" ]] || { err "cannot swap esc<->caps: [$conf_file] does not exist; abort;"; return 1; }

    # map caps to esc:
    if ! grep -q 'key <ESC>.*Caps_Lock' "$conf_file"; then
        # hasn't been replaced yet
        execute "sudo sed -i 's/.*key.*ESC.*Escape.*/    key <ESC>  \{    \[ Caps_Lock        \]   \};/g' $conf_file"
        [[ $? -ne 0 ]] && { err "replacing esc<->caps @ [$conf_file] failed"; return 2; }
    fi

    # map esc to caps:
    if ! grep -q 'key <CAPS>.*Escape' "$conf_file"; then
        # hasn't been replaced yet
        execute "sudo sed -i 's/.*key.*CAPS.*Caps_Lock.*/    key <CAPS> \{    \[ Escape     \]   \};/g' $conf_file"
        [[ $? -ne 0 ]] && { err "replacing esc<->caps @ [$conf_file] failed"; return 2; }
    fi

    return 0
}


function install_altiris() {
    local rpm_loc altiris_loc

    rpm_loc="/usr/bin/rpm"
    # alt_loc from   https://williamhill.jira.com/wiki/display/TRAD/Developer+Machines :
    altiris_loc='https://williamhill.jira.com/wiki/download/attachments/21528849/altiris_install.sh'

    [[ "$MODE" != work ]] && { err "won't install it in $MODE mode; only in work mode."; return 1; }

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
            -O $TMPDIR/altiris_install.sh \
            -- $altiris_loc \
    " || { err "couldn't find altiris script; read wiki."; return 1; }

    execute "chmod +x -- $TMPDIR/altiris_install.sh"
    execute "sudo $TMPDIR/altiris_install.sh" || {
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


function install_symantec_endpoint_security() {
    local sep_loc jce_loc tmpdir tarball dir jars

    sep_loc='https://williamhillorg-my.sharepoint.com/personal/leighhall_williamhill_co_uk/_layouts/15/guestaccess.aspx?guestaccesstoken=B5plVjedQluwT7BgUH50bG3rs99cJaCg6lckbkGdS6I%3d&docid=2_15a1ca98041134ad8b2e4d93286806892'
    jce_loc='http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip'

    [[ "$MODE" != work ]] && { err "won't install it in [$MODE] mode; only in work mode."; return 1; }
    [[ -d "$JDK_LINK_LOC" ]] || { err "expected [$JDK_LINK_LOC] to link to existing jdk installation."; return 1; }

    tmpdir="$(mktemp -d "symantec-endpoint-sec-tempdir-XXXXX" -p $TMPDIR)" || { err "unable to create tempdir with \$ mktemp"; return 1; }
    execute "pushd $tmpdir" || return 1

    # fetch & install SEP:
    execute "wget -- $sep_loc" || return 1
    tarball="$(ls)"
    extract "$tarball" || { err "extracting [$tarball] failed."; return 1; }
    dir="$(find -mindepth 1 -maxdepth 1 -type d)"
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
    dir="$(find -mindepth 1 -maxdepth 1 -type d)"
    [[ -d "$dir" ]] || { err "couldn't find unpacked jce directory"; return 1; }
    jars="$(find "$dir" -mindepth 1 -type f -name '*.jar')" || { err "looks like we didn't find any .jar files under [$dir]"; return 1; }
    execute "sudo cp $jars $JDK_LINK_LOC/jre/lib/security" || return 1

    # cleanup:
    execute "popd"
    execute "sudo rm -rf -- $tmpdir"
}


function install_laptop_deps() {
    local wifi_info

    is_laptop || return

    # xinput is for configuration; see  https://wiki.archlinux.org/index.php/Libinput
    install_block '
        libinput-tools
        xinput
        blueman
        xfce4-power-manager
    '

    # consider using   lspci -vnn | grep -A5 WLAN | grep -qi intel
    readonly wifi_info="$(sudo lshw | grep -iA 5 'Wireless interface')"

    if echo "$wifi_info" | grep -iq 'vendor.*Intel'; then
        report "we have intel wifi; installing intel drivers..."
        install_block "firmware-iwlwifi"
    elif echo "$wifi_info" | grep -iq 'vendor.*Realtek' && \
            confirm "we seem to have realtek wifi; want to install firmware-realtek?"; then
        report "we have realtek wifi; installing realtek drivers..."
        install_block "firmware-realtek"
    fi
}


function install_progs() {

    execute "sudo apt-get --yes update"

    #confirm "do you want to install our webdev lot?" && install_webdev
    install_webdev
    install_npm_modules

    install_from_repo
    install_laptop_deps
    install_own_builds

    install_oracle_jdk
    #install_skype
    install_nvidia

    # TODO; delete?:
    #if [[ "$MODE" == work ]]; then
        #install_altiris
        #install_symantec_endpoint_security
    #fi
}


# system deps, which depend on npm & nodejs
# TODO: kind of depends in install_deps()?
function install_npm_modules() {

    if ! command -v nodejs >/dev/null || ! command -v npm >/dev/null; then
        report "need to install npm & nodejs first..."
        install_block '
            nodejs
            npm
        ' || { err "err installing npm and/or nodejs"; return 1; }
    fi

    # first thing update npm:
    execute "sudo npm install npm -g" && sleep 0.5

    # https://github.com/FredrikNoren/ungit
    # https://github.com/dominictarr/JSON.sh
    #
    # (note the required -H for ungit)
    execute "sudo -H npm install -g \
        ungit \
        JSON.sh \
    "
}


# to force ver: apt-get install linux-image-amd64:version
# check avail vers: apt-cache showpkg linux-image-amd64
function upgrade_kernel() {
    local package_line kernels_list amd64_arch

    declare -a kernels_list=()
    is_64_bit && readonly amd64_arch="amd64"

    # install kernel meta-packages:
    # NOTE: these meta-packages only required, if using non-stable debian;
    # they keep the kernel and headers in sync:
    if is_64_bit; then
        report "first installing kernel meta-packages..."
        install_block '
            linux-image-amd64
            linux-headers-amd64
        '
    else
        report "verified we're not running 64bit system. make sure it's correct. skipping kernel meta-package installation."
        sleep 5
    fi

    # search for available kernel images:
    while IFS= read -r package_line; do
        kernels_list+=( $(echo "$package_line" | cut -d' ' -f1) )
    done <   <(apt-cache search  --names-only "^linux-image-[0-9+]\.[0-9+]\.[0-9+].*$amd64_arch\$" | sort -n)

    [[ -z "${kernels_list[@]}" ]] && { err "apt-cache search didn't find any kernel images. skipping kernel upgrade"; sleep 5; return 1; }

    while true; do
        echo
        report "current kernel: $(uname -r)"
        report "select kernel to install: (select none to skip kernel upgrade)\n"
        select_items "${kernels_list[*]}" 1

        if [[ -n "$__SELECTED_ITEMS" ]]; then
            report "installing ${__SELECTED_ITEMS}..."
            execute "sudo apt-get --yes install $__SELECTED_ITEMS"
            break
        else
            confirm "no items were selected; skip kernel upgrade?" && break
        fi
    done

    unset __SELECTED_ITEMS
}


# 'own build' as in everything from not the debian repository; either build from
# source, or fetch from the interwebs and install/configure manually.
function install_own_builds() {

    install_vim
    install_neovim
    install_keepassx
    install_goforit
    install_copyq
    install_synergy
    install_dwm
}


# note that jdk will be installed under $JDK_INSTALLATION_DIR
function install_oracle_jdk() {
    local tarball tmpdir dir

    readonly tmpdir="$(mktemp -d "jdk-tempdir-XXXXX" -p $TMPDIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }

    report "fetcing [$ORACLE_JDK_LOC]"
    execute "pushd -- $tmpdir" || return 1

    execute "wget --no-check-certificate \
        --no-cookies \
        --header 'Cookie: oraclelicense=accept-securebackup-cookie' \
        -- '$ORACLE_JDK_LOC'" || { err "wgetting [$ORACLE_JDK_LOC] failed."; return 1; }

    readonly tarball="$(basename -- "$ORACLE_JDK_LOC")"
    extract "$tarball" || { err "extracting [$tarball] failed."; return 1; }
    dir="$(find -mindepth 1 -maxdepth 1 -type d)"
    [[ -d "$dir" ]] || { err "couldn't find unpacked jdk directory"; return 1; }

    [[ -d "$JDK_INSTALLATION_DIR" ]] || execute "sudo mkdir -- $JDK_INSTALLATION_DIR"
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


function switch_jdk_versions() {
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


function install_synergy() {
    local re_clone

    is_server && { report "we're server, skipping synergy installation."; return; }
    should_build_if_avail_in_repo synergy || { report "skipping building of synergy remember to install it from the repo after the install!"; return; }

    report "setting up synergy"

    # find whether there already is a synergy build dir present:
    if [[ -d "$BASE_BUILDS_DIR/synergy" ]]; then
        if confirm "$BASE_BUILDS_DIR/synergy dir already exists. use that one? (answering 'no' will re-clone repo)"; then
            re_clone=0
        fi
    fi

    build_and_install_synergy $re_clone
    return $?
}


function install_copyq() {
    is_server && { report "we're server, skipping copyq installation."; return; }

    report "setting up copyq"

    # first find whether we have deb packages from other times:
    if confirm "do you wish to install copyq from our previous build .deb package, if available?"; then
        install_from_deb copyq && return 0
    fi

    build_and_install_copyq
    return $?
}


function install_skype() {  # https://wiki.debian.org/skype
    local skypeFile skype_downloads_dir

    is_server && { report "we're server, skipping skype installation."; return; }
    readonly skypeFile="$TMPDIR/skype-install.deb"
    readonly skype_downloads_dir="$BASE_DATA_DIR/Downloads/skype_dl"

    report "setting up skype"

    #if confirm "do you wish to install skype from our local .deb package, if available?"; then
        #install_from_deb skype && return 0
    #fi

    if is_64_bit; then
        execute "sudo dpkg --add-architecture i386"
        execute "sudo apt-get --yes update"
        execute "sudo apt-get -f --yes install"
    fi

    execute "wget -O $skypeFile -- $SKYPE_LOC" || { err; return 1; }
    execute "sudo dpkg -i $skypeFile"  #|| { err; return 1; }  # do not exit on err!
    execute "sudo apt-get -f --yes install" || { err; return 1; }

    # store the .deb, just in case:
    execute "mv $skypeFile $BASE_BUILDS_DIR"

    # create target dir for skype file transfers;
    # ! needs to be configured in skype!
    [[ -d "$skype_downloads_dir" ]] || execute "mkdir '$skype_downloads_dir'"
}


function install_webdev() {
    is_server && { report "we're server, skipping webdev env installation."; return; }

    install_block '
        ruby
        nodejs
        npm
    ' || { err "first install_block failed" "$FUNCNAME"; return 1; }

    # create link for node (there's a different package called 'node' for debian,
    # that's why the 'node' executable is very likely to be missing from the $PATH:
    if ! command -v node >/dev/null; then
        command -v nodejs >/dev/null || { err "nodejs is not on \$PATH; can't create 'node' link to it. fix it."; }
        create_link --sudo "$(which nodejs)" "/usr/bin/node"
    fi

    # first thing update npm:
    execute "sudo npm install npm -g" && sleep 0.5

    # install npm modules:
    execute "sudo npm install -g \
        jshint grunt-cli csslint \
    "

    # install ruby modules:          # sass: http://sass-lang.com/install
    execute "sudo gem install \
        sass \
    "

    # ruby (rbenv):
    ##################################
    install_block '
        ruby-build
        rbenv
    '

    # ruby-build recommended deps (https://github.com/rbenv/ruby-build/wiki):
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
        libgdbm3
        libgdbm-dev
    '

    # this would install it globally; better install new local ver by
    # rbenv install <ver> && rbenv global <ver> && gem install rails
    #execute 'sudo gem install rails'
}


function install_keepassx() {
    is_server && { report "we're server, skipping keepassx installation."; return; }

    report "setting up keepassx..."

    # first find whether we have deb packages from other times:
    if confirm "do you wish to install keepassx from our previous build .deb package, if available?"; then
        install_from_deb keepassx && return 0
    fi

    build_and_install_keepassx
    return $?
}


# TO-DO list manager
# https://github.com/mank319/Go-For-It
function install_goforit() {
    is_server && { report "we're server, skipping goforit installation."; return; }
    should_build_if_avail_in_repo go-for-it || { report "skipping building of go-for-it; remember to install it from the repo after the install!"; return; }

    report "setting up goforit..."

    # first find whether we have deb packages from other times:
    if confirm "do you wish to install goforit from our previous build .deb package, if available?"; then
        install_from_deb goforit && return 0
    fi

    build_and_install_goforit
    return $?
}


# building instructions from https://github.com/synergy/synergy/wiki/Compiling
function build_and_install_synergy() {
    local builddir do_clone

    readonly do_clone="$1"  # set to '0' if synergy repo should NOT be re-cloned

    readonly builddir="$BASE_BUILDS_DIR/synergy"
    report "building synergy"

    report "installing synergy build dependencies..."
    install_block '
        build-essential
        cmake
        libavahi-compat-libdnssd-dev
        libcurl4-openssl-dev
        libssl-dev
        python
        qt4-dev-tools
        xorg-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }

    if [[ "$do_clone" -ne 0 ]]; then
        [[ -d "$builddir" ]] && execute "sudo rm -rf -- $builddir"
        execute "git clone $SYNERGY_REPO_LOC $builddir" || return 1
    fi

    execute "pushd $builddir" || return 1
    [[ "$do_clone" -eq 0 ]] && is_ssh_key_available && execute "git pull"

    execute "./hm.sh conf -g1"
    execute "./hm.sh build"

    # note builddir should not be deleted
    execute "popd"
    return 0
}


# building instructions from https://github.com/hluk/CopyQ/blob/master/INSTALL
function build_and_install_copyq() {
    local tmpdir

    readonly tmpdir="$TMPDIR/copyq-build-${RANDOM}"

    should_build_if_avail_in_repo copyq || { report "skipping building of copyq remember to install it from the repo after the install!"; return; }
    report "building copyq"

    report "installing copyq build dependencies..."
    install_block '
        libqt4-dev
        cmake
        libxfixes-dev
        libxtst-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }

    execute "git clone $COPYQ_REPO_LOC $tmpdir" || return 1
    execute "pushd $tmpdir" || return 1

    execute 'cmake .' || { err; popd; return 1; }
    execute "make" || { err; popd; return 1; }

    create_deb_install_and_store

    execute "popd"
    execute "sudo rm -rf -- $tmpdir"
    return 0
}


# runs checkinstall in current working dir, and copies the created
# .deb file to $BASE_BUILDS_DIR/
function create_deb_install_and_store() {
    local deb_file

    check_progs_installed checkinstall || return 1
    report "creating .deb and installing with checkinstall..."
    execute "sudo checkinstall" || { err "checkinstall run failed. abort."; return 1; }

    readonly deb_file="$(find . -type f -name '*.deb')"
    if [[ -f "$deb_file" ]]; then
        report "moving built package [$deb_file] to [$BASE_BUILDS_DIR]"
        execute "mv -- $deb_file $BASE_BUILDS_DIR/"
        return $?
    else
        err "couldn't find built package (find cmd found [$deb_file])"
        return 1
    fi
}


# building instructions from https://github.com/mank319/Go-For-It
function build_and_install_goforit() {
    local tmpdir

    should_build_if_avail_in_repo goforit || { report "skipping building of goforit. remember to install it from the repo after the install!"; return; }

    readonly tmpdir="$TMPDIR/goforit-build-${RANDOM}"
    report "building goforit..."

    execute "git clone $GOFORIT_REPO_LOC $tmpdir" || return 1

    execute "mkdir $tmpdir/build"
    execute "pushd $tmpdir/build" || return 1
    execute 'cmake ..' || { err; popd; return 1; }
    execute "make" || { err; popd; return 1; }

    create_deb_install_and_store

    execute "popd"
    execute "sudo rm -rf -- '$tmpdir'"
    return 0
}


# building instructions from https://github.com/keepassx/keepassx & www.keepass.org/dev/projects/keepasx/wiki/Install_instructions
function build_and_install_keepassx() {
    local tmpdir

    should_build_if_avail_in_repo keepassx || { report "skipping building of keepassx. remember to install it from the repo after the install!"; return; }

    readonly tmpdir="$TMPDIR/keepassx-build-${RANDOM}"
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
    ' || { err 'failed to install build deps. abort.'; return 1; }

    execute "git clone $KEEPASS_REPO_LOC $tmpdir" || return 1

    execute "mkdir $tmpdir/build"
    execute "pushd $tmpdir/build" || return 1
    execute 'cmake ..' || { err; popd; return 1; }
    execute "make" || { err; popd; return 1; }

    create_deb_install_and_store

    execute "popd"
    execute "sudo rm -rf -- '$tmpdir'"
    return 0
}


function install_dwm() {
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


# searches .deb packages with provided name in its filename from
# $BASE_BUILDS_DIR and installs it.
function install_from_deb() {
    local deb_file count name

    readonly name="$1"

    deb_file="$(find $BASE_BUILDS_DIR -type f -iname "*$name*.deb")"
    [[ "$?" -eq 0 && -n "$deb_file" ]] || { report "didn't find any pre-build deb packages for $name; trying to build..."; return 1; }
    readonly count="$(echo "$deb_file" | wc -l)"

    if [[ "$count" -gt 1 ]]; then
        report "found $count potential deb packages. select one, or select none to build instead:"

        while true; do
            select_items "$deb_file" 1

            if [[ -n "$__SELECTED_ITEMS" ]]; then
                deb_file="$__SELECTED_ITEMS"
                break
            else
                confirm "no files selected; skip installing from .deb and build $name instead?" && { report "ok, won't install $name from .deb"; return 1; }
            fi
        done
    fi

    report "installing ${deb_file}..."
    execute "sudo dpkg -i $deb_file"
    return $?
}

#https://github.com/neovim/neovim/wiki/Building-Neovim
function install_neovim() {
    local tmpdir nvim_confdir

    readonly tmpdir="$TMPDIR/nvim-build-${RANDOM}"
    readonly nvim_confdir="$HOME/.config/nvim"

    report "setting up nvim..."

    # first find whether we have deb packages from other times:
    if confirm "do you wish to install nvim from our previous build .deb package, if available?"; then
        install_from_deb neovim || return 1
    else
        report "building neovim..."

        report "installing neovim build dependencies..."  # https://github.com/neovim/neovim/wiki/Building-Neovim#build-prerequisites
        install_block '
            libtool
            libtool-bin
            autoconf
            automake
            cmake
            g\+\+
            pkg-config
            unzip
        ' || { err 'failed to install neovim build deps. abort.'; return 1; }

        execute "git clone $NVIM_REPO_LOC $tmpdir" || return 1
        execute "pushd $tmpdir" || { err; return 1; }

        # TODO: checkinstall fails with neovim (bug in checkinstall afaik):
        #execute "make" || { err; return 1; }
        #create_deb_install_and_store || { err; return 1; }
        execute "sudo make install" || { err; return 1; }  # TODO  remove this once checkinstall issue is resolved;

        execute "popd"
        execute "sudo rm -rf -- $tmpdir"
    fi

    # post-install config:

    # create links (as per https://neovim.io/doc/user/nvim_from_vim.html):
    create_link "$HOME/.vim" "$nvim_confdir"
    create_link "$HOME/.vimrc" "$nvim_confdir/init.vim"

    # as per https://neovim.io/doc/user/nvim_python.html#nvim-python :
    execute " sudo pip2 install --upgrade neovim"
    execute " sudo pip3 install --upgrade neovim"

    return 0
}


function install_vim() {

    report "setting up vim..."
    report "removing already installed vim components..."
    execute "sudo apt-get --yes remove vim vim-runtime gvim vim-tiny vim-common vim-gui-common"

    # first find whether we have deb packages from other times:
    if confirm "do you wish to install vim from our previous build .deb package, if available?"; then
        install_from_deb vim || build_and_install_vim || return 1
    else
        build_and_install_vim || return 1
    fi

    vim_post_install_configuration

    report "launching vim, so the initialization could be done (pulling in plugins et al. simply exit vim when it's done.)"
    echo 'initialising vim; simply exit when plugin fetching is complete. (quit with  :qa!)' | \
        vim -  # needs to be non-root

    # YCM installation AFTER the first vim launch!
    install_YCM
    install_vim_plugin_deps
}


function install_vim_plugin_deps() {
    local vim_pluginsdir

    readonly vim_pluginsdir="$HOME/.vim/bundle"

    function _install_tern_for_vim_deps() {
        local plugindir
        readonly plugindir="$vim_pluginsdir/tern_for_vim"

        if ! command -v npm >/dev/null; then
            install_block 'npm' || return 1
        fi

        [[ -d "$plugindir" ]] || { err "$plugindir is not a dir."; return 1; }
        execute "pushd $plugindir" || return 1
        execute "npm install"
        execute "popd"
    }

    # install plugin deps:
    # tern: https://github.com/ternjs/tern_for_vim
    _install_tern_for_vim_deps

    unset _install_tern_for_vim_deps
}


function vim_post_install_configuration() {
    local stored_vim_sessions vim_sessiondir i

    readonly stored_vim_sessions="$BASE_DATA_DIR/.vim_sessions"
    readonly vim_sessiondir="$HOME/.vim/sessions"

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

    # link sessions dir, if stored @ $BASE_DATA_DIR: (related to the 'xolox/vim-session' plugin)
    # note we don't want sessions in homesick, as they're likely to be machine-dependent.
    if [[ -d "$stored_vim_sessions" ]]; then
        if ! [[ -h "$vim_sessiondir" ]]; then
            [[ -d "$vim_sessiondir" ]] && execute "sudo rm -rf -- $vim_sessiondir"
            create_link "$stored_vim_sessions" "$vim_sessiondir"
        fi
    else  # $stored_vim_sessions does not exist; init it anyways
        if [[ -d "$vim_sessiondir" ]]; then
            execute "mv $vim_sessiondir $stored_vim_sessions"
        else
            execute "mkdir $stored_vim_sessions"
        fi

        create_link "$stored_vim_sessions" "$vim_sessiondir"
    fi
}


# building instructions from https://github.com/Valloric/YouCompleteMe/wiki/Building-Vim-from-source
function build_and_install_vim() {
    local tmpdir

    readonly tmpdir="$TMPDIR/vim-build-${RANDOM}"
    report "building vim..."

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
        ruby-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }

    execute "git clone $VIM_REPO_LOC $tmpdir" || return 1
    execute "pushd $tmpdir" || return 1

    execute "./configure \
            --with-features=huge \
            --enable-multibyte \
            --enable-rubyinterp \
            --enable-pythoninterp \
            --with-python-config-dir=/usr/lib/python2.7/config \
            --enable-perlinterp \
            --enable-luainterp \
            --enable-gui=gtk2 \
            --enable-cscope \
            --prefix=/usr \
    " || { err 'vim configure build phase failed.'; return 1; }

    execute "make VIMRUNTIMEDIR=/usr/share/vim/vim74" || { err 'vim make failed'; return 1; }
    #!(make sure rutimedir is correct; at this moment 74 was)
    create_deb_install_and_store || { err; return 1; }

    execute "popd"
    execute "sudo rm -rf -- $tmpdir"

    return 0
}


# note: instructions & info here: https://github.com/Valloric/YouCompleteMe
# note2: available in deb repo as 'ycmd'
function install_YCM() {
    local ycm_root  ycm_build_root  libclang_root  ycm_third_party_rootdir

    readonly ycm_root="$BASE_BUILDS_DIR/YCM"
    readonly ycm_build_root="$ycm_root/ycm_build"
    readonly libclang_root="$ycm_root/llvm"
    readonly ycm_third_party_rootdir="$HOME/.vim/bundle/YouCompleteMe/third_party/ycmd/third_party"

    function __fetch_libclang() {
        local tmpdir tarball dir

        readonly tmpdir="$(mktemp -d "ycm-tempdir-XXXXX" -p $TMPDIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }
        readonly tarball="$(basename -- "$CLANG_LLVM_LOC")"

        execute "pushd -- $tmpdir" || return 1
        report "fetching [$CLANG_LLVM_LOC]"
        execute "wget '$CLANG_LLVM_LOC'" || { err "wgetting [$CLANG_LLVM_LOC] failed."; return 1; }
        extract "$tarball" || { err "extracting [$tarball] failed."; return 1; }
        dir="$(find -mindepth 1 -maxdepth 1 -type d)"
        [[ -d "$dir" ]] || { err "couldn't find unpacked clang directory"; return 1; }
        [[ -d "$libclang_root" ]] && execute "sudo rm -rf -- '$libclang_root'"
        execute "mv -- '$dir' '$libclang_root'"

        execute "popd"
        execute "sudo rm -rf -- '$tmpdir'"

        return 0
    }

    # sanity
    if ! [[ -d "$HOME/.vim/bundle/YouCompleteMe" ]]; then
        err "expected vim plugin YouCompleteMe to be already pulled"
        err "you're either missing vimrc conf or haven't started vim yet (first start pulls all the plugins)."
        err
        return 1
    fi

    [[ -d "$ycm_root" ]] || execute "mkdir -- '$ycm_root'"

    # first make sure we have libclang:
    if [[ -d "$libclang_root" ]]; then
        if ! confirm "found existing libclang at [$libclang_root]; use this one? (answering 'no' will fetch new version)"; then
            __fetch_libclang || { err "fetching libclang failed; aborting YCM installation."; return 1; }
        fi
    else
        __fetch_libclang || { err "fetching libclang failed; aborting YCM installation."; return 1; }
    fi

    # clean previous builddir, if existing:
    [[ -d "$ycm_build_root" ]] && execute "sudo rm -rf -- '$ycm_build_root'"

    # build:
    execute "mkdir -- '$ycm_build_root'"
    execute "pushd -- '$ycm_build_root'" || return 1
    execute "cmake -G 'Unix Makefiles' \
        -DPATH_TO_LLVM_ROOT=$libclang_root \
        . \
        ~/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp \
    "
    execute 'cmake --build . --target ycm_core --config Release'
    execute "popd"

    ############
    # set up support for additional languages:
    # C#:
    execute "pushd $ycm_third_party_rootdir/OmniSharpServer" || return 1
    execute "xbuild"
    execute "popd"

    # js:
    execute "pushd $ycm_third_party_rootdir/tern_runtime" || return 1
    execute "npm install --production"
    execute "popd"


    unset __fetch_libclang  # to keep the inner function really an inner one (ie private).
}


function install_fonts() {
    local dir

    report "installing fonts..."

    install_block '
        ttf-dejavu
        ttf-liberation
        ttf-mscorefonts-installer
        xfonts-terminus
        xfonts-75dpi
        xfonts-75dpi-transcoded
        xfonts-100dpi
        xfonts-100dpi-transcoded
        xfonts-mplus
        xfonts-bitmap-mule
        xfonts-base
        fontforge
    '

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


# majority of packages get installed at this point; including drivers, if any.
function install_from_repo() {
    local block block1 block2 block3 block4 extra_apt_params

    declare -A extra_apt_params
    extra_apt_params=(
       [block2]="--no-install-recommends"
    )

    declare -ar block1=(
        xorg
        sudo
        alsa-base
        alsa-utils
        xfce4-volumed
        xfce4-notifyd
        xscreensaver
        smartmontools
        gksu
        pm-utils
        ntfs-3g
        fuseiso
        dosfstools
        checkinstall
        build-essential
        cmake
        python3
        python3-dev
        python3-pip
        python-dev
        python-pip
        python-flake8
        python3-flake8
        devscripts
        curl
        lshw
        acpid
        lm-sensors
        psensor
        xsensors
        hardinfo
        macchanger
        ufw
    )

    declare -ar block2=(
        jq
        dnsutils
        glances
        htop
        ntop
        wireshark
        iptraf
        tkremind
        remind
        tree
        flashplugin-nonfree
        ntp
        gdebi
        synaptic
        apt-show-versions
        apt-xapian-index
        mercurial
        git
        git-flow
        git-cola
        zenity
        msmtp
        rsync
        gparted
        network-manager
        network-manager-gnome
        gnome-keyring
        gsimplecal
        gnome-disk-utility
        cups
        system-config-printer
        galculator
        file-roller
        rar
        unrar
        p7zip
        dos2unix
        qt4-qtconfig
        lxappearance
        gtk2-engines-murrine
        gtk2-engines-pixbuf
        meld
        gthumb
        pastebinit
    )


    # fyi:
        #- [gnome-keyring???-installi vaid siis, kui mingi jama]
        #- !! gksu no moar recommended; pkexec advised; to use pkexec, you need to define its
        #     action in /usr/share/polkit-1/actions.

    declare -ar block3=(
        iceweasel
        chromium
        icedove
        rxvt-unicode-256color
        guake
        mopidy
        mopidy-soundcloud
        mopidy-spotify
        mopidy-youtube
        youtube-dl
        mpc
        ncmpcpp
        ncmpc
        audacity
        geany
        libreoffice
        calibre
        zathura
        mplayer2
        gimp
        feh
        sxiv
        geeqie
        imagemagick
        pinta
        xsel
        xclip
        exuberant-ctags
        shellcheck
        ranger
        spacefm-gtk3
        screenfetch
        scrot
        ffmpeg
        vokoscreen
        screenkey
        mediainfo
        lynx
        tmux
        powerline
        libxml2-utils
        pidgin
        filezilla
        etckeeper
        gradle
        lxrandr
        transmission
        transmission-remote-cli
        transmission-remote-gtk
    )

    declare -ar block4=(
        mutt-patched
        notmuch-mutt
        notmuch
        abook
        isync
        atool
        highlight
        urlview
        silversearcher-ag
        cowsay
        toilet
        lolcat
        figlet
    )

    for block in \
            block1 \
            block2 \
            block3 \
            block4 \
                ; do
        # update apt-get before each main block; had issues with first one returning code 100:
        execute "sudo apt-get --yes update"
        install_block "$(eval echo "\${$block[@]}")" "${extra_apt_params[$block]}"
        if [[ "$?" -ne 0 && "$?" -ne "$SOME_PACKAGE_IGNORED_EXIT_CODE" ]]; then
            err "one of the main-block installation failed. these are the packages that have failed to install so far:"
            echo -e "[${PACKAGES_FAILED_TO_INSTALL[*]}]"
            confirm "continue with setup? answering no will exit script" || exit 1
        fi
    done


    if [[ "$MODE" == work ]]; then
        install_block '
            samba-common-bin
            smbclient
            ruby-dev
            vagrant

            virtualbox
            virtualbox-dkms

            puppet
            docker.io
            nfs-common
            nfs-kernel-server
        '

        # note that both nfs-common & nfs-kernel-server at this point are required
        # for the work's vagrant setup.
    fi

    if confirm "wish to install ${COLORS[YELLOW]}${COLORS[BOLD]}pulseaudio${COLORS[OFF]}?"; then

        # configure pulseaudio/equalizer
        #
        # see https://wiki.debian.org/PulseAudio#Dynamically_enable.2Fdisable
        # to dynamically enable/disable pulseaudio;
        function configure_pulseaudio() {
            local conf conf_lines i

            readonly conf='/etc/pulse/default.pa'
            declare -ar conf_lines=('load-module module-equalizer-sink'
                                    'load-module module-dbus-protocol'
                                   )

            [[ -f "$conf" ]] || { err "[$conf] is not a valid file."; return 1; }

            for i in "${conf_lines[@]}"; do
                if ! grep -q "^$i\$" "$conf"; then
                    report "adding [$i] to $conf"
                    execute "echo $i | sudo tee --append $conf > /dev/null"
                fi
            done
        }

        # pasystray for easier config access; to meant to be ran continuously.
        install_block '
            pulseaudio
            pulseaudio-equalizer
            pasystray
        '
        configure_pulseaudio
    fi
}


# offers to install nvidia drivers, if NVIDIA card is detected.
#
# in order to reinstall the dkms part, purge both nvidia-driver &
# nvidia-xconfig, and then reinstall.
function install_nvidia() {
    # https://wiki.debian.org/NvidiaGraphicsDrivers

    # TODO: consider  lspci -vnn | grep VGA | grep -i nvidia
    if sudo lshw | grep -iA 5 'display' | grep -iq 'vendor.*NVIDIA'; then
        if confirm "we seem to have NVIDIA card; want to install nvidia drivers?"; then
            report "installing NVIDIA drivers..."
            install_block 'nvidia-driver  nvidia-xconfig'
            execute "sudo nvidia-xconfig"
            return $?
        fi
    else
        report "we don't have a nvidia card; skipping installing their drivers..."
    fi
}


# provides the possibility to cherry-pick out packages.
# this might come in handy, if few of the packages cannot be found/installed.
function install_block() {
    local list_to_install extra_apt_params dry_run_failed exit_sig exit_sig_install_failed pkg

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
        if execute "sudo apt-get -qq --dry-run install $extra_apt_params $pkg"; then
            sleep 0.1
            execute "sudo apt-get --yes install $extra_apt_params $pkg" || { exit_sig_install_failed=$?; PACKAGES_FAILED_TO_INSTALL+=("$pkg"); }
        else
            dry_run_failed+=( $pkg )
        fi
    done

    if [[ -n "${dry_run_failed[*]}" ]]; then
        err "either these packages could not be found from the repo, or some other issue occurred; skipping installing these packages. this will be logged:"
        err "${dry_run_failed[*]}"

        PACKAGES_IGNORED_TO_INSTALL+=( ${dry_run_failed[*]} )
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


# returns false, if there's an available package with given value in its name, and
# user opts not to build the package, but later install it from the repo by himself.
function should_build_if_avail_in_repo() {
    local package_name packages

    readonly package_name="$1"

    readonly packages="$(apt-cache search --names-only "$package_name")" || { err; return 1; }
    if [[ -n "$packages" ]]; then
        report "FYI, these packages with [$package_name] in them are available in repo:\n"
        echo -e "$packages"

        if ! confirm "\tdo you still wish to build yourself?\n\t(answering 'no' will skip the build. you need to manually install it from the repo yourself.)"; then
            # TODO: store and log!
            return 1
        fi
    fi

    return 0
}


function choose_step() {
    report "what do you want to do?"

    select_items "full-install single-task" 1

    case "$__SELECTED_ITEMS" in
        "full-install" ) full_install ;;
        "single-task"  ) choose_single_task ;;
        "") exit 0 ;;
        *) err "unsupported choice [$__SELECTED_ITEMS]"
           exit 1
           ;;
    esac
}


# basically offers steps from setup() & install_progs():
function choose_single_task() {
    local choices

    LOGGING_LVL=1
    readonly FULL_INSTALL=0

    # need to assume .bash_env_vars are there:
    if [[ -f "$SHELL_ENVS" ]]; then
        execute "source $SHELL_ENVS"
    else
        err "expected [$SHELL_ENVS] to exist; note that some configuration might be missing."
    fi

    declare -ar choices=(
        setup
        setup_homesick
        setup_dirs
        setup_config_files

        generate_key
        switch_jdk_versions
        install_SSID_checker
        install_acpi_events
        install_deps
        install_fonts
        upgrade_kernel
        install_nvidia
        install_webdev
        install_npm_modules
        install_from_repo
        install_laptop_deps
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
function __choose_prog_to_build() {
    local choices

    declare -ar choices=(
        install_vim
        install_neovim
        install_YCM
        install_keepassx
        install_goforit
        install_gtk_theme
        install_copyq
        install_synergy
        install_dwm
        install_oracle_jdk
        install_skype
        install_altiris
        install_symantec_endpoint_security
    )

    report "what do you want to build/install?"

    select_items "${choices[*]}" 1

    [[ -z "$__SELECTED_ITEMS" ]] && return

    $__SELECTED_ITEMS
}


function full_install() {

    LOGGING_LVL=10
    readonly FULL_INSTALL=1

    setup

    execute "sudo apt-get --yes update"
    upgrade_kernel
    install_fonts  # has to be after apt has been updated
    install_progs
    post_install_progs_setup
    install_deps
    install_ssh_server_or_client
    install_nfs_server_or_client
    remind_manually_installed_progs
}


# programs that cannot be installed automatically should be reminded
function remind_manually_installed_progs() {
    local progs i

    declare -ar progs=(
        franz
        lazyman2
    )

    for i in "${progs[@]}"; do
        if ! command -v "$i" >/dev/null; then
            report "    don't forget to install [$i]"
        fi
    done
}


# as per    https://confluence.jetbrains.com/display/IDEADEV/Inotify+Watches+Limit
function increase_inotify_watches_limit() {
    local sysctl_conf property value

    readonly sysctl_conf="/etc/sysctl.conf"
    readonly property='fs.inotify.max_user_watches'
    readonly value=524288

    [[ -f "$sysctl_conf" ]] || { err "$sysctl_conf is not a valid file. can't increase inotify watches limit for IDEA"; return 1; }

    if ! grep -q "^$property = $value\$" "$sysctl_conf"; then
        # just in case delete all same prop definitions, regardless of its value:
        execute "sudo sed -i '/^$property/d' \"$sysctl_conf\""

        # increase inotify watches limit (for intellij idea):
        execute "echo $property = $value | sudo tee --append $sysctl_conf > /dev/null"

        # apply the change:
        execute "sudo sysctl -p"
    fi
}


# note: if you don't want to install docker from the debian's own repo (docker.io),
# follow this instruction:  https://docs.docker.com/engine/installation/linux/debian/
#
# (refer to proglist2 if docker complains about memory swappiness not supported.)
#
# add our user to docker group so it could be run as non-root:
function setup_docker() {
    execute "sudo adduser $USER docker"      # add user to docker group
    #execute "sudo gpasswd -a ${USER} docker"  # add user to docker group
    execute "sudo service docker restart"
    execute "newgrp docker"  # log us into the new group
}


## increase the max nr of open file in system. (for intance node might compline otherwise).
## see https://github.com/paulmillr/chokidar/issues/45
## and http://stackoverflow.com/a/21536041/1803648
#function increase_ulimit() {
    #readonly ulimit=3000
    #execute "newgrp docker"  # log us into the new group
#}


# puts networkManager to manage our network interfaces;
# alternatively, you can remove your interface name from /etc/network/interfaces
# (bottom) line; eg from 'iface wlan0 inet dhcp' to 'iface inet dhcp'
function enable_network_manager() {
    local net_manager_conf_file

    readonly net_manager_conf_file='/etc/NetworkManager/NetworkManager.conf'

    [[ -f "$net_manager_conf_file" ]] || { err "[$net_manager_conf_file] does not exist; are you using NetworkManager? if not, this config logic should be removed."; return 1; }
    execute "sudo sed -i 's/^managed=false$/managed=true/' \"$net_manager_conf_file\""
}


# Entryponit for gtk themes; comment out that should not be installed.
function install_gtk_theme() {
    #install_gtk_numix
    install_block 'arc-theme'
}


# https://github.com/numixproject/numix-gtk-theme
#
# consider also numix-gtk-theme & numix-icon-theme straight from the repo
#
# another themes to consider: flatabolous (https://github.com/anmoljagetia/Flatabulous)  (hosts also flat icons);
#                             ultra-flat (https://www.gnome-look.org/content/show.php/Ultra-Flat?content=167473)
function install_gtk_numix() {
    local theme_repo tmpdir

    readonly theme_repo='https://github.com/numixproject/numix-gtk-theme.git'
    readonly tmpdir="$TMPDIR/numix-theme-build-${RANDOM}"

    check_progs_installed  glib-compile-schemas  gdk-pixbuf-pixdata || { err "those need to be on path for numix build to succeed."; return 1; }
    report "installing numix build dependencies..."
    execute "sudo gem install sass" || return 1

    execute "git clone $theme_repo $tmpdir" || return 1
    execute "pushd $tmpdir" || return 1

    execute "make" || { err; popd; return 1; }

    create_deb_install_and_store

    execute "popd"
    execute "sudo rm -rf -- '$tmpdir'"
    return 0
}


# add additional ntp servers
function configure_ntp_for_work() {
    local servers conf i

    readonly conf='/etc/ntp.conf'
    declare -ar servers=('server gibntp01.prod.williamhill.plc'
                         'server gibntp02.prod.williamhill.plc'
                        )

    [[ "$MODE" == work ]] || return
    [[ -f "$conf" ]] || { err "[$conf] is not a valid file. is ntp installed?"; return 1; }

    for i in "${servers[@]}"; do
        if ! grep -q "^$i\$" "$conf"; then
            report "adding [$i] to $conf"
            execute "echo $i | sudo tee --append $conf > /dev/null"
        fi
    done
}


# configs & settings that can/need to be installed  AFTER  the related programs have
# been installed.
function post_install_progs_setup() {

    install_acpi_events   # has to be after install_progs(), so acpid is already insalled and events/ dir present;
    enable_network_manager
    install_SSID_checker  # has to come after install_progs; otherwise NM wrapper dir won't be present
    execute --ignore-errs "sudo alsactl init"  # TODO: cannot be done after reboot and/or xsession.
    execute "mopidy local scan"            # update mopidy library
    execute "sudo sensors-detect --auto"   # answer enter for default values (this is lm-sensors config)
    increase_inotify_watches_limit         # for intellij IDEA
    setup_docker
    execute "sudo adduser $USER wireshark"      # add user to wireshark group, so it could be run as non-root;
                                                # (implies wireshark is installed with allowing non-root users
                                                # to capture packets - it asks this during installation);
    execute "newgrp wireshark"                  # log us into the new group
    execute "sudo adduser $USER vboxusers"      # add user to vboxusers group (to be able to pass usb devices for instance); (https://wiki.archlinux.org/index.php/VirtualBox#Add_usernames_to_the_vboxusers_group)
    execute "newgrp vboxusers"                  # log us into the new group
    install_gtk_theme
    configure_ntp_for_work
}


function install_ssh_server_or_client() {
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
        "server-side" ) install_ssh_server ;;
        "client-side" ) install_sshfs ;;
    esac
}


function install_nfs_server_or_client() {
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

###################
# UTILS (contains no setup-related logic)
###################

function confirm() {
    local msg yno

    readonly msg=${1:+"\n$1"}

    while true; do
        [[ -n "$msg" ]] && echo -e "$msg"
        read -r yno
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


function err() {
    local msg caller_name

    readonly msg="$1"
    readonly caller_name="$2"  # OPTIONAL

    [[ "$LOGGING_LVL" -ge 10 ]] && echo -e "    ERR LOG: ${caller_name:+[$caller_name]: }$msg" >> "$EXECUTION_LOG"
    echo -e "${COLORS[RED]}${caller_name:-"error"}:${COLORS[OFF]} ${msg:-"Abort"}" 1>&2
}


function report() {
    local msg caller_name

    readonly msg="$1"
    readonly caller_name="$2"  # OPTIONAL

    [[ "$LOGGING_LVL" -ge 10 ]] && echo -e "OK LOG: ${caller_name:+[$caller_name]: }$msg" >> "$EXECUTION_LOG"
    echo -e "${COLORS[YELLOW]}${caller_name:-"INFO"}:${COLORS[OFF]} ${msg:-"--info lvl message placeholder--"}"
}


function _sanitize_ssh() {

    if ! [[ -d "$HOME/.ssh" ]]; then
        err "tried to sanitize ~/.ssh, but dir did not exist."
        return 1
    fi

    execute "chmod -R u=rwX,g=,o= -- $HOME/.ssh"
    return $?
}


function is_ssh_key_available() {
    [[ -f "$PRIVATE_KEY_LOC" ]] && return 0 || return 1
}


function check_connection() {
    local timeout ip

    readonly timeout=5  # in seconds
    readonly ip="google.com"

    # Check whether the client is connected to the internet:
    # TODO: keep '--no-check-certificate' by default?
    wget --no-check-certificate -q --spider --timeout=$timeout -- "$ip" > /dev/null 2>&1  # works in networks where ping is not allowed
    return $?
}


function generate_key() {
    local mail valid_mail_regex

    readonly valid_mail_regex='^[a-zA-Z0-9_.+-]+@[a-zA-Z0-9-]+\.[a-zA-Z0-9.-]+$'

    if is_ssh_key_available; then
        confirm "key @ [$PRIVATE_KEY_LOC] already exists; still generate key?" || return 1
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

    execute "ssh-keygen -t rsa -b 4096 -C \"$mail\" -f $PRIVATE_KEY_LOC"
}


# required for common point of logging and exception catching.
#
# provide '-i' or '--ignore-errs' as first arg to avoid returning non-zero code or
# logging ERR to exec logfile on unsuccessful execution.
function execute() {
    local cmd exit_sig ignore_errs

    [[ "$1" == -i || "$1" == --ignore-errs ]] && { shift; readonly ignore_errs=1; }
    readonly cmd="$1"

    echo -e "--> executing [$cmd]"
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


function select_items() {
    local DMENU nr_of_dmenu_vertical_lines dmenurc options options_dmenu i prompt msg choices num is_single_selection selections

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
        if xset q &>/dev/null && [[ -n "$DISPLAY" ]] && command -v dmenu > /dev/null 2>&1; then
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


function remove_items_from_list() {
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


function extract() {
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


function is_server() {
    [[ "$HOSTNAME" == *"server"* ]] && return 0 || return 1
}


# Checks whether system is a laptop.
#
# @returns {bool}   true if system is a laptop.
function is_laptop() {
    local pwr_supply_dir
    readonly pwr_supply_dir="/sys/class/power_supply"

    # sanity:
    [[ -d "$pwr_supply_dir" ]] || { err "$pwr_supply_dir is not a valid dir! cannot decide if we're a laptop; assuming we're not. abort." "$FUNCNAME"; sleep 5; return 1; }

    find "$pwr_supply_dir" -mindepth 1 -maxdepth 1 -name 'BAT*' -print -quit | grep -q .
    return $?
}


function is_64_bit() {
    [[ "$(uname -m)" == x86_64 ]] && return 0 || return 1
}


# Checks whether we're in a git repository.
#
# @returns {bool}  true, if we are in git repo.
function is_git() {
    if git rev-parse --is-inside-work-tree &>/dev/null; then
        return 0
    fi

    return 1
}


# pass '-s' or '--sudo' as first arg to execute as sudo
#
# second arg, the target, should end with a slash if a containing dir is meant to be
# passed, not a literal path to the to-be-created link.
function create_link() {
    local src target filename sudo

    [[ "$1" == -s || "$1" == --sudo ]] && { shift; readonly sudo=sudo; }

    readonly src="$1"
    target="$2"

    if [[ "$target" == */ ]] && $sudo test -d "$target"; then
        readonly filename="$(basename -- "$src")"
        target="${target}$filename"
    fi

    $sudo test -h "$target" && execute "$sudo rm -- $target"
    execute "$sudo ln -s -- \"$src\" \"$target\""

    return 0
}


function __is_work() {
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
function list_contains() {
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
function check_progs_installed() {
    local msg msg_beginning i progs_missing

    declare -a progs_missing=()

    # Check whether required programs are installed:
    for i in "$@"; do
        if ! command -v -- "$i" >/dev/null; then
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


# Builds comma separated list.
#
# @param {string...}   list of elements to build string from.
#
# @returns {string}  comma separated list, eg "a, b, c"
function build_comma_separated_list() {
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
function copy_to_clipboard() {
    local input

    readonly input="$1"

    { command -v xsel >/dev/null 2>/dev/null && echo -n "$input" | xsel --clipboard; } \
        || { command -v xclip >/dev/null 2>/dev/null && echo -n "$input" | xclip -selection clipboard; } \
        || return 1

    return 0
}


function cleanup() {
    [[ "$__CLEANUP_EXECUTED_MARKER" -eq 1 ]] && return  # don't invoke more than once.

    if [[ -n "${PACKAGES_IGNORED_TO_INSTALL[*]}" ]]; then
        echo -e "    ERR INSTALL: dry run failed for these packages: [${PACKAGES_IGNORED_TO_INSTALL[*]}]" >> "$EXECUTION_LOG"
    fi
    if [[ -n "${PACKAGES_FAILED_TO_INSTALL[*]}" ]]; then
        echo -e "    ERR INSTALL: failed installing these packages: [${PACKAGES_FAILED_TO_INSTALL[*]}]" >> "$EXECUTION_LOG"
    fi

    if [[ -e "$EXECUTION_LOG" ]]; then
        sed -i '/^\s*$/d' "$EXECUTION_LOG"  # strip empty lines

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
readonly MODE="$1"   # work | personal

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
