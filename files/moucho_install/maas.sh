#!/bin/bash

set -e
set -x

pacman -S --noconfirm python python-pip inetutils cronie ansible git p7zip vim

install --directory --owner=${ADM_USER} --group=${ADM_USER} --mode=0750 "/home/${ADM_USER}/.ansible/plugins/modules"
git clone https://github.com/kewlfft/ansible-aur.git "/home/${ADM_USER}/.ansible/plugins/modules/aur"
chown -R ${ADM_USER}: /home/${ADM_USER}/.ansible

if [[ -f /inst/files.7z ]]; then
  7z x /inst/files.7z -p${ENCRYPT_PASS_FILES}
  cd /inst/files

  # INCLUDE CUSTOMIZATIONS FOR files.7z content
  # install --preserve-timestamps --owner=${ADM_USER} --group=${ADM_USER} --mode=0600 "vault_password" "/home/${ADM_USER}/.vault_password"
fi

cd /inst
install --preserve-timestamps --owner=${ADM_USER} --group=${ADM_USER} --mode=0700 "ansible.sh" "/home/${ADM_USER}/ansible.sh"

systemctl enable systemd-timesyncd
systemctl enable pcscd

install --directory --owner=${ADM_USER} --group=${ADM_USER} --mode=0700 /opt/moucho
cp -r /post_inst/* /opt/moucho
chown -R ${ADM_USER}: /opt/moucho
find "/opt/moucho" -type d -exec chmod -R 0700 {} +
find "/opt/moucho" -type f -exec chmod -R 0600 {} +

