@echo off
setlocal ENABLEEXTENSIONS ENABLEDELAYEDEXPANSION

:: Defaults
if "%PGMICRO_REPO%"=="" set PGMICRO_REPO=https://github.com/ainvyu/pgmicro.git
if "%PGMICRO_BUILD_PROFILE%"=="" set PGMICRO_BUILD_PROFILE=lib-release
if "%PGMICRO_BUILD_DIR%"=="" set PGMICRO_BUILD_DIR=pgmicro
if "%PGMICRO_CARGO_PACKAGE%"=="" set PGMICRO_CARGO_PACKAGE=turso_sdk_kit
if "%PGMICRO_CARGO_FEATURES%"=="" set PGMICRO_CARGO_FEATURES=default-postgres
if "%PGMICRO_LIBC_VARIANT%"=="" set PGMICRO_LIBC_VARIANT=
if "%PGMICRO_GO_LIB_DIR%"=="" set PGMICRO_GO_LIB_DIR=libs
if "%PGMICRO_OUTPUT_NAME%"=="" set PGMICRO_OUTPUT_NAME=pgmicro_sdk_kit

if "%PGMICRO_BUILD_REF%"=="" (
    echo PGMICRO_BUILD_REF env var must be set
    exit /b 1
)

:: OS/ARCH detection
for /f "delims=" %%i in ('powershell -NoProfile -Command "$env:PROCESSOR_ARCHITECTURE"') do set UNAME_M=%%i

set OS=windows
if /I "%UNAME_M%"=="ARM64" (
    set ARCH=arm64
) else (
    set ARCH=amd64
)

set PLATFORM=%OS%_%ARCH%%PGMICRO_LIBC_VARIANT%
set PGMICRO_GO_LIB_PATH=%PGMICRO_GO_LIB_DIR%\%PLATFORM%

set UPSTREAM_OUT=%PGMICRO_CARGO_PACKAGE%.dll
set FINAL_NAME=%PGMICRO_OUTPUT_NAME%.dll

set CARGO_OUT_DIR=%PGMICRO_BUILD_DIR%\target\%PGMICRO_BUILD_PROFILE%
set CARGO_LIB_PATH=%CARGO_OUT_DIR%\%UPSTREAM_OUT%

echo PGMICRO_REPO:           %PGMICRO_REPO%
echo PGMICRO_BUILD_REF:      %PGMICRO_BUILD_REF%
echo PGMICRO_CARGO_PACKAGE:  %PGMICRO_CARGO_PACKAGE%
echo PGMICRO_CARGO_FEATURES: %PGMICRO_CARGO_FEATURES%
echo PLATFORM:               %PLATFORM%
echo UPSTREAM_OUT:           %UPSTREAM_OUT%
echo FINAL_NAME:             %FINAL_NAME%
echo CARGO_LIB_PATH:         %CARGO_LIB_PATH%
echo PGMICRO_GO_LIB_PATH:    %PGMICRO_GO_LIB_PATH%

git clone --single-branch --depth 1 --branch "%PGMICRO_BUILD_REF%" "%PGMICRO_REPO%" "%PGMICRO_BUILD_DIR%"
if errorlevel 1 (
    echo Failed to clone repo
    exit /b 1
)

pushd "%PGMICRO_BUILD_DIR%"
echo Building %PGMICRO_CARGO_PACKAGE% (%PGMICRO_BUILD_PROFILE%, features=%PGMICRO_CARGO_FEATURES%) for %PLATFORM%
cargo build --profile "%PGMICRO_BUILD_PROFILE%" --features "%PGMICRO_CARGO_FEATURES%" --package "%PGMICRO_CARGO_PACKAGE%"
if errorlevel 1 (
    echo Cargo build failed
    popd
    exit /b 1
)
popd

if not exist "%CARGO_LIB_PATH%" (
    echo Expected artifact not found: %CARGO_LIB_PATH%
    echo Contents of %CARGO_OUT_DIR%:
    dir "%CARGO_OUT_DIR%"
    exit /b 1
)

if not exist "%PGMICRO_GO_LIB_PATH%" mkdir "%PGMICRO_GO_LIB_PATH%"
copy /y "%CARGO_LIB_PATH%" "%PGMICRO_GO_LIB_PATH%\%FINAL_NAME%"

echo Wrote %CD%\%PGMICRO_GO_LIB_PATH%\%FINAL_NAME%

exit /b 0
