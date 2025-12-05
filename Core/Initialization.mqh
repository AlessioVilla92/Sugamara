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
    } else if(SpacingMode == SPACING_ATR) {
        Print("  ATR Period: ", ATR_Period);
        Print("  ATR Timeframe: ", EnumToString(ATR_Timeframe));
        Print("  ATR Multiplier: ", SpacingATR_Multiplier);
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
        Print("  Cooldown: ", CyclicCooldown_Seconds, " seconds");
        Print("  Max Cycles: ", MaxCyclesPerLevel == 0 ? "Unlimited" : IntegerToString(MaxCyclesPerLevel));
    }

    // Risk Management
    Print("\n[RISK MANAGEMENT]");
    Print("  Emergency Stop: ", EnableEmergencyStop ? "YES" : "NO");
    if(EnableEmergencyStop) {
        Print("  Emergency Threshold: ", EmergencyStop_Percent, "% equity");
    }
    Print("  Pause on High ATR: ", PauseOnHighATR ? "YES" : "NO");
    if(PauseOnHighATR) {
        Print("  High ATR Threshold: ", HighATR_Threshold, " pips");
    }

    // Performance Targets
    Print("\n[PERFORMANCE TARGETS]");
    Print("  Target ROI: ", activePair_TargetROI, "% monthly");
    Print("  Target Win Rate: ", activePair_TargetWinRate, "%");
    Print("  Max Drawdown: ", activePair_MaxDrawdown, "%");
    Print("  Min Capital: $", activePair_MinCapital);

    Print("\n═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Initialize Entry Point                                           |
//| Sets the central price around which grids are built              |
//+------------------------------------------------------------------+
void InitializeEntryPoint() {
    // Get current market price (midpoint of bid/ask)
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

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

