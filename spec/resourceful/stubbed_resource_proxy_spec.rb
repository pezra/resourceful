require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'advanced_http/stubbed_resource_proxy'

describe AdvancedHttp::StubbedResourceProxy, "init" do
  it 'should require real resource' do
    lambda{
      AdvancedHttp::StubbedResourceProxy.new
    }.should raise_error(ArgumentError)
  end 
  
  it 'should require canned responses hash' do
    lambda{
      AdvancedHttp::StubbedResourceProxy.new(stub('resource'))
    }.should raise_error(ArgumentError)    
  end 
  
  it 'should be creatable with a Resource and canned responses' do
    AdvancedHttp::StubbedResourceProxy.new(stub('resource'), {})
  end 
end 

describe AdvancedHttp::StubbedResourceProxy do
  before do
    @resource = stub('resource', :effective_uri => "http://test.invalid/foo")
    @stubbed_resource = AdvancedHttp::StubbedResourceProxy.
      new(@resource, [{:mime_type => 'application/xml', 
                        :body => '<thing>1</thing>'}])
  end
  
  it 'should return canned response body for matching requests' do
    resp = @stubbed_resource.get
    resp.body.should == '<thing>1</thing>'
    resp['content-type'].should == 'application/xml'
  end 
  
  it 'should pass #get() through to base resource if no matching canned response is defined' do
    @resource.expects(:get)
    @stubbed_resource.get(:accept => 'application/unknown')
  end 

  it 'should pass #post() through to base resource if no canned response is defined' do
    @resource.expects(:post)
    @stubbed_resource.post
  end 

  it 'should pass #put() through to base resource if no canned response is defined' do
    @resource.expects(:put)
    @stubbed_resource.put
  end 
  
    it 'should pass #effective_uri() through to base resource if no canned response is defined' do
    @resource.expects(:effective_uri)
    @stubbed_resource.effective_uri
  end 

end 
