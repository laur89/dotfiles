#!/bin/bash
# base version taken from https://github.com/rastasheep/dotfiles/blob/master/script/bootstrap
#
#------------------------
#---   Configuration  ---
#------------------------
TMPDIR="/tmp"
LLVM_LOC="http://llvm.org/releases/3.7.0/clang+llvm-3.7.0-x86_64-linux-gnu-ubuntu-14.04.tar.xz"
VIM_REPO_LOC="https://github.com/vim/vim.git"
KEEPASS_REPO_LOC="https://github.com/keepassx/keepassx.git"

#------------------------
#--- Global Variables ---
#------------------------
IS_SSH_SETUP=0  # states whether our ssh keys are present. 1 || 0
__SELECTED_ITEMS=
MODE=
PACKAGES_FAILED_TO_INSTALL=()  # list of all packages that failed to install during the setup

#------------------------
#--- Global Constants ---
#------------------------
BASE_DATA_DIR="/data"
BASE_DEPS_LOC="$BASE_DATA_DIR/progs/deps"
BASE_BUILDS_DIR="$BASE_DATA_DIR/progs/custom_builds"
BASE_HOMESICK_REPOS_LOC="$BASE_DEPS_LOC/homesick/repos"
PRIVATE_CASTLE=  # installation specific private castle location (eg for 'work' or 'personal')
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
    local dir prog

    for prog in git wget; do
        if ! command -v $prog >/dev/null; then
            report "$prog not installed, installing..."
            execute "sudo apt-get -qq install $prog"
            report "...done"
        fi
    done

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


function setup_hosts() {
    local hosts_file_dest file

    hosts_file_dest="/etc"

    if ! [[ -d "$hosts_file_dest" ]]; then
        err "$hosts_file_dest is not a dir; skipping hosts file installation"
        return 1
    fi

    if [[ -f "$COMMON_DOTFILES/backups/hosts" ]]; then
        execute "sudo cp $COMMON_DOTFILES/backups/hosts $hosts_file_dest/"
    fi
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
        execute "git clone https://github.com/magicmonty/bash-git-prompt.git $BASE_DEPS_LOC/bash-git-prompt"

        execute "pushd $BASE_DEPS_LOC/bash-git-prompt"
        execute "git remote set-url origin git@$github.com:magicmonty/bash-git-prompt.git"
        execute "popd"
    else
        # if dep was already there, it's safe to assume ssh keys are ok as well.
        execute "pushd $BASE_DEPS_LOC/bash-git-prompt"
        execute "git pull"
        execute "popd"
    fi

    # pearl-ssh perhaps?

    # tmux plugin manager:
    if ! [[ -d "$HOME/.tmux/plugins/tpm" ]]; then
        report "cloning tmux-plugins (plugin manager)..."
        execute "git clone https://github.com/tmux-plugins/tpm.git ~/.tmux/plugins/tpm"
        report "don't forget to install plugins by running <prefix + I> in tmux."

        execute "pushd $HOME/.tmux/plugins/tpm"
        execute "git remote set-url origin git@$github.com:tmux-plugins/tpm.git"
        execute "popd"
    else
        # if dep was already there, it's safe to assume ssh keys are ok as well.
        execute "pushd $HOME/.tmux/plugins/tpm"
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

    # create logdir:
    if ! [[ -d "$CUSTOM_LOGDIR" ]]; then
        [[ -z "$CUSTOM_LOGDIR" ]] && { err "\$CUSTOM_LOGDIR env var was missing. abort."; sleep 5; return 1; }

        report "$CUSTOM_LOGDIR does not exist, creating..."
        execute "sudo mkdir $CUSTOM_LOGDIR"
        execute "sudo chmod 777 $CUSTOM_LOGDIR"
    fi
}


function install_homesick() {

    if ! [[ -e "$BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick" ]]; then
        execute "git clone https://github.com/andsens/homeshick.git $BASE_HOMESICK_REPOS_LOC/homeshick"

        execute "pushd $BASE_HOMESICK_REPOS_LOC/homeshick"
        execute "git remote set-url origin git@$github.com:andsens/homeshick.git"
        execute "popd"
    fi

    # add the link, because homeshick is not installed in its default location (which is $HOME):
    if ! [[ -h "$HOME/.homesick" ]]; then
        execute "ln -s $BASE_DEPS_LOC/homesick $HOME/.homesick"
    fi
}


function clone_or_link_castle() {
    local castle user hub

    castle="$1"
    user="$2"
    hub="$3"  # domain of the git repo, ie github.com/bitbucket.org...

    [[ -z "$castle" || -z "$user" || -z "$hub" ]] && { err "either user, repo or castle name were missing"; sleep 2; return 1; }

    if [[ -d "$BASE_HOMESICK_REPOS_LOC/$castle" ]]; then
        report "$castle already exists; linking..."

        execute "$BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick link $castle"
    else
        report "cloning ${castle}..."

        # note we clone via https, not ssh:
        execute "$BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick clone https://${hub}/$user/${castle}.git"

        # change just cloned repo remote from https to ssh:
        execute "pushd $BASE_HOMESICK_REPOS_LOC/$castle"
        execute "git remote set-url origin git@${hub}:$user/${castle}.git"
        execute "popd"
    fi

    # just in case verify whether our ssh issue got solved after cloning/linking:
    if [[ "$IS_SSH_SETUP" -eq 0 ]] && is_ssh_setup; then
        _sanitize_ssh
        IS_SSH_SETUP=1
    fi
}


function fetch_castles() {
    local castle user hub

    # first fetch private ones (these might contain missing .ssh or other important dotfiles):
    if [[ "$MODE" == work ]]; then
        clone_or_link_castle work_dotfiles layr gitlab.williamhill-dev.local
    elif [[ "$MODE" == personal ]]; then
        clone_or_link_castle personal-dotfiles layr bitbucket.org
    fi

    # common private:
    clone_or_link_castle private-common layr bitbucket.org

    # common public castles:
    clone_or_link_castle dotfiles laur89 github.com

    while true; do
        if confirm "want to clone another castle?"; then
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
        err "didn't find the key at ~/.ssh/id_rsa after generating keys."
    fi
}


function setup_homesick() {
    local https_castles

    install_homesick
    fetch_castles

    # just in case check if any of the castles are still tracking https instead of ssh:
    https_castles="$($BASE_HOMESICK_REPOS_LOC/homeshick/bin/homeshick list | grep '\bhttps://\b')"
    if [[ -n "$https_castles" ]]; then
        report "these homesick castles are still tracking https remotes:"
        echo -e "$https_castles"
    fi
}


# setup system config files (the ones not living under $HOME)
function setup_config_files() {

    setup_apt
    setup_crontab
    setup_sudoers
    setup_hosts
    execute "echo 'source /home/laur/.bash_env_vars' | sudo tee --append /root/.bashrc > /dev/null"
    # TODO:
    #- NW_SSID_checker_wrapper script liiguta /etc/NetworkManager/dispatcher.d/ alla;
}


function setup() {

    check_dependencies
    setup_homesick
    verify_ssh_key
    setup_config_files
    install_deps
    execute "source $HOME/.bash_env_vars"  # so we get our functions and env vars after dotfiles are pulled in
    setup_dirs  # has to come after .bash_env_vars sourcing so the env vars are in place
    setup_fonts
}



function install_progs() {

    execute "sudo apt-get update"
    upgrade_kernel
    install_from_repo
    install_own_builds
}


function upgrade_kernel() {
    local package_line kernels_list is_64_bit

    kernels_list=()
    [[ "$(uname -m)" == x86_64 ]] && is_64_bit="amd64"

    # install kernel meta-packages:
    # NOTE: these meta-packages only required, if using non-stable debian:
    if [[ "$is_64_bit" ]]; then
        install_block " \
            linux-image-amd64 \
            linux-headers-amd64 \
        "
    else
        report "apparently we're not running 64bit system. make sure it's correct. skipping kernel meta-package installation."
        sleep 5
    fi

    # search for available kernel images:
    while IFS= read -r package_line; do
        kernels_list+=( $(echo "$package_line" | cut -d' ' -f1) )
    done <   <(apt-cache search  --names-only "^linux-image-[0-9+]\.[0-9+]\.[0-9+].*$is_64_bit\$" | sort -n)

    [[ -z "${kernels_list[@]}" ]] && { err "apt-cache search didn't find any kernel images. skipping kernel upgrade"; sleep 5; return 1; }

    while true; do
        report "current kernel: $(uname -r)"
        report "select kernel to install: (select none to skip)\n"
        select_items "${kernels_list[*]}" 1

        if [[ -n "$__SELECTED_ITEMS" ]]; then
            report "installing ${__SELECTED_ITEMS}..."
            execute "sudo apt-get -qq install $__SELECTED_ITEMS"
        else
            confirm "no items were selected; skip kernel upgrade?" && break
        fi
    done

    unset __SELECTED_ITEMS
}


function install_own_builds() {

    install_vim
    install_keepassx
    install_dwm
}


function install_keepassx() {
    report "setting up keepassx..."

    # first find whether we have deb packages from other times:
    if confirm "do you wish to install keepassx from our previous build .deb package, if available?"; then
        install_from_deb keepassx || build_and_install_keepassx
    else
        build_and_install_keepassx
    fi
}


function create_deb_install_and_store() {
    local deb_file

    execute "sudo checkinstall"

    deb_file="$(find . -type f -name '*.deb')"
    if [[ -f "$deb_file" ]]; then
        report "moving built package \"$deb_file\" to $BASE_BUILDS_DIR"
        execute "mv $deb_file $BASE_BUILDS_DIR/"
    else
        err "couldn't find built package (find found \"$deb_file\")"
    fi
}


function build_and_install_keepassx() {
    # building instructions from https://github.com/keepassx/keepassx
    local tmpdir

    tmpdir="$TMPDIR/keepassx-build-${RANDOM}"
    report "building keepassx..."

    report "installing keepassx build dependencies..."
    install_block " \
        qtbase5-dev \
        libqt5x11extras5-dev \
        qttools5-dev \
        qttools5-dev-tools \
        libgcrypt20-dev \
        zlib1g-dev \
    "
    execute "git clone $KEEPASS_REPO_LOC $tmpdir"

    execute "mkdir $tmpdir/build"
    execute "pushd $tmpdir/build"
    execute "cmake .."
    execute "make"

    create_deb_install_and_store

    execute "popd"
    execute "rm -rf -- $tmpdir"
}


function install_dwm() {
    local build_dir

    build_dir="$HOME/.dwm/w0ngBuild/source6.0"

    clone_or_link_castle dwm-setup laur89 github.com
    [[ -d "$build_dir" ]] || { err "\"$build_dir\" is not a dir. skipping dwm installation"; return 1; }

    report "installing dwm build dependencies..."
    install_block " \
        suckless-tools \
        build-essential \
        libx11-dev \
        libxinerama-dev \
        libpango1.0-dev \
        libxtst-dev \
    "

    execute "pushd $build_dir"
    report "installing dwm..."
    execute "sudo make clean install"
    execute "popd"
}


function install_from_deb() {
    local deb_file count name

    name="$1"

    deb_file="$(find $BASE_BUILDS_DIR -type f -iname "*$name*.deb")"
    [[ "$?" -eq 0 ]] || { report "didn't find any pre-build deb packages for $name; trying to build..."; return 1; }
    count="$(echo "$deb_file" | wc -l)"

    [[ "$count" -gt 1 ]] && {
        report "found $count potential deb packages. select one, or select none to build instead:"

        select_items "$deb_file" 1
        if [[ -n "$__SELECTED_ITEMS" ]]; then
            deb_file="$__SELECTED_ITEMS"
        else
            report "no files selected, building..."
            return 1
        fi
    }

    execute "sudo dpkg -i $deb_file"
}


function install_vim() {
    report "setting up vim..."
    report "removing already installed vim components..."
    execute "sudo apt-get --qq remove vim vim-runtime gvim vim-tiny vim-common vim-gui-common"

    # first find whether we have deb packages from other times:
    if confirm "do you wish to install vim from our previous build .deb package, if available?"; then
        install_from_deb vim || build_and_install_vim
    else
        build_and_install_vim
    fi

    execute "sudo ln -s /home/laur/.vimrc /root/"
    execute "sudo ln -s /home/laur/.vim /root/"
    # link sessions dir, if stored:

    report "launching vim, so the initialization could be done (pulling in plugins et al. simply exit when it's done."
    sleep 4
    vim

    # YCM installation AFTER the first vim launch!
    install_YCM
}


function build_and_install_vim() {
    # building instructions from https://github.com/Valloric/YouCompleteMe/wiki/Building-Vim-from-source
    local tmpdir

    tmpdir="$TMPDIR/vim-build-${RANDOM}"
    report "building vim..."

    report "installing vim build dependencies..."
    install_block " \
        libncurses5-dev \
        libgnome2-dev \
        libgnomeui-dev \
        libgtk2.0-dev \
        libatk1.0-dev \
        libbonoboui2-dev \
        libcairo2-dev \
        libx11-dev \
        libxpm-dev \
        libxt-dev \
        python-dev \
        ruby-dev \
    "
    execute "git clone $VIM_REPO_LOC $tmpdir"
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
    "

    execute "make VIMRUNTIMEDIR=/usr/share/vim/vim74"
    #!(make sure rutimedir is correct; at this moment 74 was)
    create_deb_install_and_store

    execute "popd"
    execute "rm -rf -- $tmpdir"
}


function install_YCM() {
    # note: instructions & info here: https://github.com/Valloric/YouCompleteMe
    local ycm_root libclang_root

    ycm_root="$BASE_BUILDS_DIR/YCM"
    libclang_root="$ycm_root/llvm"

    function fetch_libclang() {
        local tmpdir tarball dir

        tmpdir="$(mktemp "ycm-tempdir-XXXXX" -p $TMPDIR)"

        execute "pushd $tmpdir"
        report "fetching $LLVM_LOC"
        execute "wget $LLVM_LOC"
        tarball="$(find -mindepth 1 -maxdepth 1 -type f)" || { err "couldn find downloaded file."; return 1; }
        extract "$tarball"
        dir="$(find -mindepth 1 -maxdepth 1 -type d)" || { err "couldn find unpacked directory"; return 1; }
        [[ -d "$libclang_root" ]] && rm -rf -- "$libclang_root"
        execute "mv $dir $libclang_root"

        execute "popd"
        execute "rm -rf $tmpdir"
    }

    #sanity
    if ! [[ -d "$HOME/.vim/bundle/YouCompleteMe" ]]; then
        err "expected vim plugin YouCompleteMe to be already pulled"
        err "you're either missing vimrc conf or haven't started vim yet (first start pulls all the plugins)."
        err
        return 1
    fi

    [[ -d "$ycm_root" ]] || execute "mkdir $ycm_root"

    # first make sure we have libclang:
    if [[ -d "$libclang_root" ]]; then
        if ! confirm "found existing libclang at ${libclang_root}; use this one? (answering no will fetch new version)"; then
            fetch_libclang
        fi
    else
        fetch_libclang
    fi

    # clean previous builddir, if existing:
    [[ -d "$ycm_root/ycm_build" ]] && rm -rf -- "$ycm_root/ycm_build"

    execute "mkdir $ycm_root/ycm_build"
    execute "pushd $ycm_root/ycm_build"
    execute "cmake -G \"Unix Makefiles\" \
        -DPATH_TO_LLVM_ROOT=$libclang_root \
        . \
        ~/.vim/bundle/YouCompleteMe/third_party/ycmd/cpp \
    "
    execute "cmake --build . --target ycm_support_libs --config Release"
    execute "popd"

    unset fetch_libclang
}


function setup_fonts() {
    report "installing & setting up fonts..."

    install_block " \
        ttf-dejavu \
        ttf-liberation \
        ttf-mscorefonts-installer \
        xfonts-terminus \
        xfonts-75dpi{,-transcoded} xfonts-100dpi{,-transcoded} \
        xfonts-mplus \
        xfonts-bitmap-mule \
        xfonts-base \
        fontforge \
    "

    execute "pushd $HOME/.fonts"
    execute "fc-cache -fv"
    execute "mkfontscale ~/.fonts"
    execute "mkfontdir ~/.fonts"
}


# majority of packages get installed at this point
function install_from_repo() {
    local block block1 block2 block3 block4 extra_apt_params

    declare -A extra_apt_params
    extra_apt_params=( \
        block2=["--no-install-recommends"] \
    )

    block1=( \
        xorg \
        sudo \
        alsa-base \
        alsa-utils \
        xfce4-volumed \
        xfce4-notifyd \
        xscreensaver \
        smartmontools \
        gksu \
        pm-utils \
        ntfs-3g \
        dosfstools \
        checkinstall \
        build-essential \
        cmake \
        python3 \
        python3-dev \
        python3-pip \
        python-dev \
        python-pip \
        curl \
        lshw \
    )

    block2=( \
        jq \
        dnsutils \
        glances \
        tkremind \
        remind \
        qt4-qtconfig \
        tree \
        flashplugin-nonfree \
        lxappearance \
        htpdate \
        apt-show-versions \
        apt-xapian-index \
        synaptic \
        mercurial \
        git \
        htop \
        zenity \
        msmtp \
        rsync \
        gparted \
        network-manager \
        network-manager-gnome \
        gsimplecal \
        gnome-disk-utility \
        galculator \
        file-roller \
        rar \
        unrar \
        p7zip \
        dos2unix \
        gtk2-engines-murrine \
        gtk2-engines-pixbuf \
    )


    # fyi:
        #- [gnome-keyring???-installi vaid siis, kui mingi jama]
        #- !! gksu no moar recommended; pkexec advised; to use pkexec, you need to define its
        #     action in /usr/share/polkit-1/actions.

    block3=( \
        iceweasel \
        icedove \
        rxvt-unicode-256color \
        mopidy \
        mpc \
        ncmpcpp \
        geany \
        libreoffice \
        zathura \
        mplayer2 \
        smplayer \
        gimp \
        feh \
        sxiv \
        geeqie \
        imagemagick \
        calibre \
        xsel \
        exuberant-ctags \
        shellcheck \
        ranger \
        spacefm \
        screenfetch \
        scrot \
        mediainfo \
        lynx \
        tmux \
        powerline \
        libxm12-utils \
        pidgin \
        filezilla \
        xclip \
        gdebi \
        etckeeper \
        lxrandr \
        transmission \
        transmission-remote-cli \
    )

    block4=( \
        mutt-patched \
        notmuch-mutt \
        notmuch \
        abook \
        atool \
        urlview \
        silversearcher-ag \
        isync \
        cowsay \
        toilet \
    )

    for block in \
            block1 \
            block2 \
            block3 \
            block4 \
                ; do
        install_block "$(eval echo "\${$block[@]}")" "${extra_apt_params[$block]}"
    done
}


# provides the possibility to cherry-pick out packages.
# this might come in handy, if few of the packages cannot be found.
function install_block() {
    local list_to_install ignored_packages extra_apt_params

    list_to_install=( $1 )
    extra_apt_params="$2"  # optional

    report "installing these packages:\n${list_to_install[*]}\n"
    unset ignored_packages

    while true; do
        if [[ -n "${ignored_packages[*]}" ]]; then
            report "retrying installation; all ignored packages so far:\n${ignored_packages[*]}\n"
        fi

        sudo apt-get -qq install $extra_apt_params ${list_to_install[*]} && break || {
            if confirm "\n  apparently installation failed. want to de-select some of the packages and try again?"; then

                while true; do
                    select_items "${list_to_install[*]}"
                    if [[ -n "$__SELECTED_ITEMS" ]]; then
                        if confirm "\nignoring these additional packages: ${__SELECTED_ITEMS}; ok?"; then
                            ignored_packages+=" $__SELECTED_ITEMS "
                            PACKAGES_FAILED_TO_INSTALL+=( $__SELECTED_ITEMS )
                            list_to_install=( $(remove_items_from_list "${list_to_install[*]}" "$__SELECTED_ITEMS") )
                            break
                        fi
                    else
                        report "you didn't de-select any packages; will re-try anyways..."
                        sleep 3
                        break
                    fi
                done
            else
                PACKAGES_FAILED_TO_INSTALL+=( ${list_to_install[*]} )

                report "all packages from this block were skipped. this will be reported"
                sleep 5
                break
            fi
        }

        unset __SELECTED_ITEMS
    done
}


###################
# UTILS (contains no setup-related logic)
###################

function confirm() {
    local msg yno
    msg="$1"

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

    if ! [[ -d "$HOME/.ssh" ]]; then
        err "tried to sanitize ~/.ssh, but dir did not exist."
        return 1
    fi

    execute "chmod -R u=rwX,g=,o= -- $HOME/.ssh"
}


function is_ssh_setup() {
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


function generate_key() {
    local mail

    report "generating ssh key..."
    report "enter your mail:"
    read mail

    report "(if asked for location, leave it to default (ie ~/.ssh/id_rsa))"
    execute "ssh-keygen -t rsa -b 4096 -C \"$mail\""
}


function execute() {
    local cmd exit_code exit_sig

    cmd="$1"
    exit_code="$2"  # only pass exit code to exit with if script should abort on unsuccessful execution

    $cmd
    exit_sig=$?

    if [[ "$exit_sig" -ne 0 ]]; then
        if [[ -n "$exit_code" ]]; then
            err "executing \"$cmd\" returned $exit_sig. abort."
            exit "$exit_code"
        else
            return 1
        fi
    fi

    return 0
}


function select_items() {
    local options i prompt msg choices num is_single_selection selections

    # original version stolen from http://serverfault.com/a/298312
    options=( $1 )
    is_single_selection="$2"

    function __menu() {
        local i

        echo "Avaliable options:"
        for i in "${!options[@]}"; do
            printf "%3d%s) %s\n" $((i+1)) "${choices[i]:- }" "${options[i]}"
        done
        [[ "$msg" ]] && echo "$msg"; :
    }

    if [[ "$is_single_selection" -eq 1 ]]; then
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
            # un-select others:
            for i in "${!choices[@]}"; do
                [[ "$i" -ne "$num" ]] && choices[$i]=""
            done
        fi

        [[ "${choices[num]}" ]] && choices[num]="" || choices[num]="+"
    done

    for i in "${!options[@]}"; do
        [[ -n "${choices[i]}" ]] && selections+=" ${options[i]} "
    done

    __SELECTED_ITEMS="$selections"

    unset __menu
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
        *.tar.bz2)
                        tar xjf "$file"
                        ;;
        *.tar.gz)
                        tar xzf "$file"
                        ;;
        *.tar.xz)
                        tar xpvf "$file"
                        ;;
        *.bz2)
                        bunzip2 -k -- "$file"
                        ;;
        *.rar)
                        unrar x "$file"
                        ;;
        *.gz)
                        gunzip -kd -- "$file"
                        ;;
        *.tar)          tar xf "$file"
                        ;;
        *.tbz2)         tar xjf "$file"
                        ;;
        *.tgz)          tar xzf "$file"
                        ;;
        *.zip)
                        unzip -- "$file"
                        ;;
        *.7z)
                        7z x -- "$file"
                        ;;
                        # TODO .Z is unverified how and where they'd unpack:
        *.Z)
                        uncompress -- "$file"  ;;
        *)           err "'$file' cannot be extracted; this filetype is not supported." "$FUNCNAME"
                        return 1
                        ;;
    esac
}


#----------------------------
#---  Script entry point  ---
#----------------------------
MODE="$1"   # work | personal

[[ "$EUID" -eq 0 ]] && { err "don't run as sudo."; exit 1; }

# ask for the administrator password upfront
report "enter sudo password:"
sudo -v || { clear; err "is sudo installed?"; exit 2; }
clear

# Keep-alive: update existing `sudo` time stamp
while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &

validate
setup
install_progs
