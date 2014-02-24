/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.test;

import core.exception;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.string;
import std.traits;

import minilib.core.set;
import minilib.core.string;
import minilib.core.util;

/**
    Return the exception of type $(D Exc) that is
    expected to be thrown when $(D expr) is evaluated.

    This is useful to verify the custom exception type
    holds some interesting state.

    If no exception is thrown, then a new exception
    is thrown to notify the user of the missing exception.
*/
Exc getException(Exc, E)(lazy E expr, string file = __FILE__, size_t line = __LINE__)
{
    try
    {
        expr();
        throw new Exception("Error: No exception was thrown.", file, line);
    }
    catch (Exc e)
    {
        return e;
    }
}

///
unittest
{
    assert({ throw new Exception("my message"); }().getException!Exception.msg == "my message");

    static class MyExc : Exception
    {
        this(string file)
        {
            this.file = file;
            super("");
        }

        string file;
    }

    assert({ throw new MyExc("file.txt"); }().getException!MyExc.file == "file.txt");

    try
    {
        assert(getException!MyExc({ }()).file == "file.txt");
    }
    catch (Exception exc)
    {
        assert(exc.msg == "Error: No exception was thrown.");
    }
}

/**
    Return the exception message of an exception.
    If no exception was thrown, then a new exception
    is thrown to notify the user of the missing exception.
*/
string getExceptionMsg(E)(lazy E expr, string file = __FILE__, size_t line = __LINE__)
{
    auto result = collectExceptionMsg!Throwable(expr);

    if (result is null)
        throw new Exception("Error: No exception was thrown.", file, line);

    return result;
}

///
unittest
{
    assert(getExceptionMsg({ throw new Exception("my message"); }()) == "my message");
    assert(getExceptionMsg({ }()).getExceptionMsg == "Error: No exception was thrown.");
}

/** Verify that calling $(D expr) throws and contains the exception message $(D msg). */
void assertErrorsWith(E)(lazy E expr, string msg, string file = __FILE__, size_t line = __LINE__)
{
    try
    {
        expr.getExceptionMsg.assertEqual(msg);
    }
    catch (AssertError ae)
    {
        ae.file = file;
        ae.line = line;
        throw ae;
    }
}

///
unittest
{
    require(1 == 2).assertErrorsWith("requirement failed.");
    require(1 == 2, "%s is not true").assertErrorsWith("%s is not true");
    require(1 == 2, "%s is not true", "1 == 2").assertErrorsWith("1 == 2 is not true");

    require(1 == 1).assertErrorsWith("requirement failed.")
                   .assertErrorsWith("Error: No exception was thrown.");
}

/**
    Similar to $(D enforce), except it can take a formatting string as the second argument.
    $(B Note:) Until Issue 8687 is fixed, $(D file) and $(D line) have to be compile-time
    arguments, which might create template bloat.
*/
T require(string file = __FILE__, size_t line = __LINE__, T, Args...)
    (T value, Args args)
{
    if (value)
        return value;

    static if (Args.length)
    {
        static if (Args.length > 1)
            string msg = format(args[0], args[1 .. $]);
        else
            string msg = text(args);
    }
    else
        enum msg = "requirement failed.";

    throw new Exception(msg, file, line);
}

///
unittest
{
    require(1 == 2).getExceptionMsg.assertEqual("requirement failed.");
    require(1 == 2, "%s is not true").getExceptionMsg.assertEqual("%s is not true");
    require(1 == 2, "%s is not true", "1 == 2").getExceptionMsg.assertEqual("1 == 2 is not true");
}

/**
    An overload of $(D enforceEx) which allows constructing the exception with the arguments its ctor supports.
    The ctor's last parameters must be a string (file) and size_t (line).
*/
template enforceEx(E)
{
    T enforceEx(T, string file = __FILE__, size_t line = __LINE__, Args...)(T value, Args args)
        if (is(typeof(new E(args, file, line))))
    {
        if (!value) throw new E(args, file, line);
        return value;
    }
}

///
unittest
{
    static class Exc : Exception
    {
        this(int x, string file, int line)
        {
            super("", file, line);
            this.x = x;
        }

        int x;
    }

    try
    {
        enforceEx!Exc(false, 1);
        assert(0);
    }
    catch (Exc ex)
    {
        assert(ex.x == 1);
    }
}

template assertEquality(bool checkEqual)
{
    void assertEquality(T1, T2)(T1 lhs, T2 rhs, string file = __FILE__, size_t line = __LINE__)
        //~ if (is(typeof(lhs == rhs) : bool))  // note: errors are better without this
    {
        static if (is(typeof(lhs == rhs) : bool))
            enum string compare = "lhs == rhs";
        else
        static if (is(typeof(equal(lhs, rhs)) : bool))
            enum string compare = "equal(lhs, rhs)";  // std.algorithm for ranges
        else
            static assert(0, format("lhs type '%s' cannot be compared against rhs type '%s'",
                __traits(identifier, T1), __traits(identifier, T2)));

        mixin(format(q{
            if (%s(%s))
                throw new AssertError(
                    format("(%%s %%s %%s) failed.", lhs.enquote, checkEqual ? "==" : "!=", rhs.enquote),
                    file, line);
        }, checkEqual ? "!" : "", compare));
    }
}

/** Unittest functions which give out a message with the failing expression. */
alias assertEquality!true assertEqual;

/// Ditto
alias assertEquality!false assertNotEqual;

///
unittest
{
    assertEqual(1, 1);
    assertNotEqual(1, 2);

    assert(assertEqual("foo", "bar").getExceptionMsg == `("foo" == "bar") failed.`);
    assert(assertNotEqual(1, 1).getExceptionMsg == "(1 != 1) failed.");

    int x;
    int[] y;
    static assert(!__traits(compiles, x.assertEqual(y)));
}

template assertProp(string prop, bool state)
{
    void assertProp(T)(T arg, string file = __FILE__, size_t line = __LINE__)
    {
        mixin(format(q{
            if (%sarg.%s)
            {
                throw new AssertError(
                    format(".%%s is %%s : %%s", prop, !state, arg), file, line);
            }
        }, state ? "!" : "", prop));
    }
}

/// Assert range is empty.
alias assertProp!("empty", true) assertEmpty;

/// Assert range isn't empty.
alias assertProp!("empty", false) assertNotEmpty;

///
unittest
{
    // Issue 9588 - format prints context pointer for struct
    static struct S { int x; bool empty() { return x == 0; } }

    S s = S(1);
    assert(assertEmpty(s).getExceptionMsg == ".empty is false : S(1)");

    s.x = 0;
    assertEmpty(s);

    assert(assertNotEmpty(s).getExceptionMsg == ".empty is true : S(0)");
    s.x = 1;
    assertNotEmpty(s);
}

/// Assert element is in container by using the $(D in) operator
void assertContainsOnly(C, E)(C container, E elem, string file = __FILE__, size_t line = __LINE__)
    if (is(typeof(elem in container) : bool))
{
    bool found = elem in container;
    if (container.length == 1 && found)
        return;

    string msg;
    if (container.length >= 1)
        msg = format("Elem %s is not %sin %s", elem.enquote, found ? "alone " : "", container);
    else
        msg = format("Container is empty : %s", container);

    throw new AssertError(msg, file, line);
}

///
unittest
{
    Set!int x;

    assert(getExceptionMsg(assertContainsOnly(x, 1)) == "Container is empty : Set!int()");
    x.add(1);
    assertContainsOnly(x, 1);
    assert(getExceptionMsg(assertContainsOnly(x, 2)) == "Elem 2 is not in Set!int(1)");

    x.remove(1);
    x.add(2);
    assertContainsOnly(x, 2);
    x.add(1);
    assert(getExceptionMsg(assertContainsOnly(x, 2)) == "Elem 2 is not alone in Set!int(1, 2)");
}

/** Common typo. */
public alias assertThrows = assertThrown;

/**
    Return true if enum $(D en) is in a valid state.
    Only usable with enums which define a member
    named $(B Invalid).
*/
bool isValidEnum(E)(E en)
    if (is(E == enum) && is(typeof( E.Invalid )))
{
    return en != E.Invalid;
}

/// ditto
bool isValidEnum(E)(E en)
    if (is(E == enum) && is(typeof( E.invalid )))
{
    return en != E.invalid;
}

///
unittest
{
    enum E1 { Invalid, a, b, c }

    E1 e1;
    assert(!e1.isValidEnum);

    e1 = E1.a;
    assert(e1.isValidEnum);

    enum E2 { a, b, c }
    E2 e2;
    static assert(!__traits(compiles, e2.isValidEnum));

    enum E3 { invalid, a, b, c }

    E3 e3_1;
    assert(!e3_1.isValidEnum);

    e3_1 = E3.a;
    assert(e3_1.isValidEnum);

}

/// Useful template to generate an assert check function
template assertOp(string op)
{
    void assertOp(T1, T2)(T1 lhs, T2 rhs,
                          string file = __FILE__,
                          size_t line = __LINE__)
    {
        string msg = format("(%s %s %s) failed.", lhs, op, rhs);

        mixin(format(q{
            if (!(lhs %s rhs)) throw new AssertError(msg, file, line);
        }, op));
    }
}

///
unittest
{
    alias assertEqual = assertOp!"==";
    alias assertNotEqual = assertOp!"!=";
    alias assertGreaterThan = assertOp!">";
    alias assertGreaterThanOrEqual = assertOp!">=";

    assertEqual(1, 1);
    assertNotEqual(1, 2);
    assertGreaterThan(2, 1);
    assertGreaterThanOrEqual(2, 2);
}
