/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.parser.simple_ini.parser;

// todo: worry about "flags=-g -d" instead of "flags=-g,-d".
// We could: Automatically split or error. If former, allow flags="-g -d" to concatenate.

import std.algorithm;
import std.conv;
import std.exception;
import std.range;
import std.stdio;
import std.string;
import std.traits;
import std.typetuple;

import minilib.core.attributes;
import minilib.core.set;
import minilib.core.test;
import minilib.core.traits;

import minilib.parser.simple_ini.tests;
import minilib.parser.simple_ini.helper;
import minilib.parser.simple_ini.attributes;

/**
    A simple .ini configuration parser.

    The parser expects field initializers specified in
    an input range passed to its constructor.

    Each field must be inside of a section. A field
    cannot be initialized more than once, unless
    the field is part of unique sections.

    A section is named with square brackets.
    A global section is marked with [.].
    Section names which are duplicated are merged into
    a single section.

    Each field must be stored on its own line.
    The field name and value are separated by an
    equals ($(B =)) sign.

    The value can either be a single value, or multiple
    values separated by a comma ($(B ,)). The value(s)
    are parsed until the end of the line. Space between
    the values is stripped away.

    A comment mark ('$(B #)') can be used to add line comments.
    All text on the line after the first comment mark will be
    ignored by the parser.

    The $(D .parse) method can be used to store
    a key's value into a variable. The function returns
    the $(D this) reference to allow function chaining.

    $(B Note:)
    See $(D minilib.parser.simple_ini.attributes) for the list
    of attributes that can be used with symbols.

    See $(D minilib.parser.simple_ini.tests) for example code.
*/
struct SimpleIni(Range)
    if (isStringRange!Range)
{
    /** Construct the parser. Input must be a string or a range of characters. */
    this(Range input)
    {
        _data = _parseIniText(input);
    }

    /// Cannot construct a default-initialized SimpleIni parser.
    @disable this();

    /**
        Fill in all member fields of the $(D store), which must be a struct type.

        A member field can be tagged with a @FieldName attribute to allow
        looking up a member field with an arbitrary key name. This allows
        using key names where the key is a D keyword and is otherwise
        illegal as the name of a member variable.

        Private fields in the structure are ignored.

        If a structure field is a non-private @property setter, the parser will
        attempt to find the key with its name, and then call the property function.
        This allows custom parsing of an input string from within user-code.
        The @property method can also have a @FieldName associated with it.

        Fields or @property setters which are marked with the @Required attribute
        must be found in the input range, otherwise an exception is thrown.

        Trying to apply @Required on a non-property function or non-setter property
        function will make the $(D parse) function error at compile-time.

        Upon exit the function returns the $(D this) reference to allow
        function chaining.
    */
    ref SimpleIni parse(T)(ref T store)
        if (isAggregate!T && !isNested!T)
    {
        auto section = _data["."];  // first type is part of the global namespace
        this.parse(section, store);
        return this;
    }

    //
    private enum ParseState
    {
        KeyNotFound,
        ValueEmpty,
        ValueFound,
    }

    /*
        Store the value in the $(D key) to the $(D store) variable.

        T must be a fundamental D type, or an enum, or a Minilib Set,
        but not a plain aggregate unless a custom @Process function is
        provided for the conversion.

        The value will be attempted to be converted to the $(D store's)
        type. If the $(D key) is not found, or if the value stored for the
        $(D key) is empty, the function immediately returns.

        If conversion fails, $(D ConvException) is thrown.

        $(D isRequired) is set when the field must be found in the input range.
        If it's not found, an exception is thrown.

        Returns $(D ParseState) based on whether the key and value were found.

        Note: 'store' can't be passed by alias due to errors such as:
        "can't pass symbol to nested template"
        It's the reason why all of the arguments are passed explicitly.
    */
    private ParseState parse(alias ProcFunc = _noOp, T)(string[][string] section, string key, ref T store, bool isRequired)
        if (!isAggregate!T || (isAggregate!T && _isCustomProcFunc!ProcFunc) || isMinilibSet!T)
    {
        if (key !in section)
        {
            enforce(!isRequired, format("@Required field '%s' was not found.", key));
            return ParseState.KeyNotFound;
        }

        auto values = section[key];
        if (values.empty)
            return ParseState.ValueEmpty;

        // retrieve the ElementType
        static if (isMinilibSet!T)
            alias ElementType = T.ElementType;
        else
            alias ElementType = T;

        // either use custom-provided @Process function or use generic to!T
        static if (_isCustomProcFunc!ProcFunc)
            alias convFunc = ProcFunc;
        else
            alias convFunc = to!ElementType;

        static if (isMinilibSet!T)  // set can have multiple values
        {
            // convert each value to the Element Type of the Set and add it to the set
            foreach (value; values)
                store.add(convFunc(value));
        }
        else
        static if (isArray!T && !isSomeString!T)  // non-strings can have multiple values
        {
            // todo: handle the case of 'convFunc(values.front)', so we can automatically
            // support arrays
            static if (!is(typeof( convFunc(values) )))
            {
                static assert(0,
                    format("Can't call function '%s' using argument of type 'string[]'",
                        fullyQualifiedName!convFunc));


            }
            else
            static if (!is(typeof( store = convFunc(values) )))
            {
                static assert(0,
                    format("Cannot implicitly convert return type of function '%s' of type '%s' to '%s'",
                        fullyQualifiedName!convFunc, fullyQualifiedName!(ReturnType!convFunc), fullyQualifiedName!T));
            }
            else
            {
                store = convFunc(values);
            }
        }
        else
        {
            enforce(values.length == 1);  // must be a single value
            string value = values.front;

            static if (is(T == bool))  // special parsing
            {
                try { store = convFunc(value); }  // try "true", "false"
                catch (ConvException) { store = cast(T)(to!int(value)); }  // try "1", "0"
            }
            else
            {
                store = convFunc(value);
            }
        }

        return ParseState.ValueFound;
    }

    /*
        Store aggregate type T. This function can be recursively called.
    */
    private void parse(T)(string[][string] section, ref T store)
        if (isAggregate!T && !isNested!T)
    {
        // iterate through all members at compile time
        foreach (idx, _; store.tupleof)
        static if (__traits(getProtection, store.tupleof[idx]) != "private")
        {
            // get the @Process function
            alias ProcFunc = _getProcessFunction!(T.tupleof[idx]);

            static if (isAggregate!(typeof(store.tupleof[idx]))
                && !isMinilibSet!(typeof(store.tupleof[idx]))  // Set is handled below
                && !_isCustomProcFunc!ProcFunc)  // only expand sections if ProcessFunc not provided
            {
                string fieldName = getFieldName!(T.tupleof[idx]);
                enforce(fieldName in _data,
                    format("Section '%s' not found. Sections: '%s'", fieldName, _data.keys()));
                section = _data[fieldName];
                this.parse(section, store.tupleof[idx]);  // recursive call
            }
            else
            {
                // are we required to find this field?
                bool isRequired = _isRequired!(T.tupleof[idx]);

                this.parse!ProcFunc(section, getFieldName!(T.tupleof[idx]), store.tupleof[idx], isRequired);
            }
        }

        // @bug: Check if variadic array arguments are supported in @property functions
        foreach (propSet; GetAllPropertySetters!T)
        static if (__traits(getProtection, propSet) != "private")
        {
            // actual name of the @property function
            enum propName = __traits(identifier, propSet);

            // the field name of the @property
            enum fieldName = getFieldName!propSet;

            // make a variable with the type of the first parameter of the setter @property
            ParameterTypeTuple!(propSet)[0] result;

            // are we required to find this property as a field name?
            bool isRequired = _isRequired!propSet;

            // read it from the config file
            if (this.parse(section, fieldName, result, isRequired) == ParseState.ValueFound)
            {
                // invoke the setter @property with the result
                __traits(getMember, store, propName) = result;
            }
        }

        // search for any post-parsing functions, and also verify that non-property and non-setter
        // functions are not marked with @(Required)
        foreach (func; GetAllFunctions!T)
        {
            static if (_isPostParseFunc!func)
            {
                // actual name of the post-parse function
                enum funcName = __traits(identifier, func);

                // invoke the the post-parse function
                __traits(getMember, store, funcName)();
            }

            static if (_isRequired!func && !isPropertySetter!func)
            {
                static assert(0,
                    format("@(Required) attribute can only be set for a setter @property function, not '%s'.",
                        fullyQualifiedName!func));
            }

            static if (_hasProcessFunction!func && isSomeFunction!func)
            {
                static assert(0,
                    format("@(Process) attribute can only be set for a field, not the function '%s'.",
                        fullyQualifiedName!func));
            }
        }
    }

private:
    // section -> key -> values
    string[][string][string] _data;
}

/**
    Return an instance of a SimpleIni parser.
    Input must be a string or a range of characters.
*/
auto simpleIni(Range)(Range input)
    if (isStringRange!Range)
{
    return SimpleIni!Range(input);
}
