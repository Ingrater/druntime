class Foo
{
}

interface IFoo
{
}

struct SFoo
{
}

void main(string[] args)
{
  assert(typeid(byte).type == TypeInfo.Type.Byte);
  assert(typeid(ubyte).type == TypeInfo.Type.UByte);
  assert(typeid(short).type == TypeInfo.Type.Short);
  assert(typeid(ushort).type == TypeInfo.Type.UShort);
  assert(typeid(int).type == TypeInfo.Type.Int);
  assert(typeid(uint).type == TypeInfo.Type.UInt);
  assert(typeid(long).type == TypeInfo.Type.Long);
  assert(typeid(ulong).type == TypeInfo.Type.ULong);
  assert(typeid(char).type == TypeInfo.Type.Char);
  assert(typeid(wchar).type == TypeInfo.Type.WChar);
  assert(typeid(dchar).type == TypeInfo.Type.DChar);
  assert(typeid(Object).type == TypeInfo.Type.Obj);
  assert(typeid(Foo).type == TypeInfo.Type.Class);
  assert(typeid(IFoo).type == TypeInfo.Type.Interface);
  assert(typeid(SFoo).type == TypeInfo.Type.Struct);
  assert(typeid(void).type == TypeInfo.Type.Void);
  assert(typeid(bool).type == TypeInfo.Type.Bool);
  assert(typeid(float).type == TypeInfo.Type.Float);
  assert(typeid(ifloat).type == TypeInfo.Type.IFloat);
  assert(typeid(cfloat).type == TypeInfo.Type.CFloat);
  assert(typeid(double).type == TypeInfo.Type.Double);
  assert(typeid(idouble).type == TypeInfo.Type.IDouble);
  assert(typeid(cdouble).type == TypeInfo.Type.CDouble);
  assert(typeid(real).type == TypeInfo.Type.Real);
  assert(typeid(ireal).type == TypeInfo.Type.IReal);
  assert(typeid(creal).type == TypeInfo.Type.CReal);
  assert(typeid(int[]).type == TypeInfo.Type.Array);
  assert(typeid(float[]).type == TypeInfo.Type.Array);
  assert(typeid(void*).type == TypeInfo.Type.Pointer);
}