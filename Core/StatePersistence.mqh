//+------------------------------------------------------------------+
//|                                             StatePersistence.mqh |
//|                        SUGAMARA v9.26 - State Persistence        |
//|                                                                  |
//|  Modulo per salvare/ripristinare stato completo EA               |
//|  - Auto-save periodico ogni N minuti                             |
//|  - Event-save su eventi critici                                  |
//|  - Restore completo: arrays, cycling, COP, grafica               |
//|                                                                  |
//|  CRITICO: Preserva Reopen Cycling dopo crash/restart             |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025-2026"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| GLOBAL VARIABLE PREFIX                                            |
//+------------------------------------------------------------------+
#define GV_STATE_PREFIX "SUGAMARA_STATE_"

//+------------------------------------------------------------------+
//| STATE PERSISTENCE VARIABLES                                       |
//+------------------------------------------------------------------+
datetime g_lastAutoSaveTime = 0;            // Timestamp ultimo auto-save
bool g_lastAutoSaveSuccess = false;         // v9.22: Risultato ultimo backup
int g_savedVariableCount = 0;               // Contatore variabili salvate
bool g_stateRestored = false;               // Flag: stato ripristinato
int g_restoredVariableCount = 0;            // Contatore variabili ripristinate

// Error tracking per logging avanzato
int g_saveErrors = 0;                       // Contatore errori durante save
int g_restoreErrors = 0;                    // Contatore errori durante restore
int g_mergeConflicts = 0;                   // Contatore conflitti merge

//+------------------------------------------------------------------+
//| ADVANCED LOGGING SYSTEM - Categories                              |
//| Using SP_ prefix to avoid conflict with ENUM_LOG_LEVEL            |
//+------------------------------------------------------------------+
#define SP_LOG_AUTOSAVE    "[AUTO-SAVE]"
#define SP_LOG_RECOVERY    "[RECOVERY]"
#define SP_LOG_RESTORE     "[RESTORE]"
#define SP_LOG_ERROR       "[ERROR]"
#define SP_LOG_WARNING     "[WARNING]"
#define SP_LOG_SUCCESS     "[OK]"
#define SP_LOG_SECTION     "[SECTION]"

//+------------------------------------------------------------------+
//| LOG SECTION HEADER - Inizio sezione                               |
//+------------------------------------------------------------------+
void LogSection_Start(string category, string sectionName) {
    if(!AutoSave_FullLogging) return;
    Print("-----------------------------------------------------------------------");
    PrintFormat("%s %s >>> %s - START", category, SP_LOG_SECTION, sectionName);
}

//+------------------------------------------------------------------+
//| LOG SECTION END - Fine sezione con risultato                      |
//+------------------------------------------------------------------+
void LogSection_End(string category, string sectionName, int itemCount, int errorCount) {
    if(!AutoSave_FullLogging) return;
    string status = (errorCount == 0) ? SP_LOG_SUCCESS : SP_LOG_ERROR;
    PrintFormat("%s %s <<< %s - END | Items: %d | Errors: %d %s",
                category, SP_LOG_SECTION, sectionName, itemCount, errorCount, status);
}

//+------------------------------------------------------------------+
//| LOG ITEM - Singolo elemento salvato/ripristinato                  |
//+------------------------------------------------------------------+
void LogItem(string category, string itemName, string value) {
    if(!AutoSave_FullLogging) return;
    PrintFormat("%s     %s = %s", category, itemName, value);
}

//+------------------------------------------------------------------+
//| LOG ARRAY SUMMARY - Riepilogo array salvato/ripristinato          |
//+------------------------------------------------------------------+
void LogArraySummary(string category, string arrayName, int savedCount, int totalCount) {
    if(!AutoSave_FullLogging) return;
    PrintFormat("%s     %s: %d/%d elements", category, arrayName, savedCount, totalCount);
}

//+------------------------------------------------------------------+
//| LOG ERROR - Errore durante operazione                             |
//+------------------------------------------------------------------+
void LogPersistenceError(string category, string operation, string details) {
    // Errori sempre loggati (anche senza FullLogging)
    PrintFormat("%s %s %s FAILED: %s", category, SP_LOG_ERROR, operation, details);
    if(category == SP_LOG_AUTOSAVE) g_saveErrors++;
    else if(category == SP_LOG_RESTORE) g_restoreErrors++;
}

//+------------------------------------------------------------------+
//| LOG WARNING - Avviso non critico                                  |
//+------------------------------------------------------------------+
void LogPersistenceWarning(string category, string message) {
    if(!AutoSave_FullLogging) return;
    PrintFormat("%s %s %s", category, SP_LOG_WARNING, message);
}

//+------------------------------------------------------------------+
//| LOG MERGE CONFLICT - Conflitto durante merge                      |
//+------------------------------------------------------------------+
void LogMergeConflict(string gridZone, int level, string brokerStatus, string savedStatus, string resolution) {
    if(!AutoSave_FullLogging) return;
    PrintFormat("%s [MERGE] %s L%d: Broker=%s vs Saved=%s -> %s",
                SP_LOG_RESTORE, gridZone, level, brokerStatus, savedStatus, resolution);
    g_mergeConflicts++;
}

//+------------------------------------------------------------------+
//| LOG CYCLING RESTORE - Dettaglio ripristino cycling                |
//+------------------------------------------------------------------+
void LogCyclingRestore(string gridZone, int level, string status, int cycles, datetime lastClose) {
    if(!AutoSave_FullLogging) return;
    string lastCloseStr = (lastClose > 0) ? TimeToString(lastClose, TIME_DATE|TIME_SECONDS) : "never";
    PrintFormat("%s     %s L%d: Status=%s | Cycles=%d | LastClose=%s",
                SP_LOG_RESTORE, gridZone, level, status, cycles, lastCloseStr);
}

//+------------------------------------------------------------------+
//| LOG SAVE REPORT - Report finale salvataggio                       |
//+------------------------------------------------------------------+
void LogSaveReport(datetime saveTime, int totalVars, int errors) {
    Print("=======================================================================");
    PrintFormat("%s SAVE REPORT - %s", SP_LOG_AUTOSAVE, TimeToString(saveTime, TIME_DATE|TIME_SECONDS));
    Print("=======================================================================");
    PrintFormat("  Total Variables Saved: %d", totalVars);
    PrintFormat("  Errors: %d", errors);
    PrintFormat("  File Backup: %s", AutoSave_UseFileBackup ? "ENABLED" : "DISABLED");
    PrintFormat("  Next Save In: %d minutes", AutoSave_Interval_Minutes);
    if(errors > 0) {
        Print("  STATUS: COMPLETED WITH ERRORS - Check logs above");
    } else {
        Print("  STATUS: SUCCESS");
    }
    Print("=======================================================================");
}

//+------------------------------------------------------------------+
//| LOG RESTORE REPORT - Report finale ripristino                     |
//+------------------------------------------------------------------+
void LogRestoreReport(datetime savedTime, int totalVars, int errors, int merges) {
    Print("=======================================================================");
    PrintFormat("%s RESTORE REPORT", SP_LOG_RESTORE);
    Print("=======================================================================");
    PrintFormat("  State Saved At: %s", TimeToString(savedTime, TIME_DATE|TIME_SECONDS));
    PrintFormat("  Age: %d minutes", (int)((TimeCurrent() - savedTime) / 60));
    PrintFormat("  Variables Restored: %d", totalVars);
    PrintFormat("  Merge Conflicts Resolved: %d", merges);
    PrintFormat("  Errors: %d", errors);
    if(errors > 0) {
        Print("  STATUS: COMPLETED WITH ERRORS - Some data may be missing");
    } else {
        Print("  STATUS: SUCCESS - All data restored");
    }
    Print("=======================================================================");
}

//+------------------------------------------------------------------+
//| GET GLOBAL VARIABLE KEY                                           |
//| Genera chiave univoca per simbolo                                 |
//+------------------------------------------------------------------+
string GetStateKey(string varName) {
    return GV_STATE_PREFIX + _Symbol + "_" + varName;
}

//+------------------------------------------------------------------+
//| GET STATE FILE PATH                                               |
//| File backup per stato completo                                    |
//+------------------------------------------------------------------+
string GetStateFilePath() {
    return "sugamara_state_" + _Symbol + ".bin";
}

//+------------------------------------------------------------------+
//| GET ENTRY POINT BACKUP FILE PATH                                  |
//+------------------------------------------------------------------+
string GetEntryPointBackupFilePath() {
    return "sugamara_entry_" + _Symbol + ".txt";
}

//+------------------------------------------------------------------+
//| GET LAST REOPENS BACKUP FILE PATH (v9.23)                         |
//+------------------------------------------------------------------+
string GetLastReopensBackupFilePath() {
    return "sugamara_reopens_" + _Symbol + ".txt";
}

//+------------------------------------------------------------------+
//| HAS SAVED STATE?                                                   |
//| Controlla se esiste stato salvato valido (usato in OnInit)         |
//+------------------------------------------------------------------+
bool HasSavedState() {
    if(!Enable_AutoRecovery) return false;

    // Controlla se esiste timestamp ultimo salvataggio
    if(!GlobalVariableCheck(GetStateKey("lastSaveTime"))) {
        return false;
    }

    // Controlla eta' stato salvato (max 7 giorni)
    datetime lastSave = (datetime)GlobalVariableGet(GetStateKey("lastSaveTime"));
    datetime now = TimeCurrent();
    if(now - lastSave > 7 * 24 * 60 * 60) {
        Print("[AUTO-SAVE] Saved state too old (", (now - lastSave) / 86400, " days) - ignoring");
        return false;
    }

    // Verifica che ci siano dati significativi (entry point)
    double savedEntry = GlobalVariableGet(GetStateKey("entryPoint"));
    return (savedEntry > 0);
}

//+------------------------------------------------------------------+
//| SHOULD AUTO-SAVE NOW?                                             |
//| Controlla se e' tempo di eseguire auto-save                       |
//+------------------------------------------------------------------+
bool ShouldAutoSaveNow() {
    if(!Enable_AutoSave) return false;
    if(systemState != STATE_ACTIVE) return false;  // Salva solo se attivo
    if(g_lastAutoSaveTime == 0) return true;  // Prima volta

    int intervalSeconds = AutoSave_Interval_Minutes * 60;
    return (TimeCurrent() - g_lastAutoSaveTime >= intervalSeconds);
}

//+------------------------------------------------------------------+
//| EXECUTE AUTO-SAVE                                                 |
//| Chiamare da OnTick - controlla intervallo e salva                 |
//+------------------------------------------------------------------+
void ExecuteAutoSave() {
    if(!ShouldAutoSaveNow()) return;

    if(AutoSave_FullLogging) {
        Print("[AUTO-SAVE] Executing periodic save...");
    }

    SaveCompleteState();
    g_lastAutoSaveTime = TimeCurrent();
    g_lastAutoSaveSuccess = (g_saveErrors == 0);  // v9.22: Track success for dashboard

    if(AutoSave_FullLogging) {
        Print("[AUTO-SAVE] Complete - ", g_savedVariableCount, " variables saved");
    }
}

//+------------------------------------------------------------------+
//| SAVE COMPLETE STATE                                               |
//| Salva TUTTO lo stato dell'EA su GlobalVariables + File            |
//+------------------------------------------------------------------+
void SaveCompleteState() {
    g_savedVariableCount = 0;
    g_saveErrors = 0;
    int sectionItems = 0;
    int sectionErrors = 0;

    if(AutoSave_FullLogging) {
        Print("=======================================================================");
        PrintFormat("%s STARTING COMPLETE STATE SAVE - %s", SP_LOG_AUTOSAVE, _Symbol);
        Print("=======================================================================");
    }

    //=================================================================
    // SECTION 1: CORE SYSTEM STATE
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "CORE SYSTEM STATE");
    sectionItems = 0; sectionErrors = 0;

    if(!SaveStateDouble("entryPoint", entryPoint)) sectionErrors++;
    else { sectionItems++; LogItem(SP_LOG_AUTOSAVE, "entryPoint", DoubleToString(entryPoint, 5)); }

    if(!SaveStateInt("entryPointTime", (int)entryPointTime)) sectionErrors++;
    else { sectionItems++; LogItem(SP_LOG_AUTOSAVE, "entryPointTime", TimeToString(entryPointTime)); }

    if(!SaveStateDouble("currentSpacing", currentSpacing_Pips)) sectionErrors++;
    else { sectionItems++; LogItem(SP_LOG_AUTOSAVE, "currentSpacing", DoubleToString(currentSpacing_Pips, 1) + " pips"); }

    if(!SaveStateInt("systemState", (int)systemState)) sectionErrors++;
    else sectionItems++;

    if(!SaveStateBool("systemActive", systemActive)) sectionErrors++;
    else sectionItems++;

    if(!SaveStateInt("systemStartTime", (int)systemStartTime)) sectionErrors++;
    else sectionItems++;

    // Backup entry point anche su file
    if(AutoSave_UseFileBackup) {
        if(!SaveEntryPointToFile()) {
            sectionErrors++;
            LogPersistenceError(SP_LOG_AUTOSAVE, "SaveEntryPointToFile", "Failed to write backup file");
        } else {
            LogItem(SP_LOG_AUTOSAVE, "File Backup", "OK");
        }
    }

    LogSection_End(SP_LOG_AUTOSAVE, "CORE SYSTEM STATE", sectionItems, sectionErrors);
    g_saveErrors += sectionErrors;

    //=================================================================
    // SECTION 1B: PROGRESSIVE SPACING STATE (v9.26)
    //=================================================================
    if(SpacingMode == SPACING_PROGRESSIVE_PERCENTAGE || SpacingMode == SPACING_PROGRESSIVE_LINEAR) {
        LogSection_Start(SP_LOG_AUTOSAVE, "PROGRESSIVE SPACING STATE (v9.26)");
        sectionItems = 0; sectionErrors = 0;

        if(!SaveStateDouble("progressiveSpacingBase", progressiveSpacingBase)) sectionErrors++;
        else { sectionItems++; LogItem(SP_LOG_AUTOSAVE, "progressiveSpacingBase", DoubleToString(progressiveSpacingBase, 1) + " pips"); }

        if(!SaveStateDouble("progressiveSpacingRate", progressiveSpacingRate)) sectionErrors++;
        else { sectionItems++; LogItem(SP_LOG_AUTOSAVE, "progressiveSpacingRate", DoubleToString(progressiveSpacingRate * 100, 1) + "%"); }

        if(!SaveStateDouble("progressiveLinearIncrement", progressiveLinearIncrement)) sectionErrors++;
        else { sectionItems++; LogItem(SP_LOG_AUTOSAVE, "progressiveLinearIncrement", DoubleToString(progressiveLinearIncrement, 1) + " pips"); }

        if(!SaveStateInt("progressiveStartLevel", progressiveStartLevel)) sectionErrors++;
        else { sectionItems++; LogItem(SP_LOG_AUTOSAVE, "progressiveStartLevel", IntegerToString(progressiveStartLevel)); }

        if(!SaveStateBool("g_progressiveInitialized", g_progressiveInitialized)) sectionErrors++;
        else sectionItems++;

        LogSection_End(SP_LOG_AUTOSAVE, "PROGRESSIVE SPACING STATE", sectionItems, sectionErrors);
        g_saveErrors += sectionErrors;
    }

    //=================================================================
    // SECTION 2: GRID ARRAYS - STATUS (CRITICO per Cycling!)
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "GRID STATUS ARRAYS (Cycling Critical)");
    sectionItems = 0; sectionErrors = 0;
    int statusSaved = 0;

    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        if(SaveStateInt("gAU_Status_" + IntegerToString(i), (int)gridA_Upper_Status[i])) statusSaved++;
        if(SaveStateInt("gAL_Status_" + IntegerToString(i), (int)gridA_Lower_Status[i])) statusSaved++;
        if(SaveStateInt("gBU_Status_" + IntegerToString(i), (int)gridB_Upper_Status[i])) statusSaved++;
        if(SaveStateInt("gBL_Status_" + IntegerToString(i), (int)gridB_Lower_Status[i])) statusSaved++;
    }
    sectionItems = statusSaved;
    LogArraySummary(SP_LOG_AUTOSAVE, "Grid Status Arrays", statusSaved, MAX_GRID_LEVELS * 4);
    LogSection_End(SP_LOG_AUTOSAVE, "GRID STATUS ARRAYS", sectionItems, sectionErrors);

    //=================================================================
    // SECTION 3: GRID ARRAYS - CYCLES (CRITICO per Cycling!)
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "GRID CYCLES ARRAYS (Cycling Critical)");
    int cyclesSaved = 0;
    int totalCycles = 0;

    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        if(SaveStateInt("gAU_Cycles_" + IntegerToString(i), gridA_Upper_Cycles[i])) cyclesSaved++;
        if(SaveStateInt("gAL_Cycles_" + IntegerToString(i), gridA_Lower_Cycles[i])) cyclesSaved++;
        if(SaveStateInt("gBU_Cycles_" + IntegerToString(i), gridB_Upper_Cycles[i])) cyclesSaved++;
        if(SaveStateInt("gBL_Cycles_" + IntegerToString(i), gridB_Lower_Cycles[i])) cyclesSaved++;
        totalCycles += gridA_Upper_Cycles[i] + gridA_Lower_Cycles[i] + gridB_Upper_Cycles[i] + gridB_Lower_Cycles[i];
    }
    LogArraySummary(SP_LOG_AUTOSAVE, "Grid Cycles Arrays", cyclesSaved, MAX_GRID_LEVELS * 4);
    LogItem(SP_LOG_AUTOSAVE, "Total Cycles Sum", IntegerToString(totalCycles));
    LogSection_End(SP_LOG_AUTOSAVE, "GRID CYCLES ARRAYS", cyclesSaved, 0);

    //=================================================================
    // SECTION 4: GRID ARRAYS - LAST CLOSE (CRITICO per Cycling!)
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "GRID LASTCLOSE ARRAYS (Cycling Critical)");
    int lastCloseSaved = 0;

    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        if(SaveStateInt("gAU_LastClose_" + IntegerToString(i), (int)gridA_Upper_LastClose[i])) lastCloseSaved++;
        if(SaveStateInt("gAL_LastClose_" + IntegerToString(i), (int)gridA_Lower_LastClose[i])) lastCloseSaved++;
        if(SaveStateInt("gBU_LastClose_" + IntegerToString(i), (int)gridB_Upper_LastClose[i])) lastCloseSaved++;
        if(SaveStateInt("gBL_LastClose_" + IntegerToString(i), (int)gridB_Lower_LastClose[i])) lastCloseSaved++;
    }
    LogArraySummary(SP_LOG_AUTOSAVE, "Grid LastClose Arrays", lastCloseSaved, MAX_GRID_LEVELS * 4);
    LogSection_End(SP_LOG_AUTOSAVE, "GRID LASTCLOSE ARRAYS", lastCloseSaved, 0);

    //=================================================================
    // SECTION 5: GRID ARRAYS - TICKETS
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "GRID TICKETS ARRAYS");
    int ticketsSaved = 0;

    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        if(SaveStateUlong("gAU_Ticket_" + IntegerToString(i), gridA_Upper_Tickets[i])) ticketsSaved++;
        if(SaveStateUlong("gAL_Ticket_" + IntegerToString(i), gridA_Lower_Tickets[i])) ticketsSaved++;
        if(SaveStateUlong("gBU_Ticket_" + IntegerToString(i), gridB_Upper_Tickets[i])) ticketsSaved++;
        if(SaveStateUlong("gBL_Ticket_" + IntegerToString(i), gridB_Lower_Tickets[i])) ticketsSaved++;
    }
    LogArraySummary(SP_LOG_AUTOSAVE, "Grid Tickets Arrays", ticketsSaved, MAX_GRID_LEVELS * 4);
    LogSection_End(SP_LOG_AUTOSAVE, "GRID TICKETS ARRAYS", ticketsSaved, 0);

    //=================================================================
    // SECTION 6: GRID ARRAYS - ENTRY PRICES
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "GRID PRICES ARRAYS");
    int pricesSaved = 0;
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        if(SaveStateDouble("gAU_Price_" + IntegerToString(i), gridA_Upper_EntryPrices[i])) pricesSaved++;
        if(SaveStateDouble("gAL_Price_" + IntegerToString(i), gridA_Lower_EntryPrices[i])) pricesSaved++;
        if(SaveStateDouble("gBU_Price_" + IntegerToString(i), gridB_Upper_EntryPrices[i])) pricesSaved++;
        if(SaveStateDouble("gBL_Price_" + IntegerToString(i), gridB_Lower_EntryPrices[i])) pricesSaved++;
    }
    LogArraySummary(SP_LOG_AUTOSAVE, "Grid Prices Arrays", pricesSaved, MAX_GRID_LEVELS * 4);
    LogSection_End(SP_LOG_AUTOSAVE, "GRID PRICES ARRAYS", pricesSaved, 0);

    //=================================================================
    // SECTION 7: GRID ARRAYS - LOTS
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "GRID LOTS ARRAYS");
    int lotsSaved = 0;
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        if(SaveStateDouble("gAU_Lots_" + IntegerToString(i), gridA_Upper_Lots[i])) lotsSaved++;
        if(SaveStateDouble("gAL_Lots_" + IntegerToString(i), gridA_Lower_Lots[i])) lotsSaved++;
        if(SaveStateDouble("gBU_Lots_" + IntegerToString(i), gridB_Upper_Lots[i])) lotsSaved++;
        if(SaveStateDouble("gBL_Lots_" + IntegerToString(i), gridB_Lower_Lots[i])) lotsSaved++;
    }
    LogArraySummary(SP_LOG_AUTOSAVE, "Grid Lots Arrays", lotsSaved, MAX_GRID_LEVELS * 4);
    LogSection_End(SP_LOG_AUTOSAVE, "GRID LOTS ARRAYS", lotsSaved, 0);

    //=================================================================
    // SECTION 8: GRID ARRAYS - TP
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "GRID TP ARRAYS");
    int tpSaved = 0;
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        if(SaveStateDouble("gAU_TP_" + IntegerToString(i), gridA_Upper_TP[i])) tpSaved++;
        if(SaveStateDouble("gAL_TP_" + IntegerToString(i), gridA_Lower_TP[i])) tpSaved++;
        if(SaveStateDouble("gBU_TP_" + IntegerToString(i), gridB_Upper_TP[i])) tpSaved++;
        if(SaveStateDouble("gBL_TP_" + IntegerToString(i), gridB_Lower_TP[i])) tpSaved++;
    }
    LogArraySummary(SP_LOG_AUTOSAVE, "Grid TP Arrays", tpSaved, MAX_GRID_LEVELS * 4);
    LogSection_End(SP_LOG_AUTOSAVE, "GRID TP ARRAYS", tpSaved, 0);

    //=================================================================
    // SECTION 9: GRID COUNTERS (Dashboard Statistics)
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "GRID COUNTERS");
    int countersSaved = 0;
    if(SaveStateInt("gridA_ClosedCount", g_gridA_ClosedCount)) countersSaved++;
    if(SaveStateInt("gridA_PendingCount", g_gridA_PendingCount)) countersSaved++;
    if(SaveStateInt("gridB_ClosedCount", g_gridB_ClosedCount)) countersSaved++;
    if(SaveStateInt("gridB_PendingCount", g_gridB_PendingCount)) countersSaved++;
    if(SaveStateInt("gridA_LimitFilled", g_gridA_LimitFilled)) countersSaved++;
    if(SaveStateInt("gridA_LimitCycles", g_gridA_LimitCycles)) countersSaved++;
    if(SaveStateInt("gridA_LimitReopens", g_gridA_LimitReopens)) countersSaved++;
    if(SaveStateInt("gridA_StopFilled", g_gridA_StopFilled)) countersSaved++;
    if(SaveStateInt("gridA_StopCycles", g_gridA_StopCycles)) countersSaved++;
    if(SaveStateInt("gridA_StopReopens", g_gridA_StopReopens)) countersSaved++;
    if(SaveStateInt("gridB_LimitFilled", g_gridB_LimitFilled)) countersSaved++;
    if(SaveStateInt("gridB_LimitCycles", g_gridB_LimitCycles)) countersSaved++;
    if(SaveStateInt("gridB_LimitReopens", g_gridB_LimitReopens)) countersSaved++;
    if(SaveStateInt("gridB_StopFilled", g_gridB_StopFilled)) countersSaved++;
    if(SaveStateInt("gridB_StopCycles", g_gridB_StopCycles)) countersSaved++;
    if(SaveStateInt("gridB_StopReopens", g_gridB_StopReopens)) countersSaved++;
    LogItem(SP_LOG_AUTOSAVE, "Grid A Closed/Pending", IntegerToString(g_gridA_ClosedCount) + "/" + IntegerToString(g_gridA_PendingCount));
    LogItem(SP_LOG_AUTOSAVE, "Grid B Closed/Pending", IntegerToString(g_gridB_ClosedCount) + "/" + IntegerToString(g_gridB_PendingCount));
    LogSection_End(SP_LOG_AUTOSAVE, "GRID COUNTERS", countersSaved, 0);

    //=================================================================
    // SECTION 9B: LAST REOPENS (v9.23: Dashboard display persistence)
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "LAST REOPENS (v9.23)");
    sectionErrors = 0;
    if(AutoSave_UseFileBackup) {
        if(!SaveLastReopensToFile()) {
            sectionErrors++;
            LogPersistenceError(SP_LOG_AUTOSAVE, "SaveLastReopensToFile", "Failed to write backup file");
        } else {
            LogItem(SP_LOG_AUTOSAVE, "Last Reopens Count", IntegerToString(g_lastReopensCount));
            for(int i = 0; i < g_lastReopensCount; i++) {
                LogItem(SP_LOG_AUTOSAVE, StringFormat("Reopen[%d]", i), g_lastReopens[i]);
            }
        }
    }
    LogSection_End(SP_LOG_AUTOSAVE, "LAST REOPENS", g_lastReopensCount, sectionErrors);
    g_saveErrors += sectionErrors;

    //=================================================================
    // SECTION 10: COP STATE (Close On Profit)
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "COP STATE");
    int copSaved = 0;
    if(SaveStateDouble("cop_RealizedProfit", cop_RealizedProfit)) copSaved++;
    if(SaveStateDouble("cop_FloatingProfit", cop_FloatingProfit)) copSaved++;
    if(SaveStateDouble("cop_TotalCommissions", cop_TotalCommissions)) copSaved++;
    if(SaveStateDouble("cop_NetProfit", cop_NetProfit)) copSaved++;
    if(SaveStateBool("cop_TargetReached", cop_TargetReached)) copSaved++;
    if(SaveStateInt("cop_TradesToday", cop_TradesToday)) copSaved++;
    if(SaveStateDouble("cop_TotalLotsToday", cop_TotalLotsToday)) copSaved++;
    if(SaveStateInt("cop_LastResetDate", (int)cop_LastResetDate)) copSaved++;
    LogItem(SP_LOG_AUTOSAVE, "COP Net Profit", "$" + DoubleToString(cop_NetProfit, 2));
    LogItem(SP_LOG_AUTOSAVE, "COP Target Reached", cop_TargetReached ? "YES" : "NO");
    LogSection_End(SP_LOG_AUTOSAVE, "COP STATE", copSaved, 0);

    //=================================================================
    // SECTION 11: SESSION STATISTICS
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "SESSION STATISTICS");
    int sessionSaved = 0;
    if(SaveStateDouble("sessionRealizedProfit", sessionRealizedProfit)) sessionSaved++;
    if(SaveStateDouble("sessionPeakProfit", sessionPeakProfit)) sessionSaved++;
    if(SaveStateDouble("sessionGrossProfit", sessionGrossProfit)) sessionSaved++;
    if(SaveStateDouble("sessionGrossLoss", sessionGrossLoss)) sessionSaved++;
    if(SaveStateInt("sessionWins", sessionWins)) sessionSaved++;
    if(SaveStateInt("sessionLosses", sessionLosses)) sessionSaved++;
    if(SaveStateInt("totalTrades", totalTrades)) sessionSaved++;
    if(SaveStateDouble("dailyRealizedProfit", dailyRealizedProfit)) sessionSaved++;
    if(SaveStateInt("dailyWins", dailyWins)) sessionSaved++;
    if(SaveStateInt("dailyLosses", dailyLosses)) sessionSaved++;
    if(SaveStateDouble("dailyPeakEquity", dailyPeakEquity)) sessionSaved++;
    LogItem(SP_LOG_AUTOSAVE, "Session Profit", "$" + DoubleToString(sessionRealizedProfit, 2));
    LogItem(SP_LOG_AUTOSAVE, "Win/Loss", IntegerToString(sessionWins) + "/" + IntegerToString(sessionLosses));
    LogSection_End(SP_LOG_AUTOSAVE, "SESSION STATISTICS", sessionSaved, 0);

    //=================================================================
    // SECTION 12: RISK TRACKING
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "RISK TRACKING");
    int riskSaved = 0;
    if(SaveStateDouble("startingEquity", startingEquity)) riskSaved++;
    if(SaveStateDouble("startingBalance", startingBalance)) riskSaved++;
    if(SaveStateDouble("maxEquityReached", maxEquityReached)) riskSaved++;
    if(SaveStateDouble("maxDrawdownReached", maxDrawdownReached)) riskSaved++;
    LogItem(SP_LOG_AUTOSAVE, "Max Drawdown", DoubleToString(maxDrawdownReached, 2) + "%");
    LogSection_End(SP_LOG_AUTOSAVE, "RISK TRACKING", riskSaved, 0);

    //=================================================================
    // SECTION 13: EXPOSURE
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "EXPOSURE");
    int exposureSaved = 0;
    if(SaveStateDouble("totalLongLots", totalLongLots)) exposureSaved++;
    if(SaveStateDouble("totalShortLots", totalShortLots)) exposureSaved++;
    if(SaveStateDouble("netExposure", netExposure)) exposureSaved++;
    if(SaveStateBool("isNeutral", isNeutral)) exposureSaved++;
    LogItem(SP_LOG_AUTOSAVE, "Long/Short Lots", DoubleToString(totalLongLots, 2) + "/" + DoubleToString(totalShortLots, 2));
    LogItem(SP_LOG_AUTOSAVE, "Net Exposure", DoubleToString(netExposure, 2) + " lots");
    LogSection_End(SP_LOG_AUTOSAVE, "EXPOSURE", exposureSaved, 0);

    //=================================================================
    // SECTION 14: ATR CACHE
    //=================================================================
    LogSection_Start(SP_LOG_AUTOSAVE, "ATR CACHE");
    int atrSaved = 0;
    if(SaveStateDouble("atrCache_valuePips", g_atrCache.valuePips)) atrSaved++;
    if(SaveStateInt("atrCache_lastUpdate", (int)g_atrCache.lastFullUpdate)) atrSaved++;
    if(SaveStateInt("atrCache_lastBar", (int)g_atrCache.lastBarTime)) atrSaved++;
    if(SaveStateBool("atrCache_isValid", g_atrCache.isValid)) atrSaved++;
    if(SaveStateDouble("currentATR_Pips", currentATR_Pips)) atrSaved++;
    LogItem(SP_LOG_AUTOSAVE, "ATR Value", DoubleToString(currentATR_Pips, 1) + " pips");
    LogSection_End(SP_LOG_AUTOSAVE, "ATR CACHE", atrSaved, 0);

    //=================================================================
    // SECTION 15: STRADDLE STATE (se abilitato)
    //=================================================================
    if(Straddle_Enabled) {
        LogSection_Start(SP_LOG_AUTOSAVE, "STRADDLE STATE");
        int straddleSaved = 0;
        if(SaveStateBool("straddle_isActive", straddle.isActive)) straddleSaved++;
        if(SaveStateInt("straddle_currentRound", straddle.currentRound)) straddleSaved++;
        if(SaveStateBool("straddle_inCoverMode", straddle.inCoverMode)) straddleSaved++;
        if(SaveStateDouble("straddle_entryPrice", straddle.entryPrice)) straddleSaved++;
        if(SaveStateDouble("straddle_buyStopPrice", straddle.buyStopPrice)) straddleSaved++;
        if(SaveStateDouble("straddle_sellStopPrice", straddle.sellStopPrice)) straddleSaved++;
        if(SaveStateUlong("straddle_buyTicket", straddle.buyStopTicket)) straddleSaved++;
        if(SaveStateUlong("straddle_sellTicket", straddle.sellStopTicket)) straddleSaved++;
        if(SaveStateDouble("straddle_buyLotSize", straddle.currentBuyLot)) straddleSaved++;
        if(SaveStateDouble("straddle_sellLotSize", straddle.currentSellLot)) straddleSaved++;
        if(SaveStateDouble("straddle_totalBuyLot", straddle.totalBuyLot)) straddleSaved++;
        if(SaveStateDouble("straddle_totalSellLot", straddle.totalSellLot)) straddleSaved++;
        if(SaveStateInt("straddle_buyPositions", straddle.totalBuyPositions)) straddleSaved++;
        if(SaveStateInt("straddle_sellPositions", straddle.totalSellPositions)) straddleSaved++;
        if(SaveStateInt("straddle_lastCloseTime", (int)straddle.lastCloseTime)) straddleSaved++;
        if(SaveStateInt("straddle_lastFillType", (int)straddle.lastFillType)) straddleSaved++;
        LogItem(SP_LOG_AUTOSAVE, "Straddle Active", straddle.isActive ? "YES" : "NO");
        LogItem(SP_LOG_AUTOSAVE, "Current Round", IntegerToString(straddle.currentRound));
        LogSection_End(SP_LOG_AUTOSAVE, "STRADDLE STATE", straddleSaved, 0);
    }

    //=================================================================
    // SECTION 16: MANUAL S/R (se abilitato)
    //=================================================================
    if(Enable_ManualSR) {
        LogSection_Start(SP_LOG_AUTOSAVE, "MANUAL S/R");
        int srSaved = 0;
        if(SaveStateDouble("manualSR_Resistance", manualSR_Resistance)) srSaved++;
        if(SaveStateDouble("manualSR_Support", manualSR_Support)) srSaved++;
        if(SaveStateDouble("manualSR_Activation", manualSR_Activation)) srSaved++;
        if(SaveStateBool("manualSR_Initialized", manualSR_Initialized)) srSaved++;
        LogItem(SP_LOG_AUTOSAVE, "Resistance", DoubleToString(manualSR_Resistance, 5));
        LogItem(SP_LOG_AUTOSAVE, "Support", DoubleToString(manualSR_Support, 5));
        LogSection_End(SP_LOG_AUTOSAVE, "MANUAL S/R", srSaved, 0);
    }

    //=================================================================
    // SECTION 17: TIMESTAMP ULTIMO SAVE
    //=================================================================
    SaveStateInt("lastSaveTime", (int)TimeCurrent());

    // FINAL REPORT
    if(AutoSave_FullLogging) {
        LogSaveReport(TimeCurrent(), g_savedVariableCount, g_saveErrors);
    } else {
        // Log minimo anche senza FullLogging
        PrintFormat("%s Complete - %d vars saved, %d errors", SP_LOG_AUTOSAVE, g_savedVariableCount, g_saveErrors);
    }
}

//+------------------------------------------------------------------+
//| SAVE ENTRY POINT TO FILE BACKUP                                   |
//| Doppio backup: GlobalVariable + File per garanzia 100%            |
//+------------------------------------------------------------------+
bool SaveEntryPointToFile() {
    if(entryPoint <= 0) return false;

    string filePath = GetEntryPointBackupFilePath();
    int handle = FileOpen(filePath, FILE_WRITE|FILE_TXT|FILE_COMMON);
    if(handle == INVALID_HANDLE) {
        return false;
    }

    string data = DoubleToString(entryPoint, 8) + ";" +
                  DoubleToString(currentSpacing_Pips, 2) + ";" +
                  IntegerToString(entryPointTime);
    uint bytesWritten = FileWriteString(handle, data);
    FileClose(handle);

    return (bytesWritten > 0);
}

//+------------------------------------------------------------------+
//| LOAD ENTRY POINT FROM FILE BACKUP                                 |
//| Fallback se GlobalVariable non disponibile                        |
//+------------------------------------------------------------------+
bool LoadEntryPointFromFile(double &entry, double &spacing, datetime &entryTime) {
    string filePath = GetEntryPointBackupFilePath();
    int handle = FileOpen(filePath, FILE_READ|FILE_TXT|FILE_COMMON);
    if(handle == INVALID_HANDLE) return false;

    string data = FileReadString(handle);
    FileClose(handle);

    if(StringLen(data) < 5) return false;

    string parts[];
    int count = StringSplit(data, ';', parts);
    if(count >= 2) {
        entry = StringToDouble(parts[0]);
        spacing = StringToDouble(parts[1]);
        if(count >= 3) entryTime = (datetime)StringToInteger(parts[2]);
        return (entry > 0 && spacing > 0);
    }
    return false;
}

//+------------------------------------------------------------------+
//| SAVE LAST REOPENS TO FILE (v9.23)                                  |
//| Salva g_lastReopens[] su file per persistence                      |
//+------------------------------------------------------------------+
bool SaveLastReopensToFile() {
    if(g_lastReopensCount == 0) return true;  // Nothing to save

    string filePath = GetLastReopensBackupFilePath();
    int handle = FileOpen(filePath, FILE_WRITE|FILE_TXT|FILE_COMMON);
    if(handle == INVALID_HANDLE) {
        return false;
    }

    // Format: count;string1;string2;string3
    string data = IntegerToString(g_lastReopensCount);
    for(int i = 0; i < MAX_LAST_REOPENS; i++) {
        data += ";" + g_lastReopens[i];
    }

    uint bytesWritten = FileWriteString(handle, data);
    FileClose(handle);

    return (bytesWritten > 0);
}

//+------------------------------------------------------------------+
//| LOAD LAST REOPENS FROM FILE (v9.23)                                |
//| Ripristina g_lastReopens[] da file                                 |
//+------------------------------------------------------------------+
bool LoadLastReopensFromFile() {
    string filePath = GetLastReopensBackupFilePath();
    int handle = FileOpen(filePath, FILE_READ|FILE_TXT|FILE_COMMON);
    if(handle == INVALID_HANDLE) return false;

    string data = FileReadString(handle);
    FileClose(handle);

    if(StringLen(data) < 1) return false;

    string parts[];
    int count = StringSplit(data, ';', parts);
    if(count >= 1) {
        g_lastReopensCount = (int)StringToInteger(parts[0]);
        if(g_lastReopensCount > MAX_LAST_REOPENS) g_lastReopensCount = MAX_LAST_REOPENS;

        for(int i = 0; i < MAX_LAST_REOPENS && i + 1 < count; i++) {
            g_lastReopens[i] = parts[i + 1];
        }
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| SHOULD AUTO-RESTORE?                                              |
//| Controlla se dovremmo ripristinare stato salvato                  |
//+------------------------------------------------------------------+
bool ShouldAutoRestore() {
    if(!Enable_AutoRecovery) return false;

    // Controlla se esiste stato salvato
    if(!GlobalVariableCheck(GetStateKey("lastSaveTime"))) {
        return false;
    }

    // Controlla eta' stato salvato (max 7 giorni)
    datetime lastSave = (datetime)LoadStateInt("lastSaveTime", 0);
    datetime now = TimeCurrent();
    if(now - lastSave > 7 * 24 * 60 * 60) {
        Print("[RESTORE] Saved state too old (", (now - lastSave) / 86400, " days) - ignoring");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| RESTORE COMPLETE STATE WITH MERGE                                 |
//| Ripristina stato salvato CON MERGE intelligente con broker        |
//| CRITICO: Preserva ORDER_CLOSED_TP per Cycling!                    |
//+------------------------------------------------------------------+
bool RestoreCompleteStateWithMerge() {
    if(!Enable_AutoRecovery) return false;

    datetime lastSave = (datetime)LoadStateInt("lastSaveTime", 0);
    if(lastSave == 0) {
        LogPersistenceError(SP_LOG_RESTORE, "RestoreCompleteStateWithMerge", "No saved state found");
        return false;
    }

    g_restoredVariableCount = 0;
    g_restoreErrors = 0;
    g_mergeConflicts = 0;
    int sectionItems = 0;
    int sectionErrors = 0;

    if(AutoSave_FullLogging) {
        Print("=======================================================================");
        PrintFormat("%s STARTING STATE RESTORATION - %s", SP_LOG_RESTORE, _Symbol);
        Print("=======================================================================");
        PrintFormat("%s State saved at: %s (Age: %d minutes)",
                    SP_LOG_RESTORE, TimeToString(lastSave, TIME_DATE|TIME_SECONDS),
                    (int)((TimeCurrent() - lastSave) / 60));
    }

    //=================================================================
    // SECTION 1: CORE SYSTEM STATE
    //=================================================================
    LogSection_Start(SP_LOG_RESTORE, "CORE SYSTEM STATE");
    sectionItems = 0; sectionErrors = 0;

    // Entry point: usa salvato se valido, altrimenti prova file backup
    double savedEntry = LoadStateDouble("entryPoint", 0);
    if(savedEntry > 0) {
        entryPoint = savedEntry;
        sectionItems++;
        LogItem(SP_LOG_RESTORE, "entryPoint (GV)", DoubleToString(entryPoint, 5));
    } else if(AutoSave_UseFileBackup) {
        double fileEntry = 0, fileSpacing = 0;
        datetime fileTime = 0;
        if(LoadEntryPointFromFile(fileEntry, fileSpacing, fileTime)) {
            entryPoint = fileEntry;
            currentSpacing_Pips = fileSpacing;
            entryPointTime = fileTime;
            sectionItems += 3;
            LogItem(SP_LOG_RESTORE, "entryPoint (FILE)", DoubleToString(entryPoint, 5));
            LogPersistenceWarning(SP_LOG_RESTORE, "Used file backup (GlobalVariable not found)");
        } else {
            sectionErrors++;
            LogPersistenceError(SP_LOG_RESTORE, "LoadEntryPoint", "Both GV and file backup failed");
        }
    }

    entryPointTime = (datetime)LoadStateInt("entryPointTime", (int)entryPointTime);
    currentSpacing_Pips = LoadStateDouble("currentSpacing", currentSpacing_Pips);
    sectionItems += 2;
    LogItem(SP_LOG_RESTORE, "entryPointTime", TimeToString(entryPointTime));
    LogItem(SP_LOG_RESTORE, "currentSpacing", DoubleToString(currentSpacing_Pips, 1) + " pips");

    // System state: mantieni ACTIVE se recovery ha trovato ordini
    ENUM_SYSTEM_STATE savedState = (ENUM_SYSTEM_STATE)LoadStateInt("systemState", (int)STATE_IDLE);
    if(savedState == STATE_ACTIVE && systemState != STATE_ACTIVE) {
        systemState = STATE_ACTIVE;
        LogItem(SP_LOG_RESTORE, "systemState", "ACTIVE (restored from saved)");
    } else {
        LogItem(SP_LOG_RESTORE, "systemState", "Kept broker recovery state");
    }
    sectionItems++;

    systemStartTime = (datetime)LoadStateInt("systemStartTime", (int)systemStartTime);
    sectionItems++;
    g_restoredVariableCount += 5;

    LogSection_End(SP_LOG_RESTORE, "CORE SYSTEM STATE", sectionItems, sectionErrors);
    g_restoreErrors += sectionErrors;

    //=================================================================
    // SECTION 1B: PROGRESSIVE SPACING STATE (v9.26)
    //=================================================================
    if(SpacingMode == SPACING_PROGRESSIVE_PERCENTAGE || SpacingMode == SPACING_PROGRESSIVE_LINEAR) {
        LogSection_Start(SP_LOG_RESTORE, "PROGRESSIVE SPACING STATE (v9.26)");
        sectionItems = 0;

        // Restore progressive spacing variables only if not already initialized
        if(!g_progressiveInitialized) {
            double savedBase = LoadStateDouble("progressiveSpacingBase", 0);
            if(savedBase > 0) {
                progressiveSpacingBase = savedBase;
                sectionItems++;
                LogItem(SP_LOG_RESTORE, "progressiveSpacingBase", DoubleToString(progressiveSpacingBase, 1) + " pips");
            }

            double savedRate = LoadStateDouble("progressiveSpacingRate", 0);
            if(savedRate > 0) {
                progressiveSpacingRate = savedRate;
                sectionItems++;
                LogItem(SP_LOG_RESTORE, "progressiveSpacingRate", DoubleToString(progressiveSpacingRate * 100, 1) + "%");
            }

            double savedLinear = LoadStateDouble("progressiveLinearIncrement", 0);
            if(savedLinear > 0) {
                progressiveLinearIncrement = savedLinear;
                sectionItems++;
                LogItem(SP_LOG_RESTORE, "progressiveLinearIncrement", DoubleToString(progressiveLinearIncrement, 1) + " pips");
            }

            int savedStartLevel = LoadStateInt("progressiveStartLevel", -1);
            if(savedStartLevel >= 0) {
                progressiveStartLevel = savedStartLevel;
                sectionItems++;
                LogItem(SP_LOG_RESTORE, "progressiveStartLevel", IntegerToString(progressiveStartLevel));
            }

            g_progressiveInitialized = LoadStateBool("g_progressiveInitialized", false);
            if(g_progressiveInitialized) sectionItems++;

            g_restoredVariableCount += sectionItems;
        } else {
            LogPersistenceWarning(SP_LOG_RESTORE, "Progressive already initialized - skipping restore");
        }

        LogSection_End(SP_LOG_RESTORE, "PROGRESSIVE SPACING STATE", sectionItems, 0);
    }

    //=================================================================
    // SECTION 2-4: GRID ARRAYS CON MERGE INTELLIGENTE
    // CRITICO: Se broker non ha trovato ordine ma saved state ha
    // ORDER_CLOSED_TP, ripristina per continuare cycling!
    //=================================================================
    if(Recovery_RestoreCycling) {
        LogSection_Start(SP_LOG_RESTORE, "GRID ARRAYS WITH MERGE (Cycling Critical)");
        int statusMerged = 0;
        int cyclesRestored = 0;
        int totalCyclesSum = 0;
        int pricesRestored = 0;

        for(int i = 0; i < MAX_GRID_LEVELS; i++) {
            //--- GRID A UPPER ---
            if(gridA_Upper_Status[i] == ORDER_NONE) {
                ENUM_ORDER_STATUS savedStatus = (ENUM_ORDER_STATUS)LoadStateInt("gAU_Status_" + IntegerToString(i), (int)ORDER_NONE);
                if(savedStatus == ORDER_CLOSED_TP || savedStatus == ORDER_CLOSED_SL || savedStatus == ORDER_CANCELLED) {
                    gridA_Upper_Status[i] = savedStatus;
                    statusMerged++;
                    LogMergeConflict("GridA_Upper", i, "ORDER_NONE", EnumToString(savedStatus), "RESTORED");
                }
            }
            gridA_Upper_Cycles[i] = LoadStateInt("gAU_Cycles_" + IntegerToString(i), gridA_Upper_Cycles[i]);
            gridA_Upper_LastClose[i] = (datetime)LoadStateInt("gAU_LastClose_" + IntegerToString(i), (int)gridA_Upper_LastClose[i]);
            if(gridA_Upper_Cycles[i] > 0) {
                cyclesRestored++;
                totalCyclesSum += gridA_Upper_Cycles[i];
            }
            if(gridA_Upper_EntryPrices[i] == 0) {
                gridA_Upper_EntryPrices[i] = LoadStateDouble("gAU_Price_" + IntegerToString(i), 0);
                if(gridA_Upper_EntryPrices[i] > 0) pricesRestored++;
            }
            if(gridA_Upper_Tickets[i] == 0) {
                gridA_Upper_Tickets[i] = LoadStateUlong("gAU_Ticket_" + IntegerToString(i), 0);
            }
            if(gridA_Upper_Lots[i] == 0) {
                gridA_Upper_Lots[i] = LoadStateDouble("gAU_Lots_" + IntegerToString(i), 0);
            }
            if(gridA_Upper_TP[i] == 0) {
                gridA_Upper_TP[i] = LoadStateDouble("gAU_TP_" + IntegerToString(i), 0);
            }

            //--- GRID A LOWER ---
            if(gridA_Lower_Status[i] == ORDER_NONE) {
                ENUM_ORDER_STATUS savedStatus = (ENUM_ORDER_STATUS)LoadStateInt("gAL_Status_" + IntegerToString(i), (int)ORDER_NONE);
                if(savedStatus == ORDER_CLOSED_TP || savedStatus == ORDER_CLOSED_SL || savedStatus == ORDER_CANCELLED) {
                    gridA_Lower_Status[i] = savedStatus;
                    statusMerged++;
                    LogMergeConflict("GridA_Lower", i, "ORDER_NONE", EnumToString(savedStatus), "RESTORED");
                }
            }
            gridA_Lower_Cycles[i] = LoadStateInt("gAL_Cycles_" + IntegerToString(i), gridA_Lower_Cycles[i]);
            gridA_Lower_LastClose[i] = (datetime)LoadStateInt("gAL_LastClose_" + IntegerToString(i), (int)gridA_Lower_LastClose[i]);
            if(gridA_Lower_Cycles[i] > 0) {
                cyclesRestored++;
                totalCyclesSum += gridA_Lower_Cycles[i];
            }
            if(gridA_Lower_EntryPrices[i] == 0) {
                gridA_Lower_EntryPrices[i] = LoadStateDouble("gAL_Price_" + IntegerToString(i), 0);
                if(gridA_Lower_EntryPrices[i] > 0) pricesRestored++;
            }
            if(gridA_Lower_Tickets[i] == 0) {
                gridA_Lower_Tickets[i] = LoadStateUlong("gAL_Ticket_" + IntegerToString(i), 0);
            }
            if(gridA_Lower_Lots[i] == 0) {
                gridA_Lower_Lots[i] = LoadStateDouble("gAL_Lots_" + IntegerToString(i), 0);
            }
            if(gridA_Lower_TP[i] == 0) {
                gridA_Lower_TP[i] = LoadStateDouble("gAL_TP_" + IntegerToString(i), 0);
            }

            //--- GRID B UPPER ---
            if(gridB_Upper_Status[i] == ORDER_NONE) {
                ENUM_ORDER_STATUS savedStatus = (ENUM_ORDER_STATUS)LoadStateInt("gBU_Status_" + IntegerToString(i), (int)ORDER_NONE);
                if(savedStatus == ORDER_CLOSED_TP || savedStatus == ORDER_CLOSED_SL || savedStatus == ORDER_CANCELLED) {
                    gridB_Upper_Status[i] = savedStatus;
                    statusMerged++;
                    LogMergeConflict("GridB_Upper", i, "ORDER_NONE", EnumToString(savedStatus), "RESTORED");
                }
            }
            gridB_Upper_Cycles[i] = LoadStateInt("gBU_Cycles_" + IntegerToString(i), gridB_Upper_Cycles[i]);
            gridB_Upper_LastClose[i] = (datetime)LoadStateInt("gBU_LastClose_" + IntegerToString(i), (int)gridB_Upper_LastClose[i]);
            if(gridB_Upper_Cycles[i] > 0) {
                cyclesRestored++;
                totalCyclesSum += gridB_Upper_Cycles[i];
            }
            if(gridB_Upper_EntryPrices[i] == 0) {
                gridB_Upper_EntryPrices[i] = LoadStateDouble("gBU_Price_" + IntegerToString(i), 0);
                if(gridB_Upper_EntryPrices[i] > 0) pricesRestored++;
            }
            if(gridB_Upper_Tickets[i] == 0) {
                gridB_Upper_Tickets[i] = LoadStateUlong("gBU_Ticket_" + IntegerToString(i), 0);
            }
            if(gridB_Upper_Lots[i] == 0) {
                gridB_Upper_Lots[i] = LoadStateDouble("gBU_Lots_" + IntegerToString(i), 0);
            }
            if(gridB_Upper_TP[i] == 0) {
                gridB_Upper_TP[i] = LoadStateDouble("gBU_TP_" + IntegerToString(i), 0);
            }

            //--- GRID B LOWER ---
            if(gridB_Lower_Status[i] == ORDER_NONE) {
                ENUM_ORDER_STATUS savedStatus = (ENUM_ORDER_STATUS)LoadStateInt("gBL_Status_" + IntegerToString(i), (int)ORDER_NONE);
                if(savedStatus == ORDER_CLOSED_TP || savedStatus == ORDER_CLOSED_SL || savedStatus == ORDER_CANCELLED) {
                    gridB_Lower_Status[i] = savedStatus;
                    statusMerged++;
                    LogMergeConflict("GridB_Lower", i, "ORDER_NONE", EnumToString(savedStatus), "RESTORED");
                }
            }
            gridB_Lower_Cycles[i] = LoadStateInt("gBL_Cycles_" + IntegerToString(i), gridB_Lower_Cycles[i]);
            gridB_Lower_LastClose[i] = (datetime)LoadStateInt("gBL_LastClose_" + IntegerToString(i), (int)gridB_Lower_LastClose[i]);
            if(gridB_Lower_Cycles[i] > 0) {
                cyclesRestored++;
                totalCyclesSum += gridB_Lower_Cycles[i];
            }
            if(gridB_Lower_EntryPrices[i] == 0) {
                gridB_Lower_EntryPrices[i] = LoadStateDouble("gBL_Price_" + IntegerToString(i), 0);
                if(gridB_Lower_EntryPrices[i] > 0) pricesRestored++;
            }
            if(gridB_Lower_Tickets[i] == 0) {
                gridB_Lower_Tickets[i] = LoadStateUlong("gBL_Ticket_" + IntegerToString(i), 0);
            }
            if(gridB_Lower_Lots[i] == 0) {
                gridB_Lower_Lots[i] = LoadStateDouble("gBL_Lots_" + IntegerToString(i), 0);
            }
            if(gridB_Lower_TP[i] == 0) {
                gridB_Lower_TP[i] = LoadStateDouble("gBL_TP_" + IntegerToString(i), 0);
            }

            g_restoredVariableCount += 28;  // 7 variabili x 4 zone
        }

        LogItem(SP_LOG_RESTORE, "Status Merged (CLOSED_TP/SL)", IntegerToString(statusMerged) + " levels");
        LogItem(SP_LOG_RESTORE, "Levels with Cycles > 0", IntegerToString(cyclesRestored));
        LogItem(SP_LOG_RESTORE, "Total Cycles Sum", IntegerToString(totalCyclesSum));
        LogItem(SP_LOG_RESTORE, "Prices Restored", IntegerToString(pricesRestored));
        LogSection_End(SP_LOG_RESTORE, "GRID ARRAYS WITH MERGE", MAX_GRID_LEVELS * 28, 0);
    } else {
        LogPersistenceWarning(SP_LOG_RESTORE, "Recovery_RestoreCycling DISABLED - Grid arrays skipped");
    }

    //=================================================================
    // SECTION 5: GRID COUNTERS
    //=================================================================
    LogSection_Start(SP_LOG_RESTORE, "GRID COUNTERS");
    g_gridA_ClosedCount = LoadStateInt("gridA_ClosedCount", g_gridA_ClosedCount);
    g_gridA_PendingCount = LoadStateInt("gridA_PendingCount", g_gridA_PendingCount);
    g_gridB_ClosedCount = LoadStateInt("gridB_ClosedCount", g_gridB_ClosedCount);
    g_gridB_PendingCount = LoadStateInt("gridB_PendingCount", g_gridB_PendingCount);
    g_gridA_LimitFilled = LoadStateInt("gridA_LimitFilled", g_gridA_LimitFilled);
    g_gridA_LimitCycles = LoadStateInt("gridA_LimitCycles", g_gridA_LimitCycles);
    g_gridA_LimitReopens = LoadStateInt("gridA_LimitReopens", g_gridA_LimitReopens);
    g_gridA_StopFilled = LoadStateInt("gridA_StopFilled", g_gridA_StopFilled);
    g_gridA_StopCycles = LoadStateInt("gridA_StopCycles", g_gridA_StopCycles);
    g_gridA_StopReopens = LoadStateInt("gridA_StopReopens", g_gridA_StopReopens);
    g_gridB_LimitFilled = LoadStateInt("gridB_LimitFilled", g_gridB_LimitFilled);
    g_gridB_LimitCycles = LoadStateInt("gridB_LimitCycles", g_gridB_LimitCycles);
    g_gridB_LimitReopens = LoadStateInt("gridB_LimitReopens", g_gridB_LimitReopens);
    g_gridB_StopFilled = LoadStateInt("gridB_StopFilled", g_gridB_StopFilled);
    g_gridB_StopCycles = LoadStateInt("gridB_StopCycles", g_gridB_StopCycles);
    g_gridB_StopReopens = LoadStateInt("gridB_StopReopens", g_gridB_StopReopens);
    g_restoredVariableCount += 16;
    LogItem(SP_LOG_RESTORE, "Grid A Closed/Pending", IntegerToString(g_gridA_ClosedCount) + "/" + IntegerToString(g_gridA_PendingCount));
    LogItem(SP_LOG_RESTORE, "Grid B Closed/Pending", IntegerToString(g_gridB_ClosedCount) + "/" + IntegerToString(g_gridB_PendingCount));
    LogItem(SP_LOG_RESTORE, "Total Cycles (A+B)", IntegerToString(g_gridA_LimitCycles + g_gridA_StopCycles + g_gridB_LimitCycles + g_gridB_StopCycles));
    LogSection_End(SP_LOG_RESTORE, "GRID COUNTERS", 16, 0);

    //=================================================================
    // SECTION 5B: LAST REOPENS (v9.23: Dashboard display persistence)
    //=================================================================
    LogSection_Start(SP_LOG_RESTORE, "LAST REOPENS (v9.23)");
    if(LoadLastReopensFromFile()) {
        LogItem(SP_LOG_RESTORE, "Last Reopens Count", IntegerToString(g_lastReopensCount));
        for(int i = 0; i < g_lastReopensCount; i++) {
            LogItem(SP_LOG_RESTORE, StringFormat("Reopen[%d]", i), g_lastReopens[i]);
        }
        g_restoredVariableCount += g_lastReopensCount + 1;
        LogSection_End(SP_LOG_RESTORE, "LAST REOPENS", g_lastReopensCount, 0);
    } else {
        LogPersistenceWarning(SP_LOG_RESTORE, "Last Reopens file not found or empty - dashboard will start fresh");
        LogSection_End(SP_LOG_RESTORE, "LAST REOPENS", 0, 0);
    }

    //=================================================================
    // SECTION 6: COP STATE
    //=================================================================
    if(Recovery_RestoreCOP) {
        LogSection_Start(SP_LOG_RESTORE, "COP STATE");
        cop_RealizedProfit = LoadStateDouble("cop_RealizedProfit", cop_RealizedProfit);
        cop_FloatingProfit = LoadStateDouble("cop_FloatingProfit", cop_FloatingProfit);
        cop_TotalCommissions = LoadStateDouble("cop_TotalCommissions", cop_TotalCommissions);
        cop_NetProfit = LoadStateDouble("cop_NetProfit", cop_NetProfit);
        cop_TargetReached = LoadStateBool("cop_TargetReached", cop_TargetReached);
        cop_TradesToday = LoadStateInt("cop_TradesToday", cop_TradesToday);
        cop_TotalLotsToday = LoadStateDouble("cop_TotalLotsToday", cop_TotalLotsToday);
        cop_LastResetDate = (datetime)LoadStateInt("cop_LastResetDate", (int)cop_LastResetDate);
        g_restoredVariableCount += 8;
        LogItem(SP_LOG_RESTORE, "COP Net Profit", "$" + DoubleToString(cop_NetProfit, 2));
        LogItem(SP_LOG_RESTORE, "COP Target Reached", cop_TargetReached ? "YES" : "NO");
        LogItem(SP_LOG_RESTORE, "Trades Today", IntegerToString(cop_TradesToday));
        LogSection_End(SP_LOG_RESTORE, "COP STATE", 8, 0);
    } else {
        LogPersistenceWarning(SP_LOG_RESTORE, "Recovery_RestoreCOP DISABLED - COP state skipped");
    }

    //=================================================================
    // SECTION 7: SESSION STATISTICS
    //=================================================================
    if(Recovery_RestoreSession) {
        LogSection_Start(SP_LOG_RESTORE, "SESSION STATISTICS");
        sessionRealizedProfit = LoadStateDouble("sessionRealizedProfit", sessionRealizedProfit);
        sessionPeakProfit = LoadStateDouble("sessionPeakProfit", sessionPeakProfit);
        sessionGrossProfit = LoadStateDouble("sessionGrossProfit", sessionGrossProfit);
        sessionGrossLoss = LoadStateDouble("sessionGrossLoss", sessionGrossLoss);
        sessionWins = LoadStateInt("sessionWins", sessionWins);
        sessionLosses = LoadStateInt("sessionLosses", sessionLosses);
        totalTrades = LoadStateInt("totalTrades", totalTrades);
        dailyRealizedProfit = LoadStateDouble("dailyRealizedProfit", dailyRealizedProfit);
        dailyWins = LoadStateInt("dailyWins", dailyWins);
        dailyLosses = LoadStateInt("dailyLosses", dailyLosses);
        dailyPeakEquity = LoadStateDouble("dailyPeakEquity", dailyPeakEquity);
        g_restoredVariableCount += 11;
        LogItem(SP_LOG_RESTORE, "Session Profit", "$" + DoubleToString(sessionRealizedProfit, 2));
        LogItem(SP_LOG_RESTORE, "Win/Loss", IntegerToString(sessionWins) + "/" + IntegerToString(sessionLosses));
        LogItem(SP_LOG_RESTORE, "Total Trades", IntegerToString(totalTrades));
        LogSection_End(SP_LOG_RESTORE, "SESSION STATISTICS", 11, 0);
    } else {
        LogPersistenceWarning(SP_LOG_RESTORE, "Recovery_RestoreSession DISABLED - Session stats skipped");
    }

    //=================================================================
    // SECTION 8: RISK TRACKING
    //=================================================================
    LogSection_Start(SP_LOG_RESTORE, "RISK TRACKING");
    startingEquity = LoadStateDouble("startingEquity", startingEquity);
    startingBalance = LoadStateDouble("startingBalance", startingBalance);
    maxEquityReached = LoadStateDouble("maxEquityReached", maxEquityReached);
    maxDrawdownReached = LoadStateDouble("maxDrawdownReached", maxDrawdownReached);
    g_restoredVariableCount += 4;
    LogItem(SP_LOG_RESTORE, "Starting Equity", "$" + DoubleToString(startingEquity, 2));
    LogItem(SP_LOG_RESTORE, "Max Drawdown", DoubleToString(maxDrawdownReached, 2) + "%");
    LogSection_End(SP_LOG_RESTORE, "RISK TRACKING", 4, 0);

    //=================================================================
    // SECTION 9: EXPOSURE
    //=================================================================
    LogSection_Start(SP_LOG_RESTORE, "EXPOSURE");
    totalLongLots = LoadStateDouble("totalLongLots", totalLongLots);
    totalShortLots = LoadStateDouble("totalShortLots", totalShortLots);
    netExposure = LoadStateDouble("netExposure", netExposure);
    isNeutral = LoadStateBool("isNeutral", isNeutral);
    g_restoredVariableCount += 4;
    LogItem(SP_LOG_RESTORE, "Long/Short Lots", DoubleToString(totalLongLots, 2) + "/" + DoubleToString(totalShortLots, 2));
    LogItem(SP_LOG_RESTORE, "Net Exposure", DoubleToString(netExposure, 2) + " lots");
    LogItem(SP_LOG_RESTORE, "Is Neutral", isNeutral ? "YES" : "NO");
    LogSection_End(SP_LOG_RESTORE, "EXPOSURE", 4, 0);

    //=================================================================
    // SECTION 10: ATR CACHE
    //=================================================================
    LogSection_Start(SP_LOG_RESTORE, "ATR CACHE");
    g_atrCache.valuePips = LoadStateDouble("atrCache_valuePips", g_atrCache.valuePips);
    g_atrCache.lastFullUpdate = (datetime)LoadStateInt("atrCache_lastUpdate", (int)g_atrCache.lastFullUpdate);
    g_atrCache.lastBarTime = (datetime)LoadStateInt("atrCache_lastBar", (int)g_atrCache.lastBarTime);
    g_atrCache.isValid = LoadStateBool("atrCache_isValid", g_atrCache.isValid);
    currentATR_Pips = LoadStateDouble("currentATR_Pips", currentATR_Pips);
    g_restoredVariableCount += 5;
    LogItem(SP_LOG_RESTORE, "ATR Value", DoubleToString(currentATR_Pips, 1) + " pips");
    LogItem(SP_LOG_RESTORE, "Cache Valid", g_atrCache.isValid ? "YES" : "NO");
    LogSection_End(SP_LOG_RESTORE, "ATR CACHE", 5, 0);

    //=================================================================
    // SECTION 11: STRADDLE STATE (se abilitato)
    //=================================================================
    if(Straddle_Enabled) {
        LogSection_Start(SP_LOG_RESTORE, "STRADDLE STATE");
        straddle.isActive = LoadStateBool("straddle_isActive", straddle.isActive);
        straddle.currentRound = LoadStateInt("straddle_currentRound", straddle.currentRound);
        straddle.inCoverMode = LoadStateBool("straddle_inCoverMode", straddle.inCoverMode);
        straddle.entryPrice = LoadStateDouble("straddle_entryPrice", straddle.entryPrice);
        straddle.buyStopPrice = LoadStateDouble("straddle_buyStopPrice", straddle.buyStopPrice);
        straddle.sellStopPrice = LoadStateDouble("straddle_sellStopPrice", straddle.sellStopPrice);
        straddle.buyStopTicket = LoadStateUlong("straddle_buyTicket", straddle.buyStopTicket);
        straddle.sellStopTicket = LoadStateUlong("straddle_sellTicket", straddle.sellStopTicket);
        straddle.currentBuyLot = LoadStateDouble("straddle_buyLotSize", straddle.currentBuyLot);
        straddle.currentSellLot = LoadStateDouble("straddle_sellLotSize", straddle.currentSellLot);
        straddle.totalBuyLot = LoadStateDouble("straddle_totalBuyLot", straddle.totalBuyLot);
        straddle.totalSellLot = LoadStateDouble("straddle_totalSellLot", straddle.totalSellLot);
        straddle.totalBuyPositions = LoadStateInt("straddle_buyPositions", straddle.totalBuyPositions);
        straddle.totalSellPositions = LoadStateInt("straddle_sellPositions", straddle.totalSellPositions);
        straddle.lastCloseTime = (datetime)LoadStateInt("straddle_lastCloseTime", (int)straddle.lastCloseTime);
        straddle.lastFillType = (ENUM_POSITION_TYPE)LoadStateInt("straddle_lastFillType", (int)straddle.lastFillType);
        g_restoredVariableCount += 16;
        LogItem(SP_LOG_RESTORE, "Straddle Active", straddle.isActive ? "YES" : "NO");
        LogItem(SP_LOG_RESTORE, "Current Round", IntegerToString(straddle.currentRound));
        LogItem(SP_LOG_RESTORE, "In Cover Mode", straddle.inCoverMode ? "YES" : "NO");
        LogSection_End(SP_LOG_RESTORE, "STRADDLE STATE", 16, 0);
    }

    //=================================================================
    // SECTION 12: MANUAL S/R (se abilitato)
    //=================================================================
    if(Enable_ManualSR) {
        LogSection_Start(SP_LOG_RESTORE, "MANUAL S/R");
        manualSR_Resistance = LoadStateDouble("manualSR_Resistance", manualSR_Resistance);
        manualSR_Support = LoadStateDouble("manualSR_Support", manualSR_Support);
        manualSR_Activation = LoadStateDouble("manualSR_Activation", manualSR_Activation);
        manualSR_Initialized = LoadStateBool("manualSR_Initialized", manualSR_Initialized);
        g_restoredVariableCount += 4;
        LogItem(SP_LOG_RESTORE, "Resistance", DoubleToString(manualSR_Resistance, 5));
        LogItem(SP_LOG_RESTORE, "Support", DoubleToString(manualSR_Support, 5));
        LogItem(SP_LOG_RESTORE, "Activation", DoubleToString(manualSR_Activation, 5));
        LogSection_End(SP_LOG_RESTORE, "MANUAL S/R", 4, 0);
    }

    //=================================================================
    // FINAL RESTORE REPORT
    //=================================================================
    g_stateRestored = true;

    if(AutoSave_FullLogging) {
        LogRestoreReport(lastSave, g_restoredVariableCount, g_restoreErrors, g_mergeConflicts);
    } else {
        // Log minimo anche senza FullLogging
        PrintFormat("%s Complete - %d vars restored, %d errors, %d merge conflicts",
                    SP_LOG_RESTORE, g_restoredVariableCount, g_restoreErrors, g_mergeConflicts);
    }

    return true;
}

//+------------------------------------------------------------------+
//| RECREATE ALL GRAPHICS                                             |
//| Ricrea tutta la grafica dopo recovery                             |
//+------------------------------------------------------------------+
void RecreateAllGraphics() {
    if(!Recovery_RestoreGraphics) {
        LogPersistenceWarning(SP_LOG_RECOVERY, "Recovery_RestoreGraphics DISABLED - Graphics skipped");
        return;
    }

    if(AutoSave_FullLogging) {
        Print("-----------------------------------------------------------------------");
        PrintFormat("%s [GRAPHICS] >>> RECREATING VISUAL ELEMENTS - START", SP_LOG_RECOVERY);
    }

    int elementsCreated = 0;

    // 1. Ricrea linee grid e entry point
    DrawGridVisualization();
    elementsCreated++;
    if(AutoSave_FullLogging) {
        LogItem(SP_LOG_RECOVERY, "Grid Visualization", "Entry line + Grid lines");
    }

    // 2. Ricrea dashboard completa
    RecreateEntireDashboard();
    elementsCreated++;
    if(AutoSave_FullLogging) {
        LogItem(SP_LOG_RECOVERY, "Dashboard", "All panels recreated");
    }

    // 3. Ricrea Manual S/R e Loss Zones se abilitato
    if(Enable_ManualSR && manualSR_Resistance > 0 && manualSR_Support > 0) {
        // Ricrea le linee S/R con i valori ripristinati
        // Usa stringhe dirette (SR_LINE_* definiti in ManualSR.mqh incluso dopo)
        CreateSRLine("SUGAMARA_SR_RESISTANCE", manualSR_Resistance, clrRed, "Resistance");
        CreateSRLine("SUGAMARA_SR_SUPPORT", manualSR_Support, clrLime, "Support");
        if(DefaultEntryMode == ENTRY_LIMIT || DefaultEntryMode == ENTRY_STOP) {
            CreateSRLine("SUGAMARA_SR_ACTIVATION", manualSR_Activation, clrGold, "Activation");
        }
        manualSR_Initialized = true;
        elementsCreated += 3;

        if(AutoSave_FullLogging) {
            LogItem(SP_LOG_RECOVERY, "Manual S/R Lines", "Resistance + Support + Activation");
        }
    }

    // 4. Forza redraw chart
    ChartRedraw(0);

    if(AutoSave_FullLogging) {
        PrintFormat("%s [GRAPHICS] <<< RECREATING VISUAL ELEMENTS - COMPLETE | Elements: %d",
                    SP_LOG_RECOVERY, elementsCreated);
        Print("-----------------------------------------------------------------------");
    } else {
        PrintFormat("%s Graphics recreated successfully", SP_LOG_RECOVERY);
    }
}

//+------------------------------------------------------------------+
//| CLEAR SAVED STATE                                                 |
//| Elimina tutti i dati salvati (per reset completo)                 |
//+------------------------------------------------------------------+
void ClearSavedState() {
    Print("[STATE] Clearing all saved state...");

    // Lista chiavi principali da eliminare
    string keys[] = {
        "entryPoint", "entryPointTime", "currentSpacing", "systemState",
        "systemActive", "systemStartTime", "lastSaveTime",
        // v9.26: Progressive spacing state
        "progressiveSpacingBase", "progressiveSpacingRate", "progressiveLinearIncrement",
        "progressiveStartLevel", "g_progressiveInitialized",
        "gridA_ClosedCount", "gridA_PendingCount", "gridB_ClosedCount", "gridB_PendingCount",
        "gridA_LimitFilled", "gridA_LimitCycles", "gridA_LimitReopens",
        "gridA_StopFilled", "gridA_StopCycles", "gridA_StopReopens",
        "gridB_LimitFilled", "gridB_LimitCycles", "gridB_LimitReopens",
        "gridB_StopFilled", "gridB_StopCycles", "gridB_StopReopens",
        "cop_RealizedProfit", "cop_FloatingProfit", "cop_TotalCommissions", "cop_NetProfit",
        "cop_TargetReached", "cop_TradesToday", "cop_TotalLotsToday", "cop_LastResetDate",
        "sessionRealizedProfit", "sessionPeakProfit", "sessionGrossProfit", "sessionGrossLoss",
        "sessionWins", "sessionLosses", "totalTrades",
        "dailyRealizedProfit", "dailyWins", "dailyLosses", "dailyPeakEquity",
        "startingEquity", "startingBalance", "maxEquityReached", "maxDrawdownReached",
        "totalLongLots", "totalShortLots", "netExposure", "isNeutral",
        "atrCache_valuePips", "atrCache_lastUpdate", "atrCache_lastBar", "atrCache_isValid", "currentATR_Pips",
        "manualSR_Resistance", "manualSR_Support", "manualSR_Activation", "manualSR_Initialized"
    };

    int deletedCount = 0;
    for(int i = 0; i < ArraySize(keys); i++) {
        string key = GetStateKey(keys[i]);
        if(GlobalVariableCheck(key)) {
            GlobalVariableDel(key);
            deletedCount++;
        }
    }

    // Elimina tutti i grid arrays
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        // Status
        GlobalVariableDel(GetStateKey("gAU_Status_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gAL_Status_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBU_Status_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBL_Status_" + IntegerToString(i)));
        // Cycles
        GlobalVariableDel(GetStateKey("gAU_Cycles_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gAL_Cycles_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBU_Cycles_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBL_Cycles_" + IntegerToString(i)));
        // LastClose
        GlobalVariableDel(GetStateKey("gAU_LastClose_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gAL_LastClose_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBU_LastClose_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBL_LastClose_" + IntegerToString(i)));
        // Tickets
        GlobalVariableDel(GetStateKey("gAU_Ticket_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gAL_Ticket_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBU_Ticket_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBL_Ticket_" + IntegerToString(i)));
        // Prices
        GlobalVariableDel(GetStateKey("gAU_Price_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gAL_Price_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBU_Price_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBL_Price_" + IntegerToString(i)));
        // Lots
        GlobalVariableDel(GetStateKey("gAU_Lots_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gAL_Lots_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBU_Lots_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBL_Lots_" + IntegerToString(i)));
        // TP
        GlobalVariableDel(GetStateKey("gAU_TP_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gAL_TP_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBU_TP_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBL_TP_" + IntegerToString(i)));
        deletedCount += 28;
    }

    // Elimina straddle state
    string straddleKeys[] = {
        "straddle_isActive", "straddle_currentRound", "straddle_inCoverMode",
        "straddle_entryPrice", "straddle_buyStopPrice", "straddle_sellStopPrice",
        "straddle_buyTicket", "straddle_sellTicket", "straddle_buyLotSize", "straddle_sellLotSize",
        "straddle_totalBuyLot", "straddle_totalSellLot", "straddle_buyPositions", "straddle_sellPositions",
        "straddle_lastCloseTime", "straddle_lastFillType"
    };
    for(int i = 0; i < ArraySize(straddleKeys); i++) {
        GlobalVariableDel(GetStateKey(straddleKeys[i]));
    }

    // Elimina file backup
    FileDelete(GetEntryPointBackupFilePath(), FILE_COMMON);
    FileDelete(GetStateFilePath(), FILE_COMMON);
    FileDelete(GetLastReopensBackupFilePath(), FILE_COMMON);  // v9.23

    Print("[STATE] Cleared ", deletedCount, " GlobalVariables + backup files");
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS - SAVE (return bool for error tracking)          |
//+------------------------------------------------------------------+
bool SaveStateDouble(string name, double value) {
    datetime result = GlobalVariableSet(GetStateKey(name), value);
    if(result == 0) {
        LogPersistenceError(SP_LOG_AUTOSAVE, "SaveStateDouble", "Failed to save " + name);
        return false;
    }
    g_savedVariableCount++;
    return true;
}

bool SaveStateInt(string name, int value) {
    datetime result = GlobalVariableSet(GetStateKey(name), (double)value);
    if(result == 0) {
        LogPersistenceError(SP_LOG_AUTOSAVE, "SaveStateInt", "Failed to save " + name);
        return false;
    }
    g_savedVariableCount++;
    return true;
}

bool SaveStateUlong(string name, ulong value) {
    datetime result = GlobalVariableSet(GetStateKey(name), (double)value);
    if(result == 0) {
        LogPersistenceError(SP_LOG_AUTOSAVE, "SaveStateUlong", "Failed to save " + name);
        return false;
    }
    g_savedVariableCount++;
    return true;
}

bool SaveStateBool(string name, bool value) {
    datetime result = GlobalVariableSet(GetStateKey(name), value ? 1.0 : 0.0);
    if(result == 0) {
        LogPersistenceError(SP_LOG_AUTOSAVE, "SaveStateBool", "Failed to save " + name);
        return false;
    }
    g_savedVariableCount++;
    return true;
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS - LOAD                                           |
//+------------------------------------------------------------------+
double LoadStateDouble(string name, double defaultValue) {
    string key = GetStateKey(name);
    if(GlobalVariableCheck(key)) {
        return GlobalVariableGet(key);
    }
    return defaultValue;
}

int LoadStateInt(string name, int defaultValue) {
    string key = GetStateKey(name);
    if(GlobalVariableCheck(key)) {
        return (int)GlobalVariableGet(key);
    }
    return defaultValue;
}

ulong LoadStateUlong(string name, ulong defaultValue) {
    string key = GetStateKey(name);
    if(GlobalVariableCheck(key)) {
        return (ulong)GlobalVariableGet(key);
    }
    return defaultValue;
}

bool LoadStateBool(string name, bool defaultValue) {
    string key = GetStateKey(name);
    if(GlobalVariableCheck(key)) {
        return (GlobalVariableGet(key) > 0.5);
    }
    return defaultValue;
}

//+------------------------------------------------------------------+
//| GET STATE PERSISTENCE INFO (for dashboard)                        |
//+------------------------------------------------------------------+
string GetStatePersistenceInfo() {
    datetime lastSave = (datetime)LoadStateInt("lastSaveTime", 0);

    string info = "";
    info += "AutoSave: " + (Enable_AutoSave ? "ON" : "OFF");
    if(Enable_AutoSave && lastSave > 0) {
        int secondsAgo = (int)(TimeCurrent() - lastSave);
        info += " | Last: " + IntegerToString(secondsAgo) + "s ago";
    }

    return info;
}

//+------------------------------------------------------------------+
//| LOG AUTO-SAVE STATUS                                              |
//+------------------------------------------------------------------+
void LogAutoSaveStatus() {
    Print("=======================================================================");
    Print("  AUTO-SAVE STATUS");
    Print("=======================================================================");
    Print("  Enable_AutoSave: ", Enable_AutoSave);
    Print("  Interval: ", AutoSave_Interval_Minutes, " minutes");
    Print("  File Backup: ", AutoSave_UseFileBackup ? "ENABLED" : "DISABLED");
    Print("  Last Save: ", g_lastAutoSaveTime > 0 ? TimeToString(g_lastAutoSaveTime, TIME_DATE|TIME_SECONDS) : "Never");
    Print("  Variables Saved: ", g_savedVariableCount);
    Print("  State Restored: ", g_stateRestored ? "YES" : "NO");
    if(g_stateRestored) {
        Print("  Variables Restored: ", g_restoredVariableCount);
    }
    Print("=======================================================================");
}
