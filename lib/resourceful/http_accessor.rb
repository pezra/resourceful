require 'net/http'

require 'resourceful/options_interpreter'
require 'resourceful/authentication_manager'
require 'resourceful/cache_manager'
require 'resourceful/resource'
require 'resourceful/stubbed_resource_proxy'
require 'resourceful/rd_http_adapter'

module Resourceful
  # This is an imitation Logger used when no real logger is
  # registered.  This allows most of the code to assume that there
  # is always a logger available, which significantly improved the
  # readability of the logging related code.
  class BitBucketLogger
    def warn(*args); end
    def info(*args); end
    def debug(*args); end
  end

  # This is the simplest logger. It just writes everything to STDOUT.
  class StdOutLogger
    def warn(*args); puts args; end
    def info(*args); puts args; end
    def debug(*args); puts args; end
  end
  
  # This class provides a simple interface to the functionality
  # provided by the Resourceful library.  Conceptually this object
  # acts a collection of all the resources available via HTTP.
  class HttpAccessor
    
    ##
    # A logger object to which messages about the activities of this
    # object will be written.  This should be an object that responds
    # to +#info(message)+ and +#debug(message)+.  
    #
    # Errors will not be logged.  Instead an exception will be raised
    # and the application code should log it if appropriate.
    attr_accessor :logger

    ##
    attr_accessor :cache_manager
    
    ##
    # 
    attr_reader :auth_manager
    
    ##
    # List of all User-Agent tokens that will be included in requests made by this accessor.
    attr_reader :user_agent_tokens  

    ##
    # The adapter this accessor will use to make the actual HTTP requests.
    attr_reader :http_adapter


    INIT_OPTIONS = OptionsInterpreter.new do 
      option(:logger, :default => BitBucketLogger.new)
      option(:user_agent, :default => []) {|ua| [ua].flatten}
      option(:cache_manager, :default => NullCacheManager.new)
      option(:authenticator)
      option(:authenticators, :default => [])
      option(:http_adapter, :default => lambda{NetHttpAdapter.new})
    end
    
    # Initializes a new HttpAccessor.  Valid options:
    #
    #  +:logger+
    #  : A Logger object that the new HTTP accessor should
    #    send log messages
    #
    #  +:user_agent+
    #  : One or more additional user agent tokens to
    #    added to the user agent string.
    #
    #  +:cache_manager+
    #  : The cache manager this accessor should use.
    #
    #  +:authenticator+
    #  : Add a single authenticator for this accessor.
    #
    #  +:authenticators+
    #  : Enumerable of the authenticators for this accessor.
    #
    #  +:http_adapter+
    #  : The AbstractHttpAdapter the new accessor should use to access the network.
    def initialize(options = {})
      @user_agent_tokens = [RESOURCEFUL_USER_AGENT_TOKEN]
      
      INIT_OPTIONS.interpret(options) do |opts|
        @user_agent_tokens.push(*opts[:user_agent].reverse)
        self.logger = opts[:logger]
        @auth_manager = AuthenticationManager.new()
        @cache_manager = opts[:cache_manager]
        @http_adapter = opts[:http_adapter]
        
        add_authenticator(opts[:authenticator]) if opts[:authenticator]
        opts[:authenticators].each { |a| add_authenticator(a) }
      end     
    end
    
    # Returns the string that identifies this HTTP accessor.  If you
    # want to add a token to the user agent string simply add the new
    # token to the end of +#user_agent_tokens+.
    def user_agent_string
      user_agent_tokens.reverse.join(' ')
    end
    
    # Returns a resource object representing the resource indicated
    # by the specified URI.  A resource object will be created if necessary.
    def resource(uri, opts = {})
      resource = Resource.new(self, uri, opts)
    end
    alias [] resource

    # Adds an Authenticator to the set used by the accessor.
    def add_authenticator(an_authenticator)
      auth_manager.add_auth_handler(an_authenticator)
    end
  end
end
