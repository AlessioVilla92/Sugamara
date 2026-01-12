//+------------------------------------------------------------------+
//|                                         CloseOnProfitManager.mqh |
//|                        Sugamara - Close On Profit System v5.1    |
//|                                                                  |
//|  Daily profit target management with:                            |
//|  - Realized + Floating P/L tracking                              |
//|  - Commission deduction                                          |
//|  - Auto close all positions at target                            |
//|  - Auto delete all pending orders                                |
//|  - Trading pause after target reached                            |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| COP INITIALIZATION                                               |
//+------------------------------------------------------------------+
void InitializeCloseOnProfit() {
    COP_ResetDaily();
    Log_InitConfigNum("COP.Target", COP_DailyTarget_USD);
    Log_InitComplete("COP");
}

//+------------------------------------------------------------------+
//| COP DAILY RESET                                                  |
//+------------------------------------------------------------------+
void COP_ResetDaily() {
    cop_RealizedProfit = 0.0;
    cop_FloatingProfit = 0.0;
    cop_TotalCommissions = 0.0;
    cop_NetProfit = 0.0;
    cop_TargetReached = false;
    cop_TradesToday = 0;
    cop_TotalLotsToday = 0.0;
    cop_LastResetDate = TimeCurrent();

    Log_COPReset("DAILY");
}

//+------------------------------------------------------------------+
//| CHECK IF NEW DAY (for auto reset)                                |
//+------------------------------------------------------------------+
bool COP_IsNewDay() {
    MqlDateTime currentTime, lastResetTime;
    TimeCurrent(currentTime);
    TimeToStruct(cop_LastResetDate, lastResetTime);

    // New day if day changed
    return (currentTime.day != lastResetTime.day ||
            currentTime.mon != lastResetTime.mon ||
            currentTime.year != lastResetTime.year);
}

//+------------------------------------------------------------------+
//| GET CURRENT FLOATING PROFIT (all Sugamara positions)             |
//+------------------------------------------------------------------+
double COP_GetFloatingProfit() {
    double floating = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;

        // Check symbol
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        // Check magic number (Grid A, Grid B)
        long magic = PositionGetInteger(POSITION_MAGIC);
        if(magic < MagicNumber || magic > MagicNumber + MAGIC_OFFSET_GRID_B + 1000) continue;

        floating += PositionGetDouble(POSITION_PROFIT);
        floating += PositionGetDouble(POSITION_SWAP);
    }

    return floating;
}

//+------------------------------------------------------------------+
//| CALCULATE COMMISSIONS                                            |
//+------------------------------------------------------------------+
double COP_CalculateCommissions() {
    if(!COP_DeductCommissions) return 0;
    return cop_TotalLotsToday * COP_CommissionPerLot;
}

//+------------------------------------------------------------------+
//| UPDATE COP TRACKING (call from OnTick)                           |
//+------------------------------------------------------------------+
void COP_UpdateTracking() {
    if(!Enable_CloseOnProfit) return;

    // Check for new day reset
    if(COP_IsNewDay()) {
        COP_ResetDaily();
    }

    // Skip if target already reached
    if(cop_TargetReached) return;

    // v9.0 FIX: Ricalcola RealizedProfit dalla history dei deals
    // Garantisce che il COP funzioni correttamente dopo restart EA
    cop_RealizedProfit = GetCurrentPairRealizedProfit();

    // Update floating
    cop_FloatingProfit = COP_IncludeFloating ? COP_GetFloatingProfit() : 0;

    // Update commissions (solo per display/dashboard)
    cop_TotalCommissions = COP_CalculateCommissions();

    // Calculate net profit
    // v5.7 FIX: cop_RealizedProfit GIA' include DEAL_COMMISSION (negativo)
    // NON sottrarre cop_TotalCommissions per evitare double counting
    cop_NetProfit = cop_RealizedProfit + cop_FloatingProfit;
}

//+------------------------------------------------------------------+
//| CHECK IF TARGET REACHED                                          |
//+------------------------------------------------------------------+
bool COP_CheckTarget() {
    if(!Enable_CloseOnProfit) return false;
    if(cop_TargetReached) return true;

    // Update tracking first
    COP_UpdateTracking();

    if(cop_NetProfit >= COP_DailyTarget_USD) {
        cop_TargetReached = true;

        Log_COPTargetReached(cop_NetProfit, COP_DailyTarget_USD);

        Alert("SUGAMARA COP: Target $", DoubleToString(COP_DailyTarget_USD, 2),
              " reached! Net=$", DoubleToString(cop_NetProfit, 2));

        COP_ExecuteTargetActions();

        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| EXECUTE TARGET ACTIONS                                           |
//+------------------------------------------------------------------+
void COP_ExecuteTargetActions() {
    if(COP_ClosePositions) {
        COP_CloseAllPositions();
    }

    if(COP_DeletePending) {
        COP_DeleteAllPending();
    }

    if(COP_PauseTrading) {
        systemState = STATE_PAUSED;
        Log_Debug("COP", "Trading PAUSED until next day");
    }

    COP_ResetDaily();
}

//+------------------------------------------------------------------+
//| CLOSE ALL SUGAMARA POSITIONS                                     |
//+------------------------------------------------------------------+
void COP_CloseAllPositions() {
    int closed = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;

        // Check symbol
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        // Check magic number
        long magic = PositionGetInteger(POSITION_MAGIC);
        if(magic < MagicNumber || magic > MagicNumber + MAGIC_OFFSET_GRID_B + 1000) continue;

        if(trade.PositionClose(ticket)) {
            closed++;
            Log_PositionClosed(ticket, "COP_TARGET", 0, 0);
        }
    }
}

//+------------------------------------------------------------------+
//| DELETE ALL SUGAMARA PENDING ORDERS                               |
//+------------------------------------------------------------------+
void COP_DeleteAllPending() {
    int deleted = 0;

    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;

        // Check symbol
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

        // Check magic number
        long magic = OrderGetInteger(ORDER_MAGIC);
        if(magic < MagicNumber || magic > MagicNumber + MAGIC_OFFSET_GRID_B + 1000) continue;

        if(trade.OrderDelete(ticket)) {
            deleted++;
            Log_OrderCancelled(ticket, "COP_TARGET");
        }
    }
}

//+------------------------------------------------------------------+
//| RECORD TRADE FOR COP (call from OnTradeTransaction)              |
//+------------------------------------------------------------------+
void COP_RecordTrade(double profit, double lots) {
    if(!Enable_CloseOnProfit) return;

    cop_RealizedProfit += profit;
    cop_TradesToday++;
    cop_TotalLotsToday += lots;

    Log_Debug("COP", StringFormat("Trade recorded profit=%.2f total_realized=%.2f lots_today=%.2f",
              profit, cop_RealizedProfit, cop_TotalLotsToday));
}

//+------------------------------------------------------------------+
//| GET COP NET PROFIT (for dashboard and external use)              |
//+------------------------------------------------------------------+
double COP_GetNetProfit() {
    return cop_NetProfit;
}

//+------------------------------------------------------------------+
//| GET COP PROGRESS PERCENT (for dashboard)                         |
//+------------------------------------------------------------------+
double COP_GetProgressPercent() {
    if(COP_DailyTarget_USD <= 0) return 0;
    double progress = (cop_NetProfit / COP_DailyTarget_USD) * 100.0;
    return MathMax(0, MathMin(100, progress));
}

//+------------------------------------------------------------------+
//| IS COP TARGET REACHED (for external checks)                      |
//+------------------------------------------------------------------+
bool COP_IsTargetReached() {
    return cop_TargetReached;
}

//+------------------------------------------------------------------+
//| SHOULD BLOCK NEW ORDERS (for trading decision)                   |
//+------------------------------------------------------------------+
bool COP_ShouldBlockTrading() {
    if(!Enable_CloseOnProfit) return false;
    if(!COP_PauseTrading) return false;
    return cop_TargetReached;
}

//+------------------------------------------------------------------+
//| COP DEINITIALIZATION                                             |
//+------------------------------------------------------------------+
void DeinitializeCloseOnProfit() {
    Log_Debug("COP", StringFormat("DEINIT realized=%.2f trades=%d lots=%.2f net=%.2f target=%s",
              cop_RealizedProfit, cop_TradesToday, cop_TotalLotsToday, cop_NetProfit,
              cop_TargetReached ? "YES" : "NO"));
}
