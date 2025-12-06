//+------------------------------------------------------------------+
//|                                              Indicators.mqh      |
//|                  Sugamara - Technical Indicators                 |
//|                                                                  |
//|  Volatility Monitor with Dual Timeframe ATR Analysis             |
//|  ADX Trend Strength with +DI/-DI                                 |
//|  v2.0 - Adapted from Breva-Tivan with Sugamara Theme             |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Global Variables for Volatility Monitor                          |
//+------------------------------------------------------------------+
int atrHandle_Immediate = INVALID_HANDLE;
int atrHandle_Context = INVALID_HANDLE;

double atrValue_Immediate = 0.0;
double atrValue_Context = 0.0;

double volatilityPercent_Immediate = 0.0;
double volatilityPercent_Context = 0.0;

int volatilityRating_Immediate = 0;
int volatilityRating_Context = 0;

string volatilityStatus_Immediate = "IDLE";
string volatilityStatus_Context = "IDLE";

color volatilityColor_Immediate = clrGray;
color volatilityColor_Context = clrGray;

//+------------------------------------------------------------------+
//| Global Variables for ADX Trend Strength                          |
//+------------------------------------------------------------------+
int adxHandle_Immediate = INVALID_HANDLE;
int adxHandle_Context = INVALID_HANDLE;

double adxValue_Immediate = 0.0;
double adxValue_Context = 0.0;

double plusDI_Immediate = 0.0;
double plusDI_Context = 0.0;

double minusDI_Immediate = 0.0;
double minusDI_Context = 0.0;

int trendRating_Immediate = 0;
int trendRating_Context = 0;

string trendStatus_Immediate = "IDLE";
string trendStatus_Context = "IDLE";

string trendDirection_Immediate = "NEUTRAL";
string trendDirection_Context = "NEUTRAL";

color trendColor_Immediate = clrGray;
color trendColor_Context = clrGray;

//+------------------------------------------------------------------+
//| Initialize Volatility Monitor                                    |
//+------------------------------------------------------------------+
bool InitializeVolatilityMonitor() {
    if(!EnableVolatilityMonitor) {
        Print("[Indicators] Volatility Monitor is DISABLED");
        return true;
    }

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  INITIALIZING VOLATILITY MONITOR - DUAL TIMEFRAME                ");
    Print("═══════════════════════════════════════════════════════════════════");

    // Initialize Immediate Timeframe ATR
    atrHandle_Immediate = iATR(_Symbol, Vol_TF_Immediate, Vol_ATR_Period);
    if(atrHandle_Immediate == INVALID_HANDLE) {
        Print("[Indicators] ERROR: Failed to create ATR for Immediate TF: ",
              EnumToString(Vol_TF_Immediate));
        return false;
    }
    Print("[Indicators] SUCCESS: ATR Immediate initialized - TF: ",
          EnumToString(Vol_TF_Immediate), " Period: ", Vol_ATR_Period);

    // Initialize Context Timeframe ATR
    ENUM_TIMEFRAMES contextTF = Vol_TF_Context;
    if(contextTF == PERIOD_CURRENT) {
        contextTF = Period();
    }

    atrHandle_Context = iATR(_Symbol, contextTF, Vol_ATR_Period);
    if(atrHandle_Context == INVALID_HANDLE) {
        Print("[Indicators] ERROR: Failed to create ATR for Context TF: ",
              EnumToString(contextTF));
        return false;
    }
    Print("[Indicators] SUCCESS: ATR Context initialized - TF: ",
          EnumToString(contextTF), " Period: ", Vol_ATR_Period);

    Print("[Indicators] SUCCESS: Volatility Monitor initialized!");
    Print("═══════════════════════════════════════════════════════════════════");

    return true;
}

//+------------------------------------------------------------------+
//| Update Volatility Monitor [Throttled]                            |
//+------------------------------------------------------------------+
void UpdateVolatilityMonitor() {
    if(!EnableVolatilityMonitor) return;

    // Throttle: update once per second
    static datetime lastUpdate = 0;
    datetime currentTime = TimeCurrent();

    if(currentTime == lastUpdate) {
        return;
    }
    lastUpdate = currentTime;

    // Update both timeframes
    UpdateATR_Immediate();
    UpdateATR_Context();
}

//+------------------------------------------------------------------+
//| Update ATR for Immediate Timeframe                               |
//+------------------------------------------------------------------+
void UpdateATR_Immediate() {
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    if(CopyBuffer(atrHandle_Immediate, 0, 0, 1, atrBuffer) <= 0) {
        return;
    }

    atrValue_Immediate = atrBuffer[0];

    // Calculate volatility as percentage of current price
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(currentPrice > 0) {
        volatilityPercent_Immediate = (atrValue_Immediate / currentPrice) * 100.0;
    }

    // Calculate Rating (1-9)
    volatilityRating_Immediate = CalculateVolatilityRating(volatilityPercent_Immediate);

    // Determine Status and Color
    DetermineVolatilityStatus(volatilityRating_Immediate,
                              volatilityStatus_Immediate,
                              volatilityColor_Immediate);
}

//+------------------------------------------------------------------+
//| Update ATR for Context Timeframe                                 |
//+------------------------------------------------------------------+
void UpdateATR_Context() {
    double atrBuffer[];
    ArraySetAsSeries(atrBuffer, true);

    if(CopyBuffer(atrHandle_Context, 0, 0, 1, atrBuffer) <= 0) {
        return;
    }

    atrValue_Context = atrBuffer[0];

    // Calculate volatility as percentage of current price
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(currentPrice > 0) {
        volatilityPercent_Context = (atrValue_Context / currentPrice) * 100.0;
    }

    // Calculate Rating (1-9)
    volatilityRating_Context = CalculateVolatilityRating(volatilityPercent_Context);

    // Determine Status and Color
    DetermineVolatilityStatus(volatilityRating_Context,
                              volatilityStatus_Context,
                              volatilityColor_Context);
}

//+------------------------------------------------------------------+
//| Calculate Volatility Rating (1-9 Scale)                          |
//+------------------------------------------------------------------+
int CalculateVolatilityRating(double volatilityPercent) {
    if(volatilityPercent < Volatility_Rating1) return 1;
    if(volatilityPercent < Volatility_Rating2) return 2;
    if(volatilityPercent < Volatility_Rating3) return 3;
    if(volatilityPercent < Volatility_Rating4) return 4;
    if(volatilityPercent < Volatility_Rating5) return 5;
    if(volatilityPercent < Volatility_Rating6) return 6;
    if(volatilityPercent < Volatility_Rating7) return 7;
    if(volatilityPercent < Volatility_Rating8) return 8;

    return 9;
}

//+------------------------------------------------------------------+
//| Determine Status Label and Color based on Rating                 |
//+------------------------------------------------------------------+
void DetermineVolatilityStatus(int rating, string &status, color &statusColor) {
    switch(rating) {
        case 1:
            status = "BASSISSIMA";
            statusColor = C'0,150,150';      // Teal scuro
            break;
        case 2:
        case 3:
            status = "BASSA";
            statusColor = C'0,200,200';      // Cyan
            break;
        case 4:
        case 5:
            status = "MEDIA";
            statusColor = C'100,180,255';    // Azure
            break;
        case 6:
        case 7:
            status = "ALTA";
            statusColor = C'255,180,100';    // Arancione chiaro
            break;
        case 8:
        case 9:
            status = "ALTISSIMA";
            statusColor = C'255,100,100';    // Rosso chiaro
            break;
        default:
            status = "N/A";
            statusColor = clrGray;
    }
}

//+------------------------------------------------------------------+
//| Get ATR in Pips                                                  |
//+------------------------------------------------------------------+
double GetATRInPips(double atrValue) {
    double pipSize = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    if(SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 3 ||
       SymbolInfoInteger(_Symbol, SYMBOL_DIGITS) == 5) {
        pipSize *= 10;
    }
    return atrValue / pipSize;
}

//+------------------------------------------------------------------+
//| Get Timeframe Display Name                                       |
//+------------------------------------------------------------------+
string GetTimeframeName(ENUM_TIMEFRAMES tf) {
    switch(tf) {
        case PERIOD_M1: return "M1";
        case PERIOD_M2: return "M2";
        case PERIOD_M3: return "M3";
        case PERIOD_M4: return "M4";
        case PERIOD_M5: return "M5";
        case PERIOD_M6: return "M6";
        case PERIOD_M10: return "M10";
        case PERIOD_M12: return "M12";
        case PERIOD_M15: return "M15";
        case PERIOD_M20: return "M20";
        case PERIOD_M30: return "M30";
        case PERIOD_H1: return "H1";
        case PERIOD_H2: return "H2";
        case PERIOD_H3: return "H3";
        case PERIOD_H4: return "H4";
        case PERIOD_H6: return "H6";
        case PERIOD_H8: return "H8";
        case PERIOD_H12: return "H12";
        case PERIOD_D1: return "D1";
        case PERIOD_W1: return "W1";
        case PERIOD_MN1: return "MN";
        default: return "??";
    }
}

//+------------------------------------------------------------------+
//| Deinitialize Volatility Monitor                                  |
//+------------------------------------------------------------------+
void DeinitializeVolatilityMonitor() {
    if(atrHandle_Immediate != INVALID_HANDLE) {
        IndicatorRelease(atrHandle_Immediate);
        atrHandle_Immediate = INVALID_HANDLE;
    }

    if(atrHandle_Context != INVALID_HANDLE) {
        IndicatorRelease(atrHandle_Context);
        atrHandle_Context = INVALID_HANDLE;
    }

    Print("[Indicators] Volatility Monitor deinitialized");
}

//+------------------------------------------------------------------+
//| Get Volatility Report                                            |
//+------------------------------------------------------------------+
string GetVolatilityReport() {
    if(!EnableVolatilityMonitor) return "Volatility Monitor Disabled";

    double atrPips_Imm = GetATRInPips(atrValue_Immediate);
    double atrPips_Ctx = GetATRInPips(atrValue_Context);

    string report = StringFormat(
        "\n═══════════════ VOLATILITY REPORT ═══════════════\n" +
        "IMMEDIATE:\n" +
        "  ATR: %.5f (%.1f pips) | Vol: %.2f%% | Rating: %d/9 | %s\n" +
        "CONTEXT:\n" +
        "  ATR: %.5f (%.1f pips) | Vol: %.2f%% | Rating: %d/9 | %s\n" +
        "═════════════════════════════════════════════════",
        atrValue_Immediate, atrPips_Imm, volatilityPercent_Immediate,
        volatilityRating_Immediate, volatilityStatus_Immediate,
        atrValue_Context, atrPips_Ctx, volatilityPercent_Context,
        volatilityRating_Context, volatilityStatus_Context
    );

    return report;
}

//+------------------------------------------------------------------+
//|                     ADX TREND STRENGTH SYSTEM                     |
//|                   Dual Timeframe with +DI/-DI                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize ADX Trend Monitor                                      |
//+------------------------------------------------------------------+
bool InitializeADXMonitor() {
    if(!EnableADXMonitor) {
        Print("[Indicators] ADX Trend Monitor is DISABLED");
        return true;
    }

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  INITIALIZING ADX TREND MONITOR - DUAL TIMEFRAME                 ");
    Print("═══════════════════════════════════════════════════════════════════");

    // Initialize Immediate Timeframe ADX
    adxHandle_Immediate = iADX(_Symbol, ADX_TF_Immediate, ADX_Period_Monitor);
    if(adxHandle_Immediate == INVALID_HANDLE) {
        Print("[Indicators] ERROR: Failed to create ADX for Immediate TF: ",
              EnumToString(ADX_TF_Immediate));
        return false;
    }
    Print("[Indicators] SUCCESS: ADX Immediate initialized - TF: ",
          EnumToString(ADX_TF_Immediate), " Period: ", ADX_Period_Monitor);

    // Initialize Context Timeframe ADX
    ENUM_TIMEFRAMES contextTF = ADX_TF_Context;
    if(contextTF == PERIOD_CURRENT) {
        contextTF = Period();
    }

    adxHandle_Context = iADX(_Symbol, contextTF, ADX_Period_Monitor);
    if(adxHandle_Context == INVALID_HANDLE) {
        Print("[Indicators] ERROR: Failed to create ADX for Context TF: ",
              EnumToString(contextTF));
        return false;
    }
    Print("[Indicators] SUCCESS: ADX Context initialized - TF: ",
          EnumToString(contextTF), " Period: ", ADX_Period_Monitor);

    Print("[Indicators] SUCCESS: ADX Trend Monitor initialized!");
    Print("═══════════════════════════════════════════════════════════════════");

    return true;
}

//+------------------------------------------------------------------+
//| Update ADX Trend Monitor [Throttled]                             |
//+------------------------------------------------------------------+
void UpdateADXMonitor() {
    if(!EnableADXMonitor) return;

    // Throttle: update once per second
    static datetime lastUpdate = 0;
    datetime currentTime = TimeCurrent();

    if(currentTime == lastUpdate) {
        return;
    }
    lastUpdate = currentTime;

    // Update both timeframes
    UpdateADX_Immediate();
    UpdateADX_Context();
}

//+------------------------------------------------------------------+
//| Update ADX for Immediate Timeframe                               |
//+------------------------------------------------------------------+
void UpdateADX_Immediate() {
    double adxBuffer[];
    double plusDIBuffer[];
    double minusDIBuffer[];

    ArraySetAsSeries(adxBuffer, true);
    ArraySetAsSeries(plusDIBuffer, true);
    ArraySetAsSeries(minusDIBuffer, true);

    // Buffer 0 = ADX Main Line
    // Buffer 1 = +DI (Plus Directional Indicator)
    // Buffer 2 = -DI (Minus Directional Indicator)

    if(CopyBuffer(adxHandle_Immediate, 0, 0, 1, adxBuffer) <= 0) return;
    if(CopyBuffer(adxHandle_Immediate, 1, 0, 1, plusDIBuffer) <= 0) return;
    if(CopyBuffer(adxHandle_Immediate, 2, 0, 1, minusDIBuffer) <= 0) return;

    adxValue_Immediate = adxBuffer[0];
    plusDI_Immediate = plusDIBuffer[0];
    minusDI_Immediate = minusDIBuffer[0];

    // Calculate Rating (1-9)
    trendRating_Immediate = CalculateTrendRating(adxValue_Immediate);

    // Determine Trend Direction
    trendDirection_Immediate = DetermineTrendDirection(plusDI_Immediate, minusDI_Immediate);

    // Determine Status and Color
    DetermineTrendStatus(trendRating_Immediate,
                         trendDirection_Immediate,
                         trendStatus_Immediate,
                         trendColor_Immediate);
}

//+------------------------------------------------------------------+
//| Update ADX for Context Timeframe                                 |
//+------------------------------------------------------------------+
void UpdateADX_Context() {
    double adxBuffer[];
    double plusDIBuffer[];
    double minusDIBuffer[];

    ArraySetAsSeries(adxBuffer, true);
    ArraySetAsSeries(plusDIBuffer, true);
    ArraySetAsSeries(minusDIBuffer, true);

    if(CopyBuffer(adxHandle_Context, 0, 0, 1, adxBuffer) <= 0) return;
    if(CopyBuffer(adxHandle_Context, 1, 0, 1, plusDIBuffer) <= 0) return;
    if(CopyBuffer(adxHandle_Context, 2, 0, 1, minusDIBuffer) <= 0) return;

    adxValue_Context = adxBuffer[0];
    plusDI_Context = plusDIBuffer[0];
    minusDI_Context = minusDIBuffer[0];

    // Calculate Rating (1-9)
    trendRating_Context = CalculateTrendRating(adxValue_Context);

    // Determine Trend Direction
    trendDirection_Context = DetermineTrendDirection(plusDI_Context, minusDI_Context);

    // Determine Status and Color
    DetermineTrendStatus(trendRating_Context,
                         trendDirection_Context,
                         trendStatus_Context,
                         trendColor_Context);
}

//+------------------------------------------------------------------+
//| Calculate Trend Rating (1-9 Scale) based on ADX value            |
//+------------------------------------------------------------------+
int CalculateTrendRating(double adxValue) {
    if(adxValue < ADX_Rating_1) return 1;
    if(adxValue < ADX_Rating_2) return 2;
    if(adxValue < ADX_Rating_3) return 3;
    if(adxValue < ADX_Rating_4) return 4;
    if(adxValue < ADX_Rating_5) return 5;
    if(adxValue < ADX_Rating_6) return 6;
    if(adxValue < ADX_Rating_7) return 7;
    if(adxValue < ADX_Rating_8) return 8;

    return 9;
}

//+------------------------------------------------------------------+
//| Determine Trend Direction based on +DI and -DI                   |
//+------------------------------------------------------------------+
string DetermineTrendDirection(double plusDI, double minusDI) {
    double diDiff = MathAbs(plusDI - minusDI);

    // If difference is too small, trend is indecisive
    if(diDiff < 2.0) {
        return "NEUTRAL";
    }

    if(plusDI > minusDI) {
        return "UPTREND";
    } else {
        return "DOWNTREND";
    }
}

//+------------------------------------------------------------------+
//| Determine Trend Status Label and Color                           |
//+------------------------------------------------------------------+
void DetermineTrendStatus(int rating, string direction, string &status, color &statusColor) {
    if(rating <= 3) {
        // Weak/No trend - IDEAL per Grid Neutral!
        status = "NO TREND";
        statusColor = C'0,200,200';  // Cyan - Good for neutral
    }
    else if(rating == 4) {
        // Pre-trend forming
        status = "FORMING";
        statusColor = C'200,200,100';    // Yellow
    }
    else if(rating == 5) {
        // Trend confirmed
        if(direction == "UPTREND") {
            status = "CONFIRMED UP";
            statusColor = C'100,200,100';  // Green
        } else if(direction == "DOWNTREND") {
            status = "CONFIRMED DOWN";
            statusColor = C'200,100,100';  // Red
        } else {
            status = "CONFIRMED";
            statusColor = C'200,200,100';
        }
    }
    else if(rating >= 6 && rating <= 7) {
        // Strong trend - ATTENZIONE per Grid Neutral
        if(direction == "UPTREND") {
            status = "STRONG UP";
            statusColor = C'255,180,0';  // Orange
        } else if(direction == "DOWNTREND") {
            status = "STRONG DOWN";
            statusColor = C'255,180,0';  // Orange
        } else {
            status = "STRONG";
            statusColor = C'255,180,0';
        }
    }
    else {
        // Very strong / Extreme - PERICOLO per Grid Neutral
        if(direction == "UPTREND") {
            status = "EXTREME UP";
            statusColor = C'255,80,80'; // Red
        } else if(direction == "DOWNTREND") {
            status = "EXTREME DOWN";
            statusColor = C'255,80,80'; // Red
        } else {
            status = "EXTREME";
            statusColor = C'255,80,80';
        }
    }
}

//+------------------------------------------------------------------+
//| Get Trend Arrow Symbol                                           |
//+------------------------------------------------------------------+
string GetTrendArrow(string direction) {
    if(direction == "UPTREND") return "▲";
    if(direction == "DOWNTREND") return "▼";
    return "●";  // Neutral
}

//+------------------------------------------------------------------+
//| Deinitialize ADX Monitor                                         |
//+------------------------------------------------------------------+
void DeinitializeADXMonitor() {
    if(adxHandle_Immediate != INVALID_HANDLE) {
        IndicatorRelease(adxHandle_Immediate);
        adxHandle_Immediate = INVALID_HANDLE;
    }

    if(adxHandle_Context != INVALID_HANDLE) {
        IndicatorRelease(adxHandle_Context);
        adxHandle_Context = INVALID_HANDLE;
    }

    Print("[Indicators] ADX Trend Monitor deinitialized");
}

//+------------------------------------------------------------------+
//| Get ADX Report                                                   |
//+------------------------------------------------------------------+
string GetADXReport() {
    if(!EnableADXMonitor) return "ADX Monitor Disabled";

    string arrow_Imm = GetTrendArrow(trendDirection_Immediate);
    string arrow_Ctx = GetTrendArrow(trendDirection_Context);

    string report = StringFormat(
        "\n═══════════════ ADX TREND REPORT ═══════════════\n" +
        "IMMEDIATE:\n" +
        "  ADX: %.1f | Rating: %d/9 | %s %s | %s\n" +
        "  +DI: %.1f | -DI: %.1f\n" +
        "CONTEXT:\n" +
        "  ADX: %.1f | Rating: %d/9 | %s %s | %s\n" +
        "  +DI: %.1f | -DI: %.1f\n" +
        "═════════════════════════════════════════════════",
        adxValue_Immediate, trendRating_Immediate,
        trendDirection_Immediate, arrow_Imm, trendStatus_Immediate,
        plusDI_Immediate, minusDI_Immediate,
        adxValue_Context, trendRating_Context,
        trendDirection_Context, arrow_Ctx, trendStatus_Context,
        plusDI_Context, minusDI_Context
    );

    return report;
}

//+------------------------------------------------------------------+
//| Check if Market is Good for Grid Neutral                         |
//| Returns true if ADX is low (ranging market)                      |
//+------------------------------------------------------------------+
bool IsMarketGoodForNeutral() {
    if(!EnableADXMonitor) return true;  // Assume good if monitor disabled

    // Mercato ideale per Grid Neutral: ADX basso (ranging)
    // Rating 1-3 = NO TREND = IDEALE
    // Rating 4-5 = FORMING/CONFIRMED = ATTENZIONE
    // Rating 6+ = STRONG/EXTREME = PERICOLO

    return (trendRating_Context <= 4);
}

//+------------------------------------------------------------------+
//| Get Market Condition for Dashboard                               |
//+------------------------------------------------------------------+
string GetMarketCondition() {
    if(!EnableADXMonitor) return "N/A";

    if(trendRating_Context <= 3) {
        return "RANGING";  // Ideale per Grid Neutral
    } else if(trendRating_Context <= 5) {
        return "MIXED";    // Attenzione
    } else {
        return "TRENDING"; // Pericolo per Grid Neutral
    }
}

//+------------------------------------------------------------------+
//| Get Market Condition Color                                       |
//+------------------------------------------------------------------+
color GetMarketConditionColor() {
    if(!EnableADXMonitor) return clrGray;

    if(trendRating_Context <= 3) {
        return C'0,200,200';    // Cyan - Ideale
    } else if(trendRating_Context <= 5) {
        return C'255,200,100';  // Giallo - Attenzione
    } else {
        return C'255,100,100';  // Rosso - Pericolo
    }
}

//+------------------------------------------------------------------+
//|                   ATR MULTI-TIMEFRAME SYSTEM v3.0                 |
//|                   Dashboard: M5, M15, H1, H4                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Global Variables for ATR Multi-Timeframe                         |
//+------------------------------------------------------------------+
int atrHandle_MTF[4];                   // Handles per i 4 TF
double atrValue_MTF[4];                 // Valori ATR
double atrPips_MTF[4];                  // ATR in pips
int atrRating_MTF[4];                   // Rating 1-9
string atrStatus_MTF[4];                // Status text
color atrColor_MTF[4];                  // Status color
ENUM_TIMEFRAMES atrTF_MTF[4];           // Timeframes

//+------------------------------------------------------------------+
//| Initialize ATR Multi-Timeframe                                   |
//+------------------------------------------------------------------+
bool InitializeATRMultiTF() {
    if(!Enable_ATRMultiTF) {
        Print("[Indicators] ATR Multi-TF is DISABLED");
        return true;
    }

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  INITIALIZING ATR MULTI-TIMEFRAME v3.0");
    Print("═══════════════════════════════════════════════════════════════════");

    // Store timeframes
    atrTF_MTF[0] = ATR_MTF_TF1;  // M5
    atrTF_MTF[1] = ATR_MTF_TF2;  // M15
    atrTF_MTF[2] = ATR_MTF_TF3;  // H1
    atrTF_MTF[3] = ATR_MTF_TF4;  // H4

    // Create handles for each timeframe
    for(int i = 0; i < 4; i++) {
        atrHandle_MTF[i] = iATR(_Symbol, atrTF_MTF[i], ATR_MTF_Period);

        if(atrHandle_MTF[i] == INVALID_HANDLE) {
            Print("[Indicators] ERROR: Failed to create ATR for TF: ", EnumToString(atrTF_MTF[i]));
            return false;
        }

        // Initialize values
        atrValue_MTF[i] = 0;
        atrPips_MTF[i] = 0;
        atrRating_MTF[i] = 0;
        atrStatus_MTF[i] = "INIT";
        atrColor_MTF[i] = clrGray;

        Print("[Indicators] SUCCESS: ATR ", GetTimeframeName(atrTF_MTF[i]),
              " initialized - Period: ", ATR_MTF_Period);
    }

    Print("═══════════════════════════════════════════════════════════════════");
    return true;
}

//+------------------------------------------------------------------+
//| Update ATR Multi-Timeframe                                       |
//+------------------------------------------------------------------+
void UpdateATRMultiTF() {
    if(!Enable_ATRMultiTF) return;

    // Throttle: update once per second
    static datetime lastUpdate = 0;
    datetime currentTime = TimeCurrent();

    if(currentTime == lastUpdate) return;
    lastUpdate = currentTime;

    // Update all 4 timeframes
    for(int i = 0; i < 4; i++) {
        UpdateSingleATRMTF(i);
    }
}

//+------------------------------------------------------------------+
//| Update Single ATR MTF                                            |
//+------------------------------------------------------------------+
void UpdateSingleATRMTF(int index) {
    if(atrHandle_MTF[index] == INVALID_HANDLE) return;

    double buffer[];
    ArraySetAsSeries(buffer, true);

    if(CopyBuffer(atrHandle_MTF[index], 0, 0, 1, buffer) <= 0) return;

    atrValue_MTF[index] = buffer[0];

    // Calculate in pips
    double pipSize = symbolPoint;
    if(symbolDigits == 3 || symbolDigits == 5) pipSize *= 10;
    atrPips_MTF[index] = atrValue_MTF[index] / pipSize;

    // Calculate rating based on ATR pips
    atrRating_MTF[index] = CalculateATRRatingMTF(atrPips_MTF[index]);

    // Determine status and color
    DetermineATRStatusMTF(atrRating_MTF[index], atrStatus_MTF[index], atrColor_MTF[index]);
}

//+------------------------------------------------------------------+
//| Calculate ATR Rating for MTF (1-9 scale based on pips)           |
//+------------------------------------------------------------------+
int CalculateATRRatingMTF(double atrPips) {
    // Rating basato su ATR in pips
    // Adattato per EUR/USD e coppie simili
    if(atrPips < 5)  return 1;   // Molto calmo
    if(atrPips < 10) return 2;   // Calmo
    if(atrPips < 15) return 3;   // Basso
    if(atrPips < 20) return 4;   // Sotto media
    if(atrPips < 30) return 5;   // Normale
    if(atrPips < 40) return 6;   // Sopra media
    if(atrPips < 50) return 7;   // Volatile
    if(atrPips < 70) return 8;   // Molto volatile
    return 9;                     // Estremo
}

//+------------------------------------------------------------------+
//| Determine ATR Status for MTF                                     |
//+------------------------------------------------------------------+
void DetermineATRStatusMTF(int rating, string &status, color &statusColor) {
    switch(rating) {
        case 1:
        case 2:
            status = "CALM";
            statusColor = C'0,180,180';      // Teal
            break;
        case 3:
        case 4:
            status = "LOW";
            statusColor = C'100,200,255';    // Azure
            break;
        case 5:
            status = "NORMAL";
            statusColor = C'100,255,100';    // Green
            break;
        case 6:
            status = "ELEVATED";
            statusColor = C'255,255,100';    // Yellow
            break;
        case 7:
            status = "HIGH";
            statusColor = C'255,180,80';     // Orange
            break;
        case 8:
        case 9:
            status = "EXTREME";
            statusColor = C'255,80,80';      // Red
            break;
        default:
            status = "N/A";
            statusColor = clrGray;
    }
}

//+------------------------------------------------------------------+
//| Get ATR Multi-TF Data for Dashboard                              |
//+------------------------------------------------------------------+
void GetATRMultiTFData(int index, string &tfName, double &atrPips,
                       int &rating, string &status, color &statusColor) {
    if(index < 0 || index >= 4) {
        tfName = "N/A";
        atrPips = 0;
        rating = 0;
        status = "N/A";
        statusColor = clrGray;
        return;
    }

    tfName = GetTimeframeName(atrTF_MTF[index]);
    atrPips = atrPips_MTF[index];
    rating = atrRating_MTF[index];
    status = atrStatus_MTF[index];
    statusColor = atrColor_MTF[index];
}

//+------------------------------------------------------------------+
//| Get ATR Average Rating (for overall assessment)                  |
//+------------------------------------------------------------------+
int GetATRMultiTFAverageRating() {
    if(!Enable_ATRMultiTF) return 5; // Default neutral

    int sum = 0;
    for(int i = 0; i < 4; i++) {
        sum += atrRating_MTF[i];
    }
    return sum / 4;
}

//+------------------------------------------------------------------+
//| Get ATR Multi-TF Consensus                                       |
//+------------------------------------------------------------------+
string GetATRMultiTFConsensus() {
    if(!Enable_ATRMultiTF) return "N/A";

    int avgRating = GetATRMultiTFAverageRating();

    if(avgRating <= 3) return "RANGING MARKET";
    if(avgRating <= 5) return "NORMAL CONDITIONS";
    if(avgRating <= 7) return "VOLATILE MARKET";
    return "EXTREME VOLATILITY";
}

//+------------------------------------------------------------------+
//| Get ATR Multi-TF Report                                          |
//+------------------------------------------------------------------+
string GetATRMultiTFReport() {
    if(!Enable_ATRMultiTF) return "ATR Multi-TF Disabled";

    string report = "\n═══════════════ ATR MULTI-TIMEFRAME ═══════════════\n";

    for(int i = 0; i < 4; i++) {
        report += StringFormat("  %s: %.1f pips | Rating: %d/9 | %s\n",
                              GetTimeframeName(atrTF_MTF[i]),
                              atrPips_MTF[i],
                              atrRating_MTF[i],
                              atrStatus_MTF[i]);
    }

    report += "─────────────────────────────────────────────────────\n";
    report += StringFormat("  CONSENSUS: %s (Avg: %d/9)\n",
                          GetATRMultiTFConsensus(),
                          GetATRMultiTFAverageRating());
    report += "═════════════════════════════════════════════════════";

    return report;
}

//+------------------------------------------------------------------+
//| Deinitialize ATR Multi-Timeframe                                 |
//+------------------------------------------------------------------+
void DeinitializeATRMultiTF() {
    for(int i = 0; i < 4; i++) {
        if(atrHandle_MTF[i] != INVALID_HANDLE) {
            IndicatorRelease(atrHandle_MTF[i]);
            atrHandle_MTF[i] = INVALID_HANDLE;
        }
    }
    Print("[Indicators] ATR Multi-TF deinitialized");
}

