class common::ssh {
    service { "sshd":
        ensure => $run_services,
        enable => true,
    }
    file { "/usr/bin/rsh":
        ensure => link,
        target => "/usr/bin/ssh",
    }
    file { "/etc/cron.d/update_ssh_known_hosts":
        ensure => present,
        owner => root,
        group => root,
        mode => "0444",
        source => "puppet:///modules/common/etc/cron.d/update_ssh_known_hosts",
    }
    file { "/usr/libexec/openssh/ssh-keysign":
        ensure => present,
        owner => root,
        group => ssh_keys,
        mode => "4711",
    }

    file { "/etc/ssh/ssh_config":
        ensure => present,
        owner  => root,
        group  => root,
        mode   => "0444",
        source => "puppet:///modules/common/etc/ssh/ssh_config",
    }
    file { "/etc/ssh/sshd_config":
        ensure => present,
        owner  => root,
        group  => root,
        mode   => "0400",
        source => "puppet:///modules/common/etc/ssh/sshd_config",
        notify => Service["sshd"],
    }

    # This key file defaults to mode 0644, but this causes the warnings:
    # "no matching hostkey found; ssh_keysign: no reply; key_sign failed"
    # every time you ssh between hosts, which gets very spammy when using pdsh.
    # Preventing everyone from reading the file prevents the useless warnings.
    file { "/etc/ssh/ssh_host_ed25519_key.pub":
        mode => "0640",
    }
}
