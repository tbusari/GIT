class common::hsi {

    file { "/etc/krb5.conf":
        ensure => present,
        owner => root,
        group => root,
        mode => "0444",
        source => "puppet:///modules/common/etc/krb5.conf",
    }

    file { "/opt/hsi":
        ensure => directory,
    }

    file { "/opt/hsi/etc":
        ensure => directory,
        require => File["/opt/hsi"],
    }

    file { "/opt/hsi/etc/env.conf":
        ensure => present,
        source => "puppet:///modules/common/opt/hsi/etc/env.conf",
        require => File["/opt/hsi/etc"],
    }

    file { "/usr/local/bin/fortresskey":
        ensure => present,
        owner => root,
        group => root,
        mode => "0555",
        source => "puppet:///modules/common/usr/local/bin/fortresskey",
    }

    file { "/usr/local/bin/hpss_chkkeytab":
        ensure => present,
        owner => root,
        group => root,
        mode => "0555",
        source => "puppet:///modules/common/usr/local/bin/hpss_chkkeytab",
    }

}
