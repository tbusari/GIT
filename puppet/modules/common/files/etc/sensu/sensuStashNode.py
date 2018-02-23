#!/usr/bin/env python

'''sensuStashNode.py

Stash a node and resolve all of its events if this script is called.
Requires an fqdn to stash. To be used in conjuction with staci.
'''

import sys, getopt, urllib2, json, time
from base64 import encodestring

def argParse(argv):
    hostname = False
    clear = False
    reason = False
    source = "STACI"
    try:
        opts, args = getopt.getopt(argv, "hn:cr:s:", ["help", "name", "clear", "reason", "source"])
    except getopt.GetoptError as e:
        print("Error: %s" % (str(e),))
        usage()
        sys.exit(1)
    for opt,arg in opts:
        if opt in ('-h', '--help'):
            usage()
            sys.exit()
        if opt in ('-n', '--name'):
            hostname = str(arg).lower()
        if opt in ('-c', '--clear'):
            clear = True
        if opt in ('-r', '--reason'):
            reason = str(arg)
        if opt in ('-s', '--source'):
            source = str(arg)
    if not hostname:
        print ("Error: hostname is required.")
        usage()
        sys.exit(1)
    return (hostname, clear, reason, source)

def usage():
    print '%s -n <fqdn> [-c]' % (str(sys.argv[0]),)
    print
    print '''Connects to sensu, stashes the fqdn in question,
          and clears all of its events. Clears the stash if -c is given.'''
    print
    print '-n\tRequired. FQDN of the machine to stash.'
    print '-c\tOptional. Clears the stash instead of adding machine to the stash. Also does not clear events.'
    print '-r\tOptional, but recommended. Adds a reason to the stash event.'
    print '-s\tOptional. Defines the source of the event. Defaults to STACI.'
    print

def checkForError(result):
    if "HTTPError" in result:
        print("The API Returned an error: %s" % (result["HTTPError"],))
        sys.exit(2)
    return False

def callSensuApi(endpoint, method="get", payload=False):
    if payload:
        payload = json.dumps(payload)
    endpoint = "/" + endpoint if endpoint[0] != "/" else endpoint

    apiurl = 'https://oculus.rcac.purdue.edu:5210' + endpoint
    with open('/etc/sensu/sensuApiAuth.json', 'r') as f:
        apiAuth = json.loads(f.read())
        apiuser = apiAuth['user']
        apipass = apiAuth['pass']

    # Man I wish I could use the requests library. This is a mess.
    try:
        opener = urllib2.build_opener(urllib2.HTTPHandler)
        request = urllib2.Request(apiurl, data=payload) if payload else urllib2.Request(apiurl)
        base64string = encodestring('%s:%s' % (apiuser, apipass)).replace('\n', '')
        request.add_header('Authorization', 'Basic %s' % base64string)
        request.get_method = lambda: method.upper()
        r = opener.open(request)
    except urllib2.URLError as e:
        return {'HTTPError': e.code}

    output = r.read()
    if output != "":
        return json.loads(output)
    else:
        return True


if __name__ == "__main__":
    hostname, clear, reason, source = argParse(sys.argv[1:])
    if clear:
        result = callSensuApi('/stashes/silence/' + hostname, method="delete")
        # This is weird, because even though any value is considered true, you
        # can test to see if the result is literally True. Silly python.
        if result != True and "HTTPError" in result and str(result["HTTPError"]) != "404":
            print("The API Returned an error: %s" % (result["HTTPError"],))
            sys.exit(2)
        sys.exit()
    else:
        # First, check if stashed by our source. If so, exit - nothing else to
        # do here.
        result = callSensuApi('/stashes/silence/' + hostname)
        if result != True and "HTTPError" in result and str(result["HTTPError"]) != "404":
            print("The API Returned an error: %s" % (result["HTTPError"],))
            sys.exit(2)
        elif result != True and "HTTPError" in result and str(result["HTTPError"]) == "404":
            # Now, stash the node. Don't want more events happening while we do
            # this.
            reason = reason if reason else " " # Convert "False" to a space. Just so it's not an empty string.
            payload = {'timestamp':int(time.time()), 'source': source, 'reason':reason}
            result = callSensuApi('/stashes/silence/' + hostname, method="post", payload=payload)
            checkForError(result)
            # Now get a list of all of the host's current events and clear them.
            events = callSensuApi('/events/' + hostname)
            checkForError(result)
            for event in events:
                result = callSensuApi('/events/' + hostname + '/' + event['check']['name'], method="delete")
                checkForError(result)
        sys.exit()
