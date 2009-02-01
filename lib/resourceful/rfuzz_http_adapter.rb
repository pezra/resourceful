require 'addressable/uri'
require 'resourceful/header'

begin
  require 'rfuzz/client'
rescue LoadError
end 

if defined?(RFuzz::HttpClient)
  module Resourceful
    class RFuzzHttpAdapterClass
      # Make an HTTP request
      #
      # @param [Symbol] method   The HTTP method of the request to make.
      # @param [Addressable::URI]   The URI of the resource to request
      # @param [String]   The body of the request to make.
      # @param [Resourceful::Header]   The set of header fields that should be 
      #   included in the request.
      #
      # @return [Array(Integer,Resourceful::Header,String)]  The status, header and 
      #   body of the response.
      def make_request(method, uri, body = nil, header = nil)
        resp = client_for(uri).send_request(method.to_s.upcase, uri.absolute_path, :body => body, :header => header)

        [resp.http_status.to_i,
         Resourceful::Header.new(resp),
         resp.http_body]
      end

      protected

      def client_for(a_uri)
        RFuzz::HttpClient.new(a_uri.host, a_uri.inferred_port)
      end
    end

    RFuzzHttpAdapter = RFuzzHttpAdapterClass.new
  end
end
