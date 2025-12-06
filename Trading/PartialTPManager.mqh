//+------------------------------------------------------------------+
//|                                            PartialTPManager.mqh  |
//|                        Sugamara v3.0 - Partial Take Profit       |
//|                                                                  |
//|  Lock profit progressivamente: 50% -> 75% -> 100%                |
//|  Applica a Grid A, Grid B e Shield                               |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| PARTIAL TP STRUCTURES                                            |
//+------------------------------------------------------------------+

// Tracking per ogni posizione
struct PartialTPTracker {
    ulong    ticket;                    // Ticket posizione
    double   original_lot;              // Lot originale
    double   current_lot;               // Lot attuale
    double   entry_price;               // Prezzo entry
    double   tp_price;                  // Prezzo TP originale
    ENUM_PARTIAL_TP_STATUS status;      // Stato partial
    bool     level1_hit;                // Level 1 raggiunto
    bool     level2_hit;                // Level 2 raggiunto
    double   level1_price;              // Prezzo Level 1
    double   level2_price;              // Prezzo Level 2
    double   profit_locked;             // Profit bloccato
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+

PartialTPTracker partialTP_GridA_Upper[];
PartialTPTracker partialTP_GridA_Lower[];
PartialTPTracker partialTP_GridB_Upper[];
PartialTPTracker partialTP_GridB_Lower[];
PartialTPTracker partialTP_Shield;

double totalPartialProfit = 0.0;        // Profit totale da partial TP
int partialTP_Executions = 0;           // Numero esecuzioni partial

//+------------------------------------------------------------------+
//| Initialize Partial TP Manager                                    |
//+------------------------------------------------------------------+
bool InitializePartialTPManager() {
    if(!Enable_PartialTP) {
        Print("INFO: Partial TP is DISABLED");
        return true;
    }

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  INITIALIZING PARTIAL TP MANAGER v3.0");
    Print("═══════════════════════════════════════════════════════════════════");

    // Resize arrays
    ArrayResize(partialTP_GridA_Upper, GridLevelsPerSide);
    ArrayResize(partialTP_GridA_Lower, GridLevelsPerSide);
    ArrayResize(partialTP_GridB_Upper, GridLevelsPerSide);
    ArrayResize(partialTP_GridB_Lower, GridLevelsPerSide);

    // Initialize all trackers
    for(int i = 0; i < GridLevelsPerSide; i++) {
        ResetPartialTracker(partialTP_GridA_Upper[i]);
        ResetPartialTracker(partialTP_GridA_Lower[i]);
        ResetPartialTracker(partialTP_GridB_Upper[i]);
        ResetPartialTracker(partialTP_GridB_Lower[i]);
    }

    ResetPartialTracker(partialTP_Shield);

    totalPartialProfit = 0.0;
    partialTP_Executions = 0;

    Print("  Level 1: ", PartialTP_Level1_Percent, "% progress -> Close ", PartialTP_Level1_Close, "%");
    Print("  Level 2: ", PartialTP_Level2_Percent, "% progress -> Close ", PartialTP_Level2_Close, "%");
    Print("  Apply to Shield: ", PartialTP_OnShield ? "YES" : "NO");
    Print("═══════════════════════════════════════════════════════════════════");

    return true;
}

//+------------------------------------------------------------------+
//| Reset Partial Tracker                                            |
//+------------------------------------------------------------------+
void ResetPartialTracker(PartialTPTracker &tracker) {
    tracker.ticket = 0;
    tracker.original_lot = 0;
    tracker.current_lot = 0;
    tracker.entry_price = 0;
    tracker.tp_price = 0;
    tracker.status = PARTIAL_NONE;
    tracker.level1_hit = false;
    tracker.level2_hit = false;
    tracker.level1_price = 0;
    tracker.level2_price = 0;
    tracker.profit_locked = 0;
}

//+------------------------------------------------------------------+
//| Setup Partial TP for a Position                                  |
//+------------------------------------------------------------------+
void SetupPartialTP(ulong ticket, double entry, double tp, double lot,
                    ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {

    if(!Enable_PartialTP) return;

    PartialTPTracker tracker;
    tracker.ticket = ticket;
    tracker.original_lot = lot;
    tracker.current_lot = lot;
    tracker.entry_price = entry;
    tracker.tp_price = tp;
    tracker.status = PARTIAL_NONE;
    tracker.level1_hit = false;
    tracker.level2_hit = false;
    tracker.profit_locked = 0;

    // Calculate partial levels
    double distance = MathAbs(tp - entry);

    if(tp > entry) {
        // LONG position
        tracker.level1_price = entry + (distance * PartialTP_Level1_Percent / 100.0);
        tracker.level2_price = entry + (distance * PartialTP_Level2_Percent / 100.0);
    } else {
        // SHORT position
        tracker.level1_price = entry - (distance * PartialTP_Level1_Percent / 100.0);
        tracker.level2_price = entry - (distance * PartialTP_Level2_Percent / 100.0);
    }

    // Store in appropriate array
    if(side == GRID_A) {
        if(zone == ZONE_UPPER) partialTP_GridA_Upper[level] = tracker;
        else partialTP_GridA_Lower[level] = tracker;
    } else {
        if(zone == ZONE_UPPER) partialTP_GridB_Upper[level] = tracker;
        else partialTP_GridB_Lower[level] = tracker;
    }

    if(DetailedLogging) {
        Print("Partial TP setup: Ticket ", ticket,
              " L1@", DoubleToString(tracker.level1_price, _Digits),
              " L2@", DoubleToString(tracker.level2_price, _Digits));
    }
}

//+------------------------------------------------------------------+
//| Setup Partial TP for Shield                                      |
//+------------------------------------------------------------------+
void SetupPartialTPShield(ulong ticket, double entry, double tp, double lot) {
    if(!Enable_PartialTP || !PartialTP_OnShield) return;

    partialTP_Shield.ticket = ticket;
    partialTP_Shield.original_lot = lot;
    partialTP_Shield.current_lot = lot;
    partialTP_Shield.entry_price = entry;
    partialTP_Shield.tp_price = tp;
    partialTP_Shield.status = PARTIAL_NONE;
    partialTP_Shield.level1_hit = false;
    partialTP_Shield.level2_hit = false;
    partialTP_Shield.profit_locked = 0;

    double distance = MathAbs(tp - entry);

    if(tp > entry) {
        partialTP_Shield.level1_price = entry + (distance * PartialTP_Level1_Percent / 100.0);
        partialTP_Shield.level2_price = entry + (distance * PartialTP_Level2_Percent / 100.0);
    } else {
        partialTP_Shield.level1_price = entry - (distance * PartialTP_Level1_Percent / 100.0);
        partialTP_Shield.level2_price = entry - (distance * PartialTP_Level2_Percent / 100.0);
    }

    Print("Shield Partial TP setup: L1@", DoubleToString(partialTP_Shield.level1_price, _Digits),
          " L2@", DoubleToString(partialTP_Shield.level2_price, _Digits));
}

//+------------------------------------------------------------------+
//| Process All Partial TPs                                          |
//+------------------------------------------------------------------+
void ProcessPartialTPs() {
    if(!Enable_PartialTP) return;

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Process Grid A
    for(int i = 0; i < GridLevelsPerSide; i++) {
        ProcessSinglePartialTP(partialTP_GridA_Upper[i], currentPrice);
        ProcessSinglePartialTP(partialTP_GridA_Lower[i], currentPrice);
    }

    // Process Grid B
    for(int i = 0; i < GridLevelsPerSide; i++) {
        ProcessSinglePartialTP(partialTP_GridB_Upper[i], currentPrice);
        ProcessSinglePartialTP(partialTP_GridB_Lower[i], currentPrice);
    }

    // Process Shield
    if(PartialTP_OnShield && partialTP_Shield.ticket > 0) {
        ProcessSinglePartialTP(partialTP_Shield, currentPrice);
    }
}

//+------------------------------------------------------------------+
//| Process Single Partial TP                                        |
//+------------------------------------------------------------------+
void ProcessSinglePartialTP(PartialTPTracker &tracker, double currentPrice) {
    if(tracker.ticket == 0 || tracker.status == PARTIAL_COMPLETE) return;

    // Check if position still exists
    if(!PositionSelectByTicket(tracker.ticket)) {
        tracker.status = PARTIAL_COMPLETE;
        return;
    }

    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    bool isLong = (posType == POSITION_TYPE_BUY);

    // Check Level 1
    if(!tracker.level1_hit) {
        bool level1Reached = isLong ?
            (currentPrice >= tracker.level1_price) :
            (currentPrice <= tracker.level1_price);

        if(level1Reached) {
            ExecutePartialClose(tracker, 1);
        }
    }
    // Check Level 2
    else if(!tracker.level2_hit) {
        bool level2Reached = isLong ?
            (currentPrice >= tracker.level2_price) :
            (currentPrice <= tracker.level2_price);

        if(level2Reached) {
            ExecutePartialClose(tracker, 2);
        }
    }
}

//+------------------------------------------------------------------+
//| Execute Partial Close                                            |
//+------------------------------------------------------------------+
void ExecutePartialClose(PartialTPTracker &tracker, int level) {
    if(!PositionSelectByTicket(tracker.ticket)) return;

    double closePercent = (level == 1) ? PartialTP_Level1_Close : PartialTP_Level2_Close;
    double lotToClose = NormalizeDouble(tracker.original_lot * closePercent / 100.0, 2);

    // Ensure minimum lot
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    if(lotToClose < minLot) lotToClose = minLot;

    // Ensure we don't close more than current lot
    if(lotToClose > tracker.current_lot) lotToClose = tracker.current_lot;

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  PARTIAL TP LEVEL ", level, " TRIGGERED");
    Print("───────────────────────────────────────────────────────────────────");
    Print("  Ticket: ", tracker.ticket);
    Print("  Closing: ", DoubleToString(lotToClose, 2), " lot (", closePercent, "%)");
    Print("  Current Lot: ", DoubleToString(tracker.current_lot, 2));

    // Execute partial close
    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.action = TRADE_ACTION_DEAL;
    request.position = tracker.ticket;
    request.symbol = _Symbol;
    request.volume = lotToClose;
    request.deviation = Slippage;

    long posType = PositionGetInteger(POSITION_TYPE);
    if(posType == POSITION_TYPE_BUY) {
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    } else {
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    }

    request.comment = "SUGAMARA_PARTIAL_L" + IntegerToString(level);

    if(OrderSend(request, result)) {
        if(result.retcode == TRADE_RETCODE_DONE) {
            tracker.current_lot -= lotToClose;

            // Calculate locked profit
            double profit = result.price - tracker.entry_price;
            if(posType == POSITION_TYPE_SELL) profit = -profit;
            profit *= lotToClose * SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) /
                      SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

            tracker.profit_locked += profit;
            totalPartialProfit += profit;
            partialTP_Executions++;

            if(level == 1) {
                tracker.level1_hit = true;
                tracker.status = PARTIAL_LEVEL1;
            } else {
                tracker.level2_hit = true;
                tracker.status = PARTIAL_LEVEL2;
            }

            Print("  ✅ SUCCESS: Closed ", DoubleToString(lotToClose, 2), " lot");
            Print("  Profit Locked: $", DoubleToString(profit, 2));
            Print("  Remaining: ", DoubleToString(tracker.current_lot, 2), " lot");
            Print("═══════════════════════════════════════════════════════════════════");

            if(EnableAlerts) {
                Alert("SUGAMARA: Partial TP Level ", level, " - Locked $", DoubleToString(profit, 2));
            }
        }
    } else {
        Print("  ❌ ERROR: Partial close failed - ", result.retcode);
        Print("═══════════════════════════════════════════════════════════════════");
    }
}

//+------------------------------------------------------------------+
//| Get Partial TP Statistics                                        |
//+------------------------------------------------------------------+
double GetTotalPartialProfit() {
    return totalPartialProfit;
}

int GetPartialTPExecutions() {
    return partialTP_Executions;
}

//+------------------------------------------------------------------+
//| Clear Partial TP for Closed Position                             |
//+------------------------------------------------------------------+
void ClearPartialTP(ulong ticket) {
    // Check all arrays
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(partialTP_GridA_Upper[i].ticket == ticket) ResetPartialTracker(partialTP_GridA_Upper[i]);
        if(partialTP_GridA_Lower[i].ticket == ticket) ResetPartialTracker(partialTP_GridA_Lower[i]);
        if(partialTP_GridB_Upper[i].ticket == ticket) ResetPartialTracker(partialTP_GridB_Upper[i]);
        if(partialTP_GridB_Lower[i].ticket == ticket) ResetPartialTracker(partialTP_GridB_Lower[i]);
    }

    if(partialTP_Shield.ticket == ticket) ResetPartialTracker(partialTP_Shield);
}

//+------------------------------------------------------------------+
//| Get Partial Status Text                                          |
//+------------------------------------------------------------------+
string GetPartialStatusText(ENUM_PARTIAL_TP_STATUS status) {
    switch(status) {
        case PARTIAL_NONE:     return "None";
        case PARTIAL_LEVEL1:   return "L1 Hit";
        case PARTIAL_LEVEL2:   return "L2 Hit";
        case PARTIAL_COMPLETE: return "Complete";
    }
    return "Unknown";
}

//+------------------------------------------------------------------+
//| Deinitialize Partial TP Manager                                  |
//+------------------------------------------------------------------+
void DeinitializePartialTPManager() {
    ArrayFree(partialTP_GridA_Upper);
    ArrayFree(partialTP_GridA_Lower);
    ArrayFree(partialTP_GridB_Upper);
    ArrayFree(partialTP_GridB_Lower);

    Print("Partial TP Manager: Total Profit Locked: $", DoubleToString(totalPartialProfit, 2));
    Print("Partial TP Manager: Executions: ", partialTP_Executions);
}

