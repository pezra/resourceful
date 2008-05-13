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
      request = Resourceful::Request.new(:post, self, data)
      response = request.response

      if response.code == 301
        if @on_redirect and @on_redirect.call(request, response)
          @uris.unshift response.header['Location'].first
          request = Resourceful::Request.new(:post, self)
          response = request.response
        end
      end
      if response.code == 302
        if @on_redirect and @on_redirect.call(request, response)
          @uris.unshift response.header['Location'].first
          request = Resourceful::Request.new(:get, self)
          response = request.response
          @uris.shift # don't remember this new location
        end
      end

      response
    end

    def put(data = "")
      request = Resourceful::Request.new(:put, self, data)
      response = request.response

      if response.code == 301
        if @on_redirect and @on_redirect.call(request, response)
          @uris.unshift response.header['Location'].first
          request = Resourceful::Request.new(:put, self)
          response = request.response
        end
      end
      if response.code == 302
        if @on_redirect and @on_redirect.call(request, response)
          @uris.unshift response.header['Location'].first
          request = Resourceful::Request.new(:get, self)
          response = request.response
          @uris.shift # don't remember this new location
        end
      end

      response
    end

    def delete
      request = Resourceful::Request.new(:delete, self)
      response = request.response

      if response.code == 301
        if @on_redirect and @on_redirect.call(request, response)
          @uris.unshift response.header['Location'].first
          request = Resourceful::Request.new(:delete, self)
          response = request.response
        end
      end
      if response.code == 302
        if @on_redirect and @on_redirect.call(request, response)
          @uris.unshift response.header['Location'].first
          request = Resourceful::Request.new(:get, self)
          response = request.response
          @uris.shift # don't remember this new location
        end
      end

      response
    end

    protected 

    def do_read_request(method)
      request = Resourceful::Request.new(:get, self)
      response = request.response

      if response.is_redirect? and request.should_be_redirected?
        previous_response = response
        @uris.unshift response.header['Location'].first
        request = Resourceful::Request.new(:delete, self)
        response = request.response
        @uris.shift unless previous_response.code == 301
      end

      response

    end

    def do_write_request(method, data)
      
    end

  end

end
