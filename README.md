LA's Debian netinstall base setup
=================================

Pre-requisities:
* Debian testing release netinstall
* media/data mountpoint mounted at /data

Notes:
*  this setup is heavily dependent on the system configuration found in numerous
homeshick castles. Some of them are publicly not accessible, so your milage
WILL vary.

Installation
------------

The installation script under .bootstrap provides setup logic intended to be run on
fresh Debian netinstall installation. It also offers a possibility to run one of the
steps separately apart from the full installation mode.

### Full install:

1. Install Debian testing release netinstall (in reality, any Debian base distro
   should work fine).
    * can be found from https://www.debian.org/devel/debian-installer/
    * (or https://cdimage.debian.org/cdimage/daily-builds/daily/arch-latest/amd64/iso-cd/
      more specifically)
1. optionally preseed the installation (`esc` when graphical menu appears)
    * `auto url=http(s)://webserver/path/preseed.cfg
      hostname=myhostname domain=internal.yourdomain.tld
      debian-installer/allow_unauthenticated_ssl=true
      passwd/root-password password r00tpass
      passwd/root-password-again password r00tpass
      passwd/user-fullname string Full Name
      passwd/username string username
      passwd/user-password password userpass
      passwd/user-password-again password userpass`
1. wget https://github.com/laur89/dotfiles/raw/master/.bootstrap/install_system.sh
    * or `wget https://github.com/laur89/dotfiles/raw/develop/.bootstrap/install_system.sh`
      for develop branch.
1. `chmod +x install_system.sh`
1. install sudo, if not already installed:
    * su
    * apt-get install sudo
1. add your user to /etc/sudoers file, by:
    * `echo 'YOUR_USER ALL=(ALL) ALL' >> /etc/sudoers`
    *   or:
    * `adduser  YOUR_USERNAME  sudo`    (and logout + login afterwards)
1. sudo apt-get update
1. execute script:
    * `./install_system.sh  personal|work`
    * select the 'full-install' option.

### Single task:

This mode is intended to be used througout the system lifetime post-fullinstall.
It provides maintenance/management options, such as
* generating ssh key
* switching active jdk versions
* upgrading kernel
* installing various drivers
* installing the base package set
* build and/or install software (such as vim, copyq, oracle jdk)

### TODO

1. delay homeshick repos' https->ssh change to later stages; otherwise
   if we need to restart installation, pull can fail due to missing ssh
   keys or port 22 being blocked (and relevant git config still not in place);
