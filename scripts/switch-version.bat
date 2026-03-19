@echo off
REM Switch PHP (and optionally MySQL) versions in .env
REM Usage: scripts\switch-version.bat [php_version] [mysql_version]
REM   - 無參數：進入互動式選單
REM   - 有參數：驗證並切換版本

setlocal enabledelayedexpansion

REM ================================================
REM 支援的版本清單
REM ================================================
set "SUPPORTED_PHP=56 74 80 81 82 83"
set "SUPPORTED_MYSQL=5.7 8.0 8.4"

REM ================================================
REM 主程式
REM ================================================
if "%~1"=="" (
  call :interactive_mode
) else (
  call :command_line_mode "%~1" "%~2"
)
goto :eof

REM ================================================
REM 驗證版本是否支援
REM ================================================
:validate_version
set "ver=%~1"
set "list=%~2"
for %%v in (%list%) do (
  if "!ver!"=="%%v" (
    exit /b 0
  )
)
exit /b 1

REM ================================================
REM 顯示選單並取得使用者選擇
REM ================================================
:select_version
set "prompt=%~1"
set "list=%~2"
set "result_var=%~3"

echo %prompt%
set /a idx=1
for %%v in (%list%) do (
  echo   !idx!. %%v
  set /a idx+=1
)

:select_loop
set /p choice=請選擇 (1-%idx%):
set /a max_idx=idx-1

if !choice! lss 1 goto :invalid_choice
if !choice! gtr !max_idx! goto :invalid_choice

set /a curr=1
for %%v in (%list%) do (
  if !curr! equ !choice! (
    set "%result_var%=%%v"
    goto :eof
  )
  set /a curr+=1
)

:invalid_choice
echo 無效選擇，請重新輸入
goto :select_loop

REM ================================================
REM 更新 .env 檔案
REM ================================================
:update_env_file
set "php_ver=%~1"
set "mysql_ver=%~2"

if "%mysql_ver%"=="" (
  powershell -NoProfile -Command ^
    "(Get-Content '.env') | ForEach-Object { ^
      if ($_ -match '^PHP_VERSION=') { 'PHP_VERSION=%php_ver%' } ^
      else { $_ } ^
    } | Set-Content '.env'"
  echo √ 已更新 PHP_VERSION=%php_ver%
) else (
  powershell -NoProfile -Command ^
    "(Get-Content '.env') | ForEach-Object { ^
      if ($_ -match '^PHP_VERSION=') { 'PHP_VERSION=%php_ver%' } ^
      elseif ($_ -match '^MYSQL_VERSION=') { 'MYSQL_VERSION=%mysql_ver%' } ^
      else { $_ } ^
    } | Set-Content '.env'"
  echo √ 已更新 PHP_VERSION=%php_ver%
  echo √ 已更新 MYSQL_VERSION=%mysql_ver%
)
goto :eof

REM ================================================
REM 互動式模式
REM ================================================
:interactive_mode
echo ================================================
echo Docker 版本切換工具 (互動式)
echo ================================================
echo.

REM 選擇 PHP 版本
call :select_version "可用的 PHP 版本:" "%SUPPORTED_PHP%" PHP_VER
echo 已選擇 PHP !PHP_VER!
echo.

REM 詢問是否切換 MySQL
set /p change_mysql=是否要切換 MySQL 版本? (y/N):
if /i "!change_mysql!"=="y" (
  call :select_version "可用的 MySQL 版本:" "%SUPPORTED_MYSQL%" MYSQL_VER
  echo 已選擇 MySQL !MYSQL_VER!
) else (
  set "MYSQL_VER="
)

echo.
echo ================================================
call :update_env_file "!PHP_VER!" "!MYSQL_VER!"
echo ================================================
echo.
echo 請執行以下指令以套用變更:
echo   docker-compose down ^&^& docker-compose up -d --build
goto :eof

REM ================================================
REM 命令列模式
REM ================================================
:command_line_mode
set "php_ver=%~1"
set "mysql_ver=%~2"

REM 驗證 PHP 版本
call :validate_version "%php_ver%" "%SUPPORTED_PHP%"
if !errorlevel! neq 0 (
  echo 錯誤: 不支援的 PHP 版本 '%php_ver%' 1>&2
  echo 支援的版本: %SUPPORTED_PHP% 1>&2
  exit /b 1
)

REM 驗證 MySQL 版本 (如果有提供)
if not "%mysql_ver%"=="" (
  call :validate_version "%mysql_ver%" "%SUPPORTED_MYSQL%"
  if !errorlevel! neq 0 (
    echo 錯誤: 不支援的 MySQL 版本 '%mysql_ver%' 1>&2
    echo 支援的版本: %SUPPORTED_MYSQL% 1>&2
    exit /b 1
  )
)

call :update_env_file "%php_ver%" "%mysql_ver%"
echo.
echo 請執行以下指令以套用變更:
echo   docker-compose down ^&^& docker-compose up -d --build
goto :eof
