class common {
    class { 'common::yum': }->
    class { 'common::packages': }->
    class { [ 'common::accounts',
              'common::autofs',
              'common::config',
              'common::firewall',
              'common::hsi',
              'common::logrotate',
              'common::postfix',
              'common::rcacsite',
              'common::rsyslog',
              'common::shells',
              'common::singularity',
              'common::ssh',
              'common::time',
              'common::x11' ]:
    }
    exec { "daemon-reload":
        command     => "/usr/bin/systemctl daemon-reload",
        refreshonly => true,
    }
}
