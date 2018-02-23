#!/bin/bash

# This script runs from cron and updates the local copies of our account database

# Check that wget is installed
if [[ ! -f /usr/bin/wget ]];
then
	/bin/logger -t nssdb_update "Wget not found, aborting."
	exit 1
fi

# Enter the working directory
cd /var/db
if [[ $? -ne 0 ]];
then
        /bin/logger -t nssdb_update "/var/db doesn't exist"
        exit 1
fi

# Retrieve the necessary files from animus
for DBFILE in group.cache group.cache.sha512 passwd.cache passwd.cache.sha512
do
	/usr/bin/rm ${DBFILE} 2>/dev/null >/dev/null
	/usr/bin/wget -O ${DBFILE} "http://animus.rcac.purdue.edu/nss_db/${DBFILE}" >/dev/null 2>/dev/null
	if [[ $? -ne 0 ]];
	then
		/bin/logger -t nssdb_update "Unable to retrieve ${DBFILE}, aborting"
		exit 1
	fi
done

# Sanity check the downloaded files
for CHKFILE in group.cache passwd.cache
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
/usr/bin/sort passwd.cache > passwd.sorted
/usr/bin/sort group.cache > group.sorted
/usr/bin/make
if [[ $? -ne 0 ]];
then
	/bin/logger -t nssdb_update "creating databases failed"
	exit 1
fi

# Clean up temporary files
for DBFILE in group.cache group.cache.sha512 passwd.cache passwd.cache.sha512 passwd.sorted group.sorted
do
	/usr/bin/rm ${DBFILE}
done

# Exit successfully
/bin/logger -t nssdb_update "Update nssdb successful."
exit 0
