require 'pathname'
require 'benchmark'
require 'resourceful/response'
require 'resourceful/net_http_adapter'
require 'resourceful/exceptions'

module Resourceful

  class Request

    REDIRECTABLE_METHODS = [:get, :head]
    CACHEABLE_METHODS = [:get, :head]

    attr_accessor :method, :resource, :body, :header
    attr_reader   :request_time, :accessor

    # @param [Symbol] http_method
    #   :get, :put, :post, :delete or :head
    # @param [Resourceful::Resource] resource
    # @param [String] body
    # @param [Resourceful::Header, Hash] header
    def initialize(http_method, resource, body = nil, header = nil)
      @method, @resource, @body = http_method, resource, body
      @accessor = @resource.accessor
      @header = header.is_a?(Resourceful::Header) ? header : Resourceful::Header.new(header)

      # Resourceful handled gzip encoding transparently, so set that up
      @header.accept_encoding ||= 'gzip, identity'

      # 'Host' is a required HTTP/1.1 header, so set it if it isn't already
      @header.host ||= Addressable::URI.parse(resource.uri).host

      # Setting the date isn't a bad idea, either
      @header.date ||= Time.now.httpdate

      # Add any auth credentials we might want
      add_credentials!

    end

    def add_credentials!
      @accessor.auth_manager.add_credentials(self)
    end

    def fetch_response
      accessor.auth_manager.add_credentials(self)
      cached_response = accessor.cache_manager.lookup(self) unless skip_cache?
      if cached_response
        logger.info("    Retrieved from cache")
        if needs_revalidation?(cached_response)
          logger.info("    Cache entry is stale")
          set_validation_headers!(cached_response)
        else
          # We're done!
          return cached_response
        end
      end

      response = perform!

      if response.not_modified?
        logger.info("    Resource not modified")
        cached_response.header.merge!(response.header)
        cached_response.request_time = response.request_time
        response = cached_response
        response.authoritative = true
      end

      if response.redirect? and should_be_redirected?(response)
        if response.moved_permanently?
          resource.update_uri response.header['Location'].first
          logger.info("    Permanently redirected to #{uri} - Storing new location.")
          response = fetch_response
        elsif response.see_other? # Always use GET for this redirect, regardless of initial method
          redirected_resource = Resourceful::Resource.new(self.accessor, response.header['Location'].first)
          response = Request.new(:get, redirected_resource, body, header).fetch_response
        else
          redirected_resource = Resourceful::Resource.new(self.accessor, response.header['Location'].first)
          logger.info("    Redirected to #{redirected_resource.uri} - Caching new location.")
          response = Request.new(method, redirected_resource, body, header).fetch_response
        end
      end

      if response.unauthorized? && !@already_tried_with_auth
        @already_tried_with_auth = true
        accessor.auth_manager.associate_auth_info(response)
        logger.info("Authentication Required. Retrying with auth info")
        accessor.auth_manager.add_credentials(self)
        response = fetch_response
      end

      raise UnsuccessfulHttpRequestError.new(self, response) if response.error?

      accessor.cache_manager.store(self, response) unless (self.header['Cache-Control'] || '').include?('no-store')

      return response
    end

    def skip_cache?
      return true unless method.in? CACHEABLE_METHODS
      header.cache_control && header.cache_control.include?('no-cache')
    end

    def perform!
      @request_time = Time.now

      http_resp = NetHttpAdapter.make_request(@method, @resource.uri, @body, @header)
      @response = Resourceful::Response.new(uri, *http_resp)
      @response.request_time = @request_time
      @response.authoritative = true

      @response
    end

    def should_be_redirected?(response)
      if resource.on_redirect.nil?
        return true if method.in? REDIRECTABLE_METHODS
        false
      else
        resource.on_redirect.call(self, response)
      end
    end

    def needs_revalidation?(response)
      return true if response.stale?
      return true if max_age && response.current_age > max_age
      false
    end

    def set_validation_headers!(response)
      @header['If-None-Match'] = response.header['ETag'] if response.header.has_key?('ETag')
      @header['If-Modified-Since'] = response.header['Last-Modified'] if response.header.has_key?('Last-Modified')
      @header['Cache-Control'] = 'max-age=0' if response.header.has_key?('Cache-Control') and response.header['Cache-Control'].include?('must-revalidate')
    end

    # @return [String]   The URI against which this request will be, or was, made.
    def uri
      resource.uri
    end

    def forces_revalidation?
      if cc = header['Cache-Control']
        cc.include?('no-cache') || max_age == 0
      else
        false
      end
    end
    
    # Indicates the maxmimum response age in seconds we are willing to accept
    #
    # Returns nil if we don't care how old the response is
    def max_age
      if header['Cache-Control'] and header['Cache-Control'].include?('max-age')
        header['Cache-Control'].split(',').grep(/max-age/).first.split('=').last.to_i
      end
    end

    def logger
      resource.logger
    end

  end

end
