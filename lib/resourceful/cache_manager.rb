require 'resourceful/header'

module Resourceful

  class CacheManager
    def initialize
      raise NotImplementedError,
        "Use one of CacheManager's child classes instead. Try NullCacheManager if you don't want any caching at all."
    end

    # Search for a cached representation that can be used to fulfill the
    # the given request. If none are found, returns nil.
    #
    # @param request<Resourceful::Request>
    #   The request to use for searching.
    def lookup(request); end

    # Store a response in the cache. 
    #
    # This method is smart enough to not store responses that cannot be 
    # cached (Vary: * or Cache-Control: no-cache, private, ...)
    #
    # @param request<Resourceful::Request>
    #   The request used to obtain the response. This is needed so the 
    #   values from the response's Vary header can be stored.
    # @param response<Resourceful::Response>
    #   The response to be stored.
    def store(request, response); end

    # Invalidates a all cached entries for a uri. 
    #
    # This is used, for example, to invalidate the cache for a resource 
    # that gets POSTed to.
    #
    # @param uri<String>
    #   The uri of the resource to be invalidated
    def invalidate(uri); end

    # Selects the headers from the request named by the response's Vary header
    # http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.5.6
    #
    # @param request<Resourceful::Request>
    #   The request used to obtain the response.
    # @param response<Resourceful::Response>
    #   The response obtained from the request.
    def select_request_headers(request, response)
      header = Resourceful::Header.new

      response.header['Vary'].first.split(',').each do |name|
        name.strip!
        header[name] = request.header[name]
      end if response.header['Vary']

      header
    end
  end

  # This is the default cache, and does not do any caching. All lookups
  # result in nil, and all attempts to store a response are a no-op.
  class NullCacheManager < CacheManager
    def initialize; end

    def lookup(request)
      nil
    end

    def store(request, response); end
  end

  # This is a nieve implementation of caching. Unused entries are never
  # removed, and this may eventually eat up all your memory and cause your
  # machine to explode.
  class InMemoryCacheManager < CacheManager

    def initialize
      @collection = Hash.new{ |h,k| h[k] = CacheEntryCollection.new}
    end

    def lookup(request)
      entry = @collection[request.uri.to_s][request]
      response = entry.response if entry
      response.authoritative = false if response

      response      
    end

    def store(request, response)
      return unless response.cachable?

      entry = CacheEntry.new(request.request_time, 
                             select_request_headers(request, response), 
                             response)
      
      @collection[request.uri.to_s][request] = entry
    end

    def invalidate(uri)
      @collection.delete(uri)
    end

    # The collection of all cached entries for a single resource (uri). 
    class CacheEntryCollection
      include Enumerable

      def initialize
        @entries = []
      end

      # Iterates over the entries. Needed for Enumerable
      def each(&block)
        @entries.each(&block)
      end

      # Looks of a Entry that could fullfil the request. Returns nil if none
      # was found.
      #
      # @param request<Resourceful::Request>
      #   The request to use for the lookup.
      def [](request)
        self.each do |entry|
          return entry if entry.valid_for?(request)
        end
        return nil
      end

      # Saves an entry into the collection. Replaces any existing ones that could 
      # be used with the updated response.
      #
      # @param request<Resourceful::Request>
      #   The request that was used to obtain the response
      # @param cache_entry<CacheEntry>
      #   The cache_entry generated from response that was obtained.
      def []=(request, cache_entry)
        @entries.delete_if { |e| e.valid_for?(request) }
        @entries.unshift cache_entry
      end

    end # class CacheEntryCollection

    # Contains everything we need to know to build a response for a request using the
    # stored request.
    class CacheEntry
      # request_vary_headers is a HttpHeader with keys from the 
      # Vary header of the response, plus the values from the matching
      # fields in the request
      attr_accessor :request_time, :request_vary_headers, :response

      # @param request_time<Time>
      #   Client-generated timestamp for when the request was made
      # @param request_vary_headers<Resourceful::HttpHeader>
      #   A HttpHeader constructed from the keys listed in the vary headers
      #   of the response, and values obtained from those headers in the request
      # @param response<Resourceful::Response>
      #   The Response obhect to be stored.
      def initialize(request_time, request_vary_headers, response)
        @request_time, @request_vary_headers, @response = request_time, request_vary_headers, response
      end

      # Returns true if this entry may be used to fullfil the given request, 
      # according to the vary headers.
      #
      # @param request<Resourceful::Request>
      #   The request to do the lookup on. 
      def valid_for?(request)
        @request_vary_headers.all? do |key, value|
          request.header[key] == value
        end
      end

    end # class CacheEntry

  end # class InMemoryCacheManager

end
