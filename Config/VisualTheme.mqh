//+------------------------------------------------------------------+
//|                                              VisualTheme.mqh     |
//|                        Sugamara - DUNE Visual Theme Constants    |
//|                                                                  |
//|  Colori hardcodati - editabili SOLO via codice sorgente          |
//|  NON visibili nelle impostazioni EA                              |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| CHART THEME (DUNE/Arrakis Desert Theme)                          |
//| "The Spice Must Flow"                                            |
//+------------------------------------------------------------------+
#define THEME_CHART_BACKGROUND    C'25,12,35'       // Viola Scurissimo (Desert Night)
#define THEME_CANDLE_BULL         clrDodgerBlue     // Blu Splendente (Fremen Blue)
#define THEME_CANDLE_BEAR         clrYellow         // Giallo (Spice Orange/Gold)

//+------------------------------------------------------------------+
//| DASHBOARD COLORS                                                  |
//+------------------------------------------------------------------+
#define THEME_DASHBOARD_BG        C'20,60,80'       // Blu Turchese
#define THEME_DASHBOARD_TEXT      clrCyan           // Azzurro
#define THEME_DASHBOARD_ACCENT    clrAqua           // Acqua

//+------------------------------------------------------------------+
//| GRID LINE COLORS (Order Types)                                    |
//+------------------------------------------------------------------+
#define COLOR_GRIDLINE_BUY_LIMIT  clrDarkGreen      // BUY LIMIT: Verde Scuro
#define COLOR_GRIDLINE_BUY_STOP   clrBlue           // BUY STOP: Blu
#define COLOR_GRIDLINE_SELL_LIMIT clrOrange         // SELL LIMIT: Arancione
#define COLOR_GRIDLINE_SELL_STOP  clrPlum           // SELL STOP: Viola Chiaro
#define COLOR_GRIDZERO_LINE       clrChartreuse     // v7.1: Grid Zero - Giallo-verde fluorescente
#define GRIDLINE_WIDTH            3                  // Spessore Linee Grid
#define GRIDZERO_LINE_WIDTH       5                  // v7.1: Spessore Linee Grid Zero (priorità visiva)

//+------------------------------------------------------------------+
//| LEGACY GRID COLORS (Grid A/B zones)                               |
//+------------------------------------------------------------------+
#define COLOR_ENTRY_POINT         clrCyan           // Entry Point Line
#define COLOR_GRID_A_UPPER        C'100,180,255'    // Grid A Upper Zone (Azure)
#define COLOR_GRID_A_LOWER        C'60,140,205'     // Grid A Lower Zone
#define COLOR_GRID_B_UPPER        C'100,220,255'    // Grid B Upper Zone (Cyan)
#define COLOR_GRID_B_LOWER        C'60,180,205'     // Grid B Lower Zone

//+------------------------------------------------------------------+
//| TP VISUAL LINES                                                   |
//+------------------------------------------------------------------+
#define TP_LINE_BUY_COLOR         clrLightYellow    // TP Color for BUY orders
#define TP_LINE_SELL_COLOR        clrRed            // TP Color for SELL orders
#define TP_LINE_STYLE             STYLE_DASH        // TP Line Style
#define TP_LINE_WIDTH             1                  // TP Line Width

//+------------------------------------------------------------------+
//| MANUAL S/R COLORS                                                 |
//+------------------------------------------------------------------+
#define MANUAL_SR_RESISTANCE_COLOR   clrRed         // Resistance Line
#define MANUAL_SR_SUPPORT_COLOR      clrLime        // Support Line
#define MANUAL_SR_ACTIVATION_COLOR   clrGold        // Activation Level
#define MANUAL_SR_LINE_WIDTH         2              // Line Width
#define MANUAL_SR_SHOW_LABELS        true           // Show Labels

//+------------------------------------------------------------------+
//| SHIELD ZONES VISUAL                                               |
//+------------------------------------------------------------------+
#define SHIELDZONES_TRANSPARENCY     210            // Transparency (0=opaque, 255=invisible)
#define SHIELDZONE_PHASE1_COLOR      clrYellow      // Phase 1 (Warning) - Yellow
#define SHIELDZONE_PHASE2_COLOR      clrOrange      // Phase 2 (Pre-Shield) - Orange
#define SHIELDZONE_PHASE3_COLOR      C'160,40,40'   // Phase 3 (Breakout) - Dark Red
#define SHIELDENTRY_LINE_COLOR       clrLightYellow // Shield Entry Line - Giallo Chiaro (v5.9.1)
#define SHIELDENTRY_LINE_WIDTH       2              // Shield Entry Line Width
#define SHIELDENTRY_LINE_STYLE       STYLE_DASH     // Shield Entry Line Style
#define PROFITZONE_COLOR             clrLime        // Profit Zone - Green
#define PROFITZONE_TRANSPARENCY      220            // Profit Zone Transparency

//+------------------------------------------------------------------+
