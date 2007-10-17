require 'advanced_http/resource'
  
module AdvancedHttp
  class StubbedResourceProxy
    def initialize(resource)
      @resource = resource
    end
    
    def stub_get(response_mime_type, response_body)
      resp = Net::HTTPOK.new('1.1', '200', 'OK')
      resp['content-type'] = response_mime_type.to_str
      resp.instance_variable_set(:@read, true)
      resp.instance_variable_set(:@body, response_body)
      
      @canned_get_response = resp
    end
    
    def get(*args)
      @canned_get_response || @resource.get(*args)
    end

    def method_missing(method, *args)
      @resource.send(method, *args)
    end
  end
end
