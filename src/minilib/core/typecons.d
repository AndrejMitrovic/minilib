/*
 *             Copyright Andrej Mitrovic 2013.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.typecons;

import core.atomic;
import core.thread;

import std.array;
import std.concurrency;
import std.conv;
import std.exception;
import std.stdio;
import std.string;
import std.traits;
import std.typecons;
import std.typetuple;

import minilib.core.platform;
import minilib.core.string;

/** Static class. */
T Cast(T, S)(S source)
{
    return cast(T)(*cast(void**)&source);
}

///
unittest
{
    class A { int x; }
    class B : A { int y; this(int y) { this.y = y; } }
    A a = new B(1);
    B b = Cast!B(a);
    assert(b.y == 1);
}

/** Create a custom Exception type. */
template NewException(string name)
{
    import minilib.core.string : fmt;

    mixin(fmt(q{
        static class %s : Exception
        {
            @safe pure nothrow this(string msg = "", string file = __FILE__, size_t line = __LINE__, Throwable next = null)
            {
                super(msg, file, line, next);
            }

            @safe pure nothrow this(string msg, Throwable next, string file = __FILE__, size_t line = __LINE__)
            {
                super(msg, file, line, next);
            }
        }
    }, name));
}

///
unittest
{
    mixin NewException!"MyEx";
    static void foo() { throw new MyEx(""); }
    assertThrown!MyEx(foo());
}

/**
    Constructs a tuple from the given variables, where each variable in the
    tuple is accessible through its original variable name as named members
    of the tuple. Members can still be accessed by indexing.
*/
auto tuple(syms...)()
{
    return Tuple!(NameTypePairs!syms)(syms);
}

///
unittest
{
    auto func()
    {
        int x = 1;
        string y = "2";
        auto square = (int a) => a * a;

        // simple and concise syntax
        return tuple!(x, y, square);
    }

    auto tup = func();

    // symbol names accessible from the call site
    assert(tup.x == 1);
    assert(tup.y == "2");
    assert(tup.square(2) == 4);
}

private template NameTypePairs(alias front, syms...)
{
    enum name = __traits(identifier, front);
    alias pair = TypeTuple!(typeof(front), name);

    static if (syms.length == 0)
        alias NameTypePairs = pair;
    else
        alias NameTypePairs = TypeTuple!(pair, NameTypePairs!syms);
}

/**
    Singleton pattern implemented via a simple synchronized block.
    This is comparatively the slowest thread-safe singleton implementation.
*/
class LockSingleton(C) if (is(C == class))
{
    static C get()
    {
        __gshared C _instance;

        synchronized
        {
            if (_instance is null)
                _instance = new C();
        }

        return _instance;
    }

private:
    this() { }
}

/**
    Singleton pattern implemented via thread-local initialization checks.

    Only when a new thread attemts to retrieve the singleton for the very
    first time will a synchronized block be entered. Subsequent reads
    by the same thread will not enter the synchronized block, but will
    instead check a thread-local initialization flag.

    Note that each newly spawned thread will have to enter the synchronized
    block on the very first read.

    See the more elaborate description here: http://forum.dlang.org/thread/mailman.158.1391156715.13884.digitalmars-d@puremagic.com?page=2#post-mailman.162.1391165871.13884.digitalmars-d:40puremagic.com

    This is comparatively one of the fastest thread-safe singleton implementations.
*/
class SyncSingleton(C) if (is(C == class))
{
    static C get()
    {
        static bool _instantiated;  // tls
        __gshared C _instance;

        if (!_instantiated)
        {
            synchronized
            {
                if (_instance is null)
                    _instance = new C();

                _instantiated = true;
            }
        }

        return _instance;
    }

private:
    this() { }
}

/**
    Singleton pattern implemented via atomic operations on a global
    initialization flag.

    Each thread on every read will attempt to atomically read the
    global initialization flag, and only if it is false a synchronized
    block will be entered.

    See the more elaborate description here: http://forum.dlang.org/thread/mailman.158.1391156715.13884.digitalmars-d@puremagic.com?page=2#post-mailman.162.1391165871.13884.digitalmars-d:40puremagic.com

    This is comparatively one of the fastest thread-safe singleton implementations.
    However, atomic operations might be slower than TLS read operations which
    SyncSingleton uses based on the hardware, the OS, and the optimizer being used.
*/
class AtomicSingleton(C) if (is(C == class))
{
    static C get()
    {
        shared static bool _instantiated = false;
        __gshared C _instance;

        // only enter synchronized block if not instantiated
        if (!atomicLoad!(MemoryOrder.acq)(_instantiated))
        {
            synchronized
            {
                if (_instance is null)
                    _instance = new C();

                atomicStore!(MemoryOrder.rel)(_instantiated, true);
            }
        }

        return _instance;
    }
}

version (all)  /// make sure semantic checks are run when not benchmarking
{
    import std.typetuple;
    static class _SC { }
    alias _SingletonChecks = TypeTuple!(LockSingleton!_SC, SyncSingleton!_SC, AtomicSingleton!_SC);
}

/// note: enable when benchmarking
// version = BenchmarkSingletons;

version (BenchmarkSingletons)
{
    ulong _thread_call_count;  // TLS
}

version (BenchmarkSingletons)
unittest
{
    import std.array;
    import std.datetime;
    import std.stdio;
    import std.string;
    import std.typetuple;
    import std.exception;
    import core.atomic;

    static class C { }

    foreach (TestSingleton; TypeTuple!(LockSingleton, SyncSingleton, AtomicSingleton))
    {
        enum SingletonName = __traits(identifier, TestSingleton);

        // mixin to avoid multiple definition errors
        mixin(q{

        shared ulong msecs = 0;
        static void test_%1$s(shared ulong* counter)
        {
            auto sw = StopWatch(AutoStart.yes);
            foreach (i; 0 .. 1024_000)
            {
                // just trying to avoid the compiler from doing dead-code optimization
                _thread_call_count += enforce(TestSingleton!C.get() !is null);
            }
            sw.stop();
            atomicOp!"+="(*counter, sw.peek.msecs);
        }

        enum threadCount = 4;
        foreach (i; 0 .. threadCount)
            spawn(&test_%1$s, &msecs);
        thread_joinAll();

        }.format(SingletonName));

        writefln("Test time for %s: %s msecs.", SingletonName, cast(double)msecs / threadCount);
    }
}
