require 'resourceful/response'
require 'resourceful/net_http_adapter'

module Resourceful

  class Request

    attr_accessor :method, :resource

    def initialize(http_method, resource)
      @method, @resource = http_method, resource
    end

    def make

      reponse = NetHttpAdapter.get(resource.uri)

      response = Resourceful::Response.new(response)

      response

    end

  end

end
