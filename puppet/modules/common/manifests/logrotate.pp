class common::logrotate {
    file { "/etc/logrotate.conf":
        ensure => present,
        owner => root,
        group => root,
        mode => "0444",
        source => "puppet:///modules/common/etc/logrotate.conf",
    }
    file { "/etc/logrotate.d":
        ensure => directory,
    }
    file { "/etc/logrotate.d/syslog":
        ensure => present,
        owner => root,
        group => root,
        mode => "0444",
        source => "puppet:///modules/common/etc/logrotate.d/syslog",
        require => File["/etc/logrotate.d"],
    }
}
