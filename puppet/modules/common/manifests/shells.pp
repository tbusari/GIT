class common::shells {

    File {
        owner => root,
        group => root,
        mode  => "0555",
    }

    file { "/usr/local/bin/bash":
        ensure => link,
        target => "/bin/bash",
    }

    file { "/usr/local/bin/tcsh":
        ensure => link,
        target => "/bin/tcsh",
    }

    file { "/usr/local/bin/perl":
        ensure => link,
        target => "/usr/bin/perl",
    }

    file { "/etc/shells":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/shells",
    }

    file { "/etc/bashrc":
        ensure => present,
        source => "puppet:///modules/common/etc/bashrc",
    }
    file { "/etc/csh.cshrc":
        ensure => present,
        source => "puppet:///modules/common/etc/csh.cshrc",
    }
    file { "/etc/kshrc":
        ensure => present,
        source => "puppet:///modules/common/etc/kshrc",
    }
    file { "/etc/zshrc":
        ensure => present,
        source => "puppet:///modules/common/etc/zshrc",
    }
    file { "/etc/profile.d/000_rcac_prompt.sh":
        ensure => present,
        source => "puppet:///modules/common/etc/profile.d/000_rcac_prompt.sh",
    }
    file { "/etc/profile.d/000_rcac_prompt.csh":
        ensure => present,
        source => "puppet:///modules/common/etc/profile.d/000_rcac_prompt.csh",
    }
    file { "/etc/profile.d/hpss.sh":
        ensure => present,
        source => "puppet:///modules/common/etc/profile.d/hpss.sh",
    }
    file { "/etc/profile.d/hpss.csh":
        ensure => present,
        source => "puppet:///modules/common/etc/profile.d/hpss.csh",
    }
}
