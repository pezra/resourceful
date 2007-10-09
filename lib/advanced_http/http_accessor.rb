require 'advanced_http/http_service_proxy'
require 'net_http_auth_ext'

module AdvancedHttp
  
  # Interface for an object that can provide user names and passwords
  # for HTTP authentication.
  class AbstraceAuthenicationInfoProvider
    # Returns an array containing the account name and password
    # (+[account, password]+) to be used to authenticate at the
    # specified realm.  If no authentication information is known for
    # the specified realm +nil+ should be returned.
    def authentication_info(realm)
      raise NotImplementedError
    end
  end
  
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
    
    # Initializes a new HttpAccessor.  If
    # +authentication_info_provider+ is provided it will be use to get
    # authentication information for requests that require it.
    def initialize(authentication_info_provider = nil, logger = nil)
      self.authentication_info_provider = authentication_info_provider
      self.logger = logger
    end
    
    # Makes a GET request to the resource indicated by +a_uri+ and
    # returns the resulting Net::HTTPResponse.
    #
    # Options
    #  +:accept+::
    #    A MIME type, or set of MIME types, that are acceptable for 
    #    the server use as the representation of the resource
    #    indicated by +a_uri+.  If not specified '*/*' is used.
    def get(a_uri, options = {})
      proxy = HttpServiceProxy.for(a_uri)
      begin
        log(:info, "GET #{a_uri} (#{[options[:accept] || '*/*'].flatten.compact.join(',')})")
        proxy.get(a_uri, options)
        
      rescue AuthenticationRequiredError => e
        if auth_opts = figure_auth_opts(e.response)
          # retry with authorization...
          log(:info, "GET #{a_uri} (#{[options[:accept] || '*/*'].flatten.compact.join(',')}) (Auth: type=#{auth_opts[:digest_challenge] ? 'digest':'basic'}, realm='#{e.response.realm}', account='#{auth_opts[:account]}')")
          proxy.get(a_uri, options.merge(auth_opts))
        else
          # not enough info to authenticate
          raise e
        end
        # retry with authorization...
      end
    end
    
    # Makes a POST request to the specified resources with the
    # specified body and returns the resulting Net::HTTPResponse.
    #
    # Options
    #  +:accept+::
    #    A MIME type, or set of MIME types, that are acceptable for 
    #    the server use as the representation of the resource
    #    indicated by +a_uri+.  If not specified '*/*' is used.
    def post(a_uri, body, mime_type, options={})
      proxy = HttpServiceProxy.for(a_uri)
      begin
        log(:info, "POST #{a_uri} (content-type: #{mime_type})")
        proxy.post(a_uri, body, mime_type, options)
        
      rescue AuthenticationRequiredError => e
        if auth_opts = figure_auth_opts(e.response)
          # retry with authorization...
          log(:info, "POST #{a_uri} (content-type: #{mime_type}) (Auth: type=#{auth_opts[:digest_challenge] ? 'digest':'basic'}, realm='#{e.response.realm}', account='#{auth_opts[:account]}')") 
          proxy.post(a_uri, body, mime_type, options.merge(auth_opts))
                       
        else
          # not enough info to authenticate
          raise e
        end
      end
    end
    
    # Makes a PUT request to the specified resources with the
    # specified body and returns the resulting Net::HTTPResponse.
    def put(a_uri, body)
      raise NotImplementedError
    end
    
    # Makes a DELETE request to the resource indicated by +a_uri+ and
    # returns the resulting Net::HTTPResponse.
    def delete(a_uri)
      raise NotImplementedError
    end

    protected
    def auth_info_for(realm)
      authentication_info_provider.authentication_info(realm) unless authentication_info_provider.nil?
    end

    def figure_auth_opts(resp)
      account, password = auth_info_for(resp.realm)
      return nil unless account and password
      
      opts = { :account => account, :password => password}
      opts[:digest_challenge] = resp.digest_challenge if resp.digest_challenge      
      
      opts
    end

    # Log +message+ 
    def log(level, message)
      return unless logger
      
      case level
      when :info
        logger.info(message)
      when :debug
        logger.debug(message)
      end
    end
  end
end
