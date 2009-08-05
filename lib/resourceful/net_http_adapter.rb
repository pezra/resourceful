require 'net/http'
require 'net/https'
require 'addressable/uri'

require 'pathname'
require 'resourceful/header'

module Addressable
  class URI
    def absolute_path
      absolute_path = ""
      absolute_path << self.path.to_s
      absolute_path << "?#{self.query}" if self.query != nil
      absolute_path << "##{self.fragment}" if self.fragment != nil
      return absolute_path
    end
  end
end

module Resourceful

  class NetHttpAdapter
    # Make an HTTP request using the standard library net/http.
    #
    # Will use a proxy defined in the http_proxy environment variable, if set.
    def self.make_request(method, uri, body = nil, header = nil)
      uri = uri.is_a?(Addressable::URI) ? uri : Addressable::URI.parse(uri)

      req = net_http_request_class(method).new(uri.absolute_path)
      header.each_field { |k,v| req[k] = v } if header
      https = ("https" == uri.scheme)
      conn = Net::HTTP.Proxy(*proxy_details).new(uri.host, uri.port || (https ? 443 : 80))
      conn.use_ssl = https
      begin 
        conn.start
        res = if body
                conn.request(req, body.read)
              else
                conn.request(req)
              end
      ensure
        conn.finish if conn.started?
      end

      [ Integer(res.code),
        Resourceful::Header.new(res.header.to_hash),
        res.body
      ]
    ensure
      
    end

    private

    # Parse proxy details from http_proxy environment variable
    def self.proxy_details
      proxy = Addressable::URI.parse(ENV["http_proxy"])
      [proxy.host, proxy.port, proxy.user, proxy.password] if proxy
    end

    def self.net_http_request_class(method)
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
