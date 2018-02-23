class common::packages {
    package {
        # Dan requests these disappear:
        'atlas':
            ensure => absent;
        'mpi-selector':
            ensure => absent;
        'mvapich2':
            ensure => absent;
        'netcdf':
            ensure => absent;
        'hdf5':
            ensure => absent;
        'openmpi':
            ensure => absent;

        # This is a package that touches all sorts of performance settings for dynamic usage.
        'tuned':
            ensure => absent;

        # Install our custom package list:

        'singularity':
            ensure => present;
        'sssd':
            ensure => present;
        'ipset-service':
            ensure => present;
        'iptables-services':
            ensure => present;
        'ca-certificates':
            ensure => present;
        'colordiff':
            ensure => present;
        'psutils-perl':
            ensure => present;
        'dbus-x11':
            ensure => present;
        'emacs':
            ensure => present;
        'emacs-common':
            ensure => present;
        'expat-devel':
            ensure => present;
        'finger':
            ensure => present;
        'gstreamer-plugins-good':
            ensure => present;
        'gstreamer-devel':
            ensure => present;
        'gtk2-devel':
            ensure => present;
        'hsi_htar':
            ensure => present;
        'htop':
            ensure => present;
        'ipset':
            ensure => present;
        'iptables':
            ensure => present;
        'libicu-devel':
            ensure => present;
        'libjpeg-turbo-devel':
            ensure => present;
        'libXp':
            ensure => present;
        'lldpd':
            ensure => present;
        'openssl-devel':
            ensure => present;
        'pam_radius':
            ensure => present;
        'procmail':
            ensure => present;
        'python34':
            ensure => present;
        'rasdaemon':
            ensure => present;
        'rubygem-json':
            ensure => present;
        'rubygem-net-ping':
            ensure => present;
        'samba-client':
            ensure => present;
        'sox':
            ensure => present;
        'startup-notification-devel':
            ensure => present;
        'stress':
            ensure => present;
        'time':
            ensure => present;
        'tree':
            ensure => present;
        'unixODBC-devel':
            ensure => present;
        'wget':
            ensure => present;
        'xorg-x11-server-Xvfb':
            ensure => present;
        'ack':
            ensure => present;
        'git':
            ensure => present;
        'perl-Curses':
            ensure => present;
        'shflags':
            ensure => present;
        'tcl':
            ensure => present;
        'tk':
            ensure => present;
        'bash':
            ensure => present;
        'bash-completion':
            ensure => present;
        'bc':
            ensure => present;
        'bison':
            ensure => present;
        'bison-devel':
            ensure => present;
        'binutils':
            ensure => present;
        'byacc':
            ensure => present;
        'bzip2':
            ensure => present;
        'bzip2-devel':
            ensure => present;
        'cmake':
            ensure => present;
        'dos2unix':
            ensure => present;
        'ethtool':
            ensure => present;
        'dstat':
            ensure => present;
        'flex':
            ensure => present;
        'flex-devel':
            ensure => present;
        'flac':
            ensure => present;
        'gcc':
            ensure => present;
        'gzip':
            ensure => present;
        'iotop':
            ensure => present;
        'ioping':
            ensure => present;
        'ksh':
            ensure => present;
        'make':
            ensure => present;
        'mercurial':
            ensure => present;
        'nfs-utils':
            ensure => present;
        'openssh-clients':
            ensure => present;
        'openssh-server':
            ensure => present;
        'p7zip':
            ensure => present;
        'p7zip-plugins':
            ensure => present;
        'parted':
            ensure => present;
        'pciutils':
            ensure => present;
        'pdsh':
            ensure => present;
        'rpm-build':
            ensure => present;
        'sudo':
            ensure => present;
        'screen':
            ensure => present;
        'tmux':
            ensure => present;
        'unzip':
            ensure => present;
        'zsh':
            ensure => present;
        'subversion':
            ensure => present;
        'nss-pam-ldapd':
            ensure => present;
        'lua-bitop':
            ensure => present;
        'lua-filesystem':
            ensure => present;
        'lua-posix':
            ensure => present;
        'apr':
            ensure => present;
        'apr-util':
            ensure => present;
        'autoconf':
            ensure => present;
        'autofs':
            ensure => present;
        'autogen':
            ensure => present;
        'automake':
            ensure => present;
        'cronie':
            ensure => present;
        'cronie-noanacron':
            ensure => present;
        'crontabs':
            ensure => present;
        'firefox':
            ensure => present;
        'gc':
            ensure => present;
        'gcc-c++':
            ensure => present;
        'gcc-gfortran':
            ensure => present;
        'gettext':
            ensure => present;
        'gettext-common-devel':
            ensure => present;
        'gettext-devel':
            ensure => present;
        'gettext-libs':
            ensure => present;
        'guile':
            ensure => present;
        'guile-devel':
            ensure => present;
        'hesiod':
            ensure => present;
        'hunspell':
            ensure => present;
        'hunspell-en-US':
            ensure => present;
        'imake':
            ensure => present;
        'intltool':
            ensure => present;
        'libcurl-devel':
            ensure => present;
        'libgfortran':
            ensure => present;
        'libICE-devel':
            ensure => present;
        'libpipeline':
            ensure => present;
        'libquadmath-devel':
            ensure => present;
        'libSM-devel':
            ensure => present;
        'libstdc++-devel':
            ensure => present;
        'libunistring':
            ensure => present;
        'libuuid-devel':
            ensure => present;
        'libXmu-devel':
            ensure => present;
        'libXt-devel':
            ensure => present;
        'libXxf86misc':
            ensure => present;
        'man-db':
            ensure => present;
        'man-pages':
            ensure => present;
        'mesa-dri-drivers':
            ensure => present;
        'mesa-filesystem':
            ensure => present;
        'mesa-libGLU':
            ensure => present;
        'mesa-libGLU-devel':
            ensure => present;
        'mesa-private-llvm':
            ensure => present;
        'mozilla-filesystem':
            ensure => present;
        'ncurses-devel':
            ensure => present;
        'libquadmath':
            ensure => present;
        'perf':
            ensure => present;
        'postfix':
            ensure => present;
        'python-devel':
            ensure => present;
        'readline-devel':
            ensure => present;
        'rubygem-diff-lcs':
            ensure => present;
        'rxvt-unicode':
            ensure => present;
        'rxvt-unicode-256color':
            ensure => present;
        'sensu':
            ensure => present;
        'strace':
            ensure => present;
        'tcl-devel':
            ensure => present;
        'tcsh':
            ensure => present;
        'xmlsec1':
            ensure => present;
        'xmlsec1-openssl':
            ensure => present;
        'xorg-x11-server-utils':
            ensure => present;
        'xz-devel':
            ensure => present;
        'mlocate':
            ensure => present;
        'openldap':
            ensure => present;
        'openldap-clients':
            ensure => present;
        'compat-libstdc++-33':
            ensure => present;
        'numactl':
            ensure => present;
        'numactl-devel':
            ensure => present;
        'numactl-libs':
            ensure => present;
        'tcpdump':
            ensure => present;
        'traceroute':
            ensure => present;
        'hwloc':
            ensure => present;
        'hwloc-plugins':
            ensure => present;
        'hwloc-libs':
            ensure => present;
        'hwloc-devel':
            ensure => present;
        'hwloc-gui':
            ensure => present;
        'compat-libcolord1':
            ensure => present;
        'libxshmfence-devel':
            ensure => present;
        'mesa-libOSMesa':
            ensure => present;
        'mesa-libOSMesa-devel':
            ensure => present;
        'pytalloc':
            ensure => present;
        'python2-pip':
            ensure => present;
        'python-backports':
            ensure => present;
        'python-backports-ssl_match_hostname':
            ensure => present;
        'python-setuptools':
            ensure => present;
        'perl-core':
            ensure => present;
        'perl-Perl4-CoreLibs':
            ensure => present;
        'perl-AppConfig':
            ensure => present;
        'perl-DBD-MySQL':
            ensure => present;
        'perl-Sys-Syslog':
            ensure => present;
        'pdsh-mod-dshgroup':
            ensure => present;
        'pdsh-mod-netgroup':
            ensure => present;
        'pdsh-rcmd-ssh':
            ensure => present;
        'redhat-lsb':
            ensure => present;
        'motif':
            ensure => present;
        'motif-devel':
            ensure => present;
        'motif-static':
            ensure => present;
        'libtool':
            ensure => present;
    }
}
