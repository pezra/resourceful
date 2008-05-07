require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/header'

describe Resourceful::Header do

  it "should capitalize on all accesses" do
    h = Resourceful::Header.new("foo" => "bar")
    h["foo"].should == "bar"
    h["Foo"].should == "bar"
    h["FOO"].should == "bar"

    h.to_hash.should == {"Foo" => "bar"}

    h["bar-zzle"] = "quux"

    h.to_hash.should == {"Foo" => "bar", "Bar-Zzle" => "quux"}
  end

  it "should capitalize correctly" do
    h = Resourceful::Header.new

    h.capitalize("foo").should == "Foo"
    h.capitalize("foo-bar").should == "Foo-Bar"
    h.capitalize("foo_bar").should == "Foo_Bar"
    h.capitalize("foo bar").should == "Foo Bar"
    h.capitalize("foo-bar-quux").should == "Foo-Bar-Quux"
    h.capitalize("foo-bar-2quux").should == "Foo-Bar-2quux"
  end

  it "should be converted to real Hash" do
    h = Resourceful::Header.new("foo" => "bar")
    h.to_hash.should be_instance_of(Hash)
  end

end

