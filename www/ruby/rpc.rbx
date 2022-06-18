#!/usr/local/bin/ruby
@message = nil
RLIB = '/wikk/rlib'

# Having issues with gems not loading, so catching the error for logging
[ 'cgi', 'json', 'wikk_web_auth', 'wikk_configuration' ].each do |f|
  begin
    require f
  rescue Exception => e # rubocop: disable Lint/RescueException # We need to return to the caller, and not just crash
    @message = "#{f}: #{e}"
  end
end
[ "#{RLIB}/wikk_conf.rb", "#{RLIB}/rpc/rpc.rb" ].each do |f|
  begin
    require_relative f
  rescue Exception => e # rubocop: disable Lint/RescueException # We need to return to the caller, and not just crash
    @message = "#{f}: #{e}"
  end
end

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
    return WIKK::Web_Auth.authenticated?(@cgi)
  rescue Exception => _e # rubocop: disable Lint/RescueException # We need to return to the caller, and not just crash
    return false
  end
end

def dev_response
  response = extract_json.to_s
  return [ 200, { 'Content-Type' => 'application/json' }, [ response ]]
end

def prod_response
  begin
    response = RPC.rpc( authenticated: authenticated, query: extract_json )
    return [ 200, { 'Content-Type' => 'application/json' }, [ response ]]
  rescue Exception => e # rubocop: disable Lint/RescueException # We need to return to the caller, and not just crash
    backtrace = e.backtrace[0].split(':')
    @message = "MSG: (#{File.basename(backtrace[-3])} #{backtrace[-2]}): #{e.message.to_s.gsub(/'/, '\\\'')}".gsub(/\n/, ' ').gsub(/</, '&lt;').gsub(/>/, '&gt;')
    response = { code: -32000,
                 response: @message,
                 message: "Method: (auth=#{authenticated})"
    }.to_j

    return [ 200, { 'Content-Type' => 'application/json' }, [ response ]]
  end
end

def test_pattern
  begin
    logged_in = WIKK::Web_Auth.authenticated?(@cgi)
  rescue Exception => e # rubocop: disable Lint/RescueException # We need to return to the caller, and not just crash
    @message = "test_pattern: Auth test: #{e}"
  end
  response = "{ \"authenticated\": \"#{authenticated}\", \"a2\": \"#{logged_in}\", \"message\": \"#{@message}\" }"
  return [ 200, { 'Content-Type' => 'application/json' }, [ response ]]
end

def simple_test_pattern
  response = "{ \"message\": \"#{@message}\" }"
  return [ 200, { 'Content-Type' => 'application/json' }, [ response ]]
end

@cgi = CGI.new('html5')

rack_result = if @message.nil?
                # rack_result = simple_test_pattern
                # rack_result = test_pattern
                # rack_result = dev_response
                prod_response
              else
                # There was an error
                [ 500, { 'Content-Type' => 'application/json' }, [ @message.to_j ]]
              end

@cgi.out('type' => 'application/json') do
  rack_result[2][0]
end
