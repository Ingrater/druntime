/**
* This module provides linker comments to
* wrap differences between different versions of the MS C runtime.
* The linker renames relevant for phobos are in a seperate C file 
* so they can be applied to the import library of druntime/phobos.
* Otherwise they would be missing when using the shared runtime.
*
* Copyright: Copyright Digital Mars 2016.
* License: Distributed under the
*      $(LINK2 http://www.boost.org/LICENSE_1_0.txt, Boost Software License 1.0).
*    (See accompanying file LICENSE)
* Source:    $(DRUNTIMESRC rt/_msvc.c)
* Authors:   Rainer Schuetze, Benjamin Thaut
*/

#include "msvc.h"

// helper function that does not actually do anything but forces the linker to pull in the object
void _msvc_force_link()
{
	
}

// VS2015+ provides C99-conformant (v)snprintf functions, so weakly
// link to legacy _(v)snprintf (not C99-conformant!) for VS2013- only

DECLARE_ALTERNATE_NAME (snprintf, _snprintf);
DECLARE_ALTERNATE_NAME (vsnprintf, _vsnprintf);

// VS2013- implements these functions as macros, VS2015+ provides symbols

DECLARE_ALTERNATE_NAME (_fputc_nolock, _msvc_fputc_nolock);
DECLARE_ALTERNATE_NAME (_fgetc_nolock, _msvc_fgetc_nolock);
DECLARE_ALTERNATE_NAME (rewind, _msvc_rewind);
DECLARE_ALTERNATE_NAME (clearerr, _msvc_clearerr);
DECLARE_ALTERNATE_NAME (feof, _msvc_feof);
DECLARE_ALTERNATE_NAME (ferror, _msvc_ferror);
DECLARE_ALTERNATE_NAME (fileno, _msvc_fileno);

/**
 * 32-bit x86 MS VC runtimes lack most single-precision math functions.
 * Declare alternate implementations to be pulled in from msvc_math.c.
 */
#if defined _M_IX86

DECLARE_ALTERNATE_NAME (acosf,  _msvc_acosf);
DECLARE_ALTERNATE_NAME (asinf,  _msvc_asinf);
DECLARE_ALTERNATE_NAME (atanf,  _msvc_atanf);
DECLARE_ALTERNATE_NAME (atan2f, _msvc_atan2f);
DECLARE_ALTERNATE_NAME (cosf,   _msvc_cosf);
DECLARE_ALTERNATE_NAME (sinf,   _msvc_sinf);
DECLARE_ALTERNATE_NAME (tanf,   _msvc_tanf);
DECLARE_ALTERNATE_NAME (coshf,  _msvc_coshf);
DECLARE_ALTERNATE_NAME (sinhf,  _msvc_sinhf);
DECLARE_ALTERNATE_NAME (tanhf,  _msvc_tanhf);
DECLARE_ALTERNATE_NAME (expf,   _msvc_expf);
DECLARE_ALTERNATE_NAME (logf,   _msvc_logf);
DECLARE_ALTERNATE_NAME (log10f, _msvc_log10f);
DECLARE_ALTERNATE_NAME (powf,   _msvc_powf);
DECLARE_ALTERNATE_NAME (sqrtf,  _msvc_sqrtf);
DECLARE_ALTERNATE_NAME (ceilf,  _msvc_ceilf);
DECLARE_ALTERNATE_NAME (floorf, _msvc_floorf);
DECLARE_ALTERNATE_NAME (fmodf,  _msvc_fmodf);
DECLARE_ALTERNATE_NAME (modff,  _msvc_modff);

#endif // _M_IX86