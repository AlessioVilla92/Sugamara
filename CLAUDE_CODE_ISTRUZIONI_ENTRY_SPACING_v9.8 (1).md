# SUGAMARA RIBELLE v9.8 - IMPLEMENTAZIONE ENTRY SPACING MODE

## 📋 OBIETTIVO

Implementare la funzionalità **Entry Spacing Mode** che permette di configurare la distanza tra l'Entry Point e le prime grid (Grid +1 e Grid -1), eliminando il "buco" di 20 pips al centro della griglia.

**Contestualmente, RIMUOVERE COMPLETAMENTE** la funzionalità Grid Zero che non verrà più utilizzata.

---

## 🎯 PROBLEMA DA RISOLVERE

### Situazione Attuale (v9.7)
Quando l'utente preme START:
- Entry Point viene fissato al prezzo corrente
- Grid +1 viene piazzata a `Entry + GridSpacing` (es: +10 pips)
- Grid -1 viene piazzata a `Entry - GridSpacing` (es: -10 pips)
- **RISULTATO**: Buco di 20 pips tra Grid +1 e Grid -1

```
Grid +2:  +20 pips  ████████████
Grid +1:  +10 pips  ████████████
                    
ENTRY:      0 pips  ══════════════  ← Prezzo START
                    
                    ← BUCO 20 PIPS! →
                    
Grid -1:  -10 pips  ████████████
Grid -2:  -20 pips  ████████████
```

### Soluzione: Entry Spacing Mode
Permettere all'utente di scegliere la distanza delle prime grid dall'entry:

| Modalità | Entry Spacing | Gap al Centro | Descrizione |
|----------|---------------|---------------|-------------|
| **FULL** | = GridSpacing | 2×spacing (20 pips) | Legacy/Default originale |
| **HALF** | = GridSpacing/2 | = spacing (10 pips) | **PERFECT CASCADE** |
| **MANUAL** | = Custom pips | 2×custom | Configurabile dall'utente |

---

## 📁 FILE DA MODIFICARE

### Lista completa file coinvolti:
1. `Config/Enums.mqh` - Aggiungere ENUM_ENTRY_SPACING_MODE
2. `Config/InputParameters.mqh` - Aggiungere input parameters + RIMUOVERE Grid Zero
3. `Utils/GridHelpers.mqh` - Modificare CalculateGridLevelPrice()
4. `Trading/GridZero.mqh` - SOSTITUIRE con file stub vuoto
5. `Sugamara.mq5` - Aggiornare versione e log
6. `UI/Dashboard.mqh` - Rimuovere riferimenti Grid Zero
7. `Core/Initialization.mqh` - Rimuovere chiamate Grid Zero
8. `Core/RecoveryManager.mqh` - Rimuovere recovery Grid Zero

---

## 📝 MODIFICHE DETTAGLIATE

---

### 1️⃣ Config/Enums.mqh

**POSIZIONE**: Dopo `ENUM_FOREX_PAIR` (circa riga 37)

**AGGIUNGERE** il nuovo ENUM:

```cpp
//+------------------------------------------------------------------+
//| 🆕 v9.8 ENTRY SPACING MODE - Spaziatura prima grid da entry      |
//+------------------------------------------------------------------+
//| Configura la distanza tra Entry Point e Grid ±1                  |
//| Risolve il "buco" al centro della griglia                        |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_SPACING_MODE {
    ENTRY_SPACING_FULL = 0,     // FULL - Prima grid a spacing completo (buco = 2×spacing)
    ENTRY_SPACING_HALF = 1,     // HALF - Prima grid a metà spacing (PERFECT CASCADE!)
    ENTRY_SPACING_MANUAL = 2    // MANUAL - Prima grid a distanza personalizzata
};
```

---

### 2️⃣ Config/InputParameters.mqh

#### A) AGGIORNARE HEADER (riga 6)
```cpp
// DA:
//|  v9.7 - Cleanup & Fixes                                          |

// A:
//|  v9.8 - Entry Spacing Mode + Grid Zero Removed                   |
```

#### B) AGGIUNGERE SEZIONE ENTRY SPACING
**POSIZIONE**: Dopo la riga con `Fixed_Spacing_Pips` (circa riga 96)

```cpp
input group "    ╔═ ENTRY SPACING v9.8 ═══════════════════════════════════════🔽🔽🔽"
input ENUM_ENTRY_SPACING_MODE EntrySpacingMode = ENTRY_SPACING_HALF; // 📐 Entry Spacing Mode ▼
// FULL:   Grid ±1 a ±spacing completo (buco = 2×spacing, es: 20 pips)
// HALF:   Grid ±1 a ±spacing/2 (buco = spacing, es: 10 pips) - PERFECT CASCADE!
// MANUAL: Grid ±1 a distanza personalizzata (configurabile sotto)

input double    Entry_Spacing_Manual_Pips = 5.0;                     // 📐 Distanza Manuale Entry→Grid±1 (pips)
// Usato SOLO quando EntrySpacingMode = ENTRY_SPACING_MANUAL
// Esempio: 5.0 = Grid+1 a +5 pips dall'entry, Grid-1 a -5 pips dall'entry
// Il "buco" al centro sarà 2 × questo valore (es: 10 pips con 5.0)
```

#### C) RIMUOVERE COMPLETAMENTE SEZIONE GRID ZERO
**POSIZIONE**: Righe 173-193 (circa)

**ELIMINARE TUTTO QUESTO BLOCCO:**
```cpp
// ❌ RIMUOVERE COMPLETAMENTE - DA ELIMINARE:

input group "                                                           "
input group "╔════════════════════════════════════════════════════════════╗"
input group "║  🎯 GRID ZERO v5.8 - Center Gap Filler                    ║"
input group "╚════════════════════════════════════════════════════════════╝"

input group "    ✅ ATTIVAZIONE"
input bool   Enable_GridZero = true;                        // ✅ Abilita Grid Zero (Mean Reversion)
// Grid Zero fills the 27-pip gap at the center of the grid
// Triggered when L2 is filled (price moved 24+ pips from entry)
// Inserts counter-trend orders for mean-reversion strategy

input group "    📊 CONFIGURAZIONE"
input int    GridZero_Trigger_Level = 2;                    // 🎯 Trigger Level (L2 = default)
// 1 = Trigger when L1 filled (12 pips from entry)
// 2 = Trigger when L2 filled (24 pips from entry) - RECOMMENDED
// 3 = Trigger when L3 filled (36 pips from entry) - Conservative

// ❌ FINE BLOCCO DA ELIMINARE
```

---

### 3️⃣ Utils/GridHelpers.mqh

#### A) AGGIORNARE HEADER
```cpp
//|  v9.8 - Entry Spacing Mode Implementation                        |
```

#### B) AGGIUNGERE FUNZIONI HELPER
**POSIZIONE**: Dopo la funzione `GetOrderTypeString()` (circa riga 127)

```cpp
//+------------------------------------------------------------------+
//| 🆕 v9.8: Get Entry Spacing in Pips                               |
//| Restituisce la distanza in pips tra Entry Point e Grid ±1        |
//+------------------------------------------------------------------+
double GetEntrySpacingPips(double gridSpacingPips) {
    switch(EntrySpacingMode) {
        case ENTRY_SPACING_FULL:
            // Legacy: Prima grid a spacing completo
            // Buco = 2 × gridSpacingPips (es: 20 pips con spacing 10)
            return gridSpacingPips;
            
        case ENTRY_SPACING_HALF:
            // PERFECT CASCADE: Prima grid a metà spacing
            // Buco = gridSpacingPips (es: 10 pips con spacing 10)
            return gridSpacingPips / 2.0;
            
        case ENTRY_SPACING_MANUAL:
            // Custom: Prima grid a distanza definita dall'utente
            // Buco = 2 × Entry_Spacing_Manual_Pips
            return Entry_Spacing_Manual_Pips;
            
        default:
            return gridSpacingPips;
    }
}

//+------------------------------------------------------------------+
//| 🆕 v9.8: Get Entry Spacing Mode Name (for logging/dashboard)     |
//+------------------------------------------------------------------+
string GetEntrySpacingModeName() {
    switch(EntrySpacingMode) {
        case ENTRY_SPACING_FULL:   
            return "FULL (Buco: " + DoubleToString(currentSpacing_Pips * 2, 1) + " pips)";
        case ENTRY_SPACING_HALF:   
            return "HALF/Perfect (" + DoubleToString(currentSpacing_Pips, 1) + " pips)";
        case ENTRY_SPACING_MANUAL: 
            return "MANUAL (" + DoubleToString(Entry_Spacing_Manual_Pips, 1) + " pips)";
        default:                   
            return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| 🆕 v9.8: Log Entry Spacing Configuration                         |
//+------------------------------------------------------------------+
void LogEntrySpacingConfig() {
    double entrySpacing = GetEntrySpacingPips(currentSpacing_Pips);
    double gapAtCenter = entrySpacing * 2;
    
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  🆕 v9.8 ENTRY SPACING CONFIGURATION");
    Print("═══════════════════════════════════════════════════════════════════");
    PrintFormat("  Mode: %s", GetEntrySpacingModeName());
    PrintFormat("  Grid Spacing: %.1f pips", currentSpacing_Pips);
    PrintFormat("  Entry Spacing (Entry→Grid±1): %.1f pips", entrySpacing);
    PrintFormat("  Gap at Center (Grid+1 ↔ Grid-1): %.1f pips", gapAtCenter);
    
    if(EntrySpacingMode == ENTRY_SPACING_HALF) {
        Print("");
        Print("  ✅ PERFECT CASCADE ATTIVO!");
        Print("  → Gap al centro = Grid Spacing (simmetria perfetta)");
        Print("  → Tutti i Take Profit sono perfettamente allineati");
    }
    Print("═══════════════════════════════════════════════════════════════════");
}
```

#### C) MODIFICARE CalculateGridLevelPrice()
**POSIZIONE**: Righe 137-149 (circa)

**SOSTITUIRE LA FUNZIONE ESISTENTE CON:**

```cpp
//+------------------------------------------------------------------+
//| Calculate Entry Price for Grid Level                             |
//| 🆕 v9.8: ENTRY SPACING MODE - Supporta FULL/HALF/MANUAL          |
//|                                                                  |
//| FORMULA v9.8:                                                    |
//|   Level 0 (L1): baseEntry ± entrySpacing                         |
//|   Level N (LN+1): baseEntry ± entrySpacing + (N × gridSpacing)   |
//|                                                                  |
//| ESEMPI con GridSpacing=10, EntrySpacingMode=HALF:                |
//|   entrySpacing = 5 pips                                          |
//|   L1 (level=0): entry ± 5 pips                                   |
//|   L2 (level=1): entry ± 5 + 10 = ± 15 pips                       |
//|   L3 (level=2): entry ± 5 + 20 = ± 25 pips                       |
//+------------------------------------------------------------------+
double CalculateGridLevelPrice(double baseEntryPoint, ENUM_GRID_ZONE zone, int level,
                                double spacingPips, ENUM_GRID_SIDE side = GRID_A) {
    
    // Converti pips in price points
    double spacingPrice = PipsToPoints(spacingPips);
    
    // 🆕 v9.8: Calcola Entry Spacing basato sulla modalità
    double entrySpacingPips = GetEntrySpacingPips(spacingPips);
    double entrySpacingPrice = PipsToPoints(entrySpacingPips);
    
    //=================================================================
    // CALCOLO OFFSET v9.8
    //=================================================================
    double offset;
    
    if(level == 0) {
        // Prima grid (L1): usa Entry Spacing
        // Questa è la distanza tra Entry Point e Grid ±1
        offset = entrySpacingPrice;
    } else {
        // Altre grid (L2, L3, ...): Entry Spacing + (level × spacing)
        // L2: entrySpacing + 1×spacing
        // L3: entrySpacing + 2×spacing
        // ecc.
        offset = entrySpacingPrice + (spacingPrice * level);
    }
    
    //=================================================================
    // APPLICA OFFSET IN BASE ALLA ZONA
    //=================================================================
    if(zone == ZONE_UPPER) {
        // Upper zone: prezzi SOPRA l'entry point (positivi)
        return NormalizeDouble(baseEntryPoint + offset, symbolDigits);
    } else {
        // Lower zone: prezzi SOTTO l'entry point (negativi)
        return NormalizeDouble(baseEntryPoint - offset, symbolDigits);
    }
}
```

#### D) MODIFICARE CalculateCascadeTP() (opzionale ma consigliato)
La funzione CalculateCascadeTP potrebbe necessitare aggiustamenti per garantire che i TP siano corretti con il nuovo sistema. Verificare che per L1 il TP punti correttamente all'entry point.

---

### 4️⃣ Trading/GridZero.mqh

**SOSTITUIRE L'INTERO FILE** con questo stub che mantiene compatibilità:

```cpp
//+------------------------------------------------------------------+
//|                                                    GridZero.mqh  |
//|                        Sugamara v9.8 - Grid Zero REMOVED         |
//|                                                                  |
//|  🚫 v9.8: GRID ZERO COMPLETAMENTE RIMOSSO                        |
//|  Sostituito da Entry Spacing Mode in GridHelpers.mqh             |
//|  Questo file contiene solo stub per compatibilità                |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025-2026"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES (stub - non utilizzate)                         |
//+------------------------------------------------------------------+
bool g_gridZeroInserted = false;
bool g_gridZeroBiasUp = false;
bool g_gridZeroBiasDown = false;
int g_gridZero_PendingCount = 0;
int g_gridZero_FilledCount = 0;

//+------------------------------------------------------------------+
//| STUB FUNCTIONS - Tutte vuote per compatibilità                   |
//+------------------------------------------------------------------+

void InitGridZero() {
    // v9.8: Grid Zero removed - replaced by Entry Spacing Mode
    if(DetailedLogging) {
        Print("[GridZero] v9.8: DISABLED - Using Entry Spacing Mode");
    }
}

void ResetGridZeroFlags() {
    g_gridZeroInserted = false;
    g_gridZeroBiasUp = false;
    g_gridZeroBiasDown = false;
}

void CheckAndInsertGridZero() {
    // v9.8: Does nothing - Entry Spacing handles center gap
}

void ManageGridZeroCycling() {
    // v9.8: Does nothing
}

void UpdateGridZeroStatus(ulong ticket, ENUM_ORDER_STATUS newStatus) {
    // v9.8: Does nothing
}

bool IsGridZeroTicket(ulong ticket) {
    return false;  // v9.8: No Grid Zero tickets exist
}

string GetGridZeroStatusText() {
    return "N/A (v9.8)";
}

string GetGridZeroBiasText() {
    return "N/A";
}

void DrawGridZeroLines() {
    // v9.8: No Grid Zero lines to draw
}

void RemoveGridZeroLines() {
    // Cleanup any old lines that might exist
    ObjectDelete(0, "GRIDZERO_STOP");
    ObjectDelete(0, "GRIDZERO_LIMIT");
}

void DeinitializeGridZero() {
    RemoveGridZeroLines();
}

void RecoverGridZeroOrdersFromBroker() {
    // v9.8: No Grid Zero orders to recover
}
```

---

### 5️⃣ Sugamara.mq5

#### A) AGGIORNARE HEADER (righe 1-36)
```cpp
//+==================================================================+
//|                                    SUGAMARA RIBELLE v9.8         |
//|                                                                  |
//|   CASCADE SOVRAPPOSTO - Grid A=BUY, Grid B=SELL                  |
//|                                                                  |
//|   "The Spice Must Flow" - DUNE Theme                             |
//|   Ottimizzato per EUR/USD e AUD/NZD                              |
//+------------------------------------------------------------------+
//|  Copyright (C) 2025-2026 - Sugamara Ribelle Development Team     |
//|  Version: 9.8.0 - Entry Spacing Mode + Grid Zero Removed         |
//|  Release Date: January 2026                                      |
//+------------------------------------------------------------------+

#property version   "9.80"
#property description "SUGAMARA RIBELLE v9.8 - Entry Spacing Mode"
#property description "Grid A = SOLO BUY | Grid B = SOLO SELL"
#property description "Grid Zero RIMOSSO - Entry Spacing Mode attivo"
```

#### B) IN OnInit() - Aggiungere log Entry Spacing
**POSIZIONE**: Dopo `ApplyPairPresets();` (circa riga 161)

```cpp
    //--- v9.8: Log Entry Spacing Configuration ---
    LogEntrySpacingConfig();
```

#### C) IN LogV4StatusReport() - Aggiornare report
**POSIZIONE**: Nella funzione LogV4StatusReport (circa riga 850-860)

**RIMUOVERE:**
```cpp
Print("│  GRID ZERO: ", Enable_GridZero ? "ENABLED (Visual Priority 5px)" : "DISABLED");
```

**AGGIUNGERE:**
```cpp
Print("│  ENTRY SPACING: ", GetEntrySpacingModeName());
Print("│  Gap at Center: ", DoubleToString(GetEntrySpacingPips(currentSpacing_Pips) * 2, 1), " pips");
```

---

### 6️⃣ UI/Dashboard.mqh

**CERCARE E RIMUOVERE** tutti i riferimenti a Grid Zero nella dashboard:
- Rimuovere righe che mostrano `GetGridZeroStatusText()`
- Rimuovere righe che mostrano `GetGridZeroBiasText()`
- Sostituire con visualizzazione Entry Spacing Mode

---

### 7️⃣ Core/Initialization.mqh

**CERCARE E RIMUOVERE** chiamate a:
- `InitGridZero()`
- Eventuali riferimenti a `Enable_GridZero`

---

### 8️⃣ Core/RecoveryManager.mqh

**CERCARE E RIMUOVERE** chiamate a:
- `RecoverGridZeroOrdersFromBroker()`
- Riferimenti a recovery Grid Zero

---

## 📊 VISUALIZZAZIONE RISULTATO

### ENTRY_SPACING_FULL (Legacy)
```
Grid +3:  +30 pips  ████████████
Grid +2:  +20 pips  ████████████
Grid +1:  +10 pips  ████████████
                    
ENTRY:      0 pips  ══════════════
                    ← BUCO 20 PIPS →
Grid -1:  -10 pips  ████████████
Grid -2:  -20 pips  ████████████
Grid -3:  -30 pips  ████████████

Distanza Grid+1 ↔ Grid-1 = 20 pips
```

### ENTRY_SPACING_HALF (Perfect Cascade) ⭐ RACCOMANDATO
```
Grid +3:  +25 pips  ████████████
Grid +2:  +15 pips  ████████████
Grid +1:   +5 pips  ████████████  ← Entry Spacing = Spacing/2
                    
ENTRY:      0 pips  ══════════════
                    ← BUCO 10 PIPS = SPACING →
Grid -1:   -5 pips  ████████████  ← Entry Spacing = Spacing/2
Grid -2:  -15 pips  ████████████
Grid -3:  -25 pips  ████████████

Distanza Grid+1 ↔ Grid-1 = 10 pips = Spacing ✅
```

### ENTRY_SPACING_MANUAL (3 pips custom)
```
Grid +3:  +23 pips  ████████████
Grid +2:  +13 pips  ████████████
Grid +1:   +3 pips  ████████████  ← Entry Spacing = 3 pips (custom)
                    
ENTRY:      0 pips  ══════════════
                    ← BUCO 6 PIPS →
Grid -1:   -3 pips  ████████████
Grid -2:  -13 pips  ████████████
Grid -3:  -23 pips  ████████████

Distanza Grid+1 ↔ Grid-1 = 6 pips (2 × custom)
```

---

## ✅ CHECKLIST VERIFICA

Dopo l'implementazione, verificare:

- [ ] ENUM_ENTRY_SPACING_MODE compilato correttamente
- [ ] Input parameters visibili nel pannello MT5
- [ ] Default = ENTRY_SPACING_HALF
- [ ] Grid Zero completamente rimosso (no errori compilazione)
- [ ] Log OnInit mostra Entry Spacing config
- [ ] Dashboard mostra Entry Spacing mode
- [ ] Grid L1 posizionata correttamente (a metà spacing in HALF mode)
- [ ] Take Profit allineati correttamente
- [ ] Nessun riferimento residuo a Enable_GridZero

---

## 🧪 TEST CONSIGLIATI

1. **Test HALF Mode**: 
   - Spacing 10 pips
   - Verificare Grid +1 a +5 pips, Grid -1 a -5 pips
   - Verificare TP Grid +1 punta a Entry (0)

2. **Test MANUAL Mode**:
   - Entry_Spacing_Manual_Pips = 3.0
   - Verificare Grid +1 a +3 pips, Grid -1 a -3 pips

3. **Test FULL Mode (Legacy)**:
   - Verificare comportamento identico a v9.7

---

## 📝 NOTE FINALI

- **Backup**: Fare backup di tutti i file prima di modificare
- **Compilazione**: Compilare dopo ogni file modificato per catturare errori subito
- **Testing**: Testare prima in Strategy Tester, poi Demo
- **Recovery**: Il sistema di Recovery automatico gestirà anche le nuove grid senza modifiche

---

Documento creato: Gennaio 2026
Versione target: 9.8.0
