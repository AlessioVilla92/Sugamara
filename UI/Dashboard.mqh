//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                        Sugamara v3.0 - Dashboard Display         |
//|                                                                  |
//|  Visual dashboard for Double Grid Neutral MULTIMODE              |
//|  Color Scheme: AMARANTH/AZURE GRADIENT - 2 COLUMN LAYOUT         |
//|                                                                  |
//|  v3.0: ROBUST PERSISTENCE - Dashboard auto-recreates on restart  |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| DASHBOARD PERSISTENCE SYSTEM                                     |
//| Auto-verifies and recreates dashboard objects on restart         |
//+------------------------------------------------------------------+
bool g_dashboardInitialized = false;
datetime g_lastDashboardCheck = 0;
const int DASHBOARD_CHECK_INTERVAL = 5;  // Seconds between checks

//+------------------------------------------------------------------+
//| AMARANTH/AZURE COLOR SCHEME v3.0                                 |
//| Sfondo: Amaranto Scuro | Dashboard: Blu Turchese                 |
//+------------------------------------------------------------------+
// NOTE: Non usare #define con variabili input (evaluate at compile-time!)
// Usare direttamente Theme_ChartBackground, Theme_DashboardBG, etc. nel codice

// Background Colors (Dark Amaranth) - Literal fallbacks
#define CLR_BG_DARK       C'45,20,35'        // Panel background (amaranto scuro)
#define CLR_BG_MEDIUM     C'50,12,30'        // Section background
#define CLR_BG_LIGHT      C'68,18,42'        // Highlight background
#define CLR_BORDER        C'120,40,80'       // Border color

// Dashboard Colors (Blu Turchese) - Literal fallbacks
#define CLR_DASH_BG       C'20,60,80'        // Dashboard background (blu turchese)
#define CLR_DASH_TEXT     clrCyan            // Dashboard text (azzurro)
#define CLR_DASH_ACCENT   clrAqua            // Dashboard accent

// Getter functions to use actual input values at runtime
color GetThemeChartBackground() { return Theme_ChartBackground; }
color GetThemeDashboardBG() { return Theme_DashboardBG; }
color GetThemeDashboardText() { return Theme_DashboardText; }
color GetThemeDashboardAccent() { return Theme_DashboardAccent; }

// Text Colors (Azure Gradient)
#define CLR_AZURE_1       C'100,180,255'     // Lightest azure (titles)
#define CLR_AZURE_2       C'70,150,220'      // Medium azure (sections)
#define CLR_AZURE_3       C'50,120,190'      // Darker azure (labels)
#define CLR_AZURE_4       C'30,90,160'       // Darkest azure (inactive)

// Accent Colors
#define CLR_CYAN          clrCyan            // Highlight cyan
#define CLR_TEAL          C'0,180,180'       // Teal accent
#define CLR_WHITE         clrWhite           // White text
#define CLR_SILVER        C'180,190,200'     // Normal text
#define CLR_GOLD          clrGold            // Gold accent

// Status Colors
#define CLR_PROFIT        C'0,220,100'       // Green profit
#define CLR_LOSS          C'255,80,80'       // Red loss
#define CLR_NEUTRAL       C'255,200,50'      // Yellow neutral/warning
#define CLR_ACTIVE        C'0,255,180'       // Active system

// Grid Colors (Azure Variants)
#define CLR_GRID_A        C'60,160,255'      // Grid A - Light Blue
#define CLR_GRID_B        C'100,200,255'     // Grid B - Cyan Blue

// Mode Colors
#define CLR_MODE_PURE     C'150,150,255'     // Purple-ish for PURE
#define CLR_MODE_CASCADE  C'80,180,255'      // Azure for CASCADE
#define CLR_MODE_RANGEBOX C'0,200,200'       // Teal for RANGEBOX

// Panel Background Colors (Blu Turchese Theme)
#define CLR_PANEL_GRIDA   C'15,40,55'        // Grid A panel (dark teal)
#define CLR_PANEL_GRIDB   C'15,45,60'        // Grid B panel (dark cyan)
#define CLR_PANEL_BUTTONS C'20,50,70'        // Buttons panel (turchese scuro)
#define CLR_PANEL_PERF    C'15,35,50'        // Performance panel

//+------------------------------------------------------------------+
//| DASHBOARD CONSTANTS                                              |
//+------------------------------------------------------------------+
#define PANEL_WIDTH       315
#define TOTAL_WIDTH       630
#define PANEL_HEADER      28
#define LINE_HEIGHT       18
#define SECTION_MARGIN    10
#define FONT_SIZE         9
#define FONT_NAME         "Consolas"
#define FONT_TITLE        "Segoe UI Semibold"

//+------------------------------------------------------------------+
//| Global Button Position Variables                                 |
//+------------------------------------------------------------------+
int g_btnY = 0;       // Button panel Y position
int g_leftX = 10;     // Left column X position
int g_colWidth = 315; // Column width

//+------------------------------------------------------------------+
//| Handle Button Click Events                                       |
//+------------------------------------------------------------------+
void HandleButtonClick(string clickedObject) {
    // Reset button state
    ObjectSetInteger(0, clickedObject, OBJPROP_STATE, false);
    ChartRedraw(0);

    // Check if system can accept new orders
    if(systemState != STATE_IDLE && clickedObject != "BTN_CLOSE_ALL") {
        Print("WARNING: System already active - click ignored");
        if(EnableAlerts) Alert("WARNING: System already active!");
        return;
    }

    //==============================================================
    // BUY BUTTONS - Grid A (Long Bias)
    //==============================================================
    if(clickedObject == "BTN_BUY_MARKET") {
        Print("INFO: BUY MARKET requested - Starting Grid A");
        systemState = STATE_ACTIVE;
        if(InitializeGridA()) {
            PlaceAllGridAOrders();
            Print("SUCCESS: Grid A started (MARKET)");
        }
        return;
    }

    if(clickedObject == "BTN_BUY_LIMIT") {
        Print("INFO: BUY LIMIT requested - Starting Grid A");
        systemState = STATE_ACTIVE;
        if(InitializeGridA()) {
            PlaceAllGridAOrders();
            Print("SUCCESS: Grid A started (LIMIT)");
        }
        return;
    }

    if(clickedObject == "BTN_BUY_STOP") {
        Print("INFO: BUY STOP requested - Starting Grid A");
        systemState = STATE_ACTIVE;
        if(InitializeGridA()) {
            PlaceAllGridAOrders();
            Print("SUCCESS: Grid A started (STOP)");
        }
        return;
    }

    //==============================================================
    // SELL BUTTONS - Grid B (Short Bias)
    //==============================================================
    if(clickedObject == "BTN_SELL_MARKET") {
        Print("INFO: SELL MARKET requested - Starting Grid B");
        systemState = STATE_ACTIVE;
        if(InitializeGridB()) {
            PlaceAllGridBOrders();
            Print("SUCCESS: Grid B started (MARKET)");
        }
        return;
    }

    if(clickedObject == "BTN_SELL_LIMIT") {
        Print("INFO: SELL LIMIT requested - Starting Grid B");
        systemState = STATE_ACTIVE;
        if(InitializeGridB()) {
            PlaceAllGridBOrders();
            Print("SUCCESS: Grid B started (LIMIT)");
        }
        return;
    }

    if(clickedObject == "BTN_SELL_STOP") {
        Print("INFO: SELL STOP requested - Starting Grid B");
        systemState = STATE_ACTIVE;
        if(InitializeGridB()) {
            PlaceAllGridBOrders();
            Print("SUCCESS: Grid B started (STOP)");
        }
        return;
    }

    //==============================================================
    // START BOTH GRIDS - Neutral Strategy
    //==============================================================
    if(clickedObject == "BTN_START_NEUTRAL") {
        Print("INFO: NEUTRAL START requested - Starting Both Grids");
        systemState = STATE_ACTIVE;
        InitializeEntryPoint();
        CalculateCurrentSpacing();
        if(InitializeGridA() && InitializeGridB()) {
            PlaceAllGridAOrders();
            PlaceAllGridBOrders();
            Print("SUCCESS: Both Grids started (NEUTRAL)");
            if(EnableAlerts) Alert("Sugamara: NEUTRAL Grid System STARTED");
        }
        return;
    }

    //==============================================================
    // PAUSE/RESUME
    //==============================================================
    if(clickedObject == "BTN_PAUSE") {
        if(systemState == STATE_PAUSED) {
            systemState = STATE_ACTIVE;
            Print("INFO: System RESUMED");
            UpdatePauseButton();
        } else if(systemState == STATE_ACTIVE) {
            systemState = STATE_PAUSED;
            Print("INFO: System PAUSED");
            UpdatePauseButton();
        }
        return;
    }

    //==============================================================
    // CLOSE ALL
    //==============================================================
    if(clickedObject == "BTN_CLOSE_ALL") {
        Print("WARNING: CLOSE ALL requested");
        CloseAllSugamaraOrders();
        systemState = STATE_IDLE;
        if(EnableAlerts) Alert("Sugamara: ALL POSITIONS CLOSED");
        return;
    }
}

//+------------------------------------------------------------------+
//| Update Pause Button Text                                         |
//+------------------------------------------------------------------+
void UpdatePauseButton() {
    string btnText = (systemState == STATE_PAUSED) ? "RESUME" : "PAUSE";
    color btnColor = (systemState == STATE_PAUSED) ? CLR_PROFIT : CLR_NEUTRAL;
    ObjectSetString(0, "BTN_PAUSE", OBJPROP_TEXT, btnText);
    ObjectSetInteger(0, "BTN_PAUSE", OBJPROP_BGCOLOR, btnColor);
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Initialize Dashboard - 2 Column Layout (ROBUST VERSION)          |
//+------------------------------------------------------------------+
bool InitializeDashboard() {
    if(!ShowDashboard) return true;

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  SUGAMARA DASHBOARD v3.1 - PERSISTENT MODE                        ");
    Print("═══════════════════════════════════════════════════════════════════");

    // Check if dashboard already exists and is complete
    if(VerifyDashboardExists()) {
        Print("Dashboard already exists - skipping recreation, updating values only");
        g_dashboardInitialized = true;
        g_lastDashboardCheck = TimeCurrent();
        UpdateDashboard();
        ChartRedraw(0);
        LogMessage(LOG_SUCCESS, "Dashboard v3.1 restored from existing objects");
        return true;
    }

    // Dashboard doesn't exist or is incomplete - create fresh
    Print("Creating new dashboard...");
    RemoveDashboard();
    Sleep(50);  // Small delay to ensure objects are deleted

    CreateUnifiedDashboard();
    CreateVolatilityPanel();
    CreateADXPanel();
    CreateShieldPanel();

    // Mark dashboard as initialized
    g_dashboardInitialized = true;
    g_lastDashboardCheck = TimeCurrent();

    // Verify dashboard was created correctly
    if(!VerifyDashboardExists()) {
        Print("WARNING: Dashboard verification failed - attempting recreation");
        RecreateEntireDashboard();
    }

    ChartRedraw(0);
    LogMessage(LOG_SUCCESS, "Dashboard v3.1 initialized with Amaranth/Azure theme (PERSISTENT)");
    return true;
}

//+------------------------------------------------------------------+
//| Verify Dashboard Exists - Check critical objects                  |
//+------------------------------------------------------------------+
bool VerifyDashboardExists() {
    if(!ShowDashboard) return true;

    // Check for critical dashboard objects
    string criticalObjects[] = {
        "TITLE_PANEL",
        "MODE_PANEL",
        "LEFT_GRIDA_PANEL",
        "RIGHT_GRIDB_PANEL",
        "LEFT_EXPOSURE_PANEL",
        "RIGHT_PERF_PANEL",
        "VOL_PANEL",
        "ADX_PANEL",
        "SHIELD_PANEL"
    };

    int missingCount = 0;
    for(int i = 0; i < ArraySize(criticalObjects); i++) {
        if(ObjectFind(0, criticalObjects[i]) < 0) {
            missingCount++;
        }
    }

    // If ANY critical objects are missing, dashboard needs recreation
    if(missingCount > 0) {
        Print("Dashboard verification: ", missingCount, " critical objects missing - will recreate");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Recreate Entire Dashboard - Force complete rebuild                |
//+------------------------------------------------------------------+
void RecreateEntireDashboard() {
    if(!ShowDashboard) return;

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  RECREATING DASHBOARD (Auto-Recovery)                             ");
    Print("═══════════════════════════════════════════════════════════════════");

    // Remove any partial objects
    RemoveDashboard();
    Sleep(100);

    // Recreate all components
    CreateUnifiedDashboard();
    CreateVolatilityPanel();
    CreateADXPanel();
    CreateShieldPanel();

    // Initialize control buttons if enabled
    if(Enable_AdvancedButtons) {
        InitializeControlButtons(g_btnY, g_leftX, g_colWidth);
    }

    g_dashboardInitialized = true;
    g_lastDashboardCheck = TimeCurrent();

    ChartRedraw(0);
    Print("SUCCESS: Dashboard recreated successfully");
}

//+------------------------------------------------------------------+
//| Check Dashboard Persistence - Called periodically from OnTick    |
//+------------------------------------------------------------------+
void CheckDashboardPersistence() {
    if(!ShowDashboard) return;

    // If dashboard was marked for recreation (e.g., object deleted externally)
    if(!g_dashboardInitialized) {
        Print("INFO: Dashboard initialization flag reset - recreating...");
        RecreateEntireDashboard();
        return;
    }

    // Only check every DASHBOARD_CHECK_INTERVAL seconds
    if(TimeCurrent() - g_lastDashboardCheck < DASHBOARD_CHECK_INTERVAL) return;
    g_lastDashboardCheck = TimeCurrent();

    // Quick check: verify main panel exists
    if(ObjectFind(0, "TITLE_PANEL") < 0) {
        Print("WARNING: Dashboard missing - auto-recreating...");
        RecreateEntireDashboard();
    }
}

//+------------------------------------------------------------------+
//| Ensure Dashboard On Chart Change                                  |
//+------------------------------------------------------------------+
void EnsureDashboardOnChartEvent() {
    if(!ShowDashboard) return;

    // Verify and recreate if needed
    if(!VerifyDashboardExists()) {
        Print("INFO: Dashboard objects missing after chart event - recreating");
        RecreateEntireDashboard();
    }
}

//+------------------------------------------------------------------+
//| Create Unified Dashboard - 2 Column Layout                       |
//+------------------------------------------------------------------+
void CreateUnifiedDashboard() {
    int x = Dashboard_X;
    int y = Dashboard_Y;
    int colWidth = PANEL_WIDTH;
    int totalWidth = TOTAL_WIDTH;

    //═══════════════════════════════════════════════════════════════
    // TITLE PANEL (Full Width)
    //═══════════════════════════════════════════════════════════════
    int titleHeight = 70;
    DashRectangle("TITLE_PANEL", x, y, totalWidth, titleHeight, CLR_BG_DARK);
    DashLabel("TITLE_MAIN", x + totalWidth/2 - 80, y + 15, "SUGAMARA v2.0", CLR_GOLD, 16, "Arial Black");
    DashLabel("TITLE_SUB", x + totalWidth/2 - 70, y + 42, "Double Grid Neutral", CLR_AZURE_1, 10, "Arial Bold");
    y += titleHeight;

    //═══════════════════════════════════════════════════════════════
    // MODE & SYMBOL PANEL (Full Width)
    //═══════════════════════════════════════════════════════════════
    int modeHeight = 55;
    DashRectangle("MODE_PANEL", x, y, totalWidth, modeHeight, CLR_BG_DARK);
    DashLabel("MODE_INFO1", x + 15, y + 8, "Mode: ---", CLR_CYAN, 9);
    DashLabel("MODE_INFO2", x + 15, y + 24, "Symbol: --- | Spread: ---", CLR_SILVER, 8);
    DashLabel("MODE_INFO3", x + 15, y + 38, "Pair: --- | Grids: --- | Spacing: ---", CLR_AZURE_2, 8);
    DashLabel("MODE_INFO4", x + 350, y + 8, "ATR: --- pips", CLR_AZURE_1, 9);
    DashLabel("MODE_INFO5", x + 350, y + 24, "ADX: ---", CLR_SILVER, 8);
    DashLabel("MODE_INFO6", x + 350, y + 38, "Step: ---", CLR_AZURE_2, 8);
    y += modeHeight;

    //═══════════════════════════════════════════════════════════════
    // LEFT COLUMN START
    //═══════════════════════════════════════════════════════════════
    int leftX = x;
    int leftY = y;

    //--- GRID A PANEL (Long Bias) ---
    int gridAHeight = 180;
    DashRectangle("LEFT_GRIDA_PANEL", leftX, leftY, colWidth, gridAHeight, CLR_PANEL_GRIDA);

    int ay = leftY + 8;
    DashLabel("LEFT_GRIDA_TITLE", leftX + 10, ay, "GRID A (Long Bias)", CLR_GRID_A, 11, "Arial Bold");
    ay += 22;
    DashLabel("LEFT_GRIDA_STATUS", leftX + 10, ay, "Status: IDLE", clrGray, 9);
    ay += 18;
    DashLabel("LEFT_GRIDA_POSITIONS", leftX + 10, ay, "Positions: 0", CLR_WHITE, 8);
    ay += 16;
    DashLabel("LEFT_GRIDA_PENDING", leftX + 10, ay, "Pending: 0", CLR_WHITE, 8);
    ay += 16;
    DashLabel("LEFT_GRIDA_LOTS", leftX + 10, ay, "Long Lots: 0.00", CLR_GRID_A, 8);
    ay += 16;
    DashLabel("LEFT_GRIDA_SHORT", leftX + 10, ay, "Short Lots: 0.00", CLR_LOSS, 8);
    ay += 20;
    DashLabel("LEFT_GRIDA_PROFIT", leftX + 10, ay, "P/L: $0.00", CLR_WHITE, 10, "Arial Bold");
    ay += 18;
    DashLabel("LEFT_GRIDA_CYCLES", leftX + 10, ay, "Cycles: 0 | Reopens: 0", CLR_SILVER, 8);

    leftY += gridAHeight;

    //--- NET EXPOSURE PANEL ---
    int exposureHeight = 100;
    DashRectangle("LEFT_EXPOSURE_PANEL", leftX, leftY, colWidth, exposureHeight, CLR_BG_MEDIUM);

    int ey = leftY + 8;
    DashLabel("LEFT_EXPOSURE_TITLE", leftX + 10, ey, "NET EXPOSURE", CLR_AZURE_2, 11, "Arial Bold");
    ey += 22;
    DashLabel("LEFT_EXPOSURE_LONG", leftX + 10, ey, "Total Long: 0.00 lot", CLR_GRID_A, 9);
    ey += 18;
    DashLabel("LEFT_EXPOSURE_SHORT", leftX + 10, ey, "Total Short: 0.00 lot", CLR_GRID_B, 9);
    ey += 18;
    DashLabel("LEFT_EXPOSURE_NET", leftX + 10, ey, "Net: 0.00 (NEUTRAL)", CLR_ACTIVE, 10, "Arial Bold");

    leftY += exposureHeight;

    //--- CONTROL BUTTONS PANEL ---
    int buttonsHeight = 170;
    DashRectangle("LEFT_BUTTONS_PANEL", leftX, leftY, colWidth, buttonsHeight, CLR_PANEL_BUTTONS);
    g_btnY = leftY;
    CreateControlButtons(leftY, leftX, colWidth);

    leftY += buttonsHeight;

    //═══════════════════════════════════════════════════════════════
    // RIGHT COLUMN START
    //═══════════════════════════════════════════════════════════════
    int rightX = x + colWidth;
    int rightY = y;

    //--- GRID B PANEL (Short Bias) ---
    int gridBHeight = 180;
    DashRectangle("RIGHT_GRIDB_PANEL", rightX, rightY, colWidth, gridBHeight, CLR_PANEL_GRIDB);

    int by = rightY + 8;
    DashLabel("RIGHT_GRIDB_TITLE", rightX + 10, by, "GRID B (Short Bias)", CLR_GRID_B, 11, "Arial Bold");
    by += 22;
    DashLabel("RIGHT_GRIDB_STATUS", rightX + 10, by, "Status: IDLE", clrGray, 9);
    by += 18;
    DashLabel("RIGHT_GRIDB_POSITIONS", rightX + 10, by, "Positions: 0", CLR_WHITE, 8);
    by += 16;
    DashLabel("RIGHT_GRIDB_PENDING", rightX + 10, by, "Pending: 0", CLR_WHITE, 8);
    by += 16;
    DashLabel("RIGHT_GRIDB_LOTS", rightX + 10, by, "Long Lots: 0.00", CLR_GRID_A, 8);
    by += 16;
    DashLabel("RIGHT_GRIDB_SHORT", rightX + 10, by, "Short Lots: 0.00", CLR_LOSS, 8);
    by += 20;
    DashLabel("RIGHT_GRIDB_PROFIT", rightX + 10, by, "P/L: $0.00", CLR_WHITE, 10, "Arial Bold");
    by += 18;
    DashLabel("RIGHT_GRIDB_CYCLES", rightX + 10, by, "Cycles: 0 | Reopens: 0", CLR_SILVER, 8);

    rightY += gridBHeight;

    //--- RANGEBOX PANEL (if enabled) ---
    int rangeboxHeight = 100;
    DashRectangle("RIGHT_RANGEBOX_PANEL", rightX, rightY, colWidth, rangeboxHeight, CLR_BG_MEDIUM);

    int ry = rightY + 8;
    DashLabel("RIGHT_RANGEBOX_TITLE", rightX + 10, ry, "RANGEBOX STATUS", CLR_MODE_RANGEBOX, 11, "Arial Bold");
    ry += 22;
    DashLabel("RIGHT_RANGEBOX_RES", rightX + 10, ry, "Resistance: ---", CLR_LOSS, 9);
    ry += 18;
    DashLabel("RIGHT_RANGEBOX_SUP", rightX + 10, ry, "Support: ---", CLR_PROFIT, 9);
    ry += 18;
    DashLabel("RIGHT_RANGEBOX_STATUS", rightX + 10, ry, "Status: N/A", CLR_SILVER, 9);

    rightY += rangeboxHeight;

    //--- PERFORMANCE PANEL ---
    int perfHeight = 190;  // Increased for Risk line
    DashRectangle("RIGHT_PERF_PANEL", rightX, rightY, colWidth, perfHeight, CLR_PANEL_PERF);

    int py = rightY + 8;
    DashLabel("RIGHT_PERF_TITLE", rightX + colWidth/2 - 50, py, "PERFORMANCE", CLR_GOLD, 9, "Arial Bold");
    py += 22;
    DashLabel("RIGHT_PERF_TOTAL", rightX + 10, py, "Total P/L: $0.00", CLR_WHITE, 11, "Arial Bold");
    py += 20;
    DashLabel("RIGHT_PERF_EQUITY", rightX + 10, py, "Equity: $---", CLR_WHITE, 8);
    py += 16;
    DashLabel("RIGHT_PERF_BALANCE", rightX + 10, py, "Balance: $---", CLR_WHITE, 8);
    py += 16;
    DashLabel("RIGHT_PERF_DD", rightX + 10, py, "Drawdown: 0.00%", CLR_WHITE, 8);
    py += 16;
    DashLabel("RIGHT_PERF_RISK", rightX + 10, py, "Risk: ---", CLR_PROFIT, 9, "Arial Bold");
    py += 20;
    DashLabel("RIGHT_PERF_WINRATE", rightX + 10, py, "Win Rate: --% (0W/0L)", CLR_SILVER, 8);
    py += 16;
    DashLabel("RIGHT_PERF_TRADES", rightX + 10, py, "Total Trades: 0", CLR_SILVER, 8);

    rightY += perfHeight;

    ChartRedraw(0);
    Print("SUCCESS: Unified Dashboard created with 2-column layout");
}

//+------------------------------------------------------------------+
//| Create Control Buttons v3.0 (MARKET/LIMIT/STOP/CLOSE)            |
//+------------------------------------------------------------------+
void CreateControlButtons(int startY, int startX, int panelWidth) {
    int x = startX + 10;
    int y = startY + 10;
    int btnStartWidth = 140;   // v4.3: START largo
    int btnCloseWidth = 120;   // v4.3: CLOSE largo
    int btnHeight = 35;
    int spacing = 10;

    // v4.3 Control Buttons Mode (Simplified: START + CLOSE only)
    if(Enable_AdvancedButtons) {
        // Status Label (matches ControlButtons.mqh BTN_STATUS_V3)
        DashLabel("SUGAMARA_BTN_STATUS", x, y, "READY - Click START", CLR_DASH_TEXT, 10, "Arial Bold");
        y += 22;

        // v4.3: 2 Main Buttons: START | CLOSE (LIMIT/STOP removed - not needed for neutral grid)
        // Names MUST match ControlButtons.mqh: BTN_START_V3 and BTN_CLOSEALL_V3
        DashButton("SUGAMARA_BTN_START", x, y, btnStartWidth, btnHeight, "START", C'0,150,80');
        DashButton("SUGAMARA_BTN_CLOSEALL", x + btnStartWidth + spacing, y, btnCloseWidth, btnHeight, "CLOSE", C'180,30,30');
        y += btnHeight + 8;

        // Entry Mode Status
        DashLabel("BTN_MODE_STATUS", x, y, "Mode: READY", CLR_CYAN, 9, "Arial Bold");
    }
    else {
        // Legacy v2.0 Buttons
        // BUY Label
        DashLabel("LBL_BUY", x + panelWidth/2 - 25, y, "BUY (Grid A)", clrLimeGreen, 9, "Arial Bold");
        y += 18;

        // BUY Buttons (3 in a row)
        DashButton("BTN_BUY_MARKET", x, y, 95, 30, "MARKET", clrLimeGreen);
        DashButton("BTN_BUY_LIMIT", x + 100, y, 95, 30, "LIMIT", clrDodgerBlue);
        DashButton("BTN_BUY_STOP", x + 200, y, 95, 30, "STOP", clrGold);
        y += 38;

        // SELL Label
        DashLabel("LBL_SELL", x + panelWidth/2 - 25, y, "SELL (Grid B)", clrRed, 9, "Arial Bold");
        y += 18;

        // SELL Buttons (3 in a row)
        DashButton("BTN_SELL_MARKET", x, y, 95, 30, "MARKET", clrRed);
        DashButton("BTN_SELL_LIMIT", x + 100, y, 95, 30, "LIMIT", clrOrangeRed);
        DashButton("BTN_SELL_STOP", x + 200, y, 95, 30, "STOP", clrDarkOrange);
        y += 40;

        // CLOSE ALL Button (full width)
        DashButton("BTN_CLOSE_ALL", x, y, 290, 34, "CLOSE ALL POSITIONS", C'180,0,0');
    }

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Create Volatility/ATR Monitor Panel (Right Side)                 |
//+------------------------------------------------------------------+
void CreateVolatilityPanel() {
    int volX = Dashboard_X + TOTAL_WIDTH + 10;
    int volY = Dashboard_Y;
    int volWidth = 175;
    int volHeight = 160;

    DashRectangle("VOL_PANEL", volX, volY, volWidth, volHeight, CLR_BG_DARK);

    int ly = volY + 8;
    DashLabel("VOL_TITLE", volX + 10, ly, "ATR MONITOR", CLR_GOLD, 9, "Arial Bold");
    ly += 20;
    DashLabel("VOL_SEPARATOR", volX + 10, ly, "------------------------", clrGray, 7);
    ly += 15;

    // IMMEDIATE Section
    DashLabel("VOL_IMMEDIATE_TITLE", volX + 10, ly, "IMMEDIATE (M5):", CLR_CYAN, 8, "Arial Bold");
    ly += 16;
    DashLabel("VOL_IMMEDIATE_ATR", volX + 10, ly, "ATR: --- pips", clrGray, 8);
    ly += 14;
    DashLabel("VOL_IMMEDIATE_COND", volX + 10, ly, "Condition: ---", clrGray, 8);
    ly += 18;

    // CONTEXT Section
    DashLabel("VOL_CONTEXT_TITLE", volX + 10, ly, "CONTEXT (H1):", CLR_NEUTRAL, 8, "Arial Bold");
    ly += 16;
    DashLabel("VOL_CONTEXT_ATR", volX + 10, ly, "ATR: --- pips", clrGray, 8);
    ly += 14;
    DashLabel("VOL_CONTEXT_COND", volX + 10, ly, "Condition: ---", clrGray, 8);
    ly += 18;

    // Spacing Status
    DashLabel("VOL_SPACING_STATUS", volX + 10, ly, "Spacing: --- pips", CLR_AZURE_1, 9, "Arial Bold");

    Print("SUCCESS: Volatility Panel created");
}

//+------------------------------------------------------------------+
//| Create ADX Trend Strength Panel (Right Side)                     |
//+------------------------------------------------------------------+
void CreateADXPanel() {
    int adxX = Dashboard_X + TOTAL_WIDTH + 10;
    int adxY = Dashboard_Y + 168;
    int adxWidth = 175;
    int adxHeight = 150;

    DashRectangle("ADX_PANEL", adxX, adxY, adxWidth, adxHeight, C'35,15,15');

    int ly = adxY + 8;
    DashLabel("ADX_TITLE", adxX + 10, ly, "ADX MONITOR", CLR_GOLD, 9, "Arial Bold");
    ly += 20;
    DashLabel("ADX_SEPARATOR", adxX + 10, ly, "------------------------", clrGray, 7);
    ly += 15;

    // IMMEDIATE Section
    DashLabel("ADX_IMMEDIATE_TITLE", adxX + 10, ly, "IMMEDIATE (M15):", CLR_CYAN, 8, "Arial Bold");
    ly += 16;
    DashLabel("ADX_IMMEDIATE_VALUE", adxX + 10, ly, "ADX: ---", clrGray, 8);
    ly += 14;
    DashLabel("ADX_IMMEDIATE_DI", adxX + 10, ly, "+DI: --- | -DI: ---", clrGray, 8);
    ly += 18;

    // CONTEXT Section
    DashLabel("ADX_CONTEXT_TITLE", adxX + 10, ly, "CONTEXT (H1):", CLR_NEUTRAL, 8, "Arial Bold");
    ly += 16;
    DashLabel("ADX_CONTEXT_VALUE", adxX + 10, ly, "ADX: ---", clrGray, 8);
    ly += 14;
    DashLabel("ADX_CONTEXT_DI", adxX + 10, ly, "+DI: --- | -DI: ---", clrGray, 8);
    ly += 18;

    // Trend Status
    DashLabel("ADX_TREND_STATUS", adxX + 10, ly, "Trend: NEUTRAL", clrGray, 9, "Arial Bold");

    Print("SUCCESS: ADX Panel created");
}

//+------------------------------------------------------------------+
//| Create Shield Panel (Right Side)                                  |
//+------------------------------------------------------------------+
void CreateShieldPanel() {
    int shieldX = Dashboard_X + TOTAL_WIDTH + 10;
    int shieldY = Dashboard_Y + 328;
    int shieldWidth = 175;
    int shieldHeight = 140;

    DashRectangle("SHIELD_PANEL", shieldX, shieldY, shieldWidth, shieldHeight, C'25,35,25');

    int ly = shieldY + 8;
    DashLabel("SHIELD_TITLE", shieldX + 10, ly, "SHIELD MONITOR", CLR_GOLD, 9, "Arial Bold");
    ly += 20;
    DashLabel("SHIELD_SEPARATOR", shieldX + 10, ly, "------------------------", clrGray, 7);
    ly += 15;

    // Shield Mode
    DashLabel("SHIELD_MODE", shieldX + 10, ly, "Mode: ---", CLR_AZURE_1, 8);
    ly += 16;

    // Shield Status
    DashLabel("SHIELD_STATUS", shieldX + 10, ly, "Status: IDLE", clrGray, 8);
    ly += 16;

    // Shield Phase
    DashLabel("SHIELD_PHASE", shieldX + 10, ly, "Phase: Normal", clrGray, 8);
    ly += 18;

    // Active Shield Info
    DashLabel("SHIELD_TYPE", shieldX + 10, ly, "Type: ---", clrGray, 8);
    ly += 16;
    DashLabel("SHIELD_LOT", shieldX + 10, ly, "Lot: ---", clrGray, 8);
    ly += 16;
    DashLabel("SHIELD_PL", shieldX + 10, ly, "P/L: ---", clrGray, 9, "Arial Bold");

    Print("SUCCESS: Shield Panel created");
}

//+------------------------------------------------------------------+
//| Update All Dashboard Values                                      |
//+------------------------------------------------------------------+
void UpdateDashboard() {
    if(!ShowDashboard) return;

    // Throttle updates to once per second
    static datetime lastUpdate = 0;
    if(TimeCurrent() == lastUpdate) return;
    lastUpdate = TimeCurrent();

    UpdateModeSection();
    UpdateGridASection();
    UpdateGridBSection();
    UpdateExposureSection();
    UpdateRangeBoxSection();
    UpdatePerformanceSection();
    UpdateVolatilityPanel();
    UpdateADXPanel();
    UpdateShieldSection();

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Update Mode Section                                              |
//+------------------------------------------------------------------+
void UpdateModeSection() {
    // Line 1: Mode
    string modeText = "Mode: " + GetModeName();
    ObjectSetString(0, "MODE_INFO1", OBJPROP_TEXT, modeText);
    ObjectSetInteger(0, "MODE_INFO1", OBJPROP_COLOR, GetModeColor());

    // Line 2: Symbol + Spread
    string symbolText = StringFormat("Symbol: %s | Spread: %.1f pips", _Symbol, GetSpreadPips());
    ObjectSetString(0, "MODE_INFO2", OBJPROP_TEXT, symbolText);

    // Line 3: Pair + Grids + Spacing (DYNAMIC)
    string pairName = GetPairDisplayName(SelectedPair);
    double dynSpacing = GetDynamicSpacing();
    string pairGridText = StringFormat("Pair: %s | Grids: %d | Spacing: %.1f pips",
                                        pairName, GridLevelsPerSide, dynSpacing);
    ObjectSetString(0, "MODE_INFO3", OBJPROP_TEXT, pairGridText);

    // Line 4: ATR
    double atrPips = GetATRPips();
    string atrText = StringFormat("ATR: %.1f pips", atrPips);
    ObjectSetString(0, "MODE_INFO4", OBJPROP_TEXT, atrText);

    // Line 5: ADX
    double adxVal = GetADXValue(PERIOD_M15, 0);
    string adxText = StringFormat("ADX: %.1f", adxVal);
    ObjectSetString(0, "MODE_INFO5", OBJPROP_TEXT, adxText);

    // Line 6: ATR Step (v4.0 Dynamic)
    if(EnableDynamicATRSpacing && NeutralMode != NEUTRAL_PURE) {
        string stepName = GetATRStepName(currentATRStep);
        ObjectSetString(0, "MODE_INFO6", OBJPROP_TEXT, "Step: " + stepName);
        // Color based on step
        color stepColor = CLR_AZURE_2;
        if(currentATRStep == ATR_STEP_EXTREME) stepColor = CLR_LOSS;
        else if(currentATRStep == ATR_STEP_HIGH) stepColor = CLR_NEUTRAL;
        else if(currentATRStep == ATR_STEP_VERY_LOW) stepColor = clrGray;
        ObjectSetInteger(0, "MODE_INFO6", OBJPROP_COLOR, stepColor);
    } else {
        ObjectSetString(0, "MODE_INFO6", OBJPROP_TEXT, "Step: N/A (Fixed)");
        ObjectSetInteger(0, "MODE_INFO6", OBJPROP_COLOR, clrGray);
    }
}

//+------------------------------------------------------------------+
//| Update Grid A Section                                            |
//+------------------------------------------------------------------+
void UpdateGridASection() {
    int positions = GetGridAActivePositions();
    int pending = GetGridAPendingOrders();
    double profit = GetGridAOpenProfit();
    double longLots = GetGridALongLots();
    double shortLots = GetGridAShortLots();

    // Status
    string statusText = "Status: ";
    color statusColor = clrGray;
    if(systemState == STATE_ACTIVE && positions > 0) {
        statusText += "ACTIVE";
        statusColor = CLR_ACTIVE;
    } else if(systemState == STATE_PAUSED) {
        statusText += "PAUSED";
        statusColor = CLR_NEUTRAL;
    } else {
        statusText += "IDLE";
    }
    ObjectSetString(0, "LEFT_GRIDA_STATUS", OBJPROP_TEXT, statusText);
    ObjectSetInteger(0, "LEFT_GRIDA_STATUS", OBJPROP_COLOR, statusColor);

    ObjectSetString(0, "LEFT_GRIDA_POSITIONS", OBJPROP_TEXT, "Positions: " + IntegerToString(positions));
    ObjectSetString(0, "LEFT_GRIDA_PENDING", OBJPROP_TEXT, "Pending: " + IntegerToString(pending));
    ObjectSetString(0, "LEFT_GRIDA_LOTS", OBJPROP_TEXT, StringFormat("Long Lots: %.2f", longLots));
    ObjectSetString(0, "LEFT_GRIDA_SHORT", OBJPROP_TEXT, StringFormat("Short Lots: %.2f", shortLots));

    color profitColor = profit >= 0 ? CLR_PROFIT : CLR_LOSS;
    ObjectSetString(0, "LEFT_GRIDA_PROFIT", OBJPROP_TEXT, StringFormat("P/L: $%.2f", profit));
    ObjectSetInteger(0, "LEFT_GRIDA_PROFIT", OBJPROP_COLOR, profitColor);
}

//+------------------------------------------------------------------+
//| Update Grid B Section                                            |
//+------------------------------------------------------------------+
void UpdateGridBSection() {
    int positions = GetGridBActivePositions();
    int pending = GetGridBPendingOrders();
    double profit = GetGridBOpenProfit();
    double longLots = GetGridBLongLots();
    double shortLots = GetGridBShortLots();

    // Status
    string statusText = "Status: ";
    color statusColor = clrGray;
    if(systemState == STATE_ACTIVE && positions > 0) {
        statusText += "ACTIVE";
        statusColor = CLR_ACTIVE;
    } else if(systemState == STATE_PAUSED) {
        statusText += "PAUSED";
        statusColor = CLR_NEUTRAL;
    } else {
        statusText += "IDLE";
    }
    ObjectSetString(0, "RIGHT_GRIDB_STATUS", OBJPROP_TEXT, statusText);
    ObjectSetInteger(0, "RIGHT_GRIDB_STATUS", OBJPROP_COLOR, statusColor);

    ObjectSetString(0, "RIGHT_GRIDB_POSITIONS", OBJPROP_TEXT, "Positions: " + IntegerToString(positions));
    ObjectSetString(0, "RIGHT_GRIDB_PENDING", OBJPROP_TEXT, "Pending: " + IntegerToString(pending));
    ObjectSetString(0, "RIGHT_GRIDB_LOTS", OBJPROP_TEXT, StringFormat("Long Lots: %.2f", longLots));
    ObjectSetString(0, "RIGHT_GRIDB_SHORT", OBJPROP_TEXT, StringFormat("Short Lots: %.2f", shortLots));

    color profitColor = profit >= 0 ? CLR_PROFIT : CLR_LOSS;
    ObjectSetString(0, "RIGHT_GRIDB_PROFIT", OBJPROP_TEXT, StringFormat("P/L: $%.2f", profit));
    ObjectSetInteger(0, "RIGHT_GRIDB_PROFIT", OBJPROP_COLOR, profitColor);
}

//+------------------------------------------------------------------+
//| Update Exposure Section                                          |
//+------------------------------------------------------------------+
void UpdateExposureSection() {
    CalculateTotalExposure();

    ObjectSetString(0, "LEFT_EXPOSURE_LONG", OBJPROP_TEXT,
                    StringFormat("Total Long: %.2f lot", totalLongLots));
    ObjectSetString(0, "LEFT_EXPOSURE_SHORT", OBJPROP_TEXT,
                    StringFormat("Total Short: %.2f lot", totalShortLots));

    string netText = "";
    color netColor = CLR_NEUTRAL;

    if(netExposure > 0.001) {
        netText = StringFormat("Net: +%.2f (LONG bias)", netExposure);
        netColor = CLR_GRID_A;
    } else if(netExposure < -0.001) {
        netText = StringFormat("Net: %.2f (SHORT bias)", netExposure);
        netColor = CLR_GRID_B;
    } else {
        netText = "Net: 0.00 (NEUTRAL)";
        netColor = CLR_ACTIVE;
    }

    ObjectSetString(0, "LEFT_EXPOSURE_NET", OBJPROP_TEXT, netText);
    ObjectSetInteger(0, "LEFT_EXPOSURE_NET", OBJPROP_COLOR, netColor);
}

//+------------------------------------------------------------------+
//| Update RangeBox Section                                          |
//+------------------------------------------------------------------+
void UpdateRangeBoxSection() {
    if(!IsRangeBoxAvailable()) {
        ObjectSetString(0, "RIGHT_RANGEBOX_STATUS", OBJPROP_TEXT, "Status: N/A");
        ObjectSetInteger(0, "RIGHT_RANGEBOX_STATUS", OBJPROP_COLOR, clrGray);
        return;
    }

    ObjectSetString(0, "RIGHT_RANGEBOX_RES", OBJPROP_TEXT,
                    StringFormat("Resistance: %.5f", rangeBox_Resistance));
    ObjectSetString(0, "RIGHT_RANGEBOX_SUP", OBJPROP_TEXT,
                    StringFormat("Support: %.5f", rangeBox_Support));

    string statusText = "Status: ";
    color statusColor = CLR_WHITE;

    if(isBreakoutUp) {
        statusText += "BREAKOUT UP";
        statusColor = CLR_LOSS;
    } else if(isBreakoutDown) {
        statusText += "BREAKOUT DOWN";
        statusColor = CLR_LOSS;
    } else if(isInsideRange) {
        statusText += "Inside Range";
        statusColor = CLR_ACTIVE;
    } else {
        statusText += "Unknown";
    }

    ObjectSetString(0, "RIGHT_RANGEBOX_STATUS", OBJPROP_TEXT, statusText);
    ObjectSetInteger(0, "RIGHT_RANGEBOX_STATUS", OBJPROP_COLOR, statusColor);
}

//+------------------------------------------------------------------+
//| Update Performance Section                                       |
//+------------------------------------------------------------------+
void UpdatePerformanceSection() {
    double totalPL = sessionRealizedProfit + GetTotalOpenProfit();
    double equity = GetEquity();
    double balance = GetBalance();
    double dd = GetCurrentDrawdown();
    double winRate = GetWinRate();
    int trades = sessionWins + sessionLosses;

    color plColor = totalPL >= 0 ? CLR_PROFIT : CLR_LOSS;
    ObjectSetString(0, "RIGHT_PERF_TOTAL", OBJPROP_TEXT, StringFormat("Total P/L: $%.2f", totalPL));
    ObjectSetInteger(0, "RIGHT_PERF_TOTAL", OBJPROP_COLOR, plColor);

    ObjectSetString(0, "RIGHT_PERF_EQUITY", OBJPROP_TEXT, StringFormat("Equity: $%.2f", equity));
    ObjectSetString(0, "RIGHT_PERF_BALANCE", OBJPROP_TEXT, StringFormat("Balance: $%.2f", balance));

    color ddColor = dd > 10 ? CLR_LOSS : (dd > 5 ? CLR_NEUTRAL : CLR_WHITE);
    ObjectSetString(0, "RIGHT_PERF_DD", OBJPROP_TEXT, StringFormat("Drawdown: %.2f%%", dd));
    ObjectSetInteger(0, "RIGHT_PERF_DD", OBJPROP_COLOR, ddColor);

    // Risk-Based Status (if enabled)
    if(LotMode == LOT_RISK_BASED) {
        double currentDD = GetCurrentUnrealizedDrawdown();
        double riskPercent = (RiskCapital_USD > 0) ? (currentDD / RiskCapital_USD * 100.0) : 0;
        color riskColor = riskPercent > 80 ? CLR_LOSS : (riskPercent > 50 ? CLR_NEUTRAL : CLR_PROFIT);

        ObjectSetString(0, "RIGHT_PERF_RISK", OBJPROP_TEXT,
                        StringFormat("Risk: $%.0f / $%.0f (%.0f%%)", currentDD, RiskCapital_USD, riskPercent));
        ObjectSetInteger(0, "RIGHT_PERF_RISK", OBJPROP_COLOR, riskColor);
    } else {
        ObjectSetString(0, "RIGHT_PERF_RISK", OBJPROP_TEXT, "Risk: FIXED MODE");
        ObjectSetInteger(0, "RIGHT_PERF_RISK", OBJPROP_COLOR, clrGray);
    }

    ObjectSetString(0, "RIGHT_PERF_WINRATE", OBJPROP_TEXT,
                    StringFormat("Win Rate: %.0f%% (%dW/%dL)", winRate, sessionWins, sessionLosses));
    ObjectSetString(0, "RIGHT_PERF_TRADES", OBJPROP_TEXT, StringFormat("Total Trades: %d", trades));
}

//+------------------------------------------------------------------+
//| Update Volatility Panel - NO LAG                                 |
//+------------------------------------------------------------------+
void UpdateVolatilityPanel() {
    // Immediate ATR (M5)
    double atrM5 = GetATRValue(PERIOD_M5);
    double atrM5Pips = atrM5 / symbolPoint / 10.0;

    ObjectSetString(0, "VOL_IMMEDIATE_ATR", OBJPROP_TEXT, StringFormat("ATR: %.1f pips", atrM5Pips));

    string condM5 = GetATRConditionText(atrM5Pips);
    color condM5Color = GetATRConditionColor(atrM5Pips);
    ObjectSetString(0, "VOL_IMMEDIATE_COND", OBJPROP_TEXT, "Condition: " + condM5);
    ObjectSetInteger(0, "VOL_IMMEDIATE_COND", OBJPROP_COLOR, condM5Color);

    // Context ATR (H1)
    double atrH1 = GetATRValue(PERIOD_H1);
    double atrH1Pips = atrH1 / symbolPoint / 10.0;

    ObjectSetString(0, "VOL_CONTEXT_ATR", OBJPROP_TEXT, StringFormat("ATR: %.1f pips", atrH1Pips));

    string condH1 = GetATRConditionText(atrH1Pips);
    color condH1Color = GetATRConditionColor(atrH1Pips);
    ObjectSetString(0, "VOL_CONTEXT_COND", OBJPROP_TEXT, "Condition: " + condH1);
    ObjectSetInteger(0, "VOL_CONTEXT_COND", OBJPROP_COLOR, condH1Color);

    // Spacing status
    ObjectSetString(0, "VOL_SPACING_STATUS", OBJPROP_TEXT,
                    StringFormat("Spacing: %.1f pips", currentSpacing_Pips));
}

//+------------------------------------------------------------------+
//| Update ADX Panel - NO LAG                                        |
//+------------------------------------------------------------------+
void UpdateADXPanel() {
    // Immediate ADX (M15)
    double adxM15 = GetADXValue(PERIOD_M15, 0);
    double plusDIM15 = GetADXValue(PERIOD_M15, 1);
    double minusDIM15 = GetADXValue(PERIOD_M15, 2);

    ObjectSetString(0, "ADX_IMMEDIATE_VALUE", OBJPROP_TEXT, StringFormat("ADX: %.1f", adxM15));
    ObjectSetString(0, "ADX_IMMEDIATE_DI", OBJPROP_TEXT,
                    StringFormat("+DI: %.1f | -DI: %.1f", plusDIM15, minusDIM15));

    color adxM15Color = adxM15 > 25 ? CLR_PROFIT : (adxM15 > 20 ? CLR_NEUTRAL : clrGray);
    ObjectSetInteger(0, "ADX_IMMEDIATE_VALUE", OBJPROP_COLOR, adxM15Color);

    // Context ADX (H1)
    double adxH1 = GetADXValue(PERIOD_H1, 0);
    double plusDIH1 = GetADXValue(PERIOD_H1, 1);
    double minusDIH1 = GetADXValue(PERIOD_H1, 2);

    ObjectSetString(0, "ADX_CONTEXT_VALUE", OBJPROP_TEXT, StringFormat("ADX: %.1f", adxH1));
    ObjectSetString(0, "ADX_CONTEXT_DI", OBJPROP_TEXT,
                    StringFormat("+DI: %.1f | -DI: %.1f", plusDIH1, minusDIH1));

    color adxH1Color = adxH1 > 25 ? CLR_PROFIT : (adxH1 > 20 ? CLR_NEUTRAL : clrGray);
    ObjectSetInteger(0, "ADX_CONTEXT_VALUE", OBJPROP_COLOR, adxH1Color);

    // Trend Status
    string trendText = "Trend: ";
    color trendColor = clrGray;

    if(adxH1 > 25) {
        if(plusDIH1 > minusDIH1) {
            trendText += "BULLISH";
            trendColor = CLR_PROFIT;
        } else {
            trendText += "BEARISH";
            trendColor = CLR_LOSS;
        }
    } else {
        trendText += "NEUTRAL";
        trendColor = CLR_NEUTRAL;
    }

    ObjectSetString(0, "ADX_TREND_STATUS", OBJPROP_TEXT, trendText);
    ObjectSetInteger(0, "ADX_TREND_STATUS", OBJPROP_COLOR, trendColor);
}

//+------------------------------------------------------------------+
//| Update Shield Section                                             |
//+------------------------------------------------------------------+
void UpdateShieldSection() {
    // Shield Mode
    string modeText = "Mode: ";
    if(NeutralMode != NEUTRAL_RANGEBOX) {
        modeText += "N/A";
        ObjectSetString(0, "SHIELD_MODE", OBJPROP_TEXT, modeText);
        ObjectSetInteger(0, "SHIELD_MODE", OBJPROP_COLOR, clrGray);
        ObjectSetString(0, "SHIELD_STATUS", OBJPROP_TEXT, "Status: N/A");
        ObjectSetInteger(0, "SHIELD_STATUS", OBJPROP_COLOR, clrGray);
        ObjectSetString(0, "SHIELD_PHASE", OBJPROP_TEXT, "Phase: N/A");
        ObjectSetInteger(0, "SHIELD_PHASE", OBJPROP_COLOR, clrGray);
        ObjectSetString(0, "SHIELD_TYPE", OBJPROP_TEXT, "Type: ---");
        ObjectSetString(0, "SHIELD_LOT", OBJPROP_TEXT, "Lot: ---");
        ObjectSetString(0, "SHIELD_PL", OBJPROP_TEXT, "P/L: ---");
        return;
    }

    // Get Shield Mode Name
    switch(ShieldMode) {
        case SHIELD_DISABLED: modeText += "DISABLED"; break;
        case SHIELD_SIMPLE: modeText += "SIMPLE"; break;
        case SHIELD_3_PHASES: modeText += "3 PHASES"; break;
    }
    ObjectSetString(0, "SHIELD_MODE", OBJPROP_TEXT, modeText);
    ObjectSetInteger(0, "SHIELD_MODE", OBJPROP_COLOR, CLR_AZURE_1);

    // Shield Status
    string statusText = "Status: ";
    color statusColor = clrGray;

    if(ShieldMode == SHIELD_DISABLED) {
        statusText += "DISABLED";
        statusColor = clrGray;
    }
    else if(!shield.isActive) {
        switch(shield.phase) {
            case PHASE_NORMAL:
                statusText += "IDLE";
                statusColor = CLR_AZURE_3;
                break;
            case PHASE_WARNING:
                statusText += "WARNING";
                statusColor = CLR_NEUTRAL;
                break;
            case PHASE_PRE_SHIELD:
                statusText += "PRE-SHIELD";
                statusColor = clrOrange;
                break;
            default:
                statusText += "IDLE";
                break;
        }
    }
    else {
        if(shield.type == SHIELD_LONG) {
            statusText += "SHIELD LONG";
            statusColor = CLR_PROFIT;
        } else if(shield.type == SHIELD_SHORT) {
            statusText += "SHIELD SHORT";
            statusColor = CLR_LOSS;
        }
    }

    ObjectSetString(0, "SHIELD_STATUS", OBJPROP_TEXT, statusText);
    ObjectSetInteger(0, "SHIELD_STATUS", OBJPROP_COLOR, statusColor);

    // Shield Phase
    string phaseText = "Phase: ";
    switch(shield.phase) {
        case PHASE_NORMAL: phaseText += "Normal"; break;
        case PHASE_WARNING: phaseText += "Warning"; break;
        case PHASE_PRE_SHIELD: phaseText += "Pre-Shield"; break;
        case PHASE_SHIELD_ACTIVE: phaseText += "Active"; break;
    }
    ObjectSetString(0, "SHIELD_PHASE", OBJPROP_TEXT, phaseText);

    // Active Shield Details
    if(shield.isActive) {
        string typeText = "Type: ";
        if(shield.type == SHIELD_LONG) typeText += "LONG";
        else if(shield.type == SHIELD_SHORT) typeText += "SHORT";
        else typeText += "---";
        ObjectSetString(0, "SHIELD_TYPE", OBJPROP_TEXT, typeText);

        ObjectSetString(0, "SHIELD_LOT", OBJPROP_TEXT,
                        StringFormat("Lot: %.2f", shield.lot_size));

        color plColor = shield.current_pl >= 0 ? CLR_PROFIT : CLR_LOSS;
        ObjectSetString(0, "SHIELD_PL", OBJPROP_TEXT,
                        StringFormat("P/L: $%.2f", shield.current_pl));
        ObjectSetInteger(0, "SHIELD_PL", OBJPROP_COLOR, plColor);
    }
    else {
        ObjectSetString(0, "SHIELD_TYPE", OBJPROP_TEXT, "Type: ---");
        ObjectSetString(0, "SHIELD_LOT", OBJPROP_TEXT, "Lot: ---");
        ObjectSetString(0, "SHIELD_PL", OBJPROP_TEXT, "P/L: ---");
        ObjectSetInteger(0, "SHIELD_PL", OBJPROP_COLOR, clrGray);
    }
}

//+------------------------------------------------------------------+
//| Helper: Get ATR Value for Timeframe                              |
//+------------------------------------------------------------------+
double GetATRValue(ENUM_TIMEFRAMES tf) {
    int handle = iATR(_Symbol, tf, ATR_Period);
    if(handle == INVALID_HANDLE) return 0;

    double buffer[];
    ArraySetAsSeries(buffer, true);
    if(CopyBuffer(handle, 0, 0, 1, buffer) <= 0) return 0;

    IndicatorRelease(handle);
    return buffer[0];
}

//+------------------------------------------------------------------+
//| Helper: Get ADX Value for Timeframe                              |
//| bufferIndex: 0=ADX, 1=+DI, 2=-DI                                 |
//+------------------------------------------------------------------+
double GetADXValue(ENUM_TIMEFRAMES tf, int bufferIndex) {
    int handle = iADX(_Symbol, tf, 14);
    if(handle == INVALID_HANDLE) return 0;

    double buffer[];
    ArraySetAsSeries(buffer, true);
    if(CopyBuffer(handle, bufferIndex, 0, 1, buffer) <= 0) return 0;

    IndicatorRelease(handle);
    return buffer[0];
}

//+------------------------------------------------------------------+
//| Helper: Get ATR Condition Text                                   |
//+------------------------------------------------------------------+
string GetATRConditionText(double atrPips) {
    if(atrPips < 15) return "CALM";
    if(atrPips < 30) return "NORMAL";
    if(atrPips < 50) return "VOLATILE";
    return "EXTREME";
}

//+------------------------------------------------------------------+
//| Helper: Get ATR Condition Color                                  |
//+------------------------------------------------------------------+
color GetATRConditionColor(double atrPips) {
    if(atrPips < 15) return clrGray;
    if(atrPips < 30) return CLR_PROFIT;
    if(atrPips < 50) return CLR_NEUTRAL;
    return CLR_LOSS;
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
//| UI Helper Functions                                              |
//+------------------------------------------------------------------+
void DashLabel(string name, int x, int y, string text, color clr, int fontSize, string font = "Arial") {
    ObjectDelete(0, name);
    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    ObjectSetString(0, name, OBJPROP_FONT, font);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 10000);
}

void DashButton(string name, int x, int y, int width, int height, string text, color clr) {
    ObjectDelete(0, name);
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
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 10000);
}

void DashRectangle(string name, int x, int y, int width, int height, color clr) {
    ObjectDelete(0, name);
    ObjectCreate(0, name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, name, OBJPROP_YSIZE, height);
    ObjectSetInteger(0, name, OBJPROP_BGCOLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, name, OBJPROP_BORDER_COLOR, CLR_BORDER);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 9000);
}

//+------------------------------------------------------------------+
//| Remove Dashboard                                                 |
//+------------------------------------------------------------------+
void RemoveDashboard() {
    DeleteObjectsByPrefix("TITLE_");
    DeleteObjectsByPrefix("MODE_");
    DeleteObjectsByPrefix("LEFT_");
    DeleteObjectsByPrefix("RIGHT_");
    DeleteObjectsByPrefix("VOL_");
    DeleteObjectsByPrefix("ADX_");
    DeleteObjectsByPrefix("BTN_");
    DeleteObjectsByPrefix("LBL_");
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Draw All Grid Lines                                              |
//+------------------------------------------------------------------+
void DrawGridVisualization() {
    if(!ShowGridLines) return;

    DrawEntryPointLine();
    DrawRangeBoundaries();
    DrawGridALines();
    DrawGridBLines();

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| NOTE: DrawEntryPointLine() is defined in Utils/GridHelpers.mqh   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| NOTE: DrawRangeBoundaries() is defined in Utils/GridHelpers.mqh  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Draw Grid A Lines (Azure gradient)                               |
//+------------------------------------------------------------------+
void DrawGridALines() {
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_EntryPrices[i] > 0) {
            CreateGridLevelLine(GRID_A, ZONE_UPPER, i, gridA_Upper_EntryPrices[i]);
        }
    }
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Lower_EntryPrices[i] > 0) {
            CreateGridLevelLine(GRID_A, ZONE_LOWER, i, gridA_Lower_EntryPrices[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Draw Grid B Lines (Cyan gradient)                                |
//+------------------------------------------------------------------+
void DrawGridBLines() {
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_EntryPrices[i] > 0) {
            CreateGridLevelLine(GRID_B, ZONE_UPPER, i, gridB_Upper_EntryPrices[i]);
        }
    }
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Lower_EntryPrices[i] > 0) {
            CreateGridLevelLine(GRID_B, ZONE_LOWER, i, gridB_Lower_EntryPrices[i]);
        }
    }
}

//+------------------------------------------------------------------+
//| Get Gradient Color                                               |
//+------------------------------------------------------------------+
color GetGradientColor(color baseColor, int level, int maxLevels) {
    int r = (baseColor >> 16) & 0xFF;
    int g = (baseColor >> 8) & 0xFF;
    int b = baseColor & 0xFF;

    double factor = 1.0 - (level * 0.08);
    if(factor < 0.5) factor = 0.5;

    r = (int)(r * factor);
    g = (int)(g * factor);
    b = (int)(b * factor);

    return (color)((r << 16) | (g << 8) | b);
}

//+------------------------------------------------------------------+
//| NOTE: CreateGridLevelLine defined in Utils/GridHelpers.mqh       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| NOTE: DeleteAllGridObjects() is defined in Utils/GridHelpers.mqh |
//+------------------------------------------------------------------+

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
//| NOTE: CalculateTotalExposure() defined in Trading/PositionMonitor|
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| NOTE: GetSpreadPips is defined in Utils/Helpers.mqh              |
//+------------------------------------------------------------------+
