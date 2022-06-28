#!/usr/bin/env ruby
# abstract string methods for ST parsing

# returns the substring of a string between two delimiters and the index of the
# start and end delimiter in the original string
def substring_btwn_delimiters(str, s, e)
    start_index = str.index(s)
    if start_index.nil?
        return nil
    end

    end_index = str.index(e, start_index + s.length)
    if end_index.nil?
        return nil
    end

    return {
        :str => str[start_index + s.length..end_index - 1], 
        :start => start_index, 
        :end => end_index + e.length,
        :type => s
    }
end

# for a list of starting and ending string delimiters, removes all
# delimited substrings and their delimiters from a string, returing
# the resulting string and the list of removed substrings
def remove_delimited_substrings(str, delimiters)
    substrings = []

    delimiters.each do |delimiter|
        while str.index(delimiter[0]) != nil
            subs = substring_btwn_delimiters(str, delimiter[0], delimiter[1])

            if subs.nil?
                break
            end

            # remove the substring so we may keep going, must be done here
            # and not later or our indices will be off
            if subs[:start] == 0
                pre = ""
            else
                pre = str[0..subs[:start] - 1]
            end
            suf = str[subs[:end]..-1]
            str = pre + suf
            subs[:start] = nil
            subs[:end] = nil

            substrings << subs
        end
    end

    return str, substrings
end