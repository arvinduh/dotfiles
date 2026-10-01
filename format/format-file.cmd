@echo off
setlocal
where bash >nul 2>&1
if %ERRORLEVEL% equ 0 (
  bash "%~dp0format-file" %*
) else (
  echo bash not found, unable to run format-file 1>&2
  exit /b 1
)
