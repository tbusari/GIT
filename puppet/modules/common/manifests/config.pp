class common::config {

    # This class will configure those one off, common things on an RCAC host

    File {
        owner => root,
        group => root,
    }

    # ensure resolv.conf is proper
    file { "/etc/resolv.conf":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/resolv.conf",
    }

    # common netgroups file, mostly used for ssh
    file { "/etc/netgroup":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/netgroup",
    }

    # set idmapd for nfs v4 if we use it
    file { "/etc/idmapd.conf":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/idmapd.conf",
    }

    # set module options
    file { "/etc/modprobe.d/conntrack.conf":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/modprobe.d/conntrack.conf",
    }
    file { "/etc/modprobe.d/cpufreq_disable.conf":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/modprobe.d/cpufreq_disable.conf",
    }

    # if we run "locate" be sure we don't index everything
    file { "/etc/updatedb.conf":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/updatedb.conf",
    }

    # manage root's authorized_keys file
    file { "/root/.ssh":
        ensure => directory,
        mode => "0500",
    }
    file { "/root/.ssh/authorized_keys":
        ensure => present,
        mode => "0400",
        source => "puppet:///modules/common/root/.ssh/authorized_keys",
        require => File["/root/.ssh"],
    }

    # ensure everything runs /etc/rc.local
    service { "rc-local":
        enable => true,
    }

    # configure sysctl parameters
    file { "/etc/sysctl.conf":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/sysctl.conf",
    }
    file { "/etc/sysctl.d":
         ensure => directory,
    }
    file { "/etc/sysctl.d/00-vm.conf":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/sysctl.d/00-vm.conf",
        require => File["/etc/sysctl.d"],
    }
    file { "/etc/sysctl.d/01-net.conf":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/sysctl.d/01-net.conf",
        require => File["/etc/sysctl.d"],
    }

    # prevent users from using "wall"
    file { "/usr/bin/wall":
        group => "tty",
        mode  => "0555",
    }

    # setcap the ping binary so non-privileged users can ping
    exec { 'setcap ping':
        command => "/usr/sbin/setcap 'cap_net_admin,cap_net_raw+ep' /usr/bin/ping",
        onlyif => '/usr/bin/test -f /usr/bin/ping',
    }

    # Place a Puppet agent lock file down to prevent "puppet agent" running
    file { "/var/lib/puppet/state/agent_disabled.lock":
        ensure => present,
        mode   => "0644",
        source => "puppet:///modules/common/var/lib/puppet/state/agent_disabled.lock",
    }

    file { "/usr/site/rcac/sbin/run_puppet":
        ensure => present,
        mode   => "0550",
        source => "puppet:///modules/common/usr/site/rcac/sbin/run_puppet",
    }
    file { "/etc/cron.d/puppet":
        ensure => present,
        mode   => "0444",
        source => "puppet:///modules/common/etc/cron.d/puppet",
    }
    file { "/etc/cron.d/syncfiles":
        ensure => present,
        mode   => "0444",
        source => "puppet:///modules/common/etc/cron.d/syncfiles",
    }   
    file { "/usr/site/rcac/sbin/syncfiles":
        ensure => present,
        mode   => "0550",
        source => "puppet:///modules/common/usr/site/rcac/sbin/syncfiles",
    } 

    # Run rasdaemon to log hardware failure events
    service { "rasdaemon":
        ensure => $run_services,
        enable => true,
    }

    # Add /home and /depot to /etc/fstab if those lines are not already in /etc/fstab
    exec { "/home fstab existence check":
        command => "/usr/bin/echo 'persistent-nfs.rcac.purdue.edu:/persistent/home    /home   nfs nodev,intr,nosuid,proto=tcp,vers=3,hard,bg,rsize=131072,wsize=524288,timeo=600,retrans=2    0   0' >> /etc/fstab",
        onlyif  => "/usr/bin/test ! $(/usr/bin/grep -F /home /etc/fstab | wc -l) -ge 1",
    }
}
