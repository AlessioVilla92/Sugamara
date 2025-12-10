# 🎯 SUGAMARA - PIANO IMPLEMENTAZIONE COMPLETO

## Sistema Grid Neutral Avanzato con ATR Dinamico e Auto-Recenter

**Versione:** 4.0  
**Data:** Dicembre 2024  
**Basato su:** Analisi completa sistema SUGAMARA esistente  
**Target:** EUR/USD, AUD/NZD, coppie range-bound

---

# INDICE

1. [Executive Summary](#1-executive-summary)
2. [Architettura Generale](#2-architettura-generale)
3. [FASE 1: ATR Dynamic Spacing](#3-fase-1-atr-dynamic-spacing)
4. [FASE 2: Cyclic Reopen Ottimizzato](#4-fase-2-cyclic-reopen-ottimizzato)
5. [FASE 3: Sistema Indicatori Centro](#5-fase-3-sistema-indicatori-centro)
6. [FASE 4: Auto-Recenter Logic](#6-fase-4-auto-recenter-logic)
7. [FASE 5: Integrazione e Testing](#7-fase-5-integrazione-e-testing)
8. [Parametri Completi](#8-parametri-completi)
9. [Checklist Implementazione](#9-checklist-implementazione)

---

# 1. EXECUTIVE SUMMARY

## 1.1 Obiettivi

Implementare 5 miglioramenti chiave per SUGAMARA:

| # | Funzionalità | Impatto Atteso |
|---|--------------|----------------|
| 1 | ATR Dynamic Spacing | +30-50% profitti |
| 2 | Cyclic Reopen Ottimizzato | +200-400% profitti |
| 3 | Sistema 3 Indicatori Centro | Ricentramento preciso |
| 4 | Auto-Recenter Logic | Grid sempre ottimale |
| 5 | Integrazione Completa | Sistema sinergico |

## 1.2 Indicatori Scelti per Centro

| Rank | Indicatore | Peso | Funzione |
|------|------------|------|----------|
| 🥇 | Pivot Point Daily | 40% | Ancora stabile istituzionale |
| 🥈 | EMA 50 (M15) | 30% | Smoothing e direzione trend |
| 🥉 | Donchian Center (20) | 30% | Range reale del mercato |

**Formula Centro Ottimale:**
```
CENTRO = (Pivot × 0.40) + (EMA50 × 0.30) + (DonchianCenter × 0.30)
```

## 1.3 Timeline

| Settimana | Fase | Deliverable |
|-----------|------|-------------|
| 1 | ATR Dynamic Spacing | `DynamicATRAdapter.mqh` |
| 2 | Cyclic Reopen | Modifiche `GridHelpers.mqh` |
| 3 | Sistema Indicatori | `CenterCalculator.mqh` |
| 4 | Auto-Recenter | `GridRecenterManager.mqh` |
| 5 | Test e Ottimizzazione | Sistema completo validato |

---

# 2. ARCHITETTURA GENERALE

## 2.1 Nuovi File da Creare

```
/Experts/Sugamara/
│
├── Sugamara.mq5                          # File principale (modificare)
│
├── Config/
│   ├── Enums.mqh                         # AGGIUNGERE nuove enum
│   └── InputParameters.mqh               # AGGIUNGERE nuovi parametri
│
├── Utils/
│   ├── ATRCalculator.mqh                 # MODIFICARE per step discreti
│   └── DynamicATRAdapter.mqh             # NUOVO - Logica adattamento
│
├── Trading/
│   ├── GridHelpers.mqh                   # MODIFICARE per reopen avanzato
│   └── GridRecenterManager.mqh           # NUOVO - Logica ricentramento
│
└── Indicators/
    └── CenterCalculator.mqh              # NUOVO - Calcolo centro ottimale
```

## 2.2 Flusso di Esecuzione

```
┌─────────────────────────────────────────────────────────────────────┐
│                         OnTick() / OnTimer()                        │
├─────────────────────────────────────────────────────────────────────┤
│                                                                     │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐ │
│  │  ATR ADAPTER    │    │ CENTER CALC     │    │ RECENTER CHECK  │ │
│  │  (ogni 5 min)   │───▶│ (ogni 5 min)    │───▶│ (ogni 5 min)    │ │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘ │
│          │                      │                      │            │
│          ▼                      ▼                      ▼            │
│  ┌─────────────────┐    ┌─────────────────┐    ┌─────────────────┐ │
│  │ Nuovo Spacing?  │    │ Centro Calcolato│    │ Condizioni OK?  │ │
│  │ Adatta Pending  │    │ Pivot+EMA+DC    │    │ Esegui Reset    │ │
│  └─────────────────┘    └─────────────────┘    └─────────────────┘ │
│                                                                     │
│  ┌─────────────────────────────────────────────────────────────┐   │
│  │                    CYCLIC REOPEN (ogni tick)                 │   │
│  │   Per ogni livello chiuso: verifica condizioni → riapri      │   │
│  └─────────────────────────────────────────────────────────────┘   │
│                                                                     │
└─────────────────────────────────────────────────────────────────────┘
```

---

# 3. FASE 1: ATR DYNAMIC SPACING

## 3.1 Obiettivo

Adattare automaticamente lo spacing della griglia in base alla volatilità ATR, usando 5 step discreti per evitare micro-variazioni continue.

## 3.2 Enumerazioni da Aggiungere

**File:** `Config/Enums.mqh`

```cpp
//+------------------------------------------------------------------+
//| ATR STEP ENUMERATION                                             |
//+------------------------------------------------------------------+
enum ENUM_ATR_STEP {
    ATR_STEP_VERY_LOW = 0,    // ATR < 10 pips
    ATR_STEP_LOW = 1,         // ATR 10-15 pips
    ATR_STEP_NORMAL = 2,      // ATR 15-25 pips
    ATR_STEP_HIGH = 3,        // ATR 25-35 pips
    ATR_STEP_EXTREME = 4      // ATR > 35 pips
};
```

## 3.3 Parametri da Aggiungere

**File:** `Config/InputParameters.mqh`

```cpp
//+------------------------------------------------------------------+
//| 🔄 ATR DYNAMIC SPACING SETTINGS                                  |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔄 ATR DYNAMIC SPACING                                    ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⚙️ ATTIVAZIONE"
input bool      EnableDynamicATRSpacing = true;         // ✅ Abilita Spacing Dinamico ATR
// Se FALSE: usa Fixed_Spacing_Pips come attualmente

input group "    ⏱️ TIMING"
input int       ATR_CheckInterval_Seconds = 300;        // ⏱️ Intervallo Check ATR (secondi)
// Consigliato: 300 = 5 minuti
input int       ATR_MinTimeBetweenChanges = 900;        // ⏱️ Min tempo tra cambi (secondi)
// Consigliato: 900 = 15 minuti
input double    ATR_StepChangeThreshold = 15.0;         // 📊 Soglia cambio step (%)
// Cambia spacing solo se ATR varia > 15%

input group "    📏 SPACING PER STEP"
input double    Spacing_VeryLow_Pips = 8.0;             // 📏 Spacing ATR VERY_LOW (< 10 pips)
input double    Spacing_Low_Pips = 12.0;                // 📏 Spacing ATR LOW (10-15 pips)
input double    Spacing_Normal_Pips = 16.0;             // 📏 Spacing ATR NORMAL (15-25 pips)
input double    Spacing_High_Pips = 22.0;               // 📏 Spacing ATR HIGH (25-35 pips)
input double    Spacing_Extreme_Pips = 30.0;            // 📏 Spacing ATR EXTREME (> 35 pips)

input group "    🔒 LIMITI"
input double    DynamicSpacing_Min_Pips = 8.0;          // 🔒 Spacing Minimo Assoluto
input double    DynamicSpacing_Max_Pips = 40.0;         // 🔒 Spacing Massimo Assoluto
```

## 3.4 Variabili Globali da Aggiungere

**File:** `Core/GlobalVariables.mqh`

```cpp
//+------------------------------------------------------------------+
//| ATR DYNAMIC SPACING GLOBALS                                      |
//+------------------------------------------------------------------+

// Stato corrente ATR
ENUM_ATR_STEP       currentATRStep = ATR_STEP_NORMAL;
ENUM_ATR_STEP       lastATRStep = ATR_STEP_NORMAL;
double              lastATRValue_Dynamic = 0;
datetime            lastATRCheck_Dynamic = 0;
datetime            lastSpacingChange = 0;

// Spacing tracking
double              previousSpacing_Pips = 0;
bool                spacingChangeInProgress = false;
```

## 3.5 Nuovo File: DynamicATRAdapter.mqh

**File:** `Utils/DynamicATRAdapter.mqh`

```cpp
//+------------------------------------------------------------------+
//|                                           DynamicATRAdapter.mqh  |
//|                        Sugamara v4.0 - Dynamic ATR Adapter       |
//|                                                                  |
//|  Adatta lo spacing della griglia in base alla volatilità ATR     |
//|  usando 5 step discreti per stabilità                            |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| INIZIALIZZAZIONE                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Inizializza il sistema ATR Dynamic                               |
//+------------------------------------------------------------------+
bool InitializeDynamicATRAdapter() {
    if(!EnableDynamicATRSpacing) {
        Print("[ATR-Dynamic] Sistema DISABILITATO - uso spacing fisso");
        return true;
    }
    
    // Calcola step iniziale
    double atrPips = GetATRPips();
    currentATRStep = CalculateATRStep(atrPips);
    lastATRStep = currentATRStep;
    lastATRValue_Dynamic = atrPips;
    lastATRCheck_Dynamic = TimeCurrent();
    lastSpacingChange = TimeCurrent();
    
    Print("[ATR-Dynamic] Inizializzato:");
    Print("  ATR Corrente: ", DoubleToString(atrPips, 1), " pips");
    Print("  Step: ", GetATRStepName(currentATRStep));
    Print("  Spacing: ", DoubleToString(GetSpacingForATRStep(currentATRStep), 1), " pips");
    
    return true;
}

//+------------------------------------------------------------------+
//| CALCOLO ATR STEP                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Determina lo step ATR in base al valore                          |
//+------------------------------------------------------------------+
ENUM_ATR_STEP CalculateATRStep(double atrPips) {
    if(atrPips < 10.0)       return ATR_STEP_VERY_LOW;
    else if(atrPips < 15.0)  return ATR_STEP_LOW;
    else if(atrPips < 25.0)  return ATR_STEP_NORMAL;
    else if(atrPips < 35.0)  return ATR_STEP_HIGH;
    else                     return ATR_STEP_EXTREME;
}

//+------------------------------------------------------------------+
//| Ottieni nome step ATR                                            |
//+------------------------------------------------------------------+
string GetATRStepName(ENUM_ATR_STEP step) {
    switch(step) {
        case ATR_STEP_VERY_LOW: return "VERY_LOW (<10)";
        case ATR_STEP_LOW:      return "LOW (10-15)";
        case ATR_STEP_NORMAL:   return "NORMAL (15-25)";
        case ATR_STEP_HIGH:     return "HIGH (25-35)";
        case ATR_STEP_EXTREME:  return "EXTREME (>35)";
        default:                return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Ottieni spacing per step ATR                                     |
//+------------------------------------------------------------------+
double GetSpacingForATRStep(ENUM_ATR_STEP step) {
    double spacing = 0;
    
    switch(step) {
        case ATR_STEP_VERY_LOW: spacing = Spacing_VeryLow_Pips;  break;
        case ATR_STEP_LOW:      spacing = Spacing_Low_Pips;      break;
        case ATR_STEP_NORMAL:   spacing = Spacing_Normal_Pips;   break;
        case ATR_STEP_HIGH:     spacing = Spacing_High_Pips;     break;
        case ATR_STEP_EXTREME:  spacing = Spacing_Extreme_Pips;  break;
        default:                spacing = Spacing_Normal_Pips;   break;
    }
    
    // Applica limiti
    spacing = MathMax(spacing, DynamicSpacing_Min_Pips);
    spacing = MathMin(spacing, DynamicSpacing_Max_Pips);
    
    return spacing;
}

//+------------------------------------------------------------------+
//| CHECK E ADATTAMENTO                                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funzione principale: controlla ATR e adatta se necessario        |
//| Chiamare da OnTimer() ogni ATR_CheckInterval_Seconds             |
//+------------------------------------------------------------------+
void CheckAndAdaptATRSpacing() {
    if(!EnableDynamicATRSpacing) return;
    
    // Verifica intervallo minimo tra check
    datetime now = TimeCurrent();
    if(now - lastATRCheck_Dynamic < ATR_CheckInterval_Seconds) return;
    
    lastATRCheck_Dynamic = now;
    
    // Leggi ATR corrente
    double currentATR = GetATRPips();
    
    // Calcola step corrente
    ENUM_ATR_STEP newStep = CalculateATRStep(currentATR);
    
    // Verifica se lo step è cambiato
    if(newStep == currentATRStep) {
        // Step invariato, nessuna azione
        return;
    }
    
    // Verifica cambio percentuale ATR (soglia di sicurezza)
    double changePercent = 0;
    if(lastATRValue_Dynamic > 0) {
        changePercent = MathAbs((currentATR - lastATRValue_Dynamic) / lastATRValue_Dynamic) * 100;
    }
    
    if(changePercent < ATR_StepChangeThreshold) {
        // Cambio troppo piccolo, ignora
        return;
    }
    
    // Verifica tempo minimo dall'ultimo cambio
    if(now - lastSpacingChange < ATR_MinTimeBetweenChanges) {
        // Troppo presto per un altro cambio
        if(DetailedLogging) {
            Print("[ATR-Dynamic] Cambio step rilevato ma troppo presto per applicare");
        }
        return;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // ESEGUI ADATTAMENTO SPACING
    // ═══════════════════════════════════════════════════════════════
    
    LogMessage(LOG_INFO, "═══════════════════════════════════════════════");
    LogMessage(LOG_INFO, "ATR DYNAMIC: SPACING ADAPTATION TRIGGERED");
    LogMessage(LOG_INFO, "═══════════════════════════════════════════════");
    
    // Salva stato precedente
    ENUM_ATR_STEP oldStep = currentATRStep;
    double oldSpacing = currentSpacing_Pips;
    
    // Aggiorna stato
    currentATRStep = newStep;
    lastATRStep = oldStep;
    lastATRValue_Dynamic = currentATR;
    lastSpacingChange = now;
    
    // Calcola nuovo spacing
    double newSpacing = GetSpacingForATRStep(newStep);
    
    // Log cambio
    Print("[ATR-Dynamic] Step: ", GetATRStepName(oldStep), " → ", GetATRStepName(newStep));
    Print("[ATR-Dynamic] ATR: ", DoubleToString(lastATRValue_Dynamic, 1), " → ", 
          DoubleToString(currentATR, 1), " pips (", DoubleToString(changePercent, 1), "%)");
    Print("[ATR-Dynamic] Spacing: ", DoubleToString(oldSpacing, 1), " → ", 
          DoubleToString(newSpacing, 1), " pips");
    
    // Esegui adattamento griglia
    AdaptGridToNewSpacing(newSpacing);
}

//+------------------------------------------------------------------+
//| Adatta la griglia al nuovo spacing                               |
//| REGOLA FONDAMENTALE: NON TOCCARE MAI ordini FILLED!              |
//+------------------------------------------------------------------+
void AdaptGridToNewSpacing(double newSpacing) {
    spacingChangeInProgress = true;
    previousSpacing_Pips = currentSpacing_Pips;
    
    Print("[ATR-Dynamic] Inizio adattamento griglia...");
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 1: Identifica ordini FILLED (DA NON TOCCARE!)
    // ═══════════════════════════════════════════════════════════════
    
    int filledGridA_Upper = 0, filledGridA_Lower = 0;
    int filledGridB_Upper = 0, filledGridB_Lower = 0;
    double lastFilledPriceA = 0, lastFilledPriceB = 0;
    
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Status[i] == ORDER_FILLED) {
            filledGridA_Upper++;
            if(gridA_Upper_EntryPrices[i] > lastFilledPriceA)
                lastFilledPriceA = gridA_Upper_EntryPrices[i];
        }
        if(gridA_Lower_Status[i] == ORDER_FILLED) {
            filledGridA_Lower++;
            if(lastFilledPriceA == 0 || gridA_Lower_EntryPrices[i] < lastFilledPriceA)
                lastFilledPriceA = gridA_Lower_EntryPrices[i];
        }
        if(gridB_Upper_Status[i] == ORDER_FILLED) {
            filledGridB_Upper++;
            if(gridB_Upper_EntryPrices[i] > lastFilledPriceB)
                lastFilledPriceB = gridB_Upper_EntryPrices[i];
        }
        if(gridB_Lower_Status[i] == ORDER_FILLED) {
            filledGridB_Lower++;
            if(lastFilledPriceB == 0 || gridB_Lower_EntryPrices[i] < lastFilledPriceB)
                lastFilledPriceB = gridB_Lower_EntryPrices[i];
        }
    }
    
    int totalFilled = filledGridA_Upper + filledGridA_Lower + filledGridB_Upper + filledGridB_Lower;
    Print("[ATR-Dynamic] Ordini FILLED (non toccati): ", totalFilled);
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 2: Cancella SOLO ordini PENDING
    // ═══════════════════════════════════════════════════════════════
    
    int cancelledCount = 0;
    
    // Grid A
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Status[i] == ORDER_PENDING) {
            if(DeletePendingOrder(gridA_Upper_Tickets[i])) {
                gridA_Upper_Status[i] = ORDER_NONE;
                gridA_Upper_Tickets[i] = 0;
                cancelledCount++;
            }
        }
        if(gridA_Lower_Status[i] == ORDER_PENDING) {
            if(DeletePendingOrder(gridA_Lower_Tickets[i])) {
                gridA_Lower_Status[i] = ORDER_NONE;
                gridA_Lower_Tickets[i] = 0;
                cancelledCount++;
            }
        }
    }
    
    // Grid B
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Status[i] == ORDER_PENDING) {
            if(DeletePendingOrder(gridB_Upper_Tickets[i])) {
                gridB_Upper_Status[i] = ORDER_NONE;
                gridB_Upper_Tickets[i] = 0;
                cancelledCount++;
            }
        }
        if(gridB_Lower_Status[i] == ORDER_PENDING) {
            if(DeletePendingOrder(gridB_Lower_Tickets[i])) {
                gridB_Lower_Status[i] = ORDER_NONE;
                gridB_Lower_Tickets[i] = 0;
                cancelledCount++;
            }
        }
    }
    
    Print("[ATR-Dynamic] Ordini PENDING cancellati: ", cancelledCount);
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 3: Aggiorna spacing globale
    // ═══════════════════════════════════════════════════════════════
    
    currentSpacing_Pips = newSpacing;
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 4: Ricalcola livelli griglia con nuovo spacing
    // ═══════════════════════════════════════════════════════════════
    
    // Ricalcola prezzi entry per ordini NON filled
    for(int i = 0; i < GridLevelsPerSide; i++) {
        // Grid A Upper
        if(gridA_Upper_Status[i] != ORDER_FILLED) {
            gridA_Upper_EntryPrices[i] = CalculateGridLevelPrice(entryPoint, ZONE_UPPER, i, newSpacing);
            gridA_Upper_TP[i] = CalculateCascadeTP(entryPoint, GRID_A, ZONE_UPPER, i, newSpacing, GridLevelsPerSide);
        }
        
        // Grid A Lower
        if(gridA_Lower_Status[i] != ORDER_FILLED) {
            gridA_Lower_EntryPrices[i] = CalculateGridLevelPrice(entryPoint, ZONE_LOWER, i, newSpacing);
            gridA_Lower_TP[i] = CalculateCascadeTP(entryPoint, GRID_A, ZONE_LOWER, i, newSpacing, GridLevelsPerSide);
        }
        
        // Grid B Upper
        if(gridB_Upper_Status[i] != ORDER_FILLED) {
            gridB_Upper_EntryPrices[i] = CalculateGridLevelPrice(entryPoint, ZONE_UPPER, i, newSpacing);
            gridB_Upper_TP[i] = CalculateCascadeTP(entryPoint, GRID_B, ZONE_UPPER, i, newSpacing, GridLevelsPerSide);
        }
        
        // Grid B Lower
        if(gridB_Lower_Status[i] != ORDER_FILLED) {
            gridB_Lower_EntryPrices[i] = CalculateGridLevelPrice(entryPoint, ZONE_LOWER, i, newSpacing);
            gridB_Lower_TP[i] = CalculateCascadeTP(entryPoint, GRID_B, ZONE_LOWER, i, newSpacing, GridLevelsPerSide);
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 5: Piazza nuovi ordini PENDING
    // ═══════════════════════════════════════════════════════════════
    
    int placedCount = 0;
    
    for(int i = 0; i < GridLevelsPerSide; i++) {
        // Grid A Upper
        if(gridA_Upper_Status[i] == ORDER_NONE) {
            if(PlaceGridAUpperOrder(i)) placedCount++;
        }
        
        // Grid A Lower
        if(gridA_Lower_Status[i] == ORDER_NONE) {
            if(PlaceGridALowerOrder(i)) placedCount++;
        }
        
        // Grid B Upper
        if(gridB_Upper_Status[i] == ORDER_NONE) {
            if(PlaceGridBUpperOrder(i)) placedCount++;
        }
        
        // Grid B Lower
        if(gridB_Lower_Status[i] == ORDER_NONE) {
            if(PlaceGridBLowerOrder(i)) placedCount++;
        }
    }
    
    Print("[ATR-Dynamic] Nuovi ordini PENDING piazzati: ", placedCount);
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 6: Sincronizza RangeBox con nuovi livelli
    // ═══════════════════════════════════════════════════════════════
    
    if(IsRangeBoxAvailable()) {
        SyncRangeBoxWithGrid();
        CalculateBreakoutLevels();
        Print("[ATR-Dynamic] RangeBox sincronizzato con nuovi livelli");
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 7: Aggiorna visualizzazione
    // ═══════════════════════════════════════════════════════════════
    
    if(ShowGridLines) {
        DeleteAllGridObjects();
        DrawAllGridLines();
    }
    
    spacingChangeInProgress = false;
    
    Print("[ATR-Dynamic] Adattamento completato con successo");
    Print("═══════════════════════════════════════════════════════════");
    
    // Alert se abilitato
    if(EnableAlerts) {
        Alert("SUGAMARA: Spacing adattato a ", DoubleToString(newSpacing, 1), 
              " pips (ATR Step: ", GetATRStepName(currentATRStep), ")");
    }
}

//+------------------------------------------------------------------+
//| UTILITÀ                                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Ottieni spacing corrente (dinamico o fisso)                      |
//+------------------------------------------------------------------+
double GetDynamicSpacing() {
    if(!EnableDynamicATRSpacing) {
        return Fixed_Spacing_Pips;
    }
    return GetSpacingForATRStep(currentATRStep);
}

//+------------------------------------------------------------------+
//| Report stato ATR Dynamic                                         |
//+------------------------------------------------------------------+
void LogATRDynamicReport() {
    Print("═══════════════════════════════════════════════════════════");
    Print("  ATR DYNAMIC SPACING REPORT");
    Print("═══════════════════════════════════════════════════════════");
    Print("  Enabled: ", EnableDynamicATRSpacing ? "YES" : "NO");
    Print("  Current ATR: ", DoubleToString(GetATRPips(), 1), " pips");
    Print("  Current Step: ", GetATRStepName(currentATRStep));
    Print("  Current Spacing: ", DoubleToString(currentSpacing_Pips, 1), " pips");
    Print("  Last Change: ", TimeToString(lastSpacingChange));
    Print("═══════════════════════════════════════════════════════════");
}
```

## 3.6 Modifiche a Sugamara.mq5

### In OnInit():

```cpp
// Dopo InitializeATR...

//--- STEP 7.5: Initialize Dynamic ATR Adapter ---
if(EnableDynamicATRSpacing) {
    if(!InitializeDynamicATRAdapter()) {
        Print("WARNING: Failed to initialize Dynamic ATR Adapter");
    }
}

// Setup Timer per ATR check
EventSetTimer(ATR_CheckInterval_Seconds);
```

### In OnTimer():

```cpp
void OnTimer() {
    // ATR Dynamic Spacing Check
    if(EnableDynamicATRSpacing) {
        CheckAndAdaptATRSpacing();
    }
    
    // Center e Recenter Check (Fase 3-4)
    if(EnableAutoRecenter) {
        CheckAndRecenterGrid();
    }
}
```

---

# 4. FASE 2: CYCLIC REOPEN OTTIMIZZATO

## 4.1 Obiettivo

Ottimizzare il sistema di riapertura ciclica degli ordini chiusi, mantenendo la semplicità del "stesso punto" ma con condizioni di sicurezza migliorate.

## 4.2 Parametri da Aggiungere/Modificare

**File:** `Config/InputParameters.mqh`

```cpp
//+------------------------------------------------------------------+
//| 🔄 CYCLIC REOPEN ENHANCED SETTINGS                               |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔄 CYCLIC REOPEN SETTINGS                                 ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⚙️ ATTIVAZIONE"
input bool      EnableCyclicReopen = true;              // ✅ Abilita Cyclic Reopen

input group "    ╔═ SELEZIONA MODALITÀ REOPEN ══════════════════════════🔽🔽🔽"
input ENUM_REOPEN_MODE ReopenMode = REOPEN_SAME_POINT;  // 📍 Modalità Reopen ▼
// REOPEN_SAME_POINT: Riapre esattamente nello stesso punto originale
// REOPEN_ATR_DRIVEN: Riapre nel punto calcolato da ATR corrente
// REOPEN_HYBRID:     Stesso punto se vicino, ATR se lontano (>50% spacing)

input group "    ⏱️ TIMING E LIMITI"
input int       CyclicCooldown_Seconds = 60;            // ⏱️ Cooldown tra cicli (secondi)
input int       MaxCyclesPerLevel = 0;                  // 🔢 Max cicli per livello (0=illimitato)
input int       MaxCyclesPerSession = 0;                // 🔢 Max cicli per sessione (0=illimitato)

input group "    📏 TRIGGER"
input ENUM_REOPEN_TRIGGER ReopenTrigger = REOPEN_PRICE_LEVEL; // 📍 Trigger Reopen ▼
// REOPEN_IMMEDIATE:    Riapre subito dopo cooldown
// REOPEN_PRICE_LEVEL:  Riapre quando prezzo torna vicino al livello
input double    ReopenOffset_Pips = 5.0;                // 📏 Offset trigger (pips)

input group "    🛡️ SICUREZZA"
input bool      PauseReopenOnTrend = true;              // 🛡️ Pausa reopen se trend forte
input double    TrendADX_Threshold = 30.0;              // 📊 Soglia ADX per trend (>30 = trend)
input bool      PauseReopenNearShield = true;           // 🛡️ Pausa reopen vicino a Shield
input double    ShieldProximity_Pips = 20.0;            // 📏 Distanza minima da Shield (pips)
```

## 4.3 Enum da Aggiungere

**File:** `Config/Enums.mqh`

```cpp
//+------------------------------------------------------------------+
//| REOPEN MODE ENUMERATION                                          |
//+------------------------------------------------------------------+
enum ENUM_REOPEN_MODE {
    REOPEN_SAME_POINT,    // Stesso punto originale
    REOPEN_ATR_DRIVEN,    // Punto calcolato da ATR
    REOPEN_HYBRID         // Ibrido
};

enum ENUM_REOPEN_TRIGGER {
    REOPEN_IMMEDIATE,     // Riapre subito dopo cooldown
    REOPEN_PRICE_LEVEL    // Riapre quando prezzo vicino
};
```

## 4.4 Modifiche a GridHelpers.mqh

### Funzione CanLevelReopen Migliorata:

```cpp
//+------------------------------------------------------------------+
//| Check if Level Can Reopen (ENHANCED)                             |
//+------------------------------------------------------------------+
bool CanLevelReopen(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(!EnableCyclicReopen) return false;
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 1: Cooldown temporale
    // ═══════════════════════════════════════════════════════════════
    datetime lastClose = GetLastCloseTime(side, zone, level);
    if(lastClose > 0) {
        int elapsed = SecondsElapsed(lastClose);
        if(elapsed < CyclicCooldown_Seconds) {
            return false;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 2: Max cicli per livello
    // ═══════════════════════════════════════════════════════════════
    if(MaxCyclesPerLevel > 0) {
        int cycles = GetCycleCount(side, zone, level);
        if(cycles >= MaxCyclesPerLevel) {
            return false;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 3: Pausa se trend forte (ADX)
    // ═══════════════════════════════════════════════════════════════
    if(PauseReopenOnTrend) {
        double adx = GetADXValue();
        if(adx > TrendADX_Threshold) {
            if(DetailedLogging) {
                Print("[Reopen] Paused - Strong trend detected (ADX=", 
                      DoubleToString(adx, 1), ")");
            }
            return false;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 4: Pausa se vicino a Shield
    // ═══════════════════════════════════════════════════════════════
    if(PauseReopenNearShield && IsRangeBoxAvailable()) {
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double distanceToUpperShield = MathAbs(upperBreakoutLevel - currentPrice);
        double distanceToLowerShield = MathAbs(currentPrice - lowerBreakoutLevel);
        double minDistance = MathMin(distanceToUpperShield, distanceToLowerShield);
        
        if(PointsToPips(minDistance) < ShieldProximity_Pips) {
            if(DetailedLogging) {
                Print("[Reopen] Paused - Too close to Shield (", 
                      DoubleToString(PointsToPips(minDistance), 1), " pips)");
            }
            return false;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 5: Volatilità estrema
    // ═══════════════════════════════════════════════════════════════
    if(EnableDynamicATRSpacing && currentATRStep == ATR_STEP_EXTREME) {
        if(DetailedLogging) {
            Print("[Reopen] Paused - Extreme volatility");
        }
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Calcola prezzo di reopen in base alla modalità                   |
//+------------------------------------------------------------------+
double CalculateReopenPrice(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    double originalPrice = GetOriginalEntryPrice(side, zone, level);
    
    switch(ReopenMode) {
        case REOPEN_SAME_POINT:
            // Riapre esattamente nello stesso punto
            return originalPrice;
            
        case REOPEN_ATR_DRIVEN:
            // Riapre nel punto calcolato con spacing ATR corrente
            return CalculateGridLevelPrice(entryPoint, zone, level, currentSpacing_Pips);
            
        case REOPEN_HYBRID:
            // Ibrido: stesso punto se vicino, ATR se lontano
            double atrPrice = CalculateGridLevelPrice(entryPoint, zone, level, currentSpacing_Pips);
            double distance = MathAbs(originalPrice - atrPrice);
            double threshold = PipsToPoints(currentSpacing_Pips * 0.5);
            
            if(distance > threshold) {
                // Troppo lontano, usa ATR
                return atrPrice;
            } else {
                // Vicino, usa originale
                return originalPrice;
            }
            
        default:
            return originalPrice;
    }
}
```

---

# 5. FASE 3: SISTEMA INDICATORI CENTRO

## 5.1 Obiettivo

Creare un sistema di calcolo del "centro ottimale" usando 3 indicatori complementari: Pivot Point Daily, EMA 50, e Donchian Channel Center.

## 5.2 Parametri da Aggiungere

**File:** `Config/InputParameters.mqh`

```cpp
//+------------------------------------------------------------------+
//| 🎯 CENTER INDICATOR SETTINGS                                     |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎯 CENTER INDICATOR SYSTEM                                ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📊 INDICATORI ATTIVI"
input bool      UsePivotPoint = true;                   // ✅ Usa Pivot Point Daily
input bool      UseEMA50 = true;                        // ✅ Usa EMA 50
input bool      UseDonchianCenter = true;               // ✅ Usa Donchian Channel Center

input group "    ⚖️ PESI INDICATORI"
input double    Weight_PivotPoint = 40.0;               // ⚖️ Peso Pivot Point (%)
input double    Weight_EMA50 = 30.0;                    // ⚖️ Peso EMA 50 (%)
input double    Weight_Donchian = 30.0;                 // ⚖️ Peso Donchian Center (%)
// NOTA: I pesi vengono normalizzati automaticamente a 100%

input group "    ⚙️ PARAMETRI INDICATORI"
input int       EMA_Period = 50;                        // 📊 Periodo EMA
input ENUM_TIMEFRAMES EMA_Timeframe = PERIOD_M15;       // 📊 Timeframe EMA
input int       Donchian_Period = 20;                   // 📊 Periodo Donchian Channel
input ENUM_TIMEFRAMES Donchian_Timeframe = PERIOD_M15;  // 📊 Timeframe Donchian
input ENUM_TIMEFRAMES Pivot_Timeframe = PERIOD_D1;      // 📊 Timeframe Pivot (D1 consigliato)
```

## 5.3 Nuovo File: CenterCalculator.mqh

**File:** `Indicators/CenterCalculator.mqh`

```cpp
//+------------------------------------------------------------------+
//|                                            CenterCalculator.mqh  |
//|                        Sugamara v4.0 - Center Calculator         |
//|                                                                  |
//|  Calcola il centro ottimale usando:                              |
//|  - Pivot Point Daily (40%)                                       |
//|  - EMA 50 (30%)                                                  |
//|  - Donchian Channel Center (30%)                                 |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| STRUTTURE                                                        |
//+------------------------------------------------------------------+

struct PivotLevels {
    double pivot;       // Pivot centrale
    double r1, r2, r3;  // Resistenze
    double s1, s2, s3;  // Supporti
    datetime calcTime;  // Timestamp calcolo
    bool isValid;
};

struct DonchianLevels {
    double upper;       // Upper band (Highest High)
    double lower;       // Lower band (Lowest Low)
    double center;      // Centro (Upper + Lower) / 2
    datetime calcTime;
    bool isValid;
};

struct CenterCalculation {
    double pivotCenter;
    double emaCenter;
    double donchianCenter;
    double optimalCenter;   // Centro ponderato finale
    double confidence;      // 0-100% (quanto i 3 indicatori sono allineati)
    datetime calcTime;
    bool isValid;
};

//+------------------------------------------------------------------+
//| VARIABILI GLOBALI                                                |
//+------------------------------------------------------------------+

PivotLevels         g_pivotLevels;
DonchianLevels      g_donchianLevels;
CenterCalculation   g_centerCalc;

int                 g_emaHandle = INVALID_HANDLE;
int                 g_donchianUpperHandle = INVALID_HANDLE;
int                 g_donchianLowerHandle = INVALID_HANDLE;

datetime            g_lastPivotCalcDay = 0;
datetime            g_lastCenterCalc = 0;

//+------------------------------------------------------------------+
//| INIZIALIZZAZIONE                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Inizializza il sistema di calcolo centro                         |
//+------------------------------------------------------------------+
bool InitializeCenterCalculator() {
    Print("[CenterCalc] Inizializzazione sistema indicatori centro...");
    
    bool success = true;
    
    // ═══════════════════════════════════════════════════════════════
    // 1. Inizializza EMA
    // ═══════════════════════════════════════════════════════════════
    if(UseEMA50) {
        g_emaHandle = iMA(_Symbol, EMA_Timeframe, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
        if(g_emaHandle == INVALID_HANDLE) {
            Print("[CenterCalc] ERROR: Failed to create EMA indicator");
            success = false;
        } else {
            Print("[CenterCalc] EMA ", EMA_Period, " (", EnumToString(EMA_Timeframe), ") initialized");
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // 2. Inizializza Donchian Channel (usando iCustom o calcolo manuale)
    // ═══════════════════════════════════════════════════════════════
    if(UseDonchianCenter) {
        // Donchian non ha indicatore built-in, lo calcoliamo manualmente
        Print("[CenterCalc] Donchian Channel ", Donchian_Period, 
              " (", EnumToString(Donchian_Timeframe), ") - calcolo manuale");
    }
    
    // ═══════════════════════════════════════════════════════════════
    // 3. Calcola Pivot Point iniziale
    // ═══════════════════════════════════════════════════════════════
    if(UsePivotPoint) {
        if(CalculateDailyPivot()) {
            Print("[CenterCalc] Pivot Point Daily initialized");
            Print("  Pivot: ", FormatPrice(g_pivotLevels.pivot));
            Print("  R1: ", FormatPrice(g_pivotLevels.r1), " | S1: ", FormatPrice(g_pivotLevels.s1));
        } else {
            Print("[CenterCalc] WARNING: Failed to calculate initial Pivot");
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // 4. Calcola centro iniziale
    // ═══════════════════════════════════════════════════════════════
    if(success) {
        CalculateOptimalCenter();
        Print("[CenterCalc] Centro ottimale iniziale: ", FormatPrice(g_centerCalc.optimalCenter));
        Print("[CenterCalc] Confidence: ", DoubleToString(g_centerCalc.confidence, 1), "%");
    }
    
    return success;
}

//+------------------------------------------------------------------+
//| Rilascia risorse                                                 |
//+------------------------------------------------------------------+
void DeinitializeCenterCalculator() {
    if(g_emaHandle != INVALID_HANDLE) {
        IndicatorRelease(g_emaHandle);
        g_emaHandle = INVALID_HANDLE;
    }
}

//+------------------------------------------------------------------+
//| CALCOLO PIVOT POINT                                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calcola Pivot Point Daily                                        |
//+------------------------------------------------------------------+
bool CalculateDailyPivot() {
    // Verifica se già calcolato oggi
    datetime today = iTime(_Symbol, PERIOD_D1, 0);
    if(g_lastPivotCalcDay == today && g_pivotLevels.isValid) {
        return true;  // Già calcolato
    }
    
    // Ottieni dati del giorno precedente
    double high = iHigh(_Symbol, PERIOD_D1, 1);
    double low = iLow(_Symbol, PERIOD_D1, 1);
    double close = iClose(_Symbol, PERIOD_D1, 1);
    
    if(high == 0 || low == 0 || close == 0) {
        g_pivotLevels.isValid = false;
        return false;
    }
    
    // Calcola Pivot
    g_pivotLevels.pivot = (high + low + close) / 3.0;
    
    // Calcola Resistenze
    g_pivotLevels.r1 = (2.0 * g_pivotLevels.pivot) - low;
    g_pivotLevels.r2 = g_pivotLevels.pivot + (high - low);
    g_pivotLevels.r3 = high + 2.0 * (g_pivotLevels.pivot - low);
    
    // Calcola Supporti
    g_pivotLevels.s1 = (2.0 * g_pivotLevels.pivot) - high;
    g_pivotLevels.s2 = g_pivotLevels.pivot - (high - low);
    g_pivotLevels.s3 = low - 2.0 * (high - g_pivotLevels.pivot);
    
    g_pivotLevels.calcTime = TimeCurrent();
    g_pivotLevels.isValid = true;
    g_lastPivotCalcDay = today;
    
    return true;
}

//+------------------------------------------------------------------+
//| CALCOLO EMA                                                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Ottieni valore EMA corrente                                      |
//+------------------------------------------------------------------+
double GetEMAValue() {
    if(!UseEMA50 || g_emaHandle == INVALID_HANDLE) {
        return 0;
    }
    
    double buffer[];
    ArraySetAsSeries(buffer, true);
    
    if(CopyBuffer(g_emaHandle, 0, 0, 1, buffer) <= 0) {
        return 0;
    }
    
    return buffer[0];
}

//+------------------------------------------------------------------+
//| CALCOLO DONCHIAN CHANNEL                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calcola Donchian Channel manualmente                             |
//+------------------------------------------------------------------+
bool CalculateDonchianChannel() {
    if(!UseDonchianCenter) {
        g_donchianLevels.isValid = false;
        return false;
    }
    
    double highestHigh = 0;
    double lowestLow = DBL_MAX;
    
    // Trova Highest High e Lowest Low degli ultimi N periodi
    for(int i = 1; i <= Donchian_Period; i++) {
        double high = iHigh(_Symbol, Donchian_Timeframe, i);
        double low = iLow(_Symbol, Donchian_Timeframe, i);
        
        if(high > highestHigh) highestHigh = high;
        if(low < lowestLow) lowestLow = low;
    }
    
    if(highestHigh == 0 || lowestLow == DBL_MAX) {
        g_donchianLevels.isValid = false;
        return false;
    }
    
    g_donchianLevels.upper = highestHigh;
    g_donchianLevels.lower = lowestLow;
    g_donchianLevels.center = (highestHigh + lowestLow) / 2.0;
    g_donchianLevels.calcTime = TimeCurrent();
    g_donchianLevels.isValid = true;
    
    return true;
}

//+------------------------------------------------------------------+
//| CALCOLO CENTRO OTTIMALE                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calcola centro ottimale ponderato                                |
//+------------------------------------------------------------------+
bool CalculateOptimalCenter() {
    // ═══════════════════════════════════════════════════════════════
    // 1. Aggiorna tutti gli indicatori
    // ═══════════════════════════════════════════════════════════════
    
    // Pivot Point
    if(UsePivotPoint) {
        CalculateDailyPivot();
    }
    
    // EMA
    double emaValue = 0;
    if(UseEMA50) {
        emaValue = GetEMAValue();
    }
    
    // Donchian
    if(UseDonchianCenter) {
        CalculateDonchianChannel();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // 2. Calcola pesi normalizzati
    // ═══════════════════════════════════════════════════════════════
    
    double totalWeight = 0;
    double weightPivot = 0, weightEMA = 0, weightDonchian = 0;
    
    if(UsePivotPoint && g_pivotLevels.isValid) {
        weightPivot = Weight_PivotPoint;
        totalWeight += weightPivot;
    }
    
    if(UseEMA50 && emaValue > 0) {
        weightEMA = Weight_EMA50;
        totalWeight += weightEMA;
    }
    
    if(UseDonchianCenter && g_donchianLevels.isValid) {
        weightDonchian = Weight_Donchian;
        totalWeight += weightDonchian;
    }
    
    if(totalWeight == 0) {
        g_centerCalc.isValid = false;
        return false;
    }
    
    // Normalizza pesi a 100%
    weightPivot = (weightPivot / totalWeight) * 100;
    weightEMA = (weightEMA / totalWeight) * 100;
    weightDonchian = (weightDonchian / totalWeight) * 100;
    
    // ═══════════════════════════════════════════════════════════════
    // 3. Salva valori individuali
    // ═══════════════════════════════════════════════════════════════
    
    g_centerCalc.pivotCenter = (g_pivotLevels.isValid) ? g_pivotLevels.pivot : 0;
    g_centerCalc.emaCenter = emaValue;
    g_centerCalc.donchianCenter = (g_donchianLevels.isValid) ? g_donchianLevels.center : 0;
    
    // ═══════════════════════════════════════════════════════════════
    // 4. Calcola centro ponderato
    // ═══════════════════════════════════════════════════════════════
    
    double weightedSum = 0;
    
    if(g_pivotLevels.isValid) {
        weightedSum += g_pivotLevels.pivot * (weightPivot / 100);
    }
    
    if(emaValue > 0) {
        weightedSum += emaValue * (weightEMA / 100);
    }
    
    if(g_donchianLevels.isValid) {
        weightedSum += g_donchianLevels.center * (weightDonchian / 100);
    }
    
    g_centerCalc.optimalCenter = weightedSum;
    
    // ═══════════════════════════════════════════════════════════════
    // 5. Calcola confidence (quanto i 3 indicatori sono allineati)
    // ═══════════════════════════════════════════════════════════════
    
    g_centerCalc.confidence = CalculateCenterConfidence();
    
    // ═══════════════════════════════════════════════════════════════
    // 6. Finalizza
    // ═══════════════════════════════════════════════════════════════
    
    g_centerCalc.calcTime = TimeCurrent();
    g_centerCalc.isValid = true;
    g_lastCenterCalc = TimeCurrent();
    
    return true;
}

//+------------------------------------------------------------------+
//| Calcola confidence del centro                                    |
//+------------------------------------------------------------------+
double CalculateCenterConfidence() {
    // Confidence = quanto i 3 indicatori sono vicini tra loro
    // 100% = tutti sullo stesso prezzo
    // 0% = molto dispersi
    
    int validCount = 0;
    double values[];
    ArrayResize(values, 3);
    
    if(g_pivotLevels.isValid) {
        values[validCount++] = g_pivotLevels.pivot;
    }
    if(g_centerCalc.emaCenter > 0) {
        values[validCount++] = g_centerCalc.emaCenter;
    }
    if(g_donchianLevels.isValid) {
        values[validCount++] = g_donchianLevels.center;
    }
    
    if(validCount < 2) return 50.0;  // Non abbastanza dati
    
    // Calcola range tra min e max
    double minVal = values[0], maxVal = values[0];
    for(int i = 1; i < validCount; i++) {
        if(values[i] < minVal) minVal = values[i];
        if(values[i] > maxVal) maxVal = values[i];
    }
    
    double range = maxVal - minVal;
    double rangePips = PointsToPips(range);
    
    // Confidence: 100% se range < 5 pips, scende con range maggiore
    // 0% se range > 50 pips
    double confidence = 100.0 - (rangePips * 2.0);
    confidence = MathMax(0, MathMin(100, confidence));
    
    return confidence;
}

//+------------------------------------------------------------------+
//| FUNZIONI PUBBLICHE                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Ottieni centro ottimale corrente                                 |
//+------------------------------------------------------------------+
double GetOptimalCenter() {
    // Ricalcola se necessario (ogni 5 minuti)
    if(TimeCurrent() - g_lastCenterCalc > 300) {
        CalculateOptimalCenter();
    }
    
    return g_centerCalc.optimalCenter;
}

//+------------------------------------------------------------------+
//| Ottieni confidence corrente                                      |
//+------------------------------------------------------------------+
double GetCenterConfidence() {
    return g_centerCalc.confidence;
}

//+------------------------------------------------------------------+
//| Ottieni struttura completa calcolo centro                        |
//+------------------------------------------------------------------+
CenterCalculation GetCenterCalculation() {
    return g_centerCalc;
}

//+------------------------------------------------------------------+
//| Log report centro                                                |
//+------------------------------------------------------------------+
void LogCenterReport() {
    CalculateOptimalCenter();  // Aggiorna
    
    Print("═══════════════════════════════════════════════════════════════");
    Print("  CENTER CALCULATION REPORT");
    Print("═══════════════════════════════════════════════════════════════");
    
    if(g_pivotLevels.isValid) {
        Print("  Pivot Point Daily: ", FormatPrice(g_pivotLevels.pivot), 
              " (Weight: ", DoubleToString(Weight_PivotPoint, 0), "%)");
        Print("    R1: ", FormatPrice(g_pivotLevels.r1), 
              " | S1: ", FormatPrice(g_pivotLevels.s1));
    }
    
    if(g_centerCalc.emaCenter > 0) {
        Print("  EMA ", EMA_Period, ": ", FormatPrice(g_centerCalc.emaCenter),
              " (Weight: ", DoubleToString(Weight_EMA50, 0), "%)");
    }
    
    if(g_donchianLevels.isValid) {
        Print("  Donchian Center: ", FormatPrice(g_donchianLevels.center),
              " (Weight: ", DoubleToString(Weight_Donchian, 0), "%)");
        Print("    Upper: ", FormatPrice(g_donchianLevels.upper),
              " | Lower: ", FormatPrice(g_donchianLevels.lower));
    }
    
    Print("  ─────────────────────────────────────────────────────────────");
    Print("  OPTIMAL CENTER: ", FormatPrice(g_centerCalc.optimalCenter));
    Print("  CONFIDENCE: ", DoubleToString(g_centerCalc.confidence, 1), "%");
    Print("═══════════════════════════════════════════════════════════════");
}
```

---

# 6. FASE 4: AUTO-RECENTER LOGIC

## 6.1 Obiettivo

Implementare la logica di ricentramento automatico della griglia quando il prezzo torna vicino al centro ottimale e l'entry point attuale è troppo lontano.

## 6.2 Parametri da Aggiungere

**File:** `Config/InputParameters.mqh`

```cpp
//+------------------------------------------------------------------+
//| 🔄 AUTO-RECENTER SETTINGS                                        |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔄 AUTO-RECENTER SYSTEM                                   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⚙️ ATTIVAZIONE"
input bool      EnableAutoRecenter = true;              // ✅ Abilita Auto-Recenter
input bool      RequireUserConfirm = false;             // ⚠️ Richiedi conferma utente

input group "    📏 CONDIZIONI TRIGGER"
input double    Recenter_PriceProximity_Pips = 10.0;    // 📏 Prezzo deve essere entro X pips dal centro
input double    Recenter_EntryDistance_Pips = 40.0;     // 📏 Entry deve essere lontano almeno X pips dal centro
input double    Recenter_MinConfidence = 60.0;          // 📊 Confidence minima indicatori (%)

input group "    💰 CONDIZIONI SICUREZZA"
input double    Recenter_MaxFloatingLoss_USD = 50.0;    // 💰 Max floating loss per reset ($)
input double    Recenter_MaxFloatingLoss_Pct = 2.0;     // 💰 Max floating loss per reset (% equity)
input int       Recenter_MinFilledPositions = 0;        // 🔢 Min posizioni filled per bloccare (0=ignora)

input group "    ⏱️ TIMING"
input int       Recenter_MinInterval_Minutes = 240;     // ⏱️ Intervallo minimo tra recenter (minuti)
input bool      Recenter_OnlyOnNewBar = true;           // ⏱️ Recenter solo su nuova barra M15

input group "    🛡️ ECCEZIONI"
input bool      BlockRecenterNearShield = true;         // 🛡️ Blocca recenter vicino a Shield
input bool      BlockRecenterOnTrend = true;            // 🛡️ Blocca recenter su trend forte
input bool      BlockRecenterHighVolatility = true;     // 🛡️ Blocca recenter su ATR EXTREME
```

## 6.3 Nuovo File: GridRecenterManager.mqh

**File:** `Trading/GridRecenterManager.mqh`

```cpp
//+------------------------------------------------------------------+
//|                                         GridRecenterManager.mqh  |
//|                        Sugamara v4.0 - Grid Recenter Manager     |
//|                                                                  |
//|  Gestisce il ricentramento automatico della griglia              |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| VARIABILI GLOBALI                                                |
//+------------------------------------------------------------------+

datetime        g_lastRecenterTime = 0;
datetime        g_lastRecenterCheck = 0;
int             g_recenterCount = 0;
bool            g_recenterPending = false;

//+------------------------------------------------------------------+
//| INIZIALIZZAZIONE                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Inizializza Recenter Manager                                     |
//+------------------------------------------------------------------+
bool InitializeRecenterManager() {
    Print("[Recenter] Manager inizializzato");
    Print("  Auto-Recenter: ", EnableAutoRecenter ? "ENABLED" : "DISABLED");
    
    if(EnableAutoRecenter) {
        Print("  Proximity Trigger: ", DoubleToString(Recenter_PriceProximity_Pips, 1), " pips");
        Print("  Entry Distance: ", DoubleToString(Recenter_EntryDistance_Pips, 1), " pips");
        Print("  Min Interval: ", Recenter_MinInterval_Minutes, " minuti");
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| VERIFICA CONDIZIONI                                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Verifica se tutte le condizioni per recenter sono soddisfatte    |
//+------------------------------------------------------------------+
bool CheckRecenterConditions() {
    if(!EnableAutoRecenter) return false;
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 1: Intervallo minimo
    // ═══════════════════════════════════════════════════════════════
    if(g_lastRecenterTime > 0) {
        int minutesElapsed = (int)((TimeCurrent() - g_lastRecenterTime) / 60);
        if(minutesElapsed < Recenter_MinInterval_Minutes) {
            return false;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 2: Solo su nuova barra (se richiesto)
    // ═══════════════════════════════════════════════════════════════
    if(Recenter_OnlyOnNewBar) {
        static datetime lastBarTime = 0;
        datetime currentBarTime = iTime(_Symbol, PERIOD_M15, 0);
        if(currentBarTime == lastBarTime) {
            return false;
        }
        lastBarTime = currentBarTime;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 3: Calcola centro ottimale
    // ═══════════════════════════════════════════════════════════════
    double optimalCenter = GetOptimalCenter();
    if(optimalCenter <= 0) {
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 4: Confidence minima
    // ═══════════════════════════════════════════════════════════════
    double confidence = GetCenterConfidence();
    if(confidence < Recenter_MinConfidence) {
        if(DetailedLogging) {
            Print("[Recenter] Blocked - Low confidence: ", 
                  DoubleToString(confidence, 1), "%");
        }
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 5: Prezzo vicino al centro
    // ═══════════════════════════════════════════════════════════════
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double distanceToCenter = MathAbs(currentPrice - optimalCenter);
    double distanceToCenterPips = PointsToPips(distanceToCenter);
    
    if(distanceToCenterPips > Recenter_PriceProximity_Pips) {
        // Prezzo non ancora al centro
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 6: Entry Point lontano dal centro
    // ═══════════════════════════════════════════════════════════════
    double entryDistance = MathAbs(entryPoint - optimalCenter);
    double entryDistancePips = PointsToPips(entryDistance);
    
    if(entryDistancePips < Recenter_EntryDistance_Pips) {
        // Entry già vicino al centro, non serve recenter
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 7: Floating loss accettabile
    // ═══════════════════════════════════════════════════════════════
    double floatingPL = GetTotalFloatingPL();
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double floatingPct = (floatingPL / equity) * 100;
    
    if(floatingPL < -Recenter_MaxFloatingLoss_USD) {
        if(DetailedLogging) {
            Print("[Recenter] Blocked - Floating loss too high: ", 
                  FormatMoney(floatingPL));
        }
        return false;
    }
    
    if(floatingPct < -Recenter_MaxFloatingLoss_Pct) {
        if(DetailedLogging) {
            Print("[Recenter] Blocked - Floating loss % too high: ", 
                  DoubleToString(floatingPct, 2), "%");
        }
        return false;
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 8: Non vicino a Shield
    // ═══════════════════════════════════════════════════════════════
    if(BlockRecenterNearShield && IsRangeBoxAvailable()) {
        if(currentShieldPhase != PHASE_NORMAL) {
            if(DetailedLogging) {
                Print("[Recenter] Blocked - Shield phase active");
            }
            return false;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 9: Non in trend forte
    // ═══════════════════════════════════════════════════════════════
    if(BlockRecenterOnTrend) {
        double adx = GetADXValue();
        if(adx > TrendADX_Threshold) {
            if(DetailedLogging) {
                Print("[Recenter] Blocked - Strong trend (ADX=", 
                      DoubleToString(adx, 1), ")");
            }
            return false;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // CHECK 10: Non in volatilità estrema
    // ═══════════════════════════════════════════════════════════════
    if(BlockRecenterHighVolatility && EnableDynamicATRSpacing) {
        if(currentATRStep == ATR_STEP_EXTREME) {
            if(DetailedLogging) {
                Print("[Recenter] Blocked - Extreme volatility");
            }
            return false;
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // TUTTE LE CONDIZIONI SODDISFATTE!
    // ═══════════════════════════════════════════════════════════════
    
    return true;
}

//+------------------------------------------------------------------+
//| ESECUZIONE RECENTER                                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Funzione principale: controlla e esegue recenter                 |
//+------------------------------------------------------------------+
void CheckAndRecenterGrid() {
    if(!EnableAutoRecenter) return;
    
    if(!CheckRecenterConditions()) return;
    
    // Condizioni soddisfatte - esegui recenter
    double optimalCenter = GetOptimalCenter();
    
    Print("═══════════════════════════════════════════════════════════════");
    Print("  🔄 AUTO-RECENTER TRIGGERED");
    Print("═══════════════════════════════════════════════════════════════");
    Print("  Old Entry Point: ", FormatPrice(entryPoint));
    Print("  New Entry Point: ", FormatPrice(optimalCenter));
    Print("  Distance: ", DoubleToString(PointsToPips(MathAbs(entryPoint - optimalCenter)), 1), " pips");
    
    if(RequireUserConfirm) {
        // Imposta flag per conferma utente (da gestire con pulsante)
        g_recenterPending = true;
        Print("  ⚠️ ATTESA CONFERMA UTENTE");
        
        if(EnableAlerts) {
            Alert("SUGAMARA: Recenter pronto - Confermare?");
        }
        return;
    }
    
    // Esegui recenter
    ExecuteGridRecenter(optimalCenter);
}

//+------------------------------------------------------------------+
//| Esegue il recenter della griglia                                 |
//+------------------------------------------------------------------+
void ExecuteGridRecenter(double newEntryPoint) {
    Print("[Recenter] Inizio esecuzione...");
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 1: Chiudi tutte le posizioni aperte
    // ═══════════════════════════════════════════════════════════════
    
    Print("[Recenter] Chiusura posizioni Grid A...");
    CloseAllGridA();
    
    Print("[Recenter] Chiusura posizioni Grid B...");
    CloseAllGridB();
    
    // Attendi conferma chiusura
    Sleep(500);
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 2: Cancella ordini pending residui
    // ═══════════════════════════════════════════════════════════════
    
    Print("[Recenter] Cancellazione ordini pending residui...");
    CancelAllPendingOrders();
    
    Sleep(500);
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 3: Aggiorna Entry Point
    // ═══════════════════════════════════════════════════════════════
    
    double oldEntryPoint = entryPoint;
    entryPoint = newEntryPoint;
    
    Print("[Recenter] Entry Point aggiornato: ", 
          FormatPrice(oldEntryPoint), " → ", FormatPrice(newEntryPoint));
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 4: Ricalcola spacing (se ATR dinamico)
    // ═══════════════════════════════════════════════════════════════
    
    if(EnableDynamicATRSpacing) {
        currentSpacing_Pips = GetSpacingForATRStep(currentATRStep);
    }
    
    Print("[Recenter] Spacing: ", DoubleToString(currentSpacing_Pips, 1), " pips");
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 5: Reinizializza array griglie
    // ═══════════════════════════════════════════════════════════════
    
    Print("[Recenter] Reinizializzazione Grid A...");
    InitializeGridA();
    
    Print("[Recenter] Reinizializzazione Grid B...");
    InitializeGridB();
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 6: Piazza nuovi ordini
    // ═══════════════════════════════════════════════════════════════
    
    Print("[Recenter] Piazzamento ordini Grid A...");
    PlaceAllGridAOrders();
    
    Print("[Recenter] Piazzamento ordini Grid B...");
    PlaceAllGridBOrders();
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 7: Aggiorna RangeBox e Shield
    // ═══════════════════════════════════════════════════════════════
    
    if(IsRangeBoxAvailable()) {
        Print("[Recenter] Sincronizzazione RangeBox...");
        SyncRangeBoxWithGrid();
        CalculateBreakoutLevels();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 8: Aggiorna visualizzazione
    // ═══════════════════════════════════════════════════════════════
    
    if(ShowGridLines) {
        DeleteAllGridObjects();
        DrawEntryPointLine();
        DrawAllGridLines();
    }
    
    if(ShowRangeBox) {
        DrawRangeBoxVisualization();
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 9: Aggiorna stato
    // ═══════════════════════════════════════════════════════════════
    
    g_lastRecenterTime = TimeCurrent();
    g_recenterCount++;
    g_recenterPending = false;
    
    Print("═══════════════════════════════════════════════════════════════");
    Print("  ✅ RECENTER COMPLETATO CON SUCCESSO");
    Print("  Nuovo Entry Point: ", FormatPrice(entryPoint));
    Print("  Nuovo Spacing: ", DoubleToString(currentSpacing_Pips, 1), " pips");
    Print("  Recenter #", g_recenterCount, " della sessione");
    Print("═══════════════════════════════════════════════════════════════");
    
    // Alert
    if(EnableAlerts) {
        Alert("SUGAMARA: Grid recentered @ ", FormatPrice(entryPoint));
    }
}

//+------------------------------------------------------------------+
//| Conferma recenter pendente (chiamata da pulsante UI)             |
//+------------------------------------------------------------------+
void ConfirmPendingRecenter() {
    if(!g_recenterPending) return;
    
    double optimalCenter = GetOptimalCenter();
    ExecuteGridRecenter(optimalCenter);
}

//+------------------------------------------------------------------+
//| Cancella recenter pendente                                       |
//+------------------------------------------------------------------+
void CancelPendingRecenter() {
    g_recenterPending = false;
    Print("[Recenter] Recenter pendente cancellato");
}

//+------------------------------------------------------------------+
//| UTILITÀ                                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Ottieni stato recenter                                           |
//+------------------------------------------------------------------+
bool IsRecenterPending() {
    return g_recenterPending;
}

//+------------------------------------------------------------------+
//| Ottieni conteggio recenter sessione                              |
//+------------------------------------------------------------------+
int GetRecenterCount() {
    return g_recenterCount;
}

//+------------------------------------------------------------------+
//| Log report recenter                                              |
//+------------------------------------------------------------------+
void LogRecenterReport() {
    double optimalCenter = GetOptimalCenter();
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    Print("═══════════════════════════════════════════════════════════════");
    Print("  RECENTER STATUS REPORT");
    Print("═══════════════════════════════════════════════════════════════");
    Print("  Auto-Recenter: ", EnableAutoRecenter ? "ENABLED" : "DISABLED");
    Print("  Current Entry Point: ", FormatPrice(entryPoint));
    Print("  Optimal Center: ", FormatPrice(optimalCenter));
    Print("  Current Price: ", FormatPrice(currentPrice));
    Print("  ─────────────────────────────────────────────────────────────");
    Print("  Distance Price→Center: ", 
          DoubleToString(PointsToPips(MathAbs(currentPrice - optimalCenter)), 1), " pips");
    Print("  Distance Entry→Center: ", 
          DoubleToString(PointsToPips(MathAbs(entryPoint - optimalCenter)), 1), " pips");
    Print("  ─────────────────────────────────────────────────────────────");
    Print("  Recenter Count (session): ", g_recenterCount);
    Print("  Last Recenter: ", (g_lastRecenterTime > 0) ? 
          TimeToString(g_lastRecenterTime) : "Never");
    Print("  Pending: ", g_recenterPending ? "YES" : "NO");
    Print("═══════════════════════════════════════════════════════════════");
}
```

---

# 7. FASE 5: INTEGRAZIONE E TESTING

## 7.1 Modifiche Finali a Sugamara.mq5

### Include dei Nuovi File:

```cpp
// Dopo gli altri include...

// v4.0 NEW Modules
#include "Utils/DynamicATRAdapter.mqh"
#include "Indicators/CenterCalculator.mqh"
#include "Trading/GridRecenterManager.mqh"
```

### Modifiche a OnInit():

```cpp
int OnInit() {
    // ... codice esistente ...
    
    //--- STEP 7.5: Initialize Dynamic ATR Adapter ---
    if(EnableDynamicATRSpacing) {
        if(!InitializeDynamicATRAdapter()) {
            Print("WARNING: Failed to initialize Dynamic ATR Adapter");
        }
    }
    
    //--- STEP 7.6: Initialize Center Calculator ---
    if(EnableAutoRecenter) {
        if(!InitializeCenterCalculator()) {
            Print("WARNING: Failed to initialize Center Calculator");
        }
    }
    
    //--- STEP 7.7: Initialize Recenter Manager ---
    if(EnableAutoRecenter) {
        if(!InitializeRecenterManager()) {
            Print("WARNING: Failed to initialize Recenter Manager");
        }
    }
    
    //--- Setup Timer ---
    EventSetTimer(60);  // Check ogni minuto
    
    // ... resto del codice ...
}
```

### Modifiche a OnTimer():

```cpp
void OnTimer() {
    // ATR Dynamic Spacing Check (ogni 5 minuti)
    static datetime lastATRCheck = 0;
    if(TimeCurrent() - lastATRCheck >= ATR_CheckInterval_Seconds) {
        if(EnableDynamicATRSpacing) {
            CheckAndAdaptATRSpacing();
        }
        lastATRCheck = TimeCurrent();
    }
    
    // Center e Recenter Check (ogni 5 minuti)
    static datetime lastRecenterCheck = 0;
    if(TimeCurrent() - lastRecenterCheck >= 300) {
        if(EnableAutoRecenter) {
            CheckAndRecenterGrid();
        }
        lastRecenterCheck = TimeCurrent();
    }
}
```

### Modifiche a OnDeinit():

```cpp
void OnDeinit(const int reason) {
    // ... codice esistente ...
    
    // Rilascia indicatori centro
    DeinitializeCenterCalculator();
    
    // ... resto del codice ...
}
```

## 7.2 Checklist Testing

### Test Fase 1 (ATR Dynamic):

- [ ] ATR viene letto correttamente
- [ ] Step ATR cambia quando ATR varia >15%
- [ ] Spacing cambia correttamente per ogni step
- [ ] Solo ordini PENDING vengono modificati
- [ ] Ordini FILLED non vengono toccati
- [ ] RangeBox si sincronizza dopo cambio spacing

### Test Fase 2 (Cyclic Reopen):

- [ ] Ordini chiusi vengono riaperti
- [ ] Cooldown viene rispettato
- [ ] Max cicli viene rispettato (se impostato)
- [ ] Pausa su trend forte funziona
- [ ] Pausa vicino a Shield funziona

### Test Fase 3 (Center Indicators):

- [ ] Pivot Point calcolato correttamente
- [ ] EMA 50 letto correttamente
- [ ] Donchian Center calcolato correttamente
- [ ] Centro ponderato calcolato correttamente
- [ ] Confidence calcolata correttamente

### Test Fase 4 (Auto-Recenter):

- [ ] Condizioni verificate correttamente
- [ ] Recenter eseguito quando tutte condizioni OK
- [ ] Posizioni chiuse correttamente
- [ ] Nuovo entry point impostato
- [ ] Nuova griglia creata correttamente
- [ ] RangeBox aggiornato

### Test Integrazione:

- [ ] Tutti i moduli lavorano insieme
- [ ] Nessun conflitto tra funzionalità
- [ ] Performance accettabile (no lag)
- [ ] Log chiari e informativi

---

# 8. PARAMETRI COMPLETI

## 8.1 Tabella Parametri Consigliati

| Categoria | Parametro | Valore Consigliato | Note |
|-----------|-----------|-------------------|------|
| **ATR Dynamic** | EnableDynamicATRSpacing | true | Core feature |
| | ATR_CheckInterval_Seconds | 300 | 5 minuti |
| | ATR_MinTimeBetweenChanges | 900 | 15 minuti |
| | ATR_StepChangeThreshold | 15.0 | 15% |
| | Spacing_VeryLow_Pips | 8.0 | ATR < 10 |
| | Spacing_Low_Pips | 12.0 | ATR 10-15 |
| | Spacing_Normal_Pips | 16.0 | ATR 15-25 |
| | Spacing_High_Pips | 22.0 | ATR 25-35 |
| | Spacing_Extreme_Pips | 30.0 | ATR > 35 |
| **Cyclic Reopen** | EnableCyclicReopen | true | Essential |
| | ReopenMode | REOPEN_SAME_POINT | Start simple |
| | CyclicCooldown_Seconds | 60 | 1 minuto |
| | MaxCyclesPerLevel | 0 | Illimitato |
| | PauseReopenOnTrend | true | Safety |
| **Center Indicators** | UsePivotPoint | true | 40% weight |
| | UseEMA50 | true | 30% weight |
| | UseDonchianCenter | true | 30% weight |
| | EMA_Period | 50 | Standard |
| | Donchian_Period | 20 | Standard |
| **Auto-Recenter** | EnableAutoRecenter | true | Optimization |
| | Recenter_PriceProximity_Pips | 10.0 | Trigger |
| | Recenter_EntryDistance_Pips | 40.0 | Threshold |
| | Recenter_MinConfidence | 60.0 | Safety |
| | Recenter_MaxFloatingLoss_USD | 50.0 | Safety |
| | Recenter_MinInterval_Minutes | 240 | 4 ore |

---

# 9. CHECKLIST IMPLEMENTAZIONE

## 9.1 Checklist Pre-Implementazione

- [ ] Backup completo del codice esistente
- [ ] Ambiente di test configurato (demo account)
- [ ] MT5 Strategy Tester pronto

## 9.2 Checklist Fase 1 (Settimana 1)

- [ ] Aggiungere enum ENUM_ATR_STEP a Enums.mqh
- [ ] Aggiungere parametri ATR Dynamic a InputParameters.mqh
- [ ] Aggiungere variabili globali a GlobalVariables.mqh
- [ ] Creare DynamicATRAdapter.mqh
- [ ] Modificare Sugamara.mq5 (OnInit, OnTimer)
- [ ] Test: verifica cambio spacing
- [ ] Test: verifica ordini FILLED non toccati

## 9.3 Checklist Fase 2 (Settimana 2)

- [ ] Aggiungere enum ENUM_REOPEN_MODE a Enums.mqh
- [ ] Aggiungere parametri Cyclic Reopen a InputParameters.mqh
- [ ] Modificare CanLevelReopen() in GridHelpers.mqh
- [ ] Aggiungere CalculateReopenPrice() a GridHelpers.mqh
- [ ] Test: verifica reopen funziona
- [ ] Test: verifica condizioni di sicurezza

## 9.4 Checklist Fase 3 (Settimana 3)

- [ ] Aggiungere parametri Center Indicators a InputParameters.mqh
- [ ] Creare CenterCalculator.mqh
- [ ] Implementare calcolo Pivot Point
- [ ] Implementare lettura EMA
- [ ] Implementare calcolo Donchian
- [ ] Implementare calcolo centro ponderato
- [ ] Test: verifica calcoli corretti

## 9.5 Checklist Fase 4 (Settimana 4)

- [ ] Aggiungere parametri Auto-Recenter a InputParameters.mqh
- [ ] Creare GridRecenterManager.mqh
- [ ] Implementare CheckRecenterConditions()
- [ ] Implementare ExecuteGridRecenter()
- [ ] Modificare Sugamara.mq5 per integrazione
- [ ] Test: verifica recenter funziona
- [ ] Test: verifica condizioni di sicurezza

## 9.6 Checklist Fase 5 (Settimana 5)

- [ ] Test integrazione completa
- [ ] Test su dati storici (backtest)
- [ ] Test su demo account (forward test)
- [ ] Ottimizzazione parametri
- [ ] Documentazione finale
- [ ] Release versione 4.0

---

# APPENDICE A: FORMULA CENTRO OTTIMALE

```
CENTRO OTTIMALE = (Pivot × 0.40) + (EMA50 × 0.30) + (DonchianCenter × 0.30)

Dove:
- Pivot = (High_D1 + Low_D1 + Close_D1) / 3
- EMA50 = Exponential Moving Average 50 periodi su M15
- DonchianCenter = (HighestHigh_20 + LowestLow_20) / 2 su M15
```

# APPENDICE B: CONDIZIONI RECENTER

```
TUTTE le seguenti condizioni devono essere TRUE:

1. EnableAutoRecenter = true
2. |Price - Centro| < 10 pips
3. |Entry - Centro| > 40 pips
4. Confidence > 60%
5. FloatingPL > -$50
6. FloatingPL > -2% equity
7. TimeSinceLastRecenter > 4 ore
8. ShieldPhase = NORMAL
9. ADX < 30 (no trend forte)
10. ATR_Step != EXTREME
```

# APPENDICE C: TABELLA STEP ATR

| Step | Range ATR | Spacing | Range Grid (5 liv) |
|------|-----------|---------|-------------------|
| VERY_LOW | < 10 pips | 8 pips | 80 pips |
| LOW | 10-15 pips | 12 pips | 120 pips |
| NORMAL | 15-25 pips | 16 pips | 160 pips |
| HIGH | 25-35 pips | 22 pips | 220 pips |
| EXTREME | > 35 pips | 30 pips | 300 pips |

---

**Fine Documento Piano Implementazione**

**Versione:** 4.0  
**Data:** Dicembre 2024  
**Target:** SUGAMARA Double Grid Neutral  
**Autore:** Analisi tecnica avanzata

🚀 **READY FOR IMPLEMENTATION!**
