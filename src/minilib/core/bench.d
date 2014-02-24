/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.bench;

import std.conv;
import std.datetime;
import std.functional;
import std.range;
import std.stdio;
import std.string;

import minilib.core.string;

/**
    Benchmark which outputs timing results when it goes out of scope.
    The output can be set to a function or delegate that is an output range.
*/
struct Bench
{
    StopWatch sw;
    string file;
    size_t line;

    /** Output is an output range delegate. */
    alias SinkF = void function(const(char)[]);
    alias Sink = void delegate(const(char)[]);
    Sink sink;

    static Bench opCall(Sink sink = toDelegate(&stderrSink), string file = __FILE__, size_t line = __LINE__)
    {
        return Bench(sink, file, line);
    }

    static Bench opCall(SinkF sink = &stderrSink, string file = __FILE__, size_t line = __LINE__)
    {
        return Bench(toDelegate(sink), file, line);
    }

    this(Sink sink = toDelegate(&stderrSink), string file = __FILE__, size_t line = __LINE__)
    {
        this.file = file;
        this.line = line;
        this.sink = sink;
        sw = StopWatch(AutoStart.yes);
    }

    this(SinkF sink = &stderrSink, string file = __FILE__, size_t line = __LINE__)
    {
        this(toDelegate(sink), file, line);
    }

    ~this()
    {
        sw.stop();
        sink.put(format("%s(%s): Benchmark time: %s.", file, line, getTimeString()));
    }

    private string getTimeString()
    {
        TickDuration time = sw.peek();

        long secs = time.seconds;
        long msecs = time.msecs - (1000 * secs);
        long usecs = time.usecs - (1000 * msecs) - (1000 * 1000 * secs);

        return format("%s secs, %s msecs, %s usecs", secs, msecs, usecs);
    }

    /** Default output */
    private static void stderrSink(const(char)[] input)
    {
        stderr.writeln(input);
    }
}

unittest
{
    static void sink(const(char)[] input)
    {
        // writeln(input);
    }

    void dgSink(const(char)[] input)
    {
        // writeln(input);
    }

    auto a = Bench(&sink);
    auto b = Bench(&dgSink);
}
