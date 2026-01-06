# SUGAMARA v8.0+ - DOCUMENTO OTTIMIZZAZIONI COMPLETE

**Data Creazione:** 5 Gennaio 2026  
**Sessione:** Chat Analisi Configurazione e Nuove Funzionalità  
**Versione Target:** v8.1  

---

## INDICE

1. [Filosofia Operativa SUGAMARA](#1-filosofia-operativa-sugamara)
2. [Configurazione 10 Grid vs 7 Grid](#2-configurazione-10-grid-vs-7-grid)
3. [Differenza TRAIL vs SHIELD](#3-differenza-trail-vs-shield)
4. [Sweet Spot Indicator](#4-sweet-spot-indicator)
5. [Grid Zero Visual Zone](#5-grid-zero-visual-zone)
6. [Grid Counters e Recycling Dashboard](#6-grid-counters-e-recycling-dashboard)
7. [Ottimizzazioni Prestazioni](#7-ottimizzazioni-prestazioni)
8. [Riepilogo Modifiche da Implementare](#8-riepilogo-modifiche-da-implementare)

---

## 1. FILOSOFIA OPERATIVA SUGAMARA

### La Forza del Sistema

La forza di SUGAMARA sta nel **rimanere a mercato** e sfruttare ogni singolo movimento:

```
APRI → CHIUDI → APRI → CHIUDI → APRI → CHIUDI (profit continuo)
```

### Principio Fondamentale

> **"Più l'EA rimane a mercato, più compensa le eventuali perdite e più approfitta dai movimenti laterali."**

### Come Funziona la Compensazione

1. **Movimento Direzionale** → Alcune grid vengono fillate e vanno in floating loss
2. **Lateralità Successiva** → Le grid "ciclano" (apri/chiudi) generando piccoli profit
3. **Accumulo Profit** → I profit si accumulano e compensano il floating loss
4. **Risultato** → `Floating Loss FISSO + Profit CUMULATIVO = Net Positive`

### Scenario Tipico

```
MATTINA: Movimento brusco → Grid L4, L5 SELL fillate → Floating Loss -€50
POMERIGGIO: Lateralità → 30 cicli apri/chiudi → Profit Realizzato +€35
SERA: Continua lateralità → 20 cicli apri/chiudi → Profit Realizzato +€25
FINE GIORNATA: Floating Loss -€50 + Profit +€60 = NET +€10
```

### Importanza delle Grid Pronte

È **essenziale** avere le grid già posizionate per:
- Essere pronti per rotture/breakout
- Sfruttare movimenti inversi dopo gap
- Non perdere opportunità mentre il Trail aggiunge grid

---

## 2. CONFIGURAZIONE 10 GRID VS 7 GRID

### Configurazione Attuale (7 Grid)

| Parametro | Valore |
|-----------|--------|
| Grid per lato | 7 |
| Lotti per grid | 0.03 |
| Esposizione max/lato | 0.21 lotti |
| Range coperto EUR/USD (11 pip) | 77 pip |
| Ordini totali | 28 (7×4) |

### Configurazione Proposta (10 Grid) ✅ RACCOMANDATA

| Parametro | EUR/USD | GBP/USD |
|-----------|---------|---------|
| Grid per lato | 10 | 10 |
| Lotti per grid | 0.02 | 0.02 |
| Spacing | 10-11 pip | 12 pip |
| Esposizione max/lato | 0.20 lotti | 0.20 lotti |
| Range coperto | 100-110 pip | 120 pip |
| Ordini totali | 40 (10×4) | 40 (10×4) |

### Vantaggi 10 Grid

| Vantaggio | Dettaglio |
|-----------|-----------|
| **+43% copertura range** | 110 pip vs 77 pip - CRUCIALE per gap weekend |
| **Esposizione simile** | 0.20 vs 0.21 lotti - rischio equivalente |
| **Grid già pronte** | Sfrutta subito lo storno dopo un gap |
| **Buffer più ampio** | Trail/Shield intervengono dopo, non subito |
| **Più cicli** | Più ordini = più opportunità apri/chiudi |

### Gestione Gap Weekend/Festivi

Con 10 grid a 11 pip = **110 pip di copertura**:
- Gap tipico weekend EUR/USD: 20-50 pip → **COPERTO**
- Gap medio festività: 30-80 pip → **COPERTO**
- Gap estremo (eventi geopolitici): 100-150 pip → **Parzialmente coperto + Shield**

### Modifica Codice

**File:** `InputParameters.mqh`

```cpp
// PRIMA (7 grid)
input int GridLevelsPerSide = 7;  // 🔢 Livelli per Lato (3-10) [Default: 7]

// DOPO (10 grid)
input int GridLevelsPerSide = 10; // 🔢 Livelli per Lato (3-15) [Default: 10]
```

### Note Importanti

- `MAX_GRID_LEVELS` è già impostato a 15 → supporta 10 grid + 5 extra trail
- Con 10 grid + Trail_Max_Extra_Grids=4, il massimo è 14 (sotto il limite 15)
- Le prestazioni con 40 ordini sono praticamente identiche a 28 ordini su MT5 moderno

---

## 3. DIFFERENZA TRAIL VS SHIELD

### TRAILING GRID (TrailingGridManager.mqh)

| Aspetto | Descrizione |
|---------|-------------|
| **OBIETTIVO** | Mantenere il gioco, seguire il mercato |
| **COSA FA** | Aggiunge nuove grid davanti quando il prezzo "consuma" quelle esistenti |
| **FILOSOFIA** | "Inserisci Prima, Elimina Dopo" - mai rimanere senza grid |
| **QUANDO SERVE** | Movimenti direzionali normali, drift intraday |
| **LIMITE** | NON può proteggerti da eventi catastrofici |

**Esempio Trail:**
```
Prezzo sale → Grid L5, L6, L7 BUY STOP fillate
Trail rileva: solo 2 grid pending sopra
Trail agisce: inserisce L8, L9 sopra
Risultato: sempre grid pronte per continuare a ciclare
```

### SHIELD (ShieldManager.mqh)

| Aspetto | Descrizione |
|---------|-------------|
| **OBIETTIVO** | Protezione emergenziale, evitare il disastro |
| **COSA FA** | Apre posizione di copertura che neutralizza la perdita |
| **FILOSOFIA** | "Copro e basta" - sacrifico profit futuri per preservare capitale |
| **QUANDO SERVE** | Cigni neri, gap weekend catastrofici, NFP disaster |
| **CAPACITÀ UNICA** | Crea hedge istantaneo che il Trail non può fare |

**Esempio Shield:**
```
Gap weekend: -200 pip overnight
Posizioni SHORT esposte: 0.15 lotti in floating loss -€300
Shield attiva: BUY 0.15 lotti a mercato
Risultato: Perdita BLOCCATA, non peggiora ulteriormente
```

### Tabella Comparativa

| Caratteristica | TRAIL | SHIELD |
|----------------|-------|--------|
| Tipo protezione | Prevenzione | Emergenza |
| Attivazione | Automatica continua | Solo su breakout estremo |
| Azione | Aggiunge/sposta grid | Apre hedge opposto |
| Impatto su profit | Nessuno (continua a ciclare) | Blocca tutto (stop profit e loss) |
| Gestisce gap? | NO (troppo veloce) | SÌ (istantaneo) |
| Complementare a? | Shield | Trail |

### Conclusione

**Trail e Shield sono COMPLEMENTARI, non alternativi:**
- **Trail** = Prevenzione continua durante il trading normale
- **Shield** = Paracadute per eventi straordinari

---

## 4. SWEET SPOT INDICATOR

### Descrizione

Indicatore visuale sulla Dashboard che mostra in quale **zona operativa** si trova il prezzo rispetto alla struttura grid.

### Zone Operative

| Zona | Posizione nel Range | Colore | Significato |
|------|---------------------|--------|-------------|
| **SWEET SPOT** | 20% - 80% (60% centrale) | 🟢 VERDE | Zona ottimale, cicla continuamente |
| **TRAIL ZONE** | 10% - 20% e 80% - 90% | 🟡 GIALLO | Trailing attivo, attenzione al drift |
| **SHIELD ZONE** | 0% - 10% e 90% - 100% | 🔴 ROSSO | Protezione attiva o imminente |

### Parametri da Mostrare

| Parametro | Descrizione | Formula/Calcolo |
|-----------|-------------|-----------------|
| **Zona Attuale** | Nome zona + colore | Posizione % nel range |
| **Range Coperto** | Pip totali coperti | `GridLevelsPerSide × Spacing` |
| **Cycle Rate** | Cicli completati per ora | `TotalCycles / HoursActive` |
| **Break-Even Distance** | Pip lateralità per recuperare floating | `FloatingLoss / AvgProfitPerCycle` |

### Interpretazione

```
🟢 SWEET SPOT: "Batti il ferro caldo sull'incudine!"
   → Prezzo lateralizza nel centro
   → Ogni oscillazione genera profit
   → IDEALE - lascia lavorare l'EA

🟡 TRAIL ZONE: "Attenzione al drift"
   → Prezzo verso gli estremi
   → Trail sta aggiungendo grid
   → Monitora ma non intervenire

🔴 SHIELD ZONE: "Evento straordinario"
   → Prezzo oltre l'ultima grid
   → Shield attivo o in pre-attivazione
   → Valuta se chiudere manualmente
```

### Codice Implementazione

**File:** `GlobalVariables.mqh` - Aggiungere struttura

```cpp
//+------------------------------------------------------------------+
//| SWEET SPOT INDICATOR DATA STRUCTURE                               |
//+------------------------------------------------------------------+
struct SweetSpotData {
    double pricePosition;        // 0.0-1.0 (0=bottom, 1=top del range)
    string zoneStatus;           // "SWEET_SPOT", "TRAIL_ZONE", "SHIELD_ZONE"
    color zoneColor;             // Verde/Giallo/Rosso
    double rangeCoveredPips;     // Pip totali coperti dalla grid
    double cycleRatePerHour;     // Cicli completati per ora
    double breakEvenDistPips;    // Pip necessari per break-even
    datetime lastUpdate;         // Timestamp ultimo aggiornamento
};

SweetSpotData g_sweetSpot;
```

**File:** `Dashboard.mqh` - Funzione di calcolo

```cpp
//+------------------------------------------------------------------+
//| Update Sweet Spot Indicator                                       |
//+------------------------------------------------------------------+
void UpdateSweetSpotIndicator() {
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double rangeTop = rangeUpperBound;
    double rangeBottom = rangeLowerBound;
    double rangeHeight = rangeTop - rangeBottom;
    
    if(rangeHeight <= 0) {
        g_sweetSpot.zoneStatus = "NO_RANGE";
        return;
    }
    
    // Calcola posizione % nel range (0.0 = bottom, 1.0 = top)
    g_sweetSpot.pricePosition = (currentPrice - rangeBottom) / rangeHeight;
    
    // Determina zona basata sulla posizione
    if(g_sweetSpot.pricePosition < 0.10 || g_sweetSpot.pricePosition > 0.90) {
        // SHIELD ZONE - Estremi 10%
        g_sweetSpot.zoneStatus = "SHIELD_ZONE";
        g_sweetSpot.zoneColor = CLR_LOSS;  // Rosso
    }
    else if(g_sweetSpot.pricePosition < 0.20 || g_sweetSpot.pricePosition > 0.80) {
        // TRAIL ZONE - 10%-20% e 80%-90%
        g_sweetSpot.zoneStatus = "TRAIL_ZONE";
        g_sweetSpot.zoneColor = CLR_NEUTRAL;  // Giallo
    }
    else {
        // SWEET SPOT - 20%-80% centrale
        g_sweetSpot.zoneStatus = "SWEET_SPOT";
        g_sweetSpot.zoneColor = CLR_PROFIT;  // Verde
    }
    
    // Calcola range coperto in pip
    g_sweetSpot.rangeCoveredPips = rangeHeight / PipsToPoints(1);
    
    // Calcola cycle rate (cicli per ora)
    int totalCycles = g_gridA_ClosedCount + g_gridB_ClosedCount;
    double hoursActive = (double)(TimeCurrent() - systemStartTime) / 3600.0;
    if(hoursActive > 0) {
        g_sweetSpot.cycleRatePerHour = totalCycles / hoursActive;
    } else {
        g_sweetSpot.cycleRatePerHour = 0;
    }
    
    // Calcola break-even distance
    double floatingLoss = MathAbs(MathMin(0, GetTotalOpenProfit()));
    double avgProfitPerCycle = 0;
    if(totalCycles > 0 && dailyRealizedProfit > 0) {
        avgProfitPerCycle = dailyRealizedProfit / totalCycles;
    } else {
        // Stima: spacing × lot × 10 (valore pip per lot standard)
        avgProfitPerCycle = currentSpacing_Pips * BaseLotSize * 10;
    }
    
    if(avgProfitPerCycle > 0) {
        // Pip necessari = (Loss / ProfitPerPip) dove ProfitPerPip ≈ lot × 10
        g_sweetSpot.breakEvenDistPips = floatingLoss / (BaseLotSize * 10);
    } else {
        g_sweetSpot.breakEvenDistPips = 0;
    }
    
    g_sweetSpot.lastUpdate = TimeCurrent();
}
```

**File:** `Dashboard.mqh` - Sezione visualizzazione

```cpp
//+------------------------------------------------------------------+
//| Draw Sweet Spot Panel                                             |
//+------------------------------------------------------------------+
void DrawSweetSpotPanel(int startX, int startY) {
    int y = startY;
    
    // Aggiorna dati
    UpdateSweetSpotIndicator();
    
    // Titolo sezione
    CreateLabel("SWEETSPOT_TITLE", "🎯 SWEET SPOT INDICATOR", 
                startX, y, CLR_SPICE, FONT_SIZE + 1);
    y += LINE_HEIGHT + 5;
    
    // Barra visuale (rappresentazione testuale)
    string barVisual = "";
    int position = (int)(g_sweetSpot.pricePosition * 20);  // 0-20
    for(int i = 0; i < 20; i++) {
        if(i == position) barVisual += "▼";
        else if(i < 2 || i > 17) barVisual += "█";  // Shield zone
        else if(i < 4 || i > 15) barVisual += "▓";  // Trail zone
        else barVisual += "░";  // Sweet spot
    }
    
    CreateLabel("SWEETSPOT_BAR", barVisual, 
                startX, y, g_sweetSpot.zoneColor, FONT_SIZE);
    y += LINE_HEIGHT;
    
    // Zona attuale
    string zoneEmoji = "";
    if(g_sweetSpot.zoneStatus == "SWEET_SPOT") zoneEmoji = "🟢";
    else if(g_sweetSpot.zoneStatus == "TRAIL_ZONE") zoneEmoji = "🟡";
    else if(g_sweetSpot.zoneStatus == "SHIELD_ZONE") zoneEmoji = "🔴";
    
    CreateLabel("SWEETSPOT_ZONE", zoneEmoji + " " + g_sweetSpot.zoneStatus, 
                startX, y, g_sweetSpot.zoneColor, FONT_SIZE);
    y += LINE_HEIGHT + 5;
    
    // Statistiche
    CreateLabel("SWEETSPOT_RANGE", 
                StringFormat("Range: %.0f pip", g_sweetSpot.rangeCoveredPips), 
                startX, y, CLR_SAND_3, FONT_SIZE);
    y += LINE_HEIGHT;
    
    CreateLabel("SWEETSPOT_CYCLE", 
                StringFormat("Cycle Rate: %.1f /hr", g_sweetSpot.cycleRatePerHour), 
                startX, y, CLR_SAND_3, FONT_SIZE);
    y += LINE_HEIGHT;
    
    CreateLabel("SWEETSPOT_BE", 
                StringFormat("Break-Even: %.1f pip", g_sweetSpot.breakEvenDistPips), 
                startX, y, CLR_SAND_3, FONT_SIZE);
}
```

---

## 5. GRID ZERO VISUAL ZONE

### Descrizione

Rettangolo semitrasparente che evidenzia il **"buco"** centrale tra Entry Point e la prima grid (L1). Questa zona è dove opera Grid Zero per catturare i movimenti di mean-reversion.

### Scelta Colore

Colore raccomandato: **Arancione Chiaro** (non impattante, visibile ma non invasivo)

| Opzione | Codice RGB | Note |
|---------|------------|------|
| **Arancione Chiaro** ✅ | `C'255,200,130'` | Raccomandato - si distingue senza disturbare |
| Verde Scuro | `C'60,120,80'` | Alternativa - più neutro |
| Lavanda | `C'180,160,220'` | Alternativa - delicato |

### Dimensioni Zona

```
ENTRY POINT = 1.0970
Grid L1 Upper = 1.0981 (Entry + Spacing)
Grid L1 Lower = 1.0959 (Entry - Spacing)

GRID ZERO ZONE = Da 1.0959 a 1.0981 = 22 pip (2× Spacing)
```

### Codice Implementazione

**File:** `GridZero.mqh` - Costanti

```cpp
//+------------------------------------------------------------------+
//| GRID ZERO VISUAL ZONE - Constants                                 |
//+------------------------------------------------------------------+
#define GRIDZERO_ZONE_NAME      "SUGAMARA_GRIDZERO_ZONE"
#define GRIDZERO_ZONE_COLOR     C'255,200,130'    // Arancione Chiaro
#define GRIDZERO_ZONE_STYLE     STYLE_DOT         // Bordo tratteggiato
#define GRIDZERO_ZONE_WIDTH     1                 // Spessore bordo

// Nota: MT5 non supporta trasparenza nativa per rettangoli,
// usiamo un colore chiaro che simula trasparenza su sfondo scuro
```

**File:** `GridZero.mqh` - Funzione disegno

```cpp
//+------------------------------------------------------------------+
//| Draw Grid Zero Visual Zone                                        |
//| Disegna rettangolo che evidenzia il "buco" centrale               |
//+------------------------------------------------------------------+
void DrawGridZeroVisualZone() {
    if(!Enable_GridZero) {
        RemoveGridZeroVisualZone();
        return;
    }
    
    if(entryPoint == 0) return;  // Entry non ancora impostato
    
    // Calcola i limiti della zona Grid Zero
    // La zona è lo spazio tra Entry e L1 (sopra e sotto)
    double spacingPoints = PipsToPoints(currentSpacing_Pips);
    double zoneUpperBound = entryPoint + spacingPoints;  // Dove inizia L1 Upper
    double zoneLowerBound = entryPoint - spacingPoints;  // Dove inizia L1 Lower
    
    // Tempo per estendere il rettangolo (500 barre a sinistra e destra)
    datetime timeLeft = TimeCurrent() - PeriodSeconds() * 500;
    datetime timeRight = TimeCurrent() + PeriodSeconds() * 500;
    
    // Crea rettangolo se non esiste
    if(ObjectFind(0, GRIDZERO_ZONE_NAME) < 0) {
        if(!ObjectCreate(0, GRIDZERO_ZONE_NAME, OBJ_RECTANGLE, 0, 
                         timeLeft, zoneUpperBound,
                         timeRight, zoneLowerBound)) {
            Print("[GridZero] ERROR: Failed to create visual zone");
            return;
        }
    }
    
    // Imposta proprietà del rettangolo
    ObjectSetInteger(0, GRIDZERO_ZONE_NAME, OBJPROP_COLOR, GRIDZERO_ZONE_COLOR);
    ObjectSetInteger(0, GRIDZERO_ZONE_NAME, OBJPROP_STYLE, GRIDZERO_ZONE_STYLE);
    ObjectSetInteger(0, GRIDZERO_ZONE_NAME, OBJPROP_WIDTH, GRIDZERO_ZONE_WIDTH);
    ObjectSetInteger(0, GRIDZERO_ZONE_NAME, OBJPROP_FILL, true);      // Riempimento
    ObjectSetInteger(0, GRIDZERO_ZONE_NAME, OBJPROP_BACK, true);      // Sfondo (dietro candele)
    ObjectSetInteger(0, GRIDZERO_ZONE_NAME, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, GRIDZERO_ZONE_NAME, OBJPROP_HIDDEN, true);    // Nascondi da lista oggetti
    
    // Tooltip informativo
    double zoneSizePips = (zoneUpperBound - zoneLowerBound) / PipsToPoints(1);
    ObjectSetString(0, GRIDZERO_ZONE_NAME, OBJPROP_TOOLTIP, 
                    StringFormat("Grid Zero Zone: %.1f pip\nEntry: %.5f\nUpper: %.5f\nLower: %.5f",
                                zoneSizePips, entryPoint, zoneUpperBound, zoneLowerBound));
    
    // Aggiorna coordinate (per seguire eventuali cambi di entry)
    ObjectSetDouble(0, GRIDZERO_ZONE_NAME, OBJPROP_PRICE, 0, zoneUpperBound);
    ObjectSetDouble(0, GRIDZERO_ZONE_NAME, OBJPROP_PRICE, 1, zoneLowerBound);
    ObjectSetInteger(0, GRIDZERO_ZONE_NAME, OBJPROP_TIME, 0, timeLeft);
    ObjectSetInteger(0, GRIDZERO_ZONE_NAME, OBJPROP_TIME, 1, timeRight);
}

//+------------------------------------------------------------------+
//| Remove Grid Zero Visual Zone                                      |
//+------------------------------------------------------------------+
void RemoveGridZeroVisualZone() {
    if(ObjectFind(0, GRIDZERO_ZONE_NAME) >= 0) {
        ObjectDelete(0, GRIDZERO_ZONE_NAME);
    }
}

//+------------------------------------------------------------------+
//| Update Grid Zero Visual Zone (chiamare in OnTick se necessario)   |
//+------------------------------------------------------------------+
void UpdateGridZeroVisualZone() {
    // Aggiorna solo se Grid Zero è abilitato e sistema attivo
    if(!Enable_GridZero || systemState != STATE_ACTIVE) return;
    
    // Ricalcola e ridisegna (in caso di cambio spacing o entry)
    DrawGridZeroVisualZone();
}
```

**File:** `GridZero.mqh` - Chiamate in Init/Deinit

```cpp
// In InitGridZero() - aggiungere alla fine:
DrawGridZeroVisualZone();

// In DeinitializeGridZero() - aggiungere:
RemoveGridZeroVisualZone();
```

### Utilizzo Pratico

Guardando il grafico a colpo d'occhio:

| Cosa Vedi | Significato | Azione |
|-----------|-------------|--------|
| Prezzo DENTRO zona arancione | Mean-reversion attivo | Grid Zero sta lavorando |
| Prezzo SOPRA zona arancione | Trend rialzista | Grid A Upper stanno ciclando |
| Prezzo SOTTO zona arancione | Trend ribassista | Grid A Lower stanno ciclando |
| Zona arancione ampia | Spacing elevato | Più spazio per Grid Zero |

---

## 6. GRID COUNTERS E RECYCLING DASHBOARD

### Descrizione

Nuova sezione della Dashboard che mostra in tempo reale:
- Quante grid sono pending/filled per Grid A e Grid B
- Contatore cicli completati (TP hit) per ogni grid
- **TOTAL RECYCLING**: Somma di tutti i cicli completati nella sessione

### Struttura Dati

**File:** `GlobalVariables.mqh` - Variabili già esistenti

```cpp
// Queste variabili esistono già - verificare che vengano incrementate correttamente
int g_gridA_ClosedCount = 0;    // Grid A chiuse con TP
int g_gridB_ClosedCount = 0;    // Grid B chiuse con TP
```

**File:** `GlobalVariables.mqh` - Variabili da aggiungere per dettaglio

```cpp
//+------------------------------------------------------------------+
//| GRID COUNTERS DETAILED - Per zona Upper/Lower                     |
//+------------------------------------------------------------------+
int g_gridA_Upper_CyclesTotal = 0;   // Cicli totali Grid A Upper (BUY STOP)
int g_gridA_Lower_CyclesTotal = 0;   // Cicli totali Grid A Lower (BUY LIMIT)
int g_gridB_Upper_CyclesTotal = 0;   // Cicli totali Grid B Upper (SELL LIMIT)
int g_gridB_Lower_CyclesTotal = 0;   // Cicli totali Grid B Lower (SELL STOP)
```

### Funzione Conteggio

**File:** `Dashboard.mqh` - Helper function

```cpp
//+------------------------------------------------------------------+
//| Count Grid Orders by Status                                       |
//+------------------------------------------------------------------+
int CountGridStatus(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, ENUM_ORDER_STATUS status) {
    int count = 0;
    int maxLevel = GridLevelsPerSide + 
                   (zone == GRID_UPPER ? g_trailExtraGridsAbove : g_trailExtraGridsBelow);
    if(maxLevel > MAX_GRID_LEVELS) maxLevel = MAX_GRID_LEVELS;
    
    for(int i = 0; i < maxLevel; i++) {
        ENUM_ORDER_STATUS currentStatus = ORDER_NONE;
        
        if(side == GRID_A && zone == GRID_UPPER) currentStatus = gridA_Upper_Status[i];
        else if(side == GRID_A && zone == GRID_LOWER) currentStatus = gridA_Lower_Status[i];
        else if(side == GRID_B && zone == GRID_UPPER) currentStatus = gridB_Upper_Status[i];
        else if(side == GRID_B && zone == GRID_LOWER) currentStatus = gridB_Lower_Status[i];
        
        if(currentStatus == status) count++;
    }
    
    return count;
}
```

### Sezione Dashboard

**File:** `Dashboard.mqh` - Nuova sezione

```cpp
//+------------------------------------------------------------------+
//| Draw Grid Counters Panel                                          |
//+------------------------------------------------------------------+
void DrawGridCountersPanel(int startX, int startY) {
    int y = startY;
    
    // ═══════════════════════════════════════════════════════════════
    // TITOLO SEZIONE
    // ═══════════════════════════════════════════════════════════════
    CreateLabel("COUNTERS_TITLE", "📊 GRID COUNTERS & RECYCLING", 
                startX, y, CLR_SPICE, FONT_SIZE + 1);
    y += LINE_HEIGHT + 8;
    
    // ═══════════════════════════════════════════════════════════════
    // GRID A (BUY)
    // ═══════════════════════════════════════════════════════════════
    CreateLabel("COUNTER_GRIDA_TITLE", "🔶 GRID A (BUY)", 
                startX, y, CLR_GRID_A, FONT_SIZE);
    y += LINE_HEIGHT;
    
    // Conta ordini Grid A
    int gridA_Upper_Pending = CountGridStatus(GRID_A, GRID_UPPER, ORDER_PENDING);
    int gridA_Upper_Filled = CountGridStatus(GRID_A, GRID_UPPER, ORDER_FILLED);
    int gridA_Lower_Pending = CountGridStatus(GRID_A, GRID_LOWER, ORDER_PENDING);
    int gridA_Lower_Filled = CountGridStatus(GRID_A, GRID_LOWER, ORDER_FILLED);
    
    CreateLabel("COUNTER_GRIDA_UPPER", 
                StringFormat("  Upper: %d pend / %d fill", gridA_Upper_Pending, gridA_Upper_Filled),
                startX, y, CLR_SAND_3, FONT_SIZE);
    y += LINE_HEIGHT;
    
    CreateLabel("COUNTER_GRIDA_LOWER", 
                StringFormat("  Lower: %d pend / %d fill", gridA_Lower_Pending, gridA_Lower_Filled),
                startX, y, CLR_SAND_3, FONT_SIZE);
    y += LINE_HEIGHT;
    
    // Cicli Grid A
    CreateLabel("COUNTER_GRIDA_CYCLES", 
                StringFormat("  ♻️ Cycles: %d", g_gridA_ClosedCount),
                startX, y, CLR_PROFIT, FONT_SIZE);
    y += LINE_HEIGHT + 8;
    
    // ═══════════════════════════════════════════════════════════════
    // GRID B (SELL)
    // ═══════════════════════════════════════════════════════════════
    CreateLabel("COUNTER_GRIDB_TITLE", "🔷 GRID B (SELL)", 
                startX, y, CLR_FREMEN_BLUE, FONT_SIZE);
    y += LINE_HEIGHT;
    
    // Conta ordini Grid B
    int gridB_Upper_Pending = CountGridStatus(GRID_B, GRID_UPPER, ORDER_PENDING);
    int gridB_Upper_Filled = CountGridStatus(GRID_B, GRID_UPPER, ORDER_FILLED);
    int gridB_Lower_Pending = CountGridStatus(GRID_B, GRID_LOWER, ORDER_PENDING);
    int gridB_Lower_Filled = CountGridStatus(GRID_B, GRID_LOWER, ORDER_FILLED);
    
    CreateLabel("COUNTER_GRIDB_UPPER", 
                StringFormat("  Upper: %d pend / %d fill", gridB_Upper_Pending, gridB_Upper_Filled),
                startX, y, CLR_SAND_3, FONT_SIZE);
    y += LINE_HEIGHT;
    
    CreateLabel("COUNTER_GRIDB_LOWER", 
                StringFormat("  Lower: %d pend / %d fill", gridB_Lower_Pending, gridB_Lower_Filled),
                startX, y, CLR_SAND_3, FONT_SIZE);
    y += LINE_HEIGHT;
    
    // Cicli Grid B
    CreateLabel("COUNTER_GRIDB_CYCLES", 
                StringFormat("  ♻️ Cycles: %d", g_gridB_ClosedCount),
                startX, y, CLR_PROFIT, FONT_SIZE);
    y += LINE_HEIGHT + 10;
    
    // ═══════════════════════════════════════════════════════════════
    // TOTAL RECYCLING (evidenziato)
    // ═══════════════════════════════════════════════════════════════
    int totalRecycling = g_gridA_ClosedCount + g_gridB_ClosedCount;
    
    // Sfondo evidenziato
    CreateLabel("COUNTER_TOTAL_LINE", "═════════════════════════════", 
                startX, y, CLR_BORDER, FONT_SIZE);
    y += LINE_HEIGHT;
    
    CreateLabel("COUNTER_TOTAL_TITLE", 
                StringFormat("♻️ TOTAL RECYCLING: %d", totalRecycling),
                startX, y, CLR_GOLD, FONT_SIZE + 2);
    y += LINE_HEIGHT;
    
    CreateLabel("COUNTER_TOTAL_DETAIL", 
                StringFormat("   (A:%d + B:%d)", g_gridA_ClosedCount, g_gridB_ClosedCount),
                startX, y, CLR_SAND_3, FONT_SIZE);
}
```

### Incremento Contatori

Verificare che i contatori vengano incrementati quando una grid chiude in TP.

**File:** `PositionMonitor.mqh` o `GridHelpers.mqh` - Nel punto dove si rileva la chiusura TP

```cpp
// Quando Grid A chiude in TP:
g_gridA_ClosedCount++;

// Quando Grid B chiude in TP:
g_gridB_ClosedCount++;

// Per dettaglio zona (opzionale):
if(zone == GRID_UPPER) g_gridA_Upper_CyclesTotal++;
else g_gridA_Lower_CyclesTotal++;
```

---

## 7. OTTIMIZZAZIONI PRESTAZIONI

### Analisi Codice Completata

| Componente | Stato | Note |
|------------|-------|------|
| `MAX_GRID_LEVELS = 15` | ✅ OK | Supporta 10 grid + 5 trail |
| `Trail_LogTriggerChecks` | ✅ OK | Default FALSE |
| `g_shieldHeartbeatSec = 3600` | ✅ OK | Heartbeat ogni ora |
| Recovery | ✅ OK | Solo su init |
| DetailedLogging | ⚠️ Attenzione | Impostare FALSE in produzione |

### Ottimizzazione 1: Cache per Tick

**Problema:** `CountPendingGridsAbove/Below` chiamati 4 volte per tick

**Soluzione:** Cache dei risultati per tick

**File:** `TrailingGridManager.mqh`

```cpp
//+------------------------------------------------------------------+
//| TICK CACHE - Evita ricalcoli multipli per tick                    |
//+------------------------------------------------------------------+
struct TrailTickCache {
    datetime tickTime;           // Timestamp del tick
    int pendingAbove;            // Grid pending sopra
    int pendingBelow;            // Grid pending sotto
    double currentPrice;         // Prezzo corrente
    bool isValid;                // Cache valida
};

TrailTickCache g_trailCache = {0, 0, 0, 0, false};

//+------------------------------------------------------------------+
//| Get Cached Pending Count (or recalculate if stale)                |
//+------------------------------------------------------------------+
void UpdateTrailCache() {
    datetime currentTickTime = TimeCurrent();
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Se stesso secondo, usa cache
    if(g_trailCache.tickTime == currentTickTime && g_trailCache.isValid) {
        return;  // Cache ancora valida
    }
    
    // Ricalcola
    g_trailCache.pendingAbove = CountPendingGridsAbove(currentPrice);
    g_trailCache.pendingBelow = CountPendingGridsBelow(currentPrice);
    g_trailCache.currentPrice = currentPrice;
    g_trailCache.tickTime = currentTickTime;
    g_trailCache.isValid = true;
}

//+------------------------------------------------------------------+
//| Modified ProcessTrailingGridCheck - Usa Cache                     |
//+------------------------------------------------------------------+
void ProcessTrailingGridCheck() {
    if(!Enable_TrailingGrid) return;
    if(systemState != STATE_ACTIVE) return;
    
    // Aggiorna cache (ricalcola solo se necessario)
    UpdateTrailCache();
    
    double currentPrice = g_trailCache.currentPrice;
    int pendingAbove = g_trailCache.pendingAbove;
    int pendingBelow = g_trailCache.pendingBelow;
    
    // ... resto della logica invariato, usa variabili cached
}
```

### Ottimizzazione 2: Throttle Dashboard Update

**Problema:** Dashboard aggiornata ogni tick (potenzialmente 10+ volte/secondo)

**Soluzione:** Throttle a 500ms minimo

**File:** `Dashboard.mqh`

```cpp
//+------------------------------------------------------------------+
//| DASHBOARD THROTTLE                                                |
//+------------------------------------------------------------------+
ulong g_lastDashboardUpdateMs = 0;
const ulong DASHBOARD_MIN_INTERVAL_MS = 500;  // Minimo 500ms tra update

//+------------------------------------------------------------------+
//| Update Dashboard (Throttled)                                      |
//+------------------------------------------------------------------+
void UpdateDashboard() {
    // Throttle: non aggiornare più spesso di ogni 500ms
    ulong currentMs = GetTickCount64();
    if(currentMs - g_lastDashboardUpdateMs < DASHBOARD_MIN_INTERVAL_MS) {
        return;  // Skip questo update
    }
    g_lastDashboardUpdateMs = currentMs;
    
    // ... resto della funzione UpdateDashboard() invariato
}
```

### Ottimizzazione 3: Log Default OFF in Produzione

**File:** `InputParameters.mqh` - Cambiare default

```cpp
// PRIMA (debug)
input bool DetailedLogging = true;
input bool Trail_DetailedLogging = true;

// DOPO (produzione)
input bool DetailedLogging = false;           // 📝 Log Dettagliato (OFF per produzione)
input bool Trail_DetailedLogging = false;     // 📝 Log Trail (OFF per produzione)
```

### Ottimizzazione 4: Skip Funzioni Non Necessarie

**File:** `Sugamara.mq5` - In OnTick()

```cpp
void OnTick() {
    // ... codice esistente ...
    
    // Ottimizzazione: Skip ATR Multi-TF se non visibile
    if(Enable_ATRMultiTF && IsDashboardVisible()) {
        UpdateATRMultiTF();
    }
    
    // Ottimizzazione: Skip Sweet Spot se non visibile
    if(IsDashboardVisible()) {
        UpdateSweetSpotIndicator();
    }
    
    // ... resto codice ...
}

// Helper function
bool IsDashboardVisible() {
    // Verifica se la dashboard è visibile (finestra in primo piano)
    return (ChartGetInteger(0, CHART_BRING_TO_TOP) == 1);
}
```

### Riepilogo Impatto Prestazioni

| Ottimizzazione | Impatto CPU | Difficoltà | Priorità |
|----------------|-------------|------------|----------|
| Cache per Tick | -30% chiamate | ⭐⭐ Media | Alta |
| Throttle Dashboard | -80% update | ⭐ Facile | Alta |
| Log OFF default | -10% I/O | ⭐ Facile | Media |
| Skip non visibili | -5% CPU | ⭐⭐ Media | Bassa |

---

## 8. RIEPILOGO MODIFICHE DA IMPLEMENTARE

### Priorità ALTA ⚡

| # | Modifica | File | Stima Tempo |
|---|----------|------|-------------|
| 1 | Cambiare default `GridLevelsPerSide = 10` | InputParameters.mqh | 5 min |
| 2 | Grid Zero Visual Zone (arancione chiaro) | GridZero.mqh | 30 min |
| 3 | Grid Counters sulla Dashboard | Dashboard.mqh | 45 min |

### Priorità MEDIA ⚙️

| # | Modifica | File | Stima Tempo |
|---|----------|------|-------------|
| 4 | Sweet Spot Indicator | Dashboard.mqh + GlobalVariables.mqh | 1 ora |
| 5 | Cache per Tick | TrailingGridManager.mqh | 30 min |
| 6 | Throttle Dashboard | Dashboard.mqh | 15 min |

### Priorità BASSA 🔧

| # | Modifica | File | Stima Tempo |
|---|----------|------|-------------|
| 7 | Log default OFF | InputParameters.mqh | 5 min |
| 8 | Skip funzioni non visibili | Sugamara.mq5 | 20 min |

---

## CHECKLIST IMPLEMENTAZIONE

```
□ 1. Aprire InputParameters.mqh
    □ Cambiare GridLevelsPerSide = 10
    □ Cambiare DetailedLogging = false (opzionale)
    □ Compilare e verificare

□ 2. Aprire GridZero.mqh
    □ Aggiungere costanti GRIDZERO_ZONE_*
    □ Aggiungere DrawGridZeroVisualZone()
    □ Aggiungere RemoveGridZeroVisualZone()
    □ Chiamare in InitGridZero() e DeinitializeGridZero()
    □ Compilare e verificare visuale

□ 3. Aprire GlobalVariables.mqh
    □ Aggiungere struct SweetSpotData
    □ Aggiungere variabili cicli per zona (opzionale)
    □ Compilare

□ 4. Aprire Dashboard.mqh
    □ Aggiungere CountGridStatus() helper
    □ Aggiungere DrawGridCountersPanel()
    □ Aggiungere UpdateSweetSpotIndicator()
    □ Aggiungere DrawSweetSpotPanel()
    □ Chiamare nuove funzioni in UpdateDashboard()
    □ Compilare e verificare Dashboard

□ 5. Test Finale
    □ Avviare EA su EUR/USD con 10 grid
    □ Verificare Grid Zero Zone visibile
    □ Verificare contatori sulla Dashboard
    □ Verificare Sweet Spot Indicator
    □ Test performance (nessun lag)
```

---

**Fine Documento**

*Documento di riferimento per implementazione con Claude Code*
*Versione: 1.0 - 5 Gennaio 2026*
