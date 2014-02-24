/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.parser.simple_ini.tests;

/**
    $(D SimpleIni) tests.
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
import minilib.core.set;
import minilib.core.test;
import minilib.core.traits;

import minilib.parser.simple_ini.attributes;
import minilib.parser.simple_ini.parser;

///
unittest
{
    string input =
    `
    [.]
    debug=1
    extern=extern "C" __attribute__((dllexport))
    values=foo,bar,doo
    ints=1,2,3
    compiler=dmd
    intSetSingle=1
    intSetMultiple=1,2,3
    input_language=c++
    private_value=zero
    `;

    enum InputLanguage
    {
        Invalid,  // sentinel
        c,
        cpp,
    }

    // custom conversion function
    static InputLanguage getInputLanguage(string input)
    {
        switch (input.toLower)
        {
            case "c":
                return InputLanguage.c;

            case "c++", "cpp", "cplusplus":
                return InputLanguage.cpp;

            default:
                assert(0);
        }
    }

    enum Compiler { Invalid, gdc, dmd }

    static struct Config
    {
        @(FieldName("debug")) bool _debug;
        @(FieldName("extern")) string _extern;
        string[] values;
        int[] ints;
        string foobar;
        @(FieldName("empty")) int[] _empty;
        Compiler compiler;
        Set!int intSetSingle;
        Set!int intSetMultiple;

        // setter will be invoked if public
        @(FieldName("input_language")) @property void inputLanguage(string input)
        {
            _inputLanguage = getInputLanguage(input);
        }

        // getter is ignored
        @property InputLanguage inputLanguage()
        {
            return _inputLanguage;
        }

        // private properties will not be invoked.
        private @property void do_not_invoke(string input)
        {
            assert(0);
        }

        @(PostIniParse)
        void normalize()
        {
            isNormalized = true;
        }

    /** private fields will not be written to. */
    private:
        bool isNormalized;
        InputLanguage _inputLanguage;
        string private_value = "one";
    }

    Config config;
    simpleIni(input).parse(config);

    with (config)
    {
        assert(_debug);
        assert(_extern == `extern "C" __attribute__((dllexport))`);
        assert(values == ["foo", "bar", "doo"]);
        assert(ints == [1, 2, 3]);
        assert(foobar is null);
        assert(_empty.length == 0);
        assert(compiler == Compiler.dmd);
        assert(intSetSingle.elements == [1]);
        assert(intSetMultiple.elements == [1, 2, 3]);
        assert(inputLanguage == InputLanguage.cpp);
        assert(private_value == "one");
        assert(isNormalized);
    }
}

/**
    Recursive key-extraction is supported, aggregates can be
    composed of other aggregate types.
*/
unittest
{
    string input =
    `
    [.]
    name=foo

    [data]
    field=2
    `;

    static struct Data
    {
        int field;
    }

    static struct Config
    {
        string name;
        Data data;
    }

    Config config;
    simpleIni(input).parse(config);

    with (config)
    {
        assert(name == "foo");
        assert(data.field == 2);
    }
}

/// test @(Required) attribute
unittest
{
    string input =
    `
    [.]
    foo=1
    `;

    static struct Config1
    {
        bool foo;
        @(Required) bool bar;
    }

    Config1 config1;
    simpleIni(input).parse(config1).getExceptionMsg.assertEqual("@Required field 'bar' was not found.");

    static struct Config2
    {
        @(Required) @property void bar(bool b) { }
    }

    Config2 config2;
    simpleIni(input).parse(config2).getExceptionMsg.assertEqual("@Required field 'bar' was not found.");

    // test both @Required and @FieldName for a field
    static struct Config3
    {
        @(FieldName("some_field")) @(Required) @property void foo(bool b) { }
    }

    Config3 config3;
    simpleIni(input).parse(config3).getExceptionMsg.assertEqual("@Required field 'some_field' was not found.");

    // test @Required section
    static struct Section1
    {
        int la_femme_nikita;
    }

    static struct Config4
    {
        @(Required) Section1 section1;
    }

    input =
    `
    [.]
    foo=1
    [section2]
    x=2
    `;

    Config4 config4;
    simpleIni(input).parse(config4).getExceptionMsg
        .assertEqual("Section 'section1' not found. Sections: '[\"section2\", \".\"]'");
}

// convenience check: make sure @(Required) for functions is only applied to setter functions.
// it avoids user-bugs where a @(Required) function was not called.
unittest
{
    string input =
    `
    [.]
    foo=1
    `;

    static struct C1
    {
        @(Required) void f() { }  // not a property
    }

    C1 c1;
    static assert(!__traits(compiles, {
        simpleIni(input).parse(c1);
    }()));

    static struct C2
    {
        @(Required) @property void f() { }  // not a setter
    }

    C2 c2;
    static assert(!__traits(compiles, {
        simpleIni(input).parse(c2);
    }()));
}

// minilib bug fix: do not call @property function if key or value not found
unittest
{
    enum MachineFormat
    {
        Invalid,  // sentinel
        x86,      // 32-bit
        x86_64,   // 64-bit
        // x32,   // todo: 32-bit pointers, 64-bit app (Posix only)
    }

    static struct Config
    {
        @property void machine_formats(string[] inputs)
        {
        }

        @property MachineFormat[] machine_formats()
        {
            return null;
        }

        /// should not be called
        @property void machine_format(string input)
        {
            assert(0);
        }
    }

    string input =
    `
    [.]
    machine_formats=x86
    `;

    Config config;
    simpleIni(input).parse(config);  // should not throw
}

// test Process attribute
unittest
{
    string input =
    `
    [.]
    compiler1=DMD
    compiler2=GdC
    compiler3=gcc
    `;

    enum Compiler { dmd, gdc, gcc }

    static struct Config
    {
        @(Process!getCompiler) Compiler compiler1;
        @(Process!getCompiler) Compiler compiler2;
        @(Process!getCompiler) Compiler compiler3;

        static Compiler getCompiler(string input)
        {
            switch (input.toLower) with (Compiler)
            {
                case "dmd": return dmd;
                case "gdc": return gdc;
                case "gcc": return gcc;
                default: assert(0);
            }
        }
    }

    Config config;
    simpleIni(input).parse(config);

    with (config)
    {
        assert(compiler1 == Compiler.dmd);
        assert(compiler2 == Compiler.gdc);
        assert(compiler3 == Compiler.gcc);
    }
}

// test aggregate types with Process functions, which should not be expanded into sections
unittest
{
    string input =
    `
    [.]
    compiler=DMD
    arr=1,2,3
    `;

    struct Compiler { string compiler; }

    static struct Config
    {
        @(Process!getCompiler) Compiler compiler;
        @(Process!parseArray) int[] arr;

        static Compiler getCompiler(string input)
        {
            return Compiler(input);
        }

        static int[] parseArray(string[] input)
        {
            return to!(int[])(input);
        }
    }

    Config config;
    simpleIni(input).parse(config);

    with (config)
    {
        assert(compiler.compiler == "DMD");
        assert(arr == [1, 2, 3]);
    }
}

// Process can only work for fields
unittest
{
    string input =
    `
    [.]
    `;

    static struct Config
    {
        @(Process!foo) @property void set(string s) { }

        static string foo(string input)
        {
            return "";
        }
    }

    Config config;

    static assert(!__traits(compiles, {
        simpleIni(input).parse(config);
    }()));
}


// Process conversion function must have a valid parameter type and return type
unittest
{
    string input =
    `
    [.]
    compiler=DMD
    arr=1,2,3
    `;

    static struct C1
    {
        @(Process!parseArray) int[] arr;

        // wrong input
        static int[] parseArray(string input)
        {
            return null;
        }
    }

    C1 c1;
    static assert(!__traits(compiles, {
        simpleIni(input).parse(c1);
    }()));

    static struct C2
    {
        @(Process!parseArray) int[] arr;

        // wrong return type
        static int parseArray(string[] input)
        {
            return 1;
        }
    }

    C2 c2;
    static assert(!__traits(compiles, {
        simpleIni(input).parse(c2);
    }()));
}
