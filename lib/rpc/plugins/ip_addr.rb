# Return calling IP address, as a simple test
class IP_Addr < RPC
  def initialize(authenticated = false)
    super(authenticated)
    @requestor = ENV['REMOTE_ADDR']
    @messages = ''
  end

  # rmethods are the RPC methods we call via the JSON RPC
  rmethod :ip_addr do |select_on: nil, set: nil, result: nil, **_kwargs| # rubocop: disable Lint/UnusedBlockArgument # Want consistent params
    return response(address_string: @requestor)
  end

  private def response(address_string:, **_kwargs)
    return { 'remote_addr' => address_string,
             'messages' => @messages
            }
  end
end
