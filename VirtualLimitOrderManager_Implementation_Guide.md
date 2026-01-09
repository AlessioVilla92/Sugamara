# VIRTUAL LIMIT ORDER MANAGER - Implementation Guide

## SUGAMARA RIBELLE v10.0 - Implementazione Completa

**Versione**: 1.0
**Data**: Gennaio 2026
**Compatibilità**: SUGAMARA RIBELLE v9.5 → v10.0
**Autore**: Sugamara Development Team

---

# INDICE

1. [Panoramica e Obiettivo](#1-panoramica-e-obiettivo)
2. [Modifiche alla Struttura File](#2-modifiche-alla-struttura-file)
3. [Nuove Enumerazioni (Enums.mqh)](#3-nuove-enumerazioni-enumsmqh)
4. [Nuovi Input Parameters](#4-nuovi-input-parameters)
5. [Nuove Variabili Globali](#5-nuove-variabili-globali)
6. [Nuovo Modulo: VirtualLimitOrderManager.mqh](#6-nuovo-modulo-virtuallimitordermanagermqh)
7. [Modifiche a GridASystem.mqh](#7-modifiche-a-gridasystemmqh)
8. [Modifiche a GridBSystem.mqh](#8-modifiche-a-gridbsystemmqh)
9. [Nuova Sezione Dashboard](#9-nuova-sezione-dashboard)
10. [Modifiche a Sugamara.mq5](#10-modifiche-a-sugaramamq5)
11. [Sistema di Recovery](#11-sistema-di-recovery)
12. [Test Cases](#12-test-cases)
13. [Checklist Implementazione](#13-checklist-implementazione)

---

# 1. PANORAMICA E OBIETTIVO

## 1.1 Problema Attuale

Nel sistema CASCADE attuale v9.5:

```
Grid A (SOLO BUY):
├── Upper Zone: BUY STOP   ← OK (fill in salita = profit in salita)
└── Lower Zone: BUY LIMIT  ← PROBLEMA (fill in discesa = loss in discesa)

Grid B (SOLO SELL):
├── Upper Zone: SELL LIMIT ← PROBLEMA (fill in salita = loss in salita)
└── Lower Zone: SELL STOP  ← OK (fill in discesa = profit in discesa)
```

**Problema**: Durante spike unidirezionali, gli ordini LIMIT vengono fillati creando posizioni contro-trend con drawdown significativo.

## 1.2 Soluzione: Virtual Limit Order Manager

Convertire gli ordini LIMIT in ordini VIRTUALI gestiti via software che diventano STOP solo dopo conferma trigger:

```
PRIMA (v9.5):
├── SELL LIMIT @ 1.0410 → Fill IMMEDIATO quando prezzo sopra = LOSS

DOPO (v10.0):
├── Virtual SELL @ 1.0410 (in memoria)
├── Trigger @ 1.0413 (+3 pips)
├── Quando prezzo >= 1.0413 → Piazza SELL STOP @ 1.0410
└── SELL STOP si filla SOLO in discesa = PROFIT
```

## 1.3 Cosa NON Cambia

- ✅ BUY STOP (Grid A Upper) - **INVARIATO**
- ✅ SELL STOP (Grid B Lower) - **INVARIATO**
- ✅ Entry prices - **IDENTICI**
- ✅ TP/SL logic - **INVARIATA**
- ✅ Recycling esistente - **INVARIATO**
- ✅ Magic numbers - **INVARIATI**

## 1.4 Cosa Cambia

- ❌ BUY LIMIT (Grid A Lower) → **VIRTUAL BUY**
- ❌ SELL LIMIT (Grid B Upper) → **VIRTUAL SELL**
- ➕ Nuova sezione Dashboard per Virtual Orders
- ➕ Nuovo modulo VirtualLimitOrderManager.mqh

---

# 2. MODIFICHE ALLA STRUTTURA FILE

## 2.1 Nuovi File da Creare

```
Sugamara/
├── Trading/
│   └── VirtualLimitOrderManager.mqh  ← NUOVO
├── Config/
│   ├── Enums.mqh                     ← MODIFICARE
│   ├── InputParameters.mqh           ← MODIFICARE
│   └── GlobalVariables.mqh           ← MODIFICARE (ora in Core/)
├── Core/
│   └── GlobalVariables.mqh           ← MODIFICARE
├── UI/
│   └── Dashboard.mqh                 ← MODIFICARE (nuova sezione)
└── Sugamara.mq5                      ← MODIFICARE
```

## 2.2 File da Modificare

| File | Tipo Modifica |
|------|---------------|
| Enums.mqh | Aggiungere ENUM_VIRTUAL_STATE |
| InputParameters.mqh | Aggiungere parametri Virtual Order |
| GlobalVariables.mqh | Aggiungere array e strutture Virtual |
| GridASystem.mqh | Modificare PlaceGridALowerOrder() |
| GridBSystem.mqh | Modificare PlaceGridBUpperOrder() |
| Dashboard.mqh | Nuova sezione VIRTUAL ORDERS MONITOR |
| Sugamara.mq5 | Aggiungere include e chiamate OnTick() |

---

# 3. NUOVE ENUMERAZIONI (Enums.mqh)

## 3.1 Aggiungere dopo ENUM_ORDER_STATUS

```mql5
//+------------------------------------------------------------------+
//| 🔄 VIRTUAL ORDER STATE - Stati ordini virtuali (v10.0)           |
//+------------------------------------------------------------------+
enum ENUM_VIRTUAL_STATE {
    VSTATE_INACTIVE = 0,        // Ordine virtuale in attesa di trigger
    VSTATE_TRIGGERED = 1,       // Trigger raggiunto, pronto per piazzamento
    VSTATE_PLACED = 2,          // Ordine STOP reale piazzato sul broker
    VSTATE_FILLED = 3,          // Ordine STOP eseguito (posizione aperta)
    VSTATE_CLOSED = 4,          // Posizione chiusa (TP/SL)
    VSTATE_TIMEOUT = 5,         // Timeout trigger (reset a INACTIVE)
    VSTATE_ERROR = 6            // Errore durante processing
};
```

## 3.2 Aggiungere costanti

```mql5
//+------------------------------------------------------------------+
//| VIRTUAL ORDER CONSTANTS (v10.0)                                  |
//+------------------------------------------------------------------+
const int VIRTUAL_TRIGGER_OFFSET_DEFAULT = 3;    // Pips sopra/sotto entry per trigger
const int VIRTUAL_TIMEOUT_SECONDS = 300;         // 5 minuti timeout trigger
const int VIRTUAL_CHECK_INTERVAL_MS = 100;       // Millisecondi tra check
```

---

# 4. NUOVI INPUT PARAMETERS

## 4.1 Aggiungere in InputParameters.mqh

Inserire dopo la sezione "GRID CONFIGURATION":

```mql5
//+------------------------------------------------------------------+
//| 🔄 VIRTUAL LIMIT ORDER MANAGER v10.0                             |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════════╗"
input group "║  🔄 VIRTUAL LIMIT ORDER MANAGER v10.0                         ║"
input group "╚═══════════════════════════════════════════════════════════════╝"

input group "    ⚡ VIRTUAL ORDER ACTIVATION"
input bool      EnableVirtualLimitOrders = true;            // ✅ Abilita Virtual Limit Orders
// Quando abilitato, BUY LIMIT e SELL LIMIT vengono gestiti virtualmente
// Gli ordini STOP reali vengono piazzati solo dopo conferma trigger

input group "    🎯 TRIGGER SETTINGS"
input double    Virtual_TriggerOffset_Pips = 3.0;           // 🎯 Trigger Offset (pips oltre entry)
// Esempio: Entry @ 1.0410, Trigger @ 1.0413 (+3 pips)
// Il SELL STOP viene piazzato @ 1.0410 quando prezzo raggiunge 1.0413

input group "    ⏱️ TIMEOUT SETTINGS"
input int       Virtual_Timeout_Seconds = 300;              // ⏱️ Timeout Trigger (secondi) [300 = 5 min]
// Se il trigger è attivo ma non viene confermato entro X secondi, reset a INACTIVE
input bool      Virtual_EnableTimeout = true;               // ✅ Abilita Timeout

input group "    📊 MONITORING"
input bool      Virtual_ShowOnChart = true;                 // ✅ Mostra livelli Virtual su Chart
input color     Virtual_TriggerColor = clrMagenta;          // 🎨 Colore linea Trigger
input color     Virtual_EntryColor = clrDarkMagenta;        // 🎨 Colore linea Entry (tratteggiata)
input bool      Virtual_DetailedLog = true;                 // 📝 Log dettagliato transizioni stato
```

---

# 5. NUOVE VARIABILI GLOBALI

## 5.1 Aggiungere in GlobalVariables.mqh

Inserire dopo la sezione "GRID STRUCTURE":

```mql5
//+------------------------------------------------------------------+
//| 🔄 VIRTUAL LIMIT ORDER MANAGER STRUCTURE v10.0                   |
//| Gestisce ordini LIMIT come virtuali con trigger+conferma         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Virtual Order Structure                                          |
//+------------------------------------------------------------------+
struct VirtualOrderStruct {
    // Identification
    int             level;              // Livello grid (0-based)
    ENUM_GRID_SIDE  gridSide;           // GRID_A o GRID_B
    ENUM_GRID_ZONE  zone;               // ZONE_UPPER o ZONE_LOWER
    
    // Prices
    double          entryPrice;         // Prezzo entry originale (dove piazzare STOP)
    double          triggerPrice;       // Prezzo trigger (quando piazzare STOP)
    double          tpPrice;            // Take Profit
    double          lots;               // Lot size
    
    // State
    ENUM_VIRTUAL_STATE state;           // Stato corrente
    datetime        triggerTime;        // Quando è stato triggerato
    datetime        lastStateChange;    // Ultimo cambio stato
    
    // Real Order (quando piazzato)
    ulong           realTicket;         // Ticket ordine reale (quando PLACED/FILLED)
    
    // Cycling
    int             cycleCount;         // Contatore cicli completati
    datetime        lastCloseTime;      // Ultimo tempo chiusura
};

//+------------------------------------------------------------------+
//| VIRTUAL ORDER ARRAYS                                             |
//| Grid A Lower = Virtual BUY (trigger quando prezzo SCENDE)        |
//| Grid B Upper = Virtual SELL (trigger quando prezzo SALE)         |
//+------------------------------------------------------------------+

// Grid A Lower - Virtual BUY orders (sostituiscono BUY LIMIT)
VirtualOrderStruct g_virtualBuy[20];
int g_virtualBuyCount = 0;

// Grid B Upper - Virtual SELL orders (sostituiscono SELL LIMIT)
VirtualOrderStruct g_virtualSell[20];
int g_virtualSellCount = 0;

//+------------------------------------------------------------------+
//| VIRTUAL ORDER STATISTICS (per Dashboard)                         |
//+------------------------------------------------------------------+
int g_virtualBuy_Inactive = 0;          // Virtual BUY in attesa
int g_virtualBuy_Triggered = 0;         // Virtual BUY triggerati
int g_virtualBuy_Placed = 0;            // Virtual BUY → BUY STOP piazzati
int g_virtualBuy_Filled = 0;            // Virtual BUY → BUY STOP fillati
int g_virtualBuy_Cycles = 0;            // Cicli completati

int g_virtualSell_Inactive = 0;         // Virtual SELL in attesa
int g_virtualSell_Triggered = 0;        // Virtual SELL triggerati
int g_virtualSell_Placed = 0;           // Virtual SELL → SELL STOP piazzati
int g_virtualSell_Filled = 0;           // Virtual SELL → SELL STOP fillati
int g_virtualSell_Cycles = 0;           // Cicli completati

//+------------------------------------------------------------------+
//| VIRTUAL ORDER RUNTIME FLAGS                                      |
//+------------------------------------------------------------------+
bool g_virtualSystemInitialized = false;
datetime g_lastVirtualCheck = 0;
```

## 5.2 Funzione di Inizializzazione Array

Aggiungere in fondo a InitializeArrays():

```mql5
//+------------------------------------------------------------------+
//| Initialize Virtual Order Arrays (v10.0)                          |
//+------------------------------------------------------------------+
void InitializeVirtualArrays() {
    // Reset Virtual BUY array
    for(int i = 0; i < 20; i++) {
        ZeroMemory(g_virtualBuy[i]);
        g_virtualBuy[i].level = i;
        g_virtualBuy[i].gridSide = GRID_A;
        g_virtualBuy[i].zone = ZONE_LOWER;
        g_virtualBuy[i].state = VSTATE_INACTIVE;
        g_virtualBuy[i].realTicket = 0;
        g_virtualBuy[i].cycleCount = 0;
    }
    g_virtualBuyCount = 0;
    
    // Reset Virtual SELL array
    for(int i = 0; i < 20; i++) {
        ZeroMemory(g_virtualSell[i]);
        g_virtualSell[i].level = i;
        g_virtualSell[i].gridSide = GRID_B;
        g_virtualSell[i].zone = ZONE_UPPER;
        g_virtualSell[i].state = VSTATE_INACTIVE;
        g_virtualSell[i].realTicket = 0;
        g_virtualSell[i].cycleCount = 0;
    }
    g_virtualSellCount = 0;
    
    // Reset statistics
    g_virtualBuy_Inactive = 0;
    g_virtualBuy_Triggered = 0;
    g_virtualBuy_Placed = 0;
    g_virtualBuy_Filled = 0;
    g_virtualBuy_Cycles = 0;
    
    g_virtualSell_Inactive = 0;
    g_virtualSell_Triggered = 0;
    g_virtualSell_Placed = 0;
    g_virtualSell_Filled = 0;
    g_virtualSell_Cycles = 0;
    
    g_virtualSystemInitialized = true;
    
    Print("[VirtualOrders] Arrays initialized - Ready for v10.0");
}
```

---

# 6. NUOVO MODULO: VirtualLimitOrderManager.mqh

## 6.1 Creare il file Trading/VirtualLimitOrderManager.mqh

```mql5
//+------------------------------------------------------------------+
//|                                    VirtualLimitOrderManager.mqh  |
//|                        Sugamara - Virtual Limit Order System     |
//|                                                                  |
//|  v10.0: Gestisce ordini LIMIT come virtuali                      |
//|  - Grid A Lower: Virtual BUY (trigger su DISCESA)                |
//|  - Grid B Upper: Virtual SELL (trigger su SALITA)                |
//|                                                                  |
//|  Gli ordini STOP reali vengono piazzati SOLO dopo trigger        |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2026"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| VIRTUAL ORDER MANAGER - INITIALIZATION                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Virtual Orders for Grid A Lower (Virtual BUY)         |
//| Chiamare dopo InitializeGridA()                                  |
//+------------------------------------------------------------------+
bool InitializeVirtualBuyOrders() {
    if(!EnableVirtualLimitOrders) return true;  // Skip se disabilitato
    
    LogMessage(LOG_INFO, "[VirtualBuy] Initializing Virtual BUY orders...");
    
    // Calcola trigger offset in points
    double triggerOffset = PipsToPoints(Virtual_TriggerOffset_Pips);
    
    for(int i = 0; i < GridLevelsPerSide; i++) {
        // Entry price = stesso del BUY LIMIT originale
        g_virtualBuy[i].entryPrice = gridA_Lower_EntryPrices[i];
        
        // Trigger price = entry - offset (trigger quando prezzo SCENDE sotto)
        // Per BUY, vogliamo triggerare quando prezzo scende SOTTO il trigger
        // poi piazzare BUY STOP che si filla quando prezzo RISALE
        g_virtualBuy[i].triggerPrice = g_virtualBuy[i].entryPrice - triggerOffset;
        
        // TP e Lots dal sistema esistente
        g_virtualBuy[i].tpPrice = gridA_Lower_TP[i];
        g_virtualBuy[i].lots = gridA_Lower_Lots[i];
        
        // Stato iniziale
        g_virtualBuy[i].state = VSTATE_INACTIVE;
        g_virtualBuy[i].triggerTime = 0;
        g_virtualBuy[i].realTicket = 0;
        g_virtualBuy[i].cycleCount = 0;
        
        if(Virtual_DetailedLog) {
            PrintFormat("[VirtualBuy] L%d: Entry=%.5f Trigger=%.5f TP=%.5f",
                        i+1, g_virtualBuy[i].entryPrice, 
                        g_virtualBuy[i].triggerPrice,
                        g_virtualBuy[i].tpPrice);
        }
    }
    
    g_virtualBuyCount = GridLevelsPerSide;
    UpdateVirtualStatistics();
    
    // Disegna linee su chart se abilitato
    if(Virtual_ShowOnChart) {
        DrawVirtualBuyLines();
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| Initialize Virtual Orders for Grid B Upper (Virtual SELL)        |
//| Chiamare dopo InitializeGridB()                                  |
//+------------------------------------------------------------------+
bool InitializeVirtualSellOrders() {
    if(!EnableVirtualLimitOrders) return true;  // Skip se disabilitato
    
    LogMessage(LOG_INFO, "[VirtualSell] Initializing Virtual SELL orders...");
    
    // Calcola trigger offset in points
    double triggerOffset = PipsToPoints(Virtual_TriggerOffset_Pips);
    
    for(int i = 0; i < GridLevelsPerSide; i++) {
        // Entry price = stesso del SELL LIMIT originale
        g_virtualSell[i].entryPrice = gridB_Upper_EntryPrices[i];
        
        // Trigger price = entry + offset (trigger quando prezzo SALE sopra)
        // Per SELL, vogliamo triggerare quando prezzo sale SOPRA il trigger
        // poi piazzare SELL STOP che si filla quando prezzo SCENDE
        g_virtualSell[i].triggerPrice = g_virtualSell[i].entryPrice + triggerOffset;
        
        // TP e Lots dal sistema esistente
        g_virtualSell[i].tpPrice = gridB_Upper_TP[i];
        g_virtualSell[i].lots = gridB_Upper_Lots[i];
        
        // Stato iniziale
        g_virtualSell[i].state = VSTATE_INACTIVE;
        g_virtualSell[i].triggerTime = 0;
        g_virtualSell[i].realTicket = 0;
        g_virtualSell[i].cycleCount = 0;
        
        if(Virtual_DetailedLog) {
            PrintFormat("[VirtualSell] L%d: Entry=%.5f Trigger=%.5f TP=%.5f",
                        i+1, g_virtualSell[i].entryPrice, 
                        g_virtualSell[i].triggerPrice,
                        g_virtualSell[i].tpPrice);
        }
    }
    
    g_virtualSellCount = GridLevelsPerSide;
    UpdateVirtualStatistics();
    
    // Disegna linee su chart se abilitato
    if(Virtual_ShowOnChart) {
        DrawVirtualSellLines();
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| VIRTUAL ORDER MANAGER - MAIN PROCESSING                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Process All Virtual Orders - Chiamare in OnTick()                |
//+------------------------------------------------------------------+
void ProcessVirtualOrders() {
    if(!EnableVirtualLimitOrders) return;
    if(!g_virtualSystemInitialized) return;
    if(systemState != STATE_ACTIVE && systemState != STATE_RUNNING) return;
    
    // Process Virtual SELL (Grid B Upper)
    ProcessVirtualSellOrders();
    
    // Process Virtual BUY (Grid A Lower)
    ProcessVirtualBuyOrders();
    
    // Update statistics for dashboard
    UpdateVirtualStatistics();
}

//+------------------------------------------------------------------+
//| Process Virtual SELL Orders (Grid B Upper)                       |
//| Trigger su SALITA, piazza SELL STOP, fill su DISCESA             |
//+------------------------------------------------------------------+
void ProcessVirtualSellOrders() {
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    for(int i = 0; i < g_virtualSellCount; i++) {
        ProcessSingleVirtualSell(i, currentBid, currentAsk);
    }
}

//+------------------------------------------------------------------+
//| Process Single Virtual SELL Order                                |
//+------------------------------------------------------------------+
void ProcessSingleVirtualSell(int level, double bid, double ask) {
    // State Machine per Virtual SELL
    switch(g_virtualSell[level].state) {
        
        //----------------------------------------------------------
        // INACTIVE: Aspetta che prezzo SALGA sopra trigger
        //----------------------------------------------------------
        case VSTATE_INACTIVE:
            // Trigger quando BID >= trigger price
            if(bid >= g_virtualSell[level].triggerPrice) {
                // TRANSIZIONE: INACTIVE → TRIGGERED
                g_virtualSell[level].state = VSTATE_TRIGGERED;
                g_virtualSell[level].triggerTime = TimeCurrent();
                g_virtualSell[level].lastStateChange = TimeCurrent();
                
                if(Virtual_DetailedLog) {
                    PrintFormat("[VirtualSell] L%d: INACTIVE → TRIGGERED | Bid=%.5f >= Trigger=%.5f",
                                level+1, bid, g_virtualSell[level].triggerPrice);
                }
                
                // Piazza immediatamente SELL STOP
                PlaceVirtualSellStop(level);
            }
            break;
            
        //----------------------------------------------------------
        // TRIGGERED: Ordine STOP deve essere piazzato
        //----------------------------------------------------------
        case VSTATE_TRIGGERED:
            // Se non ancora piazzato, riprova
            if(g_virtualSell[level].realTicket == 0) {
                PlaceVirtualSellStop(level);
            }
            
            // Check timeout
            if(Virtual_EnableTimeout) {
                if(TimeCurrent() - g_virtualSell[level].triggerTime > Virtual_Timeout_Seconds) {
                    // TRANSIZIONE: TRIGGERED → TIMEOUT → INACTIVE
                    g_virtualSell[level].state = VSTATE_INACTIVE;
                    g_virtualSell[level].triggerTime = 0;
                    g_virtualSell[level].lastStateChange = TimeCurrent();
                    
                    if(Virtual_DetailedLog) {
                        PrintFormat("[VirtualSell] L%d: TRIGGERED → TIMEOUT → INACTIVE | Timeout %d sec",
                                    level+1, Virtual_Timeout_Seconds);
                    }
                }
            }
            break;
            
        //----------------------------------------------------------
        // PLACED: SELL STOP è sul broker, aspetta fill
        //----------------------------------------------------------
        case VSTATE_PLACED:
            // Verifica se ordine è stato fillato
            if(g_virtualSell[level].realTicket > 0) {
                // Controlla se ordine esiste ancora come pending
                if(!OrderSelect(g_virtualSell[level].realTicket)) {
                    // Ordine non più pending, verifica se diventato posizione
                    if(PositionSelectByTicket(g_virtualSell[level].realTicket)) {
                        // TRANSIZIONE: PLACED → FILLED
                        g_virtualSell[level].state = VSTATE_FILLED;
                        g_virtualSell[level].lastStateChange = TimeCurrent();
                        
                        // Aggiorna anche lo stato Grid B per coerenza
                        gridB_Upper_Status[level] = ORDER_FILLED;
                        gridB_Upper_Tickets[level] = g_virtualSell[level].realTicket;
                        
                        if(Virtual_DetailedLog) {
                            PrintFormat("[VirtualSell] L%d: PLACED → FILLED | Ticket=%d",
                                        level+1, g_virtualSell[level].realTicket);
                        }
                    }
                }
            }
            break;
            
        //----------------------------------------------------------
        // FILLED: Posizione aperta, aspetta chiusura
        //----------------------------------------------------------
        case VSTATE_FILLED:
            // Verifica se posizione è stata chiusa
            if(g_virtualSell[level].realTicket > 0) {
                if(!PositionSelectByTicket(g_virtualSell[level].realTicket)) {
                    // Posizione chiusa!
                    // TRANSIZIONE: FILLED → CLOSED → INACTIVE (Recycling)
                    g_virtualSell[level].state = VSTATE_CLOSED;
                    g_virtualSell[level].lastCloseTime = TimeCurrent();
                    g_virtualSell[level].cycleCount++;
                    g_virtualSell_Cycles++;
                    
                    if(Virtual_DetailedLog) {
                        PrintFormat("[VirtualSell] L%d: FILLED → CLOSED | Cycle %d completed",
                                    level+1, g_virtualSell[level].cycleCount);
                    }
                    
                    // RECYCLING: Reset per nuovo ciclo
                    RecycleVirtualSell(level);
                }
            }
            break;
            
        //----------------------------------------------------------
        // CLOSED: Appena chiuso, transizione immediata a INACTIVE
        //----------------------------------------------------------
        case VSTATE_CLOSED:
            // Già gestito sopra, ma per sicurezza
            RecycleVirtualSell(level);
            break;
            
        //----------------------------------------------------------
        // ERROR: Errore, tentativo di recovery
        //----------------------------------------------------------
        case VSTATE_ERROR:
            // Reset a INACTIVE dopo errore
            g_virtualSell[level].state = VSTATE_INACTIVE;
            g_virtualSell[level].realTicket = 0;
            g_virtualSell[level].triggerTime = 0;
            break;
    }
}

//+------------------------------------------------------------------+
//| Place SELL STOP for Virtual SELL Order                           |
//+------------------------------------------------------------------+
bool PlaceVirtualSellStop(int level) {
    double entryPrice = g_virtualSell[level].entryPrice;
    double tp = g_virtualSell[level].tpPrice;
    double sl = 0;  // No SL come sistema esistente
    double lot = g_virtualSell[level].lots;
    
    // Valida prezzo
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // SELL STOP deve essere SOTTO prezzo corrente
    if(entryPrice >= currentBid) {
        // Prezzo non valido per SELL STOP - aspetta
        if(Virtual_DetailedLog) {
            PrintFormat("[VirtualSell] L%d: Cannot place SELL STOP - entry %.5f >= bid %.5f",
                        level+1, entryPrice, currentBid);
        }
        return false;
    }
    
    // Piazza ordine
    string comment = "VS_L" + IntegerToString(level+1);  // VS = Virtual Sell
    ulong ticket = PlacePendingOrder(
        ORDER_TYPE_SELL_STOP,
        lot,
        entryPrice,
        sl,
        tp,
        comment,
        GetGridMagic(GRID_B)
    );
    
    if(ticket > 0) {
        // TRANSIZIONE: TRIGGERED → PLACED
        g_virtualSell[level].realTicket = ticket;
        g_virtualSell[level].state = VSTATE_PLACED;
        g_virtualSell[level].lastStateChange = TimeCurrent();
        
        // Aggiorna anche Grid B per coerenza
        gridB_Upper_Tickets[level] = ticket;
        gridB_Upper_Status[level] = ORDER_PENDING;
        
        PrintFormat("[VirtualSell] ✓ L%d: SELL STOP placed @ %.5f | Ticket=%d",
                    level+1, entryPrice, ticket);
        
        return true;
    } else {
        PrintFormat("[VirtualSell] ✗ L%d: Failed to place SELL STOP @ %.5f",
                    level+1, entryPrice);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Recycle Virtual SELL Order (after close)                         |
//+------------------------------------------------------------------+
void RecycleVirtualSell(int level) {
    // Reset per nuovo ciclo
    g_virtualSell[level].state = VSTATE_INACTIVE;
    g_virtualSell[level].realTicket = 0;
    g_virtualSell[level].triggerTime = 0;
    g_virtualSell[level].lastStateChange = TimeCurrent();
    
    // Reset anche Grid B status
    gridB_Upper_Status[level] = ORDER_NONE;
    gridB_Upper_Tickets[level] = 0;
    
    if(Virtual_DetailedLog) {
        PrintFormat("[VirtualSell] L%d: RECYCLED → INACTIVE | Ready for new cycle",
                    level+1);
    }
}

//+------------------------------------------------------------------+
//| Process Virtual BUY Orders (Grid A Lower)                        |
//| Trigger su DISCESA, piazza BUY STOP, fill su SALITA              |
//+------------------------------------------------------------------+
void ProcessVirtualBuyOrders() {
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    for(int i = 0; i < g_virtualBuyCount; i++) {
        ProcessSingleVirtualBuy(i, currentBid, currentAsk);
    }
}

//+------------------------------------------------------------------+
//| Process Single Virtual BUY Order                                 |
//+------------------------------------------------------------------+
void ProcessSingleVirtualBuy(int level, double bid, double ask) {
    // State Machine per Virtual BUY
    switch(g_virtualBuy[level].state) {
        
        //----------------------------------------------------------
        // INACTIVE: Aspetta che prezzo SCENDA sotto trigger
        //----------------------------------------------------------
        case VSTATE_INACTIVE:
            // Trigger quando ASK <= trigger price
            if(ask <= g_virtualBuy[level].triggerPrice) {
                // TRANSIZIONE: INACTIVE → TRIGGERED
                g_virtualBuy[level].state = VSTATE_TRIGGERED;
                g_virtualBuy[level].triggerTime = TimeCurrent();
                g_virtualBuy[level].lastStateChange = TimeCurrent();
                
                if(Virtual_DetailedLog) {
                    PrintFormat("[VirtualBuy] L%d: INACTIVE → TRIGGERED | Ask=%.5f <= Trigger=%.5f",
                                level+1, ask, g_virtualBuy[level].triggerPrice);
                }
                
                // Piazza immediatamente BUY STOP
                PlaceVirtualBuyStop(level);
            }
            break;
            
        //----------------------------------------------------------
        // TRIGGERED: Ordine STOP deve essere piazzato
        //----------------------------------------------------------
        case VSTATE_TRIGGERED:
            // Se non ancora piazzato, riprova
            if(g_virtualBuy[level].realTicket == 0) {
                PlaceVirtualBuyStop(level);
            }
            
            // Check timeout
            if(Virtual_EnableTimeout) {
                if(TimeCurrent() - g_virtualBuy[level].triggerTime > Virtual_Timeout_Seconds) {
                    // TRANSIZIONE: TRIGGERED → TIMEOUT → INACTIVE
                    g_virtualBuy[level].state = VSTATE_INACTIVE;
                    g_virtualBuy[level].triggerTime = 0;
                    g_virtualBuy[level].lastStateChange = TimeCurrent();
                    
                    if(Virtual_DetailedLog) {
                        PrintFormat("[VirtualBuy] L%d: TRIGGERED → TIMEOUT → INACTIVE | Timeout %d sec",
                                    level+1, Virtual_Timeout_Seconds);
                    }
                }
            }
            break;
            
        //----------------------------------------------------------
        // PLACED: BUY STOP è sul broker, aspetta fill
        //----------------------------------------------------------
        case VSTATE_PLACED:
            if(g_virtualBuy[level].realTicket > 0) {
                if(!OrderSelect(g_virtualBuy[level].realTicket)) {
                    if(PositionSelectByTicket(g_virtualBuy[level].realTicket)) {
                        // TRANSIZIONE: PLACED → FILLED
                        g_virtualBuy[level].state = VSTATE_FILLED;
                        g_virtualBuy[level].lastStateChange = TimeCurrent();
                        
                        gridA_Lower_Status[level] = ORDER_FILLED;
                        gridA_Lower_Tickets[level] = g_virtualBuy[level].realTicket;
                        
                        if(Virtual_DetailedLog) {
                            PrintFormat("[VirtualBuy] L%d: PLACED → FILLED | Ticket=%d",
                                        level+1, g_virtualBuy[level].realTicket);
                        }
                    }
                }
            }
            break;
            
        //----------------------------------------------------------
        // FILLED: Posizione aperta, aspetta chiusura
        //----------------------------------------------------------
        case VSTATE_FILLED:
            if(g_virtualBuy[level].realTicket > 0) {
                if(!PositionSelectByTicket(g_virtualBuy[level].realTicket)) {
                    // Posizione chiusa!
                    g_virtualBuy[level].state = VSTATE_CLOSED;
                    g_virtualBuy[level].lastCloseTime = TimeCurrent();
                    g_virtualBuy[level].cycleCount++;
                    g_virtualBuy_Cycles++;
                    
                    if(Virtual_DetailedLog) {
                        PrintFormat("[VirtualBuy] L%d: FILLED → CLOSED | Cycle %d completed",
                                    level+1, g_virtualBuy[level].cycleCount);
                    }
                    
                    RecycleVirtualBuy(level);
                }
            }
            break;
            
        //----------------------------------------------------------
        // CLOSED / ERROR
        //----------------------------------------------------------
        case VSTATE_CLOSED:
            RecycleVirtualBuy(level);
            break;
            
        case VSTATE_ERROR:
            g_virtualBuy[level].state = VSTATE_INACTIVE;
            g_virtualBuy[level].realTicket = 0;
            g_virtualBuy[level].triggerTime = 0;
            break;
    }
}

//+------------------------------------------------------------------+
//| Place BUY STOP for Virtual BUY Order                             |
//+------------------------------------------------------------------+
bool PlaceVirtualBuyStop(int level) {
    double entryPrice = g_virtualBuy[level].entryPrice;
    double tp = g_virtualBuy[level].tpPrice;
    double sl = 0;
    double lot = g_virtualBuy[level].lots;
    
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    
    // BUY STOP deve essere SOPRA prezzo corrente
    if(entryPrice <= currentAsk) {
        if(Virtual_DetailedLog) {
            PrintFormat("[VirtualBuy] L%d: Cannot place BUY STOP - entry %.5f <= ask %.5f",
                        level+1, entryPrice, currentAsk);
        }
        return false;
    }
    
    string comment = "VB_L" + IntegerToString(level+1);  // VB = Virtual Buy
    ulong ticket = PlacePendingOrder(
        ORDER_TYPE_BUY_STOP,
        lot,
        entryPrice,
        sl,
        tp,
        comment,
        GetGridMagic(GRID_A)
    );
    
    if(ticket > 0) {
        g_virtualBuy[level].realTicket = ticket;
        g_virtualBuy[level].state = VSTATE_PLACED;
        g_virtualBuy[level].lastStateChange = TimeCurrent();
        
        gridA_Lower_Tickets[level] = ticket;
        gridA_Lower_Status[level] = ORDER_PENDING;
        
        PrintFormat("[VirtualBuy] ✓ L%d: BUY STOP placed @ %.5f | Ticket=%d",
                    level+1, entryPrice, ticket);
        
        return true;
    } else {
        PrintFormat("[VirtualBuy] ✗ L%d: Failed to place BUY STOP @ %.5f",
                    level+1, entryPrice);
        return false;
    }
}

//+------------------------------------------------------------------+
//| Recycle Virtual BUY Order                                        |
//+------------------------------------------------------------------+
void RecycleVirtualBuy(int level) {
    g_virtualBuy[level].state = VSTATE_INACTIVE;
    g_virtualBuy[level].realTicket = 0;
    g_virtualBuy[level].triggerTime = 0;
    g_virtualBuy[level].lastStateChange = TimeCurrent();
    
    gridA_Lower_Status[level] = ORDER_NONE;
    gridA_Lower_Tickets[level] = 0;
    
    if(Virtual_DetailedLog) {
        PrintFormat("[VirtualBuy] L%d: RECYCLED → INACTIVE | Ready for new cycle",
                    level+1);
    }
}

//+------------------------------------------------------------------+
//| VIRTUAL ORDER MANAGER - STATISTICS                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Virtual Order Statistics (per Dashboard)                  |
//+------------------------------------------------------------------+
void UpdateVirtualStatistics() {
    // Reset counters
    g_virtualSell_Inactive = 0;
    g_virtualSell_Triggered = 0;
    g_virtualSell_Placed = 0;
    g_virtualSell_Filled = 0;
    
    g_virtualBuy_Inactive = 0;
    g_virtualBuy_Triggered = 0;
    g_virtualBuy_Placed = 0;
    g_virtualBuy_Filled = 0;
    
    // Count Virtual SELL states
    for(int i = 0; i < g_virtualSellCount; i++) {
        switch(g_virtualSell[i].state) {
            case VSTATE_INACTIVE: g_virtualSell_Inactive++; break;
            case VSTATE_TRIGGERED: g_virtualSell_Triggered++; break;
            case VSTATE_PLACED: g_virtualSell_Placed++; break;
            case VSTATE_FILLED: g_virtualSell_Filled++; break;
        }
    }
    
    // Count Virtual BUY states
    for(int i = 0; i < g_virtualBuyCount; i++) {
        switch(g_virtualBuy[i].state) {
            case VSTATE_INACTIVE: g_virtualBuy_Inactive++; break;
            case VSTATE_TRIGGERED: g_virtualBuy_Triggered++; break;
            case VSTATE_PLACED: g_virtualBuy_Placed++; break;
            case VSTATE_FILLED: g_virtualBuy_Filled++; break;
        }
    }
}

//+------------------------------------------------------------------+
//| Get Virtual State Name (for logging/dashboard)                   |
//+------------------------------------------------------------------+
string GetVirtualStateName(ENUM_VIRTUAL_STATE state) {
    switch(state) {
        case VSTATE_INACTIVE:  return "INACTIVE";
        case VSTATE_TRIGGERED: return "TRIGGERED";
        case VSTATE_PLACED:    return "PLACED";
        case VSTATE_FILLED:    return "FILLED";
        case VSTATE_CLOSED:    return "CLOSED";
        case VSTATE_TIMEOUT:   return "TIMEOUT";
        case VSTATE_ERROR:     return "ERROR";
    }
    return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| VIRTUAL ORDER MANAGER - VISUALIZATION                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw Virtual SELL Lines on Chart                                 |
//+------------------------------------------------------------------+
void DrawVirtualSellLines() {
    if(!Virtual_ShowOnChart) return;
    
    for(int i = 0; i < g_virtualSellCount; i++) {
        string triggerName = "VIRT_SELL_TRIGGER_" + IntegerToString(i);
        string entryName = "VIRT_SELL_ENTRY_" + IntegerToString(i);
        
        // Linea Trigger (solida)
        ObjectDelete(0, triggerName);
        ObjectCreate(0, triggerName, OBJ_HLINE, 0, 0, g_virtualSell[i].triggerPrice);
        ObjectSetInteger(0, triggerName, OBJPROP_COLOR, Virtual_TriggerColor);
        ObjectSetInteger(0, triggerName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, triggerName, OBJPROP_WIDTH, 1);
        ObjectSetString(0, triggerName, OBJPROP_TEXT, "VS_T" + IntegerToString(i+1));
        
        // Linea Entry (tratteggiata)
        ObjectDelete(0, entryName);
        ObjectCreate(0, entryName, OBJ_HLINE, 0, 0, g_virtualSell[i].entryPrice);
        ObjectSetInteger(0, entryName, OBJPROP_COLOR, Virtual_EntryColor);
        ObjectSetInteger(0, entryName, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, entryName, OBJPROP_WIDTH, 1);
        ObjectSetString(0, entryName, OBJPROP_TEXT, "VS_E" + IntegerToString(i+1));
    }
}

//+------------------------------------------------------------------+
//| Draw Virtual BUY Lines on Chart                                  |
//+------------------------------------------------------------------+
void DrawVirtualBuyLines() {
    if(!Virtual_ShowOnChart) return;
    
    for(int i = 0; i < g_virtualBuyCount; i++) {
        string triggerName = "VIRT_BUY_TRIGGER_" + IntegerToString(i);
        string entryName = "VIRT_BUY_ENTRY_" + IntegerToString(i);
        
        ObjectDelete(0, triggerName);
        ObjectCreate(0, triggerName, OBJ_HLINE, 0, 0, g_virtualBuy[i].triggerPrice);
        ObjectSetInteger(0, triggerName, OBJPROP_COLOR, Virtual_TriggerColor);
        ObjectSetInteger(0, triggerName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, triggerName, OBJPROP_WIDTH, 1);
        ObjectSetString(0, triggerName, OBJPROP_TEXT, "VB_T" + IntegerToString(i+1));
        
        ObjectDelete(0, entryName);
        ObjectCreate(0, entryName, OBJ_HLINE, 0, 0, g_virtualBuy[i].entryPrice);
        ObjectSetInteger(0, entryName, OBJPROP_COLOR, Virtual_EntryColor);
        ObjectSetInteger(0, entryName, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, entryName, OBJPROP_WIDTH, 1);
        ObjectSetString(0, entryName, OBJPROP_TEXT, "VB_E" + IntegerToString(i+1));
    }
}

//+------------------------------------------------------------------+
//| Remove All Virtual Lines                                         |
//+------------------------------------------------------------------+
void RemoveVirtualLines() {
    DeleteObjectsByPrefix("VIRT_SELL_");
    DeleteObjectsByPrefix("VIRT_BUY_");
}

//+------------------------------------------------------------------+
//| VIRTUAL ORDER MANAGER - CLEANUP                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Cleanup Virtual Order System                                     |
//+------------------------------------------------------------------+
void CleanupVirtualOrders() {
    // Rimuovi linee dal chart
    RemoveVirtualLines();
    
    // Reset arrays
    InitializeVirtualArrays();
    
    g_virtualSystemInitialized = false;
    
    Print("[VirtualOrders] System cleaned up");
}
```

---

# 7. MODIFICHE A GridASystem.mqh

## 7.1 Modificare PlaceAllGridAOrders()

**PRIMA (v9.5):**
```mql5
bool PlaceAllGridAOrders() {
    LogMessage(LOG_INFO, "Placing Grid A orders...");

    int placedUpper = 0;
    int placedLower = 0;

    // Place Upper Zone Orders (BUY STOP)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(PlaceGridAUpperOrder(i)) {
            placedUpper++;
        }
    }

    // Place Lower Zone Orders (BUY LIMIT)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(PlaceGridALowerOrder(i)) {
            placedLower++;
        }
    }
    // ... resto della funzione
}
```

**DOPO (v10.0):**
```mql5
bool PlaceAllGridAOrders() {
    LogMessage(LOG_INFO, "Placing Grid A orders...");

    int placedUpper = 0;
    int placedLower = 0;

    // Place Upper Zone Orders (BUY STOP) - INVARIATO
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(PlaceGridAUpperOrder(i)) {
            placedUpper++;
        }
    }

    // v10.0: Lower Zone Orders - Virtual o Real in base a setting
    if(EnableVirtualLimitOrders) {
        // Initialize Virtual BUY orders (invece di BUY LIMIT reali)
        if(InitializeVirtualBuyOrders()) {
            placedLower = GridLevelsPerSide;  // Tutti "piazzati" come virtuali
            LogMessage(LOG_INFO, "[GridA] Lower Zone: Virtual BUY orders initialized");
        }
    } else {
        // Comportamento originale: BUY LIMIT reali
        for(int i = 0; i < GridLevelsPerSide; i++) {
            if(PlaceGridALowerOrder(i)) {
                placedLower++;
            }
        }
    }

    int totalPlaced = placedUpper + placedLower;
    int totalExpected = GridLevelsPerSide * 2;

    LogMessage(LOG_INFO, "Grid A: Placed " + IntegerToString(totalPlaced) + "/" +
               IntegerToString(totalExpected) + " orders" +
               (EnableVirtualLimitOrders ? " (Lower=VIRTUAL)" : ""));

    if(totalPlaced < totalExpected) {
        LogMessage(LOG_WARNING, "Grid A: Some orders failed to place");
        return false;
    }

    return true;
}
```

## 7.2 Modificare ReopenGridALowerOrder()

**DOPO (v10.0):**
```mql5
void ReopenGridALowerOrder(int level) {
    // v10.0: Se Virtual Limit abilitato, il recycling è gestito dal VirtualLimitOrderManager
    if(EnableVirtualLimitOrders) {
        // Il Virtual Order Manager gestisce autonomamente il recycling
        // La funzione RecycleVirtualBuy() resetta lo stato a INACTIVE
        // e il sistema ri-triggera automaticamente quando il prezzo raggiunge il trigger
        if(Virtual_DetailedLog) {
            PrintFormat("[GridA-DN] L%d: Reopen delegated to Virtual Order Manager", level+1);
        }
        return;
    }
    
    // Comportamento originale per BUY LIMIT reali
    // ... codice esistente ...
}
```

---

# 8. MODIFICHE A GridBSystem.mqh

## 8.1 Modificare PlaceAllGridBOrders()

**DOPO (v10.0):**
```mql5
bool PlaceAllGridBOrders() {
    LogMessage(LOG_INFO, "Placing Grid B orders...");

    int placedUpper = 0;
    int placedLower = 0;

    // v10.0: Upper Zone Orders - Virtual o Real in base a setting
    if(EnableVirtualLimitOrders) {
        // Initialize Virtual SELL orders (invece di SELL LIMIT reali)
        if(InitializeVirtualSellOrders()) {
            placedUpper = GridLevelsPerSide;  // Tutti "piazzati" come virtuali
            LogMessage(LOG_INFO, "[GridB] Upper Zone: Virtual SELL orders initialized");
        }
    } else {
        // Comportamento originale: SELL LIMIT reali
        for(int i = 0; i < GridLevelsPerSide; i++) {
            if(PlaceGridBUpperOrder(i)) {
                placedUpper++;
            }
        }
    }

    // Place Lower Zone Orders (SELL STOP) - INVARIATO
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(PlaceGridBLowerOrder(i)) {
            placedLower++;
        }
    }

    int totalPlaced = placedUpper + placedLower;
    int totalExpected = GridLevelsPerSide * 2;

    LogMessage(LOG_INFO, "Grid B: Placed " + IntegerToString(totalPlaced) + "/" +
               IntegerToString(totalExpected) + " orders" +
               (EnableVirtualLimitOrders ? " (Upper=VIRTUAL)" : ""));

    if(totalPlaced < totalExpected) {
        LogMessage(LOG_WARNING, "Grid B: Some orders failed to place");
        return false;
    }

    return true;
}
```

## 8.2 Modificare ReopenGridBUpperOrder()

**DOPO (v10.0):**
```mql5
void ReopenGridBUpperOrder(int level) {
    // v10.0: Se Virtual Limit abilitato, il recycling è gestito dal VirtualLimitOrderManager
    if(EnableVirtualLimitOrders) {
        if(Virtual_DetailedLog) {
            PrintFormat("[GridB-UP] L%d: Reopen delegated to Virtual Order Manager", level+1);
        }
        return;
    }
    
    // Comportamento originale per SELL LIMIT reali
    // ... codice esistente ...
}
```

---

# 9. NUOVA SEZIONE DASHBOARD

## 9.1 Aggiungere in Dashboard.mqh

Inserire una nuova funzione per la sezione Virtual Orders:

```mql5
//+------------------------------------------------------------------+
//| 🔄 VIRTUAL ORDERS MONITOR SECTION v10.0                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw Virtual Orders Monitor Panel                                |
//| Sostituisce le vecchie sezioni Grid A/Grid B dettagliate         |
//+------------------------------------------------------------------+
void DrawVirtualOrdersPanel(int startY) {
    if(!EnableVirtualLimitOrders) return;
    
    int x = Dashboard_X + 10;
    int y = startY;
    int panelWidth = TOTAL_WIDTH - 20;
    int lineHeight = LINE_HEIGHT;
    
    // Panel Background
    DashRectangle("VIRT_PANEL_BG", x-5, y-5, panelWidth, 280, CLR_PANEL_PERF);
    
    // Title
    DashLabel("VIRT_TITLE", x, y, "🔄 VIRTUAL ORDERS MONITOR", CLR_SPICE, 11, FONT_TITLE);
    y += 25;
    
    // Separator
    DashLabel("VIRT_SEP1", x, y, "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━", CLR_BORDER, 8);
    y += 15;
    
    //------------------------------------------------------------------
    // VIRTUAL SELL Section (Grid B Upper)
    //------------------------------------------------------------------
    DashLabel("VIRT_SELL_TITLE", x, y, "📉 VIRTUAL SELL (Grid B Upper)", CLR_GRID_B, 10, FONT_TITLE);
    y += lineHeight;
    
    // Statistics Row
    string sellStats = StringFormat("⚪ Inactive: %d  | 🟡 Triggered: %d  | 🟢 Placed: %d  | ✅ Filled: %d",
                                    g_virtualSell_Inactive, g_virtualSell_Triggered,
                                    g_virtualSell_Placed, g_virtualSell_Filled);
    DashLabel("VIRT_SELL_STATS", x+10, y, sellStats, CLR_DASH_TEXT, FONT_SIZE);
    y += lineHeight;
    
    // Cycles completed
    DashLabel("VIRT_SELL_CYCLES", x+10, y, "🔄 Cycles: " + IntegerToString(g_virtualSell_Cycles), CLR_PROFIT, FONT_SIZE);
    y += lineHeight + 5;
    
    // Level Details (compact)
    y += DrawVirtualOrdersTable(x, y, g_virtualSell, g_virtualSellCount, "SELL");
    
    y += 10;
    
    //------------------------------------------------------------------
    // VIRTUAL BUY Section (Grid A Lower)
    //------------------------------------------------------------------
    DashLabel("VIRT_BUY_TITLE", x, y, "📈 VIRTUAL BUY (Grid A Lower)", CLR_GRID_A, 10, FONT_TITLE);
    y += lineHeight;
    
    // Statistics Row
    string buyStats = StringFormat("⚪ Inactive: %d  | 🟡 Triggered: %d  | 🟢 Placed: %d  | ✅ Filled: %d",
                                   g_virtualBuy_Inactive, g_virtualBuy_Triggered,
                                   g_virtualBuy_Placed, g_virtualBuy_Filled);
    DashLabel("VIRT_BUY_STATS", x+10, y, buyStats, CLR_DASH_TEXT, FONT_SIZE);
    y += lineHeight;
    
    // Cycles completed
    DashLabel("VIRT_BUY_CYCLES", x+10, y, "🔄 Cycles: " + IntegerToString(g_virtualBuy_Cycles), CLR_PROFIT, FONT_SIZE);
    y += lineHeight + 5;
    
    // Level Details (compact)
    y += DrawVirtualOrdersTable(x, y, g_virtualBuy, g_virtualBuyCount, "BUY");
}

//+------------------------------------------------------------------+
//| Draw Virtual Orders Table (compact level view)                   |
//+------------------------------------------------------------------+
int DrawVirtualOrdersTable(int x, int y, VirtualOrderStruct &orders[], int count, string type) {
    int lineHeight = 14;
    int startY = y;
    int col1 = x + 10;       // Level
    int col2 = x + 50;       // State
    int col3 = x + 140;      // Entry
    int col4 = x + 220;      // Trigger
    int col5 = x + 300;      // Ticket
    
    // Header
    string prefix = "VIRT_" + type + "_TBL_";
    DashLabel(prefix + "H_LVL", col1, y, "LVL", CLR_SAND_3, 8);
    DashLabel(prefix + "H_STATE", col2, y, "STATE", CLR_SAND_3, 8);
    DashLabel(prefix + "H_ENTRY", col3, y, "ENTRY", CLR_SAND_3, 8);
    DashLabel(prefix + "H_TRIG", col4, y, "TRIGGER", CLR_SAND_3, 8);
    DashLabel(prefix + "H_TKT", col5, y, "TICKET", CLR_SAND_3, 8);
    y += lineHeight;
    
    // Show first 5 levels (or active ones)
    int shown = 0;
    for(int i = 0; i < count && shown < 5; i++) {
        // Mostra solo se non INACTIVE o se è tra i primi
        if(orders[i].state != VSTATE_INACTIVE || i < 3) {
            string levelStr = "L" + IntegerToString(i+1);
            string stateStr = GetVirtualStateShort(orders[i].state);
            string entryStr = DoubleToString(orders[i].entryPrice, symbolDigits);
            string triggerStr = DoubleToString(orders[i].triggerPrice, symbolDigits);
            string ticketStr = (orders[i].realTicket > 0) ? IntegerToString(orders[i].realTicket) : "-";
            
            color stateColor = GetVirtualStateColor(orders[i].state);
            
            DashLabel(prefix + "L" + IntegerToString(i) + "_LVL", col1, y, levelStr, CLR_DASH_TEXT, 8);
            DashLabel(prefix + "L" + IntegerToString(i) + "_STATE", col2, y, stateStr, stateColor, 8);
            DashLabel(prefix + "L" + IntegerToString(i) + "_ENTRY", col3, y, entryStr, CLR_SAND_2, 8);
            DashLabel(prefix + "L" + IntegerToString(i) + "_TRIG", col4, y, triggerStr, Virtual_TriggerColor, 8);
            DashLabel(prefix + "L" + IntegerToString(i) + "_TKT", col5, y, ticketStr, CLR_SAND_3, 8);
            
            y += lineHeight;
            shown++;
        }
    }
    
    // Show "..." if more levels exist
    if(count > 5) {
        DashLabel(prefix + "MORE", col1, y, "... +" + IntegerToString(count - 5) + " more", CLR_SAND_4, 8);
        y += lineHeight;
    }
    
    return y - startY;
}

//+------------------------------------------------------------------+
//| Get Short State Name for Table                                   |
//+------------------------------------------------------------------+
string GetVirtualStateShort(ENUM_VIRTUAL_STATE state) {
    switch(state) {
        case VSTATE_INACTIVE:  return "⚪ WAIT";
        case VSTATE_TRIGGERED: return "🟡 TRIG";
        case VSTATE_PLACED:    return "🟢 PEND";
        case VSTATE_FILLED:    return "✅ FILL";
        case VSTATE_CLOSED:    return "⬜ DONE";
        case VSTATE_TIMEOUT:   return "⏱️ TIME";
        case VSTATE_ERROR:     return "❌ ERR";
    }
    return "?";
}

//+------------------------------------------------------------------+
//| Get State Color for Dashboard                                    |
//+------------------------------------------------------------------+
color GetVirtualStateColor(ENUM_VIRTUAL_STATE state) {
    switch(state) {
        case VSTATE_INACTIVE:  return CLR_SAND_4;      // Gray
        case VSTATE_TRIGGERED: return CLR_NEUTRAL;     // Yellow
        case VSTATE_PLACED:    return CLR_ACTIVE;      // Blue
        case VSTATE_FILLED:    return CLR_PROFIT;      // Green
        case VSTATE_CLOSED:    return CLR_SILVER;      // Silver
        case VSTATE_TIMEOUT:   return CLR_SPICE;       // Orange
        case VSTATE_ERROR:     return CLR_LOSS;        // Red
    }
    return CLR_WHITE;
}

//+------------------------------------------------------------------+
//| Remove Virtual Orders Panel                                      |
//+------------------------------------------------------------------+
void RemoveVirtualOrdersPanel() {
    DeleteObjectsByPrefix("VIRT_");
}
```

## 9.2 Modificare la chiamata nel Dashboard principale

Nella funzione `UpdateDashboard()` o equivalente, aggiungere:

```mql5
void UpdateDashboard() {
    if(!ShowDashboard) return;
    
    int y = Dashboard_Y;
    
    // ... sezioni esistenti (Title, Mode, Performance, etc.) ...
    
    // v10.0: Nuova sezione Virtual Orders Monitor
    if(EnableVirtualLimitOrders) {
        DrawVirtualOrdersPanel(y);
        y += 300;  // Altezza panel Virtual Orders
    }
    
    // ... resto del dashboard ...
}
```

---

# 10. MODIFICHE A Sugamara.mq5

## 10.1 Aggiungere Include

Dopo la riga `#include "Trading/StraddleTrendingManager.mqh"`:

```mql5
// v10.0 Virtual Limit Order Manager
#include "Trading/VirtualLimitOrderManager.mqh"
```

## 10.2 Modificare OnInit()

Aggiungere dopo `InitializeArrays()`:

```mql5
//--- STEP 5.5: Initialize Virtual Order Arrays (v10.0) ---
if(EnableVirtualLimitOrders) {
    InitializeVirtualArrays();
    LogSystem("Virtual Limit Order Manager initialized");
}
```

## 10.3 Modificare OnTick()

Aggiungere dopo le chiamate di monitoring esistenti:

```mql5
void OnTick() {
    // ... codice esistente di monitoring ...
    
    //--- v10.0: Process Virtual Orders ---
    if(EnableVirtualLimitOrders) {
        ProcessVirtualOrders();
    }
    
    // ... resto di OnTick() ...
}
```

## 10.4 Modificare OnDeinit()

Aggiungere prima di `RemoveDashboard()`:

```mql5
void OnDeinit(const int reason) {
    // ... codice esistente ...
    
    //--- v10.0: Cleanup Virtual Orders ---
    if(EnableVirtualLimitOrders) {
        CleanupVirtualOrders();
    }
    
    RemoveDashboard();
    // ... resto ...
}
```

---

# 11. SISTEMA DI RECOVERY

## 11.1 Aggiungere in VirtualLimitOrderManager.mqh

```mql5
//+------------------------------------------------------------------+
//| VIRTUAL ORDER RECOVERY SYSTEM                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Save Virtual Orders State to GlobalVariables                     |
//| Chiamare periodicamente o su cambio stato                        |
//+------------------------------------------------------------------+
void SaveVirtualOrdersState() {
    string prefix = "SUGAMARA_VIRT_" + _Symbol + "_";
    
    // Salva stato Virtual SELL
    for(int i = 0; i < g_virtualSellCount; i++) {
        string key = prefix + "SELL_" + IntegerToString(i);
        // Encode: state * 1000000 + ticket
        double value = (double)g_virtualSell[i].state * 1000000.0 + (double)g_virtualSell[i].realTicket;
        GlobalVariableSet(key, value);
    }
    
    // Salva stato Virtual BUY
    for(int i = 0; i < g_virtualBuyCount; i++) {
        string key = prefix + "BUY_" + IntegerToString(i);
        double value = (double)g_virtualBuy[i].state * 1000000.0 + (double)g_virtualBuy[i].realTicket;
        GlobalVariableSet(key, value);
    }
    
    // Salva timestamp
    GlobalVariableSet(prefix + "LAST_SAVE", (double)TimeCurrent());
}

//+------------------------------------------------------------------+
//| Load Virtual Orders State from GlobalVariables                   |
//| Chiamare in OnInit() dopo recovery ordini esistenti              |
//+------------------------------------------------------------------+
bool LoadVirtualOrdersState() {
    string prefix = "SUGAMARA_VIRT_" + _Symbol + "_";
    
    // Verifica se esistono dati salvati
    if(!GlobalVariableCheck(prefix + "LAST_SAVE")) {
        Print("[VirtualRecovery] No saved state found");
        return false;
    }
    
    datetime lastSave = (datetime)GlobalVariableGet(prefix + "LAST_SAVE");
    
    // Se dati troppo vecchi (> 24 ore), ignora
    if(TimeCurrent() - lastSave > 86400) {
        Print("[VirtualRecovery] Saved state too old, ignoring");
        return false;
    }
    
    // Carica stato Virtual SELL
    for(int i = 0; i < GridLevelsPerSide; i++) {
        string key = prefix + "SELL_" + IntegerToString(i);
        if(GlobalVariableCheck(key)) {
            double value = GlobalVariableGet(key);
            int state = (int)(value / 1000000.0);
            ulong ticket = (ulong)(value - state * 1000000.0);
            
            g_virtualSell[i].state = (ENUM_VIRTUAL_STATE)state;
            g_virtualSell[i].realTicket = ticket;
            
            // Sincronizza con broker
            SyncVirtualSellWithBroker(i);
        }
    }
    
    // Carica stato Virtual BUY
    for(int i = 0; i < GridLevelsPerSide; i++) {
        string key = prefix + "BUY_" + IntegerToString(i);
        if(GlobalVariableCheck(key)) {
            double value = GlobalVariableGet(key);
            int state = (int)(value / 1000000.0);
            ulong ticket = (ulong)(value - state * 1000000.0);
            
            g_virtualBuy[i].state = (ENUM_VIRTUAL_STATE)state;
            g_virtualBuy[i].realTicket = ticket;
            
            SyncVirtualBuyWithBroker(i);
        }
    }
    
    Print("[VirtualRecovery] State loaded from ", TimeToString(lastSave));
    return true;
}

//+------------------------------------------------------------------+
//| Sync Virtual SELL with Broker (after recovery)                   |
//+------------------------------------------------------------------+
void SyncVirtualSellWithBroker(int level) {
    ulong ticket = g_virtualSell[level].realTicket;
    
    if(ticket == 0) {
        // Nessun ticket, stato deve essere INACTIVE
        if(g_virtualSell[level].state != VSTATE_INACTIVE) {
            g_virtualSell[level].state = VSTATE_INACTIVE;
        }
        return;
    }
    
    // Verifica se ordine esiste come pending
    if(OrderSelect(ticket)) {
        // Ordine pending esiste
        g_virtualSell[level].state = VSTATE_PLACED;
        gridB_Upper_Status[level] = ORDER_PENDING;
        gridB_Upper_Tickets[level] = ticket;
        Print("[VirtualRecovery] SELL L", level+1, ": Synced as PLACED (pending)");
        return;
    }
    
    // Verifica se esiste come posizione
    if(PositionSelectByTicket(ticket)) {
        // Posizione aperta
        g_virtualSell[level].state = VSTATE_FILLED;
        gridB_Upper_Status[level] = ORDER_FILLED;
        gridB_Upper_Tickets[level] = ticket;
        Print("[VirtualRecovery] SELL L", level+1, ": Synced as FILLED (position)");
        return;
    }
    
    // Ordine/posizione non trovato - probabilmente chiuso
    g_virtualSell[level].state = VSTATE_INACTIVE;
    g_virtualSell[level].realTicket = 0;
    gridB_Upper_Status[level] = ORDER_NONE;
    gridB_Upper_Tickets[level] = 0;
    Print("[VirtualRecovery] SELL L", level+1, ": Reset to INACTIVE (not found)");
}

//+------------------------------------------------------------------+
//| Sync Virtual BUY with Broker (after recovery)                    |
//+------------------------------------------------------------------+
void SyncVirtualBuyWithBroker(int level) {
    ulong ticket = g_virtualBuy[level].realTicket;
    
    if(ticket == 0) {
        if(g_virtualBuy[level].state != VSTATE_INACTIVE) {
            g_virtualBuy[level].state = VSTATE_INACTIVE;
        }
        return;
    }
    
    if(OrderSelect(ticket)) {
        g_virtualBuy[level].state = VSTATE_PLACED;
        gridA_Lower_Status[level] = ORDER_PENDING;
        gridA_Lower_Tickets[level] = ticket;
        Print("[VirtualRecovery] BUY L", level+1, ": Synced as PLACED (pending)");
        return;
    }
    
    if(PositionSelectByTicket(ticket)) {
        g_virtualBuy[level].state = VSTATE_FILLED;
        gridA_Lower_Status[level] = ORDER_FILLED;
        gridA_Lower_Tickets[level] = ticket;
        Print("[VirtualRecovery] BUY L", level+1, ": Synced as FILLED (position)");
        return;
    }
    
    g_virtualBuy[level].state = VSTATE_INACTIVE;
    g_virtualBuy[level].realTicket = 0;
    gridA_Lower_Status[level] = ORDER_NONE;
    gridA_Lower_Tickets[level] = 0;
    Print("[VirtualRecovery] BUY L", level+1, ": Reset to INACTIVE (not found)");
}

//+------------------------------------------------------------------+
//| Clear Virtual Orders State from GlobalVariables                  |
//+------------------------------------------------------------------+
void ClearVirtualOrdersState() {
    string prefix = "SUGAMARA_VIRT_" + _Symbol + "_";
    
    for(int i = 0; i < 20; i++) {
        GlobalVariableDel(prefix + "SELL_" + IntegerToString(i));
        GlobalVariableDel(prefix + "BUY_" + IntegerToString(i));
    }
    GlobalVariableDel(prefix + "LAST_SAVE");
    
    Print("[VirtualRecovery] Saved state cleared");
}
```

---

# 12. TEST CASES

## 12.1 Test Case 1: Spike UP Senza Ritracciamento

```
SCENARIO:
- Entry Point: 1.04000
- Virtual SELL L1: Entry=1.04100, Trigger=1.04130
- Prezzo sale da 1.04000 a 1.04200 senza tornare sotto 1.04100

COMPORTAMENTO ATTESO:
1. Prezzo raggiunge 1.04100 → BUY STOP L1 fill
2. Prezzo raggiunge 1.04130 → Virtual SELL L1: TRIGGERED
3. Sistema piazza SELL STOP @ 1.04100
4. Prezzo continua a salire, SELL STOP resta PENDENTE
5. ZERO posizioni SELL aperte = ZERO drawdown SELL

VERIFICA:
[ ] Virtual SELL L1 stato = PLACED
[ ] SELL STOP @ 1.04100 esiste sul broker
[ ] Nessun fill SELL
```

## 12.2 Test Case 2: Spike UP con Ritracciamento

```
SCENARIO:
- Entry Point: 1.04000
- Virtual SELL L1: Entry=1.04100, Trigger=1.04130
- Prezzo sale a 1.04150, poi scende a 1.04050

COMPORTAMENTO ATTESO:
1. Prezzo 1.04130 → TRIGGERED, piazza SELL STOP @ 1.04100
2. Prezzo scende a 1.04100 → SELL STOP fill
3. Prezzo scende a 1.04050 → SELL in profit
4. TP raggiunto → SELL chiuso
5. Virtual SELL L1 → INACTIVE (recycled)

VERIFICA:
[ ] SELL fillato @ 1.04100 (o meglio per slippage)
[ ] TP eseguito
[ ] Virtual SELL L1 tornato INACTIVE
[ ] Ciclo incrementato
```

## 12.3 Test Case 3: Recovery dopo Restart

```
SCENARIO:
- EA attivo con Virtual SELL L1 stato PLACED (ticket 12345)
- EA viene fermato/riavviato
- Ordine 12345 ancora sul broker

COMPORTAMENTO ATTESO:
1. OnInit() chiama LoadVirtualOrdersState()
2. Trova ticket 12345 salvato
3. SyncVirtualSellWithBroker() verifica ordine esiste
4. Virtual SELL L1 ripristinato come PLACED
5. Monitoraggio continua normalmente

VERIFICA:
[ ] Stato caricato correttamente
[ ] Ordine sincronizzato con broker
[ ] Nessun ordine duplicato
```

---

# 13. CHECKLIST IMPLEMENTAZIONE

```
[ ] FASE 1: STRUTTURE DATI
    [ ] Aggiungere ENUM_VIRTUAL_STATE in Enums.mqh
    [ ] Aggiungere costanti VIRTUAL_* in Enums.mqh
    [ ] Aggiungere input parameters in InputParameters.mqh
    [ ] Aggiungere VirtualOrderStruct in GlobalVariables.mqh
    [ ] Aggiungere array g_virtualSell[] e g_virtualBuy[]
    [ ] Aggiungere variabili statistiche

[ ] FASE 2: MODULO PRINCIPALE
    [ ] Creare Trading/VirtualLimitOrderManager.mqh
    [ ] Implementare InitializeVirtualBuyOrders()
    [ ] Implementare InitializeVirtualSellOrders()
    [ ] Implementare ProcessVirtualOrders()
    [ ] Implementare ProcessSingleVirtualSell()
    [ ] Implementare ProcessSingleVirtualBuy()
    [ ] Implementare PlaceVirtualSellStop()
    [ ] Implementare PlaceVirtualBuyStop()
    [ ] Implementare RecycleVirtualSell()
    [ ] Implementare RecycleVirtualBuy()

[ ] FASE 3: INTEGRAZIONE GRID SYSTEMS
    [ ] Modificare PlaceAllGridAOrders() in GridASystem.mqh
    [ ] Modificare PlaceAllGridBOrders() in GridBSystem.mqh
    [ ] Modificare ReopenGridALowerOrder()
    [ ] Modificare ReopenGridBUpperOrder()

[ ] FASE 4: DASHBOARD
    [ ] Aggiungere DrawVirtualOrdersPanel() in Dashboard.mqh
    [ ] Aggiungere DrawVirtualOrdersTable()
    [ ] Aggiungere helper functions (GetVirtualStateShort, GetVirtualStateColor)
    [ ] Integrare in UpdateDashboard()

[ ] FASE 5: FILE PRINCIPALE
    [ ] Aggiungere #include per VirtualLimitOrderManager.mqh
    [ ] Modificare OnInit()
    [ ] Modificare OnTick()
    [ ] Modificare OnDeinit()

[ ] FASE 6: RECOVERY
    [ ] Implementare SaveVirtualOrdersState()
    [ ] Implementare LoadVirtualOrdersState()
    [ ] Implementare SyncVirtualSellWithBroker()
    [ ] Implementare SyncVirtualBuyWithBroker()
    [ ] Integrare in RecoveryManager.mqh

[ ] FASE 7: TESTING
    [ ] Test spike UP senza ritracciamento
    [ ] Test spike UP con ritracciamento
    [ ] Test spike DOWN
    [ ] Test timeout trigger
    [ ] Test recovery dopo restart
    [ ] Test recycling completo
    [ ] Test dashboard visualization

[ ] FASE 8: DOCUMENTAZIONE
    [ ] Aggiornare versione a v10.0
    [ ] Aggiornare changelog
    [ ] Aggiornare header file principale
```

---

# APPENDICE: RIEPILOGO MODIFICHE

## File Modificati

| File | Linee Aggiunte | Linee Modificate |
|------|---------------|------------------|
| Enums.mqh | ~20 | 0 |
| InputParameters.mqh | ~25 | 0 |
| GlobalVariables.mqh | ~80 | ~10 |
| GridASystem.mqh | ~20 | ~15 |
| GridBSystem.mqh | ~20 | ~15 |
| Dashboard.mqh | ~150 | ~10 |
| Sugamara.mq5 | ~15 | ~5 |
| **NUOVO: VirtualLimitOrderManager.mqh** | ~600 | N/A |

## Garanzie Mantenute

- ✅ BUY STOP (Grid A Upper) - **INVARIATO**
- ✅ SELL STOP (Grid B Lower) - **INVARIATO**
- ✅ Entry prices - **IDENTICI**
- ✅ TP logic - **INVARIATA**
- ✅ Magic numbers - **INVARIATI**
- ✅ Recycling esistente - **FUNZIONANTE**
- ✅ Recovery ordini reali - **FUNZIONANTE**

---

**FINE DOCUMENTO**

*Virtual Limit Order Manager Implementation Guide v1.0*
*SUGAMARA RIBELLE v10.0*
*Sugamara Development Team - Gennaio 2026*
