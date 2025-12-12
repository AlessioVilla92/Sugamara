//+------------------------------------------------------------------+
//|                                          DynamicATRAdapter.mqh   |
//|                        Sugamara v4.0 - ATR Dynamic Spacing       |
//|                                                                  |
//|  Sistema adattamento spacing griglia basato su 5 step ATR        |
//|  - Calcola step discreto da ATR corrente                         |
//|  - Adatta spacing solo su ordini PENDING (mai FILLED!)           |
//|  - Transizioni smooth con cooldown temporale                     |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Initialize Dynamic ATR Adapter                                    |
//+------------------------------------------------------------------+
bool InitializeDynamicATRAdapter() {
    if(!EnableDynamicATRSpacing) {
        Print("DynamicATRAdapter: DISABLED by user settings");
        return true;
    }

    // Validate parameters
    if(ATR_Threshold_VeryLow >= ATR_Threshold_Low ||
       ATR_Threshold_Low >= ATR_Threshold_Normal ||
       ATR_Threshold_Normal >= ATR_Threshold_High) {
        Print("ERROR: ATR thresholds must be in ascending order");
        return false;
    }

    // Initialize state
    lastATRCheck_Dynamic = 0;
    lastSpacingChange = 0;
    spacingChangeInProgress = false;

    // Calculate initial step
    double atrPips = GetATRInPips();
    currentATRStep = CalculateATRStep(atrPips);
    lastATRStep = currentATRStep;
    lastATRValue_Dynamic = atrPips;
    previousSpacing_Pips = GetSpacingForATRStep(currentATRStep);

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  DynamicATRAdapter v4.0 INITIALIZED");
    Print("  Current ATR: ", DoubleToString(atrPips, 1), " pips");
    Print("  Current Step: ", GetATRStepName(currentATRStep));
    Print("  Current Spacing: ", DoubleToString(previousSpacing_Pips, 1), " pips");
    Print("═══════════════════════════════════════════════════════════════════");

    return true;
}

//+------------------------------------------------------------------+
//| Get ATR value in pips (uses existing ATR system)                  |
//+------------------------------------------------------------------+
double GetATRInPips() {
    if(atrHandle == INVALID_HANDLE) return 20.0;  // Default

    double atrBuffer[1];
    if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0) {
        return currentATR_Pips > 0 ? currentATR_Pips : 20.0;
    }

    // Convert to pips
    double pipValue = symbolPoint;
    if(symbolDigits == 5 || symbolDigits == 3) pipValue *= 10;

    return atrBuffer[0] / pipValue;
}

//+------------------------------------------------------------------+
//| NOTE: CalculateATRStep(), GetSpacingForATRStep(), GetATRStepName()|
//| are defined in Utils/ATRCalculator.mqh                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check and Adapt ATR Spacing (called from OnTimer) v4.1/4.2        |
//| Returns true if spacing was changed                               |
//| Uses event-driven check on new candle for efficiency              |
//+------------------------------------------------------------------+
bool CheckAndAdaptATRSpacing() {
    if(!EnableDynamicATRSpacing) return false;
    if(spacingChangeInProgress) return false;
    if(NeutralMode == NEUTRAL_PURE) return false;  // PURE mode ignores ATR

    datetime now = TimeCurrent();
    datetime currentBarTime = iTime(_Symbol, ATR_Timeframe, 0);

    // v4.1: Event-driven check - only on new candle
    static datetime lastCheckedBar = 0;
    bool isNewBar = (currentBarTime != lastCheckedBar);

    // Also check time interval as backup
    bool intervalPassed = (now - lastATRCheck_Dynamic >= ATR_CheckInterval_Seconds);

    if(!isNewBar && !intervalPassed) {
        return false;  // No new bar and interval not passed
    }

    lastCheckedBar = currentBarTime;
    lastATRCheck_Dynamic = now;

    // v4.1: Use unified cache function
    double atrPips = GetATRPipsUnified(1);  // Force update

    // v4.2: Debug logging for every check
    if(ATR_LogEveryCheck) {
        ENUM_ATR_STEP checkStep = CalculateATRStep(atrPips);
        Print("[ATR CHECK] ", TimeToString(now, TIME_SECONDS),
              " | ATR: ", DoubleToString(atrPips, 1), " pips",
              " | Step: ", GetATRStepName(checkStep),
              " | NewBar: ", isNewBar ? "YES" : "NO");
    }

    // Check if ATR changed significantly
    double atrChange = 0;
    if(lastATRValue_Dynamic > 0) {
        atrChange = (atrPips - lastATRValue_Dynamic) / lastATRValue_Dynamic * 100;
    }

    if(MathAbs(atrChange) < ATR_StepChangeThreshold) {
        lastATRValue_Dynamic = atrPips;
        return false;  // Change too small
    }

    // Check minimum time between changes (cooldown)
    if(now - lastSpacingChange < ATR_MinTimeBetweenChanges) {
        if(ATR_DetailedLogging) {
            Print("[ATR] Change blocked - cooldown active (",
                  (int)(ATR_MinTimeBetweenChanges - (now - lastSpacingChange)), " sec left)");
        }
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════
    // v4.6: LINEAR MODE - Check if spacing changed significantly
    // ═══════════════════════════════════════════════════════════════════
    if(UseLinearInterpolation) {
        double targetSpacing = GetInterpolatedSpacing(atrPips);
        double newSpacing = ApplyRateLimiting(targetSpacing, lastAppliedSpacing_Pips);

        // Check if spacing actually changed enough to warrant grid update
        double spacingDelta = MathAbs(newSpacing - lastAppliedSpacing_Pips);
        if(spacingDelta < 0.5) {  // Less than 0.5 pips change - skip
            lastATRValue_Dynamic = atrPips;
            return false;
        }

        // Log the change
        if(ATR_DetailedLogging || ATR_AlertOnSpacingChange) {
            Print("[ATR LINEAR] Spacing: ", DoubleToString(lastAppliedSpacing_Pips, 1),
                  " -> ", DoubleToString(newSpacing, 1), " pips",
                  " | ATR: ", DoubleToString(atrPips, 1), " pips",
                  " | Delta: ", DoubleToString(spacingDelta, 1), " pips");
        }

        if(ATR_AlertOnSpacingChange) {
            Alert("[SUGAMARA] Spacing changed: ", DoubleToString(lastAppliedSpacing_Pips, 1),
                  " -> ", DoubleToString(newSpacing, 1), " pips (LINEAR mode)");
        }

        // Update state and adapt grid
        double oldSpacing = lastAppliedSpacing_Pips;
        previousSpacing_Pips = lastAppliedSpacing_Pips;
        lastAppliedSpacing_Pips = newSpacing;
        lastSpacingChange = now;
        lastATRValue_Dynamic = atrPips;
        currentSpacing_Pips = newSpacing;

        // Adapt grid (only PENDING orders!)
        AdaptGridToNewSpacing(newSpacing);

        if(ATR_DetailedLogging) {
            LogATRDynamicReport();
        }

        return true;
    }

    // ═══════════════════════════════════════════════════════════════════
    // LEGACY: STEP-BASED SYSTEM
    // ═══════════════════════════════════════════════════════════════════

    // Calculate new step
    ENUM_ATR_STEP newStep = CalculateATRStep(atrPips);

    // Check if step actually changed
    if(newStep == currentATRStep) {
        lastATRValue_Dynamic = atrPips;
        return false;
    }

    // ═══════════════════════════════════════════════════════════════════
    // STEP CHANGED! Perform adaptation with full logging
    // ═══════════════════════════════════════════════════════════════════

    double oldSpacing = GetSpacingForATRStep(currentATRStep);
    double newSpacing = GetSpacingForATRStep(newStep);

    // v4.2: Log ATR step transition
    LogATRStepTransition(currentATRStep, newStep, lastATRValue_Dynamic, atrPips, atrChange);

    // v4.2: Log spacing change with ALERT
    LogSpacingChangeWithAlert(oldSpacing, newSpacing, newStep, atrPips);

    // Update state BEFORE grid adaptation
    lastATRStep = currentATRStep;
    currentATRStep = newStep;
    lastATRValue_Dynamic = atrPips;
    previousSpacing_Pips = currentSpacing_Pips;
    currentSpacing_Pips = newSpacing;
    lastSpacingChange = now;

    // Adapt grid to new spacing (only PENDING orders!)
    AdaptGridToNewSpacing(newSpacing);

    // Log full status report if detailed logging enabled
    if(ATR_DetailedLogging) {
        LogATRDynamicReport();
    }

    return true;
}

//+------------------------------------------------------------------+
//| Adapt Grid to New Spacing                                         |
//| CRITICAL: Only modifies PENDING orders, NEVER touches FILLED!     |
//+------------------------------------------------------------------+
void AdaptGridToNewSpacing(double newSpacing) {
    spacingChangeInProgress = true;

    Print("Adapting grid to new spacing: ", DoubleToString(newSpacing, 1), " pips");

    int pendingModified = 0;
    int pendingFailed = 0;
    int filledSkipped = 0;

    // Convert spacing to points
    double spacingPoints = PipsToPoints(newSpacing);

    // ═══════════════════════════════════════════════════════════════════
    // GRID A - Upper Zone (Buy Limit orders)
    // ═══════════════════════════════════════════════════════════════════
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Status[i] == ORDER_FILLED) {
            filledSkipped++;
            continue;  // NEVER touch filled positions!
        }

        if(gridA_Upper_Status[i] == ORDER_PENDING && gridA_Upper_Tickets[i] > 0) {
            // Calculate new price for this level
            double newPrice = NormalizeDouble(entryPoint + spacingPoints * (i + 1), symbolDigits);
            double newTP = CalculateTPForLevel(i, newPrice, true, GRID_A, ZONE_UPPER);

            // Delete old pending and place new one
            if(DeletePendingOrder(gridA_Upper_Tickets[i])) {
                gridA_Upper_EntryPrices[i] = newPrice;
                gridA_Upper_TP[i] = newTP;

                if(PlaceGridOrder(GRID_A, ZONE_UPPER, i)) {
                    pendingModified++;
                } else {
                    pendingFailed++;
                    gridA_Upper_Status[i] = ORDER_NONE;
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // GRID A - Lower Zone (Sell Stop orders)
    // ═══════════════════════════════════════════════════════════════════
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Lower_Status[i] == ORDER_FILLED) {
            filledSkipped++;
            continue;
        }

        if(gridA_Lower_Status[i] == ORDER_PENDING && gridA_Lower_Tickets[i] > 0) {
            double newPrice = NormalizeDouble(entryPoint - spacingPoints * (i + 1), symbolDigits);
            double newTP = CalculateTPForLevel(i, newPrice, false, GRID_A, ZONE_LOWER);

            if(DeletePendingOrder(gridA_Lower_Tickets[i])) {
                gridA_Lower_EntryPrices[i] = newPrice;
                gridA_Lower_TP[i] = newTP;

                if(PlaceGridOrder(GRID_A, ZONE_LOWER, i)) {
                    pendingModified++;
                } else {
                    pendingFailed++;
                    gridA_Lower_Status[i] = ORDER_NONE;
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // GRID B - Upper Zone (Sell Limit orders)
    // ═══════════════════════════════════════════════════════════════════
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Status[i] == ORDER_FILLED) {
            filledSkipped++;
            continue;
        }

        if(gridB_Upper_Status[i] == ORDER_PENDING && gridB_Upper_Tickets[i] > 0) {
            double newPrice = NormalizeDouble(entryPoint + spacingPoints * (i + 1), symbolDigits);
            double newTP = CalculateTPForLevel(i, newPrice, false, GRID_B, ZONE_UPPER);

            if(DeletePendingOrder(gridB_Upper_Tickets[i])) {
                gridB_Upper_EntryPrices[i] = newPrice;
                gridB_Upper_TP[i] = newTP;

                if(PlaceGridOrder(GRID_B, ZONE_UPPER, i)) {
                    pendingModified++;
                } else {
                    pendingFailed++;
                    gridB_Upper_Status[i] = ORDER_NONE;
                }
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // GRID B - Lower Zone (Buy Stop orders)
    // ═══════════════════════════════════════════════════════════════════
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Lower_Status[i] == ORDER_FILLED) {
            filledSkipped++;
            continue;
        }

        if(gridB_Lower_Status[i] == ORDER_PENDING && gridB_Lower_Tickets[i] > 0) {
            double newPrice = NormalizeDouble(entryPoint - spacingPoints * (i + 1), symbolDigits);
            double newTP = CalculateTPForLevel(i, newPrice, true, GRID_B, ZONE_LOWER);

            if(DeletePendingOrder(gridB_Lower_Tickets[i])) {
                gridB_Lower_EntryPrices[i] = newPrice;
                gridB_Lower_TP[i] = newTP;

                if(PlaceGridOrder(GRID_B, ZONE_LOWER, i)) {
                    pendingModified++;
                } else {
                    pendingFailed++;
                    gridB_Lower_Status[i] = ORDER_NONE;
                }
            }
        }
    }

    // Update RangeBox if applicable
    if(IsRangeBoxAvailable()) {
        SyncRangeBoxWithGrid();
        if(ShieldMode != SHIELD_DISABLED) {
            CalculateBreakoutLevels();
        }
    }

    // Update grid visualization
    if(ShowGridLines) {
        DrawGridVisualization();
    }

    // Log detailed summary
    LogGridAdaptationSummary(pendingModified, pendingFailed, filledSkipped, newSpacing);

    spacingChangeInProgress = false;
}

//+------------------------------------------------------------------+
//| Calculate TP for Level (wrapper for existing function)            |
//+------------------------------------------------------------------+
double CalculateTPForLevel(int level, double orderPrice, bool isLong,
                           ENUM_GRID_SIDE gridSide, ENUM_GRID_ZONE zone) {
    // Get previous entry price for CASCADE mode
    double prevEntry = 0;

    if(level > 0) {
        if(gridSide == GRID_A) {
            prevEntry = (zone == ZONE_UPPER) ? gridA_Upper_EntryPrices[level-1]
                                              : gridA_Lower_EntryPrices[level-1];
        } else {
            prevEntry = (zone == ZONE_UPPER) ? gridB_Upper_EntryPrices[level-1]
                                              : gridB_Lower_EntryPrices[level-1];
        }
    } else {
        prevEntry = entryPoint;
    }

    return CalculateTPForMode(level, orderPrice, prevEntry, isLong);
}

//+------------------------------------------------------------------+
//| Place Grid Order (wrapper for existing functions)                 |
//+------------------------------------------------------------------+
bool PlaceGridOrder(ENUM_GRID_SIDE gridSide, ENUM_GRID_ZONE zone, int level) {
    if(gridSide == GRID_A) {
        if(zone == ZONE_UPPER) {
            return PlaceGridAUpperOrder(level);
        } else {
            return PlaceGridALowerOrder(level);
        }
    } else {
        if(zone == ZONE_UPPER) {
            return PlaceGridBUpperOrder(level);
        } else {
            return PlaceGridBLowerOrder(level);
        }
    }
}

//+------------------------------------------------------------------+
//| Get Dynamic Spacing (v4.6 - LINEAR + RATE LIMITING)              |
//+------------------------------------------------------------------+
double GetDynamicSpacing() {
    // NEUTRAL_PURE always uses fixed spacing
    if(NeutralMode == NEUTRAL_PURE) {
        return Fixed_Spacing_Pips;
    }

    // If dynamic ATR disabled, use legacy ATR or fixed
    if(!EnableDynamicATRSpacing) {
        if(UseATR && SpacingMode == SPACING_ATR) {
            return CalculateATRSpacing();
        }
        return Fixed_Spacing_Pips;
    }

    // v4.6: LINEAR INTERPOLATION with RATE LIMITING
    if(UseLinearInterpolation) {
        double currentATR = GetATRPipsUnified(2);  // Mode 2: Update on new bar (was 0=cache only - BUG FIX)
        double targetSpacing = GetInterpolatedSpacing(currentATR);

        // Apply rate limiting if enabled
        double finalSpacing = ApplyRateLimiting(targetSpacing, lastAppliedSpacing_Pips);

        // Initialize on first call
        if(lastAppliedSpacing_Pips <= 0) {
            lastAppliedSpacing_Pips = finalSpacing;
        }

        return finalSpacing;
    }

    // Fallback: legacy step-based system
    return GetSpacingForATRStep(currentATRStep);
}

//+------------------------------------------------------------------+
//| Get Current ATR Step                                              |
//+------------------------------------------------------------------+
ENUM_ATR_STEP GetCurrentATRStep() {
    return currentATRStep;
}

//+------------------------------------------------------------------+
//| Get ATR Step Info String (for dashboard)                          |
//+------------------------------------------------------------------+
string GetATRStepInfo() {
    return StringFormat("%s (%.1f pips → %.1f pips spacing)",
                        GetATRStepName(currentATRStep),
                        lastATRValue_Dynamic,
                        GetSpacingForATRStep(currentATRStep));
}

//+------------------------------------------------------------------+
//| Is ATR Dynamic Available (mode check)                             |
//+------------------------------------------------------------------+
bool IsATRDynamicAvailable() {
    return (NeutralMode != NEUTRAL_PURE && EnableDynamicATRSpacing);
}

//+------------------------------------------------------------------+
//| LOG ATR DYNAMIC STATUS REPORT                                     |
//| Comprehensive diagnostic output for troubleshooting               |
//+------------------------------------------------------------------+
void LogATRDynamicReport() {
    Print("");
    Print("╔═══════════════════════════════════════════════════════════════════╗");
    Print("║              ATR DYNAMIC SPACING - STATUS REPORT                  ║");
    Print("╠═══════════════════════════════════════════════════════════════════╣");
    Print("║ CONFIGURATION                                                     ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║  Enabled: ", EnableDynamicATRSpacing ? "YES" : "NO",
          "  |  Mode: ", NeutralMode == NEUTRAL_PURE ? "PURE (ATR ignored)" : "CASCADE/RANGEBOX");
    Print("║  Check Interval: ", ATR_CheckInterval_Seconds, " sec",
          "  |  Min Change Time: ", ATR_MinTimeBetweenChanges, " sec");
    Print("║  Step Change Threshold: ", DoubleToString(ATR_StepChangeThreshold, 1), "%");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║ ATR THRESHOLDS (pips)                                             ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║  VERY_LOW: < ", DoubleToString(ATR_Threshold_VeryLow, 1),
          "  |  LOW: < ", DoubleToString(ATR_Threshold_Low, 1),
          "  |  NORMAL: < ", DoubleToString(ATR_Threshold_Normal, 1));
    Print("║  HIGH: < ", DoubleToString(ATR_Threshold_High, 1),
          "  |  EXTREME: >= ", DoubleToString(ATR_Threshold_High, 1));
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║ SPACING PER STEP (pips)                                           ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║  VERY_LOW: ", DoubleToString(Spacing_VeryLow_Pips, 1),
          "  |  LOW: ", DoubleToString(Spacing_Low_Pips, 1),
          "  |  NORMAL: ", DoubleToString(Spacing_Normal_Pips, 1));
    Print("║  HIGH: ", DoubleToString(Spacing_High_Pips, 1),
          "  |  EXTREME: ", DoubleToString(Spacing_Extreme_Pips, 1));
    Print("║  Limits: Min=", DoubleToString(DynamicSpacing_Min_Pips, 1),
          " | Max=", DoubleToString(DynamicSpacing_Max_Pips, 1));
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║ CURRENT STATE                                                     ║");
    Print("╟───────────────────────────────────────────────────────────────────╢");
    Print("║  Current ATR: ", DoubleToString(GetATRInPips(), 2), " pips");
    Print("║  Current Step: ", GetATRStepName(currentATRStep),
          " (previous: ", GetATRStepName(lastATRStep), ")");
    Print("║  Current Spacing: ", DoubleToString(GetDynamicSpacing(), 1), " pips",
          " (previous: ", DoubleToString(previousSpacing_Pips, 1), ")");
    Print("║  Last ATR Check: ", lastATRCheck_Dynamic > 0 ? TimeToString(lastATRCheck_Dynamic, TIME_DATE|TIME_SECONDS) : "Never");
    Print("║  Last Spacing Change: ", lastSpacingChange > 0 ? TimeToString(lastSpacingChange, TIME_DATE|TIME_SECONDS) : "Never");
    Print("║  Change In Progress: ", spacingChangeInProgress ? "YES" : "NO");

    // Cooldown status
    if(lastSpacingChange > 0) {
        int secSinceChange = (int)(TimeCurrent() - lastSpacingChange);
        int cooldownLeft = ATR_MinTimeBetweenChanges - secSinceChange;
        if(cooldownLeft > 0) {
            Print("║  Cooldown: ", cooldownLeft, " sec remaining");
        } else {
            Print("║  Cooldown: Ready for next change");
        }
    }

    Print("╚═══════════════════════════════════════════════════════════════════╝");
    Print("");
}

//+------------------------------------------------------------------+
//| Log ATR Step Transition (detailed) v4.2                           |
//+------------------------------------------------------------------+
void LogATRStepTransition(ENUM_ATR_STEP oldStep, ENUM_ATR_STEP newStep,
                          double oldATR, double newATR, double changePercent) {
    if(!ATR_DetailedLogging && !ATR_LogStepTransitions) return;

    g_atrStepChangeCount++;  // v4.2: Increment counter

    string direction = (newStep > oldStep) ? "VOLATILITY INCREASING" : "VOLATILITY DECREASING";
    string oldName = GetATRStepName(oldStep);
    string newName = GetATRStepName(newStep);

    Print("");
    Print("═══════════════════════════════════════════════════════════════");
    Print("  ATR STEP CHANGE #", g_atrStepChangeCount);
    Print("═══════════════════════════════════════════════════════════════");
    Print("  Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
    Print("  Symbol: ", _Symbol);
    Print("  Direction: ", direction);
    Print("  ATR Value: ", DoubleToString(oldATR, 1), " -> ", DoubleToString(newATR, 1), " pips");
    Print("  ATR Change: ", changePercent > 0 ? "+" : "", DoubleToString(changePercent, 1), "%");
    Print("  ATR Step: ", oldName, " -> ", newName);
    Print("  Spacing: ", DoubleToString(GetSpacingForATRStep(oldStep), 1), " -> ",
          DoubleToString(GetSpacingForATRStep(newStep), 1), " pips");
    Print("═══════════════════════════════════════════════════════════════");
    Print("");

    g_lastATRStepName = newName;
    g_lastLoggedATRChange = TimeCurrent();
}

//+------------------------------------------------------------------+
//| Log Spacing Change with Alert v4.2                                |
//| Generates visible Alert in MetaTrader Alert Log                   |
//+------------------------------------------------------------------+
void LogSpacingChangeWithAlert(double oldSpacing, double newSpacing,
                               ENUM_ATR_STEP step, double atrPips) {
    g_spacingChangeCount++;  // v4.2: Increment counter

    string stepName = GetATRStepName(step);
    double delta = newSpacing - oldSpacing;

    // Print detailed log
    Print("");
    Print("╔══════════════════════════════════════════════════════════════╗");
    Print("║         GRID SPACING CHANGE #", g_spacingChangeCount);
    Print("╠══════════════════════════════════════════════════════════════╣");
    Print("║  Time: ", TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS));
    Print("║  Symbol: ", _Symbol);
    Print("║  ATR Step: ", stepName);
    Print("║  ATR Value: ", DoubleToString(atrPips, 1), " pips");
    Print("║  OLD Spacing: ", DoubleToString(oldSpacing, 1), " pips");
    Print("║  NEW Spacing: ", DoubleToString(newSpacing, 1), " pips");
    Print("║  Delta: ", delta > 0 ? "+" : "", DoubleToString(delta, 1), " pips");
    Print("╚══════════════════════════════════════════════════════════════╝");
    Print("");

    // Generate visible Alert in MT5 Alert Log
    if(ATR_AlertOnSpacingChange) {
        string alertMsg = StringFormat(
            "SUGAMARA [%s] SPACING CHANGE: %.1f -> %.1f pips (ATR: %.1f, Step: %s)",
            _Symbol, oldSpacing, newSpacing, atrPips, stepName
        );
        Alert(alertMsg);
    }
}

//+------------------------------------------------------------------+
//| Log Grid Adaptation Summary v4.2                                  |
//+------------------------------------------------------------------+
void LogGridAdaptationSummary(int modified, int failed, int skipped, double newSpacing) {
    if(!ATR_DetailedLogging) return;

    Print("");
    Print("┌──────────────────────────────────────────────────────────────┐");
    Print("│  GRID ADAPTATION SUMMARY                                     │");
    Print("├──────────────────────────────────────────────────────────────┤");
    Print("│  New Spacing Applied: ", DoubleToString(newSpacing, 1), " pips");
    Print("│  Pending Orders Deleted/Recreated: ", modified);
    Print("│  Modifications Failed: ", failed);
    Print("│  FILLED Positions: ", skipped, " (UNCHANGED - protected)");
    Print("└──────────────────────────────────────────────────────────────┘");
    Print("");

    // Also log to Expert tab
    Print("[GRID ADAPT] Deleted: ", modified,
          " | Created: ", modified,
          " | Failed: ", failed,
          " | FILLED preserved: ", skipped,
          " | New Spacing: ", DoubleToString(newSpacing, 1), " pips");
}

