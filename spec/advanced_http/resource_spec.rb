require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'advanced_http/resource'

describe AdvancedHttp::Resource, 'init' do
  it 'should be creatable with a URI' do
    AdvancedHttp::Resource.new('http://www.example/foo')
  end   
end

describe AdvancedHttp::Resource do
  before do
    @resource = AdvancedHttp::Resource.new('http://www.example/foo')
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
    Net::HTTP.expects(:start).with('www.example', 80).yields(http_conn).returns(response = stub('response', :code => '201'))
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
    AdvancedHttp::Resource.new('http://www.example/foo', :logger => stub('logger', :debug))
  end 
  
  it 'should #log should pass :info messages through to logger object' do
    resource = AdvancedHttp::Resource.new('http://www.example/foo', :logger => logger = stub('logger', :debug))
    
    logger.expects(:info).with('hello')
    
    resource.send(:log, :info, 'hello')
  end 

  it 'should #log should pass :debug messages through to logger object' do
    resource = AdvancedHttp::Resource.new('http://www.example/foo', :logger => logger = stub('logger', :debug))
    
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

describe AdvancedHttp::Resource, '#do_request (non-auth)' do
  before do
    @resource = AdvancedHttp::Resource.new('http://www.example/foo')
    @ok_response = stub('ok_response', :code => '200')
    
    @http_conn = mock('http_conn')
    Net::HTTP.expects(:start).with('www.example', 80).yields(@http_conn)
    @http_conn.stubs(:request).returns(@ok_response)

    @request = stub("http_req", :method => 'GET', :basic_auth => nil)
  end
  
  it 'should include response code in log message' do
    @resource.expects(:log).with(:info, regexp_matches(/\(200\)/))
    
    @resource.send(:do_request, @request)    
  end 
  
  it 'should include timing information in log message' do
    @resource.expects(:log).with(:info, regexp_matches(/\(0.000 sec\)/))
    
    @resource.send(:do_request, @request)        
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
    Net::HTTP.stubs(:start).with('www.example', 80).yields(@http_conn)
    @http_conn.stubs(:request).returns(@unauth_response, @ok_response)

    @request = stub("http_req", :method => 'GET', :basic_auth => nil, :authentication_scheme => 'basic', :authentication_realm => 'test_realm')
  end
  
  it 'should not include body in authenticated retry' do
    @http_conn.expects(:request).with(anything, 'testing').once.returns(@unauth_response)
    @http_conn.expects(:request).with(anything).once.returns(@ok_response)

    @resource.send(:do_request, @request, 'testing')    
  end 
  
  it 'should retry unauthorized requests with auth if possible' do
    @http_conn.expects(:request).times(2).returns(@unauth_response, @ok_response)
 
    @resource.send(:do_request, @request)    
  end 

  it 'should set basic auth on request before retry' do
    @http_conn.expects(:request).times(2).returns(@unauth_response, @ok_response)
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
  
  it 'should warn log if credentials are missing' do
    @auth_provider.expects(:authentication_info).returns(nil)

    @resource.expects(:log).with(:info, anything)
    @resource.expects(:log).with(:warn, "    No credentials known for test_realm")
    @resource.send(:do_request, @request)    
  end 
  
  it 'should set Accept request header if :accept options is passed' do
  
  end 
end 

describe AdvancedHttp::Resource, '#do_request (digest auth)' do
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

    @request = stub("http_req", :method => 'GET', :digest_auth => nil, :authentication_scheme => 'digest', :authentication_realm => 'test_realm')
  end
  
  it 'should retry unauthorized requests with auth if possible' do
    @http_conn.expects(:request).times(2).returns(@unauth_response, @ok_response)
 
    @resource.send(:do_request, @request)    
  end 

  it 'should set basic auth on request before retry' do
    @http_conn.expects(:request).times(2).returns(@unauth_response, @ok_response)
    @request.expects(:digest_auth).with('me', 'mine', @digest_challenge)
 
    @resource.send(:do_request, @request)    
  end 
  
  it 'should look up authentication information' do
    @auth_provider.expects(:authentication_info).with('test_realm').returns(['me', 'emin'])

    @resource.send(:do_request, @request)    
  end 
  
  it 'should log the retry' do
    @resource.expects(:log).with(:info, regexp_matches(/(digest_auth: realm='test_realm', account='me')/i))
    @resource.expects(:log).with(:info, anything)
    @resource.send(:do_request, @request)    
  end 
end 

describe AdvancedHttp::Resource, '#get_body' do
  before do
    @resource = AdvancedHttp::Resource.new('http://www.example/foo')
    @response = stub('http_response', :body => 'I am foo', :code => '200')
    @resource.stubs(:do_request).with(instance_of(Net::HTTP::Get)).returns(@response)
  end

  it 'should return the response body as a string' do
    @resource.get_body.should == 'I am foo'
  end 
  
  it 'should get body from response' do
    @response.expects(:body).returns('hello')
    @resource.get_body
  end 
  
  it 'should call get with passed options' do
    @resource.expects(:get).with(:accept => 'nonsense/foo').returns(@response)
    
    @resource.get_body(:accept => 'nonsense/foo')
  end 

  it 'should raise arg error for unrecognized options' do
    lambda {
      @resource.get_body(:foo => 'nonsense/foo', :bar => 'yer')
    }.should raise_error(ArgumentError, /Unrecognized option\(s\): (?:foo|bar), (?:foo|bar)/)
  end 
  
  it 'should recognize parse_as option' do
    lambda{
      @resource.get_body(:parse_as => :json)
    }.should_not raise_error(ArgumentError)
  end 

  it 'should raise arg error for unrecognized parser' do
    lambda{
      @resource.get_body(:parse_as => :nonsense)
    }.should raise_error(ArgumentError, "Unrecognized parser type nonsense")    
  end 
  
  it 'should parser JSON response body if parser is :json' do
    @response.stubs(:body).returns('{"this": ["a", null, 3]}')
    @resource.get_body(:parse_as => :json).should == {'this' => ['a', nil, 3]}
  end 
end 

describe AdvancedHttp::Resource, '#get_json_body' do
  before do
    @resource = AdvancedHttp::Resource.new('http://www.example/foo')
  end
  
  it 'should call get body with parse_as option set to :json' do   
    @resource.expects(:get_body).with(has_entry(:parse_as, :json)).returns({})
    @resource.get_json_body
  end

  it 'should pass options through to get_body' do
    @resource.expects(:get_body).with(has_entry(:accept, 'text/nonsense')).returns({})
    @resource.get_json_body(:accept => 'text/nonsense')
  end
end 

describe AdvancedHttp::Resource, '#get' do
  before do
    @resource = AdvancedHttp::Resource.new('http://www.example/foo')
    @response = stub('http_response', :body => 'I am foo', :code => '200')
    @resource.stubs(:do_request).with(instance_of(Net::HTTP::Get)).returns(@response)
  end

  it 'should return the HTTPResponse' do
    @resource.get.should == @response
  end 

  it 'should use http connection associated with resource' do
    @resource.expects(:do_request).with(instance_of(Net::HTTP::Get)).returns(@response)
    @resource.get
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
  
  it 'should accept header in request should be equivalent to :accept option if specified as string' do
    @resource.expects(:do_request).with{|req| req['accept'] == 'application/prs.api.test'}.returns(@response)
    @resource.get(:accept => 'application/prs.api.test')
  end 

  it 'should accept header in request should be equivalent to :accept option if specified as array of strings' do
    @resource.expects(:do_request).with{|req| req['accept'] == 'application/xml, application/prs.api.test'}.returns(@response)
    
    @resource.get(:accept => ['application/xml', 'application/prs.api.test'])
  end 

  it 'should accept header in request should be equivalent to :accept option if specified as array of to_str-ables' do
    mt1 = stub('mt1', :to_str => 'application/xml')
    mt2 = stub('mt2', :to_str => 'application/prs.api.test')
    
    @resource.expects(:do_request).with{|req| req['accept'] == 'application/xml, application/prs.api.test'}.returns(@response)
    @resource.get(:accept => ['application/xml', 'application/prs.api.test'])
  end 

  it 'should accept header in request should be */* if :accept option is not specified' do
    @resource.expects(:do_request).with{|req| req['accept'] == '*/*'}.returns(@response)
    @resource.get
  end 
  
  it 'should not accept unknown options' do
    lambda{
      @resource.get(:my_option => 'cool', :foo => :bar)
    }.should raise_error(ArgumentError, /Unrecognized option\(s\): (?:my_option, foo)|(?:foo, my_option)/)
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
      @resource.get.should == @ok_response
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
    @resource.get.should == @ok_response
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

    it 'should raise argument error for unsupported options' do
    lambda{
      @resource.post("this=that", 'application/x-form-urlencoded', :bar => 'foo')
    }.should raise_error(ArgumentError, "Unrecognized option(s): bar")
  end 
  
  it 'should support :accept option' do
    req = stub('request', :[]= => nil)
    Net::HTTP::Post.expects(:new).returns(req)
    req.expects(:[]=).with('accept', ['text/special'])
    @resource.post("this=that", 'application/x-form-urlencoded', :accept => 'text/special')
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

  it 'should make request to correct path' do
    @resource.expects(:do_request).with{|r,_| r.path == '/foo'}.returns(@response)
    @resource.put("this=that", 'application/x-form-urlencoded')
  end 

  it 'should raise argument error for unsupported options' do
    lambda{
      @resource.put("this=that", 'application/x-form-urlencoded', :bar => 'foo')
    }.should raise_error(ArgumentError, "Unrecognized option(s): bar")
  end 
  
  it 'should support :accept option' do
    req = stub('request', :[]= => nil)
    Net::HTTP::Put.expects(:new).returns(req)
    req.expects(:[]=).with('accept', ['text/special'])
    @resource.put("this=that", 'application/x-form-urlencoded', :accept => 'text/special')
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

