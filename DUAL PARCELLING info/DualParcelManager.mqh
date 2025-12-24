//+------------------------------------------------------------------+
//|                                          DualParcelManager.mqh   |
//|                        Sugamara v5.2 - Dual Parcelling           |
//|                                                                  |
//|  Split ordini in 2 parcels con TP e BE differenziati             |
//|  - Parcel A: TP corto (1 livello), BE veloce                     |
//|  - Parcel B: TP lungo (2 livelli), BE ritardato                  |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| DUAL PARCEL ENUMS                                                |
//+------------------------------------------------------------------+
enum ENUM_PARCEL_STATE {
    PARCEL_INACTIVE = 0,        // Posizione non ancora attiva
    PARCEL_TRACKING = 1,        // Tracking attivo, nessun BE
    PARCEL_SL_AT_BE = 2,        // SL spostato a Break Even
    PARCEL_CLOSED = 3           // Parcel chiuso (TP o SL hit)
};

//+------------------------------------------------------------------+
//| DUAL PARCEL STRUCTURE - Tracking per singolo parcel              |
//+------------------------------------------------------------------+
struct ParcelData {
    ENUM_PARCEL_STATE state;    // Stato corrente del parcel
    double targetTP;            // Prezzo TP target per questo parcel
    double lotSize;             // Lot size di questo parcel
    double bePrice;             // Prezzo BE (= entry originale)
    double slToBE_Progress;     // % progress per spostare SL a BE
    double beConfirm_Progress;  // % progress per confermare BE
    bool slMovedToBE;           // Flag: SL già spostato a BE
    bool closed;                // Flag: parcel chiuso
    double closedProfit;        // Profit realizzato alla chiusura
};

//+------------------------------------------------------------------+
//| DUAL PARCEL TRACKER - Tracking per singola posizione             |
//+------------------------------------------------------------------+
struct DualParcelTracker {
    // Identificazione
    ulong positionTicket;       // Ticket della posizione
    ENUM_GRID_SIDE gridSide;    // GRID_A o GRID_B
    ENUM_GRID_ZONE gridZone;    // ZONE_UPPER o ZONE_LOWER
    int gridLevel;              // Livello grid (0-9)
    
    // Dati posizione originale
    double entryPrice;          // Prezzo entry
    double originalLot;         // Lot totale originale
    double originalTP;          // TP originale (usato per calcoli)
    double spacing;             // Spacing in prezzo (per calcolo TP2)
    bool isBuyPosition;         // true = BUY, false = SELL
    
    // Parcels
    ParcelData parcelA;         // Parcel A: TP corto
    ParcelData parcelB;         // Parcel B: TP lungo
    
    // Stato generale
    bool isActive;              // Tracker attivo
    bool fullyProcessed;        // Entrambi i parcels gestiti
    double currentLot;          // Lot rimanente nella posizione
    datetime activationTime;    // Quando è stato attivato
};

//+------------------------------------------------------------------+
//| GLOBAL ARRAYS - Un tracker per ogni livello grid                 |
//+------------------------------------------------------------------+
DualParcelTracker g_dualParcels_GridA_Upper[10];
DualParcelTracker g_dualParcels_GridA_Lower[10];
DualParcelTracker g_dualParcels_GridB_Upper[10];
DualParcelTracker g_dualParcels_GridB_Lower[10];

//+------------------------------------------------------------------+
//| STATISTICS                                                       |
//+------------------------------------------------------------------+
int g_dualParcel_ParcelA_Closed = 0;    // Contatore Parcel A chiusi
int g_dualParcel_ParcelB_Closed = 0;    // Contatore Parcel B chiusi
double g_dualParcel_TotalProfit = 0;    // Profit totale da chiusure parziali
int g_dualParcel_BE_Activations = 0;    // Contatore BE attivati

//+------------------------------------------------------------------+
//| Initialize Dual Parcel Manager                                   |
//+------------------------------------------------------------------+
bool InitializeDualParcelManager() {
    if(!Enable_DualParcelling) {
        Print("INFO: Dual Parcelling is DISABLED");
        return true;
    }
    
    Print("╔═══════════════════════════════════════════════════════════════════╗");
    Print("║  INITIALIZING DUAL PARCEL MANAGER v5.2                            ║");
    Print("╚═══════════════════════════════════════════════════════════════════╝");
    
    // Validate lot size
    double parcelLot = BaseLot / 2.0;
    if(parcelLot < symbolMinLot) {
        Print("ERROR: Parcel lot ", DoubleToString(parcelLot, 2), 
              " < broker minimum ", DoubleToString(symbolMinLot, 2));
        Print("       Increase BaseLot to at least ", DoubleToString(symbolMinLot * 2, 2));
        return false;
    }
    
    // Initialize all trackers
    for(int i = 0; i < 10; i++) {
        ResetDualParcelTracker(g_dualParcels_GridA_Upper[i]);
        ResetDualParcelTracker(g_dualParcels_GridA_Lower[i]);
        ResetDualParcelTracker(g_dualParcels_GridB_Upper[i]);
        ResetDualParcelTracker(g_dualParcels_GridB_Lower[i]);
    }
    
    // Reset statistics
    g_dualParcel_ParcelA_Closed = 0;
    g_dualParcel_ParcelB_Closed = 0;
    g_dualParcel_TotalProfit = 0;
    g_dualParcel_BE_Activations = 0;
    
    // Log configuration
    Print("  Configuration:");
    Print("  ├─ Parcel A: TP = Entry + ", ParcelA_TP_Levels, " level(s)");
    Print("  │           SL→BE at ", DoubleToString(ParcelA_SL_ToBE_Pct, 0), "% | BE confirm at ", DoubleToString(ParcelA_BE_Trigger_Pct, 0), "%");
    Print("  ├─ Parcel B: TP = Entry + ", ParcelB_TP_Levels, " level(s)");
    Print("  │           SL→BE at ", DoubleToString(ParcelB_SL_ToBE_Pct, 0), "% | BE confirm at ", DoubleToString(ParcelB_BE_Trigger_Pct, 0), "%");
    Print("  └─ Lot Split: ", DoubleToString(DualParcel_LotRatio * 100, 0), "% / ", DoubleToString((1-DualParcel_LotRatio) * 100, 0), "%");
    Print("═══════════════════════════════════════════════════════════════════");
    
    return true;
}

//+------------------------------------------------------------------+
//| Reset Single Tracker                                             |
//+------------------------------------------------------------------+
void ResetDualParcelTracker(DualParcelTracker &tracker) {
    tracker.positionTicket = 0;
    tracker.gridSide = GRID_A;
    tracker.gridZone = ZONE_UPPER;
    tracker.gridLevel = 0;
    tracker.entryPrice = 0;
    tracker.originalLot = 0;
    tracker.originalTP = 0;
    tracker.spacing = 0;
    tracker.isBuyPosition = true;
    tracker.isActive = false;
    tracker.fullyProcessed = false;
    tracker.currentLot = 0;
    tracker.activationTime = 0;
    
    // Reset Parcel A
    tracker.parcelA.state = PARCEL_INACTIVE;
    tracker.parcelA.targetTP = 0;
    tracker.parcelA.lotSize = 0;
    tracker.parcelA.bePrice = 0;
    tracker.parcelA.slToBE_Progress = 0;
    tracker.parcelA.beConfirm_Progress = 0;
    tracker.parcelA.slMovedToBE = false;
    tracker.parcelA.closed = false;
    tracker.parcelA.closedProfit = 0;
    
    // Reset Parcel B
    tracker.parcelB.state = PARCEL_INACTIVE;
    tracker.parcelB.targetTP = 0;
    tracker.parcelB.lotSize = 0;
    tracker.parcelB.bePrice = 0;
    tracker.parcelB.slToBE_Progress = 0;
    tracker.parcelB.beConfirm_Progress = 0;
    tracker.parcelB.slMovedToBE = false;
    tracker.parcelB.closed = false;
    tracker.parcelB.closedProfit = 0;
}

//+------------------------------------------------------------------+
//| Get Tracker Reference by Grid Position                           |
//+------------------------------------------------------------------+
DualParcelTracker* GetDualParcelTracker(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(level < 0 || level >= 10) return NULL;
    
    if(side == GRID_A) {
        if(zone == ZONE_UPPER) return GetPointer(g_dualParcels_GridA_Upper[level]);
        else return GetPointer(g_dualParcels_GridA_Lower[level]);
    } else {
        if(zone == ZONE_UPPER) return GetPointer(g_dualParcels_GridB_Upper[level]);
        else return GetPointer(g_dualParcels_GridB_Lower[level]);
    }
}

//+------------------------------------------------------------------+
//| Setup Dual Parcel Tracking for Newly Filled Position             |
//| Called when order status changes to ORDER_FILLED                 |
//+------------------------------------------------------------------+
void SetupDualParcelTracking(ulong ticket, ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, 
                              int level, double entryPrice, double lot, double tp, double spacing) {
    if(!Enable_DualParcelling) return;
    
    DualParcelTracker* tracker = GetDualParcelTracker(side, zone, level);
    if(tracker == NULL) return;
    
    // Determine position direction
    bool isBuy = IsGridOrderBuy(side, zone);
    
    // Calculate spacing in price terms
    double spacingPrice = PipsToPoints(spacing);
    
    // Calculate TP targets
    double tp1Distance = spacingPrice * ParcelA_TP_Levels;
    double tp2Distance = spacingPrice * ParcelB_TP_Levels;
    
    double tpParcelA, tpParcelB;
    if(isBuy) {
        tpParcelA = entryPrice + tp1Distance;
        tpParcelB = entryPrice + tp2Distance;
    } else {
        tpParcelA = entryPrice - tp1Distance;
        tpParcelB = entryPrice - tp2Distance;
    }
    
    // Calculate lot sizes
    double lotParcelA = NormalizeDouble(lot * DualParcel_LotRatio, 2);
    double lotParcelB = NormalizeDouble(lot - lotParcelA, 2);
    
    // Ensure minimum lot
    if(lotParcelA < symbolMinLot) lotParcelA = symbolMinLot;
    if(lotParcelB < symbolMinLot) lotParcelB = symbolMinLot;
    
    // Setup tracker
    tracker.positionTicket = ticket;
    tracker.gridSide = side;
    tracker.gridZone = zone;
    tracker.gridLevel = level;
    tracker.entryPrice = entryPrice;
    tracker.originalLot = lot;
    tracker.originalTP = tp;
    tracker.spacing = spacingPrice;
    tracker.isBuyPosition = isBuy;
    tracker.isActive = true;
    tracker.fullyProcessed = false;
    tracker.currentLot = lot;
    tracker.activationTime = TimeCurrent();
    
    // Setup Parcel A
    tracker.parcelA.state = PARCEL_TRACKING;
    tracker.parcelA.targetTP = tpParcelA;
    tracker.parcelA.lotSize = lotParcelA;
    tracker.parcelA.bePrice = entryPrice;
    tracker.parcelA.slToBE_Progress = ParcelA_SL_ToBE_Pct;
    tracker.parcelA.beConfirm_Progress = ParcelA_BE_Trigger_Pct;
    tracker.parcelA.slMovedToBE = false;
    tracker.parcelA.closed = false;
    tracker.parcelA.closedProfit = 0;
    
    // Setup Parcel B
    tracker.parcelB.state = PARCEL_TRACKING;
    tracker.parcelB.targetTP = tpParcelB;
    tracker.parcelB.lotSize = lotParcelB;
    tracker.parcelB.bePrice = entryPrice;
    tracker.parcelB.slToBE_Progress = ParcelB_SL_ToBE_Pct;
    tracker.parcelB.beConfirm_Progress = ParcelB_BE_Trigger_Pct;
    tracker.parcelB.slMovedToBE = false;
    tracker.parcelB.closed = false;
    tracker.parcelB.closedProfit = 0;
    
    // Modify position TP to Parcel B target (il più lontano)
    if(PositionSelectByTicket(ticket)) {
        double currentSL = PositionGetDouble(POSITION_SL);
        trade.PositionModify(ticket, currentSL, tpParcelB);
    }
    
    Print("╔═══════════════════════════════════════════════════════════════════╗");
    Print("║  DUAL PARCEL TRACKING ACTIVATED                                   ║");
    Print("╠═══════════════════════════════════════════════════════════════════╣");
    Print("║  Position: #", ticket, " | ", GetGridSideName(side), "-", GetGridZoneName(zone), "-L", level+1);
    Print("║  Entry: ", DoubleToString(entryPrice, _Digits), " | Direction: ", isBuy ? "BUY" : "SELL");
    Print("╠───────────────────────────────────────────────────────────────────╣");
    Print("║  Parcel A: ", DoubleToString(lotParcelA, 2), " lot");
    Print("║           TP1 = ", DoubleToString(tpParcelA, _Digits), " (", ParcelA_TP_Levels, " level)");
    Print("║           SL→BE at ", DoubleToString(ParcelA_SL_ToBE_Pct, 0), "% | Confirm at ", DoubleToString(ParcelA_BE_Trigger_Pct, 0), "%");
    Print("╠───────────────────────────────────────────────────────────────────╣");
    Print("║  Parcel B: ", DoubleToString(lotParcelB, 2), " lot");
    Print("║           TP2 = ", DoubleToString(tpParcelB, _Digits), " (", ParcelB_TP_Levels, " levels)");
    Print("║           SL→BE at ", DoubleToString(ParcelB_SL_ToBE_Pct, 0), "% | Confirm at ", DoubleToString(ParcelB_BE_Trigger_Pct, 0), "%");
    Print("╚═══════════════════════════════════════════════════════════════════╝");
}

//+------------------------------------------------------------------+
//| Calculate Progress Percentage toward TP                          |
//| Returns: 0-100% for Parcel A, can exceed 100% for Parcel B calc  |
//+------------------------------------------------------------------+
double CalculateProgressPercent(DualParcelTracker &tracker, double currentPrice) {
    if(tracker.entryPrice == 0 || tracker.parcelA.targetTP == 0) return 0;
    
    double totalDistance = MathAbs(tracker.parcelA.targetTP - tracker.entryPrice);
    if(totalDistance == 0) return 0;
    
    double currentDistance;
    if(tracker.isBuyPosition) {
        currentDistance = currentPrice - tracker.entryPrice;
    } else {
        currentDistance = tracker.entryPrice - currentPrice;
    }
    
    // Progress can be negative (in loss) or > 100% (beyond TP1)
    return (currentDistance / totalDistance) * 100.0;
}

//+------------------------------------------------------------------+
//| Process All Dual Parcels - Main tick function                    |
//+------------------------------------------------------------------+
void ProcessDualParcels() {
    if(!Enable_DualParcelling) return;
    
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    
    // Process all grids
    for(int i = 0; i < GridLevelsPerSide; i++) {
        ProcessSingleDualParcel(g_dualParcels_GridA_Upper[i], currentPrice);
        ProcessSingleDualParcel(g_dualParcels_GridA_Lower[i], currentPrice);
        ProcessSingleDualParcel(g_dualParcels_GridB_Upper[i], currentPrice);
        ProcessSingleDualParcel(g_dualParcels_GridB_Lower[i], currentPrice);
    }
}

//+------------------------------------------------------------------+
//| Process Single Dual Parcel Tracker                               |
//+------------------------------------------------------------------+
void ProcessSingleDualParcel(DualParcelTracker &tracker, double currentPrice) {
    if(!tracker.isActive) return;
    if(tracker.fullyProcessed) return;
    
    // Verify position still exists
    if(!PositionSelectByTicket(tracker.positionTicket)) {
        // Position closed externally (TP2 hit, SL hit, manual close)
        HandlePositionClosed(tracker);
        return;
    }
    
    // Update current lot from position
    tracker.currentLot = PositionGetDouble(POSITION_VOLUME);
    
    // Calculate progress percentage (based on Parcel A distance)
    double progress = CalculateProgressPercent(tracker, currentPrice);
    
    //=================================================================
    // PARCEL A PROCESSING (TP1 - short target)
    //=================================================================
    if(!tracker.parcelA.closed && tracker.parcelA.state != PARCEL_CLOSED) {
        ProcessParcelA(tracker, currentPrice, progress);
    }
    
    //=================================================================
    // PARCEL B PROCESSING (TP2 - long target)
    //=================================================================
    if(!tracker.parcelB.closed && tracker.parcelB.state != PARCEL_CLOSED) {
        ProcessParcelB(tracker, currentPrice, progress);
    }
    
    // Check if fully processed
    if(tracker.parcelA.closed && tracker.parcelB.closed) {
        tracker.fullyProcessed = true;
        tracker.isActive = false;
        
        Print("[DualParcel] Position #", tracker.positionTicket, " fully processed");
        Print("             Parcel A Profit: $", DoubleToString(tracker.parcelA.closedProfit, 2));
        Print("             Parcel B Profit: $", DoubleToString(tracker.parcelB.closedProfit, 2));
    }
}

//+------------------------------------------------------------------+
//| Process Parcel A (Short TP)                                      |
//+------------------------------------------------------------------+
void ProcessParcelA(DualParcelTracker &tracker, double currentPrice, double progress) {
    
    //--- CHECK SL → BE TRIGGER (at 50% by default) ---
    if(!tracker.parcelA.slMovedToBE && progress >= tracker.parcelA.slToBE_Progress) {
        // Move SL to Break Even
        if(MoveSLToBreakEven(tracker)) {
            tracker.parcelA.slMovedToBE = true;
            tracker.parcelA.state = PARCEL_SL_AT_BE;
            g_dualParcel_BE_Activations++;
            
            Print("[DualParcel] Parcel A: SL moved to BE at ", DoubleToString(progress, 1), "% progress");
            Print("             Entry: ", DoubleToString(tracker.entryPrice, _Digits));
        }
    }
    
    //--- CHECK TP1 HIT (at 100% = entry grid +1) ---
    bool tp1Hit = false;
    if(tracker.isBuyPosition) {
        tp1Hit = (currentPrice >= tracker.parcelA.targetTP);
    } else {
        tp1Hit = (currentPrice <= tracker.parcelA.targetTP);
    }
    
    if(tp1Hit && !tracker.parcelA.closed) {
        // Close Parcel A (partial close)
        if(ExecuteParcelClose(tracker, true)) {
            tracker.parcelA.state = PARCEL_CLOSED;
            tracker.parcelA.closed = true;
            g_dualParcel_ParcelA_Closed++;
            
            Print("╔═══════════════════════════════════════════════════════════════════╗");
            Print("║  ✅ PARCEL A CLOSED - TP1 HIT                                     ║");
            Print("╠═══════════════════════════════════════════════════════════════════╣");
            Print("║  Position: #", tracker.positionTicket);
            Print("║  Closed: ", DoubleToString(tracker.parcelA.lotSize, 2), " lot at ", DoubleToString(currentPrice, _Digits));
            Print("║  Profit: $", DoubleToString(tracker.parcelA.closedProfit, 2));
            Print("║  Remaining: ", DoubleToString(tracker.parcelB.lotSize, 2), " lot → TP2");
            Print("╚═══════════════════════════════════════════════════════════════════╝");
        }
    }
}

//+------------------------------------------------------------------+
//| Process Parcel B (Long TP)                                       |
//+------------------------------------------------------------------+
void ProcessParcelB(DualParcelTracker &tracker, double currentPrice, double progress) {
    
    //--- CHECK SL → BE TRIGGER (at 100% by default = when Parcel A closes) ---
    if(!tracker.parcelB.slMovedToBE && progress >= tracker.parcelB.slToBE_Progress) {
        // For Parcel B, we only move SL to BE if Parcel A is already closed
        // This ensures we don't lock in BE too early
        if(tracker.parcelA.closed || progress >= tracker.parcelB.slToBE_Progress) {
            if(MoveSLToBreakEven(tracker)) {
                tracker.parcelB.slMovedToBE = true;
                tracker.parcelB.state = PARCEL_SL_AT_BE;
                g_dualParcel_BE_Activations++;
                
                Print("[DualParcel] Parcel B: SL moved to BE at ", DoubleToString(progress, 1), "% progress");
            }
        }
    }
    
    // Note: Parcel B closes when:
    // 1. TP2 is hit (handled by broker)
    // 2. SL is hit (handled by broker)
    // 3. Position closed externally
    // We don't need to manually check TP2 hit here since position TP is already set to TP2
}

//+------------------------------------------------------------------+
//| Move Stop Loss to Break Even                                     |
//+------------------------------------------------------------------+
bool MoveSLToBreakEven(DualParcelTracker &tracker) {
    if(!PositionSelectByTicket(tracker.positionTicket)) return false;
    
    double currentSL = PositionGetDouble(POSITION_SL);
    double currentTP = PositionGetDouble(POSITION_TP);
    double bePrice = tracker.entryPrice;
    
    // Add small buffer (1 pip) to ensure we don't get stopped out at exact entry
    double buffer = PipsToPoints(1.0);
    if(tracker.isBuyPosition) {
        bePrice = bePrice + buffer;  // SL slightly above entry for BUY
    } else {
        bePrice = bePrice - buffer;  // SL slightly below entry for SELL
    }
    
    bePrice = NormalizeDouble(bePrice, _Digits);
    
    // Check if new SL is better than current
    bool shouldModify = false;
    if(tracker.isBuyPosition) {
        shouldModify = (currentSL == 0 || bePrice > currentSL);
    } else {
        shouldModify = (currentSL == 0 || bePrice < currentSL);
    }
    
    if(!shouldModify) return true;  // Already at or better than BE
    
    // Modify position
    if(trade.PositionModify(tracker.positionTicket, bePrice, currentTP)) {
        return true;
    } else {
        Print("[DualParcel] ERROR: Failed to move SL to BE - ", trade.ResultRetcodeDescription());
        return false;
    }
}

//+------------------------------------------------------------------+
//| Execute Parcel Close (Partial Close)                             |
//+------------------------------------------------------------------+
bool ExecuteParcelClose(DualParcelTracker &tracker, bool isParcelA) {
    if(!PositionSelectByTicket(tracker.positionTicket)) return false;
    
    double lotToClose = isParcelA ? tracker.parcelA.lotSize : tracker.parcelB.lotSize;
    
    // Ensure we don't close more than available
    double availableLot = PositionGetDouble(POSITION_VOLUME);
    if(lotToClose > availableLot) lotToClose = availableLot;
    
    // Ensure minimum lot
    if(lotToClose < symbolMinLot) lotToClose = symbolMinLot;
    
    // Execute partial close
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.position = tracker.positionTicket;
    request.symbol = _Symbol;
    request.volume = lotToClose;
    request.deviation = Slippage;
    
    if(tracker.isBuyPosition) {
        request.type = ORDER_TYPE_SELL;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    } else {
        request.type = ORDER_TYPE_BUY;
        request.price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    }
    
    request.comment = isParcelA ? "SUGAMARA_PARCEL_A" : "SUGAMARA_PARCEL_B";
    
    if(OrderSend(request, result)) {
        if(result.retcode == TRADE_RETCODE_DONE) {
            // Calculate profit
            double profit = 0;
            double priceDiff = result.price - tracker.entryPrice;
            if(!tracker.isBuyPosition) priceDiff = -priceDiff;
            
            profit = priceDiff * lotToClose * 
                     SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE) /
                     SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
            
            if(isParcelA) {
                tracker.parcelA.closedProfit = profit;
            } else {
                tracker.parcelB.closedProfit = profit;
            }
            
            g_dualParcel_TotalProfit += profit;
            
            return true;
        }
    }
    
    Print("[DualParcel] ERROR: Partial close failed - ", result.retcode);
    return false;
}

//+------------------------------------------------------------------+
//| Handle Position Closed (externally or by TP2/SL)                 |
//+------------------------------------------------------------------+
void HandlePositionClosed(DualParcelTracker &tracker) {
    // Position was closed - either TP2 hit, SL hit, or manual close
    
    // Get profit from history
    double profit = GetHistoricalOrderProfit(tracker.positionTicket);
    
    // If Parcel A wasn't closed yet, both parcels close together
    if(!tracker.parcelA.closed) {
        tracker.parcelA.closed = true;
        tracker.parcelA.state = PARCEL_CLOSED;
        tracker.parcelA.closedProfit = profit * DualParcel_LotRatio;
        g_dualParcel_ParcelA_Closed++;
    }
    
    // Parcel B definitely closed now
    if(!tracker.parcelB.closed) {
        tracker.parcelB.closed = true;
        tracker.parcelB.state = PARCEL_CLOSED;
        tracker.parcelB.closedProfit = profit * (1 - DualParcel_LotRatio);
        g_dualParcel_ParcelB_Closed++;
    }
    
    tracker.fullyProcessed = true;
    tracker.isActive = false;
    
    Print("[DualParcel] Position #", tracker.positionTicket, " closed externally");
    Print("             Total Profit: $", DoubleToString(profit, 2));
}

//+------------------------------------------------------------------+
//| Clear Dual Parcel Tracker (on position close for recycling)      |
//+------------------------------------------------------------------+
void ClearDualParcelTracker(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    DualParcelTracker* tracker = GetDualParcelTracker(side, zone, level);
    if(tracker != NULL) {
        ResetDualParcelTracker(tracker);
    }
}

//+------------------------------------------------------------------+
//| Check if Dual Parcel Level is Fully Closed (for recycling)       |
//+------------------------------------------------------------------+
bool IsDualParcelFullyClosed(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(!Enable_DualParcelling) return true;  // If disabled, always allow recycling
    
    DualParcelTracker* tracker = GetDualParcelTracker(side, zone, level);
    if(tracker == NULL) return true;
    
    // If tracker not active, level is available
    if(!tracker.isActive) return true;
    
    // If fully processed, level is available
    if(tracker.fullyProcessed) return true;
    
    // Otherwise, still tracking parcels
    return false;
}

//+------------------------------------------------------------------+
//| Get Dual Parcel Statistics String                                |
//+------------------------------------------------------------------+
string GetDualParcelStats() {
    if(!Enable_DualParcelling) return "Disabled";
    
    return "A:" + IntegerToString(g_dualParcel_ParcelA_Closed) +
           " B:" + IntegerToString(g_dualParcel_ParcelB_Closed) +
           " BE:" + IntegerToString(g_dualParcel_BE_Activations) +
           " $" + DoubleToString(g_dualParcel_TotalProfit, 2);
}

//+------------------------------------------------------------------+
//| Log Dual Parcel Status Report                                    |
//+------------------------------------------------------------------+
void LogDualParcelReport() {
    if(!Enable_DualParcelling) {
        Print("Dual Parcelling: DISABLED");
        return;
    }
    
    Print("");
    Print("╔═══════════════════════════════════════════════════════════════════╗");
    Print("║          DUAL PARCEL STATUS REPORT                                ║");
    Print("╠═══════════════════════════════════════════════════════════════════╣");
    Print("║  Parcel A Closed: ", g_dualParcel_ParcelA_Closed);
    Print("║  Parcel B Closed: ", g_dualParcel_ParcelB_Closed);
    Print("║  BE Activations:  ", g_dualParcel_BE_Activations);
    Print("║  Total Profit:    $", DoubleToString(g_dualParcel_TotalProfit, 2));
    Print("╠═══════════════════════════════════════════════════════════════════╣");
    
    // Count active trackers
    int activeTrackers = 0;
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(g_dualParcels_GridA_Upper[i].isActive) activeTrackers++;
        if(g_dualParcels_GridA_Lower[i].isActive) activeTrackers++;
        if(g_dualParcels_GridB_Upper[i].isActive) activeTrackers++;
        if(g_dualParcels_GridB_Lower[i].isActive) activeTrackers++;
    }
    
    Print("║  Active Trackers: ", activeTrackers);
    Print("╚═══════════════════════════════════════════════════════════════════╝");
    Print("");
}

//+------------------------------------------------------------------+
//| Deinitialize Dual Parcel Manager                                 |
//+------------------------------------------------------------------+
void DeinitializeDualParcelManager() {
    if(!Enable_DualParcelling) return;
    
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  DUAL PARCEL MANAGER - SESSION SUMMARY");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  Parcel A Closed: ", g_dualParcel_ParcelA_Closed);
    Print("  Parcel B Closed: ", g_dualParcel_ParcelB_Closed);
    Print("  BE Activations:  ", g_dualParcel_BE_Activations);
    Print("  Total Profit:    $", DoubleToString(g_dualParcel_TotalProfit, 2));
    Print("═══════════════════════════════════════════════════════════════════");
}

