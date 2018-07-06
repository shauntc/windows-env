@echo off
:: This only runs when launched from tools/shortcuts 
echo|set /p="[107;30m Cmd [0m"
net session >nul 2>&1
if %errorLevel% == 0 (
    :: Has admin privilages
    echo [41;37m Admin\%USERNAME% [0m
) else (
    :: Does not have admin privilages
    echo [42;37m User\%USERNAME% [0m
    cd %USERPROFILE%
)