class common::rsyslog {
    service { "rsyslog":
        ensure => $run_services,
        enable => true,
        require => File["/etc/rsyslog.conf"],
    }
    file { "/etc/rsyslog.conf":
        ensure => present,
        source => "puppet:///modules/common/etc/rsyslog.conf",
        notify => Service["rsyslog"],
    }
}
