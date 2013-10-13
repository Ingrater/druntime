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
module rt.typeinfo.ti_Ashort;

private import core.stdc.string;
private import rt.util.hash;
version(NOGCSAFE) import core.refcounted : _T;

// short[]

class TypeInfo_As : TypeInfo_Array
{
    override bool opEquals(Object o) { return TypeInfo.opEquals(o); }

    override to_string_t toString() const 
	{
      version(NOGCSAFE)
        return _T("short[]");
      else		
	    return "short[]"; 
	}

    override size_t getHash(in void* p) @trusted const
    {
        short[] s = *cast(short[]*)p;
        return hashOf(s.ptr, s.length * short.sizeof);
    }

    override bool equals(in void* p1, in void* p2) const
    {
        short[] s1 = *cast(short[]*)p1;
        short[] s2 = *cast(short[]*)p2;

        return s1.length == s2.length &&
               memcmp(cast(void *)s1, cast(void *)s2, s1.length * short.sizeof) == 0;
    }

    override int compare(in void* p1, in void* p2) const
    {
        short[] s1 = *cast(short[]*)p1;
        short[] s2 = *cast(short[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int result = s1[u] - s2[u];
            if (result)
                return result;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    override @property inout(TypeInfo) next() inout
    {
        return cast(inout)typeid(short);
    }
}


// ushort[]

class TypeInfo_At : TypeInfo_As
{
    override to_string_t toString() const 
	{
      version(NOGCSAFE)
        return _T("ushort[]");
      else		
	    return "ushort[]"; 
	}

    override int compare(in void* p1, in void* p2) const
    {
        ushort[] s1 = *cast(ushort[]*)p1;
        ushort[] s2 = *cast(ushort[]*)p2;
        size_t len = s1.length;

        if (s2.length < len)
            len = s2.length;
        for (size_t u = 0; u < len; u++)
        {
            int result = s1[u] - s2[u];
            if (result)
                return result;
        }
        if (s1.length < s2.length)
            return -1;
        else if (s1.length > s2.length)
            return 1;
        return 0;
    }

    override @property inout(TypeInfo) next() inout
    {
        return cast(inout)typeid(ushort);
    }
}

// wchar[]

class TypeInfo_Au : TypeInfo_At
{
    override to_string_t toString() const 
	{
      version(NOGCSAFE)
        return _T("wchar[]");
      else		
	    return "wchar[]"; 
	}

    override @property inout(TypeInfo) next() inout
    {
        return cast(inout)typeid(wchar);
    }
}
