#!/usr/local/bin/ruby
require 'cgi'
require 'json'
require 'wikk_web_auth'
require 'wikk_configuration'

RLIB = '/wikk/rlib'
require_relative "#{RLIB}/wikk_conf.rb"
require_relative "#{RLIB}/rpc/rpc.rb"

def extract_json
  if @cgi.params.length > 0
    @cgi.params.collect do |k, _v| # rubocop: disable Lint/UnreachableLoop # Should do this in a nicer way
      return JSON.parse(k)
    end
  end
  return {}
end

def authenticated
  begin
    WIKK::Web_Auth.authenticated?(@cgi)
  rescue Exception => _e # rubocop: disable Lint/RescueException # We need to return to the caller, and not just crash
    false
  end
end

def dev_response
  response = extract_json.to_s
  [ 200, { 'Content-Type' => 'application/json' }, [ response ]]
end

def prod_response
  begin
    response = RPC.rpc( authenticated: authenticated, query: extract_json )
    [ 200, { 'Content-Type' => 'application/json' }, [ response ]]
  rescue Exception => e # rubocop: disable Lint/RescueException # We need to return to the caller, and not just crash
    backtrace = e.backtrace[0].split(':')
    message = "MSG: (#{File.basename(backtrace[-3])} #{backtrace[-2]}): #{e.message.to_s.gsub(/'/, '\\\'')}".gsub(/\n/, ' ').gsub(/</, '&lt;').gsub(/>/, '&gt;')
    response = {}
    response[:error] = { code: -32000, message: "Method (auth=#{authenticated}) 'rescue': #{message}" }
    [ 500, { 'Content-Type' => 'application/json' }, [ response ]]
  end
end

def test_pattern
  response = "{ \"authenticated\": \"#{authenticated}\", \"a2\": \"#{WIKK::Web_Auth.authenticated?(@cgi)}\" }"
  [ 200, { 'Content-Type' => 'application/json' }, [ response ]]
end

@cgi = CGI.new('html5')

# rack_result = test_pattern
rack_result = prod_response

@cgi.out('type' => 'application/json') do
  rack_result[2][0]
end
