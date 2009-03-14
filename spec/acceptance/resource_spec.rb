
require File.dirname(__FILE__) + '/../spec_helper'
require 'resourceful'

describe Resourceful do
  describe "working with a resource" do
    before do 
      @http = Resourceful::HttpAccessor.new
      @ok_resource = @http.resource('http://localhost:3000/code/200')
      @missing_resource = @http.resource('http://localhost:3000/code/404')
    end

    it 'should expose the original URI' do 
      @ok_resource.uri.should == 'http://localhost:3000/code/200'
    end

    it 'should expose the URI from after any redirects' do 
      @ok_resource.effective_uri.should == 'http://localhost:3000/code/200'
    end

    it 'should set the user agent string on the default header' do
      @ok_resource.default_header.should have_key('User-Agent')
      @ok_resource.default_header['User-Agent'].should == Resourceful::RESOURCEFUL_USER_AGENT_TOKEN
    end

    describe "GET" do

      it "should return a response for success response" do
        @ok_resource.get.should be_kind_of(Resourceful::Response)
      end

      it "should raise exception for non-success response" do
        lambda {
          @missing_resource.get
        }.should raise_error(Resourceful::UnsuccessfulHttpRequestError)
      end
      
      
    end

    describe "POST" do

      it "should be performable on a resource and return a response" do
        response = @ok_resource.post
        response.should be_kind_of(Resourceful::Response)
      end

      it "should require Content-Type be set if a body is provided" do
        lambda {
          @ok_resource.post("some text")
        }.should raise_error(Resourceful::MissingContentType)
      end

    end

    describe "PUT" do

      it "should be performable on a resource and return a response" do
        response = @ok_resource.put(nil)
        response.should be_kind_of(Resourceful::Response)
      end

      it "should require Content-Type be set if a body is provided" do
        lambda {
          @ok_resource.put("some text")
        }.should raise_error(Resourceful::MissingContentType)
      end

      it "should require an entity-body to be set" do
        lambda {
          @ok_resource.put()
        }.should raise_error(ArgumentError)
      end

      it "should allow the entity-body to be nil" do
        lambda {
          @ok_resource.put(nil)
        }.should_not raise_error(ArgumentError)
      end
    end

    describe "DELETE" do

      it "should be performable on a resource and return a response" do
        response = @ok_resource.delete
        response.should be_kind_of(Resourceful::Response)
      end

    end

    
  end
end
