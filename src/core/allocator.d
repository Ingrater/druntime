module core.allocator;

import core.stdc.stdlib;
import core.stdc.stdio;
import core.sync.mutex;
import core.stdc.string; //for memcpy
import core.hashmap;
import core.refcounted;
import core.traits;

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

struct PointerHashPolicy
{
  static size_t Hash(void* ptr)
  {
    //Usually pointers are at least 4 byte aligned if they come out of a allocator
    return (cast(size_t)ptr) / 4;
  }
}

private {

  extern(C) void _initStdAllocator()
  {
    g_stdAllocatorMem[] = typeid(StdAllocator).init[];
    g_stdAllocator = cast(StdAllocator)g_stdAllocatorMem.ptr;
    static if(is(typeof(g_stdAllocator.__ctor())))
    {
      g_stdAllocator.__ctor();
    }
  }

  extern(C) void _initMemoryTracking()
  {
    StdAllocator.globalInstance.InitMemoryTracking();
  }

  extern(C) void _deinitMemoryTracking()
  {
    StdAllocator.globalInstance.DeinitMemoryTracking();
    Destruct(g_stdAllocator);
  }
}

interface IAllocator
{
  /**
   * allocates a block of memory
   * Params:
   *   size = the size in bytes to allocate
   * Returns: the allocated block of memory or a empty array if allocation failed
   */
  void[] AllocateMemory(size_t size);

  /**
   * Frees a block of memory
   * Params:
   *   mem = pointer to the start of the memory block to free
   */
  void FreeMemory(void* mem);
}

interface IAdvancedAllocator : IAllocator
{
  /**
  * tries to resize a block of memory, if not possible allocates a new block and copies all data to it
  * Params:
  *   mem = pointer to the block of memory which should be resized
  *   size = new size the block should have in bytes
  */
  void[] ReallocateMemory(void* mem, size_t size);
}

private class TrackingAllocator : IAdvancedAllocator
{
  final void[] AllocateMemory(size_t size)
  {
    version(DUMA)
      return _duma_memalign(size_t.sizeof,size,__FILE__,__LINE__);
    else
      return malloc(size)[0..size];
  }
  
  final void[] ReallocateMemory(void* mem, size_t size)
  {
    version(DUMA)
    {
      void* temp = _duma_realloc(mem,size,__FILE__,__LINE__);
      assert(cast(size_t)temp / size_t.sizeof == 0,"alignment changed");
      return temp;
    }
    else
      return realloc(mem,size)[0..size];
  }
  
  final void FreeMemory(void* mem)
  {
    version(DUMA)
      return _duma_free(mem,__FILE__,__LINE__);
    else
      free(mem);
  }
}

private TrackingAllocator g_trackingAllocator;

class StdAllocator : IAdvancedAllocator
{
  alias g_stdAllocator globalInstance;
  enum size_t alignment = 4; //default alignment 4 byte

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

  
  private Mutex m_allocMutex;
  private Hashmap!(void*, MemoryBlockInfo, PointerHashPolicy, TrackingAllocator) m_memoryMap;
  OnAllocateMemoryDelegate OnAllocateMemoryCallback;
  OnFreeMemoryDelegate OnFreeMemoryCallback;
  OnReallocateMemoryDelegate OnReallocateMemoryCallback;

  
  final void InitMemoryTracking()
  {
    printf("initializing memory tracking\n");
    g_trackingAllocator = New!TrackingAllocator();
    m_memoryMap = AllocatorNew!(typeof(m_memoryMap), TrackingAllocator)(g_trackingAllocator, g_trackingAllocator);
    m_allocMutex = New!Mutex();
  }
  
  final void DeinitMemoryTracking()
  {
    //Set the allocation mutex to null so that any allocations that happen during
    //resolving don't get added to the hashmap to prevent recursion and changing of
    //the hashmap while it is in use
    auto temp = m_allocMutex;
    m_allocMutex = null;
    
    printf("deinitializing memory tracking\n");
    printf("Found %d memory leaks",m_memoryMap.count);
    FILE* log = null;
    void* min = null;
    void* max = null;
    if(m_memoryMap.count > 0)
      log = fopen("memoryleaks.log","wb");
    foreach(ref void* addr, ref leak; m_memoryMap)
    {
      printf("---------------------------------\n");
      if(log !is null) fprintf(log,"---------------------------------\n");
      printf("memory leak %d bytes\n",leak.size);
      if(log !is null) fprintf(log,"memory leak %d bytes\n",leak.size);
      auto trace = StackTrace.resolveAddresses(leak.backtrace);
      foreach(ref line; trace)
      {
        line ~= "\0";
        printf("%s\n",line.ptr);
        if(log !is null) fprintf(log, "%s\n",line.ptr);
      }

      if(min == null)
      {
        min = addr;
        max = addr;
      }
      else
      {
        min = (min > addr) ? addr : min;
        max = (max < addr) ? addr : max;
      }
    }

    if( m_memoryMap.count > 0)
    {
      //find root leaks
      auto nonRootMap = AllocatorNew!(Hashmap!(void*, bool, PointerHashPolicy, TrackingAllocator), TrackingAllocator)(g_trackingAllocator, g_trackingAllocator);
      
      foreach(void* addr, ref leak; m_memoryMap)
      {
        void*[] ptrs = (cast(void**)addr)[0..(leak.size / (void*).sizeof)];
        foreach(ptr; ptrs)
        {
          if(ptr >= min && ptr <= max && cast(size_t)ptr % 4 == 0)
          {
            if(m_memoryMap.exists(ptr))
            {
              nonRootMap[ptr] = true;
            }
          }
        }
      }

      if(m_memoryMap.count > nonRootMap.count)
      {
        printf("---------------------------------\n");
        printf("ROOTS\n");
        if(log !is null)
        {
          fprintf(log, "---------------------------------\n");
          fprintf(log, "ROOTS\n");
        }
        foreach(void* addr, ref leak; m_memoryMap)
        {
          if(nonRootMap.exists(addr)) //skip non roots
            continue;
          printf("---------------------------------\n");
          if(log !is null) fprintf(log,"---------------------------------\n");
          printf("memory leak %d bytes\n",leak.size);
          if(log !is null) fprintf(log,"memory leak %d bytes\n",leak.size);
          auto trace = StackTrace.resolveAddresses(leak.backtrace);
          foreach(ref line; trace)
          {
            line ~= "\0";
            printf("%s\n",line.ptr);
            if(log !is null) fprintf(log, "%s\n",line.ptr);
          }
        }
      }

      Delete(nonRootMap);

      //close logfile
      if(log !is null) fclose(log);
      debug
      {
        asm { int 3; }
      }
    }
    Delete(temp);
    Delete(m_memoryMap);
    Delete(g_trackingAllocator);
  }
  
  final void[] AllocateMemory(size_t size)
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
          info.backtraceSize = StackTrace.traceAddresses(info.backtrace,false,3).length;
        }
        auto map = m_memoryMap;
        map[mem] = info;
      }
    }
    return mem[0..size];
  }
  
  final void[] ReallocateMemory(void* ptr, size_t size)
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
        return mem[0..size];
      }
    }

    void *mem = (OnReallocateMemoryCallback is null) ? null : OnReallocateMemoryCallback(ptr,size);
    if(mem is null)
    {
      version(DUMA)
      {
        throw New!Error("Nested duma reallocate");
      }
      else
      {
        mem = realloc(ptr,size);
      }
    }
    return mem[0..size];
  }
  
  final void FreeMemory(void* ptr)
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

__gshared StdAllocator g_stdAllocator;
__gshared void[__traits(classInstanceSize, StdAllocator)] g_stdAllocatorMem = void;

auto New(T,ARGS...)(ARGS args)
{
  return AllocatorNew!(T,StdAllocator,ARGS)(StdAllocator.globalInstance, args);
}

string ListAvailableCtors(T)()
{
  string result = "";
  foreach(t; __traits(getOverloads, T, "__ctor"))
    result ~= typeof(t).stringof ~ "\n";
  return result;
}

auto AllocatorNew(T,AT,ARGS...)(AT allocator, ARGS args)
{
  static if(is(T == class))
  {
    size_t memSize = __traits(classInstanceSize,T);
  } 
  else {
    size_t memSize = T.sizeof;
  }
  
  void[] mem = allocator.AllocateMemory(memSize);
  assert(mem.ptr !is null,"Out of memory");
  auto address = cast(size_t)mem.ptr;
  assert(address % T.alignof == 0,"Missaligned memory");  
  
  //initialize
  static if(is(T == class))
  {
    auto ti = typeid(StripModifier!T);
    assert(memSize == ti.init.length,"classInstanceSize and typeid(T).init.length do not match");
    mem[] = (cast(void[])ti.init)[];
    auto result = (cast(T)mem.ptr);
    static if(is(typeof(result.__ctor(args))))
    {
      result.__ctor(args);
    }
    else
    {
      static assert(args.length == 0 && !is(typeof(&T.__ctor)),
                "Don't know how to initialize an object of type "
                ~ T.stringof ~ " with arguments:\n" ~ ARGS.stringof ~ "\nAvailable ctors:\n" ~ ListAvailableCtors!T() );
    }
    
    static if(is(T : RefCounted))
    {
      result.SetAllocator(allocator);
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
                ~ T.stringof ~ " with arguments " ~ args.stringof ~ "\nAvailable ctors:\n" ~ ListAvailableCtors!T() );
    }
    return result;
  }
}

/**
 * Deletes an object / array and destroys it
 */
void Delete(T)(T mem)
{
  AllocatorDelete!(T,StdAllocator)(StdAllocator.globalInstance, mem);
}

/**
 * Frees the memory pointed at by the object / array
 */
void Free(T)(T mem)
{
  AlloactorFree!(T,StdAllocator)(StdAllocator.globalInstance, mem);
}

void Destruct(Object obj)
{
  rt_finalize(cast(void*)obj);
}

struct DefaultCtor {}; //call default ctor type

struct composite(T)
{
  static assert(is(T == class),"can only composite classes");
  void[__traits(classInstanceSize, T)] _classMemory = void;
  bool m_destructed = false;

  @property T _instance()
  {
    return cast(T)_classMemory.ptr;
  }

  alias _instance this;

  @disable this();
  @disable this(this); //prevent evil stuff from happening

  this(DefaultCtor c){ };

  void construct(ARGS...)(ARGS args) //TODO fix: workaround because constructor can not be a template
  {
    _classMemory[] = typeid(T).init[];
    T result = (cast(T)_classMemory.ptr);
    static if(ARGS.length == 1 && is(ARGS[0] == DefaultCtor))
    {
      static if(is(typeof(result.__ctor())))
      {
        result.__ctor();
      }
      else
      {
        static assert(0,T.stringof ~ " does not have a default constructor");
      }
    }
    else {
      static if(is(typeof(result.__ctor(args))))
      {
        result.__ctor(args);
      }
      else
      {
        static assert(args.length == 0 && !is(typeof(&T.__ctor)),
                      "Don't know how to initialize an object of type "
                      ~ T.stringof ~ " with arguments:\n" ~ ARGS.stringof ~ "\nAvailable ctors:\n" ~ ListAvailableCtors!T() );
      }
    }
  }

  void destruct()
  {
    assert(!m_destructed);
    Destruct(_instance);
    m_destructed = true;
  }

  ~this()
  {
    if(!m_destructed)
    {
      Destruct(_instance);
      m_destructed = true;
    }
  }
}

void AllocatorDelete(T,AT)(AT allocator, T obj)
{
  static assert(!is(T U == composite!U), "can not delete composited instance");
  static if(is(T == class))
  {
    if(obj is null)
      return;
    rt_finalize(cast(void*)obj);
    allocator.FreeMemory(cast(void*)obj);
  }
  else static if(is(T == interface))
  {
    if(obj is null)
      return;
    Object realObj = cast(Object)obj;
    if(realObj is null)
      return;
    rt_finalize(cast(void*)realObj);
    allocator.FreeMemory(cast(void*)realObj);
  }
  else static if(is(T P == U*, U))
  {
    if(obj is null)
      return;
    callDtor(obj);
    allocator.FreeMemory(cast(void*)obj);
  }
  else static if(is(T P == U[], U))
  {
    if(!obj)
      return;
    callDtor(obj);
    allocator.FreeMemory(cast(void*)obj.ptr);    
  }
}

void AllocatorFree(T,AT)(AT allocator, T obj)
{
  static assert(!is(T U == composite!U), "can not free composited instance");
  static if(is(T == class))
  {
    if(obj is null)
      return;
    allocator.FreeMemory(cast(void*)obj);
  }
  else static if(is(T P == U*, U))
  {
    if(obj is null)
      return;
    allocator.FreeMemory(cast(void*)obj);
  }
  else static if(is(T P == U[], U))
  {
    if(!obj)
      return;
    allocator.FreeMemory(cast(void*)obj.ptr);    
  }
}

auto NewArray(T)(size_t size, InitializeMemoryWith init = InitializeMemoryWith.INIT){
  return AllocatorNewArray!(T,StdAllocator)(StdAllocator.globalInstance, size,init);
}

auto AllocatorNewArray(T,AT)(AT allocator, size_t size, InitializeMemoryWith init = InitializeMemoryWith.INIT)
{
  size_t memSize = T.sizeof * size;
  void* mem = allocator.AllocateMemory(memSize).ptr;
  
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
      memset(mem,0,memSize);
      break;
  }
  return data;
}

void callPostBlit(T)(T subject)
{
  static if(is(T U == V[], V))
  {
    static if(is(V == struct))
    {
      static if(is(typeof(subject[0].__postblit)))
      {
        foreach(ref el; subject)
        {
          el.__postblit();
        }
      }
    }
  }
  else static if(is(T P == U*, U))
  {
    static if(is(U == struct))
    {
      static if(is(typeof(subject.__postblit)))
      {
        subject.__postblit();
      }
    }
  }
  else
  {
    static if(is(T == struct))
    {
      static assert(0, "can not call postblit on copy");
    }
  }
}

void callDtor(T)(T subject)
{
  static if(is(T U == V[], V))
  {
    static if(is(V == struct))
    {
      auto typeinfo = typeid(V);
      if(typeinfo.xdtor !is null)
      {
        foreach(ref el; subject)
        {
          typeinfo.xdtor(&el);
        }
      }
      //TODO: structs are currently only destroyable over a typeinfo object, fix
      /*static if(is(typeof(subject[0].__fieldDtor)))
      {
        foreach(ref el; subject)
          el.__fieldDtor();
      }
      else static if(is(typeof(subject[0].__dtor)))
      {
        foreach(ref el; subject)
          el.__dtor();
      }*/
    }
  }
  else static if(is(T P == U*, U))
  {
    static if(is(U == struct))
    {
      auto typeinfo = typeid(U);
      if(typeinfo.xdtor !is null)
      {
        typeinfo.xdtor(subject);
      }
      //TODO: structs are currently only destroyable over a type info object, fix
      /*static if(is(typeof(subject.__fieldDtor)))
      {
        subject.__fieldDtor();
      }
      else static if(is(typeof(subject.__dtor)))
      {
        subject.__dtor();
      }*/
    }
  }
  else
  {
    static if(is(T == struct))
    {
      static assert(0, "can not destruct copy");
    }
  }
}

void uninitializedCopy(DT,ST)(DT dest, ST source) 
if(is(DT DBT == DBT[]) && is(ST SBT == SBT[]) 
   && is(StripModifier!DBT == StripModifier!SBT))
{
  assert(dest.length == source.length, "array lengths do not match");
  memcpy(dest.ptr,source.ptr,dest.length * typeof(*dest.ptr).sizeof);
  callPostBlit(dest);
}

void copy(DT,ST)(DT dest, ST source) 
if(is(DT DBT == DBT[]) && is(ST SBT == SBT[]) 
   && is(StripModifier!DBT == StripModifier!SBT))
{
  assert(dest.length == source.length, "array lengths do not match");
  callDtor(dest);
  memcpy(dest.ptr,source.ptr,dest.length * typeof(*dest.ptr).sizeof);
  callPostBlit(dest);
}


void uninitializedCopy(DT,ST)(ref DT dest, ref ST source) if(is(DT == struct) && is(DT == ST))
{
  memcpy(&dest,&source,DT.sizeof);
  static if(is(typeof(dest.__postblit)))
  {
    dest.__postblit();
  }
}

void uninitializedCopy(DT,ST)(ref DT dest, ref ST source) if(!is(DT == struct) && !is(DT U == U[]) && is(StripModifier!DT == StripModifier!ST))
{
  dest = source;
}

void uninitializedMove(DT,ST)(DT dest, ST source) 
if(is(DT DBT == DBT[]) && is(ST SBT == SBT[]) 
   && is(StripModifier!DBT == StripModifier!SBT))
{
  assert(dest.length == source.length, "array lengths do not match");
  memcpy(dest.ptr,source.ptr,dest.length * typeof(*dest.ptr).sizeof);
}