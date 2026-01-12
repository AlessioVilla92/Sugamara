# 📋 GUIDA IMPLEMENTAZIONE AUTO-SAVE COMPLETO
## Per Sugamara.mq5 (RIBELLE v9.11 → v9.12)

**Data:** Gennaio 2026  
**Versione Target:** v9.12 - Auto-Save Integration  
**Destinatario:** Claude Code  

---

# 🎯 OBIETTIVO

Implementare un sistema **AUTO-SAVE** completo in Sugamara.mq5 che:
1. Salvi TUTTE le variabili, array e stato grafico ogni N minuti
2. Ripristini TUTTO in caso di crash/restart/cambio timeframe
3. Si integri perfettamente con il RecoveryManager esistente
4. Garantisca che il Reopen Cycling continui a funzionare dopo recovery

---

# 📁 PARTE 1: NUOVA SEZIONE INPUT PARAMETERS

## 1.1 Posizione nel File

Aprire **`InputParameters.mqh`** e inserire la nuova sezione **DOPO** la sezione "DEBUG MODE" e **PRIMA** di "FOREX PAIR SELECTION".

## 1.2 Codice da Inserire

```cpp
//+------------------------------------------------------------------+
//| 💾 AUTO-SAVE & RECOVERY SYSTEM                                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔══════════════════════════════════════════════════════════════╗"
input group "║  💾 AUTO-SAVE & RECOVERY SYSTEM                              ║"
input group "╚══════════════════════════════════════════════════════════════╝"

input group "    💾 AUTO-SAVE SETTINGS"
input bool      Enable_AutoSave = true;                   // ✅ Enable Auto-Save (Backup ogni N minuti)
input int       AutoSave_Interval_Minutes = 5;            // ⏱️ Intervallo Backup (minuti) [Default: 5]
input bool      AutoSave_FullLogging = false;             // 📝 Full Logging Auto-Save (true=dettagliato, false=minimale)

input group "    🔄 RECOVERY SETTINGS"
input bool      Enable_AutoRecovery = true;               // ✅ Enable Auto-Recovery (da ultimo salvataggio)
input bool      Recovery_RestoreGraphics = true;          // 🎨 Ripristina Grafica (linee grid, entry point)
input bool      Recovery_RestoreCycling = true;           // 🔄 Ripristina Reopen Cycling (Status, Cycles, LastClose)
input bool      Recovery_RestoreCOP = true;               // 💰 Ripristina COP (Profitto realizzato, stats)
input bool      Recovery_RestoreSession = true;           // 📊 Ripristina Session Stats (Profit, Wins, Losses)
```

---

# 📁 PARTE 2: NUOVO FILE StatePersistence.mqh

## 2.1 Creare Nuovo File

Creare il file **`Core/StatePersistence.mqh`** con il seguente contenuto:

```cpp
//+------------------------------------------------------------------+
//|                                             StatePersistence.mqh |
//|                        SUGAMARA v9.12 - State Persistence        |
//|                                                                  |
//|  Modulo per salvare/ripristinare stato completo EA               |
//|  - Auto-save periodico ogni N minuti                             |
//|  - Event-save su eventi critici (chiusura ordini)                |
//|  - Restore completo: arrays, cycling, COP, grafica               |
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
int g_lastDeinitReason = 0;                 // Motivo ultimo OnDeinit
datetime g_lastAutoSaveTime = 0;            // Timestamp ultimo auto-save
int g_savedVariableCount = 0;               // Contatore variabili salvate
bool g_stateRestored = false;               // Flag: stato ripristinato

//+------------------------------------------------------------------+
//| GET GLOBAL VARIABLE KEY                                           |
//| Genera chiave univoca per simbolo                                 |
//+------------------------------------------------------------------+
string GetStateKey(string varName) {
    return GV_STATE_PREFIX + _Symbol + "_" + varName;
}

//+------------------------------------------------------------------+
//| GET CYCLING STATE FILE PATH                                       |
//+------------------------------------------------------------------+
string GetCyclingStateFilePath() {
    return "sugamara_cycling_" + _Symbol + ".txt";
}

//+------------------------------------------------------------------+
//| GET ENTRY POINT BACKUP FILE PATH                                  |
//+------------------------------------------------------------------+
string GetEntryPointBackupFilePath() {
    return "sugamara_entry_" + _Symbol + ".txt";
}

//+------------------------------------------------------------------+
//| SHOULD AUTO-SAVE NOW?                                             |
//| Controlla se è tempo di eseguire auto-save                        |
//+------------------------------------------------------------------+
bool ShouldAutoSaveNow() {
    if(!Enable_AutoSave) return false;
    if(g_lastAutoSaveTime == 0) return true;  // Prima volta
    
    int intervalSeconds = AutoSave_Interval_Minutes * 60;
    return (TimeCurrent() - g_lastAutoSaveTime >= intervalSeconds);
}

//+------------------------------------------------------------------+
//| EXECUTE AUTO-SAVE                                                 |
//| Chiamare da OnTick ogni tick                                      |
//+------------------------------------------------------------------+
void ExecuteAutoSave() {
    if(!ShouldAutoSaveNow()) return;
    
    if(AutoSave_FullLogging) {
        Print("[AUTO-SAVE] Executing periodic save...");
    }
    
    SaveCompleteState();
    g_lastAutoSaveTime = TimeCurrent();
    
    if(AutoSave_FullLogging) {
        Print("[AUTO-SAVE] Complete - ", g_savedVariableCount, " variables saved");
    }
}

//+------------------------------------------------------------------+
//| SAVE COMPLETE STATE                                               |
//| Salva TUTTO lo stato dell'EA                                      |
//+------------------------------------------------------------------+
void SaveCompleteState() {
    g_savedVariableCount = 0;
    
    //=================================================================
    // 1. CORE SYSTEM STATE
    //=================================================================
    SaveStateDouble("entryPoint", entryPoint);
    SaveStateInt("entryPointTime", (int)entryPointTime);
    SaveStateDouble("currentSpacing", currentSpacing_Pips);
    SaveStateInt("systemState", (int)systemState);
    SaveStateBool("systemActive", systemActive);
    SaveStateInt("systemStartTime", (int)systemStartTime);
    
    // v9.12: Backup entry point anche su file
    SaveEntryPointToFile();
    
    //=================================================================
    // 2. GRID ARRAYS - STATUS (4 zone x 20 livelli = 80 variabili)
    //=================================================================
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        SaveStateInt("gAU_Status_" + IntegerToString(i), (int)gridA_Upper_Status[i]);
        SaveStateInt("gAL_Status_" + IntegerToString(i), (int)gridA_Lower_Status[i]);
        SaveStateInt("gBU_Status_" + IntegerToString(i), (int)gridB_Upper_Status[i]);
        SaveStateInt("gBL_Status_" + IntegerToString(i), (int)gridB_Lower_Status[i]);
    }
    
    //=================================================================
    // 3. GRID ARRAYS - CYCLES (4 zone x 20 livelli = 80 variabili)
    //=================================================================
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        SaveStateInt("gAU_Cycles_" + IntegerToString(i), gridA_Upper_Cycles[i]);
        SaveStateInt("gAL_Cycles_" + IntegerToString(i), gridA_Lower_Cycles[i]);
        SaveStateInt("gBU_Cycles_" + IntegerToString(i), gridB_Upper_Cycles[i]);
        SaveStateInt("gBL_Cycles_" + IntegerToString(i), gridB_Lower_Cycles[i]);
    }
    
    //=================================================================
    // 4. GRID ARRAYS - LAST CLOSE (4 zone x 20 livelli = 80 variabili)
    //=================================================================
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        SaveStateInt("gAU_LastClose_" + IntegerToString(i), (int)gridA_Upper_LastClose[i]);
        SaveStateInt("gAL_LastClose_" + IntegerToString(i), (int)gridA_Lower_LastClose[i]);
        SaveStateInt("gBU_LastClose_" + IntegerToString(i), (int)gridB_Upper_LastClose[i]);
        SaveStateInt("gBL_LastClose_" + IntegerToString(i), (int)gridB_Lower_LastClose[i]);
    }
    
    //=================================================================
    // 5. GRID ARRAYS - TICKETS (4 zone x 20 livelli = 80 variabili)
    //=================================================================
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        SaveStateUlong("gAU_Ticket_" + IntegerToString(i), gridA_Upper_Tickets[i]);
        SaveStateUlong("gAL_Ticket_" + IntegerToString(i), gridA_Lower_Tickets[i]);
        SaveStateUlong("gBU_Ticket_" + IntegerToString(i), gridB_Upper_Tickets[i]);
        SaveStateUlong("gBL_Ticket_" + IntegerToString(i), gridB_Lower_Tickets[i]);
    }
    
    //=================================================================
    // 6. GRID ARRAYS - ENTRY PRICES (4 zone x 20 livelli = 80 variabili)
    //=================================================================
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        SaveStateDouble("gAU_Price_" + IntegerToString(i), gridA_Upper_EntryPrices[i]);
        SaveStateDouble("gAL_Price_" + IntegerToString(i), gridA_Lower_EntryPrices[i]);
        SaveStateDouble("gBU_Price_" + IntegerToString(i), gridB_Upper_EntryPrices[i]);
        SaveStateDouble("gBL_Price_" + IntegerToString(i), gridB_Lower_EntryPrices[i]);
    }
    
    //=================================================================
    // 7. GRID ARRAYS - LOTS (4 zone x 20 livelli = 80 variabili)
    //=================================================================
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        SaveStateDouble("gAU_Lots_" + IntegerToString(i), gridA_Upper_Lots[i]);
        SaveStateDouble("gAL_Lots_" + IntegerToString(i), gridA_Lower_Lots[i]);
        SaveStateDouble("gBU_Lots_" + IntegerToString(i), gridB_Upper_Lots[i]);
        SaveStateDouble("gBL_Lots_" + IntegerToString(i), gridB_Lower_Lots[i]);
    }
    
    //=================================================================
    // 8. GRID ARRAYS - TP (4 zone x 20 livelli = 80 variabili)
    //=================================================================
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        SaveStateDouble("gAU_TP_" + IntegerToString(i), gridA_Upper_TP[i]);
        SaveStateDouble("gAL_TP_" + IntegerToString(i), gridA_Lower_TP[i]);
        SaveStateDouble("gBU_TP_" + IntegerToString(i), gridB_Upper_TP[i]);
        SaveStateDouble("gBL_TP_" + IntegerToString(i), gridB_Lower_TP[i]);
    }
    
    //=================================================================
    // 9. GRID COUNTERS (12 variabili)
    //=================================================================
    SaveStateInt("gridA_ClosedCount", g_gridA_ClosedCount);
    SaveStateInt("gridA_PendingCount", g_gridA_PendingCount);
    SaveStateInt("gridB_ClosedCount", g_gridB_ClosedCount);
    SaveStateInt("gridB_PendingCount", g_gridB_PendingCount);
    SaveStateInt("gridA_LimitFilled", g_gridA_LimitFilled);
    SaveStateInt("gridA_LimitCycles", g_gridA_LimitCycles);
    SaveStateInt("gridA_LimitReopens", g_gridA_LimitReopens);
    SaveStateInt("gridA_StopFilled", g_gridA_StopFilled);
    SaveStateInt("gridA_StopCycles", g_gridA_StopCycles);
    SaveStateInt("gridA_StopReopens", g_gridA_StopReopens);
    SaveStateInt("gridB_LimitFilled", g_gridB_LimitFilled);
    SaveStateInt("gridB_LimitCycles", g_gridB_LimitCycles);
    SaveStateInt("gridB_LimitReopens", g_gridB_LimitReopens);
    SaveStateInt("gridB_StopFilled", g_gridB_StopFilled);
    SaveStateInt("gridB_StopCycles", g_gridB_StopCycles);
    SaveStateInt("gridB_StopReopens", g_gridB_StopReopens);
    
    //=================================================================
    // 10. COP STATE (8 variabili)
    //=================================================================
    SaveStateDouble("cop_RealizedProfit", cop_RealizedProfit);
    SaveStateDouble("cop_FloatingProfit", cop_FloatingProfit);
    SaveStateDouble("cop_TotalCommissions", cop_TotalCommissions);
    SaveStateDouble("cop_NetProfit", cop_NetProfit);
    SaveStateBool("cop_TargetReached", cop_TargetReached);
    SaveStateInt("cop_TradesToday", cop_TradesToday);
    SaveStateDouble("cop_TotalLotsToday", cop_TotalLotsToday);
    SaveStateInt("cop_LastResetDate", (int)cop_LastResetDate);
    
    //=================================================================
    // 11. SESSION STATISTICS (12 variabili)
    //=================================================================
    SaveStateDouble("sessionProfit", sessionProfit);
    SaveStateDouble("sessionPeakProfit", sessionPeakProfit);
    SaveStateDouble("sessionGrossProfit", sessionGrossProfit);
    SaveStateDouble("sessionGrossLoss", sessionGrossLoss);
    SaveStateInt("sessionWins", sessionWins);
    SaveStateInt("sessionLosses", sessionLosses);
    SaveStateDouble("maxDrawdownReached", maxDrawdownReached);
    SaveStateDouble("startingEquity", startingEquity);
    SaveStateDouble("startingBalance", startingBalance);
    
    //=================================================================
    // 12. EXPOSURE (4 variabili)
    //=================================================================
    SaveStateDouble("totalLongLots", totalLongLots);
    SaveStateDouble("totalShortLots", totalShortLots);
    SaveStateDouble("netExposure", netExposure);
    SaveStateBool("isNeutral", isNeutral);
    
    //=================================================================
    // 13. RANGE BOUNDARIES (3 variabili)
    //=================================================================
    SaveStateDouble("rangeUpperBound", rangeUpperBound);
    SaveStateDouble("rangeLowerBound", rangeLowerBound);
    SaveStateDouble("totalRangePips", totalRangePips);
    
    //=================================================================
    // 14. ATR CACHE (5 variabili)
    //=================================================================
    SaveStateDouble("atrCache_valuePips", g_atrCache.valuePips);
    SaveStateInt("atrCache_lastUpdate", (int)g_atrCache.lastFullUpdate);
    SaveStateInt("atrCache_lastBar", (int)g_atrCache.lastBarTime);
    SaveStateBool("atrCache_isValid", g_atrCache.isValid);
    SaveStateDouble("currentATR_Pips", currentATR_Pips);
    
    //=================================================================
    // 15. BREAKOUT LEVELS (6 variabili)
    //=================================================================
    SaveStateDouble("upperBreakoutLevel", upperBreakoutLevel);
    SaveStateDouble("lowerBreakoutLevel", lowerBreakoutLevel);
    SaveStateDouble("upperReentryLevel", upperReentryLevel);
    SaveStateDouble("lowerReentryLevel", lowerReentryLevel);
    SaveStateInt("breakoutDetectionTime", (int)breakoutDetectionTime);
    SaveStateInt("lastBreakoutDirection", (int)lastBreakoutDirection);
    
    //=================================================================
    // 16. SHIELD STATE (se abilitato) - 15+ variabili
    //=================================================================
    if(Enable_ShieldIntelligente) {
        SaveStateBool("shield_isActive", shieldData.isActive);
        SaveStateInt("shield_type", (int)shieldData.type);
        SaveStateInt("shield_phase", (int)shieldData.phase);
        SaveStateUlong("shield_ticket", shieldData.ticket);
        SaveStateDouble("shield_lotSize", shieldData.lot_size);
        SaveStateDouble("shield_entryPrice", shieldData.entry_price);
        SaveStateDouble("shield_currentPL", shieldData.current_pl);
        SaveStateInt("shield_startTime", (int)shieldData.start_time);
        SaveStateDouble("shield_maxProfit", shieldData.max_profit);
        SaveStateDouble("shield_triggerPrice", shieldData.trigger_price);
        SaveStateInt("shield_triggerCount", shieldData.trigger_count);
        SaveStateBool("shield_reentryBlocked", shieldData.reentry_blocked);
        SaveStateDouble("shield_lastExitPrice", shieldData.last_exit_price);
    }
    
    //=================================================================
    // 17. STRADDLE STATE (se abilitato) - 15+ variabili
    //=================================================================
    if(Straddle_Enabled) {
        SaveStateBool("straddle_isActive", straddleState.isActive);
        SaveStateInt("straddle_roundNumber", straddleState.roundNumber);
        SaveStateBool("straddle_coverMode", straddleState.coverMode);
        SaveStateDouble("straddle_entryPrice", straddleState.entryPrice);
        SaveStateDouble("straddle_buyStopPrice", straddleState.buyStopPrice);
        SaveStateDouble("straddle_sellStopPrice", straddleState.sellStopPrice);
        SaveStateUlong("straddle_buyTicket", straddleState.buyStopTicket);
        SaveStateUlong("straddle_sellTicket", straddleState.sellStopTicket);
        SaveStateDouble("straddle_buyLotSize", straddleState.buyLotSize);
        SaveStateDouble("straddle_sellLotSize", straddleState.sellLotSize);
        SaveStateDouble("straddle_totalBuyLot", straddleState.totalBuyLots);
        SaveStateDouble("straddle_totalSellLot", straddleState.totalSellLots);
        SaveStateInt("straddle_buyPositions", straddleState.buyPositions);
        SaveStateInt("straddle_sellPositions", straddleState.sellPositions);
        SaveStateInt("straddle_lastCloseTime", (int)straddleState.lastCloseTime);
        SaveStateInt("straddle_lastFillTime", (int)straddleState.lastFillTime);
    }
    
    //=================================================================
    // 18. TIMESTAMP ULTIMO SAVE
    //=================================================================
    SaveStateInt("lastSaveTime", (int)TimeCurrent());
    
    if(AutoSave_FullLogging) {
        Print("[AUTO-SAVE] Saved ", g_savedVariableCount, " variables to GlobalVariables");
    }
}

//+------------------------------------------------------------------+
//| SAVE ENTRY POINT TO FILE BACKUP                                   |
//| Doppio backup: GlobalVariable + File per garanzia 100%            |
//+------------------------------------------------------------------+
void SaveEntryPointToFile() {
    if(entryPoint <= 0) return;
    
    string filePath = GetEntryPointBackupFilePath();
    int handle = FileOpen(filePath, FILE_WRITE|FILE_TXT|FILE_COMMON);
    if(handle != INVALID_HANDLE) {
        string data = DoubleToString(entryPoint, 8) + ";" + 
                      DoubleToString(currentSpacing_Pips, 2) + ";" +
                      IntegerToString(entryPointTime);
        FileWriteString(handle, data);
        FileClose(handle);
    }
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
//| RESTORE COMPLETE STATE                                            |
//| Ripristina TUTTO lo stato dell'EA                                 |
//+------------------------------------------------------------------+
bool RestoreCompleteState() {
    if(!Enable_AutoRecovery) return false;
    
    // Verifica se esiste stato salvato
    if(!GlobalVariableCheck(GetStateKey("lastSaveTime"))) {
        Print("[RESTORE] No saved state found");
        return false;
    }
    
    datetime lastSave = (datetime)LoadStateInt("lastSaveTime", 0);
    datetime now = TimeCurrent();
    
    // Ignora stato troppo vecchio (> 7 giorni)
    if(now - lastSave > 7 * 24 * 60 * 60) {
        Print("[RESTORE] Saved state too old (", (now - lastSave) / 86400, " days) - ignoring");
        return false;
    }
    
    Print("[RESTORE] Restoring state from ", TimeToString(lastSave, TIME_DATE|TIME_SECONDS));
    int restoredCount = 0;
    
    //=================================================================
    // 1. CORE SYSTEM STATE
    //=================================================================
    entryPoint = LoadStateDouble("entryPoint", 0);
    entryPointTime = (datetime)LoadStateInt("entryPointTime", 0);
    currentSpacing_Pips = LoadStateDouble("currentSpacing", 0);
    
    // Fallback: prova a caricare da file se GlobalVar fallisce
    if(entryPoint <= 0) {
        double fileEntry = 0, fileSpacing = 0;
        datetime fileTime = 0;
        if(LoadEntryPointFromFile(fileEntry, fileSpacing, fileTime)) {
            entryPoint = fileEntry;
            currentSpacing_Pips = fileSpacing;
            entryPointTime = fileTime;
            Print("[RESTORE] Entry loaded from file backup: ", DoubleToString(entryPoint, 5));
        }
    }
    
    systemState = (ENUM_SYSTEM_STATE)LoadStateInt("systemState", (int)STATE_IDLE);
    systemActive = LoadStateBool("systemActive", false);
    systemStartTime = (datetime)LoadStateInt("systemStartTime", 0);
    restoredCount += 6;
    
    //=================================================================
    // 2-8. GRID ARRAYS (se Recovery_RestoreCycling abilitato)
    //=================================================================
    if(Recovery_RestoreCycling) {
        for(int i = 0; i < MAX_GRID_LEVELS; i++) {
            // Status
            gridA_Upper_Status[i] = (ENUM_ORDER_STATUS)LoadStateInt("gAU_Status_" + IntegerToString(i), (int)ORDER_NONE);
            gridA_Lower_Status[i] = (ENUM_ORDER_STATUS)LoadStateInt("gAL_Status_" + IntegerToString(i), (int)ORDER_NONE);
            gridB_Upper_Status[i] = (ENUM_ORDER_STATUS)LoadStateInt("gBU_Status_" + IntegerToString(i), (int)ORDER_NONE);
            gridB_Lower_Status[i] = (ENUM_ORDER_STATUS)LoadStateInt("gBL_Status_" + IntegerToString(i), (int)ORDER_NONE);
            
            // Cycles
            gridA_Upper_Cycles[i] = LoadStateInt("gAU_Cycles_" + IntegerToString(i), 0);
            gridA_Lower_Cycles[i] = LoadStateInt("gAL_Cycles_" + IntegerToString(i), 0);
            gridB_Upper_Cycles[i] = LoadStateInt("gBU_Cycles_" + IntegerToString(i), 0);
            gridB_Lower_Cycles[i] = LoadStateInt("gBL_Cycles_" + IntegerToString(i), 0);
            
            // LastClose
            gridA_Upper_LastClose[i] = (datetime)LoadStateInt("gAU_LastClose_" + IntegerToString(i), 0);
            gridA_Lower_LastClose[i] = (datetime)LoadStateInt("gAL_LastClose_" + IntegerToString(i), 0);
            gridB_Upper_LastClose[i] = (datetime)LoadStateInt("gBU_LastClose_" + IntegerToString(i), 0);
            gridB_Lower_LastClose[i] = (datetime)LoadStateInt("gBL_LastClose_" + IntegerToString(i), 0);
            
            // Tickets
            gridA_Upper_Tickets[i] = LoadStateUlong("gAU_Ticket_" + IntegerToString(i), 0);
            gridA_Lower_Tickets[i] = LoadStateUlong("gAL_Ticket_" + IntegerToString(i), 0);
            gridB_Upper_Tickets[i] = LoadStateUlong("gBU_Ticket_" + IntegerToString(i), 0);
            gridB_Lower_Tickets[i] = LoadStateUlong("gBL_Ticket_" + IntegerToString(i), 0);
            
            // Entry Prices
            gridA_Upper_EntryPrices[i] = LoadStateDouble("gAU_Price_" + IntegerToString(i), 0);
            gridA_Lower_EntryPrices[i] = LoadStateDouble("gAL_Price_" + IntegerToString(i), 0);
            gridB_Upper_EntryPrices[i] = LoadStateDouble("gBU_Price_" + IntegerToString(i), 0);
            gridB_Lower_EntryPrices[i] = LoadStateDouble("gBL_Price_" + IntegerToString(i), 0);
            
            // Lots
            gridA_Upper_Lots[i] = LoadStateDouble("gAU_Lots_" + IntegerToString(i), 0);
            gridA_Lower_Lots[i] = LoadStateDouble("gAL_Lots_" + IntegerToString(i), 0);
            gridB_Upper_Lots[i] = LoadStateDouble("gBU_Lots_" + IntegerToString(i), 0);
            gridB_Lower_Lots[i] = LoadStateDouble("gBL_Lots_" + IntegerToString(i), 0);
            
            // TP
            gridA_Upper_TP[i] = LoadStateDouble("gAU_TP_" + IntegerToString(i), 0);
            gridA_Lower_TP[i] = LoadStateDouble("gAL_TP_" + IntegerToString(i), 0);
            gridB_Upper_TP[i] = LoadStateDouble("gBU_TP_" + IntegerToString(i), 0);
            gridB_Lower_TP[i] = LoadStateDouble("gBL_TP_" + IntegerToString(i), 0);
            
            restoredCount += 28;  // 7 array x 4 zone
        }
        Print("[RESTORE] Grid arrays restored (Status, Cycles, LastClose, Tickets, Prices, Lots, TP)");
    }
    
    //=================================================================
    // 9. GRID COUNTERS
    //=================================================================
    g_gridA_ClosedCount = LoadStateInt("gridA_ClosedCount", 0);
    g_gridA_PendingCount = LoadStateInt("gridA_PendingCount", 0);
    g_gridB_ClosedCount = LoadStateInt("gridB_ClosedCount", 0);
    g_gridB_PendingCount = LoadStateInt("gridB_PendingCount", 0);
    g_gridA_LimitFilled = LoadStateInt("gridA_LimitFilled", 0);
    g_gridA_LimitCycles = LoadStateInt("gridA_LimitCycles", 0);
    g_gridA_LimitReopens = LoadStateInt("gridA_LimitReopens", 0);
    g_gridA_StopFilled = LoadStateInt("gridA_StopFilled", 0);
    g_gridA_StopCycles = LoadStateInt("gridA_StopCycles", 0);
    g_gridA_StopReopens = LoadStateInt("gridA_StopReopens", 0);
    g_gridB_LimitFilled = LoadStateInt("gridB_LimitFilled", 0);
    g_gridB_LimitCycles = LoadStateInt("gridB_LimitCycles", 0);
    g_gridB_LimitReopens = LoadStateInt("gridB_LimitReopens", 0);
    g_gridB_StopFilled = LoadStateInt("gridB_StopFilled", 0);
    g_gridB_StopCycles = LoadStateInt("gridB_StopCycles", 0);
    g_gridB_StopReopens = LoadStateInt("gridB_StopReopens", 0);
    restoredCount += 16;
    
    //=================================================================
    // 10. COP STATE (se Recovery_RestoreCOP abilitato)
    //=================================================================
    if(Recovery_RestoreCOP) {
        cop_RealizedProfit = LoadStateDouble("cop_RealizedProfit", 0);
        cop_FloatingProfit = LoadStateDouble("cop_FloatingProfit", 0);
        cop_TotalCommissions = LoadStateDouble("cop_TotalCommissions", 0);
        cop_NetProfit = LoadStateDouble("cop_NetProfit", 0);
        cop_TargetReached = LoadStateBool("cop_TargetReached", false);
        cop_TradesToday = LoadStateInt("cop_TradesToday", 0);
        cop_TotalLotsToday = LoadStateDouble("cop_TotalLotsToday", 0);
        cop_LastResetDate = (datetime)LoadStateInt("cop_LastResetDate", 0);
        restoredCount += 8;
        Print("[RESTORE] COP state restored (Profit, Commissions, Trades)");
    }
    
    //=================================================================
    // 11. SESSION STATISTICS (se Recovery_RestoreSession abilitato)
    //=================================================================
    if(Recovery_RestoreSession) {
        sessionProfit = LoadStateDouble("sessionProfit", 0);
        sessionPeakProfit = LoadStateDouble("sessionPeakProfit", 0);
        sessionGrossProfit = LoadStateDouble("sessionGrossProfit", 0);
        sessionGrossLoss = LoadStateDouble("sessionGrossLoss", 0);
        sessionWins = LoadStateInt("sessionWins", 0);
        sessionLosses = LoadStateInt("sessionLosses", 0);
        maxDrawdownReached = LoadStateDouble("maxDrawdownReached", 0);
        startingEquity = LoadStateDouble("startingEquity", 0);
        startingBalance = LoadStateDouble("startingBalance", 0);
        restoredCount += 9;
        Print("[RESTORE] Session statistics restored");
    }
    
    //=================================================================
    // 12. EXPOSURE
    //=================================================================
    totalLongLots = LoadStateDouble("totalLongLots", 0);
    totalShortLots = LoadStateDouble("totalShortLots", 0);
    netExposure = LoadStateDouble("netExposure", 0);
    isNeutral = LoadStateBool("isNeutral", true);
    restoredCount += 4;
    
    //=================================================================
    // 13. RANGE BOUNDARIES
    //=================================================================
    rangeUpperBound = LoadStateDouble("rangeUpperBound", 0);
    rangeLowerBound = LoadStateDouble("rangeLowerBound", 0);
    totalRangePips = LoadStateDouble("totalRangePips", 0);
    restoredCount += 3;
    
    //=================================================================
    // 14. ATR CACHE
    //=================================================================
    g_atrCache.valuePips = LoadStateDouble("atrCache_valuePips", 0);
    g_atrCache.lastFullUpdate = (datetime)LoadStateInt("atrCache_lastUpdate", 0);
    g_atrCache.lastBarTime = (datetime)LoadStateInt("atrCache_lastBar", 0);
    g_atrCache.isValid = LoadStateBool("atrCache_isValid", false);
    currentATR_Pips = LoadStateDouble("currentATR_Pips", 0);
    restoredCount += 5;
    
    //=================================================================
    // 15. BREAKOUT LEVELS
    //=================================================================
    upperBreakoutLevel = LoadStateDouble("upperBreakoutLevel", 0);
    lowerBreakoutLevel = LoadStateDouble("lowerBreakoutLevel", 0);
    upperReentryLevel = LoadStateDouble("upperReentryLevel", 0);
    lowerReentryLevel = LoadStateDouble("lowerReentryLevel", 0);
    breakoutDetectionTime = (datetime)LoadStateInt("breakoutDetectionTime", 0);
    lastBreakoutDirection = (ENUM_BREAKOUT_DIRECTION)LoadStateInt("lastBreakoutDirection", 0);
    restoredCount += 6;
    
    //=================================================================
    // 16. SHIELD STATE (se abilitato)
    //=================================================================
    if(Enable_ShieldIntelligente) {
        shieldData.isActive = LoadStateBool("shield_isActive", false);
        shieldData.type = (ENUM_SHIELD_TYPE)LoadStateInt("shield_type", 0);
        shieldData.phase = (ENUM_SHIELD_PHASE)LoadStateInt("shield_phase", 0);
        shieldData.ticket = LoadStateUlong("shield_ticket", 0);
        shieldData.lot_size = LoadStateDouble("shield_lotSize", 0);
        shieldData.entry_price = LoadStateDouble("shield_entryPrice", 0);
        shieldData.current_pl = LoadStateDouble("shield_currentPL", 0);
        shieldData.start_time = (datetime)LoadStateInt("shield_startTime", 0);
        shieldData.max_profit = LoadStateDouble("shield_maxProfit", 0);
        shieldData.trigger_price = LoadStateDouble("shield_triggerPrice", 0);
        shieldData.trigger_count = LoadStateInt("shield_triggerCount", 0);
        shieldData.reentry_blocked = LoadStateBool("shield_reentryBlocked", false);
        shieldData.last_exit_price = LoadStateDouble("shield_lastExitPrice", 0);
        restoredCount += 13;
        Print("[RESTORE] Shield state restored");
    }
    
    //=================================================================
    // 17. STRADDLE STATE (se abilitato)
    //=================================================================
    if(Straddle_Enabled) {
        straddleState.isActive = LoadStateBool("straddle_isActive", false);
        straddleState.roundNumber = LoadStateInt("straddle_roundNumber", 0);
        straddleState.coverMode = LoadStateBool("straddle_coverMode", false);
        straddleState.entryPrice = LoadStateDouble("straddle_entryPrice", 0);
        straddleState.buyStopPrice = LoadStateDouble("straddle_buyStopPrice", 0);
        straddleState.sellStopPrice = LoadStateDouble("straddle_sellStopPrice", 0);
        straddleState.buyStopTicket = LoadStateUlong("straddle_buyTicket", 0);
        straddleState.sellStopTicket = LoadStateUlong("straddle_sellTicket", 0);
        straddleState.buyLotSize = LoadStateDouble("straddle_buyLotSize", 0);
        straddleState.sellLotSize = LoadStateDouble("straddle_sellLotSize", 0);
        straddleState.totalBuyLots = LoadStateDouble("straddle_totalBuyLot", 0);
        straddleState.totalSellLots = LoadStateDouble("straddle_totalSellLot", 0);
        straddleState.buyPositions = LoadStateInt("straddle_buyPositions", 0);
        straddleState.sellPositions = LoadStateInt("straddle_sellPositions", 0);
        straddleState.lastCloseTime = (datetime)LoadStateInt("straddle_lastCloseTime", 0);
        straddleState.lastFillTime = (datetime)LoadStateInt("straddle_lastFillTime", 0);
        restoredCount += 16;
        Print("[RESTORE] Straddle state restored");
    }
    
    g_stateRestored = true;
    Print("[RESTORE] Complete - ", restoredCount, " variables restored");
    
    return true;
}

//+------------------------------------------------------------------+
//| RECREATE GRID GRAPHICS                                            |
//| Ricrea tutte le linee grafiche delle grid                         |
//+------------------------------------------------------------------+
void RecreateGridGraphics() {
    if(!Recovery_RestoreGraphics) return;
    if(entryPoint <= 0) return;
    
    Print("[GRAPHICS] Recreating grid visual elements...");
    
    // 1. Ricalcola range boundaries
    CalculateRangeBoundaries();
    
    // 2. Ricrea Entry Point Line
    if(ShowEntryLine) {
        StateDrawEntryPoint();
    }
    
    // 3. Ricrea Grid Lines per tutti i livelli attivi
    if(ShowGridLines) {
        for(int i = 0; i < GridLevelsPerSide; i++) {
            double price;
            
            // Grid A Upper (BUY STOP)
            if(gridA_Upper_Status[i] != ORDER_NONE || gridA_Upper_EntryPrices[i] > 0) {
                price = (gridA_Upper_EntryPrices[i] > 0) ? 
                        gridA_Upper_EntryPrices[i] : 
                        entryPoint + (i + 1) * currentSpacing_Pips * 10 * _Point;
                StateDrawGridLine("GridA_Upper_" + IntegerToString(i), price, Color_BuyStop);
            }
            
            // Grid A Lower (BUY LIMIT)
            if(gridA_Lower_Status[i] != ORDER_NONE || gridA_Lower_EntryPrices[i] > 0) {
                price = (gridA_Lower_EntryPrices[i] > 0) ? 
                        gridA_Lower_EntryPrices[i] : 
                        entryPoint - (i + 1) * currentSpacing_Pips * 10 * _Point;
                StateDrawGridLine("GridA_Lower_" + IntegerToString(i), price, Color_BuyLimit);
            }
            
            // Grid B Upper (SELL LIMIT)
            if(gridB_Upper_Status[i] != ORDER_NONE || gridB_Upper_EntryPrices[i] > 0) {
                price = (gridB_Upper_EntryPrices[i] > 0) ? 
                        gridB_Upper_EntryPrices[i] : 
                        entryPoint + (i + 1) * currentSpacing_Pips * 10 * _Point;
                StateDrawGridLine("GridB_Upper_" + IntegerToString(i), price, Color_SellLimit);
            }
            
            // Grid B Lower (SELL STOP)
            if(gridB_Lower_Status[i] != ORDER_NONE || gridB_Lower_EntryPrices[i] > 0) {
                price = (gridB_Lower_EntryPrices[i] > 0) ? 
                        gridB_Lower_EntryPrices[i] : 
                        entryPoint - (i + 1) * currentSpacing_Pips * 10 * _Point;
                StateDrawGridLine("GridB_Lower_" + IntegerToString(i), price, Color_SellStop);
            }
        }
    }
    
    // 4. Force chart redraw
    ChartRedraw();
    
    Print("[GRAPHICS] Grid visual elements recreated (", GridLevelsPerSide, " levels per side)");
}

//+------------------------------------------------------------------+
//| STATE DRAW ENTRY POINT LINE (Helper)                              |
//+------------------------------------------------------------------+
void StateDrawEntryPoint() {
    if(entryPoint <= 0) return;
    
    string objName = "SUGAMARA_EntryPoint";
    
    // Delete if exists
    if(ObjectFind(0, objName) >= 0) {
        ObjectDelete(0, objName);
    }
    
    // Create horizontal line
    if(ObjectCreate(0, objName, OBJ_HLINE, 0, 0, entryPoint)) {
        ObjectSetInteger(0, objName, OBJPROP_COLOR, Color_EntryLine);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, EntryLine_Width);
        ObjectSetInteger(0, objName, OBJPROP_BACK, true);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
        ObjectSetString(0, objName, OBJPROP_TEXT, "Entry Point");
    }
}

//+------------------------------------------------------------------+
//| STATE DRAW GRID LEVEL LINE (Helper)                               |
//+------------------------------------------------------------------+
void StateDrawGridLine(string name, double price, color lineColor) {
    string objName = "SUGAMARA_" + name;
    
    // Delete if exists
    if(ObjectFind(0, objName) >= 0) {
        ObjectDelete(0, objName);
    }
    
    // Create horizontal line
    if(ObjectCreate(0, objName, OBJ_HLINE, 0, 0, price)) {
        ObjectSetInteger(0, objName, OBJPROP_COLOR, lineColor);
        ObjectSetInteger(0, objName, OBJPROP_STYLE, STYLE_DOT);
        ObjectSetInteger(0, objName, OBJPROP_WIDTH, GridLine_Width);
        ObjectSetInteger(0, objName, OBJPROP_BACK, true);
        ObjectSetInteger(0, objName, OBJPROP_SELECTABLE, false);
    }
}

//+------------------------------------------------------------------+
//| SHOULD AUTO-RESTORE?                                              |
//| Controlla se dovremmo ripristinare stato salvato                  |
//+------------------------------------------------------------------+
bool ShouldAutoRestore() {
    if(!Enable_AutoRecovery) return false;
    
    // Controlla se esiste stato salvato
    if(!GlobalVariableCheck(GetStateKey("entryPoint"))) {
        return false;
    }
    
    // Controlla se ci sono ordini esistenti sul broker
    if(!HasExistingOrders()) {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| CLEAR SAVED STATE                                                 |
//| Elimina tutti i dati salvati (per reset completo)                 |
//+------------------------------------------------------------------+
void ClearSavedState() {
    // Elimina tutte le GlobalVariables con il prefisso
    // Nota: MQL5 non ha modo diretto di eliminare per prefisso,
    // quindi usiamo una lista manuale delle chiavi principali
    
    string keys[] = {
        "entryPoint", "entryPointTime", "currentSpacing", "systemState", 
        "systemActive", "systemStartTime", "lastSaveTime",
        "gridA_ClosedCount", "gridA_PendingCount", "gridB_ClosedCount", "gridB_PendingCount",
        "cop_RealizedProfit", "cop_FloatingProfit", "cop_TotalCommissions", "cop_NetProfit",
        "cop_TargetReached", "cop_TradesToday", "cop_TotalLotsToday", "cop_LastResetDate",
        "sessionProfit", "sessionPeakProfit", "sessionGrossProfit", "sessionGrossLoss",
        "sessionWins", "sessionLosses", "maxDrawdownReached", "startingEquity", "startingBalance"
    };
    
    for(int i = 0; i < ArraySize(keys); i++) {
        string key = GetStateKey(keys[i]);
        if(GlobalVariableCheck(key)) {
            GlobalVariableDel(key);
        }
    }
    
    // Elimina tutti i grid arrays
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        GlobalVariableDel(GetStateKey("gAU_Status_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gAL_Status_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBU_Status_" + IntegerToString(i)));
        GlobalVariableDel(GetStateKey("gBL_Status_" + IntegerToString(i)));
        // ... (ripeti per tutti gli altri array)
    }
    
    // Elimina file backup
    FileDelete(GetEntryPointBackupFilePath(), FILE_COMMON);
    FileDelete(GetCyclingStateFilePath(), FILE_COMMON);
    
    Print("[STATE] All saved state cleared");
}

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS - SAVE                                           |
//+------------------------------------------------------------------+
void SaveStateDouble(string name, double value) {
    GlobalVariableSet(GetStateKey(name), value);
    g_savedVariableCount++;
}

void SaveStateInt(string name, int value) {
    GlobalVariableSet(GetStateKey(name), (double)value);
    g_savedVariableCount++;
}

void SaveStateUlong(string name, ulong value) {
    GlobalVariableSet(GetStateKey(name), (double)value);
    g_savedVariableCount++;
}

void SaveStateBool(string name, bool value) {
    GlobalVariableSet(GetStateKey(name), value ? 1.0 : 0.0);
    g_savedVariableCount++;
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
    info += "Last Save: " + (lastSave > 0 ? TimeToString(lastSave, TIME_DATE|TIME_SECONDS) : "Never") + "\n";
    info += "Auto-Save: " + (Enable_AutoSave ? "ON (" + IntegerToString(AutoSave_Interval_Minutes) + " min)" : "OFF") + "\n";
    
    if(Enable_AutoSave && g_lastAutoSaveTime > 0) {
        int nextSave = AutoSave_Interval_Minutes * 60 - (int)(TimeCurrent() - g_lastAutoSaveTime);
        info += "Next Save in: " + IntegerToString(nextSave) + "s";
    }
    
    return info;
}
```

---

# 📁 PARTE 3: MODIFICHE A Sugamara.mq5

## 3.1 Aggiungere Include

Dopo la riga `#include "Core/RecoveryManager.mqh"` (circa riga 52), aggiungere:

```cpp
#include "Core/StatePersistence.mqh"  // v9.12 Auto-Save & Recovery
```

## 3.2 Modificare OnInit()

Nella funzione `OnInit()`, **DOPO** il blocco di recovery esistente (circa riga 150) e **PRIMA** di "STEP 2: Apply Pair Presets", aggiungere:

```cpp
    //--- STEP 1.6: CHECK FOR AUTO-RESTORE (v9.12) ---
    // v9.12: Auto-restore if valid saved state exists AND broker has existing orders
    if(ShouldAutoRestore()) {
        Print("[AUTO-RESTORE] Valid saved state found - restoring...");
        
        if(RestoreCompleteState()) {
            Print("[AUTO-RESTORE] State restored successfully");
            
            // Apply pair presets for other settings
            ApplyPairPresets();
            
            // Recreate graphics if enabled
            RecreateGridGraphics();
            
            // Skip normal grid initialization
            skipGridInit = true;
        }
    }
```

## 3.3 Modificare OnTick()

All'**INIZIO** della funzione `OnTick()` (prima di qualsiasi altra logica), aggiungere:

```cpp
    //--- v9.12: AUTO-SAVE CHECK ---
    ExecuteAutoSave();
```

## 3.4 Modificare OnDeinit()

Nella funzione `OnDeinit(const int reason)`, aggiungere all'**INIZIO**:

```cpp
    //--- v9.12: SAVE STATE ON DEINIT ---
    g_lastDeinitReason = reason;
    
    // Always save on deinit (except if reason is REASON_REMOVE which means user removed EA)
    if(reason != REASON_REMOVE) {
        Print("[STATE] Saving state on deinit (reason=", reason, ")");
        SaveCompleteState();
    } else {
        Print("[STATE] EA removed - clearing saved state");
        ClearSavedState();
    }
```

---

# 📁 PARTE 4: MODIFICHE A GlobalVariables.mqh

## 4.1 Aggiungere Variabili COP Mancanti

Se non già presenti, aggiungere dopo la sezione ATR (circa riga 65):

```cpp
//+------------------------------------------------------------------+
//| 💰 COP STATE VARIABLES                                            |
//+------------------------------------------------------------------+
double cop_RealizedProfit = 0;              // Profitto realizzato oggi
double cop_FloatingProfit = 0;              // Profitto floating corrente
double cop_TotalCommissions = 0;            // Commissioni totali oggi
double cop_NetProfit = 0;                   // Profitto netto (realized + floating - comm)
bool cop_TargetReached = false;             // Target raggiunto
int cop_TradesToday = 0;                    // Numero trades oggi
double cop_TotalLotsToday = 0;              // Lotti totali oggi
datetime cop_LastResetDate = 0;             // Data ultimo reset

//+------------------------------------------------------------------+
//| 📊 SESSION STATISTICS                                             |
//+------------------------------------------------------------------+
double sessionProfit = 0;                   // Profitto sessione
double sessionPeakProfit = 0;               // Picco profitto sessione
double sessionGrossProfit = 0;              // Profitto lordo sessione
double sessionGrossLoss = 0;                // Perdita lorda sessione
int sessionWins = 0;                        // Vittorie sessione
int sessionLosses = 0;                      // Perdite sessione
double maxDrawdownReached = 0;              // Drawdown massimo raggiunto
double startingEquity = 0;                  // Equity iniziale
double startingBalance = 0;                 // Balance iniziale
```

---

# 📋 PARTE 5: LISTA COMPLETA VARIABILI SALVATE

## 5.1 Riepilogo Variabili (600+ variabili totali)

| Categoria | Variabili | Note |
|-----------|-----------|------|
| Core System | 6 | entryPoint, spacing, state |
| Grid Status | 80 | 4 zone × 20 livelli |
| Grid Cycles | 80 | Contatori cicli reopen |
| Grid LastClose | 80 | Timestamp ultima chiusura |
| Grid Tickets | 80 | Ticket ordini |
| Grid Prices | 80 | Prezzi entry |
| Grid Lots | 80 | Lot size per livello |
| Grid TP | 80 | Take Profit |
| Grid Counters | 16 | Statistiche grid |
| COP State | 8 | Close On Profit |
| Session Stats | 9 | Statistiche sessione |
| Exposure | 4 | Esposizione netta |
| Range | 3 | Boundaries |
| ATR Cache | 5 | Volatilità |
| Breakout | 6 | Livelli breakout |
| Shield | 13 | (se abilitato) |
| Straddle | 16 | (se abilitato) |
| **TOTALE** | **~650** | **Copertura 100%** |

## 5.2 Focus Critico: Reopen Cycling

Le variabili **CRITICHE** per il Reopen Cycling sono:

1. **`gridX_Zone_Status[i]`** - ENUM_ORDER_STATUS (ORDER_CLOSED_TP = aspetta reopen)
2. **`gridX_Zone_Cycles[i]`** - Contatore cicli completati
3. **`gridX_Zone_LastClose[i]`** - Timestamp chiusura (per cooldown)
4. **`gridX_Zone_EntryPrices[i]`** - Prezzo dove reinserire l'ordine

Senza queste variabili, dopo un crash:
- Un livello che era `ORDER_CLOSED_TP` diventa `ORDER_NONE`
- Il sistema non sa che deve reinserire l'ordine
- Il Reopen Cycling si interrompe
- Si perdono i cicli già completati

---

# 📋 PARTE 6: TESTING CHECKLIST

## 6.1 Test Auto-Save

1. ✅ Avviare EA e verificare che salvi dopo N minuti
2. ✅ Controllare GlobalVariables (premere F3 in MT5)
3. ✅ Verificare file backup in `MQL5/Files/Common/`

## 6.2 Test Recovery

1. ✅ Avviare griglia e attendere alcuni cicli
2. ✅ Cambiare timeframe (simula restart)
3. ✅ Verificare che tutto sia ripristinato
4. ✅ Verificare che le linee grafiche siano visibili
5. ✅ Verificare che il Reopen Cycling continui

## 6.3 Test Scenari Crash

1. ✅ Chiudere MT5 (Task Manager)
2. ✅ Riavviare MT5
3. ✅ Verificare recovery automatico
4. ✅ Confrontare stato pre/post crash

---

# ⚠️ NOTE IMPORTANTI PER CLAUDE CODE

1. **NON modificare** la logica esistente del RecoveryManager - aggiungi solo l'integrazione
2. **PRESERVA** tutti i commenti esistenti nel codice
3. **USA** lo stesso stile di codice (indentazione, naming convention)
4. **TESTA** ogni modifica incrementalmente
5. **DOCUMENTA** ogni cambiamento nel changelog

---

# 📌 VERSIONE TARGET

```
SUGAMARA RIBELLE v9.12 - Auto-Save Integration
- NEW: Auto-Save every N minutes (configurable)
- NEW: Full state persistence (600+ variables)
- NEW: Graphics recreation on recovery
- NEW: Reopen Cycling preserved after crash
- ENHANCED: Recovery system integration
```

---

**Fine documento - Pronto per Claude Code**
