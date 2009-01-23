require 'net/http'
require 'time'
require 'rubygems'
require 'facets/kernel/ergo'
require 'zlib'

module Resourceful
  # Exception indicating that the server used a content coding scheme
  # that Resourceful is unable to handle.
  class UnsupportedContentCoding < Exception
  end

  class Response
    REDIRECT_RESPONSE_CODES = [301,302,303,307]

    attr_reader :uri, :code, :header, :body, :response_time
    alias headers header

    attr_accessor :authoritative, :request_time
    alias authoritative? authoritative

    def initialize(uri, code, header, body)
      @uri, @code, @header, @body = uri, code, header, body
      @response_time = Time.now
    end

    # Is this a cached response that has expired?
    #
    # @return true|false
    def expired?
      if header['Cache-Control'] and header['Cache-Control'].first.include?('max-age')
        max_age = header['Cache-Control'].first.split(',').grep(/max-age/).first.split('=').last.to_i
        return true if current_age > max_age
      elsif header['Expire']
        return true if Time.httpdate(header['Expire'].first) < Time.now
      end

      false
    end

    # Is this a cached response that is stale?
    #
    # @return true|false
    def stale?
      return true if expired?
      if header['Cache-Control']
        return true if header['Cache-Control'].include?('must-revalidate')
        return true if header['Cache-Control'].include?('no-cache')
      end

      false
    end

    # Is this response cachable?
    #
    # @return true|false
    def cachable?
      return false unless [200, 203, 300, 301, 410].include?(code.to_i)
      return false if header['Vary'] and header['Vary'].include?('*')
      return false if header['Cache-Control'] and header['Cache-Control'].include?('no-store')

      true
    end

    # Algorithm taken from RCF2616#13.2.3
    def current_age
      age_value   = Time.httpdate(header['Age'].first) if header['Age']
      date_value  = Time.httpdate(header['Date'].first)
      now         = Time.now

      apparent_age = [0, response_time - date_value].max
      corrected_received_age = [apparent_age, age_value || 0].max
      current_age = corrected_received_age + (response_time - request_time) + (now - response_time)
    end

    def body
      case header['Content-Encoding'].ergo.first
      when nil
        # body is identity encoded; just return it
        @body
      when /^\s*gzip\s*$/i
        gz_in = ::Zlib::GzipReader.new(StringIO.new(@body, 'r'))
        @body = gz_in.read
        gz_in.close
        header.delete('Content-Encoding')
        @body
      else
        raise UnsupportedContentCoding, "Resourceful does not support #{header['Content-Encoding'].ergo.first} content coding" 
      end
    end

    CODE_NAMES = {
      100 => "Continue".freeze,
      101 => "Switching Protocols".freeze,

      200 => "OK".freeze,
      201 => "Created".freeze,
      202 => "Accepted".freeze,
      203 => "Non-Authoritative Information".freeze,
      204 => "No Content".freeze,
      205 => "Reset Content".freeze,
      206 => "Partial Content".freeze,

      300 => "Multiple Choices".freeze,
      301 => "Moved Permanently".freeze,
      302 => "Found".freeze,
      303 => "See Other".freeze,
      304 => "Not Modified".freeze,
      305 => "Use Proxy".freeze,
      307 => "Temporary Redirect".freeze,

      400 => "Bad Request".freeze,
      401 => "Unauthorized".freeze,
      402 => "Payment Required".freeze,
      403 => "Forbidden".freeze,
      404 => "Not Found".freeze,
      405 => "Method Not Allowed".freeze,
      406 => "Not Acceptable".freeze,
      407 => "Proxy Authentication Required".freeze,
      408 => "Request Timeout".freeze,
      409 => "Conflict".freeze,
      410 => "Gone".freeze,
      411 => "Length Required".freeze,
      412 => "Precondition Failed".freeze,
      413 => "Request Entity Too Large".freeze,
      414 => "Request-URI Too Long".freeze,
      415 => "Unsupported Media Type".freeze,
      416 => "Requested Range Not Satisfiable".freeze,
      417 => "Expectation Failed".freeze,

      500 => "Internal Server Error".freeze,
      501 => "Not Implemented".freeze,
      502 => "Bad Gateway".freeze,
      503 => "Service Unavailable".freeze,
      504 => "Gateway Timeout".freeze,
      505 => "HTTP Version Not Supported".freeze,
    }.freeze

    CODE_NAMES.each do |code, msg|
      method_name = msg.downcase.gsub(/[- ]/, "_")

      class_eval <<-RUBY
        def #{method_name}?                           # def ok?
          @code == #{code}                            #   @code == 200
        end                                           # end
      RUBY
    end

    # Is the response informational? True for
    # 1xx series response codes
    #
    # @return true|false
    def informational?
      @code.in? 100..199
    end

    # Is the response code sucessful? True for only 2xx series
    # response codes.
    #
    # @return true|false
    def successful?
      @code.in? 200..299
    end
    alias success? successful?

    # Is the response a redirect? True for
    # 3xx series response codes
    #
    # @return true|false
    def redirection?
      @code.in? 300..399
    end
    alias redirect? redirection?

    # Is the response the result of a client error? True for
    # 4xx series response codes
    #
    # @return true|false
    def client_error?
      @code.in? 400..499
    end

    # Is the response the result of a server error? True for
    # 5xx series response codes
    #
    # @return true|false
    def server_error?
      @code.in? 500..599
    end

    # Is the response the result of any kind of error? True for
    # 4xx and 5xx series response codes
    #
    # @return true|false
    def error?
      server_error? || client_error?
    end

  end
  
end
