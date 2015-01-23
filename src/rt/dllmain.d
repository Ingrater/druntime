module core.sys.windows.dllmain;

import core.sys.windows.windows;
import core.sys.windows.dllfixup;
import core.stdc.stdio;

debug = PRINTF;

extern (Windows) 
BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved) 
{
  switch(ulReason)
  {
    case DLL_PROCESS_ATTACH:
      debug(PRINTF) printf("druntime loaded\n");
      _d_dll_fixup();
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