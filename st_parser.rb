#!/usr/bin/env ruby
# This file parses structured text into a set of components
require_relative "./str.rb"

$component_type_delimiters = [
    ["FUNCTION_BLOCK", "END_FUNCTION_BLOCK"], # note order matters
    ["FUNCTION", "END_FUNCTION"],
    ["PROGRAM", "END_PROGRAM"],
    ["TYPE", "END_TYPE"],
    ["VAR_GLOBAL", "END_VAR"]
]

$field_delimiters = [
    ["VAR_IN_OUT", "END_VAR"], # order matters
    ["VAR_INPUT", "END_VAR"],
    ["VAR_OUTPUT", "END_VAR"],
    ["VAR_TEMP", "END_VAR"],
    ["VAR", "END_VAR"],
    ["METHOD", "END_METHOD"], # TODO: methods
    ["STRUCT", "END_STRUCT"]
]

def parse_component_fields(fields, res)
    fields.each do |field|
        field_type = field[:type]
        field_body = field[:str]
        f = {:type => field_type, :body => field_body}
        parse_component_vars(f[:type], f[:body], f)
        res[:fields].push(f)
    end
end

def parse_component_first_line_from_body(type, body, res)
    name = body.match(/\w+/)[0]
    res[:name] = name

    if type == "FUNCTION"
        body.strip!
        first_line = body.split("\n")[0]

        # NOTE: we do not include generic types support because 
        # the XML parser does not support it

        res[:name] = first_line.split(":")[0].strip
        t = {:variables => []}
        typestr = ":" + first_line.split(":")[1..-1].join(":")
        parse_variable(typestr, t)
        res[:return_type] = t[:variables][0]
        res[:return_type][:str] = typestr
    end

    return nil
end

def parse_component_attributes(type, body, res)
    if type == "VAR_GLOBAL"
        res[:body] = body.strip
    elsif body != nil
        parse_component_first_line_from_body(type, body, res)

        body = body.sub(res[:name], "").strip

        if type == "FUNCTION"
            return_type_index = body.index(res[:return_type][:str])
            # remove everything before the return type
            if return_type_index != nil
                body = body[return_type_index + res[:return_type].length..-1].strip 
            end
        # if body matches "(...)" then it is an enum
        elsif body.match(/^:\s*\(.*?\);$/)
            res[:type] = "ENUM"
            res[:variables] = []
            vars = body.match(/\(.*\)/)[0].split(",").map {|v| v.strip}
            # parse out each variable from the comma-separated list of vars
            vars.each do |var|
                parse_variable(var, res)
            end
        end

        res[:body] = body
    end
end

def parse_variable(variable, res)
    # if ":" is not in the variable, then we assume it is an enum variable
    # and do not gve it a type, just a name which is equivalent to the 
    # stripped variable body
    if variable.index(":") == nil
        res[:variables].push({:name => variable.strip})
        return
    end

    # split variable on the ":", extract names from comma-separated list on 
    # the lhs, then extract type from the rhs as the string before any ";"
    var_names = variable.split(":")[0].split(",").map {|v| v.strip}
    var_type = variable.split(":")[1].split(";")[0].strip

    # if STRING is in the type, parse out the length of the string from STRING[#]
    dimensions = nil
    if var_type.include?("STRING")
        var_type = var_type.split("[")[0]
        # if there is a dimension, parse it out
        if var_type.include?("[")
            dimensions = [variable.split("[")[1].split("]")[0].to_i]
        end
    # otherwise check if it is an array, where the dimensions are represented as 
    # ARRAY[x0..xn] OF type
    # Note: we do not support multi-dimensional arrays or arrays of strings
    elsif var_type.include?("ARRAY")
        var_type = "ARRAY #{var_type.split("]")[1].split("OF")[1].strip}"
        dimensions = variable.split("[")[1].split("]")[0].split(/\s+/).map {|ds| 
            ds = ds.strip.split("..")
            [ds[0].to_i, ds[1].to_i]
        }
    end

    value = nil
    # if a ":= occurs in the string, then the variable is assigned to 
    # and we extract the string after this but before the ";"
    if variable.index(":=") != nil
        value = variable.split(":=")[1].split(";")[0].strip
    end

    if var_names.length > 0
        var_names.each { |n| 
            res[:variables].push({
                :name => n, 
                :type => var_type, 
                :value => value, 
                :dimensions => dimensions
            })
        }
    else
        res[:variables].push({
            :name => nil, 
            :type => var_type, 
            :value => value, 
            :dimensions => dimensions
        })
    end

end

def parse_component_vars(name, body, res)
    # Note: we do not support pass by reference
    if name[0..2] == "VAR" or name == "STRUCT"
        res[:variables] = []
        variables = body.split("\n").map {|v| v.strip}.select {|v| v != ""}
        variables.each do |variable|
            parse_variable(variable, res)
        end
    end
end

def handle_component(component_name, component_body)
    res = {:type => component_name, :fields => []}

    component_body, fields = remove_delimited_substrings(component_body, $field_delimiters)
    parse_component_fields(fields, res)
    parse_component_attributes(component_name, component_body, res)
    parse_component_vars(component_name, res[:body], res)

    return res
end

def parse_st_bodies(str)
    parsed_bodies = []
    remainder, bodies = remove_delimited_substrings(str, $component_type_delimiters)

    # remove any trailing "@EXTERNAL" from the remainder
    remainder = remainder.strip!
    remainder = remainder.gsub("@EXTERNAL", "")

    if remainder != ""
        puts "Error: remainder is not all spaces"
        puts str
        puts "=== remainder ==="
        puts remainder
        exit 1
    end

    bodies.each do |body|
        component_type = body[:type]
        component_body = body[:str]
        parsed_bodies.push(handle_component(component_type, component_body))
    end
    return parsed_bodies
end

