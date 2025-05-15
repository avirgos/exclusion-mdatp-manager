#!/bin/bash

######################################################################
# Template
######################################################################
set -o errexit  # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset  # Exit if variable not set.
IFS=$'\n\t'     # Remove the initial space and instead use '\n'.

######################################################################
# Global variables
######################################################################
# inventory file
INVENTORY="inventory.ini"
# Ansible playbook
PLAYBOOK="exclusion-mdatp.yml"
# group in the inventory containing managed nodes
HOSTS_GROUP="servers"
HOSTS=()

# extract hosts from the group specified in the inventory
in_group=0
while IFS= read -r line
do
    # ignore blank lines and comments
    [[ -z "${line}" || "${line}" =~ ^# ]] && continue

    # beginning of target group (`HOSTS_GROUP`)
    if [[ "${line}" =~ ^\["${HOSTS_GROUP}"\] ]]
    then
        in_group=1
        continue
    fi

    if [[ "${in_group}" -eq 1 ]]
    then
        [[ "${line}" =~ ^\[.*\] ]] && break
        HOSTS+=("$(echo "${line}" | cut -d' ' -f1)")
    fi
done < "${INVENTORY}"

# main loop on each host in the group
for ((i=0; i<"${#HOSTS[@]}"; ++i))
do
  HOST="${HOSTS[$i]}"
  ACTION=0
  IS_LAST_HOST=0

  if [[ "${i}" -eq $((${#HOSTS[@]} - 1)) ]]
  then
        IS_LAST_HOST=1
  fi

  while [[ "${ACTION}" != "4" ]]
  do
    echo "Host : ["${HOST}"]"
    echo "Choose the action to perform :"
    echo "1 | List exclusions"
    echo "2 | Add an exclusion"
    echo "3 | Remove an exclusion"
    if [[ "${IS_LAST_HOST}" -eq 1 ]]
    then
      echo "4 | End the script"
    else
      echo "4 | Move to the next host"
    fi
    read -p "Enter the number corresponding to your choice... : " ACTION

    if [[ ! "${ACTION}" =~ ^[1-4]$ ]]
    then
      echo -e "\n ⚠ Invalid input. Please enter a number between 1 and 4. ⚠ \n"
      continue
    fi

    # go to the next host
    if [[ "${ACTION}" == "4" ]]
    then
        if [[ "${IS_LAST_HOST}" -eq 1 ]]
        then
            echo -e "\n • End of script. All hosts have been processed. \n"
        else
            echo -e "\n • Moving to the next host... \n"
        fi
        break
    fi

    # run the Ansible playbook for the selected action on the current host
    ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" -l "${HOST}" -e "exclusion_action="${ACTION}" hosts_group="${HOSTS_GROUP}""
  done
done