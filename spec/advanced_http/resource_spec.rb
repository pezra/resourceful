require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'advanced_http/resource'

describe AdvancedHttp::Resource do
  before do
    @resource = AdvancedHttp::Resource.new('http://www.example/foo')
  end
  
  it 'should be creatable with a URI' do
    AdvancedHttp::Resource.new('http://www.example/foo')
  end 

  it "should know it's URI" do
    @resource.uri.should == URI.parse('http://www.example/foo')
  end 
  
  it 'should be creatable with a URI' do
    AdvancedHttp::Resource.new('http://www.example/foo')
  end 

  it 'should execute request against remote server' do
    req = mock("http_req", :method => 'GET')
    http_conn = mock('http_conn')
    response = stub('response', :code => '200')
    Net::HTTP.expects(:start).with('www.example', 80).yields(http_conn).returns(response)
    http_conn.expects(:request).with(req, nil).returns(response)
    
    @resource.send(:do_request, req).should == response
  end 

  it 'should send body to remote server if provided' do
    req = mock("http_req", :method => 'POST')
    http_conn = mock('http_conn')
    Net::HTTP.expects(:start).with('www.example', 80).yields(http_conn).returns(response = mock('response', :code => '201'))
    http_conn.expects(:request).with(req, "body").returns(response)
    
    @resource.send(:do_request, req, "body").should == response
  end 
  
  it 'should provide effective URI attribute' do
    @resource.effective_uri.should == URI.parse('http://www.example/foo')
  end 
  
  it 'should forget current effective URI upon reset' do
    @resource.send(:effective_uri=, 'http://www.example/bar')
    @resource.effective_uri.should == URI.parse('http://www.example/bar')
    @resource.reset
    @resource.effective_uri.should == URI.parse('http://www.example/foo')
  end 
  
  it 'should accept logger at initialize time' do
    AdvancedHttp::Resource.new('http://www.example/foo', :logger => mock('logger'))
  end 
  
  it 'should #log should pass :info messages through to logger object' do
    resource = AdvancedHttp::Resource.new('http://www.example/foo', :logger => logger = mock('logger'))
    
    logger.expects(:info).with('hello')
    
    resource.send(:log, :info, 'hello')
  end 

  it 'should #log should pass :debug messages through to logger object' do
    resource = AdvancedHttp::Resource.new('http://www.example/foo', :logger => logger = mock('logger'))
    
    logger.expects(:debug).with('hello')
    
    resource.send(:log, :debug, 'hello')
  end 
  
  it 'should accept auth_info init option' do
    AdvancedHttp::Resource.new('http://www.example/foo', :auth_info => mock('auth_info_provider'))
  end 
  
  it 'should raise argument error if unrecognized options are passed to init' do
    lambda {
      AdvancedHttp::Resource.new('http://www.example/foo', :foo => 'oof')
    }.should raise_error(ArgumentError)
  end 
end 

describe AdvancedHttp::Resource, '#do_request (basic auth)' do
  before do
    @auth_provider = stub('auth_provider', :authentication_info => ['me', 'mine'])
    @resource = AdvancedHttp::Resource.new('http://www.example/foo', :auth_info => @auth_provider)
    
    @unauth_response = stub('unauth_response', :code => '401', :digest_auth_allowed? => false, 
                            :basic_auth_allowed? => true, :realm => 'test_realm')
    @ok_response = stub('ok_response', :code => '200')
    
    @http_conn = mock('http_conn')
    Net::HTTP.expects(:start).with('www.example', 80).yields(@http_conn)
    @http_conn.stubs(:request).returns(@unauth_response, @ok_response)

    @request = stub("http_req", :method => 'GET', :basic_auth => nil)
  end
  
  it 'should retry unauthorized requests with auth if possible' do
    @http_conn.expects(:request).with(@request, nil).times(2).returns(@unauth_response, @ok_response)
 
    @resource.send(:do_request, @request)    
  end 

  it 'should set basic auth on request before retry' do
    @http_conn.expects(:request).with(@request, nil).times(2).returns(@unauth_response, @ok_response)
    @request.expects(:basic_auth).with('me', 'mine')
 
    @resource.send(:do_request, @request)    
  end 
  
  it 'should look up authentication information' do
    @auth_provider.expects(:authentication_info).with('test_realm').returns(['me', 'emin'])

    @resource.send(:do_request, @request)    
  end 
  
  it 'should log the retry' do
    @resource.expects(:log).with(:info, regexp_matches(/(basic_auth: realm='test_realm', account='me')/))
    @resource.expects(:log).with(:info, anything)
    @resource.send(:do_request, @request)    
  end   
end 

describe AdvancedHttp::Resource, '#do_request (basic auth)' do
  before do
    @auth_provider = stub('auth_provider', :authentication_info => ['me', 'mine'])
    @resource = AdvancedHttp::Resource.new('http://www.example/foo', :auth_info => @auth_provider)
    
    @digest_challenge = stub('digest_challenge')
    @unauth_response = stub('unauth_response', :code => '401', :digest_auth_allowed? => true, 
                            :basic_auth_allowed? => false, :realm => 'test_realm', 
                            :digest_challenge => @digest_challenge)
    @ok_response = stub('ok_response', :code => '200')
    
    @http_conn = mock('http_conn')
    Net::HTTP.expects(:start).with('www.example', 80).yields(@http_conn)
    @http_conn.stubs(:request).returns(@unauth_response, @ok_response)

    @request = stub("http_req", :method => 'GET', :digest_auth => nil)
  end
  
  it 'should retry unauthorized requests with auth if possible' do
    @http_conn.expects(:request).with(@request, nil).times(2).returns(@unauth_response, @ok_response)
 
    @resource.send(:do_request, @request)    
  end 

  it 'should set basic auth on request before retry' do
    @http_conn.expects(:request).with(@request, nil).times(2).returns(@unauth_response, @ok_response)
    @request.expects(:digest_auth).with('me', 'mine', @digest_challenge)
 
    @resource.send(:do_request, @request)    
  end 
  
  it 'should look up authentication information' do
    @auth_provider.expects(:authentication_info).with('test_realm').returns(['me', 'emin'])

    @resource.send(:do_request, @request)    
  end 
  
  it 'should log the retry' do
    @resource.expects(:log).with(:info, regexp_matches(/(digest_auth: realm='test_realm', account='me')/))
    @resource.expects(:log).with(:info, anything)
    @resource.send(:do_request, @request)    
  end 
end 

describe AdvancedHttp::Resource, '#get' do
  before do
    @resource = AdvancedHttp::Resource.new('http://www.example/foo')
    @response = stub('http_response', :body => 'I am foo', :code => '200')
    @resource.stubs(:do_request).with(instance_of(Net::HTTP::Get)).returns(@response)
  end

  it 'should use http connection associated with resource' do
    @resource.expects(:do_request).with(instance_of(Net::HTTP::Get)).returns(@response)
    @resource.get
  end 
  
  it 'should return the representation as a string' do
    @resource.get.should == "I am foo"
  end 

  it 'should raise error for all 2xx response codes except 200' do
    @response.expects(:code).at_least_once.returns('202')
    lambda{
      @resource.get
    }.should raise_error(AdvancedHttp::NonOkResponseError)
  end 
  
  it 'should raise client error for 4xx response codes' do
    @response.expects(:code).at_least_once.returns('400')
    lambda{
      @resource.get      
    }.should raise_error(AdvancedHttp::HttpClientError)
  end 
  
  it 'should raise server error for 5xx response codes' do
    @response.expects(:code).at_least_once.returns('500')
    lambda{
      @resource.get      
    }.should raise_error(AdvancedHttp::HttpServerError)    
  end 
  
  it "should make get request to server" do
    @resource.stubs(:do_request).with{|req| req.path == '/foo'}.returns(@response)
    @resource.get
  end 
end 

describe AdvancedHttp::Resource, '#get (unacceptable redirection)' do
  before do
    @resource = AdvancedHttp::Resource.new('http://www.example/foo')
    @redir_response = stub('http_response', :code => '300')
    @redir_response.stubs(:[]).with('location').returns('http://www.example/bar')
    
    @resource.stubs(:do_request).returns(@redir_response)
  end
  
  ['300','303','304','305'].each do |code|
    it "should raise redirection error for #{code} response" do
      @redir_response.stubs(:code).returns('300')
      
      lambda{
        @resource.get
      }.should raise_error(AdvancedHttp::HttpRequestRedirected)
      
    end 
  end
  
end 

[['307', 'Temporary'], ['302', 'Found']].each do |code, message|
  describe AdvancedHttp::Resource, "#get (#{message} redirection)" do
    before do
      @resource = AdvancedHttp::Resource.new('http://www.example/foo')
      @redir_response = stub('http_response', :code => code)
      @redir_response.stubs(:[]).with('location').returns('http://www.example/bar')
      @ok_response = stub('http_response', :code => '200', :body => "I am foo (bar)") 
      
      @resource.stubs(:do_request).returns(@redir_response, @ok_response)
    end
    
    it 'should follow redirect' do
      @resource.expects(:do_request).with{|r| r.path == '/foo'}.returns(@redir_response)
      @resource.expects(:do_request).with{|r| r.path == '/bar'}.returns(@ok_response)
      
      @resource.get
    end 

    it 'should not reset URI' do
      @resource.get
      
      @resource.uri.should == URI.parse('http://www.example/foo')
    end 

    it 'should set effective URI' do
      @resource.get
      
      @resource.effective_uri.should == URI.parse('http://www.example/bar')
    end 

    it 'should return body of second response' do
      @resource.get.should == 'I am foo (bar)'
    end 

  end 
end

describe AdvancedHttp::Resource, '#get (Permanent redirection)' do
  before do
    @resource = AdvancedHttp::Resource.new('http://www.example/foo')
    @redir_response = stub('http_response', :code => '301')
    @redir_response.stubs(:[]).with('location').returns('http://www.example/bar')
    @ok_response = stub('http_response', :code => '200', :body => "I am foo (bar)") 
    
    @resource.stubs(:do_request).returns(@redir_response, @ok_response)
  end
  
  it 'should follow redirect' do
    @resource.expects(:do_request).with{|r| r.path == '/foo'}.returns(@redir_response)
    @resource.expects(:do_request).with{|r| r.path == '/bar'}.returns(@ok_response)
    
    @resource.get
  end 

  it 'should reset URI' do
    @resource.get
    @resource.uri.should == URI.parse('http://www.example/bar')
  end 
  
  it 'should return body of second response' do
    @resource.get.should == 'I am foo (bar)'
  end 

end 


describe AdvancedHttp::Resource, '#post' do
  before do
    @resource = AdvancedHttp::Resource.new('http://www.example/foo')
    @response = stub('http_response', :is_a? => false, :body => 'Created', :code => '201')
    @response.stubs(:[]).with('location').returns('http://www.example/foo/42')
    
    @resource.stubs(:do_request).returns(@response)
  end

  it 'should make request to the effective_uri' do
    @resource.send(:effective_uri=, 'http://www.example/bar')
    @resource.expects(:do_request).with{|r,_| r.path =='/bar'}.returns(@response)

    @resource.post("this=that", 'application/x-form-urlencoded')
  end 

  it 'should request obj should have content-type set' do
    @resource.expects(:do_request).with{|r,_| r['content-type'] =='application/prs.foo.bar'}.returns(@response)
    
    @resource.post("this=that", 'application/prs.foo.bar')
  end 

  it 'should set request body' do
    @resource.expects(:do_request).with(anything, 'this=that').returns(@response)
    
    @resource.post("this=that", 'application/prs.foo.bar')
  end 

  it 'should return http response object if response is 2xx' do
    @resource.post("this=that", 'application/x-form-urlencoded').should == @response
  end 
  
  it 'should raise client error for 4xx response' do
    @response.expects(:code).at_least_once.returns('404')
    lambda{
      @resource.post("this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::HttpClientError)
  end 

  it 'should raise client error for 5xx response' do
    @response.expects(:code).at_least_once.returns('500')
    lambda{
      @resource.post("this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::HttpServerError)
  end 
  
  it 'should raise redirected exception for 3xx response' do
    @response.expects(:code).at_least_once.returns('301')
    lambda{
      @resource.post("this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::HttpRequestRedirected)    
  end 

  it 'should return response to get against redirect target for 303 response' do
    see_other_response = stub('http_see_other_response',  :body => 'ok_response', :code => '303')
    see_other_response.expects(:[]).with('location').returns('http://alt.example/bar')
    
    @resource.expects(:do_request).with{|r,_| r.method == 'POST' and r.path == '/foo'}.returns(see_other_response)

    AdvancedHttp::Resource.expects(:new).with('http://alt.example/bar').
      returns(secondary_resource = mock('resource2'))
    ok_response = stub('http_ok_response',  :body => 'ok_response', :code => '200')
    secondary_resource.expects(:get_response).returns(ok_response)
    
    @resource.post("this=that", 'application/x-form-urlencoded')
  end 

end

describe AdvancedHttp::Resource, '#put' do
  before do
    @resource = AdvancedHttp::Resource.new('http://www.example/foo')
    @response = stub('http_response', :is_a? => false, :body => 'Created', :code => '201')
    @response.stubs(:[]).with('location').returns('http://www.example/foo/42')
    
    @resource.stubs(:do_request).returns(@response)
  end

  it 'should make request correct path' do
    @resource.expects(:do_request).with{|r,_| r.path == '/foo'}.returns(@response)
    @resource.put("this=that", 'application/x-form-urlencoded')
  end 

  it 'should make request with body' do
    @resource.expects(:do_request).with(instance_of(Net::HTTP::Put), 'this=that').returns(@response)
    @resource.put("this=that", 'application/x-form-urlencoded')
  end 

  it 'should make request with correct content' do
    @resource.expects(:do_request).with{|r,_| r['content-type'] == 'application/prs.api.test'}.returns(@response)
    @resource.put("this=that", 'application/prs.api.test')
  end 

  it 'should make put request effective_uri' do
    @resource.send(:effective_uri=, 'http://www.example.com/bar')
    @resource.expects(:do_request).with{|r,_| r.path == '/bar'}.returns(@response)
    @resource.put("this=that", 'application/x-form-urlencoded')
  end 
  
  it 'should return http response object if response is 2xx' do
    @resource.put("this=that", 'application/x-form-urlencoded').should == @response
  end 
  
  it 'should raise client error for 4xx response' do
    @response.expects(:code).at_least_once.returns('404')
    lambda{
      @resource.put("this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::HttpClientError)
  end 

  it 'should raise client error for 5xx response' do
    @response.expects(:code).at_least_once.returns('500')
    lambda{
      @resource.put("this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::HttpServerError)
  end 
  
  it 'should raise redirected exception for 3xx response' do
    @response.expects(:code).at_least_once.returns('301')
    lambda{
      @resource.put("this=that", 'application/x-form-urlencoded')
    }.should raise_error(AdvancedHttp::HttpRequestRedirected)    
  end 

end

