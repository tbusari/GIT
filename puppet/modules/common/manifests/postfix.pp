class common::postfix {
    service { "postfix":
        ensure => $run_services,
        enable => true,
        require => File["/etc/postfix/main.cf"],
    }
    file { "/etc/postfix/main.cf":
        ensure => present,
        owner => root,
        group => root,
        mode => "0444",
        source => "puppet:///modules/common/etc/postfix/main.cf",
        notify => Service["postfix"],
    }

    # route local mail
    file { "/etc/aliases":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/aliases",
    }

}
