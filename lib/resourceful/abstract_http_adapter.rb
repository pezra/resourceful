module Resourceful
  class AbstractHttpAdapter
    ResponseStruct = Struct.new(:status, :reason, :header, :body)

    # Make the specified request and return the parsed info from the response
    #
    # @param request 
    #   Information about the request to make.  This object will
    #   respond to #uri, #method, #header, #body.
    # @return [ResponseStruct]  
    #   The parse response from the server.
    def make_request(request)
      raise NotImplementedError
    end
  end
end
