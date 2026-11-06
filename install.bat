@echo off
setlocal
title Bangla Fonts Installer

rem Pause at the end when launched by double-clicking from Explorer, so the
rem summary stays visible. When started from a console, keep the window open.
set "DOUBLECLICKED="
echo "%cmdcmdline%" | findstr /i /c:"%~nx0" >nul
if not errorlevel 1 set "DOUBLECLICKED=1"

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install.ps1" %*
set "EXITCODE=%ERRORLEVEL%"

if not "%EXITCODE%"=="0" (
    echo.
    echo Installation failed with exit code %EXITCODE%.
    pause
) else if defined DOUBLECLICKED (
    echo.
    pause
)

exit /b %EXITCODE%
