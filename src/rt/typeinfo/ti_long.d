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
module rt.typeinfo.ti_long;

private import rt.util.hash;

// long

class TypeInfo_l : TypeInfo
{
    override to_string_t toString() 
    { 
      version(NOGCSAFE)
        return to_string_t("long");
      else
        return "long"; 
    }
    @trusted:
    const:
    pure:
    nothrow:


    override hash_t getHash(in void* p)
    {
        return hashOf(p, long.sizeof);
    }

    override equals_t equals(in void* p1, in void* p2)
    {
        return *cast(long *)p1 == *cast(long *)p2;
    }

    override int compare(in void* p1, in void* p2)
    {
        if (*cast(long *)p1 < *cast(long *)p2)
            return -1;
        else if (*cast(long *)p1 > *cast(long *)p2)
            return 1;
        return 0;
    }

    override @property size_t tsize() nothrow pure
    {
        return long.sizeof;
    }

    override void swap(void *p1, void *p2)
    {
        long t;

        t = *cast(long *)p1;
        *cast(long *)p1 = *cast(long *)p2;
        *cast(long *)p2 = t;
    }

    override @property size_t talign() nothrow pure
    {
        return long.alignof;
    }

    @property override Type type() nothrow pure { return Type.Long; }
}
