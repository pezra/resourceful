require 'resourceful/response'
require 'resourceful/net_http_adapter'

module Resourceful

  class Request

    REDIRECTABLE_METHODS = [:get, :head]

    attr_accessor :method, :resource, :body, :header
    attr_reader   :request_time

    def initialize(http_method, resource, body = nil, header = nil)
      @method, @resource, @body = http_method, resource, body
      @header = header.is_a?(Resourceful::Header) ? header : Resourceful::Header.new(header || {})

      @header['Accept-Encoding'] = 'gzip'
    end

    def response
      @request_time = Time.now

      cached_response = resource.accessor.cache_manager.lookup(self)
      return cached_response if cached_response and not cached_response.stale?

      set_validation_headers(cached_response) if cached_response and cached_response.stale?

      http_resp = NetHttpAdapter.make_request(@method, @resource.uri, @body, @header)
      response = Resourceful::Response.new(uri, *http_resp)

      if response.code == 304
        cached_response.header.merge(response.header)
        response = cached_response
      end

      resource.accessor.cache_manager.store(self, response)

      response.authoritative = true
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
      @header['Cache-Control'] = 'max-age=0' if response.header.has_key?('Cache-Control') and response.header['Cache-Control'].include?('must-revalidate')
    end

    def uri
      resource.uri
    end

  end

end
