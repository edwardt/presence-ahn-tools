require 'drb'
require 'rubygems'
require 'yaml'
require 'json' # Get with "gem install json"
require 'sinatra'

#Load the configuration file
config_file = File.expand_path(File.dirname(__FILE__) + "./config/config.yml")
$config = YAML::load_file(config_file)

# Adhearsion must be running also. Type "ahn start ." from within this folder
Adhearsion = DRbObject.new_with_uri "druby://#{$config["ahn_drb_hostname"]}:#{$config["ahn_drb_port"]}"

def format_source source
  return $config["channel_technology"] + '/' + source
end

post "/call" do  
  options = { :channel => format_source(params[:source]),
              :context => $config["click_to_call_context"],
              :exten => params[:destination],
              :priority =>  1,
              :variable =>'CLICKTOCALL=TRUE',
              :timeout => 43200000,
              :async => false }
              
  Adhearsion.proxy.originate(options)
  { :dial_result => "ok" }.to_json
end