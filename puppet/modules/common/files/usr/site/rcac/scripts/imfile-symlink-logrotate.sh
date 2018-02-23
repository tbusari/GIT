#!/bin/bash

# Usage
# imfile-symlink-logrotate.sh directory filename
# Assumes the last updated file in a directory is the current log file. This
# isn't necessarily true if there are multiple log files stored in this directory
# so this should be updated for that sometime.
#
# Spencer Julian
# Purdue University 2015

usage() {
    echo "Usage: $0 directory filename"
    echo ""
    echo "Checks directory for the most recently updated file, and creates or"
    echo "updates a symlink at filename pointing to that file."
    exit 1
}

get_latest_file(){
    local dir="$1"
    unset -v latest
    [[ ! -d "$dir" ]] && return 92
    for file in "$dir"/*; do
        [[ $file -nt $latest ]] && latest=$file
    done
    [[ -z "$latest" ]] && return 91 || return 0
}

[[ $# -ne 2 ]] && usage

get_latest_file "$1" || echo "The directory is empty or does not exist."
if [ "$(readlink $2)" != "$latest" ]; then
    if [ -L "$2" ]; then
        rm "$2"
    fi
    ln -s "$latest" "$2"
fi
