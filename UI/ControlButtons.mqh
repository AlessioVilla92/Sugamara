//+------------------------------------------------------------------+
//|                                             ControlButtons.mqh   |
//|                        Sugamara v3.0 - Control Buttons           |
//|                                                                  |
//|  4 Bottoni Principali:                                           |
//|  - MARKET: Partenza immediata @ prezzo corrente                  |
//|  - LIMIT: Aspetta che prezzo torni a livello attivazione         |
//|  - STOP: Aspetta breakout di un livello                          |
//|  - CLOSE ALL: Chiude tutto e resetta                             |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| BUTTON CONSTANTS                                                 |
//+------------------------------------------------------------------+
#define BTN_MARKET_V3     "SUGAMARA_BTN_MARKET"
#define BTN_LIMIT_V3      "SUGAMARA_BTN_LIMIT"
#define BTN_STOP_V3       "SUGAMARA_BTN_STOP"
#define BTN_CLOSEALL_V3   "SUGAMARA_BTN_CLOSEALL"
#define BTN_STATUS_V3     "SUGAMARA_BTN_STATUS"

//+------------------------------------------------------------------+
//| BUTTON COLORS                                                    |
//+------------------------------------------------------------------+
#define CLR_BTN_MARKET    C'0,150,80'       // Verde scuro
#define CLR_BTN_LIMIT     C'30,120,200'     // Blu
#define CLR_BTN_STOP      C'200,150,0'      // Oro
#define CLR_BTN_CLOSE     C'180,30,30'      // Rosso scuro
#define CLR_BTN_ACTIVE    C'0,200,100'      // Verde brillante
#define CLR_BTN_WAITING   C'200,180,50'     // Giallo attesa

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+

ENUM_ENTRY_MODE currentEntryMode = ENTRY_MARKET;
ENUM_BUTTON_STATE buttonState = BTN_STATE_IDLE;
bool waitingForActivation = false;
datetime waitStartTime = 0;

//+------------------------------------------------------------------+
//| Initialize Control Buttons                                       |
//+------------------------------------------------------------------+
bool InitializeControlButtons(int startX, int startY, int panelWidth) {
    if(!Enable_AdvancedButtons) {
        Print("INFO: Advanced Control Buttons are DISABLED");
        return true;
    }

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  INITIALIZING CONTROL BUTTONS v3.0");
    Print("═══════════════════════════════════════════════════════════════════");

    int x = startX + 10;
    int y = startY + 10;
    int btnWidth = 70;
    int btnHeight = 35;
    int spacing = 5;

    // Status Label
    CreateButtonLabel(BTN_STATUS_V3, x, y, panelWidth - 20, "READY - Select Entry Mode", Theme_DashboardText);
    y += 25;

    // MARKET Button
    CreateControlButton(BTN_MARKET_V3, x, y, btnWidth, btnHeight, "MARKET", CLR_BTN_MARKET);

    // LIMIT Button
    CreateControlButton(BTN_LIMIT_V3, x + btnWidth + spacing, y, btnWidth, btnHeight, "LIMIT", CLR_BTN_LIMIT);

    // STOP Button
    CreateControlButton(BTN_STOP_V3, x + (btnWidth + spacing) * 2, y, btnWidth, btnHeight, "STOP", CLR_BTN_STOP);

    // CLOSE ALL Button
    CreateControlButton(BTN_CLOSEALL_V3, x + (btnWidth + spacing) * 3, y, btnWidth + 15, btnHeight, "CLOSE", CLR_BTN_CLOSE);

    // Set default mode
    currentEntryMode = DefaultEntryMode;
    buttonState = BTN_STATE_IDLE;

    Print("  Default Entry Mode: ", GetEntryModeName(currentEntryMode));
    Print("═══════════════════════════════════════════════════════════════════");

    ChartRedraw(0);
    return true;
}

//+------------------------------------------------------------------+
//| Create Control Button                                            |
//+------------------------------------------------------------------+
void CreateControlButton(string name, int x, int y, int width, int height, string text, color bgColor) {
    ObjectDelete(0, name);

    if(!ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0)) {
        Print("ERROR: Failed to create button ", name);
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
    if(!Enable_AdvancedButtons) return;

    // Reset button state
    ObjectSetInteger(0, objectName, OBJPROP_STATE, false);

    //══════════════════════════════════════════════════════════════
    // MARKET Button
    //══════════════════════════════════════════════════════════════
    if(objectName == BTN_MARKET_V3) {
        Print("═══════════════════════════════════════════════════════════════════");
        Print("  MARKET MODE SELECTED - Starting Immediately");
        Print("═══════════════════════════════════════════════════════════════════");

        currentEntryMode = ENTRY_MARKET;
        buttonState = BTN_STATE_ACTIVE;
        waitingForActivation = false;

        // Highlight active button
        HighlightActiveButton(BTN_MARKET_V3);
        UpdateStatusLabel("MARKET MODE - Starting Grid...");

        // Start grid immediately
        StartGridSystem();

        return;
    }

    //══════════════════════════════════════════════════════════════
    // LIMIT Button
    //══════════════════════════════════════════════════════════════
    if(objectName == BTN_LIMIT_V3) {
        Print("═══════════════════════════════════════════════════════════════════");
        Print("  LIMIT MODE SELECTED - Waiting for Price Return");
        Print("═══════════════════════════════════════════════════════════════════");

        currentEntryMode = ENTRY_LIMIT;
        buttonState = BTN_STATE_WAITING;
        waitingForActivation = true;
        waitStartTime = TimeCurrent();

        // Highlight waiting button
        HighlightActiveButton(BTN_LIMIT_V3);

        double activationPrice = (Enable_ManualSR) ? GetManualActivation() :
                                 (LimitActivation_Price > 0) ? LimitActivation_Price :
                                 SymbolInfoDouble(_Symbol, SYMBOL_BID);

        UpdateStatusLabel("LIMIT: Waiting @ " + DoubleToString(activationPrice, _Digits));

        Print("  Activation Price: ", DoubleToString(activationPrice, _Digits));
        Print("  Drag the GOLD line to set activation level");

        if(EnableAlerts) {
            Alert("SUGAMARA: LIMIT mode - Waiting for price @ ", DoubleToString(activationPrice, _Digits));
        }

        return;
    }

    //══════════════════════════════════════════════════════════════
    // STOP Button
    //══════════════════════════════════════════════════════════════
    if(objectName == BTN_STOP_V3) {
        Print("═══════════════════════════════════════════════════════════════════");
        Print("  STOP MODE SELECTED - Waiting for Breakout");
        Print("═══════════════════════════════════════════════════════════════════");

        currentEntryMode = ENTRY_STOP;
        buttonState = BTN_STATE_WAITING;
        waitingForActivation = true;
        waitStartTime = TimeCurrent();

        // Highlight waiting button
        HighlightActiveButton(BTN_STOP_V3);

        double activationPrice = (Enable_ManualSR) ? GetManualActivation() :
                                 (StopActivation_Price > 0) ? StopActivation_Price :
                                 SymbolInfoDouble(_Symbol, SYMBOL_BID);

        UpdateStatusLabel("STOP: Waiting breakout @ " + DoubleToString(activationPrice, _Digits));

        Print("  Breakout Price: ", DoubleToString(activationPrice, _Digits));
        Print("  Drag the GOLD line to set breakout level");

        if(EnableAlerts) {
            Alert("SUGAMARA: STOP mode - Waiting for breakout @ ", DoubleToString(activationPrice, _Digits));
        }

        return;
    }

    //══════════════════════════════════════════════════════════════
    // CLOSE ALL Button
    //══════════════════════════════════════════════════════════════
    if(objectName == BTN_CLOSEALL_V3) {
        Print("═══════════════════════════════════════════════════════════════════");
        Print("  CLOSE ALL REQUESTED");
        Print("═══════════════════════════════════════════════════════════════════");

        CloseAllSugamaraOrders();

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

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Process Entry Mode Waiting                                       |
//+------------------------------------------------------------------+
void ProcessEntryModeWaiting() {
    if(!Enable_AdvancedButtons || !waitingForActivation) return;

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double activationPrice = (Enable_ManualSR) ? GetManualActivation() :
                             (currentEntryMode == ENTRY_LIMIT) ? LimitActivation_Price :
                             StopActivation_Price;

    if(activationPrice == 0) return;

    bool shouldActivate = false;
    double tolerance = 3 * symbolPoint * 10; // 3 pips tolerance

    if(currentEntryMode == ENTRY_LIMIT) {
        // LIMIT: Activate when price RETURNS to level
        shouldActivate = (MathAbs(currentPrice - activationPrice) <= tolerance);
    }
    else if(currentEntryMode == ENTRY_STOP) {
        // STOP: Activate when price BREAKS through level
        // Determine direction based on current price vs activation
        static double lastCheckPrice = 0;

        if(lastCheckPrice == 0) lastCheckPrice = currentPrice;

        // If price was below and now above = upward breakout
        if(lastCheckPrice <= activationPrice && currentPrice > activationPrice + tolerance) {
            shouldActivate = true;
            Print("STOP: Upward breakout detected");
        }
        // If price was above and now below = downward breakout
        else if(lastCheckPrice >= activationPrice && currentPrice < activationPrice - tolerance) {
            shouldActivate = true;
            Print("STOP: Downward breakout detected");
        }

        lastCheckPrice = currentPrice;
    }

    if(shouldActivate) {
        Print("═══════════════════════════════════════════════════════════════════");
        Print("  ACTIVATION TRIGGERED!");
        Print("  Mode: ", GetEntryModeName(currentEntryMode));
        Print("  Price: ", DoubleToString(currentPrice, _Digits));
        Print("═══════════════════════════════════════════════════════════════════");

        waitingForActivation = false;
        buttonState = BTN_STATE_ACTIVE;

        UpdateStatusLabel(GetEntryModeName(currentEntryMode) + " ACTIVATED!");

        // Start the grid system
        StartGridSystem();

        if(EnableAlerts) {
            Alert("SUGAMARA: ", GetEntryModeName(currentEntryMode), " mode activated @ ",
                  DoubleToString(currentPrice, _Digits));
        }
    }
}

//+------------------------------------------------------------------+
//| Start Grid System                                                |
//+------------------------------------------------------------------+
void StartGridSystem() {
    systemState = STATE_ACTIVE;

    // Initialize entry point at current price
    InitializeEntryPoint();

    // Calculate spacing
    currentSpacing_Pips = CalculateCurrentSpacing();

    // Initialize and place grids
    if(InitializeGridA() && InitializeGridB()) {
        PlaceAllGridAOrders();
        PlaceAllGridBOrders();

        Print("SUCCESS: Grid system started in ", GetEntryModeName(currentEntryMode), " mode");
        UpdateStatusLabel("ACTIVE - Grid Running");
    } else {
        Print("ERROR: Failed to start grid system");
        UpdateStatusLabel("ERROR - Check logs");
        systemState = STATE_ERROR;
    }
}

//+------------------------------------------------------------------+
//| Highlight Active Button                                          |
//+------------------------------------------------------------------+
void HighlightActiveButton(string activeBtn) {
    // Reset all buttons
    ObjectSetInteger(0, BTN_MARKET_V3, OBJPROP_BGCOLOR, CLR_BTN_MARKET);
    ObjectSetInteger(0, BTN_LIMIT_V3, OBJPROP_BGCOLOR, CLR_BTN_LIMIT);
    ObjectSetInteger(0, BTN_STOP_V3, OBJPROP_BGCOLOR, CLR_BTN_STOP);

    // Highlight active/waiting
    color highlightColor = (buttonState == BTN_STATE_WAITING) ? CLR_BTN_WAITING : CLR_BTN_ACTIVE;
    ObjectSetInteger(0, activeBtn, OBJPROP_BGCOLOR, highlightColor);

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Reset Button Highlights                                          |
//+------------------------------------------------------------------+
void ResetButtonHighlights() {
    ObjectSetInteger(0, BTN_MARKET_V3, OBJPROP_BGCOLOR, CLR_BTN_MARKET);
    ObjectSetInteger(0, BTN_LIMIT_V3, OBJPROP_BGCOLOR, CLR_BTN_LIMIT);
    ObjectSetInteger(0, BTN_STOP_V3, OBJPROP_BGCOLOR, CLR_BTN_STOP);
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
    UpdateStatusLabel("READY - Select Entry Mode");
}

//+------------------------------------------------------------------+
//| Remove Control Buttons                                           |
//+------------------------------------------------------------------+
void RemoveControlButtons() {
    ObjectDelete(0, BTN_MARKET_V3);
    ObjectDelete(0, BTN_LIMIT_V3);
    ObjectDelete(0, BTN_STOP_V3);
    ObjectDelete(0, BTN_CLOSEALL_V3);
    ObjectDelete(0, BTN_STATUS_V3);
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Deinitialize Control Buttons                                     |
//+------------------------------------------------------------------+
void DeinitializeControlButtons() {
    RemoveControlButtons();
    Print("Control Buttons: Deinitialized");
}

