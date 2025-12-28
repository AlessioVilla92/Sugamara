# 🎯 DOUBLE PARCELLING - DOCUMENTO FINALE DI IMPLEMENTAZIONE

## Versione: SUGAMARA v5.2
## Data: 27 Dicembre 2025
## Stato: PRONTO PER IMPLEMENTAZIONE

---

# 📋 INDICE

1. [SPECIFICA FUNZIONALE COMPLETA](#1-specifica-funzionale-completa)
2. [PARAMETRI CONFIGURABILI](#2-parametri-configurabili)
3. [PROBLEMI IDENTIFICATI E SOLUZIONI](#3-problemi-identificati-e-soluzioni)
4. [ARCHITETTURA DEL MODULO](#4-architettura-del-modulo)
5. [CODICE DI IMPLEMENTAZIONE](#5-codice-di-implementazione)
6. [INTEGRAZIONI CON MODULI ESISTENTI](#6-integrazioni-con-moduli-esistenti)
7. [TEST CASES](#7-test-cases)
8. [CHECKLIST IMPLEMENTAZIONE](#8-checklist-implementazione)

---

# 1. SPECIFICA FUNZIONALE COMPLETA

## 1.1 Concetto Double Parcelling

**Double Parcelling** gestisce un singolo ordine (es: 0.02 lot) come **due parcels logici** con:
- **TP differenziati** (TP1 per Parcel A, TP2 per Parcel B)
- **Break On Parcelling** separato per ogni parcel
- **Chiusura parziale** sequenziale

```
┌─────────────────────────────────────────────────────────────────┐
│                    ORDINE ORIGINALE                             │
│                    0.02 lot @ Entry                             │
└───────────────────────────┬─────────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────────┐
│   PARCEL A (50% = 0.01 lot)                                      │
│   ├─ TP1 = Entry + (Spacing × DP_TP1_Percent / 100)              │
│   ├─ BOP1 Trigger = DP_BOP1_Trigger_Percent (default: 70%)       │
│   ├─ BOP1 SL = DP_BOP1_SL_Percent (default: 50%)                 │
│   └─ Chiusura: quando prezzo raggiunge TP1                       │
└───────────────────────────────────────────────────────────────────┘
                            +
┌───────────────────────────────────────────────────────────────────┐
│   PARCEL B (50% = 0.01 lot)                                      │
│   ├─ TP2 = TP1 × DP_TP2_Multiplier (o Entry + Spacing × %)       │
│   ├─ BOP2 Trigger = DP_BOP2_Trigger_Percent (default: 100%)      │
│   ├─ BOP2 SL = DP_BOP2_SL_Percent (default: 70%)                 │
│   └─ Chiusura: quando prezzo raggiunge TP2                       │
└───────────────────────────────────────────────────────────────────┘
                            │
                            ▼
┌───────────────────────────────────────────────────────────────────┐
│   RECYCLING                                                      │
│   Solo quando ENTRAMBI i parcels sono chiusi                     │
└───────────────────────────────────────────────────────────────────┘
```

## 1.2 Flusso Operativo Dettagliato

```
FASE 0 - ORDINE ATTIVATO
├─ Ordine 0.02 lot si attiva (ORDER_PENDING → ORDER_FILLED)
├─ Sistema inizializza tracking Double Parcelling
├─ Calcola TP1, TP2, BOP1, BOP2
└─ NON imposta TP su MT5 (gestione manuale)

FASE 1 - TRACKING PARCEL A (0% → BOP1 Trigger)
├─ Monitora progress verso TP1
├─ Progress = (currentPrice - entry) / TP1_Distance × 100
└─ Nessuna azione finché < BOP1_Trigger

FASE 2 - BOP1 ATTIVATO (Break On Parcelling per Parcel A)
├─ TRIGGER: Progress >= DP_BOP1_Trigger_Percent (es: 70%)
├─ AZIONE: Sposta SL dell'INTERA posizione (0.02 lot)
├─ Nuovo SL = Entry + (TP1_Distance × DP_BOP1_SL_Percent / 100)
└─ Flag: bop1_Activated = true

FASE 3 - TP1 RAGGIUNTO (Chiusura Parcel A)
├─ TRIGGER: Progress >= 100% (prezzo @ TP1)
├─ AZIONE: trade.PositionClosePartial(ticket, 0.01)
├─ MT5 chiude 0.01 lot e CREA NUOVO TICKET per restante
├─ ⚠️ CRITICO: Recuperare nuovo ticket!
├─ Flag: parcelA_Closed = true
└─ Profit Parcel A registrato

FASE 4 - TRACKING PARCEL B (post TP1)
├─ Monitora progress verso TP2 con NUOVO TICKET
├─ Progress = (currentPrice - entry) / TP2_Distance × 100
└─ Attende BOP2 Trigger

FASE 5 - BOP2 ATTIVATO (Break On Parcelling per Parcel B)
├─ TRIGGER: Progress >= DP_BOP2_Trigger_Percent (es: 100% = quando A chiude)
├─ AZIONE: Sposta SL della posizione rimanente (0.01 lot)
├─ Nuovo SL = Entry + (TP2_Distance × DP_BOP2_SL_Percent / 100)
└─ Flag: bop2_Activated = true

FASE 6 - TP2 RAGGIUNTO (Chiusura Parcel B)
├─ TRIGGER: Progress >= 100% verso TP2 (prezzo @ TP2)
├─ AZIONE: trade.PositionClose(currentTicket)
├─ Flag: parcelB_Closed = true
└─ Profit Parcel B registrato

FASE 7 - RECYCLING
├─ CONDIZIONE: parcelA_Closed AND parcelB_Closed
├─ Reset tutti i flag DP
├─ Imposta gridX_Status[level] = ORDER_CLOSED_TP
└─ Cyclic Reopen può procedere
```

## 1.3 Scenari di Uscita con Numeri

**Configurazione esempio:**
- Entry = 1.08500
- Spacing = 10 pips
- DP_TP1_Percent = 100 (TP1 = 1.08600)
- DP_TP2_Multiplier = 2.0 (TP2 = 1.08700)
- Lot = 0.02

| # | Scenario | Parcel A | Parcel B | Profit Totale |
|---|----------|----------|----------|---------------|
| 1 | TP2 raggiunto | +$1.00 (10 pips) | +$2.00 (20 pips) | **+$3.00** |
| 2 | TP1 + SL@BOP2 | +$1.00 (10 pips) | +$0.70 (7 pips) | **+$1.70** |
| 3 | Solo BOP1 (SL hit) | +$0.50 (5 pips) | +$0.50 (5 pips) | **+$1.00** |
| 4 | Niente (no BOP1) | $0 | $0 | **$0 o loss** |

---

# 2. PARAMETRI CONFIGURABILI

## 2.1 Input Parameters Completi

```mql5
//+------------------------------------------------------------------+
//| 🎯 DOUBLE PARCELLING (v5.2) - Input Parameters                   |
//+------------------------------------------------------------------+

input group "═══════════════════════════════════════════════════════════"
input group "  🎯 DOUBLE PARCELLING (v5.2)"
input group "═══════════════════════════════════════════════════════════"

input bool   Enable_DoubleParcelling = false;   // ✅ Enable Double Parcelling

//--- TP1 CONFIGURATION (Parcel A) ---
input group "    📊 TP1 - PARCEL A"
input int    DP_TP1_Percent = 100;              // TP1 (% dello spacing)
                                                 // 100 = 1 spacing = Entry Grid 2
                                                 // 50 = 0.5 spacing (mezzo livello)
                                                 // 150 = 1.5 spacing

//--- TP2 CONFIGURATION (Parcel B) ---
input group "    📊 TP2 - PARCEL B"
input int    DP_TP2_Percent = 200;              // TP2 (% dello spacing)
                                                 // 100 = uguale a TP1
                                                 // 150 = 1.5× spacing
                                                 // 200 = 2× spacing = Entry Grid 3
                                                 // 300 = 3× spacing = Entry Grid 4

// ALTERNATIVA: TP2 come moltiplicatore di TP1
// input double DP_TP2_Multiplier = 2.0;        // TP2 = TP1 × Multiplier

//--- BREAK ON PARCELLING - PARCEL A (BOP1) ---
input group "    🔒 BREAK ON PARCELLING - PARCEL A"
input int    DP_BOP1_Trigger_Percent = 70;      // BOP1 Trigger (% progress verso TP1)
                                                 // Quando attivare il Break Even per Parcel A
input int    DP_BOP1_SL_Percent = 50;           // BOP1 SL Level (% progress)
                                                 // Dove posizionare SL dopo trigger

//--- BREAK ON PARCELLING - PARCEL B (BOP2) ---
input group "    🔒 BREAK ON PARCELLING - PARCEL B"
input int    DP_BOP2_Trigger_Percent = 100;     // BOP2 Trigger (% progress verso TP2)
                                                 // 100 = si attiva quando Parcel A chiude
input int    DP_BOP2_SL_Percent = 70;           // BOP2 SL Level (% progress verso TP2)
                                                 // Dove posizionare SL dopo trigger

//--- LOT SPLIT ---
input group "    📦 LOT CONFIGURATION"
input int    DP_LotRatio = 50;                  // Parcel Split (%)
                                                 // 50 = 50/50 (0.01 + 0.01)
                                                 // 60 = 60/40 (0.012 + 0.008)
                                                 // 70 = 70/30 (0.014 + 0.006)
```

## 2.2 Tabella Configurazioni Esempio

| Configurazione | TP1 | TP2 | BOP1 | BOP2 | Uso Consigliato |
|----------------|-----|-----|------|------|-----------------|
| **Conservativa** | 100% | 150% | 60%/40% | 100%/60% | Range stretto |
| **Bilanciata** | 100% | 200% | 70%/50% | 100%/70% | Default |
| **Aggressiva** | 100% | 250% | 80%/60% | 120%/80% | Trend forte |
| **Classica** | 100% | 100% | 70%/50% | - | Come senza DP |

## 2.3 Formula Calcolo TP1 e TP2

```mql5
// TP1: Distanza dal spacing
double TP1_Distance = spacingPoints * DP_TP1_Percent / 100.0;
double TP1_Price = isBuy ? (entry + TP1_Distance) : (entry - TP1_Distance);

// TP2: Distanza dal spacing (indipendente da TP1)
double TP2_Distance = spacingPoints * DP_TP2_Percent / 100.0;
double TP2_Price = isBuy ? (entry + TP2_Distance) : (entry - TP2_Distance);

// OPPURE: TP2 come moltiplicatore di TP1
// double TP2_Distance = TP1_Distance * DP_TP2_Multiplier;
```

---

# 3. PROBLEMI IDENTIFICATI E SOLUZIONI

## 3.1 🔴 PROBLEMA 1: Cambio Ticket dopo Chiusura Parziale

### Descrizione
Quando si esegue `trade.PositionClosePartial()`, MT5:
1. Chiude la posizione originale
2. Apre una NUOVA posizione per il volume rimanente
3. La nuova posizione ha un **NUOVO TICKET**

### Impatto senza soluzione
```
PRIMA: gridA_Upper_Tickets[0] = 123456
DOPO partial close: Ticket 123456 CHIUSO, Ticket 123457 CREATO
PROBLEMA: gridA_Upper_Tickets[0] = 123456 ← OBSOLETO!
```
- Parcel B (ticket 123457) viene perso
- Impossibile monitorare progress verso TP2
- Recycling parte prematuramente

### ✅ SOLUZIONE

```mql5
//+------------------------------------------------------------------+
//| Close Partial Position and Track New Ticket                     |
//+------------------------------------------------------------------+
ulong ClosePositionPartial_AndTrack(ulong oldTicket, double lotsToClose,
                                     ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(oldTicket == 0) return 0;
    if(!PositionSelectByTicket(oldTicket)) return 0;
    
    // Salva info per trovare nuovo ticket
    double currentVolume = PositionGetDouble(POSITION_VOLUME);
    string symbol = PositionGetString(POSITION_SYMBOL);
    long magic = PositionGetInteger(POSITION_MAGIC);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double expectedRemainingVolume = currentVolume - lotsToClose;
    
    // Esegui chiusura parziale
    if(!trade.PositionClosePartial(oldTicket, lotsToClose, Slippage)) {
        LogMessage(LOG_ERROR, "[DP] Partial close FAILED for #" + IntegerToString(oldTicket));
        return oldTicket;  // Ritorna vecchio ticket (operazione fallita)
    }
    
    LogMessage(LOG_SUCCESS, "[DP] Partial close OK: " + DoubleToString(lotsToClose, 2) + 
               " lots from #" + IntegerToString(oldTicket));
    
    // Attendi che MT5 processi
    Sleep(50);
    
    // Cerca il nuovo ticket
    ulong newTicket = FindNewTicketAfterPartialClose(symbol, magic, posType, expectedRemainingVolume);
    
    if(newTicket > 0 && newTicket != oldTicket) {
        LogMessage(LOG_INFO, "[DP] New ticket found: #" + IntegerToString(newTicket));
        
        // ⚠️ CRITICO: Aggiorna il ticket nell'array della grid!
        UpdateGridTicket(side, zone, level, newTicket);
        
        return newTicket;
    }
    
    LogMessage(LOG_WARNING, "[DP] Could not find new ticket - position may be fully closed");
    return 0;
}

//+------------------------------------------------------------------+
//| Find New Ticket After Partial Close                             |
//+------------------------------------------------------------------+
ulong FindNewTicketAfterPartialClose(string symbol, long magic, 
                                      ENUM_POSITION_TYPE posType, double expectedVolume) {
    // Cerca nelle posizioni aperte quella con parametri corrispondenti
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket)) {
            // Verifica corrispondenza completa
            if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != posType) continue;
            
            // Verifica volume (con tolleranza)
            double volume = PositionGetDouble(POSITION_VOLUME);
            if(MathAbs(volume - expectedVolume) < 0.001) {
                return ticket;
            }
        }
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Update Grid Ticket After Partial Close                          |
//+------------------------------------------------------------------+
void UpdateGridTicket(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, ulong newTicket) {
    if(side == GRID_A) {
        if(zone == ZONE_UPPER) {
            gridA_Upper_Tickets[level] = newTicket;
        } else {
            gridA_Lower_Tickets[level] = newTicket;
        }
    } else {
        if(zone == ZONE_UPPER) {
            gridB_Upper_Tickets[level] = newTicket;
        } else {
            gridB_Lower_Tickets[level] = newTicket;
        }
    }
    
    LogMessage(LOG_INFO, "[DP] Grid ticket updated: " + 
               (side == GRID_A ? "A" : "B") + "-" +
               (zone == ZONE_UPPER ? "Upper" : "Lower") + 
               " L" + IntegerToString(level+1) + 
               " → #" + IntegerToString(newTicket));
}
```

### Verifica Soluzione
- ✅ Dopo partial close, trova automaticamente il nuovo ticket
- ✅ Aggiorna l'array della grid con il nuovo ticket
- ✅ Il tracking continua correttamente con Parcel B

---

## 3.2 🔴 PROBLEMA 2: SL Colpito dal Broker

### Descrizione
Quando lo SL (impostato da Break On Parcelling) viene colpito:
- È il **BROKER** che chiude la posizione, non il nostro codice
- Il nostro codice potrebbe non rilevare la chiusura
- I flag `parcelB_Closed` non vengono aggiornati

### Relazione con Problema 1
Se risolviamo il Problema 1 (tracking corretto del ticket), possiamo rilevare quando la posizione non esiste più.

### ✅ SOLUZIONE

```mql5
//+------------------------------------------------------------------+
//| Check if Position Still Exists (SL Detection)                   |
//+------------------------------------------------------------------+
void CheckPositionExistence_DP(DoubleParcelling_Level &dp, 
                                ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    
    // Se entrambi i parcels sono già chiusi, niente da fare
    if(dp.parcelA_Closed && dp.parcelB_Closed) return;
    
    // Verifica se la posizione esiste ancora
    if(!PositionSelectByTicket(dp.currentTicket)) {
        // Posizione NON esiste più!
        
        if(!dp.parcelA_Closed) {
            // Parcel A non era ancora chiuso → SL ha chiuso tutto
            dp.parcelA_Closed = true;
            dp.parcelB_Closed = true;
            dp.parcelA_CloseTime = TimeCurrent();
            dp.parcelB_CloseTime = TimeCurrent();
            
            // Calcola profit da history
            double profit = GetHistoricalOrderProfit(dp.currentTicket);
            dp.parcelA_Profit = profit / 2;  // Approssimazione
            dp.parcelB_Profit = profit / 2;
            
            LogMessage(LOG_INFO, "[DP] Position closed by SL (before TP1). Profit: $" + 
                       DoubleToString(profit, 2));
        }
        else if(!dp.parcelB_Closed) {
            // Parcel A era chiuso, Parcel B chiuso da SL
            dp.parcelB_Closed = true;
            dp.parcelB_CloseTime = TimeCurrent();
            
            // Calcola profit Parcel B
            double profit = GetHistoricalOrderProfit(dp.currentTicket);
            dp.parcelB_Profit = profit;
            
            LogMessage(LOG_INFO, "[DP] Parcel B closed by SL (Break On Parcelling). Profit: $" + 
                       DoubleToString(profit, 2));
        }
        
        // Trigger recycling se entrambi chiusi
        if(dp.parcelA_Closed && dp.parcelB_Closed) {
            TriggerLevelRecycling(side, zone, level);
            ResetDP_Level(dp);
        }
    }
}
```

### Verifica Soluzione
- ✅ Rileva quando la posizione viene chiusa dal broker
- ✅ Aggiorna correttamente i flag parcelA/B_Closed
- ✅ Triggera il recycling quando appropriato

---

## 3.3 🔴 PROBLEMA 3: Sincronizzazione Cyclic Reopen

### Descrizione
Il Cyclic Reopen guarda `gridX_Status[level]`:
- Se impostiamo `ORDER_CLOSED_TP` dopo TP1, il sistema cerca di riaprire
- Ma Parcel B è ancora attivo!
- Rischio di ordini doppi sullo stesso livello

### Codice Attuale (Problematico)
```mql5
// GridASystem.mqh - ShouldReopenGridAUpper()
if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
    return false;  // ← Se status = ORDER_CLOSED_TP, procede al reopen!
}
```

### ✅ SOLUZIONE

```mql5
//+------------------------------------------------------------------+
//| Check if Level is Waiting for Parcel B                          |
//+------------------------------------------------------------------+
bool IsWaitingForParcelB(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(!Enable_DoubleParcelling) return false;
    
    // Ottieni la struttura DP per questo livello
    DoubleParcelling_Level* dp = GetDP_LevelPtr(side, zone, level);
    if(dp == NULL) return false;
    
    // Se DP non è attivo per questo livello, non aspettare
    if(!dp.isActive) return false;
    
    // Se Parcel A è chiuso ma B no, BLOCCA il recycling
    if(dp.parcelA_Closed && !dp.parcelB_Closed) {
        return true;  // Aspetta!
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| MODIFIED: ShouldReopenGridAUpper - Con check Double Parcelling  |
//+------------------------------------------------------------------+
bool ShouldReopenGridAUpper(int level) {
    ENUM_ORDER_STATUS status = gridA_Upper_Status[level];

    // ═══════════════════════════════════════════════════════════════
    // v5.2: Double Parcelling check PRIMA di tutto il resto
    // ═══════════════════════════════════════════════════════════════
    if(Enable_DoubleParcelling) {
        if(IsWaitingForParcelB(GRID_A, ZONE_UPPER, level)) {
            return false;  // ⚠️ Aspetta che Parcel B chiuda!
        }
    }

    // Check standard (codice originale invariato)
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

// Stessa modifica per: ShouldReopenGridALower, ShouldReopenGridBUpper, ShouldReopenGridBLower
```

### Verifica Soluzione
- ✅ Blocca il recycling finché Parcel B non è chiuso
- ✅ Non interferisce con il comportamento normale quando DP è disabilitato
- ✅ Nessun ordine doppio possibile

---

## 3.4 🟡 PROBLEMA 4: Calcolo Progress BUY vs SELL

### Descrizione
Il calcolo del progress deve considerare la direzione:
- BUY: guadagno quando prezzo SALE
- SELL: guadagno quando prezzo SCENDE

### ✅ SOLUZIONE

```mql5
//+------------------------------------------------------------------+
//| Calculate Progress Percentage Toward Target                     |
//+------------------------------------------------------------------+
double CalculateProgress_DP(ulong ticket, double entryPrice, double targetDistance) {
    if(ticket == 0 || targetDistance <= 0) return 0;
    if(!PositionSelectByTicket(ticket)) return 0;
    
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    // Prezzo corrente appropriato
    double currentPrice;
    if(posType == POSITION_TYPE_BUY) {
        currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    } else {
        currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    }
    
    // Calcolo differenza nella direzione corretta
    double currentDistance;
    if(posType == POSITION_TYPE_BUY) {
        currentDistance = currentPrice - entryPrice;  // Positivo se prezzo sale
    } else {
        currentDistance = entryPrice - currentPrice;  // Positivo se prezzo scende
    }
    
    // Progress in percentuale rispetto al target
    double progress = (currentDistance / targetDistance) * 100.0;
    
    return progress;
}
```

### Verifica Soluzione
- ✅ Calcola correttamente per BUY e SELL
- ✅ Usa prezzo appropriato (BID per BUY, ASK per SELL)
- ✅ Ritorna percentuale precisa del progress

---

## 3.5 ✅ VERIFICA: Le Nuove Richieste Creano Problemi?

### Nuove richieste:
1. TP1 editabile (non più fisso)
2. TP2 editabile come % dello spacing
3. Break On Parcelling separato per TP1 e TP2

### Analisi Impatto

| Modifica | Impatto sui 4 Problemi | Risultato |
|----------|------------------------|-----------|
| TP1 editabile | Nessuno - è solo un parametro | ✅ OK |
| TP2 editabile | Nessuno - è solo un parametro | ✅ OK |
| BOP1 separato | Nessuno - logica già prevista | ✅ OK |
| BOP2 separato | Nessuno - logica già prevista | ✅ OK |

### ✅ CONFERMA: Nessun Nuovo Problema Introdotto

Le nuove richieste sono **solo parametri configurabili**. La logica di base rimane identica:
1. Problema 1 (Cambio Ticket) → Risolto dalla stessa funzione
2. Problema 2 (SL Broker) → Risolto dalla stessa funzione
3. Problema 3 (Cyclic Reopen) → Risolto dalla stessa funzione
4. Problema 4 (Progress) → Risolto dalla stessa funzione

**Le soluzioni proposte funzionano con qualsiasi configurazione di TP1, TP2, BOP1, BOP2.**

---

# 4. ARCHITETTURA DEL MODULO

## 4.1 Struttura File

```
SUGAMARA/
├── Trading/
│   ├── DoubleParcelling.mqh       ← NUOVO FILE
│   ├── GridASystem.mqh            ← Modifiche minori
│   ├── GridBSystem.mqh            ← Modifiche minori
│   ├── OrderManager.mqh           ← Aggiunte funzioni
│   └── PositionMonitor.mqh        ← Modifiche minori
├── Config/
│   └── InputParameters.mqh        ← Nuovi parametri
├── Core/
│   └── GlobalVariables.mqh        ← Nuove variabili
└── Sugamara.mq5                   ← Include e chiamate
```

## 4.2 Struttura Dati DoubleParcelling_Level

```mql5
//+------------------------------------------------------------------+
//| DOUBLE PARCELLING - Tracking Structure per Livello              |
//+------------------------------------------------------------------+
struct DoubleParcelling_Level {
    // === STATO GENERALE ===
    bool   isActive;                // DP attivo per questo livello
    
    // === TICKET TRACKING ===
    ulong  originalTicket;          // Ticket originale (prima di partial close)
    ulong  currentTicket;           // Ticket corrente (può cambiare!)
    
    // === PREZZI CALCOLATI ===
    double entryPrice;              // Prezzo entry
    double tp1_Price;               // TP1 per Parcel A
    double tp2_Price;               // TP2 per Parcel B
    double tp1_Distance;            // Distanza TP1 in points
    double tp2_Distance;            // Distanza TP2 in points
    
    // === BREAK ON PARCELLING 1 (Parcel A) ===
    bool   bop1_Activated;          // BOP1 già attivato
    double bop1_TriggerPrice;       // Prezzo trigger BOP1
    double bop1_SL_Price;           // Prezzo SL dopo BOP1
    
    // === BREAK ON PARCELLING 2 (Parcel B) ===
    bool   bop2_Activated;          // BOP2 già attivato
    double bop2_TriggerPrice;       // Prezzo trigger BOP2
    double bop2_SL_Price;           // Prezzo SL dopo BOP2
    
    // === PARCEL A (Prima metà) ===
    bool   parcelA_Closed;          // Parcel A chiuso
    double parcelA_Lots;            // Lotti Parcel A
    double parcelA_Profit;          // Profit realizzato
    datetime parcelA_CloseTime;     // Tempo chiusura
    
    // === PARCEL B (Seconda metà) ===
    bool   parcelB_Closed;          // Parcel B chiuso
    double parcelB_Lots;            // Lotti Parcel B
    double parcelB_Profit;          // Profit realizzato
    datetime parcelB_CloseTime;     // Tempo chiusura
    
    // === SL TRACKING ===
    double currentSL;               // SL corrente sulla posizione
    bool   positionType;            // true = BUY, false = SELL
};
```

## 4.3 Arrays Globali

```mql5
//+------------------------------------------------------------------+
//| DOUBLE PARCELLING - Global Arrays (in GlobalVariables.mqh)      |
//+------------------------------------------------------------------+

// Grid A
DoubleParcelling_Level dpA_Upper[10];   // Grid A Upper Zone
DoubleParcelling_Level dpA_Lower[10];   // Grid A Lower Zone

// Grid B
DoubleParcelling_Level dpB_Upper[10];   // Grid B Upper Zone
DoubleParcelling_Level dpB_Lower[10];   // Grid B Lower Zone

// Statistics
int    g_dp_TotalCycles = 0;            // Cicli DP completati
double g_dp_TotalProfit = 0;            // Profit totale da DP
int    g_dp_ParcelA_Active = 0;         // Parcel A attualmente attivi
int    g_dp_ParcelB_Active = 0;         // Parcel B attualmente attivi
```

---

# 5. CODICE DI IMPLEMENTAZIONE

## 5.1 DoubleParcelling.mqh - File Completo

```mql5
//+------------------------------------------------------------------+
//|                                          DoubleParcelling.mqh    |
//|                        Sugamara v5.2 - Double Parcelling         |
//|                                                                  |
//|  Split ordini in 2 parcels con TP e Break On Parcelling          |
//|  differenziati per massimizzare profitti                         |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
bool InitializeDoubleParcelling() {
    if(!Enable_DoubleParcelling) {
        LogMessage(LOG_INFO, "[DP] Double Parcelling: DISABLED");
        return true;
    }
    
    LogMessage(LOG_INFO, "[DP] Initializing Double Parcelling...");
    
    // Reset all DP structures
    for(int i = 0; i < GridLevelsPerSide; i++) {
        ResetDP_Level(dpA_Upper[i]);
        ResetDP_Level(dpA_Lower[i]);
        ResetDP_Level(dpB_Upper[i]);
        ResetDP_Level(dpB_Lower[i]);
    }
    
    // Reset statistics
    g_dp_TotalCycles = 0;
    g_dp_TotalProfit = 0;
    g_dp_ParcelA_Active = 0;
    g_dp_ParcelB_Active = 0;
    
    // Log configuration
    LogMessage(LOG_INFO, "[DP] TP1: " + IntegerToString(DP_TP1_Percent) + "% of spacing");
    LogMessage(LOG_INFO, "[DP] TP2: " + IntegerToString(DP_TP2_Percent) + "% of spacing");
    LogMessage(LOG_INFO, "[DP] BOP1: Trigger=" + IntegerToString(DP_BOP1_Trigger_Percent) + 
               "%, SL=" + IntegerToString(DP_BOP1_SL_Percent) + "%");
    LogMessage(LOG_INFO, "[DP] BOP2: Trigger=" + IntegerToString(DP_BOP2_Trigger_Percent) + 
               "%, SL=" + IntegerToString(DP_BOP2_SL_Percent) + "%");
    
    LogMessage(LOG_SUCCESS, "[DP] Double Parcelling initialized");
    return true;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void DeinitializeDoubleParcelling() {
    if(!Enable_DoubleParcelling) return;
    
    LogMessage(LOG_INFO, "[DP] Double Parcelling Stats:");
    LogMessage(LOG_INFO, "[DP] Total Cycles: " + IntegerToString(g_dp_TotalCycles));
    LogMessage(LOG_INFO, "[DP] Total Profit: $" + DoubleToString(g_dp_TotalProfit, 2));
}

//+------------------------------------------------------------------+
//| RESET LEVEL                                                      |
//+------------------------------------------------------------------+
void ResetDP_Level(DoubleParcelling_Level &dp) {
    dp.isActive = false;
    dp.originalTicket = 0;
    dp.currentTicket = 0;
    dp.entryPrice = 0;
    dp.tp1_Price = 0;
    dp.tp2_Price = 0;
    dp.tp1_Distance = 0;
    dp.tp2_Distance = 0;
    dp.bop1_Activated = false;
    dp.bop1_TriggerPrice = 0;
    dp.bop1_SL_Price = 0;
    dp.bop2_Activated = false;
    dp.bop2_TriggerPrice = 0;
    dp.bop2_SL_Price = 0;
    dp.parcelA_Closed = false;
    dp.parcelA_Lots = 0;
    dp.parcelA_Profit = 0;
    dp.parcelA_CloseTime = 0;
    dp.parcelB_Closed = false;
    dp.parcelB_Lots = 0;
    dp.parcelB_Profit = 0;
    dp.parcelB_CloseTime = 0;
    dp.currentSL = 0;
    dp.positionType = true;
}

//+------------------------------------------------------------------+
//| SETUP ON FILL - Chiamato quando ordine si attiva                |
//+------------------------------------------------------------------+
void SetupDP_OnFill(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level,
                     ulong ticket, double entryPrice, double lots, bool isBuy) {
    
    if(!Enable_DoubleParcelling) return;
    
    // Ottieni struttura corretta
    DoubleParcelling_Level* dp = GetDP_LevelPtr(side, zone, level);
    if(dp == NULL) return;
    
    // Reset prima di setup
    ResetDP_Level(*dp);
    
    // Setup base
    dp->isActive = true;
    dp->originalTicket = ticket;
    dp->currentTicket = ticket;
    dp->entryPrice = entryPrice;
    dp->positionType = isBuy;
    
    // Calcola distanze TP
    double spacingPoints = PipsToPoints(currentSpacing_Pips);
    dp->tp1_Distance = spacingPoints * DP_TP1_Percent / 100.0;
    dp->tp2_Distance = spacingPoints * DP_TP2_Percent / 100.0;
    
    // Calcola prezzi TP
    if(isBuy) {
        dp->tp1_Price = NormalizeDouble(entryPrice + dp->tp1_Distance, symbolDigits);
        dp->tp2_Price = NormalizeDouble(entryPrice + dp->tp2_Distance, symbolDigits);
    } else {
        dp->tp1_Price = NormalizeDouble(entryPrice - dp->tp1_Distance, symbolDigits);
        dp->tp2_Price = NormalizeDouble(entryPrice - dp->tp2_Distance, symbolDigits);
    }
    
    // Calcola prezzi BOP1
    double bop1_TriggerDistance = dp->tp1_Distance * DP_BOP1_Trigger_Percent / 100.0;
    double bop1_SL_Distance = dp->tp1_Distance * DP_BOP1_SL_Percent / 100.0;
    if(isBuy) {
        dp->bop1_TriggerPrice = NormalizeDouble(entryPrice + bop1_TriggerDistance, symbolDigits);
        dp->bop1_SL_Price = NormalizeDouble(entryPrice + bop1_SL_Distance, symbolDigits);
    } else {
        dp->bop1_TriggerPrice = NormalizeDouble(entryPrice - bop1_TriggerDistance, symbolDigits);
        dp->bop1_SL_Price = NormalizeDouble(entryPrice - bop1_SL_Distance, symbolDigits);
    }
    
    // Calcola prezzi BOP2
    double bop2_TriggerDistance = dp->tp2_Distance * DP_BOP2_Trigger_Percent / 100.0;
    double bop2_SL_Distance = dp->tp2_Distance * DP_BOP2_SL_Percent / 100.0;
    if(isBuy) {
        dp->bop2_TriggerPrice = NormalizeDouble(entryPrice + bop2_TriggerDistance, symbolDigits);
        dp->bop2_SL_Price = NormalizeDouble(entryPrice + bop2_SL_Distance, symbolDigits);
    } else {
        dp->bop2_TriggerPrice = NormalizeDouble(entryPrice - bop2_TriggerDistance, symbolDigits);
        dp->bop2_SL_Price = NormalizeDouble(entryPrice - bop2_SL_Distance, symbolDigits);
    }
    
    // Calcola lotti parcels
    dp->parcelA_Lots = NormalizeDouble(lots * DP_LotRatio / 100.0, 2);
    dp->parcelB_Lots = NormalizeDouble(lots - dp->parcelA_Lots, 2);
    
    // Log
    LogMessage(LOG_INFO, "[DP] Setup " + GridSideToString(side) + "-" + GridZoneToString(zone) + 
               " L" + IntegerToString(level+1) + 
               " | Entry: " + DoubleToString(entryPrice, symbolDigits) +
               " | TP1: " + DoubleToString(dp->tp1_Price, symbolDigits) +
               " | TP2: " + DoubleToString(dp->tp2_Price, symbolDigits));
    
    g_dp_ParcelA_Active++;
    g_dp_ParcelB_Active++;
}

//+------------------------------------------------------------------+
//| GET DP LEVEL POINTER                                            |
//+------------------------------------------------------------------+
DoubleParcelling_Level* GetDP_LevelPtr(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(level < 0 || level >= GridLevelsPerSide) return NULL;
    
    if(side == GRID_A) {
        if(zone == ZONE_UPPER) return &dpA_Upper[level];
        else return &dpA_Lower[level];
    } else {
        if(zone == ZONE_UPPER) return &dpB_Upper[level];
        else return &dpB_Lower[level];
    }
}

//+------------------------------------------------------------------+
//| MAIN PROCESSING - Chiamato ogni tick                            |
//+------------------------------------------------------------------+
void ProcessDoubleParcelling() {
    if(!Enable_DoubleParcelling) return;
    
    // Process Grid A Upper
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Status[i] == ORDER_FILLED || dpA_Upper[i].isActive) {
            ProcessDP_SingleLevel(dpA_Upper[i], GRID_A, ZONE_UPPER, i);
        }
    }
    
    // Process Grid A Lower
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Lower_Status[i] == ORDER_FILLED || dpA_Lower[i].isActive) {
            ProcessDP_SingleLevel(dpA_Lower[i], GRID_A, ZONE_LOWER, i);
        }
    }
    
    // Process Grid B Upper
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Status[i] == ORDER_FILLED || dpB_Upper[i].isActive) {
            ProcessDP_SingleLevel(dpB_Upper[i], GRID_B, ZONE_UPPER, i);
        }
    }
    
    // Process Grid B Lower
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Lower_Status[i] == ORDER_FILLED || dpB_Lower[i].isActive) {
            ProcessDP_SingleLevel(dpB_Lower[i], GRID_B, ZONE_LOWER, i);
        }
    }
}

//+------------------------------------------------------------------+
//| PROCESS SINGLE LEVEL                                            |
//+------------------------------------------------------------------+
void ProcessDP_SingleLevel(DoubleParcelling_Level &dp, 
                            ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    
    // Skip se non attivo
    if(!dp.isActive) return;
    
    // Skip se entrambi i parcels già chiusi
    if(dp.parcelA_Closed && dp.parcelB_Closed) return;
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 0: Verifica esistenza posizione (detecta SL hit)
    // ═══════════════════════════════════════════════════════════════
    if(!PositionSelectByTicket(dp.currentTicket)) {
        // Posizione non esiste più!
        HandlePositionClosed_DP(dp, side, zone, level);
        return;
    }
    
    // Ottieni prezzo corrente
    double currentPrice = dp.positionType ? 
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 1: PARCEL A STILL OPEN - Check BOP1 and TP1
    // ═══════════════════════════════════════════════════════════════
    if(!dp.parcelA_Closed) {
        
        // --- Check BOP1 Trigger ---
        if(!dp.bop1_Activated) {
            bool bop1_Triggered = dp.positionType ? 
                                  (currentPrice >= dp.bop1_TriggerPrice) : 
                                  (currentPrice <= dp.bop1_TriggerPrice);
            
            if(bop1_Triggered) {
                // Attiva BOP1 - Sposta SL
                if(ModifyPositionSL_DP(dp.currentTicket, dp.bop1_SL_Price)) {
                    dp.bop1_Activated = true;
                    dp.currentSL = dp.bop1_SL_Price;
                    LogMessage(LOG_SUCCESS, "[DP] BOP1 Activated @ " + 
                               DoubleToString(dp.bop1_SL_Price, symbolDigits));
                }
            }
        }
        
        // --- Check TP1 Reached ---
        bool tp1_Reached = dp.positionType ? 
                           (currentPrice >= dp.tp1_Price) : 
                           (currentPrice <= dp.tp1_Price);
        
        if(tp1_Reached) {
            // Chiudi Parcel A (partial close)
            ulong newTicket = ClosePositionPartial_AndTrack(
                dp.currentTicket, 
                dp.parcelA_Lots,
                side, zone, level
            );
            
            if(newTicket != dp.currentTicket) {
                // Successo!
                dp.parcelA_Closed = true;
                dp.parcelA_CloseTime = TimeCurrent();
                dp.parcelA_Profit = CalculateParcelProfit(dp.parcelA_Lots, dp.tp1_Distance);
                
                if(newTicket > 0) {
                    dp.currentTicket = newTicket;  // Aggiorna ticket!
                    LogMessage(LOG_SUCCESS, "[DP] Parcel A closed. Profit: $" + 
                               DoubleToString(dp.parcelA_Profit, 2) +
                               ". New ticket: #" + IntegerToString(newTicket));
                    g_dp_ParcelA_Active--;
                } else {
                    // Tutta la posizione è stata chiusa
                    dp.parcelB_Closed = true;
                    dp.parcelB_CloseTime = TimeCurrent();
                    LogMessage(LOG_WARNING, "[DP] Full position closed at TP1 (unexpected)");
                    g_dp_ParcelA_Active--;
                    g_dp_ParcelB_Active--;
                }
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 2: PARCEL B OPEN - Check BOP2 and TP2
    // ═══════════════════════════════════════════════════════════════
    if(dp.parcelA_Closed && !dp.parcelB_Closed) {
        
        // Riseleziona posizione (ticket potrebbe essere cambiato)
        if(!PositionSelectByTicket(dp.currentTicket)) {
            HandlePositionClosed_DP(dp, side, zone, level);
            return;
        }
        
        currentPrice = dp.positionType ? 
                       SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                       SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        
        // --- Check BOP2 Trigger ---
        if(!dp.bop2_Activated) {
            bool bop2_Triggered = dp.positionType ? 
                                  (currentPrice >= dp.bop2_TriggerPrice) : 
                                  (currentPrice <= dp.bop2_TriggerPrice);
            
            if(bop2_Triggered) {
                // Attiva BOP2 - Sposta SL
                if(ModifyPositionSL_DP(dp.currentTicket, dp.bop2_SL_Price)) {
                    dp.bop2_Activated = true;
                    dp.currentSL = dp.bop2_SL_Price;
                    LogMessage(LOG_SUCCESS, "[DP] BOP2 Activated @ " + 
                               DoubleToString(dp.bop2_SL_Price, symbolDigits));
                }
            }
        }
        
        // --- Check TP2 Reached ---
        bool tp2_Reached = dp.positionType ? 
                           (currentPrice >= dp.tp2_Price) : 
                           (currentPrice <= dp.tp2_Price);
        
        if(tp2_Reached) {
            // Chiudi Parcel B (tutto)
            if(ClosePosition(dp.currentTicket)) {
                dp.parcelB_Closed = true;
                dp.parcelB_CloseTime = TimeCurrent();
                dp.parcelB_Profit = CalculateParcelProfit(dp.parcelB_Lots, dp.tp2_Distance);
                
                LogMessage(LOG_SUCCESS, "[DP] Parcel B closed. Profit: $" + 
                           DoubleToString(dp.parcelB_Profit, 2) +
                           ". Total: $" + DoubleToString(dp.parcelA_Profit + dp.parcelB_Profit, 2));
                
                g_dp_ParcelB_Active--;
            }
        }
    }
    
    // ═══════════════════════════════════════════════════════════════
    // STEP 3: Check if both closed → Trigger Recycling
    // ═══════════════════════════════════════════════════════════════
    if(dp.parcelA_Closed && dp.parcelB_Closed) {
        CompleteCycle_DP(dp, side, zone, level);
    }
}

//+------------------------------------------------------------------+
//| HANDLE POSITION CLOSED (By Broker SL)                           |
//+------------------------------------------------------------------+
void HandlePositionClosed_DP(DoubleParcelling_Level &dp, 
                              ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    
    // Recupera profit da history
    double profit = GetHistoricalOrderProfit(dp.currentTicket);
    
    if(!dp.parcelA_Closed) {
        // SL hit prima di TP1 - entrambi i parcels chiusi insieme
        dp.parcelA_Closed = true;
        dp.parcelB_Closed = true;
        dp.parcelA_CloseTime = TimeCurrent();
        dp.parcelB_CloseTime = TimeCurrent();
        dp.parcelA_Profit = profit / 2;
        dp.parcelB_Profit = profit / 2;
        
        LogMessage(LOG_INFO, "[DP] Position closed by SL (before TP1). Profit: $" + 
                   DoubleToString(profit, 2));
        
        g_dp_ParcelA_Active--;
        g_dp_ParcelB_Active--;
    } else {
        // SL hit su Parcel B
        dp.parcelB_Closed = true;
        dp.parcelB_CloseTime = TimeCurrent();
        dp.parcelB_Profit = profit;
        
        LogMessage(LOG_INFO, "[DP] Parcel B closed by SL (BOP). Profit: $" + 
                   DoubleToString(profit, 2));
        
        g_dp_ParcelB_Active--;
    }
    
    // Trigger recycling
    CompleteCycle_DP(dp, side, zone, level);
}

//+------------------------------------------------------------------+
//| COMPLETE CYCLE                                                  |
//+------------------------------------------------------------------+
void CompleteCycle_DP(DoubleParcelling_Level &dp, 
                       ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    
    // Update statistics
    g_dp_TotalCycles++;
    double cycleProfit = dp.parcelA_Profit + dp.parcelB_Profit;
    g_dp_TotalProfit += cycleProfit;
    
    LogMessage(LOG_SUCCESS, "[DP] Cycle completed: " + 
               GridSideToString(side) + "-" + GridZoneToString(zone) + 
               " L" + IntegerToString(level+1) +
               " | Profit: $" + DoubleToString(cycleProfit, 2) +
               " | Total cycles: " + IntegerToString(g_dp_TotalCycles));
    
    // Update grid status to allow recycling
    SetGridStatus(side, zone, level, ORDER_CLOSED_TP);
    
    // Reset DP structure
    ResetDP_Level(dp);
}

//+------------------------------------------------------------------+
//| HELPER: Modify Position SL                                      |
//+------------------------------------------------------------------+
bool ModifyPositionSL_DP(ulong ticket, double newSL) {
    if(ticket == 0) return false;
    if(!PositionSelectByTicket(ticket)) return false;
    
    newSL = NormalizeDouble(newSL, symbolDigits);
    double currentTP = PositionGetDouble(POSITION_TP);
    
    // Mantieni TP = 0 per gestione manuale
    return trade.PositionModify(ticket, newSL, 0);
}

//+------------------------------------------------------------------+
//| HELPER: Calculate Parcel Profit                                 |
//+------------------------------------------------------------------+
double CalculateParcelProfit(double lots, double distancePoints) {
    // Pip value per 1 lot = 10 per major pairs
    double pipValue = lots * 10.0;
    double pips = distancePoints / symbolPoint / 10.0;
    return pipValue * pips;
}

//+------------------------------------------------------------------+
//| IS WAITING FOR PARCEL B - Per Cyclic Reopen                     |
//+------------------------------------------------------------------+
bool IsWaitingForParcelB(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(!Enable_DoubleParcelling) return false;
    
    DoubleParcelling_Level* dp = GetDP_LevelPtr(side, zone, level);
    if(dp == NULL) return false;
    if(!dp->isActive) return false;
    
    // Se Parcel A chiuso ma B no → BLOCCA recycling
    return (dp->parcelA_Closed && !dp->parcelB_Closed);
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS                                                |
//+------------------------------------------------------------------+
string GridSideToString(ENUM_GRID_SIDE side) {
    return (side == GRID_A) ? "A" : "B";
}

string GridZoneToString(ENUM_GRID_ZONE zone) {
    return (zone == ZONE_UPPER) ? "Upper" : "Lower";
}

void SetGridStatus(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, ENUM_ORDER_STATUS status) {
    if(side == GRID_A) {
        if(zone == ZONE_UPPER) gridA_Upper_Status[level] = status;
        else gridA_Lower_Status[level] = status;
    } else {
        if(zone == ZONE_UPPER) gridB_Upper_Status[level] = status;
        else gridB_Lower_Status[level] = status;
    }
}
```

---

# 6. INTEGRAZIONI CON MODULI ESISTENTI

## 6.1 Modifiche a Sugamara.mq5

```mql5
// ═══════════════════════════════════════════════════════════════
// RIGA ~72 - Aggiungere include DOPO CloseOnProfitManager.mqh
// ═══════════════════════════════════════════════════════════════
#include "Trading/DoubleParcelling.mqh"  // v5.2 - Double Parcelling

// ═══════════════════════════════════════════════════════════════
// OnInit() - RIGA ~230 - Aggiungere inizializzazione
// ═══════════════════════════════════════════════════════════════
//--- STEP 14: Initialize Double Parcelling (v5.2) ---
if(!InitializeDoubleParcelling()) {
    Print("WARNING: Double Parcelling initialization failed");
    // Non ritornare INIT_FAILED, continua senza DP
}

// ═══════════════════════════════════════════════════════════════
// OnTick() - RIGA ~550 - Aggiungere PRIMA di MonitorPositions()
// ═══════════════════════════════════════════════════════════════
//--- v5.2: DOUBLE PARCELLING ---
if(Enable_DoubleParcelling) {
    ProcessDoubleParcelling();
}

// ═══════════════════════════════════════════════════════════════
// OnDeinit() - RIGA ~400 - Aggiungere prima del banner finale
// ═══════════════════════════════════════════════════════════════
// Deinitialize Double Parcelling
DeinitializeDoubleParcelling();
```

## 6.2 Modifiche a InputParameters.mqh

Aggiungere la sezione completa dei parametri (vedi Sezione 2.1)

## 6.3 Modifiche a GlobalVariables.mqh

```mql5
// ═══════════════════════════════════════════════════════════════
// Aggiungere DOPO la sezione Shield (circa riga 250)
// ═══════════════════════════════════════════════════════════════

//+------------------------------------------------------------------+
//| 🎯 DOUBLE PARCELLING v5.2                                        |
//+------------------------------------------------------------------+

// Forward declaration della struttura
struct DoubleParcelling_Level;

// Arrays per ogni grid/zone
DoubleParcelling_Level dpA_Upper[10];
DoubleParcelling_Level dpA_Lower[10];
DoubleParcelling_Level dpB_Upper[10];
DoubleParcelling_Level dpB_Lower[10];

// Statistics
int    g_dp_TotalCycles = 0;
double g_dp_TotalProfit = 0;
int    g_dp_ParcelA_Active = 0;
int    g_dp_ParcelB_Active = 0;
```

## 6.4 Modifiche a GridASystem.mqh

```mql5
// ═══════════════════════════════════════════════════════════════
// UpdateGridAUpperStatus() - RIGA ~301 - Dopo ORDER_FILLED detection
// ═══════════════════════════════════════════════════════════════

if(PositionSelectByTicket(ticket)) {
    gridA_Upper_Status[level] = ORDER_FILLED;
    LogGridStatus(GRID_A, ZONE_UPPER, level, "Order FILLED");
    
    // v5.2: Setup Double Parcelling
    if(Enable_DoubleParcelling) {
        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double lots = PositionGetDouble(POSITION_VOLUME);
        bool isBuy = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY;
        SetupDP_OnFill(GRID_A, ZONE_UPPER, level, ticket, entryPrice, lots, isBuy);
    }
}

// ═══════════════════════════════════════════════════════════════
// ShouldReopenGridAUpper() - RIGA ~406 - Aggiungere check DP
// ═══════════════════════════════════════════════════════════════

bool ShouldReopenGridAUpper(int level) {
    ENUM_ORDER_STATUS status = gridA_Upper_Status[level];

    // v5.2: Double Parcelling check
    if(Enable_DoubleParcelling) {
        if(IsWaitingForParcelB(GRID_A, ZONE_UPPER, level)) {
            return false;
        }
    }

    // ... resto invariato ...
}
```

## 6.5 Modifiche a GridBSystem.mqh

Stesse modifiche di GridASystem.mqh, ma per GRID_B.

## 6.6 Modifiche a PositionMonitor.mqh

```mql5
// ═══════════════════════════════════════════════════════════════
// CheckBreakOnProfit() - RIGA ~648 - Skip se DP attivo
// ═══════════════════════════════════════════════════════════════

void CheckBreakOnProfit() {
    if(!Enable_BreakOnProfit) return;
    
    // v5.2: Skip BOP if Double Parcelling is active
    // Double Parcelling ha il suo Break On Parcelling integrato
    if(Enable_DoubleParcelling) {
        return;
    }
    
    // ... resto invariato ...
}
```

## 6.7 Modifiche a OrderManager.mqh

```mql5
// ═══════════════════════════════════════════════════════════════
// Aggiungere nuova funzione DOPO ClosePosition() (circa riga 242)
// ═══════════════════════════════════════════════════════════════

//+------------------------------------------------------------------+
//| Close Partial Position and Track New Ticket                     |
//+------------------------------------------------------------------+
ulong ClosePositionPartial_AndTrack(ulong oldTicket, double lotsToClose,
                                     ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    // [Codice completo dalla Sezione 3.1]
}

//+------------------------------------------------------------------+
//| Find New Ticket After Partial Close                             |
//+------------------------------------------------------------------+
ulong FindNewTicketAfterPartialClose(string symbol, long magic, 
                                      ENUM_POSITION_TYPE posType, double expectedVolume) {
    // [Codice completo dalla Sezione 3.1]
}

//+------------------------------------------------------------------+
//| Update Grid Ticket After Partial Close                          |
//+------------------------------------------------------------------+
void UpdateGridTicket(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, ulong newTicket) {
    // [Codice completo dalla Sezione 3.1]
}
```

---

# 7. TEST CASES

## 7.1 Test Cases Obbligatori

| # | Test Case | Setup | Risultato Atteso |
|---|-----------|-------|------------------|
| 1 | TP2 raggiunto | Prezzo raggiunge TP2 | Parcel A+B chiusi, profit completo |
| 2 | TP1 + SL hit | Prezzo a TP1, poi ritraccia a BOP2 SL | Parcel A a TP1, B a SL |
| 3 | Solo BOP1 | Prezzo a 70%, poi ritraccia a BOP1 SL | Tutto chiuso a BOP1 SL, profit minimo |
| 4 | No BOP1 | Prezzo non raggiunge 70% | Nessun BE, floating |
| 5 | DP OFF | Enable_DoubleParcelling = false | Comportamento classico |
| 6 | Grid A + B | Entrambe le grid attive | Gestione indipendente |
| 7 | Restart EA | EA si riavvia durante ciclo | Recovery stato (da implementare) |
| 8 | Cambio ticket | Partial close eseguito | Nuovo ticket tracciato correttamente |
| 9 | Recycling block | Parcel A chiuso, B aperto | Nessun reopen fino a B chiuso |
| 10 | BOP2 timing | BOP2 trigger = 100% | BOP2 si attiva quando A chiude |

## 7.2 Metriche da Verificare

- [ ] Profit per ciclo corretto
- [ ] Nessun ordine "orfano"
- [ ] Recycling funzionante
- [ ] Ticket aggiornato dopo partial close
- [ ] BOP1/BOP2 attivati correttamente
- [ ] Log dettagliati per debug

---

# 8. CHECKLIST IMPLEMENTAZIONE

## Fase 1: Preparazione File
- [ ] Creare `Trading/DoubleParcelling.mqh`
- [ ] Definire struttura `DoubleParcelling_Level`
- [ ] Aggiungere parametri a `InputParameters.mqh`
- [ ] Aggiungere variabili a `GlobalVariables.mqh`

## Fase 2: Core Functions
- [ ] Implementare `InitializeDoubleParcelling()`
- [ ] Implementare `SetupDP_OnFill()`
- [ ] Implementare `ProcessDoubleParcelling()`
- [ ] Implementare `ProcessDP_SingleLevel()`
- [ ] Implementare `HandlePositionClosed_DP()`
- [ ] Implementare `CompleteCycle_DP()`

## Fase 3: Helper Functions
- [ ] Implementare `ClosePositionPartial_AndTrack()`
- [ ] Implementare `FindNewTicketAfterPartialClose()`
- [ ] Implementare `UpdateGridTicket()`
- [ ] Implementare `IsWaitingForParcelB()`
- [ ] Implementare `ModifyPositionSL_DP()`
- [ ] Implementare `CalculateParcelProfit()`

## Fase 4: Integrazioni
- [ ] Modificare `Sugamara.mq5`
- [ ] Modificare `GridASystem.mqh`
- [ ] Modificare `GridBSystem.mqh`
- [ ] Modificare `PositionMonitor.mqh`
- [ ] Modificare `OrderManager.mqh`

## Fase 5: Testing
- [ ] Test 1: TP2 raggiunto
- [ ] Test 2: TP1 + SL hit
- [ ] Test 3: Solo BOP1
- [ ] Test 4: DP OFF
- [ ] Test 5: Multi-grid
- [ ] Test 6: Cambio ticket
- [ ] Test 7: Recycling block

## Fase 6: Documentazione
- [ ] Aggiornare Dashboard con stats DP
- [ ] Logging dettagliato
- [ ] Commenti nel codice

---

# 📌 RIEPILOGO SCHEMATICO FINALE

## ✅ PROBLEMI RISOLTI

| # | Problema | Soluzione | Stato |
|---|----------|-----------|-------|
| 1 | Cambio Ticket | `ClosePositionPartial_AndTrack()` + `UpdateGridTicket()` | ✅ |
| 2 | SL dal Broker | `HandlePositionClosed_DP()` | ✅ |
| 3 | Cyclic Reopen | `IsWaitingForParcelB()` | ✅ |
| 4 | Progress BUY/SELL | Logica integrata in `ProcessDP_SingleLevel()` | ✅ |

## ✅ PARAMETRI CONFIGURABILI

| Parametro | Default | Range |
|-----------|---------|-------|
| `DP_TP1_Percent` | 100 | 50-200 |
| `DP_TP2_Percent` | 200 | 100-400 |
| `DP_BOP1_Trigger_Percent` | 70 | 50-90 |
| `DP_BOP1_SL_Percent` | 50 | 30-70 |
| `DP_BOP2_Trigger_Percent` | 100 | 80-150 |
| `DP_BOP2_SL_Percent` | 70 | 50-90 |
| `DP_LotRatio` | 50 | 30-70 |

## ✅ COMPATIBILITÀ

| Modulo | Compatibile | Note |
|--------|-------------|------|
| Cyclic Reopen | ✅ | Con check `IsWaitingForParcelB()` |
| Shield Manager | ✅ | Nessuna modifica |
| COP | ✅ | Nessuna modifica |
| BOP | ⚠️ | Auto-disabilitato se DP attivo |
| Session Manager | ✅ | Nessuna modifica |

---

**PRONTO PER IMPLEMENTAZIONE** ✅

*Documento generato da Claude*
*Data: 27 Dicembre 2025*
*Versione: SUGAMARA v5.2*
