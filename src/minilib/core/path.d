/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.path;

import std.array;

/** Return a win32-native path, replacing forward slashes with backslashes. */
string toWinPath(string input)
{
    return input.replace("/", r"\");
}

///
unittest
{
    assert(r"foo/bar\doo".toWinPath == r"foo\bar\doo");
}

/** Return a posix-native path, replacing back slashes with forward slashes. */
string toPosixPath(string input)
{
    return input.replace(r"\", "/");
}

///
unittest
{
    assert(r"foo/bar\doo".toPosixPath == r"foo/bar/doo");
}
