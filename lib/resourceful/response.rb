require 'net/http'

module Resourceful

  class Response
    REDIRECT_RESPONSE_CODES = [301,302,303,307]

    attr_reader :code, :header, :body
    alias headers header

    def initialize(code, header, body)
      @code, @header, @body = code, header, body
    end

    def is_redirect?
      @code.in? REDIRECT_RESPONSE_CODES
    end
    alias was_redirect? is_redirect?

    def is_permanent_redirect?
      @code == 301
    end
  end
  
end
