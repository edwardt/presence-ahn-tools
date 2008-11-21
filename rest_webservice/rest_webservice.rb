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
adhearsion = DRbObject.new_with_uri "druby://#{$config["ahn_drb_hostname"]}:#{$config["ahn_drb_port"]}"

#Format the number in order to ensure it is for SIP or IAX2 or even TDM
def format_source source
  return $config["source_technology"] + '/' + source.to_s
end

#Verify the final dial string prepending the prefix and long distance code
def format_destination phone_number
  #See if the number is on the exception list and then either add only a dial prefix if it is
  #or a long distance prefix if it is not
  if phone_number.to_s.match($config["exception_list"])
    phone_number = $config["dial_prefix"].to_s + phone_number.to_s
  else
    phone_number = $config["dial_prefix"].to_s + $config["long_distance_prefix"].to_s + phone_number.to_s
  end
  
  #Add the outbound trunk if it is present in the configuration
  if $config["dial_trunk"] != nil
    phone_number = phone_number.to_s + "@" + $config["dial_trunk"].to_s
  end

  return phone_number
end

#Expose the RESTFful API via Sinatra web server
post "/call" do  
  
  source = format_source(params[:source])
  destination = format_destination(params[:destination])
  
  #Build the options to place the call
  options = { :channel => source,
              :context => $config["click_to_call_context"],
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