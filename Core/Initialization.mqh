//+------------------------------------------------------------------+
//|                                          Initialization.mqh      |
//|                        Sugamara - System Initialization          |
//|                                                                  |
//|  Initialization routines for Double Grid Neutral System          |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Print System Configuration                                       |
//+------------------------------------------------------------------+
void PrintSystemConfiguration() {
    Log_Header("SUGAMARA v9.10 - SYSTEM CONFIGURATION");

    // General
    Log_SubHeader("GENERAL");
    Log_KeyValueNum("Magic Number", MagicNumber, 0);
    Log_KeyValue("Symbol", _Symbol);
    Log_KeyValue("Pair", GetPairDisplayName(SelectedPair));
    Log_KeyValue("Risk Level", GetPairRiskLevel(SelectedPair));

    // Grid Configuration
    Log_SubHeader("GRID CONFIGURATION");
    Log_KeyValueNum("Levels/Side", GridLevelsPerSide, 0);
    Log_KeyValueNum("Total Orders", GridLevelsPerSide * 4, 0);
    Log_KeyValue("Spacing Mode", EnumToString(SpacingMode));

    if(SpacingMode == SPACING_FIXED) {
        Log_KeyValueNum("Fixed Spacing", Fixed_Spacing_Pips, 1);
    } else if(SpacingMode == SPACING_PAIR_AUTO) {
        Log_KeyValueNum("Auto Spacing", GetPairDefaultSpacing(), 1);
    }

    // Lot Configuration
    Log_SubHeader("LOT SIZING");
    Log_KeyValue("Lot Mode", EnumToString(LotMode));
    Log_KeyValueNum("Base Lot", BaseLot, 2);
    if(LotMode == LOT_PROGRESSIVE) {
        Log_KeyValueNum("Multiplier", LotMultiplier, 2);
        Log_KeyValueNum("Max Lot/Level", MaxLotPerLevel, 2);
    }

    // Cascade Configuration
    Log_SubHeader("PERFECT CASCADE");
    Log_KeyValue("Mode", EnumToString(CascadeMode));
    if(CascadeMode == CASCADE_RATIO) {
        Log_KeyValueNum("TP Ratio", CascadeTP_Ratio, 2);
    }
    Log_KeyValueNum("Final TP", FinalLevel_TP_Pips, 1);

    // Cyclic Reopening
    Log_SubHeader("CYCLIC REOPENING");
    Log_KeyValue("Enabled", EnableCyclicReopen ? "YES" : "NO");
    if(EnableCyclicReopen) {
        Log_KeyValue("Trigger", EnumToString(ReopenTrigger));
        Log_KeyValue("Max Cycles", MaxCyclesPerLevel == 0 ? "Unlimited" : IntegerToString(MaxCyclesPerLevel));
    }

    // Risk Management
    Log_SubHeader("RISK MANAGEMENT");
    Log_KeyValue("Emergency Stop", EnableEmergencyStop ? "YES" : "NO");
    if(EnableEmergencyStop) {
        Log_KeyValueNum("Threshold", EmergencyStop_Percent, 1);
    }

    // Performance Targets
    Log_SubHeader("PERFORMANCE TARGETS");
    Log_KeyValueNum("Target ROI", activePair_TargetROI, 1);
    Log_KeyValueNum("Max Drawdown", activePair_MaxDrawdown, 1);

    Log_Separator();
}

//+------------------------------------------------------------------+
//| Initialize Entry Point                                           |
//| Sets the central price around which grids are built              |
//| v5.x FIX: Gestisce correttamente Strategy Tester con ASK/BID=0   |
//+------------------------------------------------------------------+
void InitializeEntryPoint() {
    // v5.x FIX: Usa SymbolInfoTick per dati più affidabili
    MqlTick tick;
    double ask = 0, bid = 0;

    // Metodo 1: SymbolInfoTick (più affidabile)
    if(SymbolInfoTick(_Symbol, tick) && tick.ask > 0 && tick.bid > 0) {
        ask = tick.ask;
        bid = tick.bid;
    } else {
        // Metodo 2: Fallback a SymbolInfoDouble
        ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    }

    // v5.x FIX: Verifica dati validi (CRITICO per Strategy Tester)
    // In Strategy Tester al primo tick ASK/BID possono essere 0
    if(ask <= 0 || bid <= 0) {
        Print("[EntryPoint] WARNING: ASK/BID not available - using iClose() as fallback");
        double lastClose = iClose(_Symbol, PERIOD_M1, 0);
        if(lastClose > 0) {
            ask = lastClose;
            bid = lastClose;
            Print("[EntryPoint] Using last M1 close: ", lastClose);
        } else {
            // Ultimo tentativo: iClose su timeframe corrente
            lastClose = iClose(_Symbol, PERIOD_CURRENT, 0);
            if(lastClose > 0) {
                ask = lastClose;
                bid = lastClose;
                Print("[EntryPoint] Using current TF close: ", lastClose);
            } else {
                Print("[EntryPoint] CRITICAL: No price data available!");
                Print("[EntryPoint] Strategy Tester may not have price data at first tick - EA will not function!");
                return;  // v5.x FIX: Exit without setting entryPoint (remains 0)
            }
        }
    }

    entryPoint = NormalizeDouble((ask + bid) / 2.0, symbolDigits);
    entryPointTime = TimeCurrent();

    Log_Header("ENTRY POINT INITIALIZED");
    Log_KeyValueNum("Bid", bid, symbolDigits);
    Log_KeyValueNum("Ask", ask, symbolDigits);
    Log_KeyValueNum("Entry", entryPoint, symbolDigits);
    Log_KeyValue("Time", TimeToString(entryPointTime, TIME_DATE|TIME_MINUTES));
    Log_Separator();
}

// v9.12: CalculateRangeBoundaries() REMOVED - was dead code

