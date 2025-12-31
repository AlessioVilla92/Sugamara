# Script per estrarre errori e warning dai log di trading
# Output su file per evitare problemi di encoding

$log30 = "c:\Users\Admin\Documents\GitHub\Sugamara\Test sug\20251230.log"
$log31 = "c:\Users\Admin\Documents\GitHub\Sugamara\Test sug\20251231.log"
$outputFile = "c:\Users\Admin\Documents\GitHub\Sugamara\Test sug\error_report.txt"

# Inizializza il report
$report = @()
$report += "=" * 80
$report += "REPORT ERRORI E WARNING - LOG TRADING 30-31 DICEMBRE 2025"
$report += "=" * 80
$report += ""

# Array per raccogliere tutti gli errori
$allErrors = @()

# Processa i file
foreach ($logFile in @($log30, $log31)) {
    $fileName = Split-Path $logFile -Leaf
    $report += ""
    $report += "-" * 80
    $report += "FILE: $fileName"
    $report += "-" * 80

    $content = Get-Content $logFile -Encoding Unicode
    $matches = $content | Where-Object { $_ -match 'ERROR|FAILED|WARNING|MISMATCH|EMERGENCY' }

    $report += "Totale linee con errori/warning: $($matches.Count)"
    $report += ""

    foreach ($line in $matches) {
        $allErrors += [PSCustomObject]@{
            File = $fileName
            Line = $line
        }
    }
}

# Analisi dettagliata
$report += ""
$report += "=" * 80
$report += "SEZIONE 1: LISTA COMPLETA ERRORI (ERROR)"
$report += "=" * 80

$errors = $allErrors | Where-Object { $_.Line -match '\bERROR\b' }
$report += "Totale ERROR: $($errors.Count)"
$report += ""
foreach ($err in $errors) {
    $report += "[$($err.File)] $($err.Line)"
}

$report += ""
$report += "=" * 80
$report += "SEZIONE 2: LISTA COMPLETA WARNING"
$report += "=" * 80

$warnings = $allErrors | Where-Object { $_.Line -match '\bWARNING\b' }
$report += "Totale WARNING: $($warnings.Count)"
$report += ""
foreach ($warn in $warnings) {
    $report += "[$($warn.File)] $($warn.Line)"
}

$report += ""
$report += "=" * 80
$report += "SEZIONE 3: LISTA FAILED"
$report += "=" * 80

$failed = $allErrors | Where-Object { $_.Line -match '\bFAILED\b' }
$report += "Totale FAILED: $($failed.Count)"
$report += ""
foreach ($f in $failed) {
    $report += "[$($f.File)] $($f.Line)"
}

$report += ""
$report += "=" * 80
$report += "SEZIONE 4: LISTA MISMATCH"
$report += "=" * 80

$mismatch = $allErrors | Where-Object { $_.Line -match '\bMISMATCH\b' }
$report += "Totale MISMATCH: $($mismatch.Count)"
$report += ""
foreach ($m in $mismatch) {
    $report += "[$($m.File)] $($m.Line)"
}

$report += ""
$report += "=" * 80
$report += "SEZIONE 5: LISTA EMERGENCY"
$report += "=" * 80

$emergency = $allErrors | Where-Object { $_.Line -match '\bEMERGENCY\b' }
$report += "Totale EMERGENCY: $($emergency.Count)"
$report += ""
foreach ($e in $emergency) {
    $report += "[$($e.File)] $($e.Line)"
}

# Analisi per pair
$report += ""
$report += "=" * 80
$report += "SEZIONE 6: ANALISI PER PAIR"
$report += "=" * 80

# Estrai pair dai messaggi
$pairPattern = '[A-Z]{6}(m|\.a)?'
$pairStats = @{}

foreach ($item in $allErrors) {
    if ($item.Line -match $pairPattern) {
        $pair = $matches[0]
        if (-not $pairStats.ContainsKey($pair)) {
            $pairStats[$pair] = 0
        }
        $pairStats[$pair]++
    }
}

$report += "Errori/Warning per Pair:"
foreach ($pair in ($pairStats.Keys | Sort-Object)) {
    $report += "  $pair : $($pairStats[$pair]) occorrenze"
}

# Frequenza tipi di errore
$report += ""
$report += "=" * 80
$report += "SEZIONE 7: FREQUENZA TIPI DI ERRORE"
$report += "=" * 80

$errorTypes = @{}
foreach ($item in $allErrors) {
    # Estrai tipo di messaggio
    if ($item.Line -match '(ERROR|WARNING|FAILED|MISMATCH|EMERGENCY)') {
        $type = $matches[1]
        if (-not $errorTypes.ContainsKey($type)) {
            $errorTypes[$type] = 0
        }
        $errorTypes[$type]++
    }
}

foreach ($type in ($errorTypes.Keys | Sort-Object -Descending { $errorTypes[$_] })) {
    $report += "  $type : $($errorTypes[$type]) occorrenze"
}

# Classificazione gravita
$report += ""
$report += "=" * 80
$report += "SEZIONE 8: CLASSIFICAZIONE PER GRAVITA"
$report += "=" * 80

$critical = ($allErrors | Where-Object { $_.Line -match 'EMERGENCY|CRITICAL|FATAL' }).Count
$high = ($allErrors | Where-Object { $_.Line -match '\bERROR\b' -and $_.Line -notmatch 'EMERGENCY|CRITICAL|FATAL' }).Count
$medium = ($allErrors | Where-Object { $_.Line -match '\bFAILED\b|\bMISMATCH\b' }).Count
$low = ($allErrors | Where-Object { $_.Line -match '\bWARNING\b' }).Count

$report += "CRITICAL (EMERGENCY/FATAL): $critical"
$report += "HIGH (ERROR): $high"
$report += "MEDIUM (FAILED/MISMATCH): $medium"
$report += "LOW (WARNING): $low"

# Riepilogo
$report += ""
$report += "=" * 80
$report += "RIEPILOGO FINALE"
$report += "=" * 80
$report += "Totale linee analizzate con errori/warning: $($allErrors.Count)"
$report += ""
$report += "Distribuzione per file:"
$report += "  20251230.log: $(($allErrors | Where-Object {$_.File -eq '20251230.log'}).Count)"
$report += "  20251231.log: $(($allErrors | Where-Object {$_.File -eq '20251231.log'}).Count)"

# Salva il report
$report | Out-File -FilePath $outputFile -Encoding UTF8

Write-Host "Report salvato in: $outputFile"
Write-Host "Totale errori/warning trovati: $($allErrors.Count)"
