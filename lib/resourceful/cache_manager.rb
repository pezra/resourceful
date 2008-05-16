
module Resourceful

  class CacheManager

    def initialize
      @objects = Hash.new([])
    end

    def lookup(request)

    end

    def store(request, response)

      @objects[request.resource.uri].each do |object|
      end

    end

  end

  class CachedObject

    attr_accessor :request_time, :request_vary_headers, :response

  end

end
