//+------------------------------------------------------------------+
//|                                                    ManualSR.mqh  |
//|                        Sugamara v3.0 - Manual S/R Drag & Drop    |
//|                                                                  |
//|  Drag & Drop per Support/Resistance manuali                      |
//|  - Linea Resistance (rossa)                                      |
//|  - Linea Support (verde)                                         |
//|  - Linea Activation (gold) per LIMIT/STOP mode                   |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| CONSTANTS                                                        |
//+------------------------------------------------------------------+
#define SR_LINE_RESISTANCE    "SUGAMARA_SR_RESISTANCE"
#define SR_LINE_SUPPORT       "SUGAMARA_SR_SUPPORT"
#define SR_LINE_ACTIVATION    "SUGAMARA_SR_ACTIVATION"
#define SR_LABEL_RESISTANCE   "SUGAMARA_LBL_RESISTANCE"
#define SR_LABEL_SUPPORT      "SUGAMARA_LBL_SUPPORT"
#define SR_LABEL_ACTIVATION   "SUGAMARA_LBL_ACTIVATION"

// Loss Zone Rectangles
#define SR_RECT_UPPER_LOSS    "SUGAMARA_RECT_UPPER_LOSS"
#define SR_RECT_LOWER_LOSS    "SUGAMARA_RECT_LOWER_LOSS"

// Dark red color for loss zones (v4.4.1 - darker and more muted)
#define CLR_LOSS_ZONE         C'180,50,50'

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES                                                 |
//+------------------------------------------------------------------+

double manualSR_Resistance = 0.0;
double manualSR_Support = 0.0;
double manualSR_Activation = 0.0;
bool manualSR_Initialized = false;
string manualSR_DragObject = "";

//+------------------------------------------------------------------+
//| Initialize Manual S/R System                                     |
//+------------------------------------------------------------------+
bool InitializeManualSR() {
    if(!Enable_ManualSR) {
        Print("INFO: Manual S/R is DISABLED");
        return true;
    }

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  INITIALIZING MANUAL S/R SYSTEM v4.4 (Dynamic Positioning)");
    Print("═══════════════════════════════════════════════════════════════════");

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // v4.4: Calculate spacing in price units
    double spacing = currentSpacing_Pips * symbolPoint * ((symbolDigits == 5 || symbolDigits == 3) ? 10 : 1);
    if(spacing == 0) {
        // Fallback: use ATR-based spacing if currentSpacing not yet set
        spacing = GetATRPips() * symbolPoint * 10;
        if(spacing == 0) spacing = 15 * symbolPoint * ((symbolDigits == 5 || symbolDigits == 3) ? 10 : 1);
    }

    // v4.4: S/R Formula = (N + 0.25) × spacing
    // Places S/R just after the last grid level
    double srMultiplier = GridLevelsPerSide + 0.25;
    // N=5 → 5.25 | N=7 → 7.25 | N=9 → 9.25

    // Use entryPoint if available, otherwise currentPrice
    double basePrice = (entryPoint > 0) ? entryPoint : currentPrice;

    // Initialize default positions with dynamic formula
    if(manualSR_Resistance == 0) {
        manualSR_Resistance = basePrice + (spacing * srMultiplier);
    }
    if(manualSR_Support == 0) {
        manualSR_Support = basePrice - (spacing * srMultiplier);
    }
    if(manualSR_Activation == 0) {
        manualSR_Activation = basePrice;
    }

    Print("  S/R Multiplier: ", DoubleToString(srMultiplier, 2), " (N+0.25 where N=", GridLevelsPerSide, ")");
    Print("  Spacing: ", DoubleToString(spacing / symbolPoint / ((symbolDigits == 5 || symbolDigits == 3) ? 10 : 1), 1), " pips");

    // Use manual values if provided in inputs
    // v5.2: RangeBox removed, only use activation price if provided
    if(LimitActivation_Price > 0) manualSR_Activation = LimitActivation_Price;

    // Create lines
    CreateSRLine(SR_LINE_RESISTANCE, manualSR_Resistance, MANUAL_SR_RESISTANCE_COLOR, "Resistance");
    CreateSRLine(SR_LINE_SUPPORT, manualSR_Support, MANUAL_SR_SUPPORT_COLOR, "Support");

    // Only create activation line if in LIMIT or STOP mode
    if(DefaultEntryMode == ENTRY_LIMIT || DefaultEntryMode == ENTRY_STOP) {
        CreateSRLine(SR_LINE_ACTIVATION, manualSR_Activation, MANUAL_SR_ACTIVATION_COLOR, "Activation");
    }

    manualSR_Initialized = true;

    // Create loss zone rectangles (faded red areas)
    UpdateLossZoneRectangles();

    Print("  Resistance: ", DoubleToString(manualSR_Resistance, _Digits));
    Print("  Support: ", DoubleToString(manualSR_Support, _Digits));
    Print("  Activation: ", DoubleToString(manualSR_Activation, _Digits));
    Print("  Loss Zones: ENABLED (Red rectangles)");
    Print("  Drag & Drop: ENABLED");
    Print("═══════════════════════════════════════════════════════════════════");

    return true;
}

//+------------------------------------------------------------------+
//| Create S/R Line                                                  |
//+------------------------------------------------------------------+
void CreateSRLine(string name, double price, color clr, string label) {
    // Delete if exists
    ObjectDelete(0, name);

    // Create horizontal line
    if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, price)) {
        Print("ERROR: Failed to create ", name);
        return;
    }

    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, MANUAL_SR_LINE_WIDTH);
    ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, name, OBJPROP_BACK, false);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, true);    // Enable selection
    ObjectSetInteger(0, name, OBJPROP_SELECTED, false);
    ObjectSetInteger(0, name, OBJPROP_ZORDER, 5000);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, label + ": " + DoubleToString(price, _Digits));

    // Create label
    if(MANUAL_SR_SHOW_LABELS) {
        string lblName = name + "_LBL";
        ObjectDelete(0, lblName);

        datetime labelTime = TimeCurrent() + PeriodSeconds() * 10;

        if(ObjectCreate(0, lblName, OBJ_TEXT, 0, labelTime, price)) {
            ObjectSetString(0, lblName, OBJPROP_TEXT, label + ": " + DoubleToString(price, _Digits));
            ObjectSetInteger(0, lblName, OBJPROP_COLOR, clr);
            ObjectSetInteger(0, lblName, OBJPROP_FONTSIZE, 9);
            ObjectSetString(0, lblName, OBJPROP_FONT, "Arial Bold");
            ObjectSetInteger(0, lblName, OBJPROP_ANCHOR, ANCHOR_LEFT);
        }
    }
}

//+------------------------------------------------------------------+
//| Create/Update Loss Zone Rectangles                               |
//| Upper: Above Resistance (SELL in loss)                           |
//| Lower: Below Support (BUY in loss)                               |
//+------------------------------------------------------------------+
void UpdateLossZoneRectangles() {
    if(!Enable_ManualSR || !manualSR_Initialized) return;
    if(manualSR_Resistance == 0 || manualSR_Support == 0) return;

    // Calculate zone height (extend 500 pips beyond S/R)
    double zoneExtension = 500 * symbolPoint * ((symbolDigits == 5 || symbolDigits == 3) ? 10 : 1);

    // Time range: from 100 bars ago to 100 bars in future
    datetime timeStart = iTime(_Symbol, PERIOD_CURRENT, 100);
    datetime timeEnd = TimeCurrent() + PeriodSeconds() * 100;

    //=== UPPER LOSS ZONE (Above Resistance) ===
    double upperZoneTop = manualSR_Resistance + zoneExtension;
    double upperZoneBottom = manualSR_Resistance;

    ObjectDelete(0, SR_RECT_UPPER_LOSS);
    if(ObjectCreate(0, SR_RECT_UPPER_LOSS, OBJ_RECTANGLE, 0, timeStart, upperZoneTop, timeEnd, upperZoneBottom)) {
        ObjectSetInteger(0, SR_RECT_UPPER_LOSS, OBJPROP_COLOR, CLR_LOSS_ZONE);
        ObjectSetInteger(0, SR_RECT_UPPER_LOSS, OBJPROP_FILL, true);
        ObjectSetInteger(0, SR_RECT_UPPER_LOSS, OBJPROP_BACK, true);
        ObjectSetInteger(0, SR_RECT_UPPER_LOSS, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, SR_RECT_UPPER_LOSS, OBJPROP_ZORDER, 0);
        ObjectSetString(0, SR_RECT_UPPER_LOSS, OBJPROP_TOOLTIP, "DANGER ZONE: Above Resistance - Potential Loss Area");
    }

    //=== LOWER LOSS ZONE (Below Support) ===
    double lowerZoneTop = manualSR_Support;
    double lowerZoneBottom = manualSR_Support - zoneExtension;

    ObjectDelete(0, SR_RECT_LOWER_LOSS);
    if(ObjectCreate(0, SR_RECT_LOWER_LOSS, OBJ_RECTANGLE, 0, timeStart, lowerZoneTop, timeEnd, lowerZoneBottom)) {
        ObjectSetInteger(0, SR_RECT_LOWER_LOSS, OBJPROP_COLOR, CLR_LOSS_ZONE);
        ObjectSetInteger(0, SR_RECT_LOWER_LOSS, OBJPROP_FILL, true);
        ObjectSetInteger(0, SR_RECT_LOWER_LOSS, OBJPROP_BACK, true);
        ObjectSetInteger(0, SR_RECT_LOWER_LOSS, OBJPROP_SELECTABLE, false);
        ObjectSetInteger(0, SR_RECT_LOWER_LOSS, OBJPROP_ZORDER, 0);
        ObjectSetString(0, SR_RECT_LOWER_LOSS, OBJPROP_TOOLTIP, "DANGER ZONE: Below Support - Potential Loss Area");
    }
}

//+------------------------------------------------------------------+
//| Update S/R Line                                                  |
//+------------------------------------------------------------------+
void UpdateSRLine(string name, double newPrice, string label) {
    if(ObjectFind(0, name) < 0) return;

    ObjectSetDouble(0, name, OBJPROP_PRICE, newPrice);
    ObjectSetString(0, name, OBJPROP_TOOLTIP, label + ": " + DoubleToString(newPrice, _Digits));

    // Update label
    if(MANUAL_SR_SHOW_LABELS) {
        string lblName = name + "_LBL";
        if(ObjectFind(0, lblName) >= 0) {
            ObjectSetDouble(0, lblName, OBJPROP_PRICE, newPrice);
            ObjectSetString(0, lblName, OBJPROP_TEXT, label + ": " + DoubleToString(newPrice, _Digits));
        }
    }
}

//+------------------------------------------------------------------+
//| Handle Chart Object Drag Event                                   |
//+------------------------------------------------------------------+
void OnManualSRDrag(string objectName) {
    if(!Enable_ManualSR || !manualSR_Initialized) return;

    // Check if it's one of our lines
    if(objectName == SR_LINE_RESISTANCE) {
        double newPrice = ObjectGetDouble(0, objectName, OBJPROP_PRICE);
        if(newPrice != manualSR_Resistance) {
            manualSR_Resistance = newPrice;
            UpdateSRLine(objectName, newPrice, "Resistance");

            Print("Manual S/R: Resistance moved to ", DoubleToString(newPrice, _Digits));

            // v5.2: Update breakout levels for Shield if in CASCADE_OVERLAP mode
            if(IsCascadeOverlapMode()) {
                upperBreakoutLevel = newPrice + Breakout_Buffer_Pips * symbolPoint * 10;
            }
        }
    }
    else if(objectName == SR_LINE_SUPPORT) {
        double newPrice = ObjectGetDouble(0, objectName, OBJPROP_PRICE);
        if(newPrice != manualSR_Support) {
            manualSR_Support = newPrice;
            UpdateSRLine(objectName, newPrice, "Support");

            Print("Manual S/R: Support moved to ", DoubleToString(newPrice, _Digits));

            // v5.2: Update breakout levels for Shield if in CASCADE_OVERLAP mode
            if(IsCascadeOverlapMode()) {
                lowerBreakoutLevel = newPrice - Breakout_Buffer_Pips * symbolPoint * 10;
            }
        }
    }
    else if(objectName == SR_LINE_ACTIVATION) {
        double newPrice = ObjectGetDouble(0, objectName, OBJPROP_PRICE);
        if(newPrice != manualSR_Activation) {
            manualSR_Activation = newPrice;
            UpdateSRLine(objectName, newPrice, "Activation");

            Print("Manual S/R: Activation moved to ", DoubleToString(newPrice, _Digits));
        }
    }

    // Update loss zone rectangles when S/R lines are moved
    UpdateLossZoneRectangles();

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Check Object End Drag Event                                      |
//+------------------------------------------------------------------+
void OnManualSREndDrag(long lparam, double dparam, string sparam) {
    if(!Enable_ManualSR || !manualSR_Initialized) return;

    // sparam contains the object name
    if(sparam == SR_LINE_RESISTANCE ||
       sparam == SR_LINE_SUPPORT ||
       sparam == SR_LINE_ACTIVATION) {
        OnManualSRDrag(sparam);
    }
}

//+------------------------------------------------------------------+
//| Get Manual Resistance                                            |
//+------------------------------------------------------------------+
double GetManualResistance() {
    return manualSR_Resistance;
}

//+------------------------------------------------------------------+
//| Get Manual Support                                               |
//+------------------------------------------------------------------+
double GetManualSupport() {
    return manualSR_Support;
}

//+------------------------------------------------------------------+
//| Get Manual Activation Level                                      |
//+------------------------------------------------------------------+
double GetManualActivation() {
    return manualSR_Activation;
}

//+------------------------------------------------------------------+
//| Set Manual S/R Values Programmatically                           |
//+------------------------------------------------------------------+
void SetManualSR(double resistance, double support, double activation = 0) {
    if(!Enable_ManualSR) return;

    if(resistance > 0) {
        manualSR_Resistance = resistance;
        UpdateSRLine(SR_LINE_RESISTANCE, resistance, "Resistance");
    }

    if(support > 0) {
        manualSR_Support = support;
        UpdateSRLine(SR_LINE_SUPPORT, support, "Support");
    }

    if(activation > 0) {
        manualSR_Activation = activation;
        UpdateSRLine(SR_LINE_ACTIVATION, activation, "Activation");
    }

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Check if Price Reached Activation Level                          |
//+------------------------------------------------------------------+
bool IsPriceAtActivation(double tolerance = 0) {
    if(!Enable_ManualSR) return true; // If disabled, always ready

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double tolPips = (tolerance == 0) ? 5 * symbolPoint * 10 : tolerance;

    return (MathAbs(currentPrice - manualSR_Activation) <= tolPips);
}

//+------------------------------------------------------------------+
//| Check if Price Broke Through Activation Level (for STOP mode)    |
//+------------------------------------------------------------------+
bool IsPriceAboveActivation() {
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    return (currentPrice > manualSR_Activation);
}

bool IsPriceBelowActivation() {
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    return (currentPrice < manualSR_Activation);
}

//+------------------------------------------------------------------+
//| Remove Manual S/R Lines                                          |
//+------------------------------------------------------------------+
void RemoveManualSRLines() {
    ObjectDelete(0, SR_LINE_RESISTANCE);
    ObjectDelete(0, SR_LINE_SUPPORT);
    ObjectDelete(0, SR_LINE_ACTIVATION);
    ObjectDelete(0, SR_LINE_RESISTANCE + "_LBL");
    ObjectDelete(0, SR_LINE_SUPPORT + "_LBL");
    ObjectDelete(0, SR_LINE_ACTIVATION + "_LBL");

    // Remove loss zone rectangles
    ObjectDelete(0, SR_RECT_UPPER_LOSS);
    ObjectDelete(0, SR_RECT_LOWER_LOSS);

    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Deinitialize Manual S/R                                          |
//+------------------------------------------------------------------+
void DeinitializeManualSR() {
    RemoveManualSRLines();
    manualSR_Initialized = false;

    Print("Manual S/R: Deinitialized");
    Print("  Final Resistance: ", DoubleToString(manualSR_Resistance, _Digits));
    Print("  Final Support: ", DoubleToString(manualSR_Support, _Digits));
}

