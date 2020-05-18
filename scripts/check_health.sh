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
    SLACK_WEBHOOK_URL=${SLACK_WEBHOOK_URL:-} # Passed in from unit's environment file
    INSTANCE_NAME=$(curl -s -H "Metadata-Flavor: Google" http://metadata.google.internal/computeMetadata/v1/instance/name)
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

function post_to_slack_error() {
    local blocks_behind=${1}

    if [[ "${SLACK_WEBHOOK_URL}" =~ https:\/\/hooks.slack.com/services\/* ]]; then
        curl -s -X POST -H 'Content-type: application/json' --data "
{
        'blocks': [
                {
                        'type': 'section',
                        'text': {
                                'type': 'mrkdwn',
                                'text': '*BitCore Container Restarted*'
                        }
                },
                {
                        'type': 'section',
                        'fields': [
                                {
                                        'type': 'mrkdwn',
                                        'text': '*VM:*\n${INSTANCE_NAME}'
                                },
                                {
                                        'type': 'mrkdwn',
                                        'text': '*# of Blocks Behind:*\n${blocks_behind}'
                                }
                        ]
                }
        ]
}" ${SLACK_WEBHOOK_URL}
    else
        log_warning "Failed to post message to Slack. Slack webhook URL is '${SLACK_WEBHOOK_URL}'"
    fi
}

# Create counter file for tracking the number of times bitcore has been observed as behind the bitcoin blockchain
function create_counter_file() {
    TEMP_COUNTER_FILE=$(mktemp /tmp/${TEMP_COUNTER_FILE_BASE_NAME}.XXXXX)
    echo -e "times failed,# of blocks behind\n0,0" > ${TEMP_COUNTER_FILE}
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

# Get blockchain heights
# Iterate the counter file if the heights don't match
# Update the number of blocks bitcore is behind bitcoin_core
# Otherwise, reset the counter to 0
function compare_heights() {
    local bitcoin_core_height=$(docker logs ${BITCOIN_CORE_CONTAINER} --tail 100 | grep "height=" | cut -d '=' -f3 | awk '{print $1}' | tail -1)
    local bitcore_height=$(docker logs ${BITCORE_CONTAINER} --tail 100 | grep "height=" | cut -d '=' -f4 | tail -1)
    local times_failed=$(cat ${TEMP_COUNTER_FILE} | tail -n 1 | cut -d',' -f1)
    local blocks_behind_on_previous_run=$(cat ${TEMP_COUNTER_FILE} | tail -n 1 | cut -d',' -f2)

    # Calculate delta of blocks behind last run and blocks behind on this run
    if [ -n "${bitcoin_core_height}" ] && [ -n "${bitcore_height}" ]; then
        local blocks_behind_on_this_run=$((bitcoin_core_height - bitcore_height))
    else
        log_error "bitcoin_core height and/or bitcore height is empty. One of the containers may still be booting."
        log_error "Exiting..."
        exit 1
    fi

    # Compare blockchain heights
    if [ "${bitcoin_core_height}" != "${bitcore_height}" ]; then
        # Increment counter file by 1
        log_info "Height discrepancy found. Incrementing counter file."
        sed -ri "s/([[:digit:]]),([[:digit:]])/$((${times_failed} + 1)),\2/g" ${TEMP_COUNTER_FILE}
        sed -ri "s/([[:digit:]]),([[:digit:]])/\1,${blocks_behind_on_this_run}/g" ${TEMP_COUNTER_FILE}

        # Compare current blocks behind against previous blocks behind
        # If the blocks are getting further behind bitcoin_core since the last execution, update the counter file
        if [ ${blocks_behind_on_this_run} -gt ${blocks_behind_on_previous_run} ]; then

            # Restart Bitcore docker container if we're past the failure threshold
            if [ ${times_failed} -ge ${RESTART_THRESHOLD} ]; then
                log_info "Threshold met and we're falling further behind in blocks than previous execution. Restarting Bitcore Docker container..."
                docker restart ${BITCORE_CONTAINER} >/dev/null
                post_to_slack_error ${blocks_behind_on_this_run}
            fi
        fi
    elif [ "${bitcoin_core_height}" = "${bitcore_height}" ]; then
        # Reset counter file to 0 runs failed and 0 blocks behind
        log_info "Heights match. Setting counter file to 0"
        sed -ri "s/([[:digit:]]),([[:digit:]])/0,0/g" ${TEMP_COUNTER_FILE}
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
