class common::rcacsite {
    file { "/usr/site":
        ensure => directory,
    }

    file { "/usr/site/rcac":
        ensure => directory,
        recurse => true,
        purge => false,
        source => "puppet:///modules/common/usr/site/rcac",
        require => File["/usr/site"],
    }
    file { "/usr/site/rcac/secure":
        ensure => directory,
        mode => "0755",
    }

    file { "/usr/site/rcac/scripts/log":
        owner  => "root",
        group  => "rcacstaf",
        mode   => "0550",
        source => "puppet:///modules/common/usr/site/rcac/scripts/log",
    }
}
