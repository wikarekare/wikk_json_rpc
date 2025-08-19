#!/usr/local/bin/ruby
require 'time'
require 'wikk_webbrowser'
require 'pp'
require 'optparse'

# Set this to the current test web server (Get address when it is spawned)
TEST_WEB_SERVER = '127.0.0.1'
TEST_PORT = 3223

# Test rpc.rbx cgi via http
class REMOTE_RPC
  def initialize(url:, host:, identity: nil, auth: nil)
    @cookies = nil
    @url = url
    @identity = identity
    @auth = auth
    @host = host
  end

  # JSON RPC call via the web browser @ host
  # Ignoring authentication for the moment. Testing via http will tell us if the service works.
  # @param url [String] cgi URL
  # @param query [String] JSON RPC post data
  # @param return [String] Parsed JSON response from the web server
  def self.rpc(url:, host:, port:, query:)
    WIKK::WebBrowser.http_session(host: host, port: port) do |ws|
      response = ws.post_page(query: url,
                              # authorization: wb.bearer_authorization(token: @auth_token),
                              content_type: 'application/json',
                              data: query.to_j
                               # extra_headers: { "x-apikey"=> NIWA_API_KEY }
                             )
      @cookies = ws.cookies
      return JSON.parse(response)
    end
  end
end

# JSON RPC call via the web browser @ host
# Ignoring authentication for the moment. Testing via http will tell us if the service works.
# @param url [String] cgi URL
# @param query [String] JSON RPC post data
# @param return [String] Parsed JSON response from the web server
def rpc(url:, host:, port:, query:)
  WIKK::WebBrowser.http_session(host: host, port: port) do |ws|
    response = ws.post_page(query: url,
                            # authorization: wb.bearer_authorization(token: @auth_token),
                            content_type: 'application/json',
                            data: query.to_j
                             # extra_headers: { "x-apikey"=> NIWA_API_KEY }
                           )
    @cookies = ws.cookies
    return JSON.parse(response)
  end
end

# Same test we ran against the local library, but via a URL.
# No authorization step, so unauthorized testing only.
def test_rpc_echo
  # rpc = RPC.new
  puts 'Entering test_rpc_echo'
  begin
    r = rpc( url: 'rpc',
             host: @options[:host],
             port: @options[:port],
             query: { 'method' => 'RPC_Echo.echo',
                      'kwparams' => {
                        'select_on' => { 'message' => 'The quick brown fox jumped over the lazy dog' },
                        'set' => {},
                        'result' => []
                      },
                      'id' => 1234,
                      'version' => '1.1'
                   }
           )
    puts 'test_rpc_echo: RPC_Echo.echo call completed'
    puts r.class
    puts r
  rescue StandardError => e
    puts "Exception from RPC_Echo.echo RPC.rpc: #{e.message}"
  end
end

# Convert @cookies to ; separated strings
# @return cookies string
def cookies_to_s
  @cookies.nil? ? '' : @cookies.to_a.map { |v| v.join('=') }.join('; ')
end

def fetch_rmethods
  puts 'Entering fetch_rmethods'
  begin
    r = REMOTE_RPC.rpc(  url: 'rpc',
                         host: @options[:host],
                         port: @options[:port],
                         query: { 'method' => 'Test.get_rmethods',
                                  'kwparams' => {
                                    'select_on' => {},
                                    'set' => {},
                                    'result' => []
                                  },
                                  'id' => 1234,
                                  'version' => '1.1'
                        }
                      )
    puts 'fetch_rmethods: Test.get_rmethods call completed'
    puts r.class
    puts r
    puts 'Cookies:'
    puts cookies_to_s
  rescue StandardError => e
    puts "Exception from Test.get_rmethods REMOTE_RPC.rpc: #{e.message}"
  end
end

# parse command line arguments
# Sets @options based on command line args
def parse_options
  @options = {
    host: TEST_WEB_SERVER,
    port: TEST_PORT
  }
  @optparse = OptionParser.new do |opts|
    opts.banner = "Usage: cgi-test --ip <ip> --port <port>\n"
    opts.on( '-?', '--help', 'Display usage' ) do
      puts opts
      exit 0
    end
    opts.on( '-p', '--port [PORT]', Integer, 'Server Port' ) do |port|
      if port.nil?
        puts opts
        exit 1
      end
      @options[:port] = port
    end
    opts.on( '-h', '--host [server]', String, 'Server IPv4 address' ) do |server|
      if server.nil?
        puts opts
        exit 1
      end
      @options[:host] = server
    end
  end
  @optparse.parse!
end

parse_options

puts 'echo test'
test_rpc_echo

puts
puts 'Registered rmethods'
fetch_rmethods
