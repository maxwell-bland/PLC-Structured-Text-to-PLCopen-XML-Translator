# PLC Structured Text to PLCopen XML Translator

This project implements a minimal parser in ruby for PLC structured text programs.
It supports a large number of language features, with the exception of 

- generic types
- multidimensional or nested arrays
- pass by reference
- custom types or aliases

If you need something more complete and with stronger correctness guarantees, you
may be better off writing a layer around the [rusty](https://github.com/PLC-lang/rusty)
parser, but this script should be fine for most tasks, works in a UNIXy way, is a single 
file, is written in Ruby, and is around 1/20th of the size in LoC.

## Dependencies

```
sudo gem install rexml
```

## The API

### st_parser.rb : parse_st_bodies 

This function takes a structured text program and parses it into 
the following set of abstractions:

```
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
```

### st_to_ec.rb : class STToEC

This class converts to the PLCOpen XML structure used by E!Cockpit, and can be imported 
into the IDE for recompilation and modification.
