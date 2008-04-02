require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/http_accessor'

describe Resourceful::HttpAccessor, 'init' do
    
  it 'should be instantiatable' do
    Resourceful::HttpAccessor.new().should be_instance_of(Resourceful::HttpAccessor)
  end 
  
  it 'should accept logger to new' do
    ha = Resourceful::HttpAccessor.new(:logger => (l = stub('logger', :debug)))
    
    ha.logger.should == l
  end 

  it 'should provide logger object even when no logger is specified' do
    ha = Resourceful::HttpAccessor.new()
    
    ha.logger.should be_instance_of(Resourceful::HttpAccessor::BitBucketLogger)
  end 

  it 'should raise arg error if unrecognized options are passed' do
    lambda {
      ha = Resourceful::HttpAccessor.new(:foo => 'foo', :bar => 'bar')
    }.should raise_error(ArgumentError, /Unrecognized options: (foo, bar)|(bar, foo)/)
  end 

  it 'should create an auth manager with the specified auth_info_provider' do
    auth_info_provider = stub('auth_info_provider')
    Resourceful::AuthenticationManager.expects(:new).with(auth_info_provider).returns(stub('auth_manager'))
    
    Resourceful::HttpAccessor.new(:authentication_info_provider => auth_info_provider)
  end
  
  it 'should allow an additional user agent token to be passed at init' do
    Resourceful::HttpAccessor.new(:user_agent => "Super/3000").tap do |ha|
      ha.user_agent_string.should match(%r{^Super/3000})
    end
  end 

  it 'should allow multiple additional user agent tokens to be passed at init' do
    Resourceful::HttpAccessor.new(:user_agent => ["Super/3000", "Duper/2.1"]).tap do |ha|
      ha.user_agent_string.should match(%r{^Super/3000 Duper/2\.1 })
    end
  end 

end 

describe Resourceful::HttpAccessor do 
  before do
    @logger = stub('logger')
    @authentication_info_provider = stub('authentication_info_provider')
    @accessor = Resourceful::HttpAccessor.new(:authentication_info_provider => @authentication_info_provider,
                                               :logger => @logger)
  end
  
  it 'should have user agent string w/ just resourceful token by default' do
    @accessor.user_agent_string.should == "Resourceful/#{RESOURCEFUL_VERSION}(Ruby/#{RUBY_VERSION})"
  end 
  
  it 'should add additional user agent tokens to beginning of user agent string' do
    @accessor.user_agent_tokens << 'FooBar/3000(special-version)'
    
    @accessor.user_agent_string.should match(%r{^FooBar\/3000\(special-version\) Resourceful/})
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

  it 'should be able to return a particular resource (#[])' do
    @accessor['http://www.example/'].effective_uri.should == 'http://www.example/'
  end 

  it 'should create resource if it does not already exist (#[])' do
    Resourceful::Resource.expects(:new).returns(stub('resource'))
    @accessor['http://www.example/previously-unused-uri']
  end 

  it 'should pass uri to resource upon creation (#[])' do
    Resourceful::Resource.expects(:new).with(anything, 'http://www.example/previously-unused-uri').
      returns(stub('resource'))
    @accessor['http://www.example/previously-unused-uri']
  end 
  
  it 'should pass owning accessor to resource upon creation (#[])' do
    Resourceful::Resource.expects(:new).with(@accessor, anything).returns(stub('resource'))
    @accessor['http://www.example/previously-unused-uri']
  end 

  it 'should be able to return a particular resource (#resource)' do
    @accessor.resource('http://www.example/').effective_uri.should == 'http://www.example/'
  end 

  it 'should create resource if it does not already exist (#resource)' do
    Resourceful::Resource.expects(:new).returns(stub('resource'))
    @accessor.resource('http://www.example/previously-unused-uri')
  end 

  it 'should pass owning accessor to resource upon creation (#[])' do
    Resourceful::Resource.expects(:new).with(@accessor, anything).returns(stub('resource'))
    @accessor.resource('http://www.example/previously-unused-uri')
  end 

  it 'should pass uri to resource upon creation (#resource)' do
    Resourceful::Resource.expects(:new).with(anything, 'http://www.example/previously-unused-uri').
      returns(stub('resource'))
    @accessor.resource('http://www.example/previously-unused-uri')
  end 
end

describe Resourceful::HttpAccessor, "#get_body(uri, options = {})" do 
  before do
    @logger = stub('logger')
    @authentication_info_provider = stub('authentication_info_provider')
    @accessor = Resourceful::HttpAccessor.new(:authentication_info_provider => @authentication_info_provider,
                                               :logger => @logger)
    @resource = stub('resource', :get_body => 'boo!')
    @accessor.stubs(:resource).returns(@resource)
  end

  it 'should get the resource specified by uri' do
    @accessor.expects(:resource).with('http://www.example/foo').returns(@resource)
    @accessor.get_body('http://www.example/foo')
  end 

  it 'should call get_body on the resource' do
    @resource.expects(:get_body).returns("ha!")
    @accessor.get_body('http://www.example/foo')    
  end 

  it 'should pass options to resource.get_body' do
    @resource.expects(:get_body).with(:marker).returns("ha!")
    @accessor.get_body('http://www.example/foo', :marker)
  end 
  
  it 'should return what ever resource.get_body() does' do
    @resource.expects(:get_body).returns(:marker)
    @accessor.get_body('http://www.example/foo')
  end 
end

describe Resourceful::HttpAccessor, 'request stubbing' do
  before do
    @accessor = Resourceful::HttpAccessor.new()
  end
  
  it 'should allow http request to be stubbed for testing/debugging purposes' do
    @accessor.stub_request(:get, 'http://www.example/temptation-waits', 'text/plain', "This is a stubbed response")    
  end 
  
  it 'should return request stubbing resource proxy' do
    @accessor.stub_request(:get, 'http://www.example/temptation-waits', 'text/plain', "This is a stubbed response")
    
    @accessor.resource('http://www.example/temptation-waits').should be_kind_of(Resourceful::StubbedResourceProxy)
  end 

  it 'response to stubbed request should have canned body' do
    @accessor.stub_request(:get, 'http://www.example/temptation-waits', 'text/plain', "This is a stubbed response")
    
    @accessor.resource('http://www.example/temptation-waits').get.body.should == "This is a stubbed response"
  end
  
  it 'response to stubbed request should have canned content_type' do
    @accessor.stub_request(:get, 'http://www.example/temptation-waits', 'text/plain', "This is a stubbed response")
    
    @accessor.resource('http://www.example/temptation-waits').get['content-type'].should == "text/plain"
  end

  it 'should not allow stubbing of not get requests' do
    lambda{
      @accessor.stub_request(:post, 'http://www.example/temptation-waits', 'text/plain', "This is a stubbed response")
    }.should raise_error(ArgumentError)
    
  end 
end

