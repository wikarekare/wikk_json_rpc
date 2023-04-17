# Return message sent to us
class RPC_Echo < RPC
  def initialize(cgi, authenticated = false)
    super(cgi, authenticated)
    @requestor = @cgi.env['REMOTE_ADDR']
    @messages = ''
  end

  # rmethods are the RPC methods we call via the JSON RPC
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
