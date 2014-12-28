module core.sys.windows.dllfixup;

import core.stdc.stdio : printf;

extern(C)
{
  /*struct DllRealloc 
  {
    void* address;
    size_t offset;
  }*/

  extern __gshared void* _dllra_beg; // actually a DllRealloc* (c array of DllRealloc)
  extern __gshared void* _dllra_end;
}

extern(C) void _d_dll_registry(void* hModule, void* pminfo_beg, void* pminfo_end, void* pdeh_beg, void* pdeh_end, void* p_xc_a, void[] function() getTlsRange);

extern(C) void _d_dll_fixup()
{
  void** begin = &_dllra_beg;
  void** end = &_dllra_end;
  for(void** outer = begin; outer < end; outer += 2)
  {
    if(*outer !is null) // skip any padding
    {
      void** address = *cast(void***)outer;
      size_t offset = *cast(size_t*)(outer+1);
      printf("patching %llx to %llx (offset %d)\n", address, (**cast(void***)address), offset);
      *address = (**cast(void***)address) + offset;
    }
  }
  _d_dll_registry(null, cast(void*)&_minfo_beg, cast(void*)&_minfo_end, cast(void*)&_deh_beg, cast(void*)&_deh_end, cast(void*)&__xc_a, &_d_getTLSRange);
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
        void* _deh_beg;
        void* _deh_end;

        int __xc_a;      // &__xc_a just happens to be start of data segment
        //int _edata;    // &_edata is start of BSS segment
        //void* _deh_beg;  // &_deh_beg is past end of BSS
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