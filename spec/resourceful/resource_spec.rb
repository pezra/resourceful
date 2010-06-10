require File.dirname(__FILE__) + "/../spec_helper"

module Resourceful
  describe Resource do 
    before do 
      @http_adapter = stub(:http_adapter, 
                           :make_request => [200, Header.new('Content-Type' => 'text/special'), ""])
      @http = Resourceful::HttpAccessor.new(:http_adapter => @http_adapter)
      @resource = @http.resource('http://foo.example')
      @body = stub(:body, :content_type => 'application/x-special-type', :read => "hello there")
    end
    
    describe "POSTing" do 
      it "should use bodies content type as the request content-type if it is known" do 
        @http_adapter.should_receive(:make_request).with(anything, anything, anything, hash_including('Content-Type' => 'application/x-special-type')).and_return([200, {}, ""])
        
        @resource.post(@body)
      end
    end
  end
end
