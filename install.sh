#!/usr/bin/env sh
set -eu

declare VOLUMEN;
declare -I EXITCODE=0;

main() {
    VOLUMEN="/dev/sda"

    ntp
    mirror
    keyboard
    partitioning
    mount
    base
}

ntp() {
    echo "--> Configure time zone and NTP."
    timedatectl set-timezone Europe/Madrid
    timedatectl set-ntp true
    hwclock --systohc
}

mirror() {
    echo "--> Configure mirrorlist."
    cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.backup
    reflector -a 48 -c ES -f 5 -l 20 --sort rate --save /etc/pacman.d/mirrorlist
    echo "--> Synchronize database..."
    pacman -Sy &> /dev/null
}

keyboard() {
    loadkeys us
}

partitioning() {
    # make sure everything is unmounted before we start
    echo "--> Umount partitions."
    (umount --all-targets --quiet --recursive /mnt/) || true
    (swapoff --all) || true

    # delete old partitions
    echo "--> Delete old partitions."
    partition_delete 1
    partition_delete 2
    partition_delete 3

    # create partitions
    echo "--> Create new partitions."
    parted --script $VOLUMEN mklabel gpt
    parted --script $VOLUMEN mkpart efi fat32 1MiB 1024MiB
    parted --script $VOLUMEN set 1 esp on
    parted --script $VOLUMEN mkpart swap linux-swap 1GiB 2GiB
    parted --script $VOLUMEN mkpart root ext4 2GiB 100%

    # format partitions
    echo "--> Format partitions..."
    mkfs.fat -F32 -n UEFI "${VOLUMEN}1"
    mkswap -L SWAP "${VOLUMEN}2"
    mkfs.ext4 -L ROOT "${VOLUMEN}3"

    # reread partition table to ensure it is correct
    echo "--> Verify partitions."
    partprobe /dev/sda
}

partition_delete() {
    (partprobe "${VOLUMEN}${1}" --summary --dry-run &> /dev/null || EXITCODE=$?) || true
    if [ "${EXITCODE}" -ne 0 ]; then
        echo "--> Delete old partition: ${VOLUMEN}${1}"
        parted --script $VOLUMEN rm $1
        partprobe $VOLUMEN
    fi
    EXITCODE=0
}

mount() {
    echo "--> Mount: swap, boot and root"
    swapon "${VOLUMEN}2"
    mount "${VOLUMEN}3" /mnt
    mkdir -p /mnt/boot/efi/
    mount "${VOLUMEN}1" /mnt/boot/efi/

    echo "--> Remove default directories lost+found."
    rm -rf /mnt/boot/efi/lost+found
    rm -rf /mnt/lost+found

    echo "--> Generate fstab."
    mkdir /mnt/etc/
    genfstab -pU /mnt >> /mnt/etc/fstab
}

base() {
    echo "--> Installing essential packages..."
    pacstrap /mnt \
        base \
        base-devel \
        linux \
        linux-headers \
        linux-firmware \
        mkinitcpio \
        dhcpcd \
        networkmanager \
        iwd \
        grub \
        efibootmgr \
        vim \
        openssh
}

# localization() {
# }

main "$@"
