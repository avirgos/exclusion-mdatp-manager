# exclusion-mdatp-manager

## Overview

Bash script that uses an Ansible playbook to perform antivirus exclusions on MDE (**M**icrosoft **D**efender for **E**ndpoint) by applying them to multiple GNU/Linux machines.

## Features

ℹ️ **For a group defined in `inventory.ini`** and used in the Bash script `exclusion-mdatp-manager.sh` (`HOSTS_GROUP` global variable) :

- **Interactive menus**
- Manage exclusions (list/add/remove) **host by host**
- Add/Remove an exclusion **on all hosts**

## Prerequisites

The following packages are required:

- [`ansible`](https://docs.ansible.com/ansible/latest/installation_guide/index.html) installed on *control node*
- [`mdatp`](https://learn.microsoft.com/fr-fr/defender-endpoint/linux-install-manually) installed on *managed nodes*

`inventory.ini` lists the devices where the exclusions will be done:

```ini
[servers]
<alias-1> ansible_host=<hostname-1> ansible_user=<username-1> ansible_ssh_private_key_file=~/.ssh/ansible
<alias-2> ansible_host=<hostname-2> ansible_user=<username-2> ansible_ssh_private_key_file=~/.ssh/ansible
```

⚠️ Complete the `<alias-x>`, `<hostname-x>`, and `<username-x>` fields. ⚠️

## Deployment preparation

Create a SSH key `ansible` to allow SSH connections to the devices:

```bash
ssh-keygen -t ecdsa -b 521 -f ~/.ssh/ansible
```

Copy the SSH key to the devices where the GLPI agent will be deployed:

```bash
ssh-copy-id -i ~/.ssh/ansible.pub <username-1>@<remote-host-1>
```

⚠️ Complete the `<username-x>` and `<remote-host-x>` fields. Also, `<username-x>` must belong to the `sudo` group. ⚠️

## Usage

Run the following Bash script:

```bash
./exclusion-mdatp-manager.sh
```

## Configuration

In the Bash script `exclusion-mdatp-manager.sh`, you can modify these variables if necessary:

```bash
# path to the inventory file
INVENTORY="inventory.ini"
# Ansible playbook to manage `mdatp` exclusions
PLAYBOOK="exclusion-mdatp.yml"
# group in the inventory containing managed nodes
HOSTS_GROUP="servers"

```
