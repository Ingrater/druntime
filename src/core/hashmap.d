module core.hashmap;

import core.allocator;
import core.stdc.string; //for memcpy
import core.atomic;

version( X86 )
  version = AnyX86;
version( X86_64 )
  version = AnyX86;
version( AnyX86 )
  version = HasUnalignedOps;

/* taken from rt.utils.hash */
uint hashOf( const (void)* buf, size_t len, uint seed = 0 )
{
  /*
  * This is Paul Hsieh's SuperFastHash algorithm, described here:
  *   http://www.azillionmonkeys.com/qed/hash.html
  * It is protected by the following open source license:
  *   http://www.azillionmonkeys.com/qed/weblicense.html
  */
  version( HasUnalignedOps )
  {
    static uint get16bits( const (ubyte)* x )
    {
      return *cast(ushort*) x;
    }
  }
  else
  {
    static uint get16bits( const (ubyte)* x )
    {
      return ((cast(uint) x[1]) << 8) + (cast(uint) x[0]);
    }
  }

  // NOTE: SuperFastHash normally starts with a zero hash value.  The seed
  //       value was incorporated to allow chaining.
  auto data = cast(const (ubyte)*) buf;
  auto hash = seed;
  int  rem;

  if( len <= 0 || data is null )
    return 0;

  rem = len & 3;
  len >>= 2;

  for( ; len > 0; len-- )
  {
    hash += get16bits( data );
    auto tmp = (get16bits( data + 2 ) << 11) ^ hash;
    hash  = (hash << 16) ^ tmp;
    data += 2 * ushort.sizeof;
    hash += hash >> 11;
  }

  switch( rem )
  {
    case 3: hash += get16bits( data );
      hash ^= hash << 16;
      hash ^= data[ushort.sizeof] << 18;
      hash += hash >> 11;
      break;
    case 2: hash += get16bits( data );
      hash ^= hash << 11;
      hash += hash >> 17;
      break;
    case 1: hash += *data;
      hash ^= hash << 10;
      hash += hash >> 1;
      break;
    default:
      break;
  }

  /* Force "avalanching" of final 127 bits */
  hash ^= hash << 3;
  hash += hash >> 5;
  hash ^= hash << 4;
  hash += hash >> 17;
  hash ^= hash << 25;
  hash += hash >> 6;

  return hash;
}


struct StdHashPolicy
{
  static uint Hash(T)(T value) if(is(T == class))
  {
    return value.Hash();
  }

  static uint Hash(T)(ref T value) if(is(T == struct))
  {
    return value.Hash();
  }

  static uint Hash(T)(T value) if(!is(T == struct) && !is(T == class))
  {
    return hashOf(&value, T.sizeof);
  }

  static bool equals(T)(T lhs, T rhs)
  {
    return lhs == rhs;
  }
}

final class Hashmap(K,V,HP = StdHashPolicy, AT = StdAllocator)
{
  public:
    struct Init
    {
      uint hash;
      K key;
      V value;
    }
  private:
    enum State {
      Free, // 0
      Deleted, // 1
      Data // 2
    }
    
    struct Pair {
      K key;
      V value;
      State state;

      this(ref K key, ref V value, State state)
      {
        this.key = key;
        this.value = value;
        this.state = state;
      }
    }
  
    Pair[] m_Data;
    size_t m_FullCount = 0;
    AT m_allocator;
    //debug shared(uint) m_iterationCount = 0;
    
    enum uint INITIAL_SIZE = 5;
    // the following fraction controls the amount of always free entries in the hashmap
    enum size_t numerator = 3;
    enum size_t denominator = 4;
    
    __gshared immutable(uint[]) sizes = [13, 29, 61, 127, 257, 521, 1049, 2111, 4229, 8461, 16927, 
                                         33857, 67723, 135449, 270913, 541831, 1083689, 2167393, 
                                         4334791, 8669593, 17339197, 34678421, 69356857, 138713717, 
                                         277427441, 554854889, 1109709791, 2219419597];
                                         
    static size_t findNextSize(size_t currentSize) pure
    {
      foreach(s; sizes)
      {
        if(s > currentSize)
          return s;
      }
      return currentSize * 2;
    }
  
  public:
    
    this(AT allocator)
    {
      m_allocator = allocator;
      m_Data = (cast(Pair*)allocator.AllocateMemory(Pair.sizeof * INITIAL_SIZE))[0..INITIAL_SIZE];
      
      foreach(ref entry;m_Data)
      {
        entry.state = State.Free;
      }
    }
    
    this(Init[] init, AT allocator, size_t len)
    {
      assert(allocator !is null);
      m_allocator = allocator;
      m_Data = (cast(Pair*)allocator.AllocateMemory(Pair.sizeof * len))[0..len];
    }

    static if(is(AT == StdAllocator))
    {
      this()
      {
        this(g_stdAllocator);
      }
    }
  
    ~this()
    {
      if(m_Data.ptr !is null)
      {
        foreach(ref p; m_Data)
        {
          if(p.state == State.Data)
          {
            callDtor(&p);
          }
        }
        m_allocator.FreeMemory(m_Data.ptr);
        m_Data = [];
      }
    }
    
    private void insert(ref K key, ref V value)
    {
      //debug { assert(m_iterationCount == 0, "can't modify hashmap while iterating"); }
      size_t index = HP.Hash(key) % m_Data.length;
      while(m_Data[index].state == State.Data)
      {
        index = (index + 1) % m_Data.length;
      }
      const(void[]) initMem = typeid(Pair).init();
      if(initMem.ptr !is null)
        (cast(void*)&m_Data[index])[0..Pair.sizeof] = initMem[];
      else
        memset(&m_Data[index], 0, Pair.sizeof);
      m_Data[index].__ctor(key, value, State.Data);
    }

    private void move(ref Pair data)
    {
      size_t index = HP.Hash(data.key) % m_Data.length;
      while(m_Data[index].state == State.Data)
      {
        index = (index + 1) % m_Data.length;
      }
      memcpy(m_Data.ptr + index, &data, Pair.sizeof);
    }
    
    void reserve(size_t count)
    {
      if(count > ((m_Data.length * numerator) / denominator) || count >= m_Data.length)
      {
        Pair[] oldData = m_Data;
        auto newLength = findNextSize((count / numerator) * denominator);
        m_Data = (cast(Pair*)m_allocator.AllocateMemory(newLength * Pair.sizeof))[0..newLength];
        foreach(ref entry; m_Data)
        {
          entry.state = State.Free;
        }
        
        //rehash all values
        foreach(ref entry; oldData)
        {
          if(entry.state == State.Data)
            move(entry);
        }
        m_allocator.FreeMemory(oldData.ptr);            
      }        
    }
    
    void opIndexAssign(V value, K key)
    {
      size_t index = getIndex(key);
      if(index == size_t.max) //not in the hashmap yet
      {
        m_FullCount++;
        if(m_FullCount > ((m_Data.length * numerator) / denominator) || m_FullCount >= m_Data.length)
        {
          Pair[] oldData = m_Data;
          size_t newSize = findNextSize(oldData.length);
          m_Data = (cast(Pair*)m_allocator.AllocateMemory(newSize * Pair.sizeof))[0..newSize];
          foreach(ref entry; m_Data)
          {
            entry.state = State.Free;
          }
        
          //rehash all values
          foreach(ref entry; oldData)
          {
            if(entry.state == State.Data)
              move(entry);
          }
          m_allocator.FreeMemory(oldData.ptr);
        }
        insert(key,value);
      }
      else //already in hashmap
      {
        m_Data[index].value = value; 
      }
    }
    
    ref V opIndex(K key)
    {
      size_t index = HP.Hash(key) % m_Data.length;
      while(m_Data[index].state != State.Free)
      {
        if(m_Data[index].state == State.Data && HP.equals(m_Data[index].key, key))
          return m_Data[index].value;
        index = (index + 1) % m_Data.length;
      }
      
      assert(0,"not found");
      //TODO implement to work in relase also
    }
    
    bool exists(K key)
    {
      return getIndex(key) != size_t.max;
    }

    void ifExists(K key, scope void delegate(ref V) doIfTrue, scope void delegate() doIfFalse)
    {
      auto index = getIndex(key);
      if(index != size_t.max)
        doIfTrue(m_Data[index].value);
      else
        doIfFalse();
    }

    void ifExists(K key, scope void delegate(ref V) doIfTrue)
    {
      auto index = getIndex(key);
      if(index != size_t.max)
        doIfTrue(m_Data[index].value);
    }   

    size_t getIndex(K key)
    {
      size_t index = HP.Hash(key) % m_Data.length;
      size_t searched = 0;
      while(m_Data[index].state != State.Free && searched < m_Data.length)
      {
        if(m_Data[index].state == State.Data && HP.equals(m_Data[index].key, key))
          return index;
        index = (index + 1) % m_Data.length;
        searched++;
      }
      return size_t.max;
    }

    private void doRemove(size_t index)
    {
      size_t nextIndex = (index + 1) % m_Data.length;
      if(m_Data[nextIndex].state != State.Free)
        m_Data[index].state = State.Deleted;
      else
        m_Data[index].state = State.Free;

      //TODO remove when compiler no longer allocates on K.init
      static if(is(K == struct))
      {
        static if(__traits(compiles, (){ K constructTest; return constructTest; }))
        {
          K keyTemp;
          m_Data[index].key = keyTemp;
        }
        else
        {
          void[K.sizeof] keyTemp;
          void[] initMem = typeid(K).init();
          if(initMem.ptr is null)
            memset(keyTemp.ptr, 0, keyTemp.length);
          else
            keyTemp[] = initMem[];
          m_Data[index].key = *cast(K*)keyTemp.ptr; 
        }
      }
      else
        m_Data[index].key = K.init;

      //TODO remove when compiler no longer allocates on V.init
      static if(is(V == struct))
      {
        static if(__traits(compiles, (){ V constructTest; return constructTest; }))
        {
          V valueTemp;
          m_Data[index].value = valueTemp;
        }
        else
        {
          void[V.sizeof] valueTemp;
          void[] initMem = typeid(V).init();
          if(initMem.ptr is null)
            memset(valueTemp.ptr, 0, valueTemp.length);
          else
            valueTemp[] = initMem[];
          m_Data[index].value = *cast(V*)valueTemp.ptr; 
        }
      }
      else
        m_Data[index].value = V.init;
      m_FullCount--;
    }
    
    bool remove(K key)
    {
      //debug { assert(m_iterationCount == 0, "can't modify hashmap while iterating"); }
      size_t index = HP.Hash(key) % m_Data.length;
      bool found = false;
      while(m_Data[index].state != State.Free)
      {
        if(m_Data[index].state == State.Data && HP.equals(m_Data[index].key, key))
        {
          found = true;
          break;
        }
        index = (index + 1) % m_Data.length;
      }
      if(!found)
        return false;
      
      doRemove(index);
      return true;
    }

    size_t removeWhere(scope bool delegate(ref K, ref V) condition)
    {
      size_t removed = 0;
      foreach(size_t index, ref entry; m_Data)
      {
        if( entry.state == State.Data && condition(entry.key, entry.value) )
        {
          doRemove(index);
          removed++;
        }
      }
      return removed;
    }
    
    int opApply( scope int delegate(ref V) dg )
    {
      int result = void;
      /*debug {
        atomicOp!"+="(m_iterationCount, 1);
        scope(exit) atomicOp!"-="(m_iterationCount, 1);
      }*/
      foreach(ref entry; m_Data)
      {
        if( entry.state == State.Data && (result = dg(entry.value)) != 0)
          break;
      }
      return result;
    }

    int opApply( scope int delegate(ref K, ref V) dg )
    {
      int result = void;
      /*debug {
        atomicOp!"+="(m_iterationCount, 1);
        scope(exit) atomicOp!"-="(m_iterationCount, 1);
      }*/
      foreach(ref entry; m_Data)
      {
        if( entry.state == State.Data && (result = dg(entry.key, entry.value)) != 0)
          break;
      }
      return result;
    }

    /**
     * Removes all entries from the hashmap
     */
    void clear()
    {
      //debug { assert(m_iterationCount == 0, "can't modify hashmap while iterating"); }
      foreach(ref p; m_Data)
      {
        if(p.state == State.Data)
        {
          static if(is(V == struct))
          {
            p.value = V();
          }
          else
          {
            p.value = V.init;
          }

          static if(is(K == struct))
          {
            p.key = K();
          }
          else
          {
            p.key = K.init;
          }
          p.state = State.Free;
        }
      }
      m_FullCount = 0;
    }

    static struct KeyRange
    {
      private Hashmap!(K,V,HP,AT).Pair* m_start;
      private Hashmap!(K,V,HP,AT).Pair* m_end;

      ref K front()
      {
        return m_start.key;
      }

      ref K back()
      {
        return m_end.key;
      }

      private void validateFront()
      {
        while(m_start <= m_end && m_start.state != State.Data)
        {
          m_start++;
        }
      }

      void popFront()
      {
        m_start++;
        validateFront();
      }

      private void validateBack()
      {
        while(m_end >= m_start && m_end.state != State.Data)
        {
          m_end--;
        }
      }

      void popBack()
      {
        m_end--;
        validateBack();
      }

      @property bool empty()
      {
        return m_start > m_end;
      }
    }

    static struct ValueRange
    {
      private Hashmap!(K,V,HP,AT).Pair* m_start;
      private Hashmap!(K,V,HP,AT).Pair* m_end;

      ref V front()
      {
        return m_start.value;
      }

      ref V back()
      {
        return m_end.value;
      }

      private void validateFront()
      {
        while(m_start <= m_end && m_start.state != State.Data)
        {
          m_start++;
        }
      }

      void popFront()
      {
        m_start++;
        validateFront();
      }

      private void validateBack()
      {
        while(m_end >= m_start && m_end.state != State.Data)
        {
          m_end--;
        }
      }

      void popBack()
      {
        m_end--;
        validateBack();
      }

      @property bool empty()
      {
        return m_start > m_end;
      }
    }

    @property KeyRange keys()
    {
      KeyRange r;
      r.m_start = &m_Data[0];
      r.m_end = &m_Data[$-1];
      r.validateFront();
      r.validateBack();
      return r;
    }

    @property ValueRange values()
    {
      ValueRange r;
      r.m_start = &m_Data[0];
      r.m_end = &m_Data[$-1];
      r.validateFront();
      r.validateBack();
      return r;
    }
    
    size_t count() @property
    {
      return m_FullCount;
    }
}