#!/usr/bin/bash

#
# AUTHOR: Charlie Cantoni
#
# This script is intended to check the health of the bitcore docker container by comparing its
# current blockchain height with that of the bitcoin_core docker container. If there's a
# discrepancy, it means the bitcore container is falling behind likely due to memory creep.
# In this scenario, this script restarts the bitcore container, allowing it to catch up.
#

# Exit on error
set -e

# Parses args
function parse_args() {
    while getopts "t:" opt; do
        [[ ${OPTARG} == -* ]] && { OPTIND=$((--OPTIND)); continue; }
        case "${opt}" in
            t) RESTART_THRESHOLD=${OPTARG};;
            *) usage;;
        esac
    done
    shift $((OPTIND-1))
}

function usage() {
    echo "Usage: check_health.sh [-<option> [<value>]]"
    echo "  t <number> ; A number which sets the failure threshold of which to restart the bitcore docker container once passed"
    exit 1
}

# Sets vars used throughout the script
function set_vars() {
    RESTART_THRESHOLD=${RESTART_THRESHOLD:-10}
    BITCORE_CONTAINER=${BITCORE_CONTAINER:-bitcore}
    BITCOIN_CORE_CONTAINER=${BITCOIN_CORE_CONTAINER:-bitcoin_core}
    TEMP_COUNTER_FILE_BASE_NAME="bitcore-health-check"
    TEMP_COUNTER_FILE=$(ls /tmp/${TEMP_COUNTER_FILE_BASE_NAME}.* 2>/dev/null || echo '')
}

function log_info() {
    echo "$(date -u +%FT%T.%3NZ) | INFO: ${1}"
}

function log_warning() {
    echo "$(date -u +%FT%T.%3NZ) | WARNING: ${1}"
}

function log_error() {
    echo "$(date -u +%FT%T.%3NZ) | ERROR: ${1}"
}

# Create counter file for tracking the number of times bitcore has been observed as behind the bitcoin blockchain
function create_counter_file() {
    TEMP_COUNTER_FILE=$(mktemp /tmp/${TEMP_COUNTER_FILE_BASE_NAME}.XXXXX)
    echo "0" > ${TEMP_COUNTER_FILE}
}

# Get the tmp counter file to use
function get_counter_file() {
    if [ $(echo ${TEMP_COUNTER_FILE} | wc -l) -gt 1 ]; then
        log_warning "Multiple temp files found: ${TEMP_COUNTER_FILE}"
        log_warning "Deleting them and creating a new temp file..."

        for file in ${TEMP_COUNTER_FILE}; do
            rm -f ${file}
        done

        create_counter_file
    elif [ -z "${TEMP_COUNTER_FILE}" ]; then
        log_info "Temp file doesn't exist. Creating new temp file..."
        create_counter_file
    fi
}

# Get blockchain heights. Iterate the counter file if the heights don't match. Otherwise, reset the counter to 0
function compare_heights() {
    local bitcoin_core_height=$(docker logs ${BITCOIN_CORE_CONTAINER} --tail 100 | grep "height=" | cut -d '=' -f3 | awk '{print $1}' | tail -1)
    local bitcore_height=$(docker logs ${BITCORE_CONTAINER} --tail 100 | grep "height=" | cut -d '=' -f4 | tail -1)

    # Compare blockchain heights
    if [ "${bitcoin_core_height}" != "${bitcore_height}" ]; then
        # Increment counter file by 1
        log_info "Height discrepancy found. Incrementing counter file."
        echo $(awk '{printf($1+1)}' ${TEMP_COUNTER_FILE}) > ${TEMP_COUNTER_FILE}
    elif [ "${bitcoin_core_height}" = "${bitcore_height}" ]; then
        # Reset counter file to 0
        log_info "Heights match. Setting counter file to 0"
        echo "0" > ${TEMP_COUNTER_FILE}
    fi

    # Restart Bitcore docker container
    if [ $(cat ${TEMP_COUNTER_FILE}) -ge ${RESTART_THRESHOLD} ]; then
        log_info "Threshold met. Restarting Bitcore Docker container..."
        docker restart ${BITCORE_CONTAINER}
    fi
}

####################################
########### SCRIPT START ###########
####################################
parse_args $@
set_vars
get_counter_file
compare_heights
####################################
############ SCRIPT END ############
####################################
