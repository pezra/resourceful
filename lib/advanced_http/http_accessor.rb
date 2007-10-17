require 'advanced_http/resource'

module AdvancedHttp
  
  # This class provides a simple interface to the functionality
  # provided by the AdvancedHttp library.
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
      self.authentication_info_provider = options[:authentication_info_provider]
      self.logger = options[:logger]
    end

    # Returns a resource object representing the resource indicated
    # +uri+.  A resource object will be created if necessary.
    def resource(uri)
      Resource.new(uri, :auth_info => authentication_info_provider, :logger => logger)
    end
    alias [] resource
    
  end
end
