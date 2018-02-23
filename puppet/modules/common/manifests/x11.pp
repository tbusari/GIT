class common::x11 {
    file { "/usr/X11R6":
        ensure => directory,
    }
    file { "/usr/X11R6/bin":
        ensure => directory,
        require => File["/usr/X11R6"],
    }
    file { "/usr/X11R6/bin/xauth":
        ensure => link,
        target => "/usr/bin/xauth",
        require => File["/usr/X11R6/bin"],
    }
}
