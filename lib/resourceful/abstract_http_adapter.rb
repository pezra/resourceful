module Resourceful
  class AbstractHttpAdapter
    # Make the specified request and return the parsed info from the response
    #
    # @param [Resourceful::Request] request  The request to make.
    #
    # @return [Hash-ish]  The parse response from the server.  Hash should include the following keys:
    #   * `:status` [Integer]  status code of the response
    #   * `:reason` [String]   reason phrase from the server
    #   * `:header` [Hash-ish] header fields from server
    #   * `:body`   [String]   the body of the response
    def make_request(request)
      raise  NotImplementedError
    end
  end
end
