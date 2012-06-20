module core.traits;

/**
 * removes the const modifier from a type if any
 * const(T) -> T
 * T -> T
 */
template StripConst(T){
	static if(is(T V : const(V)))
		alias V StripConst;
	else
		alias T StripConst;
}
	
unittest {
	static assert(is(int == StripConst!(int)));
	static assert(is(int == StripConst!(const(int))));
}

/**
 * removes the shared modifier from a type if any
 * shared(T) -> T
 */
template StripShared(T)
{
  static if(is(T V : shared(V)))
    alias V StripShared;
  else
    alias T StripShared;
}

unittest {
  static assert(is(int == StripShared!(shared(int))));
  static assert(is(int == StripShared!(int)));
}

/**
 * removes the immutable modifier from a type if any
 * immutable(T) -> T
 */
template StripImmutable(T)
{
  static if(is(T V : immutable(V)))
    alias V StripImmutable;
  else
    alias T StripImmutable;
}

unittest {
  static assert(is(int == StripImmutable!(immutable(int))));
  static assert(is(int == StripImmutable!(int)));
}

/**
 * removes all type modifiers from a type
 */
template StripModifier(T)
{
  alias StripConst!(StripShared!(StripImmutable!(T))) StripModifier;
}

unittest 
{
  static assert(is(int == StripModifier!(const(int))));
  static assert(is(int == StripModifier!(shared(int))));
  static assert(is(int == StripModifier!(immutable(int))));
  static assert(is(int == StripModifier!(int)));
}

private bool IsPODStruct(T)()
{
  foreach(m; __traits(allMembers,T))
  {
    static if((m.length < 2 || m[0..2] != "__") && m != "this"){
      static if(__traits(compiles,typeof(__traits(getMember,T,m)))){
        static if(IsPOD!(typeof(__traits(getMember,T,m))) == false)
          return false;
      }
    }
  }
  return true;
}

/**
 * Checks if a given type is a POD or not
 */
template IsPOD(T)
{
  static if(is(T U : U*)) //pointer
  {
    enum bool IsPOD = false;
  }
  else static if(is(T U : U[N], size_t N)) //static array
  {
    enum bool IsPOD = IsPOD!U;
  }
  else static if(is(T U : U[N], N)) //associative array
  {
    enum bool IsPOD = false;
  }
  else static if(is(T U : U[])) //array
  {
    enum bool IsPOD = false;
  }
  else static if(is(T == class)) //reference
  {
    enum bool IsPOD = false;
  }
  else static if(is(T == struct)) //struct
  {
    enum bool IsPOD = IsPODStruct!T();
  }
  else static if(is(T == function) || is(T == delegate)) //function / delegate
  {
    enum bool IsPOD = false;
  }
  else {
    enum bool IsPOD = true; //the rest (int,float,double etc)
  }
  //TODO check for static arrays
}

unittest
{
  static assert(IsPOD!(int) == true);
  static assert(IsPOD!(int*) == false);
  static assert(IsPOD!(int[]) == false);
  static assert(IsPOD!(Object) == false);
  static assert(IsPOD!(const(int)) == true);
  static assert(IsPOD!(shared(int)) == true);
  static assert(IsPOD!(immutable(int)) == true);
  static assert(IsPOD!(const(int*)) == false);
  static assert(IsPOD!(shared(int*)) == false);
  static assert(IsPOD!(immutable(int*)) == false);
  static assert(IsPOD!(const(int)[]) == false);
  static assert(IsPOD!(const(int[])) == false);
  static assert(IsPOD!(shared(int)[]) == false);
  static assert(IsPOD!(shared(int[])) == false);
  static assert(IsPOD!(immutable(int)[]) == false);
  static assert(IsPOD!(immutable(int[])) == false);

  struct TestStruct1
  {
    alias int custom_t;
    alias void function(int) func_t;
    int i;
    double d;
    float f;
  }

  static assert(IsPOD!TestStruct1 == true);

  struct TestStruct2
  {
    Object o;
  }

  static assert(IsPOD!TestStruct2 == false);

  struct TestStruct3
  {
    int* ptr;
  }

  static assert(IsPOD!TestStruct3 == false);

  struct TestStruct4
  {
    int*[4] ptrArray;
  }

  static assert(IsPOD!TestStruct4 == false);

  struct TestStruct5
  {
    int[4] array;
  }

  static assert(IsPOD!TestStruct5 == true);

  struct TestStruct6
  {
    int[string] hashtable;
  }

  static assert(IsPOD!TestStruct6 == false);
}

template RCArrayType(T : RCArray!T)
{
  alias T RCArrayType;
}

template isRCArray(T) if(is(T U : RCArray!U))
{
  enum bool isRCArray = true;
}

template isRCArray(T) if(!is(T U : RCArray!U))
{
  enum bool isRCArray = false;
}