require File.dirname(__FILE__) + "/../spec_helper.rb"


describe Resourceful::Header do 
  it "should have constants for header names" do 
    Resourceful::Header::CONTENT_TYPE.should == 'Content-Type'
  end
end
