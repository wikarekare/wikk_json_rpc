#!/usr/local/bin/ruby
require 'json'
require '/wikk/rlib/wikk_conf.rb'
require 'wikk_json'
require 'wikk_webbrowser'

# Set up to call the webserver via the loopback
class RPC
  def initialize(url:, identity: nil, auth: nil)
    @cookies = []
    @url = url
    @identity = identity
    @auth = auth
  end

  def self.rpc(url:, query:, identity: nil, auth: nil) # rubocop:disable Lint/UnusedMethodArgument Want the args to match initialize
    WIKK::WebBrowser.http_session(host: '127.0.0.1') do |ws|
      response = ws.post_page(query: url,
                              content_type: 'application/json',
                              data: query.to_j
                             )
      return JSON.parse(response)
    end
  end
end

# Call the test plugin to get a list of rmethods
def rmethods
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
                 url: '/ruby/rpc.rbx'
               )
    return if r.nil?

    r['result']['rmethods'].sort.each do |the_class, the_rmethods|
      puts "#{the_class} #{the_rmethods}"
    end
    puts r['result']['messages']
  rescue StandardError => e
    puts e.message
  end
end

rmethods
