module core.sys.windows.dllmain;

import core.sys.windows.windows;
import core.sys.windows.dllfixup;
import core.sys.windows.dll;
import core.stdc.stdio;

debug = PRINTF;

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
          _d_dll_fixup(hInstance);
          debug(PRINTF) printf("druntime loaded\n");
          version(Win32)
          {
              return dll_fixTLS( hInstance, &_tlsstart, &_tlsend, &_tls_callbacks_a, &_tls_index );        
          }
          // We need to initialize std streams here as well in case
          // D is used from a C program so _d_main is never called.
          _d_init_std_streams(); 
          break;
      case DLL_PROCESS_DETACH:
          debug(PRINTF) printf("druntime unloaded\n");
          break;
      default:
          return true;
  }
  return true;
}