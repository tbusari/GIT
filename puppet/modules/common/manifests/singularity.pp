class common::singularity {
    file { "/etc/singularity":
        ensure => directory,
    }

    file { "/etc/singularity/singularity.conf":
        ensure => present,
        owner => root,
        group => root,
        mode => "0444",
        source => "puppet:///modules/common/etc/singularity/singularity.conf",
        require => File["/etc/singularity"],
    }
}
