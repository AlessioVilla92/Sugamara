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
    if(entryPoint <= 0 || currentSpacing_Pips <= 0) {
        Log_InitFailed("GridB", "Invalid entry point or spacing");
        return false;
    }

    // Calculate and store values for Upper Zone
    // v9.0: SELL LIMIT (Grid B = sempre SELL)
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
    // v9.0: SELL STOP (Grid B = sempre SELL)
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
//| Log Grid B Configuration                                          |
//+------------------------------------------------------------------+
void LogGridBConfiguration() {
    Log_GridStart("B", entryPoint, currentSpacing_Pips, GridLevelsPerSide);
    Log_InitConfig("GridB.Mode", "SELL_ONLY");
    Log_InitConfig("GridB.Upper", "SELL_LIMIT");
    Log_InitConfig("GridB.Lower", "SELL_STOP");
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

    LogMessage(LOG_INFO, "Grid B: Placed " + IntegerToString(totalPlaced) + " / " +
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
    if(!IsValidTrailingIndex(level, true)) return false; // v9.0: Supporta trailing grids
    if(gridB_Upper_Status[level] != ORDER_NONE) return false;

    double entryPrice = gridB_Upper_EntryPrices[level];
    double tp = gridB_Upper_TP[level];
    double sl = 0; // v5.6: No SL - Auto - hedging compensa le perdite
    double lot = gridB_Upper_Lots[level];

    // v9.0: Grid B Upper = sempre SELL LIMIT
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_B, ZONE_UPPER);
    bool isBuyOrder = false; // v9.0: Grid B = sempre SELL

    // v9.0: Rimosso GetSafeOrderPrice - entry SEMPRE originale
    // Se prezzo invalido, OrderManager ritorna 0 e cyclic reopen riprova

    // Validate TP (v5.6: SL rimosso)
    tp = ValidateTakeProfit(entryPrice, tp, isBuyOrder);

    // Place order
    ulong ticket = PlacePendingOrder(orderType, lot, entryPrice, sl, tp,
    GetGridLevelID(GRID_B, ZONE_UPPER, level),
    GetGridMagic(GRID_B));

    if(ticket > 0) {
        gridB_Upper_Tickets[level] = ticket;
        gridB_Upper_Status[level] = ORDER_PENDING;
        g_gridB_PendingCount++; // v5.9.3: Grid Counter
        LogGridStatus(GRID_B, ZONE_UPPER, level, "Order placed: " + IntegerToString(ticket));
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Place Single Grid B Lower Order (Buy Stop)                       |
//+------------------------------------------------------------------+
bool PlaceGridBLowerOrder(int level) {
    if(!IsValidTrailingIndex(level, false)) return false; // v9.0: Supporta trailing grids
    if(gridB_Lower_Status[level] != ORDER_NONE) return false;

    double entryPrice = gridB_Lower_EntryPrices[level];
    double tp = gridB_Lower_TP[level];
    double sl = 0; // v5.6: No SL - Auto - hedging compensa le perdite
    double lot = gridB_Lower_Lots[level];

    // v9.0: Grid B Lower = sempre SELL STOP
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_B, ZONE_LOWER);
    bool isBuyOrder = false; // v9.0: Grid B = sempre SELL

    // v9.0: Rimosso GetSafeOrderPrice - entry SEMPRE originale
    // Se prezzo invalido, OrderManager ritorna 0 e cyclic reopen riprova

    // Validate TP (v5.6: SL rimosso)
    tp = ValidateTakeProfit(entryPrice, tp, isBuyOrder);

    // Place order
    ulong ticket = PlacePendingOrder(orderType, lot, entryPrice, sl, tp,
    GetGridLevelID(GRID_B, ZONE_LOWER, level),
    GetGridMagic(GRID_B));

    if(ticket > 0) {
        gridB_Lower_Tickets[level] = ticket;
        gridB_Lower_Status[level] = ORDER_PENDING;
        g_gridB_PendingCount++; // v5.9.3: Grid Counter
        LogGridStatus(GRID_B, ZONE_LOWER, level, "Order placed: " + IntegerToString(ticket));
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| GRID B ORDER MONITORING                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Grid B Order Statuses                                     |
//+------------------------------------------------------------------+
void UpdateGridBStatuses() {
    // v9.9: Trailing Grid removed - use GridLevelsPerSide directly
    int maxLevel = GridLevelsPerSide;
    if(maxLevel > MAX_GRID_LEVELS) maxLevel = MAX_GRID_LEVELS;

    // Update Upper Zone
    for(int i = 0; i < maxLevel; i++) {
        UpdateGridBUpperStatus(i);
    }

    // Update Lower Zone
    for(int i = 0; i < maxLevel; i++) {
        UpdateGridBLowerStatus(i);
    }
}

//+------------------------------------------------------------------+
//| Update Single Grid B Upper Level Status                          |
//+------------------------------------------------------------------+
void UpdateGridBUpperStatus(int level) {
    if(!IsValidTrailingIndex(level, true)) return; // v9.0: Supporta trailing grids

    ulong ticket = gridB_Upper_Tickets[level];
    ENUM_ORDER_STATUS currentStatus = gridB_Upper_Status[level];

    if(ticket == 0 || currentStatus == ORDER_NONE) return;

    // Check if pending order still exists
    if(currentStatus == ORDER_PENDING) {
        if(OrderSelect(ticket)) {
            return; // Order still pending
        } else {
            // v9.23 FIX: Check if OnTradeTransaction already updated status
            if(gridB_Upper_Status[level] == ORDER_FILLED) {
                return;  // Already handled by ProcessOrderFilled()
            }

            if(PositionSelectByTicket(ticket)) {
                gridB_Upper_Status[level] = ORDER_FILLED;
                LogGridStatus(GRID_B, ZONE_UPPER, level, "Order FILLED");
            } else {
                // v9.23 FIX: Safety net - search position by price before marking cancelled
                if(FindPositionAtPrice(gridB_Upper_EntryPrices[level], POSITION_TYPE_SELL, GetGridMagic(GRID_B))) {
                    gridB_Upper_Status[level] = ORDER_FILLED;
                    LogGridStatus(GRID_B, ZONE_UPPER, level, "Order FILLED (via price match)");
                } else {
                    gridB_Upper_Status[level] = ORDER_CANCELLED;
                    gridB_Upper_Tickets[level] = 0;
                    LogGridStatus(GRID_B, ZONE_UPPER, level, "Order cancelled");
                }
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
    if(!IsValidTrailingIndex(level, false)) return; // v9.0: Supporta trailing grids

    ulong ticket = gridB_Lower_Tickets[level];
    ENUM_ORDER_STATUS currentStatus = gridB_Lower_Status[level];

    if(ticket == 0 || currentStatus == ORDER_NONE) return;

    // Check if pending order still exists
    if(currentStatus == ORDER_PENDING) {
        if(OrderSelect(ticket)) {
            return;
        } else {
            // v9.23 FIX: Check if OnTradeTransaction already updated status
            if(gridB_Lower_Status[level] == ORDER_FILLED) {
                return;  // Already handled by ProcessOrderFilled()
            }

            if(PositionSelectByTicket(ticket)) {
                gridB_Lower_Status[level] = ORDER_FILLED;
                LogGridStatus(GRID_B, ZONE_LOWER, level, "Order FILLED");
            } else {
                // v9.23 FIX: Safety net - search position by price before marking cancelled
                if(FindPositionAtPrice(gridB_Lower_EntryPrices[level], POSITION_TYPE_BUY, GetGridMagic(GRID_B))) {
                    gridB_Lower_Status[level] = ORDER_FILLED;
                    LogGridStatus(GRID_B, ZONE_LOWER, level, "Order FILLED (via price match)");
                } else {
                    gridB_Lower_Status[level] = ORDER_CANCELLED;
                    gridB_Lower_Tickets[level] = 0;
                    LogGridStatus(GRID_B, ZONE_LOWER, level, "Order cancelled");
                }
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

    // v9.9: Trailing Grid removed - use GridLevelsPerSide directly
    int maxLevel = GridLevelsPerSide;
    if(maxLevel > MAX_GRID_LEVELS) maxLevel = MAX_GRID_LEVELS;

    // Upper Zone
    for(int i = 0; i < maxLevel; i++) {
        if(ShouldReopenGridBUpper(i)) {
            ReopenGridBUpper(i);
        }
    }

    // Lower Zone
    for(int i = 0; i < maxLevel; i++) {
        if(ShouldReopenGridBLower(i)) {
            ReopenGridBLower(i);
        }
    }
}

//+------------------------------------------------------------------+
//| Check if Grid B Upper Level Should Reopen                        |
//+------------------------------------------------------------------+
//| v9.0: Smart Reopen - SELL LIMIT immediato                        |
//+------------------------------------------------------------------+
bool ShouldReopenGridBUpper(int level) {
    ENUM_ORDER_STATUS status = gridB_Upper_Status[level];

    if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
        return false;
    }

    if(!CanLevelReopen(GRID_B, ZONE_UPPER, level)) {
        return false;
    }

    // v9.0: Smart Reopen - LIMIT riapre immediatamente
    double levelPrice = gridB_Upper_EntryPrices[level];
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_B, ZONE_UPPER);
    if(!IsPriceAtReopenLevelSmart(levelPrice, orderType)) {
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check if Grid B Lower Level Should Reopen                        |
//| v9.0: Smart Reopen - SELL STOP con offset unidirezionale         |
//+------------------------------------------------------------------+
bool ShouldReopenGridBLower(int level) {
    ENUM_ORDER_STATUS status = gridB_Lower_Status[level];

    if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
        return false;
    }

    if(!CanLevelReopen(GRID_B, ZONE_LOWER, level)) {
        return false;
    }

    // v9.0: Smart Reopen - usa orderType per check unidirezionale
    double levelPrice = gridB_Lower_EntryPrices[level];
    ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_B, ZONE_LOWER);
    if(!IsPriceAtReopenLevelSmart(levelPrice, orderType)) {
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Reopen Grid B Upper Level                                        |
//| FIX v5.9: SAVE/RESET/TRY/RESTORE pattern for guaranteed retry    |
//+------------------------------------------------------------------+
void ReopenGridBUpper(int level) {
    ENUM_ORDER_STATUS prevStatus = gridB_Upper_Status[level];
    ulong prevTicket = gridB_Upper_Tickets[level];

    gridB_Upper_Status[level] = ORDER_NONE;
    gridB_Upper_Tickets[level] = 0;

    if(PlaceGridBUpperOrder(level)) {
        ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_B, ZONE_UPPER);
        string typeName = (orderType == ORDER_TYPE_SELL_LIMIT) ? "SELL_LIMIT" : "SELL_STOP";
        Log_OrderPlaced("B", "UP", level + 1, typeName, gridB_Upper_Tickets[level],
        gridB_Upper_EntryPrices[level], gridB_Upper_TP[level], 0, gridB_Upper_Lots[level]);
        IncrementCycleCount(GRID_B, ZONE_UPPER, level);
    } else {
        gridB_Upper_Status[level] = prevStatus;
        gridB_Upper_Tickets[level] = prevTicket;
        Log_Debug("Reopen", StringFormat("GridB - UP - L % d failed, retry next tick", level + 1));
    }
}

//+------------------------------------------------------------------+
//| Reopen Grid B Lower Level                                        |
//| FIX v5.9: SAVE/RESET/TRY/RESTORE pattern for guaranteed retry    |
//+------------------------------------------------------------------+
void ReopenGridBLower(int level) {
    ENUM_ORDER_STATUS prevStatus = gridB_Lower_Status[level];
    ulong prevTicket = gridB_Lower_Tickets[level];

    gridB_Lower_Status[level] = ORDER_NONE;
    gridB_Lower_Tickets[level] = 0;

    if(PlaceGridBLowerOrder(level)) {
        ENUM_ORDER_TYPE orderType = GetGridOrderType(GRID_B, ZONE_LOWER);
        string typeName = (orderType == ORDER_TYPE_SELL_STOP) ? "SELL_STOP" : "SELL_LIMIT";
        Log_OrderPlaced("B", "DN", level + 1, typeName, gridB_Lower_Tickets[level],
        gridB_Lower_EntryPrices[level], gridB_Lower_TP[level], 0, gridB_Lower_Lots[level]);
        IncrementCycleCount(GRID_B, ZONE_LOWER, level);
    } else {
        gridB_Lower_Status[level] = prevStatus;
        gridB_Lower_Tickets[level] = prevTicket;
        Log_Debug("Reopen", StringFormat("GridB - DN - L % d failed, retry next tick", level + 1));
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
    " P / L:" + FormatMoney(profit);
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

