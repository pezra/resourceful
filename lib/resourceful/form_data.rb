module Resourceful
  module FormData
    def initialize()
      @form_data = []
      super
    end

    def add(name, value)
      form_data << [name, value]
    end

    protected
    attr_reader :form_data
  end
end
