#!/bin/bash
#
# Creates individual archives for each OS
#


set -e
set -u


# -- Script-wide variables --
# set script_dir to location this script is running in
readonly script_dir="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
# where built archives will be
readonly build_dir="${script_dir}/build"

cd "${script_dir}"


# -- Logging functions --
# Usage: log "What to log"
log () {
    # logger will output to syslog, useful for background tasks
    #logger -s -t "${script_name}" -- "$*"
    # printf is good for scripts run manually when needed
    printf "%b\n" "$(date +"%Y-%m-%dT%H:%M:%S%z") $*"
}


# Checks if given executable exists or exits
check_command () {
    local command_name
    command_name="$1"

    if ! command -v "${command_name}" 1>/dev/null 2>&1; then
        echo "${command_name} is not installed or not in path" >&2
        exit 100
    fi
}


# Use 7zip to create the zip files since it's more commonly installed than the
# zip command.  Make zip files in Windows since the usability is much better
# compared to tgz files.
check_command 7za

# Double check tar and gzip commands exist but don't think I've seen that
# tar uses gzip command when you specify -z so it's required
check_command tar
check_command gzip

# Version including the project name (which is the name of this folder)
version="${script_dir##*/}-$(git describe --always)"


# Don't create extra ._. files on mac (really should be in .bashrc but just in
# case)
export COPYFILE_DISABLE=true


# always recreate build directory
rm -rf "${build_dir}"
mkdir "${build_dir}"

# all this directory creation and copying is so the files will be in a properly
# named subdirectory. This is why I couldn't use the git archive command
for os_name in windows linux mac; do
    _version_os="${version}-${os_name}"
    mkdir "${build_dir}/${_version_os}"
    cd "${script_dir}/${os_name}"
    cp -X ./* "${build_dir}/${_version_os}/"
    cd "${build_dir}"
    if [[ "${os_name}" == 'windows' ]]; then
        7za a "${_version_os}.zip" -bd -tzip "${_version_os}" >/dev/null
    else
        tar czf "${_version_os}.tgz" "${_version_os}"
    fi
    unset _version_os
done

exit 0
