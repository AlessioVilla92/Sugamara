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
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  SUGAMARA v1.0 - SYSTEM CONFIGURATION");
    Print("═══════════════════════════════════════════════════════════════════");

    // General
    Print("\n[GENERAL]");
    Print("  Magic Number: ", MagicNumber);
    Print("  Symbol: ", _Symbol);
    Print("  Selected Pair: ", GetPairDisplayName(SelectedPair));
    Print("  Risk Level: ", GetPairRiskLevel(SelectedPair));

    // Grid Configuration
    Print("\n[GRID CONFIGURATION]");
    Print("  Levels per Side: ", GridLevelsPerSide);
    Print("  Total Orders: ", GridLevelsPerSide * 4, " (", GridLevelsPerSide, " x 2 zones x 2 grids)");
    Print("  Spacing Mode: ", EnumToString(SpacingMode));

    if(SpacingMode == SPACING_FIXED) {
        Print("  Fixed Spacing: ", Fixed_Spacing_Pips, " pips");
    } else if(SpacingMode == SPACING_PAIR_AUTO) {
        Print("  Pair Auto Spacing: ", GetPairDefaultSpacing(), " pips (from ", EnumToString(SelectedPair), ")");
    } else if(SpacingMode == SPACING_GEOMETRIC) {
        Print("  Geometric Percent: ", SpacingGeometric_Percent, "%");
    }

    // Lot Configuration
    Print("\n[LOT SIZING]");
    Print("  Lot Mode: ", EnumToString(LotMode));
    Print("  Base Lot: ", BaseLot);
    if(LotMode == LOT_PROGRESSIVE) {
        Print("  Lot Multiplier: ", LotMultiplier);
        Print("  Max Lot per Level: ", MaxLotPerLevel);
    }

    // Cascade Configuration
    Print("\n[PERFECT CASCADE]");
    Print("  Cascade Mode: ", EnumToString(CascadeMode));
    if(CascadeMode == CASCADE_RATIO) {
        Print("  TP Ratio: ", CascadeTP_Ratio);
    }
    Print("  Final Level TP: ", FinalLevel_TP_Pips, " pips");

    // Cyclic Reopening
    Print("\n[CYCLIC REOPENING]");
    Print("  Enabled: ", EnableCyclicReopen ? "YES" : "NO");
    if(EnableCyclicReopen) {
        Print("  Trigger: ", EnumToString(ReopenTrigger));
        // Cooldown REMOVED v5.8 - Reopen sempre immediato
        Print("  Max Cycles: ", MaxCyclesPerLevel == 0 ? "Unlimited" : IntegerToString(MaxCyclesPerLevel));
    }

    // Risk Management
    Print("\n[RISK MANAGEMENT]");
    Print("  Emergency Stop: ", EnableEmergencyStop ? "YES" : "NO");
    if(EnableEmergencyStop) {
        Print("  Emergency Threshold: ", EmergencyStop_Percent, "% equity");
    }
    // v5.8: PauseOnHighATR removed

    // Performance Targets
    Print("\n[PERFORMANCE TARGETS]");
    Print("  Target ROI: ", activePair_TargetROI, "% monthly");
    Print("  Max Drawdown: ", activePair_MaxDrawdown, "%");

    Print("\n═══════════════════════════════════════════════════════════════════");
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
                return;  // v5.x FIX: Exit without setting entryPoint (remains 0, caught by CalculateRangeBoundaries)
            }
        }
    }

    entryPoint = NormalizeDouble((ask + bid) / 2.0, symbolDigits);
    entryPointTime = TimeCurrent();

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  ENTRY POINT INITIALIZED");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  Bid: ", bid);
    Print("  Ask: ", ask);
    Print("  Entry Point: ", entryPoint);
    Print("  Time: ", TimeToString(entryPointTime, TIME_DATE|TIME_MINUTES));
    Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Calculate Range Boundaries                                       |
//+------------------------------------------------------------------+
void CalculateRangeBoundaries() {
    if(entryPoint <= 0 || currentSpacing_Pips <= 0) {
        Print("ERROR: Cannot calculate range - entry or spacing not set");
        return;
    }

    double spacingPoints = PipsToPoints(currentSpacing_Pips);
    double totalRangePoints = spacingPoints * GridLevelsPerSide;

    rangeUpperBound = entryPoint + totalRangePoints;
    rangeLowerBound = entryPoint - totalRangePoints;
    totalRangePips = currentSpacing_Pips * GridLevelsPerSide * 2;

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  RANGE BOUNDARIES CALCULATED");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  Entry Point: ", entryPoint);
    Print("  Spacing: ", DoubleToString(currentSpacing_Pips, 1), " pips");
    Print("  Levels per Side: ", GridLevelsPerSide);
    Print("  Upper Bound: ", rangeUpperBound);
    Print("  Lower Bound: ", rangeLowerBound);
    Print("  Total Range: ", DoubleToString(totalRangePips, 1), " pips");
    Print("═══════════════════════════════════════════════════════════════════");
}

