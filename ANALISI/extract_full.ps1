# Script to extract ALL trade records with Grid info from log files
$logPath30 = 'c:\Users\Admin\Documents\GitHub\Sugamara\Test sug\20251230.log'
$logPath31 = 'c:\Users\Admin\Documents\GitHub\Sugamara\Test sug\20251231.log'

Write-Host "=== GRID POSITION CLOSED INFO - 30 DECEMBER 2025 ==="
Get-Content -Path $logPath30 -Encoding Unicode | Where-Object { $_ -match 'Grid [AB] position closed' }

Write-Host ""
Write-Host "=== GRID POSITION CLOSED INFO - 31 DECEMBER 2025 ==="
Get-Content -Path $logPath31 -Encoding Unicode | Where-Object { $_ -match 'Grid [AB] position closed' }
