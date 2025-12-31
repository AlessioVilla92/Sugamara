//+------------------------------------------------------------------+
//|                                                    GridZero.mqh  |
//|                        Sugamara v5.8 - Grid Zero System          |
//|                                                                  |
//|  Grid Zero fills the 27-pip gap in the center of the grid        |
//|  using mean-reversion counter-trend orders.                      |
//|                                                                  |
//|  Trigger: When L2 is filled (price moved 24+ pips from entry)    |
//|  Logic: Insert OPPOSITE direction orders at entry point          |
//|                                                                  |
//|  BULLISH bias -> BEARISH structure: SELL STOP + BUY LIMIT        |
//|  BEARISH bias -> BULLISH structure: BUY STOP + SELL LIMIT        |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| GRID ZERO CONSTANTS                                              |
//+------------------------------------------------------------------+
#define GRIDZERO_COOLDOWN_SECONDS 0     // No cooldown (v5.8 - immediate reopen)

//+------------------------------------------------------------------+
//| GRID ZERO GLOBAL VARIABLES                                       |
//+------------------------------------------------------------------+
bool g_gridZeroInserted = false;        // Grid Zero already inserted
bool g_gridZeroBiasUp = false;          // Bias was bullish (BEARISH structure)
bool g_gridZeroBiasDown = false;        // Bias was bearish (BULLISH structure)

ulong g_gridZero_StopTicket = 0;        // Ticket STOP order (SELL or BUY)
ulong g_gridZero_LimitTicket = 0;       // Ticket LIMIT order (BUY or SELL)

ENUM_ORDER_STATUS g_gridZero_StopStatus = ORDER_NONE;
ENUM_ORDER_STATUS g_gridZero_LimitStatus = ORDER_NONE;

datetime g_gridZero_LastStopClose = 0;
datetime g_gridZero_LastLimitClose = 0;

int g_gridZero_StopCycles = 0;
int g_gridZero_LimitCycles = 0;

//+------------------------------------------------------------------+
//| HELPER: GET ORDER STATUS NAME                                    |
//+------------------------------------------------------------------+
string GetOrderStatusName(ENUM_ORDER_STATUS status) {
    switch(status) {
        case ORDER_NONE:       return "NONE";
        case ORDER_PENDING:    return "PENDING";
        case ORDER_FILLED:     return "FILLED";
        case ORDER_CLOSED:     return "CLOSED";
        case ORDER_CLOSED_TP:  return "TP";
        case ORDER_CLOSED_SL:  return "SL";
        case ORDER_CANCELLED:  return "CANCELLED";
        default:               return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| GRID ZERO INITIALIZATION                                         |
//+------------------------------------------------------------------+
void InitGridZero() {
    g_gridZeroInserted = false;
    g_gridZeroBiasUp = false;
    g_gridZeroBiasDown = false;
    g_gridZero_StopTicket = 0;
    g_gridZero_LimitTicket = 0;
    g_gridZero_StopStatus = ORDER_NONE;
    g_gridZero_LimitStatus = ORDER_NONE;
    g_gridZero_LastStopClose = 0;
    g_gridZero_LastLimitClose = 0;
    g_gridZero_StopCycles = 0;
    g_gridZero_LimitCycles = 0;

    if(!Enable_GridZero) {
        if(DetailedLogging) {
            Print("[GridZero] Disabled - skipping initialization");
        }
        return;
    }

    Print("===================================================================");
    Print("  [GridZero] INITIALIZED");
    Print("===================================================================");
    PrintFormat("  Enable_GridZero: %s", Enable_GridZero ? "TRUE" : "FALSE");
    PrintFormat("  Trigger Level: L%d", GridZero_Trigger_Level);
    Print("===================================================================");
}

//+------------------------------------------------------------------+
//| RESET GRID ZERO FLAGS (called on CLOSE ALL and START)            |
//+------------------------------------------------------------------+
void ResetGridZeroFlags() {
    g_gridZeroInserted = false;
    g_gridZeroBiasUp = false;
    g_gridZeroBiasDown = false;
    g_gridZero_StopTicket = 0;
    g_gridZero_LimitTicket = 0;
    g_gridZero_StopStatus = ORDER_NONE;
    g_gridZero_LimitStatus = ORDER_NONE;
    g_gridZero_StopCycles = 0;
    g_gridZero_LimitCycles = 0;

    if(DetailedLogging) {
        Print("[GridZero] Flags reset");
    }
}

//+------------------------------------------------------------------+
//| CHECK AND INSERT GRID ZERO (called from OnTick)                  |
//+------------------------------------------------------------------+
void CheckAndInsertGridZero() {
    if(!Enable_GridZero) {
        return;
    }

    if(g_gridZeroInserted) {
        return;
    }

    if(systemState != STATE_ACTIVE) {
        return;
    }

    // Safety: Don't insert Grid Zero if Shield is active
    if(shield.isActive) {
        if(DetailedLogging) {
            Print("[GridZero] BLOCKED: Shield is active - cannot insert Grid Zero");
        }
        return;
    }

    // Check if entry point is valid
    if(entryPoint <= 0) {
        return;
    }

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double triggerDistance = currentSpacing_Pips * GridZero_Trigger_Level;
    double triggerPoints = PipsToPoints(triggerDistance);

    // Check BULLISH bias (price above entry by trigger distance)
    if(currentPrice > entryPoint + triggerPoints) {
        InsertGridZeroBearish();
        return;
    }

    // Check BEARISH bias (price below entry by trigger distance)
    if(currentPrice < entryPoint - triggerPoints) {
        InsertGridZeroBullish();
        return;
    }
}

//+------------------------------------------------------------------+
//| INSERT GRID ZERO BEARISH STRUCTURE (when bias is BULLISH)        |
//| Price above entry -> Insert SELL STOP + BUY LIMIT at center      |
//+------------------------------------------------------------------+
void InsertGridZeroBearish() {
    Print("===================================================================");
    Print("  [GridZero] INSERTING BEARISH STRUCTURE (Mean Reversion)");
    Print("===================================================================");
    PrintFormat("  Bias: BULLISH (price above entry)");
    PrintFormat("  Action: Insert BEARISH orders at center");
    PrintFormat("  Entry Point: %.5f", entryPoint);
    PrintFormat("  Current Price: %.5f", SymbolInfoDouble(_Symbol, SYMBOL_BID));
    Print("-------------------------------------------------------------------");

    double hedgeOffset = PipsToPoints(Hedge_Spacing_Pips);
    double spacing = PipsToPoints(currentSpacing_Pips);

    //--- Order 1: SELL STOP @ entryPoint ---
    double sellStopEntry = entryPoint;
    double sellStopTP = entryPoint - spacing;

    PrintFormat("  Order 1: SELL STOP");
    PrintFormat("    Entry: %.5f (entryPoint)", sellStopEntry);
    PrintFormat("    TP: %.5f (-%.1f pips)", sellStopTP, currentSpacing_Pips);
    PrintFormat("    Lot: %.2f", BaseLot);
    PrintFormat("    Magic: %d (GRID_B)", GetGridMagic(GRID_B));

    g_gridZero_StopTicket = PlacePendingOrder(
        ORDER_TYPE_SELL_STOP,
        BaseLot,
        sellStopEntry,
        0,  // No SL
        sellStopTP,
        "GridB-L0-SELL_STOP",
        GetGridMagic(GRID_B)
    );

    if(g_gridZero_StopTicket > 0) {
        Print("    SUCCESS: Ticket #", g_gridZero_StopTicket);
        g_gridZero_StopStatus = ORDER_PENDING;
    } else {
        Print("    ERROR: Failed to place SELL STOP - Error ", GetLastError());
    }

    Print("-------------------------------------------------------------------");

    //--- Order 2: BUY LIMIT @ entryPoint - hedge ---
    double buyLimitEntry = entryPoint - hedgeOffset;
    double buyLimitTP = entryPoint + spacing;

    PrintFormat("  Order 2: BUY LIMIT");
    PrintFormat("    Entry: %.5f (entryPoint - %.1f pips)", buyLimitEntry, Hedge_Spacing_Pips);
    PrintFormat("    TP: %.5f (+%.1f pips)", buyLimitTP, currentSpacing_Pips);
    PrintFormat("    Lot: %.2f", BaseLot);
    PrintFormat("    Magic: %d (GRID_A)", GetGridMagic(GRID_A));

    g_gridZero_LimitTicket = PlacePendingOrder(
        ORDER_TYPE_BUY_LIMIT,
        BaseLot,
        buyLimitEntry,
        0,  // No SL
        buyLimitTP,
        "GridA-L0-BUY_LIMIT",
        GetGridMagic(GRID_A)
    );

    if(g_gridZero_LimitTicket > 0) {
        Print("    SUCCESS: Ticket #", g_gridZero_LimitTicket);
        g_gridZero_LimitStatus = ORDER_PENDING;
    } else {
        Print("    ERROR: Failed to place BUY LIMIT - Error ", GetLastError());
    }

    // Set flags
    g_gridZeroInserted = true;
    g_gridZeroBiasUp = true;

    Print("===================================================================");
    Print("  [GridZero] BEARISH STRUCTURE COMPLETE");
    PrintFormat("  STOP Ticket: %d | LIMIT Ticket: %d",
                g_gridZero_StopTicket, g_gridZero_LimitTicket);
    Print("===================================================================");
}

//+------------------------------------------------------------------+
//| INSERT GRID ZERO BULLISH STRUCTURE (when bias is BEARISH)        |
//| Price below entry -> Insert BUY STOP + SELL LIMIT at center      |
//+------------------------------------------------------------------+
void InsertGridZeroBullish() {
    Print("===================================================================");
    Print("  [GridZero] INSERTING BULLISH STRUCTURE (Mean Reversion)");
    Print("===================================================================");
    PrintFormat("  Bias: BEARISH (price below entry)");
    PrintFormat("  Action: Insert BULLISH orders at center");
    PrintFormat("  Entry Point: %.5f", entryPoint);
    PrintFormat("  Current Price: %.5f", SymbolInfoDouble(_Symbol, SYMBOL_BID));
    Print("-------------------------------------------------------------------");

    double hedgeOffset = PipsToPoints(Hedge_Spacing_Pips);
    double spacing = PipsToPoints(currentSpacing_Pips);

    //--- Order 1: BUY STOP @ entryPoint ---
    double buyStopEntry = entryPoint;
    double buyStopTP = entryPoint + spacing;

    PrintFormat("  Order 1: BUY STOP");
    PrintFormat("    Entry: %.5f (entryPoint)", buyStopEntry);
    PrintFormat("    TP: %.5f (+%.1f pips)", buyStopTP, currentSpacing_Pips);
    PrintFormat("    Lot: %.2f", BaseLot);
    PrintFormat("    Magic: %d (GRID_A)", GetGridMagic(GRID_A));

    g_gridZero_StopTicket = PlacePendingOrder(
        ORDER_TYPE_BUY_STOP,
        BaseLot,
        buyStopEntry,
        0,  // No SL
        buyStopTP,
        "GridA-L0-BUY_STOP",
        GetGridMagic(GRID_A)
    );

    if(g_gridZero_StopTicket > 0) {
        Print("    SUCCESS: Ticket #", g_gridZero_StopTicket);
        g_gridZero_StopStatus = ORDER_PENDING;
    } else {
        Print("    ERROR: Failed to place BUY STOP - Error ", GetLastError());
    }

    Print("-------------------------------------------------------------------");

    //--- Order 2: SELL LIMIT @ entryPoint + hedge ---
    double sellLimitEntry = entryPoint + hedgeOffset;
    double sellLimitTP = entryPoint - spacing;

    PrintFormat("  Order 2: SELL LIMIT");
    PrintFormat("    Entry: %.5f (entryPoint + %.1f pips)", sellLimitEntry, Hedge_Spacing_Pips);
    PrintFormat("    TP: %.5f (-%.1f pips)", sellLimitTP, currentSpacing_Pips);
    PrintFormat("    Lot: %.2f", BaseLot);
    PrintFormat("    Magic: %d (GRID_B)", GetGridMagic(GRID_B));

    g_gridZero_LimitTicket = PlacePendingOrder(
        ORDER_TYPE_SELL_LIMIT,
        BaseLot,
        sellLimitEntry,
        0,  // No SL
        sellLimitTP,
        "GridB-L0-SELL_LIMIT",
        GetGridMagic(GRID_B)
    );

    if(g_gridZero_LimitTicket > 0) {
        Print("    SUCCESS: Ticket #", g_gridZero_LimitTicket);
        g_gridZero_LimitStatus = ORDER_PENDING;
    } else {
        Print("    ERROR: Failed to place SELL LIMIT - Error ", GetLastError());
    }

    // Set flags
    g_gridZeroInserted = true;
    g_gridZeroBiasDown = true;

    Print("===================================================================");
    Print("  [GridZero] BULLISH STRUCTURE COMPLETE");
    PrintFormat("  STOP Ticket: %d | LIMIT Ticket: %d",
                g_gridZero_StopTicket, g_gridZero_LimitTicket);
    Print("===================================================================");
}

//+------------------------------------------------------------------+
//| PROCESS GRID ZERO CYCLING (called from OnTick after grid cycling)|
//+------------------------------------------------------------------+
void ProcessGridZeroCycling() {
    if(!Enable_GridZero) return;
    if(!EnableCyclicReopen) return;
    if(!g_gridZeroInserted) return;

    // Check STOP order for cycling
    if(g_gridZero_StopStatus == ORDER_CLOSED_TP ||
       g_gridZero_StopStatus == ORDER_CLOSED_SL) {

        if(CanGridZeroReopen(true)) {
            ReopenGridZeroStop();
        }
    }

    // Check LIMIT order for cycling
    if(g_gridZero_LimitStatus == ORDER_CLOSED_TP ||
       g_gridZero_LimitStatus == ORDER_CLOSED_SL) {

        if(CanGridZeroReopen(false)) {
            ReopenGridZeroLimit();
        }
    }
}

//+------------------------------------------------------------------+
//| CHECK IF GRID ZERO CAN REOPEN                                    |
//+------------------------------------------------------------------+
bool CanGridZeroReopen(bool isStop) {
    // Check if cycling is enabled globally
    if(!EnableCyclicReopen) return false;

    // Check max cycles per level (if set)
    if(MaxCyclesPerLevel > 0) {
        int cycles = isStop ? g_gridZero_StopCycles : g_gridZero_LimitCycles;
        if(cycles >= MaxCyclesPerLevel) {
            if(DetailedLogging) {
                PrintFormat("[GridZero] Max cycles reached for %s: %d/%d",
                            isStop ? "STOP" : "LIMIT", cycles, MaxCyclesPerLevel);
            }
            return false;
        }
    }

    // Check cooldown (v5.8: no cooldown, always 0)
    datetime lastClose = isStop ? g_gridZero_LastStopClose : g_gridZero_LastLimitClose;
    if(lastClose > 0 && GRIDZERO_COOLDOWN_SECONDS > 0) {
        if(TimeCurrent() - lastClose < GRIDZERO_COOLDOWN_SECONDS) {
            return false;
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| REOPEN GRID ZERO STOP ORDER                                      |
//+------------------------------------------------------------------+
void ReopenGridZeroStop() {
    // Reset status
    g_gridZero_StopStatus = ORDER_NONE;
    g_gridZero_StopTicket = 0;

    double spacing = PipsToPoints(currentSpacing_Pips);

    if(g_gridZeroBiasUp) {
        // Reopen SELL STOP @ entryPoint
        double sellStopTP = entryPoint - spacing;

        g_gridZero_StopTicket = PlacePendingOrder(
            ORDER_TYPE_SELL_STOP,
            BaseLot,
            entryPoint,
            0,
            sellStopTP,
            "GridB-L0-SELL_STOP",
            GetGridMagic(GRID_B)
        );
    } else {
        // Reopen BUY STOP @ entryPoint
        double buyStopTP = entryPoint + spacing;

        g_gridZero_StopTicket = PlacePendingOrder(
            ORDER_TYPE_BUY_STOP,
            BaseLot,
            entryPoint,
            0,
            buyStopTP,
            "GridA-L0-BUY_STOP",
            GetGridMagic(GRID_A)
        );
    }

    if(g_gridZero_StopTicket > 0) {
        g_gridZero_StopStatus = ORDER_PENDING;
        g_gridZero_StopCycles++;

        Print("===================================================================");
        Print("  [GridZero] CYCLING - STOP REOPENED");
        PrintFormat("  Ticket: #%d", g_gridZero_StopTicket);
        PrintFormat("  Cycle: %d", g_gridZero_StopCycles);
        PrintFormat("  Type: %s", g_gridZeroBiasUp ? "SELL STOP" : "BUY STOP");
        Print("===================================================================");
    }
}

//+------------------------------------------------------------------+
//| REOPEN GRID ZERO LIMIT ORDER                                     |
//+------------------------------------------------------------------+
void ReopenGridZeroLimit() {
    // Reset status
    g_gridZero_LimitStatus = ORDER_NONE;
    g_gridZero_LimitTicket = 0;

    double hedgeOffset = PipsToPoints(Hedge_Spacing_Pips);
    double spacing = PipsToPoints(currentSpacing_Pips);

    if(g_gridZeroBiasUp) {
        // Reopen BUY LIMIT @ entryPoint - hedge
        double buyLimitEntry = entryPoint - hedgeOffset;
        double buyLimitTP = entryPoint + spacing;

        g_gridZero_LimitTicket = PlacePendingOrder(
            ORDER_TYPE_BUY_LIMIT,
            BaseLot,
            buyLimitEntry,
            0,
            buyLimitTP,
            "GridA-L0-BUY_LIMIT",
            GetGridMagic(GRID_A)
        );
    } else {
        // Reopen SELL LIMIT @ entryPoint + hedge
        double sellLimitEntry = entryPoint + hedgeOffset;
        double sellLimitTP = entryPoint - spacing;

        g_gridZero_LimitTicket = PlacePendingOrder(
            ORDER_TYPE_SELL_LIMIT,
            BaseLot,
            sellLimitEntry,
            0,
            sellLimitTP,
            "GridB-L0-SELL_LIMIT",
            GetGridMagic(GRID_B)
        );
    }

    if(g_gridZero_LimitTicket > 0) {
        g_gridZero_LimitStatus = ORDER_PENDING;
        g_gridZero_LimitCycles++;

        Print("===================================================================");
        Print("  [GridZero] CYCLING - LIMIT REOPENED");
        PrintFormat("  Ticket: #%d", g_gridZero_LimitTicket);
        PrintFormat("  Cycle: %d", g_gridZero_LimitCycles);
        PrintFormat("  Type: %s", g_gridZeroBiasUp ? "BUY LIMIT" : "SELL LIMIT");
        Print("===================================================================");
    }
}

//+------------------------------------------------------------------+
//| UPDATE GRID ZERO STATUS (called from OnTradeTransaction)         |
//+------------------------------------------------------------------+
void UpdateGridZeroStatus(ulong ticket, ENUM_ORDER_STATUS newStatus) {
    if(!Enable_GridZero) return;
    if(!g_gridZeroInserted) return;

    // Check if this ticket belongs to Grid Zero
    if(ticket == g_gridZero_StopTicket) {
        ENUM_ORDER_STATUS oldStatus = g_gridZero_StopStatus;
        g_gridZero_StopStatus = newStatus;

        if(newStatus == ORDER_CLOSED_TP || newStatus == ORDER_CLOSED_SL) {
            g_gridZero_LastStopClose = TimeCurrent();
        }

        if(DetailedLogging) {
            PrintFormat("[GridZero] STOP status: %s -> %s",
                        GetOrderStatusName(oldStatus),
                        GetOrderStatusName(newStatus));
        }
    }

    if(ticket == g_gridZero_LimitTicket) {
        ENUM_ORDER_STATUS oldStatus = g_gridZero_LimitStatus;
        g_gridZero_LimitStatus = newStatus;

        if(newStatus == ORDER_CLOSED_TP || newStatus == ORDER_CLOSED_SL) {
            g_gridZero_LastLimitClose = TimeCurrent();
        }

        if(DetailedLogging) {
            PrintFormat("[GridZero] LIMIT status: %s -> %s",
                        GetOrderStatusName(oldStatus),
                        GetOrderStatusName(newStatus));
        }
    }
}

//+------------------------------------------------------------------+
//| CHECK IF TICKET IS GRID ZERO ORDER                               |
//+------------------------------------------------------------------+
bool IsGridZeroTicket(ulong ticket) {
    return (ticket == g_gridZero_StopTicket || ticket == g_gridZero_LimitTicket);
}

//+------------------------------------------------------------------+
//| GET GRID ZERO STATUS STRING (for dashboard)                      |
//+------------------------------------------------------------------+
string GetGridZeroStatusText() {
    if(!Enable_GridZero) return "DISABLED";
    if(!g_gridZeroInserted) return "WAITING";

    if(g_gridZero_StopStatus == ORDER_FILLED ||
       g_gridZero_LimitStatus == ORDER_FILLED) {
        return "IN TRADE";
    }

    if(g_gridZero_StopStatus == ORDER_PENDING ||
       g_gridZero_LimitStatus == ORDER_PENDING) {
        return "ACTIVE";
    }

    return "CYCLING";
}

//+------------------------------------------------------------------+
//| GET GRID ZERO BIAS STRING (for dashboard)                        |
//+------------------------------------------------------------------+
string GetGridZeroBiasText() {
    if(g_gridZeroBiasUp) return "BULLISH";
    if(g_gridZeroBiasDown) return "BEARISH";
    return "NONE";
}

//+------------------------------------------------------------------+
//| DEINITIALIZE GRID ZERO                                           |
//+------------------------------------------------------------------+
void DeinitializeGridZero() {
    if(!Enable_GridZero) return;

    Print("===================================================================");
    Print("  [GridZero] SESSION SUMMARY");
    Print("===================================================================");
    PrintFormat("  Total STOP Cycles: %d", g_gridZero_StopCycles);
    PrintFormat("  Total LIMIT Cycles: %d", g_gridZero_LimitCycles);
    PrintFormat("  Final Bias: %s", GetGridZeroBiasText());
    Print("===================================================================");
}

//+------------------------------------------------------------------+
