#!/bin/bash
# This script runs once on the machine to bootstrap Puppet

REPO=RCAC-Bro-Configuration

/usr/bin/yum clean all
/usr/bin/yum -y install puppet-3.7.5-1.el7
/usr/bin/rm -rf /etc/puppet
/usr/bin/ln -s /root/$REPO/puppet /etc/puppet

# sync passwd and group db files before applying the common role
/usr/bin/yum -y install wget
/usr/bin/cp -f /etc/puppet/modules/common/files/etc/nsswitch.conf /etc/nsswitch.conf
/usr/bin/cp -f /etc/puppet/modules/common/files/var/db/Makefile /var/db
/usr/bin/cp -f /etc/puppet/modules/common/files/var/db/nssdb_update.sh /var/db

# need to add this group so nss-pam-ldapd package installs properly
groupadd -g 55 ldap

# update local copies of databases
/var/db/nssdb_update.sh

/usr/bin/puppet apply --logdest /var/log/puppet/puppet-apply-common.log /etc/puppet/manifests/common.pp
