# A case-normalizing Hash, adjusting on [] and []=.
# Shamelessly swiped from Rack
module Resourceful
  class Header < Hash
    def initialize(hash={})
      hash.each { |k, v| self[k] = v }
    end

    def to_hash
      {}.replace(self)
    end

    def [](k)
      super capitalize(k)
    end

    def []=(k, v)
      super capitalize(k), v
    end

    def has_key?(k)
      super capitalize(k)
    end

    def capitalize(k)
      k.to_s.downcase.gsub(/^.|[-_\s]./) { |x| x.upcase }.gsub('_', '-')
    end

    HEADERS = %w[
      Accept
      Accept-Charset
      Accept-Encoding
      Accept-Language
      Accept-Ranges
      Age
      Allow
      Authorization
      Cache-Control
      Connection
      Content-Encoding
      Content-Language
      Content-Length
      Content-Location
      Content-MD5
      Content-Range
      Content-Type
      Date
      ETag
      Expect
      Expires
      From
      Host
      If-Match
      If-Modified-Since
      If-None-Match
      If-Range
      If-Unmodified-Since
      Last-Modified
      Location
      Max-Forwards
      Pragma
      Proxy-Authenticate
      Proxy-Authorization
      Range
      Referer
      Retry-After
      Server
      TE
      Trailer
      Transfer-Encoding
      Upgrade
      User-Agent
      Vary
      Via
      Warning
      WWW-Authenticate
    ]

    HEADERS.each do |header|
      const = header.upcase.gsub('-', '_')
      meth  = header.downcase.gsub('-', '_')

      class_eval <<-RUBY
        #{const} = "#{header}".freeze    # ACCEPT = "accept".freeze

        def #{meth}                      # def accept
          self[#{const}]                 #   self[ACCEPT]
        end                              # end

        def #{meth}=(str)                # def accept=(str)
          self[#{const}] = str           #   self[ACCEPT] = str
        end                              # end
      RUBY

    end

  end
end


