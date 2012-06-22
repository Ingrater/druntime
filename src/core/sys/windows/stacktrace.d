/**
 * ...
 *
 * Copyright: Copyright Benjamin Thaut 2010 - 2011.
 * License:   $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost License 1.0)
 * Authors:   Benjamin Thaut, Sean Kelly
 * Source:    $(DRUNTIMESRC core/sys/windows/_stacktrace.d)
 */

/*          Copyright Benjamin Thaut 2010 - 2011.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module core.sys.windows.stacktrace;


import core.demangle;
import core.runtime;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.windows.dbghelp;
import core.sys.windows.windows;
import core.stdc.stdio;

version(NOGCSAFE)
{
  import core.allocator;
  import core.refcounted;
}


extern(Windows)
{
    DWORD GetEnvironmentVariableA(LPCSTR lpName, LPSTR pBuffer, DWORD nSize);
    void  RtlCaptureContext(CONTEXT* ContextRecord);

    alias LONG function(void*) UnhandeledExceptionFilterFunc;
    void* SetUnhandledExceptionFilter(void* handler);
}


enum : uint
{
    MAX_MODULE_NAME32 = 255,
    TH32CS_SNAPMODULE = 0x00000008,
    MAX_NAMELEN       = 1024,
};


extern(System)
{
    alias HANDLE function(DWORD dwFlags, DWORD th32ProcessID) CreateToolhelp32SnapshotFunc;
    alias BOOL   function(HANDLE hSnapshot, MODULEENTRY32 *lpme) Module32FirstFunc;
    alias BOOL   function(HANDLE hSnapshot, MODULEENTRY32 *lpme) Module32NextFunc;
}


struct MODULEENTRY32
{
    DWORD   dwSize;
    DWORD   th32ModuleID;
    DWORD   th32ProcessID;
    DWORD   GlblcntUsage;
    DWORD   ProccntUsage;
    BYTE*   modBaseAddr;
    DWORD   modBaseSize;
    HMODULE hModule;
    CHAR[MAX_MODULE_NAME32 + 1] szModule;
    CHAR[MAX_PATH] szExePath;
}


private
{
    version(NOGCSAFE)
    {
      alias RCArray!char path_t; 
    }
    else
    {
      alias string path_t;
    }
  
    path_t generateSearchPath()
    {
        __gshared string[3] defaultPathList = ["_NT_SYMBOL_PATH",
                                               "_NT_ALTERNATE_SYMBOL_PATH",
                                               "SYSTEMROOT"];

        path_t         path;
        char[MAX_PATH] temp;
        DWORD          len;

        if( (len = GetCurrentDirectoryA( temp.length, temp.ptr )) > 0 )
        {
            path ~= temp[0 .. len];
            path ~= ";";
        }
        if( (len = GetModuleFileNameA( null,temp.ptr,temp.length )) > 0 )
        {
            foreach_reverse( i, ref char e; temp[0 .. len] )
            {
                if( e == '\\' || e == '/' || e == ':' )
                {
                    len -= i;
                    break;
                }
            }
            if( len > 0 )
            {
                path ~= temp[0 .. len];
                path ~= ";";
            }
        }
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


    bool loadModules( HANDLE hProcess, DWORD pid )
    {
        __gshared string[2] systemDlls = ["kernel32.dll", "tlhelp32.dll"];

        CreateToolhelp32SnapshotFunc CreateToolhelp32Snapshot;
        Module32FirstFunc            Module32First;
        Module32NextFunc             Module32Next;
        HMODULE                      dll;

        foreach( e; systemDlls )
        {
            if( (dll = cast(HMODULE) Runtime.loadLibrary( e )) is null )
                continue;
            CreateToolhelp32Snapshot = cast(CreateToolhelp32SnapshotFunc) GetProcAddress( dll,"CreateToolhelp32Snapshot" );
            Module32First            = cast(Module32FirstFunc) GetProcAddress( dll,"Module32First" );
            Module32Next             = cast(Module32NextFunc) GetProcAddress( dll,"Module32Next" );
            if( CreateToolhelp32Snapshot !is null && Module32First !is null && Module32Next !is null )
                break;
            Runtime.unloadLibrary( dll );
            dll = null;
        }
        if( dll is null )
        {
            return false;
        }

        auto hSnap = CreateToolhelp32Snapshot( TH32CS_SNAPMODULE, pid );
        if( hSnap == INVALID_HANDLE_VALUE )
            return false;

        MODULEENTRY32 moduleEntry;
        moduleEntry.dwSize = MODULEENTRY32.sizeof;

        auto more  = cast(bool) Module32First( hSnap, &moduleEntry );
        int  count = 0;

        while( more )
        {
            count++;
            loadModule( hProcess,
                        moduleEntry.szExePath.ptr,
                        moduleEntry.szModule.ptr,
                        cast(DWORD64) moduleEntry.modBaseAddr,
                        moduleEntry.modBaseSize );
            more = cast(bool) Module32Next( hSnap, &moduleEntry );
        }

        CloseHandle( hSnap );
        Runtime.unloadLibrary( dll );
        return count > 0;
    }


    void loadModule( HANDLE hProcess, PCSTR img, PCSTR mod, DWORD64 baseAddr, DWORD size )
    {
        auto dbghelp       = DbgHelp.get();
        DWORD64 moduleAddr = dbghelp.SymLoadModule64( hProcess,
                                                      HANDLE.init,
                                                      img,
                                                      mod,
                                                      baseAddr,
                                                      size );
        if( moduleAddr == 0 )
            return;

        IMAGEHLP_MODULE64 moduleInfo;
        moduleInfo.SizeOfStruct = IMAGEHLP_MODULE64.sizeof;

        if( dbghelp.SymGetModuleInfo64( hProcess, moduleAddr, &moduleInfo ) == TRUE )
        {
            if( moduleInfo.SymType == SYM_TYPE.SymNone )
            {
                dbghelp.SymUnloadModule64( hProcess, moduleAddr );
                moduleAddr = dbghelp.SymLoadModule64( hProcess,
                                                      HANDLE.init,
                                                      img,
                                                      null,
                                                      cast(DWORD64) 0,
                                                      0 );
                if( moduleAddr == 0 )
                    return;
            }
        }
        //printf( "Successfully loaded module %s\n", img );
    }


    /+
    extern(Windows) static LONG unhandeledExceptionFilterHandler(void* info)
    {
        printStackTrace();
        return 0;
    }


    static void printStackTrace()
    {
        auto stack = TraceHandler( null );
        foreach( char[] s; stack )
        {
            printf( "%s\n",s );
        }
    }
    +/


    __gshared immutable bool initialized;
}


class StackTrace : Throwable.TraceInfo
{
public:
    this()
    {
        if( initialized )
            m_trace = trace();
    }
  
    version(NOGCSAFE)
    {
      alias RCArray!(immutable(char)) line_t;
      alias RCArray!(line_t) trace_t;
    }
    else
    {
      alias char[] line_t;
      alias char[][] trace_t;
    }

    int opApply( scope int delegate(ref string) dg )
    {
        return opApply( (ref size_t, ref string buf)
                        {
                            return dg( buf );
                        });
    }

    int opApply( scope int delegate(ref size_t, ref string) dg )
    {
        int result;

        foreach( i, e; m_trace )
        {
          version(NOGCSAFE)
          {
            auto temp = e[];
            if( (result = dg(i, temp )) != 0)
              break;
          }
          else {
            auto temp = cast(string)e;
            if( (result = dg( i, temp )) != 0 )
                break;
          }
        }
        return result;
    }


    override to_string_t toString()
    {
        version(NOGCSAFE)
        {
          rcstring result;
          
          foreach( e; m_trace)
          {
            result ~= e;
            result ~= "\n";
          }
          return result;
        }
        else
        {
          string result;

          foreach( e; m_trace )
          {
              result ~= e;
              result ~= "\n";
          }
          return result;
        }
    }
    
    static long[] traceAddresses(long[] addresses, bool allocateIfToSmall = true, int skip = 0)
    {
      synchronized( StackTrace.classinfo )
      {
        return traceAddressesNoSync(addresses,allocateIfToSmall,skip);
      }
    }
    
    static trace_t resolveAddresses(long[] addresses)
    {
      synchronized( StackTrace.classinfo )
      {
        return resolveAddressesNoSync(addresses);
      }
    }

private:
    trace_t m_trace;


    static trace_t trace()
    {
        synchronized( StackTrace.classinfo )
        {
            long[10] addressesBuffer;
            long[] addresses = traceAddressesNoSync(addressesBuffer,true);
            auto result = resolveAddressesNoSync(addresses);
            version(NOGCSAFE)
            {
              if(addresses.ptr != addressesBuffer.ptr)
              {
                StdAllocator.globalInstance.FreeMemory(addresses.ptr);
              }
            }
            return result;
        }
    }
    
    static void ContextHelper( ref CONTEXT c )
    {
      RtlCaptureContext( &c );
    }
  
    static long[] traceAddressesNoSync(long[] addresses, bool allocateIfToSmall = true, int skip = 0)
    {
        assert(addresses.length > 0,"need at least space to write 1 address");
        auto         dbghelp  = DbgHelp.get();
        auto         hThread  = GetCurrentThread();
        auto         hProcess = GetCurrentProcess();
        STACKFRAME64 stackframe;
        DWORD        imageType;
        char[][]     trace;
        CONTEXT      c;
        version(NOGCSAFE){
          bool         allocated = false;
        }

        c.ContextFlags = CONTEXT_FULL;
        ContextHelper( c );
        //RtlCaptureContext( &c );

        //x86
        imageType                   = IMAGE_FILE_MACHINE_I386;
        stackframe.AddrPC.Offset    = cast(DWORD64) c.Eip;
        stackframe.AddrPC.Mode      = ADDRESS_MODE.AddrModeFlat;
        stackframe.AddrFrame.Offset = cast(DWORD64) c.Ebp;
        stackframe.AddrFrame.Mode   = ADDRESS_MODE.AddrModeFlat;
        stackframe.AddrStack.Offset = cast(DWORD64) c.Esp;
        stackframe.AddrStack.Mode   = ADDRESS_MODE.AddrModeFlat; 

        //printf( "Callstack:\n" );
        size_t frameNum = 0;
        for( ; ; frameNum++ )
        {
            if( dbghelp.StackWalk64( imageType,
                                     hProcess,
                                     hThread,
                                     &stackframe,
                                     &c,
                                     null,
                                     cast(FunctionTableAccessProc64) dbghelp.SymFunctionTableAccess64,
                                     cast(GetModuleBaseProc64) dbghelp.SymGetModuleBase64,
                                     null) != TRUE )
            {
                //printf( "End of Callstack\n" );
                break;
            }
          
            if( stackframe.AddrPC.Offset == stackframe.AddrReturn.Offset )
            {
                //printf( "Endless callstack\n" );
                break;
            }
            
            //Skip first stack frame
            if(frameNum < skip)
              continue;
            
            if(frameNum-skip >= addresses.length)
            {
              if(allocateIfToSmall)
              {
                version(NOGCSAFE)
                {
                  if(allocated)
                  {
                    long* mem = cast(long*)StdAllocator.globalInstance.ReallocateMemory(addresses.ptr,addresses.length * 2 * long.sizeof);
                    addresses = mem[0..(addresses.length * 2)];
                  }
                  else
                  {
                    long* mem = cast(long*)StdAllocator.globalInstance.AllocateMemory(addresses.length * 2 * long.sizeof);
                    addresses = mem[0..(addresses.length * 2)];
                    allocated = true;
                  }
                }
                else {
                  long[] mem = new long[addresses.length * 2];
                  mem[0..addresses.length] = addresses[];
                  addresses = mem;
                }
              }
              else {
                return addresses;
              }
            }
            
            addresses[frameNum-skip] = stackframe.AddrPC.Offset;
        }
        if(frameNum < skip)
          frameNum = skip;
        return addresses[0..(frameNum-skip)];
    }
    
    static trace_t resolveAddressesNoSync(long[] addresses)
    {
      trace_t trace;
      auto dbghelp    = DbgHelp.get();
      auto hProcess   = GetCurrentProcess();
      auto symbolSize = IMAGEHLP_SYMBOL64.sizeof + MAX_NAMELEN;
      version(DUMA)
        auto symbol   = cast(IMAGEHLP_SYMBOL64*) _duma_calloc( symbolSize, 1, __FILE__, __LINE__);
      else
        auto symbol   = cast(IMAGEHLP_SYMBOL64*) calloc( symbolSize, 1 );

      static assert((IMAGEHLP_SYMBOL64.sizeof + MAX_NAMELEN) <= uint.max, "symbolSize should never exceed uint.max");

      symbol.SizeOfStruct  = cast(DWORD)symbolSize;
      symbol.MaxNameLength = MAX_NAMELEN;

      IMAGEHLP_LINE64 line;
      line.SizeOfStruct = IMAGEHLP_LINE64.sizeof;

      IMAGEHLP_MODULE64 moduleInfo;
      moduleInfo.SizeOfStruct = IMAGEHLP_MODULE64.sizeof;
        
      foreach(address; addresses)
      {
        if( address != 0 )
        {
            DWORD64 offset;

            if( dbghelp.SymGetSymFromAddr64( hProcess,
                                             address,
                                             &offset,
                                             symbol ) == TRUE )
            {
                DWORD    displacement;
                char[]   lineBuf;
                char[20] temp;
                
                auto         symbolName = (cast(char*) symbol.Name.ptr)[0 .. strlen(symbol.Name.ptr)];

                if( dbghelp.SymGetLineFromAddr64( hProcess, address, &displacement, &line ) == TRUE )
                {     
                    char[2048] demangleBuf;
                    version(NOGCSAFE){
                      line_t cur;
                      
                      cur ~= line.FileName[0 .. strlen( line.FileName )];
                      cur ~= "(";
                      cur ~= format( temp[], line.LineNumber );
                      cur ~= "):";
                      try {
                        char[2048] decodeBuffer;
                        size_t index = 0;
                        char[] decodedName = decodeDmdString( symbolName, index, decodeBuffer);
                        char[] demangledName = demangle( decodedName, demangleBuf );
                        cur ~= demangledName;
                        if(demangledName.ptr != demangleBuf.ptr)
                          StdAllocator.globalInstance.FreeMemory(demangledName.ptr);
                      }
                      catch(Exception ex)
                      {
                        cur ~= symbolName;
                        //no need to delete the exception here because it is in static memory
                      }
                      trace ~= cur;
                    }
                    else {
                      char[2048] decodeBuffer;
                      size_t index = 0;
                      char[] decodedName = decodeDmdString( symbolName, index, decodeBuffer);
                      // displacement bytes from beginning of line
                      trace ~= line.FileName[0 .. strlen( line.FileName )] ~
                               "(" ~ format( temp[], line.LineNumber ) ~ "): " ~
                               demangle( decodedName, demangleBuf );
                    }
                }
                else {
                  version(NOGCSAFE)
                  {
                    trace ~= line_t(symbolName);
                  }
                  else {
                    trace ~= symbolName;
                  }
                }
            }
            else
            {
                char[22] temp;
                auto     val = format( temp[], address, 16 );
                version(NOGCSAFE)
                {
                  trace ~= line_t(val);
                }
                else {
                  trace ~= val.dup;
                }
            }
        }
        else {
          version(NOGCSAFE)
          {
            trace ~= line_t("unknown");
          }
          else 
          {
            trace ~= "unkown".dup;
          }
        }
      }
      version(DUMA)
        _duma_free( symbol, __FILE__, __LINE__ );
      else
        free( symbol );
      return trace;        
    }

    // TODO: Remove this in favor of an external conversion.
    static char[] format( char[] buf, ulong val, uint base = 10 )
    in
    {
        assert( buf.length > 9 );
    }
    body
    {
        auto p = buf.ptr + buf.length;

        if( base < 11 )
        {
            do
            {
                *--p = cast(char)(val % base + '0');
            } while( val /= base );
        }
        else if( base < 37 )
        {
            do
            {
                auto x = val % base;
                *--p = cast(char)(x < 10 ? x + '0' : (x - 10) + 'A');
            } while( val /= base );
        }
        else
        {
            assert( false, "base too large" );
        }
        return buf[p - buf.ptr .. $];
    }
}


shared static this()
{
    auto dbghelp = DbgHelp.get();

    if( dbghelp is null )
        return; // dbghelp.dll not available

    auto hProcess = GetCurrentProcess();
    auto pid      = GetCurrentProcessId();
    auto symPath  = generateSearchPath();
    auto ret      = dbghelp.SymInitialize( hProcess,
                                           symPath.ptr,
                                           FALSE );
    assert( ret != FALSE );

    auto symOptions = dbghelp.SymGetOptions();
    symOptions |= SYMOPT_LOAD_LINES;
    symOptions |= SYMOPT_FAIL_CRITICAL_ERRORS;
    symOptions  = dbghelp.SymSetOptions( symOptions );

    if( !loadModules( hProcess, pid ) )
        {} // for now it's fine if the modules don't load
    initialized = true;
    //SetUnhandledExceptionFilter( &unhandeledExceptionFilterHandler );
}
