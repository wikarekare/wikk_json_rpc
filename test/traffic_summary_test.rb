#!/usr/local/bin/ruby
require 'time'
require 'json'
RLIB = '/wikk/rlib' unless defined? RLIB
require_relative "#{RLIB}/rpc/rpc.rb"
require_relative "#{RLIB}/rpc/minimal_cgi.rb"

# Test through Ruby RPC instance, not via TCP Socket
def test_rpc_rmethods(cgi)
  # rpc = RPC.new
  puts 'Entering test_rpc_echo'
  begin
    r = RPC.rpc( cgi: cgi,
                 query: { 'method' => 'Traffic.site_daily_usage_summary',
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

env = {
  'REMOTE_ADDR' => '127.0.0.1',
  'HTTP_COOKIE' => ''
}
cgi = WIKK::Minimal_CGI.new(env: env)

puts 'Daily Traffic Summary Site wikk003'
test_rpc_rmethods(cgi)
