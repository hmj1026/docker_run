@echo off
REM Generate a self-signed TLS cert/key for nginx SSL termination.
REM Usage: scripts\generate-cert.bat [domain]
REM Default domain: www.posdev.test

setlocal
set "DOMAIN=%1"
if "%DOMAIN%"=="" set "DOMAIN=www.posdev.test"

set "SCRIPT_DIR=%~dp0"
set "PROJECT_ROOT=%SCRIPT_DIR%.."
set "SSL_DIR=%PROJECT_ROOT%\nginx\ssl"
if not exist "%SSL_DIR%" mkdir "%SSL_DIR%"

set "CERT_PATH=%SSL_DIR%\laragon.crt"
set "KEY_PATH=%SSL_DIR%\laragon.key"

openssl req -x509 -nodes -days 3650 -newkey rsa:2048 ^
  -keyout "%KEY_PATH%" ^
  -out "%CERT_PATH%" ^
  -subj "/C=TW/ST=Taipei/L=Taipei/O=POS/OU=Dev/CN=%DOMAIN%"

echo Generated:
echo   Cert: %CERT_PATH%
echo   Key : %KEY_PATH%
echo Domain CN: %DOMAIN%
echo Restart nginx after updating cert/key (docker-compose restart nginx).
endlocal
