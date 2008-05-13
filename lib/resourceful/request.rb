require 'resourceful/response'
require 'resourceful/net_http_adapter'

module Resourceful

  class Request

    REDIRECTABLE_METHODS = [:get, :head]

    attr_accessor :method, :resource, :body, :header

    def initialize(http_method, resource, body = nil, header = nil)
      @method, @resource, @body, @header = http_method, resource, body, header
      @response = nil
    end

    def response
      if @response.nil?
        http_resp = NetHttpAdapter.make_request(@method, @resource.uri, @body, @header)
        @response = Resourceful::Response.new(*http_resp)
      end

      @response
    end

    def should_be_redirected?
      if resource.on_redirect.nil?
        return true if method.in? REDIRECTABLE_METHODS
        false
      else
        resource.on_redirect.call(self, response)
      end
    end

  end

end
