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
//| Get Current ATR Value in Pips                                    |
//+------------------------------------------------------------------+
double GetATRPips() {
    if(atrHandle == INVALID_HANDLE) {
        LogMessage(LOG_WARNING, "ATR handle invalid, returning default");
        return ATR_Normal_Spacing;  // Default fallback
    }

    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0) {
        LogMessage(LOG_WARNING, "Failed to copy ATR buffer, error: " + IntegerToString(GetLastError()));
        return ATR_Normal_Spacing;
    }

    // Convert ATR to pips
    double atrPips = PointsToPips(atrBuffer[0]);
    return atrPips;
}

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
//| ATR ADAPTIVE SPACING LOGIC                                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Optimal Spacing for Current Market                           |
//+------------------------------------------------------------------+
double GetOptimalSpacing() {
    switch(SpacingMode) {
        case SPACING_FIXED:
            return FixedSpacing_Pips;

        case SPACING_ATR:
            return CalculateATRSpacing();

        case SPACING_GEOMETRIC:
            return CalculateGeometricSpacing();

        default:
            return FixedSpacing_Pips;
    }
}

//+------------------------------------------------------------------+
//| Calculate Geometric Spacing (% of price)                         |
//+------------------------------------------------------------------+
double CalculateGeometricSpacing() {
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double spacingPrice = currentPrice * (SpacingGeometric_Percent / 100.0);

    // Convert to pips
    double spacingPips = PointsToPips(spacingPrice);

    // Apply limits
    spacingPips = MathMax(spacingPips, MIN_SPACING_PIPS);
    spacingPips = MathMin(spacingPips, MAX_SPACING_PIPS);

    return spacingPips;
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
//| Wait for ATR Data to be Ready                                    |
//+------------------------------------------------------------------+
bool WaitForATRData(int maxWaitMs = 5000) {
    if(atrHandle == INVALID_HANDLE) return false;

    int waitCount = 0;
    int waitInterval = 100;  // ms

    while(waitCount * waitInterval < maxWaitMs) {
        double atrBuffer[];
        ArraySetAsSeries(atrBuffer, true);

        if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) > 0) {
            if(atrBuffer[0] > 0) {
                return true;  // Data ready
            }
        }

        Sleep(waitInterval);
        waitCount++;
    }

    LogMessage(LOG_WARNING, "Timeout waiting for ATR data");
    return false;
}

//+------------------------------------------------------------------+
//| ATR HISTORICAL ANALYSIS                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Average ATR Over Period                                      |
//+------------------------------------------------------------------+
double GetAverageATR(int periods) {
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

