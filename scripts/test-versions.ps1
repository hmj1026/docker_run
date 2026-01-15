# ================================================
# PHP 版本測試腳本 (PowerShell)
# 用於驗證所有 PHP 容器的 Composer 和 PHPUnit 版本
# ================================================

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "PHP 環境版本驗證測試" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 定義所有 PHP 版本
$versions = @("56", "74", "80", "81", "82", "83")

foreach ($version in $versions) {
    Write-Host "==========================================" -ForegroundColor Yellow
    Write-Host "測試 PHP $version 環境" -ForegroundColor Yellow
    Write-Host "==========================================" -ForegroundColor Yellow
    Write-Host ""

    # 設定環境變數
    $env:PHP_VERSION = $version

    # 檢查 PHP 版本
    Write-Host "[PHP 版本]" -ForegroundColor Green
    docker-compose run --rm php php --version 2>$null | Select-String "PHP"
    Write-Host ""

    # 檢查 Composer 版本
    Write-Host "[Composer 版本]" -ForegroundColor Green
    docker-compose run --rm php composer --version 2>$null | Select-String "Composer"
    Write-Host ""

    # 檢查 PHPUnit 版本
    Write-Host "[PHPUnit 版本]" -ForegroundColor Green
    docker-compose run --rm php phpunit --version 2>$null | Select-String "PHPUnit"
    Write-Host ""

    Write-Host "✓ PHP $version 測試完成" -ForegroundColor Green
    Write-Host ""
}

Write-Host "==========================================" -ForegroundColor Cyan
Write-Host "所有測試完成！" -ForegroundColor Cyan
Write-Host "==========================================" -ForegroundColor Cyan
Write-Host ""

# 等待使用者按鍵
Write-Host "按任意鍵繼續..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
