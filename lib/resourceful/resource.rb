require 'pathname'
require 'resourceful/request'

module Resourceful

  class Resource
    attr_reader :accessor

    # Build a new resource for a uri
    #
    # @param accessor<HttpAccessor> 
    #   The parent http accessor
    # @param uri<String, Addressable::URI> 
    #   The uri for the location of the resource
    def initialize(accessor, uri, default_header = {})
      @accessor, @uris = accessor, [uri]
      @default_header = Resourceful::Header.new({'User-Agent' => Resourceful::RESOURCEFUL_USER_AGENT_TOKEN}.merge(default_header))
      @on_redirect = nil
    end

    # The uri used to identify this resource. This is almost always the uri
    # used to create the resource, but in the case of a permanent redirect, this
    # will always reflect the lastest uri.
    #
    # @return Addressable::URI 
    #   The current uri of the resource
    def effective_uri
      @uris.first
    end
    alias uri effective_uri

    def default_header(temp_defaults = {})
      @default_header.merge(temp_defaults)
    end

    # Returns the host for this Resource's current uri
    def host
      Addressable::URI.parse(uri).host
    end

    # Updates the effective uri after following a permanent redirect
    def update_uri(uri)
      @uris.unshift(uri)
    end

    # When performing a redirect, this callback will be executed first. If the callback
    # returns true, then the redirect is followed, otherwise it is not. The request that
    # triggered the redirect and the response will be passed into the block. This can be
    # used to update any links on the client side.
    #
    # Example:
    #
    #   author_resource.on_redirect do |req, resp|
    #     post.author_uri = resp.header['Location']
    #   end
    #
    # @yieldparam callback<request, response>
    #   The action to be executed when a request results in a redirect. Yields the 
    #   current request and result objects to the callback.
    #
    # @raise ArgumentError if called without a block 
    def on_redirect(&callback)
      if block_given?
        @on_redirect = callback
      else
        @on_redirect
      end
    end

    # Performs a GET on the resource, following redirects as neccessary, and retriving
    # it from the local cache if its available and valid.
    #
    # @return [Response] The Response to the final request made.
    #
    # @raise [UnsuccessfulHttpRequestError] unless the request is a
    #   success, ie the final request returned a 2xx response code
    def get(header = {})
      request(:get, nil, header)
    end

    def head(header = {})
      request(:head, nil, header)
    end
    # :call-seq:
    #   post(data = "", :content_type => mime_type)
    #
    # Performs a POST with the given data to the resource, following redirects as 
    # neccessary.
    #
    # @param [String] data
    #   The body of the data to be posted
    # @param [Hash] options
    #   Options to pass into the request header. At the least, :content_type is required.
    #
    # @return [Response]  The Response to the final request that was made.
    #
    # @raise [ArgumentError] unless :content-type is specified in options
    # @raise [UnsuccessfulHttpRequestError] unless the request is a
    #   success, ie the final request returned a 2xx response code
    def post(data = nil, header = {})
      request(:post, data, header)
    end

    # :call-seq:
    #   put(data = "", :content_type => mime_type)
    #
    # Performs a PUT with the given data to the resource, following redirects as 
    # neccessary.
    #
    # @param [String] data
    #   The body of the data to be posted
    # @param [Hash] options
    #   Options to pass into the request header. At the least, :content_type is required.
    #
    # @return [Response] The response to the final request made.
    #
    # @raise [ArgumentError] unless :content-type is specified in options
    # @raise [UnsuccessfulHttpRequestError] unless the request is a
    #   success, ie the final request returned a 2xx response code
    def put(data, header = {})
      request(:put, data, header)
    end

    # Performs a DELETE on the resource, following redirects as neccessary.
    #
    # @return <Response>
    #
    # @raise [UnsuccessfulHttpRequestError] unless the request is a
    #   success, ie the final request returned a 2xx response code
    def delete(header = {})
      request(:delete, nil, header)
    end

    def logger
      accessor.logger
    end

    private

    # Ensures that the request has a content type header
    def ensure_content_type(body, header)
      return if header.has_key?('Content-Type') 
      
      if body.respond_to?(:content_type)
        header['Content-Type'] = body.content_type
        return
      end
      
      return if default_header.has_key?('Content-Type') 

      # could not figure it out
      raise MissingContentType
    end

    # Actually make the request
    def request(method, data, header)
      header = default_header.merge(header)
      ensure_content_type(data, header) if data

      data = StringIO.new(data) if data.kind_of?(String)

      logger.debug { header.map {|k,v| "#{k}: #{v}"}.join("\n\t\t") }
      logger.debug { data = StringIO.new(data.read); data.string } if data
      
      log_request_with_time "#{method.to_s.upcase} [#{uri}]" do        
        request = Request.new(method, self, data, header)
        request.fetch_response
      end
    end

    # Log it took the time to make the request
    def log_request_with_time(msg, indent = 2)
      logger.info(" " * indent + msg)
      result = nil
      time = Benchmark.measure { result = yield }
      logger.info(" " * indent + "-> Returned #{result.code} in %.4fs" % time.real)
      result
    end

  end

end
