require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'advanced_http/resource'


describe AdvancedHttp::Resource, 'init' do
  it 'should require an owner and a URI' do
    accessor = stub('http_accessor')
    AdvancedHttp::Resource.new(accessor, 'http://www.example/foo')
  end   
  
end

describe AdvancedHttp::Resource do
  before do
    @logger = stub('logger', :info => false, :debug => false)
    @auth_manager = stub('auth_manager', :auth_info_available_for? => false)
    @accessor = stub('http_accessor', :logger => @logger, :auth_manager => @auth_manager)
    @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo')
  end

  it "should know it's URI" do
    @resource.uri.should == Addressable::URI.parse('http://www.example/foo')
  end
  
  it 'should be creatable with a URI' do
    AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo')
  end 

  it 'should execute request against remote server' do
    req = stub("http_req", :method => 'GET')
    http_conn = stub('http_conn')
    response = stub('response', :code => '200')
    Net::HTTP.expects(:start).with('www.example', 80).yields(http_conn).returns(response)
    http_conn.expects(:request).with(req, nil).returns(response)
    
    @resource.send(:do_request, req).should == response
  end 

  it 'should send body to remote server if provided' do
    req = stub("http_req", :method => 'POST')
    http_conn = mock('http_conn')
    Net::HTTP.expects(:start).with('www.example', 80).yields(http_conn).returns(response = stub('response', :code => '201'))
    http_conn.expects(:request).with(req, "body").returns(response)
    
    @resource.send(:do_request, req, "body").should == response
  end 
  
  it 'should provide effective URI attribute' do
    @resource.effective_uri.should == Addressable::URI.parse('http://www.example/foo')
  end 
  
  it 'should forget current effective URI upon reset' do
    @resource.send(:effective_uri=, 'http://www.example/bar')
    @resource.effective_uri.should == Addressable::URI.parse('http://www.example/bar')
    @resource.reset
    @resource.effective_uri.should == Addressable::URI.parse('http://www.example/foo')
  end 
  
end 

describe AdvancedHttp::Resource, '#do_request (non-auth)' do
  before do
    @logger = stub('logger', :info => false, :debug => false)
    @auth_manager = stub('auth_manager', :auth_info_available_for? => false)
    @accessor = stub('http_accessor', :logger => @logger, :auth_manager => @auth_manager)

    @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo')
    @ok_response = stub('ok_response', :code => '200')
    
    @http_conn = stub('http_conn')
    Net::HTTP.expects(:start).with('www.example', 80).yields(@http_conn)
    @http_conn.stubs(:request).returns(@ok_response)

    @request = stub("http_req", :method => 'GET', :basic_auth => nil)
  end
  
  it 'should attach request information to exceptions raised' do
    @http_conn.stubs(:request).raises(SocketError.new('getaddreinfo: Name or service not known'))
    
    lambda {
      @resource.send(:do_request, @request)        
    }.should raise_error(SocketError, 'getaddreinfo: Name or service not known (while GET http://www.example/foo)')
  end 
end

describe AdvancedHttp::Resource, '#do_request (auth)' do
  before do
    @logger = stub('logger', :info => false, :debug => false)
    @auth_manager = stub('auth_manager', :auth_info_available_for? => false, :register_challenge => nil, :credentials_for => 'Digest foo=bar')
    @accessor = stub('http_accessor', :logger => @logger, :auth_manager => @auth_manager)

    @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo')
    
    @unauth_response = stub('unauth_response', :code => '401', :digest_auth_allowed? => false, 
                            :basic_auth_allowed? => true, :realm => 'test_realm')
    @ok_response = stub('ok_response', :code => '200')
    
    @http_conn = mock('http_conn')
    Net::HTTP.stubs(:start).with('www.example', 80).yields(@http_conn)
    @http_conn.stubs(:request).returns(@unauth_response, @ok_response)

    @request = stub("http_req", :method => 'GET', :basic_auth => nil, :authentication_scheme => 'basic', :authentication_realm => 'test_realm', :[]= => nil)
  end
  
  it 'should not include body in authenticated retry (because it is already stored on the request object from the first time around)' do
    @http_conn.expects(:request).with(anything, 'testing').once.returns(@unauth_response)
    @http_conn.expects(:request).with(anything).once.returns(@ok_response)

    @resource.send(:do_request, @request, 'testing')    
  end 
  
  it 'should retry unauthorized requests with auth if possible' do
    @http_conn.expects(:request).times(2).returns(@unauth_response, @ok_response)
 
    @resource.send(:do_request, @request)    
  end 

  it 'should set auth info on request before retry' do
    @http_conn.expects(:request).times(2).returns(@unauth_response, @ok_response)
    @auth_manager.expects(:credentials_for).once.
      with{|r,u| r.equal?(@request) && u.to_s == 'http://www.example/foo'}.returns('Digest bar=baz')
    @request.expects(:[]=).with('Authorization', 'Digest bar=baz')
    
    @resource.send(:do_request, @request)    
  end 

  it 'should register challenge if initial response is unauthorized' do 
    @http_conn.expects(:request).times(2).returns(@unauth_response, @ok_response)
    @auth_manager.expects(:register_challenge).with(@unauth_response, Addressable::URI.parse('http://www.example/foo'))
 
    @resource.send(:do_request, @request)    
  end 
  
  it 'should log the retry' do
    @logger.expects(:info).times(2)
    
    @resource.send(:do_request, @request)    
  end   
  
  it 'should set auth info before request if it is available' do
    @http_conn.expects(:request).times(1).returns(@ok_response)
    @auth_manager.expects(:auth_info_available_for?).with(Addressable::URI.parse('http://www.example/foo')).returns(true)
    @auth_manager.expects(:credentials_for).once.with {|r,u| r.equal?(@request) && u.to_s == 'http://www.example/foo'}.returns("Digest foo")
    
    @resource.send(:do_request, @request)    
  end 

  it 'should set auth info before request if it is available' do
    @http_conn.expects(:request).times(1).returns(@ok_response)
    @auth_manager.expects(:auth_info_available_for?).with(Addressable::URI.parse('http://www.example/foo')).returns(true)
    @auth_manager.expects(:credentials_for).once.with{|r,u| r.equal?(@request) && u.to_s == 'http://www.example/foo'}.
      returns('Digest bar=baz')
    @request.expects(:[]=).with('Authorization', 'Digest bar=baz')
    
    @resource.send(:do_request, @request)    
  end 
end 

describe AdvancedHttp::Resource, '#get_body' do
  before do
    @accessor = stub('http_accessor')

    @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo')
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
    @accessor = stub('http_accessor')

    @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo')
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
    @accessor = stub('http_accessor')
    @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo')
    @response = stub('http_response', :body => 'I am foo', :code => '200', :message => 'OK')
    @resource.stubs(:do_request).with(instance_of(Net::HTTP::Get)).returns(@response)
  end

  it 'should return the HTTPResponse' do
    @resource.get.should == @response
  end 

  it 'should use http connection associated with resource' do
    @resource.expects(:do_request).with(instance_of(Net::HTTP::Get)).returns(@response)
    @resource.get
  end 
  
  it 'should not raise error for any 2xx response code' do
    @response.expects(:code).at_least_once.returns('202')
    lambda{
      @resource.get
    }.should_not raise_error
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

  it 'should raise reasonable exception when hostname lookup fails' do
    
  end 
  
end 
describe AdvancedHttp::Resource, '#get (URI with query string)' do
  before do
    @accessor = stub('http_accessor')
    @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo?q=test')
    @response = stub('http_response', :body => 'I am foo', :code => '200')
    @resource.stubs(:do_request).with(instance_of(Net::HTTP::Get)).returns(@response)
  end
  
  it "should make get request to server" do
    @resource.expects(:do_request).with{|req| req.path == 'http://www.example/foo?q=test'}.returns(@response)
    @resource.get
  end 
end

describe AdvancedHttp::Resource, '#get (unacceptable redirection)' do
  before do
    @accessor = stub('http_accessor')
    @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo')
    @redir_response = stub('http_response', :code => '300', :message => 'Multiple Choices')
    @redir_response.stubs(:[]).with('location').returns('http://www.example/bar')
    
    @resource.stubs(:do_request).returns(@redir_response)
  end
  
  ['300','303','304','305'].each do |code|
    it "should raise redirection error for #{code} response" do
      @redir_response.stubs(:code).returns('300')
      
      lambda{
        @resource.get
      }.should raise_error(AdvancedHttp::HttpRedirectionError)
      
    end 
  end
  
end 

[['307', 'Temporary'], ['302', 'Found']].each do |code, message|
  describe AdvancedHttp::Resource, "#get (#{message} redirection)" do
    before do
      @accessor = stub('http_accessor')
      @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo')
      @redir_response = stub('http_response', :code => code)
      @redir_response.stubs(:[]).with('location').returns('http://www.example/bar')
      @ok_response = stub('http_response', :code => '200', :body => "I am foo (bar)") 
      
      @resource.stubs(:do_request).returns(@redir_response, @ok_response)
    end
    
    it 'should follow redirect' do
      @resource.expects(:do_request).with{|r| r.path == 'http://www.example/foo'}.returns(@redir_response)
      @resource.expects(:do_request).with{|r| r.path == 'http://www.example/bar'}.returns(@ok_response)
      
      @resource.get
    end 

    it 'should not reset URI' do
      @resource.get
      
      @resource.uri.should == Addressable::URI.parse('http://www.example/foo')
    end 

    it 'should set effective URI' do
      @resource.get
      
      @resource.effective_uri.should == Addressable::URI.parse('http://www.example/bar')
    end 

    it 'should return body of second response' do
      @resource.get.should == @ok_response
    end 

  end 
end

describe AdvancedHttp::Resource, '#get (Permanent redirection)' do
  before do
    @accessor = stub('http_accessor')
    @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo')
    @redir_response = stub('http_response', :code => '301')
    @redir_response.stubs(:[]).with('location').returns('http://www.example/bar')
    @ok_response = stub('http_response', :code => '200', :body => "I am foo (bar)") 
    
    @resource.stubs(:do_request).returns(@redir_response, @ok_response)
  end
  
  it 'should follow redirect' do
    @resource.expects(:do_request).with{|r| r.path == 'http://www.example/foo'}.returns(@redir_response)
    @resource.expects(:do_request).with{|r| r.path == 'http://www.example/bar'}.returns(@ok_response)
    
    @resource.get
  end 

  it 'should reset URI' do
    @resource.get
    @resource.uri.should == Addressable::URI.parse('http://www.example/bar')
  end 
  
  it 'should return body of second response' do
    @resource.get.should == @ok_response
  end 

end 

describe AdvancedHttp::Resource, '#post' do
  before do
    @accessor = stub('http_accessor')
    @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo')
    @response = stub('http_response', :is_a? => false, :body => 'Created', :code => '201', :message => 'Created')
    @response.stubs(:[]).with('location').returns('http://www.example/foo/42')
    
    @resource.stubs(:do_request).returns(@response)
  end

  it 'should make request to the effective_uri' do
    @resource.send(:effective_uri=, 'http://www.example/bar')
    @resource.expects(:do_request).with{|r,_| r.path =='http://www.example/bar'}.returns(@response)

    @resource.post("this=that", 'application/x-form-urlencoded')
  end 

  it 'should include query string in request uri if there is one' do
    @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo?q=test')
    
    @resource.expects(:do_request).with{|r,_| r.path =='http://www.example/foo?q=test'}.returns(@response)

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
    }.should raise_error(AdvancedHttp::HttpRedirectionError)    
  end 

  it 'should return response to get against redirect target for 303 response' do
    see_other_response = stub('http_see_other_response',  :body => 'ok_response', :code => '303')
    see_other_response.expects(:[]).with('location').returns('http://alt.example/bar')
    
    @resource.expects(:do_request).with{|r,_| r.method == 'POST' and r.path == 'http://www.example/foo'}.returns(see_other_response)

    AdvancedHttp::Resource.expects(:new).with('http://alt.example/bar').
      returns(secondary_resource = mock('resource2'))
    ok_response = stub('http_ok_response',  :body => 'ok_response', :code => '200')
    secondary_resource.expects(:get_response).returns(ok_response)
    
    @resource.post("this=that", 'application/x-form-urlencoded')
  end 

end

describe AdvancedHttp::Resource, '#put' do
  before do
    @logger = stub('logger', :info => false, :debug => false)
    @auth_manager = stub('auth_manager', :auth_info_available_for? => false)
    @accessor = stub('http_accessor', :logger => @logger, :auth_manager => @auth_manager)

    @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo')
    @response = stub('http_response', :is_a? => false, :body => 'Created', :code => '201', :message => 'Created')
    @response.stubs(:[]).with('location').returns('http://www.example/foo/42')
    
    @resource.stubs(:do_request).returns(@response)
  end

  it 'should make request to correct path' do
    @resource.expects(:do_request).with{|r,_| r.path == 'http://www.example/foo'}.returns(@response)
    @resource.put("this=that", 'application/x-form-urlencoded')
  end 

  it 'should make request to correct path' do
    @resource = AdvancedHttp::Resource.new(@accessor, 'http://www.example/foo?q=test')
    @resource.expects(:do_request).with{|r,_| r.path == 'http://www.example/foo?q=test'}.returns(@response)
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
    @resource.expects(:do_request).with{|r,_| r.path == 'http://www.example.com/bar'}.returns(@response)
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
    }.should raise_error(AdvancedHttp::HttpRedirectionError)    
  end 

end

