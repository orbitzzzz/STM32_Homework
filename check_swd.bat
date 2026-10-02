@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

rem ============================================================
rem  check_swd.bat - hammer the SWD link, one attempt per line.
rem
rem  It retries for about a minute, so you have time to act while
rem  it runs. Two experiments, in order:
rem
rem    A. Hold the board's RESET button down.
rem       Connects -> wiring is GOOD, the running firmware is what
rem       kills the debug port.
rem       Never connects -> wrong pins, or swapped SWDIO/SWCLK.
rem
rem    B. If A fails: pull BOOT0 to 3V3, tap reset, try again.
rem
rem  ASCII-only on purpose: cmd.exe reads .bat in the OEM codepage,
rem  so non-ASCII text turns into garbage commands.
rem ============================================================

set "IDE_ROOT=C:\ST"
set "SPEED=1000"
set "ROUNDS=30"

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
echo   Hold the board RESET button down NOW. Every line below is one
echo   connect attempt; watch for a CONNECTED.
echo.

set /a HITS=0
for /l %%i in (1,1,%ROUNDS%) do (
  "%OC%" -s "%SC%" -f interface/cmsis-dap.cfg -f target/stm32f1x.cfg ^
    -c "adapter speed %SPEED%" -c "init" -c "exit" 2>&1 ^
    | findstr /c:"Listening on port 3333" >nul 2>&1
  if !ERRORLEVEL!==0 (
    echo   [%%i] CONNECTED
    set /a HITS+=1
  ) else (
    echo   [%%i] no target
  )
)

echo.
if !HITS! gtr 0 (
  echo [RESULT] !HITS! of %ROUNDS% attempts connected - the SWD link works.
  echo          If it only connects while RESET is held, the firmware on
  echo          the chip is killing the debug port: erase it or use BOOT0.
) else (
  echo [RESULT] 0 of %ROUNDS% attempts connected.
  echo          The probe never saw a chip at all. Re-check WHICH physical
  echo          pins you are on, and whether SWDIO/SWCLK are swapped or
  echo          sitting on the wrong header.
)
echo.
pause
