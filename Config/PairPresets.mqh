//+------------------------------------------------------------------+
//|                                              PairPresets.mqh     |
//|                        Sugamara - Pair Presets                   |
//|                                                                  |
//|  Optimized presets for Double Grid Neutral pairs                 |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| ACTIVE PAIR PARAMETERS - Set by ApplyPairPresets()               |
//+------------------------------------------------------------------+

// Pair Characteristics
double activePair_Spread = 0;               // Spread tipico (pips)
double activePair_DailyRange = 0;           // Range giornaliero medio (pips)
double activePair_ATR_Typical = 0;          // ATR tipico H4 (pips)
double activePair_MinBrokerDistance = 0;    // Distanza minima broker (pips)

// Recommended Settings
double activePair_RecommendedSpacing = 0;   // Spacing consigliato (pips)
int    activePair_RecommendedLevels = 0;    // Livelli consigliati per lato
double activePair_RecommendedBaseLot = 0;   // Lot base consigliato
double activePair_MinCapital = 0;           // Capitale minimo consigliato ($)

// Performance Targets
double activePair_TargetROI = 0;            // ROI mensile target (%)
double activePair_TargetWinRate = 0;        // Win rate target (%)
double activePair_MaxDrawdown = 0;          // Max drawdown atteso (%)

// Trading Sessions
string activePair_BestSessions = "";        // Sessioni migliori per trading

//+------------------------------------------------------------------+
//| Apply Pair Presets based on Selection                            |
//| Uses global SelectedPair from InputParameters.mqh                |
//+------------------------------------------------------------------+
void ApplyPairPresets() {
    // Use global SelectedPair input parameter
    ENUM_NEUTRAL_PAIR pair = SelectedPair;

    switch(pair) {

        //==============================================================
        // EUR/USD - Most Liquid Forex Pair
        //==============================================================
        case NEUTRAL_EURUSD:
            // Characteristics
            activePair_Spread = 0.8;                    // Spread ECN tipico
            activePair_DailyRange = 100.0;              // 80-120 pips/day
            activePair_ATR_Typical = 25.0;              // ATR(14) H4 tipico
            activePair_MinBrokerDistance = 10.0;        // Stop level minimo

            // Recommended Settings
            activePair_RecommendedSpacing = 20.0;       // 20 pips ottimale
            activePair_RecommendedLevels = 5;           // 5 livelli per lato
            activePair_RecommendedBaseLot = 0.02;       // 0.02 lot base
            activePair_MinCapital = 3000.0;             // $3,000 minimo

            // Performance Targets
            activePair_TargetROI = 12.0;                // 10-15% mensile
            activePair_TargetWinRate = 80.0;            // 75-85%
            activePair_MaxDrawdown = 10.0;              // 8-12%

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT), NY (13:00-21:00 GMT)";

            Print("PRESET LOADED: EUR/USD - Standard Configuration");
            Print("   Spacing: ", activePair_RecommendedSpacing, " pips");
            Print("   Levels: ", activePair_RecommendedLevels, " per side");
            Print("   Target ROI: ", activePair_TargetROI, "%");
            break;

        //==============================================================
        // AUD/NZD - Best for Range Trading (Highly Correlated)
        //==============================================================
        case NEUTRAL_AUDNZD:
            // Characteristics
            activePair_Spread = 3.0;                    // Spread piu alto
            activePair_DailyRange = 65.0;               // 50-80 pips/day (range stretto!)
            activePair_ATR_Typical = 18.0;              // ATR piu basso
            activePair_MinBrokerDistance = 15.0;        // Stop level

            // Recommended Settings
            activePair_RecommendedSpacing = 16.0;       // Spacing ridotto per range stretto
            activePair_RecommendedLevels = 5;           // 5 livelli
            activePair_RecommendedBaseLot = 0.015;      // Lot leggermente ridotto (spread alto)
            activePair_MinCapital = 2500.0;             // $2,500 minimo

            // Performance Targets
            activePair_TargetROI = 10.0;                // 8-12% (conservativo ma stabile)
            activePair_TargetWinRate = 85.0;            // 80-90% (altissimo!)
            activePair_MaxDrawdown = 8.0;               // 6-10% (basso)

            // Sessions
            activePair_BestSessions = "Asia (22:00-08:00 GMT), Sydney overlap";

            Print("PRESET LOADED: AUD/NZD - High Win Rate Configuration");
            Print("   Spacing: ", activePair_RecommendedSpacing, " pips");
            Print("   Levels: ", activePair_RecommendedLevels, " per side");
            Print("   Target Win Rate: ", activePair_TargetWinRate, "% (BEST)");
            break;

        //==============================================================
        // EUR/CHF - Very Low Volatility (SNB Floor Legacy)
        //==============================================================
        case NEUTRAL_EURCHF:
            // Characteristics
            activePair_Spread = 1.5;                    // Spread medio
            activePair_DailyRange = 50.0;               // 40-60 pips/day (molto basso)
            activePair_ATR_Typical = 15.0;              // ATR molto basso
            activePair_MinBrokerDistance = 10.0;        // Stop level

            // Recommended Settings
            activePair_RecommendedSpacing = 15.0;       // Spacing stretto
            activePair_RecommendedLevels = 5;           // 5 livelli
            activePair_RecommendedBaseLot = 0.02;       // Lot standard
            activePair_MinCapital = 2500.0;             // $2,500 minimo

            // Performance Targets
            activePair_TargetROI = 8.0;                 // 6-10% (range molto stretto)
            activePair_TargetWinRate = 85.0;            // 80-90%
            activePair_MaxDrawdown = 6.0;               // 5-8% (molto basso)

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT)";

            Print("PRESET LOADED: EUR/CHF - Ultra-Low Volatility Configuration");
            Print("   WARNING: Very tight range - lower ROI but very stable");
            break;

        //==============================================================
        // AUD/CAD - Medium Volatility Commodity Pair
        //==============================================================
        case NEUTRAL_AUDCAD:
            // Characteristics
            activePair_Spread = 2.5;                    // Spread medio-alto
            activePair_DailyRange = 75.0;               // 60-90 pips/day
            activePair_ATR_Typical = 22.0;              // ATR medio
            activePair_MinBrokerDistance = 12.0;        // Stop level

            // Recommended Settings
            activePair_RecommendedSpacing = 18.0;       // Spacing medio
            activePair_RecommendedLevels = 5;           // 5 livelli
            activePair_RecommendedBaseLot = 0.02;       // Lot standard
            activePair_MinCapital = 3000.0;             // $3,000 minimo

            // Performance Targets
            activePair_TargetROI = 10.0;                // 8-12%
            activePair_TargetWinRate = 78.0;            // 75-82%
            activePair_MaxDrawdown = 10.0;              // 8-12%

            // Sessions
            activePair_BestSessions = "Asia-London overlap, NY session";

            Print("PRESET LOADED: AUD/CAD - Commodity Pair Configuration");
            break;

        //==============================================================
        // NZD/CAD - Similar to AUD/CAD
        //==============================================================
        case NEUTRAL_NZDCAD:
            // Characteristics
            activePair_Spread = 3.0;                    // Spread alto
            activePair_DailyRange = 70.0;               // 50-80 pips/day
            activePair_ATR_Typical = 20.0;              // ATR medio-basso
            activePair_MinBrokerDistance = 15.0;        // Stop level

            // Recommended Settings
            activePair_RecommendedSpacing = 18.0;       // Spacing medio
            activePair_RecommendedLevels = 5;           // 5 livelli
            activePair_RecommendedBaseLot = 0.015;      // Lot ridotto (spread alto)
            activePair_MinCapital = 2800.0;             // $2,800 minimo

            // Performance Targets
            activePair_TargetROI = 9.0;                 // 7-11%
            activePair_TargetWinRate = 80.0;            // 75-85%
            activePair_MaxDrawdown = 9.0;               // 7-11%

            // Sessions
            activePair_BestSessions = "Asia session, early London";

            Print("PRESET LOADED: NZD/CAD - Secondary Range Pair Configuration");
            break;

        //==============================================================
        // CUSTOM - User Manual Settings
        //==============================================================
        case NEUTRAL_CUSTOM:
            // Use manual input parameters
            activePair_Spread = Custom_Spread;
            activePair_DailyRange = Custom_DailyRange;
            activePair_ATR_Typical = Custom_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Use input parameters directly
            activePair_RecommendedSpacing = FixedSpacing_Pips;
            activePair_RecommendedLevels = GridLevelsPerSide;
            activePair_RecommendedBaseLot = BaseLot;
            activePair_MinCapital = 3000.0;

            // Generic targets
            activePair_TargetROI = 10.0;
            activePair_TargetWinRate = 75.0;
            activePair_MaxDrawdown = 12.0;

            activePair_BestSessions = "Verify manually for your pair";

            Print("PRESET LOADED: CUSTOM - Manual Configuration");
            Print("   WARNING: Verify all parameters manually!");
            break;
    }

    // Log final configuration
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  PAIR PRESET SUMMARY");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  Spread: ", activePair_Spread, " pips");
    Print("  Daily Range: ", activePair_DailyRange, " pips");
    Print("  ATR Typical: ", activePair_ATR_Typical, " pips");
    Print("  Recommended Spacing: ", activePair_RecommendedSpacing, " pips");
    Print("  Recommended Levels: ", activePair_RecommendedLevels, " per side");
    Print("  Min Capital: $", activePair_MinCapital);
    Print("  Target ROI: ", activePair_TargetROI, "% monthly");
    Print("  Target Win Rate: ", activePair_TargetWinRate, "%");
    Print("  Max Drawdown: ", activePair_MaxDrawdown, "%");
    Print("  Best Sessions: ", activePair_BestSessions);
    Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Validate Pair Symbol Match                                       |
//| Ensures selected pair matches chart symbol                       |
//+------------------------------------------------------------------+
bool ValidatePairSymbolMatch() {
    string chartSymbol = _Symbol;
    string expectedSymbol = "";

    switch(SelectedPair) {
        case NEUTRAL_EURUSD:
            expectedSymbol = "EURUSD";
            break;
        case NEUTRAL_AUDNZD:
            expectedSymbol = "AUDNZD";
            break;
        case NEUTRAL_EURCHF:
            expectedSymbol = "EURCHF";
            break;
        case NEUTRAL_AUDCAD:
            expectedSymbol = "AUDCAD";
            break;
        case NEUTRAL_NZDCAD:
            expectedSymbol = "NZDCAD";
            break;
        case NEUTRAL_CUSTOM:
            // Custom pair - no validation
            return true;
    }

    // Check if chart symbol contains expected pair
    // Handles broker suffixes like "EURUSDm", "EURUSD.raw", etc.
    if(StringFind(chartSymbol, expectedSymbol) >= 0) {
        Print("SUCCESS: Chart symbol ", chartSymbol, " matches selected pair ", expectedSymbol);
        return true;
    }

    // Mismatch detected
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  ERROR: PAIR MISMATCH DETECTED!");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  Selected Pair: ", EnumToString(SelectedPair), " (", expectedSymbol, ")");
    Print("  Chart Symbol: ", chartSymbol);
    Print("  ");
    Print("  Please either:");
    Print("  1. Attach EA to correct chart (", expectedSymbol, ")");
    Print("  2. Change SelectedPair parameter to match chart");
    Print("  3. Use NEUTRAL_CUSTOM for manual configuration");
    Print("═══════════════════════════════════════════════════════════════════");

    if(EnableAlerts) {
        Alert("SUGAMARA: Pair mismatch! Selected ", expectedSymbol, " but chart is ", chartSymbol);
    }

    return false;
}

//+------------------------------------------------------------------+
//| Get Pair Display Name                                            |
//+------------------------------------------------------------------+
string GetPairDisplayName(ENUM_NEUTRAL_PAIR pair) {
    switch(pair) {
        case NEUTRAL_EURUSD: return "EUR/USD";
        case NEUTRAL_AUDNZD: return "AUD/NZD";
        case NEUTRAL_EURCHF: return "EUR/CHF";
        case NEUTRAL_AUDCAD: return "AUD/CAD";
        case NEUTRAL_NZDCAD: return "NZD/CAD";
        case NEUTRAL_CUSTOM: return "CUSTOM";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Get Pair Risk Level                                              |
//+------------------------------------------------------------------+
string GetPairRiskLevel(ENUM_NEUTRAL_PAIR pair) {
    switch(pair) {
        case NEUTRAL_EURUSD: return "MEDIUM";
        case NEUTRAL_AUDNZD: return "LOW";      // Best for beginners
        case NEUTRAL_EURCHF: return "LOW";
        case NEUTRAL_AUDCAD: return "MEDIUM";
        case NEUTRAL_NZDCAD: return "MEDIUM";
        case NEUTRAL_CUSTOM: return "VARIABLE";
        default: return "UNKNOWN";
    }
}

