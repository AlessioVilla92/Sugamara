//+------------------------------------------------------------------+
//|                                                ATRCalculator.mqh |
//|                        Sugamara - ATR Calculator Module          |
//|                                                                  |
//|  ATR-based adaptive spacing for Double Grid Neutral              |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| ATR CORE FUNCTIONS                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| NOTE: GetATRPips() is defined in Core/ModeLogic.mqh              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get ATR Condition Based on Value                                 |
//+------------------------------------------------------------------+
ENUM_ATR_CONDITION GetATRCondition(double atrPips) {
    if(atrPips < ATR_Calm_Threshold) {
        return ATR_CALM;
    } else if(atrPips < ATR_Normal_Threshold) {
        return ATR_NORMAL;
    } else if(atrPips < ATR_Volatile_Threshold) {
        return ATR_VOLATILE;
    } else {
        return ATR_EXTREME;
    }
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
//| Get Recommended Spacing for ATR Condition                        |
//+------------------------------------------------------------------+
double GetSpacingForATRCondition(ENUM_ATR_CONDITION condition) {
    switch(condition) {
        case ATR_CALM:     return ATR_Calm_Spacing;
        case ATR_NORMAL:   return ATR_Normal_Spacing;
        case ATR_VOLATILE: return ATR_Volatile_Spacing;
        case ATR_EXTREME:  return ATR_Extreme_Spacing;
        default:           return ATR_Normal_Spacing;
    }
}

//+------------------------------------------------------------------+
//| ATR SPACING CALCULATION                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Spacing Based on Current ATR                           |
//+------------------------------------------------------------------+
double CalculateATRSpacing() {
    double atrPips = GetATRPips();
    ENUM_ATR_CONDITION condition = GetATRCondition(atrPips);

    // Store current values
    currentATR_Pips = atrPips;
    currentATR_Condition = condition;

    double spacing = 0;

    // Method 1: Use decision table (discrete steps)
    if(SpacingMode == SPACING_ATR) {
        spacing = GetSpacingForATRCondition(condition);
    }

    // Method 2: Use multiplier (continuous)
    // spacing = atrPips * SpacingATR_Multiplier;

    // Apply limits
    spacing = MathMax(spacing, MIN_SPACING_PIPS);
    spacing = MathMin(spacing, MAX_SPACING_PIPS);

    if(DetailedLogging) {
        Print("ATR Calculation:");
        Print("  ATR Value: ", DoubleToString(atrPips, 1), " pips");
        Print("  Condition: ", GetATRConditionName(condition));
        Print("  Spacing: ", DoubleToString(spacing, 1), " pips");
    }

    return spacing;
}

//+------------------------------------------------------------------+
//| Calculate Spacing Using ATR Multiplier                           |
//+------------------------------------------------------------------+
double CalculateATRMultiplierSpacing() {
    double atrPips = GetATRPips();

    // Apply multiplier
    double spacing = atrPips * SpacingATR_Multiplier;

    // Apply limits
    spacing = MathMax(spacing, MIN_SPACING_PIPS);
    spacing = MathMin(spacing, MAX_SPACING_PIPS);

    return spacing;
}

//+------------------------------------------------------------------+
//| ATR MONITORING AND RECALCULATION                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if ATR Recalculation is Needed                             |
//+------------------------------------------------------------------+
bool NeedsATRRecalculation() {
    // Check time elapsed
    if(lastATRRecalc == 0) return true;

    double hoursElapsed = HoursElapsed(lastATRRecalc);
    if(hoursElapsed < ATR_RecalcHours) return false;

    // Check if auto-adjust is enabled
    if(!AutoAdjustOnATR) {
        lastATRRecalc = TimeCurrent();
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check if ATR Changed Significantly                               |
//+------------------------------------------------------------------+
bool HasATRChangedSignificantly() {
    if(lastATRValue <= 0) return true;

    double currentATR = GetATRPips();
    double changePercent = MathAbs(PercentChange(lastATRValue, currentATR));

    return (changePercent >= ATR_ChangeThreshold);
}

//+------------------------------------------------------------------+
//| Update ATR Values and Check for Grid Adjustment                  |
//+------------------------------------------------------------------+
bool UpdateATRAndCheckAdjustment() {
    if(!NeedsATRRecalculation()) return false;

    double previousATR = currentATR_Pips;
    ENUM_ATR_CONDITION previousCondition = currentATR_Condition;

    // Recalculate
    double newSpacing = CalculateATRSpacing();

    // Record update time
    lastATRRecalc = TimeCurrent();
    lastATRValue = currentATR_Pips;

    // Check if condition changed
    bool conditionChanged = (previousCondition != currentATR_Condition);

    // Check if ATR changed significantly
    bool significantChange = (previousATR > 0 && HasATRChangedSignificantly());

    if(conditionChanged || significantChange) {
        LogMessage(LOG_INFO, "ATR Update: " + DoubleToString(previousATR, 1) +
                   " -> " + DoubleToString(currentATR_Pips, 1) + " pips");

        if(conditionChanged) {
            LogMessage(LOG_INFO, "Condition: " + GetATRConditionName(previousCondition) +
                       " -> " + GetATRConditionName(currentATR_Condition));
        }

        return true;  // Grid adjustment may be needed
    }

    return false;
}

//+------------------------------------------------------------------+
//| ATR VOLATILITY CHECKS                                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Market is Too Volatile for New Orders                   |
//+------------------------------------------------------------------+
bool IsMarketTooVolatile() {
    if(!PauseOnHighATR) return false;

    double atrPips = GetATRPips();
    return (atrPips >= HighATR_Threshold);
}

//+------------------------------------------------------------------+
//| Check if Market is Calm Enough for Trading                       |
//+------------------------------------------------------------------+
bool IsMarketCalm() {
    double atrPips = GetATRPips();
    return (atrPips < ATR_Normal_Threshold);
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
    Print("Recommended Spacing: ", DoubleToString(GetSpacingForATRCondition(condition), 1), " pips");
    Print("Too Volatile: ", IsMarketTooVolatile() ? "YES" : "NO");
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
//| ATR UNIFIED CACHE SYSTEM v4.1 - Single Source of Truth
//| ═══════════════════════════════════════════════════════════════════
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate ATR Step from ATR Value (5 discrete levels)             |
//+------------------------------------------------------------------+
ENUM_ATR_STEP CalculateATRStep(double atrPips) {
    if(atrPips < ATR_Threshold_VeryLow) {
        return ATR_STEP_VERY_LOW;
    } else if(atrPips < ATR_Threshold_Low) {
        return ATR_STEP_LOW;
    } else if(atrPips < ATR_Threshold_Normal) {
        return ATR_STEP_NORMAL;
    } else if(atrPips < ATR_Threshold_High) {
        return ATR_STEP_HIGH;
    } else {
        return ATR_STEP_EXTREME;
    }
}

//+------------------------------------------------------------------+
//| Get ATR Step Name (helper)                                        |
//+------------------------------------------------------------------+
string GetATRStepName(ENUM_ATR_STEP step) {
    switch(step) {
        case ATR_STEP_VERY_LOW:  return "VERY_LOW";
        case ATR_STEP_LOW:       return "LOW";
        case ATR_STEP_NORMAL:    return "NORMAL";
        case ATR_STEP_HIGH:      return "HIGH";
        case ATR_STEP_EXTREME:   return "EXTREME";
        default:                 return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Get Spacing for ATR Step (5 levels)                               |
//+------------------------------------------------------------------+
double GetSpacingForATRStep(ENUM_ATR_STEP step) {
    double spacing = 0;

    switch(step) {
        case ATR_STEP_VERY_LOW:  spacing = Spacing_VeryLow_Pips; break;
        case ATR_STEP_LOW:       spacing = Spacing_Low_Pips; break;
        case ATR_STEP_NORMAL:    spacing = Spacing_Normal_Pips; break;
        case ATR_STEP_HIGH:      spacing = Spacing_High_Pips; break;
        case ATR_STEP_EXTREME:   spacing = Spacing_Extreme_Pips; break;
        default:                 spacing = Spacing_Normal_Pips; break;
    }

    // Apply absolute limits
    spacing = MathMax(spacing, DynamicSpacing_Min_Pips);
    spacing = MathMin(spacing, DynamicSpacing_Max_Pips);

    return spacing;
}

//+------------------------------------------------------------------+
//| Calculate Spacing with Linear Interpolation (v4.6)               |
//| Formula: spacing = min + (ATR - minATR) * (max - min) / range    |
//+------------------------------------------------------------------+
double GetInterpolatedSpacing(double atrPips) {
    // Clamp ATR to reference range (floor/ceiling)
    double atrClamped = MathMax(ATR_Reference_Min, MathMin(ATR_Reference_Max, atrPips));

    // Prevent division by zero
    double atrRange = ATR_Reference_Max - ATR_Reference_Min;
    if(atrRange <= 0) atrRange = 42.0;  // Default: 50-8=42

    // Linear interpolation formula
    double ratio = (atrClamped - ATR_Reference_Min) / atrRange;
    double spacing = Spacing_Interpolated_Min + ratio * (Spacing_Interpolated_Max - Spacing_Interpolated_Min);

    // Apply absolute limits (safety net)
    spacing = MathMax(spacing, DynamicSpacing_Min_Pips);
    spacing = MathMin(spacing, DynamicSpacing_Max_Pips);

    return NormalizeDouble(spacing, 1);
}

//+------------------------------------------------------------------+
//| Apply Rate Limiting to Spacing Change (v4.6)                     |
//| Prevents sudden jumps even with linear interpolation             |
//+------------------------------------------------------------------+
double ApplyRateLimiting(double targetSpacing, double currentSpacing) {
    if(!EnableRateLimiting || currentSpacing <= 0) {
        return targetSpacing;  // No rate limiting or first call
    }

    double delta = targetSpacing - currentSpacing;

    // Clamp delta to max allowed change
    if(MathAbs(delta) > MaxSpacingChangePerCycle) {
        delta = (delta > 0) ? MaxSpacingChangePerCycle : -MaxSpacingChangePerCycle;

        if(ATR_DetailedLogging) {
            Print("[RATE LIMIT] Target: ", DoubleToString(targetSpacing, 1),
                  " | Applied: ", DoubleToString(currentSpacing + delta, 1),
                  " | Clamped by ", DoubleToString(MaxSpacingChangePerCycle, 1), " pips/cycle");
        }
    }

    return NormalizeDouble(currentSpacing + delta, 1);
}

//+------------------------------------------------------------------+
//| Get ATR Unified - Single Source of Truth v4.7                     |
//| updateMode: 0=cache only, 1=force update, 2=if new bar            |
//| v4.7: Added BarsCalculated check + cache invalid logging          |
//+------------------------------------------------------------------+
double GetATRPipsUnified(int updateMode = 0) {
    // v4.7: Log esplicito se handle invalido
    if(atrHandle == INVALID_HANDLE) {
        static bool handleWarningShown = false;
        if(!handleWarningShown) {
            Print("[ATR UNIFIED] WARNING: Handle invalid, using cached/fallback value");
            handleWarningShown = true;
        }
        return g_atrCache.valuePips > 0 ? g_atrCache.valuePips : Fixed_Spacing_Pips;
    }

    datetime currentBarTime = iTime(_Symbol, ATR_Timeframe, 0);

    // Mode 0: Cache only (for dashboard - fast)
    if(updateMode == 0) {
        if(g_atrCache.isValid) {
            return g_atrCache.valuePips;
        } else {
            // v4.7: Log esplicito se cache non valida, forza update
            static bool cacheWarningShown = false;
            if(!cacheWarningShown) {
                Print("[ATR UNIFIED] WARNING: Cache not valid, forcing update");
                cacheWarningShown = true;
            }
            updateMode = 1;  // Forza update
        }
    }

    // Mode 2: Update only on new candle
    if(updateMode == 2 && g_atrCache.lastBarTime == currentBarTime && g_atrCache.isValid) {
        return g_atrCache.valuePips;
    }

    // v4.7: Verifica BarsCalculated prima di CopyBuffer
    int calculated = BarsCalculated(atrHandle);
    if(calculated < 0) {
        static bool barsErrorShown = false;
        if(!barsErrorShown) {
            Print("[ATR UNIFIED] ERROR: BarsCalculated() returned error: ", GetLastError());
            barsErrorShown = true;
        }
        return g_atrCache.valuePips > 0 ? g_atrCache.valuePips : Fixed_Spacing_Pips;
    }
    if(calculated < ATR_Period + 1) {
        static bool barsWarningShown = false;
        if(!barsWarningShown) {
            Print("[ATR UNIFIED] WARNING: Not ready. Bars: ", calculated, ", Required: ", ATR_Period + 1);
            barsWarningShown = true;
        }
        return g_atrCache.valuePips > 0 ? g_atrCache.valuePips : Fixed_Spacing_Pips;
    }

    // Mode 1 or cache miss: Force update from indicator
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0) {
        static bool copyErrorShown = false;
        if(!copyErrorShown) {
            Print("[ATR UNIFIED] ERROR: CopyBuffer failed, error: ", GetLastError());
            copyErrorShown = true;
        }
        return g_atrCache.valuePips > 0 ? g_atrCache.valuePips : Fixed_Spacing_Pips;
    }

    // Convert to pips
    double atrValue = atrBuffer[0];
    double atrPips = atrValue / symbolPoint;

    // JPY pair correction (3 or 5 digits)
    if(symbolDigits == 3 || symbolDigits == 5) {
        atrPips /= 10.0;
    }

    // Update cache
    g_atrCache.valuePips = atrPips;
    g_atrCache.step = CalculateATRStep(atrPips);
    g_atrCache.lastFullUpdate = TimeCurrent();
    g_atrCache.lastBarTime = currentBarTime;
    g_atrCache.isValid = true;

    return g_atrCache.valuePips;
}

//+------------------------------------------------------------------+
//| Initialize ATR Cache                                              |
//+------------------------------------------------------------------+
void InitializeATRCache() {
    // Force initial update
    if(atrHandle != INVALID_HANDLE) {
        GetATRPipsUnified(1);  // Force update
        if(ATR_DetailedLogging) {
            Print("[ATR CACHE] Initialized: ", DoubleToString(g_atrCache.valuePips, 1),
                  " pips, Step: ", GetATRStepName(g_atrCache.step));
        }
    }
}

