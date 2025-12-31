# Script to extract ALL trade records from log files
$logPath30 = 'c:\Users\Admin\Documents\GitHub\Sugamara\Test sug\20251230.log'
$logPath31 = 'c:\Users\Admin\Documents\GitHub\Sugamara\Test sug\20251231.log'

Write-Host "=== ALL TRADE RECORDS FROM 30 DECEMBER 2025 ==="
Get-Content -Path $logPath30 -Encoding Unicode | Where-Object { $_ -match 'Trade recorded' }

Write-Host ""
Write-Host "=== ALL TRADE RECORDS FROM 31 DECEMBER 2025 ==="
Get-Content -Path $logPath31 -Encoding Unicode | Where-Object { $_ -match 'Trade recorded' }
