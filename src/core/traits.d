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

/**
 * Checks if a given type is a POD or not
 */
template IsPOD(T)
{
  static if(is(T U : U*))
  {
    enum bool IsPOD = false;
  }
  else static if(is(T U : U[]))
  {
    enum bool IsPOD = false;
  }
  else static if(is(T == class))
  {
    enum bool IsPOD = false;
  }
  else static if(is(T == struct)) //TODO better checking for structs
  {
    enum bool IsPOD = false;
  }
  else {
    enum bool IsPOD = true;
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
}