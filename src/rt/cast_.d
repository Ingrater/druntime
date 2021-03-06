/**
 * Implementation of array assignment support routines.
 *
 * Copyright: Copyright Digital Mars 2004 - 2010.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright, Sean Kelly
 */

/*          Copyright Digital Mars 2004 - 2010.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.cast_;

extern (C):

/******************************************
 * Given a pointer:
 *      If it is an Object, return that Object.
 *      If it is an interface, return the Object implementing the interface.
 *      If it is null, return null.
 *      Else, undefined crash
 */

export Object _d_toObject(void* p)
{   Object o;

    if (p)
    {
        o = cast(Object)p;
        ClassInfo oc = o.classinfo;
        Interface *pi = **cast(Interface ***)p;

        /* Interface.offset lines up with ClassInfo.name.ptr,
         * so we rely on pointers never being less than 64K,
         * and Objects never being greater.
         */
        if (pi.offset < 0x10000)
        {
            //printf("\tpi.offset = %d\n", pi.offset);
            o = cast(Object)(p - pi.offset);
        }
    }
    return o;
}


/*************************************
 * Attempts to cast Object o to class c.
 * Returns o if successful, null if not.
 */

export Object _d_interface_cast(void* p, ClassInfo c)
{   Object o;

    //printf("_d_interface_cast(p = %p, c = '%.*s')\n", p, c.name);
    if (p)
    {
        Interface *pi = **cast(Interface ***)p;

        //printf("\tpi.offset = %d\n", pi.offset);
        o = cast(Object)(p - pi.offset);
        return _d_dynamic_cast(o, c);
    }
    return o;
}

export Object _d_dynamic_cast(Object o, ClassInfo c)
{   ClassInfo oc;
    size_t offset = 0;

    //printf("_d_dynamic_cast(o = %p, c = '%.*s')\n", o, c.name);

    if (o)
    {
        oc = o.classinfo;
        if (_d_isbaseof2(oc, c, offset))
        {
            //printf("\toffset = %d\n", offset);
            o = cast(Object)(cast(void*)o + offset);
        }
        else
            o = null;
    }
    //printf("\tresult = %p\n", o);
    return o;
}

export int _d_isbaseof2(ClassInfo oc, ClassInfo c, ref size_t offset)
{
    if (oc is c || opEquals(oc, c))
        return 1;
    do
    {
        if (oc.base is c || opEquals(oc.base, c))
            return 1;
        foreach (i; 0..oc.interfaces.length)
        {
            auto ic = oc.interfaces[i].classinfo;
            if (ic is c || opEquals(ic, c))
            {   offset = oc.interfaces[i].offset;
                return 1;
            }
        }
        foreach (i; 0..oc.interfaces.length)
        {
            auto ic = oc.interfaces[i].classinfo;
            if (_d_isbaseof2(ic, c, offset))
            {   offset = oc.interfaces[i].offset;
                return 1;
            }
        }
        oc = oc.base;
    } while (oc);
    return 0;
}

export int _d_isbaseof(ClassInfo oc, ClassInfo c)
{
    if (oc is c)
        return 1;
    do
    {
        if (oc.base is c)
            return 1;
        foreach (i; 0..oc.interfaces.length)
        {
            auto ic = oc.interfaces[i].classinfo;
            if (ic is c || _d_isbaseof(ic, c))
                return 1;
        }
        oc = oc.base;
    } while (oc);
    return 0;
}

/*********************************
 * Find the vtbl[] associated with Interface ic.
 */

export void *_d_interface_vtbl(ClassInfo ic, Object o)
{
    //printf("__d_interface_vtbl(o = %p, ic = %p)\n", o, ic);

    assert(o);

    auto oc = o.classinfo;
    foreach (i; 0..oc.interfaces.length)
    {
        auto oic = oc.interfaces[i].classinfo;
        if (oic is ic)
        {
            return cast(void *)oc.interfaces[i].vtbl;
        }
    }
    assert(0);
}
