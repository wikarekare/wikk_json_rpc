module WIKK
  # Stripped down CGI class, with just the cookies and environment
  class Minimal_CGI
    attr_accessor :cookies
    attr_accessor :output_cookies
    attr_accessor :remote_addr
    attr_accessor :env

    def initialize(env:)
      @env = env.nil? ? {} : env
      @cookies = {}
      @remote_addr = @env['HTTP_X_FORWARDED_FOR'].nil? ? @env['REMOTE_ADDR'] : @env['HTTP_X_FORWARDED_FOR']
      @env['REMOTE_ADDR'] = @remote_addr

      cookie_string = env['HTTP_COOKIE']
      unless cookie_string.nil?
        @key_values = cookie_string.split(';')
        @key_values.each do |kv|
          t = kv.strip.split('=', 2) # Split on first =
          @cookies[t[0]] = t[1] unless t.nil? || t.length != 2
        end
      end
      @output_cookies = []  # We get this back from CGI::Session
      @output_hidden = {}   # We get this back from CGI::Session, which we ignore
    end

    # return the cgi form parameters
    # We aren't passing cgi parameters, so this will always be nil
    def [](_the_key)
      nil
    end

    # Look to see if we have a cgi form parameter for this key
    # We aren't passing cgi parameters, so this will always be false
    def key?(_the_key)
      false
    end

    # Convert each cookie to a string, and return the resulting array
    def cookies_to_a
      @output_cookies.map(& :to_s)
    end
  end
end
