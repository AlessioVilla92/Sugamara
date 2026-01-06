# 📋 SUGAMARA v8.0 - ISTRUZIONI MODIFICHE E RISOLUZIONI
## Data: 5 Gennaio 2026
## Per: Claude Code - Esecuzione Automatica

---

# 🎯 INDICE PUNTI DA RISOLVERE

| # | Descrizione | Tipo | Priorità | File |
|---|-------------|------|----------|------|
| 1 | Bug Critico Trailing Grid | 🔴 BUG CRITICO | **MASSIMA** | TrailingGridManager.mqh, GridASystem.mqh, GridBSystem.mqh |
| 2 | Analisi Floating Loss | 📊 Analisi | Completata | - |
| 3 | Dashboard: P/L → Contatori | 🔧 Modifica | Media | Dashboard.mqh |
| 4 | Configurazione BEP per Pairs | ⚙️ Config | Media | InputParameters.mqh |
| 5 | Trailing Profit Evoluto | 🆕 Nuova Funz. | Media | Nuovo modulo |
| 6 | Ultime 2 Grid - BEP 20% | 🆕 Nuova Funz. | Bassa | PositionMonitor.mqh |
| 7 | Bug COP Non Conta Profitti | 🔴 BUG | **ALTA** | CloseOnProfitManager.mqh |
| 8 | (Vuoto) | - | - | - |
| 9 | (Vuoto) | - | - | - |
| 10 | Spacing EURUSD 9→10 | ⚙️ Config | Bassa | InputParameters.mqh |
| 11A | Dashboard Grid A/B Contatori | 🔧 Modifica | Media | Dashboard.mqh |
| 11B | Dashboard Grid Zero Status | 🔧 Modifica | Bassa | Dashboard.mqh |

---

# 🔴 PUNTO 1: BUG CRITICO TRAILING GRID

## 📍 PROBLEMA IDENTIFICATO

Il Trailing Grid **NON FUNZIONA CORRETTAMENTE**. Ho identificato **3 BUG** distinti:

### BUG 1A: Contatori NON Decrementati alla Rimozione

**File:** `TrailingGridManager.mqh`
**Righe:** 364 e 412

**PROBLEMA:** Quando `RemoveDistantGridBelow()` o `RemoveDistantGridAbove()` rimuovono una grid, incrementano solo le statistiche (`g_trailLowerRemoved++`) ma **NON decrementano** i contatori attivi (`g_trailExtraGridsBelow` / `g_trailExtraGridsAbove`).

**CONSEGUENZA:** Il sistema pensa di avere più grid trailing del reale. Raggiunge il limite `Trail_Max_Extra_Grids` e smette di aggiungere nuove grid.

**CODICE ATTUALE (ERRATO):**
```cpp
// Riga 364 in RemoveDistantGridBelow():
LogTrail_GridRemoved("BELOW", lowestIndex, lowestPrice);
g_trailLowerRemoved++;
return true;
// ❌ MANCA: g_trailExtraGridsBelow--;

// Riga 412 in RemoveDistantGridAbove():
LogTrail_GridRemoved("ABOVE", highestIndex, highestPrice);
g_trailUpperRemoved++;
return true;
// ❌ MANCA: g_trailExtraGridsAbove--;
```

---

### BUG 1B: Status Grid Trailing NON Monitorato

**File:** `GridASystem.mqh` (riga 257-267) e `GridBSystem.mqh` (riga 220-230)

**PROBLEMA:** Le funzioni `UpdateGridAStatuses()` e `UpdateGridBStatuses()` iterano **SOLO** fino a `GridLevelsPerSide` (tipicamente 7).

Le grid trailing hanno indici **DA `GridLevelsPerSide` in poi** (7, 8, 9...), quindi **NON vengono MAI monitorate**!

**CODICE ATTUALE (ERRATO):**
```cpp
// GridASystem.mqh riga 257-267
void UpdateGridAStatuses() {
    for(int i = 0; i < GridLevelsPerSide; i++) {  // ❌ Solo 0-6!
        UpdateGridAUpperStatus(i);
    }
    for(int i = 0; i < GridLevelsPerSide; i++) {  // ❌ Solo 0-6!
        UpdateGridALowerStatus(i);
    }
}
```

**CONSEGUENZA:** Le grid trailing non vengono mai rilevate come FILLED o CLOSED. Rimangono in stato PENDING per sempre nell'array interno, anche se il broker le ha già eseguite.

---

### BUG 1C: Cyclic Reopen NON Funziona per Grid Trailing

**File:** `GridASystem.mqh` (riga 371-388) e `GridBSystem.mqh` (riga 329+)

**PROBLEMA:** `ProcessGridACyclicReopen()` e `ProcessGridBCyclicReopen()` iterano **SOLO** fino a `GridLevelsPerSide`.

Le grid trailing chiuse in profit **NON vengono MAI riaperte**!

**CODICE ATTUALE (ERRATO):**
```cpp
// GridASystem.mqh riga 371-388
void ProcessGridACyclicReopen() {
    if(!EnableCyclicReopen) return;
    if(IsMarketTooVolatile()) return;

    for(int i = 0; i < GridLevelsPerSide; i++) {  // ❌ Solo 0-6!
        if(ShouldReopenGridAUpper(i)) {
            ReopenGridAUpper(i);
        }
    }
    for(int i = 0; i < GridLevelsPerSide; i++) {  // ❌ Solo 0-6!
        if(ShouldReopenGridALower(i)) {
            ReopenGridALower(i);
        }
    }
}
```

---

## ✅ FIX PUNTO 1: CODICE CORRETTO

### FIX 1A: TrailingGridManager.mqh

**AZIONE:** Aggiungere decremento contatore dopo rimozione grid.

**File:** `TrailingGridManager.mqh`

**Modifica 1 - Funzione `RemoveDistantGridBelow()` (dopo riga 364):**

```cpp
// TROVA questa riga (circa 364):
g_trailLowerRemoved++;
return true;

// SOSTITUISCI CON:
g_trailLowerRemoved++;
g_trailExtraGridsBelow--;  // ✅ FIX: Decrementa contatore attivo
if(g_trailExtraGridsBelow < 0) g_trailExtraGridsBelow = 0;  // Safety check
return true;
```

**Modifica 2 - Funzione `RemoveDistantGridAbove()` (dopo riga 412):**

```cpp
// TROVA questa riga (circa 412):
g_trailUpperRemoved++;
return true;

// SOSTITUISCI CON:
g_trailUpperRemoved++;
g_trailExtraGridsAbove--;  // ✅ FIX: Decrementa contatore attivo
if(g_trailExtraGridsAbove < 0) g_trailExtraGridsAbove = 0;  // Safety check
return true;
```

---

### FIX 1B: GridASystem.mqh

**AZIONE:** Estendere il range di iterazione per includere le grid trailing.

**File:** `GridASystem.mqh`

**Modifica - Funzione `UpdateGridAStatuses()` (riga 257-267):**

```cpp
// TROVA questa funzione:
void UpdateGridAStatuses() {
    // Update Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        UpdateGridAUpperStatus(i);
    }

    // Update Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        UpdateGridALowerStatus(i);
    }
}

// SOSTITUISCI CON:
void UpdateGridAStatuses() {
    // ✅ FIX: Include trailing grid extra
    int maxLevelUpper = GridLevelsPerSide + g_trailExtraGridsAbove;
    if(maxLevelUpper > MAX_GRID_LEVELS) maxLevelUpper = MAX_GRID_LEVELS;
    
    int maxLevelLower = GridLevelsPerSide + g_trailExtraGridsBelow;
    if(maxLevelLower > MAX_GRID_LEVELS) maxLevelLower = MAX_GRID_LEVELS;

    // Update Upper Zone (include trailing)
    for(int i = 0; i < maxLevelUpper; i++) {
        UpdateGridAUpperStatus(i);
    }

    // Update Lower Zone (include trailing)
    for(int i = 0; i < maxLevelLower; i++) {
        UpdateGridALowerStatus(i);
    }
}
```

---

### FIX 1B (continua): GridBSystem.mqh

**File:** `GridBSystem.mqh`

**Modifica - Funzione `UpdateGridBStatuses()` (riga 220-230):**

```cpp
// TROVA questa funzione:
void UpdateGridBStatuses() {
    // Update Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        UpdateGridBUpperStatus(i);
    }

    // Update Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        UpdateGridBLowerStatus(i);
    }
}

// SOSTITUISCI CON:
void UpdateGridBStatuses() {
    // ✅ FIX: Include trailing grid extra
    int maxLevelUpper = GridLevelsPerSide + g_trailExtraGridsAbove;
    if(maxLevelUpper > MAX_GRID_LEVELS) maxLevelUpper = MAX_GRID_LEVELS;
    
    int maxLevelLower = GridLevelsPerSide + g_trailExtraGridsBelow;
    if(maxLevelLower > MAX_GRID_LEVELS) maxLevelLower = MAX_GRID_LEVELS;

    // Update Upper Zone (include trailing)
    for(int i = 0; i < maxLevelUpper; i++) {
        UpdateGridBUpperStatus(i);
    }

    // Update Lower Zone (include trailing)
    for(int i = 0; i < maxLevelLower; i++) {
        UpdateGridBLowerStatus(i);
    }
}
```

---

### FIX 1C: GridASystem.mqh - Cyclic Reopen

**File:** `GridASystem.mqh`

**Modifica - Funzione `ProcessGridACyclicReopen()` (riga 371-388):**

```cpp
// TROVA questa funzione:
void ProcessGridACyclicReopen() {
    if(!EnableCyclicReopen) return;
    if(IsMarketTooVolatile()) return;

    // Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(ShouldReopenGridAUpper(i)) {
            ReopenGridAUpper(i);
        }
    }

    // Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(ShouldReopenGridALower(i)) {
            ReopenGridALower(i);
        }
    }
}

// SOSTITUISCI CON:
void ProcessGridACyclicReopen() {
    if(!EnableCyclicReopen) return;
    if(IsMarketTooVolatile()) return;

    // ✅ FIX: Include trailing grid extra
    int maxLevelUpper = GridLevelsPerSide + g_trailExtraGridsAbove;
    if(maxLevelUpper > MAX_GRID_LEVELS) maxLevelUpper = MAX_GRID_LEVELS;
    
    int maxLevelLower = GridLevelsPerSide + g_trailExtraGridsBelow;
    if(maxLevelLower > MAX_GRID_LEVELS) maxLevelLower = MAX_GRID_LEVELS;

    // Upper Zone (include trailing)
    for(int i = 0; i < maxLevelUpper; i++) {
        if(ShouldReopenGridAUpper(i)) {
            ReopenGridAUpper(i);
        }
    }

    // Lower Zone (include trailing)
    for(int i = 0; i < maxLevelLower; i++) {
        if(ShouldReopenGridALower(i)) {
            ReopenGridALower(i);
        }
    }
}
```

---

### FIX 1C (continua): GridBSystem.mqh - Cyclic Reopen

**File:** `GridBSystem.mqh`

**Modifica - Funzione `ProcessGridBCyclicReopen()` (riga 329+):**

```cpp
// TROVA questa funzione:
void ProcessGridBCyclicReopen() {
    if(!EnableCyclicReopen) return;
    if(IsMarketTooVolatile()) return;

    // Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(ShouldReopenGridBUpper(i)) {
            ReopenGridBUpper(i);
        }
    }

    // Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(ShouldReopenGridBLower(i)) {
            ReopenGridBLower(i);
        }
    }
}

// SOSTITUISCI CON:
void ProcessGridBCyclicReopen() {
    if(!EnableCyclicReopen) return;
    if(IsMarketTooVolatile()) return;

    // ✅ FIX: Include trailing grid extra
    int maxLevelUpper = GridLevelsPerSide + g_trailExtraGridsAbove;
    if(maxLevelUpper > MAX_GRID_LEVELS) maxLevelUpper = MAX_GRID_LEVELS;
    
    int maxLevelLower = GridLevelsPerSide + g_trailExtraGridsBelow;
    if(maxLevelLower > MAX_GRID_LEVELS) maxLevelLower = MAX_GRID_LEVELS;

    // Upper Zone (include trailing)
    for(int i = 0; i < maxLevelUpper; i++) {
        if(ShouldReopenGridBUpper(i)) {
            ReopenGridBUpper(i);
        }
    }

    // Lower Zone (include trailing)
    for(int i = 0; i < maxLevelLower; i++) {
        if(ShouldReopenGridBLower(i)) {
            ReopenGridBLower(i);
        }
    }
}
```

---

# 📊 PUNTO 2: ANALISI FLOATING LOSS

## Scenario A: Storno Marcato (Movimento Unidirezionale)

```
SCENARIO: Prezzo scende da 1.1000 a 1.0900 (100 pip) e risale

        Resistenza (1.1070) ═══════════════════════════════
              │
              │  Grid 7 UPPER: PENDING (mai toccata)
              │  Grid 6 UPPER: PENDING (mai toccata)
              │  Grid 5 UPPER: PENDING (mai toccata)
              │  Grid 4 UPPER: PENDING (mai toccata)
              │  Grid 3 UPPER: PENDING (mai toccata)
              │  Grid 2 UPPER: PENDING (mai toccata)
              │  Grid 1 UPPER: PENDING (mai toccata)
        Entry Point (1.1000) ─────────────────────────────
              │  Grid 1 LOWER: FILLED → Floating Loss
              │  Grid 2 LOWER: FILLED → Floating Loss
              │  Grid 3 LOWER: FILLED → Floating Loss
              │  Grid 4 LOWER: FILLED → Floating Loss
              │  Grid 5 LOWER: FILLED → Floating Loss
              │  Grid 6 LOWER: FILLED → Floating Loss
              │  Grid 7 LOWER: FILLED → Floating Loss
              ▼
        Support (1.0930) ═══════════════════════════════════
              │
              ▼ Prezzo minimo (1.0900)
```

**FLOATING LOSS MASSIMO:**
- 7 posizioni BUY aperte in loss
- FL = Σ (Entry - CurrentPrice) × LotSize
- Con 0.01 lot e 10 pip spacing: ~$49 floating loss al minimo

**RECOVERY:**
- Quando prezzo risale, ogni grid chiude in profit
- Il cycling riapre le grid → nuovo profitto
- Sistema si "recupera" automaticamente

---

## Scenario B: Zig-Zag (Range Trading)

```
SCENARIO: Prezzo oscilla tra 1.0950 e 1.1050

        ┌─────────────────────────────────────────────────────┐
        │                                                     │
   1.1050├─────────── Range Alto ─────────────────────────────│
        │         ↗    ↘    ↗    ↘    ↗    ↘                 │
        │       ↗        ↘↗        ↘↗        ↘               │
   1.1000├─── Entry ──────────────────────────────────────────│
        │     ↗                                    ↘          │
   1.0950├─────────── Range Basso ────────────────────────────│
        │                                                     │
        └─────────────────────────────────────────────────────┘
```

**COMPORTAMENTO:**
- Grid chiudono in profit su ogni oscillazione
- Cyclic reopen le rimpiazza
- Floating loss BASSO perché poche grid attive contemporaneamente
- **SCENARIO IDEALE** per SUGAMARA

---

## ✅ CONCLUSIONE PUNTO 2

| Scenario | Floating Loss | Recovery | Note |
|----------|---------------|----------|------|
| Storno Marcato | ALTO ($30-70) | Possibile se ritorna | Richiede pazienza |
| Zig-Zag | BASSO ($5-15) | Continuo | Scenario ideale |

**RACCOMANDAZIONE:** Il sistema è matematicamente corretto. Il FL alto in caso di storno è il "costo" per non usare stop loss.

---

# 🔴 PUNTO 7: BUG COP NON CONTA PROFITTI

## 📍 PROBLEMA IDENTIFICATO

**File:** `CloseOnProfitManager.mqh`

**PROBLEMA:** La variabile `cop_RealizedProfit` viene aggiornata SOLO quando `COP_RecordTrade()` è chiamata (da `OnTradeTransaction()`).

**MA:** Se l'EA viene **riavviato** durante la giornata, `cop_RealizedProfit` si resetta a **ZERO** in `COP_ResetDaily()`!

I profitti già realizzati nella sessione vengono persi.

**CONSEGUENZA:** Il COP non raggiunge mai il target perché parte sempre da $0 dopo ogni riavvio.

---

## ✅ FIX PUNTO 7: CloseOnProfitManager.mqh

**AZIONE:** In `COP_UpdateTracking()`, aggiungere ricalcolo dei profitti dalla storia.

La funzione `GetCurrentPairRealizedProfit()` esiste già in `PositionMonitor.mqh` (riga 224-252) e calcola correttamente i profitti dalla storia dei deal!

**File:** `CloseOnProfitManager.mqh`

**Modifica - Funzione `COP_UpdateTracking()` (riga 88-109):**

```cpp
// TROVA questa funzione:
void COP_UpdateTracking() {
    if(!Enable_CloseOnProfit) return;

    // Check for new day reset
    if(COP_IsNewDay()) {
        COP_ResetDaily();
    }

    // Skip if target already reached
    if(cop_TargetReached) return;

    // Update floating
    cop_FloatingProfit = COP_IncludeFloating ? COP_GetFloatingProfit() : 0;

    // Update commissions (solo per display/dashboard)
    cop_TotalCommissions = COP_CalculateCommissions();

    // Calculate net profit
    cop_NetProfit = cop_RealizedProfit + cop_FloatingProfit;
}

// SOSTITUISCI CON:
void COP_UpdateTracking() {
    if(!Enable_CloseOnProfit) return;

    // Check for new day reset
    if(COP_IsNewDay()) {
        COP_ResetDaily();
    }

    // Skip if target already reached
    if(cop_TargetReached) return;

    // ✅ FIX: Ricalcola realized profit dalla storia dei deal
    // Questo garantisce che i profitti siano corretti anche dopo riavvio EA
    cop_RealizedProfit = GetCurrentPairRealizedProfit();

    // Update floating
    cop_FloatingProfit = COP_IncludeFloating ? COP_GetFloatingProfit() : 0;

    // Update commissions (solo per display/dashboard)
    cop_TotalCommissions = COP_CalculateCommissions();

    // Calculate net profit
    // NOTA: cop_RealizedProfit già include commissioni (DEAL_COMMISSION)
    cop_NetProfit = cop_RealizedProfit + cop_FloatingProfit;
}
```

---

# ⚙️ PUNTO 10: SPACING EURUSD 9 → 10 PIP

## 📍 MODIFICA RICHIESTA

**File:** `InputParameters.mqh`

**Riga:** 525

**Modifica:**

```cpp
// TROVA questa riga (525):
input double    EURUSD_DefaultSpacing = 9.0;                 // 📐 Spacing Default (pips)

// SOSTITUISCI CON:
input double    EURUSD_DefaultSpacing = 10.0;                // 📐 Spacing Default (pips)
```

---

# 🔧 PUNTO 3 + 11A: DASHBOARD - P/L → CONTATORI

## 📍 MODIFICA RICHIESTA

Sostituire la visualizzazione del P/L parziale con il numero di grid aperte/pending.

**File:** `Dashboard.mqh`

**NOTA:** Esiste già `UpdateGridCounterSection()` (riga 993-1019) che mostra i contatori. Verifica che sia visibile nella dashboard.

Se vuoi modificare le sezioni Grid A/B per mostrare contatori invece di P/L:

**Modifica - Funzione `UpdateGridASection()` (riga 919-921):**

```cpp
// TROVA queste righe:
color profitColor = profit >= 0 ? CLR_PROFIT : CLR_LOSS;
ObjectSetString(0, "LEFT_GRIDA_PROFIT", OBJPROP_TEXT, StringFormat("P/L: $%.2f", profit));
ObjectSetInteger(0, "LEFT_GRIDA_PROFIT", OBJPROP_COLOR, profitColor);

// SOSTITUISCI CON (opzionale - per mostrare contatori invece di P/L):
int openCount = GetGridAActivePositions();
int pendingCount = GetGridAPendingOrders();
ObjectSetString(0, "LEFT_GRIDA_PROFIT", OBJPROP_TEXT, 
                StringFormat("Open: %d | Pending: %d", openCount, pendingCount));
ObjectSetInteger(0, "LEFT_GRIDA_PROFIT", OBJPROP_COLOR, CLR_ACTIVE);
```

**Modifica - Funzione `UpdateGridBSection()` (riga 954-956):**

```cpp
// TROVA queste righe:
color profitColor = profit >= 0 ? CLR_PROFIT : CLR_LOSS;
ObjectSetString(0, "RIGHT_GRIDB_PROFIT", OBJPROP_TEXT, StringFormat("P/L: $%.2f", profit));
ObjectSetInteger(0, "RIGHT_GRIDB_PROFIT", OBJPROP_COLOR, profitColor);

// SOSTITUISCI CON (opzionale - per mostrare contatori invece di P/L):
int openCount = GetGridBActivePositions();
int pendingCount = GetGridBPendingOrders();
ObjectSetString(0, "RIGHT_GRIDB_PROFIT", OBJPROP_TEXT, 
                StringFormat("Open: %d | Pending: %d", openCount, pendingCount));
ObjectSetInteger(0, "RIGHT_GRIDB_PROFIT", OBJPROP_COLOR, CLR_ACTIVE);
```

---

# ⚙️ PUNTO 4: CONFIGURAZIONE BEP OTTIMALE

## Tabella Configurazioni Consigliate

I parametri BOP esistono già in `InputParameters.mqh` (righe 92-93):
- `BOP_TriggerPercent` (default 75%)
- `BOP_LockPercent` (default 50%)

**Configurazioni consigliate per pair:**

| Pair | Spacing | BOP_Trigger | BOP_Lock | Note |
|------|---------|-------------|----------|------|
| **EURUSD** | 10 pip | 70% | 50% | Standard config |
| **GBPUSD** | 12 pip | 65% | 45% | Più volatile, lock prima |
| **USDCAD** | 12 pip | 70% | 50% | Standard |
| **AUDUSD** | 10 pip | 70% | 50% | Standard |
| **USDJPY** | 12 pip | 60% | 40% | Alta volatilità, lock early |

**NOTA:** Questi valori sono da impostare manualmente nell'EA al caricamento.

---

# 🆕 PUNTO 5: TRAILING PROFIT EVOLUTO (PROPOSTA)

## Logica Proposta: "DYNAMIC TRAILING PROFIT"

```
╔═══════════════════════════════════════════════════════════════════╗
║  FASE 1 (0-50% verso TP):   Nessuna azione                        ║
║  FASE 2 (50-70%):           Attiva BEP progressivo                ║
║                             SL = Entry + 20% del profit attuale   ║
║  FASE 3 (70-100%+):         Attiva Trailing                       ║
║                             SL segue il prezzo a 30% di distanza  ║
╚═══════════════════════════════════════════════════════════════════╝
```

**PARAMETRI SUGGERITI (da aggiungere a InputParameters.mqh):**

```cpp
//--- TRAILING PROFIT EVOLUTO (proposta punto 5)
input bool   TrailProfit_Enabled = false;               // 📈 Abilita Trailing Profit
input double TrailProfit_ActivationPercent = 50.0;      // % verso TP per attivare
input double TrailProfit_BEP_Lock = 20.0;               // % profit da proteggere in Fase 2
input double TrailProfit_TrailingStart = 70.0;          // % verso TP per iniziare trailing
input double TrailProfit_TrailingDistance = 30.0;       // % distanza trailing
```

**NOTA:** Questa è una NUOVA FUNZIONALITÀ che richiede un nuovo modulo. Non è un bug fix.

---

# 🆕 PUNTO 6: ULTIME 2 GRID - BEP 20% (PROPOSTA)

## Logica Proposta: "EDGE GRID PROTECTION"

```
╔═══════════════════════════════════════════════════════════════════╗
║  OBIETTIVO: Proteggere le ultime 2 grid (livelli 6-7)             ║
║                                                                   ║
║  TRIGGER: Quando profit ≥ 20% del TP                              ║
║  AZIONE:  Sposta SL a Entry (breakeven)                           ║
║                                                                   ║
║  BENEFICIO: Evita che le grid ai bordi accumulino floating loss   ║
║             in caso di inversione                                 ║
╚═══════════════════════════════════════════════════════════════════╝
```

**PARAMETRI SUGGERITI (da aggiungere a InputParameters.mqh):**

```cpp
//--- EDGE GRID PROTECTION (proposta punto 6)
input bool   EdgeGrid_Protection = false;               // 🛡️ Abilita protezione ultime grid
input int    EdgeGrid_LastN = 2;                        // Ultime N grid da proteggere
input double EdgeGrid_BEP_Trigger = 20.0;               // % profit per attivare BEP
```

**NOTA:** Questa è una NUOVA FUNZIONALITÀ opzionale.

---

# 🔧 PUNTO 11B: DASHBOARD GRID ZERO STATUS

## Stato Attuale

La sezione Grid Zero esiste già in `UpdateGridZeroSection()` (riga 1070+).

Mostra:
- Status (WAITING/ACTIVE/IN TRADE/CYCLING)
- Bias (BULLISH/BEARISH)

**PROPOSTA DI MIGLIORAMENTO:**

Aggiungere dettaglio status ordini STOP e LIMIT con cicli.

**File:** `Dashboard.mqh`

**Aggiungere alla fine di `UpdateGridZeroSection()`:**

```cpp
// ✅ AGGIUNGERE: Dettaglio status ordini Grid Zero
string stopStatus = GetOrderStatusName(g_gridZero_StopStatus);
string limitStatus = GetOrderStatusName(g_gridZero_LimitStatus);

ObjectSetString(0, "GZ_STOP_STATUS", OBJPROP_TEXT, 
                StringFormat("STOP: %s (Cycles: %d)", stopStatus, g_gridZero_StopCycles));
ObjectSetString(0, "GZ_LIMIT_STATUS", OBJPROP_TEXT, 
                StringFormat("LIMIT: %s (Cycles: %d)", limitStatus, g_gridZero_LimitCycles));

// Colori in base allo stato
color stopColor = (g_gridZero_StopStatus == ORDER_FILLED) ? CLR_ACTIVE : 
                  (g_gridZero_StopStatus == ORDER_PENDING) ? CLR_PROFIT : clrGray;
color limitColor = (g_gridZero_LimitStatus == ORDER_FILLED) ? CLR_ACTIVE : 
                   (g_gridZero_LimitStatus == ORDER_PENDING) ? CLR_PROFIT : clrGray;

ObjectSetInteger(0, "GZ_STOP_STATUS", OBJPROP_COLOR, stopColor);
ObjectSetInteger(0, "GZ_LIMIT_STATUS", OBJPROP_COLOR, limitColor);
```

**NOTA:** Richiede che gli oggetti grafici `GZ_STOP_STATUS` e `GZ_LIMIT_STATUS` siano creati nella funzione `CreateGridZeroSection()`.

---

# 📋 RIEPILOGO FINALE AZIONI

## 🔴 BUG CRITICI DA RISOLVERE (PRIORITÀ MASSIMA)

| # | File | Funzione | Azione |
|---|------|----------|--------|
| 1A | TrailingGridManager.mqh | RemoveDistantGridBelow() | Aggiungere `g_trailExtraGridsBelow--;` |
| 1A | TrailingGridManager.mqh | RemoveDistantGridAbove() | Aggiungere `g_trailExtraGridsAbove--;` |
| 1B | GridASystem.mqh | UpdateGridAStatuses() | Estendere range a `GridLevelsPerSide + g_trailExtraGrids` |
| 1B | GridBSystem.mqh | UpdateGridBStatuses() | Estendere range a `GridLevelsPerSide + g_trailExtraGrids` |
| 1C | GridASystem.mqh | ProcessGridACyclicReopen() | Estendere range a `GridLevelsPerSide + g_trailExtraGrids` |
| 1C | GridBSystem.mqh | ProcessGridBCyclicReopen() | Estendere range a `GridLevelsPerSide + g_trailExtraGrids` |
| 7 | CloseOnProfitManager.mqh | COP_UpdateTracking() | Aggiungere `cop_RealizedProfit = GetCurrentPairRealizedProfit();` |

## ⚙️ MODIFICHE CONFIGURAZIONE

| # | File | Riga | Modifica |
|---|------|------|----------|
| 10 | InputParameters.mqh | 525 | `EURUSD_DefaultSpacing = 9.0` → `10.0` |

## 🔧 MODIFICHE DASHBOARD (OPZIONALI)

| # | File | Funzione | Azione |
|---|------|----------|--------|
| 3/11A | Dashboard.mqh | UpdateGridASection() | Sostituire P/L con contatori |
| 3/11A | Dashboard.mqh | UpdateGridBSection() | Sostituire P/L con contatori |
| 11B | Dashboard.mqh | UpdateGridZeroSection() | Aggiungere dettaglio status |

## 🆕 NUOVE FUNZIONALITÀ (PROPOSTE - NON URGENTI)

| # | Descrizione | Note |
|---|-------------|------|
| 5 | Trailing Profit Evoluto | Richiede nuovo modulo |
| 6 | Edge Grid Protection | Richiede nuovo modulo |

---

# ✅ ISTRUZIONI PER CLAUDE CODE

## Ordine di Esecuzione

1. **PRIMO:** Applicare FIX 1A (TrailingGridManager.mqh)
2. **SECONDO:** Applicare FIX 1B (GridASystem.mqh + GridBSystem.mqh)
3. **TERZO:** Applicare FIX 1C (GridASystem.mqh + GridBSystem.mqh)
4. **QUARTO:** Applicare FIX 7 (CloseOnProfitManager.mqh)
5. **QUINTO:** Applicare modifica 10 (InputParameters.mqh)
6. **SESTO:** Opzionale - Dashboard modifications

## Verifica Post-Modifica

Dopo ogni modifica, compilare l'EA e verificare:
- ✅ Nessun errore di compilazione
- ✅ Nessun warning critico
- ✅ EA si carica correttamente su grafico

---

**DOCUMENTO COMPLETATO**

*Data: 5 Gennaio 2026*
*Versione: 1.0*
*Target: SUGAMARA v8.0*
