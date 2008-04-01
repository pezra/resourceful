require 'resourceful/resource'
  
module Resourceful
  class StubbedResourceProxy
    def initialize(resource, canned_responses)
      @resource = resource
      
      @canned_responses = {}
      
      canned_responses.each do |cr| 
        mime_type = cr[:mime_type]
        @canned_responses[mime_type] = resp = Net::HTTPOK.new('1.1', '200', 'OK')
        resp['content-type'] = mime_type.to_str
        resp.instance_variable_set(:@read, true)
        resp.instance_variable_set(:@body, cr[:body])

      end
    end

    def get_body(*args)
      get(*args).body
    end
    
    def get(*args)
      options = args.last.is_a?(Hash) ? args.last : {}
      
      if accept = [(options[:accept] || '*/*')].flatten.compact
        accept.each do |mt|
          return canned_response(mt) || next
        end
        @resource.get(*args)
       end
    end

    def method_missing(method, *args)
      @resource.send(method, *args)
    end
    
    protected
    
    def canned_response(mime_type)
      mime_type = @canned_responses.keys.first if mime_type == '*/*'
      @canned_responses[mime_type]
    end
    
  end
end
