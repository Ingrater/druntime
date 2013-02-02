/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_Adouble;

private import rt.typeinfo.ti_double;
private import rt.util.hash;

// double[]

class TypeInfo_Ad : TypeInfo_Array
{
    override bool opEquals(Object o) { return TypeInfo.opEquals(o); }
	
    override to_string_t toString() 
    { 
      version(NOGCSAFE)
        return to_string_t("double[]");
      else
        return "double[]"; 
    }
	
	@trusted:
    const:
    pure:
    nothrow:
	
    override size_t getHash(in void* p)
    {
        double[] s = *cast(double[]*)p;
        return hashOf(s.ptr, s.length * double.sizeof);
    }

    override bool equals(in void* p1, in void* p2)
    {
        double[] s1 = *cast(double[]*)p1;
        double[] s2 = *cast(double[]*)p2;
        size_t len = s1.length;

        if (len != s2.length)
            return 0;
        for (size_t u = 0; u < len; u++)
        {
            if (!TypeInfo_d._equals(s1[u], s2[u]))
                return false;
        }
        return true;
    }

    override int compare(in void* p1, in void* p2)
    {
        double[] s1 = *cast(double[]*)p1;
        double[] s2 = *cast(double[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int c = TypeInfo_d._compare(s1[u], s2[u]);
            if (c)
                return c;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    override @property const(TypeInfo) next() nothrow pure
    {
        return typeid(double);
    }

    @property override Type type() nothrow pure { return Type.Array; }
}

// idouble[]

class TypeInfo_Ap : TypeInfo_Ad
{

    override to_string_t toString() const
    { 
      version(NOGCSAFE)
        return to_string_t("idouble[]");
      else
        return "idouble[]"; 
    }

    override @property const(TypeInfo) next() nothrow pure
    {
        return typeid(idouble);
    }

    @property override Type type() nothrow pure { return Type.Array; }
}
