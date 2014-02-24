/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.dispatch;

/**
    Note: These templates are highly experimental, and slow down compilation considerably.
    Due to various bugs and issues with mixin templates they shouldn't be used in production
    code, but should only be used for experimental purposes.
*/

import core.exception;

import std.algorithm;
import std.conv;
import std.exception;
import std.stdio;
import std.string;
import std.traits;
import std.typetuple;

import minilib.core.traits;
import minilib.core.util;

/** Dispatches an object based on its dynamic type. */
template DispatchObject(Leaves...)
{
    template DispatchObject(alias func)
    {
        auto DispatchObject(Class, Args...)(Class object, Args args)
        {
            auto classInfo = typeid(object);

            foreach (Base; ClassTree!Leaves)
            {
                static if (CanCallFunc!(func, Base, Args))
                {
                    if (classInfo == Base.classinfo)
                        return func(Cast!Base(object), args);
                }
            }

            assert(0, format("function '%s' is not callable with types '%s'",
                             __traits(identifier, func), Args.stringof));
        }
    }
}

///
version(unittest)
{
    class DO_A { }
    class DO_B : DO_A { }
    class DO_C : DO_B { }
    class DO_D : DO_B { }

    void foo(DO_C c, int x) { assert(x == 1); }
    void foo(DO_D d, int x, int y) { assert(x == 2 && y == 3); }
}

///
unittest
{
    DO_A c = new DO_C;
    DO_A d = new DO_D;
    DO_A a = new DO_A;

    // alias for a class tree, usable with any function
    alias callFunc = DispatchObject!(DO_C, DO_D);

    callFunc!foo(c, 1);
    callFunc!foo(d, 2, 3);
    assertThrown!AssertError(callFunc!foo(a, 3));

    // alias a specific function for this class tree
    alias callFoo = callFunc!foo;

    callFoo(c, 1);
    callFoo(d, 2, 3);
    assertThrown!AssertError(callFoo(a, 3));
}

/** Dynamic dispatch of object method. */
mixin template DynamicDispatch(Leaves...)
{
    import core.exception;
    import std.exception;
    import std.stdio;
    import std.string;
    import std.traits;
    import std.typetuple;

    auto dynamic(Class)(Class obj)
        if (Inherits!(Class, Leaves))
    {
        static struct Dispatch(Class)
        {
            Class obj;
            auto opDispatch(string methName, Args...)(Args args) @system
            {
                alias dispatch = DispatchMethod!methName;
                return dispatch(obj, args);
            }
        }

        return Dispatch!Class(obj);
    }

    template DispatchMethod(string methodName)
    {
        auto DispatchMethod(Class, Args...)(Class object, Args args)
        {
            auto classInfo = typeid(object);

            enum call = format(q{
                if (classInfo == Base.classinfo)
                    return Cast!Base(object).%s(args);
            },
            methodName);

            alias ClassList = ClassTree!Leaves;

            /** Find dynamic type which matches one of the types in the class trees. */
            foreach (Base; ClassList)
            {
                static if (CanCall!(Base, methodName, Args))
                {
                    mixin(call);
                }
            }

            /**
                Class is not registered or does not implement the method.
                Find the closest base class which implements the method.
            */
            foreach (Base; ClassList)
            {
                classInfo = classInfo.base;
                while (classInfo !is null)
                {
                    static if (CanCall!(Base, methodName, Args))
                    {
                        mixin(call);
                    }

                    classInfo = classInfo.base;
                }
            }

            /** todo: interfaces could have function implementations. */
            assert(0, format("method '%s.%s' is not callable with types '(%s)'",
                             typeid(object).toString(), methodName, Args.stringof));
        }
    }

    mixin(DispatchHelpers());
}

///
version(unittest)
{
    class DD_A        { private void foo(int x) { assert(x == 1); } }
    class DD_B : DD_A { private void foo(int x) { assert(x == 2); } }
    class DD_C : DD_B { private void foo(int x) { assert(x == 3); } }
    class DD_D : DD_B { private void foo(int x) { assert(x == 4); } }
    class DD_E : DD_B { }

    // Pass leaf class types so they can be registered
    mixin DynamicDispatch!(DD_C, DD_D, DD_E);
}

///
unittest
{
    DD_A a = new DD_A;
    DD_A b = new DD_B;
    DD_A c = new DD_C;
    DD_A d = new DD_D;
    DD_A e = new DD_E;

    a.dynamic.foo(1);
    b.dynamic.foo(2);
    c.dynamic.foo(3);
    d.dynamic.foo(4);
    e.dynamic.foo(2);
}

/**
    Dispatches a target object and arguments to a method of the
    'this' object, based on the dynamic type of the target object.
*/
mixin template DynamicDispatchMethod(ThisClass, Leaves...)
{
    import core.exception;
    import std.exception;
    import std.stdio;
    import std.string;
    import std.traits;
    import std.typetuple;

    auto dynamic(T)(T obj)
        if (is(T == ThisClass))
    {
        static struct Dispatch
        {
            ThisClass obj;
            auto opDispatch(string methName, Args...)(Args args) @system
            {
                alias dispatch = DispatchMethod!methName;
                return dispatch(obj, args);
            }
        }

        return Dispatch(obj);
    }

    alias DynamicDispatchMethod = dynamic;

    template DispatchMethod(string methodName)
    {
        auto DispatchMethod(ClassTarget, Args...)(ThisClass thisObj, ClassTarget dynObj, Args args)
        {
            auto classInfo = typeid(dynObj);

            enum call = format(q{
                if (classInfo == Base.classinfo)
                    return thisObj.%s(Cast!Base(dynObj), args);
            },
            methodName);

            alias ClassList = ClassTree!Leaves;

            /** Find dynamic type which matches one of the types in the class trees. */
            foreach (Base; ClassList)
            {
                static if (CanCall!(ThisClass, methodName, TypeTuple!(Base, Args)))
                {
                    mixin(call);
                }
            }

            /**
                Class is not registered or does not implement the method.
                Find the closest base class which implements the method.
            */
            foreach (Base; ClassList)
            {
                classInfo = classInfo.base;
                while (classInfo !is null)
                {
                    static if (CanCall!(ThisClass, methodName, TypeTuple!(Base, Args)))
                    {
                        mixin(call);
                    }

                    classInfo = classInfo.base;
                }
            }

            /** todo: interfaces could have function implementations. */
            assert(0, format("method '%s.%s' is not callable with types '(%s)'",
                             typeid(thisObj).toString(), methodName, Args.stringof));
        }
    }

    mixin(DispatchHelpers());
}

///
version(unittest)
{
    class DDM_T1 { int x = 1; }
    class DDM_T2 : DDM_T1 { int x = 2; }
    class DDM_T3 : DDM_T1 { int x = 3; }
    class DDM_T4 : DDM_T2 { int x = 4; }
    class DDM_T5 : DDM_T3 { int x = 5; }

    class DDM_Class
    {
        void test()
        {
            DDM_T1 t1 = new DDM_T1;
            DDM_T1 t2 = new DDM_T2;
            DDM_T1 t3 = new DDM_T3;
            DDM_T1 t4 = new DDM_T4;
            DDM_T1 t5 = new DDM_T5;

            this.dynamic.foo(t1);
            this.dynamic.foo(t2);
            this.dynamic.foo(t3);
            this.dynamic.foo(t4);
            this.dynamic.foo(t5);
        }

        private void foo(DDM_T1 c) { assert(c.x == 1); };
        private void foo(DDM_T2 c) { assert(c.x == 2); };
        private void foo(DDM_T3 c) { assert(c.x == 3); };
        private void foo(DDM_T4 c) { assert(c.x == 4); };
        private void foo(DDM_T5 c) { assert(c.x == 5); };
    }

    // Pass leaf class types so they can be registered
    mixin DynamicDispatchMethod!(DDM_Class, DDM_T5, DDM_T4);
}

///
unittest
{
    auto ddm = new DDM_Class();
    ddm.test();
}

/**
    Tag-based dynamic dispatch to object method. This is
    similar to DynamicDispatch, except it expects a
    'thisTag' field which marks the tag of the class object,
    and a 'ThisTag' manifest in each Class type in the
    class hierarchy.
*/
mixin template TagDispatch(Leaves...)
{
    // note: not a constraint: bug in 'struct PushBaseMembers' in traits.c where 'base' is NULL.
    // disabled: forward reference errors
    /+ static assert(allSatisfy!(hasField!"thisTag", AllClasses)
        && allSatisfy!(hasField!"thisTag", AllClasses)); +/

    import core.exception;
    import std.exception;
    import std.stdio;
    import std.string;
    import std.traits;
    import std.typetuple;

    auto dynamic(Class)(Class obj)
        if (Inherits!(Class, Leaves))
    {
        static struct Dispatch(Class)
        {
            Class obj;

            auto opDispatch(string methName, Args...)(Args args) @system
            {
                alias dispatch = DispatchMethod!methName;
                return dispatch(obj, args);
            }
        }

        return Dispatch!Class(obj);
    }

    template DispatchMethod(string methodName)
    {
        auto DispatchMethod(Class, Args...)(Class object, Args args)
        {
            auto thisTag = object.thisTag;
            foreach (Base; ClassTree!Leaves)
            {
                static if (CanCall!(Base, methodName, Args))
                {
                    mixin(format(
                    q{
                        if (thisTag == Base.ThisTag)
                            return Cast!Base(object).%s(args);
                    },
                    methodName));
                }
            }

            assert(0, format("method '%s.%s' is not callable with types '%s' and object tag '%s'.",
                             typeid(object).toString(), methodName, Args.stringof, thisTag));
        }
    }

    mixin(DispatchHelpers());
}

///
version(unittest)
{
    enum TD_Tag
    {
        Invalid,
        A,
        B,
        C,
        D
    }

    class TD_A
    {
        TD_Tag thisTag;
        enum ThisTag = TD_Tag.A;
        this(TD_Tag tag = ThisTag) { this.thisTag = tag; }
        package int foo(int x) { assert(x == 1, text(x)); return x; }
    }

    class TD_B : TD_A
    {
        enum ThisTag = TD_Tag.B;
        this(TD_Tag tag = ThisTag) { super(tag); }
        package int foo(int x) { assert(x == 2, text(x)); return x; }
    }

    class TD_C : TD_A
    {
        enum ThisTag = TD_Tag.C;
        this(TD_Tag tag = ThisTag) { super(tag); }
        package int foo(int x) { assert(x == 3, text(x)); return x; }
    }

    class TD_FD : TD_A
    {
        enum ThisTag = TD_Tag.D;
        this(TD_Tag tag = TD_Tag.Invalid) { super(tag); }
        package int foo(int x) { assert(x == 4, text(x)); return x; }
    }

    mixin TagDispatch!(TD_FD, TD_C, TD_B);
}

///
unittest
{
    TD_A a = new TD_A;
    TD_A b = new TD_B;
    TD_A c = new TD_C;
    TD_A d = new TD_FD;

    assert(a.dynamic.foo(1) == 1);
    assert(b.dynamic.foo(2) == 2);
    assert(c.dynamic.foo(3) == 3);
    assertThrown!AssertError(d.dynamic.foo(4));
}

/**
    - Can't be a mixin template due to forward reference bugs.

    - Can't be a private struct, mixin template won't have
      access to it from other scopes.

    - Can't be a public struct, inner code won't have access
      to private/protected methods.
*/
string DispatchHelpers()
{
    return q{

    /** Check if we can call methodName on Object with argument types Args. */
    template CanCall(Object, string methodName, Args...)
        if (is(Object == class))
    {
        bool canCall()
        {
            Object obj;
            Args args;
            enum str = format("obj.%s(args);", methodName);

            return __traits(compiles, {
                mixin(str);
            });
        }

        enum CanCall = canCall();
    }

    };
}
