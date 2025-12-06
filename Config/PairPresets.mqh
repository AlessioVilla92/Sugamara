//+------------------------------------------------------------------+
//|                                              PairPresets.mqh     |
//|                        Sugamara - Pair Presets                   |
//|                                                                  |
//|  Optimized presets for Double Grid Neutral pairs                 |
//|  v2.0 - Updated for ENUM_FOREX_PAIR                              |
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
    // Use global SelectedPair input parameter (ENUM_FOREX_PAIR)
    ENUM_FOREX_PAIR pair = SelectedPair;

    switch(pair) {

        //==============================================================
        // EUR/USD - Most Liquid Forex Pair
        //==============================================================
        case PAIR_EURUSD:
            // Characteristics
            activePair_Spread = EURUSD_EstimatedSpread;       // From InputParameters
            activePair_DailyRange = EURUSD_DailyRange;
            activePair_ATR_Typical = EURUSD_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = EURUSD_DefaultSpacing;
            activePair_RecommendedLevels = 5;
            activePair_RecommendedBaseLot = 0.02;
            activePair_MinCapital = 3000.0;

            // Performance Targets
            activePair_TargetROI = 12.0;
            activePair_TargetWinRate = 80.0;
            activePair_MaxDrawdown = 10.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT), NY (13:00-21:00 GMT)";

            Print("PRESET LOADED: EUR/USD - Standard Configuration");
            break;

        //==============================================================
        // USD/CAD - North American Pair
        //==============================================================
        case PAIR_USDCAD:
            // Characteristics
            activePair_Spread = USDCAD_EstimatedSpread;
            activePair_DailyRange = USDCAD_DailyRange;
            activePair_ATR_Typical = USDCAD_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = USDCAD_DefaultSpacing;
            activePair_RecommendedLevels = 5;
            activePair_RecommendedBaseLot = 0.02;
            activePair_MinCapital = 2800.0;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_TargetWinRate = 78.0;
            activePair_MaxDrawdown = 10.0;

            // Sessions
            activePair_BestSessions = "NY (13:00-21:00 GMT), London-NY Overlap";

            Print("PRESET LOADED: USD/CAD - North American Configuration");
            break;

        //==============================================================
        // AUD/NZD - Best for Range Trading (Highly Correlated)
        //==============================================================
        case PAIR_AUDNZD:
            // Characteristics
            activePair_Spread = 3.0;
            activePair_DailyRange = 65.0;
            activePair_ATR_Typical = 18.0;
            activePair_MinBrokerDistance = 15.0;

            // Recommended Settings
            activePair_RecommendedSpacing = 16.0;
            activePair_RecommendedLevels = 5;
            activePair_RecommendedBaseLot = 0.015;
            activePair_MinCapital = 2500.0;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_TargetWinRate = 85.0;       // Highest win rate!
            activePair_MaxDrawdown = 8.0;

            // Sessions
            activePair_BestSessions = "Asia (22:00-08:00 GMT), Sydney overlap";

            Print("PRESET LOADED: AUD/NZD - High Win Rate Configuration (BEST FOR NEUTRAL)");
            break;

        //==============================================================
        // EUR/CHF - Very Low Volatility
        //==============================================================
        case PAIR_EURCHF:
            // Characteristics
            activePair_Spread = 1.5;
            activePair_DailyRange = 50.0;
            activePair_ATR_Typical = 15.0;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = 15.0;
            activePair_RecommendedLevels = 5;
            activePair_RecommendedBaseLot = 0.02;
            activePair_MinCapital = 2500.0;

            // Performance Targets
            activePair_TargetROI = 8.0;
            activePair_TargetWinRate = 85.0;
            activePair_MaxDrawdown = 6.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT)";

            Print("PRESET LOADED: EUR/CHF - Ultra-Low Volatility Configuration");
            break;

        //==============================================================
        // AUD/CAD - Medium Volatility Commodity Pair
        //==============================================================
        case PAIR_AUDCAD:
            // Characteristics
            activePair_Spread = 2.5;
            activePair_DailyRange = 75.0;
            activePair_ATR_Typical = 22.0;
            activePair_MinBrokerDistance = 12.0;

            // Recommended Settings
            activePair_RecommendedSpacing = 18.0;
            activePair_RecommendedLevels = 5;
            activePair_RecommendedBaseLot = 0.02;
            activePair_MinCapital = 3000.0;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_TargetWinRate = 78.0;
            activePair_MaxDrawdown = 10.0;

            // Sessions
            activePair_BestSessions = "Asia-London overlap, NY session";

            Print("PRESET LOADED: AUD/CAD - Commodity Pair Configuration");
            break;

        //==============================================================
        // NZD/CAD - Similar to AUD/CAD
        //==============================================================
        case PAIR_NZDCAD:
            // Characteristics
            activePair_Spread = 3.0;
            activePair_DailyRange = 70.0;
            activePair_ATR_Typical = 20.0;
            activePair_MinBrokerDistance = 15.0;

            // Recommended Settings
            activePair_RecommendedSpacing = 18.0;
            activePair_RecommendedLevels = 5;
            activePair_RecommendedBaseLot = 0.015;
            activePair_MinCapital = 2800.0;

            // Performance Targets
            activePair_TargetROI = 9.0;
            activePair_TargetWinRate = 80.0;
            activePair_MaxDrawdown = 9.0;

            // Sessions
            activePair_BestSessions = "Asia session, early London";

            Print("PRESET LOADED: NZD/CAD - Secondary Range Pair Configuration");
            break;

        //==============================================================
        // EUR/GBP - Excellent Mean Reverting European Cross
        //==============================================================
        case PAIR_EURGBP:
            // Characteristics
            activePair_Spread = 1.5;
            activePair_DailyRange = 55.0;
            activePair_ATR_Typical = 16.0;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = 15.0;
            activePair_RecommendedLevels = 5;
            activePair_RecommendedBaseLot = 0.02;
            activePair_MinCapital = 2500.0;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_TargetWinRate = 85.0;       // Excellent for mean reversion
            activePair_MaxDrawdown = 7.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT)";

            Print("PRESET LOADED: EUR/GBP - Excellent Mean Reverting Configuration");
            break;

        //==============================================================
        // GBP/USD - Currently Mean Reverting
        //==============================================================
        case PAIR_GBPUSD:
            // Characteristics
            activePair_Spread = 1.2;
            activePair_DailyRange = 100.0;
            activePair_ATR_Typical = 28.0;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = 22.0;      // Wider spacing for higher volatility
            activePair_RecommendedLevels = 5;
            activePair_RecommendedBaseLot = 0.015;
            activePair_MinCapital = 4000.0;

            // Performance Targets
            activePair_TargetROI = 12.0;
            activePair_TargetWinRate = 75.0;
            activePair_MaxDrawdown = 12.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT), London-NY Overlap";

            Print("PRESET LOADED: GBP/USD - Mean Reverting Configuration");
            break;

        //==============================================================
        // USD/CHF - Safe Haven Pair
        //==============================================================
        case PAIR_USDCHF:
            // Characteristics
            activePair_Spread = 1.5;
            activePair_DailyRange = 60.0;
            activePair_ATR_Typical = 18.0;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = 16.0;
            activePair_RecommendedLevels = 5;
            activePair_RecommendedBaseLot = 0.02;
            activePair_MinCapital = 3000.0;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_TargetWinRate = 80.0;
            activePair_MaxDrawdown = 8.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT), NY session";

            Print("PRESET LOADED: USD/CHF - Safe Haven Configuration");
            break;

        //==============================================================
        // CUSTOM - User Manual Settings
        //==============================================================
        case PAIR_CUSTOM:
            // Use manual input parameters
            activePair_Spread = Custom_Spread;
            activePair_DailyRange = Custom_DailyRange;
            activePair_ATR_Typical = Custom_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Use input parameters directly
            activePair_RecommendedSpacing = Custom_DefaultSpacing;
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
        case PAIR_EURUSD:
            expectedSymbol = "EURUSD";
            break;
        case PAIR_USDCAD:
            expectedSymbol = "USDCAD";
            break;
        case PAIR_AUDNZD:
            expectedSymbol = "AUDNZD";
            break;
        case PAIR_EURCHF:
            expectedSymbol = "EURCHF";
            break;
        case PAIR_AUDCAD:
            expectedSymbol = "AUDCAD";
            break;
        case PAIR_NZDCAD:
            expectedSymbol = "NZDCAD";
            break;
        case PAIR_EURGBP:
            expectedSymbol = "EURGBP";
            break;
        case PAIR_GBPUSD:
            expectedSymbol = "GBPUSD";
            break;
        case PAIR_USDCHF:
            expectedSymbol = "USDCHF";
            break;
        case PAIR_CUSTOM:
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
    Print("  3. Use PAIR_CUSTOM for manual configuration");
    Print("═══════════════════════════════════════════════════════════════════");

    if(EnableAlerts) {
        Alert("SUGAMARA: Pair mismatch! Selected ", expectedSymbol, " but chart is ", chartSymbol);
    }

    return false;
}

//+------------------------------------------------------------------+
//| Get Pair Display Name                                            |
//+------------------------------------------------------------------+
string GetPairDisplayName(ENUM_FOREX_PAIR pair) {
    switch(pair) {
        case PAIR_EURUSD: return "EUR/USD";
        case PAIR_USDCAD: return "USD/CAD";
        case PAIR_AUDNZD: return "AUD/NZD";
        case PAIR_EURCHF: return "EUR/CHF";
        case PAIR_AUDCAD: return "AUD/CAD";
        case PAIR_NZDCAD: return "NZD/CAD";
        case PAIR_EURGBP: return "EUR/GBP";
        case PAIR_GBPUSD: return "GBP/USD";
        case PAIR_USDCHF: return "USD/CHF";
        case PAIR_CUSTOM: return "CUSTOM";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Get Pair Risk Level                                              |
//+------------------------------------------------------------------+
string GetPairRiskLevel(ENUM_FOREX_PAIR pair) {
    switch(pair) {
        case PAIR_EURUSD: return "MEDIUM";
        case PAIR_USDCAD: return "MEDIUM";
        case PAIR_AUDNZD: return "LOW";      // Best for beginners
        case PAIR_EURCHF: return "LOW";
        case PAIR_AUDCAD: return "MEDIUM";
        case PAIR_NZDCAD: return "MEDIUM";
        case PAIR_EURGBP: return "LOW";      // Excellent for mean reversion
        case PAIR_GBPUSD: return "MEDIUM-HIGH";  // Higher volatility
        case PAIR_USDCHF: return "LOW-MEDIUM";   // Safe haven
        case PAIR_CUSTOM: return "VARIABLE";
        default: return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Get Pair Recommendation for Mode                                 |
//+------------------------------------------------------------------+
string GetPairRecommendation(ENUM_FOREX_PAIR pair) {
    switch(pair) {
        case PAIR_EURUSD:
            return "Good for all modes. High liquidity, tight spreads.";
        case PAIR_USDCAD:
            return "Good for CASCADE/RANGEBOX. Stable during NY session.";
        case PAIR_AUDNZD:
            return "BEST for NEUTRAL! Tight range, highest win rate.";
        case PAIR_EURCHF:
            return "Good for PURE mode. Very stable, low volatility.";
        case PAIR_AUDCAD:
            return "Good for CASCADE. Commodity correlation adds stability.";
        case PAIR_NZDCAD:
            return "Similar to AUD/CAD. Good backup pair.";
        case PAIR_EURGBP:
            return "EXCELLENT for NEUTRAL! European economies correlate. Tight range.";
        case PAIR_GBPUSD:
            return "Good for mean reversion. Higher volatility - use wider spacing.";
        case PAIR_USDCHF:
            return "Good for RANGEBOX. Safe haven - stable, beware risk-off events.";
        case PAIR_CUSTOM:
            return "Verify all parameters manually before live trading.";
        default:
            return "Unknown pair";
    }
}

