@echo off

:: Prepare
if not exist bin (
    mkdir bin
)

:: Build
pushd bin
spice build -m release -o .\spice-shaker.exe ..\src\main.spice
popd