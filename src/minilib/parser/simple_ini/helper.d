/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.parser.simple_ini.helper;

/**
    $(D SimpleIni) helper functions.
*/

import std.algorithm;
import std.conv;
import std.exception;
import std.range;
import std.stdio;
import std.string;
import std.traits;
import std.typetuple;

import minilib.core.attributes;
import minilib.core.test;
import minilib.core.traits;

package string[][string][string] _parseIniText(Range)(Range input)
    if (isStringRange!Range)
{
    typeof(return) result;
    static SectionInit = ValueType!(typeof(return)).init;

    alias splitter = std.algorithm.splitter;

    string sectionName;  // current section name

    size_t[string][string] keys;  // section name, to key, to line index, for error messages
    static KeysInit = ValueType!(typeof(keys)).init;

    size_t lineIndex;

    /* global namespace must always be available. */
    result["."] = SectionInit;
    keys["."] = KeysInit;

    foreach (inputLine; splitter(input, "\n"))
    {
        lineIndex++;
        string line = inputLine;

        // strip out line after first comment mark
        auto commentIdx = line.countUntil("#");
        if (commentIdx != -1)
            line = line[0 .. commentIdx];

        // strip out whitespace
        line = line.strip;

        // find a section
        auto brackBeg = line.countUntil("[");
        if (sectionName is null && brackBeg == -1)
        {
            enforce(line.strip.empty, format(`Field must be nested in a section: "%s"`, inputLine));
            continue;  // haven't found any sections yet
        }

        if (brackBeg != -1)  // new section found
        {
            line = line[brackBeg + 1 .. $];
            auto brackEnd = line.countUntil("]");

            enforce(brackEnd != -1, format(`Unterminated section name: "%s"`, inputLine));
            line = line[0 .. brackEnd];

            assert(!line.canFind("[") && !line.canFind("]"));  // sanity check
            sectionName = line;

            // only initialize if section is new, otherwise concatenate
            if (sectionName !in result)
            {
                result[sectionName] = SectionInit;
                keys[sectionName] = KeysInit;
            }

            continue;
        }

        if (line.length)
        {
            auto equalIdx = line.countUntil("=");
            enforce(equalIdx != -1, format(`Field must have an initializer: "%s"`, inputLine));

            auto keyVal = line.split("=");

            auto key = line[0 .. equalIdx].strip;

            enforce(key !in keys[sectionName],
                format(`Duplicate initializer for key "%s" is not allowed. Initializers on lines #%s and #%s.`,
                    key, keys[sectionName][key], lineIndex));

            keys[sectionName][key] = lineIndex;

            auto values = line[equalIdx + 1 .. $].strip;

            foreach (value; values.splitter(","))
            {
                value = value.strip;  // value must be stripped of empty space

                // could be empty if string was "1,2," -> [1, 2, '']
                if (!value.empty)
                    result[sectionName][key] ~= value;
            }
        }
    }

    return result;
}

unittest
{
    string input =
    `
    [.]
    debug=1
    extern=extern "C" __attribute__((dllexport))
    values=foo,bar,doo
    ints=1, 2 ,3 #ignored comment
    ints2=1,#2,3 interjected comment #another comment
    #unset=1

    [section]
    data = 1
    `;

    {
        auto parsed = _parseIniText(input);
        assert("." in parsed);
        assert("debug" in parsed["."] && parsed["."]["debug"] == ["1"]);
        assert("extern" in parsed["."] && parsed["."]["extern"] == [`extern "C" __attribute__((dllexport))`]);
        assert("values" in parsed["."] && parsed["."]["values"] == ["foo", "bar", "doo"]);
        assert("ints" in parsed["."] && parsed["."]["ints"] == ["1", "2", "3"]);
        assert("ints2" in parsed["."] && parsed["."]["ints2"] == ["1"]);
        assert("#unset" !in parsed["."]);

        assert("section" in parsed);
        assert("data" in parsed["section"]);
    }

    input =
    `
    [. # unterminated section part
    `;

    {
        assertThrown(_parseIniText(input));
    }

    input =
    `

    a = 1 # cannot have fields that don't belong to any section

    [.]
    b = 1
    `;

    {
        assertThrown(_parseIniText(input));
    }

    input =
    `

        # a = 1 # however comments are ok

    [.]
    b = 1
    `;

    {
        assertNotThrown(_parseIniText(input));
    }

    input =
    `
    [.]
    b # field must have an initializer
    `;

    {
        assertThrown(_parseIniText(input));
    }

    input =
    `
    [.]
    # no data here
    `;

    {
        auto parsed = _parseIniText(input);
        assert("." in parsed);  // global namespace always available
        assert(parsed["."].length == 0);  // it's empty
    }

    input =
    `

    [.]
    data=bar
    `;

    {
        auto parsed = _parseIniText(input);
        assert("." in parsed);
        assert("data" in parsed["."] && parsed["."]["data"] == ["bar"]);
    }

    input =
    `
    # multiple sections with the same name are allowed and they get merged
    [.]
    a=1

    [none]
    c=1

    [.]
    b=1

    `;

    {
        auto parsed = _parseIniText(input);
        assert("." in parsed);
        assert("a" in parsed["."] && parsed["."]["a"] == ["1"]);
        assert("b" in parsed["."] && parsed["."]["b"] == ["1"]);
        assert("none" in parsed && parsed["none"]["c"] == ["1"]);
    }

    input =
    `
    # multiple initializer are not allowed
    [.]
    a=1
    a=2
    `;

    {
        assertThrown(_parseIniText(input));
    }

    input =
    `
    # even if initialized in separate blocks of the same section
    [.]
    a=1

    [.]
    a=2
    `;

    {
        assertThrown(_parseIniText(input));
    }

    input =
    `
    # unless they're not in the same section
    [.]
    a=1

    [foo]
    a=2
    `;

    {
        assertNotThrown(_parseIniText(input));
    }
}
