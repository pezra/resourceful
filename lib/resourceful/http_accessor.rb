require 'net/http'

require 'resourceful/version'
require 'resourceful/options_interpreter'
require 'resourceful/authentication_manager'
require 'resourceful/cache_manager'
require 'resourceful/resource'
require 'resourceful/stubbed_resource_proxy'

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
    RESOURCEFUL_USER_AGENT_TOKEN = "Resourceful/#{RESOURCEFUL_VERSION}(Ruby/#{RUBY_VERSION})"
    
    # A logger object to which messages about the activities of this
    # object will be written.  This should be an object that responds
    # to +#info(message)+ and +#debug(message)+.  
    #
    # Errors will not be logged.  Instead an exception will be raised
    # and the application code should log it if appropriate.
    attr_accessor :logger, :cache_manager
    
    attr_reader :auth_manager
    
    attr_reader :user_agent_tokens  
    
    INIT_OPTIONS = OptionsInterpreter.new do 
      option(:logger, :default => Resourceful::BitBucketLogger.new)
      option(:user_agent, :default => []) {|ua| [ua].flatten}
      option(:cache_manager, :default => NullCacheManager.new)
    end
    
    # Initializes a new HttpAccessor.  Valid options:
    #
    #  +:logger+:: A Logger object that the new HTTP accessor should
    #    send log messages
    #
    #  +:user_agent+:: One or more additional user agent tokens to
    #    added to the user agent string.
    def initialize(options = {})
      @user_agent_tokens = [RESOURCEFUL_USER_AGENT_TOKEN]
      
      INIT_OPTIONS.interpret(options) do |opts|
        @user_agent_tokens.push(*opts[:user_agent].reverse)
        self.logger = opts[:logger]
        @auth_manager = AuthenticationManager.new()
        @cache_manager = opts[:cache_manager]
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

  end
end
