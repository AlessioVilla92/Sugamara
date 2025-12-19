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
double activePair_RecommendedBaseLot = 0;   // Lot base (sempre 0.01)

// Performance Targets
double activePair_TargetROI = 0;            // ROI mensile target (%)
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
            activePair_RecommendedLevels = 7;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 12.0;
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
            activePair_RecommendedLevels = 7;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 10.0;

            // Sessions
            activePair_BestSessions = "NY (13:00-21:00 GMT), London-NY Overlap";

            Print("PRESET LOADED: USD/CAD - North American Configuration");
            break;

        //==============================================================
        // AUD/NZD - Best for Range Trading (Highly Correlated)
        //==============================================================
        case PAIR_AUDNZD:
            // Characteristics - v4.6 uses InputParameters
            activePair_Spread = AUDNZD_EstimatedSpread;
            activePair_DailyRange = AUDNZD_DailyRange;
            activePair_ATR_Typical = AUDNZD_ATR_Typical;
            activePair_MinBrokerDistance = 15.0;

            // Recommended Settings - v4.6 uses InputParameters
            activePair_RecommendedSpacing = AUDNZD_DefaultSpacing;
            activePair_RecommendedLevels = 7;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 8.0;

            // Sessions
            activePair_BestSessions = "Asia (22:00-08:00 GMT), Sydney overlap";

            Print("PRESET LOADED: AUD/NZD - BEST FOR NEUTRAL");
            break;

        //==============================================================
        // EUR/CHF - Very Low Volatility
        //==============================================================
        case PAIR_EURCHF:
            // Characteristics - v4.6 uses InputParameters
            activePair_Spread = EURCHF_EstimatedSpread;
            activePair_DailyRange = EURCHF_DailyRange;
            activePair_ATR_Typical = EURCHF_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings - v4.6 uses InputParameters
            activePair_RecommendedSpacing = EURCHF_DefaultSpacing;
            activePair_RecommendedLevels = 7;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 8.0;
            activePair_MaxDrawdown = 6.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT)";

            Print("PRESET LOADED: EUR/CHF - Ultra-Low Volatility");
            break;

        //==============================================================
        // AUD/CAD - Medium Volatility Commodity Pair
        //==============================================================
        case PAIR_AUDCAD:
            // Characteristics - v4.6 uses InputParameters
            activePair_Spread = AUDCAD_EstimatedSpread;
            activePair_DailyRange = AUDCAD_DailyRange;
            activePair_ATR_Typical = AUDCAD_ATR_Typical;
            activePair_MinBrokerDistance = 12.0;

            // Recommended Settings - v4.6 uses InputParameters
            activePair_RecommendedSpacing = AUDCAD_DefaultSpacing;
            activePair_RecommendedLevels = 7;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 10.0;

            // Sessions
            activePair_BestSessions = "Asia-London overlap, NY session";

            Print("PRESET LOADED: AUD/CAD - Commodity Pair");
            break;

        //==============================================================
        // NZD/CAD - Similar to AUD/CAD
        //==============================================================
        case PAIR_NZDCAD:
            // Characteristics - v4.6 uses InputParameters
            activePair_Spread = NZDCAD_EstimatedSpread;
            activePair_DailyRange = NZDCAD_DailyRange;
            activePair_ATR_Typical = NZDCAD_ATR_Typical;
            activePair_MinBrokerDistance = 15.0;

            // Recommended Settings - v4.6 uses InputParameters
            activePair_RecommendedSpacing = NZDCAD_DefaultSpacing;
            activePair_RecommendedLevels = 7;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 9.0;
            activePair_MaxDrawdown = 9.0;

            // Sessions
            activePair_BestSessions = "Asia session, early London";

            Print("PRESET LOADED: NZD/CAD - Secondary Range Pair");
            break;

        //==============================================================
        // EUR/GBP - Excellent Mean Reverting European Cross
        //==============================================================
        case PAIR_EURGBP:
            // Characteristics - v4.6 uses InputParameters
            activePair_Spread = EURGBP_EstimatedSpread;
            activePair_DailyRange = EURGBP_DailyRange;
            activePair_ATR_Typical = EURGBP_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings - v4.6 uses InputParameters
            activePair_RecommendedSpacing = EURGBP_DefaultSpacing;
            activePair_RecommendedLevels = 7;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 7.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT)";

            Print("PRESET LOADED: EUR/GBP - Excellent Mean Reverting");
            break;

        //==============================================================
        // GBP/USD - Currently Mean Reverting
        //==============================================================
        case PAIR_GBPUSD:
            // Characteristics - v4.6 uses InputParameters
            activePair_Spread = GBPUSD_EstimatedSpread;
            activePair_DailyRange = GBPUSD_DailyRange;
            activePair_ATR_Typical = GBPUSD_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings - v4.6 uses InputParameters
            activePair_RecommendedSpacing = GBPUSD_DefaultSpacing;
            activePair_RecommendedLevels = 7;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 12.0;
            activePair_MaxDrawdown = 12.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT), London-NY Overlap";

            Print("PRESET LOADED: GBP/USD - Mean Reverting");
            break;

        //==============================================================
        // USD/CHF - Safe Haven Pair
        //==============================================================
        case PAIR_USDCHF:
            // Characteristics - v4.6 uses InputParameters
            activePair_Spread = USDCHF_EstimatedSpread;
            activePair_DailyRange = USDCHF_DailyRange;
            activePair_ATR_Typical = USDCHF_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings - v4.6 uses InputParameters
            activePair_RecommendedSpacing = USDCHF_DefaultSpacing;
            activePair_RecommendedLevels = 7;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 8.0;

            // Sessions
            activePair_BestSessions = "London (08:00-16:00 GMT), NY session";

            Print("PRESET LOADED: USD/CHF - Safe Haven");
            break;

        //==============================================================
        // USD/JPY - Test Breakout (High Volatility Sessions)
        //==============================================================
        case PAIR_USDJPY:
            // Characteristics - v4.6 uses InputParameters
            activePair_Spread = USDJPY_EstimatedSpread;
            activePair_DailyRange = USDJPY_DailyRange;
            activePair_ATR_Typical = USDJPY_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings - v4.6 uses InputParameters
            activePair_RecommendedSpacing = USDJPY_DefaultSpacing;
            activePair_RecommendedLevels = 7;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets - Breakout focused
            activePair_TargetROI = 15.0;           // Higher potential
            activePair_MaxDrawdown = 15.0;         // Higher DD expected

            // Sessions - Tokyo open and London-NY overlap best for breakouts
            activePair_BestSessions = "Tokyo (00:00-08:00 GMT), London-NY Overlap (13:00-17:00 GMT)";

            Print("PRESET LOADED: USD/JPY - Test Breakout Configuration");
            Print("   NOTE: Optimized for candle breakout testing!");
            break;

        //==============================================================
        // EUR/JPY - Cross Major (Added v5.2)
        //==============================================================
        case PAIR_EURJPY:
            // Characteristics
            activePair_Spread = EURJPY_EstimatedSpread;
            activePair_DailyRange = EURJPY_DailyRange;
            activePair_ATR_Typical = EURJPY_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = EURJPY_DefaultSpacing;
            activePair_RecommendedLevels = 7;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 12.0;
            activePair_MaxDrawdown = 12.0;

            // Sessions - London and Tokyo overlap
            activePair_BestSessions = "Tokyo-London Overlap (07:00-09:00 GMT), London (08:00-16:00 GMT)";

            Print("PRESET LOADED: EUR/JPY - Cross Major Configuration");
            break;

        //==============================================================
        // AUD/USD - Commodity Major (Added v5.2)
        //==============================================================
        case PAIR_AUDUSD:
            // Characteristics
            activePair_Spread = AUDUSD_EstimatedSpread;
            activePair_DailyRange = AUDUSD_DailyRange;
            activePair_ATR_Typical = AUDUSD_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = AUDUSD_DefaultSpacing;
            activePair_RecommendedLevels = 7;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 11.0;
            activePair_MaxDrawdown = 10.0;

            // Sessions - Sydney and London
            activePair_BestSessions = "Sydney (22:00-07:00 GMT), London (08:00-16:00 GMT)";

            Print("PRESET LOADED: AUD/USD - Commodity Major Configuration");
            break;

        //==============================================================
        // NZD/USD - Commodity Pair (Added v5.2)
        //==============================================================
        case PAIR_NZDUSD:
            // Characteristics
            activePair_Spread = NZDUSD_EstimatedSpread;
            activePair_DailyRange = NZDUSD_DailyRange;
            activePair_ATR_Typical = NZDUSD_ATR_Typical;
            activePair_MinBrokerDistance = 10.0;

            // Recommended Settings
            activePair_RecommendedSpacing = NZDUSD_DefaultSpacing;
            activePair_RecommendedLevels = 7;
            activePair_RecommendedBaseLot = 0.01;

            // Performance Targets
            activePair_TargetROI = 10.0;
            activePair_MaxDrawdown = 10.0;

            // Sessions - Asian session
            activePair_BestSessions = "Wellington-Sydney (21:00-07:00 GMT), London (08:00-16:00 GMT)";

            Print("PRESET LOADED: NZD/USD - Commodity Pair Configuration");
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
            activePair_RecommendedBaseLot = 0.01;

            // Generic targets
            activePair_TargetROI = 10.0;
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
    Print("  Base Lot: ", activePair_RecommendedBaseLot, " (standard 0.01)");
    Print("  Target ROI: ", activePair_TargetROI, "% monthly");
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
        case PAIR_USDJPY:
            expectedSymbol = "USDJPY";
            break;
        case PAIR_EURJPY:
            expectedSymbol = "EURJPY";
            break;
        case PAIR_AUDUSD:
            expectedSymbol = "AUDUSD";
            break;
        case PAIR_NZDUSD:
            expectedSymbol = "NZDUSD";
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
        case PAIR_USDJPY: return "USD/JPY";
        case PAIR_EURJPY: return "EUR/JPY";
        case PAIR_AUDUSD: return "AUD/USD";
        case PAIR_NZDUSD: return "NZD/USD";
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
        case PAIR_USDJPY: return "MEDIUM-HIGH"; // Breakout volatility
        case PAIR_EURJPY: return "MEDIUM-HIGH"; // Cross major, moderate volatility
        case PAIR_AUDUSD: return "MEDIUM";       // Commodity major, stable
        case PAIR_NZDUSD: return "MEDIUM";       // Commodity pair, range-bound
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
        case PAIR_USDJPY:
            return "TEST BREAKOUT pair. High volatility - ideal for candle breakout tests.";
        case PAIR_EURJPY:
            return "Good for CASCADE. Cross major with good liquidity and mean-reverting behavior.";
        case PAIR_AUDUSD:
            return "Good for all modes. Commodity major - correlated with AUD/NZD pairs.";
        case PAIR_NZDUSD:
            return "Good for CASCADE. Commodity pair - ranges well during Asian session.";
        case PAIR_CUSTOM:
            return "Verify all parameters manually before live trading.";
        default:
            return "Unknown pair";
    }
}

