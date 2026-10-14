@echo off

:: Prepare
if not exist build (
    mkdir build
)

:: Build
pushd build
spice build -m release -o .\spice-shaker.exe ..\src\main.spice
popd