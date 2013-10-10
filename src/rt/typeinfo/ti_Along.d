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
module rt.typeinfo.ti_Along;

private import core.stdc.string;
private import rt.util.hash;

// long[]

class TypeInfo_Al : TypeInfo_Array
{
    override bool opEquals(Object o) { return TypeInfo.opEquals(o); }

    override to_string_t toString() const 
	{
      version(NOGCSAFE)
        return _T("long[]");
      else		
	    return "long[]"; 
	}

    override size_t getHash(in void* p) @trusted const
    {
        long[] s = *cast(long[]*)p;
        return hashOf(s.ptr, s.length * long.sizeof);
    }

    override bool equals(in void* p1, in void* p2) const
    {
        long[] s1 = *cast(long[]*)p1;
        long[] s2 = *cast(long[]*)p2;

        return s1.length == s2.length &&
               memcmp(cast(void *)s1, cast(void *)s2, s1.length * long.sizeof) == 0;
    }

    override int compare(in void* p1, in void* p2) const
    {
        long[] s1 = *cast(long[]*)p1;
        long[] s2 = *cast(long[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            if (s1[u] < s2[u])
                return -1;
            else if (s1[u] > s2[u])
                return 1;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    override @property inout(TypeInfo) next() inout
    {
        return cast(inout)typeid(long);
    }
}


// ulong[]

class TypeInfo_Am : TypeInfo_Al
{
    override to_string_t toString() const 
	{
      version(NOGCSAFE)
        return _T("ulong[]");
      else		
	    return "ulong[]"; 
	}

    override int compare(in void* p1, in void* p2) const
    {
        ulong[] s1 = *cast(ulong[]*)p1;
        ulong[] s2 = *cast(ulong[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            if (s1[u] < s2[u])
                return -1;
            else if (s1[u] > s2[u])
                return 1;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    override @property inout(TypeInfo) next() inout
    {
        return cast(inout)typeid(ulong);
    }
}
