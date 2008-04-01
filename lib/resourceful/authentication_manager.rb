require 'addressable/uri'
require 'net/http'
require 'httpauth'

require 'resourceful/exceptions'

module Resourceful
  class DigestAuthRealm
    attr_reader :name, :domain
    
    # Initialize a new AuthRealm.
    def initialize(unauthorized_http_response, request_uri, auth_info_provider)
      challenge_str = unauthorized_http_response.get_fields('www-authenticate').find{|challenge| challenge =~ /^Digest /i} ||
        raise(ArgumentError, "unauthorized_response does not include a Digest authentication scheme challenge")
      
      req_d_uri = request_uri.normalize
      req_d_uri.path = nil
      
      @domain = if domain_match = /domain="([^"]*)"/.match(challenge_str)
                  domain_match[1].split(/\s+/).map{|u| Addressable::URI.parse(u).normalize}.map{|u| u.relative? ? req_d_uri + u : u}
                else
                  [req_d_uri]
                end
      
      challenge_str = challenge_str.gsub(/domain="([^"]*)"(,\s*)?/, '').gsub(/,\s*$/, '')
      # we remove the domain directive from the challenge str
      # because HTTPAuth::Digest::Challenge has a bug regarding
      # domain parsing.
      
      @challenge = HTTPAuth::Digest::Challenge.from_header(challenge_str)
      
      @name = @challenge.realm
      @username, @password = auth_info_provider.authentication_info(name) || 
        raise(NoAuthenticationCredentialsError, "No authentication credentials are known for the #{name} realm")
    end
    
    # Indicates if this authenication realm includes the specified URI
    def includes?(a_uri)
      a_uri = a_uri.normalize
      path_pattern = Regexp.new('^' + a_uri.path)
      
      domain.any? do |domain_uri| 
        (domain_uri.host == a_uri.host) && (domain_uri.port == a_uri.port) && 
          (a_uri.path[0,domain_uri.path.length] == domain_uri.path)
      end
    end
    
    # Returns a credentials string suitable for placing in the
    # Authorization header of a_request.
    def credentials_for(a_request)
      HTTPAuth::Digest::Credentials.from_challenge(challenge,
                                                   :username => username, 
                                                   :password => password, 
                                                   :method => a_request.method,
                                                   :uri => a_request.path).to_header
    end

    private
    
    attr_reader :challenge, :username, :password
  end

  
  # Manages authentication across multiple realms for a single
  # Resourceful::HttpAccessor.
  class AuthenticationManager
      
    # Initializes a newly created AuthenticationManager.
    def initialize(auth_info_provider)
      @auth_info_provider = auth_info_provider
      @realms = []
    end
    
    # Registers an authentication challenge for use in future
    # authentications.
    def register_challenge(unauthorized_http_response, uri)
      @realms.unshift(build_auth_realm(unauthorized_http_response, uri, auth_info_provider))
    end
    
    # Indicates if there is currently enough information available to
    # generate authentication credentials for a request of +a_uri+.
    def auth_info_available_for?(a_uri)
      @realms.any?{|r| r.includes?(a_uri)}
    end

    # Returns authentication credentials for a +an_http_request+ to
    # +a_uri+.
    def credentials_for(an_http_request, a_uri)
      realm = @realms.find{|r| r.includes?(a_uri)} || 
        raise(NoAuthenticationRealmInformationError, "#{a_uri} is not included any any known authentication realm.")
      
      realm.credentials_for(an_http_request)
    end
    
    private
    
    attr_reader :auth_info_provider, :realms

    def build_auth_realm(unauthorized_response, request_uri, auth_info_provider)
      schemes = unauthorized_response.get_fields('www-authenticate').map{|chal| chal[/\w+/]}
      
      if schemes.map{|s| s.downcase}.include?('digest')
        DigestAuthRealm.new(unauthorized_response, request_uri, auth_info_provider)
      else
        raise UnsupportedAuthenticationSchemeError, "#{schemes.join(', ')} authentication is not supported"
      end
    end

  end
end
