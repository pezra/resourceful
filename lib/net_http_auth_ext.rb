require 'net/http'
require 'httpauth'
require 'uri'

Net::HTTPUnauthorized.module_eval do

  # Indicates if the server provided a Digest auth challenge.
  def digest_auth_allowed?
    get_fields('www-authenticate').any?{|challenge| challenge =~ /^Digest /i}
  end 

  # Indicates if the server provided a Basic auth challenge.
  def basic_auth_allowed?
    get_fields('www-authenticate').any?{|challenge| challenge =~ /^Basic /i}    
  end
  
  # Extracts an returns an HTTPAuth::Digest::Challenge object
  # representing the Digest challenge provided by the server.
  def digest_challenge
    HTTPAuth::Digest::Challenge.from_header(get_fields('www-authenticate').find{|challenge| challenge =~ /^Digest /i}) if digest_auth_allowed?
  end
  
  def realm
    if digest_auth_allowed?
      digest_challenge.realm
    elsif basic_auth_allowed?
      HTTPAuth::Basic.unpack_challenge(get_fields('www-authenticate').find{|challenge| challenge =~ /^Basic /i})
    end
  end
end 

Net::HTTPRequest.module_eval do 
  # Set the Authorization: header for "Digest" authorization.
  def digest_auth(account, password, challenge)
    self['Authorization'] = 
      HTTPAuth::Digest::Credentials.from_challenge(challenge,
                                                   :username => account, 
                                                   :password => password, 
                                                   :method => method,
                                                   :uri => path).to_header
  end

  def authenticating?
    (self['Authorization'] || @partial_credentials) ? true : false
  end
end


