#!/usr/bin/python

'''

    check-package-version

DESCRIPTION:
   Checks a package version against a given yum repository. This repository does
   not need to be installed on the machine, in fact it is recommended to not be
   installed on the machine, as there are other methods (namely yum) for checking
   these.

OUTPUT:
   plain text

PLATFORMS:
   Linux

DEPENDENCIES:
   python

USAGE:
   check-package-version.py -r http://repos.sensuapp.org/yum/el/6/x86_64 -p sensu -v 0.18.1

NOTES:
   Written by Spencer Julian

LICENSE:
   Copyright 2015 Purdue University.
'''

import sys, getopt, gzip, urllib2
from lxml import etree
from distutils.version import StrictVersion
from StringIO import StringIO

# These are just the exit values that sensu expects.
OK = 0
WARNING = 1
CRITICAL = 2
UNKNOWN = 3

def argParse(argv):
    (repo, package, version) = [None] * 3
    crit = False
    try:
        opts, args = getopt.getopt(argv, "hr:p:v:c", ["help", "repo", "package", "version", "critical"])
    except getopt.GetoptError as e:
        print("Error: %s" % (str(e),))
        usage()
        sys.exit(UNKNOWN)
    for opt,arg in opts:
        if opt in ('-h', '--help'):
            usage()
            sys.exit()
        if opt in ('-r', '--repo'):
            repo = str(arg)
        if opt in ('-p', '--package'):
            package = str(arg)
        if opt in ('-v', '--version'):
            version = str(arg)
        if opt in ('-c', '--critical'):
            crit = True
    if not repo or not version or not package:
        print("Package, repo, and version are all required arguments.")
        usage()
        sys.exit(UNKNOWN)
    return (repo, package, version, crit)

def usage():
    print('%s -r <repository> -p <package> -v <version>' % (str(sys.argv[0]),))
    print
    print('Checks a yum repository for the given package and compares it to version. Warns by default if the repo is newer.')
    print
    print('-c\tFire a critical alert instead of a warning.')
    print('-r\tThe repository to check against.')
    print('-p\tThe package to check for.')
    print('-v\tThe version number to check for.')
    print

def getLatestVersion(filelist, package):
    root = etree.fromstring(filelist)
    version = "0.0"

    for i in root:
       if i.attrib['name'] == package:
           if StrictVersion(i[0].attrib['ver']) > StrictVersion(version):
              version = i[0].attrib['ver']

    return version

def getFilelist(repo):
    request = urllib2.Request('%s/repodata/filelists.xml.gz'%repo)
    request.add_header('Accept-encoding', 'gzip')
    response = urllib2.urlopen(request)
    buf = StringIO(response.read())
    f = gzip.GzipFile(fileobj=buf)
    data = f.read()

    return data

if __name__ == "__main__":
    repo, package, version, crit = argParse(sys.argv[1:])
    filelist = getFilelist(repo)
    latest = getLatestVersion(filelist, package)
    if StrictVersion(latest) > StrictVersion(version):
      print("Package %s version %s is available, and is newer than the checked version %s." % (package, latest, version))
      if crit:
        sys.exit(CRITICAL)
      else:
        sys.exit(WARNING)
