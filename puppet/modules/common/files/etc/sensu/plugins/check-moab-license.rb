#! /usr/bin/env ruby
#
#   check-moab-license
#
# DESCRIPTION:
#   This plugin checks the moab license file and alerts on the given parameters.
#
# OUTPUT:
#   plain text
#
# PLATFORMS:
#   Linux, BSD
#
# DEPENDENCIES:
#   gem: sensu-plugin
#
# USAGE:
#  check-moab-license.rb -l /opt/moab/etc/moab.lic -w 604800 -c 86400
#
# NOTES:
#  Written by Spencer Julian, based on original bash script by John Williamson
#
# LICENSE:
# Copyright 2014 Purdue University.
# MIT License, as Sensu.
#

require 'rubygems' if RUBY_VERSION < '1.9.0'
require 'sensu-plugin/check/cli'
require 'fileutils'
require 'time'

class CheckMoabLicense < Sensu::Plugin::Check::CLI
  option :license,
         :description => 'Moab License File Location',
         :short => '-l FILE',
         :long => '--license FILE'

  option :warning,
         :description => 'Warn if expiration less than provided time in seconds',
         :short => '-w SECONDS',
         :long => '--warning SECONDS'

  option :critical,
         :description => 'Critical if expiration less than provided time in seconds',
         :short => '-c SECONDS',
         :long => '--critical SECONDS'

  def run
    unknown 'No license file specified' unless config[:license]
    unknown 'No warn or critical time specified' unless config[:warning] || config[:critical]
    if File.exist?(config[:license])
      if File.size?(config[:license]).nil?
        critical 'File has zero size, is there a license in place?'
      end
      File.open(config[:license]).each do |line|
          if(line['Expires'])
              time_remaining = Time.parse(line).to_i - Time.now.to_i
              tr_string = [time_remaining / 3600, time_remaining/ 60 % 60, time_remaining % 60].map { |t| t.to_s.rjust(2,'0') }.join(':')
              if time_remaining < config[:critical].to_i and time_remaining > 0
                  critical "License expires in #{tr_string}."
              elsif time_remaining < config[:critical].to_i and time_remaining <= 0
                  critical "License has expired."
              elsif time_remaining < config[:warning].to_i
                  warning "License expires in #{tr_string}."
              else
                  ok "License expires in #{tr_string}."
              end
          end
      end
    else
      critical 'File does not exist, is there a license in place?'
    end

  end
end
