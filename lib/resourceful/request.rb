require 'resourceful/response'
require 'resourceful/net_http_adapter'

module Resourceful

  class Request

    attr_accessor :method, :resource, :body, :header

    def initialize(http_method, resource, body = nil, header = nil)
      @method, @resource, @body, @header = http_method, resource, body, header
    end

    def make

      http_resp = NetHttpAdapter.make_request(@method, @resource.uri, @body, @header)
      response = Resourceful::Response.new(*http_resp)

      response

    end

  end

end
