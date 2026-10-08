@echo off
rem Runs the mise-managed checkstyle jar on the mise-managed JDK.
rem The jar's directory carries its version, so resolve it through mise.
setlocal
for /f "delims=" %%d in ('mise where github:checkstyle/checkstyle') do set "dir=%%d"
for %%j in ("%dir%\checkstyle-*-all.jar") do java -jar "%%j" %*
