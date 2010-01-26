module Resourceful
  module Simple
    def request(method, uri, header = {}, data =nil)
      default_accessor.resource(uri).request(method, data, header)
    end
    
    def default_accessor
      @default_accessor ||= Resourceful::HttpAccessor.new
    end
    
    def add_authenticator(an_authenticator)
      default_accessor.add_authenticator(an_authenticator)
    end
  end

end
