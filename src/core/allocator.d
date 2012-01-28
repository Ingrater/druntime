module core.allocator;

import core.stdc.stdlib;
import core.stdc.stdio;
import core.sync.mutex;
import core.hashmap;
import core.refcounted;

version(DUMA)
{
  extern(C)
  {
    //void * _duma_allocate(size_t alignment, size_t userSize, int protectBelow, int fillByte, int protectAllocList, enum _DUMA_Allocator allocator, enum _DUMA_FailReturn fail, const char * filename, int lineno);
    //void   _duma_deallocate(void * baseAdr, int protectAllocList, enum _DUMA_Allocator allocator, const char * filename, int lineno);
    void * _duma_malloc(size_t size, const char * filename, int lineno);
    void * _duma_calloc(size_t elemCount, size_t elemSize, const char * filename, int lineno);
    void   _duma_free(void * baseAdr, const char * filename, int lineno);
    void * _duma_memalign(size_t alignment, size_t userSize, const char * filename, int lineno);
    int    _duma_posix_memalign(void **memptr, size_t alignment, size_t userSize, const char * filename, int lineno);
    void * _duma_realloc(void * baseAdr, size_t newSize, const char * filename, int lineno);
    void * _duma_valloc(size_t size, const char * filename, int lineno);
    char * _duma_strdup(const char *str, const char * filename, int lineno);
    void * _duma_memcpy(void *dest, const void *src, size_t size, const char * filename, int lineno);
    char * _duma_strcpy(char *dest, const char *src, const char * filename, int lineno);
    char * _duma_strncpy(char *dest, const char *src, size_t size, const char * filename, int lineno);
    char * _duma_strcat(char *dest, const char *src, const char * filename, int lineno);
    char * _duma_strncat(char *dest, const char *src, size_t size, const char * filename, int lineno);
  }
}

extern (C) void rt_finalize(void *data, bool det=true);

version(Windows)
{
  import core.sys.windows.stacktrace;
}

enum InitializeMemoryWith
{
  NOTHING,
  NULL,
  INIT
}

private struct PointerHashPolicy
{
  static size_t Hash(void* ptr)
  {
    //Usually pointers are at least 4 byte aligned if they come out of a allocator
    return (cast(size_t)ptr) / 4;
  }
}

private {
  extern(C) void _initMemoryTracking()
  {
    StdAllocator.InitMemoryTracking();
  }

  extern(C) void _deinitMemoryTracking()
  {
    StdAllocator.DeinitMemoryTracking();
  }
}

private struct TrackingAllocator
{
  static void* AllocateMemory(size_t size, size_t alignment = 0)
  {
    version(DUMA)
      return _duma_memalign(size_t.sizeof,size,__FILE__,__LINE__);
    else
      return malloc(size);
  }
  
  static void* RellocateMemory(void* mem, size_t size)
  {
    version(DUMA)
    {
      void* temp = _duma_realloc(mem,size,__FILE__,__LINE__);
      assert(cast(size_t)temp / size_t.sizeof == 0,"alignment changed");
      return temp;
    }
    else
      return realloc(mem,size);
  }
  
  static void FreeMemory(void* mem)
  {
    version(DUMA)
      return _duma_free(mem,__FILE__,__LINE__);
    else
      free(mem);
  }
}

struct StdAllocator 
{
  struct MemoryBlockInfo
  {
    size_t size;
    long[10] backtrace;
    int backtraceSize;
    
    this(size_t size)
    {
      this.size = size;
    }
  }

  //this should return NULL when the standard allocator should be used
  //if this does not return NULL the returned memory is used instead
  //Needs to be thread safe !
  alias void* delegate(size_t size, size_t alignment) OnAllocateMemoryDelegate;

  //This should return true if it frees the memory, otherwise the standard allocator will free it
  //Needs to be thread safe !
  alias bool delegate(void* ptr) OnFreeMemoryDelegate;

  //This should return NULL if it did not reallocate the memory
  //otherwise the standard allocator will reallocate the memory
  //Needs to be thread safe !
  alias void* delegate(void* ptr, size_t newSize) OnReallocateMemoryDelegate;

  
  private __gshared Mutex m_allocMutex;
  private __gshared Hashmap!(void*, MemoryBlockInfo, PointerHashPolicy, TrackingAllocator) m_memoryMap;
  __gshared OnAllocateMemoryDelegate OnAllocateMemoryCallback;
  __gshared OnFreeMemoryDelegate OnFreeMemoryCallback;
  __gshared OnReallocateMemoryDelegate OnReallocateMemoryCallback;

  
  static void InitMemoryTracking()
  {
    printf("initializing memory tracking\n");
    m_memoryMap = New!(typeof(m_memoryMap))();
    m_allocMutex = New!Mutex();
  }
  
  static void DeinitMemoryTracking()
  {
    //Set the allocation mutex to null so that any allocations that happen during
    //resolving don't get added to the hashmap to prevent recursion and changing of
    //the hashmap while it is in use
    auto temp = m_allocMutex;
    m_allocMutex = null;
    
    printf("deinitializing memory tracking\n");
    printf("Found %d memory leaks",m_memoryMap.count);
    foreach(ref leak; m_memoryMap)
    {
      printf("---------------------------------\n");
      printf("memory leak %d bytes\n",leak.size);
      auto trace = StackTrace.resolveAddresses(leak.backtrace);
      foreach(ref line; trace)
      {
        line ~= "\0";
        printf("%s\n",line.ptr);
      }
    }
    Delete(temp);
    Delete(m_memoryMap);
  }
  
  static void* AllocateMemory(size_t size, size_t alignment = 0)
  {
    void* mem = (OnFreeMemoryCallback is null) ? null : OnAllocateMemoryCallback(size,alignment);
    if(mem is null)
    {
      version(DUMA)
        mem = _duma_memalign(size_t.sizeof,size,__FILE__,__LINE__);
      else
        mem = malloc(size);
    }
    if(m_allocMutex !is null)
    {
      synchronized(m_allocMutex)
      {
        //printf("adding %x (%d)to memory map\n",mem,size);
        auto info = MemoryBlockInfo(size);
        // TODO implement for linux / osx
        version(Windows)
        {
          info.backtraceSize = StackTrace.traceAddresses(info.backtrace,false).length;
        }
        auto map = m_memoryMap;
        map[mem] = info;
      }
    }
    return mem;
  }
  
  static void* ReallocateMemory(void* ptr, size_t size)
  {
    if( m_allocMutex !is null)
    {
      synchronized( m_allocMutex )
      {
        size_t oldSize = 0;
        if(ptr !is null)
        {
          assert( m_memoryMap.exists(ptr), "trying to realloc already freed memory");
          oldSize = m_memoryMap[ptr].size;
          assert( oldSize < size, "trying to realloc smaller size");
        }

        void *mem = (OnReallocateMemoryCallback is null) ? null : OnReallocateMemoryCallback(ptr,size);

        if(mem is null)
        {      
          version(DUMA)
          {
            mem = _duma_memalign(size_t.sizeof,size,__FILE__,__LINE__);
            if( ptr !is null)
            {
              _duma_memcpy(mem,ptr,oldSize,__FILE__,__LINE__);
              _duma_free(ptr,__FILE__,__LINE__);
            }
          }
          else
          {
            mem = realloc(ptr,size);
          }
        }
        
        if(mem != ptr)
        {
          if(ptr !is null)
          {
            //printf("realloc removing %x\n",ptr);
            m_memoryMap.remove(ptr);
          }
          auto info = MemoryBlockInfo(size);
          // TODO implement for linux / osx
          version(Windows)
          {
            info.backtraceSize = StackTrace.traceAddresses(info.backtrace,false,0).length;
          }

          //printf("realloc adding %x(%d)\n",mem,size);
          m_memoryMap[mem] = info;        
        }
        else
        {
          //printf("changeing size of %x to %d\n",mem,size);
          m_memoryMap[mem].size = size;
        }
        return mem;
      }
    }

    void *mem = (OnReallocateMemoryCallback is null) ? null : OnReallocateMemoryCallback(ptr,size);
    if(mem is null)
    {
      version(DUMA)
      {
        throw new Error("Nested duma reallocate");
      }
      else
      {
        mem = realloc(ptr,size);
      }
    }
    return mem;
  }
  
  static void FreeMemory(void* ptr)
  {
    if( ptr !is null)
    {
      if( m_allocMutex !is null)
      {
        synchronized( m_allocMutex )
        {
          //printf("removing %x from memory map\n",ptr);
          assert( m_memoryMap.exists(ptr), "double free");
          m_memoryMap.remove(ptr);
        }
      }
    }
    if(OnFreeMemoryCallback is null || !OnFreeMemoryCallback(ptr))
    {
      version(DUMA)
        _duma_free(ptr,__FILE__,__LINE__);
      else
        free(ptr);
    }
  }
}

auto New(T,ARGS...)(ARGS args)
{
  return AllocatorNew!(T,StdAllocator,ARGS)(args);
}

auto AllocatorNew(T,AT,ARGS...)(ARGS args)
{
  static if(is(T == class))
  {
    size_t memSize = __traits(classInstanceSize,T);
  } 
  else {
    size_t memSize = T.sizeof;
  }
  
  void *mem = AT.AllocateMemory(memSize);
  assert(mem !is null,"Out of memory");
  auto address = cast(size_t)mem;
  assert(address % T.alignof == 0,"Missaligned memory");  
  
  //initialize
  static if(is(T == class))
  {
    void[] blop = mem[0..memSize];
    (cast(byte[])blop)[] = typeid(T).init[];
    auto result = (cast(T)mem);
    static if(is(typeof(result.__ctor(args))))
    {
      result.__ctor(args);
    }
    else
    {
      static assert(args.length == 0 && !is(typeof(&T.__ctor)),
                "Don't know how to initialize an object of type "
                ~ T.stringof ~ " with arguments " ~ Args.stringof);
    }
    
    static if(is(T : RefCountedBase))
    {
      return SmartPtr!T(result);
    }
    else {
      return result;
    }
  }
  else
  {
    *(cast(T*)mem) = T.init;
    auto result = (cast(T*)mem);
    static if(ARGS.length > 0 && is(typeof(result.__ctor(args))))
    {
      result.__ctor(args);
    }
    else static if(ARGS.length > 0)
    {
      static assert(args.length == 0 && !is(typeof(&T.__ctor)),
                "Don't know how to initialize an object of type "
                ~ T.stringof ~ " with arguments " ~ Args.stringof);
    }
    return result;
  }
}

void Delete(T)(T mem)
{
  AllocatorDelete!(T,StdAllocator)(mem);
}

void AllocatorDelete(T,AT)(T obj)
{
  static if(is(T == class))
  {
    rt_finalize(cast(void*)obj);
    AT.FreeMemory(cast(void*)obj);
  }
  else static if(is(T P == U*, U))
  {
    static if(is(U == struct) && is(typeof(obj.__dtor())))
    {
      obj.__dtor();
    }
    AT.FreeMemory(cast(void*)obj);
  }
  else static if(is(T P == U[], U))
  {
    static if(is(U == struct) && is(typeof(obj[0].__dtor())))
    {
      foreach(ref e; obj)
      {
        e.__dtor();
      }
    }
  
    AT.FreeMemory(cast(void*)obj.ptr);    
  }
}

auto NewArray(T)(size_t size, InitializeMemoryWith init = InitializeMemoryWith.INIT){
  return AllocatorNewArray!(T,StdAllocator)(size,init);
}

auto AllocatorNewArray(T,AT)(size_t size, InitializeMemoryWith init = InitializeMemoryWith.INIT)
{
  size_t memSize = T.sizeof * size;
  void* mem = AT.AllocateMemory(memsize);
  
  T[] data = (cast(T*)mem)[0..size];
  final switch(init)
  {
    case InitializeMemoryWith.NOTHING:
      break;
    case InitializeMemoryWith.INIT:
      static if(is(T == struct))
      {
        T temp;
        foreach(ref e;data)
        {
          memcpy(&e,&temp,T.sizeof);
        }
      }
      else 
      {
        foreach(ref e; data)
        {
          e = T.init;
        }
      }
      break;
    case InitializeMemoryWith.NULL:
      memset(mem,0,memsize);
      break;
  }
  return data;
}