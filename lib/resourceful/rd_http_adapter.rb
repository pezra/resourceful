# A reasonable default HTTP adapter.

module Resourceful

  class RdHttpAdapter
    HTTP_REQUEST_START_LINE="%s %s HTTP/1.1\r\n"
    HTTP_HEADER_FIELD_LINE="%s: %s\r\n" 

    # Makes HTTP request
    def make_request(method, uri, body = nil, header = {})
      uri = parse_uri(uri)

      out = Socket.new(uri.host, uri.port || 80)

      if body
        header['Content-Length'] = body.length
      end

      out.write(build_request_header(method, uri, header))
      out.write(body) if body
      out.flush

    ensure
      out.close if out
    end

    protected
    
    # Builds the HTTP request header.
    #
    # @return [String] The, verbatim, HTTP header.
    def build_request_header(method, uri, header_fields)
      req = StringIO.new
      req.write(HTTP_REQUEST_START_LINE % [method, uri])
      
      header_fields.each do |k, v|
        if v.kind_of?(Array)
          v.each {|sub_v| req.write(HTTP_HEADER_FIELD_LINE % [k,sub_v])}
        else
          req.write(HTTP_HEADER_FIELD_LINE % [k,v])
        end
      end

      req.write("\r\n")

      req.string
    end

    # Parses a URI string into a Addressable::URI object (if needed)
    #
    # @param [Addressable::URI, String] a_uri  The URI to parse.
    #
    # @return Addressable::URI
    def parse_uri(a_uri)
      if a_uri.is_a?(Addressable::URI) 
        a_uri
      else 
        Addressable::URI.parse(a_uri)
      end
    end
  end
end
