# SUGAMARA v5.1 - IMPLEMENTAZIONI COMPLETE

## 📋 INDICE

1. [Breakeven Lock 70%](#1-breakeven-lock-70)
2. [Close On Profit System](#2-close-on-profit-system)
3. [Dashboard Box Close On Profit](#3-dashboard-box-close-on-profit)
4. [Logging Migliorato](#4-logging-migliorato)
5. [Grid Visualization con Colori](#5-grid-visualization-con-colori)
6. [Gestione Lotti Differenziata](#6-gestione-lotti-differenziata-stop-vs-limit)

---

# 1. BREAKEVEN LOCK 70%

## 1.1 Concetto

Quando una posizione raggiunge il 70% del suo Take Profit:
1. **Chiude il 50%** della posizione (lock profit immediato)
2. **Sposta lo SL a Entry Price** (breakeven) per il 50% rimanente

## 1.2 Nuovi Parametri - Aggiungere in `InputParameters.mqh`

```mql5
//+------------------------------------------------------------------+
//| 💰 BREAKEVEN LOCK SETTINGS (v5.1)                                |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  💰 BREAKEVEN LOCK SYSTEM (v5.1)                          ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool      Enable_BreakevenLock = true;                // ✅ Abilita Breakeven Lock
input double    BE_Lock_TriggerPercent = 70.0;              // 📊 Trigger: % verso TP (70%)
input double    BE_Lock_ClosePercent = 50.0;                // 📉 Chiudi % posizione al trigger
input double    BE_Lock_Offset_Pips = 0.5;                  // 📏 Offset BE sopra entry (protezione spread)
input bool      BE_Lock_ApplyToShield = true;               // 🛡️ Applica anche a Shield
```

## 1.3 Nuova Struttura - Aggiungere in `GlobalVariables.mqh`

```mql5
//+------------------------------------------------------------------+
//| BREAKEVEN LOCK TRACKING STRUCTURE                                |
//+------------------------------------------------------------------+

struct BreakevenLockTracker {
    ulong    ticket;                    // Ticket posizione
    double   original_lot;              // Lot originale
    double   current_lot;               // Lot attuale (dopo partial close)
    double   entry_price;               // Prezzo entry
    double   tp_price;                  // Prezzo TP
    double   trigger_price;             // Prezzo trigger (70% verso TP)
    bool     partial_closed;            // Partial già eseguito
    bool     be_set;                    // Breakeven già impostato
    double   profit_locked;             // Profit bloccato dalla chiusura parziale
    datetime trigger_time;              // Quando è stato triggerato
};

// Arrays per tracking
BreakevenLockTracker beLock_GridA_Upper[];
BreakevenLockTracker beLock_GridA_Lower[];
BreakevenLockTracker beLock_GridB_Upper[];
BreakevenLockTracker beLock_GridB_Lower[];
BreakevenLockTracker beLock_Shield;

// Statistiche globali
double totalBELockProfit = 0.0;         // Profit totale da BE Lock
int beLock_Executions = 0;              // Numero esecuzioni
int beLock_BETriggered = 0;             // Quante volte BE ha salvato da loss
```

## 1.4 Nuovo File: `BreakevenLockManager.mqh`

Creare nuovo file nella cartella `Trading/`:

```mql5
//+------------------------------------------------------------------+
//|                                         BreakevenLockManager.mqh |
//|                        Sugamara v5.1 - Breakeven Lock System     |
//|                                                                  |
//|  Al 70% del TP: Chiude 50% + Sposta SL a Entry (Breakeven)       |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Initialize Breakeven Lock Manager                                |
//+------------------------------------------------------------------+
bool InitializeBreakevenLockManager() {
    if(!Enable_BreakevenLock) {
        Print("INFO: Breakeven Lock is DISABLED");
        return true;
    }

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  INITIALIZING BREAKEVEN LOCK MANAGER v5.1");
    Print("═══════════════════════════════════════════════════════════════════");

    // Resize arrays
    ArrayResize(beLock_GridA_Upper, GridLevelsPerSide);
    ArrayResize(beLock_GridA_Lower, GridLevelsPerSide);
    ArrayResize(beLock_GridB_Upper, GridLevelsPerSide);
    ArrayResize(beLock_GridB_Lower, GridLevelsPerSide);

    // Initialize all trackers
    for(int i = 0; i < GridLevelsPerSide; i++) {
        ResetBELockTracker(beLock_GridA_Upper[i]);
        ResetBELockTracker(beLock_GridA_Lower[i]);
        ResetBELockTracker(beLock_GridB_Upper[i]);
        ResetBELockTracker(beLock_GridB_Lower[i]);
    }

    ResetBELockTracker(beLock_Shield);

    totalBELockProfit = 0.0;
    beLock_Executions = 0;
    beLock_BETriggered = 0;

    Print("  Trigger Level: ", DoubleToString(BE_Lock_TriggerPercent, 0), "% verso TP");
    Print("  Close Amount: ", DoubleToString(BE_Lock_ClosePercent, 0), "% della posizione");
    Print("  BE Offset: ", DoubleToString(BE_Lock_Offset_Pips, 1), " pips sopra entry");
    Print("  Apply to Shield: ", BE_Lock_ApplyToShield ? "YES" : "NO");
    Print("═══════════════════════════════════════════════════════════════════");

    return true;
}

//+------------------------------------------------------------------+
//| Reset Single BE Lock Tracker                                     |
//+------------------------------------------------------------------+
void ResetBELockTracker(BreakevenLockTracker &tracker) {
    tracker.ticket = 0;
    tracker.original_lot = 0;
    tracker.current_lot = 0;
    tracker.entry_price = 0;
    tracker.tp_price = 0;
    tracker.trigger_price = 0;
    tracker.partial_closed = false;
    tracker.be_set = false;
    tracker.profit_locked = 0;
    tracker.trigger_time = 0;
}

//+------------------------------------------------------------------+
//| Setup BE Lock Tracking for a Position                            |
//+------------------------------------------------------------------+
void SetupBELockTracking(ulong ticket, double entry, double tp, double lot,
                          ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {

    if(!Enable_BreakevenLock) return;

    BreakevenLockTracker tracker;
    tracker.ticket = ticket;
    tracker.original_lot = lot;
    tracker.current_lot = lot;
    tracker.entry_price = entry;
    tracker.tp_price = tp;
    tracker.partial_closed = false;
    tracker.be_set = false;
    tracker.profit_locked = 0;
    tracker.trigger_time = 0;

    // Calculate trigger price (70% towards TP)
    double distance = MathAbs(tp - entry);
    double triggerDistance = distance * BE_Lock_TriggerPercent / 100.0;

    if(tp > entry) {
        // LONG position
        tracker.trigger_price = entry + triggerDistance;
    } else {
        // SHORT position
        tracker.trigger_price = entry - triggerDistance;
    }

    // Store in appropriate array
    if(side == GRID_A) {
        if(zone == ZONE_UPPER) beLock_GridA_Upper[level] = tracker;
        else beLock_GridA_Lower[level] = tracker;
    } else {
        if(zone == ZONE_UPPER) beLock_GridB_Upper[level] = tracker;
        else beLock_GridB_Lower[level] = tracker;
    }

    if(DetailedLogging) {
        Print("[BE LOCK] Setup: Ticket ", ticket,
              " | Entry: ", DoubleToString(entry, _Digits),
              " | TP: ", DoubleToString(tp, _Digits),
              " | Trigger (70%): ", DoubleToString(tracker.trigger_price, _Digits));
    }
}

//+------------------------------------------------------------------+
//| Setup BE Lock for Shield Position                                |
//+------------------------------------------------------------------+
void SetupBELockShield(ulong ticket, double entry, double tp, double lot) {
    if(!Enable_BreakevenLock || !BE_Lock_ApplyToShield) return;

    beLock_Shield.ticket = ticket;
    beLock_Shield.original_lot = lot;
    beLock_Shield.current_lot = lot;
    beLock_Shield.entry_price = entry;
    beLock_Shield.tp_price = tp;
    beLock_Shield.partial_closed = false;
    beLock_Shield.be_set = false;
    beLock_Shield.profit_locked = 0;

    double distance = MathAbs(tp - entry);
    double triggerDistance = distance * BE_Lock_TriggerPercent / 100.0;

    if(tp > entry) {
        beLock_Shield.trigger_price = entry + triggerDistance;
    } else {
        beLock_Shield.trigger_price = entry - triggerDistance;
    }

    Print("[BE LOCK] Shield setup: Trigger @ ", DoubleToString(beLock_Shield.trigger_price, _Digits));
}

//+------------------------------------------------------------------+
//| Process All BE Lock Checks - Call from OnTick()                  |
//+------------------------------------------------------------------+
void ProcessBreakevenLocks() {
    if(!Enable_BreakevenLock) return;

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Process Grid A
    for(int i = 0; i < GridLevelsPerSide; i++) {
        ProcessSingleBELock(beLock_GridA_Upper[i], currentPrice);
        ProcessSingleBELock(beLock_GridA_Lower[i], currentPrice);
    }

    // Process Grid B
    for(int i = 0; i < GridLevelsPerSide; i++) {
        ProcessSingleBELock(beLock_GridB_Upper[i], currentPrice);
        ProcessSingleBELock(beLock_GridB_Lower[i], currentPrice);
    }

    // Process Shield
    if(BE_Lock_ApplyToShield && beLock_Shield.ticket > 0) {
        ProcessSingleBELock(beLock_Shield, currentPrice);
    }
}

//+------------------------------------------------------------------+
//| Process Single Position for BE Lock                              |
//+------------------------------------------------------------------+
void ProcessSingleBELock(BreakevenLockTracker &tracker, double currentPrice) {
    if(tracker.ticket == 0) return;
    if(tracker.partial_closed && tracker.be_set) return;  // Already fully processed

    // Check if position still exists
    if(!PositionSelectByTicket(tracker.ticket)) {
        // Position closed (probably by TP)
        return;
    }

    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    bool isLong = (posType == POSITION_TYPE_BUY);

    // Check if trigger price reached
    bool triggerReached = false;
    if(isLong) {
        triggerReached = (currentPrice >= tracker.trigger_price);
    } else {
        triggerReached = (currentPrice <= tracker.trigger_price);
    }

    if(triggerReached && !tracker.partial_closed) {
        // Execute partial close + set BE
        ExecuteBELock(tracker, isLong);
    }
}

//+------------------------------------------------------------------+
//| Execute BE Lock: Partial Close + Set Breakeven                   |
//+------------------------------------------------------------------+
void ExecuteBELock(BreakevenLockTracker &tracker, bool isLong) {
    if(!PositionSelectByTicket(tracker.ticket)) return;

    double lotToClose = NormalizeDouble(tracker.original_lot * BE_Lock_ClosePercent / 100.0, 2);
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    
    if(lotToClose < minLot) lotToClose = minLot;
    if(lotToClose > tracker.current_lot) lotToClose = tracker.current_lot;

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  🔒 BREAKEVEN LOCK TRIGGERED @ 70%");
    Print("───────────────────────────────────────────────────────────────────");
    Print("  Ticket: ", tracker.ticket);
    Print("  Entry: ", DoubleToString(tracker.entry_price, _Digits));
    Print("  TP: ", DoubleToString(tracker.tp_price, _Digits));
    Print("  Trigger Price: ", DoubleToString(tracker.trigger_price, _Digits));
    Print("  Closing: ", DoubleToString(lotToClose, 2), " lot (", BE_Lock_ClosePercent, "%)");

    // STEP 1: Execute partial close
    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.action = TRADE_ACTION_DEAL;
    request.position = tracker.ticket;
    request.symbol = _Symbol;
    request.volume = lotToClose;
    request.deviation = Slippage;

    if(isLong) {
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    } else {
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    }

    request.comment = "SUGAMARA_BE_LOCK";

    bool partialSuccess = false;

    if(OrderSend(request, result)) {
        if(result.retcode == TRADE_RETCODE_DONE) {
            tracker.current_lot -= lotToClose;
            tracker.partial_closed = true;
            tracker.trigger_time = TimeCurrent();

            // Calculate locked profit
            double priceDiff = result.price - tracker.entry_price;
            if(!isLong) priceDiff = -priceDiff;
            
            double profit = priceDiff * lotToClose * 
                           SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) /
                           SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

            tracker.profit_locked = profit;
            totalBELockProfit += profit;
            beLock_Executions++;

            Print("  ✅ Partial Close SUCCESS");
            Print("  Profit Locked: $", DoubleToString(profit, 2));
            Print("  Remaining Lot: ", DoubleToString(tracker.current_lot, 2));

            partialSuccess = true;
        }
    } else {
        Print("  ❌ Partial Close FAILED - Error: ", result.retcode);
    }

    // STEP 2: Set Breakeven on remaining position
    if(partialSuccess && tracker.current_lot > 0) {
        SetBreakevenSL(tracker, isLong);
    }

    Print("═══════════════════════════════════════════════════════════════════");

    if(EnableAlerts && partialSuccess) {
        Alert("SUGAMARA: BE Lock Triggered - Locked $", DoubleToString(tracker.profit_locked, 2));
    }
}

//+------------------------------------------------------------------+
//| Set Breakeven Stop Loss on Remaining Position                    |
//+------------------------------------------------------------------+
void SetBreakevenSL(BreakevenLockTracker &tracker, bool isLong) {
    if(!PositionSelectByTicket(tracker.ticket)) return;

    // Calculate BE price with small offset for spread protection
    double bePrice;
    double offset = PipsToPoints(BE_Lock_Offset_Pips);

    if(isLong) {
        bePrice = tracker.entry_price + offset;  // Slightly above entry
    } else {
        bePrice = tracker.entry_price - offset;  // Slightly below entry
    }

    bePrice = NormalizeDouble(bePrice, _Digits);

    // Modify position SL
    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.action = TRADE_ACTION_SLTP;
    request.position = tracker.ticket;
    request.symbol = _Symbol;
    request.sl = bePrice;
    request.tp = tracker.tp_price;  // Keep original TP

    if(OrderSend(request, result)) {
        if(result.retcode == TRADE_RETCODE_DONE) {
            tracker.be_set = true;
            Print("  ✅ Breakeven SL Set @ ", DoubleToString(bePrice, _Digits));
            Print("  Remaining position protected!");
        } else {
            Print("  ⚠️ BE SL Set returned: ", result.retcode);
        }
    } else {
        Print("  ❌ Failed to set BE SL - Error: ", GetLastError());
    }
}

//+------------------------------------------------------------------+
//| Check if BE Saved from Loss (Statistics)                         |
//+------------------------------------------------------------------+
void CheckBESavedFromLoss(ulong ticket, double closePrice) {
    // Called when a position closes at BE
    // Check all trackers for this ticket
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(beLock_GridA_Upper[i].ticket == ticket && beLock_GridA_Upper[i].be_set) {
            if(MathAbs(closePrice - beLock_GridA_Upper[i].entry_price) < PipsToPoints(1.0)) {
                beLock_BETriggered++;
                Print("[BE LOCK] ✅ Breakeven SAVED position from potential loss!");
            }
        }
        // Repeat for other arrays...
    }
}

//+------------------------------------------------------------------+
//| Clear BE Lock Tracker for Closed Position                        |
//+------------------------------------------------------------------+
void ClearBELockTracker(ulong ticket) {
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(beLock_GridA_Upper[i].ticket == ticket) ResetBELockTracker(beLock_GridA_Upper[i]);
        if(beLock_GridA_Lower[i].ticket == ticket) ResetBELockTracker(beLock_GridA_Lower[i]);
        if(beLock_GridB_Upper[i].ticket == ticket) ResetBELockTracker(beLock_GridB_Upper[i]);
        if(beLock_GridB_Lower[i].ticket == ticket) ResetBELockTracker(beLock_GridB_Lower[i]);
    }

    if(beLock_Shield.ticket == ticket) ResetBELockTracker(beLock_Shield);
}

//+------------------------------------------------------------------+
//| Get BE Lock Statistics                                           |
//+------------------------------------------------------------------+
double GetTotalBELockProfit() {
    return totalBELockProfit;
}

int GetBELockExecutions() {
    return beLock_Executions;
}

int GetBELockSaves() {
    return beLock_BETriggered;
}

//+------------------------------------------------------------------+
//| Deinitialize BE Lock Manager                                     |
//+------------------------------------------------------------------+
void DeinitializeBreakevenLockManager() {
    ArrayFree(beLock_GridA_Upper);
    ArrayFree(beLock_GridA_Lower);
    ArrayFree(beLock_GridB_Upper);
    ArrayFree(beLock_GridB_Lower);

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  BREAKEVEN LOCK MANAGER - FINAL STATISTICS");
    Print("───────────────────────────────────────────────────────────────────");
    Print("  Total Profit Locked: $", DoubleToString(totalBELockProfit, 2));
    Print("  Total Executions: ", beLock_Executions);
    Print("  Times BE Saved from Loss: ", beLock_BETriggered);
    Print("═══════════════════════════════════════════════════════════════════");
}
```

## 1.5 Integrazione in `Sugamara.mq5`

### Aggiungere include:
```mql5
#include "Trading/BreakevenLockManager.mqh"
```

### In OnInit():
```mql5
//--- STEP 11: Initialize Breakeven Lock Manager (v5.1) ---
if(!InitializeBreakevenLockManager()) {
    Print("WARNING: Failed to initialize Breakeven Lock Manager");
}
```

### In OnTick():
```mql5
//--- v5.1: PROCESS BREAKEVEN LOCKS ---
ProcessBreakevenLocks();
```

### In OnDeinit():
```mql5
DeinitializeBreakevenLockManager();
```

---

# 2. CLOSE ON PROFIT SYSTEM

## 2.1 Concetto

Chiude automaticamente tutte le posizioni quando il profitto netto giornaliero (realizzato + floating - commissioni - spread) raggiunge un target configurato.

## 2.2 Nuovi Parametri - Aggiungere in `InputParameters.mqh`

```mql5
//+------------------------------------------------------------------+
//| 💵 CLOSE ON PROFIT SETTINGS (v5.1)                               |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  💵 CLOSE ON PROFIT SYSTEM (v5.1)                         ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool      Enable_CloseOnProfit = true;                // ✅ Abilita Close On Profit
input double    COP_DailyTarget_USD = 20.0;                 // 💰 Target Giornaliero (USD)
input bool      COP_IncludeFloating = true;                 // 📊 Includi Floating P/L
input bool      COP_DeductCommissions = true;               // 💳 Sottrai Commissioni
input bool      COP_DeductSpread = true;                    // 📉 Sottrai Costo Spread Stimato

input group "    💳 BROKER COST SETTINGS"
input double    COP_CommissionPerLot = 3.50;                // 💳 Commissione per Lot (round trip USD)
input double    COP_EstimatedSpreadPips = 0.2;              // 📉 Spread Medio Stimato (pips)

input group "    ⚙️ BEHAVIOR SETTINGS"
input bool      COP_ClosePositions = true;                  // ❌ Chiudi Posizioni al Target
input bool      COP_DeletePending = true;                   // 🗑️ Cancella Pending al Target
input bool      COP_PauseTrading = true;                    // ⏸️ Pausa Trading dopo Target
input bool      COP_AlertOnTarget = true;                   // 🔔 Alert al Raggiungimento
```

## 2.3 Nuove Variabili Globali - Aggiungere in `GlobalVariables.mqh`

```mql5
//+------------------------------------------------------------------+
//| CLOSE ON PROFIT TRACKING                                         |
//+------------------------------------------------------------------+

// P/L Components
double cop_RealizedProfit = 0.0;        // Profitto realizzato (chiusure)
double cop_FloatingProfit = 0.0;        // Profitto floating (posizioni aperte)
double cop_TotalCommissions = 0.0;      // Commissioni totali stimate
double cop_TotalSpreadCost = 0.0;       // Costo spread totale stimato
double cop_NetProfit = 0.0;             // Profitto Netto Finale

// Status
bool cop_TargetReached = false;         // Target raggiunto oggi
datetime cop_TargetReachedTime = 0;     // Quando è stato raggiunto
int cop_TradesToday = 0;                // Trades eseguiti oggi

// Daily Reset
datetime cop_LastResetDate = 0;         // Ultima data reset
```

## 2.4 Nuovo File: `CloseOnProfitManager.mqh`

Creare nuovo file nella cartella `Trading/`:

```mql5
//+------------------------------------------------------------------+
//|                                        CloseOnProfitManager.mqh  |
//|                        Sugamara v5.1 - Close On Profit System    |
//|                                                                  |
//|  Chiude tutto quando P/L netto raggiunge target giornaliero      |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Initialize Close On Profit Manager                               |
//+------------------------------------------------------------------+
bool InitializeCloseOnProfitManager() {
    if(!Enable_CloseOnProfit) {
        Print("INFO: Close On Profit is DISABLED");
        return true;
    }

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  INITIALIZING CLOSE ON PROFIT MANAGER v5.1");
    Print("═══════════════════════════════════════════════════════════════════");

    // Reset all values
    cop_RealizedProfit = 0.0;
    cop_FloatingProfit = 0.0;
    cop_TotalCommissions = 0.0;
    cop_TotalSpreadCost = 0.0;
    cop_NetProfit = 0.0;
    cop_TargetReached = false;
    cop_TargetReachedTime = 0;
    cop_TradesToday = 0;
    cop_LastResetDate = TimeCurrent();

    Print("  Daily Target: $", DoubleToString(COP_DailyTarget_USD, 2));
    Print("  Include Floating: ", COP_IncludeFloating ? "YES" : "NO");
    Print("  Deduct Commissions: ", COP_DeductCommissions ? "YES" : "NO");
    Print("  Deduct Spread: ", COP_DeductSpread ? "YES" : "NO");
    Print("  Commission/Lot: $", DoubleToString(COP_CommissionPerLot, 2));
    Print("  Est. Spread: ", DoubleToString(COP_EstimatedSpreadPips, 1), " pips");
    Print("═══════════════════════════════════════════════════════════════════");

    return true;
}

//+------------------------------------------------------------------+
//| Check for Daily Reset                                            |
//+------------------------------------------------------------------+
void CheckDailyReset() {
    MqlDateTime currentTime, lastReset;
    TimeToStruct(TimeCurrent(), currentTime);
    TimeToStruct(cop_LastResetDate, lastReset);

    // Reset if new day
    if(currentTime.day != lastReset.day || 
       currentTime.mon != lastReset.mon ||
       currentTime.year != lastReset.year) {
        
        Print("[COP] 🔄 Daily Reset - New Trading Day");
        
        cop_RealizedProfit = 0.0;
        cop_TotalCommissions = 0.0;
        cop_TotalSpreadCost = 0.0;
        cop_TargetReached = false;
        cop_TargetReachedTime = 0;
        cop_TradesToday = 0;
        cop_LastResetDate = TimeCurrent();
    }
}

//+------------------------------------------------------------------+
//| Update Close On Profit Calculations - Call from OnTick()         |
//+------------------------------------------------------------------+
void UpdateCloseOnProfit() {
    if(!Enable_CloseOnProfit) return;
    if(cop_TargetReached) return;  // Already reached, skip

    // Check for daily reset
    CheckDailyReset();

    // Calculate floating P/L
    cop_FloatingProfit = GetTotalOpenProfit();

    // Calculate Net Profit
    cop_NetProfit = cop_RealizedProfit;

    if(COP_IncludeFloating) {
        cop_NetProfit += cop_FloatingProfit;
    }

    if(COP_DeductCommissions) {
        cop_NetProfit -= cop_TotalCommissions;
    }

    if(COP_DeductSpread) {
        cop_NetProfit -= cop_TotalSpreadCost;
    }

    // Check if target reached
    if(cop_NetProfit >= COP_DailyTarget_USD) {
        OnTargetReached();
    }
}

//+------------------------------------------------------------------+
//| Called When a Trade Closes - Update Realized P/L                 |
//+------------------------------------------------------------------+
void OnTradeClosedCOP(double profit, double lots) {
    if(!Enable_CloseOnProfit) return;

    cop_RealizedProfit += profit;
    cop_TradesToday++;

    // Estimate commission for this trade
    if(COP_DeductCommissions) {
        double commission = lots * COP_CommissionPerLot;
        cop_TotalCommissions += commission;
    }

    // Estimate spread cost for this trade
    if(COP_DeductSpread) {
        double pipValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) * 10;
        double spreadCost = COP_EstimatedSpreadPips * pipValue * lots;
        cop_TotalSpreadCost += spreadCost;
    }

    if(DetailedLogging) {
        Print("[COP] Trade closed: P/L $", DoubleToString(profit, 2),
              " | Net Total: $", DoubleToString(cop_NetProfit, 2),
              " / $", DoubleToString(COP_DailyTarget_USD, 2));
    }
}

//+------------------------------------------------------------------+
//| Target Reached - Execute Close Actions                           |
//+------------------------------------------------------------------+
void OnTargetReached() {
    cop_TargetReached = true;
    cop_TargetReachedTime = TimeCurrent();

    Print("");
    Print("╔═══════════════════════════════════════════════════════════════════╗");
    Print("║  🎯 DAILY PROFIT TARGET REACHED!                                  ║");
    Print("╠═══════════════════════════════════════════════════════════════════╣");
    Print("║  Target: $", DoubleToString(COP_DailyTarget_USD, 2));
    Print("║  Net Profit: $", DoubleToString(cop_NetProfit, 2));
    Print("║  ─────────────────────────────────────────────────────────────── ║");
    Print("║  Breakdown:                                                       ║");
    Print("║    Realized P/L: $", DoubleToString(cop_RealizedProfit, 2));
    Print("║    Floating P/L: $", DoubleToString(cop_FloatingProfit, 2));
    Print("║    Commissions:  -$", DoubleToString(cop_TotalCommissions, 2));
    Print("║    Spread Cost:  -$", DoubleToString(cop_TotalSpreadCost, 2));
    Print("║  ─────────────────────────────────────────────────────────────── ║");
    Print("║  Trades Today: ", cop_TradesToday);
    Print("║  Time: ", TimeToString(cop_TargetReachedTime, TIME_DATE|TIME_SECONDS));
    Print("╚═══════════════════════════════════════════════════════════════════╝");
    Print("");

    // Close all positions
    if(COP_ClosePositions) {
        Print("[COP] Closing all positions...");
        CloseAllGridA();
        CloseAllGridB();
        if(shield.isActive) CloseShield("COP_TARGET");
        Print("[COP] ✅ All positions closed");
    }

    // Delete all pending orders
    if(COP_DeletePending) {
        Print("[COP] Deleting all pending orders...");
        DeleteAllPendingOrders();
        Print("[COP] ✅ All pending orders deleted");
    }

    // Pause trading
    if(COP_PauseTrading) {
        systemState = STATE_DAILY_TARGET_REACHED;
        Print("[COP] ⏸️ Trading paused for today");
    }

    // Alert
    if(COP_AlertOnTarget) {
        Alert("🎯 SUGAMARA: Daily Target Reached! Net Profit: $", 
              DoubleToString(cop_NetProfit, 2));
    }
}

//+------------------------------------------------------------------+
//| Delete All Pending Orders                                        |
//+------------------------------------------------------------------+
void DeleteAllPendingOrders() {
    int total = OrdersTotal();
    
    for(int i = total - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(ticket > 0) {
            if(OrderSelect(ticket)) {
                long magic = OrderGetInteger(ORDER_MAGIC);
                // Check if it's our order
                if(magic >= MagicNumber && magic <= MagicNumber + MAGIC_OFFSET_GRID_B + 1000) {
                    trade.OrderDelete(ticket);
                }
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get COP Status for Dashboard                                     |
//+------------------------------------------------------------------+
string GetCOPStatusString() {
    if(!Enable_CloseOnProfit) return "DISABLED";
    if(cop_TargetReached) return "TARGET REACHED ✓";
    return "ACTIVE";
}

double GetCOPNetProfit() {
    return cop_NetProfit;
}

double GetCOPTarget() {
    return COP_DailyTarget_USD;
}

double GetCOPProgress() {
    if(COP_DailyTarget_USD <= 0) return 0;
    return (cop_NetProfit / COP_DailyTarget_USD) * 100.0;
}

bool IsCOPTargetReached() {
    return cop_TargetReached;
}

//+------------------------------------------------------------------+
//| Get Detailed COP Breakdown for Dashboard                         |
//+------------------------------------------------------------------+
void GetCOPBreakdown(double &realized, double &floating, 
                     double &commissions, double &spread, double &net) {
    realized = cop_RealizedProfit;
    floating = cop_FloatingProfit;
    commissions = cop_TotalCommissions;
    spread = cop_TotalSpreadCost;
    net = cop_NetProfit;
}

//+------------------------------------------------------------------+
//| Log COP Report                                                   |
//+------------------------------------------------------------------+
void LogCOPReport() {
    Print("");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  CLOSE ON PROFIT - STATUS REPORT");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  Status: ", GetCOPStatusString());
    Print("  Target: $", DoubleToString(COP_DailyTarget_USD, 2));
    Print("  Progress: ", DoubleToString(GetCOPProgress(), 1), "%");
    Print("───────────────────────────────────────────────────────────────────");
    Print("  P/L Breakdown:");
    Print("    Realized P/L:  $", DoubleToString(cop_RealizedProfit, 2));
    Print("    Floating P/L:  $", DoubleToString(cop_FloatingProfit, 2));
    Print("    Commissions:   -$", DoubleToString(cop_TotalCommissions, 2));
    Print("    Spread Cost:   -$", DoubleToString(cop_TotalSpreadCost, 2));
    Print("    ─────────────────────────────────────");
    Print("    NET PROFIT:    $", DoubleToString(cop_NetProfit, 2));
    Print("───────────────────────────────────────────────────────────────────");
    Print("  Trades Today: ", cop_TradesToday);
    if(cop_TargetReached) {
        Print("  Target Reached: ", TimeToString(cop_TargetReachedTime, TIME_DATE|TIME_MINUTES));
    }
    Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Deinitialize COP Manager                                         |
//+------------------------------------------------------------------+
void DeinitializeCloseOnProfitManager() {
    LogCOPReport();
}
```

---

# 3. DASHBOARD BOX CLOSE ON PROFIT

## 3.1 Nuova Funzione Dashboard - Aggiungere in `Dashboard.mqh`

```mql5
//+------------------------------------------------------------------+
//| Draw Close On Profit Box (v5.1)                                  |
//| Position: Below ATR indicator box                                |
//+------------------------------------------------------------------+
void DrawCOPBox(int startX, int startY) {
    if(!Enable_CloseOnProfit) return;

    int boxWidth = 280;
    int boxHeight = 100;
    
    string prefix = "SUGAMARA_COP_";
    
    // Box Background
    string bgName = prefix + "BG";
    ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, startX);
    ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, startY);
    ObjectSetInteger(0, bgName, OBJPROP_XSIZE, boxWidth);
    ObjectSetInteger(0, bgName, OBJPROP_YSIZE, boxHeight);
    ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'25,25,35');
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, cop_TargetReached ? clrLime : clrGold);
    ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, bgName, OBJPROP_BACK, false);
    
    // Title
    string titleName = prefix + "TITLE";
    ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, startX + 10);
    ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, startY + 5);
    ObjectSetString(0, titleName, OBJPROP_TEXT, "💵 CLOSE ON PROFIT");
    ObjectSetInteger(0, titleName, OBJPROP_COLOR, clrGold);
    ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 10);
    ObjectSetString(0, titleName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    // Status indicator
    string statusName = prefix + "STATUS";
    ObjectCreate(0, statusName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, statusName, OBJPROP_XDISTANCE, startX + 200);
    ObjectSetInteger(0, statusName, OBJPROP_YDISTANCE, startY + 5);
    
    string statusText = cop_TargetReached ? "✓ REACHED" : "ACTIVE";
    color statusColor = cop_TargetReached ? clrLime : clrWhite;
    
    ObjectSetString(0, statusName, OBJPROP_TEXT, statusText);
    ObjectSetInteger(0, statusName, OBJPROP_COLOR, statusColor);
    ObjectSetInteger(0, statusName, OBJPROP_FONTSIZE, 9);
    ObjectSetInteger(0, statusName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    // Net Profit (Large)
    string netName = prefix + "NET";
    ObjectCreate(0, netName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, netName, OBJPROP_XDISTANCE, startX + 10);
    ObjectSetInteger(0, netName, OBJPROP_YDISTANCE, startY + 25);
    
    color netColor = cop_NetProfit >= 0 ? clrLime : clrRed;
    string netSign = cop_NetProfit >= 0 ? "+" : "";
    
    ObjectSetString(0, netName, OBJPROP_TEXT, "Net: " + netSign + "$" + 
                    DoubleToString(cop_NetProfit, 2));
    ObjectSetInteger(0, netName, OBJPROP_COLOR, netColor);
    ObjectSetInteger(0, netName, OBJPROP_FONTSIZE, 14);
    ObjectSetString(0, netName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, netName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    // Target
    string targetName = prefix + "TARGET";
    ObjectCreate(0, targetName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, targetName, OBJPROP_XDISTANCE, startX + 160);
    ObjectSetInteger(0, targetName, OBJPROP_YDISTANCE, startY + 25);
    ObjectSetString(0, targetName, OBJPROP_TEXT, "/ $" + DoubleToString(COP_DailyTarget_USD, 2));
    ObjectSetInteger(0, targetName, OBJPROP_COLOR, clrSilver);
    ObjectSetInteger(0, targetName, OBJPROP_FONTSIZE, 12);
    ObjectSetInteger(0, targetName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    // Progress Bar Background
    string progBgName = prefix + "PROG_BG";
    ObjectCreate(0, progBgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, progBgName, OBJPROP_XDISTANCE, startX + 10);
    ObjectSetInteger(0, progBgName, OBJPROP_YDISTANCE, startY + 50);
    ObjectSetInteger(0, progBgName, OBJPROP_XSIZE, boxWidth - 20);
    ObjectSetInteger(0, progBgName, OBJPROP_YSIZE, 12);
    ObjectSetInteger(0, progBgName, OBJPROP_BGCOLOR, C'40,40,50');
    ObjectSetInteger(0, progBgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, progBgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    // Progress Bar Fill
    double progress = GetCOPProgress();
    if(progress < 0) progress = 0;
    if(progress > 100) progress = 100;
    
    int fillWidth = (int)((boxWidth - 20) * progress / 100.0);
    if(fillWidth < 1) fillWidth = 1;
    
    string progFillName = prefix + "PROG_FILL";
    ObjectCreate(0, progFillName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, progFillName, OBJPROP_XDISTANCE, startX + 10);
    ObjectSetInteger(0, progFillName, OBJPROP_YDISTANCE, startY + 50);
    ObjectSetInteger(0, progFillName, OBJPROP_XSIZE, fillWidth);
    ObjectSetInteger(0, progFillName, OBJPROP_YSIZE, 12);
    
    // Color based on progress
    color progColor = clrDodgerBlue;
    if(progress >= 70) progColor = clrGold;
    if(progress >= 100) progColor = clrLime;
    
    ObjectSetInteger(0, progFillName, OBJPROP_BGCOLOR, progColor);
    ObjectSetInteger(0, progFillName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, progFillName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    // Progress Percentage
    string progTextName = prefix + "PROG_TEXT";
    ObjectCreate(0, progTextName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, progTextName, OBJPROP_XDISTANCE, startX + 125);
    ObjectSetInteger(0, progTextName, OBJPROP_YDISTANCE, startY + 49);
    ObjectSetString(0, progTextName, OBJPROP_TEXT, DoubleToString(progress, 1) + "%");
    ObjectSetInteger(0, progTextName, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, progTextName, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, progTextName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    // Breakdown Line 1: Realized + Floating
    string line1Name = prefix + "LINE1";
    ObjectCreate(0, line1Name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, line1Name, OBJPROP_XDISTANCE, startX + 10);
    ObjectSetInteger(0, line1Name, OBJPROP_YDISTANCE, startY + 68);
    
    string line1 = "Real: $" + DoubleToString(cop_RealizedProfit, 2) + 
                   "  Float: $" + DoubleToString(cop_FloatingProfit, 2);
    ObjectSetString(0, line1Name, OBJPROP_TEXT, line1);
    ObjectSetInteger(0, line1Name, OBJPROP_COLOR, clrSilver);
    ObjectSetInteger(0, line1Name, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, line1Name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    // Breakdown Line 2: Costs
    string line2Name = prefix + "LINE2";
    ObjectCreate(0, line2Name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, line2Name, OBJPROP_XDISTANCE, startX + 10);
    ObjectSetInteger(0, line2Name, OBJPROP_YDISTANCE, startY + 82);
    
    string line2 = "Comm: -$" + DoubleToString(cop_TotalCommissions, 2) + 
                   "  Spread: -$" + DoubleToString(cop_TotalSpreadCost, 2);
    ObjectSetString(0, line2Name, OBJPROP_TEXT, line2);
    ObjectSetInteger(0, line2Name, OBJPROP_COLOR, C'180,180,180');
    ObjectSetInteger(0, line2Name, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, line2Name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Update COP Box Values                                            |
//+------------------------------------------------------------------+
void UpdateCOPBox() {
    if(!Enable_CloseOnProfit) return;
    
    string prefix = "SUGAMARA_COP_";
    
    // Update Net Profit
    string netName = prefix + "NET";
    if(ObjectFind(0, netName) >= 0) {
        color netColor = cop_NetProfit >= 0 ? clrLime : clrRed;
        string netSign = cop_NetProfit >= 0 ? "+" : "";
        ObjectSetString(0, netName, OBJPROP_TEXT, "Net: " + netSign + "$" + 
                        DoubleToString(cop_NetProfit, 2));
        ObjectSetInteger(0, netName, OBJPROP_COLOR, netColor);
    }
    
    // Update Progress Bar
    double progress = GetCOPProgress();
    if(progress < 0) progress = 0;
    if(progress > 100) progress = 100;
    
    int fillWidth = (int)(260 * progress / 100.0);
    if(fillWidth < 1) fillWidth = 1;
    
    string progFillName = prefix + "PROG_FILL";
    if(ObjectFind(0, progFillName) >= 0) {
        ObjectSetInteger(0, progFillName, OBJPROP_XSIZE, fillWidth);
        
        color progColor = clrDodgerBlue;
        if(progress >= 70) progColor = clrGold;
        if(progress >= 100) progColor = clrLime;
        ObjectSetInteger(0, progFillName, OBJPROP_BGCOLOR, progColor);
    }
    
    // Update Progress Text
    string progTextName = prefix + "PROG_TEXT";
    if(ObjectFind(0, progTextName) >= 0) {
        ObjectSetString(0, progTextName, OBJPROP_TEXT, DoubleToString(progress, 1) + "%");
    }
    
    // Update Status
    string statusName = prefix + "STATUS";
    if(ObjectFind(0, statusName) >= 0) {
        string statusText = cop_TargetReached ? "✓ REACHED" : "ACTIVE";
        color statusColor = cop_TargetReached ? clrLime : clrWhite;
        ObjectSetString(0, statusName, OBJPROP_TEXT, statusText);
        ObjectSetInteger(0, statusName, OBJPROP_COLOR, statusColor);
    }
    
    // Update Breakdown Lines
    string line1Name = prefix + "LINE1";
    if(ObjectFind(0, line1Name) >= 0) {
        string line1 = "Real: $" + DoubleToString(cop_RealizedProfit, 2) + 
                       "  Float: $" + DoubleToString(cop_FloatingProfit, 2);
        ObjectSetString(0, line1Name, OBJPROP_TEXT, line1);
    }
    
    string line2Name = prefix + "LINE2";
    if(ObjectFind(0, line2Name) >= 0) {
        string line2 = "Comm: -$" + DoubleToString(cop_TotalCommissions, 2) + 
                       "  Spread: -$" + DoubleToString(cop_TotalSpreadCost, 2);
        ObjectSetString(0, line2Name, OBJPROP_TEXT, line2);
    }
    
    // Update Border Color
    string bgName = prefix + "BG";
    if(ObjectFind(0, bgName) >= 0) {
        ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, 
                        cop_TargetReached ? clrLime : clrGold);
    }
}

//+------------------------------------------------------------------+
//| Delete COP Box Objects                                           |
//+------------------------------------------------------------------+
void DeleteCOPBox() {
    string prefix = "SUGAMARA_COP_";
    ObjectsDeleteAll(0, prefix);
}
```

---

# 4. LOGGING MIGLIORATO

## 4.1 Nuovo Sistema di Logging - Aggiungere in `Helpers.mqh`

```mql5
//+------------------------------------------------------------------+
//| ENHANCED LOGGING SYSTEM v5.1                                     |
//+------------------------------------------------------------------+

// Log Levels
enum ENUM_LOG_LEVEL_V51 {
    LOG_TRACE = 0,      // Tutto (debug estremo)
    LOG_DEBUG = 1,      // Debug dettagliato
    LOG_INFO = 2,       // Informazioni generali
    LOG_SUCCESS = 3,    // Operazioni riuscite
    LOG_WARNING = 4,    // Avvisi
    LOG_ERROR = 5,      // Errori
    LOG_CRITICAL = 6    // Errori critici
};

// Current log level (configurable)
ENUM_LOG_LEVEL_V51 g_LogLevel = LOG_INFO;

//+------------------------------------------------------------------+
//| Log with Level, Category and Emoji                               |
//+------------------------------------------------------------------+
void LogV51(ENUM_LOG_LEVEL_V51 level, string category, string message) {
    if(level < g_LogLevel) return;  // Skip if below threshold
    
    string emoji = "";
    string levelStr = "";
    
    switch(level) {
        case LOG_TRACE:    emoji = "🔍"; levelStr = "TRACE"; break;
        case LOG_DEBUG:    emoji = "🐛"; levelStr = "DEBUG"; break;
        case LOG_INFO:     emoji = "ℹ️"; levelStr = "INFO"; break;
        case LOG_SUCCESS:  emoji = "✅"; levelStr = "SUCCESS"; break;
        case LOG_WARNING:  emoji = "⚠️"; levelStr = "WARNING"; break;
        case LOG_ERROR:    emoji = "❌"; levelStr = "ERROR"; break;
        case LOG_CRITICAL: emoji = "🚨"; levelStr = "CRITICAL"; break;
    }
    
    string timestamp = TimeToString(TimeCurrent(), TIME_SECONDS);
    
    // Format: [HH:MM:SS] 🔍 [CATEGORY] Message
    Print("[", timestamp, "] ", emoji, " [", category, "] ", message);
}

//+------------------------------------------------------------------+
//| Shortcut Functions                                               |
//+------------------------------------------------------------------+
void LogTrace(string category, string msg)    { LogV51(LOG_TRACE, category, msg); }
void LogDebug(string category, string msg)    { LogV51(LOG_DEBUG, category, msg); }
void LogInfo(string category, string msg)     { LogV51(LOG_INFO, category, msg); }
void LogSuccess(string category, string msg)  { LogV51(LOG_SUCCESS, category, msg); }
void LogWarning(string category, string msg)  { LogV51(LOG_WARNING, category, msg); }
void LogError(string category, string msg)    { LogV51(LOG_ERROR, category, msg); }
void LogCritical(string category, string msg) { LogV51(LOG_CRITICAL, category, msg); }

//+------------------------------------------------------------------+
//| Log Trade Event                                                  |
//+------------------------------------------------------------------+
void LogTradeEvent(string action, string gridName, int level, 
                   double price, double lot, double profit = 0) {
    string msg = StringFormat("%s | %s L%d | Price: %.5f | Lot: %.2f",
                              action, gridName, level, price, lot);
    
    if(profit != 0) {
        msg += StringFormat(" | P/L: $%.2f", profit);
    }
    
    ENUM_LOG_LEVEL_V51 lvl = (profit >= 0) ? LOG_SUCCESS : LOG_WARNING;
    LogV51(lvl, "TRADE", msg);
}

//+------------------------------------------------------------------+
//| Log Order Event                                                  |
//+------------------------------------------------------------------+
void LogOrderEvent(string action, string orderType, int level, 
                   double price, double tp, double lot) {
    string msg = StringFormat("%s | %s L%d | Entry: %.5f | TP: %.5f | Lot: %.2f",
                              action, orderType, level, price, tp, lot);
    
    LogInfo("ORDER", msg);
}

//+------------------------------------------------------------------+
//| Log Shield Event                                                 |
//+------------------------------------------------------------------+
void LogShieldEvent(string action, string shieldType, double lot, double pl = 0) {
    string msg = StringFormat("%s | Type: %s | Lot: %.2f", action, shieldType, lot);
    
    if(pl != 0) {
        msg += StringFormat(" | P/L: $%.2f", pl);
    }
    
    LogV51(LOG_WARNING, "SHIELD", msg);
}

//+------------------------------------------------------------------+
//| Log Grid Status Summary                                          |
//+------------------------------------------------------------------+
void LogGridSummary() {
    int gridA_Pos = GetGridAActivePositions();
    int gridA_Pend = GetGridAPendingOrders();
    int gridB_Pos = GetGridBActivePositions();
    int gridB_Pend = GetGridBPendingOrders();
    
    double gridA_PL = GetGridAOpenProfit();
    double gridB_PL = GetGridBOpenProfit();
    
    string summary = StringFormat(
        "Grid A: %d pos, %d pend, P/L $%.2f | Grid B: %d pos, %d pend, P/L $%.2f",
        gridA_Pos, gridA_Pend, gridA_PL,
        gridB_Pos, gridB_Pend, gridB_PL
    );
    
    LogInfo("GRID", summary);
}

//+------------------------------------------------------------------+
//| Log Separator Box                                                |
//+------------------------------------------------------------------+
void LogBox(string title) {
    Print("");
    Print("╔═══════════════════════════════════════════════════════════════════╗");
    Print("║  ", title);
    Print("╚═══════════════════════════════════════════════════════════════════╝");
}

void LogSeparator() {
    Print("───────────────────────────────────────────────────────────────────");
}

//+------------------------------------------------------------------+
//| Log Startup Banner Enhanced                                      |
//+------------------------------------------------------------------+
void LogStartupBannerV51() {
    Print("");
    Print("╔═══════════════════════════════════════════════════════════════════╗");
    Print("║                                                                   ║");
    Print("║   ███████╗██╗   ██╗ ██████╗  █████╗ ███╗   ███╗ █████╗ ██████╗   ║");
    Print("║   ██╔════╝██║   ██║██╔════╝ ██╔══██╗████╗ ████║██╔══██╗██╔══██╗  ║");
    Print("║   ███████╗██║   ██║██║  ███╗███████║██╔████╔██║███████║██████╔╝  ║");
    Print("║   ╚════██║██║   ██║██║   ██║██╔══██║██║╚██╔╝██║██╔══██║██╔══██╗  ║");
    Print("║   ███████║╚██████╔╝╚██████╔╝██║  ██║██║ ╚═╝ ██║██║  ██║██║  ██║  ║");
    Print("║   ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝  ║");
    Print("║                                                                   ║");
    Print("║             RIBELLE v5.1 - CASCADE SOVRAPPOSTO                   ║");
    Print("║                  \"The Spice Must Flow\"                           ║");
    Print("║                                                                   ║");
    Print("╠═══════════════════════════════════════════════════════════════════╣");
    Print("║  🆕 v5.1 Features:                                                ║");
    Print("║     • Breakeven Lock @ 70%                                        ║");
    Print("║     • Close On Profit System                                      ║");
    Print("║     • Enhanced Logging                                            ║");
    Print("║     • Grid Visualization                                          ║");
    Print("╚═══════════════════════════════════════════════════════════════════╝");
    Print("");
}
```

---

# 5. GRID VISUALIZATION CON COLORI

## 5.1 Concetto

Visualizzare sul grafico tutte le entry delle grid con:
- **Colori diversi** per tipo ordine (BUY STOP, BUY LIMIT, SELL STOP, SELL LIMIT)
- **Leggenda** sulla dashboard
- **Linee orizzontali** ai prezzi di entry

## 5.2 Nuovi Parametri - Aggiungere in `InputParameters.mqh`

```mql5
//+------------------------------------------------------------------+
//| 🎨 GRID VISUALIZATION SETTINGS (v5.1)                            |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎨 GRID VISUALIZATION (v5.1)                             ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool      Enable_GridVisualization = true;            // ✅ Mostra Grid Lines
input bool      GridVis_ShowLegend = true;                  // 📋 Mostra Legenda

input group "    🎨 ORDER TYPE COLORS"
input color     GridVis_BuyStop_Color = clrDodgerBlue;      // 🔵 BUY STOP (Trend Long)
input color     GridVis_BuyLimit_Color = clrDeepSkyBlue;    // 🔷 BUY LIMIT (Hedge Long)
input color     GridVis_SellStop_Color = clrOrangeRed;      // 🔴 SELL STOP (Trend Short)
input color     GridVis_SellLimit_Color = clrCoral;         // 🔶 SELL LIMIT (Hedge Short)

input group "    📏 LINE SETTINGS"
input ENUM_LINE_STYLE GridVis_Pending_Style = STYLE_DOT;    // Pending Order Style
input ENUM_LINE_STYLE GridVis_Filled_Style = STYLE_SOLID;   // Filled Order Style
input int       GridVis_LineWidth = 1;                      // Line Width
```

## 5.3 Nuovo File: `GridVisualization.mqh`

Creare nuovo file nella cartella `UI/`:

```mql5
//+------------------------------------------------------------------+
//|                                          GridVisualization.mqh   |
//|                        Sugamara v5.1 - Grid Visual System        |
//|                                                                  |
//|  Visualizza entry grid con colori per tipo ordine               |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Initialize Grid Visualization                                    |
//+------------------------------------------------------------------+
bool InitializeGridVisualization() {
    if(!Enable_GridVisualization) {
        Print("INFO: Grid Visualization is DISABLED");
        return true;
    }

    Print("[GRID VIS] Initializing Grid Visualization v5.1");
    return true;
}

//+------------------------------------------------------------------+
//| Draw All Grid Lines                                              |
//+------------------------------------------------------------------+
void DrawAllGridLines() {
    if(!Enable_GridVisualization) return;

    // Clear existing lines first
    DeleteAllGridLines();

    // Draw Grid A Lines
    DrawGridALines();

    // Draw Grid B Lines
    DrawGridBLines();

    // Draw Legend
    if(GridVis_ShowLegend) {
        DrawGridLegend();
    }
}

//+------------------------------------------------------------------+
//| Draw Grid A Lines                                                |
//+------------------------------------------------------------------+
void DrawGridALines() {
    string prefix = "SUGAMARA_GRIDVIS_A_";

    // Upper Zone - CASCADE_OVERLAP: BUY STOP
    for(int i = 0; i < GridLevelsPerSide; i++) {
        string lineName = prefix + "UPPER_" + IntegerToString(i);
        double price = gridA_Upper_EntryPrices[i];
        
        bool isFilled = (gridA_Upper_Status[i] == ORDER_FILLED);
        ENUM_LINE_STYLE style = isFilled ? GridVis_Filled_Style : GridVis_Pending_Style;
        int width = isFilled ? GridVis_LineWidth + 1 : GridVis_LineWidth;
        
        CreateGridLine(lineName, price, GridVis_BuyStop_Color, style, width,
                      "A-U" + IntegerToString(i+1) + " BUY STOP");
    }

    // Lower Zone - CASCADE_OVERLAP: BUY LIMIT (Hedge)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        string lineName = prefix + "LOWER_" + IntegerToString(i);
        double price = gridA_Lower_EntryPrices[i];
        
        bool isFilled = (gridA_Lower_Status[i] == ORDER_FILLED);
        ENUM_LINE_STYLE style = isFilled ? GridVis_Filled_Style : GridVis_Pending_Style;
        int width = isFilled ? GridVis_LineWidth + 1 : GridVis_LineWidth;
        
        CreateGridLine(lineName, price, GridVis_BuyLimit_Color, style, width,
                      "A-L" + IntegerToString(i+1) + " BUY LIMIT");
    }
}

//+------------------------------------------------------------------+
//| Draw Grid B Lines                                                |
//+------------------------------------------------------------------+
void DrawGridBLines() {
    string prefix = "SUGAMARA_GRIDVIS_B_";

    // Upper Zone - CASCADE_OVERLAP: SELL LIMIT (Hedge)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        string lineName = prefix + "UPPER_" + IntegerToString(i);
        double price = gridB_Upper_EntryPrices[i];
        
        bool isFilled = (gridB_Upper_Status[i] == ORDER_FILLED);
        ENUM_LINE_STYLE style = isFilled ? GridVis_Filled_Style : GridVis_Pending_Style;
        int width = isFilled ? GridVis_LineWidth + 1 : GridVis_LineWidth;
        
        CreateGridLine(lineName, price, GridVis_SellLimit_Color, style, width,
                      "B-U" + IntegerToString(i+1) + " SELL LIMIT");
    }

    // Lower Zone - CASCADE_OVERLAP: SELL STOP
    for(int i = 0; i < GridLevelsPerSide; i++) {
        string lineName = prefix + "LOWER_" + IntegerToString(i);
        double price = gridB_Lower_EntryPrices[i];
        
        bool isFilled = (gridB_Lower_Status[i] == ORDER_FILLED);
        ENUM_LINE_STYLE style = isFilled ? GridVis_Filled_Style : GridVis_Pending_Style;
        int width = isFilled ? GridVis_LineWidth + 1 : GridVis_LineWidth;
        
        CreateGridLine(lineName, price, GridVis_SellStop_Color, style, width,
                      "B-L" + IntegerToString(i+1) + " SELL STOP");
    }
}

//+------------------------------------------------------------------+
//| Create Single Grid Line                                          |
//+------------------------------------------------------------------+
void CreateGridLine(string name, double price, color lineColor, 
                    ENUM_LINE_STYLE style, int width, string tooltip) {
    
    if(ObjectFind(0, name) >= 0) {
        ObjectDelete(0, name);
    }
    
    ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);
}

//+------------------------------------------------------------------+
//| Draw Grid Legend Box                                             |
//+------------------------------------------------------------------+
void DrawGridLegend() {
    int startX = 10;
    int startY = 450;  // Adjust based on dashboard position
    int boxWidth = 180;
    int boxHeight = 100;
    
    string prefix = "SUGAMARA_GRIDLEG_";
    
    // Background
    string bgName = prefix + "BG";
    ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, startX);
    ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, startY);
    ObjectSetInteger(0, bgName, OBJPROP_XSIZE, boxWidth);
    ObjectSetInteger(0, bgName, OBJPROP_YSIZE, boxHeight);
    ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, C'25,25,35');
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, bgName, OBJPROP_BORDER_COLOR, clrDimGray);
    ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    // Title
    string titleName = prefix + "TITLE";
    ObjectCreate(0, titleName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, titleName, OBJPROP_XDISTANCE, startX + 10);
    ObjectSetInteger(0, titleName, OBJPROP_YDISTANCE, startY + 5);
    ObjectSetString(0, titleName, OBJPROP_TEXT, "🎨 GRID LEGEND");
    ObjectSetInteger(0, titleName, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, titleName, OBJPROP_FONTSIZE, 9);
    ObjectSetString(0, titleName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, titleName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    // Legend Items
    int yOffset = 25;
    
    // BUY STOP
    DrawLegendItem(prefix + "L1", startX + 10, startY + yOffset, 
                   GridVis_BuyStop_Color, "BUY STOP (Trend ↑)");
    yOffset += 18;
    
    // BUY LIMIT
    DrawLegendItem(prefix + "L2", startX + 10, startY + yOffset, 
                   GridVis_BuyLimit_Color, "BUY LIMIT (Hedge)");
    yOffset += 18;
    
    // SELL LIMIT
    DrawLegendItem(prefix + "L3", startX + 10, startY + yOffset, 
                   GridVis_SellLimit_Color, "SELL LIMIT (Hedge)");
    yOffset += 18;
    
    // SELL STOP
    DrawLegendItem(prefix + "L4", startX + 10, startY + yOffset, 
                   GridVis_SellStop_Color, "SELL STOP (Trend ↓)");
}

//+------------------------------------------------------------------+
//| Draw Single Legend Item                                          |
//+------------------------------------------------------------------+
void DrawLegendItem(string baseName, int x, int y, color itemColor, string text) {
    // Color box
    string boxName = baseName + "_BOX";
    ObjectCreate(0, boxName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, boxName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, boxName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, boxName, OBJPROP_XSIZE, 12);
    ObjectSetInteger(0, boxName, OBJPROP_YSIZE, 12);
    ObjectSetInteger(0, boxName, OBJPROP_BGCOLOR, itemColor);
    ObjectSetInteger(0, boxName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, boxName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    
    // Text
    string textName = baseName + "_TEXT";
    ObjectCreate(0, textName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, textName, OBJPROP_XDISTANCE, x + 18);
    ObjectSetInteger(0, textName, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, textName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, textName, OBJPROP_COLOR, clrSilver);
    ObjectSetInteger(0, textName, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, textName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Update Grid Lines (Call on status change)                        |
//+------------------------------------------------------------------+
void UpdateGridLines() {
    if(!Enable_GridVisualization) return;
    
    // Simply redraw all
    DrawAllGridLines();
}

//+------------------------------------------------------------------+
//| Delete All Grid Visualization Objects                            |
//+------------------------------------------------------------------+
void DeleteAllGridLines() {
    ObjectsDeleteAll(0, "SUGAMARA_GRIDVIS_");
    ObjectsDeleteAll(0, "SUGAMARA_GRIDLEG_");
}

//+------------------------------------------------------------------+
//| Deinitialize Grid Visualization                                  |
//+------------------------------------------------------------------+
void DeinitializeGridVisualization() {
    DeleteAllGridLines();
    Print("[GRID VIS] Grid Visualization deinitialized");
}
```

---

# 6. GESTIONE LOTTI DIFFERENZIATA (STOP vs LIMIT)

## 6.1 Concetto

**STOP orders** (trend-following) hanno più probabilità di essere in profitto quando fillati.
**LIMIT orders** (hedge/contro-trend) servono come protezione.

**Proposta**: STOP orders con lotti leggermente più alti per massimizzare i profitti sui trend.

## 6.2 Nuovi Parametri - Aggiungere in `InputParameters.mqh`

```mql5
//+------------------------------------------------------------------+
//| 📊 DIFFERENTIATED LOT SIZING (v5.1)                              |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📊 DIFFERENTIATED LOT SIZING (v5.1)                      ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool      Enable_DifferentiatedLots = false;          // ✅ Abilita Lotti Differenziati
input ENUM_LOT_DIFF_MODE LotDiff_Mode = LOT_DIFF_RATIO;     // 📊 Modalità Differenziazione

input group "    📊 RATIO MODE (STOP higher than LIMIT)"
input double    LotDiff_StopMultiplier = 1.2;               // 📈 Moltiplicatore STOP (es: 1.2 = +20%)
input double    LotDiff_LimitMultiplier = 0.8;              // 📉 Moltiplicatore LIMIT (es: 0.8 = -20%)

input group "    📊 TIERED MODE (Progressive by level)"
input double    LotDiff_Tier1_Mult = 1.0;                   // L1-L2: Moltiplicatore
input double    LotDiff_Tier2_Mult = 1.1;                   // L3-L4: Moltiplicatore
input double    LotDiff_Tier3_Mult = 1.2;                   // L5+: Moltiplicatore
```

## 6.3 Nuovo Enum - Aggiungere in `Enums.mqh`

```mql5
//+------------------------------------------------------------------+
//| 📊 LOT DIFFERENTIATION MODE                                      |
//+------------------------------------------------------------------+
enum ENUM_LOT_DIFF_MODE {
    LOT_DIFF_RATIO = 0,         // RATIO: STOP più alti di LIMIT
    LOT_DIFF_TIERED = 1,        // TIERED: Progressivo per livello
    LOT_DIFF_HYBRID = 2         // HYBRID: Combinazione
};
```

## 6.4 Funzione di Calcolo Lotti - Modificare in `GridHelpers.mqh`

```mql5
//+------------------------------------------------------------------+
//| Calculate Grid Lot Size with Differentiation (v5.1)              |
//+------------------------------------------------------------------+
double CalculateGridLotSizeV51(int level, ENUM_ORDER_TYPE orderType) {
    // Base lot calculation (existing logic)
    double baseLot = BaseLotSize;
    
    // Apply level multiplier (if using martingale/progression)
    if(LotMultiplier > 1.0) {
        baseLot = BaseLotSize * MathPow(LotMultiplier, level);
    }
    
    // Apply differentiation if enabled
    if(Enable_DifferentiatedLots) {
        baseLot = ApplyLotDifferentiation(baseLot, level, orderType);
    }
    
    // Normalize and limit
    baseLot = NormalizeLotSize(baseLot);
    baseLot = MathMax(baseLot, symbolMinLot);
    baseLot = MathMin(baseLot, symbolMaxLot);
    
    return baseLot;
}

//+------------------------------------------------------------------+
//| Apply Lot Differentiation Based on Order Type                    |
//+------------------------------------------------------------------+
double ApplyLotDifferentiation(double lot, int level, ENUM_ORDER_TYPE orderType) {
    double multiplier = 1.0;
    
    switch(LotDiff_Mode) {
        case LOT_DIFF_RATIO:
            // STOP orders get higher lots (trend-following)
            if(orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP) {
                multiplier = LotDiff_StopMultiplier;
            }
            // LIMIT orders get lower lots (hedge)
            else if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT) {
                multiplier = LotDiff_LimitMultiplier;
            }
            break;
            
        case LOT_DIFF_TIERED:
            // Progressive by level
            if(level < 2) {
                multiplier = LotDiff_Tier1_Mult;
            } else if(level < 4) {
                multiplier = LotDiff_Tier2_Mult;
            } else {
                multiplier = LotDiff_Tier3_Mult;
            }
            break;
            
        case LOT_DIFF_HYBRID:
            // Combine both approaches
            double typeMultiplier = 1.0;
            double tierMultiplier = 1.0;
            
            // Type multiplier
            if(orderType == ORDER_TYPE_BUY_STOP || orderType == ORDER_TYPE_SELL_STOP) {
                typeMultiplier = LotDiff_StopMultiplier;
            } else {
                typeMultiplier = LotDiff_LimitMultiplier;
            }
            
            // Tier multiplier
            if(level < 2) tierMultiplier = LotDiff_Tier1_Mult;
            else if(level < 4) tierMultiplier = LotDiff_Tier2_Mult;
            else tierMultiplier = LotDiff_Tier3_Mult;
            
            multiplier = typeMultiplier * tierMultiplier;
            break;
    }
    
    return lot * multiplier;
}

//+------------------------------------------------------------------+
//| Log Lot Differentiation Summary                                  |
//+------------------------------------------------------------------+
void LogLotDifferentiationSummary() {
    if(!Enable_DifferentiatedLots) {
        Print("[LOT DIFF] Disabled - Using uniform lots");
        return;
    }
    
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  LOT DIFFERENTIATION SUMMARY v5.1");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  Mode: ", EnumToString(LotDiff_Mode));
    Print("  Base Lot: ", DoubleToString(BaseLotSize, 2));
    Print("───────────────────────────────────────────────────────────────────");
    
    switch(LotDiff_Mode) {
        case LOT_DIFF_RATIO:
            Print("  STOP Orders: ", DoubleToString(BaseLotSize * LotDiff_StopMultiplier, 2),
                  " (", DoubleToString((LotDiff_StopMultiplier - 1) * 100, 0), "% more)");
            Print("  LIMIT Orders: ", DoubleToString(BaseLotSize * LotDiff_LimitMultiplier, 2),
                  " (", DoubleToString((1 - LotDiff_LimitMultiplier) * 100, 0), "% less)");
            break;
            
        case LOT_DIFF_TIERED:
            Print("  L1-L2: ", DoubleToString(BaseLotSize * LotDiff_Tier1_Mult, 2));
            Print("  L3-L4: ", DoubleToString(BaseLotSize * LotDiff_Tier2_Mult, 2));
            Print("  L5+:   ", DoubleToString(BaseLotSize * LotDiff_Tier3_Mult, 2));
            break;
            
        case LOT_DIFF_HYBRID:
            Print("  Combined Type + Tier multipliers");
            Print("  Example L1 STOP: ", DoubleToString(BaseLotSize * LotDiff_StopMultiplier * LotDiff_Tier1_Mult, 2));
            Print("  Example L3 LIMIT: ", DoubleToString(BaseLotSize * LotDiff_LimitMultiplier * LotDiff_Tier2_Mult, 2));
            break;
    }
    
    Print("═══════════════════════════════════════════════════════════════════");
}
```

---

# 📋 CHECKLIST IMPLEMENTAZIONE

## File da Creare:
- [ ] `Trading/BreakevenLockManager.mqh`
- [ ] `Trading/CloseOnProfitManager.mqh`
- [ ] `UI/GridVisualization.mqh`

## File da Modificare:
- [ ] `Config/InputParameters.mqh` (nuovi parametri)
- [ ] `Config/Enums.mqh` (nuovi enum)
- [ ] `Core/GlobalVariables.mqh` (nuove variabili)
- [ ] `Utils/Helpers.mqh` (logging migliorato)
- [ ] `Utils/GridHelpers.mqh` (lot differentiation)
- [ ] `UI/Dashboard.mqh` (COP box, legend)
- [ ] `Sugamara.mq5` (include e chiamate)

## Ordine di Integrazione:
1. Enums e GlobalVariables
2. InputParameters
3. Helpers (logging)
4. GridHelpers (lot diff)
5. BreakevenLockManager
6. CloseOnProfitManager
7. GridVisualization
8. Dashboard updates
9. Main file includes e calls

---

# 🔧 NOTE TECNICHE

## Compatibilità
- Tutte le funzionalità sono **opzionali** (Enable_xxx = false di default dove appropriato)
- Non interferiscono con la logica CASCADE esistente
- Backward compatible con configurazioni esistenti

## Performance
- Grid Visualization: Aggiornare solo su cambio status (non ogni tick)
- COP: Calcolo leggero, eseguito ogni tick
- BE Lock: Check solo su posizioni traccate

## Testing Consigliato
1. Testare ogni funzionalità **singolarmente**
2. Verificare in Strategy Tester prima del live
3. Iniziare con parametri conservativi

---

**Fine Documento - SUGAMARA v5.1 Implementation Guide**