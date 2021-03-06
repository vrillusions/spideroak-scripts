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
# 100 - script lockfile exists so not running
# 101 - the `SpiderOak` command doesn't exist in $PATH
# 102 - SpiderOak is already running (SpiderOak checks this as well but it
#       still (wrongfully IMO) returns an exit code of 0 so can't rely on it)

set -e
set -u


# -- script constants --
# What directory this will use for a lock file
_lockfile="/var/lock/run_spideroak.lock"


# -- logging functions --
# Usage: log "whatever you want to log"
log () {
    if [[ "${quiet:-false}" == "false" ]]; then
        printf "%b\n" "$(date +"%Y-%m-%dT%H:%M:%S%z") $*"
    fi
}


# -- create a flock dir --
__sig_exit () {
    rmdir "${_lockfile}"
}
if ! mkdir "${_lockfile}" 2>/dev/null ; then
    echo "unable to create lock file, exiting" >&2
    exit 100
fi
trap __sig_exit EXIT


# -- option handling --
# defaults
verbose_logfile='/dev/null'
quiet='false'
selection_file='/root/spideroak-selection.txt'
purge_days=90

while getopts ":hp:qs:v:" opt; do
    case ${opt} in
    h)
        echo "Usage: $(basename "$0") [OPTION]"
        echo 'Run spideroak and maintenance tasks'
        echo
        echo 'Options:'
        echo '  -h  this help message'
        echo "  -p  purge files deleted more than this many days (default: ${purge_days})"
        echo '  -q  suppress all output other than errors'
        echo "  -s  write current selection to this file (default: ${selection_file})"
        echo "  -v  verbose log file (default: ${verbose_logfile})"
        exit 0
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
shift $(( OPTIND - 1 ))


# SpiderOak was renamed to SpiderOakONE recently, so need to do all this stuff
if command -v SpiderOakONE 1>/dev/null; then
    spideroak_cmd=SpiderOakONE
elif command -v SpiderOak 1>/dev/null; then
    spideroak_cmd=SpiderOak
else
    echo "SpiderOak is not installed or not in path" >&2
    exit 101
fi


# Check if SpiderOak is already running and cancel if it is
spideroak_running="$(pgrep ${spideroak_cmd} &>/dev/null; echo $?)"
if [[ "${spideroak_running}" -eq "0" ]]; then
    echo "SpiderOak is already running, not rerunning" >&2
    exit 102
fi


# Get a list of selections since you can't easily pull this from SpiderOak
log "Save backup selection to file"
${spideroak_cmd} --selection >"${selection_file}"


# Intentionally overwrites logfile to prevent it from filling disk
log "Running SpiderOak"
${spideroak_cmd} --verbose --batchmode >"${verbose_logfile}"


# Does default schedule:
#   - hourly for last 24 hours
#   - daily for last month
#   - weekly thereafter
log "Purge historical versions"
${spideroak_cmd} --verbose --purge-historical-versions >>"${verbose_logfile}"


# Remove items from trash. To keep forever comment or remove line
log "Purge deleted items"
${spideroak_cmd} --verbose --purge-deleted-items="${purge_days}" >>"${verbose_logfile}"


log "Finished successfully"

exit 0
