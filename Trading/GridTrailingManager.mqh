//+------------------------------------------------------------------+
//|                                          GridTrailingManager.mqh |
//|                        Sugamara v3.0 - Asymmetric Trailing Stop  |
//|                                                                  |
//|  Trailing asimmetrico per Grid Neutral:                          |
//|  - Aggressivo (5 pips) per grid VERSO breakout                   |
//|  - Conservativo (15 pips) per grid CONTRO breakout               |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| TRAILING STRUCTURES                                              |
//+------------------------------------------------------------------+

struct TrailingTracker {
    ulong    ticket;                    // Ticket posizione
    double   entry_price;               // Prezzo entry
    double   current_sl;                // SL attuale
    double   highest_price;             // Prezzo più alto raggiunto (LONG)
    double   lowest_price;              // Prezzo più basso raggiunto (SHORT)
    ENUM_TRAILING_TYPE type;            // Tipo trailing
    bool     is_active;                 // Trailing attivo
    double   activation_price;          // Prezzo attivazione trailing
    double   trailing_distance;         // Distanza trailing in punti
};

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+

TrailingTracker trailing_GridA_Upper[];
TrailingTracker trailing_GridA_Lower[];
TrailingTracker trailing_GridB_Upper[];
TrailingTracker trailing_GridB_Lower[];
TrailingTracker trailing_Shield;

int trailingAdjustments = 0;            // Numero aggiustamenti trailing

//+------------------------------------------------------------------+
//| Initialize Trailing Manager                                      |
//+------------------------------------------------------------------+
bool InitializeTrailingManager() {
    if(!Enable_TrailingAsymmetric) {
        Print("INFO: Asymmetric Trailing is DISABLED");
        return true;
    }

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  INITIALIZING ASYMMETRIC TRAILING MANAGER v3.0");
    Print("═══════════════════════════════════════════════════════════════════");

    // Resize arrays
    ArrayResize(trailing_GridA_Upper, GridLevelsPerSide);
    ArrayResize(trailing_GridA_Lower, GridLevelsPerSide);
    ArrayResize(trailing_GridB_Upper, GridLevelsPerSide);
    ArrayResize(trailing_GridB_Lower, GridLevelsPerSide);

    // Initialize all trackers
    for(int i = 0; i < GridLevelsPerSide; i++) {
        ResetTrailingTracker(trailing_GridA_Upper[i]);
        ResetTrailingTracker(trailing_GridA_Lower[i]);
        ResetTrailingTracker(trailing_GridB_Upper[i]);
        ResetTrailingTracker(trailing_GridB_Lower[i]);
    }

    ResetTrailingTracker(trailing_Shield);
    trailingAdjustments = 0;

    Print("  Aggressive Trailing: ", Trailing_Aggressive_Pips, " pips (toward breakout)");
    Print("  Conservative Trailing: ", Trailing_Conservative_Pips, " pips (against breakout)");
    Print("  Activation: ", Trailing_Activation_Pips, " pips profit");
    Print("  Step: ", Trailing_Step_Pips, " pips");
    Print("═══════════════════════════════════════════════════════════════════");

    return true;
}

//+------------------------------------------------------------------+
//| Reset Trailing Tracker                                           |
//+------------------------------------------------------------------+
void ResetTrailingTracker(TrailingTracker &tracker) {
    tracker.ticket = 0;
    tracker.entry_price = 0;
    tracker.current_sl = 0;
    tracker.highest_price = 0;
    tracker.lowest_price = DBL_MAX;
    tracker.type = TRAILING_NONE;
    tracker.is_active = false;
    tracker.activation_price = 0;
    tracker.trailing_distance = 0;
}

//+------------------------------------------------------------------+
//| Setup Trailing for Position                                      |
//+------------------------------------------------------------------+
void SetupTrailing(ulong ticket, double entry, ENUM_GRID_SIDE side,
                   ENUM_GRID_ZONE zone, int level) {

    if(!Enable_TrailingAsymmetric) return;

    TrailingTracker tracker;
    tracker.ticket = ticket;
    tracker.entry_price = entry;
    tracker.current_sl = 0;
    tracker.highest_price = entry;
    tracker.lowest_price = entry;
    tracker.is_active = false;

    // Determine trailing type based on grid position relative to breakout
    // Logic: Grid toward breakout = aggressive, grid against = conservative
    //
    // UPPER ZONE:
    //   Grid A (LONG) -> toward upper breakout = AGGRESSIVE
    //   Grid B (SHORT) -> against upper breakout = CONSERVATIVE
    //
    // LOWER ZONE:
    //   Grid A (SELL) -> toward lower breakout = AGGRESSIVE
    //   Grid B (BUY) -> against lower breakout = CONSERVATIVE

    if(zone == ZONE_UPPER) {
        if(side == GRID_A) {
            // Grid A Upper = LONG toward resistance = AGGRESSIVE
            tracker.type = TRAILING_AGGRESSIVE;
            tracker.trailing_distance = Trailing_Aggressive_Pips * symbolPoint * 10;
        } else {
            // Grid B Upper = SHORT toward resistance = CONSERVATIVE (against trend)
            tracker.type = TRAILING_CONSERVATIVE;
            tracker.trailing_distance = Trailing_Conservative_Pips * symbolPoint * 10;
        }
    } else {
        if(side == GRID_A) {
            // Grid A Lower = SELL toward support = AGGRESSIVE
            tracker.type = TRAILING_AGGRESSIVE;
            tracker.trailing_distance = Trailing_Aggressive_Pips * symbolPoint * 10;
        } else {
            // Grid B Lower = BUY toward support = CONSERVATIVE (against trend)
            tracker.type = TRAILING_CONSERVATIVE;
            tracker.trailing_distance = Trailing_Conservative_Pips * symbolPoint * 10;
        }
    }

    // Calculate activation price
    double activationPoints = Trailing_Activation_Pips * symbolPoint * 10;

    // Need to determine if position is LONG or SHORT
    if(PositionSelectByTicket(ticket)) {
        long posType = PositionGetInteger(POSITION_TYPE);
        if(posType == POSITION_TYPE_BUY) {
            tracker.activation_price = entry + activationPoints;
        } else {
            tracker.activation_price = entry - activationPoints;
        }
    }

    // Store in appropriate array
    if(side == GRID_A) {
        if(zone == ZONE_UPPER) trailing_GridA_Upper[level] = tracker;
        else trailing_GridA_Lower[level] = tracker;
    } else {
        if(zone == ZONE_UPPER) trailing_GridB_Upper[level] = tracker;
        else trailing_GridB_Lower[level] = tracker;
    }

    if(DetailedLogging) {
        Print("Trailing setup: Ticket ", ticket, " Type: ",
              (tracker.type == TRAILING_AGGRESSIVE ? "AGGRESSIVE" : "CONSERVATIVE"),
              " Distance: ", DoubleToString(tracker.trailing_distance / symbolPoint / 10, 1), " pips");
    }
}

//+------------------------------------------------------------------+
//| Setup Trailing for Shield                                        |
//+------------------------------------------------------------------+
void SetupTrailingShield(ulong ticket, double entry, bool isLong) {
    if(!Enable_TrailingAsymmetric) return;

    trailing_Shield.ticket = ticket;
    trailing_Shield.entry_price = entry;
    trailing_Shield.current_sl = 0;
    trailing_Shield.highest_price = entry;
    trailing_Shield.lowest_price = entry;
    trailing_Shield.is_active = false;
    trailing_Shield.type = TRAILING_AGGRESSIVE; // Shield always aggressive
    trailing_Shield.trailing_distance = Trailing_Aggressive_Pips * symbolPoint * 10;

    double activationPoints = Trailing_Activation_Pips * symbolPoint * 10;
    if(isLong) {
        trailing_Shield.activation_price = entry + activationPoints;
    } else {
        trailing_Shield.activation_price = entry - activationPoints;
    }

    Print("Shield Trailing setup: ", (isLong ? "LONG" : "SHORT"),
          " Activation@", DoubleToString(trailing_Shield.activation_price, _Digits));
}

//+------------------------------------------------------------------+
//| Process All Trailing Stops                                       |
//+------------------------------------------------------------------+
void ProcessTrailingStops() {
    if(!Enable_TrailingAsymmetric) return;

    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // Process Grid A
    for(int i = 0; i < GridLevelsPerSide; i++) {
        ProcessSingleTrailing(trailing_GridA_Upper[i], currentBid, currentAsk);
        ProcessSingleTrailing(trailing_GridA_Lower[i], currentBid, currentAsk);
    }

    // Process Grid B
    for(int i = 0; i < GridLevelsPerSide; i++) {
        ProcessSingleTrailing(trailing_GridB_Upper[i], currentBid, currentAsk);
        ProcessSingleTrailing(trailing_GridB_Lower[i], currentBid, currentAsk);
    }

    // Process Shield
    if(trailing_Shield.ticket > 0) {
        ProcessSingleTrailing(trailing_Shield, currentBid, currentAsk);
    }
}

//+------------------------------------------------------------------+
//| Process Single Trailing Stop                                     |
//+------------------------------------------------------------------+
void ProcessSingleTrailing(TrailingTracker &tracker, double bid, double ask) {
    if(tracker.ticket == 0) return;

    // Check if position exists
    if(!PositionSelectByTicket(tracker.ticket)) {
        ResetTrailingTracker(tracker);
        return;
    }

    long posType = PositionGetInteger(POSITION_TYPE);
    bool isLong = (posType == POSITION_TYPE_BUY);
    double currentPrice = isLong ? bid : ask;

    // Update high/low
    if(isLong) {
        if(currentPrice > tracker.highest_price) {
            tracker.highest_price = currentPrice;
        }
    } else {
        if(currentPrice < tracker.lowest_price) {
            tracker.lowest_price = currentPrice;
        }
    }

    // Check activation
    if(!tracker.is_active) {
        bool activated = isLong ?
            (currentPrice >= tracker.activation_price) :
            (currentPrice <= tracker.activation_price);

        if(activated) {
            tracker.is_active = true;

            // Set initial trailing SL
            if(isLong) {
                tracker.current_sl = tracker.highest_price - tracker.trailing_distance;
            } else {
                tracker.current_sl = tracker.lowest_price + tracker.trailing_distance;
            }

            if(DetailedLogging) {
                Print("Trailing ACTIVATED: Ticket ", tracker.ticket,
                      " Initial SL: ", DoubleToString(tracker.current_sl, _Digits));
            }

            // Apply SL to position
            ModifyPositionSL(tracker.ticket, tracker.current_sl);
        }
        return;
    }

    // Trailing is active - check for SL adjustment
    double stepPoints = Trailing_Step_Pips * symbolPoint * 10;
    double newSL = 0;

    if(isLong) {
        newSL = tracker.highest_price - tracker.trailing_distance;

        // Only move SL if improvement >= step
        if(newSL > tracker.current_sl + stepPoints) {
            tracker.current_sl = newSL;
            ModifyPositionSL(tracker.ticket, newSL);
            trailingAdjustments++;

            if(DetailedLogging) {
                Print("Trailing SL adjusted: Ticket ", tracker.ticket,
                      " New SL: ", DoubleToString(newSL, _Digits),
                      " (", GetTrailingTypeName(tracker.type), ")");
            }
        }
    } else {
        newSL = tracker.lowest_price + tracker.trailing_distance;

        // Only move SL if improvement >= step
        if(newSL < tracker.current_sl - stepPoints || tracker.current_sl == 0) {
            tracker.current_sl = newSL;
            ModifyPositionSL(tracker.ticket, newSL);
            trailingAdjustments++;

            if(DetailedLogging) {
                Print("Trailing SL adjusted: Ticket ", tracker.ticket,
                      " New SL: ", DoubleToString(newSL, _Digits),
                      " (", GetTrailingTypeName(tracker.type), ")");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Modify Position Stop Loss                                        |
//+------------------------------------------------------------------+
bool ModifyPositionSL(ulong ticket, double newSL) {
    if(!PositionSelectByTicket(ticket)) return false;

    double currentTP = PositionGetDouble(POSITION_TP);
    double currentSL = PositionGetDouble(POSITION_SL);

    // Skip if SL hasn't changed significantly
    if(MathAbs(newSL - currentSL) < symbolPoint) return true;

    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.action = TRADE_ACTION_SLTP;
    request.position = ticket;
    request.symbol = _Symbol;
    request.sl = NormalizeDouble(newSL, _Digits);
    request.tp = currentTP;

    if(!OrderSend(request, result)) {
        if(DetailedLogging) {
            Print("ERROR: Failed to modify SL for ticket ", ticket, " - ", result.retcode);
        }
        return false;
    }

    return (result.retcode == TRADE_RETCODE_DONE);
}

//+------------------------------------------------------------------+
//| Get Trailing Type Name                                           |
//+------------------------------------------------------------------+
string GetTrailingTypeName(ENUM_TRAILING_TYPE type) {
    switch(type) {
        case TRAILING_NONE:         return "None";
        case TRAILING_AGGRESSIVE:   return "Aggressive";
        case TRAILING_CONSERVATIVE: return "Conservative";
    }
    return "Unknown";
}

//+------------------------------------------------------------------+
//| Clear Trailing for Closed Position                               |
//+------------------------------------------------------------------+
void ClearTrailing(ulong ticket) {
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(trailing_GridA_Upper[i].ticket == ticket) ResetTrailingTracker(trailing_GridA_Upper[i]);
        if(trailing_GridA_Lower[i].ticket == ticket) ResetTrailingTracker(trailing_GridA_Lower[i]);
        if(trailing_GridB_Upper[i].ticket == ticket) ResetTrailingTracker(trailing_GridB_Upper[i]);
        if(trailing_GridB_Lower[i].ticket == ticket) ResetTrailingTracker(trailing_GridB_Lower[i]);
    }

    if(trailing_Shield.ticket == ticket) ResetTrailingTracker(trailing_Shield);
}

//+------------------------------------------------------------------+
//| Get Trailing Statistics                                          |
//+------------------------------------------------------------------+
int GetTrailingAdjustments() {
    return trailingAdjustments;
}

//+------------------------------------------------------------------+
//| Deinitialize Trailing Manager                                    |
//+------------------------------------------------------------------+
void DeinitializeTrailingManager() {
    ArrayFree(trailing_GridA_Upper);
    ArrayFree(trailing_GridA_Lower);
    ArrayFree(trailing_GridB_Upper);
    ArrayFree(trailing_GridB_Lower);

    Print("Trailing Manager: Total Adjustments: ", trailingAdjustments);
}

