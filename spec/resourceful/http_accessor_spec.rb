require File.dirname(__FILE__) + "/../spec_helper"

require "resourceful/http_accessor"

module Resourceful
  describe HttpAccessor do 
    describe "instantiation" do 
      it "should accept logger option" do 
        test_logger = stub('logger', :debug => false)
        ha = HttpAccessor.new(:logger => test_logger)
        ha.logger.should equal(test_logger)
      end

      it "should accept array user_agent option" do 
        ha = HttpAccessor.new(:user_agent => ['foo/3.2', 'bar/1.0'])
        ha.user_agent_string.should match(/^foo\/3.2 bar\/1.0 Resourceful/)
      end

      it "should accept string user_agent option" do 
        ha = HttpAccessor.new(:user_agent => 'foo')
        ha.user_agent_string.should match(/^foo Resourceful/)
      end

      it "should accept cache_manager option" do 
        test_cache_manager = stub('cache_manager', :debug => false)
        ha = HttpAccessor.new(:cache_manager => test_cache_manager)
        ha.cache_manager.should equal(test_cache_manager)
      end

      it "should accept http_adapter option" do 
        test_http_adapter = stub('http_adapter', :debug => false)
        ha = HttpAccessor.new(:http_adapter => test_http_adapter)
        ha.http_adapter.should equal(test_http_adapter)
      end

      it "should accept authenticator option" do 
        test_authenticator = stub('authenticator', :debug => false)
        ha = HttpAccessor.new(:authenticator => test_authenticator)
        # cannot really be tested safely so we just rely on the fact that the option was accepted
      end

      it "should accept authenticators option" do 
        test_authenticator1 = stub('authenticator1', :debug => false)
        test_authenticator2 = stub('authenticator2', :debug => false)
        ha = HttpAccessor.new(:authenticator => [test_authenticator1, test_authenticator2])
        # cannot really be tested safely so we just rely on the fact that the option was accepted
      end

      it "should reject unrecognized options" do 
        lambda {
          HttpAccessor.new(:not_a_valid_option => "this")
        }.should raise_error(ArgumentError)
      end
    end

    describe "representation handling" do 
      before do
        @accessor = HttpAccessor.new

        @special_text_representation = rep = mock('special text representation')
        @accessor.add_representation_factory('text/special', 
                                             lambda{|response| rep})
      end

      it "should allow specifying a representation factory" do
        @accessor.add_representation_factory('text/plain', 
                                             lambda{|response| response.body}).should be_nil
      end

      it "should not accept non-callable representation factory" do
        lambda{
          @accessor.add_representation_factory('text/special', mock("bogus factory"))
        }.should raise_error(ArgumentError)
      end

      it "should convert a response into a representation using factory" do 
        response = mock("response", :header => mock('header', :content_type => 'text/special'))
        @accessor.build_representation(response).should == @special_text_representation
      end

      it "should treat response as representation if no appropriate representation factory is available" do 
        response = mock("response", :header => mock('header', :content_type => 'text/super-special'))
        @accessor.build_representation(response).should == response
      end

      it "should handle weird casing of content type" do
        response = mock("response", :header => mock('header', :content_type => 'TEXT/specIAL'))

        @accessor.build_representation(response).should == @special_text_representation
      end
    end
  end
end
