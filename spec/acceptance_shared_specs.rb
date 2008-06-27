describe 'redirect', :shared => true do
  it 'should be followed by default on GET' do
    resp = @resource.get
    resp.should be_instance_of(Resourceful::Response)
    resp.code.should == 200
    resp.header['Content-Type'].should == ['text/plain']
  end

  %w{PUT POST}.each do |method|
    it "should not be followed by default on #{method}" do
      lambda {
        @resource.send(method.downcase.intern, nil, :'content-type' => 'text/plain' )
      }.should raise_error(Resourceful::UnsuccessfulHttpRequestError)
    end

    it "should redirect on #{method.to_s.upcase} if the redirection callback returns true" do
      @resource.on_redirect { true }
      resp = @resource.send(method.downcase.intern, nil, :'content-type' => 'text/plain' )
      resp.code.should == 200
    end

    it "should not redirect on #{method.to_s.upcase} if the redirection callback returns false" do
      @resource.on_redirect { false }
      lambda {
        @resource.send(method.downcase.intern, nil, :'content-type' => 'text/plain' )
      }.should raise_error(Resourceful::UnsuccessfulHttpRequestError)
    end
  end

  it "should not be followed by default on DELETE" do
    lambda {
      @resource.delete
    }.should raise_error(Resourceful::UnsuccessfulHttpRequestError)
  end

  it "should redirect on DELETE if vthe redirection callback returns true" do
    @resource.on_redirect { true }
    resp = @resource.delete
    resp.code.should == 200
  end

  it "should not redirect on DELETE if the redirection callback returns false" do
    @resource.on_redirect { false }
    lambda {
      @resource.delete
    }.should raise_error(Resourceful::UnsuccessfulHttpRequestError)
  end
end

