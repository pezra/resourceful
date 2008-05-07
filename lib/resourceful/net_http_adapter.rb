require 'net/http'
require 'addressable/uri'

require 'resourceful/header'

module Resourceful

  class NetHttpAdapter
    
    def self.get(uri)
      uri = uri.is_a?(String) ? Addressable::URI.parse(uri) : uri

      req = Net::HTTP::Get.new(uri.path)
      res = Net::HTTP.start(uri.host, uri.port) do |conn|
        conn.request(req)
      end

      [ Integer(res.code),
        Resourceful::Header.new(res.header.to_hash),
        res.body
      ]
    end

  end

end
