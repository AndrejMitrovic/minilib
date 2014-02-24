/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.set;

import std.algorithm;
import std.array;
import std.range;
import std.string;

import minilib.core.attributes;
import minilib.core.range;
import minilib.core.string;
import minilib.core.test;
import minilib.core.traits;
import minilib.core.util;

/// Attribute that marks the Minilib Set type.
private struct MinilibSet { }

/** Check if $(D T) is a Minilib Set type. */
template isMinilibSet(T)
{
    static if (isAggregate!T)
        enum isMinilibSet = canFindAttributeType!(MinilibSet, T);
    else
        enum isMinilibSet = false;
}

///
unittest
{
    auto set = Set!int(1);
    static assert(isMinilibSet!(typeof(set)));
    static assert(!isMinilibSet!int);
}

/**
    Set type based on built-in hashes.
*/
@(MinilibSet)
struct Set(E)
{
    /** The element type of the Set. */
    alias ElementType = E;

    /** Construct a Set with the given element. */
    this(E elem)
    {
        this.add(elem);
    }

    /** Construct a Set with the given elements. */
    this(E[] elems...)
    {
        this.add(elems);
    }

    /** Add element to Set. */
    void add(E elem)
    {
        static if (hasEmpty!E)
            if (elem.empty)
                return;

        payload[elem] = [];
    }

    /** Add elements to Set. */
    void add(E[] elems...)
    {
        foreach (elem; elems)
        {
            static if (hasEmpty!E)
                if (elem.empty)
                    continue;

            payload[elem] = [];
        }
    }

    /// ditto
    alias put = add;

    /** Remove element from Set. */
    void rem(E elem)
    {
        payload.remove(elem);
    }

    /** Remove elements from Set. */
    void rem(E[] elems...)
    {
        foreach (elem; elems)
            payload.remove(elem);
    }

    /// ditto
    alias remove = rem;

    /** Merge elements of another Set to this Set. */
    void merge(Set rhs)
    {
        foreach (elem; rhs)
            add(elem);
    }

    /** Iterate through the elements. */
    int opApply(scope int delegate(E) dg)
    {
        foreach (elem; payload.byKey())
        {
            auto result = dg(elem);
            if (result)
                return result;
        }

        return 0;
    }

    /** Return true if elem in Set. */
    bool opIn_r(E elem) inout
    {
        return cast(bool)(elem in payload);
    }

    /** String representation of Set. */
    string toString() const
    {
        return fmt("Set!%s(%(%s, %))", E.stringof, sortedElements());
    }

    /** Return a range of all the elements. */
    auto ref range() inout { return payload.byKey(); }

    /** Return all elements as an array. */
    @property E[] elements() inout { return payload.keys; }

    /** Return all elements as a sorted array. */
    E[] sortedElements() inout
    {
        E[] elems = elements();
        sort(elems);
        return elems;
    }

    /** Return true if no elements in Set. */
    @property empty() inout { return !payload.length; }

    /** Return number of elements in Set. */
    @property size_t length() inout { return payload.length; }

    /** Rehash the Set for faster lookups. */
    void rehash() { payload.rehash(); }

    /** Return true if this is equal to another Set. */
    bool opEquals()(auto ref const Set rhs) inout
    {
        if (this.length != rhs.length)
            return false;

        foreach (elems; zip(this.range(), rhs.range()))
        {
            if (elems[0] != elems[1])
                return false;
        }

        return true;
    }

private:
    /** void[0] should avoid allocating values. */
    void[0][E] payload;
}

///
unittest
{
    auto oneSet = Set!int(1);
    assert(1 in oneSet);
    static assert(is(oneSet.ElementType == int));

    auto twoSet = Set!int(1, 2);
    assert(1 in twoSet && 2 in twoSet);

    assert(twoSet.range.walkLength == 2);

    Set!int si;

    si.add(1);
    si.add(2);
    si.add(3);
    assert(1 in si && 2 in si && 3 in si);

    si.rem(2);
    assert(1 in si && 2 !in si && 3 in si);

    si.add(2);
    assert(si.sortedElements() == [1, 2, 3]);
    assert(si.toString() == "Set!int(1, 2, 3)");

    Set!int sb;
    sb.add(4);
    si.merge(sb);
    si.add(5, 6);
    assert(1 in si && 2 in si && 3 in si && 4 in si && 5 in si && 6 in si);

    assert(!si.empty);
    si.remove(1, 2, 3, 4, 5, 6);
    assert(si.empty);

    si.add(1, 2, 3);
    size_t idx;
    foreach (el; si)
        idx++;
    assert(idx == 3);

    // no ref access
    static assert(!__traits(compiles, {
        foreach (ref el; si)
            el++;
    } ));

    Set!int sn;
    sn.add(1, 2, 3);
    assert(si == sn);

    Set!int sn2;
    Set!int sn3;
    sn2.add(1, 2, 3, 4);
    sn3.add(1, 2, 5);
    assert(si != sn2);
    assert(si != sn3);

    si.rehash();
}

/+ enum E { a, b }

struct GeneralConfig
{
    @property Set!E machine_formats()
    {
        return typeof(return).init;
    }
}

unittest
{
    GeneralConfig s;
    import std.string;
    auto str = format("%s", s);
} +/
