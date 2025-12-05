//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                        Sugamara v2.0 - Dashboard Display         |
//|                                                                  |
//|  Visual dashboard for Double Grid Neutral MULTIMODE              |
//|  Color Scheme: AZURE GRADIENT                                    |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| AZURE GRADIENT COLOR SCHEME                                      |
//+------------------------------------------------------------------+
// Background Colors (Dark to Light Azure)
#define CLR_BG_DARK       C'8,20,35'        // Panel background (dark navy)
#define CLR_BG_MEDIUM     C'12,30,50'       // Section background
#define CLR_BG_LIGHT      C'18,42,68'       // Highlight background
#define CLR_BORDER        C'40,80,120'      // Border color

// Text Colors (Azure Gradient)
#define CLR_AZURE_1       C'100,180,255'    // Lightest azure (titles)
#define CLR_AZURE_2       C'70,150,220'     // Medium azure (sections)
#define CLR_AZURE_3       C'50,120,190'     // Darker azure (labels)
#define CLR_AZURE_4       C'30,90,160'      // Darkest azure (inactive)

// Accent Colors
#define CLR_CYAN          C'0,220,255'      // Highlight cyan
#define CLR_TEAL          C'0,180,180'      // Teal accent
#define CLR_WHITE         clrWhite          // White text
#define CLR_SILVER        C'180,190,200'    // Normal text

// Status Colors
#define CLR_PROFIT        C'0,220,100'      // Green profit
#define CLR_LOSS          C'255,80,80'      // Red loss
#define CLR_NEUTRAL       C'255,200,50'     // Yellow neutral/warning
#define CLR_ACTIVE        C'0,255,180'      // Active system

// Grid Colors (Azure Variants)
#define CLR_GRID_A        C'60,160,255'     // Grid A - Light Blue
#define CLR_GRID_B        C'100,200,255'    // Grid B - Cyan Blue

// Mode Colors
#define CLR_MODE_PURE     C'150,150,255'    // Purple-ish for PURE
#define CLR_MODE_CASCADE  C'80,180,255'     // Azure for CASCADE
#define CLR_MODE_RANGEBOX C'0,200,200'      // Teal for RANGEBOX

//+------------------------------------------------------------------+
//| DASHBOARD CONSTANTS                                              |
//+------------------------------------------------------------------+
#define PANEL_WIDTH       340
#define PANEL_HEADER      28
#define LINE_HEIGHT       18
#define SECTION_MARGIN    10
#define FONT_SIZE         9
#define FONT_NAME         "Consolas"
#define FONT_TITLE        "Segoe UI Semibold"

//+------------------------------------------------------------------+
//| Global Button Position Variables                                 |
//+------------------------------------------------------------------+
int g_btnY = 0;       // Button panel Y position (set in CreateDashboardSections)
int g_leftX = 10;     // Left column X position

//+------------------------------------------------------------------+
//| Handle Button Click Events                                       |
//+------------------------------------------------------------------+
void HandleButtonClick(string clickedObject) {
    // Reset button state
    ObjectSetInteger(0, clickedObject, OBJPROP_STATE, false);
    ChartRedraw(0);

    //==============================================================
    // START GRID - Avvia il sistema grid
    //==============================================================
    if(clickedObject == "BTN_START_GRID") {
        if(systemState == STATE_ACTIVE) {
            Print("WARNING: System already active - click ignored");
            if(EnableAlerts) Alert("WARNING: System already active!");
            return;
        }

        Print("INFO: START GRID requested");
        systemState = STATE_ACTIVE;

        // Initialize both grids
        if(!InitializeGridA()) {
            Print("ERROR: Failed to start Grid A");
            systemState = STATE_ERROR;
            return;
        }
        if(!InitializeGridB()) {
            Print("ERROR: Failed to start Grid B");
            systemState = STATE_ERROR;
            return;
        }

        Print("SUCCESS: Grid system started");
        if(EnableAlerts) Alert("Sugamara: Grid system STARTED");
        return;
    }

    //==============================================================
    // PAUSE/RESUME - Metti in pausa o riprendi
    //==============================================================
    if(clickedObject == "BTN_PAUSE") {
        if(systemState == STATE_PAUSED) {
            // Resume
            systemState = STATE_ACTIVE;
            Print("INFO: System RESUMED");
            if(EnableAlerts) Alert("Sugamara: System RESUMED");
            UpdatePauseButton();
        } else if(systemState == STATE_ACTIVE) {
            // Pause
            systemState = STATE_PAUSED;
            Print("INFO: System PAUSED");
            if(EnableAlerts) Alert("Sugamara: System PAUSED");
            UpdatePauseButton();
        }
        return;
    }

    //==============================================================
    // CLOSE GRID A - Chiudi solo Grid A
    //==============================================================
    if(clickedObject == "BTN_CLOSE_GRID_A") {
        Print("INFO: CLOSE GRID A requested");
        CloseAllGridAOrders();
        if(EnableAlerts) Alert("Sugamara: Grid A CLOSED");
        return;
    }

    //==============================================================
    // CLOSE GRID B - Chiudi solo Grid B
    //==============================================================
    if(clickedObject == "BTN_CLOSE_GRID_B") {
        Print("INFO: CLOSE GRID B requested");
        CloseAllGridBOrders();
        if(EnableAlerts) Alert("Sugamara: Grid B CLOSED");
        return;
    }

    //==============================================================
    // CLOSE ALL - Chiudi tutto
    //==============================================================
    if(clickedObject == "BTN_CLOSE_ALL") {
        Print("WARNING: CLOSE ALL requested");
        CloseAllSugamaraOrders();
        systemState = STATE_IDLE;
        if(EnableAlerts) Alert("Sugamara: ALL POSITIONS CLOSED");
        return;
    }

    //==============================================================
    // EMERGENCY - Chiusura di emergenza
    //==============================================================
    if(clickedObject == "BTN_EMERGENCY") {
        Print("!!! EMERGENCY CLOSE requested !!!");
        EmergencyCloseAll();
        systemState = STATE_IDLE;
        if(EnableAlerts) Alert("Sugamara: EMERGENCY CLOSE EXECUTED!");
        return;
    }
}

//+------------------------------------------------------------------+
//| Update Pause Button Text                                         |
//+------------------------------------------------------------------+
void UpdatePauseButton() {
    string btnText = (systemState == STATE_PAUSED) ? "▶ RESUME" : "⏸ PAUSE";
    color btnColor = (systemState == STATE_PAUSED) ? CLR_PROFIT : CLR_NEUTRAL;

    ObjectSetString(0, "BTN_PAUSE", OBJPROP_TEXT, btnText);
    ObjectSetInteger(0, "BTN_PAUSE", OBJPROP_BGCOLOR, btnColor);
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Initialize Dashboard                                             |
//+------------------------------------------------------------------+
bool InitializeDashboard() {
    if(!ShowDashboard) return true;

    // Create panel background
    CreateDashboardBackground();

    // Create all sections
    CreateDashboardSections();

    LogMessage(LOG_SUCCESS, "Dashboard v2.0 initialized with Azure theme");
    return true;
}

//+------------------------------------------------------------------+
//| Create Dashboard Background                                      |
//+------------------------------------------------------------------+
void CreateDashboardBackground() {
    string name = "SUGAMARA_PANEL_BG";

    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    }

    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, Dashboard_X);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, Dashboard_Y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, PANEL_WIDTH);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, 550);  // Will be adjusted
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, CLR_BG_DARK);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, CLR_BORDER);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create All Dashboard Sections                                    |
//+------------------------------------------------------------------+
void CreateDashboardSections() {
    int y = Dashboard_Y + 8;
    int x = Dashboard_X + 12;
    int xVal = Dashboard_X + 140;

    //═══════════════════════════════════════════════════════════════
    // HEADER - Title with Mode
    //═══════════════════════════════════════════════════════════════
    CreatePanelLabel("HEADER", x, y, "SUGAMARA v2.0", CLR_AZURE_1, 14, FONT_TITLE);
    y += 22;
    CreatePanelLabel("MODE_BADGE", x, y, "[" + GetModeName() + "]", GetModeColor(), 11, FONT_TITLE);
    y += PANEL_HEADER;

    //═══════════════════════════════════════════════════════════════
    // SECTION 1: System Status
    //═══════════════════════════════════════════════════════════════
    CreateSectionHeader(x, y, "SYSTEM STATUS", CLR_AZURE_2);
    y += LINE_HEIGHT + 2;

    CreatePanelLabel("STATE_LBL", x, y, "State:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("STATE_VAL", xVal, y, "---", CLR_ACTIVE, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("SYMBOL_LBL", x, y, "Symbol:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("SYMBOL_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("SPREAD_LBL", x, y, "Spread:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("SPREAD_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT + SECTION_MARGIN;

    //═══════════════════════════════════════════════════════════════
    // SECTION 2: Mode & ATR (conditional)
    //═══════════════════════════════════════════════════════════════
    CreateSectionHeader(x, y, "MODE & SPACING", CLR_AZURE_2);
    y += LINE_HEIGHT + 2;

    CreatePanelLabel("MODETYPE_LBL", x, y, "Mode:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("MODETYPE_VAL", xVal, y, "---", GetModeColor(), FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("ATR_STATUS_LBL", x, y, "ATR:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("ATR_STATUS_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("ATR_VAL_LBL", x, y, "ATR Value:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("ATR_VAL_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("SPACING_LBL", x, y, "Spacing:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("SPACING_VAL", xVal, y, "---", CLR_CYAN, FONT_SIZE);
    y += LINE_HEIGHT + SECTION_MARGIN;

    //═══════════════════════════════════════════════════════════════
    // SECTION 3: Grid A (Long Bias)
    //═══════════════════════════════════════════════════════════════
    CreateSectionHeader(x, y, "GRID A (Long Bias)", CLR_GRID_A);
    y += LINE_HEIGHT + 2;

    CreatePanelLabel("GA_POS_LBL", x, y, "Positions:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("GA_POS_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("GA_PEND_LBL", x, y, "Pending:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("GA_PEND_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("GA_PL_LBL", x, y, "P/L:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("GA_PL_VAL", xVal, y, "---", CLR_PROFIT, FONT_SIZE);
    y += LINE_HEIGHT + SECTION_MARGIN;

    //═══════════════════════════════════════════════════════════════
    // SECTION 4: Grid B (Short Bias)
    //═══════════════════════════════════════════════════════════════
    CreateSectionHeader(x, y, "GRID B (Short Bias)", CLR_GRID_B);
    y += LINE_HEIGHT + 2;

    CreatePanelLabel("GB_POS_LBL", x, y, "Positions:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("GB_POS_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("GB_PEND_LBL", x, y, "Pending:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("GB_PEND_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("GB_PL_LBL", x, y, "P/L:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("GB_PL_VAL", xVal, y, "---", CLR_PROFIT, FONT_SIZE);
    y += LINE_HEIGHT + SECTION_MARGIN;

    //═══════════════════════════════════════════════════════════════
    // SECTION 5: Net Exposure
    //═══════════════════════════════════════════════════════════════
    CreateSectionHeader(x, y, "NET EXPOSURE", CLR_AZURE_2);
    y += LINE_HEIGHT + 2;

    CreatePanelLabel("LONG_LBL", x, y, "Long Lots:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("LONG_VAL", xVal, y, "---", CLR_GRID_A, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("SHORT_LBL", x, y, "Short Lots:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("SHORT_VAL", xVal, y, "---", CLR_GRID_B, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("NET_LBL", x, y, "Net:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("NET_VAL", xVal, y, "---", CLR_NEUTRAL, FONT_SIZE);
    y += LINE_HEIGHT + SECTION_MARGIN;

    //═══════════════════════════════════════════════════════════════
    // SECTION 6: RangeBox (only if RANGEBOX mode)
    //═══════════════════════════════════════════════════════════════
    if(IsRangeBoxAvailable()) {
        CreateSectionHeader(x, y, "RANGEBOX", CLR_MODE_RANGEBOX);
        y += LINE_HEIGHT + 2;

        CreatePanelLabel("RB_RES_LBL", x, y, "Resistance:", CLR_SILVER, FONT_SIZE);
        CreatePanelLabel("RB_RES_VAL", xVal, y, "---", CLR_LOSS, FONT_SIZE);
        y += LINE_HEIGHT;

        CreatePanelLabel("RB_SUP_LBL", x, y, "Support:", CLR_SILVER, FONT_SIZE);
        CreatePanelLabel("RB_SUP_VAL", xVal, y, "---", CLR_PROFIT, FONT_SIZE);
        y += LINE_HEIGHT;

        CreatePanelLabel("RB_STATUS_LBL", x, y, "Status:", CLR_SILVER, FONT_SIZE);
        CreatePanelLabel("RB_STATUS_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
        y += LINE_HEIGHT;

        if(IsHedgingAvailable()) {
            CreatePanelLabel("HEDGE_LBL", x, y, "Hedge:", CLR_SILVER, FONT_SIZE);
            CreatePanelLabel("HEDGE_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
            y += LINE_HEIGHT;
        }

        y += SECTION_MARGIN;
    }

    //═══════════════════════════════════════════════════════════════
    // SECTION 7: Account
    //═══════════════════════════════════════════════════════════════
    CreateSectionHeader(x, y, "ACCOUNT", CLR_AZURE_2);
    y += LINE_HEIGHT + 2;

    CreatePanelLabel("EQUITY_LBL", x, y, "Equity:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("EQUITY_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("BALANCE_LBL", x, y, "Balance:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("BALANCE_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("DD_LBL", x, y, "Drawdown:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("DD_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT + SECTION_MARGIN;

    //═══════════════════════════════════════════════════════════════
    // SECTION 8: Session Stats
    //═══════════════════════════════════════════════════════════════
    CreateSectionHeader(x, y, "SESSION STATS", CLR_AZURE_2);
    y += LINE_HEIGHT + 2;

    CreatePanelLabel("TOTAL_PL_LBL", x, y, "Total P/L:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("TOTAL_PL_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("WINRATE_LBL", x, y, "Win Rate:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("WINRATE_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("TRADES_LBL", x, y, "Trades:", CLR_SILVER, FONT_SIZE);
    CreatePanelLabel("TRADES_VAL", xVal, y, "---", CLR_WHITE, FONT_SIZE);
    y += LINE_HEIGHT + 15;

    //═══════════════════════════════════════════════════════════════
    // SECTION 9: Control Buttons
    //═══════════════════════════════════════════════════════════════
    CreateControlButtons(x, y);
    y += 130;  // Space for buttons

    // Adjust panel height
    int panelHeight = y - Dashboard_Y + 10;
    ObjectSetInteger(0, "SUGAMARA_PANEL_BG", OBJPROP_YSIZE, panelHeight);
}

//+------------------------------------------------------------------+
//| Create Control Buttons Section                                   |
//+------------------------------------------------------------------+
void CreateControlButtons(int startX, int startY) {
    int x = startX;
    int y = startY;
    int btnWidth = 100;
    int btnHeight = 28;
    int spacing = 5;

    // Row 1: START / PAUSE
    CreateSectionHeader(x, y, "CONTROLS", CLR_AZURE_2);
    y += LINE_HEIGHT + 5;

    CreateButton("BTN_START_GRID", x, y, btnWidth, btnHeight, "▶ START", C'0,150,80');
    CreateButton("BTN_PAUSE", x + btnWidth + spacing, y, btnWidth, btnHeight, "⏸ PAUSE", CLR_NEUTRAL);

    y += btnHeight + 8;

    // Row 2: CLOSE GRID A / CLOSE GRID B
    CreatePanelLabel("LBL_CLOSE_GRIDS", x + 50, y, "Close Individual Grids", CLR_AZURE_3, 8);
    y += 14;

    CreateButton("BTN_CLOSE_GRID_A", x, y, btnWidth, btnHeight, "CLOSE A", CLR_GRID_A);
    CreateButton("BTN_CLOSE_GRID_B", x + btnWidth + spacing, y, btnWidth, btnHeight, "CLOSE B", CLR_GRID_B);

    y += btnHeight + 8;

    // Row 3: CLOSE ALL (full width)
    int closeAllWidth = btnWidth * 2 + spacing;
    CreateButton("BTN_CLOSE_ALL", x, y, closeAllWidth, btnHeight + 2,
                "CLOSE ALL POSITIONS", C'180,50,50');

    y += btnHeight + 10;

    // Row 4: EMERGENCY (full width, red)
    CreateButton("BTN_EMERGENCY", x, y, closeAllWidth, btnHeight,
                "⚠ EMERGENCY CLOSE", C'200,0,0');

    // Store button Y for reference
    g_btnY = startY;
}

//+------------------------------------------------------------------+
//| Create Button Object                                             |
//+------------------------------------------------------------------+
void CreateButton(string name, int x, int y, int width, int height, string text, color clr) {
    ObjectDelete(0, name);  // Delete first to ensure visual priority
    ObjectCreate(0, name, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, clrBlack);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, 9);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 10000);  // Front layer
}

//+------------------------------------------------------------------+
//| Create Section Header with underline                             |
//+------------------------------------------------------------------+
void CreateSectionHeader(int x, int y, string text, color clr) {
    string id = "SEC_" + text;
    CreatePanelLabel(id, x, y, "─── " + text + " ───", clr, FONT_SIZE, FONT_NAME);
}

//+------------------------------------------------------------------+
//| Get Color for Current Mode                                       |
//+------------------------------------------------------------------+
color GetModeColor() {
    switch(NeutralMode) {
        case NEUTRAL_PURE:     return CLR_MODE_PURE;
        case NEUTRAL_CASCADE:  return CLR_MODE_CASCADE;
        case NEUTRAL_RANGEBOX: return CLR_MODE_RANGEBOX;
    }
    return CLR_WHITE;
}

//+------------------------------------------------------------------+
//| Create Single Panel Label                                        |
//+------------------------------------------------------------------+
void CreatePanelLabel(string id, int x, int y, string text, color clr, int fontSize, string fontName = FONT_NAME) {
    string name = "SUGAMARA_LBL_" + id;

    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    }

    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetString(0, name, OBJPROP_FONT, fontName);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Update All Dashboard Values                                      |
//+------------------------------------------------------------------+
void UpdateDashboard() {
    if(!ShowDashboard) return;

    UpdateSystemStatus();
    UpdateModeSection();
    UpdateGridASection();
    UpdateGridBSection();
    UpdateExposureSection();

    if(IsRangeBoxAvailable())
        UpdateRangeBoxSection();

    UpdateAccountSection();
    UpdateSessionStats();

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Update System Status Section                                     |
//+------------------------------------------------------------------+
void UpdateSystemStatus() {
    // State
    string stateText = "";
    color stateColor = CLR_WHITE;

    switch(systemState) {
        case STATE_IDLE:
            stateText = "IDLE";
            stateColor = CLR_AZURE_4;
            break;
        case STATE_INITIALIZING:
            stateText = "INITIALIZING";
            stateColor = CLR_CYAN;
            break;
        case STATE_ACTIVE:
            stateText = "ACTIVE";
            stateColor = CLR_ACTIVE;
            break;
        case STATE_PAUSED:
            stateText = "PAUSED";
            stateColor = CLR_NEUTRAL;
            break;
        case STATE_CLOSING:
            stateText = "CLOSING";
            stateColor = CLR_LOSS;
            break;
        case STATE_ERROR:
            stateText = "ERROR";
            stateColor = CLR_LOSS;
            break;
    }

    UpdateLabel("STATE_VAL", stateText, stateColor);
    UpdateLabel("SYMBOL_VAL", _Symbol, CLR_WHITE);

    // Spread
    double spread = GetSpreadPips();
    color spreadColor = (spread > 3.0) ? CLR_LOSS : ((spread > 2.0) ? CLR_NEUTRAL : CLR_PROFIT);
    UpdateLabel("SPREAD_VAL", DoubleToString(spread, 1) + " pips", spreadColor);
}

//+------------------------------------------------------------------+
//| Update Mode Section                                              |
//+------------------------------------------------------------------+
void UpdateModeSection() {
    // Mode Type
    string modeText = "";
    switch(NeutralMode) {
        case NEUTRAL_PURE:     modeText = "PURE (Fixed)"; break;
        case NEUTRAL_CASCADE:  modeText = "CASCADE"; break;
        case NEUTRAL_RANGEBOX: modeText = "RANGEBOX"; break;
    }
    UpdateLabel("MODETYPE_VAL", modeText, GetModeColor());

    // ATR Status
    string atrText = "";
    color atrColor = CLR_WHITE;

    if(!IsATRAvailable()) {
        atrText = "N/A (PURE mode)";
        atrColor = CLR_AZURE_4;
    } else if(IsATREnabled()) {
        atrText = "ENABLED";
        atrColor = CLR_ACTIVE;
    } else {
        atrText = "DISABLED";
        atrColor = CLR_NEUTRAL;
    }
    UpdateLabel("ATR_STATUS_VAL", atrText, atrColor);

    // ATR Value
    if(IsATREnabled()) {
        double atrPips = GetATRPips();
        UpdateLabel("ATR_VAL_VAL", DoubleToString(atrPips, 1) + " pips", CLR_WHITE);
    } else {
        UpdateLabel("ATR_VAL_VAL", "---", CLR_AZURE_4);
    }

    // Spacing
    UpdateLabel("SPACING_VAL", DoubleToString(currentSpacing_Pips, 1) + " pips", CLR_CYAN);
}

//+------------------------------------------------------------------+
//| Update Grid A Section                                            |
//+------------------------------------------------------------------+
void UpdateGridASection() {
    int positions = GetGridAActivePositions();
    int pending = GetGridAPendingOrders();
    double pl = GetGridAOpenProfit();

    UpdateLabel("GA_POS_VAL", IntegerToString(positions), CLR_WHITE);
    UpdateLabel("GA_PEND_VAL", IntegerToString(pending), CLR_WHITE);

    color plColor = (pl >= 0) ? CLR_PROFIT : CLR_LOSS;
    UpdateLabel("GA_PL_VAL", FormatMoney(pl), plColor);
}

//+------------------------------------------------------------------+
//| Update Grid B Section                                            |
//+------------------------------------------------------------------+
void UpdateGridBSection() {
    int positions = GetGridBActivePositions();
    int pending = GetGridBPendingOrders();
    double pl = GetGridBOpenProfit();

    UpdateLabel("GB_POS_VAL", IntegerToString(positions), CLR_WHITE);
    UpdateLabel("GB_PEND_VAL", IntegerToString(pending), CLR_WHITE);

    color plColor = (pl >= 0) ? CLR_PROFIT : CLR_LOSS;
    UpdateLabel("GB_PL_VAL", FormatMoney(pl), plColor);
}

//+------------------------------------------------------------------+
//| Update Exposure Section                                          |
//+------------------------------------------------------------------+
void UpdateExposureSection() {
    CalculateTotalExposure();

    UpdateLabel("LONG_VAL", DoubleToString(totalLongLots, 2) + " lot", CLR_GRID_A);
    UpdateLabel("SHORT_VAL", DoubleToString(totalShortLots, 2) + " lot", CLR_GRID_B);

    // Net exposure with direction indicator
    string netText = "";
    color netColor = CLR_NEUTRAL;

    if(netExposure > 0.001) {
        netText = "+" + DoubleToString(netExposure, 2) + " (LONG bias)";
        netColor = CLR_GRID_A;
    } else if(netExposure < -0.001) {
        netText = DoubleToString(netExposure, 2) + " (SHORT bias)";
        netColor = CLR_GRID_B;
    } else {
        netText = "0.00 (NEUTRAL)";
        netColor = CLR_ACTIVE;
    }

    UpdateLabel("NET_VAL", netText, netColor);
}

//+------------------------------------------------------------------+
//| Update RangeBox Section (only for RANGEBOX mode)                 |
//+------------------------------------------------------------------+
void UpdateRangeBoxSection() {
    if(!IsRangeBoxAvailable()) return;

    // Resistance
    UpdateLabel("RB_RES_VAL", DoubleToString(rangeBox_Resistance, symbolDigits), CLR_LOSS);

    // Support
    UpdateLabel("RB_SUP_VAL", DoubleToString(rangeBox_Support, symbolDigits), CLR_PROFIT);

    // Status
    string statusText = "";
    color statusColor = CLR_WHITE;

    if(isBreakoutUp) {
        statusText = "BREAKOUT UP!";
        statusColor = CLR_LOSS;
    } else if(isBreakoutDown) {
        statusText = "BREAKOUT DOWN!";
        statusColor = CLR_LOSS;
    } else if(isInsideRange) {
        statusText = "Inside Range";
        statusColor = CLR_ACTIVE;
    } else {
        statusText = "Unknown";
        statusColor = CLR_NEUTRAL;
    }
    UpdateLabel("RB_STATUS_VAL", statusText, statusColor);

    // Hedge status (if available)
    if(IsHedgingAvailable()) {
        string hedgeText = "";
        color hedgeColor = CLR_WHITE;

        switch(currentHedgeDirection) {
            case HEDGE_NONE:
                hedgeText = "No Hedge";
                hedgeColor = CLR_AZURE_4;
                break;
            case HEDGE_LONG:
                hedgeText = "LONG Active";
                hedgeColor = CLR_GRID_A;
                break;
            case HEDGE_SHORT:
                hedgeText = "SHORT Active";
                hedgeColor = CLR_GRID_B;
                break;
        }
        UpdateLabel("HEDGE_VAL", hedgeText, hedgeColor);
    }
}

//+------------------------------------------------------------------+
//| Update Account Section                                           |
//+------------------------------------------------------------------+
void UpdateAccountSection() {
    double equity = GetEquity();
    double balance = GetBalance();
    double dd = GetCurrentDrawdown();

    UpdateLabel("EQUITY_VAL", FormatMoney(equity), CLR_WHITE);
    UpdateLabel("BALANCE_VAL", FormatMoney(balance), CLR_WHITE);

    color ddColor = CLR_PROFIT;
    if(dd > 5) ddColor = CLR_NEUTRAL;
    if(dd > 10) ddColor = CLR_LOSS;

    UpdateLabel("DD_VAL", FormatPercent(dd), ddColor);
}

//+------------------------------------------------------------------+
//| Update Session Statistics                                        |
//+------------------------------------------------------------------+
void UpdateSessionStats() {
    double totalPL = sessionRealizedProfit + GetTotalOpenProfit();
    double winRate = GetWinRate();
    int trades = sessionWins + sessionLosses;

    color plColor = (totalPL >= 0) ? CLR_PROFIT : CLR_LOSS;
    UpdateLabel("TOTAL_PL_VAL", FormatMoney(totalPL), plColor);

    color wrColor = (winRate >= 70) ? CLR_PROFIT : ((winRate >= 55) ? CLR_WHITE : CLR_LOSS);
    UpdateLabel("WINRATE_VAL", FormatPercent(winRate), wrColor);

    UpdateLabel("TRADES_VAL", IntegerToString(trades) + " (" + IntegerToString(sessionWins) +
                "W/" + IntegerToString(sessionLosses) + "L)", CLR_WHITE);
}

//+------------------------------------------------------------------+
//| Update Single Label Value                                        |
//+------------------------------------------------------------------+
void UpdateLabel(string id, string text, color clr) {
    string name = "SUGAMARA_LBL_" + id;
    if(ObjectFind(0, name) >= 0) {
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    }
}

//+------------------------------------------------------------------+
//| Remove Dashboard                                                 |
//+------------------------------------------------------------------+
void RemoveDashboard() {
    DeleteObjectsByPrefix("SUGAMARA_LBL_");
    DeleteObjectsByPrefix("SUGAMARA_PANEL_");
    DeleteObjectsByPrefix("BTN_");  // Remove all buttons
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| NOTE: DeleteObjectsByPrefix is defined in Utils/Helpers.mqh      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw All Grid Lines                                              |
//+------------------------------------------------------------------+
void DrawGridVisualization() {
    if(!ShowGridLines) return;

    // Draw entry point
    DrawEntryPointLine();

    // Draw range boundaries
    DrawRangeBoundaries();

    // Draw Grid A lines (Azure gradient)
    DrawGridALines();

    // Draw Grid B lines (Cyan gradient)
    DrawGridBLines();

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Draw Entry Point Line                                            |
//+------------------------------------------------------------------+
void DrawEntryPointLine() {
    string name = "SUGAMARA_ENTRY_LINE";

    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, entryPoint);
    }

    ObjectSetDouble(0, name, OBJPROP_PRICE, entryPoint);
    ObjectSetInteger(0, name, OBJPROP_COLOR, CLR_CYAN);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
    ObjectSetString(0, name, OBJPROP_TEXT, "Entry Point");
}

//+------------------------------------------------------------------+
//| Draw Range Boundaries                                            |
//+------------------------------------------------------------------+
void DrawRangeBoundaries() {
    // Upper Boundary
    string nameUpper = "SUGAMARA_RANGE_UPPER";
    if(ObjectFind(0, nameUpper) < 0) {
        ObjectCreate(0, nameUpper, OBJ_HLINE, 0, 0, rangeUpperBound);
    }
    ObjectSetDouble(0, nameUpper, OBJPROP_PRICE, rangeUpperBound);
    ObjectSetInteger(0, nameUpper, OBJPROP_COLOR, CLR_AZURE_3);
    ObjectSetInteger(0, nameUpper, OBJPROP_STYLE, STYLE_DASHDOT);
    ObjectSetInteger(0, nameUpper, OBJPROP_WIDTH, 1);

    // Lower Boundary
    string nameLower = "SUGAMARA_RANGE_LOWER";
    if(ObjectFind(0, nameLower) < 0) {
        ObjectCreate(0, nameLower, OBJ_HLINE, 0, 0, rangeLowerBound);
    }
    ObjectSetDouble(0, nameLower, OBJPROP_PRICE, rangeLowerBound);
    ObjectSetInteger(0, nameLower, OBJPROP_COLOR, CLR_AZURE_3);
    ObjectSetInteger(0, nameLower, OBJPROP_STYLE, STYLE_DASHDOT);
    ObjectSetInteger(0, nameLower, OBJPROP_WIDTH, 1);
}

//+------------------------------------------------------------------+
//| Draw Grid A Lines (Azure gradient - lighter = closer to entry)   |
//+------------------------------------------------------------------+
void DrawGridALines() {
    // Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_EntryPrices[i] > 0) {
            color lineColor = GetGradientColor(CLR_GRID_A, i, GridLevelsPerSide);
            CreateGridLevelLine(GRID_A, ZONE_UPPER, i, gridA_Upper_EntryPrices[i], lineColor);
        }
    }

    // Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Lower_EntryPrices[i] > 0) {
            color lineColor = GetGradientColor(CLR_GRID_A, i, GridLevelsPerSide);
            CreateGridLevelLine(GRID_A, ZONE_LOWER, i, gridA_Lower_EntryPrices[i], lineColor);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Grid B Lines (Cyan gradient)                                |
//+------------------------------------------------------------------+
void DrawGridBLines() {
    // Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_EntryPrices[i] > 0) {
            color lineColor = GetGradientColor(CLR_GRID_B, i, GridLevelsPerSide);
            CreateGridLevelLine(GRID_B, ZONE_UPPER, i, gridB_Upper_EntryPrices[i], lineColor);
        }
    }

    // Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Lower_EntryPrices[i] > 0) {
            color lineColor = GetGradientColor(CLR_GRID_B, i, GridLevelsPerSide);
            CreateGridLevelLine(GRID_B, ZONE_LOWER, i, gridB_Lower_EntryPrices[i], lineColor);
        }
    }
}

//+------------------------------------------------------------------+
//| Get Gradient Color (lighter for closer levels)                   |
//+------------------------------------------------------------------+
color GetGradientColor(color baseColor, int level, int maxLevels) {
    // Extract RGB components
    int r = (baseColor >> 16) & 0xFF;
    int g = (baseColor >> 8) & 0xFF;
    int b = baseColor & 0xFF;

    // Darken progressively for further levels
    double factor = 1.0 - (level * 0.08);  // 8% darker per level
    if(factor < 0.5) factor = 0.5;

    r = (int)(r * factor);
    g = (int)(g * factor);
    b = (int)(b * factor);

    return (color)((r << 16) | (g << 8) | b);
}

//+------------------------------------------------------------------+
//| Create Grid Level Line                                           |
//+------------------------------------------------------------------+
void CreateGridLevelLine(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, double price, color lineColor) {
    string zoneName = (zone == ZONE_UPPER) ? "U" : "L";
    string sideName = (side == GRID_A) ? "A" : "B";
    string name = "SUGAMARA_GRID_" + sideName + "_" + zoneName + "_" + IntegerToString(level);

    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
    }

    ObjectSetDouble(0, name, OBJPROP_PRICE, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, lineColor);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_DOT);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, 1);
    ObjectSetString(0, name, OBJPROP_TEXT, sideName + zoneName + IntegerToString(level + 1));
}

//+------------------------------------------------------------------+
//| Delete All Grid Objects                                          |
//+------------------------------------------------------------------+
void DeleteAllGridObjects() {
    DeleteObjectsByPrefix("SUGAMARA_GRID_");
    DeleteObjectsByPrefix("SUGAMARA_ENTRY_");
    DeleteObjectsByPrefix("SUGAMARA_RANGE_");
}

//+------------------------------------------------------------------+
//| Remove All Grid Visualization                                    |
//+------------------------------------------------------------------+
void RemoveGridVisualization() {
    DeleteAllGridObjects();
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Clean Up All UI Elements                                         |
//+------------------------------------------------------------------+
void CleanupUI() {
    RemoveDashboard();
    RemoveGridVisualization();
}

//+------------------------------------------------------------------+
//| Calculate Total Exposure (helper)                                |
//+------------------------------------------------------------------+
void CalculateTotalExposure() {
    CalculateNetExposure();  // Uses function from GlobalVariables.mqh
}

//+------------------------------------------------------------------+
//| NOTE: GetSpreadPips is defined in Utils/Helpers.mqh              |
//+------------------------------------------------------------------+
