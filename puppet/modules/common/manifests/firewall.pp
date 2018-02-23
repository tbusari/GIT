class common::firewall {

    service { "ipset":
        ensure => $run_services,
        enable => true,
        require => File["/etc/sysconfig/ipset"],
    }
    service { "iptables":
        ensure => $run_services,
        enable => true,
        require => Service["ipset"],
    }
    service { "ip6tables":
        ensure => $run_services,
        enable => true,
        require => Service["ipset"],
    }

    file { "/etc/sysconfig/ip6tables":
        ensure => present,
        owner => root,
        group => root,
        mode => "0440",
        source => "puppet:///modules/common/etc/sysconfig/ip6tables",
        notify => Service["ip6tables"],
    }
    file { "/etc/sysconfig/iptables":
        ensure => present,
        owner => root,
        group => root,
        mode => "0440",
        source => "puppet:///modules/common/etc/sysconfig/iptables",
        notify => Service["iptables"],
    }
    file { "/etc/sysconfig/ipset":
        ensure => present,
        owner => root,
        group => root,
        mode => "0440",
        source => "puppet:///modules/common/etc/sysconfig/ipset",
        notify => Service["ipset"],
    }
}
