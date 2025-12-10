//+------------------------------------------------------------------+
//|                                        GridRecenterManager.mqh   |
//|                        Sugamara v4.0 - Auto Grid Recenter        |
//|                                                                  |
//|  Sistema ricentramento automatico della griglia basato su:       |
//|  - Centro Ottimale (Pivot + EMA + Donchian)                      |
//|  - Condizioni di sicurezza (10 check)                            |
//|  - Conferma utente opzionale                                     |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Initialize Recenter Manager                                       |
//+------------------------------------------------------------------+
bool InitializeRecenterManager() {
    if(!EnableAutoRecenter) {
        Print("RecenterManager: DISABLED by user settings");
        return true;
    }

    // Initialize state
    g_lastRecenterTime = 0;
    g_lastRecenterCheck = 0;
    g_recenterCount = 0;
    g_recenterPending = false;

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  RecenterManager v4.0 INITIALIZED");
    Print("  User Confirm Required: ", RequireUserConfirm ? "YES" : "NO");
    Print("  Min Interval: ", Recenter_MinInterval_Minutes, " minutes");
    Print("  Price Proximity: ", DoubleToString(Recenter_PriceProximity_Pips, 1), " pips");
    Print("  Entry Distance: ", DoubleToString(Recenter_EntryDistance_Pips, 1), " pips");
    Print("═══════════════════════════════════════════════════════════════════");

    return true;
}

//+------------------------------------------------------------------+
//| Check Recenter Conditions                                         |
//| Returns true if all conditions are met for recenter               |
//+------------------------------------------------------------------+
bool CheckRecenterConditions(string &reason) {
    if(!EnableAutoRecenter) {
        reason = "Disabled";
        return false;
    }

    // Get current price and optimal center
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double optimalCenter = GetOptimalCenter();

    if(optimalCenter <= 0) {
        reason = "Invalid optimal center";
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONDITION 1: Price must be near optimal center
    // ═══════════════════════════════════════════════════════════════════
    double priceDistancePips = MathAbs(currentPrice - optimalCenter) / PipsToPoints(1);
    if(priceDistancePips > Recenter_PriceProximity_Pips) {
        reason = StringFormat("Price too far from center (%.1f pips > %.1f)",
                              priceDistancePips, Recenter_PriceProximity_Pips);
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONDITION 2: Current entry must be far from optimal center
    // ═══════════════════════════════════════════════════════════════════
    double entryDistancePips = MathAbs(entryPoint - optimalCenter) / PipsToPoints(1);
    if(entryDistancePips < Recenter_EntryDistance_Pips) {
        reason = StringFormat("Entry already near center (%.1f pips < %.1f)",
                              entryDistancePips, Recenter_EntryDistance_Pips);
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONDITION 3: Minimum confidence from indicators
    // ═══════════════════════════════════════════════════════════════════
    double confidence = GetCenterConfidence();
    if(confidence < Recenter_MinConfidence) {
        reason = StringFormat("Low confidence (%.1f%% < %.1f%%)",
                              confidence, Recenter_MinConfidence);
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONDITION 4: Check floating loss (USD)
    // ═══════════════════════════════════════════════════════════════════
    double floatingPL = GetTotalOpenProfit();
    if(floatingPL < -Recenter_MaxFloatingLoss_USD) {
        reason = StringFormat("Floating loss too high ($%.2f > $%.2f)",
                              MathAbs(floatingPL), Recenter_MaxFloatingLoss_USD);
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONDITION 5: Check floating loss (%)
    // ═══════════════════════════════════════════════════════════════════
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);
    double floatingPct = MathAbs(floatingPL) / equity * 100;
    if(floatingPL < 0 && floatingPct > Recenter_MaxFloatingLoss_Pct) {
        reason = StringFormat("Floating loss too high (%.2f%% > %.2f%%)",
                              floatingPct, Recenter_MaxFloatingLoss_Pct);
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONDITION 6: Minimum interval between recenters
    // ═══════════════════════════════════════════════════════════════════
    datetime now = TimeCurrent();
    if(g_lastRecenterTime > 0) {
        int minutesSinceLastRecenter = (int)((now - g_lastRecenterTime) / 60);
        if(minutesSinceLastRecenter < Recenter_MinInterval_Minutes) {
            reason = StringFormat("Cooldown active (%d min < %d min)",
                                  minutesSinceLastRecenter, Recenter_MinInterval_Minutes);
            return false;
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONDITION 7: Only on new bar (optional)
    // ═══════════════════════════════════════════════════════════════════
    if(Recenter_OnlyOnNewBar) {
        static datetime lastBarTime = 0;
        datetime currentBarTime = iTime(_Symbol, PERIOD_M15, 0);
        if(currentBarTime == lastBarTime) {
            reason = "Waiting for new M15 bar";
            return false;
        }
        lastBarTime = currentBarTime;
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONDITION 8: Block if Shield is active or near activation
    // ═══════════════════════════════════════════════════════════════════
    if(BlockRecenterNearShield && IsRangeBoxAvailable()) {
        if(shield.isActive) {
            reason = "Shield is active";
            return false;
        }
        if(shield.phase >= PHASE_WARNING) {
            reason = "Shield in warning/pre-shield phase";
            return false;
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONDITION 9: Block on strong trend
    // ═══════════════════════════════════════════════════════════════════
    if(BlockRecenterOnTrend && EnableADXMonitor) {
        if(adxValue_Immediate > TrendADX_Threshold) {
            reason = StringFormat("Strong trend detected (ADX %.1f > %.1f)",
                                  adxValue_Immediate, TrendADX_Threshold);
            return false;
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // CONDITION 10: Block on extreme volatility
    // ═══════════════════════════════════════════════════════════════════
    if(BlockRecenterHighVolatility) {
        if(currentATRStep == ATR_STEP_EXTREME ||
           currentATR_Condition == ATR_EXTREME) {
            reason = "Extreme volatility detected";
            return false;
        }
    }

    // All conditions passed!
    reason = "All conditions met";
    return true;
}

//+------------------------------------------------------------------+
//| Check and Recenter Grid (called from OnTimer)                     |
//+------------------------------------------------------------------+
void CheckAndRecenterGrid() {
    if(!EnableAutoRecenter) return;

    // Throttle checks
    datetime now = TimeCurrent();
    if(now - g_lastRecenterCheck < 60) return;  // Check max once per minute
    g_lastRecenterCheck = now;

    // If pending confirmation, don't check again
    if(g_recenterPending) return;

    // Log detailed conditions check
    LogConditionsCheck();

    // Check conditions
    string reason;
    if(!CheckRecenterConditions(reason)) {
        if(DetailedLogging) {
            Print("Recenter blocked: ", reason);
        }
        return;
    }

    // All conditions met!
    double newCenter = GetOptimalCenter();

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  AUTO-RECENTER CONDITIONS MET!");
    Print("  Current Entry: ", DoubleToString(entryPoint, symbolDigits));
    Print("  New Optimal Center: ", DoubleToString(newCenter, symbolDigits));
    Print("  Distance: ", DoubleToString(MathAbs(entryPoint - newCenter) / PipsToPoints(1), 1), " pips");
    Print("═══════════════════════════════════════════════════════════════════");

    if(RequireUserConfirm) {
        // Set pending flag and wait for user confirmation
        g_recenterPending = true;
        if(EnableAlerts) {
            Alert("SUGAMARA: Auto-Recenter ready! Click CONFIRM to proceed or CANCEL to abort.");
        }
        Print("Waiting for user confirmation... (Use CONFIRM/CANCEL buttons)");
        // UI buttons will call ConfirmPendingRecenter() or CancelPendingRecenter()
    } else {
        // Execute immediately
        ExecuteGridRecenter(newCenter);
    }
}

//+------------------------------------------------------------------+
//| Execute Grid Recenter                                             |
//| CRITICAL: This resets the entire grid system!                     |
//+------------------------------------------------------------------+
bool ExecuteGridRecenter(double newEntryPoint) {
    // Store old entry for logging
    double oldEntry = entryPoint;

    // STEP 1: Close all Grid A positions
    Print("Step 1: Closing Grid A positions...");
    int closedA = CloseAllGridAPositions();

    // STEP 2: Close all Grid B positions
    Print("Step 2: Closing Grid B positions...");
    int closedB = CloseAllGridBPositions();

    // STEP 3: Cancel all pending orders
    Print("Step 3: Canceling pending orders...");
    int canceledA = CancelAllGridAPendingOrders();
    int canceledB = CancelAllGridBPendingOrders();

    Print("Closed: ", closedA + closedB, " positions, Canceled: ", canceledA + canceledB, " pending");

    // STEP 4: Update entry point
    entryPoint = NormalizeDouble(newEntryPoint, symbolDigits);
    entryPointTime = TimeCurrent();

    // STEP 5: Recalculate spacing (may have changed)
    currentSpacing_Pips = GetDynamicSpacing();

    // STEP 6: Recalculate range boundaries
    CalculateRangeBoundaries();

    // STEP 7: Reset and reinitialize Grid arrays
    ResetGridArrays();

    // STEP 8: Initialize Grid A with new entry point
    Print("Step 8: Initializing new Grid A...");
    if(!InitializeGridA()) {
        Print("ERROR: Failed to reinitialize Grid A");
        return false;
    }

    // STEP 9: Initialize Grid B with new entry point
    Print("Step 9: Initializing new Grid B...");
    if(!InitializeGridB()) {
        Print("ERROR: Failed to reinitialize Grid B");
        return false;
    }

    // STEP 10: Sync grids if enabled
    if(SyncGridAB) {
        SyncGridBWithGridA();
    }

    // STEP 11: Place new orders
    Print("Step 11: Placing new grid orders...");
    bool gridAPlaced = PlaceAllGridAOrders();
    bool gridBPlaced = PlaceAllGridBOrders();

    // STEP 12: Update RangeBox and Shield if applicable
    if(IsRangeBoxAvailable()) {
        SyncRangeBoxWithGrid();
        if(ShieldMode != SHIELD_DISABLED) {
            CalculateBreakoutLevels();
        }
    }

    // STEP 13: Update visualization
    if(ShowGridLines) {
        DrawGridVisualization();
    }
    if(ShowCenterIndicators) {
        DrawCenterIndicators();
    }

    // Update state
    g_lastRecenterTime = TimeCurrent();
    g_recenterCount++;
    g_recenterPending = false;

    // Log detailed execution summary
    bool success = gridAPlaced && gridBPlaced;
    LogRecenterExecution(oldEntry, entryPoint, closedA + closedB, canceledA + canceledB, success);

    if(EnableAlerts) {
        Alert("SUGAMARA: Grid recentered to ", DoubleToString(entryPoint, symbolDigits));
    }

    return success;
}

//+------------------------------------------------------------------+
//| Confirm Pending Recenter (called from UI button)                  |
//+------------------------------------------------------------------+
void ConfirmPendingRecenter() {
    if(!g_recenterPending) {
        Print("No pending recenter to confirm");
        return;
    }

    double newCenter = GetOptimalCenter();
    ExecuteGridRecenter(newCenter);
}

//+------------------------------------------------------------------+
//| Cancel Pending Recenter (called from UI button)                   |
//+------------------------------------------------------------------+
void CancelPendingRecenter() {
    if(!g_recenterPending) {
        Print("No pending recenter to cancel");
        return;
    }

    g_recenterPending = false;
    Print("Pending recenter CANCELED by user");

    if(EnableAlerts) {
        Alert("SUGAMARA: Auto-Recenter canceled");
    }
}

//+------------------------------------------------------------------+
//| Close All Grid A Positions                                        |
//+------------------------------------------------------------------+
int CloseAllGridAPositions() {
    int closed = 0;

    // Upper zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Status[i] == ORDER_FILLED && gridA_Upper_Tickets[i] > 0) {
            if(ClosePosition(gridA_Upper_Tickets[i])) {
                gridA_Upper_Status[i] = ORDER_CLOSED;
                closed++;
            }
        }
    }

    // Lower zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Lower_Status[i] == ORDER_FILLED && gridA_Lower_Tickets[i] > 0) {
            if(ClosePosition(gridA_Lower_Tickets[i])) {
                gridA_Lower_Status[i] = ORDER_CLOSED;
                closed++;
            }
        }
    }

    return closed;
}

//+------------------------------------------------------------------+
//| Close All Grid B Positions                                        |
//+------------------------------------------------------------------+
int CloseAllGridBPositions() {
    int closed = 0;

    // Upper zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Status[i] == ORDER_FILLED && gridB_Upper_Tickets[i] > 0) {
            if(ClosePosition(gridB_Upper_Tickets[i])) {
                gridB_Upper_Status[i] = ORDER_CLOSED;
                closed++;
            }
        }
    }

    // Lower zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Lower_Status[i] == ORDER_FILLED && gridB_Lower_Tickets[i] > 0) {
            if(ClosePosition(gridB_Lower_Tickets[i])) {
                gridB_Lower_Status[i] = ORDER_CLOSED;
                closed++;
            }
        }
    }

    return closed;
}

//+------------------------------------------------------------------+
//| Cancel All Grid A Pending Orders                                  |
//+------------------------------------------------------------------+
int CancelAllGridAPendingOrders() {
    int canceled = 0;

    // Upper zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Status[i] == ORDER_PENDING && gridA_Upper_Tickets[i] > 0) {
            if(DeletePendingOrder(gridA_Upper_Tickets[i])) {
                gridA_Upper_Status[i] = ORDER_CANCELLED;
                gridA_Upper_Tickets[i] = 0;
                canceled++;
            }
        }
    }

    // Lower zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Lower_Status[i] == ORDER_PENDING && gridA_Lower_Tickets[i] > 0) {
            if(DeletePendingOrder(gridA_Lower_Tickets[i])) {
                gridA_Lower_Status[i] = ORDER_CANCELLED;
                gridA_Lower_Tickets[i] = 0;
                canceled++;
            }
        }
    }

    return canceled;
}

//+------------------------------------------------------------------+
//| Cancel All Grid B Pending Orders                                  |
//+------------------------------------------------------------------+
int CancelAllGridBPendingOrders() {
    int canceled = 0;

    // Upper zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Status[i] == ORDER_PENDING && gridB_Upper_Tickets[i] > 0) {
            if(DeletePendingOrder(gridB_Upper_Tickets[i])) {
                gridB_Upper_Status[i] = ORDER_CANCELLED;
                gridB_Upper_Tickets[i] = 0;
                canceled++;
            }
        }
    }

    // Lower zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Lower_Status[i] == ORDER_PENDING && gridB_Lower_Tickets[i] > 0) {
            if(DeletePendingOrder(gridB_Lower_Tickets[i])) {
                gridB_Lower_Status[i] = ORDER_CANCELLED;
                gridB_Lower_Tickets[i] = 0;
                canceled++;
            }
        }
    }

    return canceled;
}

//+------------------------------------------------------------------+
//| Get Recenter Status String (for dashboard)                        |
//+------------------------------------------------------------------+
string GetRecenterStatus() {
    if(!EnableAutoRecenter) return "Disabled";
    if(g_recenterPending) return "PENDING CONFIRM";

    string reason;
    if(CheckRecenterConditions(reason)) {
        return "Ready";
    }

    return reason;
}

//+------------------------------------------------------------------+
//| NOTE: GetTotalOpenProfit is defined in Trading/PositionMonitor.mqh |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| LOG RECENTER STATUS REPORT                                        |
//| Comprehensive diagnostic output for troubleshooting               |
//+------------------------------------------------------------------+
void LogRecenterReport() {
    Print("");
    Print("╔═══════════════════════════════════════════════════════════════════╗");
    Print("║              AUTO-RECENTER - STATUS REPORT                        ║");
    Print("╠═══════════════════════════════════════════════════════════════════╣");
    Print("║ CONFIGURATION                                                     ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║  Enabled: ", EnableAutoRecenter ? "YES" : "NO",
          "  |  User Confirm: ", RequireUserConfirm ? "REQUIRED" : "AUTO");
    Print("║  Min Interval: ", Recenter_MinInterval_Minutes, " min",
          "  |  Only New Bar: ", Recenter_OnlyOnNewBar ? "YES" : "NO");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║ TRIGGER CONDITIONS                                                ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║  Price Proximity: ", DoubleToString(Recenter_PriceProximity_Pips, 1), " pips (price within center)");
    Print("║  Entry Distance: ", DoubleToString(Recenter_EntryDistance_Pips, 1), " pips (entry far from center)");
    Print("║  Min Confidence: ", DoubleToString(Recenter_MinConfidence, 1), "%");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║ SAFETY LIMITS                                                     ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║  Max Floating Loss: $", DoubleToString(Recenter_MaxFloatingLoss_USD, 2),
          " or ", DoubleToString(Recenter_MaxFloatingLoss_Pct, 1), "% equity");
    Print("║  Block Near Shield: ", BlockRecenterNearShield ? "YES" : "NO");
    Print("║  Block On Trend: ", BlockRecenterOnTrend ? "YES (ADX>" + DoubleToString(TrendADX_Threshold, 0) + ")" : "NO");
    Print("║  Block High Volatility: ", BlockRecenterHighVolatility ? "YES (ATR EXTREME)" : "NO");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║ CURRENT STATE                                                     ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double optimalCenter = GetOptimalCenter();
    double confidence = GetCenterConfidence();

    Print("║  Current Price: ", DoubleToString(currentPrice, symbolDigits));
    Print("║  Current Entry: ", DoubleToString(entryPoint, symbolDigits));
    Print("║  Optimal Center: ", DoubleToString(optimalCenter, symbolDigits));
    Print("║  Confidence: ", DoubleToString(confidence, 1), "%");

    if(optimalCenter > 0) {
        double priceToCenterPips = MathAbs(currentPrice - optimalCenter) / PipsToPoints(1);
        double entryToCenterPips = MathAbs(entryPoint - optimalCenter) / PipsToPoints(1);

        Print("║  Price-to-Center: ", DoubleToString(priceToCenterPips, 1), " pips",
              priceToCenterPips <= Recenter_PriceProximity_Pips ? " ✅" : " ❌");
        Print("║  Entry-to-Center: ", DoubleToString(entryToCenterPips, 1), " pips",
              entryToCenterPips >= Recenter_EntryDistance_Pips ? " ✅" : " ❌");
    }

    Print("║  Floating P/L: $", DoubleToString(GetTotalOpenProfit(), 2));
    Print("║  Session Recenters: ", g_recenterCount);
    Print("║  Last Recenter: ", g_lastRecenterTime > 0 ? TimeToString(g_lastRecenterTime, TIME_DATE|TIME_SECONDS) : "Never");
    Print("║  Pending Confirm: ", g_recenterPending ? "YES - Waiting for user" : "NO");

    // Cooldown status
    if(g_lastRecenterTime > 0) {
        int minSinceLast = (int)((TimeCurrent() - g_lastRecenterTime) / 60);
        int cooldownLeft = Recenter_MinInterval_Minutes - minSinceLast;
        if(cooldownLeft > 0) {
            Print("║  Cooldown: ", cooldownLeft, " min remaining");
        } else {
            Print("║  Cooldown: Ready");
        }
    }

    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║ CONDITIONS CHECK                                                  ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");

    // Check all 10 conditions
    string reason;
    bool canRecenter = CheckRecenterConditions(reason);
    Print("║  Status: ", canRecenter ? "✅ READY TO RECENTER" : "❌ BLOCKED");
    if(!canRecenter) {
        Print("║  Reason: ", reason);
    }

    Print("╚═══════════════════════════════════════════════════════════════════╝");
    Print("");
}

//+------------------------------------------------------------------+
//| Log Recenter Execution Details                                    |
//+------------------------------------------------------------------+
void LogRecenterExecution(double oldEntry, double newEntry, int closedPositions,
                          int canceledOrders, bool success) {
    Print("");
    Print("╔═══════════════════════════════════════════════════════════════════╗");
    Print("║              GRID RECENTER EXECUTION                              ║");
    Print("╠═══════════════════════════════════════════════════════════════════╣");

    if(success) {
        Print("║  STATUS: ✅ SUCCESS                                              ║");
    } else {
        Print("║  STATUS: ⚠️ COMPLETED WITH WARNINGS                              ║");
    }

    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║ ENTRY POINT CHANGE                                                ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║  Old Entry: ", DoubleToString(oldEntry, symbolDigits));
    Print("║  New Entry: ", DoubleToString(newEntry, symbolDigits));
    Print("║  Shift: ", DoubleToString(MathAbs(newEntry - oldEntry) / PipsToPoints(1), 1), " pips",
          newEntry > oldEntry ? " (UP)" : " (DOWN)");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║ CLEANUP SUMMARY                                                   ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║  Positions Closed: ", closedPositions);
    Print("║  Pending Orders Canceled: ", canceledOrders);
    Print("║  New Spacing: ", DoubleToString(GetDynamicSpacing(), 1), " pips");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║ STATISTICS                                                        ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║  Session Recenters: ", g_recenterCount);
    Print("║  Execution Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
    Print("╚═══════════════════════════════════════════════════════════════════╝");
    Print("");
}

//+------------------------------------------------------------------+
//| Log Conditions Check Details                                      |
//+------------------------------------------------------------------+
void LogConditionsCheck() {
    if(!DetailedLogging) return;

    Print("");
    Print("┌─────────────────────────────────────────────────────────────────┐");
    Print("│  🔍 RECENTER CONDITIONS CHECK                                   │");
    Print("├─────────────────────────────────────────────────────────────────┤");

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double optimalCenter = GetOptimalCenter();
    double confidence = GetCenterConfidence();
    double floatingPL = GetTotalOpenProfit();
    double equity = AccountInfoDouble(ACCOUNT_EQUITY);

    // Condition 1: Price proximity
    double priceDist = MathAbs(currentPrice - optimalCenter) / PipsToPoints(1);
    Print("│  1. Price Proximity: ", DoubleToString(priceDist, 1), " pips",
          priceDist <= Recenter_PriceProximity_Pips ? " ✅" : " ❌",
          " (need ≤", DoubleToString(Recenter_PriceProximity_Pips, 1), ")");

    // Condition 2: Entry distance
    double entryDist = MathAbs(entryPoint - optimalCenter) / PipsToPoints(1);
    Print("│  2. Entry Distance: ", DoubleToString(entryDist, 1), " pips",
          entryDist >= Recenter_EntryDistance_Pips ? " ✅" : " ❌",
          " (need ≥", DoubleToString(Recenter_EntryDistance_Pips, 1), ")");

    // Condition 3: Confidence
    Print("│  3. Confidence: ", DoubleToString(confidence, 1), "%",
          confidence >= Recenter_MinConfidence ? " ✅" : " ❌",
          " (need ≥", DoubleToString(Recenter_MinConfidence, 1), "%)");

    // Condition 4: Floating loss USD
    Print("│  4. Floating Loss: $", DoubleToString(MathAbs(floatingPL), 2),
          floatingPL >= -Recenter_MaxFloatingLoss_USD ? " ✅" : " ❌",
          " (max $", DoubleToString(Recenter_MaxFloatingLoss_USD, 2), ")");

    // Condition 5: Floating loss %
    double floatPct = MathAbs(floatingPL) / equity * 100;
    Print("│  5. Floating Loss%: ", DoubleToString(floatPct, 2), "%",
          floatPct <= Recenter_MaxFloatingLoss_Pct ? " ✅" : " ❌",
          " (max ", DoubleToString(Recenter_MaxFloatingLoss_Pct, 1), "%)");

    // Condition 6: Cooldown
    int minSinceLast = g_lastRecenterTime > 0 ? (int)((TimeCurrent() - g_lastRecenterTime) / 60) : Recenter_MinInterval_Minutes;
    Print("│  6. Cooldown: ", minSinceLast, " min",
          minSinceLast >= Recenter_MinInterval_Minutes ? " ✅" : " ❌",
          " (need ≥", Recenter_MinInterval_Minutes, " min)");

    // Condition 7: New bar
    Print("│  7. New Bar Check: ", !Recenter_OnlyOnNewBar ? "Disabled ✅" : "Enabled");

    // Condition 8: Shield
    bool shieldOK = !BlockRecenterNearShield || !IsRangeBoxAvailable() || (!shield.isActive && shield.phase < PHASE_WARNING);
    Print("│  8. Shield Clear: ", shieldOK ? "✅" : "❌ (Shield active/warning)");

    // Condition 9: Trend
    bool trendOK = !BlockRecenterOnTrend || !EnableADXMonitor || adxValue_Immediate <= TrendADX_Threshold;
    Print("│  9. Trend Clear: ", trendOK ? "✅" : "❌ (ADX=" + DoubleToString(adxValue_Immediate, 1) + ")");

    // Condition 10: Volatility
    bool volOK = !BlockRecenterHighVolatility || (currentATRStep != ATR_STEP_EXTREME && currentATR_Condition != ATR_EXTREME);
    Print("│  10. Volatility OK: ", volOK ? "✅" : "❌ (EXTREME volatility)");

    Print("└─────────────────────────────────────────────────────────────────┘");
    Print("");
}

