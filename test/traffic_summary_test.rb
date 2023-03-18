#!/usr/local/bin/ruby
require 'time'
require 'json'
RLIB = '/wikk/rlib' unless defined? RLIB
require_relative "#{RLIB}/rpc/rpc.rb"

# Test through Ruby RPC instance, not via TCP Socket
def test_rpc_rmethods
  # rpc = RPC.new
  puts 'Entering test_rpc_echo'
  begin
    r = RPC.rpc( query: { 'method' => 'Traffic.site_daily_usage_summary',
                          'kwparams' => {
                            'select_on' => { 'hostname' => 'wikk003' },
                            'set' => {},
                            'result' => []
                          },
                          'id' => 1234,
                          'version' => '1.1'
                        },
                 authenticated: true
               )
    hr = JSON.parse(r)
    p hr
  rescue StandardError => e
    puts e.message
  end
end

puts 'Daily Traffic Summary Site wikk003'
test_rpc_rmethods
