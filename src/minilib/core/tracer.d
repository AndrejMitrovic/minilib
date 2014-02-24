/*
 *             Copyright Andrej Mitrovic 2014.
 *  Distributed under the Boost Software License, Version 1.0.
 *     (See accompanying file LICENSE_1_0.txt or copy at
 *           http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.core.tracer;

/**
    Use this functionality for better stack traces, which will output traces as:

    ----------------
    C:\dev\projects\dport\src\dport\parser.d(31): Error:
        void dport.parser.messageFunction(immutable(char)[], uint, uint, immutable(char)[], bool)

    C:\dev\projects\dport\lib\Dscanner\stdx\d\parser.d(6313): Error:
        void stdx.d.parser.Parser.error(lazy immutable(char)[], bool)
    ----------------

    The syntax of the output is typically:

    -----
    <FilePath><LastLine>: Error:
        <(Optional) Aggregate Name><Function Name>
    -----

    This output allows jump-to-definition to work in most editors output panes (e.g. Scite).
    $(B Note:) Currently only the Windows tracer implements a better stack-trace output,
    other systems use druntime's default tracer.

    Use via:
    -----
    import core.runtime;
    import minilib.core.tracer;
    Runtime.traceHandler = &traceHandler;
    -----

    $(B Note:) You must call $(D Runtime.traceHandler = &traceHandler;) in your main() function,
    not in a module constructor as the druntime's module ctor might be called after your provided
    module ctor, overwriting your trace handler with its own (this might be a druntime bug compared
    to how overwriting the unittester function works => todo: investigate later).
*/

version (Windows) import core.stdc.wchar_ : wchar_t;

/// C interface for Runtime.loadLibrary
extern (C) void* rt_loadLibrary(const char* name);
/// ditto
version (Windows) extern (C) void* rt_loadLibraryW(const wchar_t* name);
/// C interface for Runtime.unloadLibrary, returns 1/0 instead of bool
extern (C) int rt_unloadLibrary(void* ptr);

/// C interface for Runtime.initialize, returns 1/0 instead of bool
extern(C) int rt_init();
/// C interface for Runtime.terminate, returns 1/0 instead of bool
extern(C) int rt_term();

private
{
    alias bool function() ModuleUnitTester;
    alias bool function(Object) CollectHandler;
    alias Throwable.TraceInfo function( void* ptr ) TraceHandler;

    extern (C) void rt_setCollectHandler( CollectHandler h );
    extern (C) CollectHandler rt_getCollectHandler();

    extern (C) void rt_setTraceHandler( TraceHandler h );
    extern (C) TraceHandler rt_getTraceHandler();

    alias void delegate( Throwable ) ExceptionHandler;

    extern (C) void* thread_stackBottom();

    // backtrace
    version( linux )
        import core.sys.linux.execinfo;
    else version( OSX )
        import core.sys.osx.execinfo;
    else version( FreeBSD )
        import core.sys.freebsd.execinfo;
    else version( Windows )
        import core.sys.windows.stacktrace;

    // For runModuleUnitTests error reporting.
    version( Windows )
    {
        import core.sys.windows.windows;
    }
    else version( Posix )
    {
        import core.sys.posix.unistd;
    }
}

version (Windows)
    enum IsWindows = true;
else
    enum IsWindows = false;

static if (!IsWindows)
{
    import core.runtime;
    alias traceHandler = defaultTraceHandler;
}
else:

import minilib.platform.windows.tracer;

import core.stdc.stdio;
Throwable.TraceInfo traceHandler( void* ptr = null )
{
    version (Win64)
    {
        static enum FIRSTFRAME = 4;
    }
    else
    {
        static enum FIRSTFRAME = 0;
    }

    auto s = new MyStackTrace(FIRSTFRAME, cast(CONTEXT*)ptr);
    return s;
}
