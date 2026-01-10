//+------------------------------------------------------------------+
//|                                                  TesterMode.mqh  |
//|                        SUGAMARA v9.7 - Strategy Tester Mode      |
//|                                                                  |
//|  Compatibility layer for reliable backtesting                    |
//|  Disables incompatible features in Strategy Tester               |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2026"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| TESTER MODE GLOBAL VARIABLES                                     |
//+------------------------------------------------------------------+
bool g_isTester = false;           // Flag: running in Strategy Tester?
bool g_isOptimization = false;     // Flag: running optimization?
bool g_testerGridStarted = false;  // Flag: grid already started in tester
bool g_testerInitComplete = false; // Flag: tester init completed

//+------------------------------------------------------------------+
//| Initialize Tester Mode Detection                                 |
//| MUST be called at the very beginning of OnInit()                 |
//+------------------------------------------------------------------+
void InitializeTesterMode() {
    g_isTester = (bool)MQLInfoInteger(MQL_TESTER);
    g_isOptimization = (bool)MQLInfoInteger(MQL_OPTIMIZATION);
    g_testerGridStarted = false;
    g_testerInitComplete = false;
    
    if(g_isTester) {
        Log_Header("STRATEGY TESTER MODE");
        Log_KeyValue("Mode", "BACKTEST");
        Log_KeyValue("Disabled", "GlobalVars, Recovery, Session, Dashboard, Alerts");
        Log_KeyValue("Enabled", "AutoStart, CyclicReopen, AllHours");
        Log_Separator();
    }
    
    if(g_isOptimization) {
        // Minimal output in optimization mode
        Print("[TESTER] Optimization mode - minimal logging enabled");
    }
}

//+------------------------------------------------------------------+
//| Check if Running in Strategy Tester                              |
//+------------------------------------------------------------------+
bool IsTesterMode() {
    return g_isTester;
}

//+------------------------------------------------------------------+
//| Check if Running in Optimization Mode                            |
//+------------------------------------------------------------------+
bool IsOptimizationMode() {
    return g_isOptimization;
}

//+------------------------------------------------------------------+
//| Should Skip UI/Dashboard Operations                              |
//| Returns true if we should skip all graphical operations          |
//+------------------------------------------------------------------+
bool ShouldSkipUI() {
    return g_isTester || g_isOptimization;
}

//+------------------------------------------------------------------+
//| Should Skip GlobalVariables Operations                           |
//| GlobalVariables are isolated in tester - useless to save/load    |
//+------------------------------------------------------------------+
bool ShouldSkipGlobalVars() {
    return g_isTester;
}

//+------------------------------------------------------------------+
//| Should Skip Recovery Mode                                        |
//| Recovery needs GlobalVariables which don't work in tester        |
//+------------------------------------------------------------------+
bool ShouldSkipRecovery() {
    return g_isTester;
}

//+------------------------------------------------------------------+
//| Should Skip Session Time Check                                   |
//| In tester, we want to trade all hours for complete testing       |
//+------------------------------------------------------------------+
bool ShouldSkipSessionCheck() {
    return g_isTester;
}

//+------------------------------------------------------------------+
//| Should Skip Volatility Check                                     |
//| Volatility check can block cyclic reopen with historical data    |
//+------------------------------------------------------------------+
bool ShouldSkipVolatilityCheck() {
    return g_isTester;
}

//+------------------------------------------------------------------+
//| Should Skip Alerts                                               |
//| Alerts would block tester execution                              |
//+------------------------------------------------------------------+
bool ShouldSkipAlerts() {
    return g_isTester || g_isOptimization;
}

//+------------------------------------------------------------------+
//| Tester-Safe Print Function                                       |
//| Skips print in optimization mode to improve performance          |
//+------------------------------------------------------------------+
void TesterPrint(string message) {
    if(!g_isOptimization) {
        Print(message);
    }
}

//+------------------------------------------------------------------+
//| Tester-Safe Print Format Function                                |
//+------------------------------------------------------------------+
void TesterPrintFormat(string format, double v1=0, double v2=0, double v3=0) {
    if(!g_isOptimization) {
        PrintFormat(format, v1, v2, v3);
    }
}

//+------------------------------------------------------------------+
//| Force Grid Start for Tester                                      |
//| Called on first tick to auto-start the grid system               |
//| Replaces the need for clicking START button                      |
//+------------------------------------------------------------------+
void TesterForceGridStart() {
    // Only in tester mode
    if(!g_isTester) return;
    
    // Only once
    if(g_testerGridStarted) return;
    
    // Only if system is idle (waiting for start)
    if(systemState != STATE_IDLE) return;
    
    g_testerGridStarted = true;

    Log_SubHeader("TESTER AUTO-START");
    Log_KeyValueNum("Entry", entryPoint, symbolDigits);
    Log_KeyValueNum("Spacing", currentSpacing_Pips, 1);
    Log_KeyValueNum("Levels", GridLevelsPerSide, 0);

    StartGridSystem();

    if(systemState == STATE_ACTIVE) {
        Log_Debug("Tester", StringFormat("Started gridA=%d gridB=%d", GetGridAPendingOrders(), GetGridBPendingOrders()));
    } else {
        Log_SystemWarning("Tester", "Grid start may have failed");
    }
}

//+------------------------------------------------------------------+
//| Mark Tester Initialization Complete                              |
//| Call at the end of OnInit()                                      |
//+------------------------------------------------------------------+
void TesterInitComplete() {
    g_testerInitComplete = true;
    
    if(g_isTester) {
        Print("[TESTER] Initialization complete - ready for first tick");
    }
}

//+------------------------------------------------------------------+
//| Check if Tester Init is Complete                                 |
//+------------------------------------------------------------------+
bool IsTesterInitComplete() {
    return g_testerInitComplete;
}

//+------------------------------------------------------------------+
//| Get Tester Status String for Logging                             |
//+------------------------------------------------------------------+
string GetTesterStatusString() {
    if(!g_isTester) return "LIVE/DEMO";
    if(g_isOptimization) return "OPTIMIZATION";
    return "BACKTEST";
}

//+------------------------------------------------------------------+
//| Log Tester Statistics (call in OnDeinit)                         |
//+------------------------------------------------------------------+
void LogTesterStatistics() {
    if(!g_isTester) return;

    Log_Header("TESTER FINAL STATISTICS");
    Log_KeyValue("Grid Started", g_testerGridStarted ? "YES" : "NO");
    Log_KeyValueNum("Session P/L", sessionRealizedProfit + GetTotalOpenProfit(), 2);
    Log_KeyValueNum("Total Trades", sessionWins + sessionLosses, 0);
    Log_KeyValueNum("Win Rate", GetWinRate(), 1);
    Log_KeyValueNum("Grid A Cycles", GetTotalGridACycles(), 0);
    Log_KeyValueNum("Grid B Cycles", GetTotalGridBCycles(), 0);
    Log_Separator();
}

//+------------------------------------------------------------------+
//| Helper: Get Total Grid A Cycles                                  |
//+------------------------------------------------------------------+
int GetTotalGridACycles() {
    int total = 0;
    for(int i = 0; i < GridLevelsPerSide; i++) {
        total += gridA_Upper_Cycles[i];
        total += gridA_Lower_Cycles[i];
    }
    return total;
}

//+------------------------------------------------------------------+
//| Helper: Get Total Grid B Cycles                                  |
//+------------------------------------------------------------------+
int GetTotalGridBCycles() {
    int total = 0;
    for(int i = 0; i < GridLevelsPerSide; i++) {
        total += gridB_Upper_Cycles[i];
        total += gridB_Lower_Cycles[i];
    }
    return total;
}

//+------------------------------------------------------------------+
//| TESTER VIRTUAL ORDERS (Optional - for spread simulation)         |
//| Can be used to simulate orders that would be rejected by broker  |
//+------------------------------------------------------------------+
/*
struct VirtualOrder {
    ulong ticket;
    ENUM_ORDER_TYPE type;
    double price;
    double lot;
    double tp;
    double sl;
    string comment;
    datetime createTime;
    bool isActive;
};

VirtualOrder g_virtualOrders[];

void AddVirtualOrder(ENUM_ORDER_TYPE type, double price, double lot, double tp, double sl, string comment) {
    // Implementation for handling orders that can't be placed due to spread
}
*/

//+------------------------------------------------------------------+
