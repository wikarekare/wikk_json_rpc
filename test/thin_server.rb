#!/usr/local/bin/ruby
require 'thin'
require 'rack'
require 'cgi'
require 'json'
require 'wikk_web_auth'
require 'wikk_configuration'

RLIB = '/wikk/rlib' unless defined? RLIB
require_relative "#{RLIB}/wikk_conf.rb"
require_relative "#{RLIB}/rpc/rpc.rb"

# Handle web queries, using thin an rack.
# Class needs a call() method for Thin.
class Responder
  # Init the Responder class
  def initialize(debug: false)
    @response = 'the quick brown fox<br>' # Test string response.
    @debug = debug
    @message = nil # We set this, if there was an exception, pre calling the rmethod.
  end

  # thin calls this for each web query.
  def call(env)
    @env = env
    @req = Rack::Request.new(env)
    @the_body = @req.body.read     # We will want the json, and can't read this twice (debug and extract)

    dump_html if @debug

    if @message.nil?
      # simple_test_pattern
      # test_pattern
      # dev_response
      return prod_response
    else
      # There was an error
      return [ 500, { 'Content-Type' => 'application/json' }, [ @message.to_j ]]
    end
  end

  # Turn json in query body into a Hash. We expect it to be json
  private def extract_json
    raise "Content type needs to be JSON (Got #{@env}['CONTENT_TYPE'])" if @env['CONTENT_TYPE'] != 'application/json'

    return @the_body.nil? || @the_body.empty? ? {} : JSON.parse(@the_body)
  end

  # Are we authenticated?
  private def authenticated?
    begin
      return false if @cgi.nil?

      return WIKK::Web_Auth.authenticated?(@cgi)
    rescue Exception => _e # rubocop: disable Lint/RescueException # We need to return to the caller, and not just crash
      return false
    end
  end

  # Response if we are in dev environment
  # Send back what we were sent
  private def dev_response
    response = extract_json.to_s
    return [ 200, { 'Content-Type' => 'application/json' }, [ response ]]
  end

  # Dev response, showing our authentication state in the response.
  private def test_pattern
    begin
      logged_in = authenticated?
    rescue Exception => e # rubocop: disable Lint/RescueException # We need to return to the caller, and not just crash
      @message = "test_pattern: Auth test: #{e}"
    end
    response = "{ \"authenticated\": \"#{logged_in}\", \"a2\": \"#{logged_in}\", \"message\": \"#{@message}\" }"
    return [ 200, { 'Content-Type' => 'application/json' }, [ response ]]
  end

  # Simple dev response. Just respond with any error message set by an exception.
  private def simple_test_pattern
    response = "{ \"message\": \"#{@message}\" }"
    return [ 200, { 'Content-Type' => 'application/json' }, [ response ]]
  end

  # Response if we are running in production.
  # i.e. Make the actual rpc calls, by running the rmethods in the appropriate plugin
  def prod_response
    begin
      rpc_json = extract_json
      puts rpc_json if @debug
      response = RPC.rpc( authenticated: authenticated?, query: rpc_json )
      return [ 200, { 'Content-Type' => 'application/json' }, [ response ]]
    rescue Exception => e # rubocop: disable Lint/RescueException # We need to return to the caller, and not just crash
      backtrace = e.backtrace[0].split(':')
      @message = "MSG: (#{File.basename(backtrace[-3])} #{backtrace[-2]}): #{e.message.to_s.gsub(/'/, '\\\'')}".gsub(/\n/, ' ').gsub(/</, '&lt;').gsub(/>/, '&gt;')
      response = { code: -32000,
                   response: @message,
                   message: "Method: (auth=#{authenticated?})"
      }.to_j

      return [ 200, { 'Content-Type' => 'application/json' }, [ response ]]
    end
  end

  private def dump_html
    puts '**********************************************************************'
    puts "script_name #{@req.script_name}"
    puts "request_method #{@req.request_method}"
    puts "Query String #{@req.query_string}"
    puts "content_type #{@req.content_type}"
    puts
    params = @req.params
    puts "req.params=#{params}"
    rack_input_str = @env['rack.input'].read
    puts "rack_input = #{rack_input_str}"
    # rack_errors_str = @env['rack.errors'].read
    # puts "rack_errors = #{rack_errors_str}"
    post_data = ''
    @env.each do |k, v|
      post_data += "#{k}=>#{v}\n"
    end
    puts 'Env:'
    puts post_data
    puts "Body\n"
    puts @the_body
  end
end

rack_app = Responder.new(debug: true)

# Listen on the loopback address.
Rack::Handler::Thin.run rack_app, Host: '127.0.0.1', Port: 3223
