require 'net/http'

module Resourceful

  class Response
    attr_reader :code, :header, :body
    alias headers header

    def initialize(code, header, body)
      @code, @header, @body = code, header, body
    end

  end
  
end
