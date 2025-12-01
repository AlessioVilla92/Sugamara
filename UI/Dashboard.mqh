//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                        Sugamara - Dashboard Display              |
//|                                                                  |
//|  Visual dashboard for Double Grid Neutral monitoring             |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| DASHBOARD CONSTANTS                                              |
//+------------------------------------------------------------------+
#define PANEL_WIDTH     320
#define PANEL_HEADER    25
#define LINE_HEIGHT     18
#define SECTION_MARGIN  8
#define FONT_SIZE       9
#define FONT_NAME       "Consolas"

//+------------------------------------------------------------------+
//| DASHBOARD INITIALIZATION                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Dashboard                                             |
//+------------------------------------------------------------------+
bool InitializeDashboard() {
    if(!ShowDashboard) return true;

    // Create panel background
    CreateDashboardBackground();

    // Create all labels
    CreateDashboardLabels();

    LogMessage(LOG_SUCCESS, "Dashboard initialized");
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
    ObjectSetInteger(0, name, OBJPROP_YSIZE, 400);  // Will be adjusted dynamically
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, COLOR_PANEL_BG);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, COLOR_PANEL_BORDER);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create Dashboard Labels                                          |
//+------------------------------------------------------------------+
void CreateDashboardLabels() {
    int y = Dashboard_Y + 5;
    int x = Dashboard_X + 10;

    // Header
    CreatePanelLabel("HEADER", x, y, "SUGAMARA v1.0 - DOUBLE GRID NEUTRAL", COLOR_TEXT_HEADER, 10);
    y += PANEL_HEADER;

    // System Status Section
    CreatePanelLabel("SECTION1", x, y, "═══ SYSTEM STATUS ═══", COLOR_TEXT_HIGHLIGHT, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("STATE_LBL", x, y, "State:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("STATE_VAL", x + 100, y, "---", COLOR_TEXT_HIGHLIGHT, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("SYMBOL_LBL", x, y, "Symbol:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("SYMBOL_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("SPREAD_LBL", x, y, "Spread:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("SPREAD_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT + SECTION_MARGIN;

    // ATR Section
    CreatePanelLabel("SECTION2", x, y, "═══ ATR ANALYSIS ═══", COLOR_TEXT_HIGHLIGHT, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("ATR_LBL", x, y, "ATR Value:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("ATR_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("ATR_COND_LBL", x, y, "Condition:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("ATR_COND_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("SPACING_LBL", x, y, "Spacing:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("SPACING_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT + SECTION_MARGIN;

    // Grid A Section
    CreatePanelLabel("SECTION3", x, y, "═══ GRID A (Long Bias) ═══", COLOR_GRID_A_ENTRY, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("GA_POS_LBL", x, y, "Positions:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("GA_POS_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("GA_PEND_LBL", x, y, "Pending:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("GA_PEND_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("GA_PL_LBL", x, y, "P/L:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("GA_PL_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT + SECTION_MARGIN;

    // Grid B Section
    CreatePanelLabel("SECTION4", x, y, "═══ GRID B (Short Bias) ═══", COLOR_GRID_B_ENTRY, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("GB_POS_LBL", x, y, "Positions:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("GB_POS_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("GB_PEND_LBL", x, y, "Pending:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("GB_PEND_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("GB_PL_LBL", x, y, "P/L:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("GB_PL_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT + SECTION_MARGIN;

    // Exposure Section
    CreatePanelLabel("SECTION5", x, y, "═══ EXPOSURE ═══", COLOR_TEXT_HIGHLIGHT, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("LONG_LBL", x, y, "Long Lots:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("LONG_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("SHORT_LBL", x, y, "Short Lots:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("SHORT_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("NET_LBL", x, y, "Net:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("NET_VAL", x + 100, y, "---", COLOR_NEUTRAL, FONT_SIZE);
    y += LINE_HEIGHT + SECTION_MARGIN;

    // Account Section
    CreatePanelLabel("SECTION6", x, y, "═══ ACCOUNT ═══", COLOR_TEXT_HIGHLIGHT, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("EQUITY_LBL", x, y, "Equity:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("EQUITY_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("BALANCE_LBL", x, y, "Balance:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("BALANCE_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("DD_LBL", x, y, "Drawdown:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("DD_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT + SECTION_MARGIN;

    // Session Stats Section
    CreatePanelLabel("SECTION7", x, y, "═══ SESSION STATS ═══", COLOR_TEXT_HIGHLIGHT, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("TOTAL_PL_LBL", x, y, "Total P/L:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("TOTAL_PL_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("WINRATE_LBL", x, y, "Win Rate:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("WINRATE_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT;

    CreatePanelLabel("TRADES_LBL", x, y, "Trades:", COLOR_TEXT_NORMAL, FONT_SIZE);
    CreatePanelLabel("TRADES_VAL", x + 100, y, "---", COLOR_TEXT_NORMAL, FONT_SIZE);
    y += LINE_HEIGHT + 10;

    // Adjust panel height
    int panelHeight = y - Dashboard_Y + 10;
    ObjectSetInteger(0, "SUGAMARA_PANEL_BG", OBJPROP_YSIZE, panelHeight);
}

//+------------------------------------------------------------------+
//| Create Single Panel Label                                        |
//+------------------------------------------------------------------+
void CreatePanelLabel(string id, int x, int y, string text, color clr, int fontSize) {
    string name = "SUGAMARA_LBL_" + id;

    if(ObjectFind(0, name) < 0) {
        ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    }

    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetString(0, name, OBJPROP_FONT, FONT_NAME);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_ANCHOR, ANCHOR_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| DASHBOARD UPDATE                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update All Dashboard Values                                      |
//+------------------------------------------------------------------+
void UpdateDashboard() {
    if(!ShowDashboard) return;

    UpdateSystemStatus();
    UpdateATRSection();
    UpdateGridASection();
    UpdateGridBSection();
    UpdateExposureSection();
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
    color stateColor = COLOR_TEXT_NORMAL;

    switch(systemState) {
        case STATE_IDLE:
            stateText = "IDLE";
            stateColor = COLOR_TEXT_NORMAL;
            break;
        case STATE_INITIALIZING:
            stateText = "INITIALIZING";
            stateColor = COLOR_TEXT_HIGHLIGHT;
            break;
        case STATE_ACTIVE:
            stateText = "ACTIVE";
            stateColor = COLOR_PROFIT;
            break;
        case STATE_PAUSED:
            stateText = "PAUSED";
            stateColor = COLOR_NEUTRAL;
            break;
        case STATE_CLOSING:
            stateText = "CLOSING";
            stateColor = COLOR_LOSS;
            break;
        case STATE_ERROR:
            stateText = "ERROR";
            stateColor = COLOR_LOSS;
            break;
    }

    UpdateLabel("STATE_VAL", stateText, stateColor);

    // Symbol
    UpdateLabel("SYMBOL_VAL", _Symbol, COLOR_TEXT_NORMAL);

    // Spread
    double spread = GetSpreadPips();
    color spreadColor = (spread > 3.0) ? COLOR_LOSS : COLOR_TEXT_NORMAL;
    UpdateLabel("SPREAD_VAL", DoubleToString(spread, 1) + " pips", spreadColor);
}

//+------------------------------------------------------------------+
//| Update ATR Section                                               |
//+------------------------------------------------------------------+
void UpdateATRSection() {
    // ATR Value
    double atrPips = GetATRPips();
    UpdateLabel("ATR_VAL", DoubleToString(atrPips, 1) + " pips", COLOR_TEXT_NORMAL);

    // ATR Condition
    ENUM_ATR_CONDITION condition = GetATRCondition(atrPips);
    string condText = GetATRConditionName(condition);
    color condColor = COLOR_TEXT_NORMAL;

    switch(condition) {
        case ATR_CALM:     condColor = COLOR_PROFIT; break;
        case ATR_NORMAL:   condColor = COLOR_TEXT_NORMAL; break;
        case ATR_VOLATILE: condColor = COLOR_NEUTRAL; break;
        case ATR_EXTREME:  condColor = COLOR_LOSS; break;
    }

    UpdateLabel("ATR_COND_VAL", condText, condColor);

    // Spacing
    UpdateLabel("SPACING_VAL", DoubleToString(currentSpacing_Pips, 1) + " pips", COLOR_TEXT_NORMAL);
}

//+------------------------------------------------------------------+
//| Update Grid A Section                                            |
//+------------------------------------------------------------------+
void UpdateGridASection() {
    int positions = GetGridAActivePositions();
    int pending = GetGridAPendingOrders();
    double pl = GetGridAOpenProfit();

    UpdateLabel("GA_POS_VAL", IntegerToString(positions), COLOR_TEXT_NORMAL);
    UpdateLabel("GA_PEND_VAL", IntegerToString(pending), COLOR_TEXT_NORMAL);

    color plColor = (pl >= 0) ? COLOR_PROFIT : COLOR_LOSS;
    UpdateLabel("GA_PL_VAL", FormatMoney(pl), plColor);
}

//+------------------------------------------------------------------+
//| Update Grid B Section                                            |
//+------------------------------------------------------------------+
void UpdateGridBSection() {
    int positions = GetGridBActivePositions();
    int pending = GetGridBPendingOrders();
    double pl = GetGridBOpenProfit();

    UpdateLabel("GB_POS_VAL", IntegerToString(positions), COLOR_TEXT_NORMAL);
    UpdateLabel("GB_PEND_VAL", IntegerToString(pending), COLOR_TEXT_NORMAL);

    color plColor = (pl >= 0) ? COLOR_PROFIT : COLOR_LOSS;
    UpdateLabel("GB_PL_VAL", FormatMoney(pl), plColor);
}

//+------------------------------------------------------------------+
//| Update Exposure Section                                          |
//+------------------------------------------------------------------+
void UpdateExposureSection() {
    CalculateTotalExposure();

    UpdateLabel("LONG_VAL", DoubleToString(totalLongLots, 2) + " lot", COLOR_TEXT_NORMAL);
    UpdateLabel("SHORT_VAL", DoubleToString(totalShortLots, 2) + " lot", COLOR_TEXT_NORMAL);

    // Net exposure with direction indicator
    string netText = "";
    color netColor = COLOR_NEUTRAL;

    if(netExposure > 0.001) {
        netText = "+" + DoubleToString(netExposure, 2) + " (LONG)";
        netColor = COLOR_GRID_A_ENTRY;
    } else if(netExposure < -0.001) {
        netText = DoubleToString(netExposure, 2) + " (SHORT)";
        netColor = COLOR_GRID_B_ENTRY;
    } else {
        netText = "0.00 (NEUTRAL)";
        netColor = COLOR_PROFIT;
    }

    UpdateLabel("NET_VAL", netText, netColor);
}

//+------------------------------------------------------------------+
//| Update Account Section                                           |
//+------------------------------------------------------------------+
void UpdateAccountSection() {
    double equity = GetEquity();
    double balance = GetBalance();
    double dd = GetCurrentDrawdown();

    UpdateLabel("EQUITY_VAL", FormatMoney(equity), COLOR_TEXT_NORMAL);
    UpdateLabel("BALANCE_VAL", FormatMoney(balance), COLOR_TEXT_NORMAL);

    color ddColor = COLOR_TEXT_NORMAL;
    if(dd > 5) ddColor = COLOR_NEUTRAL;
    if(dd > 10) ddColor = COLOR_LOSS;

    UpdateLabel("DD_VAL", FormatPercent(dd), ddColor);
}

//+------------------------------------------------------------------+
//| Update Session Statistics                                        |
//+------------------------------------------------------------------+
void UpdateSessionStats() {
    double totalPL = sessionRealizedProfit + GetTotalOpenProfit();
    double winRate = GetWinRate();
    int trades = sessionWins + sessionLosses;

    color plColor = (totalPL >= 0) ? COLOR_PROFIT : COLOR_LOSS;
    UpdateLabel("TOTAL_PL_VAL", FormatMoney(totalPL), plColor);

    color wrColor = (winRate >= 60) ? COLOR_PROFIT : ((winRate >= 50) ? COLOR_TEXT_NORMAL : COLOR_LOSS);
    UpdateLabel("WINRATE_VAL", FormatPercent(winRate), wrColor);

    UpdateLabel("TRADES_VAL", IntegerToString(trades) + " (" + IntegerToString(sessionWins) +
                "W/" + IntegerToString(sessionLosses) + "L)", COLOR_TEXT_NORMAL);
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
//| DASHBOARD CLEANUP                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Remove Dashboard                                                 |
//+------------------------------------------------------------------+
void RemoveDashboard() {
    DeleteObjectsByPrefix("SUGAMARA_LBL_");
    DeleteObjectsByPrefix("SUGAMARA_PANEL_");

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| GRID VISUALIZATION                                               |
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

    // Draw Grid A lines
    DrawGridALines();

    // Draw Grid B lines
    DrawGridBLines();

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Draw Grid A Lines                                                |
//+------------------------------------------------------------------+
void DrawGridALines() {
    // Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_EntryPrices[i] > 0) {
            CreateGridLevelLine(GRID_A, ZONE_UPPER, i, gridA_Upper_EntryPrices[i]);
        }
    }

    // Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Lower_EntryPrices[i] > 0) {
            CreateGridLevelLine(GRID_A, ZONE_LOWER, i, gridA_Lower_EntryPrices[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Grid B Lines                                                |
//+------------------------------------------------------------------+
void DrawGridBLines() {
    // Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_EntryPrices[i] > 0) {
            CreateGridLevelLine(GRID_B, ZONE_UPPER, i, gridB_Upper_EntryPrices[i]);
        }
    }

    // Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Lower_EntryPrices[i] > 0) {
            CreateGridLevelLine(GRID_B, ZONE_LOWER, i, gridB_Lower_EntryPrices[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Remove All Grid Visualization                                    |
//+------------------------------------------------------------------+
void RemoveGridVisualization() {
    DeleteAllGridObjects();
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| DASHBOARD FULL CLEANUP                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Clean Up All UI Elements                                         |
//+------------------------------------------------------------------+
void CleanupUI() {
    RemoveDashboard();
    RemoveGridVisualization();
}

