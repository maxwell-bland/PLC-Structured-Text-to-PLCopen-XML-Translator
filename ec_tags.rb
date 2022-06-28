#!/usr/bin/env ruby
# This file defines a set of dictionaries that give the 
# information about the XML tags used in the ECockpit 
# PLCOpen XML format.
require "rexml"
require_relative 'xml.rb'

class ECockpitTags 
    def initialize()
        dir = File.dirname(__FILE__)
        @parser = XMLParser.new(dir + "/formats/meta.xml")

        @dataTypes = @parser.get_element_by_path("/project/types/dataTypes")
        @struct_template = @dataTypes.elements[1]
        @enum_template = @dataTypes.elements[2]

        struct = @parser.get_subelement_by_path(@struct_template, "baseType/struct")
        @variable_template = struct.elements[1]

        enum = @parser.get_subelement_by_path(@enum_template, "baseType/enum/values")
        @value_template = enum.elements[1]

        @pous = @parser.get_element_by_path("/project/types/pous")
        @pou_template = @pous.elements[1]

        @inputVars_template = @parser.get_subelement_by_path(@pou_template, "interface/inputVars")
        @localVars_template = @parser.get_subelement_by_path(@pou_template, "interface/localVars")
        @outputVars_template = @parser.get_subelement_by_path(@pou_template, "interface/outputVars")
        @inOutVars_template = @parser.get_subelement_by_path(@pou_template, "interface/inOutVars")
        @tempVars_template = @parser.get_subelement_by_path(@pou_template, "interface/tempVars")
        @returnType_template = @parser.get_subelement_by_path(@pou_template, "interface/returnType")

        @interface_template_map = {
            "VAR_INPUT" => @inputVars_template,
            "VAR" => @localVars_template,
            "VAR_OUTPUT" => @outputVars_template,
            "VAR_IN_OUT" => @inOutVars_template,
            "VAR_TEMP" => @tempVars_template
        }

        @globalVars_root = @parser.get_element_by_path("/project/addData")
        @globalVars_parent = @parser.get_element_by_path("/project/addData/data")
        @globalVars_template = @globalVars_parent.elements[1]
        @parser.delete_element_by_path("/project/addData")

        # Key top level tags
        @parser.remove_all_inner_tags(@dataTypes)
        @parser.remove_all_inner_tags(@pous)
        @parser.remove_all_inner_tags(@globalVars_parent)

        # Key inner level tags
        @parser.remove_all_inner_tags(struct)
        @parser.remove_all_inner_tags(enum)
        
        interfaces = @parser.get_subelement_by_path(@pou_template, "interface")
        @parser.remove_all_inner_tags(interfaces)
    end


    def change_type_tag(tag, variable)
        type = variable[:type]
        dimension = variable[:dimensions]
        @parser.remove_all_inner_tags(tag)
        if type.split(" ")[0] == "ARRAY"
            # create array type tags
            new_type_tag = @parser.create_xml_element("array", {}, "")
            dimension_tag = @parser.create_xml_element("dimension", {
                "lower" => dimension[0][0], "upper" => dimension[0][1]
            }, "")
            new_type_tag.add_element(dimension_tag)
            baseType_tag = @parser.create_xml_element("baseType", {}, "")
            baseType_tag.add_element(
                @parser.create_xml_element(type.split(" ")[1], {}, "")
            )
            new_type_tag.add_element(baseType_tag)
        elsif type == "STRING"
            attributes = {}
            if dimension
                attributes["length"] = dimension[0]
            end
            new_type_tag = @parser.create_xml_element("string", attributes, "")
        else
            new_type_tag = @parser.create_xml_element(type, {}, "")
        end
        tag.add_element(new_type_tag)
    end

    def add_value_tag(tag, value, type)
        new_value_tag = @parser.create_xml_element("initialValue", {}, value)

        # if the type is not an ARRAY, then add a simple value with a value equal to the value
        if type.split(" ")[0] != "ARRAY"
            new_value_tag.add_element(@parser.create_xml_element("simpleValue", {"value" => value}, ""))
        # else if the type is array, add an arrayValue tag with inner value tags for each array element
        else
            arrayValue_tag = @parser.create_xml_element("arrayValue", {}, "")
            new_value_tag.add_element(arrayValue_tag)
            array_values = value.gsub(/[\[\]]/, "").split(",").map(&:strip)
            array_values.each do |array_value|
                arrayValue_tag.add_element(@parser.create_xml_element("simpleValue", {"value" => array_value}, ""))
            end
        end
        
        tag.add_element(new_value_tag)
    end

    def populate_variable_list(tag, variables)
        @parser.remove_all_inner_tags(tag)
        # Note that we do not support complex struct assignment, e.g. x := (y := 1, z := 2)
        variables.each do |variable|
            var = @parser.clone_element_recursive(@variable_template)
            var.add_attribute("name", variable[:name])
            if variable.include? :type
                type = @parser.get_subelement_by_path(var, "type")
                change_type_tag(type, variable)

                if variable[:value] != nil
                    add_value_tag(var, variable[:value], variable[:type])
                end
            end

            tag.add_element(var)
        end
    end

    def populate_value_list(tag, values)
        @parser.remove_all_inner_tags(tag)
        values.each do |value|
            var = @parser.clone_element_recursive(@value_template)
            var.add_attribute("name", value[:name])
            var.add_attribute("value", value[:value])
            tag.add_element(var)
        end
    end

    def add_struct_type(name, variables)
        struct = @parser.clone_element_recursive(@struct_template)
        struct.add_attribute("name", name)
        varList = @parser.get_subelement_by_path(struct, "baseType/struct")
        populate_variable_list(varList, variables)
        @dataTypes.add_element(struct)
    end

    def add_enum_type(name, values)
        enum = @parser.clone_element_recursive(@enum_template)
        enum.add_attribute("name", name)
        valueList = @parser.get_subelement_by_path(enum, "baseType/enum/values")
        populate_value_list(valueList, values)
        @dataTypes.add_element(enum)
    end

    def create_interface(template, interface, interfaces_tag)
        interface_temp = @parser.clone_element_recursive(template)
        if interface[:type] == "returnType"
            change_type_tag(interface_temp, interface[:return_type])
        else
            populate_variable_list(interface_temp, interface[:variables])
        end
        interfaces_tag.add_element(interface_temp)
    end

    def add_pou(st_body, type)
        name = st_body[:name]
        body = st_body[:body]
        interfaces = st_body[:fields]
        pou = @parser.clone_element_recursive(@pou_template)
        pou.add_attribute("name", name)
        pou.add_attribute("pouType", type)
        interfaces_tag = @parser.get_subelement_by_path(pou, "interface")

        interfaces.each do |interface|
            create_interface(@interface_template_map[interface[:type]], interface, interfaces_tag)
        end

        if st_body.include? :return_type
            create_interface(
                @returnType_template, 
                {:type => "returnType", :return_type => st_body[:return_type]}, 
                interfaces_tag)
        end

        body_tag = @parser.get_subelement_by_path(pou, "body/ST/xhtml")
        body_tag.text = body
        @pous.add_element(pou)
    end

    def add_global_vars(st_body)
        name = st_body[:name]
        variables = st_body[:variables]
        var = @parser.clone_element_recursive(@globalVars_template)
        var.add_attribute("name", name)
        add_data = @parser.get_subelement_by_path(var, "addData")
        populate_variable_list(var, variables)
        var.add_element(add_data)

        @globalVars_parent.add_element(var)
        @globalVars_root.add_element(@globalVars_parent)
        root = @parser.get_element_by_path("/project")

        @parser.add_element(root, @globalVars_root)
    end

    def write_to_file(file)
        @parser.write_to_file(file)
    end
end
