require 'cgi'

module Resourceful
  class UrlencodedFormData
    include FormData

    def content_type
      "application/x-www-form-urlencoded"
    end

    def read
      @form_data.map do |k,v|
        CGI.escape(k) + '=' + CGI.escape(v)
      end.join('&')
    end
  end
end
