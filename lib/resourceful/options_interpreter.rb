require 'set'

module Resourceful
  class OptionsInterpreter
    def self.interpret(options_hash, &block)
      interpreter = self.new(options_hash)
      interpreter.instance_eval(&block)
      
      interpreter.interpret
    end      
    
    def initialize(&block)
      @handlers = Hash.new
      
      instance_eval(&block) if block_given?
    end
    
    def interpret(options_hash) 
      unless (unrecognized_options = (options_hash.keys - supported_options)).empty?
        raise ArgumentError, "Unrecognized options: #{unrecognized_options.join(", ")}"
      end
      
      options = Hash.new
      handlers.each do |opt_name, a_handler|
        opt_val = a_handler.call(options_hash)
        options[opt_name] = opt_val if opt_val
      end
      
      options
    end
    
    def option(name, opts = {}, &block)

      passed_value_fetcher = if opts[:default] 
                               default_value = opts[:default]
                               lambda{|options_hash| options_hash[name] || default_value}
                             else
                               lambda{|options_hash| options_hash[name]}
                             end
      
      handlers[name] = if block_given?
                         lambda{|options_hash| (val = passed_value_fetcher.call(options_hash)) ? block.call(val) : nil}
                       else
                         passed_value_fetcher
                       end
    end
    
    def supported_options
      handlers.keys
    end
    
    private
    
    attr_reader :handlers
  end
end
