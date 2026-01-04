//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                     SUGAMARA RIBELLE v8.0 - Dashboard Display    |
//|                                                                  |
//|  Visual dashboard for Perfect Cascade (Grid A=BUY, B=SELL)       |
//|  Color Scheme: DUNE/ARRAKIS DESERT THEME - 2 COLUMN LAYOUT       |
//|                                                                  |
//|  v8.0: Perfect Cascade + Smart Reopen                            |
//+------------------------------------------------------------------+
#property copyright "Sugamara Ribelle (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| DASHBOARD PERSISTENCE SYSTEM                                     |
//| Auto-verifies and recreates dashboard objects on restart         |
//+------------------------------------------------------------------+
bool g_dashboardInitialized = false;
datetime g_lastDashboardCheck = 0;
const int DASHBOARD_CHECK_INTERVAL = 5;  // Seconds between checks

//+------------------------------------------------------------------+
//| DUNE/ARRAKIS DESERT COLOR SCHEME v5.1                            |
//| "The spice must flow" - Inspired by Dune (2021/2024)             |
//|                                                                  |
//| Palette: Desert sands, Spice Orange, Fremen Blue, Sandworm Gold  |
//+------------------------------------------------------------------+
// NOTE: Non usare #define con variabili input (evaluate at compile-time!)

// Background Colors (Arrakis Night - Deep Desert)
#define CLR_BG_DARK       C'35,28,20'        // Deep desert night (charcoal brown)
#define CLR_BG_MEDIUM     C'45,35,25'        // Desert dusk (warm brown)
#define CLR_BG_LIGHT      C'60,48,35'        // Desert twilight (ochre brown)
#define CLR_BORDER        C'120,90,50'       // Sand border (tan)

// Dashboard Colors (Spice Melange Theme)
#define CLR_DASH_BG       C'50,40,28'        // Spice den background
#define CLR_DASH_TEXT     C'230,200,150'     // Sand text (warm cream)
#define CLR_DASH_ACCENT   C'255,180,80'      // Spice orange accent

// Getter functions to use actual input values at runtime
color GetThemeChartBackground() { return THEME_CHART_BACKGROUND; }
color GetThemeDashboardBG() { return THEME_DASHBOARD_BG; }
color GetThemeDashboardText() { return THEME_DASHBOARD_TEXT; }
color GetThemeDashboardAccent() { return THEME_DASHBOARD_ACCENT; }

// Text Colors (Desert Sand Gradient - Light to Dark)
#define CLR_SAND_1        C'255,220,170'     // Brightest sand (titles)
#define CLR_SAND_2        C'220,185,140'     // Medium sand (sections)
#define CLR_SAND_3        C'180,150,110'     // Darker sand (labels)
#define CLR_SAND_4        C'140,115,80'      // Darkest sand (inactive)

// Accent Colors (Spice & Fremen)
#define CLR_SPICE         C'255,165,0'       // Spice melange orange (v5.4b: più acceso)
#define CLR_FREMEN_BLUE   C'80,140,200'      // Fremen blue eyes
#define CLR_WHITE         clrWhite           // White text
#define CLR_SILVER        C'200,190,170'     // Desert silver (warm gray)
#define CLR_GOLD          C'255,215,0'       // Sandworm gold (v5.4b: più luminoso)

// Status Colors (Desert Palette)
#define CLR_PROFIT        C'120,200,80'      // Oasis green (muted)
#define CLR_LOSS          C'220,80,60'       // Desert sun red
#define CLR_NEUTRAL       C'255,215,0'       // Warning gold (v5.4b: più luminoso)
#define CLR_ACTIVE        C'100,180,220'     // Active Fremen blue

// Grid Colors (Desert Variants - BUY=Gold, SELL=Bronze)
#define CLR_GRID_A        C'255,180,80'      // Grid A - Spice Gold (BUY)
#define CLR_GRID_B        C'200,140,80'      // Grid B - Desert Bronze (SELL)

// Mode Colors (Arrakis Modes)
#define CLR_MODE_PURE     C'180,160,120'     // Sandstone for PURE
#define CLR_MODE_CASCADE  C'255,160,60'      // Spice Orange for CASCADE
// CLR_MODE_RANGEBOX removed in v5.2 (RANGEBOX mode deprecated)

// Panel Background Colors (Desert Night Theme)
#define CLR_PANEL_GRIDA   C'45,38,28'        // Grid A panel (warm brown - BUY)
#define CLR_PANEL_GRIDB   C'40,35,28'        // Grid B panel (cool brown - SELL)
#define CLR_PANEL_BUTTONS C'55,45,32'        // Buttons panel (spice brown)
#define CLR_PANEL_PERF    C'38,32,24'        // Performance panel (deep night)

// Legacy aliases for compatibility
#define CLR_AZURE_1       CLR_SAND_1
#define CLR_AZURE_2       CLR_SAND_2
#define CLR_AZURE_3       CLR_SAND_3
#define CLR_AZURE_4       CLR_SAND_4
#define CLR_CYAN          CLR_SPICE
#define CLR_TEAL          CLR_FREMEN_BLUE

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
        // v5.8 FIX: COP_ResetDaily() RIMOSSO - profitti devono accumularsi
        // Il reset avviene solo al cambio giorno (COP_IsNewDay) o target raggiunto
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
    Print("  SUGAMARA RIBELLE v5.1 - CASCADE SOVRAPPOSTO - DUNE THEME          ");
    Print("  \"The Spice Must Flow\" - Grid Trading System 24/7                 ");
    Print("═══════════════════════════════════════════════════════════════════");

    // Check if dashboard already exists and is complete
    if(VerifyDashboardExists()) {
        Print("Dashboard already exists - verifying control buttons...");

        // v5.4: Verify and recreate control buttons if missing
        if(!VerifyControlButtonsExist()) {
            Print("Control buttons missing - recreating...");
            InitializeControlButtons(g_leftX, g_btnY, g_colWidth);
        }

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
    CreateShieldPanel();
    CreateGridLegendPanel();
    CreateCOPPanel();  // v5.1: Close On Profit Panel
    CreateTrailingGridPanel();  // v5.3: Trailing Grid Panel

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
        "SHIELD_PANEL",
        "GRID_LEGEND_PANEL"
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
//| Verify Control Buttons Exist (v5.4)                               |
//| Fix for buttons disappearing after parameter changes              |
//+------------------------------------------------------------------+
bool VerifyControlButtonsExist() {
    // Check for START and CLOSE buttons
    bool startExists = ObjectFind(0, "SUGAMARA_BTN_START") >= 0;
    bool closeExists = ObjectFind(0, "SUGAMARA_BTN_CLOSEALL") >= 0;

    if(!startExists || !closeExists) {
        PrintFormat("Button verification: START=%s, CLOSE=%s",
                    startExists ? "OK" : "MISSING",
                    closeExists ? "OK" : "MISSING");
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
    CreateShieldPanel();
    CreateGridLegendPanel();
    CreateCOPPanel();  // v5.1: Close On Profit Panel
    CreateTrailingGridPanel();  // v5.3: Trailing Grid Panel

    // v4.4: Control buttons ALWAYS active
    // FIX v4.5: Corrected parameter order (startX, startY, panelWidth)
    InitializeControlButtons(g_leftX, g_btnY, g_colWidth);

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
    // TITLE PANEL (Full Width) - DUNE THEME
    //═══════════════════════════════════════════════════════════════
    int titleHeight = 70;
    DashRectangle("TITLE_PANEL", x, y, totalWidth, titleHeight, CLR_BG_DARK);
    // v5.9.5: Titolo GIALLO, sottotitolo ARANCIONE SCURO
    DashLabel("TITLE_MAIN", x + totalWidth/2 - 80, y + 12, "SUGAMARA v8.0", clrYellow, 20, "Arial Black");
    DashLabel("TITLE_SUB", x + totalWidth/2 - 80, y + 42, "The Spice Must Flow", C'255,100,0', 10, "Arial Bold");
    y += titleHeight;

    //═══════════════════════════════════════════════════════════════
    // MODE & SYMBOL PANEL (Full Width)
    //═══════════════════════════════════════════════════════════════
    int modeHeight = 55;
    DashRectangle("MODE_PANEL", x, y, totalWidth, modeHeight, CLR_BG_DARK);
    // v5.9.3: Lato sinistro - Mode e Symbol
    DashLabel("MODE_INFO1", x + 15, y + 8, "Mode: ---", CLR_CYAN, 9);
    DashLabel("MODE_INFO2", x + 15, y + 24, "Symbol: --- | Spread: ---", CLR_SILVER, 8);
    DashLabel("MODE_INFO3", x + 15, y + 38, "Pair: ---", CLR_AZURE_2, 8);
    // v5.9.3: Lato destro - Spacing e Levels (sostituisce ATR)
    DashLabel("MODE_SPACING", x + 350, y + 8, "Spacing: --- pips", CLR_CYAN, 9);
    DashLabel("MODE_LEVELS", x + 350, y + 24, "Levels: ---", CLR_CYAN, 9);
    y += modeHeight;

    //═══════════════════════════════════════════════════════════════
    // LEFT COLUMN START
    //═══════════════════════════════════════════════════════════════
    int leftX = x;
    int leftY = y;

    //--- GRID A PANEL (SOLO BUY - Spice Harvesters) ---
    int gridAHeight = 180;
    DashRectangle("LEFT_GRIDA_PANEL", leftX, leftY, colWidth, gridAHeight, CLR_PANEL_GRIDA);

    int ay = leftY + 8;
    DashLabel("LEFT_GRIDA_TITLE", leftX + 10, ay, "GRID A - SOLO BUY", CLR_GRID_A, 11, "Arial Bold");
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
    int buttonsHeight = 200;  // v5.8: Increased +30px to balance Grid Zero panel
    DashRectangle("LEFT_BUTTONS_PANEL", leftX, leftY, colWidth, buttonsHeight, CLR_PANEL_BUTTONS);
    g_btnY = leftY;
    CreateControlButtons(leftY, leftX, colWidth);

    leftY += buttonsHeight;

    //═══════════════════════════════════════════════════════════════
    // RIGHT COLUMN START
    //═══════════════════════════════════════════════════════════════
    int rightX = x + colWidth;
    int rightY = y;

    //--- GRID B PANEL (SOLO SELL - Sandworm Riders) ---
    int gridBHeight = 180;
    DashRectangle("RIGHT_GRIDB_PANEL", rightX, rightY, colWidth, gridBHeight, CLR_PANEL_GRIDB);

    int by = rightY + 8;
    DashLabel("RIGHT_GRIDB_TITLE", rightX + 10, by, "GRID B - SOLO SELL", CLR_GRID_B, 11, "Arial Bold");
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

    // v5.2: RANGEBOX panel removed (mode deprecated)
    // v5.9.3: GRID INFO panel removed (info moved to Mode row)

    //--- PERFORMANCE PANEL (v5.9.3: moved up, no more GRID INFO above) ---
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

    //--- GRID COUNTER PANEL (v5.9.3) ---
    int counterHeight = 75;
    DashRectangle("RIGHT_COUNTER_PANEL", rightX, rightY, colWidth, counterHeight, C'30,35,45');

    int cy = rightY + 6;
    DashLabel("RIGHT_COUNTER_TITLE", rightX + colWidth/2 - 45, cy, "GRID COUNTER", CLR_GOLD, 9, "Arial Bold");
    cy += 18;
    // Grid A contatori
    DashLabel("COUNTER_A_CLOSED", rightX + 10, cy, "A Closed: 0", CLR_GRID_A, 8);
    DashLabel("COUNTER_A_PENDING", rightX + 10, cy + 14, "A Pending: 0", CLR_GRID_A, 8);
    // Grid B contatori
    DashLabel("COUNTER_B_CLOSED", rightX + 110, cy, "B Closed: 0", CLR_GRID_B, 8);
    DashLabel("COUNTER_B_PENDING", rightX + 110, cy + 14, "B Pending: 0", CLR_GRID_B, 8);
    // Grid Zero contatori
    DashLabel("COUNTER_ZERO", rightX + 210, cy, "Zero: 0/0", CLR_SILVER, 8);
    // Totale
    DashLabel("COUNTER_TOTAL", rightX + 210, cy + 14, "Tot: 0/0", CLR_WHITE, 8);

    rightY += counterHeight;

    //--- GRID ZERO PANEL (v5.8 + v5.9.4 legenda colore) ---
    if(Enable_GridZero) {
        int gzHeight = 55;
        DashRectangle("GZ_PANEL", rightX, rightY, colWidth, gzHeight, C'35,40,30');

        int gz = rightY + 6;
        DashLabel("GZ_TITLE", rightX + 10, gz, "GRID ZERO", CLR_GOLD, 9, "Arial Bold");
        // v5.9.4: Quadratino legenda colore chartreuse
        DashRectangle("GZ_COLOR_LEGEND", rightX + 85, gz + 2, 10, 10, clrChartreuse);
        DashLabel("GZ_STATUS", rightX + 100, gz, "Status: ---", clrGray, 8);
        DashLabel("GZ_BIAS", rightX + 200, gz, "Bias: ---", clrGray, 8);
        gz += 18;
        DashLabel("GZ_STOP", rightX + 10, gz, "STOP: ---", clrGray, 8);
        DashLabel("GZ_LIMIT", rightX + 100, gz, "LIMIT: ---", clrGray, 8);
        DashLabel("GZ_CYCLES", rightX + 200, gz, "Cycles: 0", clrGray, 8);

        rightY += gzHeight;
    }

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

    // v4.4: Control Buttons ALWAYS active (Simplified: START + CLOSE only)
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

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Create Volatility/ATR Monitor Panel (Right Side)                 |
//| v5.9: Compacted to 55px (was 160px) - 3 rows max                 |
//+------------------------------------------------------------------+
void CreateVolatilityPanel() {
    int volX = Dashboard_X + TOTAL_WIDTH + 10;
    int volY = Dashboard_Y;
    int volWidth = 175;
    int volHeight = 55;  // v5.9: Reduced from 160 to 55

    DashRectangle("VOL_PANEL", volX, volY, volWidth, volHeight, CLR_BG_DARK);

    int ly = volY + 6;
    DashLabel("VOL_TITLE", volX + 10, ly, "ATR MONITOR", CLR_GOLD, 9, "Arial Bold");
    ly += 18;

    // v5.9: Compact single line for M5 and H1
    DashLabel("VOL_ATR_LINE", volX + 10, ly, "M5: --- | H1: ---", CLR_AZURE_1, 8);
    ly += 16;

    // Spacing + Condition on same line
    DashLabel("VOL_SPACING_STATUS", volX + 10, ly, "Spacing: --- (Normal)", CLR_CYAN, 8);

    Print("SUCCESS: Volatility Panel created (v5.9 compact)");
}

//+------------------------------------------------------------------+
//| Create Shield Panel (Right Side)                                  |
//| v5.8: Expanded with PreAlert/Shield levels and distance           |
//| v5.9: Moved up (ATR Monitor reduced from 160 to 55px)             |
//+------------------------------------------------------------------+
void CreateShieldPanel() {
    int shieldX = Dashboard_X + TOTAL_WIDTH + 10;
    int shieldY = Dashboard_Y + 60;  // v5.9: Subito sotto ATR Monitor (55 + 5 gap)
    int shieldWidth = 175;
    int shieldHeight = 215;  // v5.8: Expanded from 140 to 215 for new level fields

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
    ly += 16;

    // v5.8: Shield Levels section
    DashLabel("SHIELD_SEP2", shieldX + 10, ly, "--- LEVELS ---", clrGray, 7);
    ly += 14;

    // PreAlert and Shield levels
    DashLabel("SHIELD_PREALERT_UP", shieldX + 10, ly, "PreAlert↑: ------", CLR_NEUTRAL, 7);
    ly += 13;
    DashLabel("SHIELD_PREALERT_DN", shieldX + 10, ly, "PreAlert↓: ------", CLR_NEUTRAL, 7);
    ly += 13;
    DashLabel("SHIELD_BREAKOUT_UP", shieldX + 10, ly, "Shield↑:   ------", CLR_LOSS, 7);
    ly += 13;
    DashLabel("SHIELD_BREAKOUT_DN", shieldX + 10, ly, "Shield↓:   ------", CLR_LOSS, 7);
    ly += 13;
    DashLabel("SHIELD_DISTANCE", shieldX + 10, ly, "Distance:  --- pips", CLR_AZURE_1, 7);
    ly += 16;

    // Active Shield Info
    DashLabel("SHIELD_TYPE", shieldX + 10, ly, "Type: ---", clrGray, 8);
    ly += 14;
    DashLabel("SHIELD_LOT", shieldX + 10, ly, "Lot: ---", clrGray, 8);
    ly += 14;
    DashLabel("SHIELD_PL", shieldX + 10, ly, "P/L: ---", clrGray, 9, "Arial Bold");

    Print("SUCCESS: Shield Panel created (expanded with levels)");
}

//+------------------------------------------------------------------+
//| Create Grid Legend Panel (Under Performance - Right Column)       |
//| v5.8: Moved under Performance, horizontal layout 2x2              |
//+------------------------------------------------------------------+
void CreateGridLegendPanel() {
    // v5.8: Position under Performance (and Grid Zero if enabled) in right column
    int legendX = Dashboard_X + PANEL_WIDTH;  // Right column X
    // Calculate Y: After GridB (180) + GridInfo (55) + Performance (190) + GridZero (55 if enabled)
    int legendY = Dashboard_Y + 180 + 55 + 190;
    if(Enable_GridZero) legendY += 55;        // Add Grid Zero panel height
    int legendWidth = PANEL_WIDTH;            // Same width as Performance (315)
    int legendHeight = 55;                    // Compact height for 2 rows

    DashRectangle("GRID_LEGEND_PANEL", legendX, legendY, legendWidth, legendHeight, CLR_BG_DARK);

    int ly = legendY + 6;
    DashLabel("LEGEND_TITLE", legendX + legendWidth/2 - 35, ly, "GRID LINES", CLR_GOLD, 8, "Arial Bold");
    ly += 18;

    // v5.8: Horizontal layout - 2 columns x 2 rows
    int col1 = legendX + 8;
    int col2 = legendX + legendWidth/2 + 5;

    // Row 1
    DashLabel("LEGEND_BL", col1, ly, "■ BUY LMT (GA↑)", COLOR_GRIDLINE_BUY_LIMIT, 7);
    DashLabel("LEGEND_SS", col2, ly, "■ SELL STP (GA↓)", COLOR_GRIDLINE_SELL_STOP, 7);
    ly += 14;

    // Row 2
    DashLabel("LEGEND_SL", col1, ly, "■ SELL LMT (GB↑)", COLOR_GRIDLINE_SELL_LIMIT, 7);
    DashLabel("LEGEND_BS", col2, ly, "■ BUY STP (GB↓)", COLOR_GRIDLINE_BUY_STOP, 7);

    Print("SUCCESS: Grid Legend Panel created (under Performance)");
}

//+------------------------------------------------------------------+
//| Create COP Panel (v5.1 - Close On Profit)                        |
//| v5.9: Moved up (ATR Monitor reduced)                              |
//+------------------------------------------------------------------+
void CreateCOPPanel() {
    if(!Enable_CloseOnProfit) return;

    int copX = Dashboard_X + TOTAL_WIDTH + 10;
    int copY = Dashboard_Y + 280;  // v5.9: Subito sotto Shield (60 + 215 + 5 gap)
    int copWidth = 175;
    int copHeight = 155;  // Increased for new fields

    DashRectangle("COP_PANEL", copX, copY, copWidth, copHeight, C'28,35,28');

    int ly = copY + 8;
    DashLabel("COP_TITLE", copX + 10, ly, "💵 CLOSE ON PROFIT", CLR_GOLD, 9, "Arial Bold");
    ly += 20;
    DashLabel("COP_SEPARATOR", copX + 10, ly, "------------------------", clrGray, 7);
    ly += 15;

    // Net Profit
    DashLabel("COP_NET", copX + 10, ly, "Net: $0.00 / $50.00", CLR_AZURE_1, 8);
    ly += 16;

    // Progress Bar (text-based)
    DashLabel("COP_PROGRESS", copX + 10, ly, "░░░░░░░░░░░░░░░░ 0%", clrGray, 8);
    ly += 16;

    // Status and Remaining (NEW)
    DashLabel("COP_STATUS", copX + 10, ly, "Status: ACTIVE", CLR_PROFIT, 8);
    ly += 16;
    DashLabel("COP_MISSING", copX + 10, ly, "Manca: $50.00", CLR_AZURE_1, 8);
    ly += 18;

    // Details
    DashLabel("COP_REAL", copX + 10, ly, "Real: $0.00", clrGray, 8);
    ly += 16;
    DashLabel("COP_FLOAT", copX + 10, ly, "Float: $0.00", clrGray, 8);
    ly += 16;
    DashLabel("COP_COMM", copX + 10, ly, "Comm: -$0.00", clrGray, 8);

    Print("SUCCESS: COP Panel created (enhanced v5.2)");
}

//+------------------------------------------------------------------+
//| Create Trailing Grid Panel (v5.3)                                 |
//| v5.9: Moved up (ATR Monitor reduced)                              |
//+------------------------------------------------------------------+
void CreateTrailingGridPanel() {
    if(!Enable_TrailingGrid) return;

    int tgX = Dashboard_X + TOTAL_WIDTH + 10;
    int tgY = Dashboard_Y + 440;  // v5.9: Sotto COP panel (280 + 155 + 5 gap)
    int tgWidth = 175;
    int tgHeight = 130;

    DashRectangle("TG_PANEL", tgX, tgY, tgWidth, tgHeight, C'30,35,40');

    int ly = tgY + 8;
    DashLabel("TG_TITLE", tgX + 10, ly, "TRAILING GRID", CLR_GOLD, 9, "Arial Bold");
    ly += 20;
    DashLabel("TG_SEPARATOR", tgX + 10, ly, "------------------------", clrGray, 7);
    ly += 15;

    // Status
    DashLabel("TG_STATUS", tgX + 10, ly, "Status: ACTIVE", CLR_PROFIT, 8);
    ly += 18;

    // UPPER ADDED / REMOVED
    DashLabel("TG_UPPER_ADD", tgX + 10, ly, "Upper Added: 0", CLR_GRID_A, 8);
    ly += 15;
    DashLabel("TG_UPPER_REM", tgX + 10, ly, "Upper Removed: 0", CLR_LOSS, 8);
    ly += 18;

    // LOWER ADDED / REMOVED
    DashLabel("TG_LOWER_ADD", tgX + 10, ly, "Lower Added: 0", CLR_GRID_A, 8);
    ly += 15;
    DashLabel("TG_LOWER_REM", tgX + 10, ly, "Lower Removed: 0", CLR_LOSS, 8);

    Print("SUCCESS: Trailing Grid Panel created (v5.3)");
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
    // v5.2: UpdateRangeBoxSection removed (mode deprecated)
    // v5.9.3: UpdateGridInfoSection removed (info moved to Mode row)
    UpdatePerformanceSection();
    UpdateGridCounterSection();  // v5.9.3: Grid Counter Section
    UpdateGridZeroSection();  // v5.8: Grid Zero Section
    UpdateVolatilityPanel();
    UpdateShieldSection();
    UpdateCOPSection();  // v5.1: Close On Profit Section
    UpdateTrailingGridSection();  // v5.3: Trailing Grid Section

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

    // Line 3: Pair only (v5.9.3: Grids e Spacing spostati a destra)
    string pairName = GetPairDisplayName(SelectedPair);
    ObjectSetString(0, "MODE_INFO3", OBJPROP_TEXT, "Pair: " + pairName);

    // v5.9.3: Right side - Spacing e Levels (sostituisce ATR)
    string spacingText = StringFormat("Spacing: %.1f pips", currentSpacing_Pips);
    ObjectSetString(0, "MODE_SPACING", OBJPROP_TEXT, spacingText);

    string levelsText = StringFormat("Levels: %d", GridLevelsPerSide);
    ObjectSetString(0, "MODE_LEVELS", OBJPROP_TEXT, levelsText);
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

// v5.2: UpdateRangeBoxSection() removed (RANGEBOX mode deprecated)

//+------------------------------------------------------------------+
//| Update Grid Counter Section (v5.9.3)                              |
//+------------------------------------------------------------------+
void UpdateGridCounterSection() {
    // Grid A counters
    ObjectSetString(0, "COUNTER_A_CLOSED", OBJPROP_TEXT,
                    StringFormat("A Closed: %d", g_gridA_ClosedCount));
    ObjectSetString(0, "COUNTER_A_PENDING", OBJPROP_TEXT,
                    StringFormat("A Pending: %d", g_gridA_PendingCount));

    // Grid B counters
    ObjectSetString(0, "COUNTER_B_CLOSED", OBJPROP_TEXT,
                    StringFormat("B Closed: %d", g_gridB_ClosedCount));
    ObjectSetString(0, "COUNTER_B_PENDING", OBJPROP_TEXT,
                    StringFormat("B Pending: %d", g_gridB_PendingCount));

    // Grid Zero counters (closed/pending)
    ObjectSetString(0, "COUNTER_ZERO", OBJPROP_TEXT,
                    StringFormat("Zero: %d/%d", g_gridZero_ClosedCount, g_gridZero_PendingCount));

    // Totals
    int totalClosed = g_gridA_ClosedCount + g_gridB_ClosedCount + g_gridZero_ClosedCount;
    int totalPending = g_gridA_PendingCount + g_gridB_PendingCount + g_gridZero_PendingCount;
    ObjectSetString(0, "COUNTER_TOTAL", OBJPROP_TEXT,
                    StringFormat("Tot: %d/%d", totalClosed, totalPending));

    // Colore: verde se closed == pending (bilanciato), rosso se diversi
    color totColor = (totalClosed == totalPending) ? CLR_PROFIT : CLR_LOSS;
    ObjectSetInteger(0, "COUNTER_TOTAL", OBJPROP_COLOR, totColor);
}

//+------------------------------------------------------------------+
//| Update Performance Section                                       |
//+------------------------------------------------------------------+
void UpdatePerformanceSection() {
    // v5.3: P/L per singola pair, non globale
    double totalPL = GetCurrentPairRealizedProfit() + GetTotalOpenProfit();
    double equity = GetEquity();
    double balance = GetBalance();
    double dd = GetCurrentDrawdown();

    // v5.3: Win rate e trades per singola pair
    int pairWins = GetCurrentPairWins();
    int pairLosses = GetCurrentPairLosses();
    int trades = pairWins + pairLosses;
    double winRate = trades > 0 ? (pairWins * 100.0 / trades) : 0;

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
//| Update Grid Zero Section (v5.8)                                   |
//+------------------------------------------------------------------+
void UpdateGridZeroSection() {
    if(!Enable_GridZero) return;

    // Status
    string statusText = "Status: ";
    color statusColor = clrGray;

    if(!g_gridZeroInserted) {
        statusText += "WAITING";
        statusColor = CLR_AZURE_3;
    } else if(g_gridZero_StopStatus == ORDER_PENDING ||
              g_gridZero_LimitStatus == ORDER_PENDING) {
        statusText += "ACTIVE";
        statusColor = CLR_PROFIT;
    } else if(g_gridZero_StopStatus == ORDER_FILLED ||
              g_gridZero_LimitStatus == ORDER_FILLED) {
        statusText += "IN TRADE";
        statusColor = CLR_ACTIVE;
    } else {
        statusText += "CYCLING";
        statusColor = CLR_NEUTRAL;
    }
    ObjectSetString(0, "GZ_STATUS", OBJPROP_TEXT, statusText);
    ObjectSetInteger(0, "GZ_STATUS", OBJPROP_COLOR, statusColor);

    // Bias
    string biasText = "Bias: ";
    color biasColor = clrGray;

    if(g_gridZeroBiasUp) {
        biasText += "BULLISH";
        biasColor = CLR_GRID_A;
    } else if(g_gridZeroBiasDown) {
        biasText += "BEARISH";
        biasColor = CLR_GRID_B;
    } else {
        biasText += "NONE";
    }
    ObjectSetString(0, "GZ_BIAS", OBJPROP_TEXT, biasText);
    ObjectSetInteger(0, "GZ_BIAS", OBJPROP_COLOR, biasColor);

    // STOP Status
    string stopText = "STOP: " + GetOrderStatusName(g_gridZero_StopStatus);
    ObjectSetString(0, "GZ_STOP", OBJPROP_TEXT, stopText);

    // LIMIT Status
    string limitText = "LIMIT: " + GetOrderStatusName(g_gridZero_LimitStatus);
    ObjectSetString(0, "GZ_LIMIT", OBJPROP_TEXT, limitText);

    // Cycles
    int totalCycles = g_gridZero_StopCycles + g_gridZero_LimitCycles;
    ObjectSetString(0, "GZ_CYCLES", OBJPROP_TEXT, StringFormat("Cycles: %d", totalCycles));
}

//+------------------------------------------------------------------+
//| Update Volatility Panel - v5.9 Compact Version                   |
//+------------------------------------------------------------------+
void UpdateVolatilityPanel() {
    // Get ATR values
    double atrM5 = GetATRValue(PERIOD_M5);
    double atrM5Pips = atrM5 / symbolPoint / 10.0;
    double atrH1 = GetATRValue(PERIOD_H1);
    double atrH1Pips = atrH1 / symbolPoint / 10.0;

    // v5.9: Compact single line for M5 and H1 ATR values
    ObjectSetString(0, "VOL_ATR_LINE", OBJPROP_TEXT,
                    StringFormat("M5: %.1f | H1: %.1f", atrM5Pips, atrH1Pips));

    // Color based on higher ATR condition
    double maxAtr = MathMax(atrM5Pips, atrH1Pips);
    color atrColor = GetATRConditionColor(maxAtr);
    ObjectSetInteger(0, "VOL_ATR_LINE", OBJPROP_COLOR, atrColor);

    // v5.9: Spacing + Condition on same line
    string condText = GetATRConditionText(atrM5Pips);  // Use M5 for condition
    ObjectSetString(0, "VOL_SPACING_STATUS", OBJPROP_TEXT,
                    StringFormat("Spacing: %.1f (%s)", currentSpacing_Pips, condText));
    ObjectSetInteger(0, "VOL_SPACING_STATUS", OBJPROP_COLOR, GetATRConditionColor(atrM5Pips));
}

//+------------------------------------------------------------------+
//| Update Shield Section                                             |
//+------------------------------------------------------------------+
void UpdateShieldSection() {
    // Shield Mode
    string modeText = "Mode: ";
    // v8.0: Rimosso check IsCascadeOverlapMode() - Shield sempre disponibile

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

    // v5.8: Shield Levels Update
    int priceDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    // PreAlert Levels (Warning Zone)
    if(szWarningZoneUp > 0) {
        ObjectSetString(0, "SHIELD_PREALERT_UP", OBJPROP_TEXT,
                        StringFormat("PreAlert↑: %s", DoubleToString(szWarningZoneUp, priceDigits)));
    } else {
        ObjectSetString(0, "SHIELD_PREALERT_UP", OBJPROP_TEXT, "PreAlert↑: ------");
    }

    if(szWarningZoneDown > 0) {
        ObjectSetString(0, "SHIELD_PREALERT_DN", OBJPROP_TEXT,
                        StringFormat("PreAlert↓: %s", DoubleToString(szWarningZoneDown, priceDigits)));
    } else {
        ObjectSetString(0, "SHIELD_PREALERT_DN", OBJPROP_TEXT, "PreAlert↓: ------");
    }

    // Breakout Levels (Shield Trigger)
    if(szBreakoutUp > 0) {
        ObjectSetString(0, "SHIELD_BREAKOUT_UP", OBJPROP_TEXT,
                        StringFormat("Shield↑:   %s", DoubleToString(szBreakoutUp, priceDigits)));
    } else {
        ObjectSetString(0, "SHIELD_BREAKOUT_UP", OBJPROP_TEXT, "Shield↑:   ------");
    }

    if(szBreakoutDown > 0) {
        ObjectSetString(0, "SHIELD_BREAKOUT_DN", OBJPROP_TEXT,
                        StringFormat("Shield↓:   %s", DoubleToString(szBreakoutDown, priceDigits)));
    } else {
        ObjectSetString(0, "SHIELD_BREAKOUT_DN", OBJPROP_TEXT, "Shield↓:   ------");
    }

    // Distance to nearest breakout
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double distanceUp = (szBreakoutUp > 0) ? PointsToPips(szBreakoutUp - currentPrice) : 0;
    double distanceDown = (szBreakoutDown > 0) ? PointsToPips(currentPrice - szBreakoutDown) : 0;
    double nearestDistance = 0;

    if(distanceUp > 0 && distanceDown > 0) {
        nearestDistance = MathMin(distanceUp, distanceDown);
    } else if(distanceUp > 0) {
        nearestDistance = distanceUp;
    } else if(distanceDown > 0) {
        nearestDistance = distanceDown;
    }

    if(nearestDistance > 0) {
        color distColor = (nearestDistance < 20) ? CLR_NEUTRAL : CLR_AZURE_1;
        ObjectSetString(0, "SHIELD_DISTANCE", OBJPROP_TEXT,
                        StringFormat("Distance:  %.1f pips", nearestDistance));
        ObjectSetInteger(0, "SHIELD_DISTANCE", OBJPROP_COLOR, distColor);
    } else {
        ObjectSetString(0, "SHIELD_DISTANCE", OBJPROP_TEXT, "Distance:  --- pips");
        ObjectSetInteger(0, "SHIELD_DISTANCE", OBJPROP_COLOR, clrGray);
    }

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
//| Update COP Section (v5.1)                                         |
//+------------------------------------------------------------------+
void UpdateCOPSection() {
    if(!Enable_CloseOnProfit) return;

    // Net Profit
    double netProfit = COP_GetNetProfit();
    color netColor = netProfit >= 0 ? CLR_PROFIT : CLR_LOSS;
    ObjectSetString(0, "COP_NET", OBJPROP_TEXT,
                    StringFormat("Net: $%.2f / $%.2f", netProfit, COP_DailyTarget_USD));
    ObjectSetInteger(0, "COP_NET", OBJPROP_COLOR, netColor);

    // Progress Bar
    double progress = COP_GetProgressPercent();
    int filledBars = (int)(progress / 6.25);  // 16 bars total
    if(filledBars > 16) filledBars = 16;

    string progressBar = "";
    for(int i = 0; i < 16; i++) {
        progressBar += (i < filledBars) ? "█" : "░";
    }

    color progressColor = clrGray;
    if(progress >= 100) progressColor = CLR_PROFIT;
    else if(progress >= 75) progressColor = CLR_GOLD;
    else if(progress >= 50) progressColor = CLR_NEUTRAL;

    ObjectSetString(0, "COP_PROGRESS", OBJPROP_TEXT,
                    StringFormat("%s %.0f%%", progressBar, progress));
    ObjectSetInteger(0, "COP_PROGRESS", OBJPROP_COLOR, progressColor);

    // Status (NEW v5.2)
    string statusText = "ACTIVE";
    color statusColor = CLR_PROFIT;
    if(COP_IsTargetReached()) {
        statusText = "TARGET REACHED";
        statusColor = CLR_GOLD;
    } else if(systemState == STATE_PAUSED) {
        statusText = "PAUSED";
        statusColor = CLR_NEUTRAL;
    } else if(systemState == STATE_IDLE) {
        statusText = "IDLE";
        statusColor = clrGray;
    }
    ObjectSetString(0, "COP_STATUS", OBJPROP_TEXT, "Status: " + statusText);
    ObjectSetInteger(0, "COP_STATUS", OBJPROP_COLOR, statusColor);

    // Missing amount (NEW v5.2)
    double missingAmount = COP_DailyTarget_USD - netProfit;
    if(missingAmount < 0) missingAmount = 0;
    ObjectSetString(0, "COP_MISSING", OBJPROP_TEXT,
                    StringFormat("Manca: $%.2f", missingAmount));
    ObjectSetInteger(0, "COP_MISSING", OBJPROP_COLOR,
                    missingAmount > 0 ? CLR_AZURE_1 : CLR_PROFIT);

    // Details
    ObjectSetString(0, "COP_REAL", OBJPROP_TEXT,
                    StringFormat("Real: $%.2f", cop_RealizedProfit));
    ObjectSetInteger(0, "COP_REAL", OBJPROP_COLOR,
                    cop_RealizedProfit >= 0 ? CLR_PROFIT : CLR_LOSS);

    ObjectSetString(0, "COP_FLOAT", OBJPROP_TEXT,
                    StringFormat("Float: $%.2f", cop_FloatingProfit));
    ObjectSetInteger(0, "COP_FLOAT", OBJPROP_COLOR,
                    cop_FloatingProfit >= 0 ? CLR_PROFIT : CLR_LOSS);

    ObjectSetString(0, "COP_COMM", OBJPROP_TEXT,
                    StringFormat("Comm: -$%.2f", cop_TotalCommissions));
    ObjectSetInteger(0, "COP_COMM", OBJPROP_COLOR, clrGray);

    // Status (if target reached)
    if(COP_IsTargetReached()) {
        ObjectSetString(0, "COP_TITLE", OBJPROP_TEXT, "TARGET REACHED!");
        ObjectSetInteger(0, "COP_TITLE", OBJPROP_COLOR, CLR_PROFIT);
    } else {
        ObjectSetString(0, "COP_TITLE", OBJPROP_TEXT, "CLOSE ON PROFIT");
        ObjectSetInteger(0, "COP_TITLE", OBJPROP_COLOR, CLR_GOLD);
    }
}

//+------------------------------------------------------------------+
//| Update Trailing Grid Section (v5.3)                               |
//+------------------------------------------------------------------+
void UpdateTrailingGridSection() {
    if(!Enable_TrailingGrid) return;

    // Status
    string statusText = "Status: ";
    color statusColor = clrGray;

    if(systemState == STATE_ACTIVE) {
        if(g_trailActiveAbove || g_trailActiveBelow) {
            statusText += "TRAILING";
            statusColor = CLR_ACTIVE;
        } else {
            statusText += "WATCHING";
            statusColor = CLR_PROFIT;
        }
    } else {
        statusText += "IDLE";
    }
    ObjectSetString(0, "TG_STATUS", OBJPROP_TEXT, statusText);
    ObjectSetInteger(0, "TG_STATUS", OBJPROP_COLOR, statusColor);

    // UPPER ADDED
    ObjectSetString(0, "TG_UPPER_ADD", OBJPROP_TEXT,
                    StringFormat("Upper Added: %d", g_trailUpperAdded));
    ObjectSetInteger(0, "TG_UPPER_ADD", OBJPROP_COLOR,
                    g_trailUpperAdded > 0 ? CLR_GRID_A : clrGray);

    // UPPER REMOVED
    ObjectSetString(0, "TG_UPPER_REM", OBJPROP_TEXT,
                    StringFormat("Upper Removed: %d", g_trailUpperRemoved));
    ObjectSetInteger(0, "TG_UPPER_REM", OBJPROP_COLOR,
                    g_trailUpperRemoved > 0 ? CLR_LOSS : clrGray);

    // LOWER ADDED
    ObjectSetString(0, "TG_LOWER_ADD", OBJPROP_TEXT,
                    StringFormat("Lower Added: %d", g_trailLowerAdded));
    ObjectSetInteger(0, "TG_LOWER_ADD", OBJPROP_COLOR,
                    g_trailLowerAdded > 0 ? CLR_GRID_A : clrGray);

    // LOWER REMOVED
    ObjectSetString(0, "TG_LOWER_REM", OBJPROP_TEXT,
                    StringFormat("Lower Removed: %d", g_trailLowerRemoved));
    ObjectSetInteger(0, "TG_LOWER_REM", OBJPROP_COLOR,
                    g_trailLowerRemoved > 0 ? CLR_LOSS : clrGray);
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
    DeleteObjectsByPrefix("BTN_");
    DeleteObjectsByPrefix("LBL_");
    DeleteObjectsByPrefix("LEGEND_");
    DeleteObjectsByPrefix("GRID_LEGEND_");
    DeleteObjectsByPrefix("SHIELD_");
    DeleteObjectsByPrefix("COP_");  // v5.1: Close On Profit Panel
    DeleteObjectsByPrefix("TG_");   // v5.3: Trailing Grid Panel
    DeleteObjectsByPrefix("GZ_");   // v5.8: Grid Zero Panel
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Draw All Grid Lines                                              |
//+------------------------------------------------------------------+
void DrawGridVisualization() {
    if(!ShowGridLines) return;

    DrawEntryPointLine();
    DrawGridALines();
    DrawGridBLines();

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| NOTE: DrawEntryPointLine() is defined in Utils/GridHelpers.mqh   |
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
