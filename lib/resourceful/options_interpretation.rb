module Resourceful
  # Declarative way of interpreting options hashes
  #
  #    include OptionsInterpretion
  #    def my_method(opts = {})
  #      extract_opts(opts) do |opts|
  #        host = opts.extract(:host)
  #        port = opts.extract(:port, :default => 80) {|p| Integer(p)}
  #      end
  #    end
  #
  module OptionsInterpretation
    # Interpret an options hash
    #
    # @param [Hash] opts
    #   The options to interpret.
    # 
    # @yield block that used to interpreter options hash
    #
    # @yieldparam [Resourceful::OptionsInterpretion::OptionsInterpreter] interpeter
    #   An interpreter that can be used to extract option information from the options hash.
    def extract_opts(opts, &blk)
      opts = opts.clone
      yield OptionsInterpreter.new(opts)

      unless opts.empty?
        raise ArgumentError, "Unrecognized options: #{opts.keys.join(", ")}"
      end

    end

    class OptionsInterpreter
      def initialize(options_hash)
        @options_hash = options_hash
      end
   
      # Extract a particular option.
      #
      # @param [String] name
      #   Name of option to extract
      # @param [Hash] interpreter_opts
      #   ':default'
      #   :: The default value, or an object that responds to #call 
      #      with the default value.
      #   ':required'
      #   :: Boolean indicating if this option is required.  Default: 
      #      false if a default is provided; otherwise true.
      def extract(name, interpreter_opts = {}, &blk)
        option_required = !interpreter_opts.has_key?(:default)
        option_required = interpreter_opts[:required] if interpreter_opts.has_key?(:required)
        
        raise ArgumentError, "Required option #{name} not provided" if option_required && !@options_hash.has_key?(name) 
        # We have the option we need

        orig_val = @options_hash.delete(name)
        
        if block_given?
          yield orig_val

        elsif orig_val
          orig_val
          
        elsif interpreter_opts[:default] && interpreter_opts[:default].respond_to?(:call)
          interpreter_opts[:default].call()

        elsif interpreter_opts[:default]
          interpreter_opts[:default]
        end
      end
    end
  end
end
