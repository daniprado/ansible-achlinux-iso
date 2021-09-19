[#](#) ansible-archlinux-iso

Ansible role to create de Arch Linux ISO file able to install my desktop environment.

## Usage

Create a playbook with your tasks, and include the role. I would advice to create the following variables:
- hostname
- domain
- encrypt_pass_root
- admin.name
- admin.password
- admin.sshkey

A custom compressed file "files.7z" can be added to the files directory, so it gets inserted in the ISO and its contents unzipped during install time. Specific behaviour related to the unzipped files can be added in the maas.sh script.

The simplest configuration would be:

```yaml
- name: Simple Example
  hosts: localhost
  roles:
    - role: ansible-archlinux-iso
  vars:
    hostname: test
    domain: argallar.org
    encrypt_pass_root: <<your pass here>>
    admin:
      name: admin
      password: <<your password here>>
      sshkey: <<url or path to access your pub key here>>
```

