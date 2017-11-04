@echo off
set config=%1
for %%a in (.) do set project=%%~nxa
if "%config%"=="" set config=Debug
powershell -noprofile -noexit -command "import-module '%~d0%~p0bin\%config%\net462\%project%.dll'"