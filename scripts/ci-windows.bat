@echo off
REM CI script for Windows (batch)
REM Usage: run this in the repository root on Windows CI runners (GitHub Actions windows-latest, etc.)

setlocal enabledelayedexpansion

echo Creating build directory...
if exist build (
    rmdir /s /q build
)
mkdir build
if errorlevel 1 (
    echo Failed to create build directory
    exit /b 1
)

cd build
if errorlevel 1 (
    echo Failed to change to build directory
    exit /b 1
)

echo Running CMake configure...
cmake ..
if errorlevel 1 (
    echo CMake configuration failed
    exit /b 1
)

echo Building project...
cmake --build . --config Release
if errorlevel 1 (
    echo Build failed
    exit /b 1
)

echo Running tests with CTest...
ctest --output-on-failure
if errorlevel 1 (
    echo Some tests failed
    exit /b 1
)

echo All steps completed successfully.
endlocal
exit /b 0