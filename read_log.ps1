$logFile = 'c:\Users\Admin\Documents\GitHub\Sugamara\Test sug\20251231.log'
$lines = Get-Content -Path $logFile -Encoding Unicode

# Filter lines for 00:00 - 02:00
$filteredLines = @()
foreach ($line in $lines) {
    if ($line -match '\t0[0-1]:') {
        $filteredLines += $line
    }
}

Write-Output "=== TRADES (aperture/chiusure) ==="
foreach ($line in $filteredLines) {
    if ($line -match 'Trade recorded|position closed|Closed in PROFIT|Closed in LOSS|Order placed|SUCCESS:') {
        Write-Output $line
    }
}

Write-Output ""
Write-Output "=== BOP (Break On Profit - SL movements) ==="
foreach ($line in $filteredLines) {
    if ($line -match '\[BOP\]') {
        Write-Output $line
    }
}

Write-Output ""
Write-Output "=== COP (Close On Profit) ==="
foreach ($line in $filteredLines) {
    if ($line -match '\[COP\]') {
        Write-Output $line
    }
}

Write-Output ""
Write-Output "=== GRID CYCLES (Reopening) ==="
foreach ($line in $filteredLines) {
    if ($line -match 'REOPENED|Cycle') {
        Write-Output $line
    }
}

Write-Output ""
Write-Output "=== SHIELD (Heartbeat e state changes) ==="
foreach ($line in $filteredLines) {
    if ($line -match '\[Shield\]') {
        Write-Output $line
    }
}

Write-Output ""
Write-Output "=== ERRORI (ERROR/WARNING) ==="
foreach ($line in $filteredLines) {
    if ($line -match 'ERROR|WARNING|FAIL|Error') {
        Write-Output $line
    }
}
