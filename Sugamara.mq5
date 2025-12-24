//+==================================================================+
//|                                    SUGAMARA RIBELLE v5.1         |
//|                                                                  |
//|   CASCADE SOVRAPPOSTO - Grid A=BUY, Grid B=SELL                  |
//|                                                                  |
//|   "The Spice Must Flow" - DUNE Theme                             |
//|   Ottimizzato per EUR/USD e AUD/NZD                              |
//+------------------------------------------------------------------+
//|  Copyright (C) 2025 - Sugamara Ribelle Development Team          |
//|  Version: 5.1.0 CASCADE SOVRAPPOSTO                              |
//|  Release Date: December 2025                                     |
//+------------------------------------------------------------------+
//|  SISTEMA DOUBLE GRID - CASCADE SOVRAPPOSTO (RIBELLE)             |
//|                                                                  |
//|  Grid A = SOLO ordini BUY (Upper: BUY STOP, Lower: BUY LIMIT)    |
//|  Grid B = SOLO ordini SELL (Upper: SELL LIMIT, Lower: SELL STOP) |
//|  Hedge automatico a 3 pips di distanza                           |
//|                                                                  |
//|  v5.1 FEATURES:                                                  |
//|  - CASCADE_OVERLAP: Grid A=BUY puro, Grid B=SELL puro            |
//|  - Hedge Spacing: 3 pips (STOP <-> LIMIT)                        |
//|  - DUNE/Arrakis Desert Theme                                     |
//|  - Enhanced Logging System                                       |
//|  - Shield 3 Phases Protection                                    |
//|  - Manual S/R Drag & Drop                                        |
//+------------------------------------------------------------------+

#property copyright "Sugamara Ribelle (C) 2025"
#property link      "https://sugamara.com"
#property version   "5.10"
#property description "SUGAMARA RIBELLE v5.1 - CASCADE SOVRAPPOSTO"
#property description "Grid A = SOLO BUY | Grid B = SOLO SELL"
#property description "DUNE Theme - The Spice Must Flow"
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
#include "Core/SessionManager.mqh"  // v4.6 Auto Session

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
#include "Trading/ShieldManager.mqh"

// v3.0 NEW Trading Modules
// PartialTPManager.mqh REMOVED - Dannoso per Cyclic Reopen (v5.x cleanup)

// v5.1 NEW Trading Modules
#include "Trading/CloseOnProfitManager.mqh"

// v4.0 NEW Modules
#include "Utils/DynamicATRAdapter.mqh"
#include "Indicators/CenterCalculator.mqh"

// UI Module
#include "UI/Dashboard.mqh"

// v3.0 NEW UI Modules
#include "UI/ManualSR.mqh"
#include "UI/ControlButtons.mqh"
#include "UI/ShieldZonesVisual.mqh"

// Debug Mode (v4.5)
#include "Core/DebugMode.mqh"

//+------------------------------------------------------------------+
//| Expert initialization function                                    |
//+------------------------------------------------------------------+
int OnInit() {
    //--- STARTUP BANNER (Enhanced Logging v5.1) ---
    LogStartupBanner();
    LogSystem("OnInit() started", true);

    //--- APPLY VISUAL THEME (DUNE Theme) ---
    ApplyVisualTheme();
    LogSystem("Visual theme applied: DUNE/Arrakis");

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

    //--- STEP 10.5: Initialize RangeBox (REMOVED - CASCADE_OVERLAP puro) ---
    // RangeBoxManager eliminato - CASCADE SOVRAPPOSTO non lo richiede

    //--- STEP 10.6: Initialize Hedging (REMOVED - hedge integrato in CASCADE_OVERLAP) ---
    // HedgingManager eliminato - l'hedge è integrato nei LIMIT orders

    //--- STEP 10.7: Initialize Shield Intelligente (CASCADE_OVERLAP mode) ---
    if(IsCascadeOverlapMode() && ShieldMode != SHIELD_DISABLED) {
        if(!InitializeShield()) {
            Print("WARNING: Failed to initialize Shield Intelligente");
        }
        // Calculate breakout levels after grid initialization (will recalc after grids)
    }

    //--- STEP 10.8: Initialize Shield Zones Visual (v3.0) ---
    if(IsCascadeOverlapMode() && Enable_ShieldZonesVisual) {
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

    //--- STEP 13.6: Initialize ATR Multi-TF (v3.0) ---
    if(!InitializeATRMultiTF()) {
        Print("WARNING: Failed to initialize ATR Multi-TF");
    }

    //--- STEP 13.8: Partial TP Manager REMOVED (v5.x cleanup) ---
    // Dannoso per Cyclic Reopen - riduce profit del 37%

    //--- STEP 13.8b: Initialize Close On Profit (v5.1) ---
    InitializeCloseOnProfit();

    //--- STEP 13.9: Initialize Trailing Manager (REMOVED - CASCADE_OVERLAP puro) ---
    // GridTrailingManager eliminato - non necessario per CASCADE SOVRAPPOSTO

    //--- STEP 13.10: Initialize Manual S/R (v3.0) ---
    if(!InitializeManualSR()) {
        Print("WARNING: Failed to initialize Manual S/R");
    }

    //--- STEP 13.11: Initialize Dynamic ATR Adapter (v4.0) ---
    if(EnableDynamicATRSpacing && NeutralMode != NEUTRAL_PURE) {
        if(!InitializeDynamicATRAdapter()) {
            Print("WARNING: Failed to initialize Dynamic ATR Adapter");
        }
    }

    //--- STEP 13.12: Initialize Center Calculator (v4.0) ---
    if(EnableAutoRecenter || ShowCenterIndicators) {
        if(!InitializeCenterCalculator()) {
            Print("WARNING: Failed to initialize Center Calculator");
        }
    }

    //--- STEP 13.13: Initialize Recenter Manager (REMOVED - CASCADE_OVERLAP puro) ---
    // GridRecenterManager eliminato - non necessario per CASCADE SOVRAPPOSTO

    //--- STEP 13.14: Initialize Debug Mode (v4.5) ---
    if(!InitializeDebugMode()) {
        Print("CRITICAL: Failed to initialize Debug Mode");
        return(INIT_FAILED);
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

    //--- STEP 17.3: Sync RangeBox with Grid Levels (REMOVED - CASCADE_OVERLAP) ---
    // RangeBoxManager eliminato

    //--- STEP 17.5: Calculate Breakout Levels for Shield (REMOVED) ---
    // CalculateBreakoutLevels eliminato con RangeBoxManager

    //--- STEP 18: Place Initial Orders ---
    // v4.4: Control Buttons ALWAYS active - wait for START button click
    Print("");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  GRID ORDERS ON STANDBY - WAITING FOR START BUTTON");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  Click START button to place grid orders");
    systemState = STATE_IDLE;

    //--- STEP 19: Draw Grid Visualization ---
    DrawGridVisualization();

    //--- STEP 20: Log Final Configuration ---
    PrintSystemConfiguration();
    LogATRReport();

    //--- INITIALIZATION COMPLETE ---
    // systemState already set above based on Enable_AdvancedButtons

    Print("");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  SUGAMARA RIBELLE v5.1 INITIALIZATION COMPLETE");
    Print("  Mode: ", GetModeName(), IsCascadeOverlapMode() ? " (CASCADE SOVRAPPOSTO)" : "");
    Print("  System State: IDLE (Click START)");
    Print("  Grid A Orders: ", GetGridAPendingOrders() + GetGridAActivePositions(), IsCascadeOverlapMode() ? " [SOLO BUY]" : "");
    Print("  Grid B Orders: ", GetGridBPendingOrders() + GetGridBActivePositions(), IsCascadeOverlapMode() ? " [SOLO SELL]" : "");
    if(IsCascadeOverlapMode() && ShieldMode != SHIELD_DISABLED) {
        Print("  Shield Mode: ", GetShieldModeName());
        Print("  Upper Breakout: ", DoubleToString(upperBreakoutLevel, symbolDigits));
        Print("  Lower Breakout: ", DoubleToString(lowerBreakoutLevel, symbolDigits));
    }
    Print("───────────────────────────────────────────────────────────────────");
    Print("  v5.1 FEATURES:");
    if(IsCascadeOverlapMode()) {
        Print("  ✅ CASCADE_OVERLAP: Grid A=BUY, Grid B=SELL");
        Print("  ✅ Hedge Spacing: ", DoubleToString(Hedge_Spacing_Pips, 1), " pips");
    }
    // Partial TP REMOVED - v5.x cleanup
    Print("  ✅ ATR Multi-TF: ", Enable_ATRMultiTF ? "ENABLED" : "DISABLED");
    Print("  ✅ Manual S/R: ", Enable_ManualSR ? "ENABLED" : "DISABLED");
    Print("  ✅ Control Buttons: ALWAYS ACTIVE");
    Print("  ✅ Break On Profit: ", Enable_BreakOnProfit ? "ENABLED" : "DISABLED");
    Print("  ✅ Close On Profit: ", Enable_CloseOnProfit ? ("ENABLED ($" + DoubleToString(COP_DailyTarget_USD, 2) + " daily target)") : "DISABLED");
    Print("───────────────────────────────────────────────────────────────────");
    Print("  ATR/SPACING FEATURES:");
    Print("  ✅ Dynamic ATR Spacing: ", (EnableDynamicATRSpacing && NeutralMode != NEUTRAL_PURE) ? "ENABLED" : "DISABLED");
    if(EnableDynamicATRSpacing && NeutralMode != NEUTRAL_PURE) {
        Print("     ATR Step: ", GetATRStepName(currentATRStep));
        Print("     Current Spacing: ", DoubleToString(GetDynamicSpacing(), 1), " pips");
    }
    Print("  ✅ Center Indicators: ", ShowCenterIndicators ? "ENABLED" : "DISABLED");
    Print("  ✅ Auto-Recenter: ", EnableAutoRecenter ? "ENABLED" : "DISABLED");
    // ATR Extreme Warning REMOVED - v5.x cleanup (ridondante con Shield)
    Print("  ✅ ATR Alert on Spacing: ", ATR_AlertOnSpacingChange ? "ENABLED" : "DISABLED");
    Print("═══════════════════════════════════════════════════════════════════");

    //--- v4.1: Setup Timer with dynamic interval (uses user parameter) ---
    int timerInterval = MathMax(ATR_CheckInterval_Seconds, 60);
    EventSetTimer(timerInterval);
    Print("[TIMER] Set to ", timerInterval, " seconds (ATR_CheckInterval_Seconds = ", ATR_CheckInterval_Seconds, ")");

    //--- v4.2: Log ATR Dynamic Spacing Configuration ---
    if(EnableDynamicATRSpacing && ATR_DetailedLogging && NeutralMode != NEUTRAL_PURE) {
        Print("");
        Print("╔══════════════════════════════════════════════════════════════╗");
        Print("║          ATR DYNAMIC SPACING INITIALIZED v4.2                ║");
        Print("╠══════════════════════════════════════════════════════════════╣");
        Print("║  Check Interval: ", ATR_CheckInterval_Seconds, " seconds");
        Print("║  Min Time Between Changes: ", ATR_MinTimeBetweenChanges, " seconds");
        Print("║  Step Change Threshold: ", DoubleToString(ATR_StepChangeThreshold, 1), "%");
        Print("║  Timeframe: ", EnumToString(ATR_Timeframe));
        Print("║  Detailed Logging: ", ATR_DetailedLogging ? "ON" : "OFF");
        Print("║  Alert on Change: ", ATR_AlertOnSpacingChange ? "ON" : "OFF");
        Print("╠══════════════════════════════════════════════════════════════╣");
        Print("║  SOGLIE ATR (pips):");
        Print("║    VERY_LOW: < ", DoubleToString(ATR_Threshold_VeryLow, 1), " -> ", DoubleToString(Spacing_VeryLow_Pips, 1), " pips spacing");
        Print("║    LOW: < ", DoubleToString(ATR_Threshold_Low, 1), " -> ", DoubleToString(Spacing_Low_Pips, 1), " pips spacing");
        Print("║    NORMAL: < ", DoubleToString(ATR_Threshold_Normal, 1), " -> ", DoubleToString(Spacing_Normal_Pips, 1), " pips spacing");
        Print("║    HIGH: < ", DoubleToString(ATR_Threshold_High, 1), " -> ", DoubleToString(Spacing_High_Pips, 1), " pips spacing");
        Print("║    EXTREME: >= ", DoubleToString(ATR_Threshold_High, 1), " -> ", DoubleToString(Spacing_Extreme_Pips, 1), " pips spacing");
        Print("╚══════════════════════════════════════════════════════════════╝");
        Print("");
    }

    //--- v4.6: Initialize Session Manager ---
    InitializeSessionManager();

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

    // v3.0: Deinitialize new modules
    DeinitializeATRMultiTF();
    // DeinitializePartialTPManager(); // REMOVED - v5.x cleanup
    // DeinitializeTrailingManager(); // REMOVED - GridTrailingManager eliminato
    DeinitializeManualSR();

    // v5.1: Reset and Deinitialize COP
    COP_ResetDaily();  // Reset COP counter on EA removal/chart close
    DeinitializeCloseOnProfit();

    // v4.0: Deinitialize new modules
    if(ShowCenterIndicators || EnableAutoRecenter) {
        DeinitializeCenterCalculator();
    }

    // v4.0: Kill timer
    EventKillTimer();

    // v3.0: Smart UI cleanup - Don't remove UI on recompile/terminal close
    // The UI will be automatically recreated on next initialization
    if(shouldCleanUI) {
        Print("Cleaning up UI objects...");
        DeinitializeControlButtons();
        DeinitializeShieldZonesVisual();
        CleanupUI();

        // Clean up RangeBox visualization (REMOVED - CASCADE_OVERLAP puro)
        // RangeBoxManager eliminato
    } else {
        Print("Preserving UI objects for quick restart...");
        // Reset initialization flag so dashboard will be verified on restart
        g_dashboardInitialized = false;
    }

    // Deinitialize Shield (logic only, not visual)
    if(ShieldMode != SHIELD_DISABLED) {
        DeinitializeShield();
        // DeinitializeRangeBoxShield(); // REMOVED - RangeBoxManager eliminato
    }

    // Note: We do NOT close orders on deinit - they should persist
    // Only close if explicitly requested or on critical error

    Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Expert tick function                                              |
//+------------------------------------------------------------------+
void OnTick() {
    // DEBUG MODE: Check and trigger automatic entry (MUST be FIRST)
    CheckDebugModeEntry();

    // DEBUG MODE: Check for scheduled close (intraday exit)
    CheckDebugModeClose();

    // v4.6: SESSION MANAGER - Check for auto close at session end
    CheckSessionClose();

    // v4.6: SESSION MANAGER - Skip trading if outside session hours
    if(!IsWithinTradingSession()) {
        // Only update dashboard during idle (no trading actions)
        UpdateDashboard();
        return;
    }

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

    //--- v4.1: ATR EXTREME WARNING REMOVED (v5.x cleanup) ---
    // Ridondante con Shield + Max Net Exposure

    //--- UPDATE POSITION STATUSES ---
    MonitorPositions();

    //--- RANGEBOX: (REMOVED - CASCADE_OVERLAP puro) ---
    // RangeBoxManager eliminato

    //--- HEDGING: (REMOVED - hedge integrato in LIMIT orders) ---
    // HedgingManager eliminato

    //--- SHIELD: Process Shield Intelligente ---
    // Shield ora gestito direttamente senza RangeBox
    if(ShieldMode != SHIELD_DISABLED) {
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

    //--- v3.0: UPDATE ATR MULTI-TF ---
    UpdateATRMultiTF();

    //--- v3.0: PARTIAL TAKE PROFIT REMOVED (v5.x cleanup) ---
    // ProcessPartialTPs(); // Dannoso per Cyclic Reopen

    //--- v5.1: BREAK ON PROFIT (BOP) ---
    CheckBreakOnProfit();

    //--- v5.1: CLOSE ON PROFIT (COP) - Check Daily Target ---
    if(COP_CheckTarget()) {
        // Target reached - system will be paused if COP_PauseTrading is enabled
        return;
    }

    //--- v3.0: PROCESS TRAILING STOPS (REMOVED - CASCADE_OVERLAP puro) ---
    // ProcessTrailingStops(); // GridTrailingManager eliminato

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

    // Process hedge events (REMOVED - hedge integrato in LIMIT orders CASCADE_OVERLAP)
    // OnHedgeTradeTransaction eliminato con HedgingManager
}

//+------------------------------------------------------------------+
//| Timer function (v4.0 enhanced)                                    |
//+------------------------------------------------------------------+
void OnTimer() {
    // Skip if system not active
    if(systemState != STATE_ACTIVE) return;

    // ═══════════════════════════════════════════════════════════════════
    // v4.0: ATR Dynamic Spacing Check
    // ═══════════════════════════════════════════════════════════════════
    if(EnableDynamicATRSpacing && NeutralMode != NEUTRAL_PURE) {
        CheckAndAdaptATRSpacing();
    }

    // ═══════════════════════════════════════════════════════════════════
    // v4.0: Center Indicators Update (every 5 minutes)
    // ═══════════════════════════════════════════════════════════════════
    static datetime lastCenterUpdate = 0;
    if(TimeCurrent() - lastCenterUpdate >= 300) {
        if(ShowCenterIndicators || EnableAutoRecenter) {
            UpdateCenterIndicators();
        }
        lastCenterUpdate = TimeCurrent();
    }

    // ═══════════════════════════════════════════════════════════════════
    // v4.0: Auto-Recenter Check (REMOVED - CASCADE_OVERLAP puro)
    // ═══════════════════════════════════════════════════════════════════
    // GridRecenterManager eliminato
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
        // v4.0: Handle center indicators deleted externally
        if(StringFind(sparam, "CENTER_") >= 0 && ShowCenterIndicators) {
            DrawCenterIndicators();  // Redraw
        }
    }
}

//+------------------------------------------------------------------+
//| Handle v4.0 Recenter Button Click (REMOVED - CASCADE_OVERLAP puro)|
//+------------------------------------------------------------------+
void HandleRecenterButtonClick(string objectName) {
    // GridRecenterManager eliminato - funzioni non disponibili
    Print("Recenter functionality removed in CASCADE_OVERLAP mode");
}

//+------------------------------------------------------------------+
//| Handle Object Click                                               |
//+------------------------------------------------------------------+
void HandleObjectClick(string objectName) {
    // v4.0: Handle recenter buttons
    if(StringFind(objectName, "RECENTER") >= 0) {
        HandleRecenterButtonClick(objectName);
        return;
    }

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

    // V = v4.0 Full Status Report
    if(key == 'V' || key == 'v') {
        LogV4StatusReport();
    }

    // D = Dynamic ATR Report
    if(key == 'D' || key == 'd') {
        if(IsATRDynamicAvailable()) {
            LogATRDynamicReport();
        } else {
            Print("Dynamic ATR Spacing not available (PURE mode or disabled)");
        }
    }

    // C = Center Indicators Report
    if(key == 'C' || key == 'c') {
        if(ShowCenterIndicators || EnableAutoRecenter) {
            LogCenterIndicatorsReport();
        } else {
            Print("Center Indicators not available (disabled)");
        }
    }

    // E = Recenter Status Report (REMOVED - CASCADE_OVERLAP puro)
    if(key == 'E' || key == 'e') {
        Print("Auto-Recenter removed in CASCADE_OVERLAP mode");
    }
}

//+------------------------------------------------------------------+
//| LOG v5.1 COMPLETE STATUS REPORT                                   |
//| Master report combining all v5.1 modules                          |
//+------------------------------------------------------------------+
void LogV4StatusReport() {
    Print("");
    Print("╔═══════════════════════════════════════════════════════════════════╗");
    Print("║       SUGAMARA RIBELLE v5.1 - COMPLETE STATUS REPORT              ║");
    Print("║       Generated: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS), "                      ║");
    Print("╚═══════════════════════════════════════════════════════════════════╝");
    Print("");

    // System Overview
    Print("┌─────────────────────────────────────────────────────────────────┐");
    Print("│  SYSTEM OVERVIEW                                                │");
    Print("├─────────────────────────────────────────────────────────────────┤");
    Print("│  Mode: ", EnumToString(NeutralMode));
    Print("│  State: ", EnumToString(systemState));
    Print("│  Entry Point: ", DoubleToString(entryPoint, symbolDigits));
    Print("│  Current Price: ", DoubleToString(SymbolInfoDouble(_Symbol, SYMBOL_BID), symbolDigits));
    Print("│  Current Spacing: ", DoubleToString(GetDynamicSpacing(), 1), " pips");
    Print("└─────────────────────────────────────────────────────────────────┘");
    Print("");

    // v5.1 Modules Status
    Print("┌─────────────────────────────────────────────────────────────────┐");
    Print("│  v5.1 MODULES STATUS                                            │");
    Print("├─────────────────────────────────────────────────────────────────┤");
    if(IsCascadeOverlapMode()) {
        Print("│  🎯 CASCADE_OVERLAP: Grid A=BUY, Grid B=SELL");
        Print("│      Hedge Spacing: ", DoubleToString(Hedge_Spacing_Pips, 1), " pips");
    }

    // ATR Dynamic Spacing
    if(NeutralMode == NEUTRAL_PURE) {
        Print("│  🔄 ATR Dynamic Spacing: N/A (PURE mode - fixed spacing)");
    } else if(EnableDynamicATRSpacing) {
        Print("│  🔄 ATR Dynamic Spacing: ACTIVE");
        Print("│      Step: ", GetATRStepName(currentATRStep),
              " | ATR: ", DoubleToString(GetATRInPips(), 1), " pips");
        Print("│      Spacing: ", DoubleToString(GetDynamicSpacing(), 1), " pips");
    } else {
        Print("│  🔄 ATR Dynamic Spacing: DISABLED");
    }

    // Center Indicators
    if(ShowCenterIndicators || EnableAutoRecenter) {
        Print("│  🎯 Center Indicators: ACTIVE");
        if(g_centerCalc.isValid) {
            Print("│      Optimal Center: ", DoubleToString(g_centerCalc.optimalCenter, symbolDigits));
            Print("│      Confidence: ", DoubleToString(g_centerCalc.confidence, 1), "%");
        } else {
            Print("│      Status: Calculating...");
        }
    } else {
        Print("│  🎯 Center Indicators: DISABLED");
    }

    // Auto-Recenter (REMOVED - CASCADE_OVERLAP puro)
    Print("│  🔁 Auto-Recenter: REMOVED (CASCADE_OVERLAP mode)");

    Print("└─────────────────────────────────────────────────────────────────┘");
    Print("");

    // Hotkeys reminder
    Print("┌─────────────────────────────────────────────────────────────────┐");
    Print("│  v5.1 HOTKEYS                                                   │");
    Print("├─────────────────────────────────────────────────────────────────┤");
    Print("│  V = This report (v5.1 Full Status)                             │");
    Print("│  D = Dynamic ATR Spacing detailed report                        │");
    Print("│  C = Center Indicators detailed report                          │");
    Print("└─────────────────────────────────────────────────────────────────┘");
    Print("");
}

//+------------------------------------------------------------------+
//| Apply Visual Theme v5.1 - DUNE/Arrakis Desert Theme               |
//| Sfondo: Desert Night | Candele: Spice Orange/Fremen Blue          |
//+------------------------------------------------------------------+
void ApplyVisualTheme() {
    // Apply chart background color (Deep Desert Night)
    ChartSetInteger(0, CHART_COLOR_BACKGROUND, Theme_ChartBackground);

    // Apply candle colors (DUNE Theme)
    ChartSetInteger(0, CHART_COLOR_CANDLE_BULL, Theme_CandleBull);  // Spice Orange
    ChartSetInteger(0, CHART_COLOR_CANDLE_BEAR, Theme_CandleBear);  // Fremen Blue
    ChartSetInteger(0, CHART_COLOR_CHART_UP, Theme_CandleBull);
    ChartSetInteger(0, CHART_COLOR_CHART_DOWN, Theme_CandleBear);

    // Hide grid and apply axis colors
    ChartSetInteger(0, CHART_SHOW_GRID, false);               // No grid (clean desert)
    ChartSetInteger(0, CHART_COLOR_FOREGROUND, clrWhite);     // Sand text
    ChartSetInteger(0, CHART_COLOR_CHART_LINE, clrCyan);      // Fremen blue line

    // v5.3: Hide volume bars (user requested removal of blue bars at bottom)
    ChartSetInteger(0, CHART_SHOW_VOLUMES, CHART_VOLUME_HIDE);

    // Apply volume colors (kept for if user re-enables volumes)
    ChartSetInteger(0, CHART_COLOR_VOLUME, clrDodgerBlue);
    ChartSetInteger(0, CHART_COLOR_ASK, clrRed);
    ChartSetInteger(0, CHART_COLOR_BID, clrLime);

    // Apply last price line
    ChartSetInteger(0, CHART_COLOR_LAST, clrYellow);
    ChartSetInteger(0, CHART_COLOR_STOP_LEVEL, clrRed);

    // Show bid/ask lines
    ChartSetInteger(0, CHART_SHOW_ASK_LINE, true);
    ChartSetInteger(0, CHART_SHOW_BID_LINE, true);

    Print("Visual Theme v5.1 applied: DUNE/Arrakis Desert Theme (The Spice Must Flow)");
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

