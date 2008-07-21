require 'pathname'
require Pathname(__FILE__).dirname + 'request'

module Resourceful

  # This exception used to indicate that the request did not succeed.
  # The HTTP response is included so that the appropriate actions can
  # be taken based on the details of that response
  class UnsuccessfulHttpRequestError < Exception
    attr_reader :http_response, :http_request
 
    # Initialize new error from the HTTP request and response attributes.
    #--
    # @private
    def initialize(http_request, http_response)
      super("#{http_request.method} request to <#{http_request.uri}> failed with code #{http_response.code}")
      @http_request = http_request
      @http_response = http_response
    end
  end

  class Resource
    attr_reader :accessor

    # Build a new resource for a uri
    #
    # @param accessor<HttpAccessor> 
    #   The parent http accessor
    # @param uri<String, Addressable::URI> 
    #   The uri for the location of the resource
    def initialize(accessor, uri)
      @accessor, @uris = accessor, [uri]
      @on_redirect = nil
    end

    # The uri used to identify this resource. This is almost always the uri
    # used to create the resource, but in the case of a permanent redirect, this
    # will always reflect the lastest uri.
    #
    # @return Addressable::URI 
    #   The current uri of the resource
    def effective_uri
      @uris.first
    end
    alias uri effective_uri

    # When performing a redirect, this callback will be executed first. If the callback
    # returns true, then the redirect is followed, otherwise it is not. The request that
    # triggered the redirect and the response will be passed into the block. This can be
    # used to update any links on the client side.
    #
    # Example:
    #
    #   author_resource.on_redirect do |req, resp|
    #     post.author_uri = resp.header['Location']
    #   end
    #
    # @yieldparam callback<request, response>
    #   The action to be executed when a request results in a redirect. Yields the 
    #   current request and result objects to the callback.
    #
    # @raise ArgumentError if called without a block 
    def on_redirect(&callback)
      if block_given?
        @on_redirect = callback
      else
        @on_redirect
      end
    end

    # Performs a GET on the resource, following redirects as neccessary, and retriving
    # it from the local cache if its available and valid.
    #
    # @return [Response] The Response to the final request made.
    #
    # @raise [UnsuccessfulHttpRequestError] unless the request is a
    #   success, ie the final request returned a 2xx response code
    def get(header = {})
      do_read_request(:get, header)
    end

    # :call-seq:
    #   post(data = "", :content_type => mime_type)
    #
    # Performs a POST with the given data to the resource, following redirects as 
    # neccessary.
    #
    # @param [String] data
    #   The body of the data to be posted
    # @param [Hash] options
    #   Options to pass into the request header. At the least, :content_type is required.
    #
    # @return [Response]  The Response to the final request that was made.
    #
    # @raise [ArgumentError] unless :content-type is specified in options
    # @raise [UnsuccessfulHttpRequestError] unless the request is a
    #   success, ie the final request returned a 2xx response code
    def post(data = "", options = {})
      raise ArgumentError, ":content_type must be specified" unless options.has_key?(:content_type)

      do_write_request(:post, data, {'Content-Type' => options[:content_type]})
    end

    # :call-seq:
    #   put(data = "", :content_type => mime_type)
    #
    # Performs a PUT with the given data to the resource, following redirects as 
    # neccessary.
    #
    # @param [String] data
    #   The body of the data to be posted
    # @param [Hash] options
    #   Options to pass into the request header. At the least, :content_type is required.
    #
    # @return [Response] The response to the final request made.
    #
    # @raise [ArgumentError] unless :content-type is specified in options
    # @raise [UnsuccessfulHttpRequestError] unless the request is a
    #   success, ie the final request returned a 2xx response code
    def put(data = "", options = {})
      raise ArgumentError, ":content_type must be specified" unless options.has_key?(:content_type)

      do_write_request(:put, data, {'Content-Type' => options[:content_type]})
    end

    # Performs a DELETE on the resource, following redirects as neccessary.
    #
    # @return <Response>
    #
    # @raise [UnsuccessfulHttpRequestError] unless the request is a
    #   success, ie the final request returned a 2xx response code
    def delete
      do_write_request(:delete, {}, nil)
    end

    # Performs a read request (HEAD, GET). Users should use the #get, etc methods instead.
    #
    # This method handles all the work of following redirects.
    #
    # @param method<Symbol> The method to perform
    #
    # @return <Response>
    #
    # @raise [UnsuccessfulHttpRequestError] unless the request is a
    #   success, ie the final request returned a 2xx response code
    #
    # --
    # @private
    def do_read_request(method, header = {})
      response = nil
      log_with_time "GET [#{uri}]" do
      request = Resourceful::Request.new(method, self, nil, header)
      accessor.auth_manager.add_credentials(request)

      response = request.response

      if response.is_redirect? and request.should_be_redirected?
        if response.is_permanent_redirect?
          @uris.unshift response.header['Location'].first
          response = do_read_request(method, header)
        else
          redirected_resource = Resourceful::Resource.new(self.accessor, response.header['Location'].first)
          response = redirected_resource.do_read_request(method, header)
        end
      end

      if response.is_not_authorized? && !@already_tried_with_auth
        @already_tried_with_auth = true
        accessor.auth_manager.associate_auth_info(response)
        response = do_read_request(method, header)
      end

      raise UnsuccessfulHttpRequestError.new(request,response) unless response.is_success?

      end
      return response
    end

    # Performs a write request (POST, PUT, DELETE). Users should use the #post, etc 
    # methods instead.
    #
    # This method handles all the work of following redirects.
    #
    # @param [Symbol] method  The method to perform
    # @param [String] data    Body of the http request.
    # @param [Hash]   header  Header for the HTTP resquest.
    #
    # @return [Response]
    #
    # @raise [UnsuccessfulHttpRequestError] unless the request is a
    #   success, ie the final request returned a 2xx response code
    # --
    # @private
    def do_write_request(method, data = nil, header = {})
      request = Resourceful::Request.new(method, self, data, header)
      accessor.auth_manager.add_credentials(request)

      response = request.response
      
      if response.is_redirect? and request.should_be_redirected?
        if response.is_permanent_redirect?
          @uris.unshift response.header['Location'].first
          response = do_write_request(method, data, header)
        elsif response.code == 303 # see other, must use GET for new location
          redirected_resource = Resourceful::Resource.new(self.accessor, response.header['Location'].first)
          response = redirected_resource.do_read_request(:get, header)
        else
          redirected_resource = Resourceful::Resource.new(self.accessor, response.header['Location'].first)
          response = redirected_resource.do_write_request(method, data, header)
        end
      end

      if response.is_not_authorized? && !@already_tried_with_auth
        @already_tried_with_auth = true
        accessor.auth_manager.associate_auth_info(response)
        response = do_write_request(method, data, header)
      end

      raise UnsuccessfulHttpRequestError.new(request,response) unless response.is_success?
      return response
    end

    def log_with_time(msg, indent = 2)
      logger.info(" " * indent + msg)
      result = nil
      time = Benchmark.measure { result = yield }
      logger.info(" " * indent + "-> %.4fs" % time.real)
      result
    end

    def logger
      accessor.logger
    end

  end

end
