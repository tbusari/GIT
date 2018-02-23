#! /usr/bin/env ruby
#
#  check-ping-enhanced
#
# DESCRIPTION:
#   This is an enhanced Ping check script for Sensu.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux
#
# DEPENDENCIES:
#   gem: sensu-plugin
#   gem: net-ping
#
# USAGE:
#   check-ping-enhanced -h host -T timeout [--report]
#
# NOTES:
#
# LICENSE:
#   Spencer Julian (Purdue University) <smjulian@purdue.edu>
#   Based on check-ping by Deepak Mohan Dass   <deepakmdass88@gmail.com>
#   Released under the same terms as Sensu (the MIT license); see LICENSE
#   for details.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'net/ping'

class CheckPING < Sensu::Plugin::Check::CLI
  option :host,
         :short => '-h host',
         :default => 'localhost'

  option :timeout,
         :short => '-T timeout',
         :proc => proc{ |a| a.to_i },
         :default => 5

  option :count,
         :short => '-c count',
         :description => 'The number of ping requests',
         :proc => proc{ |a| a.to_i },
         :default => 1

  option :interval,
         :short => '-i interval',
         :description => 'The number of seconds to wait between ping requests',
         :proc => proc{ |a| a.to_f },
         :default => 1

  option :warn_ratio,
         :short => '-W ratio',
         :description => 'Warn if successful ratio is under this value',
         :proc => proc{ |a| a.to_f },
         :default => 0.5

  option :critical_ratio,
         :short => '-C ratio',
         :description => 'Critical if successful ratio is under this value',
         :proc => proc{ |a| a.to_f },
         :default => 0.2

  option :report,
         :short => '-r',
         :long => '--report',
         :description => 'Attach MTR report if ping is failed',
         :default => false

  option :check_all_addresses,
         :short => '-a',
         :long => '--check_all_addresses',
         :description => 'Check all addresses on a host with multiple records. Fires warn or critical based on ratio for any host.',
         :default => false

  def resolve_domain
      output = `dig #{config[:host]} +short +time=1`
      entries = output.strip.split("\n").reject { |l| l.match('^;') || l.match('^$') }
      entries
  end

  def ping(hostList)
    return_hosts = { }
    hostList.each do |host|
        result = []
        pt = Net::Ping::External.new(host, nil, config[:timeout])
        config[:count].times do |i|
            sleep(config[:interval]) unless i == 0
            result[i] = pt.ping?
        end

        successful_count = result.count(true)
        total_count = config[:count]
        success_ratio = successful_count / total_count.to_f

        if success_ratio <= config[:critical_ratio]
            return_hosts[host] = 2
        elsif success_ratio <= config[:warn_ratio]
            return_hosts[host] = 1
        else
            return_hosts[host] = 0
        end
    end
    return_hosts
  end

  def run
    hosts = config[:check_all_addresses] ? resolve_domain : [config[:host]]
    success_hash = ping(hosts)
    message = ""
    if success_hash.has_value?2 or success_hash.has_value?1
        message = "ICMP ping unsuccessful for the following hosts: #{success_hash.select{|k,v| v == 2 or v == 1}.keys.join("\n")}\n"
        if config[:report]
            success_hash.select{|k,v| v == 2 or v == 1}.each do |k,v|
                message = message + "REPORT FOR #{k}\n============================================\n"
                report = `mtr --curses --report-cycles=1 --report --no-dns #{k}`
                message = message + report + "\n\n"
            end
        end
        if success_hash.has_value?2
            critical message
        else
            warning message
        end
    else
        message = "ICMP ping successful."
        ok message
    end
  end
end
