//+------------------------------------------------------------------+
//|                                              DebugMode.mqh       |
//|                        Sugamara - Debug Mode Manager             |
//|                                                                  |
//|  Debug mode for automated backtest entry without manual clicks   |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Global Debug Variables                                           |
//+------------------------------------------------------------------+
bool debugEntryTriggered = false;    // Flag per evitare trigger multipli
bool debugCloseTriggered = false;    // Flag per evitare chiusure multiple
datetime debugTargetTime = 0;        // Per modalita scheduled (opzionale)
datetime debugCloseTargetTime = 0;   // Orario chiusura (0 = disabilitato)

//+------------------------------------------------------------------+
//| Parse Debug Entry Time String (opzionale per scheduled mode)     |
//+------------------------------------------------------------------+
datetime ParseDebugEntryTime(string timeStr) {
    string parts[];
    int count = StringSplit(timeStr, ':', parts);

    if(count != 2) {
        Print("ERROR: Invalid time format. Expected HH:MM");
        return 0;
    }

    int hour = (int)StringToInteger(parts[0]);
    int minute = (int)StringToInteger(parts[1]);

    if(hour < 0 || hour > 23 || minute < 0 || minute > 59) {
        Print("ERROR: Invalid time values. Hour: 0-23, Minute: 0-59");
        return 0;
    }

    MqlDateTime dt;
    TimeCurrent(dt);
    dt.hour = hour;
    dt.min = minute;
    dt.sec = 0;

    return StructToTime(dt);
}

//+------------------------------------------------------------------+
//| Initialize Debug Mode                                            |
//+------------------------------------------------------------------+
bool InitializeDebugMode() {
    if(!EnableDebugMode) {
        return true;  // Non e un errore, semplicemente non abilitato
    }

    // Parse time solo se non usa immediate entry
    if(!DebugImmediateEntry && StringLen(DebugEntryTime) > 0) {
        debugTargetTime = ParseDebugEntryTime(DebugEntryTime);
        if(debugTargetTime == 0) {
            Alert("ERROR: Invalid Debug Entry Time format! Use HH:MM");
            Print("ERROR: Debug Mode disabled due to invalid time format");
            return false;
        }
    }

    Log_Header("DEBUG MODE ENABLED");
    Log_KeyValue("Mode", DebugImmediateEntry ? "IMMEDIATE (First Tick)" : "SCHEDULED");

    if(!DebugImmediateEntry) {
        Log_KeyValue("Entry Time", DebugEntryTime);
    }

    // Parse close time if provided
    if(StringLen(DebugCloseTime) > 0 && DebugCloseTime != "") {
        debugCloseTargetTime = ParseDebugEntryTime(DebugCloseTime);
        if(debugCloseTargetTime > 0) {
            Log_KeyValue("Close Time", DebugCloseTime);
        }
    }

    Log_Separator();

    return true;
}

//+------------------------------------------------------------------+
//| Check and Trigger Debug Entry                                    |
//+------------------------------------------------------------------+
void CheckDebugModeEntry() {
    // Diagnostic log: first tick only
    static bool diagnosticLoggedOnce = false;
    if(!diagnosticLoggedOnce) {
        Log_Header("DEBUG DIAGNOSTIC - First Tick");
        Log_KeyValue("EnableDebugMode", EnableDebugMode ? "TRUE" : "FALSE (BLOCKING)");
        Log_KeyValue("DebugImmediateEntry", DebugImmediateEntry ? "TRUE" : "FALSE");
        Log_KeyValue("debugEntryTriggered", debugEntryTriggered ? "TRUE (already)" : "FALSE");
        string stateStr = (systemState == STATE_IDLE) ? "IDLE" :
                         (systemState == STATE_ACTIVE) ? "ACTIVE" :
                         (systemState == STATE_ERROR) ? "ERROR" : "OTHER";
        Log_KeyValue("systemState", stateStr);
        Log_Separator();
        if(!EnableDebugMode) {
            Log_SystemWarning("Debug", "FIX: Set EnableDebugMode=true in EA parameters");
        }
        if(systemState != STATE_IDLE) {
            Log_SystemWarning("Debug", "FIX: Check OnInit() completed (look for CRITICAL errors)");
        }
        diagnosticLoggedOnce = true;
    }

    // Solo se: debug abilitato, non ancora triggered, sistema idle
    if(!EnableDebugMode || debugEntryTriggered || systemState != STATE_IDLE) {
        return;
    }

    bool shouldTrigger = false;

    // Check condizione trigger
    if(DebugImmediateEntry) {
        // IMMEDIATE MODE: Trigger al primo tick
        shouldTrigger = true;
    } else if(debugTargetTime > 0) {
        // SCHEDULED MODE: Check se ora >= target time
        MqlDateTime currentTime, targetTime;
        TimeToStruct(TimeCurrent(), currentTime);
        TimeToStruct(debugTargetTime, targetTime);

        if(currentTime.hour > targetTime.hour ||
           (currentTime.hour == targetTime.hour && currentTime.min >= targetTime.min)) {
            shouldTrigger = true;
        }
    }

    if(shouldTrigger) {
        debugEntryTriggered = true;

        Log_Header("DEBUG MODE AUTO-START");
        Log_KeyValue("Time", TimeToString(TimeCurrent()));
        Log_KeyValue("Mode", DebugImmediateEntry ? "IMMEDIATE" : "SCHEDULED");
        Log_Separator();

        // Avvia il sistema griglia (chiama StartGridSystem da ControlButtons.mqh)
        StartGridSystem();
    }
}

//+------------------------------------------------------------------+
//| Check and Trigger Debug Close (Intraday Exit)                    |
//+------------------------------------------------------------------+
void CheckDebugModeClose() {
    // Solo se: debug abilitato, close time impostato, non ancora chiuso, sistema attivo
    if(!EnableDebugMode || debugCloseTargetTime == 0 || debugCloseTriggered) {
        return;
    }

    // Solo se sistema e attivo (ha posizioni aperte)
    if(systemState != STATE_ACTIVE) {
        return;
    }

    MqlDateTime currentTime, targetTime;
    TimeToStruct(TimeCurrent(), currentTime);
    TimeToStruct(debugCloseTargetTime, targetTime);

    // Trigger quando ora >= close time
    if(currentTime.hour > targetTime.hour ||
       (currentTime.hour == targetTime.hour && currentTime.min >= targetTime.min)) {

        debugCloseTriggered = true;

        Log_Header("DEBUG MODE AUTO-CLOSE");
        Log_KeyValue("Time", TimeToString(TimeCurrent()));
        Log_KeyValue("Close Setting", DebugCloseTime);
        Log_Separator();

        // Chiudi tutte le posizioni (usa funzione esistente in OrderManager.mqh)
        CloseAllSugamaraOrders();

        // Imposta sistema in pausa (non riaprire)
        systemState = STATE_PAUSED;
    }
}
