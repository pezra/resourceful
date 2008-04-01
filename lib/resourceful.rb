require 'advanced_http/http_accessor'

# AdvancedHttp is a library that provides a high level HTTP interface.
module AdvancedHttp
  # A Hash of named URIs.  Many methods in AdvancedHTTP that need a URI
  # also take a name which they then resolve into a real URI using
  # this Hash.
  def self.named_uris
    HttpAccessor.named_uris
  end
end
