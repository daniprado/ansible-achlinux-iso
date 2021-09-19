#!/bin/bash

set -e
set -x

pacman -Sy

cryptsetup open --type plain "${device}" container --key-file /dev/random
dd if=/dev/zero of=/dev/mapper/container bs=1M status=progress && false
cryptsetup close container

parted -s "${device}" mklabel gpt
parted -s -a optimal "${device}" mkpart primary fat32 0% 512MB
parted -s -a optimal "${device}" set 1 esp on
parted -s -a optimal "${device}" mkpart primary 512MB 100%

cryptsetup luksFormat "${root_device}" <<EOL
${ENCRYPT_PASS_ROOT}
EOL
cryptsetup open "${root_device}" lvm <<EOL
${ENCRYPT_PASS_ROOT}
EOL

pvcreate -ff /dev/mapper/lvm
vgcreate "${LVM_NAME}" /dev/mapper/lvm
lvcreate -L 40GB "${LVM_NAME}" --name swap
lvcreate -L 200GB "${LVM_NAME}" --name root
lvcreate -l 100%FREE "${LVM_NAME}" --name data

mkfs.vfat -F32 -n EFI "${boot_partition}"
mkswap "${swap_partition}"
mkfs.ext4 -O ^64bit -F -m 0 -q -L root "${root_partition}"
mkfs.ext4 -O ^64bit -F -m 0 -q -L data "${data_partition}"

mount -o noatime,errors=remount-ro "${root_partition}" "${install_dir}"

install --directory "${install_dir}/boot"
mount -o noatime,errors=remount-ro "${boot_partition}" "${install_dir}/boot"

install --directory "${install_dir}/data"
mount -o noatime,errors=remount-ro "${data_partition}" "${install_dir}/data"

swapon "${swap_partition}"

curl -fsS https://www.archlinux.org/mirrorlist/?country=NL | grep -e '^#Server' | sed 's/^#//' > /etc/pacman.d/mirrorlist

pacstrap "${install_dir}" base base-devel linux linux-firmware lvm2 gptfdisk efibootmgr intel-ucode

mkdir -p "${install_dir}/etc/pacman.d"
install --owner=root --group=root --mode=0644 "/etc/pacman.d/mirrorlist" "${install_dir}/etc/pacman.d/mirrorlist"

genfstab -U -p "${install_dir}" >> "${install_dir}/etc/fstab"

# PRE-MAAS
install --directory "${install_dir}/inst"
install "./moucho_install/maas.sh" "${install_dir}/inst/maas.sh"
install "./moucho_install/ansible.sh" "${install_dir}/inst/ansible.sh"
cp -r ./post_install "${install_dir}/post_inst"
if [[ -f ./files.7z ]]; then
  install "./files.7z" "${install_dir}/inst/files.7z"
fi

arch-chroot "${install_dir}" /bin/bash < ./moucho_install/install-chroot.sh

