require 'pathname'
require 'benchmark'
require Pathname(__FILE__).dirname + 'response'
require Pathname(__FILE__).dirname + 'net_http_adapter'

module Resourceful

  class Request

    REDIRECTABLE_METHODS = [:get, :head]

    attr_accessor :method, :resource, :body, :header
    attr_reader   :request_time

    # @param [Symbol] http_method
    #   :get, :put, :post, :delete or :head
    # @param [Resourceful::Resource] resource
    # @param [String] body
    # @param [Resourceful::Header, Hash] header
    def initialize(http_method, resource, body = nil, header = nil)
      @method, @resource, @body = http_method, resource, body
      @header = header.is_a?(Resourceful::Header) ? header : Resourceful::Header.new(header || {})

      @header['Accept-Encoding'] = 'gzip, identity'
      # 'Host' is a required HTTP/1.1 header, so set it if it isn't already
      @header['Host'] ||= Addressable::URI.parse(resource.uri).host

      # Setting the date isn't a bad idea, either
      @header['Date'] ||= Time.now.httpdate
    end

    def response
      @request_time = Time.now

      http_resp = NetHttpAdapter.make_request(@method, @resource.uri, @body, @header)
      response = Resourceful::Response.new(uri, *http_resp)
      response.request_time = @request_time

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

    # @return [String]   The URI against which this request will be, or was, made.
    def uri
      resource.uri
    end
    
    def logger
      resource.logger
    end

  end

end
