#!/bin/bash

cd /opt/moucho
ansible-playbook --ask-become-password --vault-password-file=~/.vault_password moucho.yml

