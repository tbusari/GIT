#!/bin/bash
#
# DESCRIPTION:
#   This script verifies that a file's mtime is recent.
#   Originally intended to verify that GitHub Enterprise backups are still
#   being created.
#
# OUTPUT:
#   Plain text
#
# PLATFORMS:
#   Linux
#
# Usage
#   ./check-file-mtime.sh <dir or file to check> <time in seconds> (e.g. ./check-file-mtime.sh /depot/itap/github-backups/current 86400)
#
file=$1
check_time=$2
current_date=$(date +%Y-%m-%d\ %H:%M:%S)
file_mtime_date=$(date --reference=${file})
# Compute the seconds since epoch
file_mtime_date_secs=$(date --date="$file_mtime_date" +%s)
current_date_secs=$(date --date="$current_date" +%s)

# Compute the difference in dates in seconds
let "time_diff=${current_date_secs}-${file_mtime_date_secs}"
# Compute the approximate day difference
let "day_diff=${time_diff}/86400"

if [ $time_diff -gt $check_time ]; then
    echo "$file has not been modified in over $time_diff seconds ($day_diff days)"
    exit 2
else
    echo "$file has been successfully backed up in the past $check_time seconds"
    exit 0
fi
