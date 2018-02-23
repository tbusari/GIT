package Kickstand;

use 5.6.2;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);

# Items to export into callers namespace by default. Note: do not export
# names by default without a very good reason. Use EXPORT_OK instead.
# Do not simply export all your public functions/methods/constants.

# This allows declaration  use Kickstand ':all';
# If you do not need this, moving things directly into @EXPORT or @EXPORT_OK
# will save memory.
our %EXPORT_TAGS = ( 'all' => [ qw(
  
) ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( 
  
);

our $VERSION = '0.01';

sub new {
  use DBI;
  my $self = { search => undef,
        db => undef,
        username => getlogin() ||
               (getpwuid($<))[0] };
  bless $self;
  $self->{db} = DBI->connect("DBI:mysql:database=rcac_cmdb;host="
                           . "memoriae.rcac.purdue.edu;mysql_read_default_file="
                           . "/usr/site/rcac/scripts/Kickstand/.kickstand_mysql",undef,undef)
                or die $DBI::errstr;
  return $self;
}

sub SearchHosts {
  my( $self, $search, $active ) = @_;
  my $db = $self->{db};
  $active = ( $active =~ m/^(n|no|inactive)$/i ) ? "N" : "Y" ;
  my $result = $db->prepare("SELECT hostname FROM hosts WHERE (hostnameshort LIKE ? "
                          . "OR hostname LIKE ?) AND active = ?");
  $result->execute("\%$search\%","\%$search\%", $active);
  return $result->fetchall_hashref( 'hostname' );
}

sub mycmp {
  "$a:$b" =~ /^(hosts_|ethernet_|)(.*?):(hosts_|ethernet_|)(.*)$/;
  return ("$2 $1" cmp "$4 $3");
}

sub SearchHostsFull {
  my( $self, $hashref, $namesonly ) = @_;
  my $db = $self->{db};

  my @valid_fields = (
    'ethernet_active',    'ldapfilter',         'processor_type',      
    'hosts_active',       'macaddress',         'rackid',              
    'building',           'memory',             'resource',            
    'ethernet_hardware',  'next_kernel',        'room',                
    'hosts_hardware',     'os',                 'secondary_circuit_id',
    'hostname',           'ostype',             'serial',              
    'hostnameshort',      'osversion',          'servicetype',         
    'infiniband',         'pbs_comment',        'shipdate',            
    'installdate',        'pbs_comment_update', 'switch_ipaddress',    
    'ethernet_ipaddress', 'pbs_server',         'switch_lastupdate',   
    'hosts_ipaddress',    'primary_circuit_id', 'switch_name',         
    'kernel',             'processor_count',    'switch_port',         
    'kernel_build_date',  'processor_family',   'hostinfo.vendor',              
    'lastupdate',         'processor_speed',    'warrantyexpire',
  );

  # Run through the keys of the hash to make sure they are valid fields
  my $msg = "";
  foreach my $li ( keys %$hashref )
  {
    if( ! grep( /^$li$/, @valid_fields ) )
    { 
      $msg .= "Invalid fieldname: $li\n";
    }
  }
  if ($msg) {
    $msg .= "Cannot proceed.  Valid SearchHostsFull fieldnames are:\n";

# Now some fluff.  Print preceding error messages and the fieldnames in
# "@valid_fields" in a 3-column format sorted by the right-hand side of
# each fieldname.
#
    my @svf = sort mycmp @valid_fields;	# sorted valid fields
    my $l = @svf;
    my $n = int(($l + 2) / 3);
    push (@svf, "", "");	# ensure the array is "filled"
    my $i = 0;
    while ($i < $n) {
      $msg .= sprintf "  %-20s  %-20s  $svf[$i + 2 * $n]\n",
                      $svf[$i], $svf[$i + $n];
      $i++;
    }
    $msg =~ s,\s*$,\n,;		# replace trailing garbage w/newline
    print $msg;
    exit 1;			# bug out
  }

# Build the SQL statement with the necessary fields
#
  my $sql = "SELECT DISTINCT hosts.hostname";
  if (! $namesonly) {
    $sql .= ",hosts.id,hostnameshort,processor_count,"
          . "processor_type,processor_speed,memory,hosts.ipaddress,kernel,os,"
          . "ostype,lastupdate,pbs_server,hosts.active,hosts.hardware,serial,"
          . "osversion,infiniband,installdate,processor_family,resource,"
          . "pbs_comment,hostinfo.vendor,pbs_comment_update,manualadd,kernel_build_date,"
          . "building,room,rackid,primary_circuit_id,secondary_circuit_id,"
          . "switch_name,switch_ipaddress,switch_port,next_kernel"
  }
  $sql .=   " FROM hosts "
          . "LEFT JOIN hostinfo ON hosts.id = hostinfo.hostid "
          . "LEFT JOIN ethernet ON hosts.id = ethernet.id "
          . "LEFT JOIN disk ON hosts.id = disk.id WHERE"; 

  my ($field, $value, $OP);
  while (($field, $value) = each(%{$hashref})) {

# Convert field="tablename_fieldname" to field="tablename.fieldname".
#
    $field = "$1.$2"
      if $field =~ /^(hosts|hostinfo|ethernet|disk)_(.*)$/; 

# Check for a subset of the MySQL comparison operators.  The default
# MySQL field value format is "field = 'value'" for the Perl hash
# assignment "field => 'value'".
#
#   MySQL field value format      for      Perl hash assignment examples
#
#   field = 'value'                        field => 'xxxx'
#   field = | <=> [ BINARY] 'value'        field => 'BINARY = xxxx'
#   field != | <> [ BINARY] 'value'        field => '<> xxxx'
#   field < | <= | >= | > 'value'          field => '> 9'
#   field [NOT ]LIKE[ BINARY] 'pattern'    field => 'LIKE %sun_'
#   field [NOT ]RLIKE[ BINARY] 'pattern'   field => 'RLIKE .*sun.'
#   field [NOT ]REGEXP[ BINARY] 'pattern'  field => 'REGEXP .*sun.'
#   field IS[ NOT] TRUE|FALSE|UNKNOWN      field => 'IS TRUE'
#   field IS[ NOT] NULL                    field => 'IS NOT NULL'
#
# MySQL keywords are case insensitive.  Uppercase is used here for
# readability.
#
# By default, string comparison is done in a case insensitive manner.
# When "BINARY" is used, MySQL will do a case sensitive comparison.
# Be aware that `BINARY' also causes trailing spaces to be significant.
#
# "RLIKE" and "REGEXP" are synonyms and use extended regular expression
# pattern syntax.
#
# If the leading portion of 'xxxx' in "field => 'xxxx'" is a literal,
# i.e., not an operator, that mimics a "comparison operator", use the
# "field => '= xxxx'" assignment to avoid (probably terminal) confusion.
#
# There must be at least one blank character between the operator string
# and the 'xxxx' value.
#
# Be very careful with NULL.  It ain't the same as the empty string('')
# or 0.  See section "B.1.5.3 - Problems with 'NULL' values" in the
# MySQL 5 Reference Manual.
#
# `<=>' is the NULL-safe equal. This operator performs an equality
# comparison like the `=' operator, but returns `1' rather than `NULL'
# if both operands are `NULL', and `0' rather than `NULL' if one operand
# is `NULL'.
#
$OP = '=';                  # default operator

# Pattern matching.
#
    if ($value =~ /^((NOT +)?(LIKE|RLIKE|REGEXP)( +BINARY)?) +(.+)$/i) {
      $OP = $1;
      $value = $5;
    }

# Boolean assessment.
#
    elsif ($value =~ /^(IS( +NOT)?) +(NULL|TRUE|FALSE|UNKNOWN)$/i) {
      $OP = $1;
      $value = $3;
      $sql .= qq( $field $OP $value AND);
      next;
    }

# Equal     ('=' & '<=>').
# Not equal ('!=' & '<>').
#
    elsif ($value =~ /^(BINARY *)?(=|<=>|!=|<>) +(.*)$/i) {
      $OP = $2;
      $OP .= ' BINARY' if $1;
      $value = $3;		# Note that 'value' can be empty
    }
 
# Relative  ('<' & '<=' & '>=' & '>').
#
    elsif ($value =~ /^(<|<=|>=|>) +(.+)$/) {
      $OP = $1;
      $value = $2;
    }

    $sql .= qq( $field $OP '$value' AND); 
  }
  $sql =~ s/AND$//;
  #print ":sql statement is: $sql:\n";
  
  my $sth = $db->prepare($sql);
  if ($namesonly) {
    return ($db->selectcol_arrayref ($sth, { Columns=>[1] }));
  }
  else {
    return ($db->selectall_arrayref ($sth, { Slice => {} }));
  }
}

sub SearchGroups {
#
# Usage: SearchGroups (self, groupname, groupactive, hostactive)
#
  my $self = shift;
  my $groupname = shift;
  my $db = $self->{db};
  my ($active, $dump, $table, $fields);
  my $st;

  return undef unless $groupname;

# If present, strip the dump flag prefix ('D=') from the groupname and 
# set the dump flag.
#
  $dump = 0;
  if ($groupname =~ /^D=(.+)$/) {
    $groupname = $1;
    $dump = 1;
  }

# Both the 'group_hosts' and the 'hosts' tables have "active" flags so
# we need to take both into account.
#
# For each of the "xxxactive" parameters above:
#
# 1) If "E|EITHER" (case independent), hosts with either
#    <table>.active='Y' or <table>.active='N' will be considered.
# 2) If "N|NO|INACTIVE" (case independent), hosts with
#    <table>.active='N' will be considered.
# 3) If not specified or if anything else including an explicit undef,
#    hosts with <table>.active='Y' will be considered (the default for
#    both tables).
#
  $fields = "";
  foreach $table ('group_hosts', 'hosts') {
    $active = shift;
    if (! defined($active) || $active !~ /^(e|either)$/i) {
      $fields .= " AND $table.active = "
              .  ($active && $active =~ /^(n|no|inactive)$/i ? "'N'" : "'Y'");
    }
  }
   
  $st = $db->prepare (
           "SELECT hosts.hostname, group_hosts.active, groups.groupname"
         . " FROM group_hosts"
         . " JOIN groups ON groups.id = group_hosts.groupid"
         . " JOIN hosts ON hosts.id = group_hosts.hostid"
         . " WHERE groups.groupname LIKE ?"
         . "$fields");
  $st->execute ("%$groupname");
  if ($dump) {
    return ($st->fetchall_arrayref ([0,1,2]));
  }
  else {
    return ($st->fetchall_hashref ('hostname'));
  }
}

## SearchEthernet - search the Kickstand ethernet table.
#
# Usage: $self->SearchEthernet (\%hash)
# Where %hash can contain:
#   hostname       => A host to check.  Defaults to all hosts.
#   hosts_active   => Is host active - 'Y'/'N'/either.  Defaults to 'Y'.
#   eth_active     => Is device active - 'Y'/'N'.  Defaults to either.
#   eth_device     => Logical device name.  Defaults to any.
#   eth_hardware   => Hardware name string.  Defaults to any.
#   eth_ipaddress  => IP address for device.  Defaults to any.
#   eth_macaddress => MAC address for device.  Defaults to any.
#
# Returns: $hosthashref
# Where:
#   ($hostname,    $ethdevnamehashref)  = each(%{$hosthashref})
#   ($ethdevname,  $ethdevtblhashref)   = each(%{$ethdevnamehashref})
#   ($ethdevfield, $ethdevfieldvalue)   = each(%{$ethdevtblhashref})
#
my @key_fields = ('hostname', 'eth_device');

sub SearchEthernet {
  my ($self, $hashref) = @_;
  my %hash           = %{$hashref};
  my $hosts_hostid   = "'\%'";
  my $hosts_active   = "'Y'";
  my $eth_active     = "";
  my $eth_device     = "";
  my $eth_hardware   = "";
  my $eth_ipaddress  = "";
  my $eth_macaddress = "";
  my $x;

# Process hash arguments.
#
  my $hostname = delete($hash{hostname});
  if ($hostname) {
    if (! ($hosts_hostid = $self->GetHostID ($hostname))) {
      print "\"$hostname\" is not in the database.\n";
      return (undef);
    }
  }

  $hosts_active = ($x eq '\%' || $x eq 'either')
    ? "'\%'" : $x =~ /^(n|inactive$)/i ? "'N'" : "'Y'"
    if ($x = delete($hash{hosts_active}));

  $eth_active = "  AND ethernet.active LIKE "
    . ($x =~ /^(n|inactive$)/i ? "'N'" : "'Y'")
    if ($x = delete($hash{eth_active}));

  $eth_device = "  AND ethernet.eth_device LIKE '$x'"
    if ($x = delete($hash{eth_device}));

  $eth_hardware = "  AND ethernet.hardware LIKE '$x'"
    if ($x = delete($hash{eth_hardware}));

  $eth_ipaddress = "  AND ethernet.ipaddress LIKE '$x'"
    if ($x = delete($hash{eth_ipaddress}));

  $eth_macaddress = "  AND ethernet.macaddress LIKE '$x'"
    if ($x = delete($hash{eth_macaddress}));

# Make sure that we used all of the hash arguments.
#
  if (%hash) {
    printf "Illegal `SearchEthernet()' key(s) - %s\n",
      join(', ', keys(%hash));
    return (undef);
  }

# Now plug and chug in the Kickstand database.  Note - "hostname" is part of
# the hosts table NOT the ethernet table and is included in the return
# for readability only.
#
  my $db = $self->{db};
  my $sth =
    $db->prepare ("SELECT DISTINCT ethernet.id,hosts.hostname,"
      . "ethernet.eth_device,ethernet.active,ethernet.driver,"
      . "ethernet.ipaddress,ethernet.macaddress,ethernet.hardware,"
      . "ethernet.speed"
      . " FROM hosts"
      . " JOIN ethernet ON ethernet.id = hosts.id"
      . " WHERE ethernet.id LIKE $hosts_hostid"
      . "  AND hosts.active LIKE $hosts_active"
      . $eth_active
      . $eth_device
      . $eth_hardware
      . $eth_ipaddress
      . $eth_macaddress);
  return ($db->selectall_hashref ($sth, \@key_fields, {Slice => {}}));
}

sub GetHostID {
  my( $self, $search ) = @_;
  my $db = $self->{db};
  my $result = $db->prepare("SELECT id FROM hosts WHERE hostnameshort = ? "
                          . "OR hostname = ?");
  $result->execute($search,$search);
  my $row = $result->fetchrow_hashref();
  return ( $result->rows > 0 ? $row->{'id'} : 0 );
}

sub GetHostFromID {
  my ($self, $search) = @_;
  my $db = $self->{db};
  my $st =
    $db->prepare ("SELECT hostname FROM hosts WHERE id = ? ");
  $st->execute ($search);
  my $row = $st->fetchrow_hashref ();
  return ($st->rows > 0 ? $row->{hostname} : undef);
}

sub GetResourceHosts {
  my ($self, $resource, $active) = @_;
  my $db = $self->{db};
  my $fields = "";
  if (! defined($active) || $active !~ /^(e|either)$/i) {
    $fields .= " AND hosts.active = "
            .  ($active && $active =~ /n|no|inactive/i ? "'N'" : "'Y'");
  }
  my $st = $db->prepare ("SELECT hosts.hostname"
                       . " FROM hosts"
                       . " WHERE resource LIKE ?"
                       . "$fields");
  $st->execute ($resource);
  return ($db->selectcol_arrayref($st, { Columns=>[1] }));
}

sub AddEvent {
  my( $self, $hostname, $subject, $body, $status, $rtticket ) = @_;
  my $db = $self->{db};
  my $username = $self->{username};
  my $hostid = $self->GetHostID($hostname);
  if( !defined $username || !defined $hostid || !defined $subject || 
    !defined $body || !defined $status || $hostid == 0 ) 
  { return 0; }


  if( $status !~ m/^(open|closed)$/ )
  { 
    warn "AddEvent: status needs to be one of: open, closed.\n";
    return 0;
  }

  my $result = $db->prepare("SELECT serial FROM hosts WHERE id = ?");
  $result->execute( $hostid );
  my $serial = $result->{'serial'};

  $result = $db->prepare("INSERT INTO events (hostid, createdby, status, "
                          . "subject, body, datestamp, lastupdate, rtticket, "
					      . "serial) "
                          . "VALUES (?, ?, ?, ?, ?, NOW(),NOW(), ?, ?)");
  $result->execute( $hostid, $username, $status, $subject, $body, $rtticket, 
                    $serial );
  return $db->{mysql_insertid};

  # Doesn't work on RHEL4 (DBI too old)
  #return $db->last_insert_id( undef, undef, undef, undef );
}

sub AddHost {
  my( $self, $hostname ) = @_;
  my $db = $self->{db};
  if( $hostname !~ /purdue\.edu$/ ) { return 0; }
  my $hostnameshort;
  ($hostnameshort,undef) = split(/\./, $hostname);

  my $result = $db->prepare("INSERT INTO hosts (hostname,hostnameshort, "
                          . "installdate, lastupdate) VALUES (?,?, now(), now())");
  $result->execute( $hostname, $hostnameshort );
  # Doesn't work on RHEL4 (DBI too old)
  #my $hostid = $db->last_insert_id( undef, undef, undef, undef );
  my $hostid = $db->{mysql_insertid};

  $result = $db->prepare("INSERT INTO hostinfo (hostid) VALUES (?)");
  $result->execute( $hostid );
  return $hostid;
}

sub AddOutage {
  my( $self, $subject, $body, $hosts ) = @_;
  my $db = $self->{db};
  my $username = $self->{username};

  my $result = $db->prepare("INSERT INTO outages (subject, body, status,"
  							. " owner, starttime) "
  							. "VALUES (?,?,'open',?,NOW())");
  $result->execute( $subject, $body, $username );
  my $outageid = $db->{mysql_insertid};
  
  return $outageid;
}

sub AddCommentToOutage {
  my( $self, $outageid, $body, $status ) = @_;
  my $db = $self->{db};
  my $username = $self->{username};

  my $result = $db->prepare("INSERT INTO outages (parentid, body, status, "
  							. " owner, starttime ) "
  							. "VALUES ( ?,?,?,?, NOW() )");
  $result->execute( $outageid, $body, $status, $username );
  my $replyid = $db->{mysql_insertid};
  
  return $replyid;
} 

sub AddHostsToOutage {
  my( $self, $outageid, @hostsref ) = @_;
  my $db = $self->{db};

  my $result = $db->prepare("INSERT INTO outage_hosts (outageid, hostid) "
 							. "VALUES (?,?)");
  my $count = 0;
  my $hostid;
  foreach my $hostname (@hostsref)
  { 
	  $hostid = $self->GetHostID($hostname);
	  $result->execute( $outageid, $hostid ); 
	  $count++;
  }
  
  return $count;
} 

sub GetHostsFromOutage {
  my( $self, $outageid ) = @_;
  my $db = $self->{db};

  my $sth = $db->prepare("SELECT hostname FROM outage_hosts "
	  						. "JOIN hosts ON hosts.id = outage_hosts.hostid "
 							. "WHERE outageid = ?");
  my $result = $db->selectall_arrayref( $sth, { Slice => {} }, $outageid );
  return $result;
} 

sub GetOutageID {
  my( $self, $subject, $status ) = @_;
  my $db = $self->{db};

  my $result = $db->prepare("SELECT id FROM outages "
 							. "WHERE subject = ? "
							. "AND status = ?");
  $result->execute($subject, $status);
  my $row = $result->fetchrow_hashref();
  return ( $result->rows > 0 ? $row->{'id'} : 0 );
} 

sub ListCommentsOfOutage {
  my( $self, $outageid ) = @_;
  my $db = $self->{db};

  my $sth = $db->prepare("SELECT body, starttime, owner, status, parentid "
                       . "FROM outages "
                       . "WHERE id = ? OR parentid = ?");
  my $result = $db->selectall_arrayref( $sth, { Slice => {} }, $outageid, $outageid );
  return $result;
}

sub ListEvents {
  my( $self, $hostname, $status ) = @_;
  my $db = $self->{db};
  my $hostid = $self->GetHostID($hostname);
  my $sql_status = '';
  if( defined($status) && $status =~ m/^(open|closed)$/ )
  { $sql_status = qq( events.status = '$status' AND ); }

  my $sth = $db->prepare("SELECT events.id, hostid, subject, body, datestamp, "
                       . "createdby, status, parentid, rtticket, "
                       . "events.lastupdate, problemtype "
                       . "FROM events JOIN hosts ON hosts.id = events.hostid "
                       . "WHERE $sql_status hosts.id = ? AND parentid = 0");
  my $result = $db->selectall_arrayref( $sth, { Slice => {} }, $hostid );
  return $result;
}

sub ReplyEvent {
  my( $self, $eventid, $hostname, $body, $status ) = @_;
  my $db = $self->{db};
  my $username = $self->{username};
  my $hostid = $self->GetHostID($hostname);
  if( !defined $eventid || !defined $username || !defined $hostid || 
    !defined $body || !defined $status || $hostid == 0 ) 
  { return 0; }

  if( $status !~ m/^(open|closed)$/ )
  { 
    warn "ReplyEvent: status needs to be one of: open, closed.\n";
    return 0;
  }

  my $result = $db->prepare("SELECT serial FROM hosts WHERE id = ?");
  $result->execute( $hostid );
  my $serial = $result->{'serial'};

  $result = $db->prepare("INSERT INTO events (hostid, createdby, status, "
                          . "body, datestamp, lastupdate, parentid, serial) "
                          . "VALUES (?, ?, ?, ?,NOW(),NOW(), ?, ?)");
  $result->execute( $hostid, $username, $status, $body, $eventid, $serial );
  # Doesn't work on RHEL4 (DBI too old)
  #my $last_insert_id = $db->last_insert_id( undef, undef, undef, undef );
  my $last_insert_id = $db->{mysql_insertid};

  # Update the parentid with new status and the lastupdate time
  $result = $db->prepare("UPDATE events SET status = ?, lastupdate = NOW() "
                       . "WHERE id = ?");
  $result->execute( $status, $eventid );

  return $last_insert_id;
}

sub ListResources {
  my ($self, $active) = @_;
  my $db = $self->{db};
  my $fields = "";
  if (! defined($active) || $active !~ /^(e|either)$/i) {
    $fields .= " AND hosts.active = "
            .  ($active && $active =~ /n|no|inactive/i ? "'N'" : "'Y'");
  }
  my $st = $db->prepare ("SELECT DISTINCT hosts.resource"
                       . " FROM hosts"
                       . " WHERE resource LIKE '%'"
                       . "$fields");
  $st->execute ();
  return ($st->fetchall_hashref ('resource'));
}

sub ListGroups {
  my $self = shift;
  my $notempty = shift;
  my ($db, $sql, $st);

  $sql =    "SELECT DISTINCT groups.groupname"
         .  " FROM groups";
  if ($notempty) {
    $sql .= " JOIN group_hosts ON group_hosts.groupid = groups.id"
         .  " JOIN hosts ON hosts.id = group_hosts.hostid"
         .  " WHERE group_hosts.active = 'Y'"
         .  "   AND hosts.active = 'Y'";
  }
  $db = $self->{db};
  $st = $db->prepare ($sql);
  $st->execute ();
  return ($st->fetchall_hashref ('groupname'));
}

sub GetDHCPHosts {
  my( $self ) = @_;
  my $db = $self->{db};
  my $sth = $db->prepare("select hostnameshort, hosts.ipaddress, macaddress "
                       . "FROM hosts join ethernet on ethernet.id = hosts.id "
                       . "where ethernet.active = 'y' "
                       . "and hosts.ipaddress = ethernet.ipaddress "
                       . "and hosts.hardware not like '\%vmware\%' "
                       . "and hosts.ipaddress not like '127\%' "
                       . "and hosts.active = 'Y' order by hostname" );
  my $result = $db->selectall_arrayref( $sth, { Slice => {} } );
  return $result;
}

sub GetHostGroups {
  my ($self, $hostname, $active) = @_;
  my $hostid = $self->GetHostID($hostname);
  if( !defined $hostid || $hostid == 0 ) { return 0; }
  
  my $fields = "";
  if (! defined($active) || $active !~ /^(e|either)$/i) {
    $fields .= " AND group_hosts.active = "
            .  ($active && $active =~ /n|no|inactive/i ? "'N'" : "'Y'");
  }
  my $db = $self->{db};
  my $st = $db->prepare (
                 "SELECT groups.groupname, group_hosts.active"
               . "  FROM groups"
               . "  JOIN group_hosts ON group_hosts.groupid = groups.id"
               . "  WHERE group_hosts.hostid = ?"
               . "$fields");
  $st->execute ($hostid);
  return $st->fetchall_hashref ('groupname');
}

sub GetPBSComment {
  my( $self, $hostname ) = @_;
  my $hostid = $self->GetHostID($hostname);
  if( !defined $hostid || $hostid == 0 ) { return 0; }
  my $db = $self->{db};
  my $result = $db->prepare("SELECT pbs_comment FROM hosts WHERE id = ?");
  $result->execute($hostid);
  my $row = $result->fetchrow_hashref();
  return ( $result->rows > 0 ? $row->{'pbs_comment'} : 0 );
}

sub AddPBSFailedJobStart {
  my( $self, $mom_node, $sister_node, $datestamp, $jobid ) = @_;
  my $db = $self->{db};
  my $mom_hostid = $self->GetHostID($mom_node);
  my $sister_hostid = $self->GetHostID($sister_node);
  if( !defined $mom_hostid || $mom_hostid == 0 ) { return 0; }
  if( !defined $sister_hostid || $sister_hostid == 0 ) { return 0; }
  if( !defined $datestamp ) { return 0; }
  if( !defined $jobid || $jobid == 0 ) { return 0; }

  my $result = $db->prepare("INSERT INTO job_start_errors "
                          . "(mom_hostid, sister_hostid, datestamp, jobid) "
                          . "VALUES (?, ?, ?, ?)");
  $result->execute($mom_hostid, $sister_hostid, $datestamp, $jobid);
  return $db->{mysql_insertid};
}

sub SetActive {
  my ($self, $hostname, $active) = @_;
  my ($db, $hostid, $result);

  return(0) if ! ($hostid = $self->GetHostID ($hostname));

  $active = ($active =~ /^(n|no|inactive)$/i) ? "N" : "Y";

  $db = $self->{db};
  $result = $db->prepare ("UPDATE hosts"
			. " SET   active = '$active'"
			. " WHERE id = $hostid");
  return $result->execute();
}

sub UpdateHost {
  my( $self, $hostname, $hashref ) = @_;
  my $hostid = $self->GetHostID($hostname);
  if( !defined $hostid || $hostid == 0 ) { return 0; }
  my $db = $self->{db};

  # List of fields from the database.  Add any new fields to this array.
  my @valid_fields = ('hostname','hostnameshort','ipaddress','kernel','os',
                      'ostype','pbs_server','hardware','serial','osversion',
                      'infiniband','memory','processor_count','processor_type',
                      'processor_speed','processor_family',  'active',
                      'installdate','lastupdate','pbs_comment','vendor',
                      'ldapfilter','pbs_comment_update','kernel_build_date',
                      'resource','building','room','rackid','primary_circuit_id',
                      'secondary_circuit_id','switch_name','switch_ipaddress',
                      'switch_port','switch_lastupdate','warrantyexpire',
                      'shipdate','servicetype','ssh_rsa_key_pub','next_kernel');

  # Run through the keys of the hash to make sure they are valid fields
  my $flag = 0;
  foreach my $li ( keys %$hashref )
  {
    next unless( defined($hashref->{$li}) );
    if( ! grep( /^$li$/, @valid_fields ) )
    { 
      warn "Invalid fieldname passed to UpdateHost: $li\n";
      $flag = 1;
    }
  }
  if( $flag == 1 ) { die "Cannot proceed, invalid fields found\n"; }

  # Build the SQL statement with the necessary fields
  my $sql = "UPDATE hosts LEFT JOIN hostinfo ON hosts.id = hostinfo.hostid SET ";
  my $value;
  foreach my $li ( keys %$hashref )
  {
    if( $li =~ m/^(pbs_comment_update|lastupdate|installdate|switch_lastupdate)$/ 
      && $hashref->{$li} =~ m/^now/i ) 
      { $sql .= qq( $li = now\(\),); }
    elsif( $li =~/vendor$/ && defined($hashref->{$li}) ) {
	    $value = $db->quote($hashref->{$li});
  	  $sql .= qq( hostinfo.$li = $value,);
    }
    else
      {

# Massage the 'value' a bit so that embedded single quotes and single
# backslashes, etc., don't give MySQL fits.
#
	if (defined($hashref->{$li})) {
	  $value = $db->quote($hashref->{$li});
	  $sql .= qq( $li = $value,);
	}
      }
  }
  $sql =~ s/,$//;
  $sql .= qq( WHERE hosts.id = $hostid);
  #print ":sql statement is: $sql:\n";
  
  # Update the database
  my $result = $db->do($sql);

  # Return the number of rows affected.
  return $result;
}

sub CheckSerialConflict
{
  my( $self, $hostname, $serial ) = @_;
  return 0 if $serial eq ''; # ignore blank serials
  my $db = $self->{db};
  my $id = $self->GetHostID($hostname);
  # see if we already have a serial number conflict open, if so, skip this part
  my $sth = $db->prepare( "SELECT id FROM events WHERE hostid = ? "
                           . "AND subject = 'Serial Number Conflict' "
                           . "AND status = 'open'" );
  my $result = $db->selectall_arrayref( $sth, { Slice => {} }, $id );
  if( scalar($result) == 0 ) # there is not currently a serial number conflict, so check
  {
    $result = $db->prepare("SELECT hostnameshort FROM hosts "
                         . "WHERE serial = ? AND id != ? AND active = 'Y'");
    $result->execute($serial, $id);

    my $numdupes;
    while( my $return = $result->fetchrow_hashref )
    {
      my $dupehost = $return->{'hostnameshort'};
      my $body =  "Host $hostname has a duplicate serial number, please investigate.";
      $self->AddEvent($dupehost, "Serial Number Conflict", $body, "open",);
      $numdupes++;
    }
    return $numdupes;
  }
  return 0;
}

sub UpdateEthernet
{
  my( $self, $hashref ) = @_;
  my $db = $self->{db};
  my $hostname = $hashref->{hostname};
  my $hostid = $self->GetHostID($hostname);
  my $action = lc($hashref->{action});
  
  if( $action eq "update" ) # called in a loop back in update_cmdb
  {
    my $eth = $hashref->{eth};
    my $macaddress = $hashref->{macaddress};
    my $ethhardware = $hashref->{ethhardware};
    my $ethspeed = $hashref->{ethspeed};
    my $ethactive = $hashref->{ethactive};
    my $ethipaddress = $hashref->{ethipaddress};
    my $result = $db->prepare("INSERT INTO ethernet (id, eth_device, "
                            . "macaddress, hardware, speed, active, ipaddress) "
                            . "VALUES (?, ?, ?, ?, ?, ?, ?) ON DUPLICATE KEY "
                            . "UPDATE macaddress=VALUES(macaddress),"
                            . "hardware=VALUES(hardware),speed=VALUES(speed),"
                            . "active=VALUES(active),ipaddress=VALUES(ipaddress)");
    return $result->execute($hostid, $eth, $macaddress, $ethhardware, $ethspeed, $ethactive, $ethipaddress);
  }
  elsif( $action eq "deactivate" ) # called once back in update_cmdb
  {
    my $ethlist = $hashref->{ethlist}; # ethlist is ref, so @-ify it when used
    
    my $ethnotlist = "UPDATE ethernet SET active = 'N' WHERE id = $hostid AND ( ";
    foreach my $li (@{$ethlist})
    {
      $li = $db->quote($li); # safe-ify inputs
      $ethnotlist .= "eth_device != $li AND ";
    }   
    $ethnotlist =~ s/AND $//;  # remove the last 'AND'
    $ethnotlist .= " )";
    my $result = $db->prepare($ethnotlist);
    return $result->execute();
  }
  else { die "UpdateEthernet action must be 'update' or 'deactivate'\n"; } # you're doing it wrong
}

sub UpdateDisk
{
  my( $self, $hostname, $disk, $space ) = @_;
  my $db = $self->{db};
  my $id = $self->GetHostID($hostname);
  my $result = $db->prepare("INSERT INTO disk (id, disk, space) "
                          . "VALUES (?, ?, ?) ON DUPLICATE KEY UPDATE "
                          . "space=VALUES(space)");
  return $result->execute($id, $disk, $space);
}

sub AddHostToGroups
{
  my( $self, $hostname, $grouplist ) = @_;
  my $db = $self->{db};
  my $hostid = $self->GetHostID($hostname);
  my $searchgroup = $db->prepare("SELECT id FROM groups WHERE groupname = ?");
  my $insertgroup = $db->prepare("INSERT INTO groups (groupname) VALUES (?)");

  my $temp = $grouplist;
  $temp =~ s/\'//g; # replace "'" with nothing
  my @groups = split /,\s/, $temp; # split along ", "
  for my $group (@groups)
  {
    $searchgroup->execute($group);
    if( $searchgroup->rows == 0 )   # group doesn't exist, add it
    {
      $insertgroup->execute($group);
    }
  }
  my $insertgrouphosts = $db->prepare("INSERT INTO group_hosts (groupid, hostid) "
                                    . "SELECT id, '$hostid' FROM groups "
                                    . "WHERE groupname IN ($grouplist) "
                                    . "AND id NOT IN ( SELECT groupid "
                                    . "FROM group_hosts WHERE hostid = ? )");
  my $return = $insertgrouphosts->execute($hostid);

  my $result = $db->prepare("UPDATE group_hosts JOIN groups ON groups.id = group_hosts.groupid "
	  		.  "SET active = 'N' "
			.  "WHERE hostid = '$hostid' AND groupname NOT IN ($grouplist)");
  $result->execute();
}

sub AddClusterCounts
{
	my( $self ) = @_;
	my $db = $self->{db};
	my $result = $db->prepare("insert ignore into node_counts (date, resourcename, resourcecount)  select date(now()) as date, resource as resourcename, count(*) as resourcecount from hosts where hosts.active = 'y' and resource != '' group by resource order by resourcecount desc;");
	$result->execute();

	my $num_students = `/usr/site/rcac/scripts/get_group_members.py -g rcacstu -dnewline | /usr/bin/wc -l`;
	chomp($num_students);
	$result = $db->prepare("insert ignore into node_counts (date, resourcename, resourcecount)  values (date(now()), 'number_of_students',$num_students)");
	$result->execute();

	my $num_staff = `/usr/site/rcac/scripts/get_group_members.py -g rcacadmf -dnewline | egrep -v '(mckay)' | wc -l`;
	chomp($num_staff);
	$result = $db->prepare("insert ignore into node_counts (date, resourcename, resourcecount)  values (date(now()), 'number_of_staff',$num_staff)");
	$result->execute();
}

sub FindNewOutages
{
  my ($self) = @_;
  my $db = $self->{db};
  my $outage_num;
  my $outage_hostlist_sth;
  my $outage_hash = {};

  # Step 1 - get array of outages that have not been set in Nagios
  my $outage_list_sth = $db->prepare("select ID,UNIX_TIMESTAMP(starttime) as starttime,UNIX_TIMESTAMP(endtime) as endtime from outages where nagios_downtime_scheduled = 'N' and parentid=0 and planned = 'Y'");
  $outage_list_sth->execute();
  my $outage_list = $db->selectall_arrayref( $outage_list_sth, { Slice => {} } );

  # Step 2 - get list of starttime,endtime,@hostnameshort for each outage
  foreach $outage_num ( @$outage_list) {

    # Find out the starttime and endtime of an outage
    if ( defined ( $outage_num->{"starttime"} ) ) {
      $outage_hash->{$outage_num->{ID}}->{"starttime"} = $outage_num->{starttime};
    }

    if ( defined ( $outage_num->{"endtime"} ) ) {
      $outage_hash->{$outage_num->{ID}}->{"endtime"} = $outage_num->{endtime};
    }

    # Build an array of hosts for this outage
    $outage_hostlist_sth = $db->prepare("select hostnameshort from outages join outage_hosts on outages.id = outage_hosts.outageid join hosts on hosts.id = outage_hosts.hostid where outageid = '$outage_num->{ID}'");
     my $outage_hostlist = $db->selectall_arrayref ($outage_hostlist_sth, {Slice => {}});

     # Now add the host list to the outage entry
     $outage_hash->{$outage_num->{ID}}->{"hostlist"} = $outage_hostlist;

  }
  return $outage_hash;
}

sub OutageScheduledWithNagios
{
  my ( $self, $outage_id ) = @_;
  my $db = $self->{db};

  # Given an outage ID #, set the column "nagios_downtime_scheduled from
  # "N" to "Y".
  my $result = $db->prepare("update outages set nagios_downtime_scheduled='Y' where id=$outage_id");
  $result->execute();
}

sub GetCoreCountForResource
{
  my ( $self, $resource ) = @_;
  my $db = $self->{db};

  my $result = $db->prepare("SELECT sum(processor_count) AS count
                             FROM hosts
                             JOIN group_hosts ON group_hosts.hostid = hosts.id
                             JOIN groups ON groups.id = group_hosts.groupid
                             WHERE resource =? 
                             AND hosts.active ='Y' 
                             AND groupname = 'cmdb_nodes'");

  $result->execute($resource);
  my $row = $result->fetchrow_hashref();
  return ( $result->rows > 0 ? $row->{'count'} : 0 );
}

sub DESTROY {
  my $self = shift;
  my $db = $self->{db};
  $db->disconnect if defined($db);
  undef $self->{db};
  $self->SUPER::DESTROY if $self->can("SUPER::DESTROY");
}

1;
__END__

=pod

=begin man

.nh

=end man

=head1 NAME

Kickstand - Perl extension for accessing RCAC's Kickstand.

=head1 SYNOPSIS

  use RCAC::Kickstand;              # preferred
   or
  use lib "/usr/site/rcac/scripts/Kickstand";
  use Kickstand;

  $obj = new Kickstand;

  $replyid  = $obj->AddCommentToOutage(outageid, body, status);

  $obj->AddClusterCounts( );

  $integer  = $obj->AddEvent(hostname, subject, body, status, rtticket);

  $integer  = $obj->AddHost(hostname);

  $count    = $obj->AddHostsToOutage(outageid, @hosts);

  $hostid   = $obj->AddOutage(subject, @hosts);

  $obj->AddPBSFailedJobStart(mom_node, sister_node, datestamp, jobid);

  $count    = $obj->GetCoreCountForResource(resource);

  $arrayref = $obj->GetDHCPHosts();

  $hashref  = $obj->GetHostGroups(hostname, active);

  $string   = $obj->GetHostFromID ($integer);

  $arrayref = $obj->GetHostsFromOutage(outageid);

  $arrayref = $obj->GetResourceHosts(resource, active);

  $string   = $obj->GetPBSComment(hostname);

  $arrayref = $obj->ListCommentsOfOutages(outageid);

  $arrayref = $obj->ListEvents(hostname, status);

  $hashref  = $obj->ListGroups(notempty);

  $hashref  = $obj->ListResources(active);

  $integer  = $obj->ReplyEvent(eventid, hostname, body, status);

  $hashref  = $obj->SearchEthernet (hashref);

  $hashref  = $obj->SearchGroups(groupname, groupactive, hostactive);
  $arrayref = $obj->SearchGroups(D=groupname, groupactive, hostactive);

  $hashref  = $obj->SearchHosts(hostname, active);

  $arrayref = $obj->SearchHostsFull(hashref, namesonly);

  $integer  = $obj->SetActive(hostname, active);

  $integer  = $obj->UpdateEthernet (hashref);

  $integer  = $obj->UpdateHost(hostname, hashref);

=head1 DESCRIPTION

This module contains functions to facilitate access to the Kickstand within
the Rosen Center for Advanced Computing (RCAC) at Purdue University.
Its goal is to provide a consistent mechanism for user scripts to
access the Kickstand database without having explicit knowledge of either the
database or the syntax of the required mySQL queries.

To load this module, you'll need to include one of the following in your
script.

  use RCAC::Kickstand;		# preferred
       or
  use lib '/usr/site/rcac/scripts/Kickstand';
  use Kickstand;


=head2 AddClusterCounts( )

=over 4

This will count the number of machines in each active resource and add it to
the node_counts table.  It will also count the number of students from the
'rcacstu' group (minus notable exceptions) and add that total.

This allows us to get an over time feel for how many nodes we're supporting
and how many people are doing it.

=back

=head2 AddHostToGroups( I<hostname>, I<grouplist> )

=over 4

This function updates the groups table to make sure it includes all of
the groups in I<grouplist>.  It then associates I<hostname>'s hostid with the
groupid of each group in I<grouplist> in the group_hosts table.
It returns the number of rows affected in the database transaction.

=back

=head2 AddEvent( I<hostname>, I<subject>, I<body>, I<status>, I<rtticket> )

=over 4

Add an event for host I<hostname> and return the id of
the new event.  Events are used to track automated or manual
interventions on a machine, i.e., Replaced failed hard drive on
node XX.

Required fields: I<hostname>, I<subject>, I<body>, I<status>.
I<subject> is the external identifying text for the event.
I<body> is the descriptive text of the event.
I<status> is one of: 'B<open>' or 'B<closed>'.
I<rtticket> is an optional field.

The user running this script is logged as the creator of these events.

=back

=head2 AddHost( I<hostname> )

=over 4

Insert the FQDN I<hostname> (full hostname) into the database.
The hostid is returned upon success, zero upon failure.

=back

=head2 AddPBSFailedJobStart( I<mom_node>, I<sister_node>, 
              I<datestamp>, I<jobid> )

=over 4

Adds an entry to the job_start_error table.  To be used from a cron
that runs on every node looking to see if it was the parent of any
sister nodes that failed to start a job.

=back

=head2 CheckSerialConflict( I<hostname>, I<serial> )

=over 4

This function takes a I<hostname> and a I<serial>, and adds a Kickstand event
to all other hosts that have that same I<serial>.  It returns the number
of duplicates.

=back

=head2 GetCoreCountForResource( I<resource> );

=over 4

Return a total count of processors within this resource, for nodes only.

=back

=head2 GetDHCPHosts( )

=over 4

Return a reference to an array of hashes that contains all of the
information required to build a DHCP table for active hosts, similar to
B<SearchHostsFull>.

=back

=head2 GetHostGroups( I<hostname>, I<active> )

=over 4

Returns a reference to a hash in which the keys are the names of the
groups to which I<hostname> belongs.
The value of each hash entry is a reference to a subhash that uses
B<groupname> and B<active> as keys.
I<active> is optional and refers to the B<active> field in the
B<group_hosts> table.
If present, it specifies the activity status that each group must have
with respect to I<hostname>.
See B<SearchGroups> for the values that may be specified.
The default is 'Y'.

=back

=head2 GetHostID( I<hostname> )

=over 4

This function returns the id of host I<hostname>.  Returns
zero if I<hostname> does not exist.  Only useful in conjunction with
other query related commands, this ID has no real-world meaning.

=back

=head2 GetHostFromID ( I<hostid> )

=over 4
 
This function is the inverse of B<GetHostID()> and returns the hostname
associated with I<hostid>.  Returns undef if I<hostid> does not exist.

=back

=head2 GetResourceHosts( I<resource>, I<active> )

=over 4

Returns a reference to an array that consists of a list of hosts that
have resource=I<resource>.
I<active> is optional and refers to the B<active> field in the B<hosts>
table.
If present, it specifies the activity status that each returned host
must have.
See B<SearchGroups> for the values that may be specified.
The default is 'Y'.

=back

=head2 GetPBSComment( I<hostname> )

=over 4

Return the existing PBS comment for host I<hostname>.  

=back

=head2 ListEvents( I<hostname>, I<status> )

=over 4

List all of the status I<status> events for host I<hostname>.
A reference to an array of hashes is returned, similar to B<SearchHostsFull>.

=back

=head2 ListGroups( I<notempty> )

=over 4

Returns a reference to a hash in which the keys are a (sub)set of
B<groupname> values from the B<groups> table.
Host E<lt>-E<gt> Group relationships are many-to-many.
I<notempty> is optional and, if present and non-zero, only the names of
those groups that have active host members will be returned, e.g.,
B<cmdb_condor>.
On the other hand, B<cmdb_caesar> is currently empty of active hosts
and wouldn't be returned.

=back

=head2 ListResources( I<active> )

=over 4

Returns a reference to a hash in which the keys are a distinct set of
B<resource> values from the B<hosts> table.
I<active> is optional and, for each resource returned, at least one
host with that resource must have this I<active> status.
See B<SearchGroups> for the values that may be specified.
The default is 'Y'.

=back

=head2 ReplyEvent( I<eventid>, I<hostname>, I<body>, I<status> )

=over 4

Add a reply to an event, update the timestamp and status of
the parent.  The id of the new event is returned.

=back

=head2 SearchEthernet ( I<\%hash> )

=over 4

Search the Ethernet table for one or more entries that satisfy the
values specified in the hash.

Example:

 %hash = (
   hostname       => A host to check.  Defaults to all hosts.
   hosts_active   => Is host active - 'Y'/'N'/either.  Defaults to 'Y'.
   eth_active     => Is device active - 'Y'/'N'.  Defaults to either.
   eth_device     => Logical device name.  Defaults to any.
   eth_hardware   => Hardware name string.  Defaults to any.
   eth_ipaddress  => IP address for device.  Defaults to any.
   eth_macaddress => MAC address for device.  Defaults to any.
 );
 $hosthashref = SearchEthernet ($obj, \%hash);
 foreach $hostname (sort keys(%{$hosthashref})) {
   print "$hostname\n";
   $ethdevnamehashref = ${$hosthashref}{$hostname};
   foreach $ethdevname (sort keys(%{$ethdevnamehashref})) {
     print " $ethdevname\n";
     $ethdevtblhashref = ${$ethdevnamehashref}{$ethdevname};
     while (($ethdevfield, $ethdevfieldvalue) =
 				each(%{$ethdevtblhashref})) {
       printf "   %-10s  %s\n", $ethdevfield, $ethdevfieldvalue;
     }
   }
 }

=back

=head2 SearchGroups( I<groupname>, I<groupactive>, I<hostactive> )

B<SearchGroups>( B<D=>I<groupname>, I<groupactive>, I<hostactive> )

=over 4

If 'B<D=>' is not present, this function takes the name of a group,
I<groupname>, and returns a reference to a hash table in which the keys
are the FQDN of each host from the specified group.
I<groupname> is actually used as a pattern that is anchored on the right
end.
The value of each hash key is a reference to a subhash that contains
B<hostname>, B<active> and B<groupname> as keys.

If 'B<D=>' is present, this function takes the name of a group,
I<groupname>, and returns a reference to an array of array references.
Each subarray contains the (FQDN) B<hosts.hostname>,
B<group_hosts.active> and B<groups.groupname> values (in that order)
of all distinct combinations of the three.
This effectively dumps all of the pertinent group values for the
specified I<groupname>.

The I<groupactive> and I<hostactive> parameters are optional and refer
to, respectively, the B<active> field in the B<group_hosts> and B<hosts>
tables.
I<groupactive> is used to specify whether or not I<groupname> is active
for a particular host.
I<hostactive> is used to specify whether or not a host is to be active.
The argument value for either may be:

=over 3

=item 1)

B<E>|B<EITHER> (case independent), hosts with either
<table>.B<active>='B<Y>' or <table>.B<active>='B<N>' will be considered.

=item 2)

B<N>|B<NO>|B<INACTIVE> (case independent), hosts with <table>.B<active>='B<N>'
will be considered.

=item 3)

If not specified or if anything else including an explicit undef,
hosts with <table>.B<active>='B<Y>' will be considered (the default for
both tables).

=back

=back

=head2 SearchHosts( I<hostname>, I<active> )

=over 4

This function takes the name I<hostname> and returns a reference
to a hash table containing the FQDN of each host that matches.

The hostname (FQDN) and hostnameshort (shortname) fields are
both searched.  By default, this function returns only active
hosts, to get inactive hosts, pass 'no' into the I<active>
argument.

=back

=head2 SearchHostsFull( I<hash>, I<namesonly> )

=over 4

This function takes a I<hash> reference and returns a reference to an
array.

I<namesonly> is optional.
If I<namesonly> is not present, is zero or is undef, each member of the
array will consist of a reference to a hash that contains most of
the fields in the B<hosts> table and about half of the fields in the
B<hostinfo> table for each host that matches the requisites specified in
the I<hash>.
If I<namesonly> is not zero and not undef, each
member of the array will consist of the name of a host that matches.

The I<hash> will have the fieldname/value as the key/value for
each field that will be searched within the database.

There are some fieldnames that are duplicated in the hosts and ethernet
tables.
These are distinguished by prefixing the fieldname with "tablename_",
e.g. hosts_active and ethenet_active.

The following is a list of valid fieldnames for B<SearchHostsFull>:

    ethernet_active    ldapfilter         processor_type      
    hosts_active       macaddress         rackid              
    building           memory             resource            
    ethernet_hardware  next_kernel        room                
    hosts_hardware     os                 secondary_circuit_id
    hostname           ostype             serial              
    hostnameshort      osversion          servicetype         
    infiniband         pbs_comment        shipdate            
    installdate        pbs_comment_update switch_ipaddress    
    ethernet_ipaddress pbs_server         switch_lastupdate   
    hosts_ipaddress    primary_circuit_id switch_name         
    kernel             processor_count    switch_port         
    kernel_build_date  processor_family   vendor              
    lastupdate         processor_speed    warrantyexpire

This function accepts a subset of the MySQL comparison operators.
The default MySQL field value format is "field = 'value'" for the Perl
hash assignment "field => 'value'".

  MySQL field value format      for      Perl hash assignment examples

  field = 'value'                        field => 'xxxx'
  field = | <=> [ BINARY] 'value'        field => 'BINARY = xxxx'
  field != | <> [ BINARY] 'value'        field => '<> xxxx'
  field < | <= | >= | > 'value'          field => '> 9'
  field [NOT ]LIKE[ BINARY] 'pattern'    field => 'LIKE %sun_'
  field [NOT ]RLIKE[ BINARY] 'pattern'   field => 'RLIKE .*sun.'
  field [NOT ]REGEXP[ BINARY] 'pattern'  field => 'REGEXP .*sun.'
  field IS[ NOT] TRUE|FALSE|UNKNOWN      field => 'IS TRUE'
  field IS[ NOT] NULL                    field => 'IS NOT NULL'

MySQL keywords are case insensitive.  Upper case is used here for
readability.

By default, string comparison is done in a case insensitive manner.
When "BINARY" is used, MySQL will do a case sensitive comparison.
Be aware that "BINARY" also causes trailing spaces to be significant.

"RLIKE" and "REGEXP" are synonyms and use extended regular expression
pattern syntax.

If the leading portion of 'xxxx' in "field => 'xxxx'" is a literal,
i.e., not an operator, that mimics a "comparison operator", use the
"field => '= xxxx'" assignment to avoid (probably terminal) confusion.

There must be at least one blank character between the operator string
and the 'xxxx' value.

Be very careful with NULL.  It ain't the same as the empty string('')
or 0.  See section "B.1.5.3 - Problems with 'NULL' values" in the
MySQL 5 Reference Manual.

`<=>' is the NULL-safe equal. This operator performs an equality
comparison like the `=' operator, but returns `1' rather than `NULL'
if both operands are `NULL', and `0' rather than `NULL' if one operand
is `NULL'.

Example:

    use RCAC::Kickstand;

    $obj = new Kickstand;
    %hash = (
      hosts_ipaddress => '1.1.1.1',
      building        => 'MATH',
      room            => 'LIKE G19_',
    );
    $result = $obj->SearchHostsFull(\%hash);
    foreach $li ( @{$result} ) {
            foreach $li2 (keys %{$li}) { 
                    print "The $li2 is $li->{$li2}\n"; 
            }
    }

=back

=head2 SetActive( I<hostname>, I<active> )

=over 4

Set host I<hostname> active or inactive.
I<active> may be a case insensitive 'B<N>', 'B<NO>' or 'B<INACTIVE>' in
which case I<hostname> will be set inactive ('B<N>').  All other values
or no value will set I<hostname> active ('B<Y>').

=back

=head2 UpdateHost( I<hostname>, I<hashref> )

=over 4

This function takes the name I<hostname> and updates the hosts
and hostinfo tables for the required fields from the I<hash>
reference.

The I<hash> will have the fieldname/value as the key/value 
for each field that will be updated.  

Example:

  use RCAC::Kickstand;

  $obj = new Kickstand;
  my %hash = (
    ipaddress          => '1.1.1.1',
    building           => 'MATH',
    room               => 'G190',
    rackid             => 'E06',
    primary_circuit_id => 'A11.1b',
  );
  $result = $obj->UpdateHost('tempest', \%hash);

=back

=over 4

=item Z<>    Field List:  (* - indicates an automatically updated field)

=item Z<>

=over 4

=item active      *

=item building

=item hardware      *

=item infiniband    *

=item installdate

=item ipaddress      *

=item kernel      *

=item next_kernel      *

=item kernel_build_date  *

=item lastupdate

=item memory      *

=item os        *

=item ostype      *

=item osversion      *

=item pbs_comment    *

=item pbs_comment_update  *

=item pbs_server    *

=item primary_circuit_id

=item processor_count  *

=item processor_family  *

=item processor_speed  *

=item processor_type    *

=item rackid

=item resource      *

=item room

=item secondary_circuit_id

=item serial      *

=item vendor      *

=back

=back

=head2 UpdateDisk( I<hostname>, I<disk>, I<space> )

=over 4

This function takes a I<hostname>, a I<disk>, and the I<space> on that disk,
and adds that information to the Kickstand if it does not already exist.
It returns the number of rows affected in the database transaction.

=back

=head2 UpdateEthernet( I<\%hash> )

=over 4

This function takes a I<hashref> in one of two forms: update or deactivate.

 # Update hostname's Ethernet device "eth".
 #
 %hash = (
   action      => 'update',        hostname     => 'resident host',
   eth         => 'device name',   macaddress   => 'device MAC address',
   ethhardware => 'hardware desc', ethspeed     => 'device speed',
   ethactive   => 'Y'|'N',         ethipaddress => 'device IP address',
 );

 # Deactivate all of hostname's device entries except those in the
 # @ethlist array which contains a list of the names of all non-loopback
 # ethernet devices currently available on hostname.
 #
 %hash = (
   action   => 'deactivate',
   hostname => 'resident host',
   ethlist  => \@ethlist,
 );

In either case, it returns the number of rows affected in the database
transaction.

=back

=head2 EXPORT

=over 4

None by default.

=back

=head1 SEE ALSO

For reference on perl modules, go here:

L<http://www.codeproject.com/KB/perl/camel_poop.aspx>


=head1 AUTHOR

Randy Herban, E<lt>rherban@purdue.eduE<gt>

=cut
