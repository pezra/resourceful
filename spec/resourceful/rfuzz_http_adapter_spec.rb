require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'
require 'yaml'

require 'resourceful/rfuzz_http_adapter'

describe "Resourceful::RFuzzHttpAdapter" do
  before do
    pending unless defined?(RFuzz::HttpClient)
  end

  it "should return correct status code (200)" do
    u = Addressable::URI.parse("http://localhost:3000/code/200")
    Resourceful::RFuzzHttpAdapter.make_request(:get, u, nil).tap do |resp| 
      resp.first.should == 200
    end
  end 

  it "should return correct status code (400)" do
    u = Addressable::URI.parse("http://localhost:3000/code/400")
    Resourceful::RFuzzHttpAdapter.make_request(:get, u, nil).tap do |resp| 
      resp.first.should == 400
    end
  end 

  
  def self.it_should_make_requests(method)
    eval <<-RUBY
      it "should make #{method} requests" do
        u = Addressable::URI.parse("http://localhost:3000/method")
        Resourceful::RFuzzHttpAdapter.make_request(:#{method}, u).tap do |resp| 
          resp.last.should == '#{method}'.upcase
        end
      end 
    RUBY
  end
  
  it_should_make_requests(:get)
  it_should_make_requests(:put)
  it_should_make_requests(:post)
  it_should_make_requests(:delete)

  it "should not override content length header field (even if it is wrong)" do
    pending("rfuzz is a little too helpful")
    
    u = Addressable::URI.parse("http://localhost:3000/header")
    Resourceful::RFuzzHttpAdapter.make_request(:post, u, "a post body", {'Content-Length' => 13}).tap do |resp| 
      YAML.load(resp[2])['CONTENT_LENGTH'].to_i.should == 13
    end
  end 

  it "should not override content type header field" do
    pending("not sure how to spec this in the current setup")
    u = Addressable::URI.parse("http://localhost:3000/header")
    Resourceful::RFuzzHttpAdapter.make_request(:post, u, "a post body", {'Content-Type' => 'application/x-special'}).tap do |resp| 
      pp YAML.load(resp[2]) #['CONTENT_TYPE'].should == 'applicatin/x-special'
    end
  end 
  
  it "should pass back headers" do
    u = Addressable::URI.parse("http://localhost:3000/")
    Resourceful::RFuzzHttpAdapter.make_request(:post, u, "a post body").tap do |resp| 
      resp[1].should be_instance_of(Resourceful::Header)
    end
  end 

  it "should parse headers" do
    u = Addressable::URI.parse("http://localhost:3000/")
    Resourceful::RFuzzHttpAdapter.make_request(:post, u, "a post body").tap do |resp| 
      resp[1].should have_key(:server)
    end
  end 
end 
