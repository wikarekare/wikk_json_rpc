#!/usr/local/bin/ruby
require 'time'
require 'json'
RLIB = '/wikk/rlib' unless defined? RLIB
require_relative "#{RLIB}/rpc/rpc.rb"

def test_rpc_rmethods
  # rpc = RPC.new
  puts 'Entering test_rpc_echo'
  begin
    r = RPC.rpc( query: { 'method' => 'Test.get_rmethods',
                          'kwparams' => {
                            'select_on' => {},
                            'set' => {},
                            'result' => []
                          },
                          'id' => 1234,
                          'version' => '1.1'
                        },
                 authenticated: true
               )
    hr = JSON.parse(r)
    hr['result']['rmethods'].sort.each do |rclass, rmethods|
      puts "#{rclass} #{rmethods}"
    end
  rescue StandardError => e
    puts e.message
  end
end

puts 'Registered rmethods'
test_rpc_rmethods
