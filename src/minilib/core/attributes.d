/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.attributes;

import std.traits;
import std.typetuple;

import minilib.core.traits;

/**
    A user-defined attribute that can be used to mark a
    field with a custom string for its field name.
*/
struct FieldName
{
    string fieldName;
}

/**
    Get the field name of symbol $(D S). If the symbol is tagged with a
    FieldName attribute, it will be returned. Otherwise the identifier
    of the symbol will be returned.
*/
template getFieldName(S...) if (S.length == 1)
{
    static if (canFindAttributeInstance!(FieldName, S[0]))
    {
        enum string getFieldName = getAttributeInstance!(FieldName, S[0]).fieldName;
    }
    else
    {
        enum string getFieldName = __traits(identifier, S);
    }
}

///
unittest
{
    static struct Sentinel { }

    struct S
    {
        int a;
        @(FieldName("abc")) int b;
        @(Sentinel, FieldName("def")) int c;
        @(FieldName("def"), Sentinel) int d;
    }

    static assert(getFieldName!(S.a) == "a");
    static assert(getFieldName!(S.b) == "abc");
    static assert(getFieldName!(S.c) == "def");
    static assert(getFieldName!(S.d) == "def");
}

/**
    Check whether symbol $(D S) has an attribute which is the type $(D Attribute), but not an instance of it.
*/
template canFindAttributeType(Attribute, S...) if (S.length == 1)
{
    alias Attributes = GetAttributes!(S[0]);

    static if (Attributes.length)
        enum bool canFindAttributeType = canFindAttributeTypeImpl!(Attribute, Attributes);
    else
        enum bool canFindAttributeType = false;
}

///
unittest
{
    static struct Target { this(int) { } }
    static struct Sentinel { }

    struct S
    {
        @(Target) int a;
        @(Sentinel, Target) int b;
        @(Target, Sentinel) int c;

        int d;
        @(Sentinel) int e;
        @(Target(1)) int f;  // not a Type Attribute, but an Instance Attribute
    }

    static assert(canFindAttributeType!(Target, S.a));
    static assert(canFindAttributeType!(Target, S.b));
    static assert(canFindAttributeType!(Target, S.c));
    static assert(!canFindAttributeType!(Target, S.d));
    static assert(!canFindAttributeType!(Target, S.e));
    static assert(!canFindAttributeType!(Target, S.f));
}

/**
    Check whether symbol $(D S) has an attribute which is an instance of type $(D Attribute).
*/
template canFindAttributeInstance(Attribute, S...) if (S.length == 1)
{
    alias Attributes = GetAttributes!(S[0]);

    static if (Attributes.length)
        enum bool canFindAttributeInstance = canFindAttributeInstanceImpl!(Attribute, Attributes);
    else
        enum bool canFindAttributeInstance = false;
}

///
unittest
{
    static struct Target { this(int) { } }
    static struct Sentinel { }

    struct S
    {
        @(Target(1)) int a;
        @(Sentinel, Target(1)) int b;
        @(Target(1), Sentinel) int c;

        int d;
        @(Sentinel) int e;
        @(Target) int f;  // not an Instance Attribute, but a Type Attribute
    }

    static assert(canFindAttributeInstance!(Target, S.a));
    static assert(canFindAttributeInstance!(Target, S.b));
    static assert(canFindAttributeInstance!(Target, S.c));
    static assert(!canFindAttributeInstance!(Target, S.d));
    static assert(!canFindAttributeInstance!(Target, S.e));
    static assert(!canFindAttributeInstance!(Target, S.f));
}

/**
    Return the instance attribute of type $(D Attribute) for symbol $(D S).
    If the symbol does not have this attribute, the template will fail to compile.

    Use $(D canFindAttributeInstance) before calling $(D getAttributeInstance)
    to verify the attribute exists before attempting to retrieve it.
*/
template getAttributeInstance(Attribute, S...) if (S.length == 1)
{
    enum Attribute getAttributeInstance = getAttributeInstanceImpl!(Attribute, GetAttributes!(S[0]));
}

///
unittest
{
    static struct Target { int x; }
    static struct Sentinel { }

    struct S
    {
        @(Target(1)) int a;
        @(Sentinel, Target(1)) int b;
        @(Target(1), Sentinel) int c;

        int d;
        @(Sentinel) int e;
        @(Target) int f;  // not an Instance Attribute, but a Type Attribute
    }

    static assert(getAttributeInstance!(Target, S.a).x == 1);
    static assert(getAttributeInstance!(Target, S.b).x == 1);
    static assert(getAttributeInstance!(Target, S.c).x == 1);

    static assert(!__traits(compiles, { getAttributeInstance!(Target, S.d); }));
    static assert(!__traits(compiles, { getAttributeInstance!(Target, S.e); }));
    static assert(!__traits(compiles, { getAttributeInstance!(Target, S.f); }));
}

/**
    Check whether symbol $(D S) has an attribute which is an instance of template $(D Attribute).
*/
template canFindAttributeTemplateInstance(alias Attribute, S...) if (S.length == 1)
{
    // filter out Type Attributes here, because we can only check against those.
    alias Attributes = Filter!(isType, GetAttributes!(S[0]));

    static if (Attributes.length)
        enum bool canFindAttributeTemplateInstance = canFindAttributeTemplateInstanceImpl!(Attribute, Attributes);
    else
        enum bool canFindAttributeTemplateInstance = false;
}

///
unittest
{
    static struct Target(alias symbol) { alias sym = symbol; }
    static struct Sentinel { }

    static int func() { return 1; }

    struct S
    {
        @(Target!func) int a;
        @(Sentinel, Target!func) int b;
        @(Target!func, Sentinel) int c;

        int d;
        @(Sentinel) int e;
    }

    static assert(canFindAttributeTemplateInstance!(Target, S.a));
    static assert(canFindAttributeTemplateInstance!(Target, S.b));
    static assert(canFindAttributeTemplateInstance!(Target, S.c));

    static assert(!canFindAttributeTemplateInstance!(Target, S.d));
    static assert(!canFindAttributeTemplateInstance!(Target, S.e));
}

/**
    Return the instance of template attribute $(D Attribute) for symbol $(D S).
    If the symbol does not have this attribute, the template will fail to compile.

    Use $(D canFindAttributeTemplateInstance) before calling $(D getAttributeTemplateInstance)
    to verify the attribute exists before attempting to retrieve it.
*/
template getAttributeTemplateInstance(alias Attribute, S...) if (S.length == 1)
{
    // filter out Type Attributes here, because we can only check against those.
    alias Attributes = Filter!(isType, GetAttributes!(S[0]));

    alias getAttributeTemplateInstance = getAttributeTemplateInstanceImpl!(Attribute, Attributes);
}

///
unittest
{
    static struct Target(alias Func) { alias ProcFunc = Func; }
    static struct Sentinel { }

    static int func() { return 1; }

    struct S
    {
        @(Target!func) int a;
        @(Sentinel, Target!func) int b;
        @(Target!func, Sentinel) int c;

        int d;
        @(Sentinel) int e;
    }

    static assert(getAttributeTemplateInstance!(Target, S.a).ProcFunc() == 1);
    static assert(getAttributeTemplateInstance!(Target, S.b).ProcFunc() == 1);
    static assert(getAttributeTemplateInstance!(Target, S.c).ProcFunc() == 1);

    static assert(!__traits(compiles, getAttributeTemplateInstance!(Target, S.d).ProcFunc() == 1));
    static assert(!__traits(compiles, getAttributeTemplateInstance!(Target, S.e).ProcFunc() == 1));
}

private template canFindAttributeTypeImpl(Attribute, Attributes...)
{
    static if (is(Attributes[0] == Attribute))
    {
        enum canFindAttributeTypeImpl = true;
    }
    else
    static if (Attributes.length > 1)
    {
        enum canFindAttributeTypeImpl = canFindAttributeTypeImpl!(Attribute, Attributes[1 .. $]);
    }
    else
    {
        enum canFindAttributeTypeImpl = false;
    }
}

private template canFindAttributeInstanceImpl(Attribute, Attributes...)
{
    static if (is(typeof(Attributes[0]) == Attribute))
    {
        enum canFindAttributeInstanceImpl = true;
    }
    else
    static if (Attributes.length > 1)
    {
        enum canFindAttributeInstanceImpl = canFindAttributeInstanceImpl!(Attribute, Attributes[1 .. $]);
    }
    else
    {
        enum canFindAttributeInstanceImpl = false;
    }
}

private template getAttributeInstanceImpl(Attribute, Attributes...)
{
    static if (is(typeof(Attributes[0]) == Attribute))
    {
        enum getAttributeInstanceImpl = Attributes[0];
    }
    else
    static if (Attributes.length > 1)
    {
        enum getAttributeInstanceImpl = getAttributeInstanceImpl!(Attribute, Attributes[1 .. $]);
    }
    else
    {
        static assert(0, format("Instance of attribute type '%s' not found. Use canFindAttributeInstance before calling getAttributeInstance.", __traits(identifier, Attribute)));
    }
}

private template canFindAttributeTemplateInstanceImpl(alias Attribute, Attributes...)
{
    static if (isInstanceOf!(Attribute, Attributes[0]))
    {
        enum canFindAttributeTemplateInstanceImpl = true;
    }
    else
    static if (Attributes.length > 1)
    {
        enum canFindAttributeTemplateInstanceImpl = canFindAttributeTemplateInstanceImpl!(Attribute, Attributes[1 .. $]);
    }
    else
    {
        enum canFindAttributeTemplateInstanceImpl = false;
    }
}

private template getAttributeTemplateInstanceImpl(alias Attribute, Attributes...)
{
    static if (isInstanceOf!(Attribute, Attributes[0]))
    {
        alias getAttributeTemplateInstanceImpl = Attributes[0];
    }
    else
    static if (Attributes.length > 1)
    {
        alias getAttributeTemplateInstanceImpl = getAttributeTemplateInstanceImpl!(Attribute, Attributes[1 .. $]);
    }
    else
    {
        static assert(0, format("Instance of attribute template type '%s' not found. Use canFindAttributeTemplateInstance before calling getAttributeTemplateInstance.", __traits(identifier, Attribute)));
    }
}
