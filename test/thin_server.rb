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

# Handle web queries, using thin and rack.
# We can put this behind Apache2 or nginx, using proxy/rev-proxy directives.
# The advantage is, that this process doesn't need to run as Apache, so can have a different Apparmor profile.
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
      # We could be behind a forwarding proxy server, so we will not see the ENV that we need to.
      ENV['REMOTE_ADDR'] = @env['HTTP_X_FORWARDED_FOR'].nil? ? @env['REMOTE_ADDR'] : @env['HTTP_X_FORWARDED_FOR']
      # Might be using REST methodology, where the REQUEST_METHOD alters behaviour
      ENV['REQUEST_METHOD'] = @env['REQUEST_METHOD']
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
    raise "Content type needs to be JSON (Got #{@env['CONTENT_TYPE']})" if @env['CONTENT_TYPE'] !~ /application\/json/

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

      headers = {
        'Content-Type' => 'application/json',
        'Set-Cookie' => [ 'foo=bar', 'bar=foo' ]
      }

      return [ 200, headers, [ response ]]
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
    puts "script_name: #{@req.script_name}"
    puts "request_method: #{@req.request_method}"
    puts "Query String: #{@req.query_string}"
    puts "content_type: #{@req.content_type}"
    puts
    puts "req.params = #{@req.params}"
    rack_input_str = @env['rack.input'].read
    puts "rack_input = #{rack_input_str}"
    # rack_errors_str = @env['rack.errors'].read
    # puts "rack_errors = #{rack_errors_str}"
    puts "\nEnv:"
    @env.each do |k, v|
      puts "  #{k} = #{v}"
    end
    puts "\nBody:"
    puts @the_body
  end
end

rack_app = Responder.new(debug: true)

PORT = 3223 # Might shift this to a config file or an argument
# Listen on the loopback address.
Rack::Handler::Thin.run rack_app, Host: '127.0.0.1', Port: PORT
