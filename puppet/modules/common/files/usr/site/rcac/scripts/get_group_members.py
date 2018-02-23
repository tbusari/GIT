#!/usr/bin/python
""" Prints members of a group with the given delimiter to a specified file (or stdout)
"""

__author__ = 'Randy Herban rherban@purdue.edu'

import os
import optparse
import sys
import subprocess

parser = optparse.OptionParser()
parser.add_option('-g', '--group', dest='groupname', help='Group name to retrieve')
parser.add_option('-d', '--delimiter', dest='delimiter', default=',',
		help='Delimiter to use when printing the users, values are any String Literal '
		'[default: ,]')
parser.add_option('-f', '--filename', dest='filename', help='Filename to write the group members to. ' 
		'[defaults to standard output]', default=None)
(options, args) = parser.parse_args()

if options.groupname == None:
    print >> sys.stderr, 'Group not defined (use --group [-g] flag), exiting.'
    sys.exit(1)
    
group = os.popen('/usr/bin/getent group ' + options.groupname)
users = group.read().strip().split(':')[-1].split(',')

gid = subprocess.Popen('/usr/bin/ldapsearch -x -h animus.rcac.purdue.edu -b "cn=' + options.groupname + ',ou=Group,dc=rcac,dc=purdue,dc=edu" "gidNumber" | grep "^gidNumber: " | cut -d " " -f 2', shell=True, stdout=subprocess.PIPE).communicate()[0].strip()
if gid:
	primary_users = subprocess.Popen('/usr/bin/ldapsearch -x -h animus.rcac.purdue.edu -b "ou=People,dc=rcac,dc=purdue,dc=edu" "gidNumber=' + gid + '" "uid" | grep "^uid: " | cut -d " " -f 2', shell=True, stdout=subprocess.PIPE).communicate()[0].strip().split('\n')
	if len(primary_users) > 0:
		if primary_users[0] != '':
			users += primary_users

if users == ['']:
    print >>sys.stderr,'Group has no members, exiting.'
    sys.exit(1)

users.sort()

delim = options.delimiter.replace('\\n', '\n').replace('\\t','\t')
delim = delim.replace('newline', '\n').replace('tab', '\t')
delim = delim.replace('space', ' ').replace('comma', ',')

user_list = delim.join(users)
if( options.filename is None ):
    print user_list
else:
    f = open(options.filename,'w')
    try:
        f.write(user_list + '\n')
    finally:
        f.close()


