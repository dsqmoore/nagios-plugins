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
        ['--page', '-p', GetoptLong::REQUIRED_ARGUMENT],
        ['--regex', '-r', GetoptLong::REQUIRED_ARGUMENT],
        ['--warning', '-w', GetoptLong::REQUIRED_ARGUMENT],
        ['--critical', '-c', GetoptLong::REQUIRED_ARGUMENT]
    )


def printUsage(error_code)
    puts "Usage: "
    puts "required:    --url | -u <dea /varz URL>"
    puts "required:    --app | -a <application>"
    puts "required:    --page | -p <page to render>"
    puts 'required:    --regex | -r "<Regex to search for on the page >"'
    puts "required:    --warning | -w <warning threshold for a single instance response time in seconds>"
    puts "required:    --critical | -c <critical threshold for the same>"
    puts "    --help | -h  you know what it does"
    puts "i.e:"
    puts "    #{$0} -u http://mycloud-dea-node.com:34501/varz -a facebookkiller -p /home -r " + '"title.*Killer.*/title"' + " -w 2 -c 5"
    exit(error_code)
end


unless ARGV.length == 12
    printUsage(UNKNOWN);
end


url = app = page = regex = warn = crit = ""

begin
  opts.each do |opt, arg|
    case opt
      when '--url'
        url = arg
      when '--app'
        app = arg
      when '--page'
        page = arg
      when '--regex'
        regex = arg
      when '--warning'
        warn = arg
      when '--critical'
        crit = arg
    end
  end
  rescue
    printUsage(UNKNOWN)
end


if url == "" || app == "" || page == "" || regex == "" || warn == "" || crit == ""
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
    url="http://localhost:#{instance['port']}#{page}"
       ## first lets see if it can connect at all
    start_time = Time.now
    begin
        resp = Net::HTTP.get_response(URI.parse(url))
        rescue
            instance['check_result'] = "(#{instance['instance_id']}) #{url} <CRITICAL> Couldn't connect to the URL"
            global_critical = global_critical + 1
            next
    end
    end_time = Time.now - start_time
      ## Ok, looks like we connected. Lets check the body out now
    body = resp.body
    match = Regexp.new(/#{regex}/).match(body)
    if not match
        instance['check_result'] = "(#{instance['instance_id']}) #{url} <CRITICAL> pattern '#{regex}' is not found on the page"
        global_critical = global_critical + 1
        next
    end
      ## so content looks right as well, lets see how fast it was
    if end_time < Float(warn)
       message = "OK"
    elsif end_time >= Float(crit)
       message = "CRITICAL"
       global_critical = global_critical + 1
    else
       message = "WARNING"
       global_warning = global_warning + 1
    end
    instance['check_result'] = "(#{instance['instance_id']}) #{url} <#{message}> response time #{end_time} sec"
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
