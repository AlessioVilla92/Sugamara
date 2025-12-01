//+==================================================================+
//|                                              Sugamara v1.0.0.mq5 |
//|                                                                  |
//|   SUGAMARA - DOUBLE GRID NEUTRAL                                 |
//|                                                                  |
//|   Market Neutral • Bidirezionale • Zero Prediction              |
//|   Ottimizzato per EUR/USD e AUD/NZD                             |
//+------------------------------------------------------------------+
//|  Copyright (C) 2025 - Sugamara Development Team                 |
//|  Version: 1.0.0                                                 |
//|  Release Date: December 2025                                    |
//+------------------------------------------------------------------+
//|  SISTEMA DOUBLE GRID NEUTRAL CASCADE                            |
//|  - Grid A (Long Bias): Accumula LONG in salita                  |
//|  - Grid B (Short Bias): Accumula SHORT in salita                |
//|  - Auto-Hedging: Protezione intrinseca tramite grid speculari   |
//|  - Adaptive Spacing: Distanza ordini gestita da ATR             |
//|  - Perfect Cascade: TP = Entry del livello successivo           |
//+------------------------------------------------------------------+

#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"
#property version   "1.00"
#property description "SUGAMARA - Double Grid Neutral"
#property description "Market Neutral System - Auto-Hedged"
#property description "Optimized for EUR/USD and AUD/NZD"
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

// Utility Modules
#include "Utils/Helpers.mqh"
#include "Utils/GridHelpers.mqh"
#include "Utils/ATRCalculator.mqh"

// Trading Modules
#include "Trading/OrderManager.mqh"
#include "Trading/GridASystem.mqh"
#include "Trading/GridBSystem.mqh"
#include "Trading/PositionMonitor.mqh"
#include "Trading/RiskManager.mqh"

// UI Module
#include "UI/Dashboard.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  SUGAMARA v1.0.0 - DOUBLE GRID NEUTRAL                           ");
    Print("  Market Neutral • Bidirezionale • Zero Prediction               ");
    Print("  Copyright (C) 2025 - Sugamara Development Team                 ");
    Print("═══════════════════════════════════════════════════════════════════");

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

    //--- STEP 9: Calculate Spacing ---
    currentSpacing_Pips = GetOptimalSpacing();
    Print("Initial Spacing: ", DoubleToString(currentSpacing_Pips, 1), " pips");

    //--- STEP 10: Calculate Range Boundaries ---
    CalculateRangeBoundaries();

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
    Print("  SUGAMARA INITIALIZATION COMPLETE");
    Print("  System State: ACTIVE");
    Print("  Grid A Orders: ", GetGridAPendingOrders() + GetGridAActivePositions());
    Print("  Grid B Orders: ", GetGridBPendingOrders() + GetGridBActivePositions());
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
    switch(reason) {
        case REASON_PROGRAM:     reasonText = "EA removed"; break;
        case REASON_REMOVE:      reasonText = "EA removed from chart"; break;
        case REASON_RECOMPILE:   reasonText = "EA recompiled"; break;
        case REASON_CHARTCHANGE: reasonText = "Chart symbol/period changed"; break;
        case REASON_CHARTCLOSE:  reasonText = "Chart closed"; break;
        case REASON_PARAMETERS:  reasonText = "Parameters changed"; break;
        case REASON_ACCOUNT:     reasonText = "Account changed"; break;
        case REASON_TEMPLATE:    reasonText = "Template applied"; break;
        case REASON_INITFAILED:  reasonText = "Initialization failed"; break;
        case REASON_CLOSE:       reasonText = "Terminal closed"; break;
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

    // Clean up UI
    CleanupUI();

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

    //--- CHECK ATR RECALCULATION ---
    if(UpdateATRAndCheckAdjustment()) {
        // ATR changed significantly - may need to adjust grid
        double newSpacing = GetOptimalSpacing();

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

    //--- UPDATE EQUITY TRACKING ---
    UpdateEquityTracking();

    //--- UPDATE DASHBOARD ---
    UpdateDashboard();
}

//+------------------------------------------------------------------+
//| Trade transaction handler                                         |
//+------------------------------------------------------------------+
void OnTradeTransaction(const MqlTradeTransaction& trans,
                        const MqlTradeRequest& request,
                        const MqlTradeResult& result) {

    // Process trade events
    OnTradeTransactionHandler(trans, request, result);
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
}

//+------------------------------------------------------------------+
//| Handle Object Click                                               |
//+------------------------------------------------------------------+
void HandleObjectClick(string objectName) {
    // Can add interactive buttons to dashboard

    // Example: Emergency close button
    if(objectName == "SUGAMARA_BTN_EMERGENCY") {
        if(EnableAlerts) {
            int result = MessageBox("Close ALL positions?", "SUGAMARA Emergency", MB_YESNO | MB_ICONWARNING);
            if(result == IDYES) {
                EmergencyCloseAll();
            }
        }
    }

    // Example: Toggle pause
    if(objectName == "SUGAMARA_BTN_PAUSE") {
        if(systemState == STATE_ACTIVE) {
            systemState = STATE_PAUSED;
            LogMessage(LOG_INFO, "System PAUSED by user");
        } else if(systemState == STATE_PAUSED) {
            systemState = STATE_ACTIVE;
            LogMessage(LOG_INFO, "System RESUMED by user");
        }
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

