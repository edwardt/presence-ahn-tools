#!/usr/bin/env ruby

require 'drb'
require 'rubygems'
require 'yaml'
require 'json' # Get with "gem install json"
require 'sinatra'

#Load the configuration file
config_file = File.expand_path(File.dirname(__FILE__) + "/../config/config.yml")
$config = YAML::load_file(config_file)

# Adhearsion must be running also. Type "ahn start ." from within this folder
adhearsion = DRbObject.new_with_uri("druby://#{$config["ahn_drb_hostname"]}:#{$config["ahn_drb_port"]}")
@@fetch_cli = DRbObject.new_with_uri("druby://#{$config["drb_hostname"]}:#{$config["drb_port"]}")

#Format the number in order to ensure it is for SIP or IAX2 or Zap or even Local
def format_source phone_number
  #If it is a local call we need to handle it a bit differently than other technologies
  if $config["source_technology"] == 'Local'
    phone_number = phone_number.to_s + "@" + $config["local_source_context"].to_s
  else
    #Add the outbound trunk if it is present in the configuration
    if $config["dial_trunk"] != nil
      phone_number = phone_number.to_s + "@" + $config["dial_trunk"].to_s
    end
  end
  
  phone_number = $config["source_technology"] + '/' + phone_number.to_s
  return phone_number
end

#Verify the final dial string prepending the prefix and long distance code
def format_destination phone_number, serviceid
  
  #If an international prefix, only add a 9 to dial out and apply no North American rules
  if phone_number.to_s.slice(0,3) == $config["international_prefix"].to_s
    phone_number = $config["dial_prefix"].to_s + phone_number.to_s
  else
    #If 11-digit numbers simply pass with a 9 pre-pended to allow for 1 + 10 digits from the api request
    if $config["allow_11_digit_dialing"] == true && phone_number.to_s.length == 11
      phone_number = $config["dial_prefix"].to_s + phone_number.to_s
    else
      #See if the number is on the exception list and then either add only a dial prefix if it is
      #or a long distance prefix as well if it is not
      if phone_number.to_s.match($config["exception_list"])
        phone_number = $config["dial_prefix"].to_s + phone_number.to_s
      else
        phone_number = $config["dial_prefix"].to_s + $config["long_distance_prefix"].to_s + phone_number.to_s
      end
    end
  end

  #Add the prefix for setting callerid
  service = @@fetch_cli.get_service(serviceid)
  phone_number = '0' + service[:prefix].slice(1,3) + phone_number
  
  return phone_number
end

#Expose the RESTFful API via Sinatra web server
post "/call" do  
  
  source = format_source(params[:source])
  destination = format_destination(params[:destination], params[:serviceid])
  
  #Build the options to place the call
  options = { :channel => source,
              :context => $config["local_destination_context"], #$config["click_to_call_context"],
              :exten => destination,
              :priority =>  1,
              :timeout => 43200000,
              :async => $config["dial_async"] }
              
  begin
    #Return a JSON object with 'ok' to the calling application
    adhearsion.proxy.originate(options)
    { :dial_result => "ok" }.to_json
  rescue => err
    { :dial_result => "error", :error => err }.to_json
  end
end