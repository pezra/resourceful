require File.dirname(__FILE__) + "/../spec_helper"

require 'resourceful/response'
require 'resourceful/header'

module Resourceful
  describe Response do
    describe 'representation handling' do 
      before do 
        @ua = HttpAccessor.new
        @ua.add_representation_factory('text/uri-list', 
                                       @rep_factory = mock('factory', :call => mock('a representation')))

        @resp = Response.new(@ua, 'http://test.invalid/', 200, Header.new('Content-Type' => 'text/uri-list'), <<LIST)
http://test.invalid/home
http://test.invalid/work
LIST
      end

      it "should be able to convert itself into a representation" do 
        @resp.representation
      end

      it "should use proper factory to build representation" do 
        @rep_factory.should_receive(:call).with(@resp).and_return(mock('a representation'))
        @resp.representation
      end
    end

    it "should know when it is expired" do 
      resp = Response.new(nil, nil, nil, Header.new('Cache-Control' => 'max-age=2', 'Date' => (Time.now - 2).httpdate), nil)
      resp.request_time = Time.now

      resp.expired?.should be_true
    end

    it "should know when it is not expired" do 
      resp = Response.new(nil, nil, nil, Header.new('Cache-Control' => 'max-age=1', 'Date' => Time.now.httpdate), nil)
      resp.request_time = Time.now

      resp.expired?.should be_false
    end

    it "know when it is stale due to expiration" do 
      resp = Response.new(nil, nil, nil, Header.new('Cache-Control' => 'max-age=1', 'Date' => (Time.now - 2).httpdate), nil)
      resp.request_time = Time.now

      resp.stale?.should be_true
    end

    it "know when it is stale due to no-cache" do 
      resp = Response.new(nil, nil, nil, Header.new('Cache-Control' => 'no-cache', 'Date' => Time.now.httpdate), nil)
      resp.request_time = Time.now

      resp.stale?.should be_true
    end

    it "know when it is stale due to must-revalidate" do 
      resp = Response.new(nil, nil, nil, Header.new('Cache-Control' => 'must-revalidate', 'Date' => Time.now.httpdate), nil)
      resp.request_time = Time.now

      resp.stale?.should be_true
    end

    it "know when it is not stale" do 
      resp = Response.new(nil, nil, nil, Header.new('Cache-Control' => 'max-age=1', 'Date' => Time.now.httpdate), nil)
      resp.request_time = Time.now

      resp.stale?.should be_false
    end
  end

end
