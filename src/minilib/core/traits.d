/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.traits;

import core.exception;

import std.array;
import std.conv;
import std.exception;
import std.range;
import std.string;
import std.traits;
import std.typecons;
import std.typetuple;

import minilib.core.algorithm;
import minilib.core.util;
import minilib.core.string;

/**
    Check whether every enum member value can be used as a unique flag.
    Such enums can be used in operations like bit masking.
*/
template isValidFlag(E)
    if (is(E == enum))
{
    static if (is(E B == enum))
        alias BaseType = B;

    static bool checkFlag()
    {
        BaseType flag;
        foreach (member; EnumMembers!E)
        {
            if (member & flag)
                return false;

            flag |= member;
        }

        return true;
    }

    enum bool isValidFlag = checkFlag();
}

///
unittest
{
    enum EK1 { a, b, c }    // 0b00, 0b01, 0b10
    enum EF1 { a, b, c, d } // 0b00, 0b01, 0b10, 0b11 (conflict)
    enum EK2 { a = 1 << 1, b = 1 << 2, c = 1 << 3, d = 1 << 4 }
    enum EF2 { a = 1 << 1, b = 1 << 2, c = 3 << 3, d = 1 << 4 }
    static assert(isValidFlag!EK1);
    static assert(!isValidFlag!EF1);
    static assert(isValidFlag!EK2);
    static assert(!isValidFlag!EF2);
}

/**
    Get the number of fields in an enum.
*/
template EnumLength(E)
    if (is(E == enum))
{
    enum EnumLength = __traits(allMembers, E).length;
}

///
unittest
{
    enum X { a, b }
    enum Y { c = X.a, d = X.b }
    static assert(EnumLength!X == EnumLength!Y);
}

/**
    Similar to $(D EnumMembers) except any $(D .invalid) and
    $(D .Invalid) enum members are filtered out.
*/
template EnumValidMembers(E)
    if (is(E == enum))
{
    static if (is(typeof( E.invalid )))
        alias EnumValidMembers = EraseAll!(E.invalid, EnumMembers!E);
    else
    static if (is(typeof( E.Invalid )))
        alias EnumValidMembers = EraseAll!(E.Invalid, EnumMembers!E);
    else
        alias EnumValidMembers = EnumMembers!E;
}

///
unittest
{
    enum A { a, b, invalid }
    enum B { a, b, Invalid }
    enum C { a, b }

    static assert(EnumValidMembers!A == TypeTuple!(A.a, A.b));
    static assert(EnumValidMembers!B == TypeTuple!(B.a, B.b));
    static assert(EnumValidMembers!C == TypeTuple!(C.a, C.b));
}

/**
    Extract aggregate or enum $(D T)'s members by making aliases to each member,
    effectively making the members accessible from module scope without qualifications.
*/
mixin template ExportMembers(T)
    if (isAggregate!T || is(T == enum))
{
    mixin(_makeAggregateAliases!(T)());
}

///
unittest
{
    struct S
    {
        static int x;
        static int y;
    }

    mixin ExportMembers!S;

    x = 1;
    y = 2;
    assert(S.x == 1 && S.y == 2);
}

/**
    Extract enum E's members by making aliases to each member,
    effectively making the members accessible from module
    scope without qualifications (similar to C-style enums).
*/
mixin template ExportEnumMembers(E)
    if (is(E == enum))
{
    mixin(_makeAggregateAliases!(E)());
}

/// ditto: compatibility alias
alias ExtractEnumMembers = ExportEnumMembers;

///
unittest
{
    enum enum_type_t
    {
        foo,
        bar,
    }

    mixin ExportEnumMembers!enum_type_t;

    enum_type_t e1 = enum_type_t.foo;  // ok
    enum_type_t e2 = bar;    // ok
}

private string _makeAggregateAliases(T)()
    if (isAggregate!T || is(T == enum))
{
    enum enumName = __traits(identifier, T);
    Appender!(string[]) result;

    foreach (string member; __traits(allMembers, T))
        result ~= format("alias %s = %s.%s;", member, enumName, member);

    return result.data.join("\n");
}

/** Check if T is an aggregate type. */
template isAggregate(T)
{
    enum bool isAggregate = is(T == struct) || is(T == class) || is(T == union);
}

///
unittest
{
    static struct S { union U { } }
    class C { }
    static assert(isAggregate!S);
    static assert(isAggregate!(S.U));
    static assert(isAggregate!(C));
}

/** Check if aggregate T has any members which are aggregate types. */
template hasAggregateMembers(T) if (isAggregate!T)
{
    enum hasAggregateMembers = anySatisfy!(isAggregate, FieldTypeTuple!T);
}

unittest
{
    static struct S1 { }
    static struct S2 { int x; }
    static struct S3 { int x; S2 s2; }

    static assert(!hasAggregateMembers!S1);
    static assert(!hasAggregateMembers!S2);
    static assert(hasAggregateMembers!S3);
}

/** Check if T is a struct type. */
template isStruct(T)
{
    enum bool isStruct = is(T == struct);
}

///
unittest
{
    static struct S { }
    static class C { }
    static assert(isStruct!S);
    static assert(!isStruct!C);
}

/** Check if T is a class type. */
template isClass(T)
{
    enum bool isClass = is(T == class);
}

///
unittest
{
    static class C { }
    static struct S { }
    static assert(isClass!C);
    static assert(!isClass!S);
}

/** Check if T is a union type. */
template isUnion(T)
{
    enum bool isUnion = is(T == union);
}

///
unittest
{
    static class C { }
    static struct S { static union U { int x; } }
    static assert(!isUnion!C);
    static assert(!isUnion!S);
    static assert(isUnion!(S.U));
}

/** Check if any of Types inherit Root. */
template Inherits(Root, Types...)
    if (allSatisfy!(isClass, Root, Types))
{
    bool inherits()
    {
        foreach (Type; Types)
        {
            static if (is(Type : Root))
                return true;
        }

        return false;
    }

    enum bool Inherits = inherits();
}

///
unittest
{
    static class C1 { }
    static class C2 : C1 { }
    static class C3 : C2 { }
    static class C4 { }

    static assert(Inherits!(C1, C2, C3));
    static assert(!Inherits!(C1, C4));
}

/**
    Get the tree of base classes for Leaf classes.
    The order is:
        Leaf1 -> Base, Leaf2 -> Base.

    The Object class is not included.
*/
template ClassTree(Leaves...)
{
    alias DerivedToFront!(Erase!(Object, NoDuplicates!(ClassTreeImpl!(Leaves)))) ClassTree;
}

///
unittest
{
    static class A { }
    static class B : A { }

    static class L1 : B { }
    static class L2 : A { }
    static assert(is(ClassTree!(L1, L2) == TypeTuple!(L1, B, L2, A)));
}

private template ClassTreeImpl(Leaves...)
{
    static if (Leaves.length > 1)
    {
        alias TypeTuple!(Leaves[0], BaseClassesTuple!(Leaves[0]),
                         ClassTreeImpl!(Leaves[1..$])) ClassTreeImpl;
    }
    else
    static if (Leaves.length == 1)
    {
        alias TypeTuple!(Leaves[0], BaseClassesTuple!(Leaves[0])) ClassTreeImpl;
    }
    else
    {
        alias TypeTuple!() ClassTreeImpl;
    }
}

/** Check if func can be called with argument types Args. */
template CanCallFunc(alias func, Args...)
{
    bool canCallFunc()
    {
        Args args;
        return __traits(compiles,
        {
            func(args);
        }
        );
    }

    enum bool CanCallFunc = canCallFunc();
}

///
unittest
{
    static void f(double x) { }

    static assert(CanCallFunc!(f, int));
    static assert(CanCallFunc!(f, double));
    static assert(!CanCallFunc!(f, string));
}

/**
    Check if type T has a field of this name.
    Similar to $(D hasMember) except with the field
    name as the first argument. This allows currying
    and use of the template as a predicate template.
*/
template hasField(string name, T)
{
    enum bool hasField = hasMember!(T, name);
}

///
unittest
{
    static struct S1 { int f; }
    static struct S2 { int f; }
    static struct S3 { int f; }
    static struct S4 { }

    alias hasF = Curry!(hasField, "f");
    static assert(allSatisfy!(hasF, TypeTuple!(S1, S2, S3)));
    static assert(!allSatisfy!(hasF, S4));
}

/** Check if type T has members named Members. */
template hasMembers(T, Members...)
    if (isAggregate!T && allSatisfy!(isAString, Members))
{
    enum bool hasFirstMember = __traits(hasMember, T, Members[0]);

    static if (Members.length == 1)
        enum bool hasMembers = hasFirstMember;
    else
        enum bool hasMembers = hasFirstMember && hasMembers!(T, Members[1..$]);
}

///
unittest
{
    static struct S
    {
        int x, y, z;
    }

    static assert(hasMembers!(S, "x", "y", "z"));
    static assert(!hasMembers!(S, "x", "y", "z", "a"));
}

/** Return the member $(D name) of type $(D T). */
template GetMember(T, string name)
    if (isAggregate!T)
{
    alias GetMember = TypeTuple!(__traits(getMember, T.init, name));
}

/// todo: unittest
unittest
{
}

/** Return the type of T's member. */
template getMemberType(T, string member)
    if (hasMember!(T, member))
{
    alias getMemberType = typeof(__traits(getMember, T, member));
}

///
unittest
{
    static struct S
    {
        int x;
        float y;
        string z;
    }

    static assert(is(getMemberType!(S, "x") == int));
    static assert(is(getMemberType!(S, "y") == float));
    static assert(is(getMemberType!(S, "z") == string));
}

/** Return a type tuple of T's members types. */
template getMemberTypes(T, Members...)
    if (hasMembers!(T, Members))
{
    alias FrontType = getMemberType!(T, Members[0]);

    static if (Members.length == 1)
        alias getMemberTypes = FrontType;
    else
        alias getMemberTypes = TypeTuple!(FrontType, .getMemberTypes!(T, Members[1 .. $]));
}

///
unittest
{
    static struct S
    {
        int x;
        float y;
        string z;
    }

    static assert(is(getMemberTypes!(S, "x") == int));
    static assert(is(getMemberTypes!(S, "x", "y") == TypeTuple!(int, float)));
    static assert(is(getMemberTypes!(S, "x", "y", "z") == TypeTuple!(int, float, string)));
}

/**
    Return the values of Fields of aggregate T as a tuple.
    The tuple's fields are accessible by name.
*/
template getFields(Fields...)
    if (allSatisfy!(isAString, Fields))
{
    auto getFields(T)(T arg)
        if (isAggregate!T)
    {
        foreach (Field; Fields)
        {
            static assert(__traits(hasMember, T, Field),
                format(`Type %s does not have the field named "%s".`, T.stringof, Field));
        }

        enum TypeNames = toArray!(getMemberTypes!(T, Fields));
        enum FieldNames = toArray!(Fields);
        enum SpecList = multimap!((a, b) => format(`%s, "%s"`, a, b))(TypeNames, FieldNames).join(", ");

        enum returnExp = format(q{
            with (arg)
            {
                Tuple!(%s) tup = tuple(%s);
                return tup;
            }
        }, SpecList, FieldNames.join(", "));

        mixin(returnExp);
    }
}

///
unittest
{
    static struct S
    {
        int x, y, z;
    }

    alias getXZ = getFields!("x", "z");

    S s = S(1, 2, 3);
    auto tup = getXZ(s);

    assert(tup.x == 1);
    assert(tup.z == 3);
}

/** Return field recursively as an array. */
template getFieldRecurse(string Field)
{
    T[] getFieldRecurse(T)(T arg)
        if (hasField!(Field, T)
            && (is(getMemberType!(T, Field) == T)
            || (isArray!(getMemberType!(T, Field))
                && is(ElementTypeOf!(getMemberType!(T, Field)) == T))))
    {
        alias FieldType = getMemberType!(T, Field);
        alias ElementType = ElementTypeOf!FieldType;

        Appender!(ElementType[]) result;
        result ~= arg;

        static if (isArray!FieldType)
        {
            foreach (elem; __traits(getMember, arg, Field))
                result ~= .getFieldRecurse!Field(elem);
        }
        else
        {
            result ~= __traits(getMember, arg, Field);
        }

        return result.data;
    }
}

///
unittest
{
    static class C1
    {
        this() { }
        this(C1[] c) { children = c; }
        C1[] children;
    }

    alias getFieldRecurse!"children" getAllChildren;
    auto c1 = new C1([new C1]);
    assert(getAllChildren(c1).length == 2);

    static class C2
    {
        this() { }
        this(C2 c) { child = c; }
        C2 child;
    }

    alias getFieldRecurse!"child" getAllChild;
    auto c2 = new C2(new C2);
    assert(getAllChild(c2).length == 2);
}

/** Check if any Predicate returns true when instantiated with the first type or symbol T. */
template anyPredicateSatisfy(T...)
{
    static if (T.length > 1)
    {
        alias Target = T[0];
        alias Pred = T[1];  // Workaround for Issue 6474

        static if (__traits(compiles, Pred!Target))  // Test if alias/type can pass first
            enum bool isPred = Pred!Target;
        else
            enum bool isPred = false;

        enum bool anyPredicateSatisfy = isPred || anyPredicateSatisfy!(Target, T[2 .. $]);
    }
    else
    {
        enum bool anyPredicateSatisfy = false;
    }
}

///
unittest
{
    // test type
    static assert(anyPredicateSatisfy!(int, isFloatingPoint, isIntegral));
    static assert(!anyPredicateSatisfy!(int, isFloatingPoint, isSomeFunction));

    // test alias
    int x;
    static assert(!anyPredicateSatisfy!(x, isFloatingPoint, isIntegral));
    static assert(anyPredicateSatisfy!(x, isFloatingPoint, isIntegral, isAlias));
}

/** Check if $(D S) is a symbol of some sort. */
template isAlias(alias S) { enum bool isAlias = true; }

/// ditto
template isAlias(S) { enum bool isAlias = false; }

///
unittest
{
    static assert(!isAlias!int);
    struct S { this(int) { } }
    int x;
    alias y = x;
    static assert(isAlias!x);
    static assert(isAlias!y);
    static assert(isAlias!"");
    static assert(isAlias!(S(0)));

    static assert(is(typeof(Filter!(isAlias, int, 1.0)) == TypeTuple!(double)));
}

/** Check if T is a type and not a symbol. */
template isType(alias T)
{
    template isAType(T) { enum bool isAType = true; }
    enum bool isType = __traits(compiles, isAType!T);
}

/// ditto
template isType(T)
{
    enum bool isType = true;
}

///
unittest
{
    static assert(isType!int);
    struct S { this(int) { } }

    int x;
    alias y = x;
    static assert(!isType!x);
    static assert(!isType!y);
    static assert(!isType!"");
    static assert(!isType!(S(0)));

    static assert(is(Filter!(isType, int, x, y, float, "", 1, 2.0, S(0)) == TypeTuple!(int, float)));

    struct Templ(X) { }
    static assert(isType!S);
    static assert(isType!(Templ!S));
    static assert(!isType!Templ);
    static assert(!isType!1);
}

/** Return Target with qualifiers set to those of Source. */
template CopyQualifier(Source, Target)
{
         static if (is(Source U == shared(const U))) alias CopyQualifier = shared(const Target);
    else static if (is(Source U ==    immutable U )) alias CopyQualifier =    immutable(Target);
    else static if (is(Source U ==       shared U )) alias CopyQualifier =       shared(Target);
    else static if (is(Source U ==        const U )) alias CopyQualifier =        const(Target);
    else                                             alias CopyQualifier =              Target;
}

///
unittest
{
    alias CQ = CopyQualifier;

    static assert(is(CQ!(             int,   float) ==              float));
    static assert(is(CQ!(       const(int),  float) ==        const(float)));
    static assert(is(CQ!(      shared(int),  float) ==       shared(float)));
    static assert(is(CQ!(   immutable(int),  float) ==    immutable(float)));
    static assert(is(CQ!(shared(const(int)), float) == shared(const(float))));
}

/**
    Swap the element type of Type with Elem.
    Type can be a regular type, array, static array, or pointer.
    Type qualifiers will be preserved.
*/
template SwapElementType(Type, Elem)
    if (!isAssociativeArray!Type)
{
    // note: static array check must come before non-static array check
    static if (is(Type T : T[N], size_t N))
    {
        alias SwapElementType!(T, Elem)[N] R;
    }
    else
    static if (is(Type T : T[]))
    {
        alias SwapElementType!(T, Elem)[] R;
    }
    else
    static if (is(Type T : T*))
    {
        alias SwapElementType!(T, Elem)* R;
    }
    else
    {
        alias Elem R;
    }

    alias SwapElementType = CopyQualifier!(Type, R);
}

///
unittest
{
    alias SET = SwapElementType;

    // swap element type
    static assert(is(SET!(int, float) == float));

    // swap array element type
    static assert(is(SET!(             int[][],     float) ==              float[][]));
    static assert(is(SET!(       const(int)[][],    float) ==        const(float)[][]));
    static assert(is(SET!(       const(int[])[],    float) ==        const(float[])[]));
    static assert(is(SET!(shared(const(int[])[]),   float) == shared(const(float[])[])));

    // swap static array element type
    static assert(is(SET!(             int[1][2],   float) ==              float[1][2]));
    static assert(is(SET!(       const(int)[1][2],  float) ==        const(float)[1][2]));
    static assert(is(SET!(       const(int[1])[2],  float) ==        const(float[1])[2]));
    static assert(is(SET!(shared(const(int[1])[2]), float) == shared(const(float[1])[2])));

    // swap pointer element type
    static assert(is(SET!(             int**,   float) ==              float**));
    static assert(is(SET!(       const(int)**,  float) ==        const(float)**));
    static assert(is(SET!(const(shared(int*))*, float) == const(shared(float*))*));

    // associative arrays as source type are not supported
    static assert(!__traits(compiles, SET!(int[string],  float)));
    static assert(!__traits(compiles, SET!(int[string]*, float)));

    // however they are supported as the target type
    static assert(is(SET!(int[10], float[string]) == float[string][10]));
}

/**
    Return the element type of Type.

    Note: This is different from ElementType in
    std.range which returns the type of the .front property.
*/
template ElementTypeOf(Type)
{
    static if(is(Type T : T[N], size_t N))
    {
        alias ElementTypeOf = T;
    }
    else
    static if(is(Type T : T[]))
    {
        alias ElementTypeOf = T;
    }
    else
    static if(is(Type T : T*))
    {
        alias ElementTypeOf = T;
    }
    else
    {
        alias ElementTypeOf = Type;
    }
}

///
unittest
{
    static assert(is(ElementTypeOf!int == int));
    static assert(is(ElementTypeOf!(int[]) == int));
    static assert(is(ElementTypeOf!(int[][]) == int[]));
    static assert(is(ElementTypeOf!(int[1][2]) == int[1]));
    static assert(is(ElementTypeOf!(int**) == int*));
}

/**
    Return the base element type of Type.

    Note: This is different from ElementType in
    std.range which returns the type of the .front property.
*/
template BaseElementType(Type)
{
    static if(is(Type T : T[N], size_t N))
    {
        alias BaseElementType = BaseElementType!T;
    }
    else
    static if(is(Type T : T[]))
    {
        alias BaseElementType = BaseElementType!T;
    }
    else
    static if(is(Type T : T*))
    {
        alias BaseElementType = BaseElementType!T;
    }
    else
    {
        alias BaseElementType = Type;
    }
}

///
unittest
{
    static assert(is(BaseElementType!int == int));
    static assert(is(BaseElementType!(int[]) == int));
    static assert(is(BaseElementType!(int[][]) == int));
    static assert(is(BaseElementType!(int[1][2]) == int));
    static assert(is(BaseElementType!(int**) == int));
}

/** Check if expression T is a string. */
template isAString(alias T)
{
    enum bool isAString = std.traits.isSomeString!(typeof(T));
}

///
unittest
{
    static assert(isAString!"foo");
}

/** Check if type T is a string. */
template isAString(T)
{
    enum bool isAString = std.traits.isSomeString!T;
}

///
unittest
{
    string s;
    static assert(isAString!(typeof(s)));
    static assert(isAString!string);
    static assert(isAString!(char[]));
}

/** Convert a tuple of types into a string array. */
template toArray(Types...)
{
    string[] toArrayImpl()
    {
        Appender!(string[]) result;

        foreach (T; Types)
        {
            static if (isAString!T)
                result ~= T;
            else
                result ~= T.stringof;
        }

        return result.data;
    }

    enum string[] toArray = toArrayImpl();
}

///
unittest
{
    static assert(toArray!(TypeTuple!(int, float)) == ["int", "float"]);
    static assert(toArray!(TypeTuple!("int", "float")) == ["int", "float"]);
}

/** Return the element count of a static array. */
template ElementCount(T)
    if (isStaticArray!T)
{
    static if (is(T E : E[Size], int Size))
    {
        static if (isStaticArray!E)
            enum ElementCount = Size + ElementCount!E;
        else
            enum ElementCount = Size;
    }
}

///
unittest
{
    static assert(ElementCount!(int[2][2]) == 4);
    static assert(ElementCount!(int[][2][2]) == 4);
}

/** Return a unidimensional representation of a static array. */
template Flatten(T)
    if (isStaticArray!T)
{
    alias BaseElementType!T[ElementCount!T] Flatten;
}

///
unittest
{
    static assert(is(Flatten!(int[2][2]) == int[4]));
    static assert(is(Flatten!(int[1][1][1][1]) == int[4]));
}

/**
    Return the index of Target type in the list of Types, or -1 if not found.
    This is a faster version of staticIndexOf from std.typetuple, but it only
    works on types.
*/
template staticIndexOfType(Target, Types...)
{
    size_t getIndex()
    {
        foreach (idx, Type; Types)
        {
            static if (is(Target == Type))
                return idx;
        }

        return -1;
    }

    enum staticIndexOfType = getIndex();
}

///
unittest
{
    static assert(staticIndexOfType!(int,    TypeTuple!(int, float)) == 0);
    static assert(staticIndexOfType!(float,  TypeTuple!(int, float)) == 1);
    static assert(staticIndexOfType!(string, TypeTuple!(int, float)) == -1);
}

/** Curry template arguments T to a Template to allow aliasing the template. */
template Curry(alias Templ, T...)
{
    template Curry(X...)
    {
        alias Curry = Templ!(T, X);
    }
}

unittest
{
    static struct S1 { int x; }
    static struct S2 { int y; }

    alias hasX = Curry!(hasField, "x");
    static assert(hasX!S1);
    static assert(!hasX!S2);
    static assert(hasField!("x", S1));
}

/** Check whether Range is an input range that has characters as its element type. */
template isStringRange(Range)
{
    enum isStringRange = isInputRange!Range && isSomeChar!(ElementType!Range);
}

/** Return the attributes of a type or symbol $(D T). */
template GetAttributes(T...) if (T.length == 1)
{
    alias GetAttributes = TypeTuple!(__traits(getAttributes, T[0]));
}

///
unittest
{
    @("foo") struct S
    {
        @("bar") int x;
    }

    static assert(GetAttributes!S[0] == "foo");
    static assert(GetAttributes!(S.x)[0] == "bar");
}

/**
    Checks whether $(D Target) matches any $(D Types).
*/
template isOneOf(Target, Types...)
{
    static if (Types.length > 1)
    {
        enum bool isOneOf = isOneOf!(Target, Types[0]) || isOneOf!(Target, Types[1 .. $]);
    }
    else static if (Types.length == 1)
    {
        enum bool isOneOf = is(Unqual!Target == Unqual!(Types[0]));
    }
    else
    {
        enum bool isOneOf = false;
    }
}

///
unittest
{
    static assert(isOneOf!(int, float, string, const(int)));
    static assert(isOneOf!(const(int), float, string, int));
    static assert(!isOneOf!(int, float, string));
}

/**
    This implements a static foreach over an enum array.
    This allows using code such as typeof() and mixins
    at the call site.
*/
template StaticForeach(alias Arg) if (isArray!(typeof(Arg)))
{
    static if (Arg.length > 1)
        alias StaticForeach = TypeTuple!(Arg[0], StaticForeach!(Arg[1 .. $]));
    else
        alias StaticForeach = TypeTuple!(Arg[0]);
}

///
unittest
{
    enum vals = ["foo", "bar"];

    foreach (idx, val; StaticForeach!(vals))
    {
        static if (idx == 0)
            static assert(val == "foo");
        else
            static assert(val == "bar");
    }
}

/** Get all accessible members of aggregate type $(D T) as a string tuple. */
template GetAllMembers(T)
    if (isAggregate!T && !isNested!T)
{
    alias GetAllMembers = GetAllMembersImpl!(T, __traits(allMembers, T));
}

///
unittest
{
    static struct S
    {
        @property void x(int) { }
        @property int x() { return 0; }
        void y() { }
        int z;
    }

    static assert(GetAllMembers!S.length == 3, GetAllMembers!S);
}

private template GetAllMembersImpl(T, Members...)
    if (isAggregate!T && !isNested!T)
{
    static if (Members.length > 1)
    {
        alias GetAllMembersImpl = TypeTuple!(
            GetAllMembersImpl!(T, Members[0]),
            GetAllMembersImpl!(T, Members[1 .. $]),
        );
    }
    else
    {
        static if (is(typeof(
            __traits(getOverloads, T, Members[0])
        )))
        {
            alias GetAllMembersImpl = TypeTuple!(Members[0]);
        }
        else
        {
            alias GetAllMembersImpl = TypeTuple!();
        }
    }
}

/** Get all $(D member) overloads of aggregate type $(D T). */
template GetOverloads(T, string member)
    if (isAggregate!T && !isNested!T)
{
    alias GetOverloads = TypeTuple!(__traits(getOverloads, T, member));
}

///
unittest
{
    static struct S
    {
        @property void a(int) { }
        @property int a() { return 0; }

        void b() { }

        int c;

        void d() { }
        void d(int) { }
    }

    static assert(GetOverloads!(S, "a").length == 2);
    static assert(GetOverloads!(S, "b").length == 1);
    static assert(GetOverloads!(S, "c").length == 0);
    static assert(GetOverloads!(S, "d").length == 2);
}

// todo: enable when we start supporting nested types
/** Check if $(D member) is actually a context pointer. */
/+ template IsMemberContextPointer(T, string member)
{
    enum IsMemberContextPointer = __traits(isNested, T) && member == "this";
}

///
unittest
{
    int x;

    struct S
    {
        void test() { x++; }  // requires context pointer
    }

    foreach (member; GetAllMembers!S)
    {
        static if (member == "this")
        {
            static assert(IsMemberContextPointer!(S, member));
        }
    }
} +/

/** Get all functions and overloads of aggregate type $(D T). */
template GetAllFunctions(T)
    if (isAggregate!T && !isNested!T)
{
    template GetAllFunctionsImpl(T, Members...)
    {
        static if (Members.length > 1)
        {
            alias GetAllFunctionsImpl =
            TypeTuple!(
                GetAllFunctionsImpl!(T, Members[0]),
                GetAllFunctionsImpl!(T, Members[1 .. $]),
            );
        }
        else
        {
            alias GetAllFunctionsImpl = GetOverloads!(T, Members[0]);
        }
    }

    alias GetAllFunctions = GetAllFunctionsImpl!(T, GetAllMembers!T);
}

///
unittest
{
    static struct S
    {
        @property void a(int) { }
        @property int a() { return 0; }

        void b() { }

        int c;

        void d() { }
        void d(int) { }
    }

    static assert(GetAllFunctions!(S).length == 5);
}

/** Check whether function $(D F) is a @property function. */
template isPropertyFunction(alias F)
{
    enum bool isPropertyFunction = (functionAttributes!F & FunctionAttribute.property) != 0;
}

///
unittest
{
    static struct S1
    {
        @property void a(int) { }
        @property int a() { return 0; }
    }

    foreach (Func; GetAllFunctions!S1)
        static assert(isPropertyFunction!Func);

    static struct S2
    {
        void a(int) { }
        int a() { return 0; }
    }

    foreach (Func; GetAllFunctions!S2)
        static assert(!isPropertyFunction!Func);

    static struct S3
    {
        @property void a(int) { }
        int a() { return 0; }
    }

    foreach (idx, Func; GetAllFunctions!S3)
    {
        static if (idx == 0)
            static assert(isPropertyFunction!Func);
        else
            static assert(!isPropertyFunction!Func);
    }
}

/** Return all @property functions of aggregate type $(D T). */
template GetAllProperties(T)
    if (isAggregate!T)
{
    alias GetAllProperties = Filter!(isPropertyFunction, GetAllFunctions!T);
}

///
unittest
{
    static struct S
    {
        @property void a(int) { }

        void b() { }

        @property int a() { return 0; }

        void a(float x) { }
    }

    static assert(GetAllProperties!S.length == 2);
}

/** Check whether member function $(D F) is a @property setter function. */
template isPropertyGetter(alias F)
{
    // @bug: default parameters should be ignored
    enum isPropertyGetter = ParameterTypeTuple!(F).length == 0 && !is(ReturnType!F == void);
}

///
unittest
{
    int x;

    static struct S
    {
        @property void a(int) { }
        @property void b() { }
        @property int c() { return 0; }
        void d() { }
    }

    static assert(!isPropertyGetter!(GetMember!(S, "a")));
    static assert(!isPropertyGetter!(GetMember!(S, "b")));
    static assert(isPropertyGetter!(GetMember!(S, "c")));
    static assert(!isPropertyGetter!(GetMember!(S, "d")));
}

/** Check whether member function $(D F) is a @property setter function. */
template isPropertySetter(alias F)
{
    // @bug: default parameters should be ignored
    enum isPropertySetter = ParameterTypeTuple!(F).length == 1;
}

///
unittest
{
    int x;

    static struct S
    {
        @property void a(int) { }  // setter
        @property int b() { return 0; }
        @property void c(int, float) { }  // not a setter, too many parameters
        void d() { }
    }

    static assert(isPropertySetter!(GetMember!(S, "a")));
    static assert(!isPropertySetter!(GetMember!(S, "b")));
    static assert(!isPropertySetter!(GetMember!(S, "c")));
    static assert(!isPropertySetter!(GetMember!(S, "d")));
}

/** Return all @property getters for aggregate type $(D T). */
template GetAllPropertyGetters(T)
    if (isAggregate!T)
{
    alias GetAllPropertyGetters = Filter!(isPropertyGetter, GetAllProperties!T);
}

///
unittest
{
    int x;

    static struct S
    {
        @property void a() { }
        @property void a(int) { }
        @property void b(float) { }
        @property void c(char[]) { }
        @property void b() { }

        @property int d() { return 0; }  // getter
        @property int[] e() { return null; }  // getter
        @property int f() { return 0; }  // getter

        void d() { }
    }

    static assert(GetAllPropertyGetters!S.length == 3);
}

/** Return all @property setters for aggregate type $(D T). */
template GetAllPropertySetters(T)
    if (isAggregate!T)
{
    alias GetAllPropertySetters = Filter!(isPropertySetter, GetAllProperties!T);
}

///
unittest
{
    int x;

    static struct S
    {
        @property void a(int) { }  // setter
        @property void b(float) { }  // setter
        @property void c(char[]) { }  // setter
        @property void b() { }
        @property int c() { return 0; }
        void d() { }
    }

    static assert(GetAllPropertySetters!S.length == 3);
}

/** Return the string identifier of symbol $(D S). */
template Identifier(S...) if (S.length == 1)
{
    enum Identifier = __traits(identifier, S[0]);
}

///
unittest
{
    int x;
    static struct S { }

    static assert(Identifier!x == "x");
    static assert(Identifier!S == "S");
}

/**
    Check whether $(D F) is a static function,
    meaning it has no context pointer.
*/
template isStaticFunction(alias F) if (isSomeFunction!F)
{
    enum bool isStaticFunction = __traits(isStaticFunction, F);
}

///
unittest
{
    struct S
    {
        static void foo() { }
        void bar() { }
    }

    static void foo() { }
    int x;
    void bar() { x++; }

    static assert(!__traits(compiles, isStaticFunction!S));
    static assert(isStaticFunction!(S.foo));
    static assert(!isStaticFunction!(S.bar));
    static assert(isStaticFunction!(foo));
    static assert(!isStaticFunction!(bar));
}

/** Get the base enum type. Similar to OriginalType. */
template EnumBaseType(E) if (is(E == enum))
{
    static if (is(E B == enum))
        alias EnumBaseType = B;
}

unittest
{
    enum EI : int { x = 0 }
    enum EF : float { x = 1.5 }

    static assert(is(EnumBaseType!EI == int));
    static assert(is(EnumBaseType!EF == float));
}
