/**
 * Written in the D programming language.
 * This module provides Win32 specific dll initialization.
 *
 * It is compiled as static library and then merged with the 
 * import library produced by druntime/phobos so that the code
 * in this module is automatically linked into every d-dll.
 *
 * Copyright: Copyright Digital Mars 2008 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Benjamin Thaut
 * Source: $(DRUNTIMESRC src/rt/dllinit.d)
 */

module rt.dllinit;

version(CRuntime_Microsoft):

// Used to force the inclusion of the object files that contains the linker comments required to make newer version of Visual Studio work.
extern(C) void _msvc_force_link();

extern(C) void _d_dll_init(void* hModule)
{
    _msvc_force_link();
    version(Shared)
    {
        import rt.sections_win64 : registerDll;
        registerDll(hModule, cast(void*)&_dllrl_beg, cast(void*)&_dllrl_end, cast(void*)&_minfo_beg, cast(void*)&_minfo_end, cast(void*)&_deh_beg, cast(void*)&_deh_end, cast(void*)&__ImageBase, &_DP_beg, &_DP_end, &_TP_beg, &_TP_end, &initTLSRanges);
    }
}

void[] initTLSRanges() nothrow @nogc
{
    void* pbeg;
    void* pend;
    // with VS2017 15.3.1, the linker no longer puts TLS segments into a
    //  separate image section. That way _tls_start and _tls_end no
    //  longer generate offsets into .tls, but DATA.
    // Use the TEB entry to find the start of TLS instead and read the
    //  length from the TLS directory
    version(D_InlineAsm_X86)
    {
        asm @nogc nothrow
        {
            mov EAX, _tls_index;
            mov ECX, FS:[0x2C];     // _tls_array
            mov EAX, [ECX+4*EAX];
            mov pbeg, EAX;
            add EAX, [_tls_used+4]; // end
            sub EAX, [_tls_used+0]; // start
            mov pend, EAX;
        }
    }
    else version(D_InlineAsm_X86_64)
    {
        asm @nogc nothrow
        {
            xor RAX, RAX;
            mov EAX, _tls_index;
            mov RCX, 0x58;
            mov RCX, GS:[RCX];      // _tls_array (immediate value causes fixup)
            mov RAX, [RCX+8*RAX];
            mov pbeg, RAX;
            add RAX, [_tls_used+8]; // end
            sub RAX, [_tls_used+0]; // start
            mov pend, RAX;
        }
    }
    else
        static assert(false, "Architecture not supported.");

    return pbeg[0 .. pend - pbeg];
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

        void*[2] _tls_used; // start, end
        int _tls_index;
    }
}