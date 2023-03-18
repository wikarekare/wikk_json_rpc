#!/usr/local/bin/ruby
require 'time'
require 'wikk_webbrowser'
require 'pp'

# Set this to the current test web server (Get address when it is spawned)
TEST_WEB_SERVER = '127.0.0.1'
TEST_PORT = 3223

# Test rpc.rbx cgi via http
class RPC
  def initialize(url:, host:, identity: nil, auth: nil)
    @cookies = []
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
  def self.rpc(url:, host:, query:)
    WIKK::WebBrowser.http_session(host: host, port: TEST_PORT) do |ws|
      response = ws.post_page(query: url,
                              # authorization: wb.bearer_authorization(token: @auth_token),
                              content_type: 'application/json',
                              data: query.to_j
                               # extra_headers: { "x-apikey"=> NIWA_API_KEY }
                             )
      return JSON.parse(response)
    end
  end
end

# Same test we ran against the local library, but via a URL.
# No authorization step, so unauthorized testing only.
def test_rpc_echo
  # rpc = RPC.new
  puts 'Entering test_rpc_echo'
  begin
    r = RPC.rpc(  url: "http://#{TEST_WEB_SERVER}/ruby/rpc.rbx",
                  host: TEST_WEB_SERVER,
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

def fetch_rmethods
  puts 'Entering fetch_rmethods'
  begin
    r = RPC.rpc(  url: "http://#{TEST_WEB_SERVER}/ruby/rpc.rbx",
                  host: TEST_WEB_SERVER,
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
  rescue StandardError => e
    puts "Exception from Test.get_rmethods RPC.rpc: #{e.message}"
  end
end

test_rpc_echo
fetch_rmethods
