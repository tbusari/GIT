#!/usr/bin/env perl
#
# NOTE: This script has a DEBUG mode ('-d' option) so that it can be run
# from the command line
#
#   update_kickstand.pl -d [any-other-arguments]
#
# and list on STDOUT any data that would be sent to the Kickstand instead of
# updating the Kickstand. The DEBUG output should be the same as that
# written to the Kickstand during a cronjob run.
#
# Future script editors:
# If you make any changes that add a write to the Kickstand, please include
# an alternate DEBUG section that displays the new data without actually
# doing the Kickstand write.
#
# For safetys sake while you are debugging new code, it would probably
# be best if you set $DEBUG = 1 below (I got bit so I'm paranoid).
#
# Note: All references to CMDB were changed to Kickstand (Edited by Kurt Kroeger)
#
#     Table of Contents 
# ---------------------------
# | Line Number |  Contents |
# ---------------------------
#      32         Get options
#      71         Check host status in cmdb
#      120        Find networking information
#      190        Check for /etc/hosts IP mismatch
#      212        Retrieve system information
#      247        Identify the Linux flavor
#      303        Check CPU information
#      329        Check memory information
#      357        System information
#      650        Check for Hardware Changed
#      778        Resource (Add new clusters here)
#      1030       Get disk information
#      1178       Add Events
#

use Kickstand;
use Getopt::Long;
use Socket;
use POSIX qw/uname/;
use feature qw/switch/;

$cmdb   = new Kickstand;

$DEBUG = 0;
$ENV{PATH} = "/usr/bin:/bin:/usr/sbin:/sbin:$ENV{PATH}";
%inputs = ();

GetOptions (
  "debug|d"     => \$DEBUG,
  "ipaddress=s" => \$inputs{ipaddress},
  "reinstall"   => \$inputs{reinstall},
  "kernel"   	=> \$inputs{kernel},
);

$unameoutput=`uname --all`;
@uname = split(' ', $unameoutput);

$osname = lc($uname[0]);

# Not into 'sparc' hardware variants, just the 'x86' variants.
#
exit 0 if $osname eq 'sunos' && $uname[4] ne 'i86pc';

# Make sure that we have the host's canonical name and its ipaddress.
#
if (defined($inputs{ipaddress})) {
  @host = gethostbyaddr(inet_aton ($inputs{ipaddress}), AF_INET);
  die "gethostbyaddr($inputs{ipaddress}, AF_INET) died or returned NULL"
  if ! defined(@host) || @host == 0;
}
else {
  $host = $uname[1];		# probably the fqhost name but ...
  @host = gethostbyname($host);
  die "gethostbyname($host) died or returned NULL"
  if ! defined(@host) || @host == 0;
  $inputs{ipaddress} = inet_ntoa ($host[4]);
}
($inputs{shorthost} = $host[0]) =~ s,\..*$,,;
$inputs{fqhost} = $host[0];

# If the host's entry doesn't exist in the Kickstand, add it.
#
$hostid = $cmdb->GetHostID ($inputs{fqhost});
if ($hostid == 0) {
  if (! $DEBUG) {
    $hostid = $cmdb->AddHost ($inputs{fqhost});
    if (! $hostid || $hostid == 0) {
      die "Failed to add new host\n";
    }
  }
  $new_host = 1;
}

# If we're being reinstalled, update the database and exit.
#
if ($inputs{reinstall}) {
  if ($new_host) {
    myAddEvent ($inputs{fqhost}, 'Installed',
      'This host was installed.', 'closed')
      or die "Failed to add event - new installation\n";
  }
  else {
    %hash = (installdate => 'now()');
    myUpdateHost ($inputs{fqhost}, \%hash)
      or die "Failed to update host - reinstall date\n";
    myAddEvent ($inputs{fqhost}, 'Reinstall',
      'This host was reinstalled.', 'closed')
      or die "Failed to add new event - reinstallation\n";
  }
  exit;
}


# Since none of the OSs want to standardize their verbage, set some
# re patterns so that we can extract the IP address and the macaddress
# from the `ifconfig -a' output.
#
if ($osname eq 'linux') {
  $inet_pat  = 'inet addr:';
  $ether_pat = "HWaddr ";
}
else {
  $inet_pat = 'inet ';
  if ($osname eq 'sunos') {
    $ether_pat = "ether ";
  }
  elsif ($osname eq 'aix') {
    $ether_pat = "Hardware Address: ";
  }
}

# Scan the `ifconfig -a' output.  Save each non-loopback entry as a
# single string.  All "$eth = bond*" entries will be last.  Also scan
# for an entry that has the same IP address as that supplied by the
# arguments.
#
$found_ip        = 0;
$allips          = '';
@bondedeth       = ();
@ifconfig        = ();
$eth             = "lo";
$ethentry        = "";
$saved_bondedmac = "NONE";

$inputs{ipaddress} =~ s/\s+$//;

open (IFCONFIG, "ifconfig -a 2>/dev/null|");
while (<IFCONFIG>) {
  chomp;
  if (/^((\w+(:\d+)?)[:\s])/) {
    push(@{$config}, $eth, $ethentry) if $ethentry;
    $eth             = $2;

# Is this a bonded entry?
    #
    if ($ethentry =~
      /^bond.*$ether_pat(([\da-fA-F]{1,2}[:-]){5}[\da-fA-F]{1,2})/o) {
      $saved_bondedmac = uc($2);
      $saved_bondedmac =~ s,\b([A-Z\d])\b,0$1,;
    }

# Extract the IP, if any, and attempt to verify that the IP address
# specified in "$inputs{ipaddress}" is really an enabled network
# interface.
    #
    if ($ethentry =~ /$inet_pat(((\d{1,3}\.){3}\d{1,3}) )/o) {
      $allips .= $1;
      $allips =~ s/\s+$//;
      if (index($allips, $inputs{ipaddress}) != -1) {
        $found_ip = 1;
      }
    }

    $ethentry = "";
    $config = $eth =~ /^bond/ ? \@bondedeth : \@ifconfig;
  }
  $ethentry .= $_ if $eth !~ /^(lo|lo0|sit0|virbr0)$/;
}
close (IFCONFIG);

if ($ethentry =~ /$inet_pat(((\d{1,3}\.){3}\d{1,3}) )/o) {
  $allips .= $1;
  $allips =~ s/\s+$//;
  if (index($allips, $inputs{ipaddress}) != -1) {
    $found_ip = 1;
  }
}

push(@{$config}, $eth, $ethentry) if $ethentry;
push(@ifconfig, @bondedeth);	# /^bond*/ entry(ies) last 

# Scan the events table for this machine and determine if there's an
# 'open' IP/DNS "do not match" entry.
#
my $skip_hosts_complaint = 0;
$hosts_complaint_subject = 'IP and /etc/hosts do not match';
$result = $cmdb->ListEvents ($inputs{fqhost}, 'open');
foreach my $li (@{$result}) {
  if ( $li->{subject} eq $hosts_complaint_subject
    && $li->{status} eq 'open') {
    $skip_hosts_complaint = 1;
    last;
  }
}

$ipnomatchymsg =
"The IP from ifconfig and the IP from host are different. "
. "Here is what we have\n\n From /etc/hosts by way of puppet "
. "we have $inputs{ipaddress}.\nFrom ifconfig we have $allips"
. "\nThis may affect Nagios monitoring of this host.";

# If the IP/DNS match, close an 'open' "do not match" event entry.
#
if ($found_ip) {
  if ($skip_hosts_complaint) {
    myCloseIPEvent() or die "Failed to close IP event\n";
  }
}

# Else, if the IP/DNS is a "do not match" condition, create an 'open'
# event entry describing it if an entry doesn't already exist.
#
elsif (! $skip_hosts_complaint) {
  myAddEvent ($inputs{fqhost}, $hosts_complaint_subject,
    $ipnomatchymsg, 'open')
    or die "Failed to add event - IP/hosts don't match\n";
}

# Get box info.
#
%ethdevhardware = ();
$building       = "";
$ibhardware     = "";
$infiniband     = "N";
$memory         = "";
$os             = "";
$osversion      = "";
$procfamily     = "";
$procspeed      = "";
$proctype       = "";
$room           = "";
$serial         = "";
$switchaddr     = "";
$switchname     = "";
$switchport     = "";
$vendor         = "";
%mult           = (
  b         => 1,
  bytes     => 1,
  kb        => 1024,
  kilobytes => 1024,
  mb        => 1048576,
  megabytes => 1048576,
  gb        => 1073741824,
  gigabytes => 1073741824
);
@disk  = ();
@space = ();

open (MOUNT, "mount |");

if ($osname eq 'linux') {
  $rootfs = $1 if <MOUNT> =~ m,^(\S+) .*$,;

# Identify the Linux flavor.
  #
  if (-f '/etc/SuSE-release') {
    $os = "suse";
    open (RELEASE, "/etc/SuSE-release");
    $n = 2;                    # count of entries for which to look
    foreach $li (<RELEASE>) {
      if ($li =~ /VERSION\s*=\s+(.*)$/) {
        $versionmajor = $1;
        last unless --$n;
      }
      elsif ($li =~ /PATCHLEVEL\s*=\s+(.*)$/) {
        $versionminor = $1;
        last unless --$n;
      }
    }
    $versionminor = $versionminor || '0';
    $osversion = "$versionmajor.$versionminor";
  }

  elsif (-f '/etc/redhat-release') {
    $os = "redhat";
    open (RELEASE, "</etc/redhat-release");
    $result = <RELEASE>;
    if ($result =~ /release 4/) {
      $result =~ /.*(\d+) \(.*(\d+)\)/;
      $osversion = "$1.$2";
    }
    else {
      $result =~ /.*release (\d+)\.(\d+).*/;
      $osversion = "$1.$2";
    }
  }

  elsif (-f '/etc/lsb-release') {
    open (RELEASE, "</etc/lsb-release");
    $n = 2;                    # total entries for which to check
    while (<RELEASE>) {
      if (/DISTRIB_ID\s*=\s*(.*?)\s*$/) {
        $os = lc($1);
        last unless --$n;
      }
      elsif (/DISTRIB_RELEASE\s*=\s*(.*)\s*$/) {
        $osversion = $1;
        last unless --$n;
      }
    }
  }

  elsif (-f '/etc/debian_version') {
    $os = "debian";
    open (RELEASE, "</etc/debian_version");
    chomp($osversion = <RELEASE>);
  }
  close (RELEASE);

# Get what the OS thinks about the cpus.
  #
  open (CPUINFO, '</proc/cpuinfo');
  @cpuinfo = <CPUINFO>;
  close (CPUINFO);

  $proccount = grep (/^processor/, @cpuinfo);

  $n = 3;                      # total entries for which to check
  foreach (@cpuinfo) {
    if (/^cpu MHz\s+:\s+(.*)$/) {
      $procspeed = $1;
      last unless --$n;
    }
    elsif (/^vendor_id\s+:\s+(.*)$/) {
      $vi = $1;
      last unless --$n;
    }
    elsif (/^model name\s+:\s+(.*?)\s*$/) {
      $mn = $1;
      last unless --$n;
    }
  }
  undef(@cpuinfo);
  $proctype = $mn ? $mn : $vi;

# Memory Device(s) (-t 17).  I think this is the only way to get the
# actual installed memory on Linux boxes.
  #
  open (DMIDECODE, "dmidecode -t 17 |");
  $memory = 0;
  while (<DMIDECODE>) {
    $memory += $1 * (($2) ? $mult{lc($2)} : 1)    # bytes
    if /^\s*Size:\s*(\d+)\s*(\w*)\s*/;
  }
  close (DMIDECODE);
  $memory = ($memory /= 1024 ) . " kB";     # kilobytes

# Get the hardware description string and its associated "bus-info"
# string for each "Ethernet controller".  Also identify the possible
# presence of an Infiniband device.
  #
  open (LSPCI, "lspci -D |");
  while (<LSPCI>) {
    if (/^(\S+)\s+Ethernet controller:\s*(.+?)(\s+\(rev \d+\))?\s*$/) {
      $ethdevhardware{$1} = $2;	# $1 = bus-info, $2 = description
    }
    elsif (/InfiniBand:\s*(.*)\s*\(rev/) {
      $infiniband = 'Y';
      $ibhardware = $1;
    }
  }
  close (LSPCI);

# System Information (-t 1).
  #
  open (DMIDECODE, "dmidecode -t 1 |");
  $n = 3;
  while (<DMIDECODE>) {
    if (/^\s*Manufacturer:\s*(.*?)\s*$/) {
      $vendor = $1;
      last unless --$n;
    }
    elsif (/^\s*Product Name:\s*(.*?)\s*$/) {
      $hardware = $1;
      last unless --$n;
    }
    elsif (/^\s*Serial Number:\s*(.*?)\s*$/) {
      $serial = $1;
      last unless --$n;
    }
  }
  close (DMIDECODE);

  if ( $serial =~ /VMware/
    || $serial eq "DELL"
    || $serial eq "0123456789ABCDEF"
    || $serial eq "1234567890"
    || $serial eq "Not Specified"
    || $serial eq "Not Available"
    || $serial =~ /\.{5}/
    || $hardware eq "HVM domU") {
    $serial = "";
  }

# Scan the `dmidecode' processor entry(ies) (-t 4).
  #
  open (DMIDECODE, "dmidecode -t 4 |");
  $n = 2;
  while (<DMIDECODE>) {
    if (/^\s*Version:\s*(.*?)\s*$/) {
      $pv = $1;
      last unless --$n;
    }
    elsif (/^\s*Family:\s*(.*?)\s*$/) {
      $pf = $1;
      last unless --$n;
    }
  }
  close (DMIDECODE);

  if ( $pf eq 'To Be Filled By O.E.M.'
    || $pf eq 'Other'
    || $pf eq 'Not Specified'
    || $pf eq 'Unknown'
    || $pf =~ /OUT OF SPEC/) {
    $pf = "";
  }
  if ( $pv eq 'To Be Filled By O.E.M.'
    || $pv eq 'Other'
    || $pv eq 'Not Specified'
    || $pv eq 'Unknown'
    || $pv =~ /OUT OF SPEC/) {
    $pv = "";
  }

# Let "Version" string override.
  #
  $procfamily = ($pv && $pv ne $proctype) ? $pv : $pf;

  if (-x '/usr/site/rcac/sbin/lldpctl') {
    open (LLDPCTL, "/usr/site/rcac/sbin/lldpctl |");
    while (<LLDPCTL>) {
      if (/\bMgmtIP: +((\d{1,3}\.){3}\d{1,3})/) {
        $switchaddr = $1;
      }
      elsif (/\bSysName: +((?!\s*Not received)[^\s\(]+)\b\s*\(?/) {
        $switchname = $1;
      }
      elsif (/\bPortID: +([^\(]+)\b\s*\(?/) {
        $switchport = $1;
      }
    }
    close (LLDPCTL);

# If we acquired the switch name but not it's IP address, we can acquire
# the IP the hard way.
    #
    if ($switchname && ! $switchaddr) {
      @host = gethostbyname($switchname);
      $switchaddr = inet_ntoa ($host[4]) if @host >= 5;
    }
  }

  $kernel            = $uname[2];

  @kernelbuilddate = @uname[5,6,7,8,9,10];
  $kernel_build_date = join(" ", @kernelbuilddate);
}

elsif ($osname eq 'sunos') {
  $rootfs = $1 if <MOUNT> =~ m,^\S+\s+on\s+(\S+) .*$,;

# SunOS/Solaris flavor.
  #
  open (RELEASE, "</etc/release");
  @os        = split(' ', <RELEASE>);
  $os        = $os[0];
  $osversion = "$os[1] $os[2]";
  close (RELEASE);

# Get cpu info and count.
  #
  @kstat = `kstat -m cpu_info`;

  $proccount = grep (/^module:/, @kstat);

  $n = 2;
  foreach (@kstat) {
    if (/^\s*clock_MHz\s+(.*)$/) {
      $procspeed = $1;
      last unless --$n;
    }
    elsif (/\s*vendor_id\s+(.^)$/) {
      $proctype = $1;
      last unless --$n;
    }
  }
  undef(@kstat);

# Get the real total memory.  `prtconf' displays the _SC_PHYS_PAGES
# value (real.total - kernel.memory, maybe?).  We have to sum the
# "Size:" values from all of the SMB_TYPE_MEMDEVICE displays.
  #
  open (SMBIOS, "smbios -t SMB_TYPE_MEMDEVICE |");
  $memory = 0;
  while (<SMBIOS>) {
    $memory += $1 if /^\s*Size:\s*(\d+)/;
  }
  close (SMBIOS);
  $memory = ($memory /= 1024 ) . " kB";    # kilobytes

# Get some system info.
  #
  open (SMBIOS, "smbios -t SMB_TYPE_SYSTEM |");
  $n = 3;
  while (<SMBIOS>) {
    if (/^\s*Manufacturer:\s*(.*?)\s*$/) {
      $vendor = $1;
      last unless --$n;
    }
    elsif (/^\s*Product:\s*(.*?)\s*$/) {
      $hardware = $1;
      last unless --$n;
    }

# Currently, the serial number in dcache-05's bios is actually the
# macaddress.  Ignore the value if it has a ':' in it.
    #
    elsif (/^\s*Serial Number:\s*([0-9A-Za-z:]+)\s*/) {
      $serial = $1 unless $1 eq "Not Available" || $1 =~ /:/;
      last unless --$n;
    }
  }
  close (SMBIOS);

# Kludge time at least until the actual serial number can be written
# in the bios.
  #
  $serial = "0850AMR015" if $inputs{shorthost} eq "dcache-09";
  $serial = "0850AMR012" if $inputs{shorthost} eq "dcache-11";

# Get processor info.
  #
  open (SMBIOS, "smbios -t SMB_TYPE_PROCESSOR |");
  $n = 2;
  while (<SMBIOS>) {
    if (/^\s*Version:\s*(.*?)\s*$/) {
      $proctype = $1;
      last unless --$n;
    }
    elsif (/^\s*Family:.*?\((.*?)\)\s*$/) {
      $procfamily = $1;
      last unless --$n;
    }
  }
  close (SMBIOS);

  $kernel = "$uname[0] $uname[2] $uname[3]";

# Get the compile time of the kernel.
  #
  open (PKGCHK, "pkgchk -lp /kernel/genunix 2>/dev/null |");
  while (<PKGCHK>) {
    next unless /^Expected last modification:\s*(.*?)\s*$/;
    $kernel_build_date = $1;
    last;
  }
  close (PKGCHK);
}

elsif ($osname eq 'aix') {
  $_ = <MOUNT>; $_ = <MOUNT>;  #skip first two lines of `mount' output
  $rootfs = $1 if <MOUNT> =~ m,^\s*(/dev/\S+),;

  $os              = $uname[0];
  chomp($osversion = `oslevel`);
  $vendor          = 'IBM';

# Get lots of system info.
  #
  $prtconf_pid = open (PRTCONF, "prtconf |");
  $n = 7;
  while (<PRTCONF>) {
    if (/^Number Of Processors: (\d+)\s*/) {
      $proccount = $1;
      last unless --$n;
    }
    elsif (/^Processor Clock Speed: (\d+)\s*/) {
      $procspeed = $1;
      last unless --$n;
    }
    elsif (/^Processor Type: (.*?)\s*$/) {
      $proctype = $1;
      last unless --$n;
    }
    elsif (/^Memory Size: (.*?)\s*$/) {
      $memory = $1;
      last unless --$n;
    }
    elsif (/^System Model:\s*(.*?)\s*$/) {
      $hardware = $1;
      last unless --$n;
    }
    elsif (/^Machine Serial Number:\s*(.*?)\s*$/) {
      $serial = $1;
      last unless --$n;
    }
    elsif (/Processor Implementation Mode:\s*(.*?)\s*$/) {
      ($procfamily = $1) =~ s,\s,,g;
      last unless --$n;
    }
  }
  kill 1, $prtconf_pid;
  close (PRTCONF);

  $kernel = "$uname[0]-$uname[3].$uname[2]";

# It's this date or earlier.
  #
  $kernel_build_date = localtime((stat("/unix"))[9]);
}

# Don't add Hardware Changed events if an identical issue is still open
#
my $eventlist = $cmdb->ListEvents ($inputs{shorthost}, 'open');
my %changelist;
for my $event (@{$eventlist}) {
  if ($event->{subject} eq "Hardware Changed") {

# Autovivify a key in the hash if we find a keyword in the body
    if ($event->{body} =~ /Hardware/) { $changelist{Hardware} = 1; }
    if ($event->{body} =~ /Serial/)   { $changelist{Serial}   = 1; }
    if ($event->{body} =~ /Processor_type/) {
      $changelist{Processor_type} = 1;
    }
    if ($event->{body} =~ /Processor_count/) {
      $changelist{Processor_count} = 1;
    }
    if ($event->{body} =~ /Processor_family/) {
      $changelist{Processor_family} = 1;
    }
    if ($event->{body} =~ /IP Address/) { $changelist{IP_Address} = 1; }
  }
}

# This is really gross overkill but match the name of the fields in the
# MySQL "rcac_cmdb.hosts" table with their lengths.
#
$db = $cmdb->{db};
$st = $db->prepare ("LISTFIELDS hosts");
$st->execute;

%len = ();
$l = $st->{mysql_length};	# array of field lengths
$i = 0;
foreach $field (@{$st->{NAME}}) { # array of field names
  $len{$field} = ${$l}[$i++];	# match name and length
}

# Grab info from the database and compare to local values.  If any are
# too different, leave an open event.  Don't worry if the database has
# no value.  Do worry if trying to blank out a value from the database.
# Some of the Kickstand values may be truncated versions of the locally
# acquired values so compare those Kickstand values to the first portion of
# their local counterpart.
#
my %hash = (hostname => $inputs{fqhost});
my $result = $cmdb->SearchHostsFull (\%hash);
$return = pop(@$result);
my $differences = '';

unless (exists($changelist{Hardware})) {
  if (($r = trim ($return->{hardware})) &&
    substr(($l = trim ($hardware)), 0, $len{hardware}) ne $r) {
    $differences .=
    "Hardware has changed:\n" .
    "  from; $r\n" .
    "  to;   $l\n";
  }
}

unless (exists($changelist{Serial})) {
  if (($r = trim ($return->{serial})) &&
    ($l = trim ($serial)) ne $r) {
    $differences .=
    "Serial has changed:\n" .
    "  from; $r\n" .
    "  to;   $l\n";
  }
}

unless (exists($changelist{Processor_type})) {
  if (($r = trim ($return->{processor_type})) &&
    substr(($l = trim ($proctype)), 0, $len{processor_type}) ne $r) {
    $differences .=
    "Processor_type has changed:\n" .
    "  from; $r\n" .
    "  to;   $l\n";
  }
}

unless (exists($changelist{Processor_count})) {
  if (($r = trim ($return->{processor_count})) &&
    ($l = trim ($proccount)) ne $r) {
    $differences .=
    "Processor_count has changed:\n" .
    "  from; $r\n" .
    "  to;   $l\n";
  }
}

unless (exists($changelist{Processor_family})) {
  if (($r = trim ($return->{processor_family})) &&
    substr(($l = trim ($procfamily)), 0, $len{processor_family}) ne $r) {
    $differences .=
    "Processor_family has changed:\n" .
    "  from; $r\n" .
    "  to;   $l\n";
  }
}

unless (exists($changelist{IP_Address})) {
  if (($r = trim ($return->{ipaddress})) &&
    ($l = trim ($inputs{ipaddress})) ne $r) {
    $differences .=
    "IP address has changed:\n" .
    "  from; $r\n" .
    "  to;   $l\n";
  }
}

if ( ($differences ne '')  && ($hardware != "Virtual Machine") ) {
  myAddEvent (
    $inputs{fqhost},
    'Hardware Changed',
    "The hardware on this machine has changed, here are the noted differences:\n$differences",
    'open'
  ) or die "Failed to add event - Hardware Changed\n";
}

# If we're updating the kernel, update the database and exit.
#
if ($inputs{kernel}) {
  %hash = (
    kernel            => $kernel,
    kernel_build_date => $kernel_build_date
  );
  myUpdateHost ($inputs{fqhost}, \%hash)
    or die "Failed to update host - kernel\n";
  exit;
}


%hash = (
  building          => $building,
  room              => $room,
  hostname          => $inputs{fqhost},
  hostnameshort     => $inputs{shorthost},
  processor_count   => $proccount,
  processor_type    => $proctype,
  processor_speed   => $procspeed,
  processor_family  => $procfamily,
  memory            => $memory,
  ipaddress         => $inputs{ipaddress},
  kernel            => $kernel,
  kernel_build_date => $kernel_build_date,
  os                => $os,
  hardware          => $hardware,
  serial            => $serial,
  osversion         => $osversion,
  infiniband        => $infiniband,
  lastupdate        => 'now()',
  active            => 'Y',
  ldapfilter        => $ldapfilter,
  vendor            => $vendor,
);

$ostype = $osname . "_" . $uname[12];
$hash{ostype} = $ostype;

# Set Location
#

$hash{building} = `facter -p building`;
chomp($hash{building});
$hash{room} = `facter -p room`;
chomp($hash{room});

if (index($hash{building}, 'unknown') != -1) {
  $hash{building} = "";
  $hash{room} = "";
} 

# Set Resource
#

$hash{resource} = `facter -p resource`;
chomp($hash{resource});
if ($hash{resource} eq "") {
  $hash{resource} = "backend";
}

# Check PBS Server
#

$hash{pbs_server} = "";

my $resourcetype = `facter -p resource_type`;
chomp($resourcetype);
if ($resourcetype eq "compute_cluster") {
  $hash{pbs_server} = $hash{resource} . "-adm";
}

=pod
# Check switch information
#

$hash{switch_name} = `facter -p router`;
chomp($hash{switch_name});

# If facter fails, say it's unknown
if (index($hash{switch_name}, 'unknown') != -1) {
  $hash{switch_name} = "Unknown";
  $hash{switch_ipaddress} = "";
  $hash{switch_port} = "";
}
else {

  # Call host to retrieve the switch IP
  $switchname = $hash{switch_name};
  $hash{switch_ipaddress} = `host $switchname | awk -F' ' '{print\$4}'`;
  chomp($hash{switch_ipaddress});

  # Remove the .tcom.purdue.edu part
  $hash{switch_name} = substr($hash{switch_name}, 0, index($hash{switch_name}, '.'));
  $hash{switch_port} = "";
}

$hash{switch_lastupdate} = 'now()'

if $switchname || $switchport || $switchaddr;

myUpdateHost ($inputs{fqhost}, \%hash)
  or die "Failed to update hosts table\n";
=cut
$cmdb->CheckSerialConflict ($inputs{shorthost}, $serial);

# Okay, let's process the previously acquired ethernet device
# descriptions.
#
@ethlist        = ();
$saved_ethspeed = "";
while ($eth = shift(@ifconfig)) {

  $ethactive    = 'N';
  $ethipaddress = "";
  $ethspeed     = "";
  $macaddress   = "";

  push(@ethlist, $eth);

  $_ = shift(@ifconfig);

  $ethactive    = 'Y' if /\bUP\b/;
  $ethipaddress = $1  if /$inet_pat((\d{1,3}\.){3}\d{1,3}) /o;

# Info for the AIX ethernet devices.
  #
  if ($osname eq 'aix') {
    open (ENTSTAT, "entstat -d $eth |");
    $n = 3;
    while (<ENTSTAT>) {
      if (/^Device Type:\s*(.*?)\s*\(\d/) {
        $ethhardware = $1;
        last unless --$n;
      }
      elsif (/$ether_pat(([\da-fA-F]{1,2}[:-]){5}[\da-fA-F]{1,2})/o) {
        $macaddress = uc($1);
        $macaddress =~ s,\b([A-F\d])\b,0$1,g;
        last unless --$n;
      }
      elsif (/^Media Speed Running:\s*(\d+\s*\w+)\s/) {
        $ethspeed = $1;
        last unless --$n;
      }
    }
    close (ENTSTAT);
  }
  else {

# The Solaris `ifconfig' displays the macaddress only when the user is
# root.  Use `arp $inputs{fqhost}' instead maybe?
    #
    if (/$ether_pat(([0-9a-fA-F]{1,2}[:-]){5}[0-9a-fA-F]{1,2})/o) {
      $macaddress = uc($1);
      $macaddress =~ s,\b([A-F\d])\b,0$1,g;
    }

    if ($osname eq 'sunos') {
      $eth =~ /^(\w+?)(\d+)$/;
      ($ethspeed = `kstat -p $1:$2:$eth:ifspeed`) =~ s,^.*?(\d+)\s*$,$1,;
      $ethspeed /= 1000000;
      $ethspeed .= "Mb/s";

# This really can't tell if the first ethernet controller listed is the
# actual controller for the ethernet device found.  It assumes that if
# there's more than one in the list then they all are the same.
      #
      open (SCANPCI, "/usr/X11/bin/scanpci |");
      while (<SCANPCI>) {
        next unless /^\s*(.*ethernet controller.*?)\s*$/i
        || /^\s*(nvidia.*ethernet)\s*/i;
        $ethhardware = $1;
        last;
      }
      close (SCANPCI);
    }

    elsif ($osname eq 'linux') {
      open (ETHTOOL, "ethtool $eth |");
      while (<ETHTOOL>) {
        next unless /^\s+Speed:\s*(\d+.*?)\s*$/;
        $ethspeed = $1;
        last;
      }
      close (ETHTOOL);

# Now get this device's bus-info and assign the hardware descriptive
# text that we got above via `lspci -D'.
      #
      open (ETHTOOL, "ethtool -i $eth 2>/dev/null |");
      while (<ETHTOOL>) {
        next unless /^bus-info:\s+(.*?)\s*$/;
        $ethhardware = $ethdevhardware{$1};
        last;
      }
      close (ETHTOOL);
    }
  }

# Bonded devices don't list a speed, use the speed found in the
# previously encountered device entry that had the same macaddress,
  #
  if ($eth =~ /^bond/) {
    $ethspeed = $saved_ethspeed if $ethspeed eq '0';
  }

# If this macaddress matches the above bonded device's mac, mark this
# device inactive.  Also, save the devices speed for the above check.
  #
  elsif ($macaddress eq $saved_bondedmac) {
    $ethactive      = 'N';
    $saved_ethspeed = $ethspeed;
  }

  elsif ($eth =~ /^ib/) {
    $ethhardware = $ibhardware;
  }

  %hash = (
    hostname     => $inputs{shorthost},
    action       => "update",
    eth          => $eth,
    macaddress   => $macaddress,
    ethhardware  => $ethhardware,
    ethspeed     => $ethspeed,
    ethactive    => $ethactive,
    ethipaddress => $ethipaddress
  );

  if ($DEBUG) {
    print "\n\"ethernet\" table update.\n";
    foreach $fieldname (sort(keys(%hash))) {
      printf "  %-17s => '%s'\n", $fieldname, $hash{$fieldname};
    }
  }
  else {
    $cmdb->UpdateEthernet (\%hash)
      or die "Failed to update ethernet table\n";
  }
}

# Disable all other entries for eth_devices that are no longer on the
# machine.
#
%hash = (
  hostname => $inputs{shorthost},
  action   => "deactivate",
  ethlist  => \@ethlist
);

if ($DEBUG) {
  print "\n\"ethernet\" table update.\n";
  $hash{ethlist} = join(' ', @ethlist);
  foreach $fieldname (sort(keys(%hash))) {
    printf "  %-17s => '%s'\n", $fieldname, $hash{$fieldname};
  }
}
else {
  $cmdb->UpdateEthernet (\%hash)
    or die "Failed to deactivate inactive network devices\n";
}

# Get data about the hard drive(s)
#
@space = ();
$disk = getdisk ($rootfs);

if (@space) {
  $space = join(', ', @space);

  if ($DEBUG) {
    print "\n\"disk\" table update.\n";
    print "  disk              =  '$disk'\n";
    print "  space             =  '$space'\n";
  }
  else {
    $cmdb->UpdateDisk ($inputs{shorthost}, $disk, $space)
      or die "Failed to update disk table\n";
  }
}

$cmdbgroups ="cmdb_puppet";

@groups = split(' ', $cmdbgroups);

my @grouplist = ();
foreach (@groups) {
  push(@grouplist, "'$_'");
}

if (@grouplist) {
  $grouplist = join(', ', @grouplist);
  if ($DEBUG) {
    print "\n\"groups\" table update.\n";
    print "  grouplist         =  $grouplist\n";
  }
  else {
    $cmdb->AddHostToGroups ($inputs{shorthost}, $grouplist)
      or die "Failed to update host $inputs{shorthost}'s groups\n";
  }
}
1;

sub trim($) {
  my $string = shift;
  $string =~ s/^\s+//;
  $string =~ s/\s+$//;
  return $string;
}

# Find the disks associated with the root filesystem as identified in
# the first line of `mount's output.  The rootfs can be a single disk or
# it can be a metadevice(Solaris), a multiple-device(Linux) or a logical
# volume(Linux and AIX) identifier.  Below
#
#   disk = a physical volume
#   lv   = logical volume
#   md   = metadevice or multiple-device identifier
#   vg   = a volume group
#
sub getdisk {
  my $fs    = shift;
  my @disk  = ();
  my $disk  = "";
  my $is_md = 0;

# Linux code can handle:
  #
#  disk       md     lv(vg)   lv(vg)
#              \        \        \
#            disk(s)  disk(s)    md(s)
  #
  if ($osname eq 'linux') {

# Can we isolate a "vg" from a "lv" identifier?
    #
    if ($fs =~ m,/dev/mapper/(\w+)(-.*)?$,) {
      open (VGS, "vgs --noheadings -o pv_name $1 |");
      while (<VGS>) {
        if (m, (/dev/\S+)\s*$,) {
          $disk = getdisk ($1);
          push(@disk, $disk) if $disk;
        }
      }
      close (VGS);
      return ("$fs (" . join(', ', @disk) . ')');
    }

# Else, is this a "md" device?
    #
    elsif ($fs =~ m,^/dev/md\d*$,) {
      open (MDADM, "mdadm -D $fs |");
      while (<MDADM>) {
        if (m, (/dev/\S+)\s*$,) {
          $disk = getdisk ($1);
          push(@disk, $disk) if $disk;
        }
      }
      close (MDADM);
      return ("$fs (" . join(', ', @disk) . ')');
    }

# Else, it had better be just a disk somewhere in "/dev/?".
    #
# Strip the instance number from the end of the disks identifier and use
# that as the argument to `fdisk' or `parted'.  Determine the size of
# the disk.
    #
    $fs =~ s,^(/dev(/cciss)?/\w+?)((\d)p)?\d+$,$1$4,;
  return (undef) unless $1;
  $space = 0;
  if (open (FDISK, "fdisk -l $fs |")) {
    $_ = <FDISK>;            # skip the first line
    $space = $1 if <FDISK> =~ /^Disk\s+$fs:\s*([\d.]+\s*\w*)/;
    close (FDISK);
  }
  elsif (open (PARTED, "parted -s $fs print |")) {
    while (<PARTED>) {
      next unless /^Disk\s+$disk:\s+([\d.]+\s*\w*)/;
      $space = $1;
      last;
    }
  }

# Save the disk size and return the disk name without the instance id.
  #
  push(@space, $space);
  return ($fs);
}

# SunOS (Solaris) code can handle:
#
#  disk       md
#              \
#            disk(s)
#
elsif ($osname eq 'sunos') {

# Is it a metadevice identifier.
  #
  if ($fs =~ m,^/dev/md(/\w+)?/dsk/,) {
      open (METASTAT, "metastat $fs |");
      while (<METASTAT>) {
        if (/\s(c\d+t\d+d\d+s\d)\s/) {
          $disk = getdisk ("/dev/dsk/$1");
          push(@disk, $disk) if $disk;
        }
      }
      return ("$fs (" . join(', ', @disk) . ')');
    }

# Else, it had better be the path of a standard Solaris disk.
    #
# Isolate the "c\d+t\d+d\d+" portion of the path.  Use `iostat' to
# to determine the size of that disk.
    #
    $fs =~ s,^(/dev/dsk/(c\d+t\d+d\d+))(s\d+)?$,$1,;
    return (undef) unless $1;
    $disk  = $2;
    $space = 0;
    open (IOSTAT, "iostat -En $disk |");
    while (<IOSTAT>) {
      next unless /^Size:\s(\S+)/;
      $space = $1;
      last;
    }
    close (IOSTAT);
    push(@space, $space);
    return ($fs);
  }

# AIX code can handle:
  #
#  disk        lv
#               \
#             disk(s) <= physical volumes
  #
  elsif ($osname eq 'aix') {

# Physical disk?
    #
    if ($fs =~ m,/dev/hdisk\d+,) {
      push(@disk, $fs);
    }

# Else, it's probably a logical volume.
    #
    else {
      $lv = $1 if $fs =~ m,/dev/(\S+),;
      open (LSLV, "lslv -l $lv |");
      $_ = <LSLV>; $_ = <LSLV>;    # skip first two lines
      while (<LSLV>) {
        push(@disk, "/dev/$1") if /^(\S+)\s/;
      }
      close (LSLV);
      $is_md = 1;
    }
    foreach $disk (@disk) {
      $space = 0;
      $space = "$1MB" if `getconf DISK_SIZE $disk` =~ /^(\d+)/;
      push(@space, $space);
    }
    return ($is_md ? "$fs (" . join(', ', @disk) . ')' : $disk[0]);
  }
}

# If $DEBUG = 0, call the Kickstand AddEvent() with the given arguments.
# If $DEBUG = 1, print the AddEvent() arguments to STDOUT, one per line.
#
sub myAddEvent {

  return $cmdb->AddEvent (@_) if ! $DEBUG;

# Don't append unecessary newlines.
  #
  print "\nAddEvent (\n";
  foreach (@_) {
    print "  $_" . substr($_, -1, 1) eq "\n" ? "" : "\n";
  }
  print ")\n";
  return (1);
}

# Same for Kickstand UpdateHost().
#
sub myUpdateHost {

  return $cmdb->UpdateHost (@_) if ! $DEBUG;

  print "\n\"hosts\" table update.\n";
  print   "  $_[0]\n";
  foreach (sort(keys(%{$_[1]}))) {
    printf "  %-17s => '%s'\n", $_, ${$_[1]}{$_};
  }
  return (1);
}

# Close any open events pertaining to 
# IP and /etc/hosts not matching
#
sub myCloseIPEvent {
  $eventlist = $cmdb->ListEvents($host, "open");

  if(scalar(@{$eventlist}) == 0) # Array is empty
  {
    return(0);
  }

  foreach $event (@{$eventlist})
  {
    if( $event->{"subject"} eq $hosts_complaint_subject )
    {
      my $close_result = $cmdb->ReplyEvent($event->{"id"}, $uname[1], 
        "IP issues resolved", "closed");

      if( $close_result == 0 )
      {
        print "Error! Closing didn't work\n" if $DEBUG;
        return(1);
      }
    }
  }
  return(0);
}
