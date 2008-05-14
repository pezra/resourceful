require 'resourceful/response'
require 'resourceful/net_http_adapter'

module Resourceful

  class Request

    REDIRECTABLE_METHODS = [:get, :head]

    attr_accessor :method, :resource, :body, :header

    def initialize(http_method, resource, body = nil, header = nil)
      @method, @resource, @body = http_method, resource, body
      @header = header.is_a?(Resourceful::Header) ? header : Resourceful::Header.new(header || {})

    end

    def response
      cached_response = resource.accessor.cache_manager.lookup(self)
      return cached_response if cached_response and not cached_response.dirty?

      set_validation_headers(cached_response) if cached_response and cached_response.dirty?

      http_resp = NetHttpAdapter.make_request(@method, @resource.uri, @body, @header)
      response = Resourceful::Response.new(*http_resp)

      if response.code == 304
        cached_response.header.merge(response.header)
        response = cached_response
      end

      resource.accessor.cache_manager.store(response)

      response
    end

    def should_be_redirected?
      if resource.on_redirect.nil?
        return true if method.in? REDIRECTABLE_METHODS
        false
      else
        resource.on_redirect.call(self, response)
      end
    end

    def set_validation_headers(response)
      @header['If-None-Match'] = response.header['ETag'] if response.header.has_key?('ETag')
      @header['If-Modified-Since'] = response.header['Last-Modified'] if response.header.has_key?('Last-Modified')
    end

  end

end
