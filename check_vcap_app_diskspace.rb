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
    puts "required:    --url | -u <dea /varz URL>"
    puts "required:    --app | -a <application>"
    puts "required:    --warning | -w <warning threshold of FREE space left in percents>"
    puts "required:    --critical | -c <critical threshold for the same>"
    puts "    --help | -h  you know what it does"
    puts "i.e:"
    puts "    #{$0} -u http://mycloud-dea-node.com:34501/varz -a facebookkiller -w 10 -c 5"
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
# functions

def instancesInfo(url, app)
  ## get the json
    begin
        resp = Net::HTTP.get_response(URI.parse(url))
        rescue
           puts "Couldn't connect to #{url}. Check connection details and that DEA service is running."
           exit(UNKNOWN)
    end
    data = resp.body
    result = JSON.parse(data)
  ## chew the json
    return result['running_apps'].select{|f| f['name'] == app};
end




#
###############################################################################


###############################################################################
# sexy body

global_warning = 0
global_critical = 0

app_instances = instancesInfo(url, app)

if app_instances.length < 1
    puts "There is no instances of #{app} running on this DEA node"
    exit(WARNING)
end


  ## run through all instances and gather check results. update global status if needed
app_instances.each do |instance|
    disk_free = 100.0 - ( Float(instance['usage']['disk']) / Float(instance['disk_quota']) * 100.0)
    if disk_free <= Float(crit)
       message = "CRITICAL"
       global_critical = global_critical + 1
    elsif disk_free > Float(warn)
       message = "OK"
    else
       message = "WARNING"
       global_warning = global_warning + 1
    end
    url="http://localhost:#{instance['port']}"
    instance['check_result'] = "(#{instance['instance_id']}) #{url} <#{message}> free disk space: #{disk_free.round(2)} % "
end


  ## now once we have all info gathered lets print it out nicely
puts "warnings=#{global_warning}, criticals=#{global_critical},  click service link in Nagios to see more details per instance"
app_instances.each do |instance|
  puts instance['check_result']
end

if global_critical > 0
    exit(CRITICAL)
elseif global_warning > 0
    exit(WARNING)
else
    exit(OK)
end

#
###############################################################################
