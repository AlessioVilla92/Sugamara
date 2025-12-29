//+------------------------------------------------------------------+
//|                                          DoubleParcelling.mqh    |
//|                        Sugamara v5.2 - Double Parcelling         |
//|                                                                  |
//|  Split ordini in 2 parcels con TP e Break On Parcelling          |
//|  differenziati per massimizzare profitti                         |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| FORWARD DECLARATIONS                                             |
//+------------------------------------------------------------------+
// Le seguenti funzioni sono definite in altri moduli:
// - PipsToPoints() -> Helpers.mqh
// - LogMessage() -> Helpers.mqh
// - FormatMoney() -> Helpers.mqh
// - ClosePositionPartial_AndTrack() -> OrderManager.mqh (da aggiungere)

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+
bool InitializeDoubleParcelling() {
    if(!Enable_DoubleParcelling) {
        LogMessage(LOG_INFO, "[DP] Double Parcelling: DISABLED");
        return true;
    }

    LogMessage(LOG_INFO, "[DP] Initializing Double Parcelling v5.2...");

    // Reset all DP structures
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        ResetDP_Level(dpA_Upper[i]);
        ResetDP_Level(dpA_Lower[i]);
        ResetDP_Level(dpB_Upper[i]);
        ResetDP_Level(dpB_Lower[i]);
    }

    // Reset statistics
    g_dp_TotalCycles = 0;
    g_dp_TotalProfit = 0;
    g_dp_ParcelA_Active = 0;
    g_dp_ParcelB_Active = 0;

    // Log configuration
    LogMessage(LOG_INFO, "[DP] TP1: " + IntegerToString(DP_TP1_Percent) + "% of spacing");
    LogMessage(LOG_INFO, "[DP] TP2: " + IntegerToString(DP_TP2_Percent) + "% of spacing");
    LogMessage(LOG_INFO, "[DP] BOP1: Trigger=" + IntegerToString(DP_BOP1_Trigger_Percent) +
               "%, SL=" + IntegerToString(DP_BOP1_SL_Percent) + "%");
    LogMessage(LOG_INFO, "[DP] BOP2: Trigger=" + IntegerToString(DP_BOP2_Trigger_Percent) +
               "%, SL=" + IntegerToString(DP_BOP2_SL_Percent) + "%");
    LogMessage(LOG_INFO, "[DP] Lot Ratio: " + IntegerToString(DP_LotRatio) + "/" +
               IntegerToString(100 - DP_LotRatio));

    LogMessage(LOG_SUCCESS, "[DP] Double Parcelling initialized successfully");
    return true;
}

//+------------------------------------------------------------------+
//| DEINITIALIZATION                                                 |
//+------------------------------------------------------------------+
void DeinitializeDoubleParcelling() {
    if(!Enable_DoubleParcelling) return;

    LogMessage(LOG_INFO, "[DP] ═══════════════════════════════════════");
    LogMessage(LOG_INFO, "[DP] Double Parcelling Final Statistics:");
    LogDP_Statistics(g_dp_TotalCycles, g_dp_TotalProfit, g_dp_ParcelA_Active, g_dp_ParcelB_Active);
    LogMessage(LOG_INFO, "[DP] ═══════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| RESET SINGLE LEVEL                                               |
//+------------------------------------------------------------------+
void ResetDP_Level(DoubleParcelling_Level &dp) {
    dp.isActive = false;
    dp.phase = DP_PHASE_INACTIVE;
    dp.originalTicket = 0;
    dp.currentTicket = 0;
    dp.entryPrice = 0;
    dp.tp1_Price = 0;
    dp.tp2_Price = 0;
    dp.tp1_Distance = 0;
    dp.tp2_Distance = 0;
    dp.bop1_Activated = false;
    dp.bop1_TriggerPrice = 0;
    dp.bop1_SL_Price = 0;
    dp.bop2_Activated = false;
    dp.bop2_TriggerPrice = 0;
    dp.bop2_SL_Price = 0;
    dp.parcelA_Closed = false;
    dp.parcelA_Lots = 0;
    dp.parcelA_Profit = 0;
    dp.parcelA_CloseTime = 0;
    dp.parcelB_Closed = false;
    dp.parcelB_Lots = 0;
    dp.parcelB_Profit = 0;
    dp.parcelB_CloseTime = 0;
    dp.currentSL = 0;
    dp.positionType = true;
}

//+------------------------------------------------------------------+
//| GET DP LEVEL POINTER                                             |
//+------------------------------------------------------------------+
DoubleParcelling_Level* GetDP_LevelPtr(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(level < 0 || level >= MAX_GRID_LEVELS) return NULL;

    if(side == GRID_A) {
        if(zone == ZONE_UPPER) return GetPointer(dpA_Upper[level]);
        else return GetPointer(dpA_Lower[level]);
    } else {
        if(zone == ZONE_UPPER) return GetPointer(dpB_Upper[level]);
        else return GetPointer(dpB_Lower[level]);
    }
}

//+------------------------------------------------------------------+
//| SETUP ON FILL - Chiamato quando ordine si attiva                 |
//+------------------------------------------------------------------+
void SetupDP_OnFill(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level,
                     ulong ticket, double entryPrice, double lots, bool isBuy) {

    if(!Enable_DoubleParcelling) return;

    // Validazione spacing
    if(currentSpacing_Pips <= 0) {
        LogMessage(LOG_ERROR, "[DP] Invalid spacing - cannot setup DP");
        return;
    }

    // Validazione lot minimo (deve poter essere diviso)
    double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double parcelA_Lots = NormalizeDouble(lots * DP_LotRatio / 100.0, 2);
    if(parcelA_Lots < minLot) {
        LogMessage(LOG_WARNING, "[DP] Lot too small for parcelling: " +
                   DoubleToString(lots, 2) + " -> Parcel A would be " +
                   DoubleToString(parcelA_Lots, 2) + " (min: " + DoubleToString(minLot, 2) + ")");
        return;
    }

    // Ottieni struttura corretta
    DoubleParcelling_Level* dp = GetDP_LevelPtr(side, zone, level);
    if(dp == NULL) return;

    // Reset prima di setup
    ResetDP_Level(dp);

    // Setup base
    dp.isActive = true;
    dp.phase = DP_PHASE_TRACKING_A;
    dp.originalTicket = ticket;
    dp.currentTicket = ticket;
    dp.entryPrice = entryPrice;
    dp.positionType = isBuy;

    // Calcola distanze TP
    double spacingPoints = PipsToPoints(currentSpacing_Pips);
    dp.tp1_Distance = spacingPoints * DP_TP1_Percent / 100.0;
    dp.tp2_Distance = spacingPoints * DP_TP2_Percent / 100.0;

    // Calcola prezzi TP
    if(isBuy) {
        dp.tp1_Price = NormalizeDouble(entryPrice + dp.tp1_Distance, symbolDigits);
        dp.tp2_Price = NormalizeDouble(entryPrice + dp.tp2_Distance, symbolDigits);
    } else {
        dp.tp1_Price = NormalizeDouble(entryPrice - dp.tp1_Distance, symbolDigits);
        dp.tp2_Price = NormalizeDouble(entryPrice - dp.tp2_Distance, symbolDigits);
    }

    // Calcola prezzi BOP1
    double bop1_TriggerDistance = dp.tp1_Distance * DP_BOP1_Trigger_Percent / 100.0;
    double bop1_SL_Distance = dp.tp1_Distance * DP_BOP1_SL_Percent / 100.0;
    if(isBuy) {
        dp.bop1_TriggerPrice = NormalizeDouble(entryPrice + bop1_TriggerDistance, symbolDigits);
        dp.bop1_SL_Price = NormalizeDouble(entryPrice + bop1_SL_Distance, symbolDigits);
    } else {
        dp.bop1_TriggerPrice = NormalizeDouble(entryPrice - bop1_TriggerDistance, symbolDigits);
        dp.bop1_SL_Price = NormalizeDouble(entryPrice - bop1_SL_Distance, symbolDigits);
    }

    // Calcola prezzi BOP2
    double bop2_TriggerDistance = dp.tp2_Distance * DP_BOP2_Trigger_Percent / 100.0;
    double bop2_SL_Distance = dp.tp2_Distance * DP_BOP2_SL_Percent / 100.0;
    if(isBuy) {
        dp.bop2_TriggerPrice = NormalizeDouble(entryPrice + bop2_TriggerDistance, symbolDigits);
        dp.bop2_SL_Price = NormalizeDouble(entryPrice + bop2_SL_Distance, symbolDigits);
    } else {
        dp.bop2_TriggerPrice = NormalizeDouble(entryPrice - bop2_TriggerDistance, symbolDigits);
        dp.bop2_SL_Price = NormalizeDouble(entryPrice - bop2_SL_Distance, symbolDigits);
    }

    // Calcola lotti parcels
    dp.parcelA_Lots = NormalizeDouble(lots * DP_LotRatio / 100.0, 2);
    dp.parcelB_Lots = NormalizeDouble(lots - dp.parcelA_Lots, 2);

    // Log dettagliato setup con nuove funzioni
    LogDP_Setup(side, zone, level, ticket, entryPrice, lots, dp.parcelA_Lots, dp.parcelB_Lots);
    LogDP_TPLevels(side, zone, level, dp.tp1_Price, dp.tp2_Price, dp.bop1_TriggerPrice, dp.bop2_TriggerPrice);

    g_dp_ParcelA_Active++;
    g_dp_ParcelB_Active++;
}

//+------------------------------------------------------------------+
//| MAIN PROCESSING - Chiamato ogni tick                             |
//+------------------------------------------------------------------+
void ProcessDoubleParcelling() {
    if(!Enable_DoubleParcelling) return;

    // Process Grid A Upper
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        if(dpA_Upper[i].isActive) {
            ProcessDP_SingleLevel(dpA_Upper[i], GRID_A, ZONE_UPPER, i);
        }
    }

    // Process Grid A Lower
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        if(dpA_Lower[i].isActive) {
            ProcessDP_SingleLevel(dpA_Lower[i], GRID_A, ZONE_LOWER, i);
        }
    }

    // Process Grid B Upper
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        if(dpB_Upper[i].isActive) {
            ProcessDP_SingleLevel(dpB_Upper[i], GRID_B, ZONE_UPPER, i);
        }
    }

    // Process Grid B Lower
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        if(dpB_Lower[i].isActive) {
            ProcessDP_SingleLevel(dpB_Lower[i], GRID_B, ZONE_LOWER, i);
        }
    }
}

//+------------------------------------------------------------------+
//| PROCESS SINGLE LEVEL                                             |
//+------------------------------------------------------------------+
void ProcessDP_SingleLevel(DoubleParcelling_Level &dp,
                            ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {

    // Skip se non attivo o completato
    if(!dp.isActive) return;
    if(dp.phase == DP_PHASE_COMPLETED) return;
    if(dp.parcelA_Closed && dp.parcelB_Closed) return;

    // ═══════════════════════════════════════════════════════════════
    // STEP 0: Verifica esistenza posizione (detecta SL hit)
    // ═══════════════════════════════════════════════════════════════
    if(!PositionSelectByTicket(dp.currentTicket)) {
        // Posizione non esiste più!
        HandlePositionClosed_DP(dp, side, zone, level);
        return;
    }

    // Ottieni prezzo corrente
    double currentPrice = dp.positionType ?
                          SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                          SymbolInfoDouble(_Symbol, SYMBOL_ASK);

    // ═══════════════════════════════════════════════════════════════
    // STEP 1: PARCEL A STILL OPEN - Check BOP1 and TP1
    // ═══════════════════════════════════════════════════════════════
    if(!dp.parcelA_Closed) {

        // --- Check BOP1 Trigger ---
        if(!dp.bop1_Activated) {
            bool bop1_Triggered = dp.positionType ?
                                  (currentPrice >= dp.bop1_TriggerPrice) :
                                  (currentPrice <= dp.bop1_TriggerPrice);

            if(bop1_Triggered) {
                // Attiva BOP1 - Sposta SL
                if(ModifyPositionSL_DP(dp.currentTicket, dp.bop1_SL_Price)) {
                    dp.bop1_Activated = true;
                    dp.currentSL = dp.bop1_SL_Price;

                    // Log phase change e BOP activation
                    LogDP_PhaseChange(side, zone, level, "TRACKING_A", "BOP1_ACTIVE");
                    LogDP_BOPActivated(side, zone, level, 1, currentPrice, dp.bop1_SL_Price);

                    dp.phase = DP_PHASE_BOP1_ACTIVE;
                }
            }
        }

        // --- Check TP1 Reached ---
        bool tp1_Reached = dp.positionType ?
                           (currentPrice >= dp.tp1_Price) :
                           (currentPrice <= dp.tp1_Price);

        if(tp1_Reached) {
            // Chiudi Parcel A (partial close)
            ulong newTicket = ClosePositionPartial_AndTrack(
                dp.currentTicket,
                dp.parcelA_Lots,
                side, zone, level
            );

            if(newTicket != dp.currentTicket && newTicket != 0) {
                // Successo! Parcel A chiuso
                dp.parcelA_Closed = true;
                dp.parcelA_CloseTime = TimeCurrent();
                dp.parcelA_Profit = CalculateParcelProfit_DP(dp.parcelA_Lots, dp.tp1_Distance, dp.positionType);
                dp.currentTicket = newTicket;  // Aggiorna ticket!

                // Log parcel close e phase change
                LogDP_ParcelClosed(side, zone, level, "A", dp.parcelA_Lots, dp.parcelA_Profit, dp.tp1_Price);
                LogDP_PhaseChange(side, zone, level, "BOP1_ACTIVE", "TRACKING_B",
                                  "New ticket: #" + IntegerToString(newTicket));

                dp.phase = DP_PHASE_TRACKING_B;
                g_dp_ParcelA_Active--;

            } else if(newTicket == 0) {
                // Tutta la posizione è stata chiusa (errore o lot troppo piccolo)
                dp.parcelA_Closed = true;
                dp.parcelB_Closed = true;
                dp.parcelA_CloseTime = TimeCurrent();
                dp.parcelB_CloseTime = TimeCurrent();

                LogMessage(LOG_WARNING, "[DP] Full position closed at TP1 (unexpected)");
                g_dp_ParcelA_Active--;
                g_dp_ParcelB_Active--;

                CompleteCycle_DP(dp, side, zone, level);
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 2: PARCEL B OPEN - Check BOP2 and TP2
    // ═══════════════════════════════════════════════════════════════
    if(dp.parcelA_Closed && !dp.parcelB_Closed) {

        // Riseleziona posizione (ticket potrebbe essere cambiato)
        if(!PositionSelectByTicket(dp.currentTicket)) {
            HandlePositionClosed_DP(dp, side, zone, level);
            return;
        }

        currentPrice = dp.positionType ?
                       SymbolInfoDouble(_Symbol, SYMBOL_BID) :
                       SymbolInfoDouble(_Symbol, SYMBOL_ASK);

        // --- Check BOP2 Trigger ---
        if(!dp.bop2_Activated) {
            bool bop2_Triggered = dp.positionType ?
                                  (currentPrice >= dp.bop2_TriggerPrice) :
                                  (currentPrice <= dp.bop2_TriggerPrice);

            if(bop2_Triggered) {
                // Attiva BOP2 - Sposta SL
                if(ModifyPositionSL_DP(dp.currentTicket, dp.bop2_SL_Price)) {
                    dp.bop2_Activated = true;
                    dp.currentSL = dp.bop2_SL_Price;

                    // Log phase change e BOP activation
                    LogDP_PhaseChange(side, zone, level, "TRACKING_B", "BOP2_ACTIVE");
                    LogDP_BOPActivated(side, zone, level, 2, currentPrice, dp.bop2_SL_Price);

                    dp.phase = DP_PHASE_BOP2_ACTIVE;
                }
            }
        }

        // --- Check TP2 Reached ---
        bool tp2_Reached = dp.positionType ?
                           (currentPrice >= dp.tp2_Price) :
                           (currentPrice <= dp.tp2_Price);

        if(tp2_Reached) {
            // Chiudi Parcel B (tutto)
            if(ClosePosition(dp.currentTicket)) {
                dp.parcelB_Closed = true;
                dp.parcelB_CloseTime = TimeCurrent();
                dp.parcelB_Profit = CalculateParcelProfit_DP(dp.parcelB_Lots, dp.tp2_Distance, dp.positionType);

                // Log parcel close
                LogDP_ParcelClosed(side, zone, level, "B", dp.parcelB_Lots, dp.parcelB_Profit, dp.tp2_Price);
                LogDP_PhaseChange(side, zone, level, "BOP2_ACTIVE", "COMPLETED",
                                  "Total profit: " + FormatMoney(dp.parcelA_Profit + dp.parcelB_Profit));

                g_dp_ParcelB_Active--;
            }
        }
    }

    // ═══════════════════════════════════════════════════════════════
    // STEP 3: Check if both closed → Complete Cycle
    // ═══════════════════════════════════════════════════════════════
    if(dp.parcelA_Closed && dp.parcelB_Closed) {
        CompleteCycle_DP(dp, side, zone, level);
    }
}

//+------------------------------------------------------------------+
//| HANDLE POSITION CLOSED (By Broker SL or external)                |
//+------------------------------------------------------------------+
void HandlePositionClosed_DP(DoubleParcelling_Level &dp,
                              ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {

    // Recupera profit da history
    double profit = GetHistoricalOrderProfit(dp.currentTicket);

    string gridStr = (side == GRID_A) ? "A" : "B";
    string zoneStr = (zone == ZONE_UPPER) ? "Upper" : "Lower";

    if(!dp.parcelA_Closed) {
        // SL hit prima di TP1 - entrambi i parcels chiusi insieme
        dp.parcelA_Closed = true;
        dp.parcelB_Closed = true;
        dp.parcelA_CloseTime = TimeCurrent();
        dp.parcelB_CloseTime = TimeCurrent();
        dp.parcelA_Profit = profit / 2;  // Approssimazione
        dp.parcelB_Profit = profit / 2;

        LogMessage(LOG_INFO, "[DP] Position closed by SL (before TP1) " + gridStr + "-" + zoneStr +
                   " L" + IntegerToString(level+1) +
                   " | Profit: " + FormatMoney(profit));

        g_dp_ParcelA_Active--;
        g_dp_ParcelB_Active--;
    } else {
        // SL hit su Parcel B (dopo che A era già chiuso)
        dp.parcelB_Closed = true;
        dp.parcelB_CloseTime = TimeCurrent();
        dp.parcelB_Profit = profit;

        LogMessage(LOG_INFO, "[DP] Parcel B closed by SL (BOP) " + gridStr + "-" + zoneStr +
                   " L" + IntegerToString(level+1) +
                   " | Profit: " + FormatMoney(profit));

        g_dp_ParcelB_Active--;
    }

    // Complete cycle
    CompleteCycle_DP(dp, side, zone, level);
}

//+------------------------------------------------------------------+
//| COMPLETE CYCLE                                                   |
//+------------------------------------------------------------------+
void CompleteCycle_DP(DoubleParcelling_Level &dp,
                       ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {

    // Update statistics
    g_dp_TotalCycles++;
    double cycleProfit = dp.parcelA_Profit + dp.parcelB_Profit;
    g_dp_TotalProfit += cycleProfit;

    // Log cycle complete con funzione dedicata
    LogDP_CycleComplete(side, zone, level, dp.parcelA_Profit, dp.parcelB_Profit, cycleProfit);

    // Update grid status to allow recycling
    SetGridStatus_DP(side, zone, level, ORDER_CLOSED_TP);

    // Mark as completed and reset
    dp.phase = DP_PHASE_COMPLETED;
    dp.isActive = false;

    // Log statistiche aggregate
    LogDP_Statistics(g_dp_TotalCycles, g_dp_TotalProfit, g_dp_ParcelA_Active, g_dp_ParcelB_Active);

    // Don't fully reset - keep stats for logging
    // ResetDP_Level(dp);  // Commented out to preserve cycle data
}

//+------------------------------------------------------------------+
//| SET GRID STATUS - Helper per aggiornare status grid              |
//+------------------------------------------------------------------+
void SetGridStatus_DP(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, ENUM_ORDER_STATUS status) {
    if(side == GRID_A) {
        if(zone == ZONE_UPPER) gridA_Upper_Status[level] = status;
        else gridA_Lower_Status[level] = status;
    } else {
        if(zone == ZONE_UPPER) gridB_Upper_Status[level] = status;
        else gridB_Lower_Status[level] = status;
    }
}

//+------------------------------------------------------------------+
//| IS WAITING FOR PARCEL B - Per Cyclic Reopen                      |
//+------------------------------------------------------------------+
bool IsWaitingForParcelB(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(!Enable_DoubleParcelling) return false;

    DoubleParcelling_Level* dp = GetDP_LevelPtr(side, zone, level);
    if(dp == NULL) return false;
    if(!dp.isActive) return false;

    // Se Parcel A chiuso ma B no → BLOCCA recycling
    return (dp.parcelA_Closed && !dp.parcelB_Closed);
}

//+------------------------------------------------------------------+
//| MODIFY POSITION SL - Helper per modificare SL                    |
//+------------------------------------------------------------------+
bool ModifyPositionSL_DP(ulong ticket, double newSL) {
    if(ticket == 0) return false;
    if(!PositionSelectByTicket(ticket)) return false;

    newSL = NormalizeDouble(newSL, symbolDigits);

    // Mantieni TP = 0 per gestione manuale
    return trade.PositionModify(ticket, newSL, 0);
}

//+------------------------------------------------------------------+
//| CALCULATE PARCEL PROFIT - Stima profit                           |
//+------------------------------------------------------------------+
double CalculateParcelProfit_DP(double lots, double distancePoints, bool isBuy) {
    // Tick value per il simbolo
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);

    if(tickSize <= 0) return 0;

    // Profit = (distance / tickSize) * tickValue * lots
    double profit = (distancePoints / tickSize) * tickValue * lots;

    return profit;
}

//+------------------------------------------------------------------+
//| GET DP STATUS STRING - Per dashboard                             |
//+------------------------------------------------------------------+
string GetDP_StatusString(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(!Enable_DoubleParcelling) return "OFF";

    DoubleParcelling_Level* dp = GetDP_LevelPtr(side, zone, level);
    if(dp == NULL) return "N/A";
    if(!dp.isActive) return "-";

    switch(dp.phase) {
        case DP_PHASE_INACTIVE:   return "-";
        case DP_PHASE_TRACKING_A: return "A";
        case DP_PHASE_BOP1_ACTIVE: return "A+";
        case DP_PHASE_TRACKING_B: return "B";
        case DP_PHASE_BOP2_ACTIVE: return "B+";
        case DP_PHASE_COMPLETED:  return "OK";
        default: return "?";
    }
}

//+------------------------------------------------------------------+
