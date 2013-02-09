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
  //alias StripConst!(StripShared!(StripImmutable!(T))) StripModifier;
  version (none) // Error: recursive alias declaration @@@BUG1308@@@
  {
    static if (is(T U ==     const U)) alias StripModifier!U StripModifier;
    else static if (is(T U == immutable U)) alias StripModifier!U StripModifier;
    else static if (is(T U ==     inout U)) alias StripModifier!U StripModifier;
    else static if (is(T U ==    shared U)) alias StripModifier!U StripModifier;
    else                                    alias        T StripModifier;
  }
  else // workaround
  {
    static if (is(T   ==   const(void[]))) alias void[] StripModifier;
    else static if (is(T U == shared(const U))) alias U StripModifier;
    else static if (is(T U ==        const U )) alias U StripModifier;
    else static if (is(T U ==    immutable U )) alias U StripModifier;
    else static if (is(T U ==        inout U )) alias U StripModifier;
    else static if (is(T U ==       shared U )) alias U StripModifier;
    else                                        alias T StripModifier;
  }
}

unittest 
{
  static assert(is(int == StripModifier!(const(int))));
  static assert(is(int == StripModifier!(shared(int))));
  static assert(is(int == StripModifier!(immutable(int))));
  static assert(is(int == StripModifier!(int)));
}

template IsStaticMember(T, string N)
{
  mixin("enum bool IsStaticMember = __traits(compiles, { auto temp = T." ~ N ~ "; });");
}

private bool IsPODStruct(T)()
{
  foreach(m; __traits(allMembers,T))
  {
    static if((m.length < 2 || m[0..2] != "__") && m != "this"){
      static if(__traits(compiles,typeof(__traits(getMember,T,m)))){
        //pragma(msg, "checking " ~ m);
        static if(!IsStaticMember!(T, m))
        {
          static if(IsPOD!(typeof(__traits(getMember,T,m))) == false)
          {
            return false;
          }
        }
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
    static if(is(U == function))
      enum bool IsPOD = true;
    else
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
  else static if(is(T == class) || is(T == interface)) //reference
  {
    enum bool IsPOD = false;
  }
  else static if(is(T == struct) || is(T == union)) //struct, union
  {
    enum bool IsPOD = IsPODStruct!T();
  }
  else static if(is(T == delegate)) //delegate
  {
    enum bool IsPOD = false;
  }
  else {
    enum bool IsPOD = true; //the rest (int,float,double etc)
  }
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

  static struct TestStruct1
  {
    alias int custom_t;
    alias void function(int) func_t;
    int i;
    double d;
    float f;
  }

  static assert(IsPOD!TestStruct1 == true);

  static struct TestStruct2
  {
    Object o;
  }

  static assert(IsPOD!TestStruct2 == false);

  static struct TestStruct3
  {
    int* ptr;
  }

  static assert(IsPOD!TestStruct3 == false);

  static struct TestStruct4
  {
    int*[4] ptrArray;
  }

  static assert(IsPOD!TestStruct4 == false);

  static struct TestStruct5
  {
    int[4] array;
  }

  static assert(IsPOD!TestStruct5 == true);

  static struct TestStruct6
  {
    int[string] hashtable;
  }

  static assert(IsPOD!TestStruct6 == false);

  static struct TestStruct7
  {
    alias void function() func;
    alias void delegate() del;
    float f;
  }

  static assert(IsPOD!TestStruct7 == true);

  static struct TestStruct8
  {
    alias void function() func;
    func f;
  }

  static assert(IsPOD!TestStruct8 == true);

  static struct TestStruct9
  {
    alias void delegate() del;
    del d;
  }

  static assert(IsPOD!TestStruct9 == false);

  static struct TestStruct10
  {
    void randomMethod() { }
    float f;
  }

  static assert(IsPOD!TestStruct10 == true);

  static struct TestStruct11
  {
    enum string name = "TestStruct11";
    float f;
  }

  static assert(IsPOD!TestStruct11 == true);
}

template RCArrayType(T : RCArray!(T,AT), AT)
{
  alias T RCArrayType;
}

template RCAllocatorType(T : RCArray!(T, AT), AT)
{
  alias AT RCAllocatorType;
}

template isRCArray(T) if(is(T U : RCArray!U) || is(T U : RCArray!(U,AT), AT))
{
  enum bool isRCArray = true;
}

template isRCArray(T) if(!is(T U : RCArray!U) && !is(T U : RCArray!(U,AT), AT))
{
  enum bool isRCArray = false;
}

template arrayType(T : RCArray!(T,A), A)
{
  alias T arrayType;
}

template arrayType(T : T[])
{
  alias T arrayType;
}

template arrayType(T : U[n], U, size_t n)
{
  alias U arrayType;
}

template typeOfField(T, string name)
{
  alias typeOfFieldImpl!(T, name, 0) typeOfField;
}

template typeOfFieldImpl(T, string name, size_t i)
{
  static assert(!is(T == Object), "member " ~ name ~ " could not be found ");
  static if(i >= T.tupleof.length)
  {
	static if(is(T == class))
	{
		alias typeOfFieldImpl!(BaseClass!T, name, 0) typeOfFieldImpl;
	}
	else
		static assert(is(T == Object), "member " ~ name ~ " could not be found");
  }
  else
  {
 	static if (T.tupleof[i].stringof[1 + T.stringof.length + 2 .. $] == name)
	{
	  alias typeof(T.tupleof[i]) typeOfFieldImpl;
	}
	else
	  alias typeOfFieldImpl!(T, name, i + 1) typeOfFieldImpl;
  }
}

template BaseClass(A)
{
	static assert(!is(A == Object), "Object does not have a base class");
    static if (is(A P == super))
        alias P[0] BaseClass;
    else
            static assert(0, "argument is not a class or interface");
}
