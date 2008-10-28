#Script that allows you to manually refresh the cache
require 'drb'
require 'yaml'

#Load the configuration file
$config = YAML::load_file('config.yml')

DRb.start_service
fetch_cli = DRbObject.new(nil, "druby://#{$config['drb_hostname']}:#{$config['drb_port']}")

begin
  result = fetch_cli.refresh_cache!
rescue => err
  puts err
  exit
end

puts "Refreshed the CLI / PCO_OUTBOUNDSERVICE cache..."
