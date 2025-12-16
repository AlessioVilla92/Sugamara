//+------------------------------------------------------------------+
//|                                                 GridBSystem.mqh  |
//|                        Sugamara - Grid B System                  |
//|                                                                  |
//|  Grid B: Short Bias (Mirror of Grid A)                          |
//|  - Upper Zone: Sell Limit orders (price goes up, fill, TP down) |
//|  - Lower Zone: Buy Stop orders (price goes down, fill, TP up)   |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| GRID B INITIALIZATION                                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Grid B Arrays with Calculated Values                  |
//+------------------------------------------------------------------+
bool InitializeGridB() {
    LogMessage(LOG_INFO, "Initializing Grid B (Short Bias)...");

    if(entryPoint <= 0 || currentSpacing_Pips <= 0) {
        LogMessage(LOG_ERROR, "Cannot initialize Grid B: Invalid entry point or spacing");
        return false;
    }

    // Calculate and store values for Upper Zone
    // CASCADE_OVERLAP: SELL LIMIT @ +3 pips (hedge)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        gridB_Upper_EntryPrices[i] = CalculateGridLevelPrice(entryPoint, ZONE_UPPER, i, currentSpacing_Pips, GRID_B);
        gridB_Upper_TP[i] = CalculateCascadeTP(entryPoint, GRID_B, ZONE_UPPER, i, currentSpacing_Pips, GridLevelsPerSide);
        gridB_Upper_SL[i] = CalculateGridSL(entryPoint, GRID_B, ZONE_UPPER, i, currentSpacing_Pips, GridLevelsPerSide);
        gridB_Upper_Lots[i] = CalculateGridLotSize(i);
        gridB_Upper_Status[i] = ORDER_NONE;
        gridB_Upper_Tickets[i] = 0;
        gridB_Upper_Cycles[i] = 0;
        gridB_Upper_LastClose[i] = 0;
    }

    // Calculate and store values for Lower Zone
    // CASCADE_OVERLAP: SELL STOP (standard)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        gridB_Lower_EntryPrices[i] = CalculateGridLevelPrice(entryPoint, ZONE_LOWER, i, currentSpacing_Pips, GRID_B);
        gridB_Lower_TP[i] = CalculateCascadeTP(entryPoint, GRID_B, ZONE_LOWER, i, currentSpacing_Pips, GridLevelsPerSide);
        gridB_Lower_SL[i] = CalculateGridSL(entryPoint, GRID_B, ZONE_LOWER, i, currentSpacing_Pips, GridLevelsPerSide);
        gridB_Lower_Lots[i] = CalculateGridLotSize(i);
        gridB_Lower_Status[i] = ORDER_NONE;
        gridB_Lower_Tickets[i] = 0;
        gridB_Lower_Cycles[i] = 0;
        gridB_Lower_LastClose[i] = 0;
    }

    LogGridBConfiguration();
    return true;
}

//+------------------------------------------------------------------+
//| Log Grid B Configuration (Enhanced v5.0)                         |
//+------------------------------------------------------------------+
void LogGridBConfiguration() {
    Print("═══════════════════════════════════════════════════════════════════");
    if(IsCascadeOverlapMode()) {
        Print("  GRID B CONFIGURATION - SOLO SELL (CASCADE SOVRAPPOSTO)");
    } else {
        Print("  GRID B CONFIGURATION (SHORT BIAS)");
    }
    Print("═══════════════════════════════════════════════════════════════════");
    Print("Entry Point: ", FormatPrice(entryPoint));
    Print("Spacing: ", DoubleToString(currentSpacing_Pips, 1), " pips");
    Print("Levels per Zone: ", GridLevelsPerSide);
    if(IsCascadeOverlapMode()) {
        Print("Hedge Spacing: ", DoubleToString(Hedge_Spacing_Pips, 1), " pips");
        Print("Mode: CASCADE_OVERLAP (Grid B = SOLO ordini SELL)");
    }
    Print("");

    // Upper Zone - Order type depends on mode
    string upperType = IsCascadeOverlapMode() ? "SELL LIMIT [HEDGE +3pip]" : "SELL LIMIT";
    Print("--- UPPER ZONE (", upperType, ") ---");
    for(int i = 0; i < GridLevelsPerSide; i++) {
        Print("  L", i+1, ": Entry=", FormatPrice(gridB_Upper_EntryPrices[i]),
              " TP=", FormatPrice(gridB_Upper_TP[i]),
              " Lot=", DoubleToString(gridB_Upper_Lots[i], 2));
    }

    Print("");

    // Lower Zone - Order type depends on mode
    string lowerType = IsCascadeOverlapMode() ? "SELL STOP [TREND]" : "BUY STOP";
    Print("--- LOWER ZONE (", lowerType, ") ---");
    for(int i = 0; i < GridLevelsPerSide; i++) {
        Print("  L", i+1, ": Entry=", FormatPrice(gridB_Lower_EntryPrices[i]),
              " TP=", FormatPrice(gridB_Lower_TP[i]),
              " Lot=", DoubleToString(gridB_Lower_Lots[i], 2));
    }

    Print("═══════════════════════════════════════════════════════════════════");

    // Log enhanced summary for CASCADE_OVERLAP
    LogGridInitSummary(GRID_B);
}

//+------------------------------------------------------------------+
//| GRID B ORDER PLACEMENT                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Place All Grid B Orders                                          |
//+------------------------------------------------------------------+
bool PlaceAllGridBOrders() {
    LogMessage(LOG_INFO, "Placing Grid B orders...");

    int placedUpper = 0;
    int placedLower = 0;

    // Place Upper Zone Orders (Sell Limit)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(PlaceGridBUpperOrder(i)) {
            placedUpper++;
        }
    }

    // Place Lower Zone Orders (Buy Stop)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(PlaceGridBLowerOrder(i)) {
            placedLower++;
        }
    }

    int totalPlaced = placedUpper + placedLower;
    int totalExpected = GridLevelsPerSide * 2;

    LogMessage(LOG_INFO, "Grid B: Placed " + IntegerToString(totalPlaced) + "/" +
               IntegerToString(totalExpected) + " orders");

    if(totalPlaced < totalExpected) {
        LogMessage(LOG_WARNING, "Grid B: Some orders failed to place");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Place Single Grid B Upper Order (Sell Limit)                     |
//+------------------------------------------------------------------+
bool PlaceGridBUpperOrder(int level) {
    if(!IsValidLevelIndex(level)) return false;
    if(gridB_Upper_Status[level] != ORDER_NONE) return false;

    double entryPrice = gridB_Upper_EntryPrices[level];
    double tp = gridB_Upper_TP[level];
    double sl = gridB_Upper_SL[level];
    double lot = gridB_Upper_Lots[level];

    // Get order type (CASCADE_OVERLAP: SELL_LIMIT @ +3 pips)
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_B, ZONE_UPPER);
    bool isBuyOrder = (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP);

    // Validate price for order type
    if(!IsValidPendingPrice(entryPrice, orderType)) {
        entryPrice = GetSafeOrderPrice(entryPrice, orderType);
    }

    // Validate TP/SL (direction based on order type)
    tp = ValidateTakeProfit(entryPrice, tp, isBuyOrder);
    sl = ValidateStopLoss(entryPrice, sl, isBuyOrder);

    // Place order
    ulong ticket = PlacePendingOrder(orderType, lot, entryPrice, sl, tp,
                                     GetGridLevelID(GRID_B, ZONE_UPPER, level),
                                     GetGridMagic(GRID_B));

    if(ticket > 0) {
        gridB_Upper_Tickets[level] = ticket;
        gridB_Upper_Status[level] = ORDER_PENDING;
        LogGridStatus(GRID_B, ZONE_UPPER, level, "Order placed: " + IntegerToString(ticket));
        return true;
    }

    LogGridStatus(GRID_B, ZONE_UPPER, level, "Failed to place order");
    return false;
}

//+------------------------------------------------------------------+
//| Place Single Grid B Lower Order (Buy Stop)                       |
//+------------------------------------------------------------------+
bool PlaceGridBLowerOrder(int level) {
    if(!IsValidLevelIndex(level)) return false;
    if(gridB_Lower_Status[level] != ORDER_NONE) return false;

    double entryPrice = gridB_Lower_EntryPrices[level];
    double tp = gridB_Lower_TP[level];
    double sl = gridB_Lower_SL[level];
    double lot = gridB_Lower_Lots[level];

    // Get order type (CASCADE_OVERLAP: SELL_STOP)
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_B, ZONE_LOWER);
    bool isBuyOrder = (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP);

    // Validate price for order type
    if(!IsValidPendingPrice(entryPrice, orderType)) {
        entryPrice = GetSafeOrderPrice(entryPrice, orderType);
    }

    // Validate TP/SL (direction based on order type)
    tp = ValidateTakeProfit(entryPrice, tp, isBuyOrder);
    sl = ValidateStopLoss(entryPrice, sl, isBuyOrder);

    // Place order
    ulong ticket = PlacePendingOrder(orderType, lot, entryPrice, sl, tp,
                                     GetGridLevelID(GRID_B, ZONE_LOWER, level),
                                     GetGridMagic(GRID_B));

    if(ticket > 0) {
        gridB_Lower_Tickets[level] = ticket;
        gridB_Lower_Status[level] = ORDER_PENDING;
        LogGridStatus(GRID_B, ZONE_LOWER, level, "Order placed: " + IntegerToString(ticket));
        return true;
    }

    LogGridStatus(GRID_B, ZONE_LOWER, level, "Failed to place order");
    return false;
}

//+------------------------------------------------------------------+
//| GRID B ORDER MONITORING                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Grid B Order Statuses                                     |
//+------------------------------------------------------------------+
void UpdateGridBStatuses() {
    // Update Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        UpdateGridBUpperStatus(i);
    }

    // Update Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        UpdateGridBLowerStatus(i);
    }
}

//+------------------------------------------------------------------+
//| Update Single Grid B Upper Level Status                          |
//+------------------------------------------------------------------+
void UpdateGridBUpperStatus(int level) {
    if(!IsValidLevelIndex(level)) return;

    ulong ticket = gridB_Upper_Tickets[level];
    ENUM_ORDER_STATUS currentStatus = gridB_Upper_Status[level];

    if(ticket == 0 || currentStatus == ORDER_NONE) return;

    // Check if pending order still exists
    if(currentStatus == ORDER_PENDING) {
        if(OrderSelect(ticket)) {
            return;  // Order still pending
        } else {
            if(PositionSelectByTicket(ticket)) {
                gridB_Upper_Status[level] = ORDER_FILLED;
                LogGridStatus(GRID_B, ZONE_UPPER, level, "Order FILLED");
            } else {
                gridB_Upper_Status[level] = ORDER_CANCELLED;
                gridB_Upper_Tickets[level] = 0;
                LogGridStatus(GRID_B, ZONE_UPPER, level, "Order cancelled");
            }
        }
    }

    // Check if filled position still exists
    if(currentStatus == ORDER_FILLED) {
        if(!PositionSelectByTicket(ticket)) {
            double profit = GetHistoricalOrderProfit(ticket);
            if(profit >= 0) {
                gridB_Upper_Status[level] = ORDER_CLOSED_TP;
                LogGridStatus(GRID_B, ZONE_UPPER, level, "Closed in PROFIT: " + FormatMoney(profit));
            } else {
                gridB_Upper_Status[level] = ORDER_CLOSED_SL;
                LogGridStatus(GRID_B, ZONE_UPPER, level, "Closed in LOSS: " + FormatMoney(profit));
            }

            RecordCloseTime(GRID_B, ZONE_UPPER, level);
            IncrementCycleCount(GRID_B, ZONE_UPPER, level);
        }
    }
}

//+------------------------------------------------------------------+
//| Update Single Grid B Lower Level Status                          |
//+------------------------------------------------------------------+
void UpdateGridBLowerStatus(int level) {
    if(!IsValidLevelIndex(level)) return;

    ulong ticket = gridB_Lower_Tickets[level];
    ENUM_ORDER_STATUS currentStatus = gridB_Lower_Status[level];

    if(ticket == 0 || currentStatus == ORDER_NONE) return;

    // Check if pending order still exists
    if(currentStatus == ORDER_PENDING) {
        if(OrderSelect(ticket)) {
            return;
        } else {
            if(PositionSelectByTicket(ticket)) {
                gridB_Lower_Status[level] = ORDER_FILLED;
                LogGridStatus(GRID_B, ZONE_LOWER, level, "Order FILLED");
            } else {
                gridB_Lower_Status[level] = ORDER_CANCELLED;
                gridB_Lower_Tickets[level] = 0;
                LogGridStatus(GRID_B, ZONE_LOWER, level, "Order cancelled");
            }
        }
    }

    // Check if filled position still exists
    if(currentStatus == ORDER_FILLED) {
        if(!PositionSelectByTicket(ticket)) {
            double profit = GetHistoricalOrderProfit(ticket);
            if(profit >= 0) {
                gridB_Lower_Status[level] = ORDER_CLOSED_TP;
                LogGridStatus(GRID_B, ZONE_LOWER, level, "Closed in PROFIT: " + FormatMoney(profit));
            } else {
                gridB_Lower_Status[level] = ORDER_CLOSED_SL;
                LogGridStatus(GRID_B, ZONE_LOWER, level, "Closed in LOSS: " + FormatMoney(profit));
            }

            RecordCloseTime(GRID_B, ZONE_LOWER, level);
            IncrementCycleCount(GRID_B, ZONE_LOWER, level);
        }
    }
}

//+------------------------------------------------------------------+
//| GRID B CYCLIC REOPENING                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check and Process Grid B Cyclic Reopening                        |
//+------------------------------------------------------------------+
void ProcessGridBCyclicReopen() {
    if(!EnableCyclicReopen) return;
    if(IsMarketTooVolatile()) return;

    // Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(ShouldReopenGridBUpper(i)) {
            ReopenGridBUpper(i);
        }
    }

    // Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(ShouldReopenGridBLower(i)) {
            ReopenGridBLower(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Check if Grid B Upper Level Should Reopen                        |
//+------------------------------------------------------------------+
bool ShouldReopenGridBUpper(int level) {
    ENUM_ORDER_STATUS status = gridB_Upper_Status[level];

    if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
        return false;
    }

    if(!CanLevelReopen(GRID_B, ZONE_UPPER, level)) {
        return false;
    }

    double levelPrice = gridB_Upper_EntryPrices[level];
    if(!IsPriceAtReopenLevel(levelPrice)) {
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check if Grid B Lower Level Should Reopen                        |
//+------------------------------------------------------------------+
bool ShouldReopenGridBLower(int level) {
    ENUM_ORDER_STATUS status = gridB_Lower_Status[level];

    if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
        return false;
    }

    if(!CanLevelReopen(GRID_B, ZONE_LOWER, level)) {
        return false;
    }

    double levelPrice = gridB_Lower_EntryPrices[level];
    if(!IsPriceAtReopenLevel(levelPrice)) {
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Reopen Grid B Upper Level                                        |
//+------------------------------------------------------------------+
void ReopenGridBUpper(int level) {
    gridB_Upper_Status[level] = ORDER_NONE;
    gridB_Upper_Tickets[level] = 0;

    if(PlaceGridBUpperOrder(level)) {
        LogGridStatus(GRID_B, ZONE_UPPER, level, "REOPENED (Cycle " +
                      IntegerToString(gridB_Upper_Cycles[level]) + ")");
    }
}

//+------------------------------------------------------------------+
//| Reopen Grid B Lower Level                                        |
//+------------------------------------------------------------------+
void ReopenGridBLower(int level) {
    gridB_Lower_Status[level] = ORDER_NONE;
    gridB_Lower_Tickets[level] = 0;

    if(PlaceGridBLowerOrder(level)) {
        LogGridStatus(GRID_B, ZONE_LOWER, level, "REOPENED (Cycle " +
                      IntegerToString(gridB_Lower_Cycles[level]) + ")");
    }
}

//+------------------------------------------------------------------+
//| GRID B CLOSURE                                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Close All Grid B Orders and Positions                            |
//+------------------------------------------------------------------+
void CloseAllGridB() {
    LogMessage(LOG_INFO, "Closing all Grid B orders and positions...");

    // Close Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        CloseGridBLevel(ZONE_UPPER, i);
    }

    // Close Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        CloseGridBLevel(ZONE_LOWER, i);
    }
}

//+------------------------------------------------------------------+
//| Close Single Grid B Level                                        |
//+------------------------------------------------------------------+
void CloseGridBLevel(ENUM_GRID_ZONE zone, int level) {
    ulong ticket;
    ENUM_ORDER_STATUS status;

    if(zone == ZONE_UPPER) {
        ticket = gridB_Upper_Tickets[level];
        status = gridB_Upper_Status[level];
    } else {
        ticket = gridB_Lower_Tickets[level];
        status = gridB_Lower_Status[level];
    }

    if(ticket == 0) return;

    bool closed = false;

    if(status == ORDER_PENDING) {
        closed = DeletePendingOrder(ticket);
    }

    if(status == ORDER_FILLED) {
        closed = ClosePosition(ticket);
    }

    if(closed) {
        if(zone == ZONE_UPPER) {
            gridB_Upper_Status[level] = ORDER_CANCELLED;
            gridB_Upper_Tickets[level] = 0;
        } else {
            gridB_Lower_Status[level] = ORDER_CANCELLED;
            gridB_Lower_Tickets[level] = 0;
        }
        LogGridStatus(GRID_B, zone, level, "Level closed");
    }
}

//+------------------------------------------------------------------+
//| GRID B STATISTICS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Grid B Total Open Profit                                     |
//+------------------------------------------------------------------+
double GetGridBOpenProfit() {
    double profit = 0;

    // Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Status[i] == ORDER_FILLED) {
            profit += GetPositionProfit(gridB_Upper_Tickets[i]);
        }
    }

    // Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Lower_Status[i] == ORDER_FILLED) {
            profit += GetPositionProfit(gridB_Lower_Tickets[i]);
        }
    }

    return profit;
}

//+------------------------------------------------------------------+
//| Get Grid B Active Position Count                                 |
//+------------------------------------------------------------------+
int GetGridBActivePositions() {
    int count = 0;

    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Status[i] == ORDER_FILLED) count++;
        if(gridB_Lower_Status[i] == ORDER_FILLED) count++;
    }

    return count;
}

//+------------------------------------------------------------------+
//| Get Grid B Pending Order Count                                   |
//+------------------------------------------------------------------+
int GetGridBPendingOrders() {
    int count = 0;

    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Status[i] == ORDER_PENDING) count++;
        if(gridB_Lower_Status[i] == ORDER_PENDING) count++;
    }

    return count;
}

//+------------------------------------------------------------------+
//| Get Grid B Total Long Lots                                       |
//+------------------------------------------------------------------+
double GetGridBLongLots() {
    double lots = 0;

    // Grid B Lower = Buy Stop -> Long
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Lower_Status[i] == ORDER_FILLED) {
            lots += gridB_Lower_Lots[i];
        }
    }

    return lots;
}

//+------------------------------------------------------------------+
//| Get Grid B Total Short Lots                                      |
//+------------------------------------------------------------------+
double GetGridBShortLots() {
    double lots = 0;

    // Grid B Upper = Sell Limit -> Short
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Status[i] == ORDER_FILLED) {
            lots += gridB_Upper_Lots[i];
        }
    }

    return lots;
}

//+------------------------------------------------------------------+
//| Get Grid B Summary for Dashboard                                 |
//+------------------------------------------------------------------+
string GetGridBSummary() {
    int positions = GetGridBActivePositions();
    int pending = GetGridBPendingOrders();
    double profit = GetGridBOpenProfit();

    return "Pos:" + IntegerToString(positions) +
           " Pend:" + IntegerToString(pending) +
           " P/L:" + FormatMoney(profit);
}

//+------------------------------------------------------------------+
//| GRID SYNCHRONIZATION (A + B)                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Sync Grid B with Grid A (Mirror Configuration)                   |
//| Ensures both grids have same entry levels but opposite bias      |
//+------------------------------------------------------------------+
void SyncGridBWithGridA() {
    if(!SyncGridAB) return;

    // Entry prices are the same for both grids
    // Only order types differ
    for(int i = 0; i < GridLevelsPerSide; i++) {
        // Upper zone: Same price levels
        gridB_Upper_EntryPrices[i] = gridA_Upper_EntryPrices[i];
        gridB_Upper_Lots[i] = gridA_Upper_Lots[i];

        // Lower zone: Same price levels
        gridB_Lower_EntryPrices[i] = gridA_Lower_EntryPrices[i];
        gridB_Lower_Lots[i] = gridA_Lower_Lots[i];
    }

    LogMessage(LOG_INFO, "Grid B synchronized with Grid A");
}

//+------------------------------------------------------------------+
//| Check if Grids are Synchronized                                  |
//+------------------------------------------------------------------+
bool AreGridsSynchronized() {
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(MathAbs(gridA_Upper_EntryPrices[i] - gridB_Upper_EntryPrices[i]) > symbolPoint) {
            return false;
        }
        if(MathAbs(gridA_Lower_EntryPrices[i] - gridB_Lower_EntryPrices[i]) > symbolPoint) {
            return false;
        }
    }
    return true;
}

