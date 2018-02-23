class common::sensu {
    File {
        owner => sensu,
        group => sensu,
        mode  => "0444",
    }
    service { "sensu-client":
        ensure     => $run_services,
        enable     => true,
        hasrestart => true,
        notify     => Exec["daemon-reload"],
    }
    file { "/etc/systemd/system/sensu-client.service":
        ensure => present,
        owner  => root,
        group  => root,
        mode   => "0444",
        source => "puppet:///modules/common/etc/systemd/system/sensu-client.service",
    }
    file { "/var/run/sensu":
        ensure => directory,
        mode   => "0755",
    }
    # rabbitmq.json and sensuApiAuth.json are installed via syncfiles
    file { "/etc/sensu/conf.d/rabbitmq.json":
        owner  => sensu,
        group  => sensu,
        mode   => "0440",
    }
    file { "/etc/sensu/sensuApiAuth.json":
        owner  => sensu,
        group  => sensu,
        mode   => "0400",
    }
    file { "/etc/sensu/conf.d":
        ensure => directory,
    }
    file { "/etc/sensu/ssl":
        ensure => directory,
    }
    # key.pem is installed via syncfiles
    file { "/etc/sensu/ssl/key.pem":
        owner  => sensu,
        group  => sensu,
        mode   => "0400",
    }
    file { "/etc/sensu/ssl/cert.pem":
        ensure => present,
        owner  => sensu,
        group  => sensu,
        mode   => "0444",
        source => "puppet:///modules/common/etc/sensu/ssl/cert.pem",
    }
    file { "/etc/sensu/conf.d/client.json":
        ensure  => present,
        content => template("common/sensu-client.json.erb"),
    }
    file { "/etc/sensu/deleteSensuClient.py":
        ensure => present,
        owner  => puppet,
        group  => puppet,
        mode   => "0500",
        source => "puppet:///modules/common/etc/sensu/deleteSensuClient.py",
    }
    file { "/etc/sensu/sensuStashNode.py":
        ensure => present,
        owner  => root,
        group  => root,
        mode   => "0500",
        source => "puppet:///modules/common/etc/sensu/sensuStashNode.py",
    }
    file { "/etc/sensu/plugins":
        ensure  => directory,
        recurse => true,
        mode    => "0555",
        source  => "puppet:///modules/common/etc/sensu/plugins",
    }
}
