class common::yum {
    # Installs the RCAC yum repository files
    File {
        owner => root,
        group => root,
        mode  => "0444",
    }
    file {
        "/etc/yum.repos.d/rcac-software.repo":
            ensure => present,
            source => "puppet:///modules/common/etc/yum.repos.d/rcac-software.repo";
        "/etc/yum.repos.d/rcac-epel7.repo":
            ensure => present,
            source => "puppet:///modules/common/etc/yum.repos.d/rcac-epel7.repo";
        "/etc/yum.repos.d/rcac-centos7-public.repo":
            ensure => present,
            source => "puppet:///modules/common/etc/yum.repos.d/rcac-centos7-public.repo";
        "/etc/yum.repos.d/rcac-centos7-server.repo":
            ensure => present,
            source => "puppet:///modules/common/etc/yum.repos.d/rcac-centos7-server.repo";
        "/etc/yum.repos.d/CentOS-Base.repo":
            ensure => absent;
        "/etc/yum.repos.d/CentOS-CR.repo":
            ensure => absent;
        "/etc/yum.repos.d/CentOS-Debuginfo.repo":
            ensure => absent;
        "/etc/yum.repos.d/CentOS-fasttrack.repo":
            ensure => absent;
        "/etc/yum.repos.d/CentOS-Media.repo":
            ensure => absent;
        "/etc/yum.repos.d/CentOS-Sources.repo":
            ensure => absent;
        "/etc/yum.repos.d/CentOS-Vault.repo":
            ensure => absent;
        "/etc/yum/vars/":
            ensure => directory;
        "/etc/yum/vars/repo_version_epel":
            ensure => present,
            source => "puppet:///modules/common/etc/yum/vars/repo_version_epel";
        "/etc/yum/vars/repo_version_rhel":
            ensure => present,
            source => "puppet:///modules/common/etc/yum/vars/repo_version_rhel";
        "/etc/yum/vars/rhver":
            ensure => present,
            source => "puppet:///modules/common/etc/yum/vars/rhver";
    }
}
