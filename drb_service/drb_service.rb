require 'rubygems'
require 'thread'
require 'yaml'
require 'activerecord'
require File.expand_path(File.dirname(__FILE__) + "/models/pco_outboundservice.rb")

#Load the configuration file
config_file = File.expand_path(File.dirname(__FILE__) + "../config/config.yml")
$config = YAML::load_file(config_file)

#Provide our database connection details from config.yml
ActiveRecord::Base.establish_connection(  
  :adapter  => $config["adapter"],   
  :database => $config["database"],   
  :username => $config["username"],   
  :password => $config["password"])

#Class for fetching a CLI from the Presence PCO_OUTBOUNDSERVICE db
class FetchCLI
  
  #Initialize the object
  def initialize
    @@last_cache_refresh = Time.now
    @@service_cache = []
    @@thread_lock = Mutex.new
  end
  
  def refresh_cache!
    @@thread_lock.synchronize {
      @@last_cache_refresh = Time.now
      @@service_cache = []
    }
  end
  
  #Method to obtain the CLI details from the prefix off of the Dial command
  def get prefix

    cached_prefix = nil
    
    #Check to see if the cache should be refreshed, if not search the cache
    if refresh_cache? == TRUE
      refresh_cache!
    else
      @@thread_lock.synchronize {
        cached_prefix = @@service_cache.detect { |service| service[:prefix] == prefix }
      }
    end
    
    #If we already have an entry in our cache return that, otherwise fetch from the db
    #and store in the cache
    if cached_prefix
      return cached_prefix
    else
      #Fetch the service details from the database
      begin
        service = PcoOutboundservice.find(:first, :conditions => ["PHONEPREFIX = ?", "?" + prefix])
      rescue => err
        return { :result => -1, :error => err }
      end
    
      #Evaluate and return the appropriate results
      if service
        @@thread_lock.synchronize {
          @@service_cache << breakdown_cli_components(prefix, service)
        }
        return breakdown_cli_components(prefix, service)
      else
        return { :result => -1, :error => "No Service Found" }
      end
    end
  end
  
  private 
  
  #Determine if the elapsed time since the cache was last dumped exceeds
  #the timeout set in the config.yml
  def refresh_cache?
    elapsed_seconds = Time.now - @@last_cache_refresh
    if (elapsed_seconds / 60) >= $config["cache_timeout"]
      return TRUE
    else
      return FALSE
    end
  end
  
  #Break down the service name into the appropriate CLI components
  def breakdown_cli_components(prefix, service)
    cli_components = service[:name].gsub(" ","").split('|')
    cli_hash = { :result => 0,
                 :prefix => prefix,
                 :callerid_name => cli_components[0].slice(0,14), 
                 :callerid_number => cli_components[1].lstrip }
    return cli_hash
  end
  
end

#Creat the object, launch the DRb server and wait for incoming requests
drb_server_object = FetchCLI.new
DRb.start_service("druby://#{$config['drb_hostname']}:#{$config['drb_port']}", drb_server_object)
DRb.thread.join