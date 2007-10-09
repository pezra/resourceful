require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'advanced_http/http_accessor'

describe AdvancedHttp::HttpAccessor do 
  before do
    @accessor = AdvancedHttp::HttpAccessor.new
  end
  
  it 'should be instantiatable' do
    AdvancedHttp::HttpAccessor.new().should be_instance_of(AdvancedHttp::HttpAccessor)
  end 
  
  it 'should allow authentication information provider to be registered' do 
    @accessor.authentication_info_provider = mock('auth_info_provider')
  end 
end

describe AdvancedHttp::HttpAccessor, '#get()' do
  before do
    @ok_resp = Net::HTTPOK.new('1.1', '200', 'OK')
    @http_service_proxy = stub(:get => @ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    @accessor = AdvancedHttp::HttpAccessor.new
  end
  
  it 'should look up appropriate service proxy object' do
    AdvancedHttp::HttpServiceProxy.expects(:for).with('http://www.example/').returns(@http_service_proxy)
    
    @accessor.get('http://www.example/')
  end 

  it 'should use service proxy to get URI' do
    @http_service_proxy.expects(:get).with('http://www.example/')
    
    @accessor.get('http://www.example/')
  end 

  it 'should follow redirects'

  it 'should raise AuthenticationRequiredError if resource requires authentication and no appropriate auth info is known' do
    unauth_resp = mock(:realm => 'SystemShepherd')
    @http_service_proxy.expects(:get).with('http://www.example/').once.
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), unauth_resp, "Unauthorized"))
    
    lambda {
      @accessor.get('http://www.example/')
    }.should raise_error(AdvancedHttp::AuthenticationRequiredError)
  end 
end

describe AdvancedHttp::HttpAccessor, '#get() (digest authorization)' do
  before do
    @digest_challenge = stub('digest_challenge')
    @unauth_resp = stub(:realm => 'SystemShepherd', :digest_challenge => @digest_challenge)
    
    @ok_resp = Net::HTTPOK.new('1.1', '200', 'OK')
    
    @http_service_proxy = stub('http_service_proxy')
    @http_service_proxy.stubs(:get).with(instance_of(String)).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    @http_service_proxy.stubs(:get).with(instance_of(String), has_key(:account)).
      returns(@ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    
    @auth_info_provider = stub('auth_info_provider', :authentication_info => ['me', 'mine'])
    
    @accessor = AdvancedHttp::HttpAccessor.new(@auth_info_provider)
  end
  
  it 'should lookup auth info' do
    @auth_info_provider.expects(:authentication_info).with('SystemShepherd').returns(['me', 'mine'])
      
    @accessor.get('http://www.example/')
  end 

  it 'should retry requests with authorization upon unauthorized response' do 
    @http_service_proxy.expects(:get).with('http://www.example/').
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:get).
      with('http://www.example/', :account => 'me', :password => 'mine', :digest_challenge => @digest_challenge).
      returns(@ok_resp)
    
    @accessor.get('http://www.example/')
  end 
  
  it 'should raise AuthenticationRequiredError if credentials are rejected' do
    @http_service_proxy.expects(:get).
      with('http://www.example/', :account => 'me', :password => 'mine', :digest_challenge => @digest_challenge).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    lambda {
      @accessor.get('http://www.example/')
    }.should raise_error(AdvancedHttp::AuthenticationRequiredError)
      
  end 
end

describe AdvancedHttp::HttpAccessor, '#get() (authorization)' do
  before do
    @unauth_resp = stub(:realm => 'SystemShepherd', :digest_challenge => nil)
    
    @ok_resp = Net::HTTPOK.new('1.1', '200', 'OK')
    
    @http_service_proxy = stub('http_service_proxy')
    @http_service_proxy.stubs(:get).with(instance_of(String)).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    @http_service_proxy.stubs(:get).with(instance_of(String), has_key(:account)).
      returns(@ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    
    @auth_info_provider = stub('auth_info_provider', :authentication_info => ['me', 'mine'])
    
    @accessor = AdvancedHttp::HttpAccessor.new(@auth_info_provider)
  end
  
  it 'should lookup auth info' do
    @auth_info_provider.expects(:authentication_info).with('SystemShepherd').returns(['me', 'mine'])
      
    @accessor.get('http://www.example/')
  end 

  it 'should retry requests with authorization upon unauthorized response' do 
    @http_service_proxy.expects(:get).with('http://www.example/').
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:get).
      with('http://www.example/', :account => 'me', :password => 'mine').
      returns(@ok_resp)
    
    @accessor.get('http://www.example/')
  end 

  it 'should raise AuthenticationRequiredError if credentials are rejected' do
    @http_service_proxy.expects(:get).
      with('http://www.example/', :account => 'me', :password => 'mine').
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))

    lambda {
      @accessor.get('http://www.example/')
    }.should raise_error(AdvancedHttp::AuthenticationRequiredError)
  end 

end


describe AdvancedHttp::HttpAccessor, '#post()' do
  before do
    @ok_resp = Net::HTTPCreated.new('1.1', '201', 'Created')
    @http_service_proxy = stub(:post => @ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    @accessor = AdvancedHttp::HttpAccessor.new
  end
  
  it 'should look up appropriate service proxy object' do
    AdvancedHttp::HttpServiceProxy.expects(:for).with('http://www.example/').returns(@http_service_proxy)
    
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should use service proxy to post URI' do
    @http_service_proxy.expects(:post).with('http://www.example/', "foo=bar", 'application/x-form-urlencoded')
    
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should follow redirects'

  it 'should raise AuthenticationRequiredError if resource requires authentication and no appropriate auth info is known' do
    unauth_resp = mock(:realm => 'SystemShepherd')
    @http_service_proxy.expects(:post).once.
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), unauth_resp, "Unauthorized"))
    
    lambda {
      @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::AuthenticationRequiredError)
  end 
end

describe AdvancedHttp::HttpAccessor, '#post() (digest authorization)' do
  before do
    @digest_challenge = stub('digest_challenge')
    @unauth_resp = stub(:realm => 'SystemShepherd', :digest_challenge => @digest_challenge)
    
    @ok_resp = Net::HTTPOK.new('1.1', '200', 'OK')
    
    @http_service_proxy = stub('http_service_proxy')
    @http_service_proxy.stubs(:post).with(instance_of(String), instance_of(String), instance_of(String)).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    @http_service_proxy.stubs(:post).with(instance_of(String), instance_of(String), instance_of(String), 
                                          has_key(:account)).
      returns(@ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    
    @auth_info_provider = stub('auth_info_provider', :authentication_info => ['me', 'mine'])
    
    @accessor = AdvancedHttp::HttpAccessor.new(@auth_info_provider)
  end
  
  it 'should lookup auth info' do
    @auth_info_provider.expects(:authentication_info).with('SystemShepherd').returns(['me', 'mine'])
      
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should retry requests with authorization upon unauthorized response' do 
    @http_service_proxy.expects(:post).with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded').
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:post).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :account => 'me', :password => 'mine', :digest_challenge => @digest_challenge).
      returns(@ok_resp)
    
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 
  
  it 'should raise AuthenticationRequiredError if credentials are rejected' do
    @http_service_proxy.expects(:post).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :account => 'me', :password => 'mine', :digest_challenge => @digest_challenge).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    lambda {
      @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::AuthenticationRequiredError)
      
  end 
end

describe AdvancedHttp::HttpAccessor, '#post() (authorization)' do
  before do
    @unauth_resp = stub(:realm => 'SystemShepherd', :digest_challenge => nil)
    
    @ok_resp = Net::HTTPOK.new('1.1', '200', 'OK')
    
    @http_service_proxy = stub('http_service_proxy')
    @http_service_proxy.stubs(:post).with(instance_of(String), instance_of(String), instance_of(String)).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    @http_service_proxy.stubs(:post).with(instance_of(String), instance_of(String), instance_of(String), has_key(:account)).
      returns(@ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    
    @auth_info_provider = stub('auth_info_provider', :authentication_info => ['me', 'mine'])
    
    @accessor = AdvancedHttp::HttpAccessor.new(@auth_info_provider)
  end
  
  it 'should lookup auth info' do
    @auth_info_provider.expects(:authentication_info).with('SystemShepherd').returns(['me', 'mine'])
      
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should retry requests with authorization upon unauthorized response' do 
    @http_service_proxy.expects(:post).with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded').
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:post).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :account => 'me', :password => 'mine').
      returns(@ok_resp)
    
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should raise AuthenticationRequiredError if credentials are rejected' do
    @http_service_proxy.expects(:post).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :account => 'me', :password => 'mine').
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))

    lambda {
      @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::AuthenticationRequiredError)
  end 

end
