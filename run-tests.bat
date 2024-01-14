@echo off

:: Prepare
if not exist bin (
    mkdir bin
)

:: Build
pushd bin
spice test ..\test\wrapper.spice
popd