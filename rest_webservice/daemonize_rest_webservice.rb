#!/usr/bin/env ruby
# This is a startup script for use in /etc/init.d
# chkconfig: 2345 90 20
# description: Used to start and stop the rest_webservice
require 'rubygems'
require 'daemons'

APP_NAME = "rest_webservice"
BASE_DIR = "/opt/presence-ahn-tools"

@default_options = {
  :app_dir => "#{BASE_DIR}/#{APP_NAME}",
  :pid_dir => "#{BASE_DIR}/#{APP_NAME}/pid",
  :pid_file => "#{BASE_DIR}/#{APP_NAME}/pid/#{APP_NAME}.pid",
  :log_dir => "#{BASE_DIR}/#{APP_NAME}/log",
  :log_file => "#{BASE_DIR}/#{APP_NAME}/log/#{APP_NAME}.log"
}

file_to_run = @default_options[:app_dir] + "/" + APP_NAME + ".rb"
Daemons.run_proc(file_to_run) do
  exec "ruby #{file_to_run} -x -p 4567 -e production 2>&1 >> #{@default_options[:log_file]} & echo $! > #{@default_options[:pid_file]} &"
end