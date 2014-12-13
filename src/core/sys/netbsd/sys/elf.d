/**
 * D header file for NetBSD.
 *
 */
module core.sys.netbsd.sys.elf;
pragma(sharedlibrary, "std");

version (NetBSD):

public import core.sys.netbsd.sys.elf32;
public import core.sys.netbsd.sys.elf64;
