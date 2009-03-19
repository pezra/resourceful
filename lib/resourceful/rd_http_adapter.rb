require 'http11_client/http11_client'
require 'resourceful/push_back_io'
require 'resourceful/exceptions'
require 'stringio'
require 'resourceful/abstract_http_adapter'
require 'forwardable'
require 'facets/memoize'
require 'openssl'

module Resourceful

  # A reasonable default HTTP adapter.
  class RdHttpAdapter < AbstractHttpAdapter
    HTTP_REQUEST_START_LINE="%s %s HTTP/1.1\r\n"
    HTTP_HEADER_FIELD_LINE="%s: %s\r\n" 
    CHUNK_SIZE= 1024 * 16


    # Make the specified request and return the parsed info from the response
    #
    # @param request  
    #   The request to make.
    # @return [ResponseStruct]  
    #   The response from the server.
    def make_request(request)
      conn = HttpConnection.new(request.uri.host, request.uri.inferred_port, /https/i === request.uri.scheme)

      if request.body
        request.header['Content-Length'] = request.body.length
      end

      conn.send_request(request.method, request.uri, request.body, request.header)
      resp = conn.read_response

      ResponseStruct.new.tap {|r|
        r.status = Integer(resp.http_status)
        r.reason = resp.http_reason
        r.header = resp
        r.body   = resp.http_body
      }

    ensure
      conn.close unless conn.nil?
    end

    protected
    
    def parser
      Resourceful::HttpClientParser.new
    end
    memoize :parser

    # Parses a URI string into a Addressable::URI object (if needed)
    #
    # @param [Addressable::URI, String] a_uri
    #   The URI to parse.
    # @return Addressable::URI
    def parse_uri(a_uri)
      if a_uri.is_a?(Addressable::URI) 
        a_uri
      else 
        Addressable::URI.parse(a_uri)
      end
    end


    class HttpConnection
      extend Forwardable
      
      ##
      attr_reader :host
      
      ##
      attr_reader :port
      
      ##
      attr_reader :use_ssl

      ##
      attr_reader :tcp_conn

      # @param [String] host  
      #   The name of the host to connect to.
      # @param [Integer] port 
      #   The port to connect to.
      # @param [boolean] use_ssl
      #   When true secure the TCP connect using SSL. Default: false
      def initialize(host, port, use_ssl = false)
        @host = host
        @port = port
        @use_ssl = use_ssl

        socket = TCPSocket.new(host, port)
        if use_ssl
          socket = OpenSSL::SSL::SSLSocket.new(socket).tap{ |ssl|
            ssl.sync_close = true
            ssl.connect
          }
        end
        @tcp_conn = PushBackIo.new(socket)        
      end

      def send_request(method, uri, body, header)
        tcp_conn.write(build_request_header(method, uri, header))
        tcp_conn.write(body) if body
        tcp_conn.flush
      end

      # Read http response
      #
      # @return [ParserOutput]
      def read_response
        read_and_parse_header.tap do |resp|
          if /chunked/i === resp['TRANSFER_ENCODING']
            resp.http_body = read_chunked_body(resp.http_body)
          else
            needs = resp['CONTENT_LENGTH'].to_i - resp.http_body.length
            resp.http_body << tcp_conn.read(needs) if needs > 0
          end
        end
      end

      # Close the underlying TCP connection.
      def_delegator :tcp_conn, :close

      protected

      # Builds the HTTP request header.
      #
      # @return [String] 
      #   The, verbatim, HTTP request header.
      def build_request_header(method, uri, header_fields)
        req = StringIO.new
        relative_uri = uri.path
        relative_uri << '?' + uri.query if uri.query

        req.write(HTTP_REQUEST_START_LINE % [method.to_s.upcase, relative_uri])
        
        header_fields['Host'] = if uri.inferred_port == 80
                                  uri.host
                                else 
                                  "#{uri.host}:#{uri.port}"
                                end

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

      # Reads and parses header from `conn`
      def read_and_parse_header
        parser.reset
        resp = ParserOutput.new
        data = tcp_conn.readpartial(CHUNK_SIZE)
        nread = parser.execute(resp, data, 0)
        
        while !parser.finished?
          data << tcp_conn.readpartial(CHUNK_SIZE)
          nread = parser.execute(resp, data, nread)
        end
        
        resp

      rescue Resourceful::HttpClientParserError => e
        raise Resourceful::MalformedServerResponseError, e.message
      end

      def parser
        @parser ||= Resourceful::HttpClientParser.new
      end
      
      # Used to process chunked headers and then read up their bodies.
      def read_chunked_header
        resp = read_and_parse_header
        @tcp_conn.push(resp.http_body)
        
        if resp.chunk_size > 0
          resp.http_body = @tcp_conn.read(resp.chunk_size)
          
          trail = @tcp_conn.read(2)
          if trail != "\r\n"
            raise Resourceful::MalformedServerResponseError, "Chunk ended in #{trail.inspect} not a CRLF"
          end
        end
        
        return resp
      end

      # Collects up and returns chunked body 
      def read_chunked_body(partial_body)
        @tcp_conn.push(partial_body)
        body = StringIO.new

        while true
          chunk = read_chunked_header
          body << chunk.http_body

          break if chunk.chunk_size.zero?
        end
      
        body.string
      end

      # The results of HTTP client parser
      class ParserOutput < Hash
        attr_accessor :http_reason, :http_version, :http_status, :http_body, :http_chunk_size
        
        def chunk_size
          http_chunk_size.to_i(16)
        end
      end
    end
  end
end
