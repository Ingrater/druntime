C:\digital-mars\dmd2\windows\bin-nostd\dmd.exe tests.d -m64 -op -debug -g -debuglib=druntimenogc64d -I..\import -version=NOGCSAFE -oftests64.exe -L/LIBPATH:"%CD%\..\lib"
@if errorlevel 1 goto reportError

tests64

@goto noError

:reportError
@echo building nogc tests in 64 bit failed!

:noError