#!/bin/bash
#
# DESCRIPTION:
#	This script checks the logs for "too busy to service this request" and if found 250 out of 500 lines in log, returns 1
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#

FILE=`date +"%Y%m%d"`
OUT=`tail -n 500 /var/spool/torque/server_logs/${FILE} | grep -c "too busy to service this request"`

if [ "$OUT" -gt 250 ]
then
    echo "critical"
    exit 2
elif [ "$OUT" -gt 125 ]
then
    echo "warning"
    exit 1
else
    echo "PBS_SERVER is ok"
    exit 0
fi
