echo %1
set PATH=C:\Program Files (x86)\Microsoft Visual Studio 8\VC\redist\amd64\Microsoft.VC80.CRT;C:\Program Files (x86)\Microsoft Visual Studio 8\VC\bin\amd64;%PATH%
dumpbin.exe /exports %1