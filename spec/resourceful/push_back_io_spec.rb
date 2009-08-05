require 'pathname'
require Pathname(__FILE__).dirname + '../spec_helper'

require 'resourceful/push_back_io'

describe Resourceful::PushBackIo do
  before do
    @secondary = stub('socket')
    @secondary.stub!(:readpartial).and_return("this is part of the data on the socket", "This is the rest")
    @pbio = Resourceful::PushBackIo.new(@secondary)
  end

  it "should read data from secondary using #readpartial" do
    @secondary.should_receive(:readpartial).with(42)

    @pbio.readpartial(42)
  end 

  it "should not read more than #readpartial on the secondary io" do
    @pbio.readpartial(1000).should eql("this is part of the data on the socket")
  end 

  it "should read from pushback buffer before reading from secondary" do
    @pbio.push("pushed back")
    @secondary.should_not_receive(:readpartial) 

    @pbio.readpartial(1000).should eql("pushed back")
  end 

  it "should read only requested length push-back buffer" do
    @pbio.push("pushed back")
    @secondary.should_not_receive(:readpartial) 

    @pbio.readpartial(4).should eql("push")
  end 

  it "should remove read data from push-back buffer" do
    @pbio.push("pushed back")
    @secondary.should_not_receive(:readpartial) 

    @pbio.readpartial(4).should eql("push")
    @pbio.readpartial(4).should eql("ed b")
    @pbio.readpartial(4).should eql("ack")
  end 

  it "should read data from secondary after push-back buffer is exhausted" do
    @pbio.push("pushed back")

    @pbio.readpartial(100).should eql("pushed back")
    @pbio.readpartial(100).should eql("this is part of the data on the socket")
  end

  it "should be closed if secondary is closed" do
    @secondary.stub!(:closed?).and_return(true)

    @pbio.should be_closed
  end 

  it "should not be closed if there is data in the push-back buffer, even if secondary is closed" do
    @secondary.stub!(:closed?).and_return(true)
    @pbio.push("hello")

    @pbio.should_not be_closed
  end 

  it "should delegate #write to secondary" do 
    @secondary.should_receive(:write).with("foo")
    
    @pbio.write("foo")
  end

  it "should delegate #flush to secondary" do 
    @secondary.should_receive(:flush)
    
    @pbio.flush()
  end

  it "should delegate #close to secondary" do 
    @secondary.should_receive(:close)
    
    @pbio.close()
  end

  it "should dump push-back buffer on explicit close" do 
    @pbio.push("pushed back")
    @secondary.stub!(:close)
    @secondary.stub!(:closed?).and_return(true)
    @pbio.close()

    @pbio.should be_closed
  end

  it "should fail with timout if timeout is execeed" do 
    @secondary.stub!(:readpartial).and_return("this is part of the data on the socket"
    
  end

  describe "secondary w/o readpartial" do
    before do
      @secondary = stub('socket', :closed? => false)
      @secondary.stub!(:read).and_return("this is part of the data on the socket", "This is the rest")
      @pbio = Resourceful::PushBackIo.new(@secondary)
    end

    it "should read data from secondary using #readpartial" do
      @secondary.should_receive(:read).with(42)

      @pbio.readpartial(42)
    end 

    it "should raise an error on read attempts if it is closed" do
      @secondary.stub!(:closed?).and_return(true)
      
      lambda {
        @pbio.readpartial(42)
      }.should raise_error(EOFError)
    end
  end
end
