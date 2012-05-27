#!/bin/env ruby
#####
# Written by Stanislav Kelberg | stanislav.kelberg@gmail.com
# I dont care if you use this code and don't include my name in it. If it was useful to you, it's good enough for me.
# I would appreciate if you have any suggestions to improve/extend the script. You can fork it if you like. Peace.
#####

require 'rubygems'
require 'json'
require 'net/http'
require 'getoptlong'

## Nagios states
OK=0
WARNING=1
CRITICAL=2
UNKNOWN=3

#############################################################################
#The whole argument verfication thing doesn't look very elegant. If you know a better way of doing it, please do.

opts = GetoptLong.new(
        ['--help', '-h', GetoptLong::NO_ARGUMENT],
        ['--url', '-u', GetoptLong::REQUIRED_ARGUMENT],
        ['--app', '-a', GetoptLong::REQUIRED_ARGUMENT],
        ['--warning', '-w', GetoptLong::REQUIRED_ARGUMENT],
        ['--critical', '-c', GetoptLong::REQUIRED_ARGUMENT]
    )


def printUsage(error_code)
    puts "Usage: "
    puts "required:    --url | -u <health_manager /varz URL>"
    puts "required:    --app | -a <application>"
    puts "required:    --warning | -w <warning treshold of app instances running>"
    puts "required:    --critical | -c <critical threshold for the same>"
    puts "    --help | -h  you know what it does"
    puts "i.e:"
    puts "    #{$0} -u http://mycloud.com:34502/varz -a facebookkiller -w 4 -c 1"
    exit(error_code)
end


unless ARGV.length == 8
    printUsage(UNKNOWN);
end


url = app = warn = crit = ""

begin
  opts.each do |opt, arg|
    case opt
      when '--url'
        url = arg
      when '--app'
        app = arg
      when '--warning'
        warn = arg
      when '--critical'
        crit = arg
    end
  end
  rescue
    printUsage(UNKNOWN)
end


if url == "" || app == "" || warn == "" || crit == ""
   printUsage(UNKNOWN)
end

#
###############################################################################


###############################################################################
# a few functions

def instancesRunning(url, app)
  ## get the json
    begin
        resp = Net::HTTP.get_response(URI.parse(url))
        rescue
           puts "Couldn't connect to #{url}. Check connection details and that health_manager is running."
           exit(UNKNOWN)
    end
    data = resp.body
    result = JSON.parse(data)
  ## chew the json
    return result['apps'].select{|f| f['name'] == app}[0]['instances']
end


def checkResult(instances, warn, crit, exitstatus)
  puts "#{instances} instances running."
  puts "*Thresholds:  warning - #{warn} or less, critical - #{crit} or less."
  exit(exitstatus)
end

#
###############################################################################


###############################################################################
# sexy body

instances = instancesRunning(url, app)


if instances > Integer(warn)
    checkResult(instances, warn, crit, OK)
elsif instances <= Integer(crit)
    checkResult(instances, warn, crit, CRITICAL)
else
    checkResult(instances, warn, crit, WARNING)
end

#
###############################################################################
