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

  end

end
