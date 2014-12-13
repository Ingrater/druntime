module core.sys.bionic.unistd;
pragma(sharedlibrary, "std");

version(CRuntime_Bionic) extern(C) nothrow @nogc:

int flock(int, int) @trusted;
