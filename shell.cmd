@echo off

set REPOSITORY_ROOT=%~d0%~p0
set SOURCE_DIRECTORY=src
set ENV=Local

powershell ^
 -nologo ^
 -noexit ^
 -command ".'%~d0%~p0tools\pacman\shell.ps1' -RepositoryRoot '%REPOSITORY_ROOT%' -DefaultRepository '%SOURCE_DIRECTORY%' -Environment '%ENV%'"