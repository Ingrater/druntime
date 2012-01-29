#!/bin/sh

txtblk='\e[0;30m' # Black - Regular
txtred='\e[0;31m' # Red
txtgrn='\e[0;32m' # Green
txtylw='\e[0;33m' # Yellow
txtblu='\e[0;34m' # Blue
txtpur='\e[0;35m' # Purple
txtcyn='\e[0;36m' # Cyan
txtwht='\e[0;37m' # White
bldblk='\e[1;30m' # Black - Bold
bldred='\e[1;31m' # Red
bldgrn='\e[1;32m' # Green
bldylw='\e[1;33m' # Yellow
bldblu='\e[1;34m' # Blue
bldpur='\e[1;35m' # Purple
bldcyn='\e[1;36m' # Cyan
bldwht='\e[1;37m' # White
unkblk='\e[4;30m' # Black - Underline
undred='\e[4;31m' # Red
undgrn='\e[4;32m' # Green
undylw='\e[4;33m' # Yellow
undblu='\e[4;34m' # Blue
undpur='\e[4;35m' # Purple
undcyn='\e[4;36m' # Cyan
undwht='\e[4;37m' # White
bakblk='\e[40m'   # Black - Background
bakred='\e[41m'   # Red
badgrn='\e[42m'   # Green
bakylw='\e[43m'   # Yellow
bakblu='\e[44m'   # Blue
bakpur='\e[45m'   # Purple
bakcyn='\e[46m'   # Cyan
bakwht='\e[47m'   # White
txtrst='\e[0m'    # Text Reset

DMD=dmd
CC=dmc
IMPLIB=implib
DUMPBIN="./dumpbinhelper.bat"

DOCDIR=doc
IMPDIR=include

DFLAGS="-debug -g -nofloat -w -d -Isrc -Iimport -property -version=NOGCSAFE"
UDFLAGS="-debug -g -nofloat -w -d -Isrc -Iimport -property"

DLL="lib\\druntimenogc.dll"
LIB="lib\\druntimenogcdll.lib"
LIBIMP="lib\\druntimenogcdllimp.lib"
DEFDLL=druntimedll.def
DEFLIB=druntimelib.def
DEFEMPTY=druntimedllempty.def

DRUNTIME_BASE=druntimenogc
DRUNTIME="lib\\${DRUNTIME_BASE}.lib"
GCSTUB="lib\\gcstub.obj"

SRCS=" \
	src\object_.d \
	\
	src\core\atomic.d \
	src\core\bitop.d \
	src\core\cpuid.d \
	src\core\demangle.d \
	src\core\exception.d \
	src\core\math.d \
	src\core\memory.d \
	src\core\runtime.d \
	src\core\thread.d \
	src\core\time.d \
	src\core\vararg.d \
	src\core\allocator.d \
	src\core\refcounted.d \
	src\core\hashmap.d \
	src\core\traits.d \
	\
	src\core\stdc\config.d \
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
	src\core\stdc\ctype.d \
	\
	src\core\sys\windows\dbghelp.d \
	src\core\sys\windows\dll.d \
	src\core\sys\windows\stacktrace.d \
	src\core\sys\windows\threadaux.d \
	src\core\sys\windows\windows.d \
	\
	src\core\sync\barrier.d \
	src\core\sync\condition.d \
	src\core\sync\config.d \
	src\core\sync\exception.d \
	src\core\sync\mutex.d \
	src\core\sync\rwmutex.d \
	src\core\sync\semaphore.d \
	\
	src\gc\gc.d \
	src\gc\gcalloc.d \
	src\gc\gcbits.d \
	src\gc\gcstats.d \
	src\gc\gcx.d \
	\
	src\rt\dmain2.d \
	src\rt\aaA.d \
	src\rt\aApply.d \
	src\rt\aApplyR.d \
	src\rt\adi.d \
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
	src\rt\cover.d \
	src\rt\deh.d \
	src\rt\invariant.d \
	src\rt\invariant_.d \
	src\rt\lifetime.d \
	src\rt\llmath.d \
	src\rt\memory.d \
	src\rt\memset.d \
	src\rt\minfo.d \
	src\rt\obj.d \
	src\rt\qsort.d \
	src\rt\switch_.d \
	src\rt\trace.d \
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
	src\dllmain.d"
	
MAINSRC="src\dlllib.d"
	
OBJS="errno_c.obj complex.obj src\rt\minit.obj monitor.obj critical.obj duma.obj print.obj sem_inc.obj"

#make the statically linke druntime first
echo -e "${bldgrn}Compiling static druntime${txtrst}"
make -f win32nogc.mak
if [ $? -ne 0 ]; then
  exit 1
fi

echo -e "${bldgrn}creating druntime object file${txtrst}"	
$DMD -c $SRCS $DFLAGS -of${DRUNTIME_BASE}.obj -version=DLL -defaultlib="" -debuglib=""
if [ $? -ne 0 ]; then
  exit 1
fi

echo -e "${bldgrn}creating linker map file${txtrst}"
$DMD ${DRUNTIME_BASE}.obj $OBJS $DEFEMPTY $DFLAGS -of${DLL} -map ${DRUNTIME_BASE}.map
if [ $? -ne 0 ]; then
  exit 1
fi

#run def generator here
echo -e "${bldgrn}generating .def files${txtrst}"
#StartLine=`grep -n "Address       Export                  Alias" ${DRUNTIME_BASE}.map | awk '{ print $1 }'`
#EndLine=`grep -n "Address         Publics by Name               Rva+Base" ${DRUNTIME_BASE}.map | awk '{ print $1 }'`

### Workaround for Optlink bug 6673 ###
$DUMPBIN ${DLL} > dumpbin.map
StartLine=`grep -n "ordinal hint RVA      name" dumpbin.map | awk '{ print $1 }'`
EndLine=`grep -n "  Summary" dumpbin.map | awk '{ print $1 }'`
StartLine=${StartLine:0:${#StartLine}-1}
EndLine=${EndLine:0:${#EndLine}-1}
((StartLine++))
((EndLine--))
echo -e "{bldgrn}start: $StartLine end: $EndLine${txtrst}"

cp $DEFEMPTY $DEFDLL

#replace PRELOAD DISCARDABLE with SHARED EXECUTE
rm $DEFLIB
cat $DEFEMPTY | while read line
do
  echo ${line/"PRELOAD DISCARDABLE"/"SHARED EXECUTE"} >> $DEFLIB
done

echo -e "\nEXPORTS" >> $DEFDLL
echo -e "\nEXPORTS" >> $DEFLIB

cat forcedExports.txt | while read line
do
  echo -e "\t$line" >> $DEFDLL
  echo -e "\t_$line = $line " >> $DEFLIB
  echo "forced: $line"
done

lineNum=1
cat dumpbin.map | while read line && [ $lineNum -lt $EndLine ]
do
  if [ $lineNum -gt $StartLine ]; then
    symbol=`echo $line | awk '{ print $4 }'`
	echo -e "\t$symbol" >> $DEFDLL
	echo -e "\t_$symbol = $symbol " >> $DEFLIB
	echo "exported: $symbol"
  fi
  ((lineNum++))
done

echo -e "${bldgrn}linking dll${txtrst}"
$DMD ${DRUNTIME_BASE}.obj $OBJS $DEFDLL $DFLAGS -of${DLL}
if [ $? -ne 0 ]; then
  exit 1
fi

echo -e "${bldgrn}creating import .lib${txtrst}"
$IMPLIB /noi $LIBIMP $DEFLIB
if [ $? -ne 0 ]; then
  exit 1
fi

echo -e "${bldgrn}creating runtime .lib${txtrst}"
$DMD $MAINSRC -lib $DFLAGS -of$LIB $LIBIMP