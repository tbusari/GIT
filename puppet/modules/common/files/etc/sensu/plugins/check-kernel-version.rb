#!/usr/bin/env ruby
#
# Check to see if the kernel installed on a system matches a given kernel,
# passed as an argument.
# ===
#
# Spencer Julian (smjulian@purdue.edu)

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'

class CheckKernelVersion < Sensu::Plugin::Check::CLI

  option :version,
    :description => 'Full version string to check against (using uname -r)',
    :short => '-v',
    :long => '--version VERSION',
    :required => true

  option :warn,
    :description => 'Exit as a warning instead of critical.',
    :short => '-w',
    :long => '--warn',
    :boolean => true

  def chk_kernel_version
    unknown "No version string specified." unless config[:version]
    kernel_version = `uname -r`.strip
    unless kernel_version == config[:version]
        send(
            config[:warn] ? :warning : :critical,
            "Current version #{kernel_version} does not match expected version #{config[:version]}"
        )
    end
    ok "Current version #{config[:version]} matches."
  end

  def run
    chk_kernel_version
  end

end
