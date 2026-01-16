//+------------------------------------------------------------------+
//|                                                    Dashboard.mqh |
//|                     SUGAMARA RIBELLE v9.25 - Dashboard Display   |
//|                                                                  |
//|  Visual dashboard for Perfect Cascade (Grid A=BUY, B=SELL)       |
//|  Color Scheme: DUNE/ARRAKIS DESERT THEME - 2 COLUMN LAYOUT       |
//|                                                                  |
//|  v9.25: MODE indicator restored + Loss zones removed + COP fix   |
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
#define PANEL_WIDTH       345
#define TOTAL_WIDTH       690
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
int g_colWidth = 345; // Column width

//+------------------------------------------------------------------+
//| Handle Button Click Events                                       |
//+------------------------------------------------------------------+
void HandleButtonClick(string clickedObject) {
    // Reset button state
    ObjectSetInteger(0, clickedObject, OBJPROP_STATE, false);
    ChartRedraw(0);

    // v9.23: Compare with symbol-specific button names
    // Check if system can accept new orders
    if(systemState != STATE_IDLE && clickedObject != DashObjName("BTN_CLOSE_ALL")) {
        Print("WARNING: System already active - click ignored");
        if(EnableAlerts) Alert("WARNING: System already active!");
        return;
    }

    //==============================================================
    // BUY BUTTONS - Grid A (Long Bias)
    //==============================================================
    if(clickedObject == DashObjName("BTN_BUY_MARKET")) {
        Log_Debug("Dashboard", "BUY MARKET requested - Starting Grid A");
        systemState = STATE_ACTIVE;
        if(InitializeGridA()) {
            PlaceAllGridAOrders();
            Log_GridStart("A", entryPoint, currentSpacing_Pips, GridLevelsPerSide);
        }
        return;
    }

    if(clickedObject == DashObjName("BTN_BUY_LIMIT")) {
        Log_Debug("Dashboard", "BUY LIMIT requested - Starting Grid A");
        systemState = STATE_ACTIVE;
        if(InitializeGridA()) {
            PlaceAllGridAOrders();
            Log_GridStart("A", entryPoint, currentSpacing_Pips, GridLevelsPerSide);
        }
        return;
    }

    if(clickedObject == DashObjName("BTN_BUY_STOP")) {
        Log_Debug("Dashboard", "BUY STOP requested - Starting Grid A");
        systemState = STATE_ACTIVE;
        if(InitializeGridA()) {
            PlaceAllGridAOrders();
            Log_GridStart("A", entryPoint, currentSpacing_Pips, GridLevelsPerSide);
        }
        return;
    }

    //==============================================================
    // SELL BUTTONS - Grid B (Short Bias)
    //==============================================================
    if(clickedObject == DashObjName("BTN_SELL_MARKET")) {
        Log_Debug("Dashboard", "SELL MARKET requested - Starting Grid B");
        systemState = STATE_ACTIVE;
        if(InitializeGridB()) {
            PlaceAllGridBOrders();
            Log_GridStart("B", entryPoint, currentSpacing_Pips, GridLevelsPerSide);
        }
        return;
    }

    if(clickedObject == DashObjName("BTN_SELL_LIMIT")) {
        Log_Debug("Dashboard", "SELL LIMIT requested - Starting Grid B");
        systemState = STATE_ACTIVE;
        if(InitializeGridB()) {
            PlaceAllGridBOrders();
            Log_GridStart("B", entryPoint, currentSpacing_Pips, GridLevelsPerSide);
        }
        return;
    }

    if(clickedObject == DashObjName("BTN_SELL_STOP")) {
        Log_Debug("Dashboard", "SELL STOP requested - Starting Grid B");
        systemState = STATE_ACTIVE;
        if(InitializeGridB()) {
            PlaceAllGridBOrders();
            Log_GridStart("B", entryPoint, currentSpacing_Pips, GridLevelsPerSide);
        }
        return;
    }

    //==============================================================
    // START BOTH GRIDS - Neutral Strategy
    //==============================================================
    if(clickedObject == DashObjName("BTN_START_NEUTRAL")) {
        Log_Debug("Dashboard", "NEUTRAL START requested");
        systemState = STATE_ACTIVE;
        InitializeEntryPoint();
        CalculateCurrentSpacing();
        if(InitializeGridA() && InitializeGridB()) {
            PlaceAllGridAOrders();
            PlaceAllGridBOrders();
            Log_SessionStart(_Symbol, "NEUTRAL");
            if(EnableAlerts) Alert("Sugamara: NEUTRAL Grid System STARTED");
        }
        return;
    }

    //==============================================================
    // PAUSE/RESUME
    //==============================================================
    if(clickedObject == DashObjName("BTN_PAUSE")) {
        if(systemState == STATE_PAUSED) {
            systemState = STATE_ACTIVE;
            Log_Debug("Dashboard", "System RESUMED");
            UpdatePauseButton();
        } else if(systemState == STATE_ACTIVE) {
            systemState = STATE_PAUSED;
            Log_Debug("Dashboard", "System PAUSED");
            UpdatePauseButton();
        }
        return;
    }

    //==============================================================
    // CLOSE ALL
    //==============================================================
    if(clickedObject == DashObjName("BTN_CLOSE_ALL")) {
        Log_SystemWarning("Dashboard", "CLOSE ALL requested");
        CloseAllSugamaraOrders();
        // v5.8 FIX: COP_ResetDaily() RIMOSSO - profitti devono accumularsi
        // Il reset avviene solo al cambio giorno (COP_IsNewDay) o target raggiunto
        systemState = STATE_CLOSING;  // v9.20: Show "ALL CLOSED" (red) in status
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
    // v9.23: Use symbol-specific object names
    ObjectSetString(0, DashObjName("BTN_PAUSE"), OBJPROP_TEXT, btnText);
    ObjectSetInteger(0, DashObjName("BTN_PAUSE"), OBJPROP_BGCOLOR, btnColor);
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Initialize Dashboard - 2 Column Layout (ROBUST VERSION)          |
//+------------------------------------------------------------------+
bool InitializeDashboard() {
    if(!ShowDashboard) return true;

    Log_Header("SUGAMARA RIBELLE v9.25 - DUNE THEME");

    // Check if dashboard already exists and is complete
    if(VerifyDashboardExists()) {
        Log_Debug("Dashboard", "Already exists - verifying control buttons");

        // v5.4: Verify and recreate control buttons if missing
        if(!VerifyControlButtonsExist()) {
            Print("Control buttons missing - recreating...");
            InitializeControlButtons(g_leftX, g_btnY, g_colWidth);
        }

        // v9.11 Fix: Ensure Grid Visualization is also restored if missing
        if(ShowGridLines && !VerifyGridLinesExist()) {
            Print("Grid lines missing - recreating visualization...");
            DrawGridVisualization();
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
    CreateAutoSavePanel();   // v9.22: Auto-Save Monitor
    // CreateShieldPanel(); REMOVED in v9.12
    CreateGridLegendPanel(); // v9.22: Now a stub - GRID LEGEND is in right column
    CreateCOPPanel();        // v5.1: Close On Profit Panel

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

    // v9.23: Critical objects with symbol suffix (multi-chart support)
    string criticalObjects[] = {
        "TITLE_PANEL",
        "MODE_PANEL",
        "LEFT_GRIDA_PANEL",
        "RIGHT_GRIDB_PANEL",
        "LEFT_PERF_PANEL",
        "RIGHT_REOPEN_PANEL",
        "VOL_PANEL"
    };

    int missingCount = 0;
    for(int i = 0; i < ArraySize(criticalObjects); i++) {
        // v9.23: Use DashObjName() to check symbol-specific objects
        if(ObjectFind(0, DashObjName(criticalObjects[i])) < 0) {
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
    // v9.23: Check for START, CLOSE and RECOVER buttons with symbol suffix
    bool startExists = ObjectFind(0, DashObjName("SUGAMARA_BTN_START")) >= 0;
    bool closeExists = ObjectFind(0, DashObjName("SUGAMARA_BTN_CLOSEALL")) >= 0;
    bool recoverExists = ObjectFind(0, DashObjName("SUGAMARA_BTN_RECOVER")) >= 0;

    if(!startExists || !closeExists || !recoverExists) {
        PrintFormat("Button verification: START=%s, CLOSE=%s, RECOVER=%s",
                    startExists ? "OK" : "MISSING",
                    closeExists ? "OK" : "MISSING",
                    recoverExists ? "OK" : "MISSING");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| Verify Grid Lines Exist v9.11 (Basic Check)                       |
//+------------------------------------------------------------------+
bool VerifyGridLinesExist() {
    if(!ShowGridLines) return true;
    
    // Check for just one expected object (Entry Line or a Grid Level)
    // Entry Point Line is the most consistent object to check
    if(ShowEntryLine && entryPoint > 0) {
        if(ObjectFind(0, "SUGAMARA_ENTRY") < 0) return false;
    }
    
    // Warning: checking all grid lines might be intensive, so we do a light check
    return true;
}

//+------------------------------------------------------------------+
//| Recreate Entire Dashboard - Force complete rebuild                |
//+------------------------------------------------------------------+
void RecreateEntireDashboard() {
    if(!ShowDashboard) return;

    Log_Header("RECREATING DASHBOARD (Auto-Recovery)");

    // Remove any partial objects
    RemoveDashboard();
    RemoveGridVisualization(); // v9.11: Ensure grid lines are cleaned
    Sleep(100);

    // Recreate all components
    CreateUnifiedDashboard();
    CreateVolatilityPanel();
    CreateAutoSavePanel();   // v9.22: Auto-Save Monitor
    // CreateShieldPanel(); REMOVED in v9.12
    CreateGridLegendPanel(); // v9.22: Now a stub - GRID LEGEND is in right column
    CreateCOPPanel();        // v5.1: Close On Profit Panel

    // v4.4: Control buttons ALWAYS active
    // FIX v4.5: Corrected parameter order (startX, startY, panelWidth)
    InitializeControlButtons(g_leftX, g_btnY, g_colWidth);

    // v9.11: Redraw Grid Visualization
    if(ShowGridLines) {
        DrawGridVisualization();
        Print("SUCCESS: Grid Visualization restored (v9.11)");
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

    // v9.23: Quick check with symbol-specific name
    if(ObjectFind(0, DashObjName("TITLE_PANEL")) < 0) {
        // v9.23: Critical objects with symbol suffix (multi-chart support)
        string criticalObjects[] = {
            "TITLE_PANEL", "MODE_PANEL", "LEFT_GRIDA_PANEL",
            "RIGHT_GRIDB_PANEL", "LEFT_PERF_PANEL", "RIGHT_REOPEN_PANEL",
            "VOL_PANEL"
        };

        int missingCount = 0;
        string missingList = "";

        for(int i = 0; i < ArraySize(criticalObjects); i++) {
            // v9.23: Use DashObjName() for symbol-specific check
            if(ObjectFind(0, DashObjName(criticalObjects[i])) < 0) {
                missingCount++;
                if(missingList != "") missingList += ", ";
                missingList += criticalObjects[i];
            }
        }

        // v9.11: Log dettagliato con Alert
        Log_DashboardRecovery(missingCount, missingList);

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
    // TITLE PANEL (Full Width = 2 columns only, excludes side panels)
    //═══════════════════════════════════════════════════════════════
    int titleHeight = 70;
    DashRectangle("TITLE_PANEL", x, y, totalWidth, titleHeight, CLR_BG_DARK);
    // v9.22: Title centered relative to 2 columns (690px), NOT including ATR/COP side panels
    // "SUGAMARA v9.25" @ 20px Arial Black ≈ 220px wide → offset -110
    // "The Spice Must Flow" @ 10px ≈ 144px wide → offset -72
    DashLabel("TITLE_MAIN", x + totalWidth/2 - 110, y + 12, "SUGAMARA v9.25", clrYellow, 20, "Arial Black");
    DashLabel("TITLE_SUB", x + totalWidth/2 - 72, y + 42, "The Spice Must Flow", C'255,100,0', 10, "Arial Bold");
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
    int gridAHeight = 165;  // v9.22: Reduced from 200 (removed extra spacing)
    DashRectangle("LEFT_GRIDA_PANEL", leftX, leftY, colWidth, gridAHeight, CLR_PANEL_GRIDA);

    int ay = leftY + 8;
    DashLabel("LEFT_GRIDA_TITLE", leftX + 10, ay, "GRID A - BUY", CLR_GOLD, 10, "Arial Bold");  // v9.22: Standardized title
    ay += 20;  // v9.22: Consistent title spacing
    DashLabel("LEFT_GRIDA_STATUS", leftX + 10, ay, "Status: IDLE", clrGray, 9);
    ay += 16;
    DashLabel("LEFT_GRIDA_POSITIONS", leftX + 10, ay, "Positions: 0", CLR_WHITE, 8);
    ay += 14;
    DashLabel("LEFT_GRIDA_PENDING", leftX + 10, ay, "Pending: 0", CLR_WHITE, 8);
    ay += 14;
    DashLabel("LEFT_GRIDA_LOTS", leftX + 10, ay, "Long Lots: 0.00", CLR_GRID_A, 8);
    ay += 14;
    DashLabel("LEFT_GRIDA_SHORT", leftX + 10, ay, "Short Lots: 0.00", CLR_LOSS, 8);
    ay += 16;
    // v9.0: LIMIT/STOP monitoring con icone e etichette complete
    DashLabel("LEFT_GRIDA_LIMIT", leftX + 10, ay, "[^] LIMIT 0/10 | Cycles:0 | Reopen:0", CLR_WHITE, 8);
    ay += 14;
    DashLabel("LEFT_GRIDA_STOP", leftX + 10, ay, "[^] STOP  0/10 | Cycles:0 | Reopen:0", CLR_WHITE, 8);

    leftY += gridAHeight;

    //--- PERFORMANCE PANEL (v9.18: moved from right column, replaced NET EXPOSURE) ---
    int perfHeight = 140;
    DashRectangle("LEFT_PERF_PANEL", leftX, leftY, colWidth, perfHeight, CLR_PANEL_PERF);

    int py = leftY + 8;
    DashLabel("LEFT_PERF_TITLE", leftX + 10, py, "PERFORMANCE", CLR_GOLD, 10, "Arial Bold");  // v9.22: Standardized title
    py += 20;  // v9.22: Consistent title spacing
    DashLabel("LEFT_PERF_TOTAL", leftX + 10, py, "Total P/L: $0.00", CLR_WHITE, 11, "Arial Bold");
    py += 18;
    DashLabel("LEFT_PERF_EQUITY", leftX + 10, py, "Equity: $---", CLR_WHITE, 8);
    py += 16;
    DashLabel("LEFT_PERF_BALANCE", leftX + 10, py, "Balance: $---", CLR_WHITE, 8);
    py += 16;
    DashLabel("LEFT_PERF_DD", leftX + 10, py, "Drawdown: 0.00%", CLR_WHITE, 8);
    py += 16;
    DashLabel("LEFT_PERF_WINRATE", leftX + 10, py, "Win Rate: --% (0W/0L)", CLR_SILVER, 8);

    leftY += perfHeight;

    //--- CONTROL BUTTONS PANEL ---
    int buttonsHeight = 200;  // v5.8: Increased +30px to balance Grid Zero panel
    DashRectangle("LEFT_BUTTONS_PANEL", leftX, leftY, colWidth, buttonsHeight, CLR_PANEL_BUTTONS);
    g_btnY = leftY;
    // v9.24: Button creation delegated to InitializeControlButtons() in ControlButtons.mqh (called from RecreateEntireDashboard)

    // v9.25 FIX: Restore MODE indicator (accidentally removed in v9.24 button refactor)
    // Creates MODE: [colored box] STATUS below buttons
    int modeY = leftY + 142;  // 142px from top of button panel (below RECOVER button)
    int modeX = leftX + 10;   // Same X offset as buttons

    // "MODE:" label
    DashLabel("MODE_LABEL", modeX, modeY, "MODE:", CLR_WHITE, 12, "Arial Bold");

    // Colored status box (12x12px, initially white for READY state)
    DashRectangle("MODE_STATUS_BOX", modeX + 55, modeY + 2, 12, 12, clrWhite);

    // Status text (initially "READY")
    DashLabel("MODE_STATUS_TEXT", modeX + 72, modeY, "READY", CLR_WHITE, 12, "Arial Bold");

    leftY += buttonsHeight;

    // v9.22: LEFT_PADDING_PANEL removed - columns now equal height (505px each)

    //═══════════════════════════════════════════════════════════════
    // RIGHT COLUMN START
    //═══════════════════════════════════════════════════════════════
    int rightX = x + colWidth;
    int rightY = y;

    //--- GRID B PANEL (SOLO SELL - Sandworm Riders) ---
    int gridBHeight = 165;  // v9.22: Reduced from 200 (removed extra spacing)
    DashRectangle("RIGHT_GRIDB_PANEL", rightX, rightY, colWidth, gridBHeight, CLR_PANEL_GRIDB);

    int by = rightY + 8;
    DashLabel("RIGHT_GRIDB_TITLE", rightX + 10, by, "GRID B - SELL", CLR_GOLD, 10, "Arial Bold");  // v9.22: Standardized title
    by += 20;  // v9.22: Consistent title spacing
    DashLabel("RIGHT_GRIDB_STATUS", rightX + 10, by, "Status: IDLE", clrGray, 9);
    by += 16;
    DashLabel("RIGHT_GRIDB_POSITIONS", rightX + 10, by, "Positions: 0", CLR_WHITE, 8);
    by += 14;
    DashLabel("RIGHT_GRIDB_PENDING", rightX + 10, by, "Pending: 0", CLR_WHITE, 8);
    by += 14;
    DashLabel("RIGHT_GRIDB_LOTS", rightX + 10, by, "Long Lots: 0.00", CLR_GRID_A, 8);
    by += 14;
    DashLabel("RIGHT_GRIDB_SHORT", rightX + 10, by, "Short Lots: 0.00", CLR_LOSS, 8);
    by += 16;
    // v9.0: LIMIT/STOP monitoring con icone e etichette complete
    DashLabel("RIGHT_GRIDB_LIMIT", rightX + 10, by, "[v] LIMIT 0/10 | Cycles:0 | Reopen:0", CLR_WHITE, 8);
    by += 14;
    DashLabel("RIGHT_GRIDB_STOP", rightX + 10, by, "[v] STOP  0/10 | Cycles:0 | Reopen:0", CLR_WHITE, 8);

    rightY += gridBHeight;

    // v5.2: RANGEBOX panel removed (mode deprecated)
    // v5.9.3: GRID INFO panel removed (info moved to Mode row)
    // v9.18: PERFORMANCE moved to left column, GRID COUNTER replaced by REOPEN CYCLE MONITOR

    //--- REOPEN CYCLE MONITOR (v9.22: includes GRID LEGEND at bottom) ---
    // v9.22: 340px to match left column (165+140+200 = 505px, gridB 165 + reopen 340 = 505px)
    int reopenHeight = 340;
    DashRectangle("RIGHT_REOPEN_PANEL", rightX, rightY, colWidth, reopenHeight, C'35,30,25');

    int ry = rightY + 8;
    DashLabel("RIGHT_REOPEN_TITLE", rightX + 10, ry, "REOPEN CYCLE MONITOR", CLR_GOLD, 10, "Arial Bold");
    ry += 20;

    // Grid A / Grid B summary headers
    DashLabel("REOPEN_GA_HEADER", rightX + 10, ry, "GRID A (BUY)", CLR_GRID_A, 9, "Arial Bold");
    DashLabel("REOPEN_GB_HEADER", rightX + 180, ry, "GRID B (SELL)", CLR_GRID_B, 9, "Arial Bold");
    ry += 16;

    // Queue counters
    DashLabel("REOPEN_GA_QUEUE", rightX + 10, ry, "In Coda:    0", CLR_WHITE, 8);
    DashLabel("REOPEN_GB_QUEUE", rightX + 180, ry, "In Coda:    0", CLR_WHITE, 8);
    ry += 14;

    // Done counters
    DashLabel("REOPEN_GA_DONE", rightX + 10, ry, "Reinseriti: 0", CLR_WHITE, 8);
    DashLabel("REOPEN_GB_DONE", rightX + 180, ry, "Reinseriti: 0", CLR_WHITE, 8);
    ry += 14;

    // Cycles counters
    DashLabel("REOPEN_GA_CYCLES", rightX + 10, ry, "Cicli:      0/50", CLR_WHITE, 8);
    DashLabel("REOPEN_GB_CYCLES", rightX + 180, ry, "Cicli:      0/50", CLR_WHITE, 8);
    ry += 18;

    // Separator - STOP orders waiting
    DashLabel("REOPEN_SEP1", rightX + 10, ry, "STOP ORDERS IN ATTESA REOPEN:", CLR_AZURE_2, 8, "Arial Bold");
    ry += 14;

    // Stop orders waiting list (up to 4 lines)
    DashLabel("REOPEN_WAIT_1", rightX + 10, ry, "---", clrGray, 7);
    ry += 12;
    DashLabel("REOPEN_WAIT_2", rightX + 10, ry, "---", clrGray, 7);
    ry += 12;
    DashLabel("REOPEN_WAIT_3", rightX + 10, ry, "---", clrGray, 7);
    ry += 12;
    DashLabel("REOPEN_WAIT_4", rightX + 10, ry, "---", clrGray, 7);
    ry += 16;

    // Separator - Recent reopens
    DashLabel("REOPEN_SEP2", rightX + 10, ry, "ULTIMI REOPEN:", CLR_AZURE_2, 8, "Arial Bold");
    ry += 14;

    // Recent reopens list (3 lines)
    DashLabel("REOPEN_LAST_1", rightX + 10, ry, "---", clrGray, 7);
    ry += 12;
    DashLabel("REOPEN_LAST_2", rightX + 10, ry, "---", clrGray, 7);
    ry += 12;
    DashLabel("REOPEN_LAST_3", rightX + 10, ry, "---", clrGray, 7);
    ry += 18;

    //--- v9.22: GRID LEGEND integrated into REOPEN panel ---
    DashLabel("LEGEND_TITLE", rightX + 10, ry, "GRID LEGEND", CLR_GOLD, 10, "Arial Bold");
    ry += 18;

    // v9.22: Row 1 - GRID A (BUY): STP + LMT
    DashRectangle("LEGEND_GA_STOP_BOX", rightX + 10, ry + 2, 10, 10, Color_BuyStop);
    DashLabel("LEGEND_GA_STOP", rightX + 24, ry, "STP[0]", Color_BuyStop, 10);
    DashRectangle("LEGEND_GA_LIMIT_BOX", rightX + 85, ry + 2, 10, 10, Color_BuyLimit);
    DashLabel("LEGEND_GA_LIMIT", rightX + 99, ry, "LMT[0]", Color_BuyLimit, 10);
    DashLabel("LEGEND_GA_LABEL", rightX + 160, ry, "GRID A", CLR_GRID_A, 10);
    ry += 16;

    // v9.22: Row 2 - GRID B (SELL): LMT + STP
    DashRectangle("LEGEND_GB_LIMIT_BOX", rightX + 10, ry + 2, 10, 10, Color_SellLimit);
    DashLabel("LEGEND_GB_LIMIT", rightX + 24, ry, "LMT[0]", Color_SellLimit, 10);
    DashRectangle("LEGEND_GB_STOP_BOX", rightX + 85, ry + 2, 10, 10, Color_SellStop);
    DashLabel("LEGEND_GB_STOP", rightX + 99, ry, "STP[0]", Color_SellStop, 10);
    DashLabel("LEGEND_GB_LABEL", rightX + 160, ry, "GRID B", CLR_GRID_B, 10);
    ry += 16;

    // v9.22: Row 3 - Totals aligned left
    DashLabel("LEGEND_GA_TOTAL", rightX + 10, ry, "GA Tot: 0", CLR_GRID_A, 10);
    DashLabel("LEGEND_GB_TOTAL", rightX + 100, ry, "GB Tot: 0", CLR_GRID_B, 10);

    rightY += reopenHeight;

    ChartRedraw(0);
    Print("SUCCESS: Unified Dashboard created with 2-column layout (v9.22)");
}

//+------------------------------------------------------------------+
//| Create Volatility/ATR Monitor Panel (Right Side)                 |
//| v9.22: Added colored box indicator before title                   |
//+------------------------------------------------------------------+
void CreateVolatilityPanel() {
    int volX = Dashboard_X + TOTAL_WIDTH + 10;
    int volY = Dashboard_Y;
    int volWidth = 175;
    int volHeight = 55;

    DashRectangle("VOL_PANEL", volX, volY, volWidth, volHeight, CLR_BG_DARK);

    int ly = volY + 6;
    // v9.22: Colored status box before title
    DashRectangle("VOL_STATUS_BOX", volX + 10, ly + 2, 8, 8, clrLime);
    DashLabel("VOL_TITLE", volX + 22, ly, "ATR MONITOR", CLR_GOLD, 10, "Arial Bold");
    ly += 18;

    // Compact single line for M5 and H1
    DashLabel("VOL_ATR_LINE", volX + 10, ly, "M5: --- | H1: ---", CLR_AZURE_1, 8);
    ly += 16;

    // Spacing + Condition on same line
    DashLabel("VOL_SPACING_STATUS", volX + 10, ly, "Spacing: --- (Normal)", CLR_CYAN, 8);

    Print("SUCCESS: Volatility Panel created (v9.22 with status box)");
}

//+------------------------------------------------------------------+
//| Create AUTO-SAVE Monitor Panel (v9.22: NEW)                       |
//| Shows auto-save status and last backup time                       |
//+------------------------------------------------------------------+
void CreateAutoSavePanel() {
    int asX = Dashboard_X + TOTAL_WIDTH + 10;
    int asY = Dashboard_Y + 65;  // Below ATR Monitor (55px + 10px gap)
    int asWidth = 175;
    int asHeight = 50;

    DashRectangle("AUTOSAVE_PANEL", asX, asY, asWidth, asHeight, CLR_BG_DARK);

    int ly = asY + 6;
    // v9.22: Colored status box before title (like ATR MONITOR and COP)
    DashRectangle("AUTOSAVE_TITLE_BOX", asX + 10, ly + 2, 8, 8, clrLime);
    DashLabel("AUTOSAVE_TITLE", asX + 22, ly, "AUTO-SAVE", CLR_GOLD, 10, "Arial Bold");
    ly += 16;

    // Status with colored box
    DashRectangle("AUTOSAVE_STATUS_BOX", asX + 10, ly + 2, 8, 8, clrLime);
    DashLabel("AUTOSAVE_STATUS", asX + 22, ly, "ON", clrLime, 8);
    DashLabel("AUTOSAVE_LAST", asX + 60, ly, "Last: --:-- --", CLR_SILVER, 8);

    Print("SUCCESS: Auto-Save Panel created (v9.22)");
}

//+------------------------------------------------------------------+
//| CreateShieldPanel() REMOVED in v9.12                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create Grid Legend Panel                                          |
//| v9.22: MOVED to right column in CreateUnifiedDashboard()          |
//| This function now does nothing - kept for compatibility           |
//+------------------------------------------------------------------+
void CreateGridLegendPanel() {
    // v9.22: Grid Legend is now created inline in CreateUnifiedDashboard()
    // at the bottom of the right column, after REOPEN CYCLE MONITOR
    // This function is kept as a stub for compatibility
}

//+------------------------------------------------------------------+
//| Create COP Panel (v5.1 - Close On Profit)                        |
//| v9.22: Moved below AUTO-SAVE, colored box instead of emoji        |
//+------------------------------------------------------------------+
void CreateCOPPanel() {
    if(!Enable_CloseOnProfit) return;

    int copX = Dashboard_X + TOTAL_WIDTH + 10;
    int copY = Dashboard_Y + 125;  // v9.22: After ATR (55) + gap (10) + AUTO-SAVE (50) + gap (10)
    int copWidth = 175;
    int copHeight = 170;  // v9.22: Increased to include Commission label

    // v9.7: Gold border around COP panel
    DashRectangle("COP_BORDER", copX - 2, copY - 2, copWidth + 4, copHeight + 4, clrGold);
    DashRectangle("COP_PANEL", copX, copY, copWidth, copHeight, C'28,35,28');

    int ly = copY + 8;
    // v9.22: Colored status box instead of emoji (MT5 font compatibility)
    DashRectangle("COP_STATUS_BOX", copX + 10, ly + 2, 8, 8, clrLime);
    DashLabel("COP_TITLE", copX + 22, ly, "CLOSE ON PROFIT", CLR_GOLD, 10, "Arial Bold");
    ly += 20;
    DashLabel("COP_SEPARATOR", copX + 10, ly, "------------------------", clrGray, 7);
    ly += 15;

    // Net Profit
    DashLabel("COP_NET", copX + 10, ly, "Net: $0.00 / $50.00", CLR_AZURE_1, 8);
    ly += 18;  // v9.21: Increased spacing

    // Progress Bar (text-based)
    DashLabel("COP_PROGRESS", copX + 10, ly, "░░░░░░░░░░░░░░░░ 0%", clrGray, 8);
    ly += 18;  // v9.21: Increased spacing

    // Status and Remaining (NEW)
    DashLabel("COP_STATUS", copX + 10, ly, "Status: ACTIVE", CLR_PROFIT, 8);
    ly += 18;  // v9.21: Increased spacing
    DashLabel("COP_MISSING", copX + 10, ly, "Manca: $50.00", CLR_AZURE_1, 8);
    ly += 20;  // v9.21: Increased spacing

    // Details
    DashLabel("COP_REAL", copX + 10, ly, "Real: $0.00", clrGray, 8);
    ly += 18;  // v9.21: Increased spacing
    DashLabel("COP_FLOAT", copX + 10, ly, "Float: $0.00", clrGray, 8);
    ly += 18;  // v9.21: Increased spacing
    DashLabel("COP_COMM", copX + 10, ly, "Comm: -$0.00", clrGray, 8);

    Print("SUCCESS: COP Panel created (enhanced v5.2)");
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
    UpdateModeStatusIndicator();  // v9.19: Update MODE: [box] STATUS indicator
    UpdateStatusLabel();          // v9.20: Dynamic status label colors
    UpdateGridASection();
    UpdateGridBSection();
    // v9.18: UpdateExposureSection() REMOVED - replaced by Performance in left column
    UpdatePerformanceSection();  // v9.18: Now updates LEFT_PERF_* labels
    UpdateReopenCycleSection();  // v9.18: NEW - replaces GridCounterSection
    UpdateVolatilityPanel();
    UpdateGridLegendSection();   // v9.18: NEW - updates Grid Legend on right side
    UpdateAutoSaveSection();     // v9.22: NEW - updates Auto-Save status
    UpdateCOPSection();

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Update Mode Section                                              |
//+------------------------------------------------------------------+
void UpdateModeSection() {
    // v9.23: Use symbol-specific object names
    // Line 1: Mode
    string modeText = "Mode: " + GetModeName();
    ObjectSetString(0, DashObjName("MODE_INFO1"), OBJPROP_TEXT, modeText);
    ObjectSetInteger(0, DashObjName("MODE_INFO1"), OBJPROP_COLOR, GetModeColor());

    // Line 2: Symbol + Spread
    string symbolText = StringFormat("Symbol: %s | Spread: %.1f pips", _Symbol, GetSpreadPips());
    ObjectSetString(0, DashObjName("MODE_INFO2"), OBJPROP_TEXT, symbolText);

    // Line 3: Pair only (v5.9.3: Grids e Spacing spostati a destra)
    string pairName = GetPairDisplayName(SelectedPair);
    ObjectSetString(0, DashObjName("MODE_INFO3"), OBJPROP_TEXT, "Pair: " + pairName);

    // v5.9.3: Right side - Spacing e Levels (sostituisce ATR)
    string spacingText = StringFormat("Spacing: %.1f pips", currentSpacing_Pips);
    ObjectSetString(0, DashObjName("MODE_SPACING"), OBJPROP_TEXT, spacingText);

    string levelsText = StringFormat("Levels: %d", GridLevelsPerSide);
    ObjectSetString(0, DashObjName("MODE_LEVELS"), OBJPROP_TEXT, levelsText);
}

//+------------------------------------------------------------------+
//| Update Mode Status Indicator (v9.21: colored box + text)          |
//| Shows: MODE: [colored box] STATUS                                  |
//| Colors: White=READY, Green=WORKING, Red=STOPPED                    |
//+------------------------------------------------------------------+
void UpdateModeStatusIndicator() {
    color statusColor;
    string statusText;

    if(systemState == STATE_ACTIVE || systemState == STATE_RUNNING) {
        statusColor = clrLime;
        statusText = "WORKING";
    } else if(systemState == STATE_PAUSED || systemState == STATE_CLOSING) {
        // v9.21: STATE_CLOSING shows STOPPED (red)
        statusColor = clrRed;
        statusText = "STOPPED";
    } else {
        // STATE_IDLE only
        statusColor = clrWhite;
        statusText = "READY";
    }

    // v9.23: Use symbol-specific object names
    // Update colored box background
    ObjectSetInteger(0, DashObjName("MODE_STATUS_BOX"), OBJPROP_BGCOLOR, statusColor);

    // Update status text and color
    ObjectSetString(0, DashObjName("MODE_STATUS_TEXT"), OBJPROP_TEXT, statusText);
    ObjectSetInteger(0, DashObjName("MODE_STATUS_TEXT"), OBJPROP_COLOR, statusColor);
}

//+------------------------------------------------------------------+
//| Update Status Label (v9.22: dual-color support)                    |
//| SUGAMARA_BTN_STATUS + STATUS2: allows two-color status display     |
//| WHITE=READY, AZZURRO=STARTING, GREEN=ACTIVE, RED=CLOSED            |
//+------------------------------------------------------------------+
void UpdateStatusLabel() {
    color labelColor;
    string labelText;

    if(systemState == STATE_CLOSING) {
        // v9.22: Solo "ALL CLOSED" rosso (11px)
        labelColor = clrRed;
        labelText = "ALL CLOSED";
    } else if(systemState == STATE_ACTIVE || systemState == STATE_RUNNING) {
        int totalPositions = GetGridAActivePositions() + GetGridBActivePositions();
        if(totalPositions > 0) {
            labelColor = clrLime;
            labelText = "ACTIVE - GRID RUNNING";
        } else {
            labelColor = CLR_ACTIVE;  // Azzurrino
            labelText = "STARTING GRID...";
        }
    } else if(systemState == STATE_PAUSED) {
        labelColor = clrOrange;
        labelText = "PAUSED";
    } else {
        // STATE_IDLE
        labelColor = clrWhite;
        labelText = "READY - CLICK START";
    }

    // v9.23: Use symbol-specific object names
    // Update label
    ObjectSetString(0, DashObjName("SUGAMARA_BTN_STATUS"), OBJPROP_TEXT, labelText);
    ObjectSetInteger(0, DashObjName("SUGAMARA_BTN_STATUS"), OBJPROP_COLOR, labelColor);
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
    // v9.23: Use symbol-specific object names
    ObjectSetString(0, DashObjName("LEFT_GRIDA_STATUS"), OBJPROP_TEXT, statusText);
    ObjectSetInteger(0, DashObjName("LEFT_GRIDA_STATUS"), OBJPROP_COLOR, statusColor);

    ObjectSetString(0, DashObjName("LEFT_GRIDA_POSITIONS"), OBJPROP_TEXT, "Positions: " + IntegerToString(positions));
    ObjectSetString(0, DashObjName("LEFT_GRIDA_PENDING"), OBJPROP_TEXT, "Pending: " + IntegerToString(pending));
    ObjectSetString(0, DashObjName("LEFT_GRIDA_LOTS"), OBJPROP_TEXT, StringFormat("Long Lots: %.2f", longLots));
    ObjectSetString(0, DashObjName("LEFT_GRIDA_SHORT"), OBJPROP_TEXT, StringFormat("Short Lots: %.2f", shortLots));

    // v9.0: Update LIMIT/STOP counters con etichette complete
    // v9.11: Fixed emoji -> ASCII symbols for MT5 font compatibility
    ObjectSetString(0, DashObjName("LEFT_GRIDA_LIMIT"), OBJPROP_TEXT,
        StringFormat("[^] LIMIT %d/%d | Cycles:%d | Reopen:%d",
            g_gridA_LimitFilled, GridLevelsPerSide, g_gridA_LimitCycles, g_gridA_LimitReopens));
    ObjectSetString(0, DashObjName("LEFT_GRIDA_STOP"), OBJPROP_TEXT,
        StringFormat("[^] STOP  %d/%d | Cycles:%d | Reopen:%d",
            g_gridA_StopFilled, GridLevelsPerSide, g_gridA_StopCycles, g_gridA_StopReopens));
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
    // v9.23: Use symbol-specific object names
    ObjectSetString(0, DashObjName("RIGHT_GRIDB_STATUS"), OBJPROP_TEXT, statusText);
    ObjectSetInteger(0, DashObjName("RIGHT_GRIDB_STATUS"), OBJPROP_COLOR, statusColor);

    ObjectSetString(0, DashObjName("RIGHT_GRIDB_POSITIONS"), OBJPROP_TEXT, "Positions: " + IntegerToString(positions));
    ObjectSetString(0, DashObjName("RIGHT_GRIDB_PENDING"), OBJPROP_TEXT, "Pending: " + IntegerToString(pending));
    ObjectSetString(0, DashObjName("RIGHT_GRIDB_LOTS"), OBJPROP_TEXT, StringFormat("Long Lots: %.2f", longLots));
    ObjectSetString(0, DashObjName("RIGHT_GRIDB_SHORT"), OBJPROP_TEXT, StringFormat("Short Lots: %.2f", shortLots));

    // v9.0: Update LIMIT/STOP counters con etichette complete
    // v9.11: Fixed emoji -> ASCII symbols for MT5 font compatibility
    ObjectSetString(0, DashObjName("RIGHT_GRIDB_LIMIT"), OBJPROP_TEXT,
        StringFormat("[v] LIMIT %d/%d | Cycles:%d | Reopen:%d",
            g_gridB_LimitFilled, GridLevelsPerSide, g_gridB_LimitCycles, g_gridB_LimitReopens));
    ObjectSetString(0, DashObjName("RIGHT_GRIDB_STOP"), OBJPROP_TEXT,
        StringFormat("[v] STOP  %d/%d | Cycles:%d | Reopen:%d",
            g_gridB_StopFilled, GridLevelsPerSide, g_gridB_StopCycles, g_gridB_StopReopens));
}

// v9.18: UpdateExposureSection() REMOVED - NET EXPOSURE replaced by PERFORMANCE in left column

// v5.2: UpdateRangeBoxSection() removed (RANGEBOX mode deprecated)

// v9.18: UpdateGridCounterSection() REMOVED - replaced by UpdateReopenCycleSection()

//+------------------------------------------------------------------+
//| Update Reopen Cycle Monitor Section (v9.18: NEW)                  |
//+------------------------------------------------------------------+
void UpdateReopenCycleSection() {
    // Grid A summary
    int gaQueue = 0;  // Count pending reopens
    int gaDone = g_gridA_LimitReopens + g_gridA_StopReopens;
    int gaCycles = g_gridA_LimitCycles + g_gridA_StopCycles;
    bool infiniteCycles = (MaxCyclesPerLevel == 0);  // 0 = infinite cycles

    // Count Grid A pending reopens (orders waiting to reopen)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        // If infinite cycles (0), always count as pending; otherwise check against max
        if(gridA_Upper_Status[i] == ORDER_CLOSED_TP && (infiniteCycles || gridA_Upper_Cycles[i] < MaxCyclesPerLevel)) gaQueue++;
        if(gridA_Lower_Status[i] == ORDER_CLOSED_TP && (infiniteCycles || gridA_Lower_Cycles[i] < MaxCyclesPerLevel)) gaQueue++;
    }

    // v9.23: Use symbol-specific object names
    ObjectSetString(0, DashObjName("REOPEN_GA_QUEUE"), OBJPROP_TEXT, StringFormat("In Coda:    %d", gaQueue));
    ObjectSetString(0, DashObjName("REOPEN_GA_DONE"), OBJPROP_TEXT, StringFormat("Reinseriti: %d", gaDone));
    // Display "∞" for infinite cycles
    if(infiniteCycles)
        ObjectSetString(0, DashObjName("REOPEN_GA_CYCLES"), OBJPROP_TEXT, StringFormat("Cicli:      %d/inf", gaCycles));
    else
        ObjectSetString(0, DashObjName("REOPEN_GA_CYCLES"), OBJPROP_TEXT, StringFormat("Cicli:      %d/%d", gaCycles, MaxCyclesPerLevel * GridLevelsPerSide * 2));

    // Grid B summary
    int gbQueue = 0;  // Count pending reopens
    int gbDone = g_gridB_LimitReopens + g_gridB_StopReopens;
    int gbCycles = g_gridB_LimitCycles + g_gridB_StopCycles;

    // Count Grid B pending reopens
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Status[i] == ORDER_CLOSED_TP && (infiniteCycles || gridB_Upper_Cycles[i] < MaxCyclesPerLevel)) gbQueue++;
        if(gridB_Lower_Status[i] == ORDER_CLOSED_TP && (infiniteCycles || gridB_Lower_Cycles[i] < MaxCyclesPerLevel)) gbQueue++;
    }

    ObjectSetString(0, DashObjName("REOPEN_GB_QUEUE"), OBJPROP_TEXT, StringFormat("In Coda:    %d", gbQueue));
    ObjectSetString(0, DashObjName("REOPEN_GB_DONE"), OBJPROP_TEXT, StringFormat("Reinseriti: %d", gbDone));
    if(infiniteCycles)
        ObjectSetString(0, DashObjName("REOPEN_GB_CYCLES"), OBJPROP_TEXT, StringFormat("Cicli:      %d/inf", gbCycles));
    else
        ObjectSetString(0, DashObjName("REOPEN_GB_CYCLES"), OBJPROP_TEXT, StringFormat("Cicli:      %d/%d", gbCycles, MaxCyclesPerLevel * GridLevelsPerSide * 2));

    // Update waiting STOP orders list
    UpdateWaitingStopOrdersList();

    // Update recent reopens list
    UpdateRecentReopensList();
}

//+------------------------------------------------------------------+
//| Update Waiting STOP Orders List (v9.18)                           |
//+------------------------------------------------------------------+
void UpdateWaitingStopOrdersList() {
    string waitList[4];
    int waitCount = 0;
    bool infiniteCycles = (MaxCyclesPerLevel == 0);  // 0 = infinite cycles

    // Find STOP orders waiting for price to reach reopen level
    // Grid A Upper = BUY STOP, Grid B Lower = SELL STOP
    for(int i = 0; i < GridLevelsPerSide && waitCount < 4; i++) {
        // Grid A Upper (BUY STOP)
        if(gridA_Upper_Status[i] == ORDER_CLOSED_TP && (infiniteCycles || gridA_Upper_Cycles[i] < MaxCyclesPerLevel)) {
            if(infiniteCycles)
                waitList[waitCount++] = StringFormat("GA_U_%02d BUY STOP  Ciclo %d/inf", i+1, gridA_Upper_Cycles[i]+1);
            else
                waitList[waitCount++] = StringFormat("GA_U_%02d BUY STOP  Ciclo %d/%d", i+1, gridA_Upper_Cycles[i]+1, MaxCyclesPerLevel);
        }
        if(waitCount >= 4) break;

        // Grid B Lower (SELL STOP)
        if(gridB_Lower_Status[i] == ORDER_CLOSED_TP && (infiniteCycles || gridB_Lower_Cycles[i] < MaxCyclesPerLevel)) {
            if(infiniteCycles)
                waitList[waitCount++] = StringFormat("GB_L_%02d SELL STOP Ciclo %d/inf", i+1, gridB_Lower_Cycles[i]+1);
            else
                waitList[waitCount++] = StringFormat("GB_L_%02d SELL STOP Ciclo %d/%d", i+1, gridB_Lower_Cycles[i]+1, MaxCyclesPerLevel);
        }
    }

    // v9.23: Use symbol-specific object names
    // Update labels
    for(int i = 0; i < 4; i++) {
        string labelName = DashObjName(StringFormat("REOPEN_WAIT_%d", i+1));
        if(i < waitCount) {
            ObjectSetString(0, labelName, OBJPROP_TEXT, waitList[i]);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, CLR_NEUTRAL);
        } else {
            ObjectSetString(0, labelName, OBJPROP_TEXT, "---");
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrGray);
        }
    }
}

//+------------------------------------------------------------------+
//| Update Recent Reopens List (v9.18)                                |
//+------------------------------------------------------------------+
void UpdateRecentReopensList() {
    // v9.23: Use symbol-specific object names
    // Display last 3 reopens from g_lastReopens array
    for(int i = 0; i < 3; i++) {
        string labelName = DashObjName(StringFormat("REOPEN_LAST_%d", i+1));
        if(i < g_lastReopensCount && g_lastReopens[i] != "") {
            ObjectSetString(0, labelName, OBJPROP_TEXT, g_lastReopens[i]);
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, CLR_PROFIT);
        } else {
            ObjectSetString(0, labelName, OBJPROP_TEXT, "---");
            ObjectSetInteger(0, labelName, OBJPROP_COLOR, clrGray);
        }
    }
}

//+------------------------------------------------------------------+
//| Update Grid Legend Section (v9.18: NEW)                           |
//+------------------------------------------------------------------+
void UpdateGridLegendSection() {
    // Count Grid A orders (BUY only)
    int gaStop = 0, gaLimit = 0;
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Status[i] == ORDER_PENDING || gridA_Upper_Status[i] == ORDER_FILLED) gaStop++;
        if(gridA_Lower_Status[i] == ORDER_PENDING || gridA_Lower_Status[i] == ORDER_FILLED) gaLimit++;
    }
    int gaTotal = gaStop + gaLimit;

    // v9.23: Use symbol-specific object names
    // v9.22: Update STP/LMT labels
    ObjectSetString(0, DashObjName("LEGEND_GA_STOP"), OBJPROP_TEXT, StringFormat("STP[%d]", gaStop));
    ObjectSetString(0, DashObjName("LEGEND_GA_LIMIT"), OBJPROP_TEXT, StringFormat("LMT[%d]", gaLimit));
    ObjectSetString(0, DashObjName("LEGEND_GA_TOTAL"), OBJPROP_TEXT, StringFormat("GA Tot: %d", gaTotal));

    // Count Grid B orders (SELL only)
    int gbLimit = 0, gbStop = 0;
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Status[i] == ORDER_PENDING || gridB_Upper_Status[i] == ORDER_FILLED) gbLimit++;
        if(gridB_Lower_Status[i] == ORDER_PENDING || gridB_Lower_Status[i] == ORDER_FILLED) gbStop++;
    }
    int gbTotal = gbLimit + gbStop;

    // v9.22: Update STP/LMT labels + Tot on separate row
    ObjectSetString(0, DashObjName("LEGEND_GB_LIMIT"), OBJPROP_TEXT, StringFormat("LMT[%d]", gbLimit));
    ObjectSetString(0, DashObjName("LEGEND_GB_STOP"), OBJPROP_TEXT, StringFormat("STP[%d]", gbStop));
    ObjectSetString(0, DashObjName("LEGEND_GB_TOTAL"), OBJPROP_TEXT, StringFormat("GB Tot: %d", gbTotal));
}

//+------------------------------------------------------------------+
//| Update Auto-Save Section (v9.22: NEW)                             |
//+------------------------------------------------------------------+
void UpdateAutoSaveSection() {
    // Get status from global variables
    color statusColor = Enable_AutoSave ? clrLime : clrRed;
    string statusText = Enable_AutoSave ? "ON" : "OFF";

    // v9.23: Use symbol-specific object names
    // Update status box and text
    ObjectSetInteger(0, DashObjName("AUTOSAVE_STATUS_BOX"), OBJPROP_BGCOLOR, statusColor);
    ObjectSetString(0, DashObjName("AUTOSAVE_STATUS"), OBJPROP_TEXT, statusText);
    ObjectSetInteger(0, DashObjName("AUTOSAVE_STATUS"), OBJPROP_COLOR, statusColor);

    // Last backup time and result
    string lastText = "Last: --:-- --";
    color lastColor = CLR_SILVER;

    if(g_lastAutoSaveTime > 0) {
        string result = g_lastAutoSaveSuccess ? "OK" : "FAIL";
        lastColor = g_lastAutoSaveSuccess ? clrLime : clrRed;
        lastText = StringFormat("Last: %s %s",
                   TimeToString(g_lastAutoSaveTime, TIME_MINUTES), result);
    }

    ObjectSetString(0, DashObjName("AUTOSAVE_LAST"), OBJPROP_TEXT, lastText);
    ObjectSetInteger(0, DashObjName("AUTOSAVE_LAST"), OBJPROP_COLOR, lastColor);
}

//+------------------------------------------------------------------+
//| Update Performance Section (v9.18: moved to left column)         |
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

    // v9.23: Use symbol-specific object names
    // v9.18: Updated to LEFT_PERF_* labels (moved to left column)
    color plColor = totalPL >= 0 ? CLR_PROFIT : CLR_LOSS;
    ObjectSetString(0, DashObjName("LEFT_PERF_TOTAL"), OBJPROP_TEXT, StringFormat("Total P/L: $%.2f", totalPL));
    ObjectSetInteger(0, DashObjName("LEFT_PERF_TOTAL"), OBJPROP_COLOR, plColor);

    ObjectSetString(0, DashObjName("LEFT_PERF_EQUITY"), OBJPROP_TEXT, StringFormat("Equity: $%.2f", equity));
    ObjectSetString(0, DashObjName("LEFT_PERF_BALANCE"), OBJPROP_TEXT, StringFormat("Balance: $%.2f", balance));

    color ddColor = dd > 10 ? CLR_LOSS : (dd > 5 ? CLR_NEUTRAL : CLR_WHITE);
    ObjectSetString(0, DashObjName("LEFT_PERF_DD"), OBJPROP_TEXT, StringFormat("Drawdown: %.2f%%", dd));
    ObjectSetInteger(0, DashObjName("LEFT_PERF_DD"), OBJPROP_COLOR, ddColor);

    ObjectSetString(0, DashObjName("LEFT_PERF_WINRATE"), OBJPROP_TEXT,
                    StringFormat("Win Rate: %.0f%% (%dW/%dL)", winRate, pairWins, pairLosses));
    // v9.18: RIGHT_PERF_TRADES removed (Performance moved to left column)
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

    // v9.23: Use symbol-specific object names
    // v5.9: Compact single line for M5 and H1 ATR values
    ObjectSetString(0, DashObjName("VOL_ATR_LINE"), OBJPROP_TEXT,
                    StringFormat("M5: %.1f | H1: %.1f", atrM5Pips, atrH1Pips));

    // Color based on higher ATR condition
    double maxAtr = MathMax(atrM5Pips, atrH1Pips);
    color atrColor = GetATRConditionColor(maxAtr);
    ObjectSetInteger(0, DashObjName("VOL_ATR_LINE"), OBJPROP_COLOR, atrColor);

    // v5.9: Spacing + Condition on same line
    string condText = GetATRConditionText(atrM5Pips);  // Use M5 for condition
    ObjectSetString(0, DashObjName("VOL_SPACING_STATUS"), OBJPROP_TEXT,
                    StringFormat("Spacing: %.1f (%s)", currentSpacing_Pips, condText));
    ObjectSetInteger(0, DashObjName("VOL_SPACING_STATUS"), OBJPROP_COLOR, GetATRConditionColor(atrM5Pips));
}

//+------------------------------------------------------------------+
//| UpdateShieldSection() REMOVED in v9.12                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Update COP Section (v5.1)                                         |
//+------------------------------------------------------------------+
void UpdateCOPSection() {
    if(!Enable_CloseOnProfit) return;

    // v9.23: Use symbol-specific object names
    // Net Profit
    double netProfit = COP_GetNetProfit();
    color netColor = netProfit >= 0 ? CLR_PROFIT : CLR_LOSS;
    ObjectSetString(0, DashObjName("COP_NET"), OBJPROP_TEXT,
                    StringFormat("Net: $%.2f / $%.2f", netProfit, COP_DailyTarget_USD));
    ObjectSetInteger(0, DashObjName("COP_NET"), OBJPROP_COLOR, netColor);

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

    ObjectSetString(0, DashObjName("COP_PROGRESS"), OBJPROP_TEXT,
                    StringFormat("%s %.0f%%", progressBar, progress));
    ObjectSetInteger(0, DashObjName("COP_PROGRESS"), OBJPROP_COLOR, progressColor);

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
    ObjectSetString(0, DashObjName("COP_STATUS"), OBJPROP_TEXT, "Status: " + statusText);
    ObjectSetInteger(0, DashObjName("COP_STATUS"), OBJPROP_COLOR, statusColor);

    // Missing amount (NEW v5.2)
    double missingAmount = COP_DailyTarget_USD - netProfit;
    if(missingAmount < 0) missingAmount = 0;
    ObjectSetString(0, DashObjName("COP_MISSING"), OBJPROP_TEXT,
                    StringFormat("Manca: $%.2f", missingAmount));
    ObjectSetInteger(0, DashObjName("COP_MISSING"), OBJPROP_COLOR,
                    missingAmount > 0 ? CLR_AZURE_1 : CLR_PROFIT);

    // Details
    ObjectSetString(0, DashObjName("COP_REAL"), OBJPROP_TEXT,
                    StringFormat("Real: $%.2f", cop_RealizedProfit));
    ObjectSetInteger(0, DashObjName("COP_REAL"), OBJPROP_COLOR,
                    cop_RealizedProfit >= 0 ? CLR_PROFIT : CLR_LOSS);

    ObjectSetString(0, DashObjName("COP_FLOAT"), OBJPROP_TEXT,
                    StringFormat("Float: $%.2f", cop_FloatingProfit));
    ObjectSetInteger(0, DashObjName("COP_FLOAT"), OBJPROP_COLOR,
                    cop_FloatingProfit >= 0 ? CLR_PROFIT : CLR_LOSS);

    ObjectSetString(0, DashObjName("COP_COMM"), OBJPROP_TEXT,
                    StringFormat("Comm: -$%.2f", cop_TotalCommissions));
    ObjectSetInteger(0, DashObjName("COP_COMM"), OBJPROP_COLOR, clrGray);

    // Status (if target reached)
    if(COP_IsTargetReached()) {
        ObjectSetString(0, DashObjName("COP_TITLE"), OBJPROP_TEXT, "TARGET REACHED!");
        ObjectSetInteger(0, DashObjName("COP_TITLE"), OBJPROP_COLOR, CLR_PROFIT);
    } else {
        ObjectSetString(0, DashObjName("COP_TITLE"), OBJPROP_TEXT, "CLOSE ON PROFIT");
        ObjectSetInteger(0, DashObjName("COP_TITLE"), OBJPROP_COLOR, CLR_GOLD);
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

// v9.23 FIX: Symbol-specific object names to prevent multi-chart conflicts
// Returns object name with symbol suffix: "TITLE_PANEL" -> "TITLE_PANEL_EURUSD"
string DashObjName(string baseName) {
    return baseName + "_" + _Symbol;
}

void DashLabel(string name, int x, int y, string text, color clr, int fontSize, string font = "Arial") {
    string objName = DashObjName(name);  // v9.23: Symbol-specific name
    ObjectDelete(0, objName);
    ObjectCreate(0, objName, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, fontSize);
    ObjectSetString(0, objName, OBJPROP_FONT, font);
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
    ObjectSetInteger(0, objName, OBJPROP_ZORDER, 10000);
}

void DashButton(string name, int x, int y, int width, int height, string text, color clr) {
    string objName = DashObjName(name);  // v9.23: Symbol-specific name
    ObjectDelete(0, objName);
    ObjectCreate(0, objName, OBJ_BUTTON, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, objName, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, objName, OBJPROP_YSIZE, height);
    ObjectSetString(0, objName, OBJPROP_TEXT, text);
    ObjectSetInteger(0, objName, OBJPROP_COLOR, clrWhite);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, clrBlack);
    ObjectSetInteger(0, objName, OBJPROP_FONTSIZE, 9);
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
    ObjectSetInteger(0, objName, OBJPROP_ZORDER, 10000);
}

void DashRectangle(string name, int x, int y, int width, int height, color clr) {
    string objName = DashObjName(name);  // v9.23: Symbol-specific name
    ObjectDelete(0, objName);
    ObjectCreate(0, objName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, objName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
    ObjectSetInteger(0, objName, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, objName, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, objName, OBJPROP_XSIZE, width);
    ObjectSetInteger(0, objName, OBJPROP_YSIZE, height);
    ObjectSetInteger(0, objName, OBJPROP_BGCOLOR, clr);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    ObjectSetInteger(0, objName, OBJPROP_BORDER_COLOR, CLR_BORDER);
    ObjectSetInteger(0, objName, OBJPROP_BACK, false);
    ObjectSetInteger(0, objName, OBJPROP_ZORDER, 9000);
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
    DeleteObjectsByPrefix("REOPEN_");    // v9.18: Reopen Cycle Monitor
    DeleteObjectsByPrefix("AUTOSAVE_");  // v9.22: Auto-Save Monitor
    DeleteObjectsByPrefix("COP_");       // v5.1: Close On Profit Panel
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
    DrawReopenTriggerLines();  // v9.24: Reopen trigger lines for STOP orders

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
//| Draw Reopen Trigger Lines (v9.24)                                |
//| Shows dotted lines for STOP orders waiting for reopen            |
//+------------------------------------------------------------------+
void DrawReopenTriggerLines() {
    if(!ShowReopenTriggerLines) return;
    if(!EnableCyclicReopen) return;

    // Draw Grid A Upper trigger lines (BUY STOP)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_EntryPrices[i] > 0 && IsLevelWaitingForReopen(GRID_A, ZONE_UPPER, i)) {
            CreateReopenTriggerLine(GRID_A, ZONE_UPPER, i, gridA_Upper_EntryPrices[i]);
        }
    }

    // Draw Grid B Lower trigger lines (SELL STOP)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Lower_EntryPrices[i] > 0 && IsLevelWaitingForReopen(GRID_B, ZONE_LOWER, i)) {
            CreateReopenTriggerLine(GRID_B, ZONE_LOWER, i, gridB_Lower_EntryPrices[i]);
        }
    }
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
