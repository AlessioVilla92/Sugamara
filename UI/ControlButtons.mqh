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
bool waitingForActivation = false;

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
    ObjectDelete(0, name);

    if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) {
        Log_SystemError("ControlButtons", 0, StringFormat("Failed to create button %s", name));
        return;
    }

    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, bgColor);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrBlack);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 10);
    ObjectSetString(0, name, OBJPROP_FONT, "Arial Bold");
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_STATE, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 10001);
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

    // Reset button state
    ObjectSetInteger(0, objectName, OBJPROP_STATE, false);

    //══════════════════════════════════════════════════════════════
    // START Button
    //══════════════════════════════════════════════════════════════
    if(objectName == BTN_START_V3) {
        Log_Header("START BUTTON CLICKED");

        currentEntryMode = ENTRY_MARKET;
        buttonState = BTN_STATE_ACTIVE;
        waitingForActivation = false;

        // Highlight active button
        HighlightActiveButton(BTN_START_V3);
        UpdateStatusLabel("STARTING GRID...");

        // Start grid immediately
        StartGridSystem();

        return;
    }

    //══════════════════════════════════════════════════════════════
    // CLOSE ALL Button
    //══════════════════════════════════════════════════════════════
    if(objectName == BTN_CLOSEALL_V3) {
        Log_Header("CLOSE ALL REQUESTED");

        CloseAllSugamaraOrders();

        // v5.8 FIX: COP_ResetDaily() RIMOSSO - profitti devono accumularsi
        // Il reset avviene solo al cambio giorno (COP_IsNewDay) o target raggiunto

        currentEntryMode = ENTRY_MARKET;
        buttonState = BTN_STATE_IDLE;
        waitingForActivation = false;
        systemState = STATE_IDLE;

        ResetButtonHighlights();
        UpdateStatusLabel("ALL CLOSED - Ready");

        if(EnableAlerts) {
            Alert("SUGAMARA: All positions closed");
        }

        return;
    }

    //══════════════════════════════════════════════════════════════
    // RECOVER Button - v5.9 Manual Recovery
    //══════════════════════════════════════════════════════════════
    if(objectName == BTN_RECOVER_V3) {
        Log_Header("MANUAL RECOVERY REQUESTED");

        UpdateStatusLabel("RECOVERING...");
        ChartRedraw(0);

        // Call recovery function from RecoveryManager
        if(ForceRecoveryFromBroker()) {
            // Recovery successful
            LogRecoveryReport();

            systemState = STATE_ACTIVE;
            buttonState = BTN_STATE_ACTIVE;
            HighlightActiveButton(BTN_START_V3);
            UpdateStatusLabel("RECOVERED - Grid Active");

            // Recalculate spacing and redraw
            currentSpacing_Pips = CalculateCurrentSpacing();
            DrawGridVisualization();

            // v5.9.1: Ridisegna TUTTE le visualizzazioni dopo recovery
            if(Enable_ManualSR) {
                UpdateLossZoneRectangles();      // Zone rosse/verdi
            }
            // ShieldZonesVisual REMOVED in v9.12

            if(EnableAlerts && !MQLInfoInteger(MQL_TESTER)) {
                Alert("SUGAMARA [", _Symbol, "]: Recovery successful - ",
                      g_recoveredOrdersCount, " orders, ",
                      g_recoveredPositionsCount, " positions recovered");
            }
        } else {
            // No orders found to recover
            UpdateStatusLabel("No orders to recover");

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
        UpdateStatusLabel("ACTIVE - Grid Running");
    } else {
        Log_InitFailed("GridSystem", "Failed to start");
        UpdateStatusLabel("ERROR - Check logs");
        systemState = STATE_ERROR;
    }
}

//+------------------------------------------------------------------+
//| Highlight Active Button                                          |
//+------------------------------------------------------------------+
void HighlightActiveButton(string activeBtn) {
    // Reset START button
    ObjectSetInteger(0, BTN_START_V3, OBJPROP_BGCOLOR, CLR_BTN_START);

    // Highlight active
    ObjectSetInteger(0, activeBtn, OBJPROP_BGCOLOR, CLR_BTN_ACTIVE);

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Reset Button Highlights                                          |
//+------------------------------------------------------------------+
void ResetButtonHighlights() {
    ObjectSetInteger(0, BTN_START_V3, OBJPROP_BGCOLOR, CLR_BTN_START);
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Update Status Label                                              |
//+------------------------------------------------------------------+
void UpdateStatusLabel(string text) {
    ObjectSetString(0, BTN_STATUS_V3, OBJPROP_TEXT, text);
    ChartRedraw(0);
}

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

//+------------------------------------------------------------------+
//| Is Waiting For Activation                                        |
//+------------------------------------------------------------------+
bool IsWaitingForActivation() {
    return waitingForActivation;
}

//+------------------------------------------------------------------+
//| Cancel Waiting                                                   |
//+------------------------------------------------------------------+
void CancelWaiting() {
    waitingForActivation = false;
    buttonState = BTN_STATE_IDLE;
    ResetButtonHighlights();
    UpdateStatusLabel("READY - Click START");
}

//+------------------------------------------------------------------+
//| Remove Control Buttons                                           |
//+------------------------------------------------------------------+
void RemoveControlButtons() {
    ObjectDelete(0, BTN_START_V3);
    ObjectDelete(0, BTN_CLOSEALL_V3);
    ObjectDelete(0, BTN_RECOVER_V3);
    ObjectDelete(0, BTN_STATUS_V3);
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Deinitialize Control Buttons                                     |
//+------------------------------------------------------------------+
void DeinitializeControlButtons() {
    RemoveControlButtons();
    Log_Debug("ControlButtons", "Deinitialized");
}

//+------------------------------------------------------------------+
//| Process Entry Mode Waiting (Stub - LIMIT/STOP modes removed)     |
//| v4.3: This function is kept for backwards compatibility          |
//| but does nothing since LIMIT/STOP modes are no longer supported  |
//+------------------------------------------------------------------+
void ProcessEntryModeWaiting() {
    // v4.3: LIMIT and STOP modes have been removed
    // Grid Neutral only uses immediate START
    // This function is a stub for backwards compatibility
    return;
}

