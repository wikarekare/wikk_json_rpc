#!/usr/local/bin/ruby
require 'json'
load '/wikk/etc/wikk.conf' unless defined? WIKK_CONF

require 'wikk_json'
require 'wikk_webbrowser'

SERVER = 'www.wikarekare.org'

# Set up to call the webserver via the loopback
class RPC
  def initialize(url:, identity: nil, auth: nil)
    @cookies = []
    @url = url
    @identity = identity
    @auth = auth
  end

  def self.rpc(url:, query:, identity: nil, auth: nil) # rubocop:disable Lint/UnusedMethodArgument
    WIKK::WebBrowser.https_session(host: SERVER) do |ws|
      response = ws.post_page(query: url,
                              content_type: 'application/json',
                              data: query.to_j
                             )
      return JSON.parse(response)
    end
  end
end

# Call the test plugin to get a list of rmethods
def test_rpc_echo
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
                 url: '/rpc'
               )
    return if r.nil?

    puts 'test_rpc_echo: RPC_Echo.echo call completed'
    puts r.class
    puts r
  rescue StandardError => e
    puts e.message
  end
end

# Call the test plugin to get a list of rmethods
def test_rpc_rmethods
  begin
    r = RPC.rpc( query: { 'method' => 'Test.get_rmethods',
                          'kwparams' => {
                            'select_on' => {},
                            'set' => {},
                            'result' => []
                          },
                          'id' => "#{Time.now.to_i}",
                          'version' => '1.1'
                        },
                 url: '/rpc'
               )
    return if r.nil?

    r['result']['rmethods'].sort.each do |the_class, the_rmethods|
      puts "#{the_class} #{the_rmethods}"
    end
    puts r['result']['messages']
  rescue StandardError => e
    puts "Exception: #{e.message}"
  end
end

puts 'echo test'
test_rpc_echo

puts
puts 'Registered rmethods'
test_rpc_rmethods
