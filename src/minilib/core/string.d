/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.string;

import std.algorithm;
import std.array;
import std.conv;
import std.path;
import std.range;
import std.string;
import std.traits;

alias dirSep = dirSeparator;
alias defExt = defaultExtension;

import minilib.core.test;
import minilib.core.traits;

/** Wrapper around format which sets the file and line of any exception to the call site. */
string fmt(string file = __FILE__, size_t line = __LINE__, Args...)(string fmtStr, Args args)
{
    try
    {
        return format(fmtStr, args);
    }
    catch (Exception exc)
    {
        exc.file = file;
        exc.line = line;
        throw exc;
    }
}

unittest
{
    assert(fmt("%s %s", "foo", 1) == "foo 1");

    size_t line;
    try
    {
        line = __LINE__; fmt("%s", 1, 2);
    }
    catch (Exception exc)
    {
        assert(exc.file == __FILE__);
        assert(exc.line == line);
    }
}

/** Convert a module name to a path. */
string modToPath(string input)
{
    return defExt(input.replace(".", dirSep), ".d");
}

///
unittest
{
    assert(modToPath("minilib.foo.bar") == fmt("minilib%sfoo%sbar.d", dirSep, dirSep));
}

/** Workaround for Issue 9074: Can't use some range functions with Appender. */
struct Repeat(T)
{
    T input;
    sizediff_t count;

    @property bool empty() { return count == 0; }
    @property T front() { return input; }
    @property void popFront() { --count; }
}

/** Lazy repeat for any type. */
auto repeat(T)(T input, sizediff_t count)
{
    assert(count >= 0, "Internal Error: count is negative.");
    return Repeat!T(input, count);
}

///
unittest
{
    Appender!string result;
    result ~= repeat(' ', 4).repeat(4);
    alias std.array.replicate rep;
    assert(result.data == rep(rep(" ", 4), 4));
}

/**
    Generates a unique argument name when the arg name
    clashes with a previous name or when it's empty.
*/
struct ArgMaker
{
    string opCall(string arg = null)
    {
        if (!arg.length)
            arg = "arg";

        if (arg in oldArgs)
        {
            Appender!string res;
            res ~= arg;
            res ~= "_";
            res ~= to!string(oldArgs[arg]++);
            return res.data;
        }
        else
        {
            oldArgs[arg]++;
            return arg;
        }
    }

private:
    size_t[string] oldArgs;
}

///
unittest
{
    ArgMaker arg;
    assert(arg("") == "arg");
    assert(arg("") == "arg_1");
    assert(arg("foo") == "foo");
    assert(arg("foo") == "foo_1");
    assert(arg("bar") == "bar");
    assert(arg("bar") == "bar_1");
}

/**
    Return string representation of argument.
    If argument is already a string or a
    character, enquote it to make it more readable.
*/
string enquote(T)(T arg)
{
    static if (isSomeString!T)
        return format(`"%s"`, arg);
    else
    static if (isSomeChar!T)
        return format("'%s'", arg);
    else
    static if (isInputRange!T && is(ElementEncodingType!T == dchar))
        return format(`"%s"`, to!string(arg));
    else
        return to!string(arg);
}

unittest
{
    assert(enquote(0) == "0");
    assert(enquote(enquote(0)) == `"0"`);
    assert(enquote("foo") == `"foo"`);
    assert(enquote('a') == "'a'");

    auto r = ["foo", "bar"].joiner("_");
    assertEqual(enquote(r), `"foo_bar"`);
}

/**
    Return string representation of integral
    with the separator set after each set of
    count numbers.
*/
string formatIntegral(T)(T input, dchar separator = '_', size_t count = 3)
    if (isSomeString!T || isIntegral!T)
{
    static if (isSomeString!T)
        alias input src;
    else
        string src = to!string(input);

    size_t idx = 1;
    Appender!(dchar[]) res;
    while (!src.empty)
    {
        res ~= src.back;
        src.popBack;

        // more integrals follow
        if (!src.empty && (idx++ % count == 0))
            res ~= separator;
    }

    return to!string(retro(res.data));
}

///
unittest
{
    assert(formatIntegral(123456) == "123_456");
    assert(formatIntegral(1234567) == "1_234_567");
    assert(formatIntegral("123456") == "123_456");
    assert(formatIntegral("1234567") == "1_234_567");

    assert(formatIntegral("1234567", '.') == "1.234.567");
    assert(formatIntegral("1234567", '_', 2) == "1_23_45_67");
}

/*
    Format the aggregate type $(D T) which is a field of another aggregate.
    Fields are formatted horizontally instead of on separate lines, to avoid
    wasting too much vertical space.
*/
private string formatAggregateFlat(T)(T var)
    if (isAggregate!T)
{
    Appender!(string[]) fields;

    foreach (idx, member; __traits(allMembers, T))
    {
        static if (!is(FunctionTypeOf!( typeof(__traits(getMember, var, member)) )))
        {
            static if (is(typeof( __traits(getMember, var, member) )))
            {
                fields ~= format("%s = %s", member, enquote(__traits(getMember, var, member)));
            }
        }
    }

    return format("%s(%s)", __traits(identifier, T), fields.data.join(", "));
}

//
unittest
{
    struct S { int x = 1; int y = 2; string s = "foo"; char c = 'a'; }
    assert(formatAggregateFlat(S()) == `S(x = 1, y = 2, s = "foo", c = 'a')`);
}

/**
    Return the string representation of an aggregate
    field by field separated by a newline.
    The aggregate is taken by alias to print the variable name.
*/
string formatAggregate(alias var, T = typeof(var))()
    if (isAggregate!T)
{
    Appender!string result;
    Appender!(string[]) fields;
    Appender!(string[]) values;

    foreach (idx, member; __traits(allMembers, T))
    {
        static if (!is(FunctionTypeOf!( typeof(__traits(getMember, var, member)) )))
        {
            static if (is(typeof( __traits(getMember, var, member) )))
            {
                fields ~= member;

                static if (isAggregate!(typeof( __traits(getMember, var, member) )))
                    values ~= formatAggregateFlat(__traits(getMember, var, member));
                else
                    values ~= enquote(__traits(getMember, var, member));
            }
        }
    }

    size_t spaceLen = 1;
    foreach (field; fields.data)
        spaceLen = max(spaceLen, field.length);

    alias std.array.replicate replicate;
    foreach (field, value; zip(fields.data, values.data))
    {
        result ~= format("%s.%s: %s%s\n",
                         __traits(identifier, var),
                         field,
                         replicate(" ", spaceLen - field.length),
                         value);
    }

    return result.data;
}

/** Ditto when not passing by alias. */
string formatAggregate(T)(T var)
    if (isAggregate!T)
{
    return formatAggregate!var;
}

///
unittest
{
    static struct S
    {
        int x;
        void function() f;
        string s;
        char c;
    }

    S local = S(10, null, "foo", 'a');
    assert(formatAggregate!local == "local.x: 10\nlocal.s: \"foo\"\nlocal.c: 'a'\n", formatAggregate!local);
    assert(formatAggregate(local) == "var.x: 10\nvar.s: \"foo\"\nvar.c: 'a'\n");
}

///
unittest
{
    static struct S
    {
        int x;
        void function() f;
        string s;

        string toString()
        {
            return formatAggregate(this);
        }
    }

    S local = S(10, null, "foo");
    assert(format("%s", local) == "var.x: 10\nvar.s: \"foo\"\n");
}

///
unittest
{
    static struct S
    {
        static struct S2
        {
            int x;
            string s;
        }

        int x;
        void function() f;
        string s;

        S2 s2;

        string toString()
        {
            return formatAggregate(this);
        }
    }

    S local = S(10, null, "foo");
    assert(format("%s", local) == "var.x:  10\nvar.s:  \"foo\"\nvar.s2: S2(x = 0, s = \"\")\n");
}

/**
    Generate a toString() method for an aggregate type.
    Issue 9872: format should include class field values.
*/
mixin template gen_toString()
{
    override string toString()
    {
        import std.array;
        import std.conv;
        import std.string;

        Appender!(string[]) result;

        foreach (val; this.tupleof)
            result ~= to!string(val);

        return format("%s(%s)", __traits(identifier, typeof(this)), join(result.data, ", "));
    }
}

///
unittest
{
    static class C
    {
        this(int x, int y)
        {
            this.x = x;
            this.y = y;
        }

        mixin gen_toString;

        int x;
        int y;
    }

    auto c = new C(1, 2);
    assert(text(c) == "C(1, 2)");
}

/** Return the slice of a null-terminated C string, without allocating a new string. */
inout(char)[] peekCString(inout(char)* s)
{
    if (s is null)
        return null;

    inout(char)* ptr;
    for (ptr = s; *ptr; ++ptr) { }

    return s[0 .. ptr - s];
}

///
unittest
{
    const(char)[] input = "foo\0";
    assert(peekCString(input.ptr).ptr == input.ptr);
}
