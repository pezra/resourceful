
module Resourceful

  # This exception used to indicate that the request did not succeed.
  # The HTTP response is included so that the appropriate actions can
  # be taken based on the details of that response
  class UnsuccessfulHttpRequestError < Exception
    attr_reader :http_response, :http_request
 
    # Initialize new error from the HTTP request and response attributes.
    def initialize(http_request, http_response)
      super("#{http_request.method} request to <#{http_request.uri}> failed with code #{http_response.code}")
      @http_request = http_request
      @http_response = http_response
    end
  end

  # Exception indicating that the server used a content coding scheme
  # that Resourceful is unable to handle.
  class UnsupportedContentCoding < Exception
  end

end
