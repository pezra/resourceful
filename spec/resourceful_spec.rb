require "spec_helper"


describe Resourceful do
  it "should have a default accessor" do
    Resourceful.default_accessor.should be_kind_of Resourceful::HttpAccessor
  end

  it "should delegate request making (minimal)" do
    stub_resource = mock(:resource)
    Resourceful.default_accessor.should_receive(:resource).with( 'http://foo.invalid/bar').and_return(stub_resource)
    stub_resource.should_receive(:request).with(:get, nil, {})

    Resourceful.request(:get, 'http://foo.invalid/bar')
  end

  it "should delegate request making (with header)" do
    stub_resource = mock(:resource)
    Resourceful.default_accessor.should_receive(:resource).with( 'http://foo.invalid/bar').and_return(stub_resource)
    stub_resource.should_receive(:request).with(:get, nil, {:accept => :json})

    Resourceful.request(:get, 'http://foo.invalid/bar', :accept => :json)
  end

  it "should delegate request making (with body)" do
    stub_resource = mock(:resource)
    Resourceful.default_accessor.should_receive(:resource).with( 'http://foo.invalid/bar').and_return(stub_resource)
    stub_resource.should_receive(:request).with(:get, 'body', {})

    Resourceful.request(:get, 'http://foo.invalid/bar', {}, 'body')
  end

  it "should allow convenient get requests" do
    stub_resource = mock(:resource)
    Resourceful.default_accessor.should_receive(:resource).with( 'http://foo.invalid/bar').and_return(stub_resource)
    stub_resource.should_receive(:request).with(:get, nil, :header_marker)

    Resourceful.get 'http://foo.invalid/bar', :header_marker
  end

  it "should allow convenient head requests" do
    stub_resource = mock(:resource)
    Resourceful.default_accessor.should_receive(:resource).with( 'http://foo.invalid/bar').and_return(stub_resource)
    stub_resource.should_receive(:request).with(:head, nil, :header_marker)

    Resourceful.head 'http://foo.invalid/bar', :header_marker
  end

  it "should allow convenient delete requests" do
    stub_resource = mock(:resource)
    Resourceful.default_accessor.should_receive(:resource).with( 'http://foo.invalid/bar').and_return(stub_resource)
    stub_resource.should_receive(:request).with(:delete, nil, :header_marker)

    Resourceful.delete 'http://foo.invalid/bar', :header_marker
  end

  it "should allow convenient post requests" do
    stub_resource = mock(:resource)
    Resourceful.default_accessor.should_receive(:resource).with( 'http://foo.invalid/bar').and_return(stub_resource)
    stub_resource.should_receive(:request).with(:post, :body_marker, :header_marker)

    Resourceful.post 'http://foo.invalid/bar', :body_marker, :header_marker
  end

  it "should allow convenient put requests" do
    stub_resource = mock(:resource)
    Resourceful.default_accessor.should_receive(:resource).with( 'http://foo.invalid/bar').and_return(stub_resource)
    stub_resource.should_receive(:request).with(:put, :body_marker, :header_marker)

    Resourceful.put 'http://foo.invalid/bar', :body_marker, :header_marker
  end


  it "should allow new authenticators to be added to default accessor" do
    Resourceful.default_accessor.should_receive(:add_authenticator).with(:my_authentcator_marker)

    Resourceful.add_authenticator(:my_authentcator_marker)
  end
end
