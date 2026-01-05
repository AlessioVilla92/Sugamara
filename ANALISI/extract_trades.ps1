# Script to extract trades from log files
$logPath30 = 'c:\Users\Admin\Documents\GitHub\Sugamara\Test sug\20251230.log'
$logPath31 = 'c:\Users\Admin\Documents\GitHub\Sugamara\Test sug\20251231.log'

Write-Host "=== TRADES FROM 30 DECEMBER 2025 ==="
Get-Content -Path $logPath30 -Encoding Unicode | Where-Object { $_ -match 'closed|PROFIT|Trade recorded|\$' }

Write-Host ""
Write-Host "=== TRADES FROM 31 DECEMBER 2025 ==="
Get-Content -Path $logPath31 -Encoding Unicode | Where-Object { $_ -match 'closed|PROFIT|Trade recorded|\$' }
