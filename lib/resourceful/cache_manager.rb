
module Resourceful

  class CacheManager

  end

  class InMemoryCacheManager < CacheManager

    def initialize
      @collection = Hash.new(CacheEntryCollection.new)
    end

    def lookup(request)

      entry = collection[request.resource.uri][request]
      #TODO munge entry into Response

    end

    def store(request, response)

      #TODO munge request.header + response into Entry

      @objects[request.resource.uri].each do |object|
      end

    end

    class CacheEntryCollection
      include Enumerable

      def initialize
        @entries = []
      end

      def each(&block)
        @entries.each(&block)
      end

      def [](request)
        @entries.each do |entry|
          return entry if entry.valid_for?(request)
        end
        return nil
      end

      def []=(request, cache_entry)
        @entries.each do |entry|
          entry = cache_entry if entry.valid_for?(request)
        end
        @entries << cache_entry
      end

    end # class CacheEntryCollection

    class CacheEntry
      # request_vary_headers is a HttpHeader with keys from the 
      # Vary header of the response, plus the values from the matching
      # fields in the request
      attr_accessor :request_time, :request_vary_headers, :response

      def initialize(request_time, request_vary_headers, response)
        @request_time, @request_vary_headers, @response = request_time, request_vary_headers, response
      end

      def valid_for?(request)
        @request_vary_headers.all? do |key, value|
          request.header[key] == value
        end
      end

    end # class CacheEntry

  end # class InMemoryCacheManager

end
