@echo off
setlocal enabledelayedexpansion
cd /d "%~dp0"

rem ============================================================
rem  swd_check.bat - two-phase SWD diagnostic, logged to a file.
rem
rem  PHASE A  hands off the board (firmware running).
rem  PHASE B  you HOLD the RESET button down.
rem
rem  Comparing the two tells us whether the running firmware is
rem  what kills the debug port, or whether the wiring itself is
rem  bad. Read swd_check.log afterwards.
rem
rem  Nothing is written to the chip. Read-only.
rem
rem  ASCII-only on purpose: cmd.exe reads .bat in the OEM codepage.
rem ============================================================

set "IDE_ROOT=C:\ST"
set "SPEED=1000"
set "LOG=%~dp0swd_check.log"
set "ROUNDS_A=8"
set "ROUNDS_B=25"

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

echo. > "%LOG%"
call :stamp "swd_check start"

echo.
echo  ==========================================================
echo   PHASE A - DO NOT TOUCH THE BOARD. Leave it alone.
echo   Starting in 4 seconds.
echo  ==========================================================
timeout /t 4 /nobreak >nul 2>&1

set /a HITS_A=0
for /l %%i in (1,1,%ROUNDS_A%) do (
  call :try %%i
  if !ERRORLEVEL!==0 ( set /a HITS_A+=1 )
)

echo.
echo  ==========================================================
echo   PHASE B - HOLD THE RESET BUTTON DOWN. Keep it down.
echo  ==========================================================
echo.
echo   Press any key, then immediately hold RESET until the
echo   whole phase finishes (about a minute).
echo.
pause

set /a HITS_B=0
for /l %%i in (1,1,%ROUNDS_B%) do (
  call :try %%i
  if !ERRORLEVEL!==0 ( set /a HITS_B+=1 )
)

echo.
echo  ==========================================================
echo   PHASE A (board untouched) : %HITS_A% / %ROUNDS_A% connected
echo   PHASE B (RESET held)      : %HITS_B% / %ROUNDS_B% connected
echo  ==========================================================
echo.
call :stamp "swd_check result A=%HITS_A%/%ROUNDS_A% B=%HITS_B%/%ROUNDS_B%"
>>"%LOG%" echo RESULT A=%HITS_A%/%ROUNDS_A% B=%HITS_B%/%ROUNDS_B%

if %HITS_B% gtr 0 (
  echo  [READ] RESET held -^> chip answers. The firmware on it is
  echo         killing the debug port. Erase it and reflash.
) else (
  echo  [READ] Even with RESET held the chip never answers.
  echo         This is WIRING, not firmware. Check SWDIO / SWCLK
  echo         are not swapped, and that GND is really common.
)
echo.
echo  Log written to: %LOG%
echo.
pause
exit /b 0


:try
set /a ATT=%~1
"%OC%" -s "%SC%" -f interface/cmsis-dap.cfg -f target/stm32f1x.cfg ^
  -c "adapter speed %SPEED%" -c "init" -c "exit" > "%~dp0_oc_tmp.log" 2>&1
findstr /c:"Listening on port 3333" "%~dp0_oc_tmp.log" >nul 2>&1
if !ERRORLEVEL!==0 (
  echo   [%ATT%] CONNECTED
  >>"%LOG%" echo   try %ATT% CONNECTED
  exit /b 0
) else (
  findstr /c:"cannot read IDR" "%~dp0_oc_tmp.log" >nul 2>&1
  if !ERRORLEVEL!==0 (
    echo   [%ATT%] no target  ^(cannot read IDR^)
    >>"%LOG%" echo   try %ATT% no-target cannot-read-IDR
  ) else (
    echo   [%ATT%] FAILED - see _oc_tmp.log
    >>"%LOG%" echo   try %ATT% FAILED-other
    >>"%LOG%" type "%~dp0_oc_tmp.log"
  )
  exit /b 1
)

:stamp
>>"%LOG%" echo [%DATE% %TIME%] %~1
exit /b 0
