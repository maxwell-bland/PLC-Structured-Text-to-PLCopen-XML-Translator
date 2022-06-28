#/usr/bin/env ruby
require_relative 'ec_tags'

# class that takes in a parsed st body and uses it to populate 
# an ECockpitTags object by mapping the ST types to the ECockpit
# types.
class STToEC
    def initialize(st_body)
        @st_body = st_body
        @ec_tags = ECockpitTags.new
        convert_st_to_ec()
    end

    def convert_st_to_ec
        # switch on the st type
        case @st_body[:type]
        when "TYPE"
            convert_type_to_ec
        when "FUNCTION_BLOCK"
            convert_pou_to_ec("functionBlock")
        when "FUNCTION"
            convert_pou_to_ec("function")
        when "PROGRAM"
            convert_pou_to_ec("program")
        when "VAR_GLOBAL"
            convert_global_var_to_ec
        end
    end

    def convert_pou_to_ec(type)
        @ec_tags.add_pou(@st_body, type)
    end

    def convert_type_to_ec
        # check if the type has a STRUCT field
        # Note: we do not support custom types (and aliases)
        if @st_body[:fields].any? { |field| field[:type] == "STRUCT" }
            convert_struct_to_ec
        elsif @st_body[:type] == "ENUM"
            @ec_tags.add_enum_type(@st_body[:name], @st_body[:variables])
        else
            raise "Unsupported type: #{@st_body}"
        end
    end

    def convert_global_var_to_ec
        @ec_tags.add_global_vars(@st_body)
    end

    def convert_struct_to_ec
        struct_field = @st_body[:fields].find { |field| 
            field[:type] == "STRUCT" 
        }
        @ec_tags.add_struct_type(@st_body[:name], struct_field[:variables])
    end

    def write_to_file(file_name)
        @ec_tags.write_to_file(file_name)
    end
end