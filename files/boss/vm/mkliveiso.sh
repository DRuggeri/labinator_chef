#!/usr/bin/bash

set -e

# https://live-team.pages.debian.net/live-manual/html/live-manual/index.en.html

function usage {
    cat <<EOU
$0 [options] hostname

Options:
-a     autologin root on console
-p     space-separated list of packages to install
-c     directory containing files to put into chroot
-s     script to run in the chroot phase
EOU
    exit 1
}

AUTOLOGIN=0
FILENAME="/var/tmp/live-image-amd64.hybrid.iso"
PACKAGES=""
CHROOTDIR=""
CHROOTSCRIPT=""
while getopts 'af:p:c:s:' opt; do
    case ${opt} in
    a)
        AUTOLOGIN=1
        ;;
    f)
        FILENAME="${OPTARG}"
        ;;
    p)
        PACKAGES="${OPTARG}"
        ;;
    c)
        CHROOTDIR="${OPTARG}"
        ;;
    s)
        CHROOTSCRIPT="${OPTARG}"
        ;;
    esac
done

test -d /var/tmp/live || mkdir /var/tmp/live
cd /var/tmp/live

apt-get update

if [ ! -f /usr/bin/lb ];then
    apt-get remove -y live-build
    apt-get install -y po4a gettext debhelper-compat arch-test debootstrap devscripts
    cd
    test -d live-build || git clone https://salsa.debian.org/live-team/live-build.git
    cd live-build
    git reset --hard bc5b9ca4a32ea6cf79d28e0107b2c27f3fa5bf2a
    dpkg-buildpackage -b -uc -us
    cd ../
    dpkg -i live-build_*_all.deb
    apt-get remove -y po4a gettext debhelper-compat
    apt autoremove -y
fi

rm -rf temporary-working
mkdir temporary-working
cd temporary-working

lb config --apt-indices false --apt-recommends false --distribution stable

for pkg in `echo "${PACKAGES}"`;do
    echo "$pkg" >> ./config/package-lists/live.list.chroot
done

perl -pi -e 's/ quiet splash//g' config/binary
perl -pi -e 's/components/components console=ttyS0/g' config/binary

cp -r /usr/share/live/build/bootloaders/isolinux config/bootloaders/
perl -pi -e 's/timeout [0-9]+/timeout 1/g' config/bootloaders/isolinux/isolinux.cfg

if [ "$AUTOLOGIN" = 1 ];then
    for override in "serial-getty@" "getty@";do
    mkdir -p config/includes.chroot/etc/systemd/system/${override}.service.d/
    echo "[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin root --noclear %I 38400 linux
Type=idle
" > config/includes.chroot/etc/systemd/system/${override}.service.d/override.conf
    done
fi

if [ -n "$CHROOTDIR" -a -d "$CHROOTDIR" ];then
    test -d config/includes.chroot || mkdir config/includes.chroot/
    rsync -a "$CHROOTDIR"/* config/includes.chroot/
fi

if [ -s "$CHROOTSCRIPT" -a -f "$CHROOTSCRIPT" ];then
    cp "$CHROOTSCRIPT" config/hooks/normal/9999-custom-live-script.hook.chroot
    chmod 777 config/hooks/normal/9999-custom-live-script.hook.chroot
fi

time lb build
mv live-image-amd64.hybrid.iso "$FILENAME"