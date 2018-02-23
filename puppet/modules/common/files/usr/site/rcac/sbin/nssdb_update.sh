#!/bin/bash

# This script runs from cron and updates the local copies of our account database

# Check that wget is installed
if [[ ! -f /usr/bin/wget ]];
then
	/bin/logger -t nssdb_update "Wget not found, aborting."
	exit 1
fi

# Make a working directory
TMPDIR=`/bin/mktemp -d`
if [[ $? -ne 0 ]];
then
	/bin/logger -t nssdb_update "Mktemp failed, aborting."
	exit 1
fi

# Enter the working directory
cd $TMPDIR
if [[ $? -ne 0 ]];
then
        /bin/logger -t nssdb_update "Temp directory unavailable, aborting."
        exit 1
fi

# Retrieve the necessary files from animus
for DBFILE in group.db group.db.sha512 passwd.db passwd.db.sha512
do
	/usr/bin/wget -O ${TMPDIR}/${DBFILE} "http://animus.rcac.purdue.edu/nss_db/${DBFILE}" >/dev/null 2>/dev/null
	if [[ $? -ne 0 ]];
	then
		/bin/logger -t nssdb_update "Unable to retrieve ${DBFILE}, aborting"
		exit 1
	fi
done

# Sanity check the downloaded files
for CHKFILE in group.db passwd.db
do
	if [[ ! -s ${CHKFILE} || ! -s ${CHKFILE}.sha512 ]];
	then
		/bin/logger -t nssdb_update "File is zero length ${CHKFILE}, aborting"
		exit 1
	fi

	/bin/sed -e "s/\/var\/db\/nss_db_master\///g" -i ${CHKFILE}.sha512
	if [[ $? -ne 0 ]];
	then
		/bin/logger -t nssdb_update "File checksum fix failed on ${CHKFILE}.sha512, aborting"
		exit 1
	fi

	/usr/bin/sha512sum -c ${CHKFILE}.sha512 >/dev/null 2>/dev/null
	if [[ $? -ne 0 ]];
	then
		/bin/logger -t nssdb_update "File checksum failed on ${CHKFILE}, aborting"
		exit 1
	fi
done

# Copy passwd.db into place
/usr/bin/install -m 444 -g root -o root ${TMPDIR}/passwd.db /var/db/passwd.db
if [[ $? -ne 0 ]];
then
	/bin/logger -t nssdb_update "Failed installing passwd.db, aborting"
	exit 1
fi

# Copy group.db into place
/usr/bin/install -m 444 -g root -o root ${TMPDIR}/group.db /var/db/group.db
if [[ $? -ne 0 ]];
then
	/bin/logger -t nssdb_update "Failed installing group.db, aborting"
	exit 1
fi

# Clean up working directory
/bin/rm -r ${TMPDIR}
if [[ $? -ne 0 ]];
then
	/bin/logger -t nssdb_update "Failed cleaning up tmp directory ${TMPDIR}, aborting"
	exit 1
fi

# Exit successfully
/bin/logger -t nssdb_update "Update nssdb successful."
exit 0
