//+------------------------------------------------------------------+
//|                                                 RiskManager.mqh  |
//|                        Sugamara - Risk Management                |
//|                                                                  |
//|  Comprehensive risk management for Double Grid Neutral           |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| v5.7: THROTTLING VARIABLES FOR LOG OPTIMIZATION                   |
//+------------------------------------------------------------------+
datetime g_lastMarginWarning = 0;       // Last margin warning log time
datetime g_lastMarginLevelWarning = 0;  // Last margin level warning log time
datetime g_lastVolatilityWarning = 0;   // Last volatility warning log time
datetime g_lastNewsPauseLog = 0;        // Last news pause log time
int      g_warningThrottleSec = 300;    // Warning throttle: 5 minutes

//+------------------------------------------------------------------+
//| RISK MANAGER INITIALIZATION                                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Risk Manager                                          |
//+------------------------------------------------------------------+
bool InitializeRiskManager() {
    // Store initial equity
    startingEquity = GetEquity();
    startingBalance = GetBalance();

    // Initialize tracking variables
    maxDrawdownReached = 0;
    maxEquityReached = startingEquity;

    LogMessage(LOG_SUCCESS, "Risk Manager initialized");
    LogMessage(LOG_INFO, "Starting Equity: " + FormatMoney(startingEquity));
    LogMessage(LOG_INFO, "Emergency Stop: " + FormatPercent(EmergencyStop_Percent));

    return true;
}

//+------------------------------------------------------------------+
//| MAIN RISK CHECK FUNCTION                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Perform All Risk Checks                                          |
//| Returns: true if trading is allowed, false if blocked            |
//+------------------------------------------------------------------+
bool PerformRiskChecks() {
    // 1. Emergency Stop Check (highest priority)
    if(EnableEmergencyStop && IsEmergencyStopTriggered()) {
        return false;
    }

    // 2. Daily Limit Check
    if(EnableDailyTarget && IsDailyLimitReached()) {
        return false;
    }

    // 3. Margin Check (logging throttled inside HasSufficientMargin)
    if(!HasSufficientMargin()) {
        return false;
    }

    // 4. Volatility Check
    if(PauseOnHighATR && IsMarketTooVolatile()) {
        // v5.7: Throttled logging - 1x every 5 minutes if condition persists
        if(TimeCurrent() - g_lastVolatilityWarning >= g_warningThrottleSec) {
            LogMessage(LOG_WARNING, "High volatility - new orders blocked");
            g_lastVolatilityWarning = TimeCurrent();
        }
        return false;
    }

    // 5. News Pause (manual)
    if(PauseOnNews && isNewsPause) {
        // v5.7: Throttled logging - 1x every 5 minutes if condition persists
        if(TimeCurrent() - g_lastNewsPauseLog >= g_warningThrottleSec) {
            LogMessage(LOG_INFO, "News pause active - new orders blocked");
            g_lastNewsPauseLog = TimeCurrent();
        }
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| EMERGENCY STOP                                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Emergency Stop is Triggered                             |
//+------------------------------------------------------------------+
bool IsEmergencyStopTriggered() {
    double currentDD = GetCurrentDrawdown();

    // Update max drawdown tracking
    if(currentDD > maxDrawdownReached) {
        maxDrawdownReached = currentDD;
    }

    if(currentDD >= EmergencyStop_Percent) {
        LogMessage(LOG_ERROR, "!!! EMERGENCY STOP TRIGGERED !!!");
        LogMessage(LOG_ERROR, "Drawdown: " + FormatPercent(currentDD) +
                   " >= Limit: " + FormatPercent(EmergencyStop_Percent));

        TriggerEmergencyStop();
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Execute Emergency Stop                                           |
//+------------------------------------------------------------------+
void TriggerEmergencyStop() {
    // Close all positions immediately
    EmergencyCloseAll();

    // Set system state
    systemState = STATE_ERROR;

    // Alert
    if(EnableAlerts) {
        Alert("SUGAMARA EMERGENCY STOP!\n",
              "Drawdown limit exceeded!\n",
              "All positions have been closed.");
    }

    // Log final status
    LogMessage(LOG_ERROR, "Emergency Stop completed");
    LogMessage(LOG_INFO, "Final Equity: " + FormatMoney(GetEquity()));
    LogMessage(LOG_INFO, "Max Drawdown: " + FormatPercent(maxDrawdownReached));
}

//+------------------------------------------------------------------+
//| DAILY LIMITS                                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Daily Limit is Reached                                  |
//+------------------------------------------------------------------+
bool IsDailyLimitReached() {
    double dailyPL = GetDailyProfitLoss();

    // Profit target reached
    if(dailyPL >= DailyProfitTarget_USD) {
        if(!isDailyTargetReached) {
            isDailyTargetReached = true;
            LogMessage(LOG_SUCCESS, "Daily profit target reached: " + FormatMoney(dailyPL));

            if(EnableAlerts) {
                Alert("SUGAMARA: Daily profit target reached!\n",
                      "Profit: " + FormatMoney(dailyPL));
            }
        }
        return true;
    }

    // Loss limit reached
    if(dailyPL <= -DailyLossLimit_USD) {
        if(!isDailyLossLimitReached) {
            isDailyLossLimitReached = true;
            LogMessage(LOG_WARNING, "Daily loss limit reached: " + FormatMoney(dailyPL));

            // Close all on loss limit
            CloseAllSugamaraOrders();

            if(EnableAlerts) {
                Alert("SUGAMARA: Daily loss limit reached!\n",
                      "Loss: " + FormatMoney(dailyPL) + "\n",
                      "All positions closed.");
            }
        }
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| Reset Daily Flags (Call at start of new day)                     |
//+------------------------------------------------------------------+
void ResetDailyFlags() {
    isDailyTargetReached = false;
    isDailyLossLimitReached = false;
    dailyRealizedProfit = 0;
    dailyWins = 0;
    dailyLosses = 0;

    LogMessage(LOG_INFO, "Daily flags reset for new trading day");
}

//+------------------------------------------------------------------+
//| MARGIN MANAGEMENT                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Sufficient Margin Available                             |
//+------------------------------------------------------------------+
bool HasSufficientMargin() {
    double freeMargin = GetFreeMargin();
    double marginLevel = GetMarginLevel();

    // FIX v4.5: Dynamic margin check based on equity (1% minimum, at least $50)
    double minMarginRequired = AccountInfoDouble(ACCOUNT_EQUITY) * 0.01;
    if(minMarginRequired < 50) minMarginRequired = 50;  // Minimum absolute $50

    if(freeMargin < minMarginRequired) {
        // v5.7: Throttled logging - 1x every 5 minutes if condition persists
        if(TimeCurrent() - g_lastMarginWarning >= g_warningThrottleSec) {
            LogMessage(LOG_WARNING, "Free margin too low: " + FormatMoney(freeMargin) + " (min: " + FormatMoney(minMarginRequired) + ")");
            g_lastMarginWarning = TimeCurrent();
        }
        return false;
    }

    // Margin level check (if positions open)
    if(marginLevel > 0 && marginLevel < 200) {
        // v5.7: Throttled logging - 1x every 5 minutes if condition persists
        if(TimeCurrent() - g_lastMarginLevelWarning >= g_warningThrottleSec) {
            LogMessage(LOG_WARNING, "Margin level too low: " + FormatPercent(marginLevel));
            g_lastMarginLevelWarning = TimeCurrent();
        }
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Calculate Margin Required for Order                              |
//+------------------------------------------------------------------+
double CalculateMarginRequired(double lots, ENUM_ORDER_TYPE orderType) {
    double margin = 0;

    if(!OrderCalcMargin(orderType, _Symbol, lots, SymbolInfoDouble(_Symbol, SYMBOL_ASK), margin)) {
        return -1;  // Error calculating margin
    }

    return margin;
}

//+------------------------------------------------------------------+
//| Check if Order Can be Placed (Margin Check)                      |
//+------------------------------------------------------------------+
bool CanPlaceOrder(double lots, ENUM_ORDER_TYPE orderType) {
    double requiredMargin = CalculateMarginRequired(lots, orderType);

    if(requiredMargin < 0) {
        LogMessage(LOG_WARNING, "Cannot calculate margin requirement");
        return false;
    }

    double freeMargin = GetFreeMargin();
    double safetyBuffer = freeMargin * 0.2;  // Keep 20% buffer

    if(requiredMargin > freeMargin - safetyBuffer) {
        LogMessage(LOG_WARNING, "Insufficient margin for " + DoubleToString(lots, 2) + " lot order");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| EXPOSURE MANAGEMENT                                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Exposure Balance                                           |
//+------------------------------------------------------------------+
bool CheckExposureBalance() {
    CalculateTotalExposure();

    if(!isNeutral) {
        double absExposure = MathAbs(netExposure);

        if(absExposure > NetExposure_MaxLot * 1.5) {
            LogMessage(LOG_WARNING, "Critical exposure imbalance: " +
                       DoubleToString(absExposure, 2) + " lot");
            return false;
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Get Exposure Risk Level                                          |
//| Returns: 0=Safe, 1=Warning, 2=Critical                           |
//+------------------------------------------------------------------+
int GetExposureRiskLevel() {
    CalculateTotalExposure();
    double absExposure = MathAbs(netExposure);

    if(absExposure <= NetExposure_MaxLot * 0.5) return 0;   // Safe
    if(absExposure <= NetExposure_MaxLot) return 1;         // Warning
    return 2;  // Critical
}

//+------------------------------------------------------------------+
//| VOLATILITY MANAGEMENT                                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Volatility Risk                                            |
//+------------------------------------------------------------------+
int GetVolatilityRiskLevel() {
    ENUM_ATR_CONDITION condition = GetATRCondition(GetATRPips());

    switch(condition) {
        case ATR_CALM:     return 0;  // Low risk
        case ATR_NORMAL:   return 1;  // Normal risk
        case ATR_VOLATILE: return 2;  // High risk
        case ATR_EXTREME:  return 3;  // Extreme risk
    }

    return 1;
}

//+------------------------------------------------------------------+
//| Should Reduce Position Size Based on Volatility                  |
//+------------------------------------------------------------------+
double GetVolatilityLotMultiplier() {
    int riskLevel = GetVolatilityRiskLevel();

    switch(riskLevel) {
        case 0: return 1.0;    // Full size
        case 1: return 1.0;    // Full size
        case 2: return 0.75;   // 75% size
        case 3: return 0.5;    // 50% size
    }

    return 1.0;
}

//+------------------------------------------------------------------+
//| NEWS PAUSE MANAGEMENT                                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Set News Pause (Manual Activation)                               |
//+------------------------------------------------------------------+
void SetNewsPause(bool pause) {
    isNewsPause = pause;

    if(pause) {
        LogMessage(LOG_WARNING, "NEWS PAUSE ACTIVATED - New orders blocked");
        if(EnableAlerts) {
            Alert("SUGAMARA: News pause activated");
        }
    } else {
        LogMessage(LOG_INFO, "News pause deactivated - Trading resumed");
    }
}

//+------------------------------------------------------------------+
//| DRAWDOWN TRACKING                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update Equity High Water Mark                                    |
//+------------------------------------------------------------------+
void UpdateEquityTracking() {
    double currentEquity = GetEquity();

    // Update high water mark
    if(currentEquity > maxEquityReached) {
        maxEquityReached = currentEquity;
    }

    // Calculate current drawdown from peak
    double ddFromPeak = 0;
    if(maxEquityReached > 0) {
        ddFromPeak = ((maxEquityReached - currentEquity) / maxEquityReached) * 100.0;
    }

    // Update max drawdown
    if(ddFromPeak > maxDrawdownReached) {
        maxDrawdownReached = ddFromPeak;
    }
}

//+------------------------------------------------------------------+
//| Get Drawdown from Peak Equity                                    |
//+------------------------------------------------------------------+
double GetDrawdownFromPeak() {
    double currentEquity = GetEquity();

    if(maxEquityReached <= 0) return 0;
    if(currentEquity >= maxEquityReached) return 0;

    return ((maxEquityReached - currentEquity) / maxEquityReached) * 100.0;
}

//+------------------------------------------------------------------+
//| RISK REPORT                                                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Generate Risk Report                                             |
//+------------------------------------------------------------------+
void LogRiskReport() {
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  RISK MANAGEMENT REPORT");
    Print("═══════════════════════════════════════════════════════════════════");

    // Account
    Print("--- ACCOUNT STATUS ---");
    Print("  Equity: ", FormatMoney(GetEquity()));
    Print("  Balance: ", FormatMoney(GetBalance()));
    Print("  Free Margin: ", FormatMoney(GetFreeMargin()));
    Print("  Margin Level: ", FormatPercent(GetMarginLevel()));
    Print("");

    // Drawdown
    Print("--- DRAWDOWN ---");
    Print("  Current Drawdown: ", FormatPercent(GetCurrentDrawdown()));
    Print("  Drawdown from Peak: ", FormatPercent(GetDrawdownFromPeak()));
    Print("  Max Drawdown (Session): ", FormatPercent(maxDrawdownReached));
    Print("  Emergency Stop Level: ", FormatPercent(EmergencyStop_Percent));
    Print("");

    // Exposure
    Print("--- EXPOSURE ---");
    CalculateTotalExposure();
    Print("  Total Long: ", DoubleToString(totalLongLots, 2), " lot");
    Print("  Total Short: ", DoubleToString(totalShortLots, 2), " lot");
    Print("  Net Exposure: ", DoubleToString(netExposure, 2), " lot");
    Print("  Max Net Allowed: ", DoubleToString(NetExposure_MaxLot, 2), " lot");
    Print("  Status: ", isNeutral ? "NEUTRAL (OK)" : "IMBALANCED (WARN)");
    Print("");

    // Volatility
    Print("--- VOLATILITY ---");
    double atrPips = GetATRPips();
    Print("  ATR: ", DoubleToString(atrPips, 1), " pips");
    Print("  Condition: ", GetATRConditionName(GetATRCondition(atrPips)));
    Print("  High ATR Threshold: ", DoubleToString(HighATR_Threshold, 1), " pips");
    Print("  Market Too Volatile: ", IsMarketTooVolatile() ? "YES" : "NO");
    Print("");

    // Daily Status
    if(EnableDailyTarget) {
        Print("--- DAILY LIMITS ---");
        Print("  Daily P/L: ", FormatMoney(GetDailyProfitLoss()));
        Print("  Profit Target: ", FormatMoney(DailyProfitTarget_USD));
        Print("  Loss Limit: ", FormatMoney(DailyLossLimit_USD));
        Print("  Target Reached: ", isDailyTargetReached ? "YES" : "NO");
        Print("  Loss Limit Hit: ", isDailyLossLimitReached ? "YES" : "NO");
    }

    Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Get Risk Summary for Dashboard                                   |
//+------------------------------------------------------------------+
string GetRiskSummary() {
    int exposureRisk = GetExposureRiskLevel();
    int volatilityRisk = GetVolatilityRiskLevel();
    double dd = GetCurrentDrawdown();

    string status = "OK";

    if(dd > EmergencyStop_Percent * 0.7) status = "HIGH RISK";
    else if(exposureRisk > 1 || volatilityRisk > 2) status = "WARNING";
    else if(dd > EmergencyStop_Percent * 0.5) status = "CAUTION";

    return status + " (DD:" + FormatPercent(dd) + ")";
}

//+------------------------------------------------------------------+
//| POSITION SIZING BASED ON RISK                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Safe Lot Size Based on Risk                            |
//+------------------------------------------------------------------+
double CalculateSafeLotSize(double desiredLot, int gridLevel) {
    double lot = desiredLot;

    // Apply volatility multiplier
    lot *= GetVolatilityLotMultiplier();

    // Check margin
    ENUM_ORDER_TYPE checkType = ORDER_TYPE_BUY;  // Just for margin calc
    if(!CanPlaceOrder(lot, checkType)) {
        // Reduce lot size until it fits margin
        while(lot > symbolMinLot && !CanPlaceOrder(lot, checkType)) {
            lot = NormalizeLotSize(lot * 0.9);
        }

        if(lot < symbolMinLot) {
            return 0;  // Cannot place order
        }
    }

    // Apply final normalization
    return NormalizeLotSize(lot);
}

