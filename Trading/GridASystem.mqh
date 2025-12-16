//+------------------------------------------------------------------+
//|                                                 GridASystem.mqh  |
//|                        Sugamara - Grid A System                  |
//|                                                                  |
//|  Grid A: Long Bias                                               |
//|  - Upper Zone: Buy Limit orders (price goes up, fill, TP down)  |
//|  - Lower Zone: Sell Stop orders (price goes down, fill, TP up)  |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| GRID A INITIALIZATION                                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Grid A Arrays with Calculated Values                  |
//| v5.0 FIX: Aggiunto sanity check per prezzi unici                 |
//+------------------------------------------------------------------+
bool InitializeGridA() {
    LogMessage(LOG_INFO, "Initializing Grid A (Long Bias)...");

    if(entryPoint <= 0 || currentSpacing_Pips <= 0) {
        LogMessage(LOG_ERROR, "Cannot initialize Grid A: Invalid entry point or spacing");
        PrintFormat("[GridA] DEBUG: entryPoint=%.5f, currentSpacing_Pips=%.1f", entryPoint, currentSpacing_Pips);
        return false;
    }

    // v5.0 DEBUG: Log input parameters
    PrintFormat("[GridA] Initializing with: entry=%.5f, spacing=%.1f pips, levels=%d",
                entryPoint, currentSpacing_Pips, GridLevelsPerSide);
    PrintFormat("[GridA] CASCADE_OVERLAP mode: %s", IsCascadeOverlapMode() ? "YES" : "NO");

    // Calculate and store values for Upper Zone
    // CASCADE_OVERLAP: BUY STOP (standard)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        gridA_Upper_EntryPrices[i] = CalculateGridLevelPrice(entryPoint, ZONE_UPPER, i, currentSpacing_Pips, GRID_A);
        gridA_Upper_TP[i] = CalculateCascadeTP(entryPoint, GRID_A, ZONE_UPPER, i, currentSpacing_Pips, GridLevelsPerSide);
        gridA_Upper_SL[i] = CalculateGridSL(entryPoint, GRID_A, ZONE_UPPER, i, currentSpacing_Pips, GridLevelsPerSide);
        gridA_Upper_Lots[i] = CalculateGridLotSize(i);
        gridA_Upper_Status[i] = ORDER_NONE;
        gridA_Upper_Tickets[i] = 0;
        gridA_Upper_Cycles[i] = 0;
        gridA_Upper_LastClose[i] = 0;
    }

    // Calculate and store values for Lower Zone
    // CASCADE_OVERLAP: BUY LIMIT @ -3 pips (hedge)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        gridA_Lower_EntryPrices[i] = CalculateGridLevelPrice(entryPoint, ZONE_LOWER, i, currentSpacing_Pips, GRID_A);
        gridA_Lower_TP[i] = CalculateCascadeTP(entryPoint, GRID_A, ZONE_LOWER, i, currentSpacing_Pips, GridLevelsPerSide);
        gridA_Lower_SL[i] = CalculateGridSL(entryPoint, GRID_A, ZONE_LOWER, i, currentSpacing_Pips, GridLevelsPerSide);
        gridA_Lower_Lots[i] = CalculateGridLotSize(i);
        gridA_Lower_Status[i] = ORDER_NONE;
        gridA_Lower_Tickets[i] = 0;
        gridA_Lower_Cycles[i] = 0;
        gridA_Lower_LastClose[i] = 0;
    }

    // ═══════════════════════════════════════════════════════════════════
    // v5.0 FIX: SANITY CHECK - Verify prices are unique
    // If all prices are the same, there's a bug in spacing calculation
    // ═══════════════════════════════════════════════════════════════════
    bool pricesValid = true;

    // Check Upper Zone prices are unique and properly spaced
    for(int i = 1; i < GridLevelsPerSide; i++) {
        if(MathAbs(gridA_Upper_EntryPrices[i] - gridA_Upper_EntryPrices[i-1]) < symbolPoint) {
            PrintFormat("[GridA] ⚠️ BUG DETECTED: Upper L%d (%.5f) = Upper L%d (%.5f) - SAME PRICE!",
                        i+1, gridA_Upper_EntryPrices[i], i, gridA_Upper_EntryPrices[i-1]);
            pricesValid = false;
        }
    }

    // Check Lower Zone prices are unique and properly spaced
    for(int i = 1; i < GridLevelsPerSide; i++) {
        if(MathAbs(gridA_Lower_EntryPrices[i] - gridA_Lower_EntryPrices[i-1]) < symbolPoint) {
            PrintFormat("[GridA] ⚠️ BUG DETECTED: Lower L%d (%.5f) = Lower L%d (%.5f) - SAME PRICE!",
                        i+1, gridA_Lower_EntryPrices[i], i, gridA_Lower_EntryPrices[i-1]);
            pricesValid = false;
        }
    }

    if(!pricesValid) {
        PrintFormat("[GridA] ❌ CRITICAL: Price spacing validation FAILED!");
        PrintFormat("[GridA] DEBUG: PipsToPoints(%.1f) = %.5f", currentSpacing_Pips, PipsToPoints(currentSpacing_Pips));
        PrintFormat("[GridA] DEBUG: symbolPoint = %.5f, symbolDigits = %d", symbolPoint, symbolDigits);
        // Don't return false - still allow initialization but log the issue
    }

    LogGridAConfiguration();
    return true;
}

//+------------------------------------------------------------------+
//| Log Grid A Configuration (Enhanced v5.0)                         |
//+------------------------------------------------------------------+
void LogGridAConfiguration() {
    Print("═══════════════════════════════════════════════════════════════════");
    if(IsCascadeOverlapMode()) {
        Print("  GRID A CONFIGURATION - SOLO BUY (CASCADE SOVRAPPOSTO)");
    } else {
        Print("  GRID A CONFIGURATION (LONG BIAS)");
    }
    Print("═══════════════════════════════════════════════════════════════════");
    Print("Entry Point: ", FormatPrice(entryPoint));
    Print("Spacing: ", DoubleToString(currentSpacing_Pips, 1), " pips");
    Print("Levels per Zone: ", GridLevelsPerSide);
    if(IsCascadeOverlapMode()) {
        Print("Hedge Spacing: ", DoubleToString(Hedge_Spacing_Pips, 1), " pips");
        Print("Mode: CASCADE_OVERLAP (Grid A = SOLO ordini BUY)");
    }
    Print("");

    // Upper Zone - Order type depends on mode
    string upperType = IsCascadeOverlapMode() ? "BUY STOP [TREND]" : "BUY LIMIT";
    Print("--- UPPER ZONE (", upperType, ") ---");
    for(int i = 0; i < GridLevelsPerSide; i++) {
        Print("  L", i+1, ": Entry=", FormatPrice(gridA_Upper_EntryPrices[i]),
              " TP=", FormatPrice(gridA_Upper_TP[i]),
              " Lot=", DoubleToString(gridA_Upper_Lots[i], 2));
    }

    Print("");

    // Lower Zone - Order type depends on mode
    string lowerType = IsCascadeOverlapMode() ? "BUY LIMIT [HEDGE -3pip]" : "SELL STOP";
    Print("--- LOWER ZONE (", lowerType, ") ---");
    for(int i = 0; i < GridLevelsPerSide; i++) {
        Print("  L", i+1, ": Entry=", FormatPrice(gridA_Lower_EntryPrices[i]),
              " TP=", FormatPrice(gridA_Lower_TP[i]),
              " Lot=", DoubleToString(gridA_Lower_Lots[i], 2));
    }

    Print("═══════════════════════════════════════════════════════════════════");

    // Log enhanced summary for CASCADE_OVERLAP
    LogGridInitSummary(GRID_A);
}

//+------------------------------------------------------------------+
//| GRID A ORDER PLACEMENT                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Place All Grid A Orders                                          |
//+------------------------------------------------------------------+
bool PlaceAllGridAOrders() {
    LogMessage(LOG_INFO, "Placing Grid A orders...");

    int placedUpper = 0;
    int placedLower = 0;

    // Place Upper Zone Orders (Buy Limit)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(PlaceGridAUpperOrder(i)) {
            placedUpper++;
        }
    }

    // Place Lower Zone Orders (Sell Stop)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(PlaceGridALowerOrder(i)) {
            placedLower++;
        }
    }

    int totalPlaced = placedUpper + placedLower;
    int totalExpected = GridLevelsPerSide * 2;

    LogMessage(LOG_INFO, "Grid A: Placed " + IntegerToString(totalPlaced) + "/" +
               IntegerToString(totalExpected) + " orders");

    if(totalPlaced < totalExpected) {
        LogMessage(LOG_WARNING, "Grid A: Some orders failed to place");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Place Single Grid A Upper Order (Buy Limit)                      |
//+------------------------------------------------------------------+
bool PlaceGridAUpperOrder(int level) {
    if(!IsValidLevelIndex(level)) return false;
    if(gridA_Upper_Status[level] != ORDER_NONE) return false;  // Already has order

    double entryPrice = gridA_Upper_EntryPrices[level];
    double tp = gridA_Upper_TP[level];
    double sl = gridA_Upper_SL[level];
    double lot = gridA_Upper_Lots[level];

    // Get order type (CASCADE_OVERLAP: BUY_STOP, otherwise: BUY_LIMIT)
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_A, ZONE_UPPER);

    // Validate price for order type
    if(!IsValidPendingPrice(entryPrice, orderType)) {
        entryPrice = GetSafeOrderPrice(entryPrice, orderType);
    }

    // Validate TP/SL
    tp = ValidateTakeProfit(entryPrice, tp, true);
    sl = ValidateStopLoss(entryPrice, sl, true);

    // Place order
    ulong ticket = PlacePendingOrder(orderType, lot, entryPrice, sl, tp,
                                     GetGridLevelID(GRID_A, ZONE_UPPER, level),
                                     GetGridMagic(GRID_A));

    if(ticket > 0) {
        gridA_Upper_Tickets[level] = ticket;
        gridA_Upper_Status[level] = ORDER_PENDING;
        LogGridStatus(GRID_A, ZONE_UPPER, level, "Order placed: " + IntegerToString(ticket));
        return true;
    }

    LogGridStatus(GRID_A, ZONE_UPPER, level, "Failed to place order");
    return false;
}

//+------------------------------------------------------------------+
//| Place Single Grid A Lower Order (Sell Stop)                      |
//+------------------------------------------------------------------+
bool PlaceGridALowerOrder(int level) {
    if(!IsValidLevelIndex(level)) return false;
    if(gridA_Lower_Status[level] != ORDER_NONE) return false;

    double entryPrice = gridA_Lower_EntryPrices[level];
    double tp = gridA_Lower_TP[level];
    double sl = gridA_Lower_SL[level];
    double lot = gridA_Lower_Lots[level];

    // Get order type (CASCADE_OVERLAP: BUY_LIMIT, otherwise: SELL_STOP)
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_A, ZONE_LOWER);
    bool isBuyOrder = (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP);

    // Validate price for order type
    if(!IsValidPendingPrice(entryPrice, orderType)) {
        entryPrice = GetSafeOrderPrice(entryPrice, orderType);
    }

    // Validate TP/SL (isBuyOrder determines direction)
    tp = ValidateTakeProfit(entryPrice, tp, isBuyOrder);
    sl = ValidateStopLoss(entryPrice, sl, isBuyOrder);

    // Place order
    ulong ticket = PlacePendingOrder(orderType, lot, entryPrice, sl, tp,
                                     GetGridLevelID(GRID_A, ZONE_LOWER, level),
                                     GetGridMagic(GRID_A));

    if(ticket > 0) {
        gridA_Lower_Tickets[level] = ticket;
        gridA_Lower_Status[level] = ORDER_PENDING;
        LogGridStatus(GRID_A, ZONE_LOWER, level, "Order placed: " + IntegerToString(ticket));
        return true;
    }

    LogGridStatus(GRID_A, ZONE_LOWER, level, "Failed to place order");
    return false;
}

//+------------------------------------------------------------------+
//| GRID A ORDER MONITORING                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Grid A Order Statuses                                     |
//+------------------------------------------------------------------+
void UpdateGridAStatuses() {
    // Update Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        UpdateGridAUpperStatus(i);
    }

    // Update Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        UpdateGridALowerStatus(i);
    }
}

//+------------------------------------------------------------------+
//| Update Single Grid A Upper Level Status                          |
//+------------------------------------------------------------------+
void UpdateGridAUpperStatus(int level) {
    if(!IsValidLevelIndex(level)) return;

    ulong ticket = gridA_Upper_Tickets[level];
    ENUM_ORDER_STATUS currentStatus = gridA_Upper_Status[level];

    if(ticket == 0 || currentStatus == ORDER_NONE) return;

    // Check if pending order still exists
    if(currentStatus == ORDER_PENDING) {
        if(OrderSelect(ticket)) {
            // Order still pending
            return;
        } else {
            // Order no longer pending - check if it became a position
            if(PositionSelectByTicket(ticket)) {
                gridA_Upper_Status[level] = ORDER_FILLED;
                LogGridStatus(GRID_A, ZONE_UPPER, level, "Order FILLED");
            } else {
                // Order was deleted/cancelled
                gridA_Upper_Status[level] = ORDER_CANCELLED;
                gridA_Upper_Tickets[level] = 0;
                LogGridStatus(GRID_A, ZONE_UPPER, level, "Order cancelled");
            }
        }
    }

    // Check if filled position still exists
    if(currentStatus == ORDER_FILLED) {
        if(!PositionSelectByTicket(ticket)) {
            // Position closed - check how
            double profit = GetHistoricalOrderProfit(ticket);
            if(profit >= 0) {
                gridA_Upper_Status[level] = ORDER_CLOSED_TP;
                LogGridStatus(GRID_A, ZONE_UPPER, level, "Closed in PROFIT: " + FormatMoney(profit));
            } else {
                gridA_Upper_Status[level] = ORDER_CLOSED_SL;
                LogGridStatus(GRID_A, ZONE_UPPER, level, "Closed in LOSS: " + FormatMoney(profit));
            }

            // Record close time for cyclic reopening
            RecordCloseTime(GRID_A, ZONE_UPPER, level);
            IncrementCycleCount(GRID_A, ZONE_UPPER, level);
        }
    }
}

//+------------------------------------------------------------------+
//| Update Single Grid A Lower Level Status                          |
//+------------------------------------------------------------------+
void UpdateGridALowerStatus(int level) {
    if(!IsValidLevelIndex(level)) return;

    ulong ticket = gridA_Lower_Tickets[level];
    ENUM_ORDER_STATUS currentStatus = gridA_Lower_Status[level];

    if(ticket == 0 || currentStatus == ORDER_NONE) return;

    // Check if pending order still exists
    if(currentStatus == ORDER_PENDING) {
        if(OrderSelect(ticket)) {
            return;  // Order still pending
        } else {
            if(PositionSelectByTicket(ticket)) {
                gridA_Lower_Status[level] = ORDER_FILLED;
                LogGridStatus(GRID_A, ZONE_LOWER, level, "Order FILLED");
            } else {
                gridA_Lower_Status[level] = ORDER_CANCELLED;
                gridA_Lower_Tickets[level] = 0;
                LogGridStatus(GRID_A, ZONE_LOWER, level, "Order cancelled");
            }
        }
    }

    // Check if filled position still exists
    if(currentStatus == ORDER_FILLED) {
        if(!PositionSelectByTicket(ticket)) {
            double profit = GetHistoricalOrderProfit(ticket);
            if(profit >= 0) {
                gridA_Lower_Status[level] = ORDER_CLOSED_TP;
                LogGridStatus(GRID_A, ZONE_LOWER, level, "Closed in PROFIT: " + FormatMoney(profit));
            } else {
                gridA_Lower_Status[level] = ORDER_CLOSED_SL;
                LogGridStatus(GRID_A, ZONE_LOWER, level, "Closed in LOSS: " + FormatMoney(profit));
            }

            RecordCloseTime(GRID_A, ZONE_LOWER, level);
            IncrementCycleCount(GRID_A, ZONE_LOWER, level);
        }
    }
}

//+------------------------------------------------------------------+
//| GRID A CYCLIC REOPENING                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check and Process Grid A Cyclic Reopening                        |
//+------------------------------------------------------------------+
void ProcessGridACyclicReopen() {
    if(!EnableCyclicReopen) return;
    if(IsMarketTooVolatile()) return;

    // Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(ShouldReopenGridAUpper(i)) {
            ReopenGridAUpper(i);
        }
    }

    // Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(ShouldReopenGridALower(i)) {
            ReopenGridALower(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Check if Grid A Upper Level Should Reopen                        |
//+------------------------------------------------------------------+
bool ShouldReopenGridAUpper(int level) {
    ENUM_ORDER_STATUS status = gridA_Upper_Status[level];

    // Can only reopen if closed
    if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
        return false;
    }

    // Check if level can reopen (cooldown, max cycles)
    if(!CanLevelReopen(GRID_A, ZONE_UPPER, level)) {
        return false;
    }

    // Check price level trigger
    double levelPrice = gridA_Upper_EntryPrices[level];
    if(!IsPriceAtReopenLevel(levelPrice)) {
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check if Grid A Lower Level Should Reopen                        |
//+------------------------------------------------------------------+
bool ShouldReopenGridALower(int level) {
    ENUM_ORDER_STATUS status = gridA_Lower_Status[level];

    if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
        return false;
    }

    if(!CanLevelReopen(GRID_A, ZONE_LOWER, level)) {
        return false;
    }

    double levelPrice = gridA_Lower_EntryPrices[level];
    if(!IsPriceAtReopenLevel(levelPrice)) {
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Reopen Grid A Upper Level                                        |
//+------------------------------------------------------------------+
void ReopenGridAUpper(int level) {
    // Reset status
    gridA_Upper_Status[level] = ORDER_NONE;
    gridA_Upper_Tickets[level] = 0;

    // Place new order
    if(PlaceGridAUpperOrder(level)) {
        LogGridStatus(GRID_A, ZONE_UPPER, level, "REOPENED (Cycle " +
                      IntegerToString(gridA_Upper_Cycles[level]) + ")");
    }
}

//+------------------------------------------------------------------+
//| Reopen Grid A Lower Level                                        |
//+------------------------------------------------------------------+
void ReopenGridALower(int level) {
    gridA_Lower_Status[level] = ORDER_NONE;
    gridA_Lower_Tickets[level] = 0;

    if(PlaceGridALowerOrder(level)) {
        LogGridStatus(GRID_A, ZONE_LOWER, level, "REOPENED (Cycle " +
                      IntegerToString(gridA_Lower_Cycles[level]) + ")");
    }
}

//+------------------------------------------------------------------+
//| GRID A CLOSURE                                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Close All Grid A Orders and Positions                            |
//+------------------------------------------------------------------+
void CloseAllGridA() {
    LogMessage(LOG_INFO, "Closing all Grid A orders and positions...");

    // Close Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        CloseGridALevel(ZONE_UPPER, i);
    }

    // Close Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        CloseGridALevel(ZONE_LOWER, i);
    }
}

//+------------------------------------------------------------------+
//| Close Single Grid A Level                                        |
//+------------------------------------------------------------------+
void CloseGridALevel(ENUM_GRID_ZONE zone, int level) {
    ulong ticket;
    ENUM_ORDER_STATUS status;

    if(zone == ZONE_UPPER) {
        ticket = gridA_Upper_Tickets[level];
        status = gridA_Upper_Status[level];
    } else {
        ticket = gridA_Lower_Tickets[level];
        status = gridA_Lower_Status[level];
    }

    if(ticket == 0) return;

    bool closed = false;

    // If pending, delete order
    if(status == ORDER_PENDING) {
        closed = DeletePendingOrder(ticket);
    }

    // If filled, close position
    if(status == ORDER_FILLED) {
        closed = ClosePosition(ticket);
    }

    if(closed) {
        if(zone == ZONE_UPPER) {
            gridA_Upper_Status[level] = ORDER_CANCELLED;
            gridA_Upper_Tickets[level] = 0;
        } else {
            gridA_Lower_Status[level] = ORDER_CANCELLED;
            gridA_Lower_Tickets[level] = 0;
        }
        LogGridStatus(GRID_A, zone, level, "Level closed");
    }
}

//+------------------------------------------------------------------+
//| GRID A STATISTICS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Grid A Total Open Profit                                     |
//+------------------------------------------------------------------+
double GetGridAOpenProfit() {
    double profit = 0;

    // Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Status[i] == ORDER_FILLED) {
            profit += GetPositionProfit(gridA_Upper_Tickets[i]);
        }
    }

    // Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Lower_Status[i] == ORDER_FILLED) {
            profit += GetPositionProfit(gridA_Lower_Tickets[i]);
        }
    }

    return profit;
}

//+------------------------------------------------------------------+
//| Get Grid A Active Position Count                                 |
//+------------------------------------------------------------------+
int GetGridAActivePositions() {
    int count = 0;

    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Status[i] == ORDER_FILLED) count++;
        if(gridA_Lower_Status[i] == ORDER_FILLED) count++;
    }

    return count;
}

//+------------------------------------------------------------------+
//| Get Grid A Pending Order Count                                   |
//+------------------------------------------------------------------+
int GetGridAPendingOrders() {
    int count = 0;

    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Status[i] == ORDER_PENDING) count++;
        if(gridA_Lower_Status[i] == ORDER_PENDING) count++;
    }

    return count;
}

//+------------------------------------------------------------------+
//| Get Grid A Total Long Lots                                       |
//+------------------------------------------------------------------+
double GetGridALongLots() {
    double lots = 0;

    // Grid A Upper = Buy Limit -> Long
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Status[i] == ORDER_FILLED) {
            lots += gridA_Upper_Lots[i];
        }
    }

    return lots;
}

//+------------------------------------------------------------------+
//| Get Grid A Total Short Lots                                      |
//+------------------------------------------------------------------+
double GetGridAShortLots() {
    double lots = 0;

    // Grid A Lower = Sell Stop -> Short
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Lower_Status[i] == ORDER_FILLED) {
            lots += gridA_Lower_Lots[i];
        }
    }

    return lots;
}

//+------------------------------------------------------------------+
//| Get Grid A Summary for Dashboard                                 |
//+------------------------------------------------------------------+
string GetGridASummary() {
    int positions = GetGridAActivePositions();
    int pending = GetGridAPendingOrders();
    double profit = GetGridAOpenProfit();

    return "Pos:" + IntegerToString(positions) +
           " Pend:" + IntegerToString(pending) +
           " P/L:" + FormatMoney(profit);
}

