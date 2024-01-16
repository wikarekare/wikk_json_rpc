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
require_relative "#{RLIB}/rpc/minimal_cgi.rb"

# Handle web queries, using thin and rack.
# We can put this behind Apache2 or nginx, using proxy/rev-proxy directives.
# The advantage is, that this process doesn't need to run as Apache, so can have a different Apparmor profile.
# Class needs a call() method for Thin.
class Wikk_Rack
  # Init the Responder class
  def initialize(debug: false)
    @pstore_conf = JSON.parse(File.read(PSTORE_CONF))
    @debug = debug
    @message = nil # We set this, if there was an exception, pre calling the rmethod.
  end

  # thin calls this for each web query.
  # @param env [HASH] a Rack env object (the html request)
  def call(env)
    @env = env
    @req = Rack::Request.new(env)
    @the_body = @req.body.read     # We will want the json, and can't read this twice (debug and extract)
    @cgi = WIKK::Minimal_CGI.new(env: env)

    dump_html if @debug

    if @message.nil?
      # We could be behind a forwarding proxy server, so we will not see the ENV that we need to.
      # simple_test_pattern
      # test_pattern
      # dev_response
      return prod_response
    else
      # There was an error
      return [ 500, { 'Content-Type' => 'application/json' }, [ @message.to_j ]]
    end
  end

  # For our testing, we want CGI::Session and Rack to work together
  # CGI::Session takes a cgi instance argument, and injects an @output_cookies[CGI::Cookies] array
  # There are calls to cgi.key?(session_key), cgi[session_key] failing over to request.cookies[session_key]

  # Turn json in query body into a Hash. We expect it to be json
  private def extract_json
    raise "Content type needs to be JSON (Got #{@env['CONTENT_TYPE']})" if @env['CONTENT_TYPE'] !~ /application\/json/

    return @the_body.nil? || @the_body.empty? ? {} : JSON.parse(@the_body)
  end

  # Are we authenticated?
  # Done outside of the rpc calls
  private def authenticated?
    begin
      return false if @cgi.nil?

      return WIKK::Web_Auth.authenticated?(@cgi, pstore_config: @pstore_conf)
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
      response = RPC.rpc( cgi: @cgi, authenticated: authenticated?, query: rpc_json )

      headers = { 'Content-Type' => 'application/json' }

      # Cookies come back to us in env['HTTP_COOKIE'] as a string, and go back as 'Set-Cookie'
      # inject session cookies into the response ( @cgi update by authenticated?() )
      headers['Set-Cookie'] = @cgi.cookies_to_a unless @cgi.output_cookies.empty?

      # Nb. the response in in rack format.
      # i.e. a 3 element array [ return_code, html_headers, html_body ]
      #      html headers is a hash of html header value pairs
      #      The html body must respond to each, so we pass back an array.
      return [ 200, headers, [ response ]]
    rescue Exception => e # rubocop: disable Lint/RescueException # We need to return to the caller, and not just crash
      warn e.message
      backtrace = e.backtrace[0].split(':')
      warn backtrace
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
    puts "\nCookies IN"
    @cgi.cookies.each do |k, c|
      puts "#{k} => #{c}"
    end
    puts "\nCookies OUT"
    p @cgi.cookies_to_a
    puts "\nAuthenticated? #{authenticated?}"
    puts "\nEnv:"
    @env.each do |k, v|
      puts "  #{k} = #{v}"
    end
    puts "\nBody:"
    puts @the_body
  end
end

rack_app = Wikk_Rack.new(debug: true, pstore_config: PSTORE_CONF)

PORT = 3223 # Might shift this to a config file or an argument
# Listen on the loopback address.
Rack::Handler::Thin.run rack_app, Host: '127.0.0.1', Port: PORT
