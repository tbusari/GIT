#!/bin/bash
#
# DESCRIPTION:
#   Checks if the login page passed as an argument loads correctly
#
# OUTPUT:
#	plain text
#
# PLATFORMS:
#   Linux
#
# USAGE:
#   ./check-login.sh <page URL>
#   (Example: ./check-login.sh https://scholar.rcac.purdue.edu:8787/auth-sign-in)

# URL
URL=$1;

# Reading the HTML
out=$(curl -k -s -m 60 $1)

#Patterns to look for
searchString1="username"
searchString2="password"
searchString3="submit"

# Processing Variables
successCount=0
increment=1

# Checking if the page is online

if $(echo ${out} | grep "${searchString1}" 1>/dev/null 2>&1);
then
	successCount=$(expr "$successCount" + "$increment")
fi

if $(echo ${out} | grep "${searchString2}" 1>/dev/null 2>&1);
then
	successCount=$(expr "$successCount" + "$increment")
fi

if $(echo ${out} | grep "${searchString3}" 1>/dev/null 2>&1);
then
	successCount=$(expr "$successCount" + "$increment")
fi

if [ $successCount -eq 3 ]
then
	echo "$1 is online";
	exit 0;
else
	echo "critical"
	echo "$1 is currently down"
	exit 2;
fi
