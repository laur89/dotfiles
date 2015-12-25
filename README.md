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
2. wget https://github.com/laur89/dotfiles/raw/master/.bootstrap/install_system.sh
3. chmod +x install_system.sh
4. install sudo, if not already installed:
    * su
    * apt-get install sudo
    * vim(.tiny) /etc/sudoers
5. add your user to /etc/sudoers file, by:
    * echo 'YOUR_USER ALL=(ALL) ALL' >> /etc/sudoers
    *   or:
    * adduser  YOUR_USERNAME  sudo
6. sudo aptitude update
7. execute script:
    * ./install_system.sh  personal|work
    * select the 'full-install' option.

### Single task:

This mode is intended to be used througout the system lifetime post-fullinstall.
It provides maintenance/management options, such as
    * generating ssh key
    * switching activejdk versions
    * upgrading kernel
    * installing various drivers
    * installing the base package set
    * build and/or install software (such as vim, copyq, oracle jdk)

