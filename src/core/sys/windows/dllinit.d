module core.sys.windows.dllinit;

import core.stdc.stdio : printf;

extern(C) void _d_dll_registry_register(void* hModule, void* pdllrl_beg, void* pdllrl_end, void* pminfo_beg, void* pminfo_end, void* pdeh_beg, void* pdeh_end, void* p__ImageBase, void* p_DP_beg, void* p_DP_end, void* p_TP_beg, void * p_TP_end, void[] function() getTlsRange);

version(CRuntime_Microsoft)
{
  extern(C) void _msvc_force_link();
}

extern(C) void _d_dll_init(void* hModule)
{
  version(CRuntime_Microsoft)
  {
    _msvc_force_link();
  }
  version(Shared)
  {
    _d_dll_registry_register(hModule, cast(void*)&_dllrl_beg, cast(void*)&_dllrl_end, cast(void*)&_minfo_beg, cast(void*)&_minfo_end, cast(void*)&_deh_beg, cast(void*)&_deh_end, cast(void*)&__ImageBase, cast(void*)&_DP_beg, cast(void*)&_DP_end, cast(void*)&_TP_beg, cast(void*)&_TP_end, &_d_getTLSRange);
  }
}

private: 
extern(C)
{
    // the dll relocation section basically is a DllReloc[].
    // we can't use the struct however because the struct itself would introduce data symbol references through its typeinfo.
    /*struct DllReloc 
    {
      void* address;
      size_t offset;
    }*/

    extern __gshared void* _dllrl_beg; // actually a DllReloc* (c array of DllReloc)
    extern __gshared void* _dllrl_end;

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
        
        uint _DP_beg;
        uint _DP_end;
        uint _TP_beg;
        uint _TP_end;
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