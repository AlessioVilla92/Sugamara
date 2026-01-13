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
//| 📦 ATR CACHE v5.8 - For monitoring only (no spacing logic)       |
//+------------------------------------------------------------------+
struct ATRCacheStruct {
    double valuePips;                                   // Valore ATR in pips
    datetime lastFullUpdate;                            // Ultimo aggiornamento
    datetime lastBarTime;                               // Tempo ultima candela usata
    bool isValid;                                       // Cache valida
};
ATRCacheStruct g_atrCache;
datetime        g_lastLoggedATRChange = 0;              // Ultimo log ATR
string          g_lastATRStepName = "";                 // Nome ultimo step loggato

//+------------------------------------------------------------------+
//| 📊 GRID COUNTER v5.9.3 - Track closed vs pending grids           |
//+------------------------------------------------------------------+
int g_gridA_ClosedCount = 0;                 // Grid A chiuse (TP hit)
int g_gridA_PendingCount = 0;                // Grid A pending inserite
int g_gridB_ClosedCount = 0;                 // Grid B chiuse (TP hit)
int g_gridB_PendingCount = 0;                // Grid B pending inserite

// v9.0: Tracking separato LIMIT/STOP per Grid A e B (Dashboard)
int g_gridA_LimitFilled = 0;                 // Grid A LIMIT filled
int g_gridA_LimitCycles = 0;                 // Grid A LIMIT cycles completati
int g_gridA_LimitReopens = 0;                // Grid A LIMIT reopens
int g_gridA_StopFilled = 0;                  // Grid A STOP filled
int g_gridA_StopCycles = 0;                  // Grid A STOP cycles completati
int g_gridA_StopReopens = 0;                 // Grid A STOP reopens
int g_gridB_LimitFilled = 0;                 // Grid B LIMIT filled
int g_gridB_LimitCycles = 0;                 // Grid B LIMIT cycles completati
int g_gridB_LimitReopens = 0;                // Grid B LIMIT reopens
int g_gridB_StopFilled = 0;                  // Grid B STOP filled
int g_gridB_StopCycles = 0;                  // Grid B STOP cycles completati
int g_gridB_StopReopens = 0;                 // Grid B STOP reopens

//+------------------------------------------------------------------+
//| GRID STRUCTURE                                                   |
//| Ogni array ha dimensione [MAX_GRID_LEVELS] elementi              |
//| Indice 0 = Level 1 (piu vicino a entry)                          |
//| v9.0: Esteso da [15] a [20], ora usa costante MAX_GRID_LEVELS    |
//+------------------------------------------------------------------+

// ═══════════════════════════════════════════════════════════════════
// GRID A - Long Bias (Buy Limit sopra, Sell Stop sotto)
// ═══════════════════════════════════════════════════════════════════

// Upper Zone (sopra Entry Point) - Buy Limit orders
ulong gridA_Upper_Tickets[MAX_GRID_LEVELS];              // Ticket ordini pending
double gridA_Upper_EntryPrices[MAX_GRID_LEVELS];         // Prezzi entry calcolati
double gridA_Upper_Lots[MAX_GRID_LEVELS];                // Lot size per livello
double gridA_Upper_TP[MAX_GRID_LEVELS];                  // Take Profit (Cascade)
double gridA_Upper_SL[MAX_GRID_LEVELS];                  // Stop Loss
ENUM_ORDER_STATUS gridA_Upper_Status[MAX_GRID_LEVELS];   // Stato ordine
datetime gridA_Upper_LastClose[MAX_GRID_LEVELS];         // Tempo ultima chiusura (per cyclic)
int gridA_Upper_Cycles[MAX_GRID_LEVELS];                 // Contatore cicli

// Lower Zone (sotto Entry Point) - Sell Stop orders
ulong gridA_Lower_Tickets[MAX_GRID_LEVELS];
double gridA_Lower_EntryPrices[MAX_GRID_LEVELS];
double gridA_Lower_Lots[MAX_GRID_LEVELS];
double gridA_Lower_TP[MAX_GRID_LEVELS];
double gridA_Lower_SL[MAX_GRID_LEVELS];
ENUM_ORDER_STATUS gridA_Lower_Status[MAX_GRID_LEVELS];
datetime gridA_Lower_LastClose[MAX_GRID_LEVELS];
int gridA_Lower_Cycles[MAX_GRID_LEVELS];

// ═══════════════════════════════════════════════════════════════════
// GRID B - Short Bias (Sell Limit sopra, Buy Stop sotto)
// ═══════════════════════════════════════════════════════════════════

// Upper Zone (sopra Entry Point) - Sell Limit orders
ulong gridB_Upper_Tickets[MAX_GRID_LEVELS];
double gridB_Upper_EntryPrices[MAX_GRID_LEVELS];
double gridB_Upper_Lots[MAX_GRID_LEVELS];
double gridB_Upper_TP[MAX_GRID_LEVELS];
double gridB_Upper_SL[MAX_GRID_LEVELS];
ENUM_ORDER_STATUS gridB_Upper_Status[MAX_GRID_LEVELS];
datetime gridB_Upper_LastClose[MAX_GRID_LEVELS];
int gridB_Upper_Cycles[MAX_GRID_LEVELS];

// Lower Zone (sotto Entry Point) - Buy Stop orders
ulong gridB_Lower_Tickets[MAX_GRID_LEVELS];
double gridB_Lower_EntryPrices[MAX_GRID_LEVELS];
double gridB_Lower_Lots[MAX_GRID_LEVELS];
double gridB_Lower_TP[MAX_GRID_LEVELS];
double gridB_Lower_SL[MAX_GRID_LEVELS];
ENUM_ORDER_STATUS gridB_Lower_Status[MAX_GRID_LEVELS];
datetime gridB_Lower_LastClose[MAX_GRID_LEVELS];
int gridB_Lower_Cycles[MAX_GRID_LEVELS];

//+------------------------------------------------------------------+
//| NET EXPOSURE                                                     |
//+------------------------------------------------------------------+
double totalLongLots = 0;                   // Totale lotti LONG aperti
double totalShortLots = 0;                  // Totale lotti SHORT aperti
double netExposure = 0;                     // Esposizione netta (LONG - SHORT)
bool isNeutral = true;                      // Flag: sistema in equilibrio

// v9.12: Range boundaries, Shield, currentSystemState REMOVED

//+------------------------------------------------------------------+
//| RISK MANAGEMENT VARIABLES                                        |
//+------------------------------------------------------------------+
double startingEquity = 0;                  // Equity iniziale sessione
double startingBalance = 0;                 // Balance iniziale sessione
double maxEquityReached = 0;                // Picco equity raggiunto
double maxDrawdownReached = 0;              // Max drawdown registrato
// v9.11: Removed isDailyTargetReached, isDailyLossLimitReached, isNewsPause

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
//| v9.18: REOPEN CYCLE MONITOR TRACKING                             |
//+------------------------------------------------------------------+
#define MAX_LAST_REOPENS 3                     // Max elementi nell'array ultimi reopen
string g_lastReopens[MAX_LAST_REOPENS];        // Array ultimi reopen (format: "HH:MM GA_U_03 BUY STOP Ciclo 2")
int g_lastReopensCount = 0;                    // Contatore reopen registrati

// v9.22: AUTO-SAVE TRACKING moved to StatePersistence.mqh
// g_lastAutoSaveTime and g_lastAutoSaveSuccess are defined there

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

    // Shield initialization REMOVED in v9.12

    // ═══════════════════════════════════════════════════════════════════
    // v5.8: Initialize ATR Cache (monitoring only)
    // ═══════════════════════════════════════════════════════════════════
    ZeroMemory(g_atrCache);
    g_atrCache.valuePips = 0;
    g_atrCache.lastFullUpdate = 0;
    g_atrCache.lastBarTime = 0;
    g_atrCache.isValid = false;
    g_lastLoggedATRChange = 0;
    g_lastATRStepName = "";

    // ═══════════════════════════════════════════════════════════════════
    // v9.18: Initialize Reopen Cycle Monitor tracking
    // ═══════════════════════════════════════════════════════════════════
    for(int i = 0; i < MAX_LAST_REOPENS; i++) g_lastReopens[i] = "";
    g_lastReopensCount = 0;

    Print("SUCCESS: All grid arrays and v4.0 modules initialized");
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

    // v9.0: Grid A = SEMPRE BUY (tutti LONG when filled)
    // Grid A Upper (BUY STOP -> LONG when filled)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Status[i] == ORDER_FILLED) {
            totalLongLots += gridA_Upper_Lots[i];
        }
    }

    // Grid A Lower (BUY LIMIT -> LONG when filled)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Lower_Status[i] == ORDER_FILLED) {
            totalLongLots += gridA_Lower_Lots[i];  // v9.0 FIX: era totalShortLots!
        }
    }

    // v9.0: Grid B = SEMPRE SELL (tutti SHORT when filled)
    // Grid B Upper (SELL LIMIT -> SHORT when filled)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Status[i] == ORDER_FILLED) {
            totalShortLots += gridB_Upper_Lots[i];
        }
    }

    // Grid B Lower (SELL STOP -> SHORT when filled)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Lower_Status[i] == ORDER_FILLED) {
            totalShortLots += gridB_Lower_Lots[i];  // v9.0 FIX: era totalLongLots!
        }
    }

    // Calculate net
    netExposure = totalLongLots - totalShortLots;
    isNeutral = (MathAbs(netExposure) < NetExposure_MaxLot);

    if(!isNeutral && DetailedLogging && EnableNetExposureCheck) {
        Print("WARNING: Net exposure ", DoubleToString(netExposure, 2),
              " lot exceeds threshold ", NetExposure_MaxLot);
    }
}

//+------------------------------------------------------------------+
//| SYNC GRID COUNTERS FROM BROKER (v9.1)                            |
//| Sincronizza i contatori con gli ordini reali dal broker          |
//| Chiamare dopo recovery o all'avvio con ordini esistenti          |
//+------------------------------------------------------------------+
void SyncGridCountersFromBroker() {
    // Reset contatori
    g_gridA_PendingCount = 0;
    g_gridB_PendingCount = 0;
    g_gridA_LimitFilled = 0;
    g_gridA_StopFilled = 0;
    g_gridB_LimitFilled = 0;
    g_gridB_StopFilled = 0;

    long magicA = MagicNumber + MAGIC_OFFSET_GRID_A;  // = MagicNumber
    long magicB = MagicNumber + MAGIC_OFFSET_GRID_B;  // = MagicNumber + 10000

    // Conta ordini pendenti dal broker
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

        long magic = OrderGetInteger(ORDER_MAGIC);

        if(magic == magicA) {
            g_gridA_PendingCount++;
        }
        else if(magic == magicB) {
            g_gridB_PendingCount++;
        }
    }

    // Conta posizioni aperte (filled) dal broker
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        long magic = PositionGetInteger(POSITION_MAGIC);
        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);

        if(magic == magicA) {
            // Grid A = SOLO BUY
            if(posType == POSITION_TYPE_BUY) {
                // Determina se era LIMIT (sotto entry) o STOP (sopra entry)
                if(openPrice < entryPoint) {
                    g_gridA_LimitFilled++;  // BUY LIMIT era sotto entry
                } else {
                    g_gridA_StopFilled++;   // BUY STOP era sopra entry
                }
            }
        }
        else if(magic == magicB) {
            // Grid B = SOLO SELL
            if(posType == POSITION_TYPE_SELL) {
                if(openPrice > entryPoint) {
                    g_gridB_LimitFilled++;  // SELL LIMIT era sopra entry
                } else {
                    g_gridB_StopFilled++;   // SELL STOP era sotto entry
                }
            }
        }
    }

    Print("[GridSync] Counters synchronized from broker:");
    Print("  Grid A: Pending=", g_gridA_PendingCount,
          " LimitFilled=", g_gridA_LimitFilled,
          " StopFilled=", g_gridA_StopFilled);
    Print("  Grid B: Pending=", g_gridB_PendingCount,
          " LimitFilled=", g_gridB_LimitFilled,
          " StopFilled=", g_gridB_StopFilled);
}

