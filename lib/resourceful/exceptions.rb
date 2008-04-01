module Resourceful
  class HttpRequestError < Exception
    attr_reader :response, :request
    
    def initialize(message, request, response)
      @response = response
      @request = request

      super(message)
    end

    def self.new_from(request, response, resource)
      msg = if request.method == 'GET'
              "#{resource.effective_uri} #{response.message} (#{response.code})"
            else
              "Received #{response.message} response to #{request.method} #{resource.effective_uri} (#{response.code})"
            end
      
      case response.code
      when /^3/
        HttpRedirectionError
      when /^4/
        HttpClientError
      when /^5/
        HttpServerError
      else
        HttpRequestError
      end.new(msg, request, response)
    end
  end
  
  class HttpClientError < HttpRequestError
  end
  
  class HttpServerError < HttpRequestError
  end

  class HttpRedirectionError < HttpRequestError
  end

  # Used to indicated that a request failed because the server(s)
  # instructed us to perform more than the maximum allowed number of
  # redirections.
  class TooManyRedirectsError < Exception
  end

  # Used to indicate the a redirection path has looped back on it self
  # in a way that following the redirections will never result in
  # never finding the actual resource.
  class CircularRedirectionError < Exception
  end
  
  # Used to indicate that no authentication credentials were found
  # realm in which the requested resource resides.
  class NoAuthenticationCredentialsError < Exception
  end
  
  # Raised to indicate that none of the authentication scheme proposed
  # by the server are supported.
  class UnsupportedAuthenticationSchemeError < Exception
  end
  
  # Used to indicate that no authentication realm information is
  # available for the resource in question
  class NoAuthenticationRealmInformationError < Exception
  end
end
