#!/bin/bash
#
# As the backups run you'll notice certain files that change often but are not
# really important to back up.  For example the .bash_history file changes
# often but not really important.  Run this for those files and directories and
# it will exclude that file or directory and then completely purge it from
# spideroak.  NOTE: This only purges it from spideroak and not the local file.
# Of course make sure you backup anything important before running this just in
# case.
#
# Note: I intentionally don't use the --force option. This means if you try to
# exclude a folder that doesn't exist it will complain. I do this assuming I
# typed the path in wrong. If it's expected then you can add "--force" to the
# functions

set -e
set -u


# SpiderOak was renamed to SpiderOakONE recently, so need to do all this stuff
if command -v SpiderOakONE 1>/dev/null; then
    spideroak_cmd=SpiderOakONE
elif command -v SpiderOak 1>/dev/null; then
    spideroak_cmd=SpiderOak
else
    echo "SpiderOak is not installed or not in path" >&2
    exit 101
fi



log () {
    printf "%b\n" "$(date +"%Y-%m-%dT%H:%M:%S%z") $*"
}

spideroak_cleanup_dir() {
    log "Exclude and Purge directory: $1"
    "${spideroak_cmd}" --exclude-dir="$1" >/dev/null
    "${spideroak_cmd}" --purge="$1" >/dev/null
}

spideroak_cleanup_file() {
    log "Exclude and Purge file: $1"
    "${spideroak_cmd}" --exclude-file="$1" >/dev/null
    "${spideroak_cmd}" --purge="$1" >/dev/null
}


# I typically keep these around but comment them out after I run them once.
spideroak_cleanup_dir "/root/.cache"

spideroak_cleanup_file "/root/.bash_history"
spideroak_cleanup_file "/root/.viminfo"


# Print out current selection
"${spideroak_cmd}" --selection

exit 0
