module core.refcounted;

public import core.allocator;
import core.atomic;
import core.stdc.string; // for memcpy
import core.traits;
import core.hashmap;

abstract class RefCounted
{
private:
  shared(int) m_iRefCount = 0;
  IAllocator m_allocator;
  
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
    (cast(RefCounted)this).AddReference();
  }
  
  final void RemoveReference() shared
  {
    (cast(RefCounted)this).RemoveReference();
  }

protected:
  // Release also needs to be protected so that the invariant handler does not get
  // called on a already freed object
  void Release()
  {
    assert(m_allocator !is null, "no allocator given during construction!");
    auto allocator = m_allocator;
    clear(this);
    allocator.FreeMemory(cast(void*)this);
  }
  
  final void Release() shared
  {
    (cast(RefCounted)this).Release();
  }
  
public:
  @property final int refcount()
  {
    return m_iRefCount;
  }

  this(IAllocator allocator)
  {
    m_allocator = allocator;
  }

  this() { }

  final void SetAllocator(IAllocator allocator)
  {
    m_allocator = allocator;
  }
}

/**
 * Wrapper object without implicit conversion so the user recognizes he just allocated a reference counted object
 */
struct ReturnRefCounted(T)
{
  static assert(is(T : RefCounted),T.stringof ~ " is not a reference counted object");
  T ptr;

  this(T obj)
  {
    ptr = obj;
  }
}

template SmartPtrType(T : SmartPtr!T)
{
  alias T SmartPtrType;
}

template ReturnRefCountedType(T : ReturnRefCounted!T)
{
  alias T ReturnRefCountedType;
}

/**
 * Smart pointer to safely hold reference counted objects
 */
struct SmartPtr(T)
{
  static assert(is(T : RefCounted),T.stringof ~ " is not a reference counted object");
  
  T ptr;
  alias ptr this;
  alias typeof(this) this_t;
  
  this(T obj)
  {
    ptr = obj;
    ptr.AddReference();
  }
  
  this(this)
  {
    if(ptr !is null)
      ptr.AddReference();
  }

  this(ReturnRefCounted!T rh)
  {
    ptr = rh.ptr;
    if(ptr !is null)
      ptr.AddReference();
    rh.ptr = null;
  }
  
  ~this()
  {
    if(ptr !is null)
      ptr.RemoveReference();
  }
  
  //assignment to null
  void opAssign(U)(U obj) if(is(U == typeof(null)))
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = null;
  }
  
  //asignment from a normal reference
  void opAssign(U)(U obj) if(!is(U == typeof(null)) && (!is(U V : SmartPtr!V) && (is(U == T) || is(U : T))))
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = obj;
    if(ptr !is null)
      ptr.AddReference();
  }
  
  //assignment from another smart ptr
  void opAssign(U)(auto ref U rh) if(is(U V : SmartPtr!V) && is(SmartPtrType!U : T))
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = rh.ptr;
    if(ptr !is null)
      ptr.AddReference();
  }

  //assignemnt from a value New! returned
  void opAssign(U)(U rh) if(is(U V : ReturnRefCounted!V) && is(ReturnRefCountedType!U : T))
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = rh.ptr;
    if(ptr !is null)
      ptr.AddReference();
    rh.ptr = null;
  }

  //TODO reenable when bug 8295 is fixed
  /*void opAssign(shared(ReturnRefCounted!T) rh) shared
  {
    if(ptr !is null)
      ptr.RemoveReference();
    ptr = rh.ptr;
    if(ptr !is null)
      ptr.AddReference();
    rh.ptr = null;
  }*/
}

final class RCArrayData(T, AT = StdAllocator) : RefCounted
{
private:
  T[] data;
  
  alias StripModifier!(T) BT; //Base Type

public:

  static if(is(typeof(AT.globalInstance)))
  {
    this() { super(AT.globalInstance); }
  }

  this(IAllocator allocator)
  {
    super(allocator);
  }

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
  
  static auto AllocateArray(Allocator)(size_t size, Allocator allocator, InitializeMemoryWith meminit = InitializeMemoryWith.INIT)
  {
    //TODO replace enforce
    //enforce(size > 0,"can not create a array of size 0");
    size_t headerSize = __traits(classInstanceSize,typeof(this));
    size_t bytesToAllocate = headerSize + (T.sizeof * size);
    void* mem = allocator.AllocateMemory(bytesToAllocate).ptr;
    auto address = cast(size_t)mem;
    assert(address % T.alignof == 0,"Missaligned array memory");
    void[] blop = mem[0..bytesToAllocate];
    
    //initialize header
    (cast(byte[]) blop)[0..headerSize] = typeid(typeof(this)).init[];
    auto result = cast(typeof(this))mem;

    //call default ctor
    result.__ctor(allocator);
    static if(is(Allocator == StdAllocator))
    {
      allocator.SetIsClass(mem);
    }
    
    final switch(meminit)
    {
      case InitializeMemoryWith.NULL:
        memset(mem + headerSize,0,bytesToAllocate - headerSize);
        break;
      case InitializeMemoryWith.INIT:
        {
          auto arrayData = (cast(BT*)(mem + headerSize))[0..size];
          static if(is(BT == struct))
            BT inithelper;
          foreach(ref BT e; arrayData)
          {
            // If it is a struct can't use the assignment operator
            // otherwise the assignment operator might work on a non initialized instance
            static if(is(BT == struct))
              memcpy(&e,&inithelper,BT.sizeof);
            else
              e = BT.init;
          }
        }
        break;
      case InitializeMemoryWith.NOTHING:
        break;
    }   
    
    result.data = (cast(T*)(mem + headerSize))[0..size];
    return result;
  }
  
  @property final size_t length() immutable
  {
    return data.length;
  }
   
  final auto opSlice()
  {
    return this.data;
  }
  
  final auto opSlice() const
  {
    return this.data;
  }
  
  final auto opSlice() immutable
  {
    return this.data;
  }
  
  final auto opSlice() shared
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
  
  static if(is(typeof(AT.globalInstance)))
  {
    this(size_t size)
    {
      m_DataObject = data_t.AllocateArray(size, AT.globalInstance);
      m_DataObject.AddReference();
      m_Data = m_DataObject.data;
    }
  }

  this(size_t size, AT allocator)
  {
    m_DataObject = data_t.AllocateArray(size, allocator);
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
  
  private void ConstructFromArray(U)(U init, AT allocator) 
    if(is(U : BT[]) || is(U : immutable(BT)[]) || is(U : const(BT)[]))
  {
    m_DataObject = data_t.AllocateArray(init.length, allocator, InitializeMemoryWith.NOTHING);
    m_DataObject.AddReference();
    m_Data = m_DataObject.data;
    auto mem = cast(BT[])m_Data;
    uninitializedCopy(mem[], cast(BT[])init[]);
  }
  
  static if(is(typeof(AT.globalInstance)))
  {
    static if(IsPOD!(BT))
    {
      this(BT[] init) 
      {
        ConstructFromArray(init, AT.globalInstance);
      }

      this(const(BT[]) init)
      {
        ConstructFromArray(init, AT.globalInstance);
      }

      this(immutable(BT[]) init)
      {
        ConstructFromArray(init, AT.globalInstance);
      }
    }
    else {
      this(T[] init)
      {
        ConstructFromArray(init, AT.globalInstance);
      }
    }
  }

  static if(IsPOD!(BT))
  {
    this(BT[] init, AT allocator) 
    {
      ConstructFromArray(init, allocator);
    }

    this(const(BT[]) init, AT allocator)
    {
      ConstructFromArray(init, allocator);
    }

    this(immutable(BT[]) init, AT allocator)
    {
      ConstructFromArray(init, allocator);
    }
  }
  else {
    this(T[] init, AT allocator)
    {
      ConstructFromArray(init, allocator);
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
  
  this(data_t data)
  {
    assert(data !is null);
    m_DataObject = data;
    m_DataObject.AddReference();
    m_Data = m_DataObject.data;
  }
  
  this(data_t dataObject, T[] data)
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
  
  @trusted void opAssign(T)(auto ref T rh) if(!is(T == this_t) && isRCArray!T && is(RCArrayType!T == RCArrayType!this_t) 
                                     && is(typeof( true ? RCAllocatorType!T : AT) == AT))
  {
    static assert(__traits(classInstanceSize, typeof(m_DataObject)) == __traits(classInstanceSize, typeof(rh.m_DataObject)), "can not cast because sizes don't match");

    if(m_DataObject !is null)
      m_DataObject.RemoveReference();

    m_DataObject = cast(typeof(m_DataObject))cast(void*)rh.m_DataObject; //very ugly cast

    m_Data = rh.m_Data;
    if(m_DataObject !is null)
      m_DataObject.AddReference();
  }

  @trusted void opAssign(T)(T rh) if(is(T == this_t))
  {
    if(m_DataObject !is null)
      m_DataObject.RemoveReference();
    m_DataObject = rh.m_DataObject;
    m_Data = rh.m_Data;
    if(m_DataObject !is null)
      m_DataObject.AddReference();
  }
  
  static if(is(typeof(AT.globalInstance)))
  {
    @trusted void opAssign(U)(U rh) if(is(U == T[]) || 
                              (IsPOD!(BT) && (is(U == BT[]) || is(U == const(BT)[]) || is(U == immutable(BT)[])))
                             )
    {
      if(m_DataObject !is null)
        m_DataObject.RemoveReference();
      auto newData = data_t.AllocateArray(rh.length, AT.globalInstance, InitializeMemoryWith.NOTHING);
      auto mem = cast(BT[])newData.data;
      mem[] = rh[];
      m_DataObject = newData;
      m_DataObject.AddReference();
      m_Data = newData.data;
    }
  }
  
  /*void opAssign(ref shared(this_t) rh) shared
  {
    if(m_DataObject !is null)
      m_DataObject.RemoveReference();
    m_DataObject = rh.m_DataObject;
    m_Data = rh.m_Data;
    if(m_DataObject !is null)
      m_DataObject.AddReference();
  }*/
  
  static if(is(typeof(AT.globalInstance)))
  {
    this_t dup()
    {
      assert(m_Data !is null,"nothing to duplicate");
      auto copy = data_t.AllocateArray(m_Data.length, AT.globalInstance, InitializeMemoryWith.NOTHING);
      auto mem = cast(BT[])copy.data;
      uninitializedCopy(mem[], m_Data[]);
      return this_t(copy);
    }
  }
  
  //TODO fix
  /*immutable(this_t) idup()
  {
    return cast(immutable(this_t))dup();
  }*/

  static if(is(BT == T))
  {
    ref T opIndexAssign(T value, size_t index)
    {
      m_Data[index] = value;
      return m_Data[index];
    }

    void opIndexAssign(T value, size_t from, size_t to)
    {
      m_Data[from..to] = value;
    }

    //TODO implement op slice assign
  }
  
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

  const(T[]) opSlice() const
  {
    return m_Data;
  }

  immutable(T[]) opSlice() immutable
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
  
  //Appending of a other RCArray or normal array with the ~= operator
  void opOpAssign(string op,U)(U rh) if(op == "~" && ((isRCArray!U && is(RCArrayType!U == RCArrayType!this_t)) || is(U : BT[]) || is(U : const(BT)[]) || is(U : immutable(BT)[])))
  {
    static if(is(typeof(AT.globalInstance)))
    {
      AT allocator = AT.globalInstance;
    }
    else
    {
      IAllocator allocator = (m_DataObject is null) ? null : m_DataObject.m_allocator;
      static if(isRCArray!U)
      {
        if(allocator is null && rh.m_DataObject !is null)
         allocator = rh.m_DataObject.m_allocator;
      }
      assert(allocator !is null, "no allocator could be found");
    }

    auto newData = data_t.AllocateArray(m_Data.length + rh.length, allocator, InitializeMemoryWith.NOTHING);
    auto mem = cast(BT[])newData.data;
    if(m_Data.length > 0)
    {
      uninitializedCopy(mem[0..m_Data.length], m_Data[]);
      uninitializedCopy(mem[m_Data.length..$], rh[]);
    }
    else
    {
      uninitializedCopy(mem[0..$], rh[]);
    }

    if(m_DataObject !is null)
      m_DataObject.RemoveReference();
    m_DataObject = newData;
    m_DataObject.AddReference();
    m_Data = newData.data;
  }
  
  //Appending of a single element using the ~= operator
  void opOpAssign(string op,U)(U rh) if(op == "~" && (is(U == T) || IsPOD!(BT) && is(U == BT)))
  {
    static if(is(typeof(AT.globalInstance)))
    {
      auto allocator = AT.globalInstance;
    }
    else
    {
      IAllocator allocator = (m_DataObject !is null) ? m_DataObject.m_allocator : null;
      assert(allocator, "couldn't find allocator");
    }

    auto newData = data_t.AllocateArray(m_Data.length + 1, allocator, InitializeMemoryWith.NOTHING);
    if(m_Data.length > 0)
    {
      auto mem = cast(BT[])newData.data;

      uninitializedCopy(mem[0..m_Data.length], m_Data[]);
      uninitializedCopy(mem[m_Data.length], rh);
    }
    else
    {
      uninitializedCopy((cast(BT[])newData.data)[m_Data.length], rh);
    }
    if(m_DataObject !is null)
      m_DataObject.RemoveReference();
    m_DataObject = newData;
    m_DataObject.AddReference();
    m_Data = newData.data;
  }
  
  /*void opOpAssign(string op,U)(U rh)
  {
    static assert(0,U.stringof);
  }*/
  
  //Append another array using the ~ operator
  this_t opBinary(string op,U)(auto ref U rh) if(op == "~" && ((isRCArray!U && is(RCArrayType!this_t == RCArrayType!U)) || 
                                      is(U == T[]) || 
                                      (IsPOD!(BT) && (is(U == BT[]) || is(U == const(BT)[]) || is(U == immutable(BT)[])))
                                     ))
  {
    static if(is(typeof(AT.globalInstance)))
    {
      AT allocator = AT.globalInstance;
    }
    else
    {
      IAllocator allocator = (m_DataObject is null) ? null : m_DataObject.m_allocator;
      static if(isRCArray!U)
      {
        if(allocator is null && rh.m_DataObject !is null)
          allocator = rh.m_DataObject.m_allocator;
      }
      assert(allocator !is null, "no allocator could be found");
    }

    auto result = data_t.AllocateArray(this.length + rh.length, allocator, InitializeMemoryWith.NOTHING);
    auto mem = cast(BT[])result[];
    copy(mem[0..this.length], this[]);
    copy(mem[this.length..$], rh[]);

    return this_t(result);
  }
  
  //Appending a single element
  this_t opBinary(string op,U)(auto ref U rh) if(op == "~" && (is(U == T) || 
                                                 (IsPOD!(BT) && (is(U == BT) || is(U == const(BT)) || is(U == immutable(BT))))
                                                ))
  {
    static if(is(typeof(AT.globalInstance)))
    {
      AT allocator = AT.globalInstance;
    }
    else
    {
      IAllocator allocator = (m_DataObject is null) ? null : m_DataObject.m_allocator;
      assert(allocator !is null, "couldn't find an allocator");
    }

    auto result = data_t.AllocateArray(this.length + 1, allocator);
    auto mem = cast(BT[])result[];
    uninitializedCopy(mem[0..this.length], this[]);
    uninitializedCopy(mem[this.length], rh);
    return this_t(result);
  }
  
  //The same as above, but swaped operands
  this_t opBinaryRight(string op,U)(U lh) if(op == "~" && (
                                      is(U == T[]) || 
                                      (IsPOD!(BT) && (is(U == BT[]) || is(U == const(BT)[]) || is(U == immutable(BT))))
                                     ))
  {
    static if(is(typeof(AT.globalInstance)))
    {
      AT allocator = AT.globalInstance;
    }
    else
    {
      IAllocator allocator = (m_DataObject is null) ? null : m_DataObject.m_allocator;
      assert(allocator !is null, "couldn't find an allocator");
    }

    auto result = data_t.AllocateArray(this.length + lh.length, allocator);
    auto mem = cast(BT[])result[];

    uninitializedCopy(mem[0..lh.length], lh[]);
    uninitializedCopy(mem[lh.length..$], this[]);

    return this_t(result);
  }
  
  this_t opBinaryRight(string op,U)(U lh) if(op == "~" && (is(U == T) || 
                                                 (IsPOD!(BT) && (is(U == BT) || is(U == const(BT)) || is(U == immutable(BT))))
                                                ))
  {
    auto result = data_t.AllocateArray(this.length + 1);
    auto mem = cast(BT[])result[];
    uninitializedCopy(mem[0], lh);
    uninitializedCopy(mem[1..$], this[]);
    return this_t(result);
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
    return (m_Data !is null && m_Data.length != 0); 
  }

  //this cast operator eithers casts to from different storage types, or to a lower allocator type
  auto opCast(U)() if(is(U V : RCArray!(V,A), A) && is(BT == U.BT) && (is(RCAllocatorType!U == AT) || is(typeof( true ? RCAllocatorType!U : AT) == RCAllocatorType!U)) )
  {
    return U(cast(U.data_t)(cast(void*)m_DataObject), //need to use very ugly cast here
             cast(RCArrayType!U[])m_Data);
  }

  /*U opCast(U)() if(isRCArray!U && is(RCArrayType!U == RCArrayType!this_t)
    && is(typeof( true ? RCAllocatorType!U : AT) == AT))
  {
    static union UglyCastHelper
    {
      typeof(m_DataObject) to;
      RCArrayData!(RCArrayType!U, RCAllocatorType!U) from;
    }
    UglyCastHelper helper;
    static assert(__traits(classInstanceSize, typeof(helper.form)) == __traits(classInstanceSize, typeof(helper.to)));

    helper.from = value.m_DataObject;

    return U(helper.to, value[]);
  }*/
  
  @property auto ptr()
  {
    return m_Data.ptr;
  }

  @property auto ptr() const
  {
    return m_Data.ptr;
  }

  @property auto ptr() immutable
  {
    return m_Data.ptr;
  }
  
  @property size_t length() const
  {
    return m_Data.length;
  }

  bool opEquals(this_t rh)
  {
    return (this[] == rh[]);
  }

  bool opEquals(const(this_t) rh) const
  {
    return (this[] == rh[]);
  }

  bool opEquals(T[] rh)
  {
    return (this[] == rh);
  }

  int opCmp(T[] rh)
  {
    return (this[] < rh);
  }

  int opCmp(this_t rh)
  {
    return (this[] < rh[]);
  }

  uint Hash() const
  {
    return hashOf(m_Data.ptr, m_Data.length);
  }

  auto getDataObject() { return m_DataObject; }
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

class RCException : Exception
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
  
  RCArray!(immutable(char)) getMessage() { return rcmsg; }
}
