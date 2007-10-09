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
  
  it 'should allow a logger to be specified' do
    l = stub('logger')
    
    @accessor.logger = l
    @accessor.logger.should == l
  end 

  it 'should allow a logger to be removed' do
    l = stub('logger')
    
    @accessor.logger = l
    @accessor.logger = nil
    @accessor.logger.should be_nil    
  end 

end

describe AdvancedHttp::HttpAccessor, '#get()' do
  before do
    @ok_resp = Net::HTTPOK.new('1.1', '200', 'OK')
    @http_service_proxy = stub(:get => @ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    @accessor = AdvancedHttp::HttpAccessor.new
  end

  it 'should include request duration in the log message' 
# do
#     l = stub('logger')
#     l.expects(:info).with(regexp_matches(%r|\([\d\.]+s\)|)).times(2)

#     @accessor.logger = l
#     @accessor.get('http://www.example/')
#   end

  it 'should log request if a logger is provided' do
    l = mock('logger')
    l.expects(:info).with(regexp_matches(%r|GET http://www.example/|))

    @accessor.logger = l
    @accessor.get('http://www.example/')
  end 

  it 'should include acceptable representations if specified' do
    l = mock('logger')
    l.expects(:info).with(regexp_matches(%r|example/ \(text/html,application/xml\)|))

    @accessor.logger = l
    @accessor.get('http://www.example/', :accept => ['text/html', 'application/xml'])
  end 
  
  it 'should look up appropriate service proxy object' do
    AdvancedHttp::HttpServiceProxy.expects(:for).with('http://www.example/').returns(@http_service_proxy)
    
    @accessor.get('http://www.example/')
  end 

  it 'should use service proxy to get URI' do
    @http_service_proxy.expects(:get).with('http://www.example/', {})
    
    @accessor.get('http://www.example/')
  end 

  it 'should follow redirects'

  it 'should raise AuthenticationRequiredError if resource requires authentication and no appropriate auth info is known' do
    unauth_resp = mock(:realm => 'SystemShepherd')
    @http_service_proxy.expects(:get).with('http://www.example/', {}).once.
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), unauth_resp, "Unauthorized"))
    
    lambda {
      @accessor.get('http://www.example/')
    }.should raise_error(AdvancedHttp::AuthenticationRequiredError)
  end 
  
  it 'should allow acceptable representations to be specified' do
    @http_service_proxy.expects(:get).with('http://www.example/', :accept => 'text/prs.foo.bar')
    
    @accessor.get('http://www.example/', :accept => 'text/prs.foo.bar')
  end 
end

describe AdvancedHttp::HttpAccessor, '#get() (digest authorization)' do
  before do
    @digest_challenge = stub('digest_challenge')
    @unauth_resp = stub(:realm => 'SystemShepherd', :digest_challenge => @digest_challenge)
    
    @ok_resp = Net::HTTPOK.new('1.1', '200', 'OK')
    
    @http_service_proxy = stub('http_service_proxy')
    @http_service_proxy.stubs(:get).with(instance_of(String), anything).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    @http_service_proxy.stubs(:get).with(instance_of(String), has_key(:account)).
      returns(@ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    
    @auth_info_provider = stub('auth_info_provider', :authentication_info => ['me', 'mine'])
    
    @accessor = AdvancedHttp::HttpAccessor.new(@auth_info_provider)
  end  
  
  it 'should log both requests' do
    l = stub('logger')
    l.expects(:info).with(regexp_matches(%r|^GET http://www.example/|)).times(2)

    @accessor.logger = l
    @accessor.get('http://www.example/')
  end 
  
  it 'should include auth info in messages regarding authenticated requests' do
    l = stub('logger', :info => true)
    l.expects(:info).with(regexp_matches(/\(Auth: type=digest, realm='SystemShepherd', account='me'\)/)).once

    @accessor.logger = l
    @accessor.get('http://www.example/')
  end 

  
  it 'should lookup auth info' do
    @auth_info_provider.expects(:authentication_info).with('SystemShepherd').returns(['me', 'mine'])
      
    @accessor.get('http://www.example/')
  end 

  it 'should retry requests with authorization upon unauthorized response' do 
    @http_service_proxy.expects(:get).with('http://www.example/', {}).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:get).
      with('http://www.example/', :account => 'me', :password => 'mine', :digest_challenge => @digest_challenge).
      returns(@ok_resp)
    
    @accessor.get('http://www.example/')
  end 

  it 'should include acceptable representation information in retries' do 
    @http_service_proxy.expects(:get).with('http://www.example/', :accept => 'text/prs.foo.bar').
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:get).
      with('http://www.example/', :accept => 'text/prs.foo.bar', :account => 'me', :password => 'mine', :digest_challenge => @digest_challenge).
      returns(@ok_resp)
    
    @accessor.get('http://www.example/', :accept => 'text/prs.foo.bar')
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

describe AdvancedHttp::HttpAccessor, '#get() (basic authorization)' do
  before do
    @unauth_resp = stub(:realm => 'SystemShepherd', :digest_challenge => nil)
    
    @ok_resp = Net::HTTPOK.new('1.1', '200', 'OK')
    
    @http_service_proxy = stub('http_service_proxy')
    @http_service_proxy.stubs(:get).with(instance_of(String), anything).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    @http_service_proxy.stubs(:get).with(instance_of(String), has_key(:account)).
      returns(@ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    
    @auth_info_provider = stub('auth_info_provider', :authentication_info => ['me', 'mine'])
    
    @accessor = AdvancedHttp::HttpAccessor.new(@auth_info_provider)
  end

  it 'should log both requests' do
    l = stub('logger')
    l.expects(:info).with(regexp_matches(%r|^GET http://www.example/|)).times(2)

    @accessor.logger = l
    @accessor.get('http://www.example/')
  end 
  
  it 'should include auth info in messages regarding authenticated requests' do
    l = stub('logger', :info => true)
    l.expects(:info).with(regexp_matches(/\(Auth: type=basic, realm='SystemShepherd', account='me'\)/)).once

    @accessor.logger = l
    @accessor.get('http://www.example/')
  end 

  it 'should lookup auth info' do
    @auth_info_provider.expects(:authentication_info).with('SystemShepherd').returns(['me', 'mine'])
      
    @accessor.get('http://www.example/')
  end 

  it 'should retry requests with authorization upon unauthorized response' do 
    @http_service_proxy.expects(:get).with('http://www.example/', {}).
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

  it 'should include request duration in the log message' 
# do
#     l = stub('logger')
#     l.expects(:info).with(regexp_matches(%r|\([\d\.]+s\)|)).times(2)

#     @accessor.logger = l
#     @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
#   end

  it 'should log request if a logger is provided' do
    l = mock('logger')
    l.expects(:info).with(regexp_matches(%r|^POST http://www.example/|)).once
    
    @accessor.logger = l
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 
  
  it 'should include content type in log messages' do
    l = mock('logger')
    l.expects(:info).with(regexp_matches(/\(content-type: application\/x-form-urlencoded\)/)).once
    
    @accessor.logger = l
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should look up appropriate service proxy object' do
    AdvancedHttp::HttpServiceProxy.expects(:for).with('http://www.example/').returns(@http_service_proxy)
    
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should use service proxy to post URI' do
    @http_service_proxy.expects(:post).with('http://www.example/', "foo=bar", 'application/x-form-urlencoded', {})
    
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should include acceptable res presentation in the request' do
    @http_service_proxy.expects(:post).with('http://www.example/', "foo=bar", 'application/x-form-urlencoded', :accept => 'test/html')
    
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :accept => 'test/html')
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
    @http_service_proxy.stubs(:post).with(instance_of(String), instance_of(String), instance_of(String), anything).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    @http_service_proxy.stubs(:post).with(instance_of(String), instance_of(String), instance_of(String), 
                                          has_key(:account)).
      returns(@ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    
    @auth_info_provider = stub('auth_info_provider', :authentication_info => ['me', 'mine'])
    
    @accessor = AdvancedHttp::HttpAccessor.new(@auth_info_provider)
  end
  
  it 'should log both requests if a logger is provided' do
    l = mock('logger')
    l.expects(:info).with(regexp_matches(%r|^POST http://www.example/|)).times(2)
    
    @accessor.logger = l
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should include auth info in messages regarding authenticated requests' do 
    l = stub('logger', :info => true)
    l.expects(:info).with(regexp_matches(/\(Auth: type=digest, realm='SystemShepherd', account='me'\)/)).once
    
    @accessor.logger = l
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 
  
  it 'should lookup auth info' do
    @auth_info_provider.expects(:authentication_info).with('SystemShepherd').returns(['me', 'mine'])
      
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should retry requests with authorization upon unauthorized response' do 
    @http_service_proxy.expects(:post).with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', {}).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:post).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :account => 'me', :password => 'mine', :digest_challenge => @digest_challenge).
      returns(@ok_resp)
    
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should include acceptable representation info in auth retry requests' do 
    @http_service_proxy.expects(:post).with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', 
                                            :accept => 'text/html').
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:post).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :accept => 'text/html', 
           :account => 'me', :password => 'mine', :digest_challenge => @digest_challenge).
      returns(@ok_resp)
    
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :accept => 'text/html')
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

describe AdvancedHttp::HttpAccessor, '#post() (basic authorization)' do
  before do
    @unauth_resp = stub(:realm => 'SystemShepherd', :digest_challenge => nil)
    
    @ok_resp = Net::HTTPOK.new('1.1', '200', 'OK')
    
    @http_service_proxy = stub('http_service_proxy')
    @http_service_proxy.stubs(:post).with(instance_of(String), instance_of(String), instance_of(String), anything).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    @http_service_proxy.stubs(:post).with(instance_of(String), instance_of(String), instance_of(String), has_key(:account)).
      returns(@ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    
    @auth_info_provider = stub('auth_info_provider', :authentication_info => ['me', 'mine'])
    
    @accessor = AdvancedHttp::HttpAccessor.new(@auth_info_provider)
  end

  it 'should log both requests if a logger is provided' do
    l = mock('logger')
    l.expects(:info).with(regexp_matches(%r|^POST http://www.example/|)).times(2)
    
    @accessor.logger = l
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should include auth info in messages regarding authenticated requests' do 
    l = stub('logger', :info => true)
    l.expects(:info).with(regexp_matches(/\(Auth: type=basic, realm='SystemShepherd', account='me'\)/)).once
    
    @accessor.logger = l
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should lookup auth info' do
    @auth_info_provider.expects(:authentication_info).with('SystemShepherd').returns(['me', 'mine'])
      
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should retry requests with authorization upon unauthorized response' do 
    @http_service_proxy.expects(:post).with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', {}).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:post).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :account => 'me', :password => 'mine').
      returns(@ok_resp)
    
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should include acceptable representation info in auth retry requests' do 
    @http_service_proxy.expects(:post).with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', 
                                            :accept => 'text/html').
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:post).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :account => 'me', :password => 'mine', 
           :accept => 'text/html').
      returns(@ok_resp)
    
    @accessor.post('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :accept => 'text/html')
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
