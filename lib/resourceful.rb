require 'resourceful/http_accessor'

require 'resourceful/util'

# Resourceful is a library that provides a high level HTTP interface.
module Resourceful
  # A Hash of named URIs.  Many methods in Resourceful that need a URI
  # also take a name which they then resolve into a real URI using
  # this Hash.
  def self.named_uris
    Resourceful.named_uris
  end

  HOP_BY_HOP_HEADERS = %w{
    Connection
    Keep-Alive
    Proxy-Authenticate
    Proxy-Authorization
    TE
    Trailers
    Transfer-Encoding
    Upgrade
  }

  NON_MODIFIABLE_HEADERS = %w{
    Content-Location
    Content-MD5
    ETag
    Last-Modified
    Expires
  }


end
