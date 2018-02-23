#!/bin/bash
#
# DESCRIPTION:
#   This script checks the mount entered into the command, it kills the command if it takes longer than 60s and then sends a critical alert
#
# OUTPUT:
#   Plain text
#
# PLATFORMS:
#   Linux
#
#Usage
#   ./check-mount.sh <mount point>  (ex: ./check-mount.sh /depot)
#

timeout -s 9 60 stat $1 &>/dev/null
if (( `echo $?` == 0 ))
    then
        echo "$1 is ok"
    else
        echo "$1 is broken"
        echo "critical"
        exit 2
fi
