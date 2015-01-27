/**
 * Written in the D programming language.
 * This module provides Win32-specific support for sections.
 *
 * Copyright: Copyright Digital Mars 2008 - 2012.
 * License: Distributed under the
 *      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
 *    (See accompanying file LICENSE)
 * Authors:   Walter Bright, Sean Kelly, Martin Nowak
 * Source: $(DRUNTIMESRC src/rt/_sections_win64.d)
 */

module rt.sections_win64;

version(Win64):

// debug = PRINTF;
debug(PRINTF) import core.stdc.stdio;
import core.stdc.stdlib : malloc, free;
import rt.deh, rt.minfo;
import rt.util.container.array;
import core.memory;

struct SectionGroup
{
    static int opApply(scope int delegate(ref SectionGroup) dg)
    {
        version(Shared)
        {
            foreach (ref section; _sections)
            {
                if (auto res = dg(section))
                    return res;
            }
            return 0;
        }
        else
        {
            return dg(_sections);
        }
    }

    static int opApplyReverse(scope int delegate(ref SectionGroup) dg)
    {
        version(Shared)
        {
            foreach_reverse (ref section; _sections)
            {
                if (auto res = dg(section))
                    return res;
            }
            return 0;
        }
        else
        {
            return dg(_sections);
        }
    }

    @property immutable(ModuleInfo*)[] modules() const
    {
        return _moduleGroup.modules;
    }

    @property ref inout(ModuleGroup) moduleGroup() inout
    {
        return _moduleGroup;
    }

    @property immutable(FuncTable)[] ehTables() const
    {
        version(Shared)
        {
            return _ehTables;
        }
        else
        {
            auto pbeg = cast(immutable(FuncTable)*)&_deh_beg;
            auto pend = cast(immutable(FuncTable)*)&_deh_end;
            return pbeg[0 .. pend - pbeg];
        }
    }

    @property inout(void[])[] gcRanges() inout
    {
        return _gcRanges[];
    }

private:
    ModuleGroup _moduleGroup;
    void[][1] _gcRanges;
    
    version(Shared)
    {
        void* _hModule;
        extern(C) void[] function() _getTlsRange;
        immutable(FuncTable)[] _ehTables;
    }
}

alias ScanDG = void delegate(void* pbeg, void* pend) nothrow;

version (Shared)
{    
    /**
     * Per thread per Dll Tls Data
     **/
    struct ThreadDllTlsData
    {
        void* _hModule;
        void[] _tlsRange;
    }
    Array!(ThreadDllTlsData) _tlsRanges;
    
    /****
    * Boolean flag set to true while the runtime is initialized.
    */
    __gshared bool _isRuntimeInitialized;
    
    void initSections()
    {
        _isRuntimeInitialized = true;
    }
    
    void finiSections()
    {
        foreach(ref section; _sections)
        {
            .free(cast(void*)section.modules.ptr);
        }
        _sections.reset();
        _isRuntimeInitialized = false;
    }
    
    Array!(ThreadDllTlsData)* initTLSRanges()
    {
        auto pbeg = cast(void*)&_tls_start;
        auto pend = cast(void*)&_tls_end;
        _tlsRanges.insertBack(ThreadDllTlsData(null, pbeg[0 .. pend - pbeg]));       

        // iterate over all already loaded dlls and insert their TLS sections as well.
        // The executable is treated as a dll.
        foreach(ref section; _sections)
        {
            if(section._getTlsRange !is null)
                _tlsRanges.insertBack(ThreadDllTlsData(section._hModule, section._getTlsRange()));
        }
        
        return &_tlsRanges;
    }

    void finiTLSRanges(Array!(ThreadDllTlsData)* tlsRanges)
    {
        _tlsRanges.reset();
    }
    
    void scanTLSRanges(Array!(ThreadDllTlsData)* tlsRanges, scope ScanDG dg) nothrow
    {
        foreach (ref r; *tlsRanges)
            dg(r._tlsRange.ptr, r._tlsRange.ptr + r._tlsRange.length);
    }

    private __gshared Array!(SectionGroup) _sections;
}
else
{
    void initSections()
    {
        _sections._moduleGroup = ModuleGroup(getModuleInfos(_minfo_beg, _minfo_end));

        auto pbeg = cast(void*)&__xc_a;
        auto pend = cast(void*)&_deh_beg;
        _sections._gcRanges[0] = pbeg[0 .. pend - pbeg];
    }

    void finiSections()
    {
        .free(cast(void*)_sections.modules.ptr);
    }

    void[] initTLSRanges()
    {
        auto pbeg = cast(void*)&_tls_start;
        auto pend = cast(void*)&_tls_end;
        return pbeg[0 .. pend - pbeg];
    }

    void finiTLSRanges(void[] rng)
    {
    }

    void scanTLSRanges(void[] rng, scope ScanDG dg) nothrow
    {
        dg(rng.ptr, rng.ptr + rng.length);
    }
    
    private __gshared SectionGroup _sections;
}

private:
extern(C)
{
    extern __gshared void* _minfo_beg;
    extern __gshared void* _minfo_end;
}

immutable(ModuleInfo*)[] getModuleInfos(void* pminfo_beg, void* pminfo_end)
out (result)
{
    foreach(m; result)
        assert(m !is null);
}
body
{
    auto m = (cast(immutable(ModuleInfo*)*)pminfo_beg)[1 .. cast(void**)pminfo_end - cast(void**)pminfo_beg];
    /* Because of alignment inserted by the linker, various null pointers
     * are there. We need to filter them out.
     */
    auto p = m.ptr;
    auto pend = m.ptr + m.length;

    // count non-null pointers
    size_t cnt;
    for (; p < pend; ++p)
    {
        if (*p !is null) ++cnt;
    }

    auto result = (cast(immutable(ModuleInfo)**).malloc(cnt * size_t.sizeof))[0 .. cnt];

    p = m.ptr;
    cnt = 0;
    for (; p < pend; ++p)
        if (*p !is null) result[cnt++] = *p;

    return cast(immutable)result;
}

extern(C)
{
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

version(Shared)
{
private:
    void registerGCRanges(ref SectionGroup pdll)
    {
        foreach (rng; pdll._gcRanges)
            GC.addRange(rng.ptr, rng.length);
    }

    void unregisterGCRanges(ref SectionGroup pdll)
    {
        foreach (rng; pdll._gcRanges)
            GC.removeRange(rng.ptr);
    }


export extern(C) void _d_dll_registry_register(void* hModule, void* pminfo_beg, void* pminfo_end, void* pdeh_beg, void* pdeh_end, void* p_xc_a, void[] function() getTlsRange)
    {
        SectionGroup dllSection;
        dllSection._moduleGroup = ModuleGroup(getModuleInfos(pminfo_beg, pminfo_end));
        dllSection._getTlsRange = getTlsRange;
        dllSection._hModule = hModule;

        {
            auto pbeg = cast(void*)p_xc_a;
            auto pend = cast(void*)pdeh_beg;
            dllSection._gcRanges[0] = pbeg[0 .. pend - pbeg]; 
        }
        
        {
            auto pbeg = cast(immutable(FuncTable)*)pdeh_beg;
            auto pend = cast(immutable(FuncTable)*)pdeh_end;
            dllSection._ehTables = pbeg[0 .. pend - pbeg];
        }    
        
        if(_isRuntimeInitialized)
        {
            // Add tls range
            if(dllSection._getTlsRange !is null)
                _tlsRanges.insertBack(ThreadDllTlsData(dllSection._hModule, dllSection._getTlsRange()));
                
            // register GC ranges
            registerGCRanges(dllSection);
        
            // Run Module Constructors
            dllSection._moduleGroup.sortCtors();
            dllSection._moduleGroup.runCtors();
            dllSection._moduleGroup.runTlsCtors();
        }

        _sections.insertBack(dllSection);
    }
  
    extern(C) void _d_dll_registry_unregister(void* hModule)
    {
        size_t i = 0;
        for(; i < _sections.length; i++)
        {
          if(_sections[i]._hModule is hModule)
            break;
        }
        // if the runtime was already deinitialized _sections is empty
        if(i < _sections.length)
        {
            auto dllSection = _sections[i];
            _sections.remove(i);
            
            if(_isRuntimeInitialized)
            {
                // Run Module Destructors
                dllSection._moduleGroup.runTlsDtors();  
                dllSection.moduleGroup.runDtors();
                dllSection.moduleGroup.free();        
                
                // unregister GC ranges
                unregisterGCRanges(dllSection);
                
                // remove tls range
                size_t j = 0;
                for(; j < _tlsRanges.length; j++)
                {
                  if(_tlsRanges[i]._hModule is hModule)
                    break;
                }
                if(j < _tlsRanges.length)
                {
                  _tlsRanges.remove(j);
                }
            }
            
            .free(cast(void*)dllSection.modules.ptr);
        }
    }
}
