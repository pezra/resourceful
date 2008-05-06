require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/resource'


describe Resourceful::Resource, 'init' do
  it 'should require an owner and a URI' do
    accessor = mock('http_accessor')
    Resourceful::Resource.new(accessor, 'http://www.example/foo')
  end   
  
end

describe Resourceful::Resource do
  before do
    @logger = mock('logger', :info => false, :debug => false)
    @auth_manager = mock('auth_manager', :auth_info_available_for? => false)
    @accessor = mock('http_accessor', :logger => @logger, :auth_manager => @auth_manager, :user_agent_string => 'test/1.0')
    @resource = Resourceful::Resource.new(@accessor, 'http://www.example/foo')
  end

  it "should know it's URI" do
    @resource.uri.should == 'http://www.example/foo'
  end
  
  it 'should be creatable with a URI' do
    Resourceful::Resource.new(@accessor, 'http://www.example/foo')
  end 

  it 'should execute request against remote server' do
    req = mock("http_req", :method => 'GET', :[] => nil, :[]= => nil)
    http_conn = mock('http_conn')
    response = mock('response', :code => '200')
    Net::HTTP.should_receive(:start).with('www.example', 80).and_yield(http_conn).and_return(response)
    http_conn.should_receive(:request).with(req, nil).and_return(response)
    
    @resource.send(:do_request, req).should == response
  end 

  it 'should send body to remote server if provided' do
    req = mock("http_req", :method => 'POST', :[] => nil, :[]= => nil)
    http_conn = mock('http_conn')
    Net::HTTP.should_receive(:start).with('www.example', 80).and_yield(http_conn).and_return(response = mock('response', :code => '201'))
    http_conn.should_receive(:request).with(req, "body").and_return(response)
    
    @resource.send(:do_request, req, "body").should == response
  end 
  
  it 'should provide effective URI attribute' do
    @resource.effective_uri.should == 'http://www.example/foo'
  end 
  
  it 'should forget current effective URI upon reset' do
    @resource.send(:effective_uri=, 'http://www.example/bar')
    @resource.effective_uri.should == 'http://www.example/bar'
    @resource.reset
    @resource.effective_uri.should == 'http://www.example/foo'
  end 
  
end 

describe Resourceful::Resource, '#do_request' do
  before do
    @logger = mock('logger', :info => false, :debug => false)
    @auth_manager = mock('auth_manager')
    @auth_manager.stub!(:auth_info_available_for?).and_return(false,true)
    @accessor = mock('http_accessor', :logger => @logger, :auth_manager => @auth_manager, :user_agent_string => "us/1.0")

    @resource = Resourceful::Resource.new(@accessor, 'http://www.example/foo')
    @ok_response = mock('ok_response', :code => '200')
    
    @http_conn = mock('http_conn')
    Net::HTTP.should_receive(:start).at_least(1).times.with('www.example', 80).and_yield(@http_conn)
    @http_conn.stub!(:request).and_return(@ok_response)

    @request = mock("http_req", :method => 'GET', :basic_auth => nil, :[]= => nil, :[] => nil)
  end
  
  it 'should attach request information to exceptions raised' do
    @http_conn.stub!(:request).and_raise(SocketError.new('getaddreinfo: Name or service not known'))
    
    lambda {
      @resource.send(:do_request, @request)        
    }.should raise_error(SocketError, 'getaddreinfo: Name or service not known (while GET http://www.example/foo)')
  end 

  it 'should set the user agent header field' do
    @accessor.should_receive(:user_agent_string).and_return('user-agent-marker-string')
    @request.should_receive(:[]=).with('User-Agent', 'user-agent-marker-string')
    @resource.send(:do_request, @request)
  end 
  
  describe Resourceful::Resource, '#do_request (auth)' do
    before do
      @auth_manager = mock('auth_manager', :auth_info_available_for? => [false,true], :register_challenge => nil, :credentials_for => 'Digest foo=bar')
      @accessor.stub!(:auth_manager).and_return(@auth_manager)
      @unauth_response = mock('unauth_response', :code => '401', :digest_auth_allowed? => false, 
                              :basic_auth_allowed? => true, :realm => 'test_realm')
      @http_conn.stub!(:request).and_return(@unauth_response, @ok_response)
      @request = mock("http_req", :method => 'GET', :basic_auth => nil, :authentication_scheme => 'basic', :authentication_realm => 'test_realm', :[]= => nil)
      @request.stub!(:[]).with('Authorization').and_return(nil, 'Digest foo=bar')
    end
    
    it 'should not include body in authenticated retry (because it is already stored on the request object from the first time around)' do
      @http_conn.should_receive(:request).with(anything, 'testing').once.and_return(@unauth_response)
      @http_conn.should_receive(:request).with(anything, nil).once.and_return(@ok_response)

      @resource.send(:do_request, @request, 'testing')    
    end 
    
    it 'should retry unauthorized requests with auth if possible' do
      @http_conn.should_receive(:request).exactly(2).times.and_return(@unauth_response, @ok_response)
      
      @resource.send(:do_request, @request)    
    end 

    it 'should set auth info on request before retry' do
      @http_conn.should_receive(:request).exactly(2).times.and_return(@unauth_response, @ok_response)
      @auth_manager.should_receive(:credentials_for){|r,u| r.equal?(@request) && u.to_s == 'http://www.example/foo'; 'Digest bar=baz'}.at_least(:once)
      @request.should_receive(:[]=).with('Authorization', 'Digest bar=baz').at_least(:once)
      
      @resource.send(:do_request, @request)    
    end 

    it 'should register challenge if initial response is unauthorized' do 
      @http_conn.should_receive(:request).exactly(2).times.and_return(@unauth_response, @ok_response)
      @auth_manager.should_receive(:register_challenge).with(@unauth_response, Addressable::URI.parse('http://www.example/foo'))
      
      @resource.send(:do_request, @request)    
    end 
    
    it 'should log the retry' do
      @logger.should_receive(:info).exactly(2).times
      
      @resource.send(:do_request, @request)    
    end   
    
    it 'should set auth info before request if it is available' do
      @http_conn.should_receive(:request).exactly(1).times.and_return(@ok_response)
      @auth_manager.should_receive(:auth_info_available_for?).with(Addressable::URI.parse('http://www.example/foo')).and_return(true)
      @auth_manager.should_receive(:credentials_for).once{|r,u| r.equal?(@request) && u.to_s == 'http://www.example/foo'; "Digest foo"}
      
      @resource.send(:do_request, @request)    
    end 

    it 'should set auth info before request if it is available' do
      @http_conn.should_receive(:request).exactly(1).times.and_return(@ok_response)
      @auth_manager.should_receive(:auth_info_available_for?).with(Addressable::URI.parse('http://www.example/foo')).and_return(true)
      @auth_manager.should_receive(:credentials_for).once{|r,u| r.equal?(@request) && u.to_s == 'http://www.example/foo'; 'Digest bar=baz'}
      @request.should_receive(:[]=).with('Authorization', 'Digest bar=baz')
      
      @resource.send(:do_request, @request)    
    end 
  end 
end

describe Resourceful::Resource, '#get' do
  before do
    @accessor = mock('http_accessor')
    @resource = Resourceful::Resource.new(@accessor, 'http://www.example/foo')
    @response = mock('http_response', :body => 'I am foo', :code => '200', :message => 'OK')
    @resource.stub!(:do_request).and_return(@response)
  end

  it 'should return the HTTPResponse' do
    @resource.get.should == @response
  end 

  it 'should use http connection associated with resource' do
    @resource.should_receive(:do_request).with(an_instance_of(Net::HTTP::Get)).and_return(@response)
    @resource.get
  end 
  
  it 'should not raise error for any 2xx response code' do
    @response.should_receive(:code).at_least(1).times.and_return('202')
    lambda{
      @resource.get
    }.should_not raise_error
  end 
  
  it 'should raise client error for 4xx response codes' do
    @response.should_receive(:code).at_least(1).times.and_return('400')
    lambda{
      @resource.get      
    }.should raise_error(Resourceful::HttpClientError)
  end 
  
  it 'should raise server error for 5xx response codes' do
    @response.should_receive(:code).at_least(1).times.and_return('500')
    lambda{
      @resource.get      
    }.should raise_error(Resourceful::HttpServerError)    
  end 
  
  it "should make get request to server" do
    @resource.should_receive(:do_request){|req| req.path == '/foo'; @response}
    @resource.get
  end 
  
  it 'should accept header in request should be equivalent to :accept option if specified as string' do
    @resource.should_receive(:do_request){|req| req['accept'] == 'application/prs.api.test'; @response}
    @resource.get(:accept => 'application/prs.api.test')
  end 

  it 'should accept header in request should be equivalent to :accept option if specified as array of strings' do
    @resource.should_receive(:do_request){|req| req['accept'] == 'application/xml, application/prs.api.test'; @response}
    
    @resource.get(:accept => ['application/xml', 'application/prs.api.test'])
  end 

  it 'should accept header in request should be equivalent to :accept option if specified as array of to_str-ables' do
    mt1 = mock('mt1', :to_str => 'application/xml')
    mt2 = mock('mt2', :to_str => 'application/prs.api.test')
    
    @resource.should_receive(:do_request){|req| req['accept'] == 'application/xml, application/prs.api.test'; @response}
    @resource.get(:accept => ['application/xml', 'application/prs.api.test'])
  end 

  it 'should accept header in request should be */* if :accept option is not specified' do
    @resource.should_receive(:do_request){|req| req['accept'] == '*/*'; @response}
    @resource.get
  end 
  
  it 'should not accept unknown options' do
    lambda{
      @resource.get(:my_option => 'cool', :foo => :bar)
    }.should raise_error(ArgumentError, /Unrecognized options: (?:my_option, foo)|(?:foo, my_option)/)
  end 

  it 'should raise reasonable exception when hostname lookup fails' do
    
  end 
  
  it 'should not follow more than max_redirects redirections' do
    response1 = mock('http_response1', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/bar')
    response2 = mock('http_response2', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/baz')
    response3 = mock('http_response3', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/blah')
    @resource.should_receive(:do_request).exactly(3).times.and_return(response1, response2, response3)
    
    lambda {
      @resource.get(:max_redirects => 2)
    }.should raise_error(Resourceful::TooManyRedirectsError)
  end 

  it 'should not follow circular redirects' do
    response1 = mock('http_response1', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/bar')
    response2 = mock('http_response2', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/foo')
    @resource.should_receive(:do_request).exactly(2).times.and_return(response1, response2)
    
    lambda {
      @resource.get()
    }.should raise_error(Resourceful::CircularRedirectionError)
  end 
  
  it 'should set headers on request if specified' do
    get_request = mock('get_request', :[] => nil)
    Net::HTTP::Get.should_receive(:new).and_return(get_request)
    get_request.should_receive(:[]=).with('X-Test', 'this-is-a-test')
    
    @resource.get(:http_header_fields => {'X-Test' => 'this-is-a-test'})
  end
end 

describe Resourceful::Resource, '#get (URI with query string)' do
  before do
    @accessor = mock('http_accessor')
    @resource = Resourceful::Resource.new(@accessor, 'http://www.example/foo?q=test')
    @response = mock('http_response', :body => 'I am foo', :code => '200')
    @resource.stub!(:do_request).with(an_instance_of(Net::HTTP::Get)).and_return(@response)
  end
  
  it "should make get request to server" do
    @resource.should_receive(:do_request){|req| req.path == 'http://www.example/foo?q=test'; @response}
    @resource.get
  end 
end

describe Resourceful::Resource, '#get (unacceptable redirection)' do
  before do
    @accessor = mock('http_accessor')
    @resource = Resourceful::Resource.new(@accessor, 'http://www.example/foo')
    @redir_response = mock('http_response', :code => '300', :message => 'Multiple Choices')
    @redir_response.stub!(:[]).with('location').and_return('http://www.example/bar')
    
    @resource.stub!(:do_request).and_return(@redir_response)
  end
  
  ['300','303','304','305'].each do |code|
    it "should raise redirection error for #{code} response" do
      @redir_response.stub!(:code).and_return('300')
      
      lambda{
        @resource.get
      }.should raise_error(Resourceful::HttpRedirectionError)
      
    end 
  end
  
end 

[['307', 'Temporary'], ['302', 'Found']].each do |code, message|
  describe Resourceful::Resource, "#get (#{message} redirection)" do
    before do
      @accessor = mock('http_accessor')
      @resource = Resourceful::Resource.new(@accessor, 'http://www.example/foo')
      @redir_response = mock('http_response', :code => code)
      @redir_response.stub!(:[]).with('location').and_return('http://www.example/bar')
      @ok_response = mock('http_response', :code => '200', :body => "I am foo (bar)") 
      
      @resource.stub!(:do_request).and_return(@redir_response, @ok_response)
    end
    
    it 'should follow redirect' do
      @resource.should_receive(:do_request).with(duck_type(:path)).twice.and_return{|r| 
        case r.path 
        when 'http://www.example/foo' then @redir_response
        when 'http://www.example/bar' then @ok_response
        else raise "Bad Redirect"
        end
      }

      @resource.get
    end 

    it 'should not reset URI' do
      @resource.get
      
      @resource.uri.should == 'http://www.example/foo'
    end 

    it 'should set effective URI' do
      @resource.get
      
      @resource.effective_uri.should == 'http://www.example/bar'
    end 

    it 'should return body of second response' do
      @resource.get.should == @ok_response
    end 

  end 
end

describe Resourceful::Resource, '#get (Permanent redirection)' do
  before do
    @accessor = mock('http_accessor')
    @resource = Resourceful::Resource.new(@accessor, 'http://www.example/foo')
    @redir_response = mock('http_response', :code => '301')
    @redir_response.stub!(:[]).with('location').and_return('http://www.example/bar')
    @ok_response = mock('http_response', :code => '200', :body => "I am foo (bar)") 
    
    @resource.stub!(:do_request).and_return(@redir_response, @ok_response)
  end
  
  it 'should follow redirect' do
    @resource.should_receive(:do_request).with(duck_type(:path)).twice.and_return{|r| 
      case r.path 
      when 'http://www.example/foo' then @redir_response
      when 'http://www.example/bar' then @ok_response
      else raise "Bad Redirect"
      end
    }
    
    @resource.get
  end 

  it 'should reset URI' do
    @resource.get
    @resource.uri.should == 'http://www.example/bar'
  end 
  
  it 'should return body of second response' do
    @resource.get.should == @ok_response
  end 

end 

describe Resourceful::Resource, '#post' do
  before do
    @accessor = mock('http_accessor')
    @resource = Resourceful::Resource.new(@accessor, 'http://www.example/foo')
    @response = mock('http_response', :is_a? => false, :body => 'Created', :code => '201', :message => 'Created')
    @response.stub!(:[]).with('location').and_return('http://www.example/foo/42')
    
    @resource.stub!(:do_request).and_return(@response)
  end

  it 'should make request to the effective_uri' do
    @resource.send(:effective_uri=, 'http://www.example/bar')
    @resource.should_receive(:do_request){|r,_| r.path =='http://www.example/bar'; @response}

    @resource.post("this=that", 'application/x-form-urlencoded')
  end 

  it 'should include query string in request uri if there is one' do
    @resource = Resourceful::Resource.new(@accessor, 'http://www.example/foo?q=test')
    
    @resource.should_receive(:do_request){|r,_| r.path =='http://www.example/foo?q=test'; @response}

    @resource.post("this=that", 'application/x-form-urlencoded')
  end 

  
  it 'should raise argument error for unsupported options' do
    lambda{
      @resource.post("this=that", 'application/x-form-urlencoded', :bar => 'foo')
    }.should raise_error(ArgumentError, "Unrecognized options: bar")
  end 
  
  it 'should support :accept option' do
    req = mock('request', :[]= => nil)
    Net::HTTP::Post.should_receive(:new).and_return(req)
    req.should_receive(:[]=).with('accept', ['text/special'])
    @resource.post("this=that", 'application/x-form-urlencoded', :accept => 'text/special')
  end 
  
  it 'should request obj should have content-type set' do
    @resource.should_receive(:do_request){|r,_| r['content-type'] =='application/prs.foo.bar'; @response}
    
    @resource.post("this=that", 'application/prs.foo.bar')
  end 

  it 'should set request body' do
    @resource.should_receive(:do_request).with(anything, 'this=that').and_return(@response)
    
    @resource.post("this=that", 'application/prs.foo.bar')
  end 

  it 'should return http response object if response is 2xx' do
    @resource.post("this=that", 'application/x-form-urlencoded').should == @response
  end 
  
  it 'should raise client error for 4xx response' do
    @response.should_receive(:code).at_least(1).times.and_return('404')
    lambda{
      @resource.post("this=that", 'application/x-form-urlencoded')
    }.should raise_error(Resourceful::HttpClientError)
  end 

  it 'should raise client error for 5xx response' do
    @response.should_receive(:code).at_least(1).times.and_return('500')
    lambda{
      @resource.post("this=that", 'application/x-form-urlencoded')
    }.should raise_error(Resourceful::HttpServerError)
  end 
  
  it 'should raise redirected exception for 305 response' do
    @response.should_receive(:code).at_least(1).times.and_return('305')
    lambda{
      @resource.post("this=that", 'application/x-form-urlencoded')
    }.should raise_error(Resourceful::HttpRedirectionError)    
  end 

  it 'should return response to GET against redirect target for 303 responses' do
    see_other_response = mock('http_see_other_response',  :body => 'ok_response', :code => '303')
    see_other_response.should_receive(:[]).with('location').and_return('http://alt.example/bar')
    
    @resource.should_receive(:do_request){|r,_| r.method == 'POST' and r.path == 'http://www.example/foo'; see_other_response}

    Resourceful::Resource.should_receive(:new).with('http://alt.example/bar').
      and_return(secondary_resource = mock('resource2'))
    ok_response = mock('http_ok_response',  :body => 'ok_response', :code => '200')
    secondary_resource.should_receive(:get_response).and_return(ok_response)
    
    @resource.post("this=that", 'application/x-form-urlencoded')
  end 

  it 'should return 303 responses if :ignore_redirects is true' do
    see_other_response = mock('http_see_other_response',  :body => 'ok_response', :code => '303')
    @resource.should_receive(:do_request).and_return(see_other_response)

    @resource.post("this=that", 'application/x-form-urlencoded', :ignore_redirects => true).should == see_other_response
  end 

  
  it 'should not follow more than max_redirects redirections' do
    response1 = mock('http_response1', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/bar')
    response2 = mock('http_response2', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/baz')
    response3 = mock('http_response3', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/blah')
    @resource.should_receive(:do_request).exactly(3).times.and_return(response1, response2, response3)
    
    lambda {
      @resource.post("this=that", 'application/x-form-urlencoded', :max_redirects => 2)
    }.should raise_error(Resourceful::TooManyRedirectsError)
  end 

  it 'should not follow circular redirects' do
    response1 = mock('http_response1', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/bar')
    response2 = mock('http_response2', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/foo')
    @resource.should_receive(:do_request).exactly(2).times.and_return(response1, response2)
    
    lambda {
      @resource.post("this=that", 'application/x-form-urlencoded')
    }.should raise_error(Resourceful::CircularRedirectionError)
  end 

  it 'should not follow redirects :ignore_redirects is set to true' do
    response1 = mock('http_response1', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/bar')
    @resource.should_receive(:do_request).exactly(1).times.and_return(response1)
    
    @resource.post("this=that", 'application/x-form-urlencoded', :ignore_redirects => true).should == response1
    
  end
  
  it 'should set headers on request if specified' do
    post_request = mock('get_request', :[]= => nil)
    Net::HTTP::Post.should_receive(:new).and_return(post_request)
    post_request.should_receive(:[]=).with('X-Test', 'this-is-a-test')
    
    @resource.post("this=that", 'application/x-www-form-urlencoded', :http_header_fields => {'X-Test' => 'this-is-a-test'})
  end

end

describe Resourceful::Resource, '#put' do
  before do
    @logger = mock('logger', :info => false, :debug => false)
    @auth_manager = mock('auth_manager', :auth_info_available_for? => false)
    @accessor = mock('http_accessor', :logger => @logger, :auth_manager => @auth_manager)

    @resource = Resourceful::Resource.new(@accessor, 'http://www.example/foo')
    @response = mock('http_response', :is_a? => false, :body => 'Created', :code => '201', :message => 'Created')
    @response.stub!(:[]).with('location').and_return('http://www.example/foo/42')
    
    @resource.stub!(:do_request).and_return(@response)
  end

  it 'should make request to correct path' do
    @resource.should_receive(:do_request){|r,_| r.path == 'http://www.example/foo'; @response}
    @resource.put("this=that", 'application/x-form-urlencoded')
  end 

  it 'should make request to correct path' do
    @resource = Resourceful::Resource.new(@accessor, 'http://www.example/foo?q=test')
    @resource.should_receive(:do_request){|r,_| r.path == 'http://www.example/foo?q=test'; @response}
    @resource.put("this=that", 'application/x-form-urlencoded')
  end 

  it 'should raise argument error for unsupported options' do
    lambda{
      @resource.put("this=that", 'application/x-form-urlencoded', :bar => 'foo')
    }.should raise_error(ArgumentError, "Unrecognized options: bar")
  end 
  
  it 'should support :accept option' do
    req = mock('request', :[]= => nil)
    Net::HTTP::Put.should_receive(:new).and_return(req)
    req.should_receive(:[]=).with('accept', ['text/special'])
    @resource.put("this=that", 'application/x-form-urlencoded', :accept => 'text/special')
  end 
  
  it 'should make request with body' do
    @resource.should_receive(:do_request).with(an_instance_of(Net::HTTP::Put), 'this=that').and_return(@response)
    @resource.put("this=that", 'application/x-form-urlencoded')
  end 

  it 'should make request with correct content' do
    @resource.should_receive(:do_request){|r,_| r['content-type'] == 'application/prs.api.test'; @response}
    @resource.put("this=that", 'application/prs.api.test')
  end 

  it 'should make put request effective_uri' do
    @resource.send(:effective_uri=, 'http://www.example.com/bar')
    @resource.should_receive(:do_request){|r,_| r.path == 'http://www.example.com/bar'; @response}
    @resource.put("this=that", 'application/x-form-urlencoded')
  end 
  
  it 'should return http response object if response is 2xx' do
    @resource.put("this=that", 'application/x-form-urlencoded').should == @response
  end 
  
  it 'should raise client error for 4xx response' do
    @response.should_receive(:code).at_least(1).times.and_return('404')
    lambda{
      @resource.put("this=that", 'application/x-form-urlencoded')
    }.should raise_error(Resourceful::HttpClientError)
  end 

  it 'should raise client error for 5xx response' do
    @response.should_receive(:code).at_least(1).times.and_return('500')
    lambda{
      @resource.put("this=that", 'application/x-form-urlencoded')
    }.should raise_error(Resourceful::HttpServerError)
  end 
  
  it 'should raise redirected exception for 305 response' do
    @response.should_receive(:code).at_least(1).times.and_return('305')
    lambda{
      @resource.put("this=that", 'application/x-form-urlencoded')
    }.should raise_error(Resourceful::HttpRedirectionError)    
  end 

  it 'should raise redirected exception for 303 response' do
    @response.should_receive(:code).at_least(1).times.and_return('303')
    lambda{
      @resource.put("this=that", 'application/x-form-urlencoded')
    }.should raise_error(Resourceful::HttpRedirectionError)    
  end 

  it 'should not follow more than max_redirects redirections' do
    response1 = mock('http_response1', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/bar')
    response2 = mock('http_response2', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/baz')
    response3 = mock('http_response3', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/blah')
    @resource.should_receive(:do_request).exactly(3).times.and_return(response1, response2, response3)
    
    lambda {
      @resource.put("this=that", 'application/x-form-urlencoded', :max_redirects => 2)
    }.should raise_error(Resourceful::TooManyRedirectsError)
  end 

  it 'should not follow circular redirects' do
    response1 = mock('http_response1', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/bar')
    response2 = mock('http_response2', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/foo')
    @resource.should_receive(:do_request).exactly(2).times.and_return(response1, response2)
    
    lambda {
      @resource.put("this=that", 'application/x-form-urlencoded')
    }.should raise_error(Resourceful::CircularRedirectionError)
  end 

  it 'should not follow redirects :ignore_redirects is set to true' do
    response1 = mock('http_response1', :code => '302', :message => 'temp redirect', :[] => 'http://www.example/bar')
    @resource.should_receive(:do_request).exactly(1).times.and_return(response1)
    
    @resource.put("this=that", 'application/x-form-urlencoded', :ignore_redirects => true).should == response1
    
  end 

  it 'should set headers on request if specified' do
    put_request = mock('get_request', :[]= => nil)
    Net::HTTP::Put.should_receive(:new).and_return(put_request)
    put_request.should_receive(:[]=).with('X-Test', 'this-is-a-test')
    
    @resource.put("this=that", 'application/x-www-form-urlencoded', :http_header_fields => {'X-Test' => 'this-is-a-test'})
  end

end

