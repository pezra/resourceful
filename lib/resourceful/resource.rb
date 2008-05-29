require 'resourceful/request'

module Resourceful

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
    # @block callback<request, response>
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
    # @returns <Response>
    def get
      do_read_request(:get)
    end

    # Performs a POST with the given data to the resource, following redirects as 
    # neccessary.
    #
    # @params data<String> 
    #   The body of the data to be posted
    #
    # @returns <Response>
    def post(data = "")
      do_write_request(:post, data)
    end

    # Performs a POST with the given data to the resource, following redirects as 
    # neccessary.
    #
    # @params data<String> 
    #   The body of the data to be posted
    #
    # @returns <Response>
    def put(data = "")
      do_write_request(:put, data)
    end

    # Performs a DELETE on the resource, following redirects as neccessary.
    #
    # @returns <Response>
    def delete
      do_write_request(:delete)
    end

    # Performs a read request (HEAD, GET). Users should use the #get, etc methods instead.
    #
    # This method handles all the work of following redirects.
    #
    # @param method<Symbol> The method to perform
    #
    # @return <Response>
    # --
    # @private
    def do_read_request(method)
      request = Resourceful::Request.new(method, self)
      response = request.response

      if response.is_redirect? and request.should_be_redirected?
        if response.is_permanent_redirect?
          @uris.unshift response.header['Location'].first
          response = do_read_request(method)
        else
          redirected_resource = Resourceful::Resource.new(self.accessor, response.header['Location'].first)
          response = redirected_resource.do_read_request(method)
        end
      end

      return response
    end

    # Performs a write request (POST, PUT, DELETE). Users should use the #post, etc 
    # methods instead.
    #
    # This method handles all the work of following redirects.
    #
    # @param method<Symbol> The method to perform
    #
    # @return <Response>
    # --
    # @private
    def do_write_request(method, data = nil)
      request = Resourceful::Request.new(method, self, data)
      response = request.response
      
      if response.is_redirect? and request.should_be_redirected?
        if response.is_permanent_redirect?
          @uris.unshift response.header['Location'].first
          response = do_write_request(method)
        elsif response.code == 303 # see other, must use GET for new location
          redirected_resource = Resourceful::Resource.new(self.accessor, response.header['Location'].first)
          response = redirected_resource.do_read_request(:get)
        else
          redirected_resource = Resourceful::Resource.new(self.accessor, response.header['Location'].first)
          response = redirected_resource.do_write_request(method, data)
        end
      end

      return response
    end

  end

end
