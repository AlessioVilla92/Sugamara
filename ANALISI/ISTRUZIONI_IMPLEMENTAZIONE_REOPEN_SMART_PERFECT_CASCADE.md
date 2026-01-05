# 📋 ISTRUZIONI IMPLEMENTAZIONE: REOPEN SMART + PERFECT CASCADE

## Versione: SUGAMARA RIBELLE v8.0
## Data: 3 Gennaio 2026
## Autore: Alessio + Claude

---

# 🎯 OBIETTIVO

Implementare una strategia di **Cyclic Reopen differenziata** tra ordini STOP e LIMIT, garantendo:

1. **Entry SEMPRE identico all'originale** (MAI adattato)
2. **Perfect Cascade per TUTTI** gli ordini (TP 10 pips)
3. **Neutralità e spacing preservati**
4. **Nessun invalid price**

---

# 📊 RIEPILOGO STRATEGIA

## Tabella Comportamento Finale:

| Tipo Ordine | Reopen Mode | Trigger | Entry | TP |
|-------------|-------------|---------|-------|-----|
| **BUY STOP** | SMART | prezzo ≤ entry - offset | ORIGINALE | 10 pips |
| **SELL STOP** | SMART | prezzo ≥ entry + offset | ORIGINALE | 10 pips |
| **BUY LIMIT** | IMMEDIATO | Sempre (dopo TP) | ORIGINALE | 10 pips |
| **SELL LIMIT** | IMMEDIATO | Sempre (dopo TP) | ORIGINALE | 10 pips |

## Logica Offset per STOP:

```
BUY STOP @ 1.2010, Offset = 3 pips:
- Trigger = 1.2010 - 3 = 1.2007
- Inserisce pendente quando prezzo ≤ 1.2007
- Entry rimane 1.2010 (ORIGINALE)

SELL STOP @ 1.1990, Offset = 3 pips:
- Trigger = 1.1990 + 3 = 1.1993
- Inserisce pendente quando prezzo ≥ 1.1993
- Entry rimane 1.1990 (ORIGINALE)
```

## Logica per LIMIT:

```
BUY LIMIT @ 58, dopo chiusura TP @ 68:
- Inserisce SUBITO pendente @ 58
- Nessun calcolo, nessun offset
- Proprietà intrinseca protegge dal fill indesiderato

SELL LIMIT @ 142, dopo chiusura TP @ 132:
- Inserisce SUBITO pendente @ 142
- Nessun calcolo, nessun offset
- Proprietà intrinseca protegge dal fill indesiderato
```

---

# 🔧 MODIFICHE DA IMPLEMENTARE

## 1️⃣ MODIFICA: IsPriceAtReopenLevel() → IsPriceAtReopenLevelSmart()

### File: `GridHelpers.mqh`
### Linee: ~1170-1186

### CODICE ATTUALE (da sostituire):

```cpp
bool IsPriceAtReopenLevel(double levelPrice) {
    if(ReopenTrigger != REOPEN_PRICE_LEVEL) return true;
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(currentPrice <= 0) return false;
    
    if(!EnableReopenOffset) {
        double minOffset = PipsToPoints(1.0);
        return (MathAbs(currentPrice - levelPrice) <= minOffset);
    }
    
    double offsetPrice = PipsToPoints(ReopenOffset_Pips);
    return (MathAbs(currentPrice - levelPrice) <= offsetPrice);
}
```

### NUOVO CODICE:

```cpp
//+------------------------------------------------------------------+
//| Check Price Level for Reopen Trigger - SMART DIFFERENZIATO       |
//| v8.0: LIMIT = Immediato, STOP = Smart con offset unidirezionale  |
//+------------------------------------------------------------------+
bool IsPriceAtReopenLevelSmart(double levelPrice, ENUM_ORDER_TYPE orderType) {
    
    // ═══════════════════════════════════════════════════════════════
    // ORDINI LIMIT: SEMPRE IMMEDIATO
    // ═══════════════════════════════════════════════════════════════
    // La proprietà intrinseca del LIMIT protegge già:
    // - BUY LIMIT fillato SOLO se prezzo SCENDE al livello
    // - SELL LIMIT fillato SOLO se prezzo SALE al livello
    // Se il prezzo non va nella direzione corretta → MAI fillato
    // ═══════════════════════════════════════════════════════════════
    if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT) {
        if(DetailedLogging) {
            Print("[Reopen] LIMIT order - IMMEDIATE reopen enabled");
        }
        return true;  // Inserisce SUBITO all'entry originale
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ORDINI STOP: SMART con offset UNIDIREZIONALE
    // ═══════════════════════════════════════════════════════════════
    // Inserisce il pendente SOLO quando il prezzo è nella direzione
    // che garantisce la validità dell'entry originale.
    // Questo evita completamente il problema dell'invalid price
    // e l'adattamento del prezzo da parte di GetSafeOrderPrice().
    // ═══════════════════════════════════════════════════════════════
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(currentPrice <= 0) return false;
    
    double offsetPoints = PipsToPoints(ReopenOffset_Pips);  // Default: 3 pips
    
    switch(orderType) {
        case ORDER_TYPE_BUY_STOP:
            // ───────────────────────────────────────────────────────
            // BUY STOP: Entry SOPRA il prezzo corrente
            // Inserisce SOLO quando prezzo SCENDE sotto (entry - offset)
            // Così l'entry originale sarà SEMPRE valido (> Ask)
            // ───────────────────────────────────────────────────────
            {
                double trigger = levelPrice - offsetPoints;
                bool canReopen = (currentPrice <= trigger);
                
                if(DetailedLogging) {
                    PrintFormat("[Reopen] BUY STOP @ %.5f | Trigger: %.5f | Price: %.5f | Reopen: %s",
                                levelPrice, trigger, currentPrice, canReopen ? "YES" : "NO");
                }
                return canReopen;
            }
            
        case ORDER_TYPE_SELL_STOP:
            // ───────────────────────────────────────────────────────
            // SELL STOP: Entry SOTTO il prezzo corrente
            // Inserisce SOLO quando prezzo SALE sopra (entry + offset)
            // Così l'entry originale sarà SEMPRE valido (< Bid)
            // ───────────────────────────────────────────────────────
            {
                double trigger = levelPrice + offsetPoints;
                bool canReopen = (currentPrice >= trigger);
                
                if(DetailedLogging) {
                    PrintFormat("[Reopen] SELL STOP @ %.5f | Trigger: %.5f | Price: %.5f | Reopen: %s",
                                levelPrice, trigger, currentPrice, canReopen ? "YES" : "NO");
                }
                return canReopen;
            }
            
        default:
            // Fallback per altri tipi (non dovrebbe mai arrivarci)
            return true;
    }
}


//+------------------------------------------------------------------+
//| FUNZIONE LEGACY - Mantieni per compatibilità se necessario       |
//| Chiamare IsPriceAtReopenLevelSmart() dove possibile              |
//+------------------------------------------------------------------+
bool IsPriceAtReopenLevel(double levelPrice) {
    // Fallback: comportamento immediato per retrocompatibilità
    // NOTA: Questa funzione NON conosce il tipo di ordine
    // Usare IsPriceAtReopenLevelSmart() per il comportamento corretto
    return true;
}
```

---

## 2️⃣ MODIFICA: ShouldReopenGridAUpper() - Passa orderType

### File: `GridASystem.mqh`
### Linee: ~406-426

### CODICE ATTUALE:

```cpp
bool ShouldReopenGridAUpper(int level) {
    ENUM_ORDER_STATUS status = gridA_Upper_Status[level];
    
    if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
        return false;
    }
    
    if(!CanLevelReopen(GRID_A, ZONE_UPPER, level)) {
        return false;
    }
    
    double levelPrice = gridA_Upper_EntryPrices[level];
    if(!IsPriceAtReopenLevel(levelPrice)) {
        return false;
    }
    
    return true;
}
```

### NUOVO CODICE:

```cpp
//+------------------------------------------------------------------+
//| Check if Grid A Upper Level Should Reopen                        |
//| v8.0: Passa orderType a IsPriceAtReopenLevelSmart()              |
//+------------------------------------------------------------------+
bool ShouldReopenGridAUpper(int level) {
    ENUM_ORDER_STATUS status = gridA_Upper_Status[level];
    
    // Can only reopen if closed
    if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
        return false;
    }
    
    // Check cooldown, max cycles, volatility
    if(!CanLevelReopen(GRID_A, ZONE_UPPER, level)) {
        return false;
    }
    
    // v8.0: Ottieni il tipo di ordine per questa zona
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_A, ZONE_UPPER);
    
    // v8.0: Usa la nuova funzione SMART con orderType
    double levelPrice = gridA_Upper_EntryPrices[level];
    if(!IsPriceAtReopenLevelSmart(levelPrice, orderType)) {
        return false;
    }
    
    return true;
}
```

---

## 3️⃣ MODIFICA: ShouldReopenGridALower() - Passa orderType

### File: `GridASystem.mqh`
### Linee: ~431-449

### NUOVO CODICE:

```cpp
//+------------------------------------------------------------------+
//| Check if Grid A Lower Level Should Reopen                        |
//| v8.0: Passa orderType a IsPriceAtReopenLevelSmart()              |
//+------------------------------------------------------------------+
bool ShouldReopenGridALower(int level) {
    ENUM_ORDER_STATUS status = gridA_Lower_Status[level];
    
    if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
        return false;
    }
    
    if(!CanLevelReopen(GRID_A, ZONE_LOWER, level)) {
        return false;
    }
    
    // v8.0: Ottieni il tipo di ordine per questa zona
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_A, ZONE_LOWER);
    
    // v8.0: Usa la nuova funzione SMART con orderType
    double levelPrice = gridA_Lower_EntryPrices[level];
    if(!IsPriceAtReopenLevelSmart(levelPrice, orderType)) {
        return false;
    }
    
    return true;
}
```

---

## 4️⃣ MODIFICA: ShouldReopenGridBUpper() - Passa orderType

### File: `GridBSystem.mqh`
### Linee: ~363-381

### NUOVO CODICE:

```cpp
//+------------------------------------------------------------------+
//| Check if Grid B Upper Level Should Reopen                        |
//| v8.0: Passa orderType a IsPriceAtReopenLevelSmart()              |
//+------------------------------------------------------------------+
bool ShouldReopenGridBUpper(int level) {
    ENUM_ORDER_STATUS status = gridB_Upper_Status[level];
    
    if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
        return false;
    }
    
    if(!CanLevelReopen(GRID_B, ZONE_UPPER, level)) {
        return false;
    }
    
    // v8.0: Ottieni il tipo di ordine per questa zona
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_B, ZONE_UPPER);
    
    // v8.0: Usa la nuova funzione SMART con orderType
    double levelPrice = gridB_Upper_EntryPrices[level];
    if(!IsPriceAtReopenLevelSmart(levelPrice, orderType)) {
        return false;
    }
    
    return true;
}
```

---

## 5️⃣ MODIFICA: ShouldReopenGridBLower() - Passa orderType

### File: `GridBSystem.mqh`
### Linee: ~385-403

### NUOVO CODICE:

```cpp
//+------------------------------------------------------------------+
//| Check if Grid B Lower Level Should Reopen                        |
//| v8.0: Passa orderType a IsPriceAtReopenLevelSmart()              |
//+------------------------------------------------------------------+
bool ShouldReopenGridBLower(int level) {
    ENUM_ORDER_STATUS status = gridB_Lower_Status[level];
    
    if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
        return false;
    }
    
    if(!CanLevelReopen(GRID_B, ZONE_LOWER, level)) {
        return false;
    }
    
    // v8.0: Ottieni il tipo di ordine per questa zona
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_B, ZONE_LOWER);
    
    // v8.0: Usa la nuova funzione SMART con orderType
    double levelPrice = gridB_Lower_EntryPrices[level];
    if(!IsPriceAtReopenLevelSmart(levelPrice, orderType)) {
        return false;
    }
    
    return true;
}
```

---

## 6️⃣ MODIFICA: Perfect Cascade per TUTTI (Rimozione Overlap)

### File: `InputParameters.mqh`

### VERIFICARE che:

```cpp
// Overlap_Percentage deve essere 0 o rimosso
input int Overlap_Percentage = 0;  // 0 = 100% Perfect Cascade

// OPPURE rimuovere completamente la logica overlap
```

### File: `GridHelpers.mqh` - Funzione CalculateCascadeTP()

### VERIFICARE che il TP sia SEMPRE 10 pips:

```cpp
//+------------------------------------------------------------------+
//| Calculate CASCADE Take Profit - PERFECT CASCADE per TUTTI        |
//| v8.0: Rimuove logica Overlap, TP sempre a 10 pips               |
//+------------------------------------------------------------------+
double CalculateCascadeTP(double entryPoint, ENUM_GRID_SIDE side, 
                          ENUM_GRID_ZONE zone, int level, 
                          double spacingPips, int totalLevels) {
    
    double entryPrice = 0;
    double tpPrice = 0;
    
    // Calcola entry price per questo livello
    entryPrice = CalculateGridLevelPrice(entryPoint, zone, level, spacingPips, side);
    
    // v8.0: PERFECT CASCADE per TUTTI - TP sempre a 10 pips (spacing)
    // Nessuna logica Overlap (+3 pips)
    double tpDistance = PipsToPoints(spacingPips);  // Es: 10 pips
    
    // Direzione TP in base al tipo di ordine
    ENUM_ORDER_TYPE orderType = GetGridOrderType(side, zone);
    
    if(orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_BUY_LIMIT) {
        // Ordini BUY: TP sopra entry
        tpPrice = entryPrice + tpDistance;
    } else {
        // Ordini SELL: TP sotto entry
        tpPrice = entryPrice - tpDistance;
    }
    
    return NormalizeDouble(tpPrice, symbolDigits);
}
```

---

## 7️⃣ REVISIONE: GetSafeOrderPrice() - Quando chiamarla

### File: `BrokerValidation.mqh`
### Linee: ~364-439

### LOGICA:

Con la nuova implementazione SMART:
- **LIMIT**: Entry sempre valido per design → GetSafeOrderPrice() **MAI necessaria**
- **STOP**: Trigger garantisce entry valido → GetSafeOrderPrice() **MAI necessaria**

### OPZIONE A: Mantenere come fallback di sicurezza

```cpp
// In PlaceGridAUpperOrder(), PlaceGridALowerOrder(), etc.

// v8.0: Con SMART Reopen, l'entry dovrebbe essere SEMPRE valido
// Manteniamo il check come fallback di sicurezza, ma logghiamo warning
if(!IsValidPendingPrice(entryPrice, orderType)) {
    // Questo NON dovrebbe MAI accadere con SMART Reopen
    LogMessage(LOG_WARNING, StringFormat(
        "[v8.0] UNEXPECTED: Entry %.5f invalid for %s - This should not happen with SMART Reopen!",
        entryPrice, EnumToString(orderType)));
    
    // OPZIONE: Ritorna false invece di adattare
    // return false;  // Riproverà al prossimo tick
    
    // OPPURE: Adatta come fallback (comportamento legacy)
    entryPrice = GetSafeOrderPrice(entryPrice, orderType);
}
```

### OPZIONE B: Rimuovere completamente la chiamata (raccomandato)

```cpp
// In PlaceGridAUpperOrder(), PlaceGridALowerOrder(), etc.

// v8.0: Con SMART Reopen, l'entry è GARANTITO valido
// Non serve più verificare o adattare
// Se arriviamo qui, l'entry è già stato validato dal trigger SMART

// RIMUOVERE QUESTE RIGHE:
// if(!IsValidPendingPrice(entryPrice, orderType)) {
//     entryPrice = GetSafeOrderPrice(entryPrice, orderType);
// }

// SOSTITUIRE CON:
// (niente - l'entry è già valido)
```

---

## 8️⃣ MODIFICA: InputParameters.mqh - Nuovi Parametri

### File: `InputParameters.mqh`

### AGGIUNGERE/MODIFICARE:

```cpp
//+------------------------------------------------------------------+
//| CYCLIC REOPEN v8.0 - SMART DIFFERENZIATO                         |
//+------------------------------------------------------------------+

input group "    ♻️ CYCLIC REOPEN v8.0"

input bool      EnableCyclicReopen = true;                   // ✅ Abilita Cyclic Reopen

// v8.0: ReopenTrigger NON più usato - logica automatica per tipo ordine
// LIMIT = Immediato, STOP = Smart
// Manteniamo per retrocompatibilità ma ignorato nel nuovo codice
input ENUM_REOPEN_TRIGGER ReopenTrigger = REOPEN_IMMEDIATE;  // [LEGACY] Non usato in v8.0

input group "    🎯 SMART REOPEN v8.0 (Solo per STOP)"

input double    ReopenOffset_Pips = 3.0;                     // 📏 Offset per STOP (pips)
// BUY STOP: inserisce quando prezzo <= entry - offset
// SELL STOP: inserisce quando prezzo >= entry + offset
// LIMIT: Ignorato (sempre immediato)

input int       MaxCyclesPerLevel = 0;                       // 🔢 Max Cicli per Livello (0=infiniti)

input group "    🛡️ SICUREZZA REOPEN"
input bool      PauseReopenNearShield = false;               // 🛡️ Pausa reopen vicino a Shield
input double    ShieldProximity_Pips = 20.0;                 // 📏 Distanza minima da Shield (pips)
input bool      PauseReopenOnExtreme = false;                // 🛡️ Pausa reopen su ATR EXTREME
```

---

## 9️⃣ VERIFICA: Enums.mqh - Tipi Ordine

### File: `Enums.mqh`

### VERIFICARE che GetGridOrderType() restituisca correttamente:

```cpp
// Per CASCADE_OVERLAP mode (quello che usiamo):

Grid A Upper: BUY STOP
Grid A Lower: BUY LIMIT
Grid B Upper: SELL LIMIT
Grid B Lower: SELL STOP
```

### CODICE da verificare in GridHelpers.mqh:

```cpp
ENUM_ORDER_TYPE GetGridOrderType(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone) {
    if(IsCascadeOverlapMode()) {
        // CASCADE_OVERLAP: Grid A = solo BUY, Grid B = solo SELL
        if(side == GRID_A) {
            if(zone == ZONE_UPPER) return ORDER_TYPE_BUY_STOP;
            else return ORDER_TYPE_BUY_LIMIT;
        } else {
            if(zone == ZONE_UPPER) return ORDER_TYPE_SELL_LIMIT;
            else return ORDER_TYPE_SELL_STOP;
        }
    }
    // ... altro codice per altri modi
}
```

---

# ✅ CHECKLIST IMPLEMENTAZIONE

## Prima di iniziare:
- [ ] Backup completo del progetto
- [ ] Verificare versione attuale (v7.0)

## Modifiche Core:
- [ ] `GridHelpers.mqh`: Creare `IsPriceAtReopenLevelSmart()`
- [ ] `GridASystem.mqh`: Modificare `ShouldReopenGridAUpper()`
- [ ] `GridASystem.mqh`: Modificare `ShouldReopenGridALower()`
- [ ] `GridBSystem.mqh`: Modificare `ShouldReopenGridBUpper()`
- [ ] `GridBSystem.mqh`: Modificare `ShouldReopenGridBLower()`

## Perfect Cascade:
- [ ] Verificare/Modificare `CalculateCascadeTP()` - TP sempre 10 pips
- [ ] Rimuovere logica Overlap se presente
- [ ] Verificare `Overlap_Percentage = 0`

## Pulizia Codice:
- [ ] Rivedere `GetSafeOrderPrice()` - decidere se rimuovere chiamate
- [ ] Aggiornare `InputParameters.mqh` con nuova documentazione
- [ ] Rimuovere parametri obsoleti (EnableReopenOffset, ReopenMode)

## Test:
- [ ] Compilazione senza errori
- [ ] Test BUY STOP: verifica trigger offset -3 pips
- [ ] Test SELL STOP: verifica trigger offset +3 pips
- [ ] Test BUY LIMIT: verifica reopen immediato
- [ ] Test SELL LIMIT: verifica reopen immediato
- [ ] Test Perfect Cascade: verifica TP 10 pips per tutti
- [ ] Test entry preservato: verifica che NESSUN entry venga mai modificato

## Documentazione:
- [ ] Aggiornare versione in Sugamara.mq5 → v8.0
- [ ] Aggiornare commenti nel codice
- [ ] Log della modifica

---

# 📊 DIAGRAMMA COMPORTAMENTO FINALE

```
╔══════════════════════════════════════════════════════════════════════╗
║                     SUGAMARA v8.0 - REOPEN FLOW                      ║
╠══════════════════════════════════════════════════════════════════════╣
║                                                                      ║
║  ORDINE CHIUDE TP                                                    ║
║         │                                                            ║
║         ▼                                                            ║
║  ┌─────────────────┐                                                 ║
║  │ Che tipo è?     │                                                 ║
║  └────────┬────────┘                                                 ║
║           │                                                          ║
║     ┌─────┴─────┐                                                    ║
║     │           │                                                    ║
║     ▼           ▼                                                    ║
║  ┌──────┐   ┌──────┐                                                 ║
║  │ STOP │   │ LIMIT│                                                 ║
║  └──┬───┘   └──┬───┘                                                 ║
║     │          │                                                     ║
║     ▼          ▼                                                     ║
║  ┌────────────────────┐   ┌────────────────────┐                     ║
║  │ Prezzo <= entry-3? │   │ REOPEN IMMEDIATO!  │                     ║
║  │ (BUY STOP)         │   │ Inserisce subito   │                     ║
║  │        o           │   │ @ entry originale  │                     ║
║  │ Prezzo >= entry+3? │   └─────────┬──────────┘                     ║
║  │ (SELL STOP)        │             │                                ║
║  └─────────┬──────────┘             │                                ║
║            │                        │                                ║
║     ┌──────┴──────┐                 │                                ║
║     │             │                 │                                ║
║    NO            SÌ                 │                                ║
║     │             │                 │                                ║
║     ▼             ▼                 │                                ║
║  ┌──────┐   ┌──────────────┐        │                                ║
║  │ATTENDI│   │REOPEN!       │        │                                ║
║  │prossimo│   │Inserisce @   │        │                                ║
║  │tick    │   │entry originale│       │                                ║
║  └──────┘   └──────┬───────┘        │                                ║
║                    │                │                                ║
║                    ▼                ▼                                ║
║              ┌─────────────────────────────┐                         ║
║              │     PENDENTE INSERITO       │                         ║
║              │     @ ENTRY ORIGINALE       │                         ║
║              │     (MAI modificato!)       │                         ║
║              │     TP = 10 pips            │                         ║
║              └─────────────────────────────┘                         ║
║                                                                      ║
╚══════════════════════════════════════════════════════════════════════╝
```

---

# 🔴 FUNZIONI DA RIMUOVERE/DEPRECARE

## GetSafeOrderPrice() - Valutare rimozione chiamate

### File: `BrokerValidation.mqh`

La funzione può rimanere nel codice come utility, ma le chiamate nei flussi di Reopen possono essere rimosse:

### File: `GridASystem.mqh` - PlaceGridAUpperOrder()

```cpp
// RIMUOVERE o COMMENTARE queste righe (circa linea 198-200):
// if(!IsValidPendingPrice(entryPrice, orderType)) {
//     entryPrice = GetSafeOrderPrice(entryPrice, orderType);
// }
```

### File: `GridASystem.mqh` - PlaceGridALowerOrder()

```cpp
// RIMUOVERE o COMMENTARE queste righe (circa linea 239-241):
// if(!IsValidPendingPrice(entryPrice, orderType)) {
//     entryPrice = GetSafeOrderPrice(entryPrice, orderType);
// }
```

### File: `GridBSystem.mqh` - PlaceGridBUpperOrder()

```cpp
// RIMUOVERE o COMMENTARE queste righe (circa linea 161-163):
// if(!IsValidPendingPrice(entryPrice, orderType)) {
//     entryPrice = GetSafeOrderPrice(entryPrice, orderType);
// }
```

### File: `GridBSystem.mqh` - PlaceGridBLowerOrder()

```cpp
// RIMUOVERE o COMMENTARE queste righe (circa linea 202-204):
// if(!IsValidPendingPrice(entryPrice, orderType)) {
//     entryPrice = GetSafeOrderPrice(entryPrice, orderType);
// }
```

---

# 📝 NOTE FINALI

## Garanzie della Nuova Implementazione:

1. **Entry SEMPRE originale** - Nessuna funzione modifica mai l'entry price
2. **Perfect Cascade uniforma** - TP 10 pips per tutti gli ordini
3. **STOP protetti da offset** - Inserimento solo quando entry è valido
4. **LIMIT protetti da proprietà intrinseca** - Mai fillati nella direzione sbagliata
5. **Neutralità preservata** - Spacing e struttura grid intatti
6. **Codice pulito** - Rimozione logiche obsolete e adattamenti non necessari

## Test Raccomandati:

1. **Strategy Tester** - Verifica cicli completi su pair mean-reverting
2. **Demo Account** - Test real-time per almeno 24h
3. **Log Analysis** - Verificare che nessun entry venga mai modificato
4. **Stress Test** - Mercato volatile per verificare comportamento STOP

---

**Documento creato il 3 Gennaio 2026**
**Per implementazione in SUGAMARA RIBELLE v8.0**
