//+------------------------------------------------------------------+
//|                                          GlobalVariables.mqh     |
//|                        Sugamara - Global Variables               |
//|                                                                  |
//|  All global variables for Double Grid Neutral System             |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

#include <Trade\Trade.mqh>

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
//| HEDGING VARIABLES (Legacy - Solo per NEUTRAL_RANGEBOX)           |
//+------------------------------------------------------------------+
ENUM_HEDGE_DIRECTION currentHedgeDirection = HEDGE_NONE;  // Direzione hedge attivo
ulong hedgeLongTicket = 0;                  // Ticket ordine hedge LONG
ulong hedgeShortTicket = 0;                 // Ticket ordine hedge SHORT
double hedgeLotSize = 0;                    // Lot size hedge corrente
datetime hedgeOpenTime = 0;                 // Tempo apertura hedge
double hedgeEntryPrice = 0;                 // Prezzo entry hedge

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
    for(int i = 0; i < 10; i++) gridA_Upper_Status[i] = ORDER_NONE;

    // Grid A Lower
    ArrayInitialize(gridA_Lower_Tickets, 0);
    ArrayInitialize(gridA_Lower_EntryPrices, 0);
    ArrayInitialize(gridA_Lower_Lots, 0);
    ArrayInitialize(gridA_Lower_TP, 0);
    ArrayInitialize(gridA_Lower_SL, 0);
    ArrayInitialize(gridA_Lower_LastClose, 0);
    ArrayInitialize(gridA_Lower_Cycles, 0);
    for(int i = 0; i < 10; i++) gridA_Lower_Status[i] = ORDER_NONE;

    // Grid B Upper
    ArrayInitialize(gridB_Upper_Tickets, 0);
    ArrayInitialize(gridB_Upper_EntryPrices, 0);
    ArrayInitialize(gridB_Upper_Lots, 0);
    ArrayInitialize(gridB_Upper_TP, 0);
    ArrayInitialize(gridB_Upper_SL, 0);
    ArrayInitialize(gridB_Upper_LastClose, 0);
    ArrayInitialize(gridB_Upper_Cycles, 0);
    for(int i = 0; i < 10; i++) gridB_Upper_Status[i] = ORDER_NONE;

    // Grid B Lower
    ArrayInitialize(gridB_Lower_Tickets, 0);
    ArrayInitialize(gridB_Lower_EntryPrices, 0);
    ArrayInitialize(gridB_Lower_Lots, 0);
    ArrayInitialize(gridB_Lower_TP, 0);
    ArrayInitialize(gridB_Lower_SL, 0);
    ArrayInitialize(gridB_Lower_LastClose, 0);
    ArrayInitialize(gridB_Lower_Cycles, 0);
    for(int i = 0; i < 10; i++) gridB_Lower_Status[i] = ORDER_NONE;

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

    Print("SUCCESS: All grid arrays and Shield initialized");
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

