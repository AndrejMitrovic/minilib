/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.types;

import std.exception;

/**
    A wrapper around an enum, that acts as an Enum itself,
    but which requires the user to explicitly initialize
    variables of this type.

    Default initialization will fail at compile-time.

    This is useful when the default initialization of an
    enum value to the first enum member is unwanted,
    e.g. to avoid logical bugs.

    $(RED Note:) Currently due to a compiler bug this
    type cannot be directly used in a switch/final switch
    statement.

    See Issue 10253: http://d.puremagic.com/issues/show_bug.cgi?id=10253
*/
struct ExplicitEnum(E) if (is(E == enum))
{
    @disable this();
    this(E e) { value = e; }

    E value;
    alias value this;
}

///
unittest
{
    /**
        The library writer would typically disallow access to
        this enum so it can never be directly used in user-code.
    */
    /* private */ enum MachineEnum
    {
        X86,
        X86_64,
    }

    // the fake enum type
    alias Machine = ExplicitEnum!MachineEnum;

    static assert(!__traits(compiles,
    {
        Machine machine;  // compile-time error
    }()));

    Machine machine = Machine.X86;  // ok

    // todo: wait for Issue 10253 to be fixed before enabling this
    /+
    static assert(__traits(compiles,
    {
        Machine m = Machine.X86;

        switch (m)
        {
            case WE.a: break;
            case WE.b: break;
            default:
        }

        final switch (we)
        {
            case WE.a: break;
            case WE.b: break;
        }
    }()));
    +/
}

/**
    This struct type allows you to store both an
    error state and the associated data.

    It can be used in if statement auto expressions.
*/
struct TaggedResult(T)
{
    bool ok = true;
    auto opCast(X = bool)() { return ok; }

    T _payload;
    alias _payload this;
}

///
unittest
{
    static struct Node { string[string] data; }

    // hardcoded example, the function will return an
    // error state if willSucceed is set to false
    static TaggedResult!Node getNode(bool willSucceed)
    {
        typeof(return) result;

        if (willSucceed)
            result.data["foo"] = "bar";
        else
            result.ok = false;

        return result;
    }

    if (auto node = getNode(true))
        assert(node.data == ["foo" : "bar"]);
    else
        assert(0);  // shouldn't get to here

    // enforce also works
    if (auto node = enforce(getNode(true)))
        assert(node.data == ["foo" : "bar"]);

    if (auto node = getNode(false))
        assert(0);  // shouldn't get to here

    try
    {
        // this will throw
        if (auto node = enforce(getNode(false))) { }
        assert(0);
    }
    catch (Exception)
    {
    }
}
