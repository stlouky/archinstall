#!/bin/bash

# arch-installer version
VERSION="v0.4b"

# sleepclear
SLEEP=1

# true / false
TRUE=0
FALSE=1

# return codes
SUCCESS=0
FAILURE=1

# verbose mode - default: quiet
VERBOSE="/dev/null"

# chosen keymap
KEYMAP=""

# set keymap
SET_KEYMAP="1"

# list keymaps
LIST_KEYMAP="2"

# installation mode
INSTALL_MODE=""

# install modes
INSTALL_REPO="1"
INSTALL_LIVE_ISO="2"
INSTALL_BLACKMAN="3"

# colors
BLUE="`tput setaf 6`"
WHITE="`tput setaf 7`"
WHITEB="`tput bold ; tput setaf 7`"
GREEN="`tput setaf 2`"
GREENB="`tput bold ; tput setaf 2`"
RED="`tput setaf 1`"
REDB="`tput bold; tput setaf 1`"
YELLOW="`tput setaf 3`"
YELLOWB="`tput bold ; tput setaf 3`"
BLINK="`tput blink`"
NC="`tput sgr0`"

# chosen keymap
KEYMAP=""

# set keymap
SET_KEYMAP="1"

# list keymaps
LIST_KEYMAP="2"

# network interfaces
NET_IFS=""

# chosen network interface
NET_IF=""

# network configuration mode
NET_CONF_MODE=""

# network configuration modes
NET_CONF_AUTO="1"
NET_CONF_WLAN="2"
NET_CONF_MANUAL="3"
NET_CONF_SKIP="4"

# hostname
HOST_NAME=""

# host ipv4 address
HOST_IPV4=""

# gateway ipv4 address
GATEWAY=""

# subnet mask
SUBNETMASK=""

# broadcast address
BROADCAST=""

# nameserver address
NAMESERVER=""

# LUKS flag
LUKS=""

# avalable hard drive
HD_DEVS=""

# chosen hard drive device
HD_DEV=""

# partition label: gpt or msdos
PART_LABEL=""

# boot partition
BOOT_PART=""

# root partition
ROOT_PART=""

# home partition
HOME_PART=""

# swap partition
SWAP_PART=""

# boot fs type - default: ext4
BOOT_FS_TYPE=""

# root fs type - default: ext4
ROOT_FS_TYPE=""

# home fs type - default: ext4
HOME_FS_TYPE=""

# chroot directory / blackarch linux installation
CHROOT="/mnt"

# normal system user
NORMAL_USER=""

# default ArchLinux repository URL
AR_REPO_URL="https://archlinux.surlyjake.com/archlinux/\$repo/os/\$arch"
AR_REPO_URL="${AR_REPO_URL} http://mirrors.evowise.com/archlinux/\$repo/os/\$arch"
AR_REPO_URL="${AR_REPO_URL} http://mirror.rackspace.com/archlinux/\$repo/os/\$arch"

# X (display + window managers ) setup - default: false
X_SETUP=$FALSE

# VirtualBox setup - default: false
VBOX_SETUP=$FALSE

# VMware setup - default: false
VMWARE_SETUP=$FALSE

# BlackArch Linux tools setup - default: false
BA_TOOLS_SETUP=$FALSE

# wlan ssid
WLAN_SSID=""

# wlan passphrase
WLAN_PASSPHRASE=""

#####################################################################

# make and format root partition
make_root_partition()
{
    
    title "Hard Drive Setup"
    wprintf "[+] Creating ROOT partition"
    printf "\n\n"
    if [ "${ROOT_FS_TYPE}" = "btrfs" ]
        then
            mkfs.${ROOT_FS_TYPE} -f ${ROOT_PART}
        else
            mkfs.${ROOT_FS_TYPE} -F ${ROOT_PART}
    fi
    sleep_clear ${SLEEP}

    return $SUCCESS
}

# create swap partition
make_swap_partition()
{
    title "Hard Drive Setup"

    wprintf "[+] Creating SWAP partition"
    printf "\n\n"
    mkswap "${SWAP_PART}"

    return $SUCCESS
}

make_home_partition()
{
	title "Hard Drive Setup"

	wprintf "[+] Creating HOME partition"
	printf "\n\n"
	mkfs.${HOME_FS_TYPE} -F ${HOME_PART}
}

# make and format boot partition
make_boot_partition()
{
    title "Hard Drive Setup"

    wprintf "[+] Creating BOOT partition"
    printf "\n\n"
    if [ "${PART_LABEL}" = "gpt" ]
    then
        mkfs.fat -F32 ${BOOT_PART}
    else
        mkfs.${BOOT_FS_TYPE} -F ${BOOT_PART}
    fi

    return $SUCCESS
}

# make and format partitions
make_partitions()
{
    make_boot_partition
    sleep_clear ${SLEEP}

    make_root_partition
    sleep_clear ${SLEEP}

    make_home_partition
    sleep_clear ${SLEEP}

    if [ "${SWAP_PART}" != "none" ]
    then
        make_swap_partition
        sleep_clear ${SLEEP}
    fi

    return $SUCCESS
}

# zero out partition if needed/chosen
zero_part()
{
    if confirm "Hard Drive Setup" "[?] Start with an in-memory zeroed \
partition table [y/n]: "
    then
        cfdisk -z "${HD_DEV}"
        sync
    else
        cfdisk "${HD_DEV}"
        sync
    fi

    return $SUCCESS
}

# ask user to create partitions using cfdisk
ask_cfdisk()
{
    if confirm "Hard Drive Setup" "[?] Create partitions with cfdisk (root and \
boot, optional swap) [y/n]: "
    then
        clear
        zero_part
    else
        echo
        err "Are you kidding me? No partitions no fun!"
    fi

    return $SUCCESS
}

# ask user for VirtualBox modules+utils setup
ask_vbox_setup()
{
    if confirm "Arch Linux Setup" "[?] Setup VirtualBox modules [y/n]: "
    then
        VBOX_SETUP=$TRUE
    fi

    return $SUCCESS
}

# setup virtualbox utils
setup_vbox_utils()
{
    title "Arch Linux Setup"

    wprintf "[+] Setting up VirtualBox utils"
    printf "\n\n"

    chroot ${CHROOT} pacman -S virtualbox-guest-utils \
        --force --needed --noconfirm

    chroot ${CHROOT} systemctl enable vboxservice
    chroot ${CHROOT} systemctl enable vboxadd
    chroot ${CHROOT} systemctl enable vboxadd-service
    chroot ${CHROOT} systemctl enable vboxadd-x11

    printf "vboxguest\nvboxsf\nvboxvideo\n" \
        > "${CHROOT}/etc/modules-load.d/vbox.conf"

    return $SUCCESS
}

# add user to newly created groups
update_user_groups()
{
    title "BlackArch Linux Setup"

    wprintf "[+] Adding user '${NORMAL_USER}' to groups"
    printf "\n\n"

    # TODO: more to add here
    chroot ${CHROOT} \
        usermod -G ${NORMAL_USER},video,audio,vboxsf

    return $SUCCESS
}

# enable color mode in pacman.conf
enable_pacman_color()
{
    path="${1}"

    if [ "${path}" = "chroot" ]
    then
        path="${CHROOT}"
    else
        path=""
    fi

    title "Pacman Setup"

    wprintf "[+] Enabling color mode"
    printf "\n\n"

    sed -i 's/^#Color/Color/' ${path}/etc/pacman.conf

    return $SUCCESS
}

# enable multilib in pacman.conf if x86_64 present
enable_pacman_multilib()
{
    path="${1}"

    if [ "${path}" = "chroot" ]
    then
        path="${CHROOT}"
    else
        path=""
    fi

    title "Pacman Setup"

    if [ "`uname -m`" = "x86_64" ]
    then
        wprintf "[+] Enabling multilib support"
        printf "\n\n"
        if grep -q "#\[multilib\]" ${path}/etc/pacman.conf
        then
            # it exists but commented
            sed -i '/\[multilib\]/{ s/^#//; n; s/^#//; }' ${path}/etc/pacman.conf
        elif ! grep -q "\[multilib\]" ${path}/etc/pacman.conf
        then
            # it does not exist at all
            printf "[multilib]\nInclude = /etc/pacman.d/mirrorlist\n" \
                >> ${path}/etc/pacman.conf
        fi
    fi

    return $SUCCESS
}

# setup window managers
setup_window_managers()
{
    title "BlackArch Linux Setup"

    wprintf "[+] Setting up window managers"
    printf "\n"

    while true
    do
        printf "
    1. I3-wm
    2. Dwm
    3. xfce
    8. All of the above
    \n"
        sleep 2
        wprintf "[?] Choose an option [8]: "
        read choice
        echo
        case $choice in
            1)
				chroot ${CHROOT} pacman -S i3 --needed --force --noconfirm
                break
                ;;
               
            2)
                chroot ${CHROOT} pacman -S dwm --needed --force --noconfirm
                break
                ;;
            3)
                chroot ${CHROOT} pacman -S xfce4 exo garcon gtk-xfce-engine thunar \
                	 tumbler xfce4-appfinder xfce4-panel  xfce4-power-manager \
                	 xfce4-session xfce4-settings xfce4-terminal xfconf xfdesktop xfwm4 \
                	 xfwm4-themes --needed --force --noconfirm
			    break
			    ;;
           
            *)
                chroot ${CHROOT} pacman -S i3 xfce4 dwm exo garcon gtk-xfce-engine thunar
                     tumbler xfce4-appfinder xfce4-panel  xfce4-power-manager \
                     xfce4-session xfce4-settings xfce4-terminal xfconf xfdesktop xfwm4 \
                     xfwm4-themes dmenu --needed --force --noconfirm
                break
                ;;
        esac
    done
    sleep 30

    return $SUCCESS
}

# setup display manager
setup_display_manager()
{
    title "Arch Linux Setup"

    wprintf "[+] Setting up Slim"
    printf "\n"

    printf "
    > slim
    \n"

    sleep 2

    # install lxdm packages
    chroot ${CHROOT} pacman -S slim archlinux-themes-slim slim-themes --needed --force --noconfirm

    # config files

    # enable in systemd
    chroot ${CHROOT} systemctl enable slim.service

    return $SUCCESS
}

# ask user for X (display + window manager) setup
ask_x_setup()
{
    if confirm "Arch Linux Setup" "[?] Setup X11 + window managers [y/n]: "
    then
        X_SETUP=$TRUE
        printf "\n"
    fi

    return $SUCCESS
}

 #setup arch related stuff
setup_arch()
{
    ask_x_setup
    sleep_clear ${SLEEP}

    if [ $X_SETUP -eq $TRUE ]
        then
            setup_window_managers
            sleep_clear ${SLEEP} 

            setup_display_manager
            sleep_clear ${SLEEP}

      	  	enable_pacman_multilib "chroot"
       	 	sleep_clear ${SLEEP}

        	enable_pacman_color "chroot"
        	sleep_clear ${SLEEP}

	    	ask_vbox_setup
        	sleep_clear ${SLEEP}

        	if [ $VBOX_SETUP -eq $TRUE ]
        	then
            	setup_vbox_utils
            	sleep_clear ${SLEEP}
        	fi
    fi

    if [ -n "${NORMAL_USER}" ]
    then
        update_user_groups
        sleep_clear ${SLEEP}
    fi

    return $SUCCESS
}

# perform sync
sync_disk()
{
    title "Game Over"

    wprintf "[+] Syncing disk"
    printf "\n\n"

    sync

    return $SUCCESS
}

# unmount filesystems
umount_filesystems()
{
    routine="${1}"

    if [ "${routine}" = "harddrive" ]
    then
        title "Hard Drive Setup"
    else
        title "Game Over"
    fi

    wprintf "[+] Unmounting filesystems"
    printf "\n\n"

    umount -Rf ${CHROOT} > /dev/null 2>&1
    umount -Rf "${BOOT_PART}" > /dev/null 2>&1
    umount -Rf "${CHROOT}/proc" > /dev/null 2>&1
    umount -Rf "${CHROOT}/sys" > /dev/null 2>&1
    umount -Rf "${CHROOT}/dev" > /dev/null 2>&1
    umount -Rf "${BOOT_PART}" > /dev/null 2>&1
    umount -Rf "${ROOT_PART}" > /dev/null 2>&1
    umount -Rf "/dev/mapper/${CRYPT_ROOT}" > /dev/null 2>&1
    cryptsetup luksClose "${CRYPT_ROOT}" > /dev/null 2>&1
    swapoff "${SWAP_PART}" > /dev/null 2>&1

    return $SUCCESS
}

# default time and timezone
default_time()
{
    echo
    warn "Setting up default time and timezone: Europe/Prague"
    printf "\n\n"
    chroot ${CHROOT} ln -sf /usr/share/zoneinfo/Europe/Prague /etc/localtime

    return $SUCCESS
}

# setup timezone
setup_time()
{
    if confirm "Default Time zone: Europe/Prague" "[?] Choose other timezone [y/n]: "
    then
        for t in `timedatectl list-timezones`
        do
            echo "    > `echo ${t}`"
        done

        wprintf "\n[?] What is your (Zone/SubZone): "
        read timezone
        chroot ${CHROOT} ln -sf /usr/share/zoneinfo/$timezone /etc/localtime \
            > /dev/null 2>&1

        if [ $? -eq 1 ]
        then
            warn "Do you live on Mars? Setting default time zone..."
            sleep 1
            default_time
        else
            wprintf "\n[+] Time zone setup correctly\n"
        fi
    else
        wprintf "\n[+] Setting up default time and timezone\n"
        sleep 2
        default_time
    fi

    printf "\n\n"
    return $SUCCESS
}

# setup boot loader for UEFI/GPT or BIOS/MBR
setup_bootloader()
{
    title "Base System Setup"

    if [ "${PART_LABEL}" = "gpt" ]
    then
        wprintf "[+] Setting up EFI boot loader"
        printf "\n\n"

        chroot ${CHROOT} bootctl install
        uuid="`blkid ${ROOT_PART} | cut -d ' ' -f 2 | cut -d '"' -f 2`"

                cat >> "${CHROOT}/boot/loader/entries/arch.conf" << EOF
title       BlackArch Linux
linux       /vmlinuz-linux
initrd      /initramfs-linux.img
options     root=UUID=${uuid} rw
EOF

    else
        wprintf "[+] Setting up GRUB boot loader"
        printf "\n\n"

        chroot ${CHROOT} pacman -S grub --noconfirm --force --needed
        uuid="`lsblk -o UUID ${ROOT_PART} | sed -n 2p`"

        chroot ${CHROOT} grub-install --target=i386-pc "${HD_DEV}"
        chroot ${CHROOT} grub-mkconfig -o /boot/grub/grub.cfg
    fi

    return $SUCCESS
}

# install extra (missing) packages
setup_extra_packages()
{
    arch="archlinux-keyring pkgfile"	#arch-install-scripts 

    browser="firefox midori elinks firefox-i18n-cs"

    editor="vim"

    multimedia="ffmpeg vlc"

    fonts="ttf-liberation ttf-dejavu ttf-freefont xorg-font-utils
    xorg-fonts-alias xorg-fonts-misc xorg-mkfontscale xorg-mkfontdir"

    kernel="linux-headers"

    misc="alsa-utils bash-completion cmake feh flashplugin git
    hdparm htop mesa p7zip rsync sudo unace unrar unzip zip"

    network="networkmanager network-manager-applet dhclient dnsutils 
    openssh dialog iw wireless_tools wpa_supplicant"

    xorg="xorg-server xorg-xinit xterm"

    all="${arch} ${browser} ${editor} ${filesystem} ${fonts} ${multimedia}"
    all="${all} ${kernel} ${misc} ${network} ${xorg}"

    title "Base System Setup"

    wprintf "[+] Installing extra packages"
    printf "\n"

    printf "
    > ArchLinux     : `echo ${arch} | wc -w` packages
    > Browser       : `echo ${browser} | wc -w` packages
    > Editor        : `echo ${editor} | wc -w` packages
    > Filesystem    : `echo ${filesystem} | wc -w` packages
    > Fonts         : `echo ${fonts} | wc -w` packages
    > Misc          : `echo ${misc} | wc -w` packages
    > Network       : `echo ${network} | wc -w` packages
    > Xorg          : `echo ${xorg} | wc -w` packages
    \n"

    sleep 2
    sleep_clear ${SLEEP}			
    chroot ${CHROOT} pacman -S `echo ${all}` --needed --force --noconfirm    

    return $SUCCESS
}

# ask for normal user account to setup
ask_user_account()
{
    if confirm "Base System Setup" "[?] Setup a normal user account [y/n]: "
    then
        wprintf "[?] User name: "
        read NORMAL_USER
    fi

    return $SUCCESS
}

# setup user account, password and environment
setup_user()
{
    user="${1}"

    title "Base System Setup"

    wprintf "[+] Setting up ${user} account"
    printf "\n\n"

    # normal user
    if [ ! -z ${NORMAL_USER} ]
    then
        chroot ${CHROOT} groupadd ${user}
        chroot ${CHROOT} useradd -g ${user} -d "/home/${user}" -s "/bin/bash" \
            -G "${user},wheel,users,video,audio" -m ${user}
        chroot ${CHROOT} chown -R ${user}:${user} "/home/${user}"
        wprintf "[+] Added user: ${user}"
        printf "\n\n"
    fi

    # password
    wprintf "[?] Set password for ${user}: "
    printf "\n\n"
    if [ "${user}" = "root" ]
    then
        chroot ${CHROOT} passwd
    else
        chroot ${CHROOT} passwd "${user}"
    fi

    return $SUCCESS
}

# setup hostname
setup_hostname()
{
    title "Base System Setup"

    wprintf "[+] Setting up hostname"
    printf "\n\n"

    echo "${HOST_NAME}" > "${CHROOT}/etc/hostname"

    return $SUCCESS
}

# setup initramfs
setup_initramfs()
{
    title "Base System Setup"

    wprintf "[+] Setting up initramfs"
    printf "\n\n"

    chroot ${CHROOT} mkinitcpio -p linux

    return $SUCCESS
}

# setup locale and keymap
setup_locale()
{
    title "Base System Setup"

    wprintf "[+] Setting up default locale (cs_CZ.UTF-8)"
    printf "\n\n"

    sed -i 's/^#cs_CZ.UTF-8/cs_CZ.UTF-8/' "${CHROOT}/etc/locale.gen"
    sed -i 's/^#cs_CZ ISO-8859-2/cs_CZ ISO-8859-2/' "${CHROOT}/etc/locale.gen"
    chroot ${CHROOT} locale-gen
    echo "KEYMAP=cz-qwertz">"${CHROOT}/etc/vconsole.conf"
    localectl set-locale LANG=cs_CZ.UTF-8

    return $SUCCESS
}

# mount /proc, /sys and /dev
setup_proc_sys_dev()
{
    title "Base System Setup"

    wprintf "[+] Setting up /proc, /sys and /dev"
    printf "\n\n"

    mkdir -p "${CHROOT}/"{proc,sys,dev} > /dev/null 2>&1

    mount -t proc proc "${CHROOT}/proc"
    mount --rbind /sys "${CHROOT}/sys"
    mount --make-rslave "${CHROOT}/sys"
    mount --rbind /dev "${CHROOT}/dev"
    mount --make-rslave "${CHROOT}/dev"

    return $SUCCESS
}

# setup fstab
setup_fstab()
{
    title "Base System Setup"

    wprintf "[+] Setting up /etc/fstab"
    printf "\n\n"

    if [ "${PART_LABEL}" = "gpt" ]
    then
        genfstab -U ${CHROOT} >> "${CHROOT}/etc/fstab"
    else
        genfstab -L ${CHROOT} >> "${CHROOT}/etc/fstab"
    fi

    return $SUCCESS
}

# install ArchLinux base and base-devel packages
install_base_packages()
{
    title "Base System setup"

    wprintf "[+] Installing ArchLinux base packages"
    printf "\n\n"

    pacstrap ${CHROOT} base base-devel
    chroot ${CHROOT} pacman -Syy --force

    return $SUCCES
}

# setup /etc/resolv.conf
setup_resolvconf()
{
    title "Base System Setup"

    wprintf "[+] Setting up /etc/resolv.conf"
    printf "\n\n"

    mkdir -p "${CHROOT}/etc/" > ${VERBOSE} 2>&1
    cp -L "/etc/resolv.conf" "${CHROOT}/etc/resolv.conf" > ${VERBOSE} 2>&1

    return $SUCCESS
}

# pass correct config
pass_mirror_conf()
{
    cp -f /etc/pacman.d/mirrorlist ${CHROOT}/etc/pacman.d/mirrorlist \
        > ${VERBOSE} 2>&1
}

# mount filesystems
mount_filesystems()
{
    title "Hard Drive Setup"

    wprintf "[+] Mounting filesystems"
    printf "\n\n"

    # ROOT
    mount ${ROOT_PART} ${CHROOT} > /dev/null 2>&1
 
    # BOOT
    mkdir ${CHROOT}/boot > /dev/null 2>&1
    mount ${BOOT_PART} "${CHROOT}/boot" > /dev/null 2>&1

    # HOME
    mkdir ${CHROOT}/home > /dev/null 2>&1
    mount ${HOME_PART} "${CHROOT}/home" > /dev/null 2>&1

    # SWAP
    swapon "${SWAP_PART}" > /dev/null 2>&1

    return $SUCCESS
}

# make and format partitions
make_partitions()
{
    make_boot_partition
    sleep_clear ${SLEEP}

    make_root_partition
    sleep_clear ${SLEEP}

    make_home_partition
    sleep_clear ${SLEEP}

    if [ "${SWAP_PART}" != "none" ]
    then
        make_swap_partition
        sleep_clear ${SLEEP}
    fi

    return $SUCCESS
}

# ask user and get confirmation for formatting
ask_formatting()
{
    if confirm "Hard Drive Setup" "[?] Formatting partitions. Are you sure? \
[y/n]: "
    then
        return $SUCCESS
    else
        echo
        err "Seriously? No formatting no fun!"
    fi

    return $SUCCESS
}

# print partitions and ask for confirmation
print_partitions()
{
    i=""

    while true
    do
        title "Hard Drive Setup"
        wprintf "[+] Current Partition table"
        printf "\n
    > /boot     : ${BOOT_PART} (${BOOT_FS_TYPE})
    > /         : ${ROOT_PART} (${ROOT_FS_TYPE})
    > /home 	: ${HOME_PART} (${HOME_FS_TYPE})
    > swap      : ${SWAP_PART} (swap)
    \n"
        wprintf "[?] Partition table correct [y/n]: "
        read i
        if [ "${i}" = "y" -o "${i}" = "Y" ]
        then
            clear
            break
        elif [ "${i}" = "n" -o "${i}" = "N" ]
        then
            echo
            err "Hard Drive Setup aborted."
        else
            clear
            continue
        fi
        clear
    done

    return $SUCCESS
}

# get partitions
get_partitions()
{
    partitions=`ls ${HD_DEV}* | grep -v "${HD_DEV}\>"`

    while [ \
        "${BOOT_PART}" = "" -o \
        "${ROOT_PART}" = "" -o \
        "${BOOT_FS_TYPE}" = "" -o \
        "${ROOT_FS_TYPE}" = "" -o \
        "${HOME_FS_TYPE}" = "" ]
    do
        title "Hard Drive Setup"
        wprintf "[+] Created partitions:"
        printf "\n\n"

        for i in ${partitions}
        do
            echo "    > ${i}"
        done
        echo

        wprintf "[?] Boot partition (/dev/sdXY): "
        read BOOT_PART
        wprintf "[?] Boot FS type (ext2, ext3, ext4, btrfs, fat32): "
        read BOOT_FS_TYPE
        wprintf "[?] Root partition (/dev/sdXY): "
        read ROOT_PART
        wprintf "[?] Root FS type (ext2, ext3, ext4, btrfs): "
        read ROOT_FS_TYPE
        wprintf "[?] Home partition (dev/sdXY): "
        read HOME_PART
        wprintf "[?] Home FS type (ext2, ext3, ext4, btrfs): "
        read HOME_FS_TYPE
        wprintf "[?] Swap parition (/dev/sdXY - empty for none): "
        read SWAP_PART

        if [ "${SWAP_PART}" = "" ]
        then
            SWAP_PART="none"
        fi
        clear
    done

    return $SUCCESS
}

# get partition label
get_partition_label()
{
    PART_LABEL="`parted -m ${HD_DEV} print | grep ${HD_DEV} | cut -d ':' -f 6`"

    return $SUCCESS
}

# ask user to create partitions using cfdisk
ask_cfdisk()
{
    if confirm "Hard Drive Setup" "[?] Create partitions with cfdisk (root \
			boot, home, optional swap) [y/n]: "
    then
        clear
        zero_part
    else
        echo
        err "Are you kidding me? No partitions no fun!"
    fi

    return $SUCCESS
}

# ask user for device to format and setup
ask_hd_dev()
{
    while true
    do
        title "Hard Drive Setup"

        wprintf "[+] Available hard drives for installation:"
        printf "\n\n"

        for i in ${HD_DEVS}
        do
            echo "    > ${i}"
        done
        echo
        wprintf "[?] Please choose a device: "
        read HD_DEV
        if echo ${HD_DEVS} | grep "\<${HD_DEV}\>" > /dev/null
        then
            HD_DEV="/dev/${HD_DEV}"
            clear
            break
        fi
        clear
    done

    return $SUCCESS
}

# get available hard disks
get_hd_devs()
{
    HD_DEVS="`lsblk | grep disk | awk '{print $1}'`"

    return $SUCCESS
}

# enable multilib in pacman.conf if x86_64 present
enable_pacman_multilib()
{
    path="${1}"

    if [ "${path}" = "chroot" ]
    then
        path="${CHROOT}"
    else
        path=""
    fi

    title "Pacman Setup"

    if [ "`uname -m`" = "x86_64" ]
    then
        wprintf "[+] Enabling multilib support"
        printf "\n\n"
        if grep -q "#\[multilib\]" ${path}/etc/pacman.conf
        then
            # it exists but commented
            sed -i '/\[multilib\]/{ s/^#//; n; s/^#//; }' ${path}/etc/pacman.conf
        elif ! grep -q "\[multilib\]" ${path}/etc/pacman.conf
        then
            # it does not exist at all
            printf "[multilib]\nInclude = /etc/pacman.d/mirrorlist\n" \
                >> ${path}/etc/pacman.conf
        fi
    fi

    return $SUCCESS
}

# update pacman.conf and database
update_pacman()
{
    enable_pacman_multilib
    sleep_clear ${SLEEP}

    enable_pacman_color
    sleep_clear ${SLEEP}

    update_pkg_database
    sleep_clear ${SLEEP}

    return $SUCCESS
}

# update pacman package database
update_pkg_database()
{
    title "Pacman Setup"

    wprintf "[+] Updating pacman database"
    printf "\n\n"

    pacman -Syy --noconfirm

    return $SUCCESS
}

# ask for archlinux server
ask_mirror_arch()
{
    declare mirrold="cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup"
    
    if confirm "ArchLinux Mirrorlist Setup" \
        "[+] Worldwide mirror will be used\n\n[?] Look for the best server? [y/n]: "
    then
        printf "\n"
        warn "This may take time depending on your connection"
        $mirrold
        sed -i 's/^#Server/Server/' /etc/pacman.d/mirrorlist.backup
        rankmirrors -n 3 /etc/pacman.d/mirrorlist.backup \
            > /etc/pacman.d/mirrorlist
    else
	    printf "\n"
	    warn "Using Worldwide mirror server"
	    $mirrold
	    echo -e "## Arch Linux repository Worldwide mirrorlist\n\n" \
            > /etc/pacman.d/mirrorlist

	    for wore in ${AR_REPO_URL}
	    do
	        echo "Server = ${wore}" >> /etc/pacman.d/mirrorlist
	    done
    fi
}

# check for internet connection
check_inet_conn()
{
    if ! wget -q --tries=3 --timeout=10 --spider http://github.com > /dev/null 2>&1
    then
        err "No Internet connection! Check your network (settings)."
    fi

    return $SUCCESS
}

# auto (dhcp) network interface configuration
net_conf_auto()
{
    opts="-h noleak -i noleak -v ,noleak -I noleak"

    title "Network Setup"
    wprintf "[+] Configuring network interface '${NET_IF}' via DHCP: "
    printf "\n\n"

    dhcpcd ${opts} -i ${NET_IF}

    return $SUCCESS
}

# ask for networking configuration mode
ask_net_conf_mode()
{
    while [ \
        "${NET_CONF_MODE}" != "${NET_CONF_AUTO}" -a \
        "${NET_CONF_MODE}" != "${NET_CONF_WLAN}" -a \
        "${NET_CONF_MODE}" != "${NET_CONF_MANUAL}" -a \
        "${NET_CONF_MODE}" != "${NET_CONF_SKIP}" ]
    do
        title "Network Setup"
        wprintf "[+] Network interface configuration:"
        printf "\n
    1. Auto DHCP (use this for auto connect via dhcp on selected interface)
    2. WiFi WPA Setup (use if you need to connect to a wlan before)
    3. Manual (use this if you are 1337)
    4. Skip (use this if you are already connected)\n\n"
        wprintf "[?] Please choose a mode: "
        read NET_CONF_MODE
        clear
    done
    return $SUCCESS
}

# ask user for network interface
ask_net_if()
{
    while true
    do
        title "Network Setup"
        wprintf "[+] Available network interfaces:"
        printf "\n\n"
        for i in ${NET_IFS}
        do
            echo "    > ${i}"
        done
        echo
        wprintf "[?] Please choose a network interface: "
        read NET_IF
        if echo ${NET_IFS} | grep "\<${NET_IF}\>" > /dev/null
        then
            clear
            break
        fi
        clear
    done
    return $SUCCESS
}

# get available network interfaces
get_net_ifs()
{
    NET_IFS="`ls /sys/class/net`"

    return $SUCCESS
}

# ask user for hostname
ask_hostname()
{
    while [ -z "${HOST_NAME}" ]
    do
        title "Network Setup"
        wprintf "[?] Set your hostname: "
        read HOST_NAME
        clear
    done
    return $SUCCESS
}

# set keymap to use
set_keymap()
{
    title "Keymap Setup"
    wprintf "[?] Set keymap [cz]: "
    read KEYMAP

    # default keymap
    if [ -z "${KEYMAP}" ]
    then
        KEYMAP="cz-qwertz"
    fi

    localectl set-keymap --no-convert "cs_CZ.UTF-8"
    loadkeys "${KEYMAP}"

    return $SUCCESS
}

ask_keymap()
{
    while [ \
        "${keymap_opt}" != "${SET_KEYMAP}" -a \
        "${keymap_opt}" != "${LIST_KEYMAP}" ]
    do
        title "Keymap Setup"
        wprintf "[+] Available keymap options:"
        printf "\n
    1. Set a keymap
    2. List available keymaps\n\n"
        wprintf "[?] Make a choice: "
        read keymap_opt

        if [ "${keymap_opt}" = "${SET_KEYMAP}" ]
        then
            break
        fi
        if [ "${keymap_opt}" = "${LIST_KEYMAP}" ]
        then
            localectl list-keymaps
            echo
        fi
        clear
    done
    clear
    return $SUCCESS
}

#check user id
check_uid()
{
    if [ `id -u` -ne 0 ]
    then
        err "You must be root to run the Arch installer!"
    fi

    return $SUCCESS
}

# check for environment issues
check_env()
{
    if [ -f "/var/lib/pacman/db.lck" ]
    then
        err "pacman locked - Please remove /var/lib/pacman/db.lck"
    fi
}

# print formatted output
wprintf()
{
    fmt="${1}"

    shift
    printf "%s${fmt}%s" "${WHITE}" "${@}" "${NC}"

    return $SUCCESS
}

# print menu title
title()
{
    banner
    printf "${BLUE}>> %s${NC}\n\n\n" "${@}"

    return "${SUCCESS}"
}

# leet banner (very important)
banner()
{
    columns="$(tput cols)"
    str="[ Arch-installer ${VERSION} ]"

    printf "${REDB}%*s${NC}\n" "${COLUMNS:-$(tput cols)}" | tr ' ' '*'

    echo "${str}" |
    while IFS= read -r line
    do
        printf "%s%*s\n%s" "${WHITEB}" $(( (${#line} + columns) / 2)) \
            "$line" "${NC}"
    done

    printf "${REDB}%*s${NC}\n\n\n" "${COLUMNS:-$(tput cols)}" | tr ' ' '*'

    return $SUCCESS
}

# print error and exit
err()
{
    printf "%s[-] ERROR: %s%s\n" "${RED}" "${@}" "${NC}"
    exit $FAILURE

    return $SUCCESS
}

# sleep and clear
sleep_clear()
{
	sleep $1
    clear

    return $SUCCESS
}

# confirm user inputted yYnN
confirm()
{
    header="${1}"
    ask="${2}"

    while true
    do
        title "${header}"
        wprintf "${ask}"
        read input
        if [ "${input}" = "y" -o "${input}" = "Y" ]
        then
            return $TRUE
        elif [ "${input}" = "n" -o "${input}" = "N" ]
        then
            return $FALSE
        else
            clear
            continue
        fi
    done
    return $SUCCESS
}

# print warning
warn()
{
    printf "%s[!] WARNING: %s%s\n" "${YELLOW}" "${@}" "${NC}"

    return $SUCCESS
}

# perform system base setup/configurations
setup_base_system()
{
    setup_resolvconf
    sleep_clear ${SLEEP}

    install_base_packages		
    sleep_clear ${SLEEP}

    setup_resolvconf
    sleep_clear ${SLEEP}

    setup_fstab
    sleep_clear ${SLEEP}

    setup_proc_sys_dev
    sleep_clear ${SLEEP}

    setup_locale
    sleep_clear ${SLEEP}

    setup_initramfs
    sleep_clear ${SLEEP}

    setup_hostname
    sleep_clear ${SLEEP}

    setup_user "root"
    sleep_clear ${SLEEP}

    ask_user_account
    sleep_clear ${SLEEP}

    if [ ! -z "${NORMAL_USER}" ]
    then
        setup_user "${NORMAL_USER}"
        sleep_clear ${SLEEP}
    fi

    setup_extra_packages	####
    setup_bootloader
    sleep_clear ${SLEEP}

    return $SUCCESS
}

main()
{
	check_uid
	check_env
	
	#keymap
	ask_keymap
	set_keymap
	clear

	#network
	ask_hostname
    get_net_ifs
    ask_net_if
    ask_net_conf_mode
    case "${NET_CONF_MODE}" in
        "${NET_CONF_AUTO}")
            net_conf_auto
            ;;
        "${NET_CONF_WLAN}")
            ask_wlan_data
            net_conf_wlan
            ;;
        "${NET_CONF_MANUAL}")
            ask_net_addr
            net_conf_manual
            ;;
        "${NET_CONF_SKIP}")
            ;;
        *)
            ;;
    esac
    sleep_clear ${SLEEP}
    check_inet_conn
    sleep_clear ${SLEEP}

    # pacman
    ask_mirror_arch		
    sleep_clear ${SLEEP}
    update_pacman

    # hard drive
    get_hd_devs
    ask_hd_dev
    umount_filesystems "harddrive"
    sleep_clear ${SLEEP}
    ask_cfdisk
    sleep_clear ${SLEEP}
    get_partition_label
    get_partitions
    print_partitions
    ask_formatting
    clear
    make_partitions
    clear
    mount_filesystems		
    sleep_clear ${SLEEP}

    # arch linux
    pass_mirror_conf
    sleep_clear ${SLEEP}
    setup_base_system
    sleep_clear ${SLEEP}
    setup_time
    sleep_clear ${SLEEP}

    # setup arch linux
    setup_arch
    sleep_clear ${SLEEP}

    # epilog     
    umount_filesystems
    sleep_clear ${SLEEP}
    sync_disk
    sleep_clear ${SLEEP}
    
    return $SUCCESS
}

# we start here
main "${@}"

# EOF
# dhcpcd neběží po startu
# konzole v us locale
# display manager ?? GDM => test
# locale nastaveno na us