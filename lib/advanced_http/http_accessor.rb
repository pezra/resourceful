require 'advanced_http/resource'
require 'advanced_http/authentication_manager'

require 'advanced_http/stubbed_resource_proxy'

module AdvancedHttp
  
  # This class provides a simple interface to the functionality
  # provided by the AdvancedHttp library.  Conceptually this object
  # acts a collection of all the resources available via HTTP.
  class HttpAccessor
    
    # This is an imitation Logger used when no real logger is
    # registered.  This allows most of the code to assume that there
    # is always a logger available, which significantly improved the
    # readability of the logging related code.
    class BitBucketLogger
      def warn(*args); end
      def info(*args); end
      def debug(*args); end
    end

    # This is an imitation authentication information provider that
    # always response with nil.  This allows code to assume that there
    # is always an authentication information provider, which
    # significantly improves the readability of the code
    class NoOpAuthenticationInfoProvider
      def authentication_info(realm); nil; end
    end
    
    # A logger object to which messages about the activities of this
    # object will be written.  This should be an object that responds
    # to +#info(message)+ and +#debug(message)+.  
    #
    # Errors will not be logged.  Instead an exception will be raised
    # and the application code should log it if appropriate.
    attr_accessor :logger
    
    attr_reader :auth_manager
    
    # Initializes a new HttpAccessor.  Valid options:
    #
    #  +:authentication_info_provider+:: An objects that responds to
    #    +authentication_info(realm)+ and returns the account and
    #    password, as an array +[account, password]+, to use for that
    #    realm, or nil if it does not have authentication information
    #    for that realm.
    #
    #  +:logger+:: A Logger object that the new HTTP accessor should
    #    send log messages
    def initialize(options = {})
      options = options.clone
      
      self.logger = options.delete(:logger) || BitBucketLogger.new
      
      @auth_manager = AuthenticationManager.new(options.delete(:authentication_info_provider) || NoOpAuthenticationInfoProvider.new)
      
      raise ArgumentError, "Unrecognized option(s): #{options.keys.join(', ')}" unless options.empty?
    end

    # Returns a resource object representing the resource indicated
    # by the specified URI.  A resource object will be created if necessary.
    def resource(uri)
      resource = Resource.new(self, uri)
      return resource unless canned_responses[uri]
      
      # we have some stubbing todo 
      s_resource = StubbedResourceProxy.new(resource, canned_responses[uri])
      return s_resource
    end
    alias [] resource

    # Returns the representation of the resource indicated by +uri+.
    # This is identical to +resource(uri).get_body(options)+
    def get_body(uri, options = {})
      resource(uri).get_body(options)
    end
    
    # Sets up a canned response for a particular HTTP request.  Once
    # this stub is configured all matching HTTP requests will return
    # the canned response rather than actual HTTP request. This is
    # intended primarily for testing purposes.
    def stub_request(method, uri, response_mime_type, response_body)
      raise ArgumentError, "Only GETs can be stubbed" unless method == :get
      
      (canned_responses[uri] ||= []) << {:mime_type => response_mime_type, :body => response_body}
    end
    
    protected
    
    def canned_responses
      @canned_responses ||= {}
    end
    
  end
end
