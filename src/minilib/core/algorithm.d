/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.algorithm;

import std.array;
import std.conv;
import std.algorithm;
import std.range;
import std.string;
import std.traits;
import std.typetuple;

/**
    Philippe Sigaud's Permutations from dranges.
    See https://github.com/PhilippeSigaud/dranges
    and http://www.dsource.org/projects/dranges.
*/
struct Permutations(R)
{
    ElementType!R[] _input, _perm;
    size_t k, n;

    this(R r)
    {
        _input = array(r);
        _perm = array(r);
        n = _perm.length;
        k = n;
    }

    this(R r, size_t elems)
    {
        _input = array(r);
        _perm = array(r);
        n = min(elems, _perm.length);
        k = n;
    }

    ElementType!R[] front() { return _perm;}

    bool empty() { return (n == 1 && k == 0 )|| (n > 1 && k <= 1); }

    @property Permutations save() { return this; }

    void popFront()
    {
        k = n;
        if (k == 0)
        {
            n = 1; // permutation of an empty range or of zero elements
        }
        else
        {
            C3: _perm = _perm[1 .. k] ~ _perm[0] ~ _perm[k .. $];
            if (_perm[k - 1] == _input[k - 1])
            {
                k--;
                if (k > 1) goto C3;
            }
        }
    }
}

/// ditto
Permutations!R permutations(R)(R r) if (isDynamicArray!R)
{
    return Permutations!R(r);
}

/// ditto
Permutations!R permutations(R)(R r, size_t n) if (isDynamicArray!R)
{
    return Permutations!R(r, n);
}

/// ditto
Permutations!(ElementType!R[]) permutations(R)(R r)
    if (!isDynamicArray!R && isForwardRange!R && !isInfinite!R)
{
    return Permutations!(ElementType!R[])(array(r));
}

/// ditto
Permutations!(ElementType!R[]) permutations(R)(R r, size_t n)
    if (!isDynamicArray!R && isForwardRange!R && !isInfinite!R)
{
    return Permutations!(ElementType!R[])(array(r), n);
}

unittest
{
    alias splitter = std.algorithm.splitter;

    /** Workaround for Phobos 'equal' issues. */
    assert(to!(string[])(array(permutations("abc")))
           == ["abc", "bca", "cab", "bac", "acb", "cba"]);

    assert(array(permutations(splitter("foo bar", (' '))))
           == [["foo", "bar"], ["bar", "foo"]]);
}

/** Return range joined by space. */
string spaceJoin(Range)(Range input)
{
    return input.join(" ");
}

unittest
{
    assert(["foo"].spaceJoin() == "foo");
    assert(["foo", "bar"].spaceJoin() == "foo bar");
    assert(["foo", "bar", "doo"].spaceJoin() == "foo bar doo");
}

/** Return a range of all permutations of input. */
@property auto combs(string input)
{
    return map!(spaceJoin)(permutations(input.splitter(' ')));
}

unittest
{
    assert("foo bar".combs.equal(["foo bar", "bar foo"]));
    auto comb = "a b c".combs;
    foreach (c; ["a b c", "b c a", "c a b", "b a c", "a c b", "c b a"])
        assert(comb.canFind(c));
}

/** map alternative which takes multiple ranges. */
auto multimap(alias func, Ranges...)(Ranges ranges)
    if (allSatisfy!(isInputRange, Ranges))
{
    static struct MyMap
    {
        Ranges ranges;

        @property bool empty()
        {
            foreach (ref range; ranges)
                if (range.empty)
                    return true;

            return false;
        }

        @property auto front()
        {
            static string getMixin()
            {
                string[] args;
                foreach (idx; 0 .. Ranges.length)
                    args ~= format("ranges[%s].front", idx);
                return args.join(", ");
            }

            mixin(format(q{
                return func(%s);
            }, getMixin()));
        }

        void popFront()
        {
            foreach (ref range; ranges)
                range.popFront();
        }
    }

    return MyMap(ranges);
}

///
unittest
{
    auto r = multimap!((a, b) => [a : b])([1, 3], [2, 4]);
    assert(r.front == [1 : 2]);
    r.popFront();
    assert(r.front == [3 : 4]);
    r.popFront();
    assert(r.empty);
}

/+ /**
    Return input for index 0 up to but not including target.
    If target not found return input.
*/
string keepUntil(string input, string target)
{
    string result;

    auto idx = input.countUntil(target);

    if (idx == -1)
        result = input;
    else
        result = input[0 .. idx];

    return result;
}

/// todo
unittest
{
} +/

bool matchAny(T1, T2)(T1 target, T2[] inputs...)
    if (is(typeof(inputs[0] == target) == bool))
{
    foreach (input; inputs)
    {
        if (input == target)
            return true;
    }

    return false;
}

/// todo
unittest
{
}
