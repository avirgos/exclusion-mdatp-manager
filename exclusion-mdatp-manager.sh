#!/bin/bash

######################################################################
# Template
######################################################################
set -o errexit  # Exit if command failed.
set -o pipefail # Exit if pipe failed.
set -o nounset  # Exit if variable not set.
IFS=$'\n\t'     # Remove the initial space and instead use '\n'.

######################################################################
# Global variables (internal)
######################################################################
# Path to the inventory file
INVENTORY="inventory.ini"

# Ansible playbook to manage `mdatp` exclusions
PLAYBOOK="exclusion-mdatp.yml"

# Group in the inventory containing managed nodes
HOSTS_GROUP="servers"

# Array to store hostnames
HOSTS=()

# Logs
LOG_DIR="logs"
LOG_FILE=""${LOG_DIR}"/exclusion-mdatp-manager_$(date +'%Y%m%d_%H%M%S').log"

# Create "${LOG_DIR}" if absent
mkdir -p "${LOG_DIR}"

######################################################################
# Logs a message with a timestamp to the log file.
#
# Globals:
#   LOG_FILE
# Arguments:
#   "${1}"
# Returns:
#   None
######################################################################
function log() {
    echo "[ $(date +'%Y-%m-%d %H:%M:%S') ] "${1}"" >> "${LOG_FILE}"
}

######################################################################
# Parses the inventory file to extract hostnames.
#
# Globals:
#   INVENTORY, HOSTS_GROUP, HOSTS
# Locals:
#   in_group
# Returns:
#   None
######################################################################
function parse_inventory() {
    local in_group=0

    while IFS= read -r line
    do
        # ignore blank lines and comments
        [[ -z "${line}" || "${line}" =~ ^# ]] && continue

        # check for the beginning of the target group (`HOSTS_GROUP`)
        if [[ "${line}" =~ ^\["${HOSTS_GROUP}"\] ]]
        then
            in_group=1
            continue
        fi

        if [[ "${in_group}" -eq 1 ]]
        then
            # stop if another group is encountered
            [[ "${line}" =~ ^\[.*\] ]] && break

            # extract hostname and add to `HOSTS` array
            HOSTS+=("$(echo "${line}" | cut -d' ' -f1)")
        fi
    done < "${INVENTORY}"
}

######################################################################
# Displays the main menu.
#
# Returns:
#   None
######################################################################
function show_main_menu() {
    echo "╔═════════════════════════════════════════╗"
    echo "║         exclusion-mdatp-manager         ║"
    echo "╚═════════════════════════════════════════╝"
    echo "1 | Manage exclusions host by host"
    echo "2 | Add an exclusion on all hosts"
    echo "3 | Remove an exclusion on all hosts"
    echo "4 | Quit"
}

######################################################################
# Gets user action choice from the menu.
# 
# Locals:
#   action
# Returns:
#   The choice of the user as a number.
######################################################################
function get_action() {
    local action

    while true
    do
        read -p "Enter the number corresponding to your choice... : " action

        # validate user input
        if [[ "${action}" =~ ^[1-4]$ ]]
        then
            echo "${action}"
            return
        fi
    done
}

######################################################################
# Displays the action menu for a specific host.
#
# Arguments:
#   host
#   is_last
# Returns:
#   None
######################################################################
function show_action_menu() {
    local host="${1}"
    local is_last="${2}"

    echo "Host : ["${host}"]"
    echo "Choose the action to perform :"
    echo "1 | List exclusions"
    echo "2 | Add an exclusion"
    echo "3 | Remove an exclusion"
    if [[ "${is_last}" -eq 1 ]]
        then
        echo "4 | Return to main menu"
    else
        echo "4 | Move to the next host"
    fi
}

######################################################################
# Runs the Ansible playbook with specified parameters.
#
# Globals:
#   INVENTORY, PLAYBOOK, HOSTS_GROUP
# Locals:
#   extra_vars
# Arguments:
#   limit
#   action
#   exclusion_type
#   exclusion_details
# Returns:
#   None
######################################################################
function run_ansible_playbook() {
    local limit="${1}"
    local action="${2}"
    local exclusion_type="${3:-}"
    local exclusion_details="${4:-}"

    local extra_vars="exclusion_action="${action}" hosts_group="${HOSTS_GROUP}""
    [[ -n "${exclusion_type}" ]] && extra_vars=""${extra_vars}" exclusion_type_input="${exclusion_type}""
    [[ -n "${exclusion_details}" ]] && extra_vars=""${extra_vars}" exclusion_details_input='"${exclusion_details}"'"

    log "Running action "${action}" on "${limit}" with the following additional variables: "${extra_vars}""

    ANSIBLE_FORCE_COLOR=1 ansible-playbook -i "${INVENTORY}" "${PLAYBOOK}" -l "${limit}" -e "${extra_vars}" | tee -a "${LOG_FILE}"
}

######################################################################
# Processes each host one by one.
#
# Globals:
#   HOSTS
# Locals:
#   host, is_last_host, action
# Returns:
#   None
######################################################################
function process_one_by_one_hosts() {
    for ((i=0; i<"${#HOSTS[@]}"; ++i))
    do
        local host="${HOSTS[$i]}"
        local is_last_host=0

        # check if current host is the last one
        [[ "${i}" -eq $(("${#HOSTS[@]}" - 1)) ]] && is_last_host=1

        while true
        do
            show_action_menu "${host}" "${is_last_host}"

            local action
            action=$(get_action)

            if [[ "${action}" == "4" ]]
            then
                if [[ "${is_last_host}" -eq 1 ]]
                then
                    log "Returning to the main menu."
                    echo -e "\n • Returning to the main menu. \n"
                else
                    log "Moving to the next host..."
                    echo -e "\n • Moving to the next host... \n"
                fi
                break
            fi

            run_ansible_playbook "${host}" "${action}"
        done
    done
}

######################################################################
# Processes all hosts at once.
#
# Globals:
#   HOSTS_GROUP
# Arguments:
#   action
# Returns:
#   None
######################################################################
function process_all_hosts() {
    local action="${1}" # 2 = add, 3 = remove

    # ask for the type of exclusion only if action = 2 or 3
    if [[ "${action}" == "2" || "${action}" == "3" ]]
    then
        echo "Choose the type of exclusion to manage :"
        echo "1 | Directory (e.g., \`/home/*/git\`)"
        echo "2 | File (e.g., \`/var/log/system.log\`)"
        echo "3 | File extension (e.g., \`.txt\`)"
        echo "4 | Process (e.g., \`/bin/cat\`)"

        local exclusion_type
        while true
        do
            read -p "Enter the number corresponding to your choice... : " exclusion_type

            if [[ "${exclusion_type}" =~ ^[1-4]$ ]]
            then
                break
            fi
        done

        case "${exclusion_type}" in
            1)
                while true
                do
                    read -p "Path of the directory to exclude (e.g., \`/home/*/git\`) : " exclusion_details
                    [[ -n "${exclusion_details}" ]] && break
                done
                ;;
            2)
                while true
                do
                    read -p "Path of the file to exclude (e.g., \`/var/log/system.log\`) : " exclusion_details
                    [[ -n "${exclusion_details}" ]] && break
                done
                ;;
            3)
                while true
                do
                    read -p "File extension to exclude (e.g., \`.txt\`) : " exclusion_details
                    [[ -n "${exclusion_details}" ]] && break
                done
                ;;
            4)
                while true
                do
                    read -p "Name of the process to exclude (e.g., \`/bin/cat\`) : " exclusion_details
                    [[ -n "${exclusion_details}" ]] && break
                done
                ;;
        esac

        run_ansible_playbook "${HOSTS_GROUP}" "${action}" "${exclusion_type}" "${exclusion_details}"
    else
        run_ansible_playbook "${HOSTS_GROUP}" "${action}"
    fi
}

######################################################################
# Main program
######################################################################
parse_inventory
log "Start of script execution."

while true
do
    show_main_menu
    main_menu_action=$(get_action)

    case "${main_menu_action}" in
        1)
            log "Managing exclusions on a per-host basis."
            process_one_by_one_hosts
            ;;
        2)
            log "Adding an exclusion on ALL hosts..."
            echo -e "\n • Adding an exclusion on ALL hosts... \n"
            process_all_hosts 2
            ;;
        3)
            log "Removing an exclusion on ALL hosts..."
            echo -e "\n • Removing an exclusion on ALL hosts... \n"
            process_all_hosts 3
            ;;
        4)
            log "End of script execution."
            exit 0
            ;;
    esac
done
