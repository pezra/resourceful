
require 'advanced_http/http_accessor'

# AdvancedHttp is a facade that allows convenient access to the
# functionality provided by the AdvancedHttp library.
module AdvancedHttp
  # A Hash of named URIs.  Many methods in AdvancedHTTP that need a URI
  # also take a name which they then resolve into a real URI using
  # this Hash.
  def self.named_uris
    HttpAccessor.named_uris
  end
end
