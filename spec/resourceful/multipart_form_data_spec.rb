require File.dirname(__FILE__) + "/../spec_helper"
require 'tempfile'
require "resourceful/multipart_form_data.rb"

describe Resourceful::MultipartFormData do

  before do 
    @form_data = Resourceful::MultipartFormData.new
  end

  it "should know its content-type" do 
    @form_data.content_type.should match(/^multipart\/form-data/i)
  end

  it "should know its boundary string" do 
    @form_data.content_type.should match(/; boundary=[0-9A-Za-z]{10,}/i)
  end


  describe "with simple parameters" do 

    it "should all simple parameters to be added" do 
      @form_data.add(:foo, "testing")
    end

    it "should render a multipart form-data document when #read is called" do 
      @form_data.add('foo', 'bar')
      @form_data.add('baz', 'this')
      
      boundary = /boundary=(\w+)/.match(@form_data.content_type)[1]
      @form_data.read.should eql(<<MPFD[0..-2])
\r
--#{boundary}\r
Content-Disposition: form-data; name="foo"\r
\r
bar\r
--#{boundary}\r
Content-Disposition: form-data; name="baz"\r
\r
this\r
--#{boundary}--
MPFD

    end

    describe "with file parameter" do 
      it "should add file parameters to be added" do 
        Tempfile.open('resourceful-post-file-tests') do |file_to_upload|
          file_to_upload << "This is a test"
          file_to_upload.flush
          
          @form_data.add_file(:foo, file_to_upload.path)
        end
      end

      it "should render a multipart form-data document when #read is called" do 
        Tempfile.open('resourceful-post-file-tests') do |file_to_upload|
          file_to_upload << "This is a test"
          file_to_upload.flush
          
          @form_data.add_file(:foo, file_to_upload.path)
      
          boundary = /boundary=(\w+)/.match(@form_data.content_type)[1]
          @form_data.read.should eql(<<MPFD[0..-2])
\r
--#{boundary}\r
Content-Disposition: form-data; name="foo"; filename="#{File.basename(file_to_upload.path)}"\r
Content-Type: application/octet-stream\r
\r
This is a test\r
--#{boundary}--
MPFD

        end
      
      end
    end
  end
end
