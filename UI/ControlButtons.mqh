//+------------------------------------------------------------------+
//|                                             ControlButtons.mqh   |
//|                        Sugamara v4.3 - Control Buttons           |
//|                                                                  |
//|  2 Bottoni Principali (Semplificato per Grid Neutrale):          |
//|  - START: Partenza immediata @ prezzo corrente                   |
//|  - CLOSE: Chiude tutto e resetta                                 |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

// v9.24: DashObjName() function is used from Dashboard.mqh (automatically available in MQL5 includes)

//+------------------------------------------------------------------+
//| BUTTON CONSTANTS                                                 |
//+------------------------------------------------------------------+
#define BTN_START_V3      "SUGAMARA_BTN_START"
#define BTN_CLOSEALL_V3   "SUGAMARA_BTN_CLOSEALL"
#define BTN_RECOVER_V3    "SUGAMARA_BTN_RECOVER"
#define BTN_STATUS_V3     "SUGAMARA_BTN_STATUS"

//+------------------------------------------------------------------+
//| BUTTON COLORS                                                    |
//+------------------------------------------------------------------+
#define CLR_BTN_START     C'0,150,80'       // Verde scuro
#define CLR_BTN_CLOSE     C'180,30,30'      // Rosso scuro
#define CLR_BTN_RECOVER   C'0,140,140'      // Cyan/Teal - Recovery
#define CLR_BTN_ACTIVE    C'0,200,100'      // Verde brillante

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+

ENUM_ENTRY_MODE currentEntryMode = ENTRY_MARKET;
ENUM_BUTTON_STATE buttonState = BTN_STATE_IDLE;
// v9.12: waitingForActivation REMOVED - LIMIT/STOP modes not supported

//+------------------------------------------------------------------+
//| Initialize Control Buttons                                       |
//+------------------------------------------------------------------+
bool InitializeControlButtons(int startX, int startY, int panelWidth) {
    // v5.9: Buttons are ALWAYS active + RECOVER button added
    Log_Header("CONTROL BUTTONS v5.9 (Always Active + Recovery)");

    int x = startX + 10;
    int y = startY + 10;
    int btnStartWidth = 110;   // START
    int btnCloseWidth = 90;    // CLOSE
    int btnRecoverWidth = 90;  // RECOVER
    int btnHeight = 35;
    int spacing = 5;           // v5.9.1: Ridotto da 8 a 5 per far entrare tutti i bottoni

    // Status Label
    CreateButtonLabel(BTN_STATUS_V3, x, y, panelWidth - 20, "READY - Click START", THEME_DASHBOARD_TEXT);
    y += 25;

    // START Button (verde)
    CreateControlButton(BTN_START_V3, x, y, btnStartWidth, btnHeight, "START", CLR_BTN_START);

    // CLOSE Button (rosso)
    CreateControlButton(BTN_CLOSEALL_V3, x + btnStartWidth + spacing, y, btnCloseWidth, btnHeight, "CLOSE", CLR_BTN_CLOSE);

    // RECOVER Button (cyan) - v5.9
    CreateControlButton(BTN_RECOVER_V3, x + btnStartWidth + spacing + btnCloseWidth + spacing, y, btnRecoverWidth, btnHeight, "RECOVER", CLR_BTN_RECOVER);

    // Set default mode
    currentEntryMode = ENTRY_MARKET;
    buttonState = BTN_STATE_IDLE;

    Log_Debug("ControlButtons", StringFormat("Layout: START (%dpx) | CLOSE (%dpx) | RECOVER (%dpx)", btnStartWidth, btnCloseWidth, btnRecoverWidth));

    ChartRedraw(0);
    return true;
}

//+------------------------------------------------------------------+
//| Create Control Button                                            |
//+------------------------------------------------------------------+
void CreateControlButton(string name, int x, int y, int width, int height, string text, color bgColor) {
    string objName = DashObjName(name);  // v9.24: Apply symbol suffix for multi-chart
    ObjectDelete(0, objName);

    if(!ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0)) {
        Log_SystemError("ControlButtons", 0, StringFormat("Failed to create button %s", objName));
        return;
    }

    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, objName, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, objName, OBJPROP_YSIZE, height);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, bgColor);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, clrBlack);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 10);
    ObjectSetString(0, objName, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
    ObjectSetInteger(0, objName, OBJPROP_STATE, false);
    ObjectSetInteger(0, objName, OBJPROP_ZORDER, 10001);
}

//+------------------------------------------------------------------+
//| Create Button Label                                              |
//+------------------------------------------------------------------+
void CreateButtonLabel(string name, int x, int y, int width, string text, color clr) {
    ObjectDelete(0, name);

    if(!ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0)) return;

    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 10002);
}

//+------------------------------------------------------------------+
//| Handle Button Click                                              |
//+------------------------------------------------------------------+
void HandleControlButtonClick(string objectName) {
    // v4.4: No check needed - buttons always active

    // v9.24: Strip symbol suffix for comparison (multi-chart support)
    string baseName = objectName;
    int suffixPos = StringFind(objectName, "_" + _Symbol);
    if(suffixPos > 0) {
        baseName = StringSubstr(objectName, 0, suffixPos);
    }

    // Reset button state using ORIGINAL name (with suffix)
    ObjectSetInteger(0, objectName, OBJPROP_STATE, false);

    //══════════════════════════════════════════════════════════════
    // START Button
    //══════════════════════════════════════════════════════════════
    if(baseName == BTN_START_V3) {
        Log_Header("START BUTTON CLICKED");

        currentEntryMode = ENTRY_MARKET;
        buttonState = BTN_STATE_ACTIVE;

        // Highlight active button
        HighlightActiveButton(BTN_START_V3);

        // Start grid immediately
        StartGridSystem();

        // v9.22 FIX: Immediate dashboard update for state colors
        UpdateDashboard();

        return;
    }

    //══════════════════════════════════════════════════════════════
    // CLOSE ALL Button
    //══════════════════════════════════════════════════════════════
    if(baseName == BTN_CLOSEALL_V3) {
        Log_Header("CLOSE ALL REQUESTED");

        CloseAllSugamaraOrders();

        // v5.8 FIX: COP_ResetDaily() RIMOSSO - profitti devono accumularsi
        // Il reset avviene solo al cambio giorno (COP_IsNewDay) o target raggiunto

        currentEntryMode = ENTRY_MARKET;
        buttonState = BTN_STATE_IDLE;
        systemState = STATE_CLOSING;  // v9.21: Triggers STOPPED status in Mode indicator

        ResetButtonHighlights();

        // v9.22 FIX: Immediate dashboard update for state colors
        UpdateDashboard();

        if(EnableAlerts) {
            Alert("SUGAMARA: All positions closed");
        }

        return;
    }

    //══════════════════════════════════════════════════════════════
    // RECOVER Button - v5.9 Manual Recovery
    //══════════════════════════════════════════════════════════════
    if(baseName == BTN_RECOVER_V3) {
        Log_Header("MANUAL RECOVERY REQUESTED");
        // v9.22: Status updated by Dashboard.mqh based on systemState
        ChartRedraw(0);

        // Call recovery function from RecoveryManager
        if(ForceRecoveryFromBroker()) {
            // Recovery successful
            LogRecoveryReport();

            systemState = STATE_ACTIVE;
            buttonState = BTN_STATE_ACTIVE;
            HighlightActiveButton(BTN_START_V3);
            // v9.22: Status updated by Dashboard.mqh based on systemState

            // Recalculate spacing and redraw
            currentSpacing_Pips = CalculateCurrentSpacing();
            DrawGridVisualization();

            // v5.9.1: Ridisegna TUTTE le visualizzazioni dopo recovery
            // Loss zone rectangles removed in v9.25
            // ShieldZonesVisual REMOVED in v9.12

            if(EnableAlerts && !MQLInfoInteger(MQL_TESTER)) {
                Alert("SUGAMARA [", _Symbol, "]: Recovery successful - ",
                      g_recoveredOrdersCount, " orders, ",
                      g_recoveredPositionsCount, " positions recovered");
            }
        } else {
            // No orders found to recover
            // v9.22: Status updated by Dashboard.mqh based on systemState

            if(EnableAlerts && !MQLInfoInteger(MQL_TESTER)) {
                Alert("SUGAMARA [", _Symbol, "]: No orders found to recover");
            }
        }

        return;
    }

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Start Grid System                                                |
//+------------------------------------------------------------------+
void StartGridSystem() {
    // v5.8 FIX: COP_ResetDaily() RIMOSSO - profitti devono accumularsi
    // Il reset avviene solo al cambio giorno (COP_IsNewDay) o target raggiunto

    systemState = STATE_ACTIVE;

    // Initialize entry point at current price
    InitializeEntryPoint();

    // Calculate spacing
    currentSpacing_Pips = CalculateCurrentSpacing();

    // Initialize and place grids
    if(InitializeGridA() && InitializeGridB()) {
        PlaceAllGridAOrders();
        PlaceAllGridBOrders();

        Log_InitComplete("GridSystem");
        // v9.22: Status updated by Dashboard.mqh based on systemState
    } else {
        Log_InitFailed("GridSystem", "Failed to start");
        // v9.22: Status updated by Dashboard.mqh based on systemState
        systemState = STATE_ERROR;
    }
}

//+------------------------------------------------------------------+
//| Highlight Active Button                                          |
//+------------------------------------------------------------------+
void HighlightActiveButton(string activeBtn) {
    // v9.24: Apply symbol suffix for multi-chart
    string startBtn = DashObjName(BTN_START_V3);

    // Reset START button
    ObjectSetInteger(0, startBtn, OBJPROP_BGCOLOR, CLR_BTN_START);

    // Highlight active (activeBtn already has suffix from caller)
    ObjectSetInteger(0, activeBtn, OBJPROP_BGCOLOR, CLR_BTN_ACTIVE);

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Reset Button Highlights                                          |
//+------------------------------------------------------------------+
void ResetButtonHighlights() {
    // v9.24: Apply symbol suffix for multi-chart
    string startBtn = DashObjName(BTN_START_V3);
    ObjectSetInteger(0, startBtn, OBJPROP_BGCOLOR, CLR_BTN_START);
    ChartRedraw(0);
}

// v9.22: UpdateStatusLabel REMOVED - Dashboard.mqh handles status colors based on systemState

//+------------------------------------------------------------------+
//| Get Entry Mode Name                                              |
//+------------------------------------------------------------------+
string GetEntryModeName(ENUM_ENTRY_MODE mode) {
    switch(mode) {
        case ENTRY_MARKET: return "MARKET";
        case ENTRY_LIMIT:  return "LIMIT";
        case ENTRY_STOP:   return "STOP";
    }
    return "UNKNOWN";
}

//+------------------------------------------------------------------+
//| Get Current Entry Mode                                           |
//+------------------------------------------------------------------+
ENUM_ENTRY_MODE GetCurrentEntryMode() {
    return currentEntryMode;
}

// v9.12: IsWaitingForActivation(), CancelWaiting() REMOVED - LIMIT/STOP modes not supported

//+------------------------------------------------------------------+
//| Remove Control Buttons                                           |
//+------------------------------------------------------------------+
void RemoveControlButtons() {
    // v9.24: Apply symbol suffix for multi-chart
    ObjectDelete(0, DashObjName(BTN_START_V3));
    ObjectDelete(0, DashObjName(BTN_CLOSEALL_V3));
    ObjectDelete(0, DashObjName(BTN_RECOVER_V3));
    ObjectDelete(0, DashObjName(BTN_STATUS_V3));
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Deinitialize Control Buttons                                     |
//+------------------------------------------------------------------+
void DeinitializeControlButtons() {
    RemoveControlButtons();
    Log_Debug("ControlButtons", "Deinitialized");
}

// v9.12: ProcessEntryModeWaiting() REMOVED - was empty stub

