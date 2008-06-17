require 'httpauth'

module Resourceful

  class AuthenticationManager
    def initialize
      @authenticators = []
    end

    def add_auth_handler(authenticator)
      @authenticators << authenticator
    end

    def associate_auth_info(challenge)
      @authenticators.each do |authenticator|
        authenticator.update_credentials(challenge) if authenticator.valid_for?(challenge)
      end
    end

    def add_credentials(request)
      authenticator = @authenticators.find { |authenticator| authenticator.can_handle?(request) }
      authenticator.add_credentials_to(request) if authenticator
    end

  end

  class BasicAuthenticator

    def initialize(realm, username, password)
      @realm, @username, @password = realm, username, password
      @domain = nil
    end

    def valid_for?(challenge_response)
      begin
        realm = HTTPAuth::Basic.unpack_challenge(challenge_response.header['WWW-Authenticate'])
      rescue ArgumentError
        return false
      end
      realm == @realm
    end

    def update_credentials(challenge)
      @domain = Addressable::URI.parse(challenge.uri).host
    end

    def can_handle?(request)
      Addressable::URI.parse(request.uri).host == @domain
    end

    def add_credentials_to(request)
      request.header['Authorization'] = credentials
    end

    def credentials
      HTTPAuth::Basic.pack_authorization(@username, @password)
    end

  end

  class DigestAuthenticator

  end


end

