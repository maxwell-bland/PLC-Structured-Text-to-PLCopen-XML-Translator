#!/usr/bin/env ruby
# This class uses a library to generate XML files

# reads in an XML file and parses it into a tree of REXML elements
class XMLParser
    def initialize(file_name)
        @file_name = file_name
        @doc = REXML::Document.new(File.read(@file_name))
    end

    def add_element(parent, element)
        parent.elements << element
    end

    # function using REXML get child element with a given tag name
    def get_element_by_path(path)
        return @doc.elements[path]
    end

    def delete_element_by_path(path)
        @doc.elements[path].remove
    end

    def get_subelement_by_path(element, subpath)
        return element.get_elements(subpath).first
    end

    def write_to_file(file_name)
        File.open(file_name, "w") do |file|
            @doc.write(file)
        end
    end

    def create_xml_element(name, attributes, content)
        element = REXML::Element.new(name)
        attributes.each do |key, value|
            element.add_attribute(key, value)
        end
        element.text = content
        return element
    end

    def remove_all_inner_tags(parent)
        # while parent has inner tags
        while parent.elements.size > 0
            parent.delete_element("*")
        end
    end

    def clone_element_recursive(element)
        new_element = element.clone
        element.elements.each do |child|
            new_child = clone_element_recursive(child)
            new_element.add_element(new_child)
        end
        return new_element
    end
end