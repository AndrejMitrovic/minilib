/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.range;

import core.exception;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.range;

/** Separator range. */
struct MyJoiner(R, E)
{
    R range;
    E sep;

    ///
    @property bool empty() { return range.empty; }

    ///
    @property E front()
    {
        if (useSep)
            return sep;
        else
            return range.front;
    }

    ///
    void popFront()
    {
        if (!useSep)
            range.popFront();

        useSep ^= 1;
    }

    private bool useSep;
}

/**
    Lazily join a range with a separator. Unlike std.range.joiner
    the separator can be a non-range element.
*/
auto myJoiner(R, E)(R range, E sep)
    if (is(E == ElementEncodingType!R))
{
    return MyJoiner!(R, E)(range, sep);
}

unittest
{
    struct S { int x; }
    S[] arr = [S(2), S(4), S(6)];
    S e = S(0);
    auto range = arr.myJoiner(e);
    assert(equal(range, [S(2), S(0), S(4), S(0), S(6)]));
}

/**
Returns $(D true) if $(D R) has an $(D empty) member that returns a
boolean type. $(D R) does not have to be a range.
 */
template hasEmpty(R)
{
    enum bool hasEmpty = is(typeof(
    (inout int = 0)
    {
        R r = void;
        static assert(is(typeof(r.empty) : bool)
                   || is(typeof(r.empty()) : bool));
    }));
}

unittest
{
    static assert(hasEmpty!(char[]));
    static assert(hasEmpty!(int[]));
    static assert(hasEmpty!(inout(int)[]));

    struct A { bool empty; }
    struct B { bool empty() { return 0; } }
    struct C { @property bool empty() { return false; } }
    struct D { @property int empty() { return 0; } }
    static assert(hasEmpty!A);
    static assert(hasEmpty!B);
    static assert(hasEmpty!C);
    static assert(!hasEmpty!D);
}

/**
    Return the Base range type.

    Unlike ElementType in std.range this returns
    the type of .front which returns a non-range.
*/
template BaseRangeType(R)
    if (isInputRange!R)
{
    static if (is(typeof((inout int = 0){ R r = void; return r.front; }()) T))
    {
        static if (isInputRange!T)
            alias BaseRangeType = .BaseRangeType!T;
        else
            alias BaseRangeType = T;
    }
    else static assert(0);
}

///
unittest
{
    static struct Range1
    {
        int[][] front();
        void popFront();
        bool empty;
    }

    static struct Range2
    {
        Range1 front();
        void popFront();
        bool empty;
    }

    static assert(is(BaseRangeType!Range1 == int));
    static assert(is(BaseRangeType!Range2 == int));
}

/** Implements index variable for iterating through input ranges. */
struct Iterate(Range)
    if (isInputRange!Range)
{
    this(Range range)
    {
        this.range = range;
    }

    alias Item = ElementType!Range;

    /// foreach with index
    int opApply(int delegate(size_t index, ref Item) dg)
    {
        int result = 0;

        size_t index;
        foreach (item; range)
        {
            result = dg(index++, item);
            if (result)
                break;
        }

        return result;
    }

    /// foreach without index
    int opApply(int delegate(ref Item) dg)
    {
        int result = 0;

        foreach (item; range)
        {
            result = dg(item);
            if (result)
                break;
        }

        return result;
    }

private:
    Range range;
}

/**
    Return a struct instance that wraps an
    input range and provides an index variable.
*/
auto iterate(Range)(Range range)
    if (isInputRange!Range)
{
    return Iterate!Range(range);
}

/// ditto
public alias walk = iterate;

///
unittest
{
    static class Widget { this() { } this(int x) { this.x = x; } Widget next; int x; }

    // custom range
    static struct Range
    {
        Widget widget;

        @property bool empty()   { return widget is null; }
        @property Widget front() { return widget; }
        void popFront() { widget = widget.next; }
    }

    // helper
    static auto range(Widget widget)
    {
        return Range(widget);
    }

    auto widget = new Widget(0);
    widget.next = new Widget(1);
    widget.next.next = new Widget(2);

    foreach (i, item; iterate(range(widget)))
    {
        assert(item.x == i);
    }

    size_t index;
    foreach (item; iterate(range(widget)))
    {
        assert(item.x == index++);
    }
}

/**
    Take the element of range at this index.
    Return the last item if index is out of range.
    If range is empty, throw an exception.
*/
auto takeIndex(Range)(Range range, size_t index)
{
    size_t idx;

    while (!range.empty)
    {
        auto item = range.front;
        range.popFront();

        if (range.empty || idx++ == index)
            return item;
    }

    RangeError error = new RangeError();
    error.msg = "Cannot call takeIndex on an empty range.";
    throw error;
}

///
unittest
{
    static class Widget
    {
        this(int x)
        {
            this.x = x;
        }

        override string toString()
        {
            return x.text;
        }

        Widget next;
        int x;
    }

    // custom range
    static struct Range
    {
        Widget widget;

        @property bool empty()   { return widget is null; }
        @property Widget front() { return widget; }
        void popFront() { widget = widget.next; }
    }

    // helper
    static auto range(Widget widget)
    {
        return Range(widget);
    }

    auto widget = new Widget(0);
    widget.next = new Widget(1);
    widget.next.next = new Widget(2);

    assert(range(widget).takeIndex(0) is widget);
    assert(range(widget).takeIndex(1) is widget.next);
    assert(range(widget).takeIndex(2) is widget.next.next);
    assert(range(widget).takeIndex(3) is widget.next.next);  // out of bounds, return last

    auto emptyRange = range(widget).drop(3);
    assertThrown!RangeError(emptyRange.takeIndex(0) is widget);
}

/**
    A wrapper around a single value which acts as a range with length 1.

    This is useful in cases where a function demans an input range even
    if that range might consist of only one element.
*/
struct ElementRange(T)
{
    T value;

    @property T front() { return value; }
    @property void popFront() { _isEmpty = true; }
    @property bool empty() { return _isEmpty; }

private:
    bool _isEmpty = false;
}

/** Return an $(D ElementRange) of a value. */
ElementRange!T elementRange(T)(T value)
{
    return typeof(return)(value);
}

///
unittest
{
    auto range = elementRange(1);
    static assert(isInputRange!(typeof(range)));

    assert(range.front == 1);
    assert(!range.empty);
    range.popFront();
    assert(range.empty);
}
