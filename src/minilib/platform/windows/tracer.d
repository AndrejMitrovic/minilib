/**
 * ...
 *
 * Copyright: Copyright Benjamin Thaut 2010 - 2013.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Benjamin Thaut, Sean Kelly
 * Source:    $(DRUNTIMESRC core/sys/windows/_stacktrace.d)
 */

/*          Copyright Benjamin Thaut 2010 - 2012.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module minilib.platform.windows.tracer;

version(Windows):

import core.demangle;
import core.runtime;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.windows.dbghelp;
import core.sys.windows.windows;

import std.stdio;

//debug=PRINTF;
debug(PRINTF) import core.stdc.stdio;


extern(Windows) void RtlCaptureContext(CONTEXT* ContextRecord);
extern(Windows) DWORD GetEnvironmentVariableA(LPCSTR lpName, LPSTR pBuffer, DWORD nSize);

extern(Windows) alias USHORT function(ULONG FramesToSkip, ULONG FramesToCapture, PVOID *BackTrace, PULONG BackTraceHash) RtlCaptureStackBackTraceFunc;

private __gshared RtlCaptureStackBackTraceFunc RtlCaptureStackBackTrace;
private __gshared bool initialized;

class MyStackTrace : Throwable.TraceInfo
{
public:
    /**
     * Constructor
     * Params:
     *  skip = The number of stack frames to skip.
     *  context = The context to receive the stack trace from. Can be null.
     */
    this(size_t skip, CONTEXT* context)
    {
        traceInitialize();

        if(context is null)
        {
            version(Win64)
                static enum INTERNALFRAMES = 3;
            else
                static enum INTERNALFRAMES = 2;

            skip += INTERNALFRAMES; //skip the stack frames within the MyStackTrace class
        }
        else
        {
            //When a exception context is given the first stack frame is repeated for some reason
            version(Win64)
                static enum INTERNALFRAMES = 1;
            else
                static enum INTERNALFRAMES = 1;

            skip += INTERNALFRAMES;
        }
        if( initialized )
            m_trace = trace(skip, context);
    }

    int opApply( scope int delegate(ref const(char[])) dg ) const
    {
        return opApply( (ref size_t, ref const(char[]) buf)
                        {
                            return dg( buf );
                        });
    }


    int opApply( scope int delegate(ref size_t, ref const(char[])) dg ) const
    {
        int result;
        foreach( i, e; resolve(m_trace) )
        {
            if( (result = dg( i, e )) != 0 )
                break;
        }
        return result;
    }


    override string toString() const
    {
        string result;

        foreach( e; this )
        {
            result ~= e ~ "\n";
        }
        return result;
    }

    /**
     * Receive a stack trace in the form of an address list.
     * Params:
     *  skip = How many stack frames should be skipped.
     *  context = The context that should be used. If null the current context is used.
     * Returns:
     *  A list of addresses that can be passed to resolve at a later point in time.
     */
    static ulong[] trace(size_t skip = 0, CONTEXT* context = null)
    {
        synchronized( typeid(MyStackTrace) )
        {
            return traceNoSync(skip, context);
        }
    }

    /**
     * Resolve a stack trace.
     * Params:
     *  addresses = A list of addresses to resolve.
     * Returns:
     *  An array of strings with the results.
     */
    static char[][] resolve(const(ulong)[] addresses)
    {
        synchronized( typeid(MyStackTrace) )
        {
            return resolveNoSync(addresses);
        }
    }

private:
    ulong[] m_trace;


    static ulong[] traceNoSync(size_t skip, CONTEXT* context)
    {
        auto dbghelp  = DbgHelp.get();
        if(dbghelp is null)
            return []; // dbghelp.dll not available

        if(RtlCaptureStackBackTrace !is null && context is null)
        {
            size_t[63] buffer = void; // On windows xp the sum of "frames to skip" and "frames to capture" can't be greater then 63
            auto backtraceLength = RtlCaptureStackBackTrace(cast(ULONG)skip, cast(ULONG)(buffer.length - skip), cast(void**)buffer.ptr, null);

            // If we get a backtrace and it does not have the maximum length use it.
            // Otherwise rely on tracing through StackWalk64 which is slower but works when no frame pointers are available.
            if(backtraceLength > 1 && backtraceLength < buffer.length - skip)
            {
                debug(PRINTF) printf("Using result from RtlCaptureStackBackTrace\n");
                version(Win64)
                {
                    return buffer[0..backtraceLength].dup;
                }
                else
                {
                    auto result = new ulong[backtraceLength];
                    foreach(i, ref e; result)
                    {
                        e = buffer[i];
                    }
                    return result;
                }
            }
        }

        HANDLE       hThread  = GetCurrentThread();
        HANDLE       hProcess = GetCurrentProcess();
        CONTEXT      ctxt;

        if(context is null)
        {
            ctxt.ContextFlags = CONTEXT_FULL;
            RtlCaptureContext(&ctxt);
        }
        else
        {
            ctxt = *context;
        }

        //x86
        STACKFRAME64 stackframe;
        with (stackframe)
        {
            version(X86)
            {
                enum Flat = ADDRESS_MODE.AddrModeFlat;
                AddrPC.Offset    = ctxt.Eip;
                AddrPC.Mode      = Flat;
                AddrFrame.Offset = ctxt.Ebp;
                AddrFrame.Mode   = Flat;
                AddrStack.Offset = ctxt.Esp;
                AddrStack.Mode   = Flat;
            }
        else version(X86_64)
            {
                enum Flat = ADDRESS_MODE.AddrModeFlat;
                AddrPC.Offset    = ctxt.Rip;
                AddrPC.Mode      = Flat;
                AddrFrame.Offset = ctxt.Rbp;
                AddrFrame.Mode   = Flat;
                AddrStack.Offset = ctxt.Rsp;
                AddrStack.Mode   = Flat;
            }
        }

        version (X86)         enum imageType = IMAGE_FILE_MACHINE_I386;
        else version (X86_64) enum imageType = IMAGE_FILE_MACHINE_AMD64;
        else                  static assert(0, "unimplemented");

        ulong[] result;
        size_t frameNum = 0;

        // do ... while so that we don't skip the first stackframe
        do
        {
            if( stackframe.AddrPC.Offset == stackframe.AddrReturn.Offset )
            {
                debug(PRINTF) printf("Endless callstack\n");
                break;
            }
            if(frameNum >= skip)
            {
                result ~= stackframe.AddrPC.Offset;
            }
            frameNum++;
        }
        while (dbghelp.StackWalk64(imageType, hProcess, hThread, &stackframe,
                                   &ctxt, null, null, null, null));
        return result;
    }

    /// drey: added to avoid verbose stack traces
    static bool isBuiltinFile(in char[] path)
    {
        import std.array;
        import std.algorithm;
        import std.range;

        /// help me out here map/any/reduce pro's..
        static immutable arr =
            [r"minilib\core\tracer.d", r"minilib\platform\windows\tracer.d", r"dlint\trace.d", r"std\exception.d"];
        static immutable fwdArr = arr.replace(r"\", "/");

        foreach (it; chain(arr, fwdArr))
        {
            if (path.canFind(it))
                return true;
        }

        return false;
    }

    /// drey: added to avoid verbose stack traces
    static bool isBuiltinSymbol(in char[] traceLine)
    {
        import std.algorithm;

        static arr = [
            "_d_traceContext",
            "_d_run_main",
            "main",
            "mainCRTStartup",
            "BaseThreadInitThunk",
            "__RtlUserThreadStart",
            "_RtlUserThreadStart",
            "_Dmain",
        ];

        return arr.canFind(traceLine) || traceLine.startsWith("void rt.dmain2._d_run_main");
    }

    static char[][] resolveNoSync(const(ulong)[] addresses)
    {
        auto dbghelp  = DbgHelp.get();
        if(dbghelp is null)
            return []; // dbghelp.dll not available

        HANDLE hProcess = GetCurrentProcess();

        static struct BufSymbol
        {
        align(1):
            IMAGEHLP_SYMBOL64 _base;
            TCHAR[1024] _buf;
        }
        BufSymbol bufSymbol=void;
        IMAGEHLP_SYMBOL64* symbol = &bufSymbol._base;
        symbol.SizeOfStruct = IMAGEHLP_SYMBOL64.sizeof;
        symbol.MaxNameLength = bufSymbol._buf.length;

        import std.algorithm;
        import std.conv;
        import std.path;

        char[][] trace;
        foreach(pc; addresses)
        {
            if( pc != 0 )
            {
                char[] res;
                if (dbghelp.SymGetSymFromAddr64(hProcess, pc, null, symbol) &&
                    *symbol.Name.ptr)
                {
                    DWORD disp;
                    IMAGEHLP_LINE64 line=void;
                    line.SizeOfStruct = IMAGEHLP_LINE64.sizeof;

                    if (dbghelp.SymGetLineFromAddr64(hProcess, pc, &disp, &line))
                    {
                        string file = line.FileName[0 .. strlen(line.FileName)]
                            .to!string().absolutePath.buildNormalizedPath();

                        if (isBuiltinFile(file))
                            continue;

                        res = formatStackFrame(cast(void*)pc, symbol.Name.ptr,
                                               file, line.LineNumber);
                    }
                    else
                        res = formatStackFrame(cast(void*)pc, symbol.Name.ptr);
                }
                else
                    res = formatStackFrame(cast(void*)pc);

                if (!isBuiltinSymbol(res))
                    trace ~= res;
            }
        }
        return trace;
    }

    static char[] formatStackFrame(void* pc)
    {
        return [];
        //~ import core.stdc.stdio : snprintf;
        //~ char[2+2*size_t.sizeof+1] buf=void;

        //~ immutable len = snprintf(buf.ptr, buf.length, "0x%p", pc);
        //~ cast(uint)len < buf.length || assert(0);
        //~ return buf[0 .. len].dup;
    }

    static char[] formatStackFrame(void* pc, char* symName)
    {
        //~ return [];

        char[2048] demangleBuf=void;

        // auto res = formatStackFrame(pc);
        char[] res;
        //~ res ~= "In: ";
        const(char)[] tempSymName = symName[0 .. strlen(symName)];
        //~ //Deal with dmd mangling of long names
        version(DigitalMars) version(Win32)
        {
            size_t decodeIndex = 0;
            tempSymName = decodeDmdString(tempSymName, decodeIndex);
        }

        res ~= demangle(tempSymName, demangleBuf);
        return res;
    }

    static char[] formatStackFrame(void* pc, char* symName,
                                   in char[] fileName, uint lineNum)
    {
        import core.stdc.stdio : snprintf;
        char[11] buf=void;

        char[] res;
        res ~= fileName;
        res ~= "(";
        immutable len = snprintf(buf.ptr, buf.length, "%u", lineNum);
        cast(uint)len < buf.length || assert(0);
        res ~= buf[0 .. len];
        res ~= "): Error: \n    ";

        //~ import std.stdio;
        //~ stderr.writefln("WTF: %s", res);

        res ~= formatStackFrame(pc, symName);
        res ~= "\n";
        return res;
    }

    /+ static char[] formatStackFrame(void* pc, char* symName,
                                   in char* fileName, uint lineNum)
    {
        import core.stdc.stdio : snprintf;
        char[11] buf=void;

        char[] res;
        res ~= formatStackFrame(pc, symName);
        res ~= " at ";
        res ~= fileName[0 .. strlen(fileName)];
        res ~= "(";
        immutable len = snprintf(buf.ptr, buf.length, "%u", lineNum);
        cast(uint)len < buf.length || assert(0);
        res ~= buf[0 .. len];
        res ~= ")";
        return res;
    } +/
}


// Workaround OPTLINK bug (Bugzilla 8263)
extern(Windows) BOOL FixupDebugHeader(HANDLE hProcess, ULONG ActionCode,
                                      ulong CallbackContext, ulong UserContext)
{
    if (ActionCode == CBA_READ_MEMORY)
    {
        auto p = cast(IMAGEHLP_CBA_READ_MEMORY*)CallbackContext;
        if (!(p.addr & 0xFF) && p.bytes == 0x1C &&
            // IMAGE_DEBUG_DIRECTORY.PointerToRawData
            (*cast(DWORD*)(p.addr + 24) & 0xFF) == 0x20)
        {
            immutable base = DbgHelp.get().SymGetModuleBase64(hProcess, p.addr);
            // IMAGE_DEBUG_DIRECTORY.AddressOfRawData
            if (base + *cast(DWORD*)(p.addr + 20) == p.addr + 0x1C &&
                *cast(DWORD*)(p.addr + 0x1C) == 0 &&
                *cast(DWORD*)(p.addr + 0x20) == ('N'|'B'<<8|'0'<<16|'9'<<24))
            {
                debug(PRINTF) printf("fixup IMAGE_DEBUG_DIRECTORY.AddressOfRawData\n");
                memcpy(p.buf, cast(void*)p.addr, 0x1C);
                *cast(DWORD*)(p.buf + 20) = cast(DWORD)(p.addr - base) + 0x20;
                *p.bytesread = 0x1C;
                return TRUE;
            }
        }
    }
    return FALSE;
}

private string generateSearchPath()
{
    __gshared string[3] defaultPathList = ["_NT_SYMBOL_PATH",
                                           "_NT_ALTERNATE_SYMBOL_PATH",
                                           "SYSTEMROOT"];

    string path;
    char[2048] temp;
    DWORD len;

    foreach( e; defaultPathList )
    {
        if( (len = GetEnvironmentVariableA( e.ptr, temp.ptr, temp.length )) > 0 )
        {
            path ~= temp[0 .. len];
            path ~= ";";
        }
    }
    path ~= "\0";
    return path;
}

import std.exception;

private void traceInitialize()
{
    auto dbghelp = DbgHelp.get();

    //~ enforce(dbghelp !is null);

    if( dbghelp is null )
        return; // dbghelp.dll not available

    auto kernel32Handle = LoadLibraryA( "kernel32.dll" );
    //~ enforce(kernel32Handle !is null);
    if(kernel32Handle !is null)
    {
        RtlCaptureStackBackTrace = cast(RtlCaptureStackBackTraceFunc) GetProcAddress(kernel32Handle, "RtlCaptureStackBackTrace");
        debug(PRINTF)
        {
            if(RtlCaptureStackBackTrace !is null)
                printf("Found RtlCaptureStackBackTrace\n");
        }
    }

    debug(PRINTF)
    {
        API_VERSION* dbghelpVersion = dbghelp.ImagehlpApiVersion();
        printf("DbgHelp Version %d.%d.%d\n", dbghelpVersion.MajorVersion, dbghelpVersion.MinorVersion, dbghelpVersion.Revision);
    }

    HANDLE hProcess = GetCurrentProcess();

    DWORD symOptions = dbghelp.SymGetOptions();
    symOptions |= SYMOPT_LOAD_LINES;
    symOptions |= SYMOPT_FAIL_CRITICAL_ERRORS;
    symOptions |= SYMOPT_DEFERRED_LOAD;
    symOptions  = dbghelp.SymSetOptions( symOptions );

    debug(PRINTF) printf("Search paths: %s\n", generateSearchPath().ptr);

    dbghelp.SymRegisterCallback64(hProcess, &FixupDebugHeader, 0);

    initialized = true;
}
