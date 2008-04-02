require 'net/http'
require 'benchmark'
require 'addressable/uri'
require 'resourceful/exceptions'
require 'set'
require 'resourceful/options_interpreter'

module Resourceful

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

  # A resource object represents a single resource on the World Wide
  # Web.  It is identified by one or more URIs and allows the normal
  # HTTP methods to be performed on the resource.
  class Resource
    attr_reader :uri, :owner
    
    # Initialize a newly created resource object.  +owner+ is the
    # HttpAccessor that owns the new resource.
    def initialize(owner, uri)
      @owner = owner
      @alternate_uris = Set.new
      
      self.uri = uri
    end
    
    # Gets a representation of the resource this object represents and
    # returns the representation and associated meta-data (HTTP
    # headers, etc).  This method will follow redirect when
    # appropriate. If successful an HTTPResponse will be
    # returned.
    #
    # Options 
    #
    #  +:accept+:: A MIME type, or array of MIME types, that are
    #    acceptable as the formats for the response.  Anything object
    #    that responds to +#to_str+ will work as a mime type.
    #
    #  +:max_redirects+:: The maximum number of redirect responses to
    #    follow before giving up.
    #
    #  +:ignore_redirects+:: Rather than following redirects simply
    #    return the redirect response.
    #
    #  +:http_header_fields+:: Hash of HTTP header fields to include
    #    in the request.
    def get(options = {})
      opts = HTTP_REQUEST_OPTS_INTERPRETER.interpret(options)
      
      request = Net::HTTP::Get.new(effective_uri)
      request['Accept'] = opts[:accept] if opts.has_key?(:accept)
      opts[:http_header_fields].each do |name, value|
        request[name] = value
      end
      
      resp = do_request(request)
      
      case resp.code
      when /^2/
        return resp
        
      when /^30[127]/
        raise TooManyRedirectsError if opts[:max_redirects] and alternate_uris.size >  opts[:max_redirects]
        raise CircularRedirectionError if alternate_uris.include?(resp['location'])
        
        if resp.code == '301'
          self.uri = resp['location']
        else
          self.effective_uri = resp['location']
        end
        
        get options
        
      else
         raise HttpRequestError.new_from(request, resp, self)
      end 
      
    rescue Exception => e
      reset
      raise e
    end

    # Gets a representation of the resource this object represents.
    # This method will follow redirect when appropriate.  If the final
    # response is not a 200 OK this method will raise an exception.
    # If successful an HTTPResponse will be returned. 
    #
    # Options 
    #
    #  +:accept+:: A MIME type, or array of MIME types, that are
    #    acceptable as the formats for the response.  Anything object
    #    that responds to +#to_str+ will work as a mime type.
    #
    #  +:parse_as+:: Indicates that the return value should be the
    #    results of parsing the string representation.  The value of
    #    this option indicates what sort of parser should be used.
    #    Valid values are: +:json+.
    def get_body(options = {})
      options = options.dup
      parser = options.delete(:parse_as)
            
      body = get(options).body
      
      case parser
      when nil
        body
      when :json
        require 'json'
        JSON.parse(body)
      else        
        raise ArgumentError, "Unrecognized parser type #{parser}" unless parser.nil? or parser == :json
      end
    end
    
    # Deprecated.  Use `#get_body(:parse_as => :json)` instead.
    #
    # Returns the representation parses as a JSON document. 
    def get_json_body(options = {})
      get_body(options.merge(:parse_as => :json))
    end
        
    # Posts +data+ to this resource.  +mime_type+ is the MIME type of
    # +data+.  This method does *not* follow redirects, execpt for 303
    # See Other redirect.  In the case of a See Other response from
    # the post the redirection target will be gotten and that response
    # will be returned.
    #
    # Options 
    #
    #  +:accept+:: A MIME type, or array of MIME types, that are
    #    acceptable as the formats for the response.  Anything object
    #    that responds to +#to_str+ will work as a mime type.
    #
    #  +:max_redirects+:: The maximum number of redirect responses to
    #    follow before giving up.
    # 
    #  +:ignore_redirects+:: Rather than following redirects simply
    #    return the redirect response.
    #
    #  +:http_header_fields+:: Hash of HTTP header fields to include
    #    in the request.
    def post(data, mime_type, options = {})
      opts = HTTP_REQUEST_OPTS_INTERPRETER.interpret(options)
      
      req = Net::HTTP::Post.new(effective_uri)
      req['content-type'] = mime_type
      req['accept'] = opts[:accept] if opts.has_key?(:accept)
      opts[:http_header_fields].each do |name, value|
        req[name] = value
      end
      
      resp = do_request(req, data)

      case resp.code 
      when /^2\d\d$/
        return resp
        
      when '303'
        return resp if opts[:ignore_redirects] 
        
        alt_resource = Resource.new(resp['location'])
        alt_resource.get_response
        
      when /^30[127]$/
        raise TooManyRedirectsError if opts[:max_redirects] and alternate_uris.size >  opts[:max_redirects]
        raise CircularRedirectionError if alternate_uris.include?(resp['location'])
        
        return resp if opts[:ignore_redirects]
        
        if resp.code == '301'
          self.uri = resp['location']
        else
          self.effective_uri = resp['location']
        end
        
        post data, mime_type, options

      else
        # something went wrong...
        raise HttpRequestError.new_from(req, resp, self)
      end
    end

    # Puts +data+ to this resource.  +mime_type+ is the MIME type of
    # +data+.  This method does *not* follow redirects.  An Exception
    # will raised for any non-2xx response.
    #
    # Options 
    #
    #  +:accept+:: A MIME type, or array of MIME types, that are
    #    acceptable as the formats for the response.  Anything object
    #    that responds to +#to_str+ will work 
    #
    #  +:max_redirects+:: The maximum number of redirect responses to
    #    follow before giving up.
    # 
    #  +:ignore_redirects+:: Rather than following redirects simply
    #    return the redirect response.
    #
    #  +:http_header_fields+:: Hash of HTTP header fields to include
    #    in the request.
    def put(data, mime_type, options = {})
      opts = HTTP_REQUEST_OPTS_INTERPRETER.interpret(options)
      
      req = Net::HTTP::Put.new(effective_uri)
      req['content-type'] = mime_type
      req['accept'] = opts[:accept] if opts.has_key?(:accept)
      opts[:http_header_fields].each do |name, value|
        req[name] = value
      end
      
      resp = do_request(req, data)

      case resp.code 
      when /^2\d\d$/
        return resp
        
      when /^30[127]$/
        raise TooManyRedirectsError if opts[:max_redirects] and alternate_uris.size >  opts[:max_redirects]
        raise CircularRedirectionError if alternate_uris.include?(resp['location'])
        
        return resp if opts[:ignore_redirects]
        
        if resp.code == '301'
          self.uri = resp['location']
        else
          self.effective_uri = resp['location']
        end
        
        put data, mime_type, options

      else
        # something went wrong...
        raise HttpRequestError.new_from(req, resp, self)
      end
    end

    # Returns the current effective URI for this resource.  The
    # effective URI is either the URI specified when the resource was
    # created or the one reached by following one or more redirects.
    def effective_uri
      @effective_uri || @uri
    end
    

    # Clears all transient information about this resource.  For
    # example, this will cause the next call to get to fetch the URI
    # for this resource, rather than the effective URI.
    def reset
      @effective_uri = nil
      self.alternate_uris.clear
    end
    
    protected

    attr_reader :auth_info_provider
    attr_reader :alternate_uris
    
    def logger
      owner.logger
    end
    
    # Sets the effective URI for this resource.
    def effective_uri=(new_effective_uri)
      new_effective_uri = Addressable::URI.parse(new_effective_uri).normalize.to_s
      alternate_uris << new_effective_uri
      
      @effective_uri = new_effective_uri
    end
    
    # Sets the canonical URI for this resource.  This is generally
    # only used on new resources, or if a permanent redirect is
    # received.
    def uri=(new_uri)
      new_uri = Addressable::URI.parse(new_uri).normalize.to_s
      
      alternate_uris << new_uri
      @uri = new_uri
      @effective_uri = nil
    end
    
    # makes an HTTP request against the server that hosts this
    # resource and returns the HTTPResponse.
    def do_request(an_http_request, body = nil, is_auth_retry = false)
      an_http_request['User-Agent'] = owner.user_agent_string
      e_uri = Addressable::URI.parse(effective_uri)
      Net::HTTP.start(e_uri.host, e_uri.port) do |c|
 
        an_http_request['Authorization'] = auth_manager.credentials_for(an_http_request, e_uri) if auth_info_available?
        
        resp = nil
        bm = Benchmark.measure do 
          resp = c.request(an_http_request, body)
        end
        logger.info do
          msg = "#{an_http_request.method} #{effective_uri} (#{resp.code})"
          msg << " (#{format('%0.3f', bm.real)} sec)"
          msg << " (w/ auth credentials)" if an_http_request['Authorization']
        end
        logger.debug "  Authentication credentials: #{an_http_request['Authorization']}" if an_http_request['Authorization']
          
        
        if '401' == resp.code and not is_auth_retry         
          auth_manager.register_challenge(resp, e_uri)
          do_request(an_http_request, nil, true)  # retry it
        else
          resp
        end 
      end

    rescue => e
      logger.debug{"  #{an_http_request.method} #{effective_uri} failed with #{e.message}"}
      new_e = e.class.new(e.message + " (while #{an_http_request.method} #{effective_uri})")
      new_e.set_backtrace(e.backtrace)
      
      raise new_e
    end

    def auth_manager
      owner.auth_manager
    end
    
    def auth_info_available?
      auth_manager.auth_info_available_for?(Addressable::URI.parse(effective_uri))
    end

    def configure_request_from_options(request, options)
      options = options.clone
      
      if accept = options.delete(:accept)
        request['accept'] = [accept].flatten.map{|m| m.to_str}
      end
      
      return options
    end

    HTTP_REQUEST_OPTS_INTERPRETER = OptionsInterpreter.new do 
      option(:max_redirects)
      option(:ignore_redirects)
      option(:accept) {|accept| [accept].flatten.map{|m| m.to_str}}
      option(:http_header_fields, :default => {})
    end
  end
  
  
end

  
