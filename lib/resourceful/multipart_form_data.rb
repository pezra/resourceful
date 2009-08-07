
module Resourceful
  class MultipartFormData
    FileParamValue = Struct.new(:content, :file_name, :content_type)

    def initialize()
      @form_data = []
    end

    def add(name, value)
      form_data << [name, value]
    end

    def add_file(name, file_name, content_type="application/octet-stream")
      add(name, FileParamValue.new(File.new(file_name, 'r'), File.basename(file_name), content_type))
    end

    def content_type
      "multipart/form-data; boundary=#{boundary}"
    end

    def read
      StringIO.new.tap do |out|
        first = true
        form_data.each do |key, val|
          out << "\r\n" unless first
          out << "--" << boundary
          out << "\r\nContent-Disposition: form-data; name=\"#{key}\""
          if val.kind_of?(FileParamValue)
            out << "; filename=\"#{val.file_name}\""
            out << "\r\nContent-Type: #{val.content_type}"
          end
          out << "\r\n\r\n"
          if val.kind_of?(FileParamValue)
            out << val.content.read
          else
            out << val.to_s
          end
          first = false
        end
        out << "\r\n--#{boundary}--"
      end.string
    end

    protected
    attr_reader :form_data

    def boundary
      @boundary ||= (0..30).map{BOUNDARY_CHARS[rand(BOUNDARY_CHARS.length)]}.join
    end

    BOUNDARY_CHARS = [('a'..'z').to_a,('A'..'Z').to_a,(0..9).to_a].flatten
  end
end
