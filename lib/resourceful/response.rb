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

    # Is the response code sucessful? True for only 2xx series
    # response codes.
    #
    # @return true|false
    def is_success?
      @code.in? 200..299
    end
    alias was_successful? is_success?

    # Is the response the result of a server error? True for
    # 5xx series response codes
    #
    # @return true|false
    def is_server_error?
      @code.in? 500..599
    end
    alias was_server_error? is_server_error?

    # Is the response the result of a client error? True for
    # 4xx series response codes
    #
    # @return true|false
    def is_client_error?
      @code.in? 400..499
    end
    alias was_client_error? is_client_error?

    # Is the response the result of any kind of error? True for
    # 4xx and 5xx series response codes
    #
    # @return true|false
    def is_error?
      is_server_error? || is_client_error?
    end
    alias was_error? is_error?

    # Is the response not a success? True for
    # 3xx, 4xx and 5xx series response codes
    #
    # @return true|false
    def is_unsuccesful?
      is_error? || is_redirect?
    end
    alias was_unsuccessful? is_unsuccesful?

    # Is the response a redirect response code? True for
    # 3xx codes that are redirects (301, 302, 303, 307)
    #
    # @return true|false
    def is_redirect?
      @code.in? REDIRECT_RESPONSE_CODES
    end
    alias was_redirect? is_redirect?

    # Is the response a Permanent Redirect (301) ?
    #
    # @return true|false
    def is_permanent_redirect?
      @code == 301
    end

    # Is the response a Temporary Redirect (anything but 301) ?
    #
    # @return true|false
    def is_temporary_redirect?
      is_redirect? and not is_permanent_redirect?
    end

    # Is the response a client error of Not Authorized (401) ?
    #
    # @return true|false
    def is_not_authorized?
      @code == 401
    end

    # Is the response not modified (304) ?
    #
    # @return true|false
    def is_not_modified?
      @code == 304
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
  end
  
end
