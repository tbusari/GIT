class common::time {
    package { "ntp":
        ensure => present,
    }->
    service { "ntpd":
        ensure => $run_services,
        enable => true,
        require => File["/etc/ntp.conf"],
    }
    file { "/etc/ntp.conf":
        ensure => present,
        source => "puppet:///modules/common/etc/ntp.conf",
        notify => Service["ntpd"],
    }
    file { "/etc/localtime":
        ensure => link,
        target => "/usr/share/zoneinfo/America/Indiana/Indianapolis",
    }
    file { "/etc/sysconfig/clock":
        ensure => present,
        source => "puppet:///modules/common/etc/sysconfig/clock",
    }
}
