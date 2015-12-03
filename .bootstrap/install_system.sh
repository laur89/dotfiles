#!/bin/bash
# base version taken from https://github.com/rastasheep/dotfiles/blob/master/script/bootstrap
#
#------------------------
#---   Configuration  ---
#------------------------

#------------------------
#--- Global Variables ---
#------------------------
IS_SSH_SETUP=0  # states whether our ssh keys are present. 1 || 0
MODE=

#------------------------
#--- Global Constants ---
#------------------------
BASE_DATA_DIR="/data"
BASE_DEPS_LOC="$BASE_DATA_DIR/progs/deps"
BASE_HOMESICK_REPOS_LOC="$BASE_DEPS_LOC/homesick/repos"
PRIVATE_CASTLE=  # installation specific private castle location (eg for work or personal)
COMMON_DOTFILES="$BASE_HOMESICK_REPOS_LOC/dotfiles"

declare -A COLORS
COLORS=( \
    [RED]="\033[0;31m" \
    [YELLOW]="\033[0;33m" \
    [OFF]="\033[0m" \
)
#-----------------------
#---    Functions    ---
#-----------------------

function validate() {

    [[ "$MODE" != work && "$MODE" != personal ]] && { err "mode can be either work or personal."; exit 1; }
    check_connection || { err "no internet connection. abort."; exit 1; }

    if [[ "$MODE" == work ]]; then
        PRIVATE_CASTLE="$BASE_HOMESICK_REPOS_LOC/work_dotfiles"
    elif [[ "$MODE" == personal ]]; then
        PRIVATE_CASTLE="$BASE_HOMESICK_REPOS_LOC/personal-dotfiles"
    fi

    # verify we have our key(s) set up and available:
    if isSshSetup; then
        _sanitize_ssh

        if ! ssh-add -l > /dev/null 2>&1; then
            report "ssh keys already there, running ssh-add..."
            execute "ssh-add"
        fi

        IS_SSH_SETUP=1
    else
        report "ssh keys not present at the moment, be prepared to enter user & passwd for private git repos."
        IS_SSH_SETUP=0
    fi
}


# check dependencies required for this installation script
function check_dependencies() {
    local dir

    if ! command -v git >/dev/null; then
        report "git not installed, installing..."
        execute "sudo apt-get -qq install git"  # required for homeshick and fetching deps
        report "...done"
    fi

    # verify required dirs are existing:
    for dir in \
            $BASE_DATA_DIR \
                ; do
        if ! [[ -d "$dir" && -w "$dir" ]]; then
            if confirm "$dir mountpoint does not exist; simply create a directory instead? (answering 'no' aborts script)"; then
                execute "sudo mkdir $dir"
                execute "sudo chmod 777 $dir"
            else
                err "expected \"$dir\" to be already-existing dir. abort"
                exit 1
            fi
        fi
    done
}


function setup_sudoers() {
    local sudoers_dest file

    sudoers_dest="/etc"

    if ! [[ -d "$sudoers_dest" ]]; then
        err "$sudoers_dest is not a dir; skipping sudoers file installation"
        return 1
    fi

    if [[ -f "$COMMON_DOTFILES/backups/sudoers" ]]; then
        execute "sudo cp $COMMON_DOTFILES/backups/sudoers $sudoers_dest/"
    fi
}


function setup_apt() {
    local apt_dir file

    apt_dir="/etc/apt"

    if ! [[ -d "$apt_dir" ]]; then
        err "$apt_dir is not a dir; skipping apt conf installation"
        return 1
    fi

    for file in \
            sources.list \
            preferences \
                ; do
        if [[ -f "$COMMON_DOTFILES/backups/$file" ]]; then
            execute "sudo cp $COMMON_DOTFILES/backups/$file $apt_dir/"
        fi
    done
}


function setup_crontab() {
    local cron_dir

    cron_dir="/etc/cron.d"

    if ! [[ -d "$cron_dir" ]]; then
        err "$cron_dir is not a dir; skipping crontab installation"
        return 1
    fi

    if [[ -f "$PRIVATE_CASTLE/backups/crontab" ]]; then
        execute "sudo cp $PRIVATE_CASTLE/backups/crontab $cron_dir/"
    fi
}


# "deps" as in git repos our system setup depends on
function install_deps() {

    # bash-git-prompt:
    if ! [[ -d "$BASE_DEPS_LOC/bash-git-prompt" ]]; then
        execute "git clone git@github.com:magicmonty/bash-git-prompt.git $BASE_DEPS_LOC/bash-git-prompt"
    else
        execute "pushd $BASE_DEPS_LOC/bash-git-prompt"
        execute "git pull"
        execute "popd"
    fi
}


function setup_dirs() {
    local dir

    # create dirs:
    for dir in \
            $_PERSISTED_TMP \
            $BASE_DATA_DIR/.rsync \
            $BASE_DATA_DIR/progs \
            $BASE_DATA_DIR/progs/deps \
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

    # create logdir:
    if ! [[ -d "$CUSTOM_LOGDIR" ]]; then
        [[ -z "$CUSTOM_LOGDIR" ]] && { err "\$CUSTOM_LOGDIR env var was missing. abort."; exit 1; }

        report "$CUSTOM_LOGDIR does not exist, creating..."
        execute "sudo mkdir $CUSTOM_LOGDIR"
        execute "sudo chmod 777 $CUSTOM_LOGDIR"
    fi
}


function install_homesick() {

    if ! [[ -e "$BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick" ]]; then
        if [[ "$IS_SSH_SETUP" -eq 1 ]]; then
            # ssh keys already ok
            execute "git clone git@github.com:andsens/homeshick.git $BASE_HOMESICK_REPOS_LOC/homeshick"
        else  # keys not present yet
            execute "git clone https://github.com/andsens/homeshick.git $BASE_HOMESICK_REPOS_LOC/homeshick"
        fi
    fi

    if ! [[ -h "$HOME/.homesick" ]]; then
        execute "ln -s $BASE_DEPS_LOC/homesick $HOME/.homesick"
    fi
}


function clone_or_pull_castle() {
    local castle user hub

    castle="$1"
    user="$2"
    hub="$3"  # domain of the git repo, ie github.com/bitbucket.org...

    if [[ -d "$BASE_HOMESICK_REPOS_LOC/$castle" ]]; then
        report "pulling & linking ${castle}"

        execute "$BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick pull $castle"
        execute "$BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick link $castle"

        # just in case verify whether our ssh issue is solved after linking:
        if [[ "$IS_SSH_SETUP" -eq 0 ]] && isSshSetup; then
            _sanitize_ssh
            report "looks like ssh keys are there now, adding with ssh-add..."
            execute "ssh-add"
            IS_SSH_SETUP=1
        fi
    else  # castle doesn't exist, clone it:
        report "cloning ${castle}..."

        if [[ "$IS_SSH_SETUP" -eq 1 ]]; then
            execute "$BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick clone git@$hub:$user/${castle}.git"
        else
            execute "$BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick clone https://${hub}/$user/${castle}.git"

            # just in case verify whether our ssh issue got solved after cloning & subsequent linking:
            if isSshSetup; then
                # change just cloned repo remote from https to ssh:
                execute "pushd $BASE_HOMESICK_REPOS_LOC/$castle"
                execute "git remote set-url origin git@${hub}:$user/${castle}.git"
                execute "popd"

                _sanitize_ssh
                report "looks like ssh keys are there now, adding with ssh-add..."
                execute "ssh-add"
                IS_SSH_SETUP=1
            fi
        fi
    fi
}


function fetch_castles() {

    # first fetch private ones (these might contain missing .ssh or other important dotfiles):
    if [[ "$MODE" == work ]]; then
        clone_or_pull_castle work_dotfiles layr gitlab.williamhill-dev.local
    elif [[ "$MODE" == personal ]]; then
        clone_or_pull_castle personal-dotfiles layr bitbucket.org
    fi

    # common private:
    clone_or_pull_castle private-common layr bitbucket.org

    # common public castles:
    clone_or_pull_castle dotfiles laur89 github.com
    clone_or_pull_castle dwm-setup laur89 github.com
}


function verifyKeysOk() {

    if [[ "$IS_SSH_SETUP" -ne 1 ]]; then
        err "expected ssh keys to be there after cloning repo(s), but weren't."

        if confirm "do you wish to generate set of ssh keys? (answering no will abort the installation)"; then
            generateKeys
        else
            err "abort."
            exit 1
        fi

        if isSshSetup; then
            IS_SSH_SETUP=1
        else
            err "ssh key missing at ~/.ssh/id_rsa. abort"
            exit 1
        fi
    fi
}


function setup_homesick() {

    install_homesick
    fetch_castles
    verifyKeysOk

    # just in case set homeshick remote:
    execute "pushd $BASE_HOMESICK_REPOS_LOC/homeshick"
    execute "git remote set-url origin git@$github.com:andsens/homeshick.git"
    execute "popd"
}


# setup system config files (the ones not living under ~)
function setup_config_files() {

    setup_apt
    setup_crontab
    setup_sudoers
}


function setup() {

    check_dependencies
    setup_homesick
    install_deps
    execute "source $HOME/.bashrc"  # so we get our functions and env vars after dotfiles are pulled in
    setup_dirs  # has to come after .bashrc sourcing so the env vars are in place
    setup_config_files
}


function pre_install_cleanup() {

    report "removing default vim components..."
    execute "sudo apt-get --yes remove vim vim-runtime gvim vim-tiny vim-common vim-gui-common"
}


function install_progs() {

    pre_install_cleanup
    execute "sudo aptitude update"
    install_own_builds
}


function install_own_builds() {

    true
    # vim
    # spacefm?
}


###################
# UTILS (contain no setup-related logic)

function confirm() {
    local msg yno
    msg="$1"

    while true; do
        [[ -n "$msg" ]] && echo -e "$msg"
        read yno
        case "$(echo "$yno" | tr '[:lower:]' '[:upper:]')" in
            Y | YES )
                echo "Ok, continuing...";
                return 0
                ;;
            N | NO )
                echo "Abort.";
                return 1
                ;;
            *)
                err "incorrect answer; try again. (y/n accepted)"
                ;;
        esac
    done
}


function err() {
    local msg caller_name

    msg="$1"
    caller_name="$2" # OPTIONAL

    echo -e "${COLORS[RED]}${caller_name:-"error"}:${COLORS[OFF]} ${msg:-"Abort"}" 1>&2
}


function report() {
    local msg caller_name

    msg="$1"
    caller_name="$2" # OPTIONAL

    echo -e "${COLORS[YELLOW]}${caller_name:-"INFO"}:${COLORS[OFF]} ${msg:-"--info lvl message placeholder--"}"
}


function _sanitize_ssh() {

    if [[ -d "$HOME/.ssh" ]]; then
        err "tried to sanitize ~/.ssh, but dir did not exist. abort."
        exit 1
    fi

    execute "chmod -R u=rwX,g=,o= -- $HOME/.ssh"
}


function isSshSetup() {
    if [[ -f "$HOME/.ssh/id_rsa" ]]; then
        return 0
    fi

    return 1
}


function check_connection() {
    local timeout=5  # in seconds
    local ip="google.com"

    # Check whether the client is connected to the internet:
    if wget -q --spider --timeout=$timeout -- "$ip" > /dev/null 2>&1; then  # works in networks where ping is not allowed
        return 0
    fi

    return 1
}


function generateKeys() {
    local mail

    report "enter your mail:"
    read mail

    report "(if asked for location, leave it to default (ie ~/.ssh/id_rsa))"
    execute "ssh-keygen -t rsa -b 4096 -C \"$mail\""

    report "adding generated key to the ssh-agent..."
    execute "ssh-add $HOME/.ssh/id_rsa"
}


function execute() {
    local cmd exit_code

    cmd="$1"

    $cmd
    exit_code=$?

    if [[ "$exit_code" -ne 0 ]]; then
        err "executing \"$cmd\" returned $exit_code. abort."
        exit 3
    fi
}


#----------------------------
#---  Script entry point  ---
#----------------------------
MODE="$1"   # work | personal

[[ "$EUID" -eq 0 ]] && { err "don't run as sudo."; exit 1; }

# ask for the administrator password upfront
sudo -v || { err "is sudo installed?"; exit 2; }

# Keep-alive: update existing `sudo` time stamp
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

validate
setup
install_progs
