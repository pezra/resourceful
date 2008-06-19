require 'net/http'
require 'time'

module Resourceful

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

    def is_redirect?
      @code.in? REDIRECT_RESPONSE_CODES
    end
    alias was_redirect? is_redirect?

    def is_permanent_redirect?
      @code == 301
    end

    def is_temporary_redirect?
      is_redirect? and not is_permanent_redirect?
    end

    def is_not_authorized?
      @code == 401
    end

    def expired?
      if header['Expire']
        return true if Time.httpdate(header['Expire'].first) < Time.now
      end

      false
    end

    def stale?
      return true if expired?
      if header['Cache-Control']
        return true if header['Cache-Control'].include?('must-revalidate')
        return true if header['Cache-Control'].include?('no-cache')
      end

      false
    end

    def cachable?
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
      case header['Content-Encoding']
      when nil
        # body is identity encoded; just return it
        @body
      when /gzip/i
        gz_in = Zlib::GzipReader.new(StringIO.new(@body, 'r'))
        @body = gz_in.read
        gz_in.close
        header.delete('Content-Encoding')
        @body
      end
    end
  end
  
end
