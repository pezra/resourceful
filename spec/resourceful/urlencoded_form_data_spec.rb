require File.dirname(__FILE__) + "/../spec_helper"
require 'tempfile'
require "resourceful/urlencoded_form_data.rb"

describe Resourceful::UrlencodedFormData do

  before do 
    @form_data = Resourceful::UrlencodedFormData.new
  end

  it "should know its content-type" do 
    @form_data.content_type.should match(/^application\/x-www-form-urlencoded$/i)
  end

  describe "with simple parameters" do 
    it "should all simple parameters to be added" do 
      @form_data.add(:foo, "testing")
    end

    it "should render a multipart form-data document when #read is called" do 
      @form_data.add('foo', 'bar')
      @form_data.add('baz', 'this')
      
      @form_data.read.should eql("foo=bar&baz=this")
    end

    it "should escape character in values that are unsafe" do 
      @form_data.add('foo', 'this & that')
      
      @form_data.read.should eql("foo=this+%26+that")
    end

    it "should escape character in names that are unsafe" do 
      @form_data.add('foo=bar', 'this')      
      @form_data.read.should eql("foo%3Dbar=this")
    end

  end
end
