@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

rem ============================================================
rem  flash_recover.bat - erase the chip, then flash our build.
rem
rem  WHY TWO STAGES
rem  The firmware sitting in the chip kills the SWD port the
rem  moment it runs. Stage 1 must grab the core WHILE the RESET
rem  button is held. Once erased there is no firmware left to
rem  kill anything, so stage 2 needs no button at all.
rem
rem  HOW THE CORE IS CAUGHT
rem  After init, "halt" writes C_HALT into DHCSR. While RESET is
rem  held the core sits in reset, so halt reports a timeout - but
rem  the request is already latched. Let go, and the core drops
rem  straight into debug halt instead of running the firmware.
rem
rem  WHY EVERYTHING IS INLINE
rem  This file deliberately uses no "call :label". A line whose
rem  echoed string contains parentheses, continued with ^, makes
rem  cmd.exe lose track of where labels are, and later calls fail
rem  with "cannot find batch label". Running inline also means
rem  ERRORLEVEL is read straight off the command, with no
rem  subroutine return to overwrite it.
rem
rem  Stage 1 prints to the CONSOLE on purpose: OpenOCD buffers
rem  block-wise when its output is redirected, so the RELEASE
rem  RESET NOW prompt would never appear in time. Only stage 2
rem  is logged. Note -l is no good either, it steals echo output.
rem
rem  WARNING: stage 1 does a FULL CHIP ERASE.
rem
rem  ASCII-only: cmd.exe reads .bat in the OEM codepage.
rem ============================================================

set "IDE_ROOT=C:\ST"
set "SPEED=1000"
rem NOTE: Windows-style drive path with forward slashes. A leading
rem slash such as /D:/... is a Git-Bash path and makes OpenOCD
rem fail with "couldn't open".
set "ELF=D:/STM32MX/NO1homework/build/NO1homework.elf"
set "LOG2=%~dp0stage2.log"

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
if not exist "build\NO1homework.elf" ( echo [ERROR] build\NO1homework.elf missing & pause & exit /b 1 )

echo.
echo  =========================================================
echo   STAGE 1 - erase the chip.  Needs the RESET button.
echo  =========================================================
echo.
echo    1. PRESS AND HOLD the RESET button on the board.
echo    2. Press any key below.
echo    3. Keep holding.  A few lines scroll, then a box appears:
echo.
echo          ***********************************
echo          ***   RELEASE RESET NOW!        ***
echo          ***********************************
echo.
echo    4. Let go the moment you see that box.
echo.
echo   Stage 2 then runs by itself, no button needed.
echo   This ERASES the whole chip - nothing of value is on it.
echo.
pause

set /a N=0

:s1loop
set /a N+=1
if %N% gtr 5 goto :s1fail

echo.
echo ---------- stage 1, attempt %N% ----------
"%OC%" -s "%SC%" -f interface/cmsis-dap.cfg -f target/stm32f1x.cfg ^
  -c "adapter speed %SPEED%" ^
  -c "init" ^
  -c "echo halt_latch_rc=[catch {halt}]" ^
  -c "echo resethalt_latch_rc=[catch {reset halt}]" ^
  -c "echo {}" ^
  -c "echo {***********************************}" ^
  -c "echo {***   RELEASE RESET NOW!        ***}" ^
  -c "echo {***********************************}" ^
  -c "sleep 12000" ^
  -c "echo after_release_halt_rc=[catch {halt}]" ^
  -c "echo after_release_wait_rc=[catch {wait_halt 5000}]" ^
  -c "catch {stm32f1x unlock 0}" ^
  -c "echo {--- erasing whole chip ---}" ^
  -c "stm32f1x mass_erase 0" ^
  -c "echo {--- blank check, all ffffffff means clean ---}" ^
  -c "mdw 0x08000000 4" ^
  -c "echo {--- stage 1 done, core left halted ---}" ^
  -c "exit"

if errorlevel 1 goto :s1retry
echo.
echo  [OK] stage 1: erase command returned clean.
goto :s2go

:s1retry
echo.
echo  stage 1 attempt %N% FAILED - it did NOT erase.
echo  Look at the last Error line above:
echo    "cannot read IDR" = the grab missed. Hold RESET BEFORE
echo                        pressing the key, and keep holding
echo                        until the RELEASE box appears.
echo    anything else     = tell me that line.
echo.
echo  Hold RESET again, then press a key to retry.
pause
goto :s1loop

:s1fail
echo.
echo  [FAIL] stage 1 gave up after 5 tries. Chip untouched.
echo.
pause
exit /b 1

:s2go
echo.
echo  =========================================================
echo   STAGE 2 - program.  LET GO of the board. Hands off.
echo  =========================================================
echo.
"%OC%" -s "%SC%" -f interface/cmsis-dap.cfg -f target/stm32f1x.cfg ^
  -c "adapter speed %SPEED%" ^
  -c "init" ^
  -c "echo {--- programming ---}" ^
  -c "program {%ELF%} verify" ^
  -c "echo {STAGE2_MARKER_PROGRAMMED}" ^
  -c "reset run" ^
  -c "exit" ^
  > "%LOG2%" 2>&1

findstr /c:"STAGE2_MARKER_PROGRAMMED" "%LOG2%" >nul 2>&1
if errorlevel 1 goto :s2fail

echo  [OK] stage 2: flashed and verified.
echo.
echo  =========================================================
echo   DONE.  The chip now runs our firmware, so SWD works
echo   normally from here on - no more holding RESET.
echo  =========================================================
echo.
echo   To watch tick climb:   debug_tick.bat
echo.
pause
exit /b 0

:s2fail
echo.
echo  [FAIL] erase worked but programming failed. Read stage2.log.
echo         The chip is now BLANK and needs the flash redone.
echo.
pause
exit /b 1
