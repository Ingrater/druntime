module core.sys.windows.dllmain;

import core.sys.windows.windows;
import core.sys.windows.dllfixup;
import core.stdc.stdio;

extern (Windows) 
BOOL DllMain(HINSTANCE hInstance, ULONG ulReason, LPVOID pvReserved) 
{
  switch(ulReason)
  {
    case DLL_PROCESS_ATTACH:
      printf("druntime loaded\n");
      fixupDataSymbols();
      break;
    case DLL_PROCESS_DETACH:
      printf("druntime unloaded\n");
      break;
    default:
      return true;
  }
  return true;
}