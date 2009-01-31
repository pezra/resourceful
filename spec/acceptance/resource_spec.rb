
require File.dirname(__FILE__) + '/../spec_helper'
require 'resourceful'

describe Resourceful do

  describe "working with a resource" do
    before do 
      @http = Resourceful::HttpAccessor.new
      @resource = @http.resource('http://localhost:3000/')
    end

    it 'should make the original uri available' do 
      @resource.effective_uri.should == 'http://localhost:3000/'
      @resource.uri.should == 'http://localhost:3000/'
    end

    it 'should set the user agent string on the default header' do
      @resource.default_header.should have_key('User-Agent')
      @resource.default_header['User-Agent'].should == Resourceful::RESOURCEFUL_USER_AGENT_TOKEN

    end

    describe "GET" do

      it "should be performable on a resource and return a response" do
        response = @resource.get
        response.should be_kind_of(Resourceful::Response)
      end

    end

    describe "POST" do

      it "should be performable on a resource and return a response" do
        response = @resource.post
        response.should be_kind_of(Resourceful::Response)
      end

      it "should require Content-Type be set if a body is provided" do
        lambda {
          @resource.post("some text")
        }.should raise_error(Resourceful::MissingContentType)
      end

    end

    describe "PUT" do

      it "should be performable on a resource and return a response" do
        response = @resource.put(nil)
        response.should be_kind_of(Resourceful::Response)
      end

      it "should require Content-Type be set if a body is provided" do
        lambda {
          @resource.put("some text")
        }.should raise_error(Resourceful::MissingContentType)
      end

      it "should require an entity-body to be set" do
        lambda {
          @resource.put()
        }.should raise_error(ArgumentError)
      end

      it "should allow the entity-body to be nil" do
        lambda {
          @resource.put(nil)
        }.should_not raise_error(ArgumentError)
      end
    end

    describe "DELETE" do

      it "should be performable on a resource and return a response" do
        response = @resource.delete
        response.should be_kind_of(Resourceful::Response)
      end

    end

    
  end
end
