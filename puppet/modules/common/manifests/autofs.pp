class common::autofs {
    File {
        owner => root,
        group => root,
        mode  => "0444",
    }
    service { "autofs":
        ensure => $run_services,
        enable => true,
        require => File["/etc/auto.master"],
    }
    file { "/etc/auto.master":
        ensure => present,
        source => "puppet:///modules/common/etc/auto.master",
        notify => Service["autofs"],
    }
    file { "/etc/auto.rmt_share":
        ensure => present,
        source => "puppet:///modules/common/etc/auto.rmt_share",
        notify => Service["autofs"],
    }
    file { "/etc/auto.snapshot":
        ensure => present,
        source => "puppet:///modules/common/etc/auto.snapshot",
        notify => Service["autofs"],
    }
}
