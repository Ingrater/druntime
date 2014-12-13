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
pragma(sharedlibrary, "std");

version(CRuntime_Microsoft):

// debug = PRINTF;
debug(PRINTF) import core.stdc.stdio;
import core.stdc.stdlib : malloc, free;
import rt.deh, rt.minfo;
import rt.util.container.array;
import core.memory;

version(Shared)
{  
    alias GetTlsRangeDG = void[] function() nothrow @nogc;
}

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

    @property immutable(ModuleInfo*)[] modules() const nothrow @nogc
    {
        return _moduleGroup.modules;
    }

    @property ref inout(ModuleGroup) moduleGroup() inout nothrow @nogc
    {
        return _moduleGroup;
    }

    version(Win64)
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

    @property inout(void[])[] gcRanges() inout nothrow @nogc
    {
        return _gcRanges[];
    }

private:
    ModuleGroup _moduleGroup;
    void[][] _gcRanges;
    
    version(Shared)
    {
        void* _hModule;
        GetTlsRangeDG _getTlsRange;
        uint* _p_TP_beg;
        uint* _p_TP_end;
        version(Win64) immutable(FuncTable)[] _ehTables;
    }
}

shared(bool) conservative;

alias ScanDG = void delegate(void* pbeg, void* pend) nothrow;
extern(C) void[] _d_getTLSRange();

version (Shared)
{    
    /**
     * Per thread per Dll Tls Data
     **/
    struct ThreadDllTlsData
    {
        void* _hModule;
        void[] _tlsRange;
        uint* _p_TP_beg;
        uint* _p_TP_end;
    }
    Array!(ThreadDllTlsData) _tlsRanges;
    
    /****
    * Boolean flag set to true while the runtime is initialized.
    */
    __gshared bool _isRuntimeInitialized;
    
    void initSections() nothrow @nogc
    {
        _isRuntimeInitialized = true;
        
        //PR Review - Rainers - Is this the correct place to call scanDataSegPrecisely ?
        import rt.sections;
        conservative = !scanDataSegPrecisely();
        
        // The remaining initSections code in the shared library case is in _d_dll_registry_register which is called from cmain / DllMain
    }
    
    void finiSections() nothrow @nogc
    {
        foreach(ref section; _sections)
        {
            .free(cast(void*)section.modules.ptr);
            .free(section._gcRanges.ptr);
        }
        _sections.reset();
        _isRuntimeInitialized = false;
    }
    
    Array!(ThreadDllTlsData)* initTLSRanges() nothrow @nogc
    {
        static import rt.dllinit;
        // Insert the tls range for druntime
        _tlsRanges.insertBack(ThreadDllTlsData(null, rt.dllinit.initTLSRanges(), &_TP_beg, &_TP_end));       

        // iterate over all already loaded dlls and insert their TLS sections as well.
        // The executable is treated as a dll.
        foreach(ref section; _sections)
        {
            if(section._getTlsRange !is null)
                _tlsRanges.insertBack(ThreadDllTlsData(section._hModule, section._getTlsRange(), section._p_TP_beg, section._p_TP_end));
        }
        
        return &_tlsRanges;
    }

    void finiTLSRanges(Array!(ThreadDllTlsData)* tlsRanges) nothrow @nogc
    {
        _tlsRanges.reset();
    }
    
    void scanTLSRanges(Array!(ThreadDllTlsData)* tlsRanges, scope ScanDG dg) nothrow
    {
        foreach (ref r; *tlsRanges)
        {
            scanTLSRangesImpl(r._tlsRange, dg, r._p_TP_beg, r._p_TP_end);
        }
    }

    private __gshared Array!(SectionGroup) _sections;
}
else
{    
    void initSections() nothrow @nogc
    {
        _sections._moduleGroup = ModuleGroup(getModuleInfos(&_minfo_beg, &_minfo_end));
    
        // the ".data" image section includes both object file sections ".data" and ".bss"
        void[] dataSection = findImageSection(".data");
        debug(PRINTF) printf("found .data section: [%p,+%llx]\n", dataSection.ptr,
                             cast(ulong)dataSection.length);

        import rt.sections;
        conservative = !scanDataSegPrecisely();

        _sections._gcRanges = getGcRanges(dataSection, &_DP_beg, &_DP_end, conservative);
    }

    void finiSections() nothrow @nogc
    {
        .free(cast(void*)_sections.modules.ptr);
        .free(_sections._gcRanges.ptr);
    }

    void[] initTLSRanges() nothrow @nogc
    {
        static import rt.dllinit;
        return rt.dllinit.initTLSRanges();
    }

    void finiTLSRanges(void[] rng) nothrow @nogc
    {
    }

    void scanTLSRanges(void[] rng, scope ScanDG dg) nothrow
    {
        scanTLSRangesImpl(rng, dg, &_TP_beg, &_TP_end);
    }
    
    private __gshared SectionGroup _sections;
}

private:
extern(C)
{
    extern __gshared void* _minfo_beg;
    extern __gshared void* _minfo_end;
}

immutable(ModuleInfo*)[] getModuleInfos(void* pminfo_beg, void* pminfo_end) nothrow @nogc
out (result)
{
    foreach(m; result)
        assert(m !is null);
}
do
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

void[][] getGcRanges(void[] dataSection, uint* p_DP_beg, uint* p_DP_end, bool conservative) @nogc nothrow
{
    void[][] result;
    if (conservative)
    {
        result = (cast(void[]*) malloc((void[]).sizeof))[0..1];
        result[0] = dataSection;
    }
    else
    {
        size_t count = p_DP_end - p_DP_beg;
        auto ranges = cast(void[]*) malloc(count * (void[]).sizeof);
        size_t r = 0;
        void* prev = null;
        for (size_t i = 0; i < count; i++)
        {
            auto off = (p_DP_beg)[i];
            if (off == 0) // skip zero entries added by incremental linking
                continue; // assumes there is no D-pointer at the very beginning of .data
            void* addr = dataSection.ptr + off;
            debug(PRINTF) printf("  scan %p\n", addr);
            // combine consecutive pointers into single range
            if (prev + (void*).sizeof == addr)
                ranges[r-1] = ranges[r-1].ptr[0 .. ranges[r-1].length + (void*).sizeof];
            else
                ranges[r++] = (cast(void**)addr)[0..1];
            prev = addr;
        }
        result = ranges[0..r];
    }
    return result;
}

void scanTLSRangesImpl(void[] rng, scope ScanDG dg, uint* p_TP_beg, uint* p_TP_end) nothrow
{
    if (conservative)
    {
        dg(rng.ptr, rng.ptr + rng.length);
    }
    else
    {
        for (auto p = p_TP_beg; p < p_TP_end; )
        {
            uint beg = *p++;
            uint end = beg + cast(uint)((void*).sizeof);
            while (p < p_TP_end && *p == end)
            {
                end += (void*).sizeof;
                p++;
            }
            dg(rng.ptr + beg, rng.ptr + end);
        }
    }
}

extern(C)
{
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
}

/////////////////////////////////////////////////////////////////////

enum IMAGE_DOS_SIGNATURE = 0x5A4D;      // MZ

struct IMAGE_DOS_HEADER // DOS .EXE header
{
    ushort   e_magic;    // Magic number
    ushort[29] e_res2;   // Reserved ushorts
    int      e_lfanew;   // File address of new exe header
}

struct IMAGE_FILE_HEADER
{
    ushort Machine;
    ushort NumberOfSections;
    uint   TimeDateStamp;
    uint   PointerToSymbolTable;
    uint   NumberOfSymbols;
    ushort SizeOfOptionalHeader;
    ushort Characteristics;
}

struct IMAGE_NT_HEADERS
{
    uint Signature;
    IMAGE_FILE_HEADER FileHeader;
    // optional header follows
}

struct IMAGE_SECTION_HEADER
{
    char[8] Name;
    union {
        uint   PhysicalAddress;
        uint   VirtualSize;
    }
    uint   VirtualAddress;
    uint   SizeOfRawData;
    uint   PointerToRawData;
    uint   PointerToRelocations;
    uint   PointerToLinenumbers;
    ushort NumberOfRelocations;
    ushort NumberOfLinenumbers;
    uint   Characteristics;
}

bool compareSectionName(ref IMAGE_SECTION_HEADER section, string name) nothrow @nogc
{
    if (name[] != section.Name[0 .. name.length])
        return false;
    return name.length == 8 || section.Name[name.length] == 0;
}

void[] findImageSection(string name) nothrow @nogc
{
  return findImageSection(&__ImageBase, name);
}

private void[] findImageSection(void* p__ImageBase, string name) nothrow @nogc
{
    if (name.length > 8) // section name from string table not supported
        return null;
    IMAGE_DOS_HEADER* doshdr = cast(IMAGE_DOS_HEADER*) p__ImageBase;
    if (doshdr.e_magic != IMAGE_DOS_SIGNATURE)
        return null;

    auto nthdr = cast(IMAGE_NT_HEADERS*)(cast(void*)doshdr + doshdr.e_lfanew);
    auto sections = cast(IMAGE_SECTION_HEADER*)(cast(void*)nthdr + IMAGE_NT_HEADERS.sizeof + nthdr.FileHeader.SizeOfOptionalHeader);
    for(ushort i = 0; i < nthdr.FileHeader.NumberOfSections; i++)
        if (compareSectionName (sections[i], name))
            return (cast(void*)p__ImageBase + sections[i].VirtualAddress)[0 .. sections[i].VirtualSize];

    return null;
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

public:
    export void registerDll(void* hModule, void* pdllrl_beg, void* pdllrl_end, void* pminfo_beg, void* pminfo_end, void* pdeh_beg, void* pdeh_end, void* p__ImageBase, uint* p_DP_beg, uint* p_DP_end, uint* p_TP_beg, uint* p_TP_end, GetTlsRangeDG getTlsRange)
    {
        // First relocate all pointers in data sections
        {
            void** begin = cast(void**)pdllrl_beg;
            void** end = cast(void**)pdllrl_end;
            void** outer = begin;
            while(outer < end && *outer is null) outer++; // skip leading 0s
            while(outer < end)
            {
                if(*outer !is null) // skip any padding
                {
                    // The address is stored as a 32-bit offset
                    int* start = cast(int*)outer;
                    int relAddress = (*start) + 4; // take size of the offset into account as well
                    int offset = *(start+1);
                    void** reconstructedAddress = cast(void**)(cast(void*)start + relAddress);
                    debug(PRINTF) printf("patching %p to %p (offset %d)\n", reconstructedAddress, (**cast(void***)reconstructedAddress), offset);
                    *reconstructedAddress = (**cast(void***)reconstructedAddress) + offset;
                    outer += 8 / (void*).sizeof;
                }
                else
                {
                    outer++;
                }
            }
        }
    
        {
            SectionGroup dllSection;
            dllSection._moduleGroup = ModuleGroup(getModuleInfos(pminfo_beg, pminfo_end));
            dllSection._getTlsRange = getTlsRange;
            dllSection._p_TP_beg = p_TP_beg;
            dllSection._p_TP_end = p_TP_end;
            dllSection._hModule = hModule;
            
            void[] dataSection = findImageSection(p__ImageBase, ".data");
            dllSection._gcRanges = getGcRanges(dataSection, p_DP_beg, p_DP_end, conservative);
        
            version(Win64)
            {
                auto pbeg = cast(immutable(FuncTable)*)pdeh_beg;
                auto pend = cast(immutable(FuncTable)*)pdeh_end;
                dllSection._ehTables = pbeg[0 .. pend - pbeg];
            }    
        
            // need to insert the new section before initializing it
            // one of the module ctors might iterate the module infos
            _sections.insertBack(dllSection);
        }

        if(_isRuntimeInitialized)
        {
            SectionGroup* dllSection = &_sections.back();

            // Add tls range
            if(dllSection._getTlsRange !is null)
                _tlsRanges.insertBack(ThreadDllTlsData(dllSection._hModule, dllSection._getTlsRange(), dllSection._p_TP_beg, dllSection._p_TP_end));
                
            // register GC ranges
            registerGCRanges(*dllSection);
        
            // Run Module Constructors
            dllSection._moduleGroup.sortCtors();
            dllSection._moduleGroup.runCtors();
            dllSection._moduleGroup.runTlsCtors();
        }
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
            SectionGroup* dllSection = &_sections[i];

            if(_isRuntimeInitialized)
            {
                // Run Module Destructors
                dllSection._moduleGroup.runTlsDtors();  
                dllSection.moduleGroup.runDtors();
                dllSection.moduleGroup.free();        
                
                // unregister GC ranges
                unregisterGCRanges(*dllSection);
                
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
            .free(dllSection._gcRanges.ptr);
            _sections.remove(i);
        }
    }
}
