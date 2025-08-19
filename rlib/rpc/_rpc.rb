require_relative 'sql_helpers.rb'    # RPC SQL helper methods. Being deprecated
require_relative 'time_helpers.rb' # RPC time iterator method. Being deprecated

# Base class for plugins
class RPC
  include SQL_Helpers
  include Time_Helpers

  # Defined remote methods, needed across all instances
  @@rmethods = {} # rubocop:disable Style/ClassVars

  attr_reader :set_acl, :select_acl, :result_acl

  def initialize(cgi:, authenticated: false)
    @cgi = cgi
    @authenticated = authenticated
    @db_config = WIKK::Configuration.new(MYSQL_CONF)
  end

  def self.class_exists?(class_name)
    klass = Module.const_get(class_name)
    return klass.is_a?(Class)
  rescue NameError
    return false
  end

  # method is the name of the method being defined in this class, as an rpc method
  # args is a hash of the arguments to the method
  # block is the actual method being defined
  def self.rmethod(method, *args, **kwords, &block)
    raise "Missing Block for #{method}" if block.nil?

    define_method(method, *args, **kwords, &block)
    # Add the method to an Array of remote methods for the calling class.
    # the @@rmethods hash, being indexed with the class
    # The string passed to class_eval, is executed by the ruby parser, within the context of the class
    self.class_eval %(
      if @@rmethods[self] == nil
        @@rmethods[self] = [method]
      else
        @@rmethods[self] +=  [method]
      end
    ), __FILE__, __LINE__ - 6
  end

  # List of rpc methods. ala a class.method call
  # The remote methods are an Array in the @@rmethods Hash, which was indexed by the class
  def rmethods
    "#{self.class} => #{@@rmethods[self.class]}"
  end

  # Ask if there is a remote method defined for this class.
  # Arguments are strings, as that is what we would expect from the remote connection.
  # The remote methods are an Array in the @@rmethods Hash, which was indexed by the class
  def rmethod?(the_method) # Could vett the args as well?
    (methods = @@rmethods[self.class]) != nil && methods.include?(the_method.to_sym)
  end

  # Class level version of rmethod?
  # Ask if there is a remote method defined for the class.
  # Arguments are strings, as that is what we would expect from the remote connection.
  # The remote methods are an Array in the @@rmethods Hash, which was indexed by the class
  def self.rmethod?(the_class, the_method) # Could vett the args as well?
    (methods = @@rmethods[Kernel.const_get(the_class)]) != nil && methods.include?(the_method.to_sym)
  end

  # call an rpc method in the class, with the arguments specified
  def self.rsend(the_class, the_method, *the_args, **kwords)
    the_class.send(the_method, *the_args, **kwords)
  end

  # Runs the remote procedure call, as specified in json 1.1 packet (with kwparams)
  # Returns whatever the method returns, or a json error message describing the failure.
  # @param cgi [CGI] or fake CGI which responds to cgi.env[] and cgi.cookies[] and a few others. See Minimal_CGI Class.
  # @param query [Hash] the JSON query
  # @param authenticate [Boolean] Pre-call test shows we are/aren't authenticated.
  def self.rpc(cgi:, query:, authenticated: false )
    begin
      # json_rpc = query.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
      json_rpc = query.transform_keys(& :to_sym )
      response = {}
      response[:id] = json_rpc[:id] unless json_rpc[:id].nil? # Remember id (User transaction ID), as we will return it as is.
      # Determine the RPC version.
      if ! json_rpc[:version].nil?
        # json rpc 1.1 get "version: 1.1", parrot this back
        response[:version] = json_rpc[:version]
        version = 1.1
      elsif ! json_rpc[:jsonrpc].nil?
        # json rpc 2.0 "jsonrpc: 2.0", parrot this back
        response[:jsonrpc] = json_rpc[:jsonrpc]
        version = 2.0
      else
        # json rpc 1.0, don't get a version number.
        # Don't expect to see any V1.0s.
        version = 1.0
      end
      if ( method = json_rpc[:method] ).nil?
        response[:error] = { code: -32600, message: "No method (auth=#{authenticated})  '#{method}'" }
      else  # Using json 1.1 standard for packet (with the kwparams option)
        the_class, the_method = method.split('.') # All methods are specified as class.method
        if RPC.class_exists?(the_class)
          if the_method != nil && RPC.rmethod?(the_class, the_method) # Only allow Remote methods to be called.
            begin
              args = []
              case version
              when 1.0 # Original standard
                # Only get positional arguments in 1.0
                a = json_rpc[:params]
                args += a unless a.nil?
                kwargs = {}
              when 1.1 # Transitional standard.
                # Could get positional and named args, but most likey just named
                a = json_rpc[:params]
                args += a unless a.nil?
                kwargs = json_rpc[:kwparams].nil? ? {} : json_rpc[:kwparams]
              when 2.0
                # Only expect named arguments in 2.0, and in the params field.
                kwargs = json_rpc[:params].nil? ? {} : json_rpc[:params]
              end
              kwargs.transform_keys!(& :to_sym )
              response[:result] = RPC.rsend(Kernel.const_get(the_class).new(cgi: cgi, authenticated: authenticated), the_method.to_sym, *args, **kwargs)
            rescue Exception => e # rubocop:disable Lint/RescueException -- (don't want this to fail, for any reason)
              backtrace = e.backtrace[0].split(':')
              message = "MSG: (#{File.basename(backtrace[-3])} #{backtrace[-2]} #{backtrace[-1]}): #{e.message.to_s.gsub('\'', '\\\'')}".gsub("\n", ' ').gsub('<', '&lt;').gsub('>', '&gt;')
              response[:error] = { code: -32000, message: "Method #{the_method} (auth=#{authenticated}) RPC: '#{method}': #{message} " }
            end
          else
            response[:error] = { code: -32601, message: "No method (auth=#{authenticated}) '#{method}'" }
          end
        else
          response[:error] = { code: -32602, message: "No Class (auth=#{authenticated}) '#{method}'" }
        end
      end
    rescue Exception => e # rubocop:disable Lint/RescueException -- (don't want this to fail, for any reason)
      backtrace = e.backtrace[0].split(':')
      message = "MSG: (#{File.basename(backtrace[-3])} #{backtrace[-2]}): #{e.message.to_s.gsub('\'', '\\\'')}".gsub("\n", ' ').gsub('<', '&lt;').gsub('>', '&gt;')
      response[:error] = { code: -32000, message: "Method (auth=#{authenticated}) '#{method}': #{message}" }
    end
    return response.to_j
  end
end
