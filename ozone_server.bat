@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

rem ============================================================
rem  ozone_server.bat - run OpenOCD purely as a GDB server so
rem                     Ozone can attach to the DAPLink.
rem
rem  Ozone does not talk to CMSIS-DAP/DAPLink directly. Since
rem  2025-09-09 it can use a GDB server, so OpenOCD is the bridge:
rem
rem      Ozone  --GDB remote-->  OpenOCD  --SWD-->  board
rem              localhost:3333
rem
rem  Leave this window OPEN while you use Ozone. Close it, or hit
rem  Ctrl+C, to shut the server down.
rem
rem  The chip is already flashed and running normally, so no
rem  RESET holding is needed any more.
rem
rem  ASCII-only on purpose: cmd.exe reads .bat in the OEM codepage.
rem ============================================================

set "IDE_ROOT=C:\ST"
set "SPEED=1000"

if not defined OC (
  for /d %%d in ("%IDE_ROOT%\STM32CubeIDE_*") do (
    for /d %%p in ("%%~fd\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.openocd.win32_*") do (
      if not defined OC if exist "%%~fp\tools\bin\openocd.exe" set "OC=%%~fp\tools\bin\openocd.exe"
    )
  )
)
if not defined SC (
  for /d %%d in ("%IDE_ROOT%\STM32CubeIDE_*") do (
    for /d %%p in ("%%~fd\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.debug.openocd_*") do (
      if not defined SC if exist "%%~fp\resources\openocd\st_scripts\interface\cmsis-dap.cfg" set "SC=%%~fp\resources\openocd\st_scripts"
    )
  )
)
if not defined OC ( echo [ERROR] openocd.exe not found & pause & exit /b 1 )
if not defined SC ( echo [ERROR] st_scripts not found & pause & exit /b 1 )

echo.
echo  =========================================================
echo   OpenOCD GDB server for Ozone
echo  =========================================================
echo.
echo   GDB port      : 3333     ^<- point Ozone here
echo   Telnet port   : 4444
echo   TCL port      : 6666
echo.
echo   KEEP THIS WINDOW OPEN while using Ozone.
echo   Ctrl+C here to stop.
echo.
echo  =========================================================
echo.

"%OC%" -s "%SC%" -f interface/cmsis-dap.cfg -f target/stm32f1x.cfg ^
  -c "adapter speed %SPEED%" ^
  -c "init"

echo.
echo  Server stopped.
pause
