@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

rem ============================================================
rem  debug_tick.bat - watch the global variable "tick" and prove
rem                  it increments at about 1000 per second.
rem
rem  Steps:
rem    1. start OpenOCD in the background, gdb server on :3333
rem    2. GDB connects, flashes build\NO1homework.elf
rem    3. target runs free; every ~3 s GDB halts it and prints tick
rem    4. cleanup: kill OpenOCD, leave the board running
rem
rem  Usage:  debug_tick.bat
rem  Needs:  debug_tick.gdb (same folder), build\NO1homework.elf
rem
rem  NOTE: this kills every openocd.exe at the end. If you also have a
rem        CubeIDE / cortex-debug session open, it dies too.
rem
rem  This file is deliberately ASCII-only. cmd.exe reads .bat files in
rem  the OEM codepage (GBK here), so UTF-8 Chinese in a .bat gets
rem  mangled into garbage commands and the script breaks.
rem ============================================================

set "IDE_ROOT=C:\ST"
set "GDB=C:\tools\arm-gnu-toolchain\bin\arm-none-eabi-gdb.exe"
set "ELF=build\NO1homework.elf"
set "GDBSCRIPT=debug_tick.gdb"
set "OCDLOG=%~dp0openocd_debug.log"
set "SPEED=1000"
set "TARGET_CFG=stm32f1x.cfg"

rem GDB's "shell" command must go through cmd.exe: the delay uses
rem "ping -n", which bash would not understand.
set "SHELL=%COMSPEC%"

rem ---- locate openocd.exe (external tools plugin) ----
if not defined OC (
  for /d %%d in ("%IDE_ROOT%\STM32CubeIDE_*") do (
    for /d %%p in ("%%~fd\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.externaltools.openocd.win32_*") do (
      if not defined OC if exist "%%~fp\tools\bin\openocd.exe" set "OC=%%~fp\tools\bin\openocd.exe"
    )
  )
)

rem ---- locate the OpenOCD scripts (debug plugin -> st_scripts) ----
if not defined SC (
  for /d %%d in ("%IDE_ROOT%\STM32CubeIDE_*") do (
    for /d %%p in ("%%~fd\STM32CubeIDE\plugins\com.st.stm32cube.ide.mcu.debug.openocd_*") do (
      if not defined SC if exist "%%~fp\resources\openocd\st_scripts\interface\cmsis-dap.cfg" set "SC=%%~fp\resources\openocd\st_scripts"
    )
  )
)

if not defined OC        ( echo [ERROR] openocd.exe not found. Set OC or fix IDE_ROOT. & pause & exit /b 1 )
if not defined SC        ( echo [ERROR] st_scripts not found. Set SC. & pause & exit /b 1 )
if not exist "%GDB%"     ( echo [ERROR] gdb not found: %GDB% & pause & exit /b 1 )
if not exist "%GDBSCRIPT%" ( echo [ERROR] %GDBSCRIPT% not found. & pause & exit /b 1 )
if not exist "%ELF%"     ( echo [ERROR] %ELF% not found - build the project first. & pause & exit /b 1 )

echo [*] openocd : %OC%
echo [*] scripts : %SC%
echo [*] gdb     : %GDB%
echo [*] elf     : %ELF%
echo.

if exist "%OCDLOG%" del /q "%OCDLOG%" > nul 2>&1

rem ---- 1) start OpenOCD in the background ----
start "openocd" /min cmd /c ""%OC%" -s "%SC%" -f interface/cmsis-dap.cfg -f target/%TARGET_CFG% -c "adapter speed %SPEED%" > "%OCDLOG%" 2>&1"

rem ---- wait for the gdb server, up to ~15 s ----
set /a TRIES=0
:waitloop
set /a TRIES+=1
ping -n 2 127.0.0.1 > nul 2>&1
findstr /c:"Listening on port 3333" "%OCDLOG%" > nul 2>&1 && goto :ready
findstr /c:"cannot read IDR"        "%OCDLOG%" > nul 2>&1 && goto :dead
if %TRIES% lss 8 goto :waitloop
goto :dead

:ready
echo [OK] OpenOCD ready, gdb server listening on 3333
echo.
"%GDB%" --batch -x "%GDBSCRIPT%" "%ELF%"
set "RC=%ERRORLEVEL%"
echo.
taskkill /f /im openocd.exe > nul 2>&1
echo [*] OpenOCD closed (gdb exit=%RC%)
echo.
pause
exit /b %RC%

:dead
echo.
echo [FAIL] OpenOCD could not reach the target chip.
echo        The probe itself is fine, so the fault is probe-to-MCU:
echo          1. board power
echo          2. SWDIO / SWCLK / GND wiring
echo          3. replug the DAPLink
echo        Last resort: hold BOOT0 high, reset, then connect
echo        (boots from system memory, debug port is guaranteed alive).
echo ------------------------------------------------------------
type "%OCDLOG%"
echo ------------------------------------------------------------
taskkill /f /im openocd.exe > nul 2>&1
pause
exit /b 1
