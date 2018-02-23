class common::accounts {
    # This class populates items related to accounts and managing accounts

    File {
        owner => root,
        group => root,
    }

    # Copy in statically generated account files
    file { "/var/db/Makefile":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/var/db/Makefile",
    }
    file { "/var/db/nssdb_update.sh":
        ensure => present,
        mode => "0500",
        source => "puppet:///modules/common/var/db/nssdb_update.sh",
    }
    file { "/etc/cron.d/nssdb":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/cron.d/nssdb",
    }

    # set up nsswitch to use db files
    file { "/etc/nsswitch.conf":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/nsswitch.conf",
    }

    file { "/etc/sudoers":
        ensure => present,
        mode   => "0440",
        source => "puppet:///modules/common/etc/sudoers",
    }

    # allow ldap utilities to search rcac ldap
    file { "/etc/openldap/ldap.conf":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/openldap/ldap.conf",
    }
    file { "/etc/certs":
        ensure => directory,
        mode => "0555",
    }
    file { "/etc/openldap/cacerts":
        ensure => directory,
        mode => "0555",
    }
    file { "/etc/certs/cacert.pem":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/certs/cacert.pem",
        require => File["/etc/certs"],
    }
    file { "/etc/openldap/cacerts/cacert.pem":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/certs/cacert.pem",
        require => File["/etc/openldap/cacerts"],
    }

    # sssd - directory services daemon
    service { "sssd":
        ensure => $run_services,
        enable => true,
        require => File["/etc/sssd/sssd.conf"],
    }
    file { "/etc/sssd":
        ensure => directory,
        mode => "0500",
    }
    file { "/etc/sssd/sssd.conf":
        ensure => present,
        mode => "0400",
        source => "puppet:///modules/common/etc/sssd/sssd.conf",
        require => File["/etc/sssd"],
        notify => Service["sssd"],
    }

    file { "/etc/nslcd.conf":
        ensure => present,
        mode   => "0444",
        source => "puppet:///modules/common/etc/nslcd.conf",
        notify => Service["nslcd"],
    }
    service { "nslcd":
        ensure => $run_services,
        enable => true,
        require => File["/etc/nslcd.conf"],
    }

    file { "/etc/pam.d/password-auth-ac":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/pam.d/password-auth-ac",
    }
    file { "/etc/pam.d/password-auth":
        ensure => link,
        target => "/etc/pam.d/password-auth-ac",
    }
    file { "/etc/pam.d/system-auth-ac":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/pam.d/system-auth-ac",
    }
    file { "/etc/pam.d/system-auth":
        ensure => link,
        target => "/etc/pam.d/system-auth-ac",
    }
    file { "/etc/pam.d/su":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/pam.d/su",
    }
    file { "/etc/pam.d/sudo":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/pam.d/sudo",
    }

    file { "/etc/security/limits.d/limits.conf":
        ensure => present,
        mode => "0444",
        source => "puppet:///modules/common/etc/security/limits.d/limits.conf",
    }

    # Fix chsh and passwd account management tools
    file { "/usr/local/bin/chsh":
        ensure => present,
        mode => "0555",
        source => "puppet:///modules/common/usr/local/bin/chsh",
    }
    file { "/usr/local/bin/passwd":
        ensure => present,
        mode => "0555",
        source => "puppet:///modules/common/usr/local/bin/passwd",
    }
    file { "/usr/bin/chsh":
        ensure => links,
        target => "/usr/local/bin/chsh",
        require => File["/usr/local/bin/chsh"],
    }
    file { "/usr/bin/passwd":
        ensure => links,
        target => "/usr/local/bin/passwd",
        require => File["/usr/local/bin/passwd"],
    }
}
