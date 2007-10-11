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
  
  it 'should accept logger to new' do
    ha = AdvancedHttp::HttpAccessor.new(nil, l = mock('logger'))
    
    ha.logger.should == l
  end 

  it 'should accept auth info provider in new()' do
    ha = AdvancedHttp::HttpAccessor.new(aip = mock('auth_info_provider'))
    
    ha.authentication_info_provider.should == aip
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

  it 'should give up after 5 redirects if max_redirects is not specified' do    
    redir_resps = []
    
    5.times do |i|
      redir_resps << Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
      redir_resps[i].expects(:[]).with('location').returns("http://www.example/foo/#{i+1}")
      @http_service_proxy.expects(:get).with("http://www.example/foo/#{i}", anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_#{i}"), redir_resps[i], "redirected"))
    end

    final_redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    @http_service_proxy.expects(:get).with("http://www.example/foo/5", anything).
      raises(AdvancedHttp::RequestRedirected.new(mock("req_5"), final_redir_resp, "redirected"))

    
    lambda {
      @accessor.get('http://www.example/foo/0')
    }.should raise_error(AdvancedHttp::TooManyRedirectsError)
  end 

  it 'should give up after +max_redirects+ redirects' do    
    redir_resps = []
    
    3.times do |i|
      redir_resps << Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
      redir_resps[i].expects(:[]).with('location').returns("http://www.example/foo/#{i+1}")
      @http_service_proxy.expects(:get).with("http://www.example/foo/#{i}", anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_#{i}"), redir_resps[i], "redirected"))
    end

    final_redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    @http_service_proxy.expects(:get).with("http://www.example/foo/3", anything).
      raises(AdvancedHttp::RequestRedirected.new(mock("req_3"), final_redir_resp, "redirected"))
    
    lambda {
      @accessor.get('http://www.example/foo/0', :max_redirects => 3)
    }.should raise_error(AdvancedHttp::TooManyRedirectsError)
  end 

  it 'should follow redirects' do
    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redir_resp.expects(:[]).with('location').returns('http://alt.example/foo')
    @http_service_proxy.expects(:get).with('http://www.example/', anything).
      raises(AdvancedHttp::RequestRedirected.new(mock("initial_req"), redir_resp, "redirected"))
    @http_service_proxy.expects(:get).with('http://alt.example/foo', anything).returns(@ok_resp)

    @accessor.get('http://www.example/')
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

  it 'should not count auth challenge against max_redirects' do
    (0..1).each do |i|
      redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
      redir_resp.expects(:[]).with('location').returns("http://www.example/foo/#{i+1}")
      @http_service_proxy.expects(:get).with("http://www.example/foo/#{i}", anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_#{i}"), redir_resp, "redirected"))
    end

    @accessor.get('http://www.example/foo/0', :max_redirects => 3).should == @ok_resp
  end 
  
  it 'should not loose track of redirection limit is authorization is required' do
    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redir_resp.expects(:[]).with('location').returns("http://www.example/foo/1")
      @http_service_proxy.expects(:get).with("http://www.example/foo/0", anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_0"), redir_resp, "redirected"))

    @http_service_proxy.expects(:get).with("http://www.example/foo/1", anything).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('req_1(unauth)'), @unauth_resp, "Unauthorized"))
  
    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redir_resp.expects(:[]).with('location').returns("http://www.example/foo/2")
    @http_service_proxy.expects(:get).with("http://www.example/foo/1", has_key(:account)).
      raises(AdvancedHttp::RequestRedirected.new(mock('req_1(authed)'), redir_resp, "Moved Permanently"))

    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    @http_service_proxy.expects(:get).with("http://www.example/foo/2", has_key(:account)).
      raises(AdvancedHttp::RequestRedirected.new(mock('req_2'), redir_resp, "Moved Permanently"))

    lambda {
      @accessor.get('http://www.example/foo/0', :max_redirects => 2)
    }.should raise_error(AdvancedHttp::TooManyRedirectsError)
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
  
  it 'should give up after 5 redirects if max_redirects is not specified' do    
    5.times do |i|
      redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
      @http_service_proxy.expects(:post).with("http://www.example/foo/#{i}", anything, anything, anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_#{i}"), redir_resp, "redirected"))
      redir_resp.expects(:[]).with('location').returns("http://www.example/foo/#{i+1}")
    end

    final_redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    @http_service_proxy.expects(:post).with("http://www.example/foo/5", anything, anything, anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_5"), final_redir_resp, "redirected"))

    
    lambda {
      @accessor.post('http://www.example/foo/0', "hello", "text/plain")
    }.should raise_error(AdvancedHttp::TooManyRedirectsError)
  end 

  it 'should give up after +max_redirects+ redirects' do    
    3.times do |i|
      redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
      redir_resp.expects(:[]).with('location').returns("http://www.example/foo/#{i+1}")
      @http_service_proxy.expects(:post).with("http://www.example/foo/#{i}", anything, anything, anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_#{i}"), redir_resp, "redirected"))
    end

    final_redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    @http_service_proxy.expects(:post).with("http://www.example/foo/3", anything, anything, anything).
      raises(AdvancedHttp::RequestRedirected.new(mock("req_3"), final_redir_resp, "redirected"))
    
    lambda {
      @accessor.post('http://www.example/foo/0', 'hello', 'text/plain', :max_redirects => 3)
    }.should raise_error(AdvancedHttp::TooManyRedirectsError)
  end 
  
  it 'should follow redirects' do
    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redir_resp.expects(:[]).with('location').returns('http://alt.example/foo')
    @http_service_proxy.expects(:post).with('http://www.example/', anything, anything, anything).
      raises(AdvancedHttp::RequestRedirected.new(mock("initial_req"), redir_resp, "redirected"))
    @http_service_proxy.expects(:post).with('http://alt.example/foo', anything, anything, anything).returns(@ok_resp)

    @accessor.post('http://www.example/', "hello", 'text/plain')
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
  
  it 'should not count auth challenge against max_redirects' do
    (0..1).each do |i|
      redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
      redir_resp.expects(:[]).with('location').returns("http://www.example/foo/#{i+1}")
      @http_service_proxy.expects(:post).with("http://www.example/foo/#{i}", anything, anything, anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_#{i}"), redir_resp, "redirected"))
    end

    @accessor.post('http://www.example/foo/0', 'hello', 'text/plain', :max_redirects => 3).should == @ok_resp
  end 
  
  it 'should not loose track of redirection limit is authorization is required' do
    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redir_resp.expects(:[]).with('location').returns("http://www.example/foo/1")
      @http_service_proxy.expects(:post).with("http://www.example/foo/0", anything, anything, anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_0"), redir_resp, "redirected"))

    @http_service_proxy.expects(:post).with("http://www.example/foo/1", anything, anything, anything).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('req_1(unauth)'), @unauth_resp, "Unauthorized"))
  
    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redir_resp.expects(:[]).with('location').returns("http://www.example/foo/2")
    @http_service_proxy.expects(:post).with("http://www.example/foo/1", anything, anything, has_key(:account)).
      raises(AdvancedHttp::RequestRedirected.new(mock('req_1(authed)'), redir_resp, "Moved Permanently"))

    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    @http_service_proxy.expects(:post).with("http://www.example/foo/2", anything, anything, has_key(:account)).
      raises(AdvancedHttp::RequestRedirected.new(mock('req_2'), redir_resp, "Moved Permanently"))

    lambda {
      @accessor.post('http://www.example/foo/0', 'hello', 'text/plain', :max_redirects => 2)
    }.should raise_error(AdvancedHttp::TooManyRedirectsError)
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


# --- PUT ---


describe AdvancedHttp::HttpAccessor, '#put()' do
  before do
    @ok_resp = Net::HTTPCreated.new('1.1', '201', 'Created')
    @http_service_proxy = stub(:put => @ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    @accessor = AdvancedHttp::HttpAccessor.new
  end

  it 'should include request duration in the log message' 
# do
#     l = stub('logger')
#     l.expects(:info).with(regexp_matches(%r|\([\d\.]+s\)|)).times(2)

#     @accessor.logger = l
#     @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
#   end

  it 'should give up after 5 redirects if max_redirects is not specified' do    
    5.times do |i|
      redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
      @http_service_proxy.expects(:put).with("http://www.example/foo/#{i}", anything, anything, anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_#{i}"), redir_resp, "redirected"))
      redir_resp.expects(:[]).with('location').returns("http://www.example/foo/#{i+1}")
    end

    final_redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    @http_service_proxy.expects(:put).with("http://www.example/foo/5", anything, anything, anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_5"), final_redir_resp, "redirected"))

    
    lambda {
      @accessor.put('http://www.example/foo/0', "hello", "text/plain")
    }.should raise_error(AdvancedHttp::TooManyRedirectsError)
  end 

  it 'should give up after +max_redirects+ redirects' do    
    3.times do |i|
      redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
      redir_resp.expects(:[]).with('location').returns("http://www.example/foo/#{i+1}")
      @http_service_proxy.expects(:put).with("http://www.example/foo/#{i}", anything, anything, anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_#{i}"), redir_resp, "redirected"))
    end

    final_redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    @http_service_proxy.expects(:put).with("http://www.example/foo/3", anything, anything, anything).
      raises(AdvancedHttp::RequestRedirected.new(mock("req_3"), final_redir_resp, "redirected"))
    
    lambda {
      @accessor.put('http://www.example/foo/0', 'hello', 'text/plain', :max_redirects => 3)
    }.should raise_error(AdvancedHttp::TooManyRedirectsError)
  end 
  
  it 'should follow redirects' do
    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redir_resp.expects(:[]).with('location').returns('http://alt.example/foo')
    @http_service_proxy.expects(:put).with('http://www.example/', anything, anything, anything).
      raises(AdvancedHttp::RequestRedirected.new(mock("initial_req"), redir_resp, "redirected"))
    @http_service_proxy.expects(:put).with('http://alt.example/foo', anything, anything, anything).returns(@ok_resp)

    @accessor.put('http://www.example/', "hello", 'text/plain')
  end
  
  it 'should log request if a logger is provided' do
    l = mock('logger')
    l.expects(:info).with(regexp_matches(%r|^PUT http://www.example/|)).once
    
    @accessor.logger = l
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 
  
  it 'should include content type in log messages' do
    l = mock('logger')
    l.expects(:info).with(regexp_matches(/\(content-type: application\/x-form-urlencoded\)/)).once
    
    @accessor.logger = l
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should look up appropriate service proxy object' do
    AdvancedHttp::HttpServiceProxy.expects(:for).with('http://www.example/').returns(@http_service_proxy)
    
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should use service proxy to put URI' do
    @http_service_proxy.expects(:put).with('http://www.example/', "foo=bar", 'application/x-form-urlencoded', {})
    
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should include acceptable res presentation in the request' do
    @http_service_proxy.expects(:put).with('http://www.example/', "foo=bar", 'application/x-form-urlencoded', :accept => 'test/html')
    
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :accept => 'test/html')
  end 

  it 'should follow redirects'

  it 'should raise AuthenticationRequiredError if resource requires authentication and no appropriate auth info is known' do
    unauth_resp = mock(:realm => 'SystemShepherd')
    @http_service_proxy.expects(:put).once.
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), unauth_resp, "Unauthorized"))
    
    lambda {
      @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::AuthenticationRequiredError)
  end 
end


describe AdvancedHttp::HttpAccessor, '#put() (digest authorization)' do
  before do
    @digest_challenge = stub('digest_challenge')
    @unauth_resp = stub(:realm => 'SystemShepherd', :digest_challenge => @digest_challenge)
    
    @ok_resp = Net::HTTPOK.new('1.1', '200', 'OK')
    
    @http_service_proxy = stub('http_service_proxy')
    @http_service_proxy.stubs(:put).with(instance_of(String), instance_of(String), instance_of(String), anything).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    @http_service_proxy.stubs(:put).with(instance_of(String), instance_of(String), instance_of(String), 
                                          has_key(:account)).
      returns(@ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    
    @auth_info_provider = stub('auth_info_provider', :authentication_info => ['me', 'mine'])
    
    @accessor = AdvancedHttp::HttpAccessor.new(@auth_info_provider)
  end

  it 'should not count auth challenge against max_redirects' do
    (0..1).each do |i|
      redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
      redir_resp.expects(:[]).with('location').returns("http://www.example/foo/#{i+1}")
      @http_service_proxy.expects(:put).with("http://www.example/foo/#{i}", anything, anything, anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_#{i}"), redir_resp, "redirected"))
    end

    @accessor.put('http://www.example/foo/0', 'hello', 'text/plain', :max_redirects => 3).should == @ok_resp
  end 
  
  it 'should not loose track of redirection limit is authorization is required' do
    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redir_resp.expects(:[]).with('location').returns("http://www.example/foo/1")
      @http_service_proxy.expects(:put).with("http://www.example/foo/0", anything, anything, anything).
        raises(AdvancedHttp::RequestRedirected.new(mock("req_0"), redir_resp, "redirected"))

    @http_service_proxy.expects(:put).with("http://www.example/foo/1", anything, anything, anything).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('req_1(unauth)'), @unauth_resp, "Unauthorized"))
  
    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    redir_resp.expects(:[]).with('location').returns("http://www.example/foo/2")
    @http_service_proxy.expects(:put).with("http://www.example/foo/1", anything, anything, has_key(:account)).
      raises(AdvancedHttp::RequestRedirected.new(mock('req_1(authed)'), redir_resp, "Moved Permanently"))

    redir_resp = Net::HTTPMovedPermanently.new('1.1', '301', 'Moved Permanently')
    @http_service_proxy.expects(:put).with("http://www.example/foo/2", anything, anything, has_key(:account)).
      raises(AdvancedHttp::RequestRedirected.new(mock('req_2'), redir_resp, "Moved Permanently"))

    lambda {
      @accessor.put('http://www.example/foo/0', 'hello', 'text/plain', :max_redirects => 2)
    }.should raise_error(AdvancedHttp::TooManyRedirectsError)
  end 

  it 'should log both requests if a logger is provided' do
    l = mock('logger')
    l.expects(:info).with(regexp_matches(%r|^PUT http://www.example/|)).times(2)
    
    @accessor.logger = l
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should include auth info in messages regarding authenticated requests' do 
    l = stub('logger', :info => true)
    l.expects(:info).with(regexp_matches(/\(Auth: type=digest, realm='SystemShepherd', account='me'\)/)).once
    
    @accessor.logger = l
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 
  
  it 'should lookup auth info' do
    @auth_info_provider.expects(:authentication_info).with('SystemShepherd').returns(['me', 'mine'])
      
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should retry requests with authorization upon unauthorized response' do 
    @http_service_proxy.expects(:put).with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', {}).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:put).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :account => 'me', :password => 'mine', :digest_challenge => @digest_challenge).
      returns(@ok_resp)
    
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should include acceptable representation info in auth retry requests' do 
    @http_service_proxy.expects(:put).with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', 
                                            :accept => 'text/html').
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:put).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :accept => 'text/html', 
           :account => 'me', :password => 'mine', :digest_challenge => @digest_challenge).
      returns(@ok_resp)
    
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :accept => 'text/html')
  end 
  
  it 'should raise AuthenticationRequiredError if credentials are rejected' do
    @http_service_proxy.expects(:put).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :account => 'me', :password => 'mine', :digest_challenge => @digest_challenge).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    lambda {
      @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::AuthenticationRequiredError)
      
  end 
end

describe AdvancedHttp::HttpAccessor, '#put() (basic authorization)' do
  before do
    @unauth_resp = stub(:realm => 'SystemShepherd', :digest_challenge => nil)
    
    @ok_resp = Net::HTTPOK.new('1.1', '200', 'OK')
    
    @http_service_proxy = stub('http_service_proxy')
    @http_service_proxy.stubs(:put).with(instance_of(String), instance_of(String), instance_of(String), anything).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    @http_service_proxy.stubs(:put).with(instance_of(String), instance_of(String), instance_of(String), has_key(:account)).
      returns(@ok_resp)
    AdvancedHttp::HttpServiceProxy.stubs(:for).returns(@http_service_proxy)
    
    @auth_info_provider = stub('auth_info_provider', :authentication_info => ['me', 'mine'])
    
    @accessor = AdvancedHttp::HttpAccessor.new(@auth_info_provider)
  end

  it 'should log both requests if a logger is provided' do
    l = mock('logger')
    l.expects(:info).with(regexp_matches(%r|^PUT http://www.example/|)).times(2)
    
    @accessor.logger = l
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should include auth info in messages regarding authenticated requests' do 
    l = stub('logger', :info => true)
    l.expects(:info).with(regexp_matches(/\(Auth: type=basic, realm='SystemShepherd', account='me'\)/)).once
    
    @accessor.logger = l
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should lookup auth info' do
    @auth_info_provider.expects(:authentication_info).with('SystemShepherd').returns(['me', 'mine'])
      
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should retry requests with authorization upon unauthorized response' do 
    @http_service_proxy.expects(:put).with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', {}).
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:put).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :account => 'me', :password => 'mine').
      returns(@ok_resp)
    
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
  end 

  it 'should include acceptable representation info in auth retry requests' do 
    @http_service_proxy.expects(:put).with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', 
                                            :accept => 'text/html').
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))
    
    @http_service_proxy.expects(:put).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :account => 'me', :password => 'mine', 
           :accept => 'text/html').
      returns(@ok_resp)
    
    @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :accept => 'text/html')
  end 

  it 'should raise AuthenticationRequiredError if credentials are rejected' do
    @http_service_proxy.expects(:put).
      with('http://www.example/', 'foo=bar', 'application/x-form-urlencoded', :account => 'me', :password => 'mine').
      raises(AdvancedHttp::AuthenticationRequiredError.new(mock('request'), @unauth_resp, "Unauthorized"))

    lambda {
      @accessor.put('http://www.example/', 'foo=bar', 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::AuthenticationRequiredError)
  end 

end
