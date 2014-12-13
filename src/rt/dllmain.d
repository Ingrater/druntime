module core.sys.windows.dllmain;

import core.sys.windows.windows;
import core.sys.windows.dllinit;
import core.sys.windows.dll;
import core.stdc.stdio;
import core.runtime;

//debug = PRINTF;

/**
 * Special version of DllMain for druntime / phobos. 
 * Behaves slighty differently from the default implementation to fit the special initialization needs of druntime.
 **/
extern (Windows) 
BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved) 
{
  switch(ulReason)
  {
      case DLL_PROCESS_ATTACH:
          _d_dll_init(hInstance);
          debug(PRINTF) printf("druntime loaded\n");
          version(Win32)
          {
              dll_fixTLS( hInstance, &_tlsstart, &_tlsend, &_tls_callbacks_a, &_tls_index );        
          }
          break;
      case DLL_PROCESS_DETACH:
          debug(PRINTF) printf("druntime unloaded\n");
          break;
      default:
          return true;
  }
  return true;
}