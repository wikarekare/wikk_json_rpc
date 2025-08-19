# Return message sent to us
class Symbol
  def to_j
    self.to_s.to_j
  end
end

# Respond with a list of rmethod calls
class Test < RPC
  def initialize(cgi:, authenticated: false)
    super
    @requestor = @cgi.env['REMOTE_ADDR']
    @messages = ''
  end

  # rmethods are the RPC methods we call via the JSON RPC
  rmethod :get_rmethods do |select_on: nil, set: nil, result: nil, **kwargs| # rubocop: disable Lint/UnusedBlockArgument
    return response(rmethods: @@rmethods)
  end

  private def response(rmethods:)
    return { 'rmethods' => rmethods,
             'messages' => @messages
            }
  end
end
