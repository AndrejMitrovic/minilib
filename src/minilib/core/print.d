/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.print;

import std.array;
import std.conv;
import std.stdio;
import std.traits;

import minilib.core.platform;
import minilib.core.string;

/** writeln with file and line of call. */
void println(string file = __FILE__, size_t line = __LINE__, Args...)(Args args)
{
    Appender!string result;
    foreach (arg; args)
    {
        // print arrays vertically
        static if (isArray!(typeof(arg)) && !isSomeString!(typeof(arg)))
        {
            result ~= nl;
            result ~= '[';
            result ~= nl;

            foreach (idx, val; arg)
            {
                result ~= "    ";
                result ~= to!string(val);
                result ~= ',';
                result ~= nl;
            }

            result ~= ']';
            result ~= nl;
        }
        else
        {
            result ~= to!string(arg);
            result ~= " ";
        }
    }

    stderr.writefln("%s(%s) : %s", file, line, result.data);
}

/** ditto for writefln. */
void printfln(string file = __FILE__, size_t line = __LINE__, Args...)(string fmtString, Args args)
{
    string result = fmt!(file, line)(fmtString, args);
    string output = fmt!(file, line)("%s(%s) : %s", file, line, result);
    stderr.writeln(output);
}

/** ditto when calling printfln with non-string first argument. */
void printfln(string file = __FILE__, size_t line = __LINE__, Args...)(Args args)
    if (!isSomeString!(Args[0]))
{
    println!(file, line)(args);
}

/** ditto when calling printfln with no arguments. */
void printfln(string file = __FILE__, size_t line = __LINE__)()
{
    println!(file, line)(args);
}

/** Convenience. */
alias print  = println;
alias printf = printfln;
