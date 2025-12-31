# Script to extract Grid level info from log files
$logPath30 = 'c:\Users\Admin\Documents\GitHub\Sugamara\Test sug\20251230.log'
$logPath31 = 'c:\Users\Admin\Documents\GitHub\Sugamara\Test sug\20251231.log'

Write-Host "=== GRID LEVEL CLOSED INFO - 30 DECEMBER 2025 ==="
Get-Content -Path $logPath30 -Encoding Unicode | Where-Object { $_ -match 'Grid[AB]-.*-L\d.*Closed in PROFIT' }

Write-Host ""
Write-Host "=== GRID LEVEL CLOSED INFO - 31 DECEMBER 2025 ==="
Get-Content -Path $logPath31 -Encoding Unicode | Where-Object { $_ -match 'Grid[AB]-.*-L\d.*Closed in PROFIT' }
