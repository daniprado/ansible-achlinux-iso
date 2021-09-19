#!/bin/bash

set -e
set -x

ln -sf "/usr/share/zoneinfo/${TIMEZONE}" /etc/localtime
hwclock --systohc
timedatectl set-local-rtc 0
timedatectl set-timezone ${TIMEZONE}

tee /etc/vconsole.conf<<EOF
KEYMAP=${KEYMAP_EXT}
FONT=ter-124n
FONT_MAP=8859-1
KEYMAP_TOGGLE=grp:caps_toggle
EOF
tee /etc/locale.conf<<EOF
LANG=en_US.UTF-8
EOF

sed -i "s/#${LANGUAGE}/${LANGUAGE}/" /etc/locale.gen
locale-gen
localectl set-locale LANG=${LANGUAGE}

echo "${FQDN}" > /etc/hostname
tee /etc/hosts<<EOF
127.0.0.1   localhost localhost.localdomain
127.0.1.1   ${FQDN} ${MAQ}
EOF

pacman -S --noconfirm rng-tools sudo openssh dhcpcd man-db man-pages

tee /usr/lib/systemd/system/sshd.service<<EOF
[Unit]
Description=OpenSSH Daemon
Wants=sshdgenkeys.service
After=sshdgenkeys.service
After=network.target

[Service]
ExecStart=/usr/bin/sshd -D
ExecReload=/bin/kill -HUP \$MAINPID
KillMode=process
Restart=always
StartLimitBurst=0

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload

systemctl enable sshd
systemctl enable rngd
systemctl enable dhcpcd

useradd --password "${ADM_PASS}" --comment "${ADM_USER} User" --create-home --user-group "${ADM_USER}"
usermod -aG wheel "${ADM_USER}"
tee -a /home/${ADM_USER}/.bashrc<<EOF
unset SSH_AGENT_PID
if [ "${gnupg_SSH_AUTH_SOCK_by:-0}" -ne $$ ]; then
  export SSH_AUTH_SOCK="$(gpgconf --list-dirs agent-ssh-socket)"
fi
EOF

# Maas: moucho as a server
/inst/maas.sh

install --directory --owner=${ADM_USER} --group=${ADM_USER} --mode=0700 /home/${ADM_USER}/.ssh
curl --output /home/${ADM_USER}/.ssh/authorized_keys --location "${SSH_KEY_URL}"
chown ${ADM_USER}: /home/${ADM_USER}/.ssh/authorized_keys
chmod 0600 /home/${ADM_USER}/.ssh/authorized_keys

tee /etc/sudoers.d/10_${ADM_USER}<<EOF
Defaults env_keep += "SSH_AUTH_SOCK"
%wheel ALL=(ALL) ALL
EOF
chmod 0440 /etc/sudoers.d/10_${ADM_USER}

echo "Port ${SSH_PORT}" >> /etc/ssh/sshd_config

mv /etc/mkinitcpio.conf /etc/mkinitcpio.conf.old
tee /etc/mkinitcpio.conf<<EOF
MODULES=(ext4)
BINARIES=()
FILES=()
HOOKS=(base udev autodetect keyboard keymap modconf block encrypt lvm2 resume filesystems fsck)
EOF
mkinitcpio -p linux

bootctl --path=/boot install
echo default moucho >> /boot/loader/loader.conf
echo timeout 0 >> /boot/loader/loader.conf
export root_uuid=`blkid | grep ${root_device} | cut -d' ' -f2`
tee -a /boot/loader/entries/moucho.conf<<EOF
title Moucho
linux /vmlinuz-linux
initrd /intel-ucode.img
initrd /initramfs-linux.img
options cryptdevice=${root_uuid}:${LVM_NAME} root=${root_partition} resume=${swap_partition} rw intel_pstate=no_hwp
EOF

# clean up
pacman -Rcns --noconfirm gptfdisk
rm -rf /inst

