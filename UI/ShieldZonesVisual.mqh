//+------------------------------------------------------------------+
//|                                          ShieldZonesVisual.mqh   |
//|                        Sugamara v3.0 - Shield Zones Visual       |
//|                                                                  |
//|  Fasce colorate per le 3 fasi dello Shield:                      |
//|  - Fase 1 (Warning): Gialla                                      |
//|  - Fase 2 (Pre-Shield): Arancione                                |
//|  - Fase 3 (Breakout/Active): Rossa                               |
//|  + Linee Entry Shield (rosso scuro)                              |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| OBJECT NAME CONSTANTS                                            |
//+------------------------------------------------------------------+
#define SHIELD_ZONE_PHASE1_UP      "SUGAMARA_SHIELD_ZONE_P1_UP"
#define SHIELD_ZONE_PHASE1_DOWN    "SUGAMARA_SHIELD_ZONE_P1_DOWN"
#define SHIELD_ZONE_PHASE2_UP      "SUGAMARA_SHIELD_ZONE_P2_UP"
#define SHIELD_ZONE_PHASE2_DOWN    "SUGAMARA_SHIELD_ZONE_P2_DOWN"
#define SHIELD_ZONE_PHASE3_UP      "SUGAMARA_SHIELD_ZONE_P3_UP"
#define SHIELD_ZONE_PHASE3_DOWN    "SUGAMARA_SHIELD_ZONE_P3_DOWN"
#define SHIELD_ENTRY_LINE_UP       "SUGAMARA_SHIELD_ENTRY_UP"
#define SHIELD_ENTRY_LINE_DOWN     "SUGAMARA_SHIELD_ENTRY_DOWN"
#define SHIELD_ENTRY_LABEL_UP      "SUGAMARA_SHIELD_LABEL_UP"
#define SHIELD_ENTRY_LABEL_DOWN    "SUGAMARA_SHIELD_LABEL_DOWN"
#define PROFIT_ZONE_CENTER         "SUGAMARA_PROFIT_ZONE"

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+
bool shieldZonesInitialized = false;
datetime shieldZonesStartTime = 0;

// Zone price levels (cached)
double szWarningZoneUp = 0;
double szWarningZoneDown = 0;
double szLastGridUp = 0;          // Ultimo livello Grid B (Upper)
double szLastGridDown = 0;        // Ultimo livello Grid A (Lower)
double szBreakoutUp = 0;          // Upper Breakout Level
double szBreakoutDown = 0;        // Lower Breakout Level
double szShieldEntryUp = 0;       // Entry Shield SHORT
double szShieldEntryDown = 0;     // Entry Shield LONG

//+------------------------------------------------------------------+
//| Initialize Shield Zones Visual                                    |
//+------------------------------------------------------------------+
bool InitializeShieldZonesVisual()
{
   if(!Enable_ShieldZonesVisual) {
      Print("[ShieldZones] Visual zones: DISABLED");
      return true;
   }

   // v5.2: Shield zones available for CASCADE_OVERLAP mode
   if(!IsCascadeOverlapMode()) {
      Print("[ShieldZones] Visual zones only available in CASCADE_OVERLAP mode");
      return true;
   }

   Print("=============================================================");
   Print("  INITIALIZING SHIELD ZONES VISUAL");
   Print("=============================================================");

   // Set start time for zones
   shieldZonesStartTime = TimeCurrent();

   // Calculate zone levels
   if(!CalculateShieldZoneLevels()) {
      Print("[ShieldZones] ERROR: Failed to calculate zone levels");
      return false;
   }

   // Create visual zones
   CreateAllShieldZones();

   shieldZonesInitialized = true;

   Print("  Phase 1 (Warning): Yellow zones created");
   Print("  Phase 2 (Pre-Shield): Orange zones created");
   Print("  Phase 3 (Breakout): Red zones created");
   Print("  Shield Entry Lines: Dark red lines created");
   if(Enable_ProfitZoneVisual) {
      Print("  Profit Zone: Green zone created (central area)");
   }
   Print("  Danger Zones Transparency: ", ShieldZones_Transparency);
   Print("  Profit Zone Transparency: ", ProfitZone_Transparency);
   Print("=============================================================");

   return true;
}

//+------------------------------------------------------------------+
//| Calculate Shield Zone Price Levels                                |
//| v5.10 FIX: Ora usa i valori effettivi da GridHelpers.mqh          |
//|            invece di calcoli separati con Warning_Zone_Percent    |
//|            e Breakout_Buffer_Pips. Questo garantisce che la       |
//|            visualizzazione corrisponda esattamente alla logica.   |
//+------------------------------------------------------------------+
bool CalculateShieldZoneLevels()
{
   // Get range box levels
   if(shieldZone.resistance == 0 || shieldZone.support == 0) {
      Print("[ShieldZones] ERROR: ShieldZone not initialized");
      return false;
   }

   // v5.10 FIX: Usa i valori effettivi calcolati in GridHelpers.mqh
   // Questi sono gli stessi valori usati dalla logica Shield in ShieldManager.mqh

   // Warning Zone levels (Phase 1) - usa valori da shieldZone struct
   // warningZoneUp/Down sono calcolati come: entryPoint +/- (spacing * (GridLevelsPerSide - 0.5))
   szWarningZoneUp = shieldZone.warningZoneUp;
   szWarningZoneDown = shieldZone.warningZoneDown;

   // Last Grid levels (Phase 2 boundary) - support e resistance
   // Questi sono gli ultimi livelli della grid (N * spacing)
   szLastGridUp = shieldZone.resistance;
   szLastGridDown = shieldZone.support;

   // Breakout levels (Phase 3 boundary) - usa valori globali da GridHelpers
   // upperBreakoutLevel/lowerBreakoutLevel sono calcolati come: entryPoint +/- (spacing * (GridLevelsPerSide + 0.5))
   szBreakoutUp = upperBreakoutLevel;
   szBreakoutDown = lowerBreakoutLevel;

   // Shield Entry levels (where market order would execute)
   szShieldEntryUp = szBreakoutUp;
   szShieldEntryDown = szBreakoutDown;

   if(DetailedLogging) {
      Print("[ShieldZones] Zone Levels Calculated:");
      PrintFormat("  Warning Zone UP: %.5f", szWarningZoneUp);
      PrintFormat("  Last Grid UP: %.5f", szLastGridUp);
      PrintFormat("  Breakout UP: %.5f", szBreakoutUp);
      PrintFormat("  Shield Entry UP: %.5f", szShieldEntryUp);
      Print("  ---");
      PrintFormat("  Warning Zone DOWN: %.5f", szWarningZoneDown);
      PrintFormat("  Last Grid DOWN: %.5f", szLastGridDown);
      PrintFormat("  Breakout DOWN: %.5f", szBreakoutDown);
      PrintFormat("  Shield Entry DOWN: %.5f", szShieldEntryDown);
   }

   return true;
}

//+------------------------------------------------------------------+
//| Create All Shield Zones                                           |
//+------------------------------------------------------------------+
void CreateAllShieldZones()
{
   // Far future time for zone extension
   datetime futureTime = D'2100.01.01 00:00';

   //------------------------------------------------------------------
   // UPPER ZONES
   //------------------------------------------------------------------

   // Phase 1 UP (Warning) - From Warning Zone to Last Grid
   CreateShieldZoneRectangle(
      SHIELD_ZONE_PHASE1_UP,
      shieldZonesStartTime, szWarningZoneUp,
      futureTime, szLastGridUp,
      ShieldZone_Phase1_Color,
      "Phase 1 Warning UP"
   );

   // Phase 2 UP (Pre-Shield) - From Last Grid to Breakout
   CreateShieldZoneRectangle(
      SHIELD_ZONE_PHASE2_UP,
      shieldZonesStartTime, szLastGridUp,
      futureTime, szBreakoutUp,
      ShieldZone_Phase2_Color,
      "Phase 2 Pre-Shield UP"
   );

   // Phase 3 UP (Breakout/Active) - From Breakout to Extended
   double extendedUp = szBreakoutUp + (szBreakoutUp - szLastGridUp);
   CreateShieldZoneRectangle(
      SHIELD_ZONE_PHASE3_UP,
      shieldZonesStartTime, szBreakoutUp,
      futureTime, extendedUp,
      ShieldZone_Phase3_Color,
      "Phase 3 Breakout UP"
   );

   //------------------------------------------------------------------
   // LOWER ZONES
   //------------------------------------------------------------------

   // Phase 1 DOWN (Warning) - From Warning Zone to Last Grid
   CreateShieldZoneRectangle(
      SHIELD_ZONE_PHASE1_DOWN,
      shieldZonesStartTime, szLastGridDown,
      futureTime, szWarningZoneDown,
      ShieldZone_Phase1_Color,
      "Phase 1 Warning DOWN"
   );

   // Phase 2 DOWN (Pre-Shield) - From Last Grid to Breakout
   CreateShieldZoneRectangle(
      SHIELD_ZONE_PHASE2_DOWN,
      shieldZonesStartTime, szBreakoutDown,
      futureTime, szLastGridDown,
      ShieldZone_Phase2_Color,
      "Phase 2 Pre-Shield DOWN"
   );

   // Phase 3 DOWN (Breakout/Active) - From Breakout to Extended
   double extendedDown = szBreakoutDown - (szLastGridDown - szBreakoutDown);
   CreateShieldZoneRectangle(
      SHIELD_ZONE_PHASE3_DOWN,
      shieldZonesStartTime, extendedDown,
      futureTime, szBreakoutDown,
      ShieldZone_Phase3_Color,
      "Phase 3 Breakout DOWN"
   );

   //------------------------------------------------------------------
   // SHIELD ENTRY LINES
   //------------------------------------------------------------------

   // Entry line UP (where Shield SHORT would enter)
   CreateShieldEntryLine(
      SHIELD_ENTRY_LINE_UP,
      szShieldEntryUp,
      "Shield SHORT Entry"
   );

   // Entry line DOWN (where Shield LONG would enter)
   CreateShieldEntryLine(
      SHIELD_ENTRY_LINE_DOWN,
      szShieldEntryDown,
      "Shield LONG Entry"
   );

   //------------------------------------------------------------------
   // PROFIT ZONE (Green - Central Area)
   //------------------------------------------------------------------
   if(Enable_ProfitZoneVisual) {
      CreateProfitZoneRectangle(
         PROFIT_ZONE_CENTER,
         shieldZonesStartTime, szWarningZoneDown,
         futureTime, szWarningZoneUp,
         ProfitZone_Color,
         "PROFIT ZONE - Grid Operating Area"
      );
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Create Shield Zone Rectangle                                      |
//+------------------------------------------------------------------+
void CreateShieldZoneRectangle(string name, datetime time1, double price1,
                                datetime time2, double price2,
                                color clr, string tooltip)
{
   // Delete if exists
   ObjectDelete(0, name);

   // Create rectangle
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2)) {
      Print("[ShieldZones] ERROR: Failed to create rectangle ", name);
      return;
   }

   // Convert color to ARGB with transparency
   uint argbColor = ColorToARGB(clr, ShieldZones_Transparency);

   // Set properties
   ObjectSetInteger(0, name, OBJPROP_COLOR, argbColor);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);           // Behind candles
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);         // Hide from object list
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);

   if(DetailedLogging) {
      PrintFormat("[ShieldZones] Created: %s (%.5f - %.5f)", name, price1, price2);
   }
}

//+------------------------------------------------------------------+
//| Create Profit Zone Rectangle (with separate transparency)         |
//+------------------------------------------------------------------+
void CreateProfitZoneRectangle(string name, datetime time1, double price1,
                               datetime time2, double price2,
                               color clr, string tooltip)
{
   // Delete if exists
   ObjectDelete(0, name);

   // Create rectangle
   if(!ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, price1, time2, price2)) {
      Print("[ShieldZones] ERROR: Failed to create profit zone ", name);
      return;
   }

   // Convert color to ARGB with PROFIT ZONE transparency (more transparent)
   uint argbColor = ColorToARGB(clr, ProfitZone_Transparency);

   // Set properties
   ObjectSetInteger(0, name, OBJPROP_COLOR, argbColor);
   ObjectSetInteger(0, name, OBJPROP_FILL, true);
   ObjectSetInteger(0, name, OBJPROP_BACK, true);           // Behind candles
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, tooltip);

   if(DetailedLogging) {
      PrintFormat("[ShieldZones] Created PROFIT ZONE: %s (%.5f - %.5f)", name, price1, price2);
   }
}

//+------------------------------------------------------------------+
//| Create Shield Entry Line                                          |
//+------------------------------------------------------------------+
void CreateShieldEntryLine(string name, double price, string label)
{
   // Delete if exists
   ObjectDelete(0, name);

   // Create horizontal line
   if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price)) {
      Print("[ShieldZones] ERROR: Failed to create entry line ", name);
      return;
   }

   // Set properties
   ObjectSetInteger(0, name, OBJPROP_COLOR, ShieldEntry_Line_Color);
   ObjectSetInteger(0, name, OBJPROP_WIDTH, ShieldEntry_Line_Width);
   ObjectSetInteger(0, name, OBJPROP_STYLE, ShieldEntry_Line_Style);
   ObjectSetInteger(0, name, OBJPROP_BACK, false);          // In front for visibility
   ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
   ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
   ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);
   ObjectSetString(0, name, OBJPROP_TOOLTIP, label + " @ " + DoubleToString(price, _Digits));

   // Create label for the line
   string labelName = name + "_LABEL";
   ObjectDelete(0, labelName);

   if(ObjectCreate(0, labelName, OBJ_TEXT, 0, TimeCurrent(), price)) {
      ObjectSetString(0, labelName, OBJPROP_TEXT, "  " + label);
      ObjectSetInteger(0, labelName, OBJPROP_COLOR, ShieldEntry_Line_Color);
      ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
      ObjectSetString(0, labelName, OBJPROP_FONT, "Arial Bold");
      ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
      ObjectSetInteger(0, labelName, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
   }

   if(DetailedLogging) {
      PrintFormat("[ShieldZones] Created entry line: %s @ %.5f", label, price);
   }
}

//+------------------------------------------------------------------+
//| Update Shield Zones (called when levels change)                   |
//+------------------------------------------------------------------+
void UpdateShieldZones()
{
   if(!Enable_ShieldZonesVisual || !shieldZonesInitialized) {
      return;
   }

   // Recalculate levels
   if(!CalculateShieldZoneLevels()) {
      return;
   }

   datetime futureTime = D'2100.01.01 00:00';

   //------------------------------------------------------------------
   // UPDATE UPPER ZONES
   //------------------------------------------------------------------

   // Phase 1 UP
   ObjectSetDouble(0, SHIELD_ZONE_PHASE1_UP, OBJPROP_PRICE, 0, szWarningZoneUp);
   ObjectSetDouble(0, SHIELD_ZONE_PHASE1_UP, OBJPROP_PRICE, 1, szLastGridUp);

   // Phase 2 UP
   ObjectSetDouble(0, SHIELD_ZONE_PHASE2_UP, OBJPROP_PRICE, 0, szLastGridUp);
   ObjectSetDouble(0, SHIELD_ZONE_PHASE2_UP, OBJPROP_PRICE, 1, szBreakoutUp);

   // Phase 3 UP
   double extendedUp = szBreakoutUp + (szBreakoutUp - szLastGridUp);
   ObjectSetDouble(0, SHIELD_ZONE_PHASE3_UP, OBJPROP_PRICE, 0, szBreakoutUp);
   ObjectSetDouble(0, SHIELD_ZONE_PHASE3_UP, OBJPROP_PRICE, 1, extendedUp);

   //------------------------------------------------------------------
   // UPDATE LOWER ZONES
   //------------------------------------------------------------------

   // Phase 1 DOWN
   ObjectSetDouble(0, SHIELD_ZONE_PHASE1_DOWN, OBJPROP_PRICE, 0, szLastGridDown);
   ObjectSetDouble(0, SHIELD_ZONE_PHASE1_DOWN, OBJPROP_PRICE, 1, szWarningZoneDown);

   // Phase 2 DOWN
   ObjectSetDouble(0, SHIELD_ZONE_PHASE2_DOWN, OBJPROP_PRICE, 0, szBreakoutDown);
   ObjectSetDouble(0, SHIELD_ZONE_PHASE2_DOWN, OBJPROP_PRICE, 1, szLastGridDown);

   // Phase 3 DOWN
   double extendedDown = szBreakoutDown - (szLastGridDown - szBreakoutDown);
   ObjectSetDouble(0, SHIELD_ZONE_PHASE3_DOWN, OBJPROP_PRICE, 0, extendedDown);
   ObjectSetDouble(0, SHIELD_ZONE_PHASE3_DOWN, OBJPROP_PRICE, 1, szBreakoutDown);

   //------------------------------------------------------------------
   // UPDATE ENTRY LINES
   //------------------------------------------------------------------
   ObjectSetDouble(0, SHIELD_ENTRY_LINE_UP, OBJPROP_PRICE, 0, szShieldEntryUp);
   ObjectSetDouble(0, SHIELD_ENTRY_LINE_DOWN, OBJPROP_PRICE, 0, szShieldEntryDown);

   // Update labels position
   string labelUp = SHIELD_ENTRY_LINE_UP + "_LABEL";
   string labelDown = SHIELD_ENTRY_LINE_DOWN + "_LABEL";
   ObjectSetDouble(0, labelUp, OBJPROP_PRICE, 0, szShieldEntryUp);
   ObjectSetDouble(0, labelDown, OBJPROP_PRICE, 0, szShieldEntryDown);
   ObjectSetInteger(0, labelUp, OBJPROP_TIME, 0, TimeCurrent());
   ObjectSetInteger(0, labelDown, OBJPROP_TIME, 0, TimeCurrent());

   //------------------------------------------------------------------
   // UPDATE PROFIT ZONE
   //------------------------------------------------------------------
   if(Enable_ProfitZoneVisual) {
      ObjectSetDouble(0, PROFIT_ZONE_CENTER, OBJPROP_PRICE, 0, szWarningZoneDown);
      ObjectSetDouble(0, PROFIT_ZONE_CENTER, OBJPROP_PRICE, 1, szWarningZoneUp);
   }

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Remove All Shield Zones                                           |
//+------------------------------------------------------------------+
void RemoveAllShieldZones()
{
   ObjectDelete(0, SHIELD_ZONE_PHASE1_UP);
   ObjectDelete(0, SHIELD_ZONE_PHASE1_DOWN);
   ObjectDelete(0, SHIELD_ZONE_PHASE2_UP);
   ObjectDelete(0, SHIELD_ZONE_PHASE2_DOWN);
   ObjectDelete(0, SHIELD_ZONE_PHASE3_UP);
   ObjectDelete(0, SHIELD_ZONE_PHASE3_DOWN);
   ObjectDelete(0, SHIELD_ENTRY_LINE_UP);
   ObjectDelete(0, SHIELD_ENTRY_LINE_DOWN);
   ObjectDelete(0, SHIELD_ENTRY_LINE_UP + "_LABEL");
   ObjectDelete(0, SHIELD_ENTRY_LINE_DOWN + "_LABEL");
   ObjectDelete(0, PROFIT_ZONE_CENTER);

   ChartRedraw(0);

   Print("[ShieldZones] All visual zones removed");
}

//+------------------------------------------------------------------+
//| Deinitialize Shield Zones Visual                                  |
//+------------------------------------------------------------------+
void DeinitializeShieldZonesVisual()
{
   RemoveAllShieldZones();
   shieldZonesInitialized = false;
   Print("[ShieldZones] Visual system deinitialized");
}

//+------------------------------------------------------------------+
//| Toggle Shield Zones Visibility                                    |
//+------------------------------------------------------------------+
void ToggleShieldZonesVisibility(bool visible)
{
   int visibility = visible ? OBJ_ALL_PERIODS : OBJ_NO_PERIODS;

   ObjectSetInteger(0, SHIELD_ZONE_PHASE1_UP, OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, SHIELD_ZONE_PHASE1_DOWN, OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, SHIELD_ZONE_PHASE2_UP, OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, SHIELD_ZONE_PHASE2_DOWN, OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, SHIELD_ZONE_PHASE3_UP, OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, SHIELD_ZONE_PHASE3_DOWN, OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, SHIELD_ENTRY_LINE_UP, OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, SHIELD_ENTRY_LINE_DOWN, OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, SHIELD_ENTRY_LINE_UP + "_LABEL", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, SHIELD_ENTRY_LINE_DOWN + "_LABEL", OBJPROP_TIMEFRAMES, visibility);
   ObjectSetInteger(0, PROFIT_ZONE_CENTER, OBJPROP_TIMEFRAMES, visibility);

   ChartRedraw(0);

   Print("[ShieldZones] Visibility: ", (visible ? "ON" : "OFF"));
}

//+------------------------------------------------------------------+
//| Log Shield Zones Report                                           |
//+------------------------------------------------------------------+
void LogShieldZonesReport()
{
   Print("=============================================================");
   Print("  SHIELD ZONES VISUAL REPORT");
   Print("=============================================================");
   PrintFormat("  Enabled: %s", (Enable_ShieldZonesVisual ? "YES" : "NO"));
   PrintFormat("  Initialized: %s", (shieldZonesInitialized ? "YES" : "NO"));
   PrintFormat("  Danger Zones Transparency: %d", ShieldZones_Transparency);
   PrintFormat("  Profit Zone Enabled: %s", (Enable_ProfitZoneVisual ? "YES" : "NO"));
   PrintFormat("  Profit Zone Transparency: %d", ProfitZone_Transparency);
   Print("-------------------------------------------------------------");
   Print("  UPPER ZONES (Danger):");
   PrintFormat("    Phase 1 (Warning):    %.5f - %.5f", szWarningZoneUp, szLastGridUp);
   PrintFormat("    Phase 2 (Pre-Shield): %.5f - %.5f", szLastGridUp, szBreakoutUp);
   PrintFormat("    Phase 3 (Breakout):   %.5f - ...", szBreakoutUp);
   PrintFormat("    Shield Entry SHORT:   %.5f", szShieldEntryUp);
   Print("-------------------------------------------------------------");
   Print("  PROFIT ZONE (Green - Central):");
   PrintFormat("    From: %.5f  To: %.5f", szWarningZoneDown, szWarningZoneUp);
   PrintFormat("    Range: %.1f pips", (szWarningZoneUp - szWarningZoneDown) / symbolPoint / 10);
   Print("-------------------------------------------------------------");
   Print("  LOWER ZONES (Danger):");
   PrintFormat("    Phase 1 (Warning):    %.5f - %.5f", szLastGridDown, szWarningZoneDown);
   PrintFormat("    Phase 2 (Pre-Shield): %.5f - %.5f", szBreakoutDown, szLastGridDown);
   PrintFormat("    Phase 3 (Breakout):   ... - %.5f", szBreakoutDown);
   PrintFormat("    Shield Entry LONG:    %.5f", szShieldEntryDown);
   Print("=============================================================");
}

