require 'net/http'
require 'resourceful/response'

module Resourceful

  class Request

    attr_accessor :method, :resource

    def initialize(http_method, resource)
      @method, @resource = http_method, resource
    end

    def make

      req = Net::HTTP::Get.new(resource.uri)
      response = nil

      Net::HTTP.start(@resource.uri.host, @resource.uri.path) do |conn|
        response = Resourceful::Response.new(conn.request(req))
      end

      response

    end

  end

end
