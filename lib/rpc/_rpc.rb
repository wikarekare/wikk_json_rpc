# Base class for plugins
class RPC
  # Defined remote methods, needed across all instances
  @@rmethods = {} # rubocop:disable Style/ClassVars

  attr_reader :set_acl, :select_acl, :result_acl

  def initialize(authenticated = false)
    @authenticated = authenticated
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
  def self.rpc(query:, authenticated: false )
    begin
      # json_rpc = query.each_with_object({}) { |(k, v), h| h[k.to_sym] = v }
      json_rpc = query.transform_keys(& :to_sym )
      response = {}
      response[:id] = json_rpc[:id] unless json_rpc[:id].nil? # Remember id (User transaction ID), as we will return it as is.
      response[:version] = json_rpc[:version] unless json_rpc[:version].nil? # parrot this. Otherwise ignore it.
      if ( method = json_rpc[:method] ).nil?
        response[:error] = { code: -32600, message: "No method (auth=#{authenticated})  '#{method}'" }
      else  # Using json 1.1 standard for packet (with the kwparams option)
        the_class, the_method = method.split('.') # All methods are specified as class.method
        if RPC.class_exists?(the_class)
          if the_method != nil && RPC.rmethod?(the_class, the_method) # Only allow Remote methods to be called.
            begin
              args = []
              if (a = json_rpc[:params]) != nil; args += a; end   # Accept this form
              kwargs = json_rpc[:kwparams].nil? ? {} : json_rpc[:kwparams]
              response[:result] = RPC.rsend(Kernel.const_get(the_class).new(authenticated), the_method.to_sym, *args, **kwargs)
            rescue Exception => e # rubocop:disable Lint/RescueException (don't want this to fail, for any reason)
              backtrace = e.backtrace[0].split(':')
              message = "MSG: (#{File.basename(backtrace[-3])} #{backtrace[-2]} #{backtrace[-1]}): #{e.message.to_s.gsub(/'/, '\\\'')}".gsub(/\n/, ' ').gsub(/</, '&lt;').gsub(/>/, '&gt;')
              response[:error] = { code: -32000, message: "Method (auth=#{authenticated}) '#{method}': #{message} " }
            end
          else
            response[:error] = { code: -32601, message: "No method (auth=#{authenticated}) '#{method}'" }
          end
        else
          response[:error] = { code: -32602, message: "No Class (auth=#{authenticated}) '#{method}'" }
        end
      end
    rescue Exception => e # rubocop:disable Lint/RescueException (don't want this to fail, for any reason)
      backtrace = e.backtrace[0].split(':')
      message = "MSG: (#{File.basename(backtrace[-3])} #{backtrace[-2]}): #{e.message.to_s.gsub(/'/, '\\\'')}".gsub(/\n/, ' ').gsub(/</, '&lt;').gsub(/>/, '&gt;')
      response[:error] = { code: -32000, message: "Method (auth=#{authenticated}) '#{method}': #{message}" }
    end
    return response.to_j
  end
end
