module core.hashmap;

import core.allocator;
import core.stdc.string; //for memcpy

version( X86 )
  version = AnyX86;
version( X86_64 )
  version = AnyX86;
version( AnyX86 )
  version = HasUnalignedOps;

/* take from rt.utils.hash */
hash_t hashOf( const (void)* buf, size_t len, hash_t seed = 0 )
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

  static uint Hash(T)(T value) if(is(T == struct))
  {
    return value.Hash();
  }
}

class Hashmap(K,V,HP = StdHashPolicy, AT = StdAllocator)
{
  private:
    enum State {
      Free,
      Deleted,
      Data
    }
    
    struct Pair {
      K key;
      V value;
      State state;
    }
  
    Pair[] m_Data;
    size_t m_FullCount = 0;
    AT m_allocator;
    
    enum uint INITIAL_SIZE = 4;
  
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
        m_allocator.FreeMemory(m_Data.ptr);
        m_Data = [];
      }
    }
    
    private void insert(ref K key, ref V value)
    {
      size_t index = HP.Hash(key) % m_Data.length;
      while(m_Data[index].state == State.Data)
      {
        index = (index + 1) % m_Data.length;
      }
      m_Data[index].key = key;
      m_Data[index].value = value;
      m_Data[index].state = State.Data;
    }
    
    void opIndexAssign(V value, K key)
    {
      m_FullCount++;
      if(m_FullCount > m_Data.length / 2 || m_FullCount >= m_Data.length)
      {
        Pair[] oldData = m_Data;
        m_Data = (cast(Pair*)m_allocator.AllocateMemory(oldData.length * 2 * Pair.sizeof))[0..oldData.length*2];
        foreach(ref entry; m_Data)
        {
          entry.state = State.Free;
        }
        
        //rehash all values
        foreach(ref entry; oldData)
        {
          if(entry.state == State.Data)
            insert(entry.key,entry.value);
        }
        m_allocator.FreeMemory(oldData.ptr);
      }
      
      insert(key,value);
    }
    
    ref V opIndex(K key)
    {
      size_t index = HP.Hash(key) % m_Data.length;
      while(m_Data[index].state != State.Free)
      {
        if(m_Data[index].key == key)
          return m_Data[index].value;
        index = (index + 1) % m_Data.length;
      }
      
      assert(0,"not found");
      //TODO implement to work in relase also
    }
    
    bool exists(K key)
    {
      size_t index = HP.Hash(key) % m_Data.length;
      while(m_Data[index].state != State.Free)
      {
        if(m_Data[index].key == key)
          return true;
        index = (index + 1) % m_Data.length;
      }
      return false;
    }
    
    bool remove(K key)
    {
      size_t index = HP.Hash(key) % m_Data.length;
      bool found = false;
      while(m_Data[index].state != State.Free)
      {
        if(m_Data[index].key == key)
        {
          found = true;
          break;
        }
        index = (index + 1) % m_Data.length;
      }
      if(!found)
        return false;
      
      size_t nextIndex = (index + 1) % m_Data.length;
      if(m_Data[nextIndex].state != State.Free)
        m_Data[index].state = State.Deleted;
      else
        m_Data[index].state = State.Free;
      
      //TODO remove when compiler no longer allocates on K.init
      static if(is(K == struct))
      {
        K temp;
        m_Data[index].key = temp;
      }
      else
        m_Data[index].key = K.init;
      
      //TODO remove when compiler no longer allocates on V.init
      static if(is(V == struct))
      {
        V temp;
        m_Data[index].value = temp;
      }
      else
        m_Data[index].value = V.init;
      m_FullCount--;
      
      return true;
    }
    
    int opApply( scope int delegate(ref V) dg )
    {
      int result = void;
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
      foreach(ref entry; m_Data)
      {
        if( entry.state == State.Data && (result = dg(entry.key,entry.value)) != 0)
          break;
      }
      return result;
    }
    
    size_t count() @property
    {
      return m_FullCount;
    }
}