#!/usr/bin/env python

# A quick script that checks if the client exists, and if so, deletes it from
# sensu.

# I want to use requests, but it's not in the standard library and it's not
# really worth installing it everywhere.

import urllib2, socket, json, sys
from base64 import b64encode

hostname = socket.getfqdn()
hostname = hostname if hostname != '' else socket.gethostname()

checkHostUrl = "https://oculus.rcac.purdue.edu:5210/clients/%s" % (hostname,)
with open('/etc/sensu/sensuApiAuth.json', 'r') as f:
    apiAuth = json.loads(f.read())
    apiuser = apiAuth['user']
    apipass = apiAuth['pass']

request = urllib2.Request(checkHostUrl)
request.add_header('Authorization', 'Basic ' + b64encode('%s:%s' % (apiuser,apipass)))
try:
    r = urllib2.urlopen(request)
    exitCode = r.getcode()
except urllib2.HTTPError, e:
    if e.code == 404:
        print "Host %s not found so it could not be deleted." % (hostname,)
    elif e.code == 401:
        print "Username and password invalid. Check the script and try again."
    elif e.code == 500:
        print "Server error."
    else:
        print "An unknown error occured: %s" % (str(e),)
    sys.exit(0)

if exitCode == 200:
    request = urllib2.Request(checkHostUrl)
    request.add_header('Authorization', 'Basic ' + b64encode('%s:%s' % (apiuser,apipass)))
    request.get_method = lambda: 'DELETE'
    try:
        r = urllib2.urlopen(request)
        exitCode = r.getcode()
    except urllib2.HTTPError, e:
        if e.code == 401:
            print "Username and password invalid. Check the script and try again."
        elif e.code == 404:
            print "Host %s not found, could not be deleted." % (hostname,)
        elif e.code == 500:
            print "Server Error."
        sys.exit(0)
