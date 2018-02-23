#! /usr/bin/env ruby
#
#   check-lxc-status
#
# DESCRIPTION:
#   This script checks the status of an LXC container, and alerts if it is not online.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#   check-lxc-status.rb -n name
#
# NOTES:
#
# Written by Spencer Julian for Purdue University.
#

require 'sensu-plugin/check/cli'

class CheckLXCStatus < Sensu::Plugin::Check::CLI
  option :name,
         :short => '-n name',
         :required => true

  def run
      cont_out = `lxc-info --name #{config[:name]}`.strip.downcase()
      if cont_out.include? "stopped"
          critical "Container #{config[:name]} is not running."
      elsif cont_out.include? "frozen"
          warning "Container #{config[:name]} is frozen."
      elsif not cont_out.include? "running"
          critical "Container #{config[:name]} is not in a running state."
      else
          ok "Container #{config[:name]} is running and is OK."
      end
  end
end
