/**
 * TypeInfo support code.
 *
 * Copyright: Copyright Digital Mars 2004 - 2009.
 * License:   <a href="http://www.boost.org/LICENSE_1_0.txt">Boost License 1.0</a>.
 * Authors:   Walter Bright
 */

/*          Copyright Digital Mars 2004 - 2009.
 * Distributed under the Boost Software License, Version 1.0.
 *    (See accompanying file LICENSE_1_0.txt or copy at
 *          http://www.boost.org/LICENSE_1_0.txt)
 */
module rt.typeinfo.ti_ireal;

private import rt.typeinfo.ti_real;

// ireal

class TypeInfo_j : TypeInfo_e
{
    override to_string_t toString() 
    {
      version(NOGCSAFE)
        return to_string_t("ireal");
      else
        return "ireal"; 
    }

    @property override Type type() nothrow pure { return Type.Native; }
}
