# WIKK JSON RPC

Experimenting with using JSON RCP method calls, from web pages, using ruby plugins as the RPC method handlers.

## rpc.rbx

rpc.rbx is called via Apache2's mod-cgi

Apache2 config
```
<IfModule mod_alias.c>
  ScriptAlias "/ruby/" "/test/www/ruby/"
</IfModule>
<Directory "/test/www/ruby">
  AllowOverride None
  Options +ExecCGI +Indexes
  Require all granted
	AddHandler cgi-script cgi rbx
</Directory>
```

## Thin Rack version, via URL /rpc and Apache2 proxying

Is called using a thin server, running the test/rack_svr/thin_run.sh script.

Apache2 config has proxy modules added, and the config is
```
<Location "/rpc">
    ProxyPass "http://127.0.0.1:3223/"
    ProxyPassReverse "http://127.0.0.1:3223/"
</Location>
```

## rlib/rpc

The test setup has an rlib directory for libraries (which should get replaced with gems).

Within rlib, there is an rpc/ directory, which has the glue to take a JSON RPC request, and execute methods from the plugin classes defined in rlib/rpc/plugins.


## rlib/rpc/plugins

Plugins are included automatically, from this directory. A failed load, results in that plugin being excluded. With Apache2 mod-cgi, this directory is reloaded each RPC call.  With Apache2 proxying the calls to a Rack server (I am testing with thin), then the plugins only get reloaded when thin is restarted (which is much faster).

## Plugins

Plugin inherit from RPC, defined in _rpc.rb, which has a method creation method, called rmethod. Each rmethod is called by using the JSON RPC 'method' parameter, using a classname.rmethod-name convention. Rmethods are registered, so only these methods can be called remotely. Calling the other class methods will generate an error response.


## Example Echo plugin

This has no DB calls. It just sends back the message we send to it.  As a convention, I have been using the 'messages' field in responses, to return debugging information back to the caller.

```
# Return the message sent to us
class RPC_Echo < RPC
  # @param cgi [CGI] Either a real Ruby CGI class or a dummy one (see minimal_cgi.rb)
  # @param authenticated [Boolean] Tests is done before this class is instantiated
  def initialize(cgi, authenticated = false)
    super(cgi, authenticated)
    @requestor = @cgi.env['REMOTE_ADDR']
    @messages = ''
  end

  # rmethods are the RPC methods we call via JSON RPC
  rmethod :echo do |select_on: nil, set: nil, result: nil, **kwargs| # rubocop: disable Lint/UnusedBlockArgument # Want consistent params
    return response(address_string: @requestor, message_received: select_on['message'])
  end

  private def response(address_string:, message_received:, **_kwargs)
    return { 'remote_addr' => address_string,  # Send back the IP of the host making the request
             'response' => message_received,   # Send back the message we received
             'messages' => @messages           # We send back error messages here
            }
  end
end
```

## Remote calls are done via an Ajax POST of this JSON.
see: echo.html and echo_comms.js for code examples

* select_on: are in input parameters (mostly fields in the DB, but could also pass in other values to the rmethod)
* set: are parameters we intend to alter
* result: are parameters we want sent back to us

'select_on', 'set' and 'result' are experiments with dynamically creating SQL, based on the query. The idea was, that result filtering could be done by the database. That turns out to be a little ugly to work with, and it is much cleaner to maintain rmethods that have fixed SQL queries. It was easy to create dynamic queries, using sql_helpers.rb, but they could be difficult to decipher at a much later date. I now don't use 'result', and don't dynamically generate queries.

The dynamic code generation also has an argument vetting process, with arrays defining acceptable 'select_on', 'set' and 'result' parameters, for both authenticated and unauthenticated calls. I am stopping using these instance variables, in favour of simpler tests in each rmethod.


```
{ 'method': 'RPC_Echo.echo',
  'kwparams': {
    'select_on' => { 'message' => 'The quick brown fox jumped over the lazy dog' },
    'set' => {},
    'result' => []
  },
  'id' => 1236,
  'version' => '1.1'
}
```


## Normal response

* id: is the id we got sent
* version: is currently always 1.1
* timestamp: Time from the server, for this response (added for debugging)
* result: The ruby Hash the plugin returned, converted to JSON

```
{
  "id": 1236,
  "version": "1.1",
  "timestamp": "20230417T024828",
  "result": {
    "remote_addr": "127.0.0.1",
    "response": "The quick brown fox jumped over the lazy dog",
    "messages": ""
  }
}
```

## Error response (including a catchall rescue at the top level)

An error packet adds an 'error' field to the response, and doesn't include the 'result' field.

Example of calling a nonexistent rmethod
```
{
  "id": 1234,
  "version": "1.1",
  "error": {
    "code": -32601,
    "message": "No method (auth=true) 'RPC_Echo.no_method'"
  }
}
```

## Authentication

Authentication is currently done out of band, using cookies. These are tested, before the rmethod is called.  

## Cookies

An RPC plugin class is instantiated when the RPC server for each call to a class rmethod. The RPC Rack server will have been passed the environment, from which it creates a dummy CGI class, that is then used to pass the environment and cookies into the plugin class.  

The plugin class can alter the CGI @output_cookies, which will then be passed back to the caller as cookies in the  'Set-Cookie' header.  An example of this, is the test authenicate.rb plugin, that uses CGI::Session to maintain a pstore. This method was chosen, to maintain backward compatibility with my much older code base (ca. 2004), that used the ruby CGI class, with mod-ruby.
