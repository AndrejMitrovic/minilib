/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.meta;

import std.traits;
import std.typetuple;

/**
    Expand a static array into a TypeTuple of its individual elements.
    Used when wanting to pass individual elements of a static array
    into a function that takes non-array parameters, or even variadic
    functions expecting non-array parameters.
*/
template expand(alias array, size_t idx = 0)
    if (isStaticArray!(typeof(array)))
{
    static @property ref index(alias arg, size_t idx)() { return arg[idx]; }

    alias Array = typeof(array);

    static if (idx + 1 < Array.length)
        alias expand = TypeTuple!(index!(array, idx),
                                  expand!(array, idx + 1));
    else
        alias expand = index!(array, idx);
}

///
unittest
{
    void test1(int a)
    {
        assert(a == 1);
    }

    void test2(int a, int b)
    {
        assert(a == 1);
        assert(b == 2);
    }

    void test3(ref int a, ref int b, ref int c)
    {
        assert(a++ == 1);
        assert(b++ == 2);
        assert(c++ == 3);
    }

    void testVariadicArray(T...)(T args)
    {
        static assert(is(T[0] == int[3]));
    }

    void testVariadicExpanded(T...)(T args)
    {
        static assert(is(T[0] == int) && T.length == 3);
    }

    int[1] arr1 = [1];
    int[2] arr2 = [1, 2];
    int[3] arr3 = [1, 2, 3];

    test1(expand!arr1);
    test2(expand!arr2);
    test3(expand!arr3);
    assert(arr3 == [2, 3, 4]);

    testVariadicArray(arr3);
    testVariadicExpanded(expand!arr3);
}

/**
    Return a Tuple expression of $(D Func) being
    applied to every tuple argument.
*/
template Map(alias Func, args...)
{
    static auto ref ArgCall(alias Func, alias arg)() { return Func(arg); }

    static if (args.length > 1)
        alias Map = TypeTuple!(ArgCall!(Func, args[0]), Map!(Func, args[1 .. $]));
    else
        alias Map = ArgCall!(Func, args[0]);
}

///
unittest
{
    import std.conv;

    int square(int arg)
    {
        return arg * arg;
    }

    int refSquare(ref int arg)
    {
        arg *= arg;
        return arg;
    }

    ref int refRetSquare(ref int arg)
    {
        arg *= arg;
        return arg;
    }

    void test(int a, int b)
    {
        assert(a == 4, a.text);
        assert(b == 16, b.text);
    }

    void testRef(ref int a, ref int b)
    {
        assert(a++ == 16, a.text);
        assert(b++ == 256, b.text);
    }

    int a = 2;
    int b = 4;

    test(Map!(square, a, b));

    test(Map!(refSquare, a, b));
    assert(a == 4);
    assert(b == 16);

    testRef(Map!(refRetSquare, a, b));
    assert(a == 17);
    assert(b == 257);
}
