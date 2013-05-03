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

    __gshared bool initialized = false;
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
        if(!initialized) 
          return [];
        return traceAddressesNoSync(addresses, allocateIfToSmall, skip);
      }
    }
    
    static trace_t resolveAddresses(long[] addresses)
    {
      synchronized( StackTrace.classinfo )
      {
        if(!initialized) 
          return trace_t();
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
        //ContextHelper( c );
        RtlCaptureContext( &c );

        //x86
        version(X86)
        {
          imageType                   = IMAGE_FILE_MACHINE_I386;
          stackframe.AddrPC.Offset    = cast(DWORD64) c.Eip;
          stackframe.AddrPC.Mode      = ADDRESS_MODE.AddrModeFlat;
          stackframe.AddrFrame.Offset = cast(DWORD64) c.Ebp;
          stackframe.AddrFrame.Mode   = ADDRESS_MODE.AddrModeFlat;
          stackframe.AddrStack.Offset = cast(DWORD64) c.Esp;
          stackframe.AddrStack.Mode   = ADDRESS_MODE.AddrModeFlat; 
        }
        else version(X86_64)
        {
          imageType                   = IMAGE_FILE_MACHINE_AMD64;
          stackframe.AddrPC.Offset    = cast(DWORD64) c.Rip;
          stackframe.AddrPC.Mode      = ADDRESS_MODE.AddrModeFlat;
          stackframe.AddrFrame.Offset = cast(DWORD64) c.Rbp;
          stackframe.AddrFrame.Mode   = ADDRESS_MODE.AddrModeFlat;
          stackframe.AddrStack.Offset = cast(DWORD64) c.Rsp;
          stackframe.AddrStack.Mode   = ADDRESS_MODE.AddrModeFlat; 
        }
        else
          static assert(0, "plattform not supported");

        //printf( "Callstack:\n" );
        size_t frameNum = 0;
        for( ; ; frameNum++ )
        {
            if( dbghelp.StackWalk64( imageType, hProcess, hThread, &stackframe, &c,
                                     null, null, null, null) != TRUE )
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
                        char[] demangledName = symbolName;
                        version(DigitalMars) version(Win32)
                        {
                          demangledName = decodeDmdString( demangledName, index, decodeBuffer);
                        }
                        demangledName = demangle( demangledName, demangleBuf );
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
        printf("fixup IMAGE_DEBUG_DIRECTORY.AddressOfRawData\n");
        memcpy(p.buf, cast(void*)p.addr, 0x1C);
        *cast(DWORD*)(p.buf + 20) = cast(DWORD)(p.addr - base) + 0x20;
        *p.bytesread = 0x1C;
        return TRUE;
      }
    }
  }
  return FALSE;
}

private size_t formatLastError(char[] buffer)
{
  DWORD lastError = GetLastError();
  return cast(size_t)FormatMessageA(
                                        FORMAT_MESSAGE_FROM_SYSTEM |
                                        FORMAT_MESSAGE_IGNORE_INSERTS,
                                        null,
                                        lastError,
                                        MAKELANGID(LANG_NEUTRAL, SUBLANG_DEFAULT),
                                        buffer.ptr,
                                        cast(uint)buffer.length, 
                                        null );
}

void initializeStackTracing()
{
  if(initialized)
    return;
  auto dbghelp = DbgHelp.get();

  if( dbghelp is null )
    return; // dbghelp.dll not available

  auto hProcess = GetCurrentProcess();
  auto symPath  = generateSearchPath();

  auto symOptions = dbghelp.SymGetOptions();
  symOptions |= SYMOPT_LOAD_LINES;
  symOptions |= SYMOPT_FAIL_CRITICAL_ERRORS;
  symOptions |= SYMOPT_DEFERRED_LOAD;
  symOptions  = dbghelp.SymSetOptions( symOptions );

  if(!dbghelp.SymInitialize( hProcess, symPath.ptr, TRUE ))
  {
    char[1024] buffer;
    size_t len = formatLastError(buffer);
    printf("SymInitialize init failed with: %-*s\n", len, buffer.ptr);
    return;
  }

  dbghelp.SymRegisterCallback64(hProcess, &FixupDebugHeader, 0);

  initialized = true;
}


shared static this()
{
  initializeStackTracing();
}
