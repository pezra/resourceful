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
      request = Resourceful::Request.new(:get, self)
      response = request.make

      if response.code == 301
        if @on_redirect.nil? or @on_redirect.call(request, response)
          @uris.unshift response.header['Location'].first
          request = Resourceful::Request.new(:get, self)
          response = request.make
        end
      end

      response
    end

    def post(data = "")
      request = Resourceful::Request.new(:post, self, data)
      response = request.make

      if response.code == 301
        if @on_redirect and @on_redirect.call(request, response)
          @uris.unshift response.header['Location'].first
          request = Resourceful::Request.new(:post, self)
          response = request.make
        end
      end

      response
    end

    def put(data = "")
      request = Resourceful::Request.new(:put, self, data)
      response = request.make

      if response.code == 301
        if @on_redirect and @on_redirect.call(request, response)
          @uris.unshift response.header['Location'].first
          request = Resourceful::Request.new(:put, self)
          response = request.make
        end
      end

      response
    end

    def delete
      request = Resourceful::Request.new(:delete, self)
      response = request.make

      if response.code == 301
        if @on_redirect and @on_redirect.call(request, response)
          @uris.unshift response.header['Location'].first
          request = Resourceful::Request.new(:delete, self)
          response = request.make
        end
      end

      response
    end

  end

end
