module core.sys.bionic.fcntl;
pragma(sharedlibrary, "std");

version(CRuntime_Bionic) extern(C) nothrow @nogc:

enum LOCK_EX = 2;
