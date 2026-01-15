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
//+------------------------------------------------------------------+
bool InitializeGridA() {
    if(entryPoint <= 0 || currentSpacing_Pips <= 0) {
        Log_InitFailed("GridA", "Invalid entry point or spacing");
        return false;
    }

    // Calculate and store values for Upper Zone
    // v9.0: BUY STOP (Grid A = sempre BUY)
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
    // v9.0: BUY LIMIT (Grid A = sempre BUY)
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

    // Sanity check - verify prices are unique
    bool pricesValid = true;
    for(int i = 1; i < GridLevelsPerSide; i++) {
        if(MathAbs(gridA_Upper_EntryPrices[i] - gridA_Upper_EntryPrices[i - 1]) < symbolPoint) {
            Log_SystemError("GridA", 0, StringFormat("Upper L % d = L % d(same price)", i + 1, i));
            pricesValid = false;
        }
        if(MathAbs(gridA_Lower_EntryPrices[i] - gridA_Lower_EntryPrices[i - 1]) < symbolPoint) {
            Log_SystemError("GridA", 0, StringFormat("Lower L % d = L % d(same price)", i + 1, i));
            pricesValid = false;
        }
    }

    if(!pricesValid) {
        Log_SystemError("GridA", 0, "Price spacing validation FAILED");
    }

    LogGridAConfiguration();
    return true;
}

//+------------------------------------------------------------------+
//| Log Grid A Configuration                                          |
//+------------------------------------------------------------------+
void LogGridAConfiguration() {
    Log_GridStart("A", entryPoint, currentSpacing_Pips, GridLevelsPerSide);
    Log_InitConfig("GridA.Mode", "BUY_ONLY");
    Log_InitConfig("GridA.Upper", "BUY_STOP");
    Log_InitConfig("GridA.Lower", "BUY_LIMIT");
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

    LogMessage(LOG_INFO, "Grid A: Placed " + IntegerToString(totalPlaced) + " / " +
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
    if(!IsValidTrailingIndex(level, true)) return false; // v9.0: Supporta trailing grids
    if(gridA_Upper_Status[level] != ORDER_NONE) return false; // Already has order

    double entryPrice = gridA_Upper_EntryPrices[level];
    double tp = gridA_Upper_TP[level];
    double sl = 0; // v5.6: No SL - Auto - hedging compensa le perdite
    double lot = gridA_Upper_Lots[level];

    // v9.0: Grid A Upper = sempre BUY STOP
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_A, ZONE_UPPER);

    // v9.0: Rimosso GetSafeOrderPrice - entry SEMPRE originale
    // Se prezzo invalido, OrderManager ritorna 0 e cyclic reopen riprova

    // Validate TP (v5.6: SL rimosso)
    tp = ValidateTakeProfit(entryPrice, tp, true);

    // Place order
    ulong ticket = PlacePendingOrder(orderType, lot, entryPrice, sl, tp,
    GetGridLevelID(GRID_A, ZONE_UPPER, level),
    GetGridMagic(GRID_A));

    if(ticket > 0) {
        gridA_Upper_Tickets[level] = ticket;
        gridA_Upper_Status[level] = ORDER_PENDING;
        g_gridA_PendingCount++; // v5.9.3: Grid Counter
        LogGridStatus(GRID_A, ZONE_UPPER, level, "Order placed: " + IntegerToString(ticket));
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Place Single Grid A Lower Order (Sell Stop)                      |
//+------------------------------------------------------------------+
bool PlaceGridALowerOrder(int level) {
    if(!IsValidTrailingIndex(level, false)) return false; // v9.0: Supporta trailing grids
    if(gridA_Lower_Status[level] != ORDER_NONE) return false;

    double entryPrice = gridA_Lower_EntryPrices[level];
    double tp = gridA_Lower_TP[level];
    double sl = 0; // v5.6: No SL - Auto - hedging compensa le perdite
    double lot = gridA_Lower_Lots[level];

    // v9.0: Grid A Lower = sempre BUY LIMIT
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_A, ZONE_LOWER);
    bool isBuyOrder = true; // v9.0: Grid A = sempre BUY

    // v9.0: Rimosso GetSafeOrderPrice - entry SEMPRE originale
    // Se prezzo invalido, OrderManager ritorna 0 e cyclic reopen riprova

    // Validate TP (v5.6: SL rimosso)
    tp = ValidateTakeProfit(entryPrice, tp, isBuyOrder);

    // Place order
    ulong ticket = PlacePendingOrder(orderType, lot, entryPrice, sl, tp,
    GetGridLevelID(GRID_A, ZONE_LOWER, level),
    GetGridMagic(GRID_A));

    if(ticket > 0) {
        gridA_Lower_Tickets[level] = ticket;
        gridA_Lower_Status[level] = ORDER_PENDING;
        g_gridA_PendingCount++; // v5.9.3: Grid Counter
        LogGridStatus(GRID_A, ZONE_LOWER, level, "Order placed: " + IntegerToString(ticket));
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| GRID A ORDER MONITORING                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Grid A Order Statuses                                     |
//+------------------------------------------------------------------+
void UpdateGridAStatuses() {
    // v9.9: Trailing Grid removed - use GridLevelsPerSide directly
    int maxLevel = GridLevelsPerSide;
    if(maxLevel > MAX_GRID_LEVELS) maxLevel = MAX_GRID_LEVELS;

    // Update Upper Zone
    for(int i = 0; i < maxLevel; i++) {
        UpdateGridAUpperStatus(i);
    }

    // Update Lower Zone
    for(int i = 0; i < maxLevel; i++) {
        UpdateGridALowerStatus(i);
    }
}

//+------------------------------------------------------------------+
//| Update Single Grid A Upper Level Status                          |
//+------------------------------------------------------------------+
void UpdateGridAUpperStatus(int level) {
    if(!IsValidTrailingIndex(level, true)) return; // v9.0: Supporta trailing grids

    ulong ticket = gridA_Upper_Tickets[level];
    ENUM_ORDER_STATUS currentStatus = gridA_Upper_Status[level];

    if(ticket == 0 || currentStatus == ORDER_NONE) return;

    // Check if pending order still exists
    if(currentStatus == ORDER_PENDING) {
        if(OrderSelect(ticket)) {
            // Order still pending
            return;
        } else {
            // v9.23 FIX: Check if OnTradeTransaction already updated status
            if(gridA_Upper_Status[level] == ORDER_FILLED) {
                return;  // Already handled by ProcessOrderFilled()
            }

            // Order no longer pending - check if it became a position
            if(PositionSelectByTicket(ticket)) {
                gridA_Upper_Status[level] = ORDER_FILLED;
                LogGridStatus(GRID_A, ZONE_UPPER, level, "Order FILLED");
            } else {
                // v9.23 FIX: Safety net - search position by price before marking cancelled
                if(FindPositionAtPrice(gridA_Upper_EntryPrices[level], POSITION_TYPE_BUY, GetGridMagic(GRID_A))) {
                    gridA_Upper_Status[level] = ORDER_FILLED;
                    LogGridStatus(GRID_A, ZONE_UPPER, level, "Order FILLED (via price match)");
                } else {
                    // Order was deleted/cancelled
                    gridA_Upper_Status[level] = ORDER_CANCELLED;
                    gridA_Upper_Tickets[level] = 0;
                    LogGridStatus(GRID_A, ZONE_UPPER, level, "Order cancelled");
                }
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
    if(!IsValidTrailingIndex(level, false)) return; // v9.0: Supporta trailing grids

    ulong ticket = gridA_Lower_Tickets[level];
    ENUM_ORDER_STATUS currentStatus = gridA_Lower_Status[level];

    if(ticket == 0 || currentStatus == ORDER_NONE) return;

    // Check if pending order still exists
    if(currentStatus == ORDER_PENDING) {
        if(OrderSelect(ticket)) {
            return; // Order still pending
        } else {
            // v9.23 FIX: Check if OnTradeTransaction already updated status
            if(gridA_Lower_Status[level] == ORDER_FILLED) {
                return;  // Already handled by ProcessOrderFilled()
            }

            if(PositionSelectByTicket(ticket)) {
                gridA_Lower_Status[level] = ORDER_FILLED;
                LogGridStatus(GRID_A, ZONE_LOWER, level, "Order FILLED");
            } else {
                // v9.23 FIX: Safety net - search position by price before marking cancelled
                if(FindPositionAtPrice(gridA_Lower_EntryPrices[level], POSITION_TYPE_SELL, GetGridMagic(GRID_A))) {
                    gridA_Lower_Status[level] = ORDER_FILLED;
                    LogGridStatus(GRID_A, ZONE_LOWER, level, "Order FILLED (via price match)");
                } else {
                    gridA_Lower_Status[level] = ORDER_CANCELLED;
                    gridA_Lower_Tickets[level] = 0;
                    LogGridStatus(GRID_A, ZONE_LOWER, level, "Order cancelled");
                }
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

    // v9.9: Trailing Grid removed - use GridLevelsPerSide directly
    int maxLevel = GridLevelsPerSide;
    if(maxLevel > MAX_GRID_LEVELS) maxLevel = MAX_GRID_LEVELS;

    // Upper Zone
    for(int i = 0; i < maxLevel; i++) {
        if(ShouldReopenGridAUpper(i)) {
            ReopenGridAUpper(i);
        }
    }

    // Lower Zone
    for(int i = 0; i < maxLevel; i++) {
        if(ShouldReopenGridALower(i)) {
            ReopenGridALower(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Check if Grid A Upper Level Should Reopen                        |
//| v9.0: Smart Reopen - BUY STOP con offset unidirezionale          |
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

    // v9.0: Smart Reopen - usa orderType per check unidirezionale
    double levelPrice = gridA_Upper_EntryPrices[level];
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_A, ZONE_UPPER);
    if(!IsPriceAtReopenLevelSmart(levelPrice, orderType)) {
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check if Grid A Lower Level Should Reopen                        |
//| v9.0: Smart Reopen - BUY LIMIT immediato                         |
//+------------------------------------------------------------------+
bool ShouldReopenGridALower(int level) {
    ENUM_ORDER_STATUS status = gridA_Lower_Status[level];

    // Can only reopen if closed
    if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
        return false;
    }

    if(!CanLevelReopen(GRID_A, ZONE_LOWER, level)) {
        return false;
    }

    // v9.0: Smart Reopen - LIMIT riapre immediatamente
    double levelPrice = gridA_Lower_EntryPrices[level];
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_A, ZONE_LOWER);
    if(!IsPriceAtReopenLevelSmart(levelPrice, orderType)) {
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Reopen Grid A Upper Level                                        |
//+------------------------------------------------------------------+
void ReopenGridAUpper(int level) {
    ENUM_ORDER_STATUS prevStatus = gridA_Upper_Status[level];
    ulong prevTicket = gridA_Upper_Tickets[level];

    gridA_Upper_Status[level] = ORDER_NONE;
    gridA_Upper_Tickets[level] = 0;

    if(PlaceGridAUpperOrder(level)) {
        Log_OrderPlaced("A", "UP", level + 1, "BUY_STOP", gridA_Upper_Tickets[level],
        gridA_Upper_EntryPrices[level], gridA_Upper_TP[level], 0, gridA_Upper_Lots[level]);
        IncrementCycleCount(GRID_A, ZONE_UPPER, level);
    } else {
        gridA_Upper_Status[level] = prevStatus;
        gridA_Upper_Tickets[level] = prevTicket;
        Log_Debug("Reopen", StringFormat("GridA - UP - L % d FAILED", level + 1));
    }
}

//+------------------------------------------------------------------+
//| Reopen Grid A Lower Level                                        |
//+------------------------------------------------------------------+
void ReopenGridALower(int level) {
    ENUM_ORDER_STATUS prevStatus = gridA_Lower_Status[level];
    ulong prevTicket = gridA_Lower_Tickets[level];

    gridA_Lower_Status[level] = ORDER_NONE;
    gridA_Lower_Tickets[level] = 0;

    if(PlaceGridALowerOrder(level)) {
        Log_OrderPlaced("A", "DN", level + 1, "BUY_LIMIT", gridA_Lower_Tickets[level],
        gridA_Lower_EntryPrices[level], gridA_Lower_TP[level], 0, gridA_Lower_Lots[level]);
        IncrementCycleCount(GRID_A, ZONE_LOWER, level);
    } else {
        gridA_Lower_Status[level] = prevStatus;
        gridA_Lower_Tickets[level] = prevTicket;
        Log_Debug("Reopen", StringFormat("GridA - DN - L % d FAILED", level + 1));
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
    " P / L:" + FormatMoney(profit);
}

