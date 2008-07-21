require 'pathname'
require 'benchmark'
require Pathname(__FILE__).dirname + 'response'
require Pathname(__FILE__).dirname + 'net_http_adapter'

module Resourceful

  class Request

    REDIRECTABLE_METHODS = [:get, :head]

    attr_accessor :method, :resource, :body, :header
    attr_reader   :request_time

    def initialize(http_method, resource, body = nil, header = nil)
      @method, @resource, @body = http_method, resource, body
      @header = header.is_a?(Resourceful::Header) ? header : Resourceful::Header.new(header || {})

      @header['Accept-Encoding'] = 'gzip, identity'
    end

    def response
      @request_time = Time.now

      cached_response = resource.accessor.cache_manager.lookup(self)
      if cached_response
        logger.debug("    Found in cache")
        if cached_response.stale?
          logger.info("    Revalidation needed")
          set_validation_headers(cached_response)
        else
          logger.info("    Retrieved fresh from cache #{"%.4fs" % (Time.now - @request_time)}")
          return cached_response
        end
      end

      logger.debug("    Requesting from server...")
      response = nil
      time = Benchmark.measure do
        http_resp = NetHttpAdapter.make_request(@method, @resource.uri, @body, @header)
        response = Resourceful::Response.new(uri, *http_resp)
      end
      logger.debug("    Request took %.4fs" % time.real)


      if response.code == 304
        cached_response.header.merge(response.header)
        response = cached_response
      end

      resource.accessor.cache_manager.store(self, response) unless response.was_unsuccessful?

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
    
    def logger
      resource.accessor.logger
    end

  end

end
