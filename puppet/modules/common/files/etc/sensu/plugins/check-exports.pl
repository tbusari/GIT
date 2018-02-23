#!/usr/bin/perl

# This is just a really simple PERL script to check that blizzard's /export
# filesystem is successfully exported.
#
# It looks for lines that begin with "/" to determine what are real exports
# from "showmount -e" and /etc/exports.  This handles all our (RCAC) current
# cases.  This does NOT handle the case where an export spans more than one
# line.  It also doesn't look at how or to whom a filesystem is exported.
#
# If no filesystem is exported then a CRIT error is returned.
#
# If a filesystem is listed in /etc/exports but doesn't show up in
# "showmount -e" then a CRIT error is returned.
#
# If a filesystem shows up in "showmount -e" but is not listed in /etc/exports,
# then a WARN error is returned.
#
# If "showmount -e" and /etc/exports agree, then the script exits with
# OK status.  (At least 1 filesystem must be exported.)
#
# By Don Kindred

use strict;
use warnings;

# Sensu exit status (warning level).
use constant UNKNOWN => 3;
use constant CRIT => 2;
use constant WARN => 1;
use constant OK => 0;
use constant EXPORTSFILE => "/etc/exports";

# get the list of filesystems that are actually exported, as reported by
# "showmount -e"

my (%exports, @exportlist, $fs, $rest);
my ($i);

@exportlist = `showmount -e 2>/dev/null | grep "^/"`;

for ( $i = 0 ; $i <= $#exportlist ; $i++) {
    ($fs,$rest) = split(/\s+/, $exportlist[$i]);
    $exports{$fs} = 1;
}

# get the list of directories that are supposed to be exported from
# /etc/exports

my (%fexports,@fexportlist,$cmd);
my ($extraexports,$notexported,$key);

$cmd = "grep \"^/\" ".EXPORTSFILE;

@fexportlist = `$cmd`;

for ( $i = 0 ; $i <= $#fexportlist ; $i++) {
    ($fs,$rest) = split(/\s+/, $fexportlist[$i]);
    $fexports{$fs} = 1;
}

# Require at least one filesystem to be exported.
if ( $i < 1 ) {
    print "EXPORTS CRITICAL - nothing exported\n";
    exit CRIT;
}

# foreach export in /etc/exports, make sure "showmount -e" lists it.
# If it doesn't list it, then add it to the list of exports that are not
# actually exported.

$notexported = "";
foreach $key ( keys %fexports ) {
    if (!defined($exports{$key})) {
        $notexported .= " $key";
    }
}

# foreach export reported by "showmount -e", make sure it is listed in
# /etc/exports.  If it isn't listed, then add it to the list of exports
# that are exported but not listed.

$extraexports = "";
foreach $key ( keys %exports ) {
    if (!defined($fexports{$key})) {
        $extraexports .= " $key";
    }
}

if ($notexported eq "") {
    if ($extraexports eq "") {
        print "EXPORTS OK - appropriately exported\n";
        exit OK;
    } else {
        print "EXPORTS WARNING -$extraexports exported\n";
        exit WARN;
    }
} else {
    print "EXPORTS CRITICAL -$notexported not exported\n";
    exit CRIT;
}

