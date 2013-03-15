# Makefile to build nogc D runtime library druntime.lib for Win32

MODEL=64

VCDIR="\Program Files (x86)\Microsoft Visual Studio 10.0\VC"
SDKDIR="\Program Files (x86)\Microsoft SDKs\Windows\v7.0A"

GDC=gdc
CC=gcc
AR=ar
RANLIB=ranlib

DOCDIR=doc
IMPDIR=import

#DFLAGS=-m$(MODEL) -w -d -Isrc -Iimport -property -version=NOGCSAFE -version=RTTI
DFLAGS=-m$(MODEL) -Wall -g -fdeprecated -fproperty -fversion=NOGCSAFE -I src -nophoboslib
#-nostdinc -fversion=RTTI
#UDFLAGS=-m$(MODEL) -debug -g -nofloat -w -d -Isrc -Iimport -property
UDFLAGS=-m$(MODEL) -fdebug -Wall -g -fproperty -fversion=NOGCSAFE -I import -I src -nophoboslib
#-nostdinc -fversion=RTTI
#DFLAGS_RELEASE=-release -O -noboundscheck -version=NO_INVARIANTS
DFLAGS_RELEASE=-frelease -O2
#DFLAGS_DEBUG=-debug -version=MEMORY_TRACKING -g -op
DFLAGS_DEBUG=-fdebug -fbounds-check -fin -fout -fassert -fversion=MEMORY_TRACKING

#CFLAGS=/O2 /I$(VCDIR)\INCLUDE /I$(SDKDIR)\Include
#CFLAGS=/Zi /I$(VCDIR)\INCLUDE /I$(SDKDIR)\Include
CFLAGS=

DRUNTIME_BASE=druntimenogc$(MODEL)
DRUNTIME_DEBUG=lib\lib$(DRUNTIME_BASE)d_mingw.a
DRUNTIME_DEBUG_OBJ=lib$(DRUNTIME_BASE)d_mingw.o
DRUNTIME_RELEASE=lib\lib$(DRUNTIME_BASE)_mingw.a
DRUNTIME_RELEASE_OBJ=lib$(DRUNTIME_BASE)_mingw.o



target : $(DRUNTIME_DEBUG) $(DRUNTIME_RELEASE)

MANIFEST= \
	LICENSE \
	README \
	posix.mak \
	win64nogc.mak \
	\
	src\object_.d \
	src\object.di \
	src\rtti.d \
	\
	src\core\atomic.d \
	src\core\bitop.d \
	src\core\cpuid.d \
	src\core\demangle.d \
	src\core\exception.d \
	src\core\math.d \
	src\core\memory.d \
	src\core\runtime.d \
	src\core\simd.d \
	src\core\thread.d \
	src\core\thread.di \
	src\core\time.d \
	src\core\vararg.d \
	src\core\allocator.d \
	src\core\refcounted.d \
	src\core\hashmap.d \
	\
	src\core\stdc\complex.d \
	src\core\stdc\config.d \
	src\core\stdc\ctype.d \
	src\core\stdc\errno.c \
	src\core\stdc\errno.d \
	src\core\stdc\fenv.d \
	src\core\stdc\float_.d \
	src\core\stdc\inttypes.d \
	src\core\stdc\limits.d \
	src\core\stdc\locale.d \
	src\core\stdc\math.d \
	src\core\stdc\signal.d \
	src\core\stdc\stdarg.d \
	src\core\stdc\stddef.d \
	src\core\stdc\stdint.d \
	src\core\stdc\stdio.d \
	src\core\stdc\stdlib.d \
	src\core\stdc\string.d \
	src\core\stdc\tgmath.d \
	src\core\stdc\time.d \
	src\core\stdc\wchar_.d \
	src\core\stdc\wctype.d \
	\
	src\core\sync\barrier.d \
	src\core\sync\condition.d \
	src\core\sync\config.d \
	src\core\sync\exception.d \
	src\core\sync\mutex.d \
	src\core\sync\rwmutex.d \
	src\core\sync\semaphore.d \
	\
	src\core\sys\freebsd\dlfcn.d \
	src\core\sys\freebsd\execinfo.d \
	\
	src\core\sys\freebsd\sys\event.d \
	\
	src\core\sys\linux\execinfo.d \
	src\core\sys\linux\epoll.d \
	\
	src\core\sys\linux\sys\signalfd.d \
	src\core\sys\linux\sys\xattr.d \
	\
	src\core\sys\osx\execinfo.d \
	src\core\sys\osx\pthread.d \
	\
	src\core\sys\osx\mach\dyld.d \
	src\core\sys\osx\mach\getsect.d \
	src\core\sys\osx\mach\kern_return.d \
	src\core\sys\osx\mach\loader.d \
	src\core\sys\osx\mach\port.d \
	src\core\sys\osx\mach\semaphore.d \
	src\core\sys\osx\mach\thread_act.d \
	\
	src\core\sys\posix\config.d \
	src\core\sys\posix\dirent.d \
	src\core\sys\posix\dlfcn.d \
	src\core\sys\posix\fcntl.d \
	src\core\sys\posix\inttypes.d \
	src\core\sys\posix\netdb.d \
	src\core\sys\posix\poll.d \
	src\core\sys\posix\pthread.d \
	src\core\sys\posix\pwd.d \
	src\core\sys\posix\sched.d \
	src\core\sys\posix\semaphore.d \
	src\core\sys\posix\setjmp.d \
	src\core\sys\posix\signal.d \
	src\core\sys\posix\stdio.d \
	src\core\sys\posix\stdlib.d \
	src\core\sys\posix\termios.d \
	src\core\sys\posix\time.d \
	src\core\sys\posix\ucontext.d \
	src\core\sys\posix\unistd.d \
	src\core\sys\posix\utime.d \
	\
	src\core\sys\posix\arpa\inet.d \
	\
	src\core\sys\posix\net\if_.d \
	\
	src\core\sys\posix\netinet\in_.d \
	src\core\sys\posix\netinet\tcp.d \
	\
	src\core\sys\posix\sys\ioctl.d \
	src\core\sys\posix\sys\ipc.d \
	src\core\sys\posix\sys\mman.d \
	src\core\sys\posix\sys\select.d \
	src\core\sys\posix\sys\shm.d \
	src\core\sys\posix\sys\socket.d \
	src\core\sys\posix\sys\stat.d \
	src\core\sys\posix\sys\time.d \
	src\core\sys\posix\sys\types.d \
	src\core\sys\posix\sys\uio.d \
	src\core\sys\posix\sys\un.d \
	src\core\sys\posix\sys\utsname.d \
	src\core\sys\posix\sys\wait.d \
	\
	src\core\sys\windows\dbghelp.d \
	src\core\sys\windows\dll.d \
	src\core\sys\windows\stacktrace.d \
	src\core\sys\windows\threadaux.d \
	src\core\sys\windows\windows.d \
	src\core\sys\windows\mingwex.d \
	\
	src\gcstub\gc.d \
	\
	src\rt\aApply.d \
	src\rt\aApplyR.d \
	src\rt\aaA.d \
	src\rt\adi.d \
#	src\rt\alloca.d \
	src\rt\arrayassign.d \
	src\rt\arraybyte.d \
	src\rt\arraycast.d \
	src\rt\arraycat.d \
	src\rt\arraydouble.d \
	src\rt\arrayfloat.d \
	src\rt\arrayint.d \
	src\rt\arrayreal.d \
	src\rt\arrayshort.d \
	src\rt\cast_.d \
#	src\rt\cmath2.d \
	src\rt\complex.c \
#	src\rt\cover.d \
	src\rt\critical_.d \
#	src\rt\deh.d \
#	src\rt\deh2.d \
    src\rt\dmain.d \
	src\rt\dmain2.d \
	src\rt\dylib_fixes.c \
	src\rt\image.d \
	src\rt\invariant.d \
	src\rt\invariant_.d \
	src\rt\lifetime.d \
#	src\rt\llmath.d \
	src\rt\mars.h \
	src\rt\memory.d \
	src\rt\memory_osx.d \
#	src\rt\memset.d \
	src\rt\minfo.d \
	src\rt\minit.asm \
	src\rt\monitor_.d \
	src\rt\obj.d \
	src\rt\qsort.d \
#	src\rt\qsort2.d \
	src\rt\switch_.d \
	src\rt\tls.S \
	src\rt\tlsgc.d \
#	src\rt\trace.d \
	\
	src\rt\typeinfo\ti_AC.d \
	src\rt\typeinfo\ti_Acdouble.d \
	src\rt\typeinfo\ti_Acfloat.d \
	src\rt\typeinfo\ti_Acreal.d \
	src\rt\typeinfo\ti_Adouble.d \
	src\rt\typeinfo\ti_Afloat.d \
	src\rt\typeinfo\ti_Ag.d \
	src\rt\typeinfo\ti_Aint.d \
	src\rt\typeinfo\ti_Along.d \
	src\rt\typeinfo\ti_Areal.d \
	src\rt\typeinfo\ti_Ashort.d \
	src\rt\typeinfo\ti_C.d \
	src\rt\typeinfo\ti_byte.d \
	src\rt\typeinfo\ti_cdouble.d \
	src\rt\typeinfo\ti_cfloat.d \
	src\rt\typeinfo\ti_char.d \
	src\rt\typeinfo\ti_creal.d \
	src\rt\typeinfo\ti_dchar.d \
	src\rt\typeinfo\ti_delegate.d \
	src\rt\typeinfo\ti_double.d \
	src\rt\typeinfo\ti_float.d \
	src\rt\typeinfo\ti_idouble.d \
	src\rt\typeinfo\ti_ifloat.d \
	src\rt\typeinfo\ti_int.d \
	src\rt\typeinfo\ti_ireal.d \
	src\rt\typeinfo\ti_long.d \
	src\rt\typeinfo\ti_ptr.d \
	src\rt\typeinfo\ti_real.d \
	src\rt\typeinfo\ti_short.d \
	src\rt\typeinfo\ti_ubyte.d \
	src\rt\typeinfo\ti_uint.d \
	src\rt\typeinfo\ti_ulong.d \
	src\rt\typeinfo\ti_ushort.d \
	src\rt\typeinfo\ti_void.d \
	src\rt\typeinfo\ti_wchar.d \
	\
	src\rt\util\console.d \
	src\rt\util\hash.d \
	src\rt\util\string.d \
	src\rt\util\utf.d \
	\
	src\etc\linux\memoryerror.d \
	\
	src\gcc\atomics.d \
	src\gcc\builtins.d \
	src\gcc\deh.d \
	src\gcc\unwind.d \
	src\gcc\unwind_generic.d \ 
	src\gcc\unwind_pe.d 

SRCS= \
	src\object_.d \
	src\rtti.d \
	\
	src\core\atomic.d \
	src\core\bitop.d \
	src\core\cpuid.d \
	src\core\demangle.d \
	src\core\exception.d \
	src\core\math.d \
	src\core\memory.d \
	src\core\runtime.d \
	src\core\simd.d \
	src\core\thread.d \
	src\core\time.d \
	src\core\vararg.d \
	src\core\allocator.d \
	src\core\refcounted.d \
	src\core\hashmap.d \
	src\core\traits.d \
	\
	src\core\stdc\config.d \
	src\core\stdc\ctype.d \
	src\core\stdc\errno.d \
	src\core\stdc\math.d \
	src\core\stdc\signal.d \
	src\core\stdc\stdarg.d \
	src\core\stdc\stdio.d \
	src\core\stdc\stdlib.d \
	src\core\stdc\stdint.d \
	src\core\stdc\stddef.d \
	src\core\stdc\string.d \
	src\core\stdc\time.d \
	src\core\stdc\wchar_.d \
	\
	src\core\sys\windows\dbghelp.d \
	src\core\sys\windows\dll.d \
	src\core\sys\windows\stacktrace.d \
	src\core\sys\windows\threadaux.d \
	src\core\sys\windows\windows.d \
	src\core\sys\windows\mingwex.d \
	\
	src\core\sync\barrier.d \
	src\core\sync\condition.d \
	src\core\sync\config.d \
	src\core\sync\exception.d \
	src\core\sync\mutex.d \
	src\core\sync\rwmutex.d \
	src\core\sync\semaphore.d \
	\
	src\gcstub\gc.d \
	\
	src\rt\aaA.d \
	src\rt\aApply.d \
	src\rt\aApplyR.d \
	src\rt\adi.d \
#	src\rt\alloca.d \
	src\rt\arrayassign.d \
	src\rt\arraybyte.d \
	src\rt\arraycast.d \
	src\rt\arraycat.d \
	src\rt\arraydouble.d \
	src\rt\arrayfloat.d \
	src\rt\arrayint.d \
	src\rt\arrayreal.d \
	src\rt\arrayshort.d \
	src\rt\cast_.d \
#	src\rt\cmath2.d \
#	src\rt\cover.d \
	src\rt\critical_.d \
#	src\rt\deh2.d \
    src\rt\dmain.d \
	src\rt\dmain2.d \
	src\rt\invariant.d \
	src\rt\invariant_.d \
	src\rt\lifetime.d \
#	src\rt\llmath.d \
	src\rt\memory.d \
#	src\rt\memset.d \
	src\rt\minfo.d \
	src\rt\monitor_.d \
	src\rt\obj.d \
	src\rt\qsort.d \
	src\rt\switch_.d \
	src\rt\tlsgc.d \
#	src\rt\trace.d \
	\
	src\rt\util\console.d \
	src\rt\util\hash.d \
	src\rt\util\string.d \
	src\rt\util\utf.d \
	\
	src\rt\typeinfo\ti_AC.d \
	src\rt\typeinfo\ti_Acdouble.d \
	src\rt\typeinfo\ti_Acfloat.d \
	src\rt\typeinfo\ti_Acreal.d \
	src\rt\typeinfo\ti_Adouble.d \
	src\rt\typeinfo\ti_Afloat.d \
	src\rt\typeinfo\ti_Ag.d \
	src\rt\typeinfo\ti_Aint.d \
	src\rt\typeinfo\ti_Along.d \
	src\rt\typeinfo\ti_Areal.d \
	src\rt\typeinfo\ti_Ashort.d \
	src\rt\typeinfo\ti_byte.d \
	src\rt\typeinfo\ti_C.d \
	src\rt\typeinfo\ti_cdouble.d \
	src\rt\typeinfo\ti_cfloat.d \
	src\rt\typeinfo\ti_char.d \
	src\rt\typeinfo\ti_creal.d \
	src\rt\typeinfo\ti_dchar.d \
	src\rt\typeinfo\ti_delegate.d \
	src\rt\typeinfo\ti_double.d \
	src\rt\typeinfo\ti_float.d \
	src\rt\typeinfo\ti_idouble.d \
	src\rt\typeinfo\ti_ifloat.d \
	src\rt\typeinfo\ti_int.d \
	src\rt\typeinfo\ti_ireal.d \
	src\rt\typeinfo\ti_long.d \
	src\rt\typeinfo\ti_ptr.d \
	src\rt\typeinfo\ti_real.d \
	src\rt\typeinfo\ti_short.d \
	src\rt\typeinfo\ti_ubyte.d \
	src\rt\typeinfo\ti_uint.d \
	src\rt\typeinfo\ti_ulong.d \
	src\rt\typeinfo\ti_ushort.d \
	src\rt\typeinfo\ti_void.d \
	src\rt\typeinfo\ti_wchar.d \
	\
	src\gcc\atomics.d \
	src\gcc\builtins.d \
	src\gcc\deh.d \
	src\gcc\unwind.d \
	src\gcc\unwind_generic.d \
	src\gcc\unwind_pe.d

OBJS=errno_c_mingw64.o

OBJS_TO_DELETE=errno_c_mingw64.o $(DRUNTIME_RELEASE_OBJ) $(DRUNTIME_DEBUG_OBJ)

IMPORTS=\
	$(IMPDIR)\core\sync\barrier.di \
	$(IMPDIR)\core\sync\condition.di \
	$(IMPDIR)\core\sync\config.di \
	$(IMPDIR)\core\sync\exception.di \
	$(IMPDIR)\core\sync\mutex.di \
	$(IMPDIR)\core\sync\rwmutex.di \
	$(IMPDIR)\core\sync\semaphore.di

COPY=\
	src\gcc\atomics.d \
	src\gcc\builtins.d \
	src\gcc\deh.d \
	src\gcc\unwind.d \
	src\gcc\unwind_generic.d

######################## Header .di file generation ##############################

import: $(IMPORTS)

$(IMPDIR)\core\sync\barrier.di : src\core\sync\barrier.d
	$(GDC) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\condition.di : src\core\sync\condition.d
	$(GDC) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\config.di : src\core\sync\config.d
	$(GDC) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\exception.di : src\core\sync\exception.d
	$(GDC) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\mutex.di : src\core\sync\mutex.d
	$(GDC) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\rwmutex.di : src\core\sync\rwmutex.d
	$(GDC) -c -o- -Isrc -Iimport -Hf$@ $**

$(IMPDIR)\core\sync\semaphore.di : src\core\sync\semaphore.d
	$(GDC) -c -o- -Isrc -Iimport -Hf$@ $**

######################## Header .di file copy ##############################

copydir: $(IMPDIR)
	@mkdir $(IMPDIR)\core\gcc 2> NUL

copy: $(COPY)

$(IMPDIR)\object.di : src\object.di
	copy $** $@
	
$(IMPDIR)\rtti.d : src\rtti.d
	copy $** $@

$(IMPDIR)\core\atomic.d : src\core\atomic.d
	copy $** $@

$(IMPDIR)\core\bitop.d : src\core\bitop.d
	copy $** $@

$(IMPDIR)\core\cpuid.d : src\core\cpuid.d
	copy $** $@

$(IMPDIR)\core\demangle.d : src\core\demangle.d
	copy $** $@

$(IMPDIR)\core\exception.d : src\core\exception.d
	copy $** $@

$(IMPDIR)\core\math.d : src\core\math.d
	copy $** $@

$(IMPDIR)\core\memory.d : src\core\memory.d
	copy $** $@

$(IMPDIR)\core\runtime.d : src\core\runtime.d
	copy $** $@

$(IMPDIR)\core\simd.d : src\core\simd.d
	copy $** $@

$(IMPDIR)\core\thread.di : src\core\thread.di
	copy $** $@

$(IMPDIR)\core\time.d : src\core\time.d
	copy $** $@

$(IMPDIR)\core\vararg.d : src\core\vararg.d
	copy $** $@

$(IMPDIR)\core\allocator.d : src\core\allocator.d
	copy $** $@

$(IMPDIR)\core\refcounted.d : src\core\refcounted.d
	copy $** $@

$(IMPDIR)\core\hashmap.d : src\core\hashmap.d
	copy $** $@

$(IMPDIR)\core\traits.d : src\core\traits.d
	copy $** $@

$(IMPDIR)\core\stdc\complex.d : src\core\stdc\complex.d
	copy $** $@

$(IMPDIR)\core\stdc\config.d : src\core\stdc\config.d
	copy $** $@

$(IMPDIR)\core\stdc\ctype.d : src\core\stdc\ctype.d
	copy $** $@

$(IMPDIR)\core\stdc\errno.d : src\core\stdc\errno.d
	copy $** $@

$(IMPDIR)\core\stdc\fenv.d : src\core\stdc\fenv.d
	copy $** $@

$(IMPDIR)\core\stdc\float_.d : src\core\stdc\float_.d
	copy $** $@

$(IMPDIR)\core\stdc\inttypes.d : src\core\stdc\inttypes.d
	copy $** $@

$(IMPDIR)\core\stdc\limits.d : src\core\stdc\limits.d
	copy $** $@

$(IMPDIR)\core\stdc\locale.d : src\core\stdc\locale.d
	copy $** $@

$(IMPDIR)\core\stdc\math.d : src\core\stdc\math.d
	copy $** $@

$(IMPDIR)\core\stdc\signal.d : src\core\stdc\signal.d
	copy $** $@

$(IMPDIR)\core\stdc\stdarg.d : src\core\stdc\stdarg.d
	copy $** $@

$(IMPDIR)\core\stdc\stddef.d : src\core\stdc\stddef.d
	copy $** $@

$(IMPDIR)\core\stdc\stdint.d : src\core\stdc\stdint.d
	copy $** $@

$(IMPDIR)\core\stdc\stdio.d : src\core\stdc\stdio.d
	copy $** $@

$(IMPDIR)\core\stdc\stdlib.d : src\core\stdc\stdlib.d
	copy $** $@

$(IMPDIR)\core\stdc\string.d : src\core\stdc\string.d
	copy $** $@

$(IMPDIR)\core\stdc\tgmath.d : src\core\stdc\tgmath.d
	copy $** $@

$(IMPDIR)\core\stdc\time.d : src\core\stdc\time.d
	copy $** $@

$(IMPDIR)\core\stdc\wchar_.d : src\core\stdc\wchar_.d
	copy $** $@

$(IMPDIR)\core\stdc\wctype.d : src\core\stdc\wctype.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\dlfcn.d : src\core\sys\freebsd\dlfcn.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\execinfo.d : src\core\sys\freebsd\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\freebsd\sys\event.d : src\core\sys\freebsd\sys\event.d
	copy $** $@

$(IMPDIR)\core\sys\linux\execinfo.d : src\core\sys\linux\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\linux\sys\xattr.d : src\core\sys\linux\sys\xattr.d
	copy $** $@

$(IMPDIR)\core\sys\osx\execinfo.d : src\core\sys\osx\execinfo.d
	copy $** $@

$(IMPDIR)\core\sys\osx\pthread.d : src\core\sys\osx\pthread.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\kern_return.d : src\core\sys\osx\mach\kern_return.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\port.d : src\core\sys\osx\mach\port.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\semaphore.d : src\core\sys\osx\mach\semaphore.d
	copy $** $@

$(IMPDIR)\core\sys\osx\mach\thread_act.d : src\core\sys\osx\mach\thread_act.d
	copy $** $@

$(IMPDIR)\core\sys\posix\arpa\inet.d : src\core\sys\posix\arpa\inet.d
	copy $** $@

$(IMPDIR)\core\sys\posix\config.d : src\core\sys\posix\config.d
	copy $** $@

$(IMPDIR)\core\sys\posix\dirent.d : src\core\sys\posix\dirent.d
	copy $** $@

$(IMPDIR)\core\sys\posix\dlfcn.d : src\core\sys\posix\dlfcn.d
	copy $** $@

$(IMPDIR)\core\sys\posix\fcntl.d : src\core\sys\posix\fcntl.d
	copy $** $@

$(IMPDIR)\core\sys\posix\inttypes.d : src\core\sys\posix\inttypes.d
	copy $** $@

$(IMPDIR)\core\sys\posix\netdb.d : src\core\sys\posix\netdb.d
	copy $** $@

$(IMPDIR)\core\sys\posix\net\if_.d : src\core\sys\posix\net\if_.d
	copy $** $@

$(IMPDIR)\core\sys\posix\netinet\in_.d : src\core\sys\posix\netinet\in_.d
	copy $** $@

$(IMPDIR)\core\sys\posix\netinet\tcp.d : src\core\sys\posix\netinet\tcp.d
	copy $** $@

$(IMPDIR)\core\sys\posix\poll.d : src\core\sys\posix\poll.d
	copy $** $@

$(IMPDIR)\core\sys\posix\pthread.d : src\core\sys\posix\pthread.d
	copy $** $@

$(IMPDIR)\core\sys\posix\pwd.d : src\core\sys\posix\pwd.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sched.d : src\core\sys\posix\sched.d
	copy $** $@

$(IMPDIR)\core\sys\posix\semaphore.d : src\core\sys\posix\semaphore.d
	copy $** $@

$(IMPDIR)\core\sys\posix\setjmp.d : src\core\sys\posix\setjmp.d
	copy $** $@

$(IMPDIR)\core\sys\posix\signal.d : src\core\sys\posix\signal.d
	copy $** $@

$(IMPDIR)\core\sys\posix\stdio.d : src\core\sys\posix\stdio.d
	copy $** $@

$(IMPDIR)\core\sys\posix\stdlib.d : src\core\sys\posix\stdlib.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\ipc.d : src\core\sys\posix\sys\ipc.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\mman.d : src\core\sys\posix\sys\mman.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\select.d : src\core\sys\posix\sys\select.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\shm.d : src\core\sys\posix\sys\shm.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\socket.d : src\core\sys\posix\sys\socket.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\stat.d : src\core\sys\posix\sys\stat.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\time.d : src\core\sys\posix\sys\time.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\types.d : src\core\sys\posix\sys\types.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\uio.d : src\core\sys\posix\sys\uio.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\un.d : src\core\sys\posix\sys\un.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\wait.d : src\core\sys\posix\sys\wait.d
	copy $** $@

$(IMPDIR)\core\sys\posix\sys\utsname.d : src\core\sys\posix\sys\utsname.d
	copy $** $@

$(IMPDIR)\core\sys\posix\termios.d : src\core\sys\posix\termios.d
	copy $** $@

$(IMPDIR)\core\sys\posix\time.d : src\core\sys\posix\time.d
	copy $** $@

$(IMPDIR)\core\sys\posix\ucontext.d : src\core\sys\posix\ucontext.d
	copy $** $@

$(IMPDIR)\core\sys\posix\unistd.d : src\core\sys\posix\unistd.d
	copy $** $@

$(IMPDIR)\core\sys\posix\utime.d : src\core\sys\posix\utime.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dbghelp.d : src\core\sys\windows\dbghelp.d
	copy $** $@

$(IMPDIR)\core\sys\windows\dll.d : src\core\sys\windows\dll.d
	copy $** $@

$(IMPDIR)\core\sys\windows\stacktrace.d : src\core\sys\windows\stacktrace.d
	copy $** $@

$(IMPDIR)\core\sys\windows\threadaux.d : src\core\sys\windows\threadaux.d
	copy $** $@

$(IMPDIR)\core\sys\windows\windows.d : src\core\sys\windows\windows.d
	copy $** $@

$(IMPDIR)\etc\linux\memoryerror.d : src\etc\linux\memoryerror.d
	copy $** $@

################### C Targets ############################

errno_c_mingw64.o : src\core\stdc\errno.c
	$(CC) -c $(CFLAGS) src\core\stdc\errno.c -o errno_c_mingw64.o
	
cbridge_stdio_mingw64.o : src\gcc\cbridge_stdio.c
	$(CC) -c $(CFLAGS) src\gcc\cbridge_stdio.c -o cbridge_stdio_mingw64.o

################### Library generation #########################

$(DRUNTIME_RELEASE): $(OBJS) $(SRCS) mingw64nogc.mak
	$(GDC) -c -o $(DRUNTIME_RELEASE_OBJ) $(DFLAGS_RELEASE) $(DFLAGS) $(SRCS)
	$(AR) -r $(DRUNTIME_RELEASE) $(DRUNTIME_RELEASE_OBJ) $(OBJS)
	$(RANLIB) $(DRUNTIME_RELEASE)

$(DRUNTIME_DEBUG): $(OBJS) $(SRCS) mingw64nogc.mak
	$(GDC) -c -o $(DRUNTIME_DEBUG_OBJ) $(DFLAGS_DEBUG) $(DFLAGS) $(SRCS)
	$(AR) -r $(DRUNTIME_DEBUG) $(DRUNTIME_DEBUG_OBJ) $(OBJS)
	$(RANLIB) $(DRUNTIME_DEBUG)
	
unittest : $(SRCS) $(DRUNTIME) src\unittest.d
	$(GDC) $(UDFLAGS) -fversion=druntime_unittest -funittest src\unittest.d $(SRCS) $(DRUNTIME_DEBUG) -debuglib=$(DRUNTIME_DEBUG) -defaultlib=$(DRUNTIME_DEBUG)

clean:
	del $(DRUNTIME_DEBUG) $(DRUNTIME_RELEASE) $(OBJS_TO_DELETE)
	rmdir /S /Q $(DOCDIR) $(IMPDIR)
