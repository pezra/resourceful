require 'resourceful/header'
require 'andand'

module Resourceful

  class AbstractCacheManager
    def initialize
      raise NotImplementedError,
        "Use one of CacheManager's child classes instead. Try NullCacheManager if you don't want any caching at all."
    end

    # Finds a previously cached response to the provided request.  The
    # response returned may be stale.
    #
    # @param [Resourceful::Request] request 
    #   The request for which we are looking for a response.
    #
    # @return [Resourceful::Response] 
    #   A (possibly stale) response for the request provided.
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
  end

  # This is the default cache, and does not do any caching. All lookups
  # result in nil, and all attempts to store a response are a no-op.
  class NullCacheManager < AbstractCacheManager
    def initialize; end

    def lookup(request)
      nil
    end

    def store(request, response); end
  end

  # This is a nieve implementation of caching. Unused entries are never
  # removed, and this may eventually eat up all your memory and cause your
  # machine to explode.
  class InMemoryCacheManager < AbstractCacheManager

    def initialize
      @collection = Hash.new{ |h,k| h[k] = CacheEntryCollection.new}
    end

    def lookup(request)
      returning(@collection[request.uri.to_s][request]) do |response|
        response.authoritative = false if response
      end
    end

    def store(request, response)
      return unless response.cachable?

      @collection[request.uri.to_s][request] = response
    end

    def invalidate(uri)
      @collection.delete(uri)
    end
  end  # class InMemoryCacheManager

  # The collection of cached entries.  Nominally all the entry in a
  # collection of this sort will be for the same resource but that is
  # not required to be true.
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
    # @param [Resourceful::Request] request
    #   The request to use for the lookup.
    #
    # @return [Resourceful::Response] 
    #   The cached response for the specified request if one is available.
    def [](request)
      find { |an_entry| an_entry.valid_for?(request) }.andand.response 
    end
    
    # Saves an entry into the collection. Replaces any existing ones that could 
    # be used with the updated response.
    #
    # @param [Resourceful::Request] request
    #   The request that was used to obtain the response
    # @param [Resourceful::Response] response
    #   The cache_entry generated from response that was obtained.
    def []=(request, response)
      @entries.delete_if { |e| e.valid_for?(request) }
      @entries << CacheEntry.new(request, response)

      response
    end
  end # class CacheEntryCollection

  # Represents a previous request and cached response with enough
  # detail to determine construct a cached response to a matching
  # request in the future.  It also understands what a matching
  # request means.
  class CacheEntry
    # request_vary_headers is a HttpHeader with keys from the Vary
    # header of the response, plus the values from the matching fields
    # in the request
    attr_reader :request_vary_headers
    
    # The time at which the client believes the request was made.
    attr_reader :request_time

    # The URI of the request
    attr_reader :request_uri

    # The response to that we are caching
    attr_reader :response

    # @param [Resourceful::Request] request
    #   The request whose response we are storing in the cache.
    # @param response<Resourceful::Response>
    #   The Response obhect to be stored.
    def initialize(request, response)
      @request_uri = request.uri
      @request_time = request.request_time
      @request_vary_headers = select_request_headers(request, response)
      @response = response
    end

    # Returns true if this entry may be used to fullfil the given request, 
    # according to the vary headers.
    #
    # @param request<Resourceful::Request>
    #   The request to do the lookup on. 
    def valid_for?(request)
      request.uri == @request_uri and 
        @request_vary_headers.all? {|key, value| request.header[key] == value}
    end

    # Selects the headers from the request named by the response's Vary header
    # http://www.w3.org/Protocols/rfc2616/rfc2616-sec13.html#sec13.5.6
    #
    # @param [Resourceful::Request] request
    #   The request used to obtain the response.
    # @param [Resourceful::Response] response
    #   The response obtained from the request.
    def select_request_headers(request, response)
      header = Resourceful::Header.new

      response.header['Vary'].each do |name|
        header[name] = request.header[name]
      end if response.header['Vary']

      header
    end

  end # class CacheEntry

end
