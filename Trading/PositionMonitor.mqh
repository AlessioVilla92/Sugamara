//+------------------------------------------------------------------+
//|                                             PositionMonitor.mqh  |
//|                        Sugamara - Position Monitor               |
//|                                                                  |
//|  Monitors positions, calculates exposure, risk management        |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| POSITION MONITORING FUNCTIONS                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update All Position Statuses                                     |
//+------------------------------------------------------------------+
void UpdateAllPositionStatuses() {
    // Update Grid A
    UpdateGridAStatuses();

    // Update Grid B
    UpdateGridBStatuses();

    // Recalculate exposure
    CalculateNetExposure();
}

//+------------------------------------------------------------------+
//| Main Position Monitor Tick                                       |
//+------------------------------------------------------------------+
void MonitorPositions() {
    // Update statuses
    UpdateAllPositionStatuses();

    // Check for cyclic reopening
    if(EnableCyclicReopen) {
        ProcessGridACyclicReopen();
        ProcessGridBCyclicReopen();
    }

    // Check risk limits
    CheckRiskLimits();

    // Update statistics
    UpdateTradingStatistics();
}

//+------------------------------------------------------------------+
//| EXPOSURE CALCULATION                                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Total Exposure (Overrides GlobalVariables version)     |
//+------------------------------------------------------------------+
void CalculateTotalExposure() {
    // Grid A exposure
    double gridA_Long = GetGridALongLots();
    double gridA_Short = GetGridAShortLots();

    // Grid B exposure
    double gridB_Long = GetGridBLongLots();
    double gridB_Short = GetGridBShortLots();

    // Combined totals
    totalLongLots = gridA_Long + gridB_Long;
    totalShortLots = gridA_Short + gridB_Short;

    // Net exposure
    netExposure = totalLongLots - totalShortLots;

    // Check if neutral
    isNeutral = (MathAbs(netExposure) <= NetExposure_MaxLot);
}

//+------------------------------------------------------------------+
//| Get Exposure Summary                                             |
//+------------------------------------------------------------------+
string GetExposureSummary() {
    CalculateTotalExposure();

    string direction = "NEUTRAL";
    if(netExposure > 0.001) direction = "LONG";
    if(netExposure < -0.001) direction = "SHORT";

    return direction + " " + DoubleToString(MathAbs(netExposure), 2) + " lot";
}

//+------------------------------------------------------------------+
//| Check Exposure Balance                                           |
//+------------------------------------------------------------------+
bool IsExposureBalanced() {
    CalculateTotalExposure();
    return isNeutral;
}

//+------------------------------------------------------------------+
//| PROFIT & LOSS TRACKING                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Total Open Profit                                            |
//+------------------------------------------------------------------+
double GetTotalOpenProfit() {
    return GetGridAOpenProfit() + GetGridBOpenProfit();
}

//+------------------------------------------------------------------+
//| Get Total Realized Profit (Session)                              |
//+------------------------------------------------------------------+
double GetSessionRealizedProfit() {
    return sessionRealizedProfit;
}

//+------------------------------------------------------------------+
//| Update Session Statistics                                        |
//+------------------------------------------------------------------+
void UpdateSessionStatistics(double profit, bool isWin) {
    sessionRealizedProfit += profit;

    if(isWin) {
        sessionWins++;
        sessionGrossProfit += profit;
    } else {
        sessionLosses++;
        sessionGrossLoss += MathAbs(profit);
    }

    totalTrades++;

    // Update peak profit for drawdown calculation
    if(sessionRealizedProfit > sessionPeakProfit) {
        sessionPeakProfit = sessionRealizedProfit;
    }
}

//+------------------------------------------------------------------+
//| Calculate Session Drawdown                                       |
//+------------------------------------------------------------------+
double GetSessionDrawdown() {
    if(sessionPeakProfit <= 0) return 0;

    double currentProfit = sessionRealizedProfit + GetTotalOpenProfit();
    if(currentProfit >= sessionPeakProfit) return 0;

    return ((sessionPeakProfit - currentProfit) / sessionPeakProfit) * 100.0;
}

//+------------------------------------------------------------------+
//| RISK MANAGEMENT                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check All Risk Limits                                            |
//+------------------------------------------------------------------+
void CheckRiskLimits() {
    // Emergency Stop Check
    if(EnableEmergencyStop) {
        CheckEmergencyStop();
    }

    // Daily Target Check
    if(EnableDailyTarget) {
        CheckDailyLimits();
    }

    // Exposure Check
    CheckExposureLimits();

    // Volatility Check
    if(PauseOnHighATR) {
        CheckVolatilityLimits();
    }
}

//+------------------------------------------------------------------+
//| Check Emergency Stop                                             |
//+------------------------------------------------------------------+
void CheckEmergencyStop() {
    double equity = GetEquity();
    double balance = GetBalance();

    double drawdownPercent = GetCurrentDrawdown();

    if(drawdownPercent >= EmergencyStop_Percent) {
        LogMessage(LOG_ERROR, "EMERGENCY STOP TRIGGERED!");
        LogMessage(LOG_ERROR, "Drawdown: " + FormatPercent(drawdownPercent) +
                   " >= Limit: " + FormatPercent(EmergencyStop_Percent));

        // Close all positions
        EmergencyCloseAll();

        // Change system state
        systemState = STATE_ERROR;

        // Alert
        if(EnableAlerts) {
            Alert("SUGAMARA: EMERGENCY STOP - All positions closed!");
        }
    }
}

//+------------------------------------------------------------------+
//| Check Daily Limits                                               |
//+------------------------------------------------------------------+
void CheckDailyLimits() {
    double dailyPL = GetDailyProfitLoss();

    // Check profit target
    if(dailyPL >= DailyProfitTarget_USD) {
        LogMessage(LOG_SUCCESS, "Daily profit target reached: " + FormatMoney(dailyPL));

        if(systemState == STATE_ACTIVE) {
            systemState = STATE_PAUSED;
            LogMessage(LOG_INFO, "System paused - Daily target achieved");

            if(EnableAlerts) {
                Alert("SUGAMARA: Daily profit target reached!");
            }
        }
    }

    // Check loss limit
    if(dailyPL <= -DailyLossLimit_USD) {
        LogMessage(LOG_WARNING, "Daily loss limit reached: " + FormatMoney(dailyPL));

        if(systemState == STATE_ACTIVE) {
            EmergencyCloseAll();
            systemState = STATE_PAUSED;
            LogMessage(LOG_INFO, "System paused - Daily loss limit reached");

            if(EnableAlerts) {
                Alert("SUGAMARA: Daily loss limit reached - Trading paused!");
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Check Exposure Limits                                            |
//+------------------------------------------------------------------+
void CheckExposureLimits() {
    CalculateTotalExposure();

    if(!isNeutral) {
        double absExposure = MathAbs(netExposure);
        string direction = (netExposure > 0) ? "LONG" : "SHORT";

        LogMessage(LOG_WARNING, "Exposure imbalance: " + direction + " " +
                   DoubleToString(absExposure, 2) + " lot (limit: " +
                   DoubleToString(NetExposure_MaxLot, 2) + ")");

        // Could trigger rebalancing here if implemented
    }
}

//+------------------------------------------------------------------+
//| Check Volatility Limits                                          |
//+------------------------------------------------------------------+
void CheckVolatilityLimits() {
    if(IsMarketTooVolatile()) {
        if(systemState == STATE_ACTIVE) {
            LogMessage(LOG_WARNING, "High volatility detected - New orders paused");
            // Don't change state, just prevent new orders
            // systemState = STATE_PAUSED;
        }
    }
}

//+------------------------------------------------------------------+
//| DAILY P&L TRACKING                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Daily Profit/Loss                                            |
//+------------------------------------------------------------------+
double GetDailyProfitLoss() {
    // Check if new day
    if(IsNewDay()) {
        ResetDailyStatistics();
    }

    return dailyRealizedProfit + GetTotalOpenProfit();
}

//+------------------------------------------------------------------+
//| Reset Daily Statistics                                           |
//+------------------------------------------------------------------+
void ResetDailyStatistics() {
    dailyRealizedProfit = 0;
    dailyWins = 0;
    dailyLosses = 0;
    dailyPeakEquity = GetEquity();

    LogMessage(LOG_INFO, "Daily statistics reset");
}

//+------------------------------------------------------------------+
//| Update Daily Statistics                                          |
//+------------------------------------------------------------------+
void UpdateDailyStatistics(double profit, bool isWin) {
    dailyRealizedProfit += profit;

    if(isWin) {
        dailyWins++;
    } else {
        dailyLosses++;
    }

    double currentEquity = GetEquity();
    if(currentEquity > dailyPeakEquity) {
        dailyPeakEquity = currentEquity;
    }
}

//+------------------------------------------------------------------+
//| TRADING STATISTICS                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update All Trading Statistics                                    |
//+------------------------------------------------------------------+
void UpdateTradingStatistics() {
    // Count active positions
    int gridA_Pos = GetGridAActivePositions();
    int gridB_Pos = GetGridBActivePositions();
    int totalPositions = gridA_Pos + gridB_Pos;

    // Count pending orders
    int gridA_Pend = GetGridAPendingOrders();
    int gridB_Pend = GetGridBPendingOrders();
    int totalPending = gridA_Pend + gridB_Pend;

    // Update global counters
    // (These could be displayed on dashboard)
}

//+------------------------------------------------------------------+
//| Get Win Rate                                                     |
//+------------------------------------------------------------------+
double GetWinRate() {
    return CalculateWinRate(sessionWins, sessionLosses);
}

//+------------------------------------------------------------------+
//| Get Profit Factor                                                |
//+------------------------------------------------------------------+
double GetProfitFactor() {
    return CalculateProfitFactor(sessionGrossProfit, sessionGrossLoss);
}

//+------------------------------------------------------------------+
//| Get Average Win                                                  |
//+------------------------------------------------------------------+
double GetAverageWin() {
    if(sessionWins == 0) return 0;
    return sessionGrossProfit / sessionWins;
}

//+------------------------------------------------------------------+
//| Get Average Loss                                                 |
//+------------------------------------------------------------------+
double GetAverageLoss() {
    if(sessionLosses == 0) return 0;
    return sessionGrossLoss / sessionLosses;
}

//+------------------------------------------------------------------+
//| POSITION COUNT FUNCTIONS                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Total Active Positions                                       |
//+------------------------------------------------------------------+
int GetTotalActivePositions() {
    return GetGridAActivePositions() + GetGridBActivePositions();
}

//+------------------------------------------------------------------+
//| Get Total Pending Orders                                         |
//+------------------------------------------------------------------+
int GetTotalPendingOrders() {
    return GetGridAPendingOrders() + GetGridBPendingOrders();
}

//+------------------------------------------------------------------+
//| Get Total Active (Positions + Pending)                           |
//+------------------------------------------------------------------+
int GetTotalActiveOrders() {
    return GetTotalActivePositions() + GetTotalPendingOrders();
}

//+------------------------------------------------------------------+
//| POSITION REPORT                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Log Detailed Position Report                                     |
//+------------------------------------------------------------------+
void LogPositionReport() {
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  POSITION REPORT");
    Print("═══════════════════════════════════════════════════════════════════");

    // Summary
    Print("Total Positions: ", GetTotalActivePositions());
    Print("Total Pending: ", GetTotalPendingOrders());
    Print("Open P/L: ", FormatMoney(GetTotalOpenProfit()));
    Print("");

    // Grid A Details
    Print("--- GRID A (Long Bias) ---");
    Print("  Positions: ", GetGridAActivePositions());
    Print("  Pending: ", GetGridAPendingOrders());
    Print("  Long Lots: ", DoubleToString(GetGridALongLots(), 2));
    Print("  Short Lots: ", DoubleToString(GetGridAShortLots(), 2));
    Print("  P/L: ", FormatMoney(GetGridAOpenProfit()));
    Print("");

    // Grid B Details
    Print("--- GRID B (Short Bias) ---");
    Print("  Positions: ", GetGridBActivePositions());
    Print("  Pending: ", GetGridBPendingOrders());
    Print("  Long Lots: ", DoubleToString(GetGridBLongLots(), 2));
    Print("  Short Lots: ", DoubleToString(GetGridBShortLots(), 2));
    Print("  P/L: ", FormatMoney(GetGridBOpenProfit()));
    Print("");

    // Exposure
    CalculateTotalExposure();
    Print("--- EXPOSURE ---");
    Print("  Total Long: ", DoubleToString(totalLongLots, 2), " lot");
    Print("  Total Short: ", DoubleToString(totalShortLots, 2), " lot");
    Print("  Net Exposure: ", DoubleToString(netExposure, 2), " lot");
    Print("  Status: ", isNeutral ? "NEUTRAL" : "IMBALANCED");

    Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Get Compact Status for Dashboard                                 |
//+------------------------------------------------------------------+
string GetCompactStatus() {
    int positions = GetTotalActivePositions();
    int pending = GetTotalPendingOrders();
    double openPL = GetTotalOpenProfit();

    return "Pos:" + IntegerToString(positions) +
           " Pend:" + IntegerToString(pending) +
           " P/L:" + FormatMoney(openPL);
}

//+------------------------------------------------------------------+
//| TRADE EVENT HANDLERS                                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Handle Trade Transaction Events                                  |
//+------------------------------------------------------------------+
void OnTradeTransactionHandler(const MqlTradeTransaction& trans,
                                const MqlTradeRequest& request,
                                const MqlTradeResult& result) {

    // Handle deal events (position closed)
    if(trans.type == TRADE_TRANSACTION_DEAL_ADD) {
        ProcessDealEvent(trans.deal);
    }

    // Handle order events
    if(trans.type == TRADE_TRANSACTION_ORDER_DELETE ||
       trans.type == TRADE_TRANSACTION_ORDER_UPDATE) {
        // Trigger status update
        UpdateAllPositionStatuses();
    }
}

//+------------------------------------------------------------------+
//| Process Deal Event (Position Closed)                             |
//+------------------------------------------------------------------+
void ProcessDealEvent(ulong dealTicket) {
    if(!HistoryDealSelect(dealTicket)) return;

    // Get deal info
    long magic = HistoryDealGetInteger(dealTicket, DEAL_MAGIC);
    ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(dealTicket, DEAL_ENTRY);

    // Only process exit deals
    if(entry != DEAL_ENTRY_OUT && entry != DEAL_ENTRY_OUT_BY) return;

    // Check if this is our deal
    if(magic < MagicNumber || magic > MagicNumber + MAGIC_OFFSET_GRID_B + 1000) return;

    // Get profit
    double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
    profit += HistoryDealGetDouble(dealTicket, DEAL_SWAP);
    profit += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

    bool isWin = (profit >= 0);

    // Update statistics
    UpdateSessionStatistics(profit, isWin);
    UpdateDailyStatistics(profit, isWin);

    // Log
    string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
    ENUM_GRID_SIDE side = GetGridSideFromMagic((int)magic);

    LogMessage(isWin ? LOG_SUCCESS : LOG_WARNING,
               GetGridSideName(side) + " position closed: " + FormatMoney(profit));
}

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Position Monitor                                      |
//+------------------------------------------------------------------+
bool InitializePositionMonitor() {
    // Reset session statistics
    sessionRealizedProfit = 0;
    sessionPeakProfit = 0;
    sessionWins = 0;
    sessionLosses = 0;
    sessionGrossProfit = 0;
    sessionGrossLoss = 0;
    totalTrades = 0;

    // Reset daily statistics
    dailyRealizedProfit = 0;
    dailyWins = 0;
    dailyLosses = 0;
    dailyPeakEquity = GetEquity();

    LogMessage(LOG_SUCCESS, "Position Monitor initialized");
    return true;
}

