require 'http11_client/http11_client'
require 'resourceful/push_back_io'

module Resourceful

  # A reasonable default HTTP adapter.
  class RdHttpAdapter
    HTTP_REQUEST_START_LINE="%s %s HTTP/1.1\r\n"
    HTTP_HEADER_FIELD_LINE="%s: %s\r\n" 
    CHUNK_SIZE=1024 * 16

    # Makes HTTP request
    def make_request(method, uri, body = nil, header = {})
      uri = parse_uri(uri)

      conn = PushBackIo.new(Socket.new(uri.host, uri.port || 80))

      if body
        header['Content-Length'] = body.length
      end

      conn.write(build_request_header(method, uri, header))
      conn.write(body) if body
      conn.flush

      resp = read_parsed_header(conn)
      
      [Integer(resp.http_status), 
       Resourceful::Header.new(resp),
       resp.http_body]
    ensure
      conn.close if conn
    end

    protected
    
    def parser
      @parser ||= Resourceful::HttpClientParser.new
    end

    # Reads and parses header from `conn`
    def read_parsed_header(conn)
      parser.reset
      resp = HttpResponse.new
      data = conn.readpartial(CHUNK_SIZE)
      nread = parser.execute(resp, data, 0)

      while !parser.finished?
        data << conn.readpartial(CHUNK_SIZE)
        nread = parser.execute(resp, data, nread)
      end

      return resp
    end
    
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

    # A simple hash is returned for each request made by HttpClient with
    # the headers that were given by the server for that request.
    class HttpResponse < Hash
      # The reason returned in the http response ("OK","File not found",etc.)
      attr_accessor :http_reason

      # The HTTP version returned.
      attr_accessor :http_version

      # The status code (as a string!)
      attr_accessor :http_status

      # The http body of the response, in the raw
      attr_accessor :http_body

      # When parsing chunked encodings this is set
      attr_accessor :http_chunk_size

      # The actual chunks taken from the chunked encoding
      attr_accessor :raw_chunks

      # Converts the http_chunk_size string properly
      def chunk_size
        if @chunk_size == nil
          @chunk_size = @http_chunk_size ? @http_chunk_size.to_i(base=16) : 0
        end

        @chunk_size
      end

      # true if this is the last chunk, nil otherwise (false)
      def last_chunk?
        @last_chunk || chunk_size == 0
      end

      # Easier way to find out if this is a chunked encoding
#       def chunked_encoding?
#         /chunked/i === self[HttpClient::TRANSFER_ENCODING]
#       end
    end

  end
end
