require 'net/http'
require 'net/https'
require 'addressable/uri'

require 'pathname'
require 'resourceful/header'
require 'resourceful/abstract_http_adapter'

module Addressable
  class URI
    def absolute_path
      "".tap do |str|
        str << (self.path.empty? ? "/" : self.path)
        str << "?#{self.query}" if self.query != nil
        str << "##{self.fragment}" if self.fragment != nil
      end
    end
  end
end

module Resourceful

  class NetHttpAdapter < AbstractHttpAdapter

    
    # Make the specified request and return the parsed info from the
    # response
    #
    # @param request 
    #   Information about the request to make.  This object will
    #   respond to #uri, #method, #header, #body.
    # @return [ResponseStruct]  
    #   The parse response from the server.
    def make_request(request)
      net_http_req = net_http_request_class(request.method).new(request.uri.absolute_path)
      request.header.each { |k,v| net_http_req[k] = v } 
      https = ("https" == request.uri.scheme)
      conn = Net::HTTP.Proxy(*proxy_details).new(request.uri.host, request.uri.inferred_port)
      conn.use_ssl = https
      begin 
        conn.start
        res = conn.request(net_http_req, request.body)
      ensure
        conn.finish if conn.started?
      end

      ResponseStruct.new.tap {|r|
        r.status = Integer(res.code)
        r.header = res.header.to_hash
        r.body   = res.body
      }
    end

  private

    # Parse proxy details from http_proxy environment variable
    def proxy_details
      proxy = Addressable::URI.parse(ENV["http_proxy"])
      [proxy.host, proxy.port, proxy.user, proxy.password] if proxy
    end

    def net_http_request_class(method)
      case method
      when :get     then Net::HTTP::Get
      when :head    then Net::HTTP::Head
      when :post    then Net::HTTP::Post
      when :put     then Net::HTTP::Put
      when :delete  then Net::HTTP::Delete
      end

    end

  end

end
