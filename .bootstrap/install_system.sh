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
TMPDIR="/tmp"
CLANG_LLVM_LOC="http://llvm.org/releases/3.7.0/clang+llvm-3.7.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz"  # http://llvm.org/releases/download.html
VIM_REPO_LOC="https://github.com/vim/vim.git"                # vim - yeah.
KEEPASS_REPO_LOC="https://github.com/keepassx/keepassx.git"  # keepassX - open password manager forked from keepass project
COPYQ_REPO_LOC="https://github.com/hluk/CopyQ.git"           # copyq - awesome clipboard manager
SYNERGY_REPO_LOC="https://github.com/synergy/synergy.git"    # synergy - share keyboard&mouse between computers on same LAN
ORACLE_JDK_LOC="http://download.oracle.com/otn-pub/java/jdk/8u65-b17/jdk-8u65-linux-x64.tar.gz"
SKYPE_LOC="http://www.skype.com/go/getskype-linux-deb"
JDK_LINK_LOC="/usr/local/jdk_link"
JDK_INSTALLATION_DIR="/usr/local/javas"
PRIVATE_KEY_LOC="$HOME/.ssh/id_rsa"
SHELL_ENVS="$HOME/.bash_env_vars"       # location of our shell vars; expected to be pulled in via homesick
                                        # note that contents of that file are somewhat important, as some
                                        # (script-related) configuration lies within.
#------------------------
#--- Global Variables ---
#------------------------
IS_SSH_SETUP=0       # states whether our ssh keys are present. 1 || 0
__SELECTED_ITEMS=''  # only select_items() *writes* into this one.
MODE=
PACKAGES_IGNORED_TO_INSTALL=()  # list of all packages that failed to install during the setup
LOGGING_LVL=0                   # execution logging level (full install logs everything);
                                # don't set log level too soon; don't want to persist bullshit.
EXECUTION_LOG="$HOME/installation-execution-$(date +%d-%m-%y--%R).log" \
        || EXECUTION_LOG="$HOME/installation-exe.log"

#------------------------
#--- Global Constants ---
#------------------------
BASE_DATA_DIR="/data"
BASE_DEPS_LOC="$BASE_DATA_DIR/progs/deps"  # hosting stuff like homeshick, bash-git-prompt...
BASE_BUILDS_DIR="$BASE_DATA_DIR/progs/custom_builds"  # hosts our built progs and/or their .deb packages;
BASE_HOMESICK_REPOS_LOC="$BASE_DEPS_LOC/homesick/repos"
COMMON_DOTFILES="$BASE_HOMESICK_REPOS_LOC/dotfiles"
COMMON_PRIVATE_DOTFILES="$BASE_HOMESICK_REPOS_LOC/private-common"
PRIVATE_CASTLE=''  # installation specific private castle location (eg for 'work' or 'personal')

SELF="${0##*/}"

declare -A COLORS
COLORS=(
    [RED]="\033[0;31m"
    [YELLOW]="\033[0;33m"
    [OFF]="\033[0m"
)
#-----------------------
#---    Functions    ---
#-----------------------


function print_usage() {

    printf "${SELF}:  install system.
        usage: $SELF  work|personal
    "
}


function validate_and_init() {

    check_connection || { err "no internet connection. abort."; exit 1; }

    # need to define PRIVATE_CASTLE here, as otherwis 'single-step' mode of this
    # script might fail. be sure the values are in sync with the repos actually
    # pulled in fetch_castles().
    case $MODE in
        work)
            if [[ "$__ENV_VARS_LOADED_MARKER_VAR" == loaded ]] && ! __is_work; then
                confirm "you selected work mode on non-work machine; sure you want to continue?" || exit
            fi

            PRIVATE_CASTLE="$BASE_HOMESICK_REPOS_LOC/work_dotfiles"
            ;;
        personal)
            if [[ "$__ENV_VARS_LOADED_MARKER_VAR" == loaded ]] && __is_work; then
                confirm "you selected personal mode on work machine; sure you want to continue?" || exit
            fi

            PRIVATE_CASTLE="$BASE_HOMESICK_REPOS_LOC/personal-dotfiles"
            ;;
        *)
            print_usage
            exit 1 ;;
    esac

    report "private castle defined as \"$PRIVATE_CASTLE\""

    # verify we have our key(s) set up and available:
    if is_ssh_setup; then
        _sanitize_ssh
        IS_SSH_SETUP=1
    else
        report "ssh keys not present at the moment, be prepared to enter user & passwd for private git repos."
        IS_SSH_SETUP=0
    fi
}


# check dependencies required for this installation script
function check_dependencies() {
    local dir prog perms

    perms=764  # can't be 777, nor 766, since then you'd be unable to ssh into;

    for prog in git wget tar realpath dirname tee; do
        if ! command -v $prog >/dev/null; then
            report "$prog not installed yet, installing..."
            install_block "$prog" || { err "unable to install required prog $prog this script depends on. abort."; exit 1; }
            report "...done"
        fi
    done

    # TODO: need to create dev/ already here, since both dotfiles and private-common
    # either point to it, or point somthing in it; not a good solution.
    # best finalyse scripts and move them to dotfiles.
    #
    #
    # verify required dirs are existing and have $perms perms:
    for dir in \
            $BASE_DATA_DIR \
            $BASE_DATA_DIR/dev \
                ; do
        if ! [[ -d "$dir" ]]; then
            if confirm "$dir mountpoint/dir does not exist; simply create a directory instead? (answering 'no' aborts script)"; then
                execute "sudo mkdir $dir" || { err "unable to create $dir directory. abort."; exit 1; }
            else
                err "expected \"$dir\" to be already-existing dir. abort"
                exit 1
            fi
        fi

        execute "sudo chown $USER:$USER $dir" || { err "unable to change $dir ownership to $USER:$USER. abort."; exit 1; }
        execute "sudo chmod $perms $dir" || { err "unable to change $dir permissions to $perms. abort."; exit 1; }
    done
}


function setup_hosts() {
    local hosts_file_dest file current_hostline tmpfile

    hosts_file_dest="/etc"
    tmpfile="$TMPDIR/hosts"
    file="$PRIVATE_CASTLE/backups/hosts"

    function _extract_current_hostname_line() {
        local file current

        file="$1"
        #current="$(grep '\(127\.0\.1\.1\)\s\+\(.*\)\s\+\(\w\+\)' $file)"
        current="$(grep "$HOSTNAME" "$file")"
        if [[ -z "$current" || "$(echo "$current" | wc -l)" -ne 1 ]]; then
            err "$file contained either more or less than 1 line(s) containing our hostname. check manually."
            return 1
        fi

        echo "$current"
        return 0
    }

    if ! [[ -d "$hosts_file_dest" ]]; then
        err "$hosts_file_dest is not a dir; skipping hosts file installation."
        return 1
    fi

    if [[ -f "$file" ]]; then
        [[ -f "$hosts_file_dest/hosts" ]] || { err "system hosts file is missing!"; return 1; }
        current_hostline="$(_extract_current_hostname_line $hosts_file_dest/hosts)" || return 1
        execute "cp $file $tmpfile" || return 1
        execute "sed -i 's/{HOSTS_LINE_PLACEHOLDER}/$current_hostline/g' $tmpfile" || return 1

        backup_original_and_copy_file "$tmpfile" "$hosts_file_dest"
        execute "rm $tmpfile"
    else
        err "expected configuration file at \"$file\" does not exist; won't install it."
    fi

    unset _extract_current_hostname_line
}


function setup_sudoers() {
    local sudoers_dest file tmpfile

    sudoers_dest="/etc"
    tmpfile="$TMPDIR/sudoers"
    file="$COMMON_DOTFILES/backups/sudoers"

    if ! [[ -d "$sudoers_dest" ]]; then
        err "$sudoers_dest is not a dir; skipping sudoers file installation."
        return 1
    fi

    if [[ -f "$file" ]]; then
        execute "cp $file $tmpfile" || return 1
        execute "sed -i 's/{USER_PLACEHOLDER}/$USER/g' $tmpfile" || return 1
        backup_original_and_copy_file "$tmpfile" "$sudoers_dest"

        execute "rm $tmpfile"
    else
        err "expected configuration file at \"$file\" does not exist; won't install it."
    fi
}


function setup_apt() {
    local apt_dir file

    apt_dir="/etc/apt"

    if ! [[ -d "$apt_dir" ]]; then
        err "$apt_dir is not a dir; skipping apt conf installation."
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
            err "expected configuration file at \"$file\" does not exist; won't install it."
        fi
    done
}


function setup_crontab() {
    local cron_dir tmpfile file

    cron_dir="/etc/cron.d"  # where crontab will be installed at
    tmpfile="$TMPDIR/crontab"
    file="$PRIVATE_CASTLE/backups/crontab"

    if ! [[ -d "$cron_dir" ]]; then
        err "$cron_dir is not a dir; skipping crontab installation."
        return 1
    fi

    if [[ -f "$file" ]]; then
        execute "cp $file $tmpfile" || return 1
        execute "sed -i 's/{USER_PLACEHOLDER}/$USER/g' $tmpfile" || return 1
        backup_original_and_copy_file "$tmpfile" "$cron_dir"

        execute "rm $tmpfile"
    else
        err "expected configuration file at \"$file\" does not exist; won't install it."
    fi
}


function backup_original_and_copy_file() {
    local file dest filename

    file="$1"  # full path of the file to be copied
    dest="$2"  # full path of the destination directory to copy to

    filename="$(basename "$file")"

    # back up the destination file, if it's already existing:
    if [[ -f "$dest/$filename" ]] && ! [[ -e "$dest/${filename}.orig" ]]; then
        execute "sudo cp $dest/$filename $dest/${filename}.orig"
    fi

    execute "sudo cp $file $dest"
}


function clone_or_pull_repo() {
    local user repo install_dir hub

    user="$1"
    repo="$2"
    install_dir="$3"
    hub=${4:-"github.com"}  # OPTIONAL; if not provided, defaults to github.com;

    [[ -z "$install_dir" ]] && { err "need to provide target directory." "$FUNCNAME"; return 1; }

    if ! [[ -d "$install_dir/$repo" ]]; then
        execute "git clone https://$hub/$user/${repo}.git $install_dir/$repo" || return 1

        execute "pushd $install_dir/$repo"
        execute "git remote set-url origin git@${hub}:$user/${repo}.git"
        execute "popd"
    elif is_ssh_setup; then
        execute "pushd $install_dir/$repo"
        execute "git pull"
        execute "popd"
    fi
}


function install_nfs_server() {
    local nfs_conf client_ip default_mount mountpoint

    nfs_conf="/etc/exports"
    default_mount="/data"

    confirm "wish to install & configure nfs server?" || return 1
    if is_laptop; then
        confirm "you're on laptop; sure you wish to install nfs server?" || return 1
    fi

    install_block 'nfs-kernel-server' || { err "unable to install nfs-kernel-server. aborting nfs server install/config."; return 1; }

    if ! [[ -f "$nfs_conf" ]]; then
        err "$nfs_conf is not a file; skipping nfs server installation."
        return 1
    fi

    while true; do
        if confirm "$(report "add client IP for the exports list (who will access $default_mount)?")"; then
            echo -e "enter client ip:"
            read client_ip

            [[ "$client_ip" =~ ^[0-9.]+$ ]] || { err "not a valid ip: \"$client_ip\""; continue; }

            echo -e "enter mountpoint (leave blank to default to \"$default_mount\"):"
            read mountpoint

            mountpoint=${mountpoint:-"$default_mount"}
            [[ -d "$mountpoint" ]] || { err "$mountpoint is not a valid dir."; continue; }

            if ! grep -q "${mountpoint}.*${client_ip}" "$nfs_conf"; then
                report "adding $mountpoint for $client_ip to $nfs_conf"
                execute "echo $mountpoint ${client_ip}\(rw,sync,no_subtree_check\) | sudo tee --append $nfs_conf > /dev/null"
            else
                report "an entry for exposing $mountpoint to $client_ip is already present in $nfs_conf"
            fi
        else
            break
        fi
    done

    # exports the shares:
    exedute 'sudo exportfs -ra'

    return 0
}


function install_nfs_client() {
    local fstab mountpoint

    fstab="/etc/fstab"
    mountpoint="/mnt/nfs"

    confirm "wish to install & configure nfs client?" || return 1

    install_block 'nfs-common' || { err "unable to install nfs-common. aborting nfs client install/config."; return 1; }

    # create mountpoint:
    [[ -d "$mountpoint" ]] || execute "sudo mkdir $mountpoint" || { err; return 1; }
    execute "sudo chmod 777 $mountpoint"

    # TODO: automate?
    [[ -f "$fstab" ]] || { err "$fstab does not exist; cannot add fstab entry!"; return 1; }
    report "do not forget to set up fstab entry for the nfs mount!!!" && sleep 4

    return 0
}


function install_ssh_server() {
    local sshd_confdir config banner

    sshd_confdir="/etc/ssh"
    config="$COMMON_PRIVATE_DOTFILES/backups/sshd_config"
    banner="$COMMON_PRIVATE_DOTFILES/backups/ssh_banner"

    confirm "wish to install & configure ssh server?" || return 1
    if is_laptop; then
        confirm "you're on laptop; sure you wish to install ssh server?" || return 1
    fi

    install_block 'openssh-server' || { err "unable to install openssh-server. aborting sshd install/config."; return 1; }

    if ! [[ -d "$sshd_confdir" ]]; then
        err "$sshd_confdir is not a dir; skipping sshd conf installation."
        return 1
    fi

    # install sshd config:
    if [[ -f "$config" ]]; then
        backup_original_and_copy_file "$config" "$sshd_confdir"
    else
        err "expected configuration file at \"$config\" does not exist; aborting sshd configuration."
        return 1
    fi


    # install ssh banner:
    if [[ -f "$banner" ]]; then
        backup_original_and_copy_file "$banner" "$sshd_confdir"
    else
        err "expected sshd banner file at \"$banner\" does not exist; won't install it."
        #return 1  # don't return, it's just a banner.
    fi

    execute "sudo systemctl start sshd.service"
    #execute "systemctl enable sshd.service"  # TODO: this is not required, is it?

    return 0
}


function install_sshfs() {
    local fuse_conf mountpoint

    fuse_conf="/etc/fuse.conf"
    mountpoint="/mnt/ssh"

    confirm "wish to install and configure sshfs?" || return 1
    install_block 'sshfs' || { err "unable to install sshfs. aborting sshfs install/config."; return 1; }

    # note that 'user_allow_other' uncommenting makes sense only if our related fstab
    # entry has the 'allow_other' opt:
    if ! [[ -r "$fuse_conf" && -f "$fuse_conf" ]]; then
        err "$fuse_conf is not readable; cannot uncomment \"\#user_allow_other\" prop in it."
    elif grep -q '#user_allow_other' "$fuse_conf"; then
        # hasn't been uncommented yet
        execute "sudo sed -i 's/#user_allow_other/user_allow_other/g' $fuse_conf"
        [[ $? -ne 0 ]] && { err "uncommenting '#user_allow_other' in $fuse_conf failed"; return 2; }
    elif grep -q 'user_allow_other' "$fuse_conf"; then
        true  # do nothing; already uncommented, all good;
    else
        err "$fuse_conf appears not to contain config value \"user_allow_other\"; check manually."
    fi

    # add us to the fuse group:
    execute "sudo gpasswd -a $USER fuse"

    # create mountpoint:
    [[ -d "$mountpoint" ]] || execute "sudo mkdir $mountpoint" || { err; return 1; }
    execute "sudo chmod 777 $mountpoint"

    # TODO: automate?
    report "do not forget to set up fstab entry for the sshfs mount!!!" && sleep 4

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
        #err "expected ssh configuration file at \"$ssh_conf\" does not exist; aborting ssh (client) configuration."
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

        plugins_dir="$HOME/.tmux/plugins"

        if ! [[ -d "$plugins_dir/tpm" ]]; then
            clone_or_pull_repo "tmux-plugins" "tpm" "$plugins_dir"
            report "don't forget to install tmux plugins by running <prefix + I> in tmux later on." && sleep 4
        else
            # update all the tmux plugins, including the plugin manager itself:
            execute "pushd $plugins_dir"

            for dir in *; do
                if [[ -d "$dir" ]] && is_ssh_setup; then
                    execute "pushd $dir"
                    is_git && execute "git pull"
                    execute "popd"
                fi
            done

            execute "popd"
        fi
    }

    # bash-git-prompt:
    clone_or_pull_repo "magicmonty" "bash-git-prompt" "$BASE_DEPS_LOC"

    # git-flow-completion:
    clone_or_pull_repo "bobthecow" "git-flow-completion" "$BASE_DEPS_LOC"

    # bars in shell:
    clone_or_pull_repo "holman" "spark" "$BASE_DEPS_LOC"  # https://github.com/holman/spark

    # pearl-ssh perhaps?

    # tmux plugin manager:
    _install_tmux_deps

    # TODO: these are not deps, are they?:
    execute "sudo pip install git-playback"  # https://github.com/jianli/git-playback

    # this needs apt-get install  python-imaging ?:
    execute "sudo pip install img2txt.py"    # https://github.com/hit9/img2txt  (for ranger)
    execute "sudo pip3 install scdl"         # https://github.com/flyingrub/scdl (soundcloud downloader)
    execute "sudo pip install rtv"           # https://github.com/michael-lazar/rtv (reddit reader)


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
    fi

    unset _install_tmux_deps
}


function setup_dirs() {
    local dir

    # create dirs:
    for dir in \
            $_PERSISTED_TMP \
            $BASE_DATA_DIR/.rsync \
            $BASE_DATA_DIR/progs \
            $BASE_DATA_DIR/progs/deps \
            $BASE_DATA_DIR/progs/custom_builds \
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
            report "$dir does not exist, creating..."
            execute "mkdir $dir"
        fi
    done

    # create logdir ($CUSTOM_LOGDIR comes from $SHELL_ENVS):
    if ! [[ -d "$CUSTOM_LOGDIR" ]]; then
        [[ -z "$CUSTOM_LOGDIR" ]] && { err "\$CUSTOM_LOGDIR env var was missing. abort."; sleep 5; return 1; }

        report "$CUSTOM_LOGDIR does not exist, creating..."
        execute "sudo mkdir $CUSTOM_LOGDIR"
        execute "sudo chmod 777 $CUSTOM_LOGDIR"
    fi
}


function install_homesick() {

    clone_or_pull_repo "andsens" "homeshick" "$BASE_HOMESICK_REPOS_LOC"

    # add the link, since homeshick is not installed in its default location (which is $HOME):
    if ! [[ -h "$HOME/.homesick" ]]; then
        execute "ln -s $BASE_DEPS_LOC/homesick $HOME/.homesick"
    fi
}


function clone_or_link_castle() {
    local castle user hub homesick_exe

    castle="$1"
    user="$2"
    hub="$3"  # domain of the git repo, ie github.com/bitbucket.org...

    homesick_exe="$BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick"

    [[ -z "$castle" || -z "$user" || -z "$hub" ]] && { err "either user, repo or castle name were missing"; sleep 2; return 1; }
    [[ -e "$homesick_exe" ]] || { err "expected to see homesick script @ $homesick_exe, but didn't. skipping cloning castle $castle"; return 1; }

    if [[ -d "$BASE_HOMESICK_REPOS_LOC/$castle" ]]; then
        if is_ssh_setup; then
            report "$castle already exists; pulling & linking"
            execute "$homesick_exe pull $castle"
        else
            report "$castle already exists; linking..."
        fi

        execute "$homesick_exe link $castle"
    else
        report "cloning ${castle}..."
        if is_ssh_setup; then
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
    if [[ "$IS_SSH_SETUP" -eq 0 ]] && is_ssh_setup; then
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
    if [[ "$MODE" == work ]]; then
        clone_or_link_castle work_dotfiles laur.aliste gitlab.williamhill-dev.local
    elif [[ "$MODE" == personal ]]; then
        clone_or_link_castle personal-dotfiles layr bitbucket.org
    fi

    while true; do
        if confirm "$(report 'want to clone another castle?')"; then
            echo -e "enter git repo domain (eg \"github.com\", \"bitbucket.org\"):"
            read hub

            echo -e "enter username:"
            read user

            echo -e "enter castle name (repo name, eg \"dotfiles\"):"
            read castle

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

    if is_ssh_setup; then
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
    https_castles="$($BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick list | grep '\bhttps://\b')"
    if [[ -n "$https_castles" ]]; then
        report "fyi, these homesick castles are for some reason still tracking https remotes:"
        report "$https_castles"
    fi
}


# creates symlink of our personal '.bash_env_vars' to /etc & /etc/profile.d/
function setup_global_env_vars() {
    local global_env_var_loc global_env_var

    global_env_var_loc='/etc/.bash_env_vars'  # so our env vars would have user-agnostic location as well;
                                              # that location will be used by various scripts.
    global_env_var='/etc/profile.d/bash_env_vars.sh'  # target name needs to end with .sh

    if ! [[ -e "$SHELL_ENVS" ]]; then
        err "$SHELL_ENVS does not exist. can't link it to $global_env_var_loc nor $global_env_var"
        return 1
    fi

    if ! [[ -h "$global_env_var_loc" ]]; then
        execute "sudo ln -s $SHELL_ENVS $global_env_var_loc"
    fi

    if ! [[ -d "$(dirname $global_env_var)" ]]; then
        err "$(dirname $global_env_var) is not a dir; can't install globally for all the users."
    else
        if ! [[ -h "$global_env_var" ]]; then
            execute "sudo ln -s $SHELL_ENVS $global_env_var"
        fi
    fi

    #if sudo test -f $root_bashrc; then
        #if ! sudo grep -q "source $SHELL_ENVS" $root_bashrc; then
            ## hasn't been sourced in $root_bashrc yet:
            #execute "echo source $SHELL_ENVS | sudo tee --append $root_bashrc > /dev/null"
        #fi
    #else
        #err "$root_bashrc doesn't exist; cannot source \"$SHELL_ENVS\" from it!"
        #return 1
    #fi
}


# netrc file has to be accessible only by its owner.
function setup_netrc_perms() {
    local rc_loc perms

    rc_loc="$HOME/.netrc"
    perms=600

    if [[ -e "$rc_loc" ]]; then
        execute "chmod $perms $(realpath "$rc_loc")"  # realpath, since we cannot change perms via symlink
    else
        err "expected to find \"$rc_loc\", but it doesn't exist. if you're not using netrc, better remvoe related logic from ${SELF}."
        return 1
    fi
}


# setup system config files (the ones not living under $HOME, ie not managed by homesick)
# has to be invoked AFTER homeschick castles are cloned/pulled!
function setup_config_files() {

    setup_apt
    setup_crontab
    setup_sudoers
    #setup_ssh_config   # better stick to ~/.ssh/config, rite?
    setup_hosts
    setup_global_env_vars
    setup_netrc_perms
    swap_caps_lock_and_esc
}


# network manager wrapper script;
# runs other script that writes info to /tmp and manages locking logic for laptops (security, kinda)
function setup_SSID_checker() {
    local nm_wrapper_loc  nm_wrapper_dest

    nm_wrapper_loc="$BASE_DATA_DIR/dev/scripts/network_manager_SSID_checker_wrapper.sh"
    nm_wrapper_dest="/etc/NetworkManager/dispatcher.d"

    if ! [[ -f "$nm_wrapper_loc" ]]; then
        err "$nm_wrapper_loc does not exist; SSID checker won't be installed"
        return 1
    elif ! [[ -d "$nm_wrapper_dest" ]]; then
        err "$nm_wrapper_dest dir does not exist; SSID checker won't be installed"
        return 1
    fi

    execute "sudo cp $nm_wrapper_loc $nm_wrapper_dest/"
    return $?
}


function setup() {

    setup_homesick
    verify_ssh_key
    execute "source $SHELL_ENVS"  # so we get our env vars after dotfiles are pulled in

    setup_dirs  # has to come after .bash_env_vars sourcing so the env vars are in place
    setup_config_files
    setup_additional_apt_keys
}


function setup_additional_apt_keys() {

    # install keys:
    # mopidy key:
    execute 'wget -q -O - http://apt.mopidy.com/mopidy.gpg | sudo apt-key add -'

    # spotify: (from https://www.spotify.com/es/download/linux/):
    execute 'sudo apt-key adv --keyserver hkp://keyserver.ubuntu.com:80 --recv-keys BBEBDCB318AD50EC6865090613B00F1FD2C19886'
}


# can also exec 'setxkbmap -option' caps:escape or use dconf-editor
function swap_caps_lock_and_esc() {
    local conf_file

    conf_file="/usr/share/X11/xkb/symbols/pc"

    if ! [[ -f "$conf_file" ]]; then
        err "cannot swap esc<->caps: \"$conf_file\" does not exist; abort;"
        return 1
    fi

    if ! grep -q 'key <ESC>.*Caps_Lock' $conf_file; then
        # hasn't been replaced yet
        execute "sudo sed -i 's/.*key.*ESC.*Escape.*/    key <ESC>  \{    \[ Caps_Lock        \]   \};/g' $conf_file"
        [[ $? -ne 0 ]] && { err "replacing esc<->caps @ $conf_file failed"; return 2; }
    fi

    if ! grep -q 'key <CAPS>.*Escape' $conf_file; then
        # hasn't been replaced yet
        execute "sudo sed -i 's/.*key.*CAPS.*Caps_Lock.*/    key <CAPS>   \{ \[ Escape     \]   \};/g' $conf_file"
        [[ $? -ne 0 ]] && { err "replacing esc<->caps @ $conf_file failed"; return 2; }
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
        execute "sudo chmod +x $rpm_loc"
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

    execute "chmod +x $TMPDIR/altiris_install.sh"
    execute "sudo $TMPDIR/altiris_install.sh" || {
        err "something's wrong; if it failed at rollout.sh, then you probably need to install libc6:i386"
        err "(as per https://williamhill.jira.com/wiki/display/TRAD/Altiris+on+Ubuntu)"
        return 1
    }

    execute "pushd /opt/altiris/notification/nsagent/bin" || return 1
    execute "sudo ./aex-configure -configure" || return 1

    execute "sudo mkdir -p /etc/rc.d/init.d" || return 1
    execute "sudo ln -s /lib/lsb/init-functions /etc/rc.d/init.d/functions" || return 1

    execute "sudo /etc/init.d/altiris start" || return 1
    # refresh policies:
    execute "sudo /opt/altiris/notification/nsagent/bin/aex-refreshpolicies"
    execute "sudo /opt/altiris/notification/nsagent/bin/aex-sendbasicinv" || { err 'apparently cannot send basic inventory'; return 1; }
}


function install_symantec_endpoint_security() {
    local sep_loc jce_loc tmpdir tarball dir jars

    sep_loc='https://williamhillorg-my.sharepoint.com/personal/leighhall_williamhill_co_uk/_layouts/15/guestaccess.aspx?guestaccesstoken=B5plVjedQluwT7BgUH50bG3rs99cJaCg6lckbkGdS6I%3d&docid=2_15a1ca98041134ad8b2e4d93286806892'
    jce_loc='http://download.oracle.com/otn-pub/java/jce/8/jce_policy-8.zip'

    [[ "$MODE" != work ]] && { err "won't install it in $MODE mode; only in work mode."; return 1; }
    [[ -d "$JDK_LINK_LOC" ]] || { err "expected $JDK_LINK_LOC to link to existing jdk installation."; return 1; }

    tmpdir="$(mktemp -d "symantec-endpoint-sec-tempdir-XXXXX" -p $TMPDIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }
    execute "pushd $tmpdir"

    # fetch & install SEP:
    execute "wget -- $sep_loc" || return 1
    tarball="$(ls)"
    extract "$tarball" || { err "extracting $tarball failed."; return 1; }
    dir="$(find -mindepth 1 -maxdepth 1 -type d)"
    [[ -d "$dir" ]] || { err "couldn't find unpacked SEP directory"; return 1; }

    execute "sudo $dir/install.sh" || return 1

    execute "rm -- $tarball"
    execute "sudo rm -rf $dir" || return 1

    # fetch & install the jdk crypto extensions (JCE):
    execute "wget --no-check-certificate \
        --no-cookies \
        --header 'Cookie: oraclelicense=accept-securebackup-cookie' \
        -- $jce_loc" || { err "unable to wget $jce_loc."; return 1; }

    tarball="$(basename $jce_loc)"
    extract "$tarball" || { err "extracting $tarball failed."; return 1; }
    dir="$(find -mindepth 1 -maxdepth 1 -type d)"
    [[ -d "$dir" ]] || { err "couldn't find unpacked jce directory"; return 1; }
    jars="$(find "$dir" -mindepth 1 -type f -name '*.jar')" || { err "looks like we didn't find any .jar files under $dir"; return 1; }
    execute "sudo cp $jars $JDK_LINK_LOC/jre/lib/security" || return 1

    # cleanup:
    execute "popd"
    execute "sudo rm -rf -- $tmpdir"
}


function install_laptop_deps() {

    if is_laptop; then
        install_block '
            xserver-xorg-input-synaptics
            blueman
            xfce4-power-manager
        '

        # consider using   lspci -vnn | grep -A5 WLAN | grep -qi intel
        if sudo lshw | grep -iA 5 'Wireless interface' | grep -iq 'vendor.*Intel'; then
            report "we have intel wifi; installing intel drivers..."
            install_block "firmware-iwlwifi"
        fi
    fi
}


function install_progs() {

    install_from_repo
    install_laptop_deps
    install_own_builds

    install_oracle_jdk
    install_skype
    install_nvidia

    # TODO:
    #if [[ "$MODE" == work ]]; then
        #install_altiris
        #install_symantec_endpoint_security
    #fi

    if confirm "do you want to install our webdev lot?"; then
        install_webdev
    fi
}


function upgrade_kernel() {
    local package_line kernels_list amd64_arch

    kernels_list=()
    is_64_bit && amd64_arch="amd64"

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
    install_keepassx
    install_copyq
    install_synergy
    install_dwm
}


# note that jdk will be installed under $JDK_INSTALLATION_DIR
function install_oracle_jdk() {
    local tarball tmpdir dir

    tmpdir="$(mktemp -d "jdk-tempdir-XXXXX" -p $TMPDIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }

    report "fetcing $ORACLE_JDK_LOC"
    execute "pushd $tmpdir"

    wget --no-check-certificate \
        --no-cookies \
        --header 'Cookie: oraclelicense=accept-securebackup-cookie' \
        -- $ORACLE_JDK_LOC

    tarball="$(basename $ORACLE_JDK_LOC)"
    extract "$tarball" || { err "extracting $tarball failed."; return 1; }
    dir="$(find -mindepth 1 -maxdepth 1 -type d)"
    [[ -d "$dir" ]] || { err "couldn't find unpacked jdk directory"; return 1; }

    [[ -d "$JDK_INSTALLATION_DIR" ]] || execute "sudo mkdir $JDK_INSTALLATION_DIR"
    report "installing fetched JDK to $JDK_INSTALLATION_DIR"
    execute "sudo mv $dir $JDK_INSTALLATION_DIR/" || { err "could not move extracted jdk dir ($dir) to $JDK_INSTALLATION_DIR"; return 1; }

    # create link:
    [[ -h "$JDK_LINK_LOC" ]] && execute "sudo rm $JDK_LINK_LOC"
    execute "sudo ln -s $JDK_INSTALLATION_DIR/$(basename "$dir") $JDK_LINK_LOC"

    execute "popd"
    execute "sudo rm -rf $tmpdir"
    return 0
}


function switch_jdk_versions() {
    local avail_javas active_java

    [[ -d "$JDK_INSTALLATION_DIR" ]] || { err "$JDK_INSTALLATION_DIR does not exist. abort."; return 1; }
    avail_javas="$(find $JDK_INSTALLATION_DIR -mindepth 1 -maxdepth 1 -type d)"
    [[ $? -ne 0 || -z "$avail_javas" ]] && { err "discovered no java installations @ $JDK_INSTALLATION_DIR"; sleep 5; return 1; }
    if [[ -h "$JDK_LINK_LOC" ]]; then
        active_java="$(realpath $JDK_LINK_LOC)"
        if [[ "$avail_javas" == "$active_java" ]]; then
            report "only one active jdk installation, \"$active_java\" is available, and that is already linked by $JDK_LINK_LOC"
            return
        fi

        active_java="$(basename "$active_java")"
    fi

    while true; do
        [[ -n "$active_java" ]] && report "current active java: $active_java"
        report "select java ver to use (select none to skip the change)\n"
        select_items "$avail_javas" 1

        if [[ -n "$__SELECTED_ITEMS" ]]; then
            report "selecting ${__SELECTED_ITEMS}..."
            [[ -h "$JDK_LINK_LOC" ]] && execute "sudo rm $JDK_LINK_LOC"
            execute "sudo ln -s $__SELECTED_ITEMS $JDK_LINK_LOC"
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
    local skypeFile

    is_server && { report "we're server, skipping skype installation."; return; }
    skypeFile="$TMPDIR/skype-install.deb"

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
}


function install_webdev() {
    is_server && { report "we're server, skipping webdev stack installation."; return; }

    install_block '
        nodejs
    '

    execute "sudo npm install -g jshint"
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


function build_and_install_synergy() {
    # building instructions from https://github.com/synergy/synergy/wiki/Compiling
    local builddir do_clone

    do_clone="$1"  # set to '0' if synergy repo should NOT be re-cloned

    builddir="$BASE_BUILDS_DIR/synergy"
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
        [[ -d "$builddir" ]] && execute "sudo rm -rf $builddir"
        execute "git clone $SYNERGY_REPO_LOC $builddir" || return 1
    fi

    execute "pushd $builddir"
    [[ "$do_clone" -eq 0 ]] && is_ssh_setup && execute "git pull"

    execute "./hm.sh conf -g1"
    execute "./hm.sh build"

    # note builddir should not be deleted
    execute "popd"
    return 0
}


function build_and_install_copyq() {
    # building instructions from https://github.com/hluk/CopyQ/blob/master/INSTALL
    local tmpdir

    tmpdir="$TMPDIR/copyq-build-${RANDOM}"

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
    execute "pushd $tmpdir"

    execute 'cmake .'
    execute "make"

    create_deb_install_and_store

    execute "popd"
    execute "sudo rm -rf -- $tmpdir"
    return 0
}


function create_deb_install_and_store() {
    local deb_file

    report "creating .deb and installing with checkinstall..."
    execute "sudo checkinstall" || { err "checkinstall failed. is it installed? abort."; return 1; }

    deb_file="$(find . -type f -name '*.deb')"
    if [[ -f "$deb_file" ]]; then
        report "moving built package \"$deb_file\" to $BASE_BUILDS_DIR"
        execute "mv $deb_file $BASE_BUILDS_DIR/"
        return $?
    else
        err "couldn't find built package (find cmd found \"$deb_file\")"
        return 1
    fi
}


function build_and_install_keepassx() {
    # building instructions from https://github.com/keepassx/keepassx
    local tmpdir

    should_build_if_avail_in_repo keepassx || { report "skipping building of keepassx. remember to install it from the repo after the install!"; return; }

    tmpdir="$TMPDIR/keepassx-build-${RANDOM}"
    report "building keepassx..."

    report "installing keepassx build dependencies..."
    install_block '
        qtbase5-dev
        libqt5x11extras5-dev
        qttools5-dev
        qttools5-dev-tools
        libgcrypt20-dev
        zlib1g-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }

    execute "git clone $KEEPASS_REPO_LOC $tmpdir" || return 1

    execute "mkdir $tmpdir/build"
    execute "pushd $tmpdir/build"
    execute 'cmake ..'
    execute "make"

    create_deb_install_and_store

    execute "popd"
    execute "sudo rm -rf -- $tmpdir"
    return 0
}


function install_dwm() {
    local build_dir

    build_dir="$HOME/.dwm/w0ngBuild/source6.0"

    clone_or_link_castle dwm-setup laur89 github.com
    [[ -d "$build_dir" ]] || { err "\"$build_dir\" is not a dir. skipping dwm installation."; return 1; }

    report "installing dwm build dependencies..."
    install_block '
        suckless-tools
        build-essential
        libx11-dev
        libxinerama-dev
        libpango1.0-dev
        libxtst-dev
    ' || { err 'failed to install build deps. abort.'; return 1; }

    execute "pushd $build_dir"
    report "installing dwm..."
    execute "sudo make clean install"
    execute "popd"
    return 0
}


# searches .deb packages with provided name in its filename from
# $BASE_BUILDS_DIR and installs it.
function install_from_deb() {
    local deb_file count name

    name="$1"

    deb_file="$(find $BASE_BUILDS_DIR -type f -iname "*$name*.deb")"
    [[ "$?" -eq 0 && -n "$deb_file" ]] || { report "didn't find any pre-build deb packages for $name; trying to build..."; return 1; }
    count="$(echo "$deb_file" | wc -l)"

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
}


function vim_post_install_configuration() {
    local stored_vim_sessions

    stored_vim_sessions="$BASE_DATA_DIR/.vim_sessions"

    # generate links for root, if not existing:
    if ! sudo test -h "/root/.vim"; then
        if [[ ! -f "$HOME/.vimrc" || ! -d "$HOME/.vim" ]]; then
            err "either $HOME/.vimrc is not a file or $HOME/.vim is not a dir."
            err "skipping creating links to /root/"
        else
            execute "sudo ln -s $HOME/.vimrc /root/"
            execute "sudo ln -s $HOME/.vim /root/"
        fi
    fi

    # link sessions dir, if stored @ $BASE_DATA_DIR: (related to the 'xolox/vim-session' plugin)
    # note we don't want sessions in homesick, as they're likely to be machine-dependent.
    if [[ -d "$stored_vim_sessions" ]]; then
        if ! [[ -h "$HOME/.vim/sessions" ]]; then
            [[ -d "$HOME/.vim/sessions" ]] && execute "sudo rm -rf $HOME/.vim/sessions"
            execute "ln -s $stored_vim_sessions $HOME/.vim/sessions"
        fi
    else  # $stored_vim_sessions does not exist; init it anyways
        if [[ -d "$HOME/.vim/sessions" ]]; then
            execute "mv $HOME/.vim/sessions $stored_vim_sessions"
        else
            execute "mkdir $stored_vim_sessions"
        fi

        execute "ln -s $stored_vim_sessions $HOME/.vim/sessions"
    fi
}


function build_and_install_vim() {
    # building instructions from https://github.com/Valloric/YouCompleteMe/wiki/Building-Vim-from-source
    local tmpdir

    tmpdir="$TMPDIR/vim-build-${RANDOM}"
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
    execute "pushd $tmpdir"

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


function install_YCM() {
    # note: instructions & info here: https://github.com/Valloric/YouCompleteMe
    local ycm_root  ycm_build_root  libclang_root

    ycm_root="$BASE_BUILDS_DIR/YCM"
    ycm_build_root="$ycm_root/ycm_build"
    libclang_root="$ycm_root/llvm"

    function __fetch_libclang() {
        local tmpdir tarball dir

        tmpdir="$(mktemp -d "ycm-tempdir-XXXXX" -p $TMPDIR)" || { err "unable to create tempdir with \$mktemp"; return 1; }
        tarball="$(basename "$CLANG_LLVM_LOC")"

        execute "pushd $tmpdir"
        report "fetching $CLANG_LLVM_LOC"
        execute "wget $CLANG_LLVM_LOC" || { err "wgetting $CLANG_LLVM_LOC failed."; return 1; }
        extract "$tarball" || { err "extracting $tarball failed."; return 1; }
        dir="$(find -mindepth 1 -maxdepth 1 -type d)"
        [[ -d "$dir" ]] || { err "couldn't find unpacked clang directory"; return 1; }
        [[ -d "$libclang_root" ]] && execute "sudo rm -rf -- $libclang_root"
        execute "mv $dir $libclang_root"

        execute "popd"
        execute "sudo rm -rf $tmpdir"

        return 0
    }

    # sanity
    if ! [[ -d "$HOME/.vim/bundle/YouCompleteMe" ]]; then
        err "expected vim plugin YouCompleteMe to be already pulled"
        err "you're either missing vimrc conf or haven't started vim yet (first start pulls all the plugins)."
        err
        return 1
    fi

    [[ -d "$ycm_root" ]] || execute "mkdir $ycm_root"

    # first make sure we have libclang:
    if [[ -d "$libclang_root" ]]; then
        if ! confirm "found existing libclang at ${libclang_root}; use this one? (answering 'no' will fetch new version)"; then
            __fetch_libclang || { err "fetching libclang failed; aborting YCM installation."; return 1; }
        fi
    else
        __fetch_libclang || { err "fetching libclang failed; aborting YCM installation."; return 1; }
    fi

    # clean previous builddir, if existing:
    [[ -d "$ycm_build_root" ]] && execute "sudo rm -rf -- $ycm_build_root"

    execute "mkdir $ycm_build_root"
    execute "pushd $ycm_build_root"
    execute "cmake -G 'Unix Makefiles' \
        -DPATH_TO_LLVM_ROOT=$libclang_root \
        . \
        ~/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp \
    "
    execute 'cmake --build . --target ycm_support_libs --config Release'
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
        xfonts-75dpi{,-transcoded}
        xfonts-100dpi{,-transcoded}
        xfonts-mplus
        xfonts-bitmap-mule
        xfonts-base
        fontforge
    '

    # TODO: guess we can't use xset when xserver is not yet running:
    #execute "xset +fp ~/.fonts"
    #execute "mkfontscale ~/.fonts"
    #execute "mkfontdir ~/.fonts"
    #execute "pushd ~/.fonts"

    ## also install fonts in sub-dirs:
    #for dir in * ; do
        #if [[ -d "$dir" ]]; then
            #execute "pushd $dir"
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

    block1=(
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
        curl
        lshw
    )

    block2=(
        jq
        dnsutils
        glances
        htop
        tkremind
        remind
        tree
        flashplugin-nonfree
        htpdate
        gdebi
        synaptic
        apt-show-versions
        apt-xapian-index
        mercurial
        git
        git-flow
        zenity
        msmtp
        rsync
        gparted
        network-manager
        network-manager-gnome
        gsimplecal
        gnome-disk-utility
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
    )


    # fyi:
        #- [gnome-keyring???-installi vaid siis, kui mingi jama]
        #- !! gksu no moar recommended; pkexec advised; to use pkexec, you need to define its
        #     action in /usr/share/polkit-1/actions.

    block3=(
        iceweasel
        icedove
        rxvt-unicode-256color
        mopidy
        mopidy-soundcloud
        mopidy-spotify
        mopidy-youtube
        mpc
        ncmpcpp
        geany
        libreoffice
        calibre
        zathura
        mplayer2
        smplayer
        gimp
        feh
        sxiv
        geeqie
        imagemagick
        xsel
        xclip
        exuberant-ctags
        shellcheck
        ranger
        spacefm
        screenfetch
        scrot
        mediainfo
        lynx
        tmux
        powerline
        libxml2-utils
        pidgin
        filezilla
        etckeeper
        lxrandr
        transmission
        transmission-remote-cli
    )

    block4=(
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
    )

    for block in \
            block1 \
            block2 \
            block3 \
            block4 \
                ; do
        install_block "$(eval echo "\${$block[@]}")" "${extra_apt_params[$block]}"
    done


    if [[ "$MODE" == work ]]; then
        install_block '
            samba-common-bin
            davmail
            ruby-dev
            vagrant
            virtualbox
            puppet
        '
    fi
}


# offers to install nvidia drivers, if NVIDIA card is detected
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
    local list_to_install extra_apt_params packages_not_found exit_sig exit_sig_tmp packages_not_found pkg

    list_to_install=( $1 )
    extra_apt_params="$2"  # optional
    packages_not_found=()

    report "installing these packages:\n${list_to_install[*]}\n"

    # extract packages, which, for whatever reason, cannot be installed:
    for pkg in ${list_to_install[*]}; do
        if [[ -z "$(apt-cache search  --names-only "^$pkg\$")" ]]; then
            packages_not_found+=( $pkg )
            continue
        fi
        execute "sudo apt-get -qq --dry-run install $extra_apt_params $pkg" || packages_not_found+=( $pkg )
    done

    if [[ -n "${packages_not_found[*]}" ]]; then
        err "either these packages could not be found from the repo, or some other issue occurred; skipping installing these packages. this will be logged:"
        err "${packages_not_found[*]}"

        list_to_install=( $(remove_items_from_list "${list_to_install[*]}" "${packages_not_found[*]}") )
        PACKAGES_IGNORED_TO_INSTALL+=( ${packages_not_found[*]} )
        exit_sig=3
    fi

    if [[ -z "${list_to_install[*]}" ]]; then
        err "all packages got removed. skipping install block."
        return 1
    fi

    sleep 1  # just in case sleep for a bit
    execute "sudo apt-get --yes install $extra_apt_params ${list_to_install[*]}"
    exit_sig_tmp=$?

    [[ -n "$exit_sig" ]] && return $exit_sig || return $exit_sig_tmp
}


# returns false, if there's an available package with given value in its name, and
# user opts not to build the package, but later install it from the repo by himself.
function should_build_if_avail_in_repo() {
    local package_name packages

    package_name="$1"

    packages="$(apt-cache search --names-only "$package_name")" || { err; return 1; }
    if [[ -n "$packages" ]]; then
        report "FYI, these packages with \"$package_name\" in them are available in repo:\n"
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

    while true; do
        select_items "full-install single-task" 1

        if [[ -n "$__SELECTED_ITEMS" ]]; then
            break
        else
            confirm "no items were selected; exit?" && return || continue
        fi
    done

    case "$__SELECTED_ITEMS" in
        "full-install" ) full_install ;;
        "single-task"  ) choose_single_task ;;
    esac
}


# basically offers steps from setup() & install_progs():
function choose_single_task() {
    local choices

    LOGGING_LVL=1

    # need to assume .bash_env_vars are there:
    if [[ -f "$SHELL_ENVS" ]]; then
        execute "source $SHELL_ENVS"
    else
        err "expected \"$SHELL_ENVS\" to exist; note that some configuration might be missing."
    fi

    choices=(
        generate_key
        switch_jdk_versions
        setup_homesick
        setup_config_files
        setup_SSID_checker
        install_deps
        setup_dirs
        install_fonts
        upgrade_kernel
        install_nvidia
        install_webdev
        install_from_repo
        install_laptop_deps
        install_ssh_server_or_client
        install_nfs_server_or_client
        __choose_prog_to_build
    )

    report "what do you want to do?"

    while true; do
        select_items "${choices[*]}" 1

        if [[ -z "$__SELECTED_ITEMS" ]]; then
            confirm "no items were selected; exit?" && break || continue
        fi

        $__SELECTED_ITEMS
    done
}


# meta-function;
# offerst steps from install_own_builds():
function __choose_prog_to_build() {
    local choices

    choices=(
        install_vim
        install_YCM
        install_keepassx
        install_copyq
        install_synergy
        install_dwm
        install_oracle_jdk
        install_skype
        install_altiris
        install_symantec_endpoint_security
    )

    report "what do you want to build/install?"

    while true; do
        select_items "${choices[*]}" 1

        if [[ -z "$__SELECTED_ITEMS" ]]; then
            confirm "no items were selected; return to previous menu?" && break || continue
        fi

        $__SELECTED_ITEMS
    done
}


function full_install() {

    LOGGING_LVL=10

    setup

    execute "sudo apt-get --yes update"
    upgrade_kernel
    install_fonts  # has to be after apt has been updated
    install_progs
    setup_SSID_checker  # has to come after install_progs; otherwise NM wrapper dir won't be present
    install_deps
    install_ssh_server_or_client
    install_nfs_server_or_client
}


function install_ssh_server_or_client() {
    report "what do you want to do?"

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
    report "what do you want to do?"

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
    msg="$1"

    [[ -n "$msg" ]] && msg="\n$msg"

    while true; do
        [[ -n "$msg" ]] && echo -e "$msg"
        read yno
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

    msg="$1"
    caller_name="$2" # OPTIONAL

    [[ "$LOGGING_LVL" -ge 10 ]] && echo -e "    ERR LOG: $msg" >> "$EXECUTION_LOG"
    echo -e "${COLORS[RED]}${caller_name:-"error"}:${COLORS[OFF]} ${msg:-"Abort"}" 1>&2
}


function report() {
    local msg caller_name

    msg="$1"
    caller_name="$2" # OPTIONAL

    [[ "$LOGGING_LVL" -ge 10 ]] && echo -e "OK LOG: $msg" >> "$EXECUTION_LOG"
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


function is_ssh_setup() {
    [[ -f "$PRIVATE_KEY_LOC" ]] && return 0 || return 1
}


function check_connection() {
    local timeout ip

    timeout=5  # in seconds
    ip="google.com"

    # Check whether the client is connected to the internet:
    wget -q --spider --timeout=$timeout -- "$ip" > /dev/null 2>&1  # works in networks where ping is not allowed
    return $?
}


function generate_key() {
    local mail

    if is_ssh_setup; then
        confirm "key @ $PRIVATE_KEY_LOC already exists; still generate key?" || return 1
    fi

    if ! command -v ssh-keygen >/dev/null; then
        err "ssh-keygen is not installed; won't generate ssh key."
        return 1
    fi

    report "generating ssh key..."
    report "enter your mail (eg \"username@server.com\"):"
    read mail

    execute "ssh-keygen -t rsa -b 4096 -C \"$mail\" -f $PRIVATE_KEY_LOC"
}


function execute() {
    local cmd exit_sig

    cmd="$1"

    echo -e "--> executing \"$cmd\""
    # TODO: collect and log stderr?
    eval "$cmd"
    exit_sig=$?

    if [[ "$exit_sig" -ne 0 ]]; then
        [[ "$LOGGING_LVL" -ge 1 ]] && echo -e "    ERR CMD: \"$cmd\" (exited with code $exit_sig)" >> "$EXECUTION_LOG"
        return $exit_sig
    fi

    [[ "$LOGGING_LVL" -ge 10 ]] && echo "OK CMD: $cmd" >> "$EXECUTION_LOG"
    return 0
}


function select_items() {
    local DMENU nr_of_dmenu_vertical_lines dmenurc options options_dmenu i prompt msg choices num is_single_selection selections

    # original version stolen from http://serverfault.com/a/298312
    options=( $1 )
    is_single_selection="$2"

    dmenurc="$HOME/.dmenurc"
    nr_of_dmenu_vertical_lines=40
    selections=()

    [[ -r "$dmenurc" ]] && source "$dmenurc" || DMENU="dmenu -i "

    function __menu() {
        local i

        echo -e "\n---------------------"
        echo "Available options:"
        for i in "${!options[@]}"; do
            printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
        done
        [[ "$msg" ]] && echo "$msg"; :
    }

    if [[ "$is_single_selection" -eq 1 ]]; then
        if [[ -n "$DISPLAY" ]] && command -v dmenu > /dev/null 2>&1; then
            for i in ${options[*]}; do
                options_dmenu+="$i\n"
            done
            __SELECTED_ITEMS="$(echo -e "$options_dmenu" | $DMENU -l $nr_of_dmenu_vertical_lines -p 'select item')"
            return
        fi
        prompt="Check an option, only 1 item can be selected (again to uncheck, ENTER when done): "
    else
        prompt="Check an option, multiple items allowed (again to uncheck, ENTER when done): "
    fi

    while __menu && read -rp "$prompt" num && [[ "$num" ]]; do
        [[ "$num" != *[![:digit:]]* ]] &&
        (( num > 0 && num <= ${#options[@]} )) ||
        { msg="Invalid option: $num"; continue; }
        ((num--)); msg="${options[num]} was ${choices[num]:+un}checked"

        if [[ "$is_single_selection" -eq 1 ]]; then
            # un-select others to enforce single item only:
            for i in "${!choices[@]}"; do
                [[ "$i" -ne "$num" ]] && choices[$i]=""
            done
        fi

        [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
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

    orig_list=( $1 )
    elements_to_remove=( $2 )

    for i in "${!orig_list[@]}"; do
        for j in "${elements_to_remove[@]}"; do
            [[ "$j" == "${orig_list[$i]}" ]] && unset orig_list[$i]
        done
    done

    echo "${orig_list[*]}"
}


function extract() {
    local file="$*"

    if [[ -z "$file" ]]; then
        err "gimme file to extract plz." "$FUNCNAME"
        return 1
    elif [[ ! -f "$file" || ! -r "$file" ]]; then
        err "'$file' is not a regular file or read rights not granted." "$FUNCNAME"
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
    [[ "$HOSTNAME" == server* ]] && return 0 || return 1
}


# Checks whether system is a laptop.
#
# @returns {bool}   true if system is a laptop.
function is_laptop() {
    local file pwr_supply_dir
    pwr_supply_dir="/sys/class/power_supply"

    # sanity:
    [[ -d "$pwr_supply_dir" ]] || { err "$pwr_supply_dir is not a valid dir! cannot decide if we're a laptop; assuming we're not. abort." "$FUNCNAME"; sleep 5; return 1; }

    while IFS= read -r -d '' file; do
        [[ "$file" == "${pwr_supply_dir}/BAT"* ]] && return 0
    done <   <(find "$pwr_supply_dir" -maxdepth 1 -mindepth 1 -print0)

    return 1
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


function __is_work() {
    [[ "$HOSTNAME" == "$WORK_DESKTOP_HOSTNAME" || "$HOSTNAME" == "$WORK_LAPTOP_HOSTNAME" ]] \
            && return 0 \
            || return 1
}


function cleanup() {
    if [[ -n "${PACKAGES_IGNORED_TO_INSTALL[*]}" ]]; then
        echo -e "    ERR INSTALL: ignored installing these packages: \"${PACKAGES_IGNORED_TO_INSTALL[*]}\"" >> "$EXECUTION_LOG"
    fi

    if [[ -e "$EXECUTION_LOG" ]]; then
        sed -i '/^\s*$/d' "$EXECUTION_LOG"  # strip empty lines

        echo -e "\n\n___________________________________________"
        echo -e "\tscript execution log can be found at \"$EXECUTION_LOG\""
        if grep -q '    ERR' "$EXECUTION_LOG"; then
            echo -e "${COLORS[RED]}    NOTE: log contains errors.${COLORS[OFF]}"
        fi
        echo -e "___________________________________________"
    fi
}


#----------------------------
#---  Script entry point  ---
#----------------------------
MODE="$1"   # work | personal

[[ "$EUID" -eq 0 ]] && { err "don't run as root."; exit 1; }
trap "cleanup; exit" EXIT HUP INT QUIT PIPE TERM;

# ask for the admin password upfront:
report "enter sudo password:"
sudo -v || { clear; err "is user in sudoers file? is sudo installed? if not, then \"su && apt-get install sudo\""; exit 2; }
clear

# keep-alive: update existing `sudo` time stamp
while true; do sudo -n true; sleep 30; kill -0 "$$" || exit; done 2>/dev/null &

check_dependencies
validate_and_init
choose_step

exit
