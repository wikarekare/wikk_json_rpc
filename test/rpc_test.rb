#!/usr/local/bin/ruby
require 'time'
require 'json'

load '/wikk/etc/wikk.conf' unless defined? WIKK_CONF  # to get MYSQL_CONF (which we don't actually use, but is read)

require_relative "#{RLIB}/rpc/minimal_cgi.rb"
require_relative "#{RLIB}/rpc/rpc.rb"

# Test through Ruby RPC instance, not via TCP Socket
def test_rpc_echo(cgi)
  # rpc = RPC.new
  puts 'Entering test_rpc_echo'
  begin
    r = RPC.rpc(  cgi: cgi,
                  query: { 'method' => 'RPC_Echo.echo',
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

def test_rpc_rmethods(cgi)
  puts 'Entering test_rpc_echo'
  begin
    r = RPC.rpc( cgi: cgi,
                 query: { 'method' => 'Test.get_rmethods',
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

env = {
  'REMOTE_ADDR' => '127.0.0.1',
  'HTTP_COOKIE' => ''
}

puts 'echo test'
cgi = WIKK::Minimal_CGI.new(env: env)
test_rpc_echo(cgi)

puts
puts 'Registered rmethods'
cgi = WIKK::Minimal_CGI.new(env: env)
test_rpc_rmethods(cgi)
