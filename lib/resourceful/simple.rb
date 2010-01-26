module Resourceful
  module Simple
    def request(method, uri, header = {}, data = nil)
      default_accessor.resource(uri).request(method, data, header)
    end
    
    def default_accessor
      @default_accessor ||= Resourceful::HttpAccessor.new
    end
    
    def add_authenticator(an_authenticator)
      default_accessor.add_authenticator(an_authenticator)
    end

    def get(uri, header = {})
      request(:get, uri, header)
    end

    def head(uri, header = {})
      request(:head, uri, header)
    end

    def delete(uri, header = {})
      request(:delete, uri, header)
    end
 
    def post(uri, data = nil, header = {})
      request(:post, uri, header, data)
    end

    def put(uri, data = nil, header = {})
      request(:put, uri, header, data)
    end
  end

end
