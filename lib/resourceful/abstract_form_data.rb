module Resourceful
  class AbstractFormData
    def initialize(contents = {})
      @form_data = []
      
      contents.each do |k,v|
        add(k, v)
      end
    end

    def add(name, value)
      form_data << [name.to_s, value]
    end

    protected
    attr_reader :form_data
  end
end
