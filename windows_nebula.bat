# Write the corrected batch script to file with Lighthouse always assumed false
from pathlib import Path

script_name = "nebula_setup_lighthouse_false_fixed.bat"
script_path = Path("/mnt/data") / script_name

corrected_script = r"""@echo off
echo [DEBUG] Starting Nebula setup script

:: -------------------------------------------------------------
:: Required environment variables
:: -------------------------------------------------------------
set "ANYLOG_SERVER_PORT=7848"
set "ANYLOG_REST_PORT=7849"
set "ANYLOG_BROKER_PORT=7850"
set "OVERLAY_IP=10.10.1.5"
set "CIDR_OVERLAY_ADDRESS=10.10.1.1/24"
set "LIGHTHOUSE_IP=10.10.1.1"
set "LIGHTHOUSE_NODE_IP=172.233.108.122"
set "IS_LIGHTHOUSE=false"
set "REMOTE_CLI=false"
set "GRAFANA=false"

:: -------------------------------------------------------------
:: Static paths and defaults
:: -------------------------------------------------------------
set "NEBULA_VERSION=v1.8.2"
set "NEBULA_ZIP_NAME=nebula-windows-amd64.zip"
set "DOWNLOAD_URL=https://github.com/slackhq/nebula/releases/download/%NEBULA_VERSION%/%NEBULA_ZIP_NAME%"
set "NEBULA_CONFIG_DIR=D:\AnyLog-code\AnyLog-Network\nebula"
set "NEBULA_EXE_DIR=%NEBULA_CONFIG_DIR%\bin"
set "NEBULA_LOG=%NEBULA_EXE_DIR%\nebula.log"

:: -------------------------------------------------------------
:: Download and unzip Nebula if needed
:: -------------------------------------------------------------
if not exist "%NEBULA_EXE_DIR%\nebula.exe" (
    echo [DEBUG] Nebula executables not found – downloading...
    mkdir "%NEBULA_EXE_DIR%" >nul 2>&1

    echo [DEBUG] Downloading: %DOWNLOAD_URL%
    curl -L "%DOWNLOAD_URL%" -o "%NEBULA_CONFIG_DIR%\%NEBULA_ZIP_NAME%"
    if errorlevel 1 (
        echo [ERROR] Failed to download Nebula zip
        exit /b 1
    )

    echo [DEBUG] Extracting Nebula ZIP to %NEBULA_EXE_DIR%
    powershell -Command "Expand-Archive -Force -Path '%NEBULA_CONFIG_DIR%\%NEBULA_ZIP_NAME%' -DestinationPath '%NEBULA_EXE_DIR%'"
    if errorlevel 1 (
        echo [ERROR] Failed to extract Nebula zip
        exit /b 1
    )
    del "%NEBULA_CONFIG_DIR%\%NEBULA_ZIP_NAME%"
)

if not exist "%NEBULA_EXE_DIR%\nebula.exe" (
    echo [ERROR] nebula.exe not found after extraction
    exit /b 1
)
if not exist "%NEBULA_EXE_DIR%\nebula-cert.exe" (
    echo [ERROR] nebula-cert.exe not found after extraction
    exit /b 1
)

:: -------------------------------------------------------------
:: Verify Overlay IP
:: -------------------------------------------------------------
if "%OVERLAY_IP%"=="" (
    echo [ERROR] Missing desired Overlay IP address
    exit /b 1
)

findstr /C:"%OVERLAY_IP%" "%NEBULA_CONFIG_DIR%\used_ips.txt" >nul 2>&1
if %errorlevel%==0 (
    echo [ERROR] IP Address %OVERLAY_IP% already used, cannot connect to nebula
    exit /b 1
)

:: -------------------------------------------------------------
:: Copy CA files if they exist
:: -------------------------------------------------------------
if exist "%NEBULA_CONFIG_DIR%\configs\ca.crt" (
    echo [DEBUG] Copying ca.crt
    copy /Y "%NEBULA_CONFIG_DIR%\configs\ca.crt" "%NEBULA_EXE_DIR%"
    copy /Y "%NEBULA_CONFIG_DIR%\configs\ca.crt" "%NEBULA_CONFIG_DIR%"
)

if exist "%NEBULA_CONFIG_DIR%\configs\ca.key" (
    echo [DEBUG] Copying ca.key
    copy /Y "%NEBULA_CONFIG_DIR%\configs\ca.key" "%NEBULA_EXE_DIR%"
    copy /Y "%NEBULA_CONFIG_DIR%\configs\ca.key" "%NEBULA_CONFIG_DIR%"
)

:: -------------------------------------------------------------
:: Always treat as non-lighthouse: Copy lighthouse files to host.*
:: -------------------------------------------------------------
if exist "%NEBULA_CONFIG_DIR%\configs\lighthouse.crt" (
    echo [DEBUG] Copying lighthouse.crt to host.crt
    copy /Y "%NEBULA_CONFIG_DIR%\configs\lighthouse.crt" "%NEBULA_EXE_DIR%\host.crt"
    copy /Y "%NEBULA_CONFIG_DIR%\configs\lighthouse.crt" "%NEBULA_CONFIG_DIR%\host.crt"
)

if exist "%NEBULA_CONFIG_DIR%\configs\lighthouse.key" (
    echo [DEBUG] Copying lighthouse.key to host.key
    copy /Y "%NEBULA_CONFIG_DIR%\configs\lighthouse.key" "%NEBULA_EXE_DIR%\host.key"
    copy /Y "%NEBULA_CONFIG_DIR%\configs\lighthouse.key" "%NEBULA_CONFIG_DIR%\host.key"
)

:: -------------------------------------------------------------
:: Build Python configuration command
:: -------------------------------------------------------------
set CMD=python "%NEBULA_CONFIG_DIR%\config_nebula.py" %CIDR_OVERLAY_ADDRESS% %ANYLOG_SERVER_PORT% %ANYLOG_REST_PORT%

if defined ANYLOG_BROKER_PORT (
    set CMD=%CMD% --broker-port %ANYLOG_BROKER_PORT%
)
if /I "%REMOTE_CLI%"=="true" (
    set CMD=%CMD% --remote-cli
)
if /I "%GRAFANA%"=="true" (
    set CMD=%CMD% --grafana
)
set CMD=%CMD% --lighthouse-node-ip %LIGHTHOUSE_NODE_IP%

echo [DEBUG] Executing configuration script: %CMD%
cmd /c %CMD%
if errorlevel 1 (
    echo [ERROR] Python configuration script failed
    exit /b 1
)

:: -------------------------------------------------------------
:: Copy node.yml
:: -------------------------------------------------------------
if exist "%NEBULA_CONFIG_DIR%\node.yml" (
    echo [DEBUG] Copying node.yml to bin directory
    copy /Y "%NEBULA_CONFIG_DIR%\node.yml" "%NEBULA_EXE_DIR%\node.yml"
)

if not exist "%NEBULA_EXE_DIR%\node.yml" (
    echo [ERROR] node.yml not found in execution directory
    exit /b 1
)

:: -------------------------------------------------------------
:: Start Nebula
:: -------------------------------------------------------------
echo [DEBUG] Starting Nebula node
pushd "%NEBULA_EXE_DIR%"
start /b "" cmd /c "nebula.exe -config node.yml > "%NEBULA_LOG%" 2>&1"
popd

timeout /t 2 >nul

:: -------------------------------------------------------------
:: Wait for Nebula to start
:: -------------------------------------------------------------
echo [DEBUG] Waiting for Nebula to start
set /a timeout=30
set /a elapsed=0

:wait_loop
timeout /t 1 >nul
set /a elapsed+=1
findstr /C:"Nebula interface is active" "%NEBULA_LOG%" >nul 2>&1
if %errorlevel%==0 (
    echo [INFO] Nebula is up and running.
    goto end
)
if %elapsed% GEQ %timeout% (
    echo [WARNING] Timeout reached waiting for Nebula to start
    goto end
)
goto wait_loop

:end
echo.
if exist "%NEBULA_LOG%" (
    echo [DEBUG] Printing nebula.log
    type "%NEBULA_LOG%"
) else (
    echo [ERROR] nebula.log not found
)
"""

# Write the batch file
script_path.write_text(corrected_script)
script_path
