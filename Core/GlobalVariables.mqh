//+------------------------------------------------------------------+
//|                                          GlobalVariables.mqh     |
//|                        Sugamara - Global Variables               |
//|                                                                  |
//|  All global variables for Double Grid Neutral System             |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| TRADE OBJECT                                                     |
//+------------------------------------------------------------------+
CTrade trade;

//+------------------------------------------------------------------+
//| SYSTEM STATE                                                     |
//+------------------------------------------------------------------+
ENUM_SYSTEM_STATE systemState = STATE_IDLE;     // Stato sistema (usato ovunque)
bool systemActive = false;
datetime systemStartTime = 0;
datetime lastTickTime = 0;

//+------------------------------------------------------------------+
//| ENTRY POINT                                                      |
//+------------------------------------------------------------------+
double entryPoint = 0;                      // Prezzo centrale del sistema
datetime entryPointTime = 0;                // Quando e stato impostato entry point

//+------------------------------------------------------------------+
//| BROKER SPECIFICATIONS                                            |
//+------------------------------------------------------------------+
int symbolStopsLevel = 0;                   // SYMBOL_TRADE_STOPS_LEVEL
int symbolFreezeLevel = 0;                  // SYMBOL_TRADE_FREEZE_LEVEL
double symbolMinLot = 0;                    // SYMBOL_VOLUME_MIN
double symbolMaxLot = 0;                    // SYMBOL_VOLUME_MAX
double symbolLotStep = 0;                   // SYMBOL_VOLUME_STEP
long symbolSpreadPoints = 0;                // Spread corrente in points (long per SymbolInfoInteger)
double symbolPoint = 0;                     // SYMBOL_POINT
int symbolDigits = 0;                       // SYMBOL_DIGITS

//+------------------------------------------------------------------+
//| ATR & VOLATILITY                                                 |
//+------------------------------------------------------------------+
int atrHandle = INVALID_HANDLE;             // Handle indicatore ATR
double currentATR_Pips = 0;                 // ATR corrente in pips
double lastATRValue = 0;                    // ATR precedente (per confronto)
ENUM_ATR_CONDITION currentATR_Condition = ATR_NORMAL;  // Condizione volatilita
datetime lastATRRecalc = 0;                 // Ultimo ricalcolo ATR
double currentSpacing_Pips = 0;             // Spacing corrente calcolato da ATR

//+------------------------------------------------------------------+
//| 🔄 ATR DYNAMIC SPACING v4.0                                      |
//+------------------------------------------------------------------+
ENUM_ATR_STEP   currentATRStep = ATR_STEP_NORMAL;      // Step ATR corrente (5 livelli)
ENUM_ATR_STEP   lastATRStep = ATR_STEP_NORMAL;         // Step ATR precedente
double          lastATRValue_Dynamic = 0;               // Ultimo valore ATR per dynamic
datetime        lastATRCheck_Dynamic = 0;               // Ultimo check ATR dynamic
datetime        lastSpacingChange = 0;                  // Ultimo cambio spacing
double          previousSpacing_Pips = 0;               // Spacing precedente
bool            spacingChangeInProgress = false;        // Flag: cambio in corso

// Rate Limiting state (v4.6)
double          lastAppliedSpacing_Pips = 0;            // Ultimo spacing effettivamente applicato
datetime        lastRateLimitedChange = 0;              // Timestamp ultimo cambio rate-limited

//+------------------------------------------------------------------+
//| 📦 ATR UNIFIED CACHE v4.1 - Single Source of Truth               |
//+------------------------------------------------------------------+
struct ATRCacheStruct {
    double valuePips;                                   // Valore ATR in pips
    ENUM_ATR_STEP step;                                 // Step corrente
    datetime lastFullUpdate;                            // Ultimo aggiornamento completo
    datetime lastBarTime;                               // Tempo ultima candela usata
    bool isValid;                                       // Cache valida
};
ATRCacheStruct g_atrCache;

//+------------------------------------------------------------------+
//| ⚠️ ATR EXTREME WARNING v4.1                                      |
//+------------------------------------------------------------------+
bool            g_extremePauseActive = false;           // Flag: pausa per ATR extreme attiva
datetime        g_lastExtremeCheck = 0;                 // Ultimo check extreme

//+------------------------------------------------------------------+
//| 📝 ATR LOGGING STATE v4.2                                        |
//+------------------------------------------------------------------+
int             g_atrStepChangeCount = 0;               // Contatore cambi step sessione
int             g_spacingChangeCount = 0;               // Contatore cambi spacing sessione
datetime        g_lastLoggedATRChange = 0;              // Ultimo log ATR
string          g_lastATRStepName = "";                 // Nome ultimo step loggato

//+------------------------------------------------------------------+
//| 🎯 CENTER CALCULATOR v4.0                                        |
//+------------------------------------------------------------------+
// Pivot Point Daily
struct PivotLevels {
    double pivot;                           // Pivot centrale
    double r1, r2, r3;                      // Resistenze
    double s1, s2, s3;                      // Supporti
    datetime calcTime;                      // Timestamp calcolo
    bool isValid;
};
PivotLevels g_pivotLevels;

// Donchian Channel
struct DonchianLevels {
    double upper;                           // Upper band (Highest High)
    double lower;                           // Lower band (Lowest Low)
    double center;                          // Centro (Upper + Lower) / 2
    datetime calcTime;
    bool isValid;
};
DonchianLevels g_donchianLevels;

// Center Calculation Result
struct CenterCalculation {
    double pivotCenter;                     // Valore Pivot
    double emaCenter;                       // Valore EMA
    double donchianCenter;                  // Valore Donchian Center
    double optimalCenter;                   // Centro ponderato finale
    double confidence;                      // 0-100% (quanto i 3 indicatori sono allineati)
    datetime calcTime;
    bool isValid;
};
CenterCalculation g_centerCalc;

// Center Indicator Handles
int g_emaHandle = INVALID_HANDLE;           // Handle EMA indicator
datetime g_lastPivotCalcDay = 0;            // Giorno ultimo calcolo pivot
datetime g_lastCenterCalc = 0;              // Ultimo calcolo centro

//+------------------------------------------------------------------+
//| 🔄 AUTO-RECENTER v4.0                                            |
//+------------------------------------------------------------------+
datetime        g_lastRecenterTime = 0;     // Timestamp ultimo recenter
datetime        g_lastRecenterCheck = 0;    // Ultimo check recenter
int             g_recenterCount = 0;        // Contatore recenter sessione
bool            g_recenterPending = false;  // Flag: recenter in attesa conferma

//+------------------------------------------------------------------+
//| GRID STRUCTURE                                                   |
//| Ogni array ha dimensione [MAX_GRID_LEVELS] = 10 elementi         |
//| Indice 0 = Level 1 (piu vicino a entry)                          |
//| Indice 9 = Level 10 (piu lontano da entry)                       |
//+------------------------------------------------------------------+

// ═══════════════════════════════════════════════════════════════════
// GRID A - Long Bias (Buy Limit sopra, Sell Stop sotto)
// ═══════════════════════════════════════════════════════════════════

// Upper Zone (sopra Entry Point) - Buy Limit orders
ulong gridA_Upper_Tickets[10];              // Ticket ordini pending
double gridA_Upper_EntryPrices[10];         // Prezzi entry calcolati
double gridA_Upper_Lots[10];                // Lot size per livello
double gridA_Upper_TP[10];                  // Take Profit (Cascade)
double gridA_Upper_SL[10];                  // Stop Loss
ENUM_ORDER_STATUS gridA_Upper_Status[10];   // Stato ordine
datetime gridA_Upper_LastClose[10];         // Tempo ultima chiusura (per cyclic)
int gridA_Upper_Cycles[10];                 // Contatore cicli

// Lower Zone (sotto Entry Point) - Sell Stop orders
ulong gridA_Lower_Tickets[10];
double gridA_Lower_EntryPrices[10];
double gridA_Lower_Lots[10];
double gridA_Lower_TP[10];
double gridA_Lower_SL[10];
ENUM_ORDER_STATUS gridA_Lower_Status[10];
datetime gridA_Lower_LastClose[10];
int gridA_Lower_Cycles[10];

// ═══════════════════════════════════════════════════════════════════
// GRID B - Short Bias (Sell Limit sopra, Buy Stop sotto)
// ═══════════════════════════════════════════════════════════════════

// Upper Zone (sopra Entry Point) - Sell Limit orders
ulong gridB_Upper_Tickets[10];
double gridB_Upper_EntryPrices[10];
double gridB_Upper_Lots[10];
double gridB_Upper_TP[10];
double gridB_Upper_SL[10];
ENUM_ORDER_STATUS gridB_Upper_Status[10];
datetime gridB_Upper_LastClose[10];
int gridB_Upper_Cycles[10];

// Lower Zone (sotto Entry Point) - Buy Stop orders
ulong gridB_Lower_Tickets[10];
double gridB_Lower_EntryPrices[10];
double gridB_Lower_Lots[10];
double gridB_Lower_TP[10];
double gridB_Lower_SL[10];
ENUM_ORDER_STATUS gridB_Lower_Status[10];
datetime gridB_Lower_LastClose[10];
int gridB_Lower_Cycles[10];

//+------------------------------------------------------------------+
//| NET EXPOSURE                                                     |
//+------------------------------------------------------------------+
double totalLongLots = 0;                   // Totale lotti LONG aperti
double totalShortLots = 0;                  // Totale lotti SHORT aperti
double netExposure = 0;                     // Esposizione netta (LONG - SHORT)
bool isNeutral = true;                      // Flag: sistema in equilibrio

//+------------------------------------------------------------------+
//| RANGE BOUNDARIES                                                 |
//+------------------------------------------------------------------+
double rangeUpperBound = 0;                 // Limite superiore range
double rangeLowerBound = 0;                 // Limite inferiore range
double totalRangePips = 0;                  // Range totale in pips

//+------------------------------------------------------------------+
//| RANGEBOX VARIABLES (Solo per NEUTRAL_RANGEBOX)                   |
//+------------------------------------------------------------------+
double rangeBox_Resistance = 0;             // Resistance calcolata/manuale
double rangeBox_Support = 0;                // Support calcolata/manuale
datetime rangeBox_LastCalc = 0;             // Ultimo calcolo Range Box
bool isBreakoutUp = false;                  // Flag breakout sopra resistance
bool isBreakoutDown = false;                // Flag breakout sotto support
bool isInsideRange = true;                  // Flag prezzo dentro range

//+------------------------------------------------------------------+
//| 🛡️ SHIELD INTELLIGENTE STRUCTURE                                 |
//+------------------------------------------------------------------+
struct ShieldData {
    bool isActive;                          // Shield attivo
    ENUM_SHIELD_TYPE type;                  // Tipo (LONG/SHORT)
    ENUM_SHIELD_PHASE phase;                // Fase corrente (per 3 fasi)
    ulong ticket;                           // Ticket posizione shield
    double lot_size;                        // Lot size shield
    double entry_price;                     // Prezzo entry
    double current_pl;                      // P/L corrente
    double trailing_sl;                     // Trailing SL (se attivo)
    datetime activation_time;               // Tempo attivazione
    int activation_count;                   // Contatore attivazioni
};

ShieldData shield;

// Shield Statistics
int totalShieldActivations = 0;
double totalShieldPL = 0;
datetime lastShieldClosure = 0;

//+------------------------------------------------------------------+
//| 📦 RANGEBOX DATA STRUCTURE                                       |
//+------------------------------------------------------------------+
struct RangeBoxData {
    double resistance;                      // Livello Resistance
    double support;                         // Livello Support
    double center;                          // Centro range
    double rangeHeight;                     // Altezza range (pips)
    double warningZoneUp;                   // Zona warning superiore
    double warningZoneDown;                 // Zona warning inferiore
    bool isValid;                           // Range valido
    datetime lastCalc;                      // Ultimo calcolo
};

RangeBoxData rangeBox;

// Breakout Levels (calcolati da ultimo livello grid)
double upperBreakoutLevel = 0;
double lowerBreakoutLevel = 0;
double upperReentryLevel = 0;
double lowerReentryLevel = 0;

// Breakout Detection
int breakoutConfirmCounter = 0;
datetime breakoutDetectionTime = 0;
ENUM_BREAKOUT_DIRECTION lastBreakoutDirection = BREAKOUT_NONE;

//+------------------------------------------------------------------+
//| CURRENT SYSTEM STATE (Extended)                                  |
//+------------------------------------------------------------------+
ENUM_SYSTEM_STATE currentSystemState = STATE_INIT;

//+------------------------------------------------------------------+
//| RISK MANAGEMENT VARIABLES                                        |
//+------------------------------------------------------------------+
double startingEquity = 0;                  // Equity iniziale sessione
double startingBalance = 0;                 // Balance iniziale sessione
double maxEquityReached = 0;                // Picco equity raggiunto
double maxDrawdownReached = 0;              // Max drawdown registrato
bool isDailyTargetReached = false;          // Flag target giornaliero
bool isDailyLossLimitReached = false;       // Flag loss limit giornaliero
bool isNewsPause = false;                   // Flag pausa news manuale

//+------------------------------------------------------------------+
//| 💰 RISK-BASED LOT CALCULATION VARIABLES                          |
//+------------------------------------------------------------------+
double riskBasedBaseLot = 0;                // Lot base calcolato da rischio
double riskBasedMultiplier = 1.0;           // Moltiplicatore risk-based (usa LotMultiplier)
double maxTheoreticalDrawdown = 0;          // DD teorico massimo calcolato
double currentRealizedRisk = 0;             // Rischio realizzato corrente ($)
bool riskBasedLotsCalculated = false;       // Flag: lot gia calcolati

//+------------------------------------------------------------------+
//| SESSION STATISTICS                                               |
//+------------------------------------------------------------------+
double sessionRealizedProfit = 0;           // Profitto realizzato sessione
double sessionPeakProfit = 0;               // Picco profitto sessione
double sessionGrossProfit = 0;              // Profitto lordo (solo wins)
double sessionGrossLoss = 0;                // Perdita lorda (solo losses)
int sessionWins = 0;                        // Trades vincenti sessione
int sessionLosses = 0;                      // Trades perdenti sessione
int totalTrades = 0;                        // Trades totali

//+------------------------------------------------------------------+
//| DAILY STATISTICS                                                 |
//+------------------------------------------------------------------+
double dailyRealizedProfit = 0;             // Profitto giornaliero realizzato
double dailyPeakEquity = 0;                 // Picco equity giornaliero
int dailyWins = 0;                          // Wins giornalieri
int dailyLosses = 0;                        // Losses giornalieri

//+------------------------------------------------------------------+
//| 💵 CLOSE ON PROFIT (COP) v5.1                                    |
//+------------------------------------------------------------------+
double cop_RealizedProfit = 0.0;            // Profitto realizzato oggi (COP)
double cop_FloatingProfit = 0.0;            // Floating P/L corrente (COP)
double cop_TotalCommissions = 0.0;          // Commissioni totali oggi (COP)
double cop_NetProfit = 0.0;                 // Net Profit = Realized + Floating - Commissions
bool   cop_TargetReached = false;           // Flag: target giornaliero raggiunto
datetime cop_LastResetDate = 0;             // Data ultimo reset (per daily reset)
int    cop_TradesToday = 0;                 // Numero trades oggi (per commissioni)
double cop_TotalLotsToday = 0.0;            // Lotti totali tradati oggi (per commissioni)

//+------------------------------------------------------------------+
//| Initialize All Arrays                                            |
//| Call in OnInit() after variable declarations                     |
//+------------------------------------------------------------------+
void InitializeArrays() {
    // Grid A Upper
    ArrayInitialize(gridA_Upper_Tickets, 0);
    ArrayInitialize(gridA_Upper_EntryPrices, 0);
    ArrayInitialize(gridA_Upper_Lots, 0);
    ArrayInitialize(gridA_Upper_TP, 0);
    ArrayInitialize(gridA_Upper_SL, 0);
    ArrayInitialize(gridA_Upper_LastClose, 0);
    ArrayInitialize(gridA_Upper_Cycles, 0);
    for(int i = 0; i < MAX_GRID_LEVELS; i++) gridA_Upper_Status[i] = ORDER_NONE;  // FIX v4.5

    // Grid A Lower
    ArrayInitialize(gridA_Lower_Tickets, 0);
    ArrayInitialize(gridA_Lower_EntryPrices, 0);
    ArrayInitialize(gridA_Lower_Lots, 0);
    ArrayInitialize(gridA_Lower_TP, 0);
    ArrayInitialize(gridA_Lower_SL, 0);
    ArrayInitialize(gridA_Lower_LastClose, 0);
    ArrayInitialize(gridA_Lower_Cycles, 0);
    for(int i = 0; i < MAX_GRID_LEVELS; i++) gridA_Lower_Status[i] = ORDER_NONE;  // FIX v4.5

    // Grid B Upper
    ArrayInitialize(gridB_Upper_Tickets, 0);
    ArrayInitialize(gridB_Upper_EntryPrices, 0);
    ArrayInitialize(gridB_Upper_Lots, 0);
    ArrayInitialize(gridB_Upper_TP, 0);
    ArrayInitialize(gridB_Upper_SL, 0);
    ArrayInitialize(gridB_Upper_LastClose, 0);
    ArrayInitialize(gridB_Upper_Cycles, 0);
    for(int i = 0; i < MAX_GRID_LEVELS; i++) gridB_Upper_Status[i] = ORDER_NONE;  // FIX v4.5

    // Grid B Lower
    ArrayInitialize(gridB_Lower_Tickets, 0);
    ArrayInitialize(gridB_Lower_EntryPrices, 0);
    ArrayInitialize(gridB_Lower_Lots, 0);
    ArrayInitialize(gridB_Lower_TP, 0);
    ArrayInitialize(gridB_Lower_SL, 0);
    ArrayInitialize(gridB_Lower_LastClose, 0);
    ArrayInitialize(gridB_Lower_Cycles, 0);
    for(int i = 0; i < MAX_GRID_LEVELS; i++) gridB_Lower_Status[i] = ORDER_NONE;  // FIX v4.5

    // Initialize Shield Structure
    ZeroMemory(shield);
    shield.isActive = false;
    shield.type = SHIELD_NONE;
    shield.phase = PHASE_NORMAL;
    shield.ticket = 0;
    shield.lot_size = 0;
    shield.entry_price = 0;
    shield.current_pl = 0;
    shield.trailing_sl = 0;
    shield.activation_time = 0;
    shield.activation_count = 0;

    // Initialize RangeBox Structure
    ZeroMemory(rangeBox);
    rangeBox.resistance = 0;
    rangeBox.support = 0;
    rangeBox.center = 0;
    rangeBox.rangeHeight = 0;
    rangeBox.warningZoneUp = 0;
    rangeBox.warningZoneDown = 0;
    rangeBox.isValid = false;
    rangeBox.lastCalc = 0;

    // Reset breakout levels
    upperBreakoutLevel = 0;
    lowerBreakoutLevel = 0;
    upperReentryLevel = 0;
    lowerReentryLevel = 0;
    breakoutConfirmCounter = 0;
    breakoutDetectionTime = 0;
    lastBreakoutDirection = BREAKOUT_NONE;

    // ═══════════════════════════════════════════════════════════════════
    // v4.0: Initialize ATR Dynamic Spacing
    // ═══════════════════════════════════════════════════════════════════
    currentATRStep = ATR_STEP_NORMAL;
    lastATRStep = ATR_STEP_NORMAL;
    lastATRValue_Dynamic = 0;
    lastATRCheck_Dynamic = 0;
    lastSpacingChange = 0;
    previousSpacing_Pips = 0;
    spacingChangeInProgress = false;

    // ═══════════════════════════════════════════════════════════════════
    // v4.1: Initialize ATR Unified Cache
    // ═══════════════════════════════════════════════════════════════════
    ZeroMemory(g_atrCache);
    g_atrCache.valuePips = 0;
    g_atrCache.step = ATR_STEP_NORMAL;
    g_atrCache.lastFullUpdate = 0;
    g_atrCache.lastBarTime = 0;
    g_atrCache.isValid = false;

    // v4.1: Extreme Warning
    g_extremePauseActive = false;
    g_lastExtremeCheck = 0;

    // ═══════════════════════════════════════════════════════════════════
    // v4.2: Initialize ATR Logging State
    // ═══════════════════════════════════════════════════════════════════
    g_atrStepChangeCount = 0;
    g_spacingChangeCount = 0;
    g_lastLoggedATRChange = 0;
    g_lastATRStepName = "";

    // ═══════════════════════════════════════════════════════════════════
    // v4.0: Initialize Center Calculator Structures
    // ═══════════════════════════════════════════════════════════════════
    ZeroMemory(g_pivotLevels);
    g_pivotLevels.isValid = false;

    ZeroMemory(g_donchianLevels);
    g_donchianLevels.isValid = false;

    ZeroMemory(g_centerCalc);
    g_centerCalc.isValid = false;

    g_lastPivotCalcDay = 0;
    g_lastCenterCalc = 0;

    // ═══════════════════════════════════════════════════════════════════
    // v4.0: Initialize Auto-Recenter
    // ═══════════════════════════════════════════════════════════════════
    g_lastRecenterTime = 0;
    g_lastRecenterCheck = 0;
    g_recenterCount = 0;
    g_recenterPending = false;

    Print("SUCCESS: All grid arrays, Shield, and v4.0 modules initialized");
}

//+------------------------------------------------------------------+
//| Reset Grid Arrays (for system restart)                           |
//+------------------------------------------------------------------+
void ResetGridArrays() {
    InitializeArrays();

    // Reset exposure
    totalLongLots = 0;
    totalShortLots = 0;
    netExposure = 0;
    isNeutral = true;

    Print("SUCCESS: Grid arrays reset for new session");
}

//+------------------------------------------------------------------+
//| Calculate Net Exposure                                           |
//+------------------------------------------------------------------+
void CalculateNetExposure() {
    totalLongLots = 0;
    totalShortLots = 0;

    // Grid A Upper (Buy Limit -> LONG when filled)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Status[i] == ORDER_FILLED) {
            totalLongLots += gridA_Upper_Lots[i];
        }
    }

    // Grid A Lower (Sell Stop -> SHORT when filled)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Lower_Status[i] == ORDER_FILLED) {
            totalShortLots += gridA_Lower_Lots[i];
        }
    }

    // Grid B Upper (Sell Limit -> SHORT when filled)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Status[i] == ORDER_FILLED) {
            totalShortLots += gridB_Upper_Lots[i];
        }
    }

    // Grid B Lower (Buy Stop -> LONG when filled)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Lower_Status[i] == ORDER_FILLED) {
            totalLongLots += gridB_Lower_Lots[i];
        }
    }

    // Calculate net
    netExposure = totalLongLots - totalShortLots;
    isNeutral = (MathAbs(netExposure) < NetExposure_MaxLot);

    if(!isNeutral && DetailedLogging) {
        Print("WARNING: Net exposure ", DoubleToString(netExposure, 2),
              " lot exceeds threshold ", NetExposure_MaxLot);
    }
}

