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

void fixupDataSymbols()
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
}