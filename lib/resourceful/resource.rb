require 'resourceful/request'

module Resourceful

  class Resource
    attr_reader :accessor, :uri

    def initialize(accessor, uri)
      @accessor, @uri = accessor, uri
    end

    def get
      request = Resourceful::Request.new(:get, self)
      response = request.make
    end

    def post(data)
      request = Resourceful::Request.new(:post, self, data)
      response = request.make
    end

    def put(data)
      request = Resourceful::Request.new(:put, self, data)
      response = request.make
    end

    def delete
      request = Resourceful::Request.new(:delete, self)
      response = request.make
    end

  end

end
