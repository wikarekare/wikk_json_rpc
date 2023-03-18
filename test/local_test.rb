#!/usr/local/bin/ruby
require 'time'
RLIB = '/wikk/rlib' unless defined? RLIB
require_relative "#{RLIB}/wikk_conf.rb"  # to get MYSQL_CONF (which we don't actually use, but is read)
require_relative "#{RLIB}/rpc/rpc.rb"

# Test through Ruby RPC instance, not via TCP Socket
def test_rpc_echo
  # rpc = RPC.new
  puts 'Entering test_rpc_echo'
  begin
    r = RPC.rpc( query: { 'method' => 'RPC_Echo.echo',
                          'kwparams' => {
                            'select_on' => { 'message' => 'The quick brown fox jumped over the lazy dog' },
                            'set' => {},
                            'result' => []
                          },
                          'id' => 1234,
                          'version' => '1.1'
                        },
                 authenticated: true
               )
    puts 'test_rpc_echo: RPC_Echo.echo call completed'
    puts r.class
    puts r
  rescue StandardError => e
    puts e.message
  end
end

test_rpc_echo
