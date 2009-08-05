# Copyright (c) 2005 Zed A. Shaw
# You can redistribute it and/or modify it under the same terms as Ruby.

#define LEN(AT, FPC) (FPC - buffer - parser->AT)
#define MARK(M,FPC) (parser->M = (FPC) - buffer)
#define PTR_TO(F) (buffer + parser->F)
#define L(M) fprintf(stderr, "" # M "\n");


# machine
%%{
  machine http_response_parser;

  action mark { @mark = fpc }

  action start_field { 
    @mark = fpc
  }

  action write_field { 
    extract_field_name(fpc)
  }

  action start_value { 
    @mark = fpc
  }

  action write_value { 
    extract_field_value(fpc)
  }

  action reason_phrase { 
    extract_reason_phrase(fpc)
  }

  action status_code { 
    extract_status_code(fpc)
  }

  action http_version {	
    extract_http_version(fpc)
  }

  action chunk_size {
#    parser->chunk_size(parser->data, PTR_TO(mark), LEN(mark, fpc));
  }

  action last_chunk {
#    parser->last_chunk(parser->data, NULL, 0);
  }

  action done { 
    @done = true
    extract_remainder(fpc)

#    parser->body_start = fpc - buffer + 1; 
#    if(parser->header_done != NULL)
#      parser->header_done(parser->data, fpc + 1, pe - fpc - 1);
#    fbreak;
  }

# line endings
  CRLF = "\r\n";

# character types
  CTL = (cntrl | 127);
  tspecials = ("(" | ")" | "<" | ">" | "@" | "," | ";" | ":" | "\\" | "\"" | "/" | "[" | "]" | "?" | "=" | "{" | "}" | " " | "\t");

# elements
  token = (ascii -- (CTL | tspecials));

  Reason_Phrase = (any -- CRLF)+ >mark %reason_phrase;
  Status_Code = digit+ >mark %status_code;
  http_number = (digit+ "." digit+) ;
  HTTP_Version = ("HTTP/" http_number) >mark %http_version ;
  Status_Line = HTTP_Version " " Status_Code " " Reason_Phrase :> CRLF;

  field_name = token+ >start_field %write_field;
  field_value = any* >start_value %write_value;
  message_header = field_name ":" " "* field_value :> CRLF;

  Response = 	Status_Line (message_header)* (CRLF @done);

  chunk_ext_val = token+;
  chunk_ext_name = token+;
  chunk_extension = (";" chunk_ext_name >start_field %write_field %start_value ("=" chunk_ext_val >start_value)? %write_value )*;
  last_chunk = "0"? chunk_extension :> (CRLF @last_chunk @done);
  chunk_size = xdigit+;
  chunk = chunk_size >mark %chunk_size chunk_extension :> (CRLF @done);
  Chunked_Header = (chunk | last_chunk);

  main := Response | Chunked_Header;
}%%

module Resourceful
  class RdHttpAdapter
    class ParsedHttpResponseHeader
      attr_accessor :status_code, :reason_phrase, :http_version, :header_fields, :remainder
      def initialize
        @header_fields = []
      end
    end

    class IncompleteHeaderException < Exception
    end

    class HttpResponseParser
      attr_reader :result, :data

      def initialize
        @result = ParsedHttpResponseHeader.new
        @done = false

        %% write data;
     end

      def execute(buffer)
        if @data
          # second part of header
          puts "SECOND PART"
          @data = marked_data(@data.length) + buffer
          @mark = 0
        else
          @data = buffer
          %% write init;
        end
p @data

        data = @data
        %% write exec;

pp result

        raise IncompleteHeaderException unless done?

        @result
      end

      def done?
        @done
      end

      def self.marked_component(name)
        class_eval <<-EXTRACTOR
          def extract_#{name}(end_idx)
            result.#{name} = marked_data(end_idx)
            clear_mark
          end         
        EXTRACTOR
      end

      marked_component(:http_version)
      marked_component(:status_code)
      marked_component(:reason_phrase)
      
      def extract_field_name(end_idx)
        result.header_fields << [marked_data(end_idx)]
        clear_mark
      end

      def extract_field_value(end_idx)
        result.header_fields.last << marked_data(end_idx)
        clear_mark
      end
      
      def extract_remainder(header_end_idx)
        result.remainder = data[header_end_idx+1, data.length - header_end_idx]
      end
      
      protected

      def marked_data(end_idx)
        data[@mark, end_idx - @mark]
      end

      def clear_mark
        @mark = nil
      end
    end
  end
end

