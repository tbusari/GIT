#!/usr/bin/env python

import os,sys,getopt

cpusysdir = "/sys/devices/system/cpu"

def checkUser(uid):
    if os.geteuid() != 0:
        return False
    return True

def argParse(argv):
    parsedOptions = {'on':False, 'off':False}
    try:
        opts, args = getopt.getopt(argv, "hOo", ["help", "on", "off"])
    except getopt.GetoptError, e:
        print 'Error: %s' % (str(e),)
        usage()
        sys.exit(2)
    for opt, arg in opts:
        if opt in ('-h', '--help'):
            usage()
            sys.exit()
        if opt in ('-O', '--on'):
            parsedOptions['on'] = True
        if opt in ('-o', '--off'):
            parsedOptions['off'] = True
    if parsedOptions['on'] == True and parsedOptions['off'] == True:
        print("Hyperthreading cannot be both off and on at the same time.\n")
        usage()
        sys.exit(3)
    elif parsedOptions['on'] == False and parsedOptions['off'] == False:
        print("Hyperthreading must be set to either off or on.\n")
        usage()
        sys.exit(4)
    else:
        if parsedOptions['on']:
            return True
        elif parsedOptions['off']:
            return False
        else:
            return -1

def usage():
    print '%s --[on|off]' % (str(sys.argv[0]),)
    print
    print 'Enables or disables hyperthreading on the system.'
    print 'Requires root.'
    print
    print '-on\tTurn hyperthreading on'
    print '-off\tTurn hyperthreading off'

def HyperthreadingEnabled():
    with open('/proc/cpuinfo', 'r') as f:
        cpuinfo = f.readlines()

    cpuinfo = [x.strip().replace('/t', '') for x in cpuinfo]
    # Get number of CPUs based on highest physical id (which is id of chip package) + 1.
    cpus = max([int(x.split(':')[1]) for x in cpuinfo if "physical id" in x]) + 1
    # Get number of cores per physical CPU. These should all be the same, if they aren't, then there's a problem.
    listofcores = list(set([x.split(':')[1] for x in cpuinfo if "cpu cores" in x]))
    if len(listofcores) > 1:
        print("Core counts do not match, exiting.")
        sys.exit(7)
    physcores = int(listofcores[0])*cpus
    totcores = len([x for x in cpuinfo if 'processor' in x])
    if (totcores > physcores):
        return True
    else:
        return False

def toggleOff():
    if not HyperthreadingEnabled():
        print("Hyperthreading is already disabled on this system.")
        sys.exit(0)

    done = []
    for cpu in next(os.walk(cpusysdir))[1]:
        if not os.path.isdir("%s/%s/topology"%(cpusysdir,cpu)):
            continue
        with open("%s/%s/topology/thread_siblings_list"%(cpusysdir,cpu)) as f:
            coresfile = f.read()
        coresfile = coresfile.strip()
        cores = coresfile.split(",")
        if (len(cores) > 2):
            print("More than two cores per core, exiting")
            sys.exit(6)
        coretodo = cores[0] if int(cores[0]) > int(cores[1]) else cores[1]
        if coretodo in done:
            continue
        # print("Deactivate %s"%(coretodo,))
        with open("%s/cpu%s/online"%(cpusysdir,coretodo), "w") as f:
           f.write("0")
        done.append(coretodo)

def toggleOn():
    if HyperthreadingEnabled():
        print("Hyperthreading is already enabled on this system.")
        sys.exit(0)

    for cpu in next(os.walk(cpusysdir))[1]:
        if not os.path.isfile("%s/%s/online"%(cpusysdir,cpu)):
            continue
        with open("%s/%s/online"%(cpusysdir,cpu), "r") as f:
            on = f.read()
        on = int(on.strip())
        if not on:
            # print("Activate %s"%(cpu,))
            with open("%s/%s/online"%(cpusysdir,cpu), "w") as f:
               f.write("1")

if __name__ == "__main__":
    todo = argParse(sys.argv[1:])
    if todo == -1:
        print("An unknown error occurred.")
        usage()
        sys.exit(5)

    if not checkUser(os.geteuid()):
        print("Root privileges required to toggle hyperthreading, try again.")
        usage()
        sys.exit(1)

    if todo:
        toggleOn()
        if HyperthreadingEnabled():
            print("Hyperthreading has been enabled.")
        else:
            print("There has been a problem. Double check your cpu settings.")
    else:
        toggleOff()
        if not HyperthreadingEnabled():
            print("Hyperthreading has been disabled.")
        else:
            print("There has been a problem. Double check your cpu settings.")
