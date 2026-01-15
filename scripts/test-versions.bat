@echo off
REM ================================================
REM PHP 版本測試腳本 (Windows)
REM ================================================

setlocal

echo ==========================================
echo PHP 環境版本驗證測試
echo ==========================================
echo.

REM 測試 PHP 5.6
echo [PHP 5.6]
set PHP_VERSION=56
call :test_version
echo.

REM 測試 PHP 7.4
echo [PHP 7.4]
set PHP_VERSION=74
call :test_version
echo.

REM 測試 PHP 8.0
echo [PHP 8.0]
set PHP_VERSION=80
call :test_version
echo.

REM 測試 PHP 8.1
echo [PHP 8.1]
set PHP_VERSION=81
call :test_version
echo.

REM 測試 PHP 8.2
echo [PHP 8.2]
set PHP_VERSION=82
call :test_version
echo.

REM 測試 PHP 8.3
echo [PHP 8.3]
set PHP_VERSION=83
call :test_version
echo.

echo ==========================================
echo 所有測試完成！
echo ==========================================
pause
goto :eof

:test_version
echo PHP:
docker-compose run --rm php php --version | findstr "PHP"
echo.
echo Composer:
docker-compose run --rm php composer --version | findstr "Composer"
echo.
echo PHPUnit:
docker-compose run --rm php phpunit --version | findstr "PHPUnit"
goto :eof
