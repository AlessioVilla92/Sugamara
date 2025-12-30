//+------------------------------------------------------------------+
//|                                                ATRCalculator.mqh |
//|                        Sugamara - ATR Calculator Module v5.8     |
//|                                                                  |
//|  ATR indicator for volatility monitoring (display only)          |
//|  v5.8: Dynamic spacing removed - ATR used only for monitoring    |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| ATR CONDITION THRESHOLDS (hardcoded for monitoring)              |
//| These are used only for dashboard display, not for spacing       |
//+------------------------------------------------------------------+
#define ATR_THRESHOLD_CALM      8.0   // Below 8 pips = CALM
#define ATR_THRESHOLD_NORMAL    15.0  // 8-15 pips = NORMAL
#define ATR_THRESHOLD_VOLATILE  30.0  // 15-30 pips = VOLATILE
                                       // Above 30 pips = EXTREME

//+------------------------------------------------------------------+
//| ATR CORE FUNCTIONS                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| NOTE: GetATRPips() is defined in Core/ModeLogic.mqh              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get ATR Condition Based on Value (for monitoring only)           |
//+------------------------------------------------------------------+
ENUM_ATR_CONDITION GetATRCondition(double atrPips) {
    if(atrPips < ATR_THRESHOLD_CALM) {
        return ATR_CALM;
    } else if(atrPips < ATR_THRESHOLD_NORMAL) {
        return ATR_NORMAL;
    } else if(atrPips < ATR_THRESHOLD_VOLATILE) {
        return ATR_VOLATILE;
    } else {
        return ATR_EXTREME;
    }
}

//+------------------------------------------------------------------+
//| Get ATR Condition (wrapper using current ATR)                    |
//+------------------------------------------------------------------+
ENUM_ATR_CONDITION GetATRCondition() {
    return GetATRCondition(GetATRPips());
}

//+------------------------------------------------------------------+
//| Get ATR Condition Name                                           |
//+------------------------------------------------------------------+
string GetATRConditionName(ENUM_ATR_CONDITION condition) {
    switch(condition) {
        case ATR_CALM:     return "CALM";
        case ATR_NORMAL:   return "NORMAL";
        case ATR_VOLATILE: return "VOLATILE";
        case ATR_EXTREME:  return "EXTREME";
        default:           return "UNKNOWN";
    }
}


//+------------------------------------------------------------------+
//| ATR VOLATILITY CHECKS                                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Market is Too Volatile (for info display only)          |
//| Always returns false - pause feature removed v5.8                |
//+------------------------------------------------------------------+
bool IsMarketTooVolatile() {
    return false;  // v5.8: Pause on high ATR removed
}

//+------------------------------------------------------------------+
//| Check if Market is Calm Enough for Trading                       |
//+------------------------------------------------------------------+
bool IsMarketCalm() {
    double atrPips = GetATRPips();
    ENUM_ATR_CONDITION condition = GetATRCondition(atrPips);
    return (condition == ATR_CALM || condition == ATR_NORMAL);
}

//+------------------------------------------------------------------+
//| Get Volatility Description                                       |
//+------------------------------------------------------------------+
string GetVolatilityDescription() {
    ENUM_ATR_CONDITION condition = GetATRCondition(GetATRPips());

    switch(condition) {
        case ATR_CALM:     return "Low volatility - Ideal for tight grids";
        case ATR_NORMAL:   return "Normal volatility - Standard grid spacing";
        case ATR_VOLATILE: return "High volatility - Wider spacing recommended";
        case ATR_EXTREME:  return "Extreme volatility - Consider pausing";
        default:           return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| ATR INDICATOR MANAGEMENT                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create ATR Indicator Handle                                      |
//+------------------------------------------------------------------+
bool CreateATRHandle() {
    // Release existing handle if any
    if(atrHandle != INVALID_HANDLE) {
        IndicatorRelease(atrHandle);
    }

    // Create new ATR handle
    atrHandle = iATR(_Symbol, ATR_Timeframe, ATR_Period);

    if(atrHandle == INVALID_HANDLE) {
        LogMessage(LOG_ERROR, "Failed to create ATR indicator, error: " + IntegerToString(GetLastError()));
        return false;
    }

    LogMessage(LOG_SUCCESS, "ATR indicator created: Period=" + IntegerToString(ATR_Period) +
               ", TF=" + EnumToString(ATR_Timeframe));

    return true;
}

//+------------------------------------------------------------------+
//| Release ATR Indicator Handle                                     |
//+------------------------------------------------------------------+
void ReleaseATRHandle() {
    if(atrHandle != INVALID_HANDLE) {
        IndicatorRelease(atrHandle);
        atrHandle = INVALID_HANDLE;
        LogMessage(LOG_INFO, "ATR indicator released");
    }
}

//+------------------------------------------------------------------+
//| Wait for ATR Data to be Ready (v4.7 - conditional Sleep)         |
//| In Strategy Tester: usa Sleep() per attendere                    |
//| In Live Trading: ritorna subito, riprova al prossimo tick        |
//+------------------------------------------------------------------+
bool WaitForATRData(int maxWaitMs = 5000) {
    if(atrHandle == INVALID_HANDLE) return false;

    // v4.7: Verifica se siamo in Strategy Tester
    bool isTester = MQLInfoInteger(MQL_TESTER);

    // Prima verifica immediata (senza Sleep)
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    // Check BarsCalculated first
    int calculated = BarsCalculated(atrHandle);
    if(calculated >= ATR_Period + 1) {
        if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0 && atrBuffer[0] > 0) {
            return true;  // Data already ready
        }
    }

    // v4.7: In Live Trading, ritorna subito senza bloccare
    if(!isTester) {
        // Log solo la prima volta
        static bool liveWarningShown = false;
        if(!liveWarningShown) {
            Print("[ATR] INFO: Live trading - ATR not ready yet, will retry on next tick");
            liveWarningShown = true;
        }
        return false;  // Riprova al prossimo tick
    }

    // Strategy Tester: usa Sleep() per attendere
    int waitCount = 0;
    int waitInterval = 100;  // ms

    while(waitCount * waitInterval < maxWaitMs) {
        calculated = BarsCalculated(atrHandle);
        if(calculated >= ATR_Period + 1) {
            if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0 && atrBuffer[0] > 0) {
                Print("[ATR] INFO: Data ready after ", waitCount * waitInterval, "ms");
                return true;  // Data ready
            }
        }

        Sleep(waitInterval);
        waitCount++;
    }

    LogMessage(LOG_WARNING, "Timeout waiting for ATR data after " + IntegerToString(maxWaitMs) + "ms");
    return false;
}

//+------------------------------------------------------------------+
//| ATR HISTORICAL ANALYSIS                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Average ATR Over Period                                      |
//+------------------------------------------------------------------+
double GetAverageATR(int periods) {
    if(periods <= 0) return 0;  // Prevent division by zero
    if(atrHandle == INVALID_HANDLE) return 0;

    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    if(CopyBuffer(atrHandle, 0, 0, periods, atrBuffer) <= 0) {
        return 0;
    }

    double sum = 0;
    for(int i = 0; i < periods; i++) {
        sum += atrBuffer[i];
    }

    double avgATR = sum / periods;
    return PointsToPips(avgATR);
}

//+------------------------------------------------------------------+
//| Get ATR Trend (Increasing/Decreasing)                            |
//+------------------------------------------------------------------+
int GetATRTrend(int lookback = 5) {
    if(atrHandle == INVALID_HANDLE) return 0;

    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    if(CopyBuffer(atrHandle, 0, 0, lookback, atrBuffer) < lookback) {
        return 0;
    }

    // Compare first half average to second half
    double firstHalf = 0, secondHalf = 0;
    int halfPoint = lookback / 2;

    for(int i = 0; i < halfPoint; i++) {
        firstHalf += atrBuffer[i];  // Recent
    }
    for(int i = halfPoint; i < lookback; i++) {
        secondHalf += atrBuffer[i];  // Older
    }

    firstHalf /= halfPoint;
    secondHalf /= (lookback - halfPoint);

    if(firstHalf > secondHalf * 1.1) return 1;   // Increasing
    if(firstHalf < secondHalf * 0.9) return -1;  // Decreasing
    return 0;  // Stable
}

//+------------------------------------------------------------------+
//| Get ATR Trend Description                                        |
//+------------------------------------------------------------------+
string GetATRTrendDescription() {
    int trend = GetATRTrend();

    if(trend > 0) return "INCREASING";
    if(trend < 0) return "DECREASING";
    return "STABLE";
}

//+------------------------------------------------------------------+
//| ATR LOGGING AND REPORTING                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Log Full ATR Report                                              |
//+------------------------------------------------------------------+
void LogATRReport() {
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  ATR ANALYSIS REPORT");
    Print("═══════════════════════════════════════════════════════════════════");

    double currentATR = GetATRPips();
    double avgATR = GetAverageATR(20);
    ENUM_ATR_CONDITION condition = GetATRCondition(currentATR);

    Print("Current ATR: ", DoubleToString(currentATR, 1), " pips");
    Print("Average ATR (20): ", DoubleToString(avgATR, 1), " pips");
    Print("Condition: ", GetATRConditionName(condition));
    Print("Trend: ", GetATRTrendDescription());
    Print("Current Spacing: ", DoubleToString(currentSpacing_Pips, 1), " pips (Fixed)");
    Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Get ATR Summary String for Dashboard                             |
//+------------------------------------------------------------------+
string GetATRSummary() {
    double atrPips = GetATRPips();
    ENUM_ATR_CONDITION condition = GetATRCondition(atrPips);

    return DoubleToString(atrPips, 1) + " pips (" + GetATRConditionName(condition) + ")";
}

//+------------------------------------------------------------------+
//| ═══════════════════════════════════════════════════════════════════
//| ATR UNIFIED CACHE SYSTEM v5.8 - Simplified (monitoring only)
//| ═══════════════════════════════════════════════════════════════════
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get ATR Unified - Single Source of Truth v5.8                     |
//| updateMode: 0=cache only, 1=force update, 2=if new bar            |
//| v5.8: Simplified - only for monitoring, no spacing logic          |
//+------------------------------------------------------------------+
double GetATRPipsUnified(int updateMode = 0) {
    if(atrHandle == INVALID_HANDLE) {
        static bool handleWarningShown = false;
        if(!handleWarningShown) {
            Print("[ATR] WARNING: Handle invalid, using fallback value");
            handleWarningShown = true;
        }
        return g_atrCache.valuePips > 0 ? g_atrCache.valuePips : 10.0;
    }

    datetime currentBarTime = iTime(_Symbol, ATR_Timeframe, 0);

    // Mode 0: Cache only (for dashboard - fast)
    if(updateMode == 0) {
        if(g_atrCache.isValid) {
            return g_atrCache.valuePips;
        } else {
            updateMode = 1;  // Force update
        }
    }

    // Mode 2: Update only on new candle
    if(updateMode == 2 && g_atrCache.lastBarTime == currentBarTime && g_atrCache.isValid) {
        return g_atrCache.valuePips;
    }

    // Check BarsCalculated
    int calculated = BarsCalculated(atrHandle);
    if(calculated < ATR_Period + 1) {
        return g_atrCache.valuePips > 0 ? g_atrCache.valuePips : 10.0;
    }

    // Force update from indicator
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0) {
        return g_atrCache.valuePips > 0 ? g_atrCache.valuePips : 10.0;
    }

    // Convert to pips
    double atrValue = atrBuffer[0];
    double atrPips = atrValue / symbolPoint;

    // JPY pair correction (3 or 5 digits)
    if(symbolDigits == 3 || symbolDigits == 5) {
        atrPips /= 10.0;
    }

    // Update cache (simplified - no step tracking)
    g_atrCache.valuePips = atrPips;
    g_atrCache.lastFullUpdate = TimeCurrent();
    g_atrCache.lastBarTime = currentBarTime;
    g_atrCache.isValid = true;

    return g_atrCache.valuePips;
}

//+------------------------------------------------------------------+
//| Initialize ATR Cache                                              |
//+------------------------------------------------------------------+
void InitializeATRCache() {
    if(atrHandle != INVALID_HANDLE) {
        GetATRPipsUnified(1);  // Force update
        Print("[ATR] Initialized: ", DoubleToString(g_atrCache.valuePips, 1), " pips");
    }
}

