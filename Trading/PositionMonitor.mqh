//+------------------------------------------------------------------+
//|                                             PositionMonitor.mqh  |
//|                        Sugamara - Position Monitor               |
//|                                                                  |
//|  Monitors positions, calculates exposure, risk management        |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| v5.7: THROTTLING VARIABLES FOR LOG OPTIMIZATION                   |
//+------------------------------------------------------------------+
datetime g_lastExposureWarning = 0;      // Last exposure warning log time
datetime g_lastVolatilityPMWarning = 0;  // Last volatility warning log time
int      g_pmWarningThrottleSec = 300;   // Warning throttle: 5 minutes

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
//| Get Realized Profit for Current Symbol Only (v5.3)               |
//| Calculates P/L only for the current pair, not global             |
//+------------------------------------------------------------------+
double GetCurrentPairRealizedProfit() {
    double profit = 0;

    // Scan deal history for current symbol only (today)
    datetime startOfDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    HistorySelect(startOfDay, TimeCurrent());

    int totalDeals = HistoryDealsTotal();
    for(int i = 0; i < totalDeals; i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket > 0) {
            string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
            long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);

            // Solo questa pair e solo ordini Sugamara
            if(symbol == _Symbol && IsSugamaraMagic(magic)) {
                // Only count exit deals (not entry)
                ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);
                if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY) {
                    profit += HistoryDealGetDouble(ticket, DEAL_PROFIT);
                    profit += HistoryDealGetDouble(ticket, DEAL_SWAP);
                    profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
                }
            }
        }
    }

    return profit;
}

//+------------------------------------------------------------------+
//| Check if Magic Number belongs to Sugamara (v5.3)                 |
//+------------------------------------------------------------------+
bool IsSugamaraMagic(long magic) {
    // Grid A: MagicNumber + 0 to +999
    // Grid B: MagicNumber + 10000 to +10999
    // Shield: MagicNumber + 9001, MagicNumber + 9002
    long baseMagic = MagicNumber;

    if(magic >= baseMagic && magic < baseMagic + 1000) return true;  // Grid A
    if(magic >= baseMagic + 10000 && magic < baseMagic + 11000) return true;  // Grid B
    if(magic == baseMagic + MAGIC_SHIELD_LONG || magic == baseMagic + MAGIC_SHIELD_SHORT) return true;  // Shield

    return false;
}

//+------------------------------------------------------------------+
//| Get Wins for Current Pair Only (v5.3)                            |
//+------------------------------------------------------------------+
int GetCurrentPairWins() {
    int wins = 0;

    datetime startOfDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    HistorySelect(startOfDay, TimeCurrent());

    int totalDeals = HistoryDealsTotal();
    for(int i = 0; i < totalDeals; i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket > 0) {
            string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
            long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);

            if(symbol == _Symbol && IsSugamaraMagic(magic) &&
               (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)) {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                profit += HistoryDealGetDouble(ticket, DEAL_SWAP);
                profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
                if(profit >= 0) wins++;
            }
        }
    }

    return wins;
}

//+------------------------------------------------------------------+
//| Get Losses for Current Pair Only (v5.3)                          |
//+------------------------------------------------------------------+
int GetCurrentPairLosses() {
    int losses = 0;

    datetime startOfDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
    HistorySelect(startOfDay, TimeCurrent());

    int totalDeals = HistoryDealsTotal();
    for(int i = 0; i < totalDeals; i++) {
        ulong ticket = HistoryDealGetTicket(i);
        if(ticket > 0) {
            string symbol = HistoryDealGetString(ticket, DEAL_SYMBOL);
            long magic = HistoryDealGetInteger(ticket, DEAL_MAGIC);
            ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(ticket, DEAL_ENTRY);

            if(symbol == _Symbol && IsSugamaraMagic(magic) &&
               (entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)) {
                double profit = HistoryDealGetDouble(ticket, DEAL_PROFIT);
                profit += HistoryDealGetDouble(ticket, DEAL_SWAP);
                profit += HistoryDealGetDouble(ticket, DEAL_COMMISSION);
                if(profit < 0) losses++;
            }
        }
    }

    return losses;
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

    // v9.11: Daily Target Check removed (EnableDailyTarget removed)

    // Exposure Check
    CheckExposureLimits();

    // v5.8: PauseOnHighATR removed - volatility check disabled
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

// v9.11: CheckDailyLimits() function removed (EnableDailyTarget removed)

//+------------------------------------------------------------------+
//| Check Exposure Limits                                            |
//+------------------------------------------------------------------+
void CheckExposureLimits() {
    CalculateTotalExposure();

    if(!isNeutral) {
        // v5.7: Throttled logging - 1x every 5 minutes if condition persists
        if(TimeCurrent() - g_lastExposureWarning >= g_pmWarningThrottleSec) {
            double absExposure = MathAbs(netExposure);
            string direction = (netExposure > 0) ? "LONG" : "SHORT";

            LogMessage(LOG_WARNING, "Exposure imbalance: " + direction + " " +
                       DoubleToString(absExposure, 2) + " lot (limit: " +
                       DoubleToString(NetExposure_MaxLot, 2) + ")");
            g_lastExposureWarning = TimeCurrent();
        }
        // Could trigger rebalancing here if implemented
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
    Log_Header("POSITION REPORT");

    // Summary
    Log_KeyValueNum("Total Positions", GetTotalActivePositions(), 0);
    Log_KeyValueNum("Total Pending", GetTotalPendingOrders(), 0);
    Log_KeyValue("Open P/L", FormatMoney(GetTotalOpenProfit()));

    // Grid A Details
    Log_SubHeader("GRID A (Long Bias)");
    Log_KeyValueNum("Positions", GetGridAActivePositions(), 0);
    Log_KeyValueNum("Pending", GetGridAPendingOrders(), 0);
    Log_KeyValueNum("Long Lots", GetGridALongLots(), 2);
    Log_KeyValueNum("Short Lots", GetGridAShortLots(), 2);
    Log_KeyValue("P/L", FormatMoney(GetGridAOpenProfit()));

    // Grid B Details
    Log_SubHeader("GRID B (Short Bias)");
    Log_KeyValueNum("Positions", GetGridBActivePositions(), 0);
    Log_KeyValueNum("Pending", GetGridBPendingOrders(), 0);
    Log_KeyValueNum("Long Lots", GetGridBLongLots(), 2);
    Log_KeyValueNum("Short Lots", GetGridBShortLots(), 2);
    Log_KeyValue("P/L", FormatMoney(GetGridBOpenProfit()));

    // Exposure
    CalculateTotalExposure();
    Log_SubHeader("EXPOSURE");
    Log_KeyValueNum("Total Long (lot)", totalLongLots, 2);
    Log_KeyValueNum("Total Short (lot)", totalShortLots, 2);
    Log_KeyValueNum("Net Exposure (lot)", netExposure, 2);
    Log_KeyValue("Status", isNeutral ? "NEUTRAL" : "IMBALANCED");

    Log_Separator();
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

    // v5.7 FIX: Check symbol - filtra solo trade del pair corrente
    string dealSymbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
    if(dealSymbol != _Symbol) return;

    // Get profit
    double profit = HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
    profit += HistoryDealGetDouble(dealTicket, DEAL_SWAP);
    profit += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);

    bool isWin = (profit >= 0);

    // Update statistics
    UpdateSessionStatistics(profit, isWin);
    UpdateDailyStatistics(profit, isWin);

    // v5.1: Record trade for COP (Close On Profit)
    double lots = HistoryDealGetDouble(dealTicket, DEAL_VOLUME);
    COP_RecordTrade(profit, lots);

    // Log
    string symbol = HistoryDealGetString(dealTicket, DEAL_SYMBOL);
    ENUM_GRID_SIDE side = GetGridSideFromMagic((int)magic);

    LogMessage(isWin ? LOG_SUCCESS : LOG_WARNING,
               GetGridSideName(side) + " position closed: " + FormatMoney(profit));

    // v5.9.3: Update Grid Counter (closed count)
    if(isWin) {  // Only count TP hits (wins)
        if(side == GRID_A) {
            g_gridA_ClosedCount++;
        } else if(side == GRID_B) {
            g_gridB_ClosedCount++;
        }
    }
}

//+------------------------------------------------------------------+
//| BREAK ON PROFIT (BOP) v5.1                                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Break On Profit for All Positions                          |
//| Sposta SL a X% del profit quando raggiunge Y% verso TP           |
//+------------------------------------------------------------------+
void CheckBreakOnProfit() {
    if(!Enable_BreakOnProfit) return;

    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;

        // Check symbol
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        // Check magic number (Grid A, Grid B, Shield)
        long magic = PositionGetInteger(POSITION_MAGIC);
        if(magic < MagicNumber || magic > MagicNumber + MAGIC_OFFSET_GRID_B + 1000) continue;

        double entry = PositionGetDouble(POSITION_PRICE_OPEN);
        double tp = PositionGetDouble(POSITION_TP);
        double currentSL = PositionGetDouble(POSITION_SL);
        double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

        // Skip if no TP set
        if(tp == 0) continue;

        // Calculate distances
        double totalDistance = MathAbs(tp - entry);
        double currentDistance = 0;

        if(posType == POSITION_TYPE_BUY) {
            currentDistance = currentPrice - entry;
        } else {
            currentDistance = entry - currentPrice;
        }

        // Skip if in loss
        if(currentDistance <= 0) continue;

        // Calculate progress percentage
        double progressPercent = (currentDistance / totalDistance) * 100.0;

        // Check if trigger reached
        if(progressPercent >= BOP_TriggerPercent) {
            // Calculate new SL at lock percentage of current profit
            double lockDistance = currentDistance * BOP_LockPercent / 100.0;
            double newSL = 0;

            if(posType == POSITION_TYPE_BUY) {
                newSL = entry + lockDistance;
            } else {
                newSL = entry - lockDistance;
            }

            newSL = NormalizeDouble(newSL, _Digits);

            // Only modify if new SL is better
            bool shouldModify = false;
            if(posType == POSITION_TYPE_BUY) {
                if(currentSL == 0 || newSL > currentSL) shouldModify = true;
            } else {
                if(currentSL == 0 || newSL < currentSL) shouldModify = true;
            }

            if(shouldModify) {
                if(trade.PositionModify(ticket, newSL, tp)) {
                    Log_PositionModified(ticket, "SL_BOP", currentSL, newSL);
                } else {
                    Log_Debug("BOP", StringFormat("Position #%d likely closed at TP", ticket));
                }
            }
        }
    }
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

