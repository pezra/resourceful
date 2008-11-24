require 'resourceful/header'

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
      entry = @collection[request.uri.to_s][request]
      response = entry.response if entry
      response.authoritative = false if response

      response      
    end

    def store(request, response)
      return unless response.cachable?

      entry = CacheEntry.new(request.request_time, request, response)
      
      @collection[request.uri.to_s][request] = entry
    end

    def invalidate(uri)
      @collection.delete(uri)
    end
  end  # class InMemoryCacheManager

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

  # Represents a previous request and cached response with enough
  # detail to determine construct a cached response to a matching
  # request in the future.  It also understands what a matching
  # request means.
  class CacheEntry
    # request_vary_headers is a HttpHeader with keys from the 
    # Vary header of the response, plus the values from the matching
    # fields in the request
    attr_accessor :request_time, :request_vary_headers, :response
    
    # @param request_time<Time>
    #   Client-generated timestamp for when the request was made
    # @param [Resourceful::Request] request
    #   The request whose response we are storing in the cache.
    # @param response<Resourceful::Response>
    #   The Response obhect to be stored.
    def initialize(request_time, request, response)
      @request_time, @request_vary_headers, @response = request_time, select_request_headers(request, response), response
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
