require File.dirname(__FILE__) + "/../spec_helper.rb"

module Resourceful
  describe Header do 
    def self.should_support_header(name)
      const_name = name.upcase.gsub('-', '_')
      meth_name  = name.downcase.gsub('-', '_')

      eval <<-RUBY
      it "should have constant `#{const_name}` for header `#{name}`" do 
        Resourceful::Header::#{const_name}.should == '#{name}'
      end

      it "should have accessor method `#{meth_name}` for header `#{name}`" do 
        Resourceful::Header.new.should respond_to(:#{meth_name})
      end

    RUBY
    end

    should_support_header('Accept')
    should_support_header('Accept-Charset')
    should_support_header('Accept-Encoding')
    should_support_header('Accept-Language')
    should_support_header('Accept-Ranges')
    should_support_header('Age')
    should_support_header('Allow')
    should_support_header('Authorization')
    should_support_header('Cache-Control')
    should_support_header('Connection')
    should_support_header('Content-Encoding')
    should_support_header('Content-Language')
    should_support_header('Content-Length')
    should_support_header('Content-Location')
    should_support_header('Content-MD5')
    should_support_header('Content-Range')
    should_support_header('Content-Type')
    should_support_header('Date')
    should_support_header('ETag')
    should_support_header('Expect')
    should_support_header('Expires')
    should_support_header('From')
    should_support_header('Host')
    should_support_header('If-Match')
    should_support_header('If-Modified-Since')
    should_support_header('If-None-Match')
    should_support_header('If-Range')
    should_support_header('If-Unmodified-Since')
    should_support_header('Keep-Alive')
    should_support_header('Last-Modified')
    should_support_header('Location')
    should_support_header('Max-Forwards')
    should_support_header('Pragma')
    should_support_header('Proxy-Authenticate')
    should_support_header('Proxy-Authorization')
    should_support_header('Range')
    should_support_header('Referer')
    should_support_header('Retry-After')
    should_support_header('Server')
    should_support_header('TE')
    should_support_header('Trailer')
    should_support_header('Transfer-Encoding')
    should_support_header('Upgrade')
    should_support_header('User-Agent')
    should_support_header('Vary')
    should_support_header('Via')
    should_support_header('Warning')
    should_support_header('WWW-Authenticate')


    it "should be instantiatable w/ single valued header fields" do 
      Header.new('Host' => 'foo.example').
        host.should eql('foo.example')
    end

    it "should gracefully handle repeated values for single valued header fields" do 
      lambda {
        Header.new('Host' => ['foo.example', 'bar.example'])
      }.should raise_error(ArgumentError, 'Host field may only have one value')
    end

    it "should provide #each_fields to iterate through all header fields and values as strings" do 
      field_names = []
      Header.new('Accept' => "this", :content_type => "that", 'pragma' => 'test').each_field do |fname, _|
        field_names << fname
      end

      field_names.should include('Accept')
      field_names.should include('Content-Type')
      field_names.should include('Pragma')
      field_names.should have(3).items
    end

    it "should provide #to_hash as a way to dump the header fields" do 
      Header.new('Accept' => "this", :content_type => "that", 'date' => 'today').to_hash.tap do |h|
        h.should have_pair('Accept', ['this'])
        h.should have_pair('Content-Type', 'that')
        h.should have_pair('Date', 'today')
      end
    end

    it "should provide a list of hop-by-hop fields" do
      Header.header_field('X-Hop-By-Hop-Header', :hop_by_hop => true)
      Header.hop_by_hop_fields.should include('X-Hop-By-Hop-Header')
    end

    it "should provide a list of not modified fields" do
      Header.header_field('X-Dont-Modify-Me', :modifiable => false)
      Header.non_modifiable_fields.should include('X-Dont-Modify-Me')
    end

    describe "multi-valued fields" do
      it "should be instantiatable w/ repeated multi-valued header fields" do
        Header.new('Accept' => ['application/foo', 'application/bar']).
          accept.should eql(['application/foo', 'application/bar'])
      end

      it "should be instantiatable w/ repeated multi-valued header fields w/ multiple values" do
        Header.new('Accept' => ['application/foo, application/bar', 'text/plain']).
          accept.should eql(['application/foo', 'application/bar', 'text/plain'])
      end

      it "should be instantiatable w/ multi-valued header fields w/ multiple values" do
        Header.new('Accept' => 'application/foo, application/bar').
          accept.should eql(['application/foo', 'application/bar'])
      end

      it "should be instantiatable w/ multi-valued header fields w/ one value" do 
        Header.new('Accept' => 'application/foo').
          accept.should eql(['application/foo'])
      end

      it "should provide values to #each_field as a comma separated string" do 
        Header.new('Accept' => ['this', 'that']).each_field do |fname, fval|
          fval.should == 'this, that'
        end
      end

      it "should provide #each as a way to iterate through fields as w/ higher level values" do
        Header.new('Accept' => ['this', 'that']).each do |fname, fval|
          fval.should == ['this', 'that']
        end
      end
    end

    Spec::Matchers.define :have_pair do |name, value|
      match do |header_hash|
        header_hash.has_key?(name)
        header_hash[name] == value
      end
    end    
  end
end
