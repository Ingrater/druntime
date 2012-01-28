module core.refcounted;

public import core.allocator;
import core.atomic;
import core.stdc.string; // for memcpy
import core.traits;

abstract class RefCountedBase
{
private:
  int m_iRefCount = 0;
  
  final void AddReference()
  {
    atomicOp!"+="(m_iRefCount,1);
  }
  
  // RemoveRefernce needs to be private otherwise the invariant handler
  // gets called on a already destroyed and freed object
  final void RemoveReference()
  {
    int result = atomicOp!"-="(m_iRefCount,1);
    assert(result >= 0,"ref count is invalid");
    if(result == 0)
    {
      this.Release();
    }
  }
    
  final void AddReference() shared
  {
    (cast(RefCountedBase)this).AddReference();
  }
  
  final void RemoveReference() shared
  {
    (cast(RefCountedBase)this).RemoveReference();
  }

protected:
  // Release also needs to be private so that the invariant handler does not get
  // called on a already freed object
  abstract void Release();
  
  final void Release() shared
  {
    (cast(RefCountedBase)this).Release();
  }
  
public:
  @property final int refcount()
  {
    return m_iRefCount;
  }
}

abstract class RefCountedImpl(T) : RefCountedBase
{
public:
  alias T allocator_t;

protected:
  override void Release()
  {
    clear(this);
    T.FreeMemory(cast(void*)this);
  }
}

alias RefCountedImpl!StdAllocator RefCounted;

struct SmartPtr(T)
{
  static assert(is(T : RefCountedBase),T.stringof ~ " is not a reference counted object");
  
  T ptr;
  alias ptr this;
  alias typeof(this) this_t;
  
  this(T obj)
  {
    ptr = obj;
    ptr.AddReference();
  }
  
  this(const(T) obj) const
  {
    ptr = obj;
    (cast(T)ptr).AddReference();
  }
  
  this(immutable(T) obj) immutable
  {
    ptr = obj;
    (cast(T)ptr).AddReference();
  }
  
  this(this)
  {
    if(ptr !is null)
      ptr.AddReference();
  }
  
  ~this()
  {
    if(ptr !is null)
      ptr.RemoveReference();
  }
  
  static if(!is(typeof(null) == void*))
  {
    void opAssign(typeof(null) obj)
    {
      if(ptr !is null)
        ptr.RemoveReference();
      ptr = null;
    }
  }
  
  void opAssign(T obj)
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = obj;
    if(ptr !is null)
      ptr.AddReference();
  }
  
  void opAssign(shared(T) obj) shared
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = obj;
    if(ptr !is null)
      ptr.AddReference();
  }
  
  void opAssign(ref this_t rh)
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = rh.ptr;
    if(ptr !is null)
      ptr.AddReference();
  }
  
  void opAssign(ref shared(this_t) rh) shared
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = rh.ptr;
    if(ptr !is null)
      ptr.AddReference();
  }
}

final class RCArrayData(T,AT = StdAllocator) : RefCountedImpl!AT
{
private:
  T[] data;
  
  alias StripModifier!(T) BT; //Base Type

protected:

  static if(is(T == struct) && is(typeof(T.__dtor())))
  {
    ~this()
    {
      foreach(ref e; data)
      {
        e.__dtor();
      }
    }
  }
  
  static auto AllocateArray(InitializeMemoryWith meminit = InitializeMemoryWith.INIT)
                           (size_t size, bool doInit = true)
  {
    //TODO replace enforce
    //enforce(size > 0,"can not create a array of size 0");
    size_t headerSize = __traits(classInstanceSize,typeof(this));
    size_t bytesToAllocate = headerSize + (T.sizeof * size);
    void* mem = allocator_t.AllocateMemory(bytesToAllocate);
    auto address = cast(size_t)mem;
    assert(address % T.alignof == 0,"Missaligned array memory");
    void[] blop = mem[0..bytesToAllocate];
    
    //initialize header
    (cast(byte[]) blop)[0..headerSize] = typeid(typeof(this)).init[];
    auto result = cast(typeof(this))mem;
    
    static if(meminit == InitializeMemoryWith.NULL)
    {
      if(doInit)
        memset(mem + headerSize,0,bytesToAllocate - headerSize);
    }
    static if(meminit == InitializeMemoryWith.INIT)
    {
      if(doInit)
      {
        auto arrayData = (cast(BT*)(mem + headerSize))[0..size];
        foreach(ref BT e; arrayData)
        {
          // If it is a struct cant use the assignment operator
          // otherwise the assignment operator might work on a non initialized instance
          static if(is(BT == struct))
            memcpy(&e,&BT.init,BT.sizeof);
          else
            e = BT.init;
        }
      }
    }   
    
    result.data = (cast(T*)(mem + headerSize))[0..size];
    return result;
  }
  
  private @property final size_t length() immutable
  {
    return data.length;
  }
  
  final auto Resize(InitializeMemoryWith meminit = InitializeMemoryWith.INIT)
                   (size_t newSize, bool doInit = true)
  {
    assert(newSize > data.length,"can not resize to smaller size");
    
    size_t headerSize = __traits(classInstanceSize,typeof(this));
    size_t bytesToAllocate = headerSize + (T.sizeof * newSize);
    void* mem = allocator_t.ReallocateMemory(cast(void*)this,bytesToAllocate);
    
    auto result = cast(typeof(this))mem;
    
    static if(meminit == InitializeMemoryWith.NULL)
    {
      if(doInit)
        memset(mem + headerSize + result.m_Length * T.sizeof,0,
               bytesToAllocate - headerSize + result.m_Length * T.sizeof);
    }
    static if(meminit == InitializeMemoryWith.INIT)
    {
      if(doInit)
      {
        auto arrayData = (cast(BT*)(mem + headerSize))[result.data.length..newSize];
        foreach(ref BT e; arrayData)
        {
          // If it is a struct we can not use the assignment operator
          // as the assignment operator will be calle don a non initialized instance
          static if(is(BT == struct))
            memcpy(&e,&BT.init,T.sizeof);
          else
            e = BT.init;
        }
      }
    }   
    
    result.data = (cast(T*)(mem + headerSize))[0..newSize];
    return result;
  }
  
  private final auto opSlice()
  {
    return this.data;
  }
  
  private final auto opSlice() const
  {
    return this.data;
  }
  
  private final auto opSlice() immutable
  {
    return this.data;
  }
  
  private final auto opSlice() shared
  {
    return this.data;
  }
  
}

enum IsStatic {
  Yes
}

struct RCArray(T,AT = StdAllocator)
{
  alias RCArrayData!(T,AT) data_t;
  alias typeof(this) this_t;
  private data_t m_DataObject;
  private T[] m_Data;
  
  alias StripModifier!(T) BT; //base type
  
  
  this(size_t size){
    m_DataObject = data_t.AllocateArray(size);
    m_DataObject.AddReference();
    m_Data = m_DataObject.data;
  }

  static if(IsPOD!(BT))
  {
    this(T[] data, IsStatic isStatic)
    {
      assert(isStatic == IsStatic.Yes);
      m_Data = data;
      m_DataObject = null;
    }
  }
  
  private void ConstructFromArray(U)(U init) 
    if(is(U : BT[]) || is(U : immutable(BT)[]) || is(U : const(BT)[]))
  {
    m_DataObject = data_t.AllocateArray(init.length,false);
    m_DataObject.AddReference();
    m_Data = m_DataObject.data;
    auto mem = cast(BT[])m_Data;
    mem[] = cast(BT[])init[];
  }
  
  static if(IsPOD!(BT))
  {
  
    this(BT[] init) 
    {
      ConstructFromArray(init);
    }
    
    this(const(BT[]) init)
    {
      ConstructFromArray(init);
    }
    
    this(immutable(BT[]) init)
    {
      ConstructFromArray(init);
    }
  }
  else {
    this(T[] init)
    {
      ConstructFromArray(init);
    }
  }
  
  //post blit constructor
  this(this)
  {
    if(m_DataObject !is null)
      m_DataObject.AddReference();
  }
  
  this(ref immutable(this_t) rh) immutable
  {
    m_DataObject = rh.m_DataObject;
    if(m_DataObject !is null)
      (cast(data_t)m_DataObject).AddReference();
    m_Data = rh.m_Data;
  }
  
  this(ref const(this_t) rh) const
  {
    m_DataObject = rh.m_DataObject;
    if(m_DataObject !is null)
      (cast(data_t)m_DataObject).AddReference();
    m_Data = rh.m_Data;
  }
  
  private this(data_t data)
  {
    m_DataObject = data;
    m_DataObject.AddReference();
    m_Data = m_DataObject.data;
  }
  
  private this(data_t dataObject, T[] data)
  {
    m_DataObject = dataObject;
    if(m_DataObject !is null)
      m_DataObject.AddReference();
    m_Data = data;
  }
  
  private this(const(data_t) dataObject, const(T[]) data) const
  {
    m_DataObject = dataObject;
    if(m_DataObject !is null)
      (cast(data_t)m_DataObject).AddReference();
    m_Data = data;
  }
  
  private this(immutable(data_t) dataObject, immutable(T[]) data) immutable
  {
    m_DataObject = dataObject;
    if(m_DataObject !is null)
      (cast(data_t)m_DataObject).AddReference();
    m_Data = data;
  }
    
  ~this()
  {
    if(m_DataObject !is null)
      m_DataObject.RemoveReference();
  }
  
  // TODO replace this bullshit with a template once it is supported by dmd
  void opAssign(this_t rh)
  {
    if(m_DataObject !is null)
      m_DataObject.RemoveReference();
    m_DataObject = rh.m_DataObject;
    m_Data = rh.m_Data;
    if(m_DataObject !is null)
      m_DataObject.AddReference();
  }
  
  void opAssign(T[] rh)
  {
    if(m_DataObject !is null)
      m_DataObject.RemoveReference();
    auto newData = data_t.AllocateArray(rh.length,false);
    auto mem = cast(BT[])newData.data;
    mem[] = rh[];
    m_DataObject = newData;
    m_DataObject.AddReference();
    m_Data = newData.data;
  }
  
  static if(IsPOD!(BT) && !is(T == BT))
  {
    void opAssign(BT[] rh)
    {
      if(m_DataObject !is null)
        m_DataObject.RemoveReference();
      auto newData = data_t.AllocateArray(rh.length,false);
      auto mem = cast(BT[])newData.data;
      mem[] = rh[];
      m_DataObject = newData;
      m_DataObject.AddReference();
      m_Data = newData.data;      
    }
  }
  
  /*void opAssign(U)(U rh) if(is(U == T[]) || 
                            (IsPOD!(BT) && (is(U == BT[]) || is(U == const(BT)[]) || is(U == immutable(BT)[])))
                           )
  {
    if(m_DataObject !is null)
      m_DataObject.RemoveReference();
    auto newData = data_t.AllocateArray(rh.length,false);
    auto mem = cast(BT[])newData.data;
    mem[] = rh[];
    m_DataObject = newData;
    m_DataObject.AddReference();
    m_Data = newData.data;
  }*/
  
  /*void opAssign(ref shared(this_t) rh) shared
  {
    if(m_DataObject !is null)
      m_DataObject.RemoveReference();
    m_DataObject = rh.m_DataObject;
    m_Data = rh.m_Data;
    if(m_DataObject !is null)
      m_DataObject.AddReference();
  }*/
  
  this_t dup()
  {
    assert(m_Data !is null,"nothing to duplicate");
    auto copy = data_t.AllocateArray(m_Data.length,false);
    auto mem = cast(BT[])copy.data;
    mem[0..m_Data.length] = m_Data[0..$];
    return this_t(copy);
  }
  
  //TODO fix
  /*immutable(this_t) idup()
  {
    return cast(immutable(this_t))dup();
  }*/
  
  ref T opIndex(size_t index)
  {
    return m_Data[index];
  }
  
  ref const(T) opIndex(size_t index) const
  {
    return m_Data[index];
  }
  
  ref immutable(T) opIndex(size_t index) immutable
  {
    return m_Data[index];
  }
  
  ref shared(T) opIndex(size_t index) shared
  {
    return m_Data[index];
  }
  
  T[] opSlice()
  {
    return m_Data;
  }
  
  this_t opSlice(size_t start, size_t end)
  {
    return this_t(m_DataObject,m_Data[start..end]);
  }
  
  const(this_t) opSlice(size_t start, size_t end) const
  {
    return const(this_t)(m_DataObject, m_Data[start..end]);
  }
  
  immutable(this_t) opSlice(size_t start, size_t end) immutable
  {
    return immutable(this_t)(m_DataObject, m_Data[start..end]);
  }
  
  void opOpAssign(string op,U)(U rh) if(op == "~" && (is(U == this_t) || is(U : BT[]) || is(U : const(BT)[]) || is(U : immutable(BT)[])))
  {
    // We own the data and therefore can do whatever we want with it
    if(m_DataObject !is null && m_DataObject.refcount == 1)
    {
      m_DataObject = m_DataObject.Resize!(InitializeMemoryWith.NOTHING)
                                         (m_Data.length + rh.length);
      (cast(BT[])m_DataObject.data)[m_Data.length..$] = rh[];
      m_Data = m_DataObject.data;
    }
    else { // we have to copy the data
      auto newData = data_t.AllocateArray(m_Data.length + rh.length, false);
      auto mem = cast(BT[])newData.data;
      if(m_Data.length > 0)
      {
        mem[0..m_Data.length] = m_Data[];
        mem[m_Data.length..$] = rh[];
        if(m_DataObject !is null)
          m_DataObject.RemoveReference();
      }
      else
        mem[0..$] = rh[];

      m_DataObject = newData;
      m_DataObject.AddReference();
      m_Data = newData.data;
    }
  }
  
  void opOpAssign(string op,U)(U rh) if(op == "~" && (is(U == T) || IsPOD!(BT) && is(U == BT)))
  {
    //We own the data
    if(m_DataObject !is null && m_DataObject.refcount == 1)
    {
      m_DataObject = m_DataObject.Resize(m_Data.length + 1);
      (cast(BT[])m_DataObject.data)[m_Data.length] = rh;
      m_Data = m_DataObject.data;
    }
    else { // we have to copy the data
      auto newData = data_t.AllocateArray(m_Data.length + 1);
      if(m_Data.length > 0)
      {
        auto mem = cast(BT[])newData.data;
        mem[0..m_Data.length] = m_Data[];
        mem[m_Data.length] = rh;
        if(m_DataObject !is null)
          m_DataObject.RemoveReference();
      }
      else
      {
        (cast(BT[])newData.data)[m_Data.length] = rh;
      }
      m_DataObject = newData;
      m_DataObject.AddReference();
      m_Data = newData.data;
    }
  }
  
  /*void opOpAssign(string op,U)(U rh)
  {
    static assert(0,U.stringof);
  }*/
  
  this_t opBinary(string op,U)(auto ref U rh) if(op == "~" && (is(U == this_t) || 
                                      is(U == T[]) || 
                                      (IsPOD!(BT) && (is(U == BT[]) || is(U == const(BT)[]) || is(U == immutable(BT))))
                                     ))
  {
    auto result = this_t(this.length + rh.length);
    auto mem = cast(BT[])result[];
    mem[0..this.length] = this[];
    mem[this.length..$] = rh[];
    return result;
  }
  
  this_t opBinary(string op,U)(auto ref U rh) if(op == "~" && (is(U == T) || 
                                                 (IsPOD!(BT) && (is(U == BT) || is(U == const(BT)) || is(U == immutable(BT))))
                                                ))
  {
    auto result = this_t(this.length + 1);
    auto mem = cast(BT[])result[];
    mem[0..this.length] = this[];
    mem[this.length] = rh;
    return result;
  }
  
  this_t opBinaryRight(string op,U)(U lh) if(op == "~" && (
                                      is(U == T[]) || 
                                      (IsPOD!(BT) && (is(U == BT[]) || is(U == const(BT)[]) || is(U == immutable(BT))))
                                     ))
  {
    auto result = this_t(this.length + lh.length);
    auto mem = cast(BT[])result[];
    mem[0..rh.length] = rh[];
    mem[rh.length..$] = this[];
    return result;
  }
  
  this_t opBinaryRight(string op,U)(U lh) if(op == "~" && (is(U == T) || 
                                                 (IsPOD!(BT) && (is(U == BT) || is(U == const(BT)) || is(U == immutable(BT))))
                                                ))
  {
    auto result = this_t(this.length + 1);
    auto mem = cast(BT[])result[];
    mem[0] = lh;
    mem[1..$] = this[];
    return result;
  }
  
  int opApply( scope int delegate(ref T) dg )
  {
    int result;
    
    foreach( e; m_Data)
    {
      if( (result = dg( e )) != 0 )
        break;
    }
    return result;
  }
  
  int opApply( scope int delegate(ref size_t, ref T) dg )
  {
      int result;

      foreach( i, e; m_Data )
      {
          if( (result = dg( i, e )) != 0 )
              break;
      }
      return result;
  }
  
  bool opCast(U)() if(is(U == bool))
  {
    return m_DataObject !is null; 
  }
  
  @property auto ptr()
  {
    return m_Data.ptr;
  }
  
  @property size_t length()
  {
    return m_Data.length;
  }
}

RCArray!(immutable(char)) _T(immutable(char)[] data)
{
  return RCArray!(immutable(char))(data,IsStatic.Yes);
}

unittest 
{
  struct AllocCounter 
  {
    int m_iNumAllocations = 0;
    int m_iNumDeallocations = 0;

    void* OnAllocateMemory(size_t size, size_t alignment)
    {
      m_iNumAllocations++;
      return null;
    }

    bool OnFreeMemory(void* ptr)
    {
      m_iNumDeallocations++;
      return false;
    }

    void* OnReallocateMemory(void* ptr, size_t size)
    {
      m_iNumAllocations++;
      m_iNumDeallocations++;
      return null;
    }
  }

  AllocCounter counter;

  StdAllocator.OnAllocateMemoryCallback = &counter.OnAllocateMemory;
  StdAllocator.OnReallocateMemoryCallback = &counter.OnReallocateMemory;
  StdAllocator.OnFreeMemoryCallback = &counter.OnFreeMemory;

  assert(counter.m_iNumAllocations == counter.m_iNumDeallocations);

  {
    int iStartCountAlloc = counter.m_iNumAllocations;
    int iStartCountFree = counter.m_iNumDeallocations;
    auto staticString = _T("Hello World");
    assert(staticString == "Hello World");
    int iEndCountAlloc = counter.m_iNumAllocations;
    int iEndCountFree = counter.m_iNumDeallocations;
    assert(iEndCountAlloc == iStartCountAlloc);
    assert(iEndCountFree == iStartCountFree);
  }

  /*{
    int iStartCountAlloc = m_iNumAllocations;
    auto staticString = _T("Hello") ~ _T(" World");
  }*/

}

class RCException : Throwable
{
  this(RCArray!(immutable(char)) msg, string file = __FILE__, size_t line = __LINE__, Throwable next = null)
  {
    this.rcmsg = msg;
    super(msg[], file, line, next);
  }

  this(RCArray!(immutable(char)) msg, Throwable next, string file = __FILE__, size_t line = __LINE__)
  {
    this.rcmsg = msg;
    super(msg[], file, line, next);
  }

  protected RCArray!(immutable(char)) rcmsg;
}