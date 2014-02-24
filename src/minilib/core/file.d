/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.file;

import std.algorithm;
import std.array;
import std.conv;
import std.exception;
import std.file;
import std.path;
import std.range;
import std.traits;
import std.stdio;
import std.string;

import minilib.core.range;
import minilib.core.set;
import minilib.core.string;

/** Read entire file into memory and return the contents as a string. */
string readFileText(string filename)
{
    assert(filename.exists, fmt("File does not exist: %s\n", filename));
    return cast(string)std.file.read(filename);
}

/** Read entire file into memory and return the contents as a ubyte array. */
ubyte[] readFileBytes(string filename)
{
    assert(filename.exists, fmt("File does not exist: %s\n", filename));

    auto file = File(filename, "r");
	auto buffer = uninitializedArray!(ubyte[])(to!size_t(file.size));
	file.rawRead(buffer);
	return buffer;
}

/** A set of better names for SpanMode. */
struct SearchMode
{
    SpanMode mode;
    alias mode this;

    /// Search files in depth-first order
    enum deep = SearchMode(SpanMode.depth);

    /// Search files in breadth-first order
    enum wide = SearchMode(SpanMode.breadth);

    /// Search files only in the current directory
    enum flat = SearchMode(SpanMode.shallow);
}

///
unittest
{
    static assert(__traits(compiles,
        {
            SearchMode mode = SearchMode.flat;
            foreach (file; dirEntries(".", mode)) { }
        }()
    ));
}

/**
    Return an array of files in the path $(B root) if
    they have one of the $(B extensions), using the
    $(B searchMode) search pattern.

    $(B extensions) must be a single string or an input range of strings.
*/
string[] fileList(Range)(string root, Range extensions, SearchMode searchMode)
    if (!isSomeString!Range &&
        isInputRange!Range && isSomeString!(ElementType!(Range)))
{
    Appender!(string[]) result;

    enforce(root.exists, format("Root '%s' does not exist.", root));

    foreach (string entry; dirEntries(root, searchMode))
    {
        if (entry.isFile && extensions.canFind(entry.extension))
            result ~= entry;
    }

    return result.data;
}

/// ditto
string[] fileList()(string root, string extension, SearchMode searchMode)
{
    return fileList(root, elementRange(extension), searchMode);
}

///
unittest
{
    static assert(__traits(compiles,
    {
        fileList(".", ".d", SearchMode.deep);

        fileList(".", [".d", ".txt"], SearchMode.deep);

        fileList(".", Set!string(".d").range, SearchMode.deep);
    }()));
}
