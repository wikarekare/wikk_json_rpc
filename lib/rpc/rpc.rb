require 'wikk_configuration'

require_relative '_rpc.rb'          # Actual declaration of RPC
require_relative 'sql_helper.rb'    # RPC SQL helper methods. Being deprecated
require_relative 'time_iterator.rb' # RPC time iterator method. Being deprecated
require_relative 'acl.rb'

# Dynamically load the plugins, by requiring all files in the directory
path = File.dirname(__FILE__) # File.expand_path(File.dirname(__FILE__))
Dir.open("#{path}/plugins").each do |filename|
  next unless filename =~ /^[a-z].*\.rb$/

  begin
    require_relative "#{path}/plugins/#{filename}"
  rescue Exception => _e # rubocop:disable Lint/RescueException
    puts "Skipping loading '#{path}/plugins/#{filename}' Error: #{error}"
  end
end
