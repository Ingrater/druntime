/**
* This module provides MS VC runtime helper function that
* wrap differences between different versions of the MS C runtime
*
* Copyright: Copyright Digital Mars 2015.
* License: Distributed under the
*      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
*    (See accompanying file LICENSE)
* Source:    $(DRUNTIMESRC rt/_msvc.c)
* Authors:   Rainer Schuetze, Benjamin Thaut
*/

#pragma once

#if defined _M_IX86
    #define C_PREFIX "_"
#elif defined _M_X64 || defined _M_ARM || defined _M_ARM64
    #define C_PREFIX ""
#else
    #error Unsupported architecture
#endif

#define DECLARE_ALTERNATE_NAME(name, alternate_name)  \
    __pragma(comment(linker, "/alternatename:" C_PREFIX #name "=" C_PREFIX #alternate_name))
	