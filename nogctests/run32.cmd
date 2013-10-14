@set DMD_LIB=;%CD%\..\lib
C:\digital-mars\dmd2\windows\bin-nostd\dmd.exe tests.d -debug -g -debuglib=druntimenogcd -I..\import -version=NOGCSAFE -oftests32.exe
@if errorlevel 1 goto reportError

tests32

@goto noError

:reportError
@echo building nogc tests in 32 bit failed!

:noError