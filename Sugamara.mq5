//+==================================================================+
//|                                              Sugamara v3.0.0.mq5 |
//|                                                                  |
//|   SUGAMARA - DOUBLE GRID NEUTRAL MULTIMODE                       |
//|                                                                  |
//|   Market Neutral • PURE / CASCADE / RANGEBOX                     |
//|   Ottimizzato per EUR/USD e AUD/NZD                              |
//+------------------------------------------------------------------+
//|  Copyright (C) 2025 - Sugamara Development Team                  |
//|  Version: 3.0.0 MULTIMODE + ADVANCED FEATURES                    |
//|  Release Date: December 2025                                     |
//+------------------------------------------------------------------+
//|  SISTEMA DOUBLE GRID NEUTRAL - 3 MODALITÀ SELEZIONABILI          |
//|                                                                   |
//|  NEUTRAL_PURE:     Spacing fisso, TP fisso, NO ATR (learning)    |
//|  NEUTRAL_CASCADE:  TP=Entry precedente, ATR opzionale (consigliato)|
//|  NEUTRAL_RANGEBOX: Range Box + Hedge, ATR opzionale (produzione) |
//|                                                                   |
//|  v3.0 NEW FEATURES:                                              |
//|  - Partial Take Profit (50%/75%/100%)                            |
//|  - Trailing Stop Asimmetrico                                     |
//|  - ATR Multi-Timeframe Dashboard                                 |
//|  - Manual S/R Drag & Drop                                        |
//|  - Control Buttons (MARKET/LIMIT/STOP/CLOSE)                     |
//|  - Visual Theme: Amaranto Scuro + Blu Turchese                   |
//+------------------------------------------------------------------+

#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"
#property version   "3.00"
#property description "SUGAMARA v3.0 - Double Grid Neutral MULTIMODE"
#property description "3 Modalità: PURE / CASCADE / RANGEBOX"
#property description "v3.0: Partial TP, Trailing, ATR MTF, Manual S/R"
#property strict

//+------------------------------------------------------------------+
//| INCLUDE MODULES                                                  |
//+------------------------------------------------------------------+

// Configuration Modules
#include "Config/Enums.mqh"
#include "Config/InputParameters.mqh"
#include "Config/PairPresets.mqh"

// Core Modules
#include "Core/GlobalVariables.mqh"
#include "Core/BrokerValidation.mqh"
#include "Core/Initialization.mqh"
#include "Core/ModeLogic.mqh"

// Utility Modules
#include "Utils/Helpers.mqh"
#include "Utils/GridHelpers.mqh"
#include "Utils/ATRCalculator.mqh"

// Indicators Module
#include "Indicators/Indicators.mqh"

// Trading Modules
#include "Trading/OrderManager.mqh"
#include "Trading/GridASystem.mqh"
#include "Trading/GridBSystem.mqh"
#include "Trading/PositionMonitor.mqh"
#include "Trading/RiskManager.mqh"
#include "Trading/RangeBoxManager.mqh"
#include "Trading/HedgingManager.mqh"
#include "Trading/ShieldManager.mqh"

// v3.0 NEW Trading Modules
#include "Trading/PartialTPManager.mqh"
#include "Trading/GridTrailingManager.mqh"

// UI Module
#include "UI/Dashboard.mqh"

// v3.0 NEW UI Modules
#include "UI/ManualSR.mqh"
#include "UI/ControlButtons.mqh"
#include "UI/ShieldZonesVisual.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  SUGAMARA v3.0.0 - DOUBLE GRID NEUTRAL MULTIMODE                 ");
    Print("  Market Neutral • PURE / CASCADE / RANGEBOX                      ");
    Print("  v3.0: Partial TP | Trailing | ATR MTF | Manual S/R              ");
    Print("  Copyright (C) 2025 - Sugamara Development Team                  ");
    Print("═══════════════════════════════════════════════════════════════════");

    //--- APPLY VISUAL THEME ---
    ApplyVisualTheme();

    //--- STEP 0: Validate Mode Parameters and Print Config ---
    if(!ValidateModeParameters()) {
        Print("CRITICAL: Mode parameters validation FAILED");
        systemState = STATE_ERROR;
        return(INIT_FAILED);
    }
    PrintModeConfiguration();

    // Set system state
    systemState = STATE_INITIALIZING;

    // Check if system is enabled
    if(!EnableSystem) {
        Print("WARNING: System is DISABLED in settings");
        systemState = STATE_IDLE;
        return(INIT_SUCCEEDED);
    }

    //--- STEP 1: Load Broker Specifications ---
    if(!LoadBrokerSpecifications()) {
        Print("CRITICAL: Failed to load broker specifications");
        systemState = STATE_ERROR;
        return(INIT_FAILED);
    }

    //--- STEP 2: Apply Pair Presets ---
    ApplyPairPresets();

    //--- STEP 3: Validate Pair/Symbol Match ---
    if(!ValidatePairSymbolMatch()) {
        Print("WARNING: Chart symbol doesn't match selected pair preset");
        // Continue anyway, user may have intentionally selected different pair
    }

    //--- STEP 4: Validate Input Parameters ---
    if(!ValidateInputParameters()) {
        Print("CRITICAL: Input parameters validation FAILED");
        systemState = STATE_ERROR;
        return(INIT_FAILED);
    }

    //--- STEP 5: Initialize Arrays ---
    InitializeArrays();

    //--- STEP 6: Initialize Order Manager ---
    if(!InitializeOrderManager()) {
        Print("CRITICAL: Failed to initialize Order Manager");
        systemState = STATE_ERROR;
        return(INIT_FAILED);
    }

    //--- STEP 7: Initialize ATR Indicator ---
    if(!CreateATRHandle()) {
        Print("CRITICAL: Failed to create ATR indicator");
        systemState = STATE_ERROR;
        return(INIT_FAILED);
    }

    // Wait for ATR data
    if(!WaitForATRData(5000)) {
        Print("WARNING: ATR data not ready, using default spacing");
    }

    //--- STEP 8: Initialize Entry Point ---
    InitializeEntryPoint();

    //--- STEP 9: Calculate Spacing based on Mode ---
    currentSpacing_Pips = CalculateCurrentSpacing();
    Print("Initial Spacing: ", DoubleToString(currentSpacing_Pips, 1), " pips (Mode: ", GetModeName(), ")");

    //--- STEP 10: Calculate Range Boundaries ---
    CalculateRangeBoundaries();

    //--- STEP 10.5: Initialize RangeBox (only NEUTRAL_RANGEBOX) ---
    if(IsRangeBoxAvailable()) {
        if(!InitializeRangeBox()) {
            Print("CRITICAL: Failed to initialize RangeBox");
            systemState = STATE_ERROR;
            return(INIT_FAILED);
        }
    }

    //--- STEP 10.6: Initialize Hedging (only NEUTRAL_RANGEBOX with EnableHedging) ---
    if(IsHedgingAvailable()) {
        if(!InitializeHedgingManager()) {
            Print("WARNING: Failed to initialize Hedging Manager");
        }
    }

    //--- STEP 10.7: Initialize Shield Intelligente (only NEUTRAL_RANGEBOX) ---
    if(IsRangeBoxAvailable() && ShieldMode != SHIELD_DISABLED) {
        if(!InitializeShield()) {
            Print("WARNING: Failed to initialize Shield Intelligente");
        }
        // Calculate breakout levels after grid initialization (will recalc after grids)
    }

    //--- STEP 10.8: Initialize Shield Zones Visual (v3.0) ---
    if(IsRangeBoxAvailable() && Enable_ShieldZonesVisual) {
        if(!InitializeShieldZonesVisual()) {
            Print("WARNING: Failed to initialize Shield Zones Visual");
        }
    }

    //--- STEP 11: Initialize Position Monitor ---
    if(!InitializePositionMonitor()) {
        Print("WARNING: Failed to initialize Position Monitor");
    }

    //--- STEP 12: Initialize Risk Manager ---
    if(!InitializeRiskManager()) {
        Print("WARNING: Failed to initialize Risk Manager");
    }

    //--- STEP 13: Initialize Dashboard ---
    if(!InitializeDashboard()) {
        Print("WARNING: Failed to initialize Dashboard");
    }

    //--- STEP 13.5: Initialize Volatility Monitor ---
    if(!InitializeVolatilityMonitor()) {
        Print("WARNING: Failed to initialize Volatility Monitor");
    }

    //--- STEP 13.6: Initialize ADX Monitor ---
    if(!InitializeADXMonitor()) {
        Print("WARNING: Failed to initialize ADX Monitor");
    }

    //--- STEP 13.7: Initialize ATR Multi-TF (v3.0) ---
    if(!InitializeATRMultiTF()) {
        Print("WARNING: Failed to initialize ATR Multi-TF");
    }

    //--- STEP 13.8: Initialize Partial TP Manager (v3.0) ---
    if(!InitializePartialTPManager()) {
        Print("WARNING: Failed to initialize Partial TP Manager");
    }

    //--- STEP 13.9: Initialize Trailing Manager (v3.0) ---
    if(!InitializeTrailingManager()) {
        Print("WARNING: Failed to initialize Trailing Manager");
    }

    //--- STEP 13.10: Initialize Manual S/R (v3.0) ---
    if(!InitializeManualSR()) {
        Print("WARNING: Failed to initialize Manual S/R");
    }

    //--- STEP 14: Initialize Grid A ---
    if(!InitializeGridA()) {
        Print("CRITICAL: Failed to initialize Grid A");
        systemState = STATE_ERROR;
        return(INIT_FAILED);
    }

    //--- STEP 15: Initialize Grid B ---
    if(!InitializeGridB()) {
        Print("CRITICAL: Failed to initialize Grid B");
        systemState = STATE_ERROR;
        return(INIT_FAILED);
    }

    //--- STEP 16: Sync Grids (if enabled) ---
    if(SyncGridAB) {
        SyncGridBWithGridA();
    }

    //--- STEP 17: Validate Grid Configuration ---
    if(!ValidateGridConfiguration()) {
        Print("CRITICAL: Grid configuration validation FAILED");
        systemState = STATE_ERROR;
        return(INIT_FAILED);
    }

    //--- STEP 17.3: Sync RangeBox with Grid Levels ---
    // CRITICAL: S/R = Last Grid Levels (not Manual/Daily_HL/ATR)
    // Resistance = highest Grid B Upper, Support = lowest Grid A Lower
    if(IsRangeBoxAvailable()) {
        SyncRangeBoxWithGrid();
    }

    //--- STEP 17.5: Calculate Breakout Levels for Shield ---
    if(IsRangeBoxAvailable() && ShieldMode != SHIELD_DISABLED) {
        if(!CalculateBreakoutLevels()) {
            Print("WARNING: Failed to calculate breakout levels");
        }
    }

    //--- STEP 18: Place Initial Orders ---
    Print("");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  PLACING INITIAL GRID ORDERS");
    Print("═══════════════════════════════════════════════════════════════════");

    bool gridAPlaced = PlaceAllGridAOrders();
    bool gridBPlaced = PlaceAllGridBOrders();

    if(!gridAPlaced || !gridBPlaced) {
        Print("WARNING: Some orders failed to place - system will retry");
    }

    //--- STEP 19: Draw Grid Visualization ---
    DrawGridVisualization();

    //--- STEP 20: Log Final Configuration ---
    PrintSystemConfiguration();
    LogATRReport();

    //--- INITIALIZATION COMPLETE ---
    systemState = STATE_ACTIVE;

    Print("");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  SUGAMARA v3.0 INITIALIZATION COMPLETE");
    Print("  Mode: ", GetModeName());
    Print("  System State: ACTIVE");
    Print("  Grid A Orders: ", GetGridAPendingOrders() + GetGridAActivePositions());
    Print("  Grid B Orders: ", GetGridBPendingOrders() + GetGridBActivePositions());
    if(IsRangeBoxAvailable()) {
        Print("  RangeBox: R=", DoubleToString(rangeBox_Resistance, symbolDigits),
              " S=", DoubleToString(rangeBox_Support, symbolDigits));
        Print("  Shield Mode: ", GetShieldModeName());
        if(ShieldMode != SHIELD_DISABLED) {
            Print("  Upper Breakout: ", DoubleToString(upperBreakoutLevel, symbolDigits));
            Print("  Lower Breakout: ", DoubleToString(lowerBreakoutLevel, symbolDigits));
        }
    }
    Print("───────────────────────────────────────────────────────────────────");
    Print("  v3.0 FEATURES:");
    Print("  ✅ Partial TP: ", Enable_PartialTP ? "ENABLED" : "DISABLED");
    Print("  ✅ Trailing Asym: ", Enable_TrailingAsymmetric ? "ENABLED" : "DISABLED");
    Print("  ✅ ATR Multi-TF: ", Enable_ATRMultiTF ? "ENABLED" : "DISABLED");
    Print("  ✅ Manual S/R: ", Enable_ManualSR ? "ENABLED" : "DISABLED");
    Print("  ✅ Control Buttons: ", Enable_AdvancedButtons ? "ENABLED" : "DISABLED");
    Print("═══════════════════════════════════════════════════════════════════");

    if(EnableAlerts) {
        Alert("SUGAMARA: System initialized and ACTIVE");
    }

    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                  |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  SUGAMARA DEINIT");
    Print("═══════════════════════════════════════════════════════════════════");

    // Log reason
    string reasonText = "";
    bool shouldCleanUI = true;  // v3.0: Smart UI cleanup flag

    switch(reason) {
        case REASON_PROGRAM:     reasonText = "EA removed"; break;
        case REASON_REMOVE:      reasonText = "EA removed from chart"; break;
        case REASON_RECOMPILE:   reasonText = "EA recompiled"; shouldCleanUI = false; break;
        case REASON_CHARTCHANGE: reasonText = "Chart symbol/period changed"; break;
        case REASON_CHARTCLOSE:  reasonText = "Chart closed"; break;
        case REASON_PARAMETERS:  reasonText = "Parameters changed"; shouldCleanUI = false; break;
        case REASON_ACCOUNT:     reasonText = "Account changed"; break;
        case REASON_TEMPLATE:    reasonText = "Template applied"; break;
        case REASON_INITFAILED:  reasonText = "Initialization failed"; break;
        case REASON_CLOSE:       reasonText = "Terminal closed"; shouldCleanUI = false; break;
        default:                 reasonText = "Unknown reason"; break;
    }
    Print("Reason: ", reason, " (", reasonText, ")");

    // Log final statistics
    Print("");
    Print("--- FINAL SESSION STATISTICS ---");
    Print("Session P/L: ", FormatMoney(sessionRealizedProfit + GetTotalOpenProfit()));
    Print("Trades: ", sessionWins + sessionLosses, " (", sessionWins, "W/", sessionLosses, "L)");
    Print("Win Rate: ", FormatPercent(GetWinRate()));
    Print("Max Drawdown: ", FormatPercent(maxDrawdownReached));

    // Release ATR handle
    ReleaseATRHandle();

    // Release Indicators
    DeinitializeVolatilityMonitor();
    DeinitializeADXMonitor();

    // v3.0: Deinitialize new modules
    DeinitializeATRMultiTF();
    DeinitializePartialTPManager();
    DeinitializeTrailingManager();
    DeinitializeManualSR();

    // v3.0: Smart UI cleanup - Don't remove UI on recompile/terminal close
    // The UI will be automatically recreated on next initialization
    if(shouldCleanUI) {
        Print("Cleaning up UI objects...");
        DeinitializeControlButtons();
        DeinitializeShieldZonesVisual();
        CleanupUI();

        // Clean up RangeBox visualization
        if(IsRangeBoxAvailable())
            RemoveRangeBoxVisualization();
    } else {
        Print("Preserving UI objects for quick restart...");
        // Reset initialization flag so dashboard will be verified on restart
        g_dashboardInitialized = false;
    }

    // Deinitialize Shield (logic only, not visual)
    if(IsRangeBoxAvailable() && ShieldMode != SHIELD_DISABLED) {
        DeinitializeShield();
        DeinitializeRangeBoxShield();
    }

    // Note: We do NOT close orders on deinit - they should persist
    // Only close if explicitly requested or on critical error

    Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
    // Skip if system not active
    if(systemState != STATE_ACTIVE) {
        if(systemState == STATE_PAUSED) {
            // Check if we can resume
            if(EnableDailyTarget && IsNewDay()) {
                ResetDailyFlags();
                systemState = STATE_ACTIVE;
                LogMessage(LOG_INFO, "New day - System resumed");
            }
        }
        return;
    }

    //--- RISK CHECKS (Highest Priority) ---
    if(!PerformRiskChecks()) {
        // Risk check failed - don't process further
        UpdateDashboard();
        return;
    }

    //--- UPDATE POSITION STATUSES ---
    MonitorPositions();

    //--- RANGEBOX: Update state and check breakouts (only NEUTRAL_RANGEBOX) ---
    if(IsRangeBoxAvailable()) {
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        UpdateRangeBoxState(currentPrice);
        RecalculateRangeBox();  // Ricalcola se ATR_BASED e tempo trascorso
    }

    //--- HEDGING: Monitor hedge positions (only NEUTRAL_RANGEBOX with EnableHedging) ---
    if(IsHedgingAvailable()) {
        MonitorHedgePositions();
    }

    //--- SHIELD: Process Shield Intelligente (only NEUTRAL_RANGEBOX with Shield enabled) ---
    if(IsRangeBoxAvailable() && ShieldMode != SHIELD_DISABLED) {
        ProcessShield();
    }

    //--- CHECK ATR RECALCULATION (only if ATR enabled) ---
    if(IsATREnabled() && UpdateATRAndCheckAdjustment()) {
        // ATR changed significantly - may need to adjust spacing
        double newSpacing = CalculateCurrentSpacing();

        if(MathAbs(newSpacing - currentSpacing_Pips) > 2.0) {
            LogMessage(LOG_INFO, "ATR spacing change: " +
                       DoubleToString(currentSpacing_Pips, 1) + " -> " +
                       DoubleToString(newSpacing, 1) + " pips");

            // Note: Full grid recalculation would require closing and reopening orders
            // For now, just log the change - new cyclic orders will use new spacing
            currentSpacing_Pips = newSpacing;
        }
    }

    //--- PROCESS CYCLIC REOPENING ---
    if(EnableCyclicReopen && !IsMarketTooVolatile()) {
        ProcessGridACyclicReopen();
        ProcessGridBCyclicReopen();
    }

    //--- UPDATE INDICATORS ---
    UpdateVolatilityMonitor();
    UpdateADXMonitor();

    //--- v3.0: UPDATE ATR MULTI-TF ---
    UpdateATRMultiTF();

    //--- v3.0: PROCESS PARTIAL TAKE PROFIT ---
    ProcessPartialTPs();

    //--- v3.0: PROCESS TRAILING STOPS ---
    ProcessTrailingStops();

    //--- v3.0: PROCESS ENTRY MODE WAITING (LIMIT/STOP) ---
    ProcessEntryModeWaiting();

    //--- UPDATE EQUITY TRACKING ---
    UpdateEquityTracking();

    //--- UPDATE DASHBOARD ---
    UpdateDashboard();

    //--- CHECK DASHBOARD PERSISTENCE (v3.0 ROBUST) ---
    CheckDashboardPersistence();
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {

    // Process trade events (grid orders)
    OnTradeTransactionHandler(trans, request, result);

    // Process hedge events (only NEUTRAL_RANGEBOX)
    if(IsHedgingAvailable()) {
        OnHedgeTradeTransaction(trans, request, result);
    }
}

//+------------------------------------------------------------------+
//| Timer function (if enabled)                                       |
//+------------------------------------------------------------------+
void OnTimer() {
    // Can be used for periodic tasks like:
    // - ATR recalculation
    // - Dashboard updates
    // - Risk checks
}

//+------------------------------------------------------------------+
//| Chart event function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id, const long &lparam, const double &dparam, const string &sparam) {
    // Handle chart events

    // Object click events (for interactive dashboard)
    if(id == CHARTEVENT_OBJECT_CLICK) {
        HandleObjectClick(sparam);
    }

    // Keyboard events
    if(id == CHARTEVENT_KEYDOWN) {
        HandleKeyPress((int)lparam);
    }

    // v3.0: Handle Manual S/R Drag events
    if(id == CHARTEVENT_OBJECT_DRAG) {
        OnManualSRDrag(sparam);
    }

    // v3.0: Handle object end drag (for precise positioning)
    if(id == CHARTEVENT_OBJECT_ENDEDIT || id == CHARTEVENT_OBJECT_CHANGE) {
        OnManualSREndDrag(lparam, dparam, sparam);
    }

    // v3.0: ROBUST DASHBOARD - Ensure dashboard exists after chart changes
    if(id == CHARTEVENT_CHART_CHANGE) {
        EnsureDashboardOnChartEvent();
    }

    // v3.0: Handle object delete - recreate dashboard if critical object deleted
    if(id == CHARTEVENT_OBJECT_DELETE) {
        if(StringFind(sparam, "TITLE_PANEL") >= 0 ||
           StringFind(sparam, "MODE_PANEL") >= 0 ||
           StringFind(sparam, "LEFT_") >= 0 ||
           StringFind(sparam, "RIGHT_") >= 0) {
            Print("WARNING: Dashboard object deleted externally - scheduling recreation");
            g_dashboardInitialized = false;  // Force recreation on next tick
        }
    }
}

//+------------------------------------------------------------------+
//| Handle Object Click                                               |
//+------------------------------------------------------------------+
void HandleObjectClick(string objectName) {
    // v3.0: Handle new control buttons
    if(StringFind(objectName, "BTN_V3_") == 0 || StringFind(objectName, "SUGAMARA_BTN_") == 0) {
        HandleControlButtonClick(objectName);
        return;
    }

    // Handle button clicks from Dashboard
    if(StringFind(objectName, "BTN_") == 0) {
        HandleButtonClick(objectName);
        return;
    }

    // Legacy support for old object names (if any)
    if(objectName == "SUGAMARA_BTN_EMERGENCY") {
        HandleButtonClick("BTN_EMERGENCY");
    }

    if(objectName == "SUGAMARA_BTN_PAUSE") {
        HandleButtonClick("BTN_PAUSE");
    }
}

//+------------------------------------------------------------------+
//| Handle Key Press                                                  |
//+------------------------------------------------------------------+
void HandleKeyPress(int key) {
    // Hotkeys for quick actions

    // P = Pause/Resume
    if(key == 'P' || key == 'p') {
        if(systemState == STATE_ACTIVE) {
            systemState = STATE_PAUSED;
            LogMessage(LOG_INFO, "System PAUSED (hotkey)");
        } else if(systemState == STATE_PAUSED) {
            systemState = STATE_ACTIVE;
            LogMessage(LOG_INFO, "System RESUMED (hotkey)");
        }
    }

    // R = Risk Report
    if(key == 'R' || key == 'r') {
        LogRiskReport();
    }

    // S = Status Report
    if(key == 'S' || key == 's') {
        LogPositionReport();
    }

    // A = ATR Report
    if(key == 'A' || key == 'a') {
        LogATRReport();
    }

    // N = Toggle News Pause
    if(key == 'N' || key == 'n') {
        SetNewsPause(!isNewsPause);
    }
}

//+------------------------------------------------------------------+
//| Apply Visual Theme v3.0                                           |
//| Sfondo: Amaranto Scuro | Candele: Blu/Giallo                      |
//+------------------------------------------------------------------+
void ApplyVisualTheme() {
    // Apply chart background color (Amaranto Scuro)
    ChartSetInteger(0, CHART_COLOR_BACKGROUND, Theme_ChartBackground);

    // Apply candle colors
    ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, Theme_CandleBull);  // Blu splendente
    ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, Theme_CandleBear);  // Giallo
    ChartSetInteger(0, CHART_COLOR_CHART_UP, Theme_CandleBull);
    ChartSetInteger(0, CHART_COLOR_CHART_DOWN, Theme_CandleBear);

    // Apply grid and axis colors (for black background)
    ChartSetInteger(0, CHART_COLOR_GRID, C'40,40,50');        // Griglia grigio scuro
    ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhite);     // Testo bianco
    ChartSetInteger(0, CHART_COLOR_CHART_LINE, clrCyan);      // Linea chart cyan

    // Apply volume colors
    ChartSetInteger(0, CHART_COLOR_VOLUME, clrDodgerBlue);
    ChartSetInteger(0, CHART_COLOR_ASK, clrRed);
    ChartSetInteger(0, CHART_COLOR_BID, clrLime);

    // Apply last price line
    ChartSetInteger(0, CHART_COLOR_LAST, clrYellow);
    ChartSetInteger(0, CHART_COLOR_STOP_LEVEL, clrRed);

    // Show bid/ask lines
    ChartSetInteger(0, CHART_SHOW_ASK_LINE, true);
    ChartSetInteger(0, CHART_SHOW_BID_LINE, true);

    Print("Visual Theme v3.0 applied: Amaranto Scuro + Blu/Giallo candles");
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Tester function (for Strategy Tester)                             |
//+------------------------------------------------------------------+
double OnTester() {
    // Custom optimization criterion

    // Calculate performance metrics
    double winRate = GetWinRate();
    double profitFactor = GetProfitFactor();
    double maxDD = maxDrawdownReached;

    // Composite score (higher is better)
    // Prioritize: Win Rate (40%), Profit Factor (30%), Low Drawdown (30%)
    double score = 0;

    // Win rate component (target 70%+)
    if(winRate >= 70) score += 40;
    else if(winRate >= 60) score += 30;
    else if(winRate >= 50) score += 20;
    else score += winRate * 0.4;

    // Profit factor component (target 1.5+)
    if(profitFactor >= 2.0) score += 30;
    else if(profitFactor >= 1.5) score += 25;
    else if(profitFactor >= 1.2) score += 20;
    else if(profitFactor >= 1.0) score += 15;
    else score += profitFactor * 10;

    // Drawdown component (target <15%)
    if(maxDD <= 10) score += 30;
    else if(maxDD <= 15) score += 25;
    else if(maxDD <= 20) score += 20;
    else if(maxDD <= 25) score += 15;
    else score += MathMax(0, 30 - maxDD);

    return score;
}

