/**
 * ...
 *
 * Copyright: Copyright Benjamin Thaut 2010 - 2011.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Benjamin Thaut, Sean Kelly
 * Source:    $(DRUNTIMESRC core/sys/windows/_stacktrace.d)
 */

/*          Copyright Benjamin Thaut 2010 - 2012.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.windows.stacktrace;

version(NOGCSAFE)
{
  import core.allocator;
  import core.refcounted;
}

version(Windows):

import core.demangle;
import core.runtime;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.windows.dbghelp;
import core.sys.windows.windows;



//debug=PRINTF;
debug(PRINTF) import core.stdc.stdio;


extern(Windows) void RtlCaptureContext(CONTEXT* ContextRecord);
extern(Windows) DWORD GetEnvironmentVariableA(LPCSTR lpName, LPSTR pBuffer, DWORD nSize);

version(Win64)
{
  extern(Windows) USHORT RtlCaptureStackBackTrace(ULONG FramesToSkip, ULONG FramesToCapture, PVOID *BackTrace, PULONG BackTraceHash);
}
else
{
  alias extern(Windows) USHORT function(ULONG FramesToSkip, ULONG FramesToCapture, PVOID *BackTrace, PULONG BackTraceHash) RtlCaptureStackBackTrace_t;
  __gshared RtlCaptureStackBackTrace_t RtlCaptureStackBackTrace;
}


private __gshared bool initialized = false;


class StackTrace : Throwable.TraceInfo
{
private:
  version(NOGCSAFE)
  {
    alias rcstring line_t;
    alias rcstring[] trace_t;
  }
  else
  {
    alias char[] line_t;
    alias char[][] trace_t;
  }
  
  enum size_t MAX_LINE_COUNT = 32;

public:
    /**
     * Constructor
     * Params:
     *  skip = The number of stack frames to skip.
     *  context = The context to receive the stack trace from. Can be null.
     */
    this(size_t skip, CONTEXT* context)
    {
        if(context is null)
        {
            version(Win64)
                static enum INTERNALFRAMES = 4;
            else
                static enum INTERNALFRAMES = 2;
                
            skip += INTERNALFRAMES; //skip the stack frames within the StackTrace class
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
            m_trace = trace(m_buffer, skip, context);
    }

    override int opApply( scope int delegate(ref const(char[])) dg ) const
    {
        return opApply( (ref size_t, ref const(char[]) buf)
                        {
                            return dg( buf );
                        });
    }


    override int opApply( scope int delegate(ref size_t, ref const(char[])) dg ) const
    {
        int result;
        rcstring lines[MAX_LINE_COUNT];
        foreach( i, e; resolve(m_trace, lines) )
        {
            const(char[]) tmp = e[];
            if( (result = dg( i, tmp )) != 0 )
                break;
        }
        return result;
    }


    override to_string_t toString() const
    {
        to_string_t result;

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
    static ulong[] trace(ulong buf[], size_t skip = 0, CONTEXT* context = null)
    {
        synchronized( StackTrace.classinfo )
        {
            return traceNoSync(buf, skip, context);
        }
    }

    /**
     * Resolve a stack trace.
     * Params:
     *  addresses = A list of addresses to resolve.
     * Returns:
     *  An array of strings with the results.
     */
    static trace_t resolve(const(ulong)[] addresses, trace_t buffer)
    {
        synchronized( StackTrace.classinfo )
        {
            return resolveNoSync(addresses, buffer);
        }
    }

private:
    ulong[] m_trace;
    ulong[MAX_LINE_COUNT] m_buffer;


    static ulong[] traceNoSync(ulong[] buf, size_t skip, CONTEXT* context)
    {
        auto dbghelp  = DbgHelp.get();
        if(dbghelp is null)
            return []; // dbghelp.dll not available


        if(context is null)
        {
          version(Win64)
          {
            auto backtraceLength = RtlCaptureStackBackTrace(cast(uint)skip, cast(uint)buf.length, cast(void**)buf.ptr, null);
            if(backtraceLength > 1)
            {
              return buf[0..backtraceLength];
            }
          }
          version(Win32)
          {
            if(RtlCaptureStackBackTrace !is null)
            {
              auto backtraceLength = RtlCaptureStackBackTrace(cast(uint)skip, cast(uint)buf.length, cast(void**)buf.ptr, null);
              if(backtraceLength > 1)
              {
                return buf[0..backtraceLength];
              }
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
                      if(frameNum - skip >= buf.length)
                          break;
                buf[frameNum - skip] = stackframe.AddrPC.Offset;
            }
            frameNum++;
        }
        while (dbghelp.StackWalk64(imageType, hProcess, hThread, &stackframe,
                                   &ctxt, null, null, null, null));
        return buf[0..frameNum - skip];
    }

    static trace_t resolveNoSync(const(ulong)[] addresses, trace_t buffer)
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

        //trace_t trace;
        size_t count = 0;
        foreach(pc; addresses)
        {
            if( pc != 0 )
            {
                if(buffer.length <= count)
                    break;
                line_t res;
                if (dbghelp.SymGetSymFromAddr64(hProcess, pc, null, symbol) &&
                    *symbol.Name.ptr)
                {
                    DWORD disp;
                    IMAGEHLP_LINE64 line=void;
                    line.SizeOfStruct = IMAGEHLP_LINE64.sizeof;

                    if (dbghelp.SymGetLineFromAddr64(hProcess, pc, &disp, &line))
                        res = formatStackFrame(cast(void*)pc, symbol.Name.ptr,
                                               line.FileName, line.LineNumber);
                    else
                        res = formatStackFrame(cast(void*)pc, symbol.Name.ptr);
                }
                else
                    res = formatStackFrame(cast(void*)pc);
                buffer[count++] = res;
            }
        }
        return buffer[0..count];
    }

    static line_t formatStackFrame(void* pc)
    {
        import core.stdc.stdio : snprintf;
        char[2+2*size_t.sizeof+1] buf=void;

        immutable len = snprintf(buf.ptr, buf.length, "0x%p", pc);
        len < buf.length || assert(0);
        return line_t(buf[0 .. len]);
    }

    static line_t formatStackFrame(void* pc, char* symName)
    {
        char[2048] demangleBuf = void;
        char[2048] decodeBuf = void;

        auto res = formatStackFrame(pc);
        res ~= " in ";
        const(char)[] tempSymName = symName[0 .. strlen(symName)];
        //Deal with dmd mangling of long names
        version(DigitalMars) version(Win32)
        {
            size_t decodeIndex = 0;
            tempSymName = decodeDmdString(tempSymName, decodeIndex, decodeBuf);
        }
        res ~= demangle(tempSymName, demangleBuf);
        return res;
    }

    static line_t formatStackFrame(void* pc, char* symName,
                                   in char* fileName, uint lineNum)
    {
        import core.stdc.stdio : snprintf;
        char[11] buf=void;

        auto res = formatStackFrame(pc, symName);
        res ~= " at ";
        res ~= fileName[0 .. strlen(fileName)];
        res ~= "(";
        immutable len = snprintf(buf.ptr, buf.length, "%u", lineNum);
        len < buf.length || assert(0);
        res ~= buf[0 .. len];
        res ~= ")";
        return res;
    }
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

void initializeStackTracing()
{
    if(initialized)
        return;
    auto dbghelp = DbgHelp.get();

    if( dbghelp is null )
        return; // dbghelp.dll not available
    
    version(Win32)
    {
      HMODULE hMod = LoadLibraryA("ntdll.dll");
      if(hMod != null)
      {
        RtlCaptureStackBackTrace = cast(RtlCaptureStackBackTrace_t)GetProcAddress(hMod, "RtlCaptureStackBackTrace");
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

    if (!dbghelp.SymInitialize(hProcess, generateSearchPath().ptr, TRUE))
        return;

    dbghelp.SymRegisterCallback64(hProcess, &FixupDebugHeader, 0);

    initialized = true;        
}

shared static this()
{
    initializeStackTracing();
}
