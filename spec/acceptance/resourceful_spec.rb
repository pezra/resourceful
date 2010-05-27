
require File.dirname(__FILE__) + '/../spec_helper'
require 'resourceful'

describe Resourceful do

  describe ".get()" do
    it "should be performable on a resource and return a response" do
      response = Resourceful.get('http://localhost:4567/')
      response.should be_kind_of(Resourceful::Response)
    end
  end

  describe ".post()" do
    it "should be performable on a resource and return a response" do
      response = Resourceful.post('http://localhost:4567/')
      response.should be_kind_of(Resourceful::Response)
    end

    it "should require Content-Type be set if a body is provided" do
      lambda {
        Resourceful.post('http://localhost:4567/', {}, 'body')
      }.should raise_error(Resourceful::MissingContentType)
    end

  end

  describe ".put()" do

    it "should be performable on a resource and return a response" do
      response = Resourceful.put('http://localhost:4567/')
        response.should be_kind_of(Resourceful::Response)
    end

    it "should require Content-Type be set if a body is provided" do
      lambda {
        Resourceful.put('http://localhost:4567/', "some text", {})
      }.should raise_error(Resourceful::MissingContentType)
    end

    it "should allow the entity-body to be nil" do
      lambda {
        Resourceful.put('http://localhost:4567/', nil, {})
      }.should_not raise_error(ArgumentError)
    end
  end

  describe ".delete()" do

    it "should be performable on a resource and return a response" do
      response = Resourceful.delete('http://localhost:4567/')
      response.should be_kind_of(Resourceful::Response)
    end

  end
end
