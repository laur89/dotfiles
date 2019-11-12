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
    * *Note*: sometimes the daily images are broken, verify build is passing [here](https://d-i.debian.org/daily-images/daily-build-overview.html)
      before downloading.
    * If you're installing on a laptop/wifi and need firmware, you might be better
      off with these images:
          http://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/weekly-builds/amd64/iso-cd/
          ([shortcut](http://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/weekly-builds/amd64/iso-cd/firmware-testing-amd64-netinst.iso))
          OR _daily_ sid (dunno, couldn't find daily testing): http://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/daily-builds/sid_d-i/current/amd64/iso-cd/
          ([shortcut](http://cdimage.debian.org/cdimage/unofficial/non-free/cd-including-firmware/daily-builds/sid_d-i/current/amd64/iso-cd/firmware-testing-amd64-netinst.iso))

1. optionally preseed the installation (`esc` when graphical menu appears)

```
    auto url=http(s)://webserver/path/preseed.cfg
    debian-installer/allow_unauthenticated_ssl=true
    hostname=myhostname domain=internal.yourdomain.tld
    passwd/root-password=r00tpass
    passwd/root-password-again=r00tpass
    passwd/user-fullname="Full Name"
    passwd/username=username
    passwd/user-password=userpass
    passwd/user-password-again=userpass`
```

1. wget https://github.com/laur89/dotfiles/raw/master/.bootstrap/install_system.sh
    * or `wget https://github.com/laur89/dotfiles/raw/develop/.bootstrap/install_system.sh`
      for develop branch.
1. `chmod +x install_system.sh`
1. install sudo, if not already installed:
    * su
    * apt-get install sudo
1. add your user to sudo group:
    * `adduser  YOUR_USERNAME  sudo`    (and logout + login afterwards!)
1. sudo apt-get update
1. execute script:
    * `./install_system.sh -F personal|work`
    * optionally pass `-N` option for non-interactive (ie standalone) mode

### Single task:

This mode is intended to be used througout the system lifetime post-fullinstall.
It provides maintenance/management options, such as
* generating ssh key
* switching active jdk versions
* upgrading kernel
* installing various drivers
* installing the base package set
* build and/or install software (such as vim, copyq, oracle jdk)

### Update:

This mode is to be ran periodically to build/install software; note it also includes
non-standard sources, such as github releases/ pages, and being directly built from
source.

### TODO

1. delay homeshick repos' https->ssh change to later stages; otherwise
   if we need to restart installation, pull can fail due to missing ssh
   keys or port 22 being blocked (and relevant git config still not in place);
