#!/bin/bash
# This is meant to be run via cron nightly. It finishes all tasks and then
# exits (--batchmode).  It also goes through and cleans up old versions and
# trash.
#
# This outputs progress messages to STDOUT. When running through you'll want to
# redirect that to /dev/null. For example:  `./run_spideroak.sh >/dev/null`
#
# Exit codes used:
# 0   - no errors
# 1   - some unhandled error (this script won't using exit code of 1)
# 101 - the `SpiderOak` command doesn't exist relative to $spideroak_app

set -e
set -u


# -- logging functions --
# Usage: log "whatever you want to log"
log () {
    if [[ "${quiet:-false}" == "false" ]]; then
        printf "%b\n" "$(date +"%Y-%m-%dT%H:%M:%S%z") $*"
    fi
}


# -- option handling --
# defaults
start_spideroak='true'
spideroak_app='/Applications/SpiderOak.app'
verbose_logfile='/dev/null'
quiet='false'
selection_file="${HOME}/.spideroak-selection.txt"
purge_days=90

while getopts ":ha:dp:qs:v:" opt; do
    case ${opt} in
    h)
        echo "Usage: $(basename $0) [OPTION]"
        echo 'Run spideroak and maintenance tasks'
        echo
        echo 'Options:'
        echo '  -h  this help message'
        echo "  -a  location of spideroak application (default: ${spideroak_app})"
        echo '  -d  do not start SpiderOak at the end'
        echo "  -p  purge files deleted more than this many days (default: ${purge_days})"
        echo '  -q  suppress all output other than errors'
        echo "  -s  write current selection to this file (default: ${selection_file})"
        echo "  -v  verbose log file (default: ${verbose_logfile})"
        exit 0
        ;;
    a)
        spideroak_app=${OPTARG}
        ;;
    d)
        start_spideroak='false'
        ;;
    p)
        purge_days=${OPTARG}
        ;;
    q)
        quiet='true'
        ;;
    s)
        selection_file=${OPTARG}
        ;;
    v)
        verbose_logfile=${OPTARG}
        ;;
    \?)
        echo "Invalid option: -${OPTARG}" >&2
        exit 1
        ;;
    :)
        echo "Option -${OPTARG} requires an argument" >&2
        exit 1
        ;;
    esac
done
shift $(expr ${OPTIND} - 1)


spideroak_cmd="${spideroak_app}/Contents/MacOS/SpiderOak"


# Make sure SpiderOak is in our path
if ! command -v "${spideroak_cmd}" 1>/dev/null 2>&1; then
    echo 'Could not find SpiderOak command' >&2
    exit 101
fi

# Check if SpiderOak is already running and cancel if it is
# Usually it exits immediately but sometimes it can take a while
while true; do
    spideroak_running="$(pgrep SpiderOak &>/dev/null; echo $?)"
    if [[ "${spideroak_running}" -ne "0" ]]; then
        break
    else
        log "Stopping running SpiderOak instance"
        pkill -HUP SpiderOak || true
        sleep 2
    fi
done


# Get a list of selections since you can't easily pull this from SpiderOak
log "Save backup selection to file"
"${spideroak_cmd}" --selection >"${selection_file}" 2>&1

# Does default schedule:
#   - hourly for last 24 hours
#   - daily for last month
#   - weekly thereafter
log "Purge historical versions"
"${spideroak_cmd}" --verbose --purge-historical-versions >"${verbose_logfile}" 2>&1

# Remove items from trash. To keep forever comment or remove line
log "Purge deleted items"
"${spideroak_cmd}" --verbose --purge-deleted-items=${purge_days} >>"${verbose_logfile}" 2>&1

if [[ "${start_spideroak}" == 'true' ]]; then
    # Start SpiderOak back up
    log "Starting SpiderOak"
    open "${spideroak_app}"
fi


log "Finished successfully"

exit 0
