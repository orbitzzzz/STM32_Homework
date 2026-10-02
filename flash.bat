@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

rem ============================================================
rem  flash.bat - program this STM32 through a DAPLink/CMSIS-DAP probe
rem
rem  STM32CubeProgrammer cannot talk to DAPLink (its only backends are
rem  ST-LINK and J-Link), so this drives the OpenOCD that ships inside
rem  STM32CubeIDE instead. No extra driver or DLL swap is needed.
rem
rem  Usage:
rem    flash.bat                  flash the newest .elf under build\
rem    flash.bat <file.elf|hex>   flash a specific file
rem    flash.bat info             read-only: probe the chip, print IDCODE
rem                               and flash size, then let it run again
rem
rem  Notes:
rem   - The probe reports nRESET = 0 (no reset wire). Resetting therefore
rem     uses SYSRESETREQ (software reset). If you ever flash firmware that
rem     disables the SWJ pins, hold BOOT0 high to boot from system memory
rem     and recover.
rem   - Override autodetection by pre-setting the OC and SC env vars.
rem ============================================================

set "IDE_ROOT=C:\ST"
set "TARGET_CFG=stm32f1x.cfg"
set "SPEED=1000"

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

if not defined OC (
  echo [ERROR] openocd.exe not found under "%IDE_ROOT%".
  echo         Edit IDE_ROOT in this file, or set the OC environment variable.
  pause
  exit /b 1
)
if not defined SC (
  echo [ERROR] OpenOCD scripts ^(st_scripts^) not found.
  echo         Set the SC environment variable to the st_scripts folder.
  pause
  exit /b 1
)

if /i "%~1"=="info" goto :info

rem ---- flash mode ----
set "FW=%~1"
if "%FW%"=="" (
  rem Pick the newest .elf anywhere under build\. Preset builds land in
  rem build\Debug or build\Release; a plain "cmake -B build" lands in
  rem build\. Taking the newest avoids flashing a stale image.
  for /f "delims=" %%i in ('dir /b /s /o-d "build\*.elf" 2^>nul ^| findstr /v /i "CMakeFiles"') do (
    if not defined FW set "FW=%%i"
  )
)
if "%FW%"=="" (
  echo [ERROR] no .elf found under build\ - build the project first.
  pause
  exit /b 1
)
for %%i in ("%FW%") do set "FWT=%%~ti"
set "FW=%FW:\=/%"
if not exist "%FW%" (
  echo [ERROR] firmware file not found: %FW%
  pause
  exit /b 1
)

echo [*] openocd : %OC%
echo [*] probe   : CMSIS-DAP  (%TARGET_CFG%, %SPEED% kHz)
echo [*] file    : %FW%   (built %FWT%)
echo.
"%OC%" -s "%SC%" -f interface/cmsis-dap.cfg -f target/%TARGET_CFG% ^
  -c "adapter speed %SPEED%" ^
  -c "program {%FW%} verify reset exit"
set "RC=%ERRORLEVEL%"
echo.
if "%RC%"=="0" (
  echo [OK] programmed, verified, target reset and running.
) else (
  echo [FAIL] openocd exited with code %RC%
)
pause
exit /b %RC%

:info
echo [*] read-only probe - nothing is written to flash
echo.
"%OC%" -s "%SC%" -f interface/cmsis-dap.cfg -f target/%TARGET_CFG% ^
  -c "adapter speed %SPEED%" ^
  -c "init" ^
  -c "flash probe 0" ^
  -c "echo {--- DBGMCU_IDCODE (bits 15:0 = DEV_ID) ---}" ^
  -c "mdw 0xE0042000 1" ^
  -c "reset run" ^
  -c "exit"
echo.
pause
exit /b 0
