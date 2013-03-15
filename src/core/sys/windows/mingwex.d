/*
 * MinGW uses MSVCRT stdio functions by default.  Support for C99 is done with 
 * macros and inline functions.  This module generates replacement functions
 * suitable for extern(C) usage.
 *
 * From mingw-w64 stdio.h
 * This file has no copyright assigned and is placed in the Public Domain.
 * This file is part of the w64 mingw-runtime package.
 * No warranty is given; refer to the file DISCLAIMER.PD within this package.
 */
module core.sys.windows.stdio;
  
version (MinGW):
extern (C):

private import gcc.builtins;
private import core.vararg;
private import core.stdc.stdio;
private import core.stdc.stddef;


extern {
    int __mingw_sscanf(in char *  _Src,in char *  _Format,...);
    int __mingw_vsscanf (in char *  _Str,in char *  Format,va_list argp);
    int __mingw_scanf(in char *  _Format,...);
    int __mingw_vscanf(in char *  Format, va_list argp);
    int __mingw_fscanf(FILE *  _File,in char *  _Format,...);
    int __mingw_vfscanf (FILE *  fp, in char *  Format,va_list argp);
    int __mingw_vsnprintf(char *  _DstBuf,size_t _MaxCount,in char *  _Format, va_list _ArgList);
    int __mingw_snprintf(char *  s, size_t n, in char *   format, ...);
    
    int __mingw_swscanf(in wchar_t *  _Src,in wchar_t *  _Format,...);
    int __mingw_vswscanf (in wchar_t *  _Str,in wchar_t *  Format,va_list argp);
    int __mingw_wscanf(in wchar_t *  _Format,...);
    int __mingw_vwscanf(in wchar_t *  Format, va_list argp);
    int __mingw_fwscanf(FILE *  _File,in wchar_t *  _Format,...);
    int __mingw_vfwscanf (FILE *  fp, in wchar_t *  Format,va_list argp);
    
    int __mingw_fwprintf(FILE *  _File,in wchar_t *  _Format,...);
    int __mingw_wprintf(in wchar_t *  _Format,...);
    int __mingw_vfwprintf(FILE *  _File,in wchar_t *  _Format,va_list    _ArgList);
    int __mingw_vwprintf(in wchar_t *  _Format,va_list _ArgList);
    deprecated int __mingw_swprintf(wchar_t *  , in wchar_t *  , ...);
    deprecated int __mingw_vswprintf(wchar_t *  , in wchar_t *  ,va_list);
    int __mingw_snwprintf (wchar_t *  s, size_t n, in wchar_t *  format, ...);
    int __mingw_vsnwprintf (wchar_t *  , size_t, in wchar_t *  , va_list);


    nothrow 
    {
        int __mingw_printf(in char *  , ... );
        int __mingw_vprintf (in char *  , va_list);
        int __mingw_fprintf (FILE *  , in char *  , ...);
        int __mingw_vfprintf (FILE *  , in char *  , va_list);
        int __mingw_sprintf (char *  , in char *  , ...);
        int __mingw_vsprintf (char *  , in char *  , va_list);
        int __mingw_asprintf(char **  , in char *  , ...);
        int __mingw_vasprintf(char **  , in char *  , va_list);
    }
}

int sscanf(in char *__source, in char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vsscanf( __source, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int scanf(in char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vscanf( __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int fscanf(FILE *__stream, in char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vfscanf( __stream, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int vsscanf (in char *__source, in char *__format, __builtin_va_list __local_argv)
{
  return __mingw_vsscanf( __source, __format, __local_argv );
}

int vscanf(in char *__format,  __builtin_va_list __local_argv)
{
  return __mingw_vscanf( __format, __local_argv );
}

int vfscanf (FILE *__stream,  in char *__format, __builtin_va_list __local_argv)
{
  return __mingw_vfscanf( __stream, __format, __local_argv );
}

int fprintf (FILE *__stream, in char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vfprintf( __stream, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int printf (in char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vprintf( __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int sprintf (char *__stream, in char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vsprintf( __stream, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int vfprintf (FILE *__stream, in char *__format, __builtin_va_list __local_argv)
{
  return __mingw_vfprintf( __stream, __format, __local_argv );
}

int vprintf (in char *__format, __builtin_va_list __local_argv)
{
  return __mingw_vprintf( __format, __local_argv );
}

int vsprintf (char *__stream, in char *__format, __builtin_va_list __local_argv)
{
  return __mingw_vsprintf( __stream, __format, __local_argv );
}

int asprintf(char **__ret, in char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vasprintf( __ret, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}


int vasprintf(char **__ret, in char *__format, __builtin_va_list __local_argv)
{
  return __mingw_vasprintf( __ret, __format, __local_argv );
}

int snprintf (char *__stream, size_t __n, in char *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vsnprintf( __stream, __n, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int vsnprintf (char *__stream, size_t __n, in char *__format, __builtin_va_list __local_argv)
{
  return __mingw_vsnprintf( __stream, __n, __format, __local_argv );
}
 
int swscanf(in wchar_t *__source, in wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vswscanf( __source, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int wscanf(in wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vwscanf( __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int fwscanf(FILE *__stream, in wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vfwscanf( __stream, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int vswscanf (in wchar_t * __source, in wchar_t * __format, __builtin_va_list __local_argv)
{
  return __mingw_vswscanf( __source, __format, __local_argv );
}

int vwscanf(in wchar_t *__format,  __builtin_va_list __local_argv)
{
  return __mingw_vwscanf( __format, __local_argv );
}

int vfwscanf (FILE *__stream,  in wchar_t *__format, __builtin_va_list __local_argv)
{
  return __mingw_vfwscanf( __stream, __format, __local_argv );
}

int fwprintf (FILE *__stream, in wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vfwprintf( __stream, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int wprintf (in wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vwprintf( __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int swprintf (wchar_t *__stream, in wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vswprintf( __stream, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int vfwprintf (FILE *__stream, in wchar_t *__format, __builtin_va_list __local_argv)
{
  return __mingw_vfwprintf( __stream, __format, __local_argv );
}

int vwprintf (in wchar_t *__format, __builtin_va_list __local_argv)
{
  return __mingw_vwprintf( __format, __local_argv );
}

int vswprintf (wchar_t *__stream, in wchar_t *__format, __builtin_va_list __local_argv)
{
  return __mingw_vswprintf( __stream, __format, __local_argv );
}

int snwprintf (wchar_t *__stream, size_t __n, in wchar_t *__format, ...)
{
  int __retval;
  __builtin_va_list __local_argv; __builtin_va_start( __local_argv, __format );
  __retval = __mingw_vsnwprintf( __stream, __n, __format, __local_argv );
  __builtin_va_end( __local_argv );
  return __retval;
}

int vsnwprintf (wchar_t *__stream, size_t __n, in wchar_t *__format, __builtin_va_list __local_argv)
{
  return __mingw_vsnwprintf( __stream, __n, __format, __local_argv );
}
