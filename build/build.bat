@echo off
setlocal EnableDelayedExpansion

set thisPath=%~dp0
set binPath=%thisPath%\..\bin
cd %thisPath%\..\src

set "files="
for /r %%i in (*.d) do set files=!files! %%i

set "LIBS_ROOT=%CD%\..\lib
IF NOT EXIST %AE_HOME% do set AE_HOME=%LIBS_ROOT%\ae
IF NOT EXIST %MINILIB_HOME% do set MINILIB_HOME=%LIBS_ROOT%\minilib
IF NOT EXIST %DCOLLECTIONS_HOME% do set DCOLLECTIONS_HOME=%LIBS_ROOT%

set includes=-I%AE_HOME% -I%DCOLLECTIONS_HOME%
set flags=%includes%

set compiler=dmd.exe
rem set compiler=dmd_msc.exe
rem set compiler=ldmd2.exe

rem Note: -g option disabled due to CodeView bugs which crash linkers
rem (both Optlink and Unilink will ICE)
set dtest=rdmd --main -debug -unittest --force

rem %dtest% --compiler=%compiler% %flags% -Isrc minilib\package.d & echo Success: minilib tested.
echo %compiler% -debug -g -w -of%binPath%\minilib.lib -lib %flags% %files% && echo Success: minilib built.
