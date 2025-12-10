//+------------------------------------------------------------------+
//|                                           CenterCalculator.mqh   |
//|                        Sugamara v4.0 - Center Indicators         |
//|                                                                  |
//|  Calcola centro ottimale da 3 indicatori:                        |
//|  - Pivot Point Daily (40% peso default)                          |
//|  - EMA 50 (30% peso default)                                     |
//|  - Donchian Channel Center (30% peso default)                    |
//|                                                                  |
//|  Formula: CENTRO = (Pivot × W1) + (EMA × W2) + (Donchian × W3)   |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Object Names for Chart Lines                                      |
//+------------------------------------------------------------------+
#define CENTER_LINE_PIVOT     "CENTER_PIVOT_LINE"
#define CENTER_LINE_EMA       "CENTER_EMA_LINE"
#define CENTER_LINE_DONCH_U   "CENTER_DONCH_UPPER"
#define CENTER_LINE_DONCH_L   "CENTER_DONCH_LOWER"
#define CENTER_LINE_DONCH_C   "CENTER_DONCH_CENTER"
#define CENTER_LINE_OPTIMAL   "CENTER_OPTIMAL_LINE"
#define CENTER_LABEL_PREFIX   "CENTER_LABEL_"

//+------------------------------------------------------------------+
//| Initialize Center Calculator                                      |
//+------------------------------------------------------------------+
bool InitializeCenterCalculator() {
    // Check if any indicator is enabled
    if(!UsePivotPoint && !UseEMA50 && !UseDonchianCenter) {
        Print("CenterCalculator: All indicators disabled - module inactive");
        return true;
    }

    // Create EMA handle if needed
    if(UseEMA50) {
        g_emaHandle = iMA(_Symbol, EMA_Timeframe, EMA_Period, 0, MODE_EMA, PRICE_CLOSE);
        if(g_emaHandle == INVALID_HANDLE) {
            Print("ERROR: Failed to create EMA indicator handle");
            return false;
        }
    }

    // Initialize structures
    ZeroMemory(g_pivotLevels);
    ZeroMemory(g_donchianLevels);
    ZeroMemory(g_centerCalc);

    // Calculate initial values
    if(UsePivotPoint) CalculateDailyPivot();
    if(UseEMA50) UpdateEMAValue();
    if(UseDonchianCenter) CalculateDonchianChannel();

    // Calculate optimal center
    CalculateOptimalCenter();

    // Draw on chart if enabled
    if(ShowCenterIndicators) {
        DrawCenterIndicators();
    }

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  CenterCalculator v4.0 INITIALIZED");
    if(UsePivotPoint) Print("  Pivot Point: ", DoubleToString(g_pivotLevels.pivot, symbolDigits));
    if(UseEMA50) Print("  EMA(", EMA_Period, "): ", DoubleToString(g_centerCalc.emaCenter, symbolDigits));
    if(UseDonchianCenter) Print("  Donchian Center: ", DoubleToString(g_donchianLevels.center, symbolDigits));
    Print("  OPTIMAL CENTER: ", DoubleToString(g_centerCalc.optimalCenter, symbolDigits));
    Print("  Confidence: ", DoubleToString(g_centerCalc.confidence, 1), "%");
    Print("═══════════════════════════════════════════════════════════════════");

    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize Center Calculator                                    |
//+------------------------------------------------------------------+
void DeinitializeCenterCalculator() {
    // Release EMA handle
    if(g_emaHandle != INVALID_HANDLE) {
        IndicatorRelease(g_emaHandle);
        g_emaHandle = INVALID_HANDLE;
    }

    // Remove chart objects
    RemoveCenterIndicators();
}

//+------------------------------------------------------------------+
//| Calculate Daily Pivot Point                                       |
//+------------------------------------------------------------------+
bool CalculateDailyPivot() {
    // Check if we already calculated today
    MqlDateTime dt;
    TimeCurrent(dt);
    datetime today = StringToTime(StringFormat("%04d.%02d.%02d", dt.year, dt.mon, dt.day));

    if(g_lastPivotCalcDay == today && g_pivotLevels.isValid) {
        return true;  // Already calculated for today
    }

    // Get previous day OHLC from D1 timeframe
    double high[], low[], close[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);
    ArraySetAsSeries(close, true);

    if(CopyHigh(_Symbol, PERIOD_D1, 1, 1, high) <= 0) return false;
    if(CopyLow(_Symbol, PERIOD_D1, 1, 1, low) <= 0) return false;
    if(CopyClose(_Symbol, PERIOD_D1, 1, 1, close) <= 0) return false;

    double H = high[0];
    double L = low[0];
    double C = close[0];

    // Standard Pivot Point Formula
    g_pivotLevels.pivot = (H + L + C) / 3.0;

    // Resistance levels
    g_pivotLevels.r1 = 2 * g_pivotLevels.pivot - L;
    g_pivotLevels.r2 = g_pivotLevels.pivot + (H - L);
    g_pivotLevels.r3 = H + 2 * (g_pivotLevels.pivot - L);

    // Support levels
    g_pivotLevels.s1 = 2 * g_pivotLevels.pivot - H;
    g_pivotLevels.s2 = g_pivotLevels.pivot - (H - L);
    g_pivotLevels.s3 = L - 2 * (H - g_pivotLevels.pivot);

    g_pivotLevels.calcTime = TimeCurrent();
    g_pivotLevels.isValid = true;
    g_lastPivotCalcDay = today;

    if(DetailedLogging) {
        Print("Pivot Point calculated: P=", DoubleToString(g_pivotLevels.pivot, symbolDigits),
              " R1=", DoubleToString(g_pivotLevels.r1, symbolDigits),
              " S1=", DoubleToString(g_pivotLevels.s1, symbolDigits));
    }

    return true;
}

//+------------------------------------------------------------------+
//| Update EMA Value                                                  |
//+------------------------------------------------------------------+
bool UpdateEMAValue() {
    if(g_emaHandle == INVALID_HANDLE) return false;

    double emaBuffer[1];
    if(CopyBuffer(g_emaHandle, 0, 0, 1, emaBuffer) <= 0) {
        return false;
    }

    g_centerCalc.emaCenter = emaBuffer[0];
    return true;
}

//+------------------------------------------------------------------+
//| Calculate Donchian Channel                                        |
//+------------------------------------------------------------------+
bool CalculateDonchianChannel() {
    // Get high and low arrays for Donchian period
    double high[], low[];
    ArraySetAsSeries(high, true);
    ArraySetAsSeries(low, true);

    if(CopyHigh(_Symbol, Donchian_Timeframe, 0, Donchian_Period, high) < Donchian_Period) return false;
    if(CopyLow(_Symbol, Donchian_Timeframe, 0, Donchian_Period, low) < Donchian_Period) return false;

    // Find highest high and lowest low
    double highestHigh = high[0];
    double lowestLow = low[0];

    for(int i = 1; i < Donchian_Period; i++) {
        if(high[i] > highestHigh) highestHigh = high[i];
        if(low[i] < lowestLow) lowestLow = low[i];
    }

    g_donchianLevels.upper = highestHigh;
    g_donchianLevels.lower = lowestLow;
    g_donchianLevels.center = (highestHigh + lowestLow) / 2.0;
    g_donchianLevels.calcTime = TimeCurrent();
    g_donchianLevels.isValid = true;

    return true;
}

//+------------------------------------------------------------------+
//| Calculate Optimal Center (weighted average)                       |
//+------------------------------------------------------------------+
bool CalculateOptimalCenter() {
    // Update indicators
    if(UsePivotPoint) CalculateDailyPivot();
    if(UseEMA50) UpdateEMAValue();
    if(UseDonchianCenter) CalculateDonchianChannel();

    // Normalize weights
    double totalWeight = 0;
    if(UsePivotPoint) totalWeight += Weight_PivotPoint;
    if(UseEMA50) totalWeight += Weight_EMA50;
    if(UseDonchianCenter) totalWeight += Weight_Donchian;

    if(totalWeight <= 0) {
        g_centerCalc.isValid = false;
        return false;
    }

    double w1 = UsePivotPoint ? Weight_PivotPoint / totalWeight : 0;
    double w2 = UseEMA50 ? Weight_EMA50 / totalWeight : 0;
    double w3 = UseDonchianCenter ? Weight_Donchian / totalWeight : 0;

    // Store individual values
    g_centerCalc.pivotCenter = g_pivotLevels.pivot;
    g_centerCalc.donchianCenter = g_donchianLevels.center;

    // Calculate weighted average
    double center = 0;
    if(UsePivotPoint && g_pivotLevels.isValid)
        center += g_centerCalc.pivotCenter * w1;
    if(UseEMA50)
        center += g_centerCalc.emaCenter * w2;
    if(UseDonchianCenter && g_donchianLevels.isValid)
        center += g_centerCalc.donchianCenter * w3;

    g_centerCalc.optimalCenter = center;
    g_centerCalc.calcTime = TimeCurrent();

    // Calculate confidence (how aligned are the indicators)
    g_centerCalc.confidence = CalculateCenterConfidence();
    g_centerCalc.isValid = true;

    g_lastCenterCalc = TimeCurrent();

    return true;
}

//+------------------------------------------------------------------+
//| Calculate Confidence (0-100%)                                     |
//| Higher = indicators more aligned = higher confidence              |
//+------------------------------------------------------------------+
double CalculateCenterConfidence() {
    int count = 0;
    double values[];
    ArrayResize(values, 3);

    if(UsePivotPoint && g_pivotLevels.isValid) {
        values[count++] = g_centerCalc.pivotCenter;
    }
    if(UseEMA50 && g_centerCalc.emaCenter > 0) {
        values[count++] = g_centerCalc.emaCenter;
    }
    if(UseDonchianCenter && g_donchianLevels.isValid) {
        values[count++] = g_centerCalc.donchianCenter;
    }

    if(count < 2) return 100.0;  // Only one indicator, 100% confident

    // Calculate standard deviation as percentage of price
    double mean = 0;
    for(int i = 0; i < count; i++) mean += values[i];
    mean /= count;

    double variance = 0;
    for(int i = 0; i < count; i++) {
        variance += MathPow(values[i] - mean, 2);
    }
    variance /= count;
    double stdDev = MathSqrt(variance);

    // Convert to confidence: lower stdDev = higher confidence
    // Threshold: if stdDev is 0.1% of price = 50% confidence
    double stdDevPercent = (stdDev / mean) * 100;

    // Map 0-0.5% stdDev to 100-0% confidence
    double confidence = MathMax(0, 100 - (stdDevPercent * 200));

    return confidence;
}

//+------------------------------------------------------------------+
//| Get Optimal Center                                                |
//+------------------------------------------------------------------+
double GetOptimalCenter() {
    if(!g_centerCalc.isValid) {
        CalculateOptimalCenter();
    }
    return g_centerCalc.optimalCenter;
}

//+------------------------------------------------------------------+
//| Get Center Confidence                                             |
//+------------------------------------------------------------------+
double GetCenterConfidence() {
    return g_centerCalc.confidence;
}

//+------------------------------------------------------------------+
//| Draw Center Indicators on Chart                                   |
//+------------------------------------------------------------------+
void DrawCenterIndicators() {
    if(!ShowCenterIndicators) return;

    // Pivot Point Line
    if(UsePivotPoint && g_pivotLevels.isValid) {
        CreateHLine(CENTER_LINE_PIVOT, g_pivotLevels.pivot, Color_PivotLine, CenterLines_Width, STYLE_DOT);
        CreateLabel(CENTER_LABEL_PREFIX + "PIVOT", 10, GetYFromPrice(g_pivotLevels.pivot),
                    "Pivot: " + DoubleToString(g_pivotLevels.pivot, symbolDigits), Color_PivotLine, 8);
    }

    // EMA Line
    if(UseEMA50 && g_centerCalc.emaCenter > 0) {
        CreateHLine(CENTER_LINE_EMA, g_centerCalc.emaCenter, Color_EMALine, CenterLines_Width, STYLE_DOT);
        CreateLabel(CENTER_LABEL_PREFIX + "EMA", 10, GetYFromPrice(g_centerCalc.emaCenter),
                    "EMA" + IntegerToString(EMA_Period) + ": " +
                    DoubleToString(g_centerCalc.emaCenter, symbolDigits), Color_EMALine, 8);
    }

    // Donchian Channel Lines
    if(UseDonchianCenter && g_donchianLevels.isValid) {
        CreateHLine(CENTER_LINE_DONCH_U, g_donchianLevels.upper, Color_DonchianUpper, 1, STYLE_DOT);
        CreateHLine(CENTER_LINE_DONCH_L, g_donchianLevels.lower, Color_DonchianLower, 1, STYLE_DOT);
        CreateHLine(CENTER_LINE_DONCH_C, g_donchianLevels.center, Color_DonchianCenter, CenterLines_Width, STYLE_DOT);
        CreateLabel(CENTER_LABEL_PREFIX + "DONCH", 10, GetYFromPrice(g_donchianLevels.center),
                    "Donchian: " + DoubleToString(g_donchianLevels.center, symbolDigits), Color_DonchianCenter, 8);
    }

    // Optimal Center Line (prominent)
    if(g_centerCalc.isValid) {
        CreateHLine(CENTER_LINE_OPTIMAL, g_centerCalc.optimalCenter, Color_OptimalCenter, CenterLines_Width + 1, STYLE_SOLID);
        CreateLabel(CENTER_LABEL_PREFIX + "OPTIMAL", 10, GetYFromPrice(g_centerCalc.optimalCenter) - 15,
                    "OPTIMAL CENTER: " + DoubleToString(g_centerCalc.optimalCenter, symbolDigits) +
                    " (" + DoubleToString(g_centerCalc.confidence, 0) + "% conf)", Color_OptimalCenter, 9);
    }

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Remove Center Indicators from Chart                               |
//+------------------------------------------------------------------+
void RemoveCenterIndicators() {
    ObjectDelete(0, CENTER_LINE_PIVOT);
    ObjectDelete(0, CENTER_LINE_EMA);
    ObjectDelete(0, CENTER_LINE_DONCH_U);
    ObjectDelete(0, CENTER_LINE_DONCH_L);
    ObjectDelete(0, CENTER_LINE_DONCH_C);
    ObjectDelete(0, CENTER_LINE_OPTIMAL);

    // Delete all labels with prefix
    int total = ObjectsTotal(0, 0, OBJ_LABEL);
    for(int i = total - 1; i >= 0; i--) {
        string name = ObjectName(0, i, 0, OBJ_LABEL);
        if(StringFind(name, CENTER_LABEL_PREFIX) == 0) {
            ObjectDelete(0, name);
        }
    }

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| NOTE: CreateHLine and CreateLabel are defined in Utils/Helpers.mqh |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Y coordinate from price                                       |
//+------------------------------------------------------------------+
int GetYFromPrice(double price) {
    int x, y;
    datetime time = TimeCurrent();
    ChartTimePriceToXY(0, 0, time, price, x, y);
    return y;
}

//+------------------------------------------------------------------+
//| Update Center Indicators (called periodically)                    |
//+------------------------------------------------------------------+
void UpdateCenterIndicators() {
    // Recalculate
    CalculateOptimalCenter();

    // Log calculation details
    LogCenterCalculation();

    // Redraw if enabled
    if(ShowCenterIndicators) {
        DrawCenterIndicators();
    }
}

//+------------------------------------------------------------------+
//| Get Center Info String (for dashboard)                            |
//+------------------------------------------------------------------+
string GetCenterInfo() {
    if(!g_centerCalc.isValid) return "N/A";

    return StringFormat("%.5f (%.0f%% conf)",
                        g_centerCalc.optimalCenter,
                        g_centerCalc.confidence);
}

//+------------------------------------------------------------------+
//| LOG CENTER INDICATORS STATUS REPORT                               |
//| Comprehensive diagnostic output for troubleshooting               |
//+------------------------------------------------------------------+
void LogCenterIndicatorsReport() {
    Print("");
    Print("╔═══════════════════════════════════════════════════════════════════╗");
    Print("║              CENTER INDICATORS - STATUS REPORT                    ║");
    Print("╠═══════════════════════════════════════════════════════════════════╣");
    Print("║ CONFIGURATION                                                     ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║  Pivot Point: ", UsePivotPoint ? "ENABLED" : "DISABLED",
          " (Weight: ", DoubleToString(Weight_PivotPoint, 0), "%)");
    Print("║  EMA(", EMA_Period, "): ", UseEMA50 ? "ENABLED" : "DISABLED",
          " (Weight: ", DoubleToString(Weight_EMA50, 0), "%, TF: ", EnumToString(EMA_Timeframe), ")");
    Print("║  Donchian(", Donchian_Period, "): ", UseDonchianCenter ? "ENABLED" : "DISABLED",
          " (Weight: ", DoubleToString(Weight_Donchian, 0), "%, TF: ", EnumToString(Donchian_Timeframe), ")");
    Print("║  Show On Chart: ", ShowCenterIndicators ? "YES" : "NO");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║ CURRENT VALUES                                                    ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    Print("║  Current Price: ", DoubleToString(currentPrice, symbolDigits));

    // Pivot Point
    if(UsePivotPoint && g_pivotLevels.isValid) {
        double pivotDist = (currentPrice - g_pivotLevels.pivot) / symbolPoint;
        Print("║  ─────────────────────────────────────────────────────────────  │");
        Print("║  PIVOT POINT (Daily):");
        Print("║    R3: ", DoubleToString(g_pivotLevels.r3, symbolDigits));
        Print("║    R2: ", DoubleToString(g_pivotLevels.r2, symbolDigits));
        Print("║    R1: ", DoubleToString(g_pivotLevels.r1, symbolDigits));
        Print("║    PP: ", DoubleToString(g_pivotLevels.pivot, symbolDigits),
              " (Price ", pivotDist >= 0 ? "+" : "", DoubleToString(PointsToPips(pivotDist), 1), " pips)");
        Print("║    S1: ", DoubleToString(g_pivotLevels.s1, symbolDigits));
        Print("║    S2: ", DoubleToString(g_pivotLevels.s2, symbolDigits));
        Print("║    S3: ", DoubleToString(g_pivotLevels.s3, symbolDigits));
        Print("║    Calc Time: ", TimeToString(g_pivotLevels.calcTime, TIME_DATE|TIME_SECONDS));
    } else if(UsePivotPoint) {
        Print("║  PIVOT POINT: Not calculated yet");
    }

    // EMA
    if(UseEMA50 && g_centerCalc.emaCenter > 0) {
        double emaDist = (currentPrice - g_centerCalc.emaCenter) / symbolPoint;
        Print("║  ─────────────────────────────────────────────────────────────  │");
        Print("║  EMA(", EMA_Period, "): ", DoubleToString(g_centerCalc.emaCenter, symbolDigits),
              " (Price ", emaDist >= 0 ? "+" : "", DoubleToString(PointsToPips(emaDist), 1), " pips)");
    } else if(UseEMA50) {
        Print("║  EMA: Not available");
    }

    // Donchian
    if(UseDonchianCenter && g_donchianLevels.isValid) {
        double donchDist = (currentPrice - g_donchianLevels.center) / symbolPoint;
        double channelWidth = (g_donchianLevels.upper - g_donchianLevels.lower) / symbolPoint;
        Print("║  ─────────────────────────────────────────────────────────────  │");
        Print("║  DONCHIAN CHANNEL (", Donchian_Period, " periods):");
        Print("║    Upper: ", DoubleToString(g_donchianLevels.upper, symbolDigits));
        Print("║    Center: ", DoubleToString(g_donchianLevels.center, symbolDigits),
              " (Price ", donchDist >= 0 ? "+" : "", DoubleToString(PointsToPips(donchDist), 1), " pips)");
        Print("║    Lower: ", DoubleToString(g_donchianLevels.lower, symbolDigits));
        Print("║    Channel Width: ", DoubleToString(PointsToPips(channelWidth), 1), " pips");
    } else if(UseDonchianCenter) {
        Print("║  DONCHIAN: Not calculated yet");
    }

    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║ OPTIMAL CENTER                                                    ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");

    if(g_centerCalc.isValid) {
        double centerDist = (currentPrice - g_centerCalc.optimalCenter) / symbolPoint;
        double entryDist = (entryPoint - g_centerCalc.optimalCenter) / symbolPoint;

        Print("║  🎯 OPTIMAL CENTER: ", DoubleToString(g_centerCalc.optimalCenter, symbolDigits));
        Print("║  Confidence: ", DoubleToString(g_centerCalc.confidence, 1), "%");
        Print("║  Price Distance: ", centerDist >= 0 ? "+" : "", DoubleToString(PointsToPips(centerDist), 1), " pips");
        Print("║  Entry Distance: ", entryDist >= 0 ? "+" : "", DoubleToString(PointsToPips(entryDist), 1), " pips");
        Print("║  Last Calculated: ", TimeToString(g_centerCalc.calcTime, TIME_DATE|TIME_SECONDS));

        // Recenter recommendation
        if(MathAbs(PointsToPips(entryDist)) > Recenter_EntryDistance_Pips &&
           MathAbs(PointsToPips(centerDist)) < Recenter_PriceProximity_Pips &&
           g_centerCalc.confidence >= Recenter_MinConfidence) {
            Print("║  📢 RECENTER RECOMMENDED - Conditions met!");
        }
    } else {
        Print("║  OPTIMAL CENTER: Not calculated yet");
    }

    Print("╚═══════════════════════════════════════════════════════════════════╝");
    Print("");
}

//+------------------------------------------------------------------+
//| Log Center Calculation Details                                    |
//+------------------------------------------------------------------+
void LogCenterCalculation() {
    if(!DetailedLogging) return;

    Print("");
    Print("┌─────────────────────────────────────────────────────────────────┐");
    Print("│  🎯 CENTER CALCULATION UPDATE                                   │");
    Print("├─────────────────────────────────────────────────────────────────┤");

    // Weights
    double totalWeight = 0;
    if(UsePivotPoint) totalWeight += Weight_PivotPoint;
    if(UseEMA50) totalWeight += Weight_EMA50;
    if(UseDonchianCenter) totalWeight += Weight_Donchian;

    if(totalWeight > 0) {
        double w1 = UsePivotPoint ? Weight_PivotPoint / totalWeight * 100 : 0;
        double w2 = UseEMA50 ? Weight_EMA50 / totalWeight * 100 : 0;
        double w3 = UseDonchianCenter ? Weight_Donchian / totalWeight * 100 : 0;

        Print("│  Normalized Weights:");
        if(UsePivotPoint) Print("│    Pivot: ", DoubleToString(w1, 1), "% × ", DoubleToString(g_centerCalc.pivotCenter, symbolDigits));
        if(UseEMA50) Print("│    EMA: ", DoubleToString(w2, 1), "% × ", DoubleToString(g_centerCalc.emaCenter, symbolDigits));
        if(UseDonchianCenter) Print("│    Donchian: ", DoubleToString(w3, 1), "% × ", DoubleToString(g_centerCalc.donchianCenter, symbolDigits));
    }

    Print("│  ─────────────────────────────────────────────────────────────  │");
    Print("│  Result: ", DoubleToString(g_centerCalc.optimalCenter, symbolDigits),
          " (Conf: ", DoubleToString(g_centerCalc.confidence, 1), "%)");
    Print("│  Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
    Print("└─────────────────────────────────────────────────────────────────┘");
    Print("");
}

//+------------------------------------------------------------------+
//| Get Confidence Level Description                                  |
//+------------------------------------------------------------------+
string GetConfidenceDescription(double confidence) {
    if(confidence >= 90) return "EXCELLENT - Indicators highly aligned";
    if(confidence >= 75) return "GOOD - Strong agreement";
    if(confidence >= 60) return "MODERATE - Acceptable agreement";
    if(confidence >= 40) return "LOW - Indicators diverging";
    return "POOR - High disagreement";
}

