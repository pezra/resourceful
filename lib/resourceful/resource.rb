require 'resourceful/request'

module Resourceful

  class Resource
    attr_reader :accessor

    def initialize(accessor, uri)
      @accessor, @uris = accessor, [uri]
      @on_redirect = nil
    end

    def effective_uri
      @uris.first
    end
    alias uri effective_uri

    def on_redirect(&block)
      if block_given?
        @on_redirect = block
      else
        @on_redirect
      end
    end

    def get
      do_read_request(:get)
    end

    def post(data = "")
      do_write_request(:post, data)
    end

    def put(data = "")
      do_write_request(:put, data)
    end

    def delete
      do_write_request(:delete)
    end

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
