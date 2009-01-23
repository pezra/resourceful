describe 'redirect', :shared => true do
  it 'should be followed by default on GET' do
    resp = @resource.get
    resp.should be_instance_of(Resourceful::Response)
    resp.should be_ok
    resp.header['Content-Type'].should == ['text/plain']
  end

  %w{PUT POST}.each do |method|
    it "should not be followed by default on #{method}" do
      resp = @resource.send(method.downcase.intern, nil, :content_type => 'text/plain' )
      resp.should be_redirect
    end

    it "should redirect on #{method.to_s.upcase} if the redirection callback returns true" do
      @resource.on_redirect { true }
      resp = @resource.send(method.downcase.intern, nil, :content_type => 'text/plain' )
      resp.should be_ok
    end

    it "should not follow redirect on #{method.to_s.upcase} if the redirection callback returns false" do
      @resource.on_redirect { false }
      resp = @resource.send(method.downcase.intern, nil, :content_type => 'text/plain' )
      resp.should be_redirect
    end
  end

  it "should not be followed by default on DELETE" do
    resp = @resource.delete
    resp.should be_redirect
  end

  it "should redirect on DELETE if vthe redirection callback returns true" do
    @resource.on_redirect { true }
    resp = @resource.delete
    resp.should be_ok
  end

  it "should not redirect on DELETE if the redirection callback returns false" do
    resp = @resource.delete
    resp.should be_redirect
  end
end

