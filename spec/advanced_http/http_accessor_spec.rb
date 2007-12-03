require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'advanced_http/http_accessor'

describe AdvancedHttp::HttpAccessor, 'init' do
    
  it 'should be instantiatable' do
    AdvancedHttp::HttpAccessor.new().should be_instance_of(AdvancedHttp::HttpAccessor)
  end 
  
  it 'should accept logger to new' do
    ha = AdvancedHttp::HttpAccessor.new(:logger => (l = stub('logger', :debug)))
    
    ha.logger.should == l
  end 

  it 'should accept auth info provider in new()' do
    aip = mock('auth_info_provider')
    ha = AdvancedHttp::HttpAccessor.new(:authentication_info_provider => aip)
    
    ha.authentication_info_provider.should == aip
  end 
  
  it 'should debug log the lack of an auth info provider' do
    logger = stub('logger')
    logger.expects(:debug).with("No authentication information provided.")
    
    ha = AdvancedHttp::HttpAccessor.new(:logger => logger)
  end 
  
  it 'should raise arg error if unrecognized options are passed' do
    lambda {
      ha = AdvancedHttp::HttpAccessor.new(:foo => 'foo', :bar => 'bar')
    }.should raise_error(ArgumentError, "Unrecognized option(s): foo, bar")
  end 
end 

describe AdvancedHttp::HttpAccessor do 
  before do
    @logger = stub('logger')
    @authentication_info_provider = stub('authentication_info_provider')
    @accessor = AdvancedHttp::HttpAccessor.new(:authentication_info_provider => @authentication_info_provider,
                                               :logger => @logger)
  end

  it 'should provide access to name URIs registry from class' do
    AdvancedHttp::HttpAccessor.named_uris.should be_instance_of(Hash)
  end 
  
  it 'should provide access to named URIs registry from instance' do
    @accessor.named_uris.should be_instance_of(Hash)
  end 

  it 'should URIs named in class level registry should be available in instance level registry' do
    AdvancedHttp::HttpAccessor.named_uris[:test_foo] = 'http://test/foo'
    
    @accessor.named_uris[:test_foo].should == 'http://test/foo'
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

  it 'should be able to return a particular resource (#[])' do
    @accessor['http://www.example/'].effective_uri.should == URI.parse('http://www.example/')
  end 

  it 'should be able to return a particular resource based on a URI name (#[])' do
    @accessor.named_uris[:return_particular_resource_based_on_name] = 'http://www.example/'
    
    @accessor[:return_particular_resource_based_on_name].effective_uri.should == URI.parse('http://www.example/')
  end 

  it 'should create resource if it does not already exist (#[])' do
    AdvancedHttp::Resource.expects(:new).returns(stub('resource'))
    @accessor['http://www.example/previously-unused-uri']
  end 

  it 'should pass uri to resource upon creation (#[])' do
    AdvancedHttp::Resource.expects(:new).with('http://www.example/previously-unused-uri', anything).
      returns(stub('resource'))
    @accessor['http://www.example/previously-unused-uri']
  end 
  
  it 'should pass authentication_info_provider and logger to resource upon creation (#[])' do
    AdvancedHttp::Resource.expects(:new).with(anything, :auth_info => @authentication_info_provider, :logger => @logger).returns(stub('resource'))
    @accessor['http://www.example/previously-unused-uri']
  end 

  it 'should be able to return a particular resource (#resource)' do
    @accessor.resource('http://www.example/').effective_uri.should == URI.parse('http://www.example/')
  end 

  it 'should be able to return a particular resource based on a URI name (#[])' do
    @accessor.named_uris[:return_particular_resource_based_on_name_non_square_bracket] = 'http://www.example/'
    
    @accessor[:return_particular_resource_based_on_name_non_square_bracket].effective_uri.should == URI.parse('http://www.example/')
  end 

  
  it 'should create resource if it does not already exist (#resource)' do
    AdvancedHttp::Resource.expects(:new).returns(stub('resource'))
    @accessor.resource('http://www.example/previously-unused-uri')
  end 

  it 'should pass authentication_info_provider and logger to resource upon creation (#[])' do
    AdvancedHttp::Resource.expects(:new).with(anything, :auth_info => @authentication_info_provider, :logger => @logger).returns(stub('resource'))
    @accessor.resource('http://www.example/previously-unused-uri')
  end 

  it 'should pass uri to resource upon creation (#resource)' do
    AdvancedHttp::Resource.expects(:new).with('http://www.example/previously-unused-uri', anything).
      returns(stub('resource'))
    @accessor.resource('http://www.example/previously-unused-uri')
  end 
end

describe AdvancedHttp::HttpAccessor, 'request stubbing' do
   before do
    @accessor = AdvancedHttp::HttpAccessor.new()
  end
  
  it 'should allow http request to be stubbed for testing/debugging purposes' do
    @accessor.stub_request(:get, 'http://www.example/temptation-waits', 'text/plain', "This is a stubbed response")    
  end 
  
  it 'should return request stubbing resource proxy' do
    @accessor.stub_request(:get, 'http://www.example/temptation-waits', 'text/plain', "This is a stubbed response")
    
    @accessor.resource('http://www.example/temptation-waits').should be_kind_of(AdvancedHttp::StubbedResourceProxy)
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
