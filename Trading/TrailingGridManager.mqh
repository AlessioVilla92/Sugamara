//+==================================================================+
//|                                       TrailingGridManager.mqh    |
//|           SUGAMARA - Trailing Grid Intelligente v1.0             |
//|  Sistema "Inserisci Prima, Elimina Dopo" per grid dinamiche      |
//+==================================================================+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS (funzioni da altri file)                     |
//+------------------------------------------------------------------+
// Da OrderManager.mqh:
// ulong PlacePendingOrder(ENUM_ORDER_TYPE, double, double, double, double, string, int);
// bool DeletePendingOrder(ulong);
// Da GridHelpers.mqh:
// int GetGridMagic(ENUM_GRID_SIDE);
// double CalculateGridLotSize(int);
// Da Helpers.mqh:
// double PipsToPoints(double);

//+------------------------------------------------------------------+
//| Initialize Trailing Grid System                                   |
//+------------------------------------------------------------------+
bool InitializeTrailingGrid() {
    if(!Enable_TrailingGrid) {
        LogMessage(LOG_INFO, "[TrailGrid] Trailing Grid Intelligente: DISABLED");
        return true;
    }

    Print("+=================================================================+");
    Print("|   INITIALIZING TRAILING GRID INTELLIGENTE v1.0                 |");
    Print("+=================================================================+");

    // Log dettagliato configurazione
    LogTrail_Init(Trail_Trigger_Level, Trail_Spacing_Multiplier, Trail_Max_Extra_Grids, Trail_Sync_Shield);

    PrintFormat("  Trigger Level: %d (%s)",
                Trail_Trigger_Level,
                Trail_Trigger_Level == 1 ? "ULTIMA" :
                Trail_Trigger_Level == 2 ? "PENULTIMA" : "TERZULTIMA");
    PrintFormat("  Spacing Multiplier: %.2f", Trail_Spacing_Multiplier);
    PrintFormat("  Max Extra Grids: %d per lato", Trail_Max_Extra_Grids);
    PrintFormat("  Remove Distant: %s", Trail_Remove_Distant ? "YES" : "NO");
    PrintFormat("  Sync Shield: %s", Trail_Sync_Shield ? "YES" : "NO");

    // Verifica limite array
    int maxPossible = GridLevelsPerSide + Trail_Max_Extra_Grids;
    if(maxPossible > MAX_GRID_LEVELS) {
        LogTrail_Error("Init", StringFormat("GridLevels(%d) + MaxExtra(%d) = %d exceeds MAX_GRID_LEVELS(%d)",
                    GridLevelsPerSide, Trail_Max_Extra_Grids, maxPossible, MAX_GRID_LEVELS));
        PrintFormat("  WARNING: GridLevels(%d) + MaxExtra(%d) = %d > %d",
                    GridLevelsPerSide, Trail_Max_Extra_Grids, maxPossible, MAX_GRID_LEVELS);
        PrintFormat("  -> Sistema limitera automaticamente a indice %d", MAX_GRID_LEVELS - 1);
    }

    // Reset state
    g_trailExtraGridsAbove = 0;
    g_trailExtraGridsBelow = 0;
    g_trailUpperAdded = 0;
    g_trailUpperRemoved = 0;
    g_trailLowerAdded = 0;
    g_trailLowerRemoved = 0;
    g_currentMaxLevelAbove = GridLevelsPerSide - 1;
    g_currentMaxLevelBelow = GridLevelsPerSide - 1;
    g_trailActiveAbove = false;
    g_trailActiveBelow = false;
    g_lastTrailInsertTime = 0;

    LogMessage(LOG_SUCCESS, "[TrailGrid] Trailing Grid System READY");
    return true;
}

//+------------------------------------------------------------------+
//| Deinitialize Trailing Grid System                                 |
//+------------------------------------------------------------------+
void DeinitializeTrailingGrid() {
    if(!Enable_TrailingGrid) return;

    LogMessage(LOG_INFO, "[TrailGrid] Deinitializing...");
    LogTrail_Statistics(g_trailUpperAdded, g_trailUpperRemoved, g_trailLowerAdded, g_trailLowerRemoved);
}

//+------------------------------------------------------------------+
//| Count Pending Grid Orders Above Current Price                     |
//+------------------------------------------------------------------+
int CountPendingGridsAbove(double currentPrice) {
    int count = 0;
    int maxLevel = GridLevelsPerSide + g_trailExtraGridsAbove;
    if(maxLevel > MAX_GRID_LEVELS) maxLevel = MAX_GRID_LEVELS;

    for(int i = 0; i < maxLevel; i++) {
        if(gridA_Upper_Status[i] == ORDER_PENDING) {
            if(gridA_Upper_EntryPrices[i] > currentPrice) {
                count++;
            }
        }
    }

    return count;
}

//+------------------------------------------------------------------+
//| Count Pending Grid Orders Below Current Price                     |
//+------------------------------------------------------------------+
int CountPendingGridsBelow(double currentPrice) {
    int count = 0;
    int maxLevel = GridLevelsPerSide + g_trailExtraGridsBelow;
    if(maxLevel > MAX_GRID_LEVELS) maxLevel = MAX_GRID_LEVELS;

    for(int i = 0; i < maxLevel; i++) {
        if(gridA_Lower_Status[i] == ORDER_PENDING) {
            if(gridA_Lower_EntryPrices[i] < currentPrice) {
                count++;
            }
        }
    }

    return count;
}

//+------------------------------------------------------------------+
//| Get Next Grid Level Above (highest existing + spacing)            |
//+------------------------------------------------------------------+
double GetNextGridLevelAbove() {
    double highestLevel = entryPoint;
    int maxLevel = GridLevelsPerSide + g_trailExtraGridsAbove;
    if(maxLevel > MAX_GRID_LEVELS) maxLevel = MAX_GRID_LEVELS;

    for(int i = 0; i < maxLevel; i++) {
        if(gridA_Upper_EntryPrices[i] > highestLevel) {
            highestLevel = gridA_Upper_EntryPrices[i];
        }
    }

    double spacing = currentSpacing_Pips * Trail_Spacing_Multiplier;
    double newLevel = highestLevel + PipsToPoints(spacing);

    return NormalizeDouble(newLevel, symbolDigits);
}

//+------------------------------------------------------------------+
//| Get Next Grid Level Below (lowest existing - spacing)             |
//+------------------------------------------------------------------+
double GetNextGridLevelBelow() {
    double lowestLevel = entryPoint;
    int maxLevel = GridLevelsPerSide + g_trailExtraGridsBelow;
    if(maxLevel > MAX_GRID_LEVELS) maxLevel = MAX_GRID_LEVELS;

    // Trova il livello piu basso esistente
    for(int i = 0; i < maxLevel; i++) {
        if(gridA_Lower_EntryPrices[i] > 0 && gridA_Lower_EntryPrices[i] < lowestLevel) {
            lowestLevel = gridA_Lower_EntryPrices[i];
        }
    }

    // Se lowestLevel e ancora entryPoint, usa il calcolo base
    if(lowestLevel == entryPoint) {
        lowestLevel = entryPoint - PipsToPoints(currentSpacing_Pips * GridLevelsPerSide);
    }

    double spacing = currentSpacing_Pips * Trail_Spacing_Multiplier;
    double newLevel = lowestLevel - PipsToPoints(spacing);

    return NormalizeDouble(newLevel, symbolDigits);
}

//+------------------------------------------------------------------+
//| Calculate TP for Trailing Grid (CASCADE_OVERLAP mode)             |
//+------------------------------------------------------------------+
double CalculateTrailingTP(double trailEntryPrice, bool isBuy, double spacingPips) {
    // FIX: spacingPips è già moltiplicato per Trail_Spacing_Multiplier dal chiamante
    double spacingPoints = PipsToPoints(spacingPips);

    if(isBuy) {
        return NormalizeDouble(trailEntryPrice + spacingPoints, symbolDigits);
    } else {
        return NormalizeDouble(trailEntryPrice - spacingPoints, symbolDigits);
    }
}

//+------------------------------------------------------------------+
//| Insert New Grid Pair Above                                        |
//| Inserisce coppia Grid A (BUY STOP) + Grid B (SELL LIMIT)          |
//+------------------------------------------------------------------+
bool InsertNewGridAbove(double newLevel) {
    int newIndex = GridLevelsPerSide + g_trailExtraGridsAbove;
    if(newIndex >= MAX_GRID_LEVELS) {
        LogTrail_Error("InsertAbove", StringFormat("Array limit reached (%d)", MAX_GRID_LEVELS));
        return false;
    }

    double spacing = currentSpacing_Pips * Trail_Spacing_Multiplier;
    double hedgeOffset = PipsToPoints(Hedge_Spacing_Pips);
    double lotSize = CalculateGridLotSize(newIndex);

    // Grid A: BUY STOP
    double tpGridA = CalculateTrailingTP(newLevel, true, spacing);
    int magicA = GetGridMagic(GRID_A);
    string commentA = "Trail_A_U" + IntegerToString(g_trailExtraGridsAbove + 1);

    ulong ticketA = PlacePendingOrder(ORDER_TYPE_BUY_STOP, lotSize, newLevel,
                                      0, tpGridA, commentA, magicA);

    if(ticketA == 0) {
        LogTrail_Error("InsertAbove", StringFormat("Failed BUY STOP @ %.5f", newLevel));
        return false;
    }

    // Grid B: SELL LIMIT (hedge a +3 pips)
    double gridBLevel = NormalizeDouble(newLevel + hedgeOffset, symbolDigits);
    double tpGridB = CalculateTrailingTP(gridBLevel, false, spacing);
    int magicB = GetGridMagic(GRID_B);
    string commentB = "Trail_B_U" + IntegerToString(g_trailExtraGridsAbove + 1);

    ulong ticketB = PlacePendingOrder(ORDER_TYPE_SELL_LIMIT, lotSize, gridBLevel,
                                      0, tpGridB, commentB, magicB);

    if(ticketB == 0) {
        // Rollback: elimina Grid A
        DeletePendingOrder(ticketA);
        LogTrail_Error("InsertAbove", StringFormat("Failed SELL LIMIT @ %.5f, rolled back", gridBLevel));
        return false;
    }

    // Aggiorna arrays Grid A
    gridA_Upper_Tickets[newIndex] = ticketA;
    gridA_Upper_EntryPrices[newIndex] = newLevel;
    gridA_Upper_Status[newIndex] = ORDER_PENDING;
    gridA_Upper_TP[newIndex] = tpGridA;
    gridA_Upper_SL[newIndex] = 0;
    gridA_Upper_Lots[newIndex] = lotSize;
    gridA_Upper_Cycles[newIndex] = 0;
    gridA_Upper_LastClose[newIndex] = 0;

    // Aggiorna arrays Grid B
    gridB_Upper_Tickets[newIndex] = ticketB;
    gridB_Upper_EntryPrices[newIndex] = gridBLevel;
    gridB_Upper_Status[newIndex] = ORDER_PENDING;
    gridB_Upper_TP[newIndex] = tpGridB;
    gridB_Upper_SL[newIndex] = 0;
    gridB_Upper_Lots[newIndex] = lotSize;
    gridB_Upper_Cycles[newIndex] = 0;
    gridB_Upper_LastClose[newIndex] = 0;

    // Log dettagliato inserimento
    LogTrail_GridInserted("ABOVE", newIndex, newLevel, gridBLevel, lotSize, tpGridA, tpGridB);

    return true;
}

//+------------------------------------------------------------------+
//| Insert New Grid Pair Below                                        |
//| Inserisce coppia Grid A (BUY LIMIT) + Grid B (SELL STOP)          |
//+------------------------------------------------------------------+
bool InsertNewGridBelow(double newLevel) {
    int newIndex = GridLevelsPerSide + g_trailExtraGridsBelow;
    if(newIndex >= MAX_GRID_LEVELS) {
        LogTrail_Error("InsertBelow", StringFormat("Array limit reached (%d)", MAX_GRID_LEVELS));
        return false;
    }

    double spacing = currentSpacing_Pips * Trail_Spacing_Multiplier;
    double hedgeOffset = PipsToPoints(Hedge_Spacing_Pips);
    double lotSize = CalculateGridLotSize(newIndex);

    // Grid A: BUY LIMIT
    double tpGridA = CalculateTrailingTP(newLevel, true, spacing);
    int magicA = GetGridMagic(GRID_A);
    string commentA = "Trail_A_L" + IntegerToString(g_trailExtraGridsBelow + 1);

    ulong ticketA = PlacePendingOrder(ORDER_TYPE_BUY_LIMIT, lotSize, newLevel,
                                      0, tpGridA, commentA, magicA);

    if(ticketA == 0) {
        LogTrail_Error("InsertBelow", StringFormat("Failed BUY LIMIT @ %.5f", newLevel));
        return false;
    }

    // Grid B: SELL STOP (hedge a +3 pips)
    double gridBLevel = NormalizeDouble(newLevel + hedgeOffset, symbolDigits);
    double tpGridB = CalculateTrailingTP(gridBLevel, false, spacing);
    int magicB = GetGridMagic(GRID_B);
    string commentB = "Trail_B_L" + IntegerToString(g_trailExtraGridsBelow + 1);

    ulong ticketB = PlacePendingOrder(ORDER_TYPE_SELL_STOP, lotSize, gridBLevel,
                                      0, tpGridB, commentB, magicB);

    if(ticketB == 0) {
        DeletePendingOrder(ticketA);
        LogTrail_Error("InsertBelow", StringFormat("Failed SELL STOP @ %.5f, rolled back", gridBLevel));
        return false;
    }

    // Aggiorna arrays Grid A
    gridA_Lower_Tickets[newIndex] = ticketA;
    gridA_Lower_EntryPrices[newIndex] = newLevel;
    gridA_Lower_Status[newIndex] = ORDER_PENDING;
    gridA_Lower_TP[newIndex] = tpGridA;
    gridA_Lower_SL[newIndex] = 0;
    gridA_Lower_Lots[newIndex] = lotSize;
    gridA_Lower_Cycles[newIndex] = 0;
    gridA_Lower_LastClose[newIndex] = 0;

    // Aggiorna arrays Grid B
    gridB_Lower_Tickets[newIndex] = ticketB;
    gridB_Lower_EntryPrices[newIndex] = gridBLevel;
    gridB_Lower_Status[newIndex] = ORDER_PENDING;
    gridB_Lower_TP[newIndex] = tpGridB;
    gridB_Lower_SL[newIndex] = 0;
    gridB_Lower_Lots[newIndex] = lotSize;
    gridB_Lower_Cycles[newIndex] = 0;
    gridB_Lower_LastClose[newIndex] = 0;

    // Log dettagliato inserimento
    LogTrail_GridInserted("BELOW", newIndex, newLevel, gridBLevel, lotSize, tpGridA, tpGridB);

    return true;
}

//+------------------------------------------------------------------+
//| Remove Distant Grid Below (furthest pending)                      |
//+------------------------------------------------------------------+
bool RemoveDistantGridBelow() {
    double lowestPrice = DBL_MAX;
    int lowestIndex = -1;

    int maxLevel = GridLevelsPerSide + g_trailExtraGridsBelow;
    if(maxLevel > MAX_GRID_LEVELS) maxLevel = MAX_GRID_LEVELS;

    // Trova la grid pending piu lontana sotto
    for(int i = 0; i < maxLevel; i++) {
        if(gridA_Lower_Status[i] == ORDER_PENDING) {
            if(gridA_Lower_EntryPrices[i] < lowestPrice) {
                lowestPrice = gridA_Lower_EntryPrices[i];
                lowestIndex = i;
            }
        }
    }

    if(lowestIndex < 0) {
        if(Trail_DetailedLogging) LogMessage(LOG_DEBUG, "[TrailGrid] No pending grid to remove below");
        return false;
    }

    // Elimina Grid A
    if(gridA_Lower_Tickets[lowestIndex] > 0) {
        DeletePendingOrder(gridA_Lower_Tickets[lowestIndex]);
    }
    // Elimina Grid B
    if(gridB_Lower_Tickets[lowestIndex] > 0) {
        DeletePendingOrder(gridB_Lower_Tickets[lowestIndex]);
    }

    // Reset arrays
    gridA_Lower_Status[lowestIndex] = ORDER_NONE;
    gridA_Lower_Tickets[lowestIndex] = 0;
    gridA_Lower_EntryPrices[lowestIndex] = 0;
    gridB_Lower_Status[lowestIndex] = ORDER_NONE;
    gridB_Lower_Tickets[lowestIndex] = 0;
    gridB_Lower_EntryPrices[lowestIndex] = 0;

    // Log rimozione
    LogTrail_GridRemoved("BELOW", lowestIndex, lowestPrice);
    g_trailLowerRemoved++;
    return true;
}

//+------------------------------------------------------------------+
//| Remove Distant Grid Above (furthest pending)                      |
//+------------------------------------------------------------------+
bool RemoveDistantGridAbove() {
    double highestPrice = 0;
    int highestIndex = -1;

    int maxLevel = GridLevelsPerSide + g_trailExtraGridsAbove;
    if(maxLevel > MAX_GRID_LEVELS) maxLevel = MAX_GRID_LEVELS;

    // Trova la grid pending piu lontana sopra
    for(int i = 0; i < maxLevel; i++) {
        if(gridA_Upper_Status[i] == ORDER_PENDING) {
            if(gridA_Upper_EntryPrices[i] > highestPrice) {
                highestPrice = gridA_Upper_EntryPrices[i];
                highestIndex = i;
            }
        }
    }

    if(highestIndex < 0) {
        if(Trail_DetailedLogging) LogMessage(LOG_DEBUG, "[TrailGrid] No pending grid to remove above");
        return false;
    }

    // Elimina Grid A
    if(gridA_Upper_Tickets[highestIndex] > 0) {
        DeletePendingOrder(gridA_Upper_Tickets[highestIndex]);
    }
    // Elimina Grid B
    if(gridB_Upper_Tickets[highestIndex] > 0) {
        DeletePendingOrder(gridB_Upper_Tickets[highestIndex]);
    }

    // Reset arrays
    gridA_Upper_Status[highestIndex] = ORDER_NONE;
    gridA_Upper_Tickets[highestIndex] = 0;
    gridA_Upper_EntryPrices[highestIndex] = 0;
    gridB_Upper_Status[highestIndex] = ORDER_NONE;
    gridB_Upper_Tickets[highestIndex] = 0;
    gridB_Upper_EntryPrices[highestIndex] = 0;

    // Log rimozione
    LogTrail_GridRemoved("ABOVE", highestIndex, highestPrice);
    g_trailUpperRemoved++;
    return true;
}

//+------------------------------------------------------------------+
//| Update Shield Zone After Trailing                                 |
//+------------------------------------------------------------------+
void UpdateShieldZoneAfterTrailing() {
    if(!Trail_Sync_Shield) return;

    // Calcola nuova Resistance (livello piu alto)
    double effectiveResistance = entryPoint;
    int maxLevelUp = GridLevelsPerSide + g_trailExtraGridsAbove;
    if(maxLevelUp > MAX_GRID_LEVELS) maxLevelUp = MAX_GRID_LEVELS;

    for(int i = 0; i < maxLevelUp; i++) {
        if(gridA_Upper_EntryPrices[i] > effectiveResistance) {
            effectiveResistance = gridA_Upper_EntryPrices[i];
        }
    }

    // Calcola nuovo Support (livello piu basso)
    double effectiveSupport = entryPoint;
    int maxLevelDown = GridLevelsPerSide + g_trailExtraGridsBelow;
    if(maxLevelDown > MAX_GRID_LEVELS) maxLevelDown = MAX_GRID_LEVELS;

    for(int i = 0; i < maxLevelDown; i++) {
        if(gridA_Lower_EntryPrices[i] > 0 && gridA_Lower_EntryPrices[i] < effectiveSupport) {
            effectiveSupport = gridA_Lower_EntryPrices[i];
        }
    }

    if(effectiveSupport == entryPoint) {
        effectiveSupport = entryPoint - PipsToPoints(currentSpacing_Pips * GridLevelsPerSide);
    }

    // Aggiorna shieldZone
    shieldZone.resistance = effectiveResistance;
    shieldZone.support = effectiveSupport;

    double rangeHeight = effectiveResistance - effectiveSupport;
    if(rangeHeight > 0) {
        shieldZone.warningZoneUp = effectiveResistance - (rangeHeight * 0.1);
        shieldZone.warningZoneDown = effectiveSupport + (rangeHeight * 0.1);
    }

    // Aggiorna breakout levels
    double spacingPoints = PipsToPoints(currentSpacing_Pips);
    upperBreakoutLevel = NormalizeDouble(effectiveResistance + (spacingPoints * 0.5), symbolDigits);
    lowerBreakoutLevel = NormalizeDouble(effectiveSupport - (spacingPoints * 0.5), symbolDigits);

    // Aggiorna range bounds
    rangeUpperBound = effectiveResistance;
    rangeLowerBound = effectiveSupport;

    shieldZone.isValid = true;
    shieldZone.lastCalc = TimeCurrent();

    // Log update shield zone
    double rangeHeightPips = (effectiveResistance - effectiveSupport) / PipsToPoints(1);
    LogTrail_ShieldUpdate(effectiveResistance, effectiveSupport, rangeHeightPips);
}

//+------------------------------------------------------------------+
//| Main Processing Function - Called Every Tick                      |
//+------------------------------------------------------------------+
void ProcessTrailingGridCheck() {
    if(!Enable_TrailingGrid) return;
    if(systemState != STATE_ACTIVE) return;

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    //=================================================================
    // CHECK LATO SOPRA (mercato sale)
    //=================================================================
    int pendingAbove = CountPendingGridsAbove(currentPrice);

    // Log debug trigger check
    LogTrail_TriggerCheck("ABOVE", pendingAbove, Trail_Trigger_Level, currentPrice);

    if(pendingAbove <= Trail_Trigger_Level) {
        // Verifica limite extra grids
        if(Trail_Max_Extra_Grids == 0 || g_trailExtraGridsAbove < Trail_Max_Extra_Grids) {

            double newLevel = GetNextGridLevelAbove();

            if(InsertNewGridAbove(newLevel)) {
                g_trailExtraGridsAbove++;
                g_trailUpperAdded++;
                g_currentMaxLevelAbove++;
                g_lastTrailInsertTime = TimeCurrent();
                g_trailActiveAbove = true;

                // Aggiorna Shield
                if(Trail_Sync_Shield) UpdateShieldZoneAfterTrailing();

                // Rimuovi grid lontana dal lato opposto
                if(Trail_Remove_Distant) {
                    int pendingBelowNow = CountPendingGridsBelow(currentPrice);
                    if(pendingBelowNow > Trail_Trigger_Level + 1) {
                        RemoveDistantGridBelow();
                    }
                }

                // Log trigger event
                LogTrail_Triggered("ABOVE", pendingAbove, newLevel, g_trailExtraGridsAbove);
            }
        }
    }

    //=================================================================
    // CHECK LATO SOTTO (mercato scende)
    //=================================================================
    int pendingBelow = CountPendingGridsBelow(currentPrice);

    // Log debug trigger check
    LogTrail_TriggerCheck("BELOW", pendingBelow, Trail_Trigger_Level, currentPrice);

    if(pendingBelow <= Trail_Trigger_Level) {
        if(Trail_Max_Extra_Grids == 0 || g_trailExtraGridsBelow < Trail_Max_Extra_Grids) {

            double newLevel = GetNextGridLevelBelow();

            if(InsertNewGridBelow(newLevel)) {
                g_trailExtraGridsBelow++;
                g_trailLowerAdded++;
                g_currentMaxLevelBelow++;
                g_lastTrailInsertTime = TimeCurrent();
                g_trailActiveBelow = true;

                if(Trail_Sync_Shield) UpdateShieldZoneAfterTrailing();

                if(Trail_Remove_Distant) {
                    int pendingAboveNow = CountPendingGridsAbove(currentPrice);
                    if(pendingAboveNow > Trail_Trigger_Level + 1) {
                        RemoveDistantGridAbove();
                    }
                }

                // Log trigger event
                LogTrail_Triggered("BELOW", pendingBelow, newLevel, g_trailExtraGridsBelow);
            }
        }
    }
}

//+------------------------------------------------------------------+
//| Get Trailing Grid Statistics String (for Dashboard)               |
//+------------------------------------------------------------------+
string GetTrailingGridStats() {
    if(!Enable_TrailingGrid) return "DISABLED";

    return StringFormat("Up%d/%d Dn%d/%d",
                        g_trailExtraGridsAbove, Trail_Max_Extra_Grids,
                        g_trailExtraGridsBelow, Trail_Max_Extra_Grids);
}

//+------------------------------------------------------------------+
//| Reset Trailing Grid State                                         |
//+------------------------------------------------------------------+
void ResetTrailingGridState() {
    // Log statistiche prima del reset
    if(g_trailUpperAdded > 0 || g_trailLowerAdded > 0) {
        LogTrail_Statistics(g_trailUpperAdded, g_trailUpperRemoved, g_trailLowerAdded, g_trailLowerRemoved);
    }

    g_trailExtraGridsAbove = 0;
    g_trailExtraGridsBelow = 0;
    g_trailUpperAdded = 0;
    g_trailUpperRemoved = 0;
    g_trailLowerAdded = 0;
    g_trailLowerRemoved = 0;
    g_currentMaxLevelAbove = GridLevelsPerSide - 1;
    g_currentMaxLevelBelow = GridLevelsPerSide - 1;
    g_trailActiveAbove = false;
    g_trailActiveBelow = false;

    LogMessage(LOG_INFO, "[TrailGrid] State reset");
}

//+------------------------------------------------------------------+
