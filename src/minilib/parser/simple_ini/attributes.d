/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.parser.simple_ini.attributes;

/**
    $(D SimpleIni) attributes.
*/

import std.traits;

import minilib.core.attributes;
import minilib.core.traits;

/**
    Attribute used to mark a function which sould be
    called after parsing is complete on the aggregate.
*/
struct PostIniParse { }

/**
    Attribute used to mark a field which has to be written to.
    If the field is not found in the ini file, the parser will throw.
*/
struct Required { }

/**
    Attribute used to mark a field where the input string has to be
    processed before writing to the field.

    $(D Func) must be a function that takes either a string argument
    or a string[] argument, and returns a value which can be implicitly
    assignable to the field that this attribute is applied to.

    The function must be static or without an associated context pointer.
*/
struct Process(alias Func)
    if (_isProcessFunction!Func)
{
    /** The process function the ini parser will use to decode input arguments. */
    alias ProcFunc = Func;
}

/** Check if $(D Func) is a function usable as a @Process attribute function. */
private template _isProcessFunction(alias Func) if (isStaticFunction!Func)
{
    alias Params = ParameterTypeTuple!Func;
    enum bool _isProcessFunction = Params.length == 1
                                   && (is(Params[0] == string) || is(Params[0] == string[]))
                                   && !is(ReturnType!Func == void);
}

///
unittest
{
    struct S
    {
        void foo() { }
        static void bar() { }
        static void proc1(string proc) { }
        static int proc2(string proc) { return 1; }
        static int proc3(string[] proc) { return 1; }
    }

    void func() { }

    static assert(!__traits(compiles, _isProcessFunction!S));
    static assert(!__traits(compiles, _isProcessFunction!(S.foo)));
    static assert(!_isProcessFunction!(S.bar));
    static assert(!_isProcessFunction!(S.proc1));
    static assert(_isProcessFunction!(S.proc2));
    static assert(_isProcessFunction!(S.proc3));
}

// The no-op function is either called or discarded completely if a @Process function
// is not associated with a field.
package static string _noOp(string input) { return input; }

/**
    Check whether symbol $(D S) has a @Process function attribute.
*/
package template _hasProcessFunction(S...) if (S.length == 1)
{
    enum bool _hasProcessFunction = canFindAttributeTemplateInstance!(Process, S[0]);
}

///
unittest
{
    struct S
    {
        static int process(string input) { return 1; }

        int x;
        @(Process!process) int y;
    }

    S s;
    static assert(!_hasProcessFunction!s);
    static assert(!_hasProcessFunction!(s.x));
    static assert(_hasProcessFunction!(s.y));
}

/**
    Return the @Process function associated with symbol $(D S),
    or return a no-op function if none exist.
*/
package template _getProcessFunction(S...) if (S.length == 1)
{
    static if (canFindAttributeTemplateInstance!(Process, S[0]))
    {
        alias _getProcessFunction = getAttributeTemplateInstance!(Process, S[0]).ProcFunc;
    }
    else
    {
        alias _getProcessFunction = _noOp;
    }
}

///
unittest
{
    struct S
    {
        static int process(string input) { return 1; }

        int x;
        @(Process!process) int y;
    }

    S s;
    static assert(_getProcessFunction!s("foobar") == "foobar");
    static assert(_getProcessFunction!(s.x)("foobar") == "foobar");
    static assert(_getProcessFunction!(s.y)("foobar") == 1);
}

/// Check whether the $(D ProcFunc) function is a user-provided one or the noOp function.
package template _isCustomProcFunc(alias ProcFunc)
{
    enum bool _isCustomProcFunc = !is(typeof(ProcFunc) == typeof(_noOp));
}

///
unittest
{
    struct S
    {
        static int process(string input) { return 1; }

        int x;
        @(Process!process) int y;
    }

    S s;
    static assert(!_isCustomProcFunc!(_getProcessFunction!s));
    static assert(!_isCustomProcFunc!(_getProcessFunction!(s.x)));
    static assert(_isCustomProcFunc!(_getProcessFunction!(s.y)));
}

/**
    Check if function $(D F) is tagged as a post-parse function.
*/
package static template _isPostParseFunc(F...) if (F.length == 1)
{
    enum _isPostParseFunc = canFindAttributeType!(PostIniParse, F[0]);
}

/**
    Check if symbol $(D S) is tagged as a required field.
*/
package static template _isRequired(S...) if (S.length == 1)
{
    enum _isRequired = canFindAttributeType!(Required, S[0]);
}
