 require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/authentication_manager'

module Resourceful
  describe DigestAuthRealm, '#initialize(unauthorized_response, request_uri, auth_info_provider)' do
    def digest_challange_with_domain
      "Digest opaque=\"f9881f17cd67311b1d79abd587675d6e\", nonce=\"MjAwNy0xMC0wMyAwNDoxMjowMDo1NjcyMDk6NTcxMWZmMTEzMGRlMTI1OTNkNjY2NDdmYzFiOTA0Nj\", realm=\"SystemShepherd\", qop=\"auth\", algorithm=MD5-sess, domain=\"/bar http://baz.example/foo\""
    end

    def digest_challange_without_domain
      "Digest opaque=\"f9881f17cd67311b1d79abd587675d6e\", nonce=\"MjAwNy0xMC0wMyAwNDoxMjowMDo1NjcyMDk6NTcxMWZmMTEzMGRlMTI1OTNkNjY2NDdmYzFiOTA0Nj\", realm=\"SystemShepherd\", qop=\"auth\", algorithm=MD5-sess"
    end
    
    before do
      @unauth_response = Net::HTTPUnauthorized.new('1.1', '401', 'Unauthorized') 
      @unauth_response['WWW-Authenticate'] = digest_challange_with_domain
      @example_uri = Addressable::URI.parse('http://foo.example/bar')
      @auth_info_provider = mock('auth_info_provider', :authentication_info => ['me', 'mine'])
      
      @realm = DigestAuthRealm.new(@unauth_response, @example_uri, @auth_info_provider)
    end
    
    it 'should extract the realm from the challenge ' do
      @realm.name.should == 'SystemShepherd'
    end 
 
    it 'should populated domain from the domain directive in the challenge, when there is one' do
      @unauth_response['WWW-Authenticate'] = digest_challange_with_domain
      @realm = DigestAuthRealm.new(@unauth_response, @example_uri, @auth_info_provider)

      @realm.domain.should include(Addressable::URI.parse('http://foo.example/bar'))
      @realm.domain.should include(Addressable::URI.parse('http://baz.example/foo'))
                                   
      @realm.domain.should have(2).items
    end

    it 'should populated domain with the root of the request_uri domain, when challenge does not include domain directive' do
      @unauth_response['WWW-Authenticate'] = digest_challange_without_domain
      @realm = DigestAuthRealm.new(@unauth_response, @example_uri, @auth_info_provider)

      @realm.domain.should include(Addressable::URI.parse('http://foo.example/'))
      @realm.domain.should have(1).items
    end
    
    it 'should raise error if no credentials are known for this realm' do
      @auth_info_provider.stub!(:authentication_info).and_return(nil)
      
      lambda{
        DigestAuthRealm.new(@unauth_response, @example_uri, @auth_info_provider)
      }.should raise_error(Resourceful::NoAuthenticationCredentialsError, "No authentication credentials are known for the SystemShepherd realm")
    end
    
    it 'should get authentication info' do
      @auth_info_provider.should_receive(:authentication_info).with('SystemShepherd').and_return(['me', 'mine'])
      
      DigestAuthRealm.new(@unauth_response, @example_uri, @auth_info_provider)
    end 
    
    it 'should raise error is unauth response does not include digest challenge' do
      @unauth_response['WWW-Authenticate'] = 'Basic realm="SystemShepherd"'

      lambda {
        DigestAuthRealm.new(@unauth_response, @example_uri, @auth_info_provider)
      }.should raise_error(ArgumentError, "unauthorized_response does not include a Digest authentication scheme challenge")
    end 
  end
  
  describe DigestAuthRealm, '#includes?(a_uri)' do 
    before do
      @unauth_response = Net::HTTPUnauthorized.new('1.1', '401', 'Unauthorized') 
      @unauth_response['WWW-Authenticate'] = "Digest opaque=\"f9881f17cd67311b1d79abd587675d6e\", nonce=\"MjAwNy0xMC0wMyAwNDoxMjowMDo1NjcyMDk6NTcxMWZmMTEzMGRlMTI1OTNkNjY2NDdmYzFiOTA0Nj\", realm=\"SystemShepherd\", qop=\"auth\", algorithm=MD5-sess, domain=\"/bar http://baz.example/foo\""
      @example_uri = Addressable::URI.parse('http://foo.example/bar')
      @auth_info_provider = mock('auth_info_provider', :authentication_info => ['me', 'mine'])

      @realm = DigestAuthRealm.new(@unauth_response, @example_uri, @auth_info_provider)      
    end
    
    it 'should be true if specified URI is one of the domain URIs' do
      @realm.includes?(Addressable::URI.parse('http://foo.example/bar')).should be_true
      @realm.includes?(Addressable::URI.parse('http://baz.example/foo')).should be_true
    end
    
    it 'should be true if the specified is below one of the domain URIs' do
      @realm.includes?(Addressable::URI.parse('http://foo.example/bar/baz')).should be_true
      @realm.includes?(Addressable::URI.parse('http://baz.example/foo/bar')).should be_true
    end 
    
    it 'should be false if specified URI is not below any of the domain URIs' do
      @realm.includes?(Addressable::URI.parse('http://bar.example/bar')).should be_false
    end
  end
  
  describe DigestAuthRealm, '.credentials_for(a_request)' do
    before do
      @unauth_response = Net::HTTPUnauthorized.new('1.1', '401', 'Unauthorized') 
      @unauth_response['WWW-Authenticate'] = "Digest opaque=\"f9881f17cd67311b1d79abd587675d6e\", nonce=\"MjAwNy0xMC0wMyAwNDoxMjowMDo1NjcyMDk6NTcxMWZmMTEzMGRlMTI1OTNkNjY2NDdmYzFiOTA0Nj\", realm=\"SystemShepherd\", qop=\"auth\", algorithm=MD5-sess, domain=\"/bar http://baz.example/foo\""
      @example_uri = Addressable::URI.parse('http://foo.example/bar')
      @auth_info_provider = mock('auth_info_provider', :authentication_info => ['me', 'mine'])
      
      @realm = DigestAuthRealm.new(@unauth_response, @example_uri, @auth_info_provider)      
    end
    
    it 'should return a credentials string suitable for placing in the Authorization header field of a_request' do
      creds = @realm.credentials_for(Net::HTTP::Get.new('/foo/bar'))
      
      creds.should match(/^Digest/)
      creds.should match(/uri="\/foo\/bar"/)
      creds.should match(/response=/)
    end
  end 
end
  
describe Resourceful::AuthenticationManager, '.new(auth_info_provider)' do 
  it 'should return a new authentication manager' do
    @auth_info_provider = mock('auth_info_provider')
    Resourceful::AuthenticationManager.new(@auth_info_provider).should be_instance_of(Resourceful::AuthenticationManager)
  end 
end


describe Resourceful::AuthenticationManager, '#register_challenge(unauthorized_http_response, request_uri)' do
  before do
    @example_uri = Addressable::URI.parse('http://foo.example/bar')
    @auth_info_provider = mock('auth_info_provider', :authentication_info => ['me', 'mine'])
    @auth_manager = Resourceful::AuthenticationManager.new(@auth_info_provider)
    
    @unauth_response = mock('unauth_http_response', :code => '401', :get_fields => ["Digest opaque=\"f9881f17cd67311b1d79abd587675d6e\", nonce=\"MjAwNy0xMC0wMyAwNDoxMjowMDo1NjcyMDk6NTcxMWZmMTEzMGRlMTI1OTNkNjY2NDdmYzFiOTA0Nj\", realm=\"SystemShepherd\", qop=\"auth\", algorithm=MD5-sess, domain=\"/bar http://baz.example/foo\""])
  end
  
  it 'should take an unauthorized http response and canonical URI of the resource that generated the response' do
    @auth_manager.register_challenge(@unauth_response, @example_uri)
  end 
  
  it 'should know it has authentication information for the URI after the challenge is registered' do 
    lambda {
      @auth_manager.register_challenge(@unauth_response, @example_uri)
    }.should change{@auth_manager.auth_info_available_for?(@example_uri)}.from(false).to(true)
  end 
end

describe Resourceful::AuthenticationManager, '#credentials_for(uri)' do
  before do
    @example_uri = Addressable::URI.parse('http://foo.example/bar')
    @auth_info_provider = mock('auth_info_provider', :authentication_info => ['me', 'mine'])
    @auth_manager = Resourceful::AuthenticationManager.new(@auth_info_provider)
    
    @unauth_response = mock('unauth_http_response', :code => '401', :get_fields => ["Digest opaque=\"f9881f17cd67311b1d79abd587675d6e\", nonce=\"MjAwNy0xMC0wMyAwNDoxMjowMDo1NjcyMDk6NTcxMWZmMTEzMGRlMTI1OTNkNjY2NDdmYzFiOTA0Nj\", realm=\"SystemShepherd\", qop=\"auth\", algorithm=MD5-sess, domain=\"/bar http://baz.example/foo\""])
    @auth_manager.register_challenge(@unauth_response, @example_uri)
    @request = mock('http_request', :method => 'GET', :path => '/bar')
  end
  
  it 'should return credentials suitable of setting to WWW-Authenticate header field' do
    creds = @auth_manager.credentials_for(@request, @example_uri)
      
    creds.should match(/^Digest/)
    creds.should match(/uri="\/bar"/)
    creds.should match(/response=/)
  end 

  it 'should raise error if the request is for a resource that is not in any known realm' do
    lambda{
      @auth_manager.credentials_for(@request, Addressable::URI.parse('http://some-other-domain.example/bar'))
    }.should raise_error(Resourceful::NoAuthenticationRealmInformationError)
  end 
  
end
