require 'net/http'
require 'advanced_http/errors'
require 'httpauth'

module AdvancedHttp
  
  # Raised to indicate that the attempted request failed in some way.
  # Details should be retrieved from the +Net::HTTPResponse+ object in
  # the +response+ attribute.
  class RequestFailed < Exception
    attr_reader :request, :response
    
    def initialize(request, response, message)
      super(message)
      
      @response = response
      @request = request
    end
  end
  
  class RequestRedirected < RequestFailed
  end

  class ServerError < RequestFailed
  end

  class ClientError < RequestFailed
  end
  
  class AuthenticationRequiredError < ClientError
  end
  
  # Raised to indicate that the scheme of a particular URI is not
  # supported.
  class UnsupportedUriSchemeError < Exception
  end
  
  # Raised to indicate that the URI that was passed does not match the
  # service proxy to which it was passed.
  class ServiceUriMismatchError < Exception
  end

  # HttpServiceProxy object represent a single logical HTTP server.
  # This class handles (or will someday handle) the mechanics of
  # connection reuse, pooling, etc.
  class HttpServiceProxy
    def initialize(host_name_or_id_addr, port)
      @http_conn = Net::HTTP.new(host_name_or_id_addr, port)
    end
    
    # Makes a get request for the resource indicated by +a_uri+ on the
    # HTTP service this class represents.
    #
    # Options
    #
    #  +:accept+::
    #    List of acceptable representations, specified as mime-types.
    #  +:account+::
    #    The name of the account on the server if using auth (only valid 
    #    in combination with password)
    #  +:password+::
    #    The password for the account if using auth  (only valid in 
    #    combination with account)
    #  +:digest_challenge+::
    #    The digest auth challenge to use when generated the Digest 
    #    authorization credentials  (only valid in combination with 
    #    account and password).
    #
    def get(a_uri, options = {})
      options = options.clone
      a_uri = http_uri(a_uri)

      request = Net::HTTP::Get.new(a_uri.request_uri)
      handle_accept_opt(request, options)
      handle_auth_opts(request, options)

      raise ArgumentError, "Unrecognized option(s) #{options.keys.join(', ')}" unless options.empty?
      
      do_request(request)
    end
    
    
    # Makes a Post request to the resource indicated by +a_uri+ on the
    # HTTP service this class represents.  The body of the request
    # will be +body+ and Content-Type will be +mime_type+.
    #
    # Options
    #
    #  +:accept+::
    #    List of acceptable representations, specified as mime-types.
    #  +:account+::
    #    The name of the account on the server if using auth (only valid 
    #    in combination with password)
    #  +:password+::
    #    The password for the account if using auth  (only valid in 
    #    combination with account)
    #  +:digest_challenge+::
    #    The digest auth challenge to use when generated the Digest 
    #    authorization credentials  (only valid in combination with 
    #    account and password).
    #
    def post(a_uri, body, mime_type, options = {})
      options = options.clone
      a_uri = http_uri(a_uri)
      
      request = Net::HTTP::Post.new(a_uri.request_uri)
      request['content-type'] = mime_type.to_str
      handle_accept_opt(request, options)
      handle_auth_opts(request, options)

      raise ArgumentError, "Unrecognized option(s) #{options.keys.join(', ')}" unless options.empty?
      
      do_request(request, body)
    end 

    # Makes a Put request to the resource indicated by +a_uri+ on the
    # HTTP service this class represents.  The body of the request
    # will be +body+ and Content-Type will be +mime_type+.
    #
    # Options
    #
    #  +:accept+::
    #    List of acceptable representations, specified as mime-types.
    #  +:account+::
    #    The name of the account on the server if using auth (only valid 
    #    in combination with password)
    #  +:password+::
    #    The password for the account if using auth  (only valid in 
    #    combination with account)
    #  +:digest_challenge+::
    #    The digest auth challenge to use when generated the Digest 
    #    authorization credentials  (only valid in combination with 
    #    account and password).
    #
    def put(a_uri, body, mime_type, options = {})
      options = options.clone
      a_uri = http_uri(a_uri)
      
      request = Net::HTTP::Put.new(a_uri.request_uri)
      request['content-type'] = mime_type.to_str
      handle_accept_opt(request, options)
      handle_auth_opts(request, options)

      raise ArgumentError, "Unrecognized option(s) #{options.keys.join(', ')}" unless options.empty?
      
      do_request(request, body)
    end 

    
    protected
    
    def handle_accept_opt(request, options)
      if accept = options.delete(:accept)
        request.delete('accept')
        [accept].flatten.each do |mt|
          request.add_field('accept', mt.to_str)
        end
      end
    end
    
    def handle_auth_opts(request, options)
      challenge = options.delete(:digest_challenge)
      account = options.delete(:account)
      password = options.delete(:password)
      
      if challenge and account and password
        request.digest_auth(account, password, challenge)
        
      elsif challenge
        # missing account or password
        raise(ArgumentError, 
              "The :digest_challenge option is only valid if :account and :password options are also specified")

      elsif account and password
        request.basic_auth(account, password)
        
      elsif account or password
        raise(ArgumentError, "The :account and :password options only valid if they are both specified")
      end
      # the authorization header is populated correctly
    end
    
    # Finishes populating +request+ based on the options passed
    #
    # Options
    #
    #  +:accept+::
    #    List of acceptable representations, specified as mime-types.
    #  +:account+::
    #    The name of the account on the server if using auth (only valid 
    #    in combination with password)
    #  +:password+::
    #    The password for the account if using auth  (only valid in 
    #    combination with account)
    #  +:digest_challenge+::
    #    The digest auth challenge to use when generated the Digest 
    #    authorization credentials  (only valid in combination with 
    #    account and password).
    #
    def build_request(request, options = {})
      invalid_options = (options.keys - [:accept, :account, :password, :digest_challenge])
      raise ArgumentError, "Unrecognized option(s) #{invalid_options.join(', ')}" unless invalid_options.empty?

      if accept = options[:accept]
        request.delete('accept')
        [accept].flatten.each do |mt|
          request.add_field('accept', mt.to_str)
        end
      end
      # Accept header is populated correctly
      
      if challenge = options[:digest_challenge]
        raise ArgumentError, "The :digest_challenge option is only valid if :account and :password options are also specified" unless options[:account] and options[:password]
        request.digest_auth(options[:account], options[:password], challenge)
        
      elsif options[:account] or options[:password]
        raise ArgumentError, "The :account and :password options only valid if they are both specified" unless options[:account] and options[:password]
        request.basic_auth(options[:account], options[:password])
        
      end
      # the authorization header is populated correctly
      
     request 
    end
    
    # Makes the request against the server.  If the response indicates
    # success the response is returned, otherwise an exception is
    # raised indicating the exact failure.
    def do_request(request, body = nil)
      resp = @http_conn.request(request, body)

      case resp
      when Net::HTTPSuccess
        return resp
      when Net::HTTPRedirection
        raise RequestRedirected.new(request, resp, "Request redirected to '#{resp['location']}' (#{resp.message})")
      when Net::HTTPServerError
        raise ServerError.new(request, resp, "An error occured on the server (#{resp.message})")
      when Net::HTTPUnauthorized
        raise AuthenticationRequiredError.new(request, resp, "Authentication is required to access the resource")
      when Net::HTTPClientError
        raise ClientError.new(request, resp, "There was a problem with the request (#{resp.message})")
      end
    end
    
    # Converts +a_uri+ into an URI object
    def http_uri(a_uri)
      a_uri = self.class.send(:http_uri, a_uri)
      
      raise ServiceUriMismatchError, "This service does not provide the resource indicated by #{a_uri}" unless
        a_uri.host == @http_conn.address and a_uri.port == @http_conn.port and 
        @http_conn.use_ssl? == (a_uri.scheme == 'https')
      
      a_uri
    end 

    class << self
      protected :new
      
      # Returns an HTTP service proxy that can be used to access the
      # resource indicated by +a_uri+
      def for(a_uri)
        a_uri = http_uri(a_uri)
        
        new(a_uri.host, a_uri.port)
      end
      
      protected
      # Converts +a_uri+ into an URI object
      def http_uri(a_uri)
        a_uri = URI.parse(a_uri.to_s)
        
        raise UnsupportedUriSchemeError, "Don't know how to deal with '#{a_uri.scheme}' URIs" unless 
          a_uri.scheme == 'http' or a_uri.scheme == 'https'
        
        # we have a usable URI
        a_uri
      end 
    end
    

  end
end
