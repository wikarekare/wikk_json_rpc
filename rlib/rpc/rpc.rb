require 'wikk_configuration'
require 'wikk_json'

require_relative '_rpc.rb'          # Actual declaration of RPC
require_relative 'acl.rb'

# Dynamically load the plugins, by requiring all files in the directory
path = File.dirname(__FILE__) # File.expand_path(File.dirname(__FILE__))
Dir.open("#{path}/plugins").each do |filename|
  next unless filename =~ /^[a-z].*\.rb$/

  begin
    require_relative "#{path}/plugins/#{filename}"
  rescue Exception => e # rubocop:disable Lint/RescueException -- We don't want cgi's crashing without producing output
    $stderr.puts "Skipping loading '#{path}/plugins/#{filename}' Error: #{e}"
  end
end
