module rtti;

import core.stdc.stdio;

struct thMemberInfo 
{
  string name;
  TypeInfo type;
  size_t offset;
}

struct RttiAnchor
{
}

template RttiInfo(T)
{
  //pragma(msg, makeRttiInfo!T());
  __gshared RttiInfo = mixin(makeRttiInfo!T());
}

template instanceSize(T)
{
  static if(is(T == class))
    enum size_t instanceSize = __traits(classInstanceSize, T);
  else
    enum size_t instanceSize = T.sizeof;
}

size_t rttiMemberCount(T)()
{
  size_t count = 0;
  foreach(m; __traits(allMembers, T))
  {
    static if(isRttiMember!(__traits(getMember, T, m)))
    {
      count++;
    }
  }
  return count;
}

string formatOffset(size_t offset)
{
  string result = "";
  do
  {
    auto digit = offset % 10;
    result = cast(char)('0' + digit) ~ result;
    offset = offset / 10;
  }
  while(offset > 0);
  return result;
}

string makeRttiInfo(T)()
{
  static if(is(T == struct))
    pragma(msg, "struct " ~ T.stringof);
  string result = "[thMemberInfo(\"" ~ T.mangleof ~ "\", typeid(T), instanceSize!T)";
  size_t i=0;
  foreach(m; __traits(allMembers, T))
  {
    static if(is(T == struct))
    {
      static if(is(typeof(__traits(getMember, T, m).offsetof)))
      {
        size_t offset = __traits(getMember, T, m).offsetof;
        result ~= ",\nthMemberInfo(" ~ m.stringof ~ ", typeid(typeof(T." ~ m ~ ")), " ~ formatOffset(offset) ~ ")";
      }
    }
    else
    {
      static if(__traits(compiles, mixin("(T." ~ m ~ ").offsetof")))
      {
        size_t offset = mixin("(T." ~ m ~ ").offsetof");
        result ~= ",\nthMemberInfo(" ~ m.stringof ~ ", typeid(typeof(T." ~ m ~ ")), " ~ formatOffset(offset) ~ ")";
      }
    }
  }
  return result ~ "]";
}

const(thMemberInfo)[] getRttiInfo(const TypeInfo ti)
{
  auto temp = cast(const(thMemberInfo)[]*)ti.rtInfo;
  if(temp is null)
	return [];
  return *temp;
}