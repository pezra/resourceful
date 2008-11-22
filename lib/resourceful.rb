require 'resourceful/http_accessor'

require 'resourceful/util'

# Resourceful is a library that provides a high level HTTP interface.
module Resourceful
  VERSION = "0.2.3"

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
