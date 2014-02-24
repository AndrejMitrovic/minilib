/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.array;

import core.stdc.string;
import std.algorithm;
import std.array;
import std.range;

/** Return a new sorted array. */
T[] sorted(T)(T[] array)
{
    T[] result = array.dup;
    sort(result);
    return result;
}

///
unittest
{
    int[] a = [1, 3, 2];
    auto b = a.sorted();
    assert(a == [1, 3, 2]);
    assert(b == [1, 2, 3]);
}

/** Return true if target class object is in array. */
bool canFind(T)(T[] array, T target)
    if (is(T == class))
{
    return indexOf(array, target) != -1;
}

///
unittest
{
    static class C { }
    auto c = new C;
    auto arr = [new C, c, new C];
    assert(arr.canFind(c));
    assert(!arr.canFind(new C));
}

/** Return index of target class object in array, or -1 if not found. */
sizediff_t indexOf(T)(T[] array, T target)
    if (is(T == class))
{
    foreach (idx, elem; array)
    {
        if (elem is target)
            return idx;
    }

    return -1;
}

///
unittest
{
    static class C { }
    auto c = new C;
    auto arr = [new C, c, new C];
    assert(arr.indexOf(c) == 1);
    assert(arr.indexOf(new C) == -1);
}

/**
    Drop element at index from array and update array length.
    Note: This is extremely unsafe, it assumes there are no
    other pointers to the internal slice memory.
*/
void dropIndex(T)(ref T[] arr, size_t index)
{
    assert(index < arr.length);
    immutable newLen = arr.length - 1;

    if (index != newLen)
        memmove(&(arr[index]), &(arr[index + 1]), T.sizeof * (newLen - index));

    arr.length = newLen;
}

///
unittest
{
    int[] arr = [1, 2, 3];
    arr.dropIndex(1);
    assert(arr == [1, 3]);
}

/** Remove target item from array. Note: unsafe, see dropIndex. */
void remove(T)(ref T[] arr, T target)
{
    sizediff_t idx = arr.countUntil(target);
    if (idx != -1)
        arr.dropIndex(idx);
}

///
unittest
{
    int[] arr = [1, 2, 3];
    arr.remove(2);
    assert(arr == [1, 3]);
}

/** Return the memory size needed to store the elements of the array. */
size_t memSizeOf(E)(E[] arr)
{
    return E.sizeof * arr.length;
}

///
unittest
{
    int[] arrInt = [1, 2, 3, 4];
    assert(arrInt.memSizeOf == 4 * int.sizeof);

    long[] arrLong = [1, 2, 3, 4];
    assert(arrLong.memSizeOf == 4 * long.sizeof);
}
