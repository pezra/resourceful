require 'advanced_http/resource'
require 'advanced_http/stubbed_resource_proxy'

module AdvancedHttp
  
  # This class provides a simple interface to the functionality
  # provided by the AdvancedHttp library.  Conceptually this object
  # acts a collection of all the resources available via HTTP.
  class HttpAccessor
   
    # The authentication_info_provider which is used to acquire
    # the account and password to use if a request required
    # authentication.
    attr_accessor :authentication_info_provider

    # A logger object to which messages about the activities of this
    # object will be written.  This should be an object that responds
    # to +#info(message)+ and +#debug(message)+.  
    #
    # Errors will not be logged.  Instead an exception will be raised
    # and the application code should log it if appropriate.
    attr_accessor :logger
    
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
      
      self.authentication_info_provider = options.delete(:authentication_info_provider)
      self.logger = options.delete(:logger)
      
      raise ArgumentError, "Unrecognized option(s): #{options.keys.join(', ')}" unless options.empty?
      
      self.logger.debug("No authentication information provided.") if logger and not authentication_info_provider
    end

    # Returns a resource object representing the resource indicated
    # +uri+.  A resource object will be created if necessary.
    def resource(uri)
      resource = Resource.new(uri, :auth_info => authentication_info_provider, :logger => logger)
      return resource unless canned_responses[uri]
      
      # we have some stubbing todo 
      s_resource = StubbedResourceProxy.new(resource)
      s_resource.stub_get(canned_responses[uri][:mime_type], canned_responses[uri][:body])
      return s_resource
    end
    alias [] resource
    
    # Sets up a canned response for a particular HTTP request.  Once
    # this stub is configured all matching HTTP requests will return
    # the canned response rather than actual HTTP request. This is
    # intended primarily for testing purposes.
    def stub_request(method, uri, response_mime_type, response_body)
      raise ArgumentError, "Only GETs can be stubbed" unless method == :get
      
      canned_responses[uri] = {:mime_type => response_mime_type, :body => response_body}
    end
    
    protected
    
    def canned_responses
      @canned_responses ||= {}
    end
  end
end
