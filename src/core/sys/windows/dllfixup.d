module core.sys.windows.dllfixup;

import core.stdc.stdio : printf;

extern(C)
{
  // the dll relocation section basically is a DllRealloc[].
  // we can't use the struct however because the struct itself would introduce data symbol references through its typeinfo.
  /*struct DllRealloc 
  {
    void* address;
    size_t offset;
  }*/

  extern __gshared void* _dllra_beg; // actually a DllRealloc* (c array of DllRealloc)
  extern __gshared void* _dllra_end;
}

extern(C) void _d_dll_registry_register(void* hModule, void* pminfo_beg, void* pminfo_end, void* pdeh_beg, void* pdeh_end, void* p__ImageBase, void[] function() getTlsRange);

extern(C) void _d_dll_fixup(void* hModule)
{
  void** begin = &_dllra_beg;
  void** end = &_dllra_end;
  void** outer = begin;
  while(outer < end && *outer is null) outer++; // skip leading 0s
  while(outer < end)
  {
    if(*outer !is null) // skip any padding
    {
      // For 64-bit we actually store the address as 32-bit offset instead of a 64-bit pointer
      version(Win64)
      {
        int* start = cast(int*)outer;
        int relAddress = (*start) + 4; // take size of the offset into account as well
        int offset = *(start+1);
        //void** address = *cast(void***)(outer+1);
        void** reconstructedAddress = cast(void**)(cast(void*)start + relAddress);
        //if(address != reconstructedAddress) asm { int 3; }
        debug(PRINTF) printf("patching %llx to %llx (offset %d)\n", reconstructedAddress, (**cast(void***)reconstructedAddress), offset);
        *reconstructedAddress = (**cast(void***)reconstructedAddress) + offset;
        //outer += 2;
        outer++;
      }
      else
      {
        void** address = *cast(void***)outer;
        size_t offset = *cast(size_t*)(outer+1);
        debug(PRINTF) printf("patching %llx to %llx (offset %d)\n", address, (**cast(void***)address), offset);
        *address = (**cast(void***)address) + offset;
        outer += 2;
      }
    }
    else
    {
      outer++;
    }
  }
  version(Shared)
  {
    _d_dll_registry_register(hModule, cast(void*)&_minfo_beg, cast(void*)&_minfo_end, cast(void*)&_deh_beg, cast(void*)&_deh_end, cast(void*)&__ImageBase, &_d_getTLSRange);
  }
}

private: 
extern(C)
{
    extern __gshared void* _minfo_beg;
    extern __gshared void* _minfo_end;
    
    /* Symbols created by the compiler/linker and inserted into the
     * object file that 'bracket' sections.
     */
    extern __gshared
    {
        void* __ImageBase;
    
        void* _deh_beg;
        void* _deh_end;
    }

    extern
    {
        int _tls_start;
        int _tls_end;
    }
}

extern(C) void[] _d_getTLSRange()
{
    auto pbeg = cast(void*)&_tls_start;
    auto pend = cast(void*)&_tls_end;
    return pbeg[0 .. pend - pbeg];
}