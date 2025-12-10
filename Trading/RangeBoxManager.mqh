//+------------------------------------------------------------------+
//|                                            RangeBoxManager.mqh   |
//|                        Sugamara v2.0 - Range Box Manager         |
//|                                                                  |
//|  Gestisce il Range Box per la modalità NEUTRAL_RANGEBOX          |
//|  - Calcolo automatico/manuale dei livelli Resistance/Support     |
//|  - Monitoraggio breakout                                         |
//|  - Visualizzazione grafica del box                               |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Inizializza Range Box (solo se NEUTRAL_RANGEBOX)                 |
//+------------------------------------------------------------------+
bool InitializeRangeBox()
{
   if(!IsRangeBoxAvailable())
   {
      if(DetailedLogging)
         Print("[RangeBox] Skip - Mode is not RANGEBOX");
      return true;  // Non è un errore, semplicemente skip
   }

   Print("[RangeBox] Initializing Range Box...");

   // Calcola i livelli
   if(!CalculateRangeBoxLevels(rangeBox_Resistance, rangeBox_Support))
   {
      Print("[RangeBox] ERROR: Failed to calculate Range Box levels");
      return false;
   }

   // Salva timestamp
   rangeBox_LastCalc = TimeCurrent();

   // Verifica stato iniziale prezzo
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   UpdateRangeBoxState(currentPrice);

   // Log
   PrintFormat("[RangeBox] Initialized: Resistance=%.5f, Support=%.5f, Range=%.1f pips",
               rangeBox_Resistance, rangeBox_Support,
               (rangeBox_Resistance - rangeBox_Support) / symbolPoint /
               ((symbolDigits == 5 || symbolDigits == 3) ? 10 : 1));

   // Disegna visualizzazione
   if(ShowRangeBox)
      DrawRangeBoxVisualization();

   return true;
}

//+------------------------------------------------------------------+
//| Aggiorna stato Range Box (chiamato ogni tick)                    |
//+------------------------------------------------------------------+
void UpdateRangeBoxState(double currentPrice)
{
   if(!IsRangeBoxAvailable())
      return;

   // Stato precedente
   bool wasBreakoutUp = isBreakoutUp;
   bool wasBreakoutDown = isBreakoutDown;

   // Aggiorna flags
   isBreakoutUp = IsBreakoutUp(currentPrice);
   isBreakoutDown = IsBreakoutDown(currentPrice);
   isInsideRange = IsPriceInsideRange(currentPrice);

   // Rileva nuovi breakout
   if(isBreakoutUp && !wasBreakoutUp)
   {
      OnBreakoutUp(currentPrice);
   }
   else if(isBreakoutDown && !wasBreakoutDown)
   {
      OnBreakoutDown(currentPrice);
   }

   // Rileva rientro nel range
   if(isInsideRange && (wasBreakoutUp || wasBreakoutDown))
   {
      OnReturnToRange(currentPrice);
   }
}

//+------------------------------------------------------------------+
//| Evento: Breakout sopra Resistance                                |
//+------------------------------------------------------------------+
void OnBreakoutUp(double price)
{
   LogMessage(LOG_WARNING, StringFormat(
      "[RangeBox] BREAKOUT UP! Price %.5f > Resistance %.5f",
      price, rangeBox_Resistance));

   // Se hedging abilitato, apri hedge SHORT
   if(IsHedgingAvailable())
   {
      OpenHedgePosition(HEDGE_SHORT);
   }

   // Alert
   if(EnableAlerts)
      Alert("SUGAMARA: Breakout UP - Hedge SHORT opened");
}

//+------------------------------------------------------------------+
//| Evento: Breakout sotto Support                                   |
//+------------------------------------------------------------------+
void OnBreakoutDown(double price)
{
   LogMessage(LOG_WARNING, StringFormat(
      "[RangeBox] BREAKOUT DOWN! Price %.5f < Support %.5f",
      price, rangeBox_Support));

   // Se hedging abilitato, apri hedge LONG
   if(IsHedgingAvailable())
   {
      OpenHedgePosition(HEDGE_LONG);
   }

   // Alert
   if(EnableAlerts)
      Alert("SUGAMARA: Breakout DOWN - Hedge LONG opened");
}

//+------------------------------------------------------------------+
//| Evento: Ritorno nel range dopo breakout                          |
//+------------------------------------------------------------------+
void OnReturnToRange(double price)
{
   LogMessage(LOG_INFO, StringFormat(
      "[RangeBox] Returned to range - Price %.5f", price));

   // Chiudi eventuali hedge aperti
   if(IsHedgingAvailable() && currentHedgeDirection != HEDGE_NONE)
   {
      CloseHedgePosition();
   }
}

//+------------------------------------------------------------------+
//| Ricalcola Range Box (per modalità ATR_BASED)                     |
//+------------------------------------------------------------------+
bool RecalculateRangeBox()
{
   if(!IsRangeBoxAvailable())
      return true;

   // Ricalcola solo per ATR_BASED (le altre sono fisse)
   if(RangeBoxMode != RANGEBOX_ATR_BASED)
      return true;

   // Verifica se è passato abbastanza tempo
   datetime now = TimeCurrent();
   int secondsElapsed = (int)(now - rangeBox_LastCalc);

   // Ricalcola ogni ATR_RecalcHours ore
   if(secondsElapsed < ATR_RecalcHours * 3600)
      return true;

   // Calcola nuovi livelli
   double newResistance, newSupport;
   if(!CalculateRangeBoxLevels(newResistance, newSupport))
      return false;

   // Verifica se sono cambiati significativamente (>10%)
   double oldRange = rangeBox_Resistance - rangeBox_Support;
   double newRange = newResistance - newSupport;
   double changePercent = MathAbs((newRange - oldRange) / oldRange) * 100;

   if(changePercent > 10.0)
   {
      PrintFormat("[RangeBox] Recalculated: R=%.5f→%.5f, S=%.5f→%.5f (%.1f%% change)",
                  rangeBox_Resistance, newResistance,
                  rangeBox_Support, newSupport,
                  changePercent);

      rangeBox_Resistance = newResistance;
      rangeBox_Support = newSupport;
      rangeBox_LastCalc = now;

      // Ridisegna
      if(ShowRangeBox)
         DrawRangeBoxVisualization();
   }

   return true;
}

//+------------------------------------------------------------------+
//| Disegna visualizzazione Range Box sul chart                      |
//+------------------------------------------------------------------+
void DrawRangeBoxVisualization()
{
   if(!ShowRangeBox || !IsRangeBoxAvailable())
      return;

   string prefix = "SUGAMARA_RANGEBOX_";

   // Cancella oggetti precedenti
   ObjectDelete(0, prefix + "RESISTANCE");
   ObjectDelete(0, prefix + "SUPPORT");
   ObjectDelete(0, prefix + "BOX");
   ObjectDelete(0, prefix + "LABEL_R");
   ObjectDelete(0, prefix + "LABEL_S");

   // Linea Resistance
   ObjectCreate(0, prefix + "RESISTANCE", OBJ_HLINE, 0, 0, rangeBox_Resistance);
   ObjectSetInteger(0, prefix + "RESISTANCE", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, prefix + "RESISTANCE", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, prefix + "RESISTANCE", OBJPROP_WIDTH, 2);
   ObjectSetString(0, prefix + "RESISTANCE", OBJPROP_TEXT, "RESISTANCE");

   // Linea Support
   ObjectCreate(0, prefix + "SUPPORT", OBJ_HLINE, 0, 0, rangeBox_Support);
   ObjectSetInteger(0, prefix + "SUPPORT", OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, prefix + "SUPPORT", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, prefix + "SUPPORT", OBJPROP_WIDTH, 2);
   ObjectSetString(0, prefix + "SUPPORT", OBJPROP_TEXT, "SUPPORT");

   // Rettangolo Range Box
   datetime timeStart = iTime(_Symbol, PERIOD_CURRENT, 100);
   datetime timeEnd = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 50;

   ObjectCreate(0, prefix + "BOX", OBJ_RECTANGLE, 0,
                timeStart, rangeBox_Resistance,
                timeEnd, rangeBox_Support);
   ObjectSetInteger(0, prefix + "BOX", OBJPROP_COLOR, clrDarkSlateGray);
   ObjectSetInteger(0, prefix + "BOX", OBJPROP_FILL, true);
   ObjectSetInteger(0, prefix + "BOX", OBJPROP_BACK, true);

   // Label Resistance
   ObjectCreate(0, prefix + "LABEL_R", OBJ_TEXT, 0, timeEnd, rangeBox_Resistance);
   ObjectSetString(0, prefix + "LABEL_R", OBJPROP_TEXT,
                   " R: " + DoubleToString(rangeBox_Resistance, symbolDigits));
   ObjectSetInteger(0, prefix + "LABEL_R", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, prefix + "LABEL_R", OBJPROP_FONTSIZE, 8);

   // Label Support
   ObjectCreate(0, prefix + "LABEL_S", OBJ_TEXT, 0, timeEnd, rangeBox_Support);
   ObjectSetString(0, prefix + "LABEL_S", OBJPROP_TEXT,
                   " S: " + DoubleToString(rangeBox_Support, symbolDigits));
   ObjectSetInteger(0, prefix + "LABEL_S", OBJPROP_COLOR, clrGreen);
   ObjectSetInteger(0, prefix + "LABEL_S", OBJPROP_FONTSIZE, 8);

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Rimuovi visualizzazione Range Box                                |
//+------------------------------------------------------------------+
void RemoveRangeBoxVisualization()
{
   string prefix = "SUGAMARA_RANGEBOX_";
   ObjectDelete(0, prefix + "RESISTANCE");
   ObjectDelete(0, prefix + "SUPPORT");
   ObjectDelete(0, prefix + "BOX");
   ObjectDelete(0, prefix + "LABEL_R");
   ObjectDelete(0, prefix + "LABEL_S");
   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Restituisce range in pips                                        |
//+------------------------------------------------------------------+
double GetRangeBoxPips()
{
   if(!IsRangeBoxAvailable() || rangeBox_Resistance == 0 || rangeBox_Support == 0)
      return 0;

   double rangePips = (rangeBox_Resistance - rangeBox_Support) / symbolPoint;

   if(symbolDigits == 5 || symbolDigits == 3)
      rangePips /= 10.0;

   return rangePips;
}

//+------------------------------------------------------------------+
//| Restituisce distanza dal breakout superiore (pips)               |
//+------------------------------------------------------------------+
double GetDistanceToResistance(double price)
{
   if(!IsRangeBoxAvailable())
      return 0;

   double distPips = (rangeBox_Resistance - price) / symbolPoint;

   if(symbolDigits == 5 || symbolDigits == 3)
      distPips /= 10.0;

   return distPips;
}

//+------------------------------------------------------------------+
//| Restituisce distanza dal breakout inferiore (pips)               |
//+------------------------------------------------------------------+
double GetDistanceToSupport(double price)
{
   if(!IsRangeBoxAvailable())
      return 0;

   double distPips = (price - rangeBox_Support) / symbolPoint;

   if(symbolDigits == 5 || symbolDigits == 3)
      distPips /= 10.0;

   return distPips;
}

//+------------------------------------------------------------------+
//| Log report Range Box                                             |
//+------------------------------------------------------------------+
void LogRangeBoxReport()
{
   if(!IsRangeBoxAvailable())
   {
      Print("[RangeBox] Not available in current mode");
      return;
   }

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   Print("═══════════════════════════════════════════════════════════════════");
   Print("  RANGEBOX REPORT");
   Print("═══════════════════════════════════════════════════════════════════");
   PrintFormat("  Mode: %s",
               RangeBoxMode == RANGEBOX_MANUAL ? "MANUAL" :
               RangeBoxMode == RANGEBOX_DAILY_HL ? "DAILY_HL" : "ATR_BASED");
   PrintFormat("  Resistance: %.5f", rangeBox_Resistance);
   PrintFormat("  Support: %.5f", rangeBox_Support);
   PrintFormat("  Range: %.1f pips", GetRangeBoxPips());
   Print("───────────────────────────────────────────────────────────────────");
   PrintFormat("  Current Price: %.5f", currentPrice);
   PrintFormat("  Distance to R: %.1f pips", GetDistanceToResistance(currentPrice));
   PrintFormat("  Distance to S: %.1f pips", GetDistanceToSupport(currentPrice));
   Print("───────────────────────────────────────────────────────────────────");
   PrintFormat("  Inside Range: %s", isInsideRange ? "YES" : "NO");
   PrintFormat("  Breakout Up: %s", isBreakoutUp ? "YES" : "NO");
   PrintFormat("  Breakout Down: %s", isBreakoutDown ? "YES" : "NO");
   Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| ═══════════════════════════════════════════════════════════════ |
//| 🛡️ SHIELD INTELLIGENTE INTEGRATION                              |
//| ═══════════════════════════════════════════════════════════════ |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize RangeBox for Shield System                            |
//+------------------------------------------------------------------+
bool InitializeRangeBoxForShield()
{
   if(NeutralMode != NEUTRAL_RANGEBOX) {
      Print("[RangeBox] Skip Shield init - Not in RANGEBOX mode");
      return true;
   }

   Print("═══ Initializing Range Box for Shield ═══");

   // Reset structure
   ZeroMemory(rangeBox);

   bool success = false;

   switch(RangeBoxMode) {
      case RANGEBOX_MANUAL:
         success = CalculateManualRangeBoxShield();
         break;

      case RANGEBOX_DAILY_HL:
         success = CalculateDailyHLRangeBoxShield();
         break;

      case RANGEBOX_ATR_BASED:
         success = CalculateATRBasedRangeBoxShield();
         break;
   }

   if(success) {
      rangeBox.center = (rangeBox.resistance + rangeBox.support) / 2.0;
      rangeBox.rangeHeight = PointsToPips(rangeBox.resistance - rangeBox.support);

      // v4.4: Calculate Warning Zones using dynamic formula (N - 0.5) × spacing
      // This places warning zone HALFWAY between penultimate and last grid level
      double spacing = currentSpacing_Pips * symbolPoint * ((symbolDigits == 5 || symbolDigits == 3) ? 10 : 1);
      if(spacing == 0) {
         // Fallback: calculate from range
         spacing = (rangeBox.resistance - rangeBox.support) / (GridLevelsPerSide * 2);
      }
      double warningMultiplier = GridLevelsPerSide - 0.5;
      // N=5 → 4.5 | N=7 → 6.5 | N=9 → 8.5
      double basePrice = (entryPoint > 0) ? entryPoint : rangeBox.center;
      rangeBox.warningZoneUp = basePrice + (spacing * warningMultiplier);
      rangeBox.warningZoneDown = basePrice - (spacing * warningMultiplier);

      rangeBox.isValid = true;
      rangeBox.lastCalc = TimeCurrent();

      // Copy to legacy variables
      rangeBox_Resistance = rangeBox.resistance;
      rangeBox_Support = rangeBox.support;

      Print("  Mode: ", EnumToString(RangeBoxMode));
      Print("  Resistance: ", DoubleToString(rangeBox.resistance, symbolDigits));
      Print("  Support: ", DoubleToString(rangeBox.support, symbolDigits));
      Print("  Range Height: ", DoubleToString(rangeBox.rangeHeight, 1), " pips");
      Print("  Warning Zone Up: ", DoubleToString(rangeBox.warningZoneUp, symbolDigits));
      Print("  Warning Zone Down: ", DoubleToString(rangeBox.warningZoneDown, symbolDigits));

      // Draw on chart
      if(ShowRangeBox) {
         DrawRangeBoxVisualization();
         DrawWarningZones();
      }
   }

   return success;
}

//+------------------------------------------------------------------+
//| Calculate Manual Range Box for Shield                            |
//+------------------------------------------------------------------+
bool CalculateManualRangeBoxShield()
{
   if(RangeBox_Resistance <= RangeBox_Support ||
      RangeBox_Resistance == 0 || RangeBox_Support == 0) {
      Print("ERROR: Invalid manual Resistance/Support values");
      return false;
   }

   rangeBox.resistance = RangeBox_Resistance;
   rangeBox.support = RangeBox_Support;

   return true;
}

//+------------------------------------------------------------------+
//| Calculate Daily High/Low Range Box for Shield                    |
//+------------------------------------------------------------------+
bool CalculateDailyHLRangeBoxShield()
{
   double highestHigh = 0;
   double lowestLow = DBL_MAX;

   // Find High/Low in last N days
   for(int i = 1; i <= RangeBox_PeriodBars; i++) {
      double high = iHigh(_Symbol, PERIOD_D1, i);
      double low = iLow(_Symbol, PERIOD_D1, i);

      if(high > highestHigh) highestHigh = high;
      if(low < lowestLow) lowestLow = low;
   }

   if(highestHigh <= lowestLow) {
      Print("ERROR: Invalid Daily H/L data");
      return false;
   }

   rangeBox.resistance = highestHigh;
   rangeBox.support = lowestLow;

   return true;
}

//+------------------------------------------------------------------+
//| Calculate ATR-Based Range Box for Shield                         |
//+------------------------------------------------------------------+
bool CalculateATRBasedRangeBoxShield()
{
   if(currentATR_Pips <= 0) {
      Print("ERROR: Invalid ATR value for Range Box");
      return false;
   }

   double rangeDistance = PipsToPoints(currentATR_Pips * RangeBox_ATR_Mult);

   rangeBox.resistance = NormalizeDouble(entryPoint + rangeDistance, symbolDigits);
   rangeBox.support = NormalizeDouble(entryPoint - rangeDistance, symbolDigits);

   return true;
}

//+------------------------------------------------------------------+
//| Calculate Breakout Levels from Grid Edges                        |
//+------------------------------------------------------------------+
bool CalculateBreakoutLevels()
{
   // Find highest Grid B level (upper zone sells)
   double highestGridBLevel = 0;
   for(int i = 0; i < GridLevelsPerSide; i++) {
      if(gridB_Upper_EntryPrices[i] > highestGridBLevel) {
         highestGridBLevel = gridB_Upper_EntryPrices[i];
      }
   }

   // Find lowest Grid A level (lower zone sells)
   double lowestGridALevel = DBL_MAX;
   for(int i = 0; i < GridLevelsPerSide; i++) {
      if(gridA_Lower_EntryPrices[i] > 0 && gridA_Lower_EntryPrices[i] < lowestGridALevel) {
         lowestGridALevel = gridA_Lower_EntryPrices[i];
      }
   }

   if(highestGridBLevel == 0 || lowestGridALevel == DBL_MAX) {
      Print("ERROR: Cannot calculate breakout levels - grid not initialized");
      return false;
   }

   // Breakout Levels = last grid level + buffer
   double bufferPoints = PipsToPoints(Breakout_Buffer_Pips);
   upperBreakoutLevel = NormalizeDouble(highestGridBLevel + bufferPoints, symbolDigits);
   lowerBreakoutLevel = NormalizeDouble(lowestGridALevel - bufferPoints, symbolDigits);

   // Reentry Levels = breakout - buffer
   double reentryBuffer = PipsToPoints(Reentry_Buffer_Pips);
   upperReentryLevel = NormalizeDouble(upperBreakoutLevel - reentryBuffer, symbolDigits);
   lowerReentryLevel = NormalizeDouble(lowerBreakoutLevel + reentryBuffer, symbolDigits);

   Print("═══ Breakout Levels Calculated ═══");
   Print("  Upper Breakout: ", DoubleToString(upperBreakoutLevel, symbolDigits));
   Print("  Lower Breakout: ", DoubleToString(lowerBreakoutLevel, symbolDigits));
   Print("  Upper Reentry: ", DoubleToString(upperReentryLevel, symbolDigits));
   Print("  Lower Reentry: ", DoubleToString(lowerReentryLevel, symbolDigits));

   // Draw levels
   DrawBreakoutLevels();

   return true;
}

//+------------------------------------------------------------------+
//| Get Price Position in Range (for Shield 3 Phases)                |
//+------------------------------------------------------------------+
ENUM_SYSTEM_STATE GetPricePositionInRange(double price)
{
   if(!rangeBox.isValid) return STATE_RUNNING;

   // Check breakout
   if(price >= upperBreakoutLevel) {
      return STATE_BREAKOUT_UP;
   }
   if(price <= lowerBreakoutLevel) {
      return STATE_BREAKOUT_DOWN;
   }

   // Check warning zones (for Shield 3 Phases)
   if(ShieldMode == SHIELD_3_PHASES) {
      if(price >= rangeBox.warningZoneUp) {
         return STATE_WARNING_UP;
      }
      if(price <= rangeBox.warningZoneDown) {
         return STATE_WARNING_DOWN;
      }
   }

   // Inside normal range
   return STATE_INSIDE_RANGE;
}

//+------------------------------------------------------------------+
//| Check Breakout Condition with Confirmation                       |
//+------------------------------------------------------------------+
bool CheckBreakoutConditionShield(double price, ENUM_BREAKOUT_DIRECTION &direction)
{
   direction = BREAKOUT_NONE;

   // Check UP
   if(price >= upperBreakoutLevel) {
      if(Use_Candle_Close) {
         if(IsBreakoutConfirmedShield(BREAKOUT_UP)) {
            direction = BREAKOUT_UP;
            return true;
         }
      } else {
         direction = BREAKOUT_UP;
         return true;
      }
   }

   // Check DOWN
   if(price <= lowerBreakoutLevel) {
      if(Use_Candle_Close) {
         if(IsBreakoutConfirmedShield(BREAKOUT_DOWN)) {
            direction = BREAKOUT_DOWN;
            return true;
         }
      } else {
         direction = BREAKOUT_DOWN;
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check if Breakout is Confirmed (N candles)                       |
//+------------------------------------------------------------------+
bool IsBreakoutConfirmedShield(ENUM_BREAKOUT_DIRECTION direction)
{
   int confirmedCandles = 0;

   for(int i = 0; i < Breakout_Confirm_Candles; i++) {
      double closePrice = iClose(_Symbol, PERIOD_CURRENT, i);

      if(direction == BREAKOUT_UP) {
         if(closePrice > upperBreakoutLevel) {
            confirmedCandles++;
         }
      } else {
         if(closePrice < lowerBreakoutLevel) {
            confirmedCandles++;
         }
      }
   }

   return (confirmedCandles >= Breakout_Confirm_Candles);
}

//+------------------------------------------------------------------+
//| Check Reentry Condition                                          |
//+------------------------------------------------------------------+
bool CheckReentryConditionShield(double price)
{
   if(!shield.isActive) return false;

   if(shield.type == SHIELD_LONG) {
      // Was breakout DOWN, reenter if price rises above reentry level
      if(price > lowerReentryLevel) {
         if(Use_Candle_Close) {
            return IsReentryConfirmedShield(BREAKOUT_DOWN);
         }
         return true;
      }
   }
   else if(shield.type == SHIELD_SHORT) {
      // Was breakout UP, reenter if price falls below reentry level
      if(price < upperReentryLevel) {
         if(Use_Candle_Close) {
            return IsReentryConfirmedShield(BREAKOUT_UP);
         }
         return true;
      }
   }

   return false;
}

//+------------------------------------------------------------------+
//| Check if Reentry is Confirmed                                    |
//+------------------------------------------------------------------+
bool IsReentryConfirmedShield(ENUM_BREAKOUT_DIRECTION originalDirection)
{
   int confirmedCandles = 0;

   for(int i = 0; i < Breakout_Confirm_Candles; i++) {
      double closePrice = iClose(_Symbol, PERIOD_CURRENT, i);

      if(originalDirection == BREAKOUT_UP) {
         if(closePrice < upperReentryLevel) {
            confirmedCandles++;
         }
      } else {
         if(closePrice > lowerReentryLevel) {
            confirmedCandles++;
         }
      }
   }

   return (confirmedCandles >= Breakout_Confirm_Candles);
}

//+------------------------------------------------------------------+
//| Sync RangeBox with Grid Levels                                   |
//| S/R = Last Grid Levels (Resistance = highest Grid B Upper,       |
//|                         Support = lowest Grid A Lower)           |
//| Warning Zone starts 10% INSIDE the range                         |
//+------------------------------------------------------------------+
void SyncRangeBoxWithGrid()
{
   if(NeutralMode != NEUTRAL_RANGEBOX) {
      if(DetailedLogging)
         Print("[RangeBox] SyncRangeBoxWithGrid() - Skip: Not in RANGEBOX mode");
      return;
   }

   Print("═══════════════════════════════════════════════════════════════════");
   Print("  SYNCING RANGEBOX WITH GRID LEVELS");
   Print("═══════════════════════════════════════════════════════════════════");

   // Find highest Grid B Upper level (RESISTANCE)
   double highestGridB = 0;
   int highestGridBIndex = -1;
   for(int i = 0; i < GridLevelsPerSide; i++) {
      if(gridB_Upper_EntryPrices[i] > highestGridB) {
         highestGridB = gridB_Upper_EntryPrices[i];
         highestGridBIndex = i;
      }
   }

   // Find lowest Grid A Lower level (SUPPORT)
   double lowestGridA = DBL_MAX;
   int lowestGridAIndex = -1;
   for(int i = 0; i < GridLevelsPerSide; i++) {
      if(gridA_Lower_EntryPrices[i] > 0 && gridA_Lower_EntryPrices[i] < lowestGridA) {
         lowestGridA = gridA_Lower_EntryPrices[i];
         lowestGridAIndex = i;
      }
   }

   // Validate
   if(highestGridB == 0 || lowestGridA == DBL_MAX) {
      Print("  ERROR: Cannot sync - Grid levels not initialized");
      PrintFormat("    Highest Grid B: %.5f (index %d)", highestGridB, highestGridBIndex);
      PrintFormat("    Lowest Grid A: %.5f (index %d)", lowestGridA, lowestGridAIndex);
      return;
   }

   // Store previous values for logging
   double prevResistance = rangeBox.resistance;
   double prevSupport = rangeBox.support;

   // Sync RangeBox with Grid Levels
   rangeBox.resistance = highestGridB;
   rangeBox.support = lowestGridA;
   rangeBox_Resistance = highestGridB;
   rangeBox_Support = lowestGridA;

   // Calculate center and range
   rangeBox.center = (rangeBox.resistance + rangeBox.support) / 2.0;
   rangeBox.rangeHeight = PointsToPips(rangeBox.resistance - rangeBox.support);

   // v4.4: Calculate Warning Zones using dynamic formula (N - 0.5) × spacing
   // This places warning zone HALFWAY between penultimate and last grid level
   double spacing = currentSpacing_Pips * symbolPoint * ((symbolDigits == 5 || symbolDigits == 3) ? 10 : 1);
   if(spacing == 0) {
      // Fallback: calculate from range
      spacing = (rangeBox.resistance - rangeBox.support) / (GridLevelsPerSide * 2);
   }
   double warningMultiplier = GridLevelsPerSide - 0.5;
   // N=5 → 4.5 | N=7 → 6.5 | N=9 → 8.5
   double basePrice = (entryPoint > 0) ? entryPoint : rangeBox.center;
   rangeBox.warningZoneUp = basePrice + (spacing * warningMultiplier);
   rangeBox.warningZoneDown = basePrice - (spacing * warningMultiplier);

   rangeBox.isValid = true;
   rangeBox.lastCalc = TimeCurrent();

   // Detailed logging
   Print("───────────────────────────────────────────────────────────────────");
   Print("  RANGEBOX SYNCED WITH GRID LEVELS");
   Print("───────────────────────────────────────────────────────────────────");
   PrintFormat("  RESISTANCE: %.5f (Grid B Upper[%d])", rangeBox.resistance, highestGridBIndex);
   PrintFormat("  SUPPORT:    %.5f (Grid A Lower[%d])", rangeBox.support, lowestGridAIndex);
   Print("───────────────────────────────────────────────────────────────────");
   PrintFormat("  Range Height: %.1f pips", rangeBox.rangeHeight);
   PrintFormat("  Center: %.5f", rangeBox.center);
   Print("───────────────────────────────────────────────────────────────────");
   PrintFormat("  Warning Zone Up:   %.5f (%.1f%% inside)",
               rangeBox.warningZoneUp, Warning_Zone_Percent);
   PrintFormat("  Warning Zone Down: %.5f (%.1f%% inside)",
               rangeBox.warningZoneDown, Warning_Zone_Percent);
   Print("───────────────────────────────────────────────────────────────────");

   if(prevResistance > 0 && prevSupport > 0) {
      double resDiff = MathAbs(rangeBox.resistance - prevResistance);
      double supDiff = MathAbs(rangeBox.support - prevSupport);
      if(resDiff > symbolPoint || supDiff > symbolPoint) {
         Print("  DELTA from previous:");
         PrintFormat("    Resistance: %.5f -> %.5f (delta: %.1f pips)",
                     prevResistance, rangeBox.resistance, PointsToPips(resDiff));
         PrintFormat("    Support: %.5f -> %.5f (delta: %.1f pips)",
                     prevSupport, rangeBox.support, PointsToPips(supDiff));
      }
   }
   Print("═══════════════════════════════════════════════════════════════════");

   // Update visualization
   if(ShowRangeBox) {
      DrawRangeBoxVisualization();
      DrawWarningZones();
   }
}

//+------------------------------------------------------------------+
//| Get Last Grid B Level (highest)                                  |
//+------------------------------------------------------------------+
double GetLastGridBLevel()
{
   double highest = 0;
   for(int i = 0; i < GridLevelsPerSide; i++) {
      if(gridB_Upper_EntryPrices[i] > highest) {
         highest = gridB_Upper_EntryPrices[i];
      }
   }
   return highest;
}

//+------------------------------------------------------------------+
//| Get Last Grid A Level (lowest)                                   |
//+------------------------------------------------------------------+
double GetLastGridALevel()
{
   double lowest = DBL_MAX;
   for(int i = 0; i < GridLevelsPerSide; i++) {
      if(gridA_Lower_EntryPrices[i] > 0 && gridA_Lower_EntryPrices[i] < lowest) {
         lowest = gridA_Lower_EntryPrices[i];
      }
   }
   return (lowest == DBL_MAX) ? 0 : lowest;
}

//+------------------------------------------------------------------+
//| Draw Warning Zones (for Shield 3 Phases)                         |
//+------------------------------------------------------------------+
void DrawWarningZones()
{
   if(ShieldMode != SHIELD_3_PHASES) return;

   string prefix = "SUGAMARA_";

   ObjectDelete(0, prefix + "WARNING_UP");
   ObjectCreate(0, prefix + "WARNING_UP", OBJ_HLINE, 0, 0, rangeBox.warningZoneUp);
   ObjectSetInteger(0, prefix + "WARNING_UP", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, prefix + "WARNING_UP", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, prefix + "WARNING_UP", OBJPROP_WIDTH, 1);
   ObjectSetString(0, prefix + "WARNING_UP", OBJPROP_TEXT, "Warning Up");

   ObjectDelete(0, prefix + "WARNING_DOWN");
   ObjectCreate(0, prefix + "WARNING_DOWN", OBJ_HLINE, 0, 0, rangeBox.warningZoneDown);
   ObjectSetInteger(0, prefix + "WARNING_DOWN", OBJPROP_COLOR, clrOrange);
   ObjectSetInteger(0, prefix + "WARNING_DOWN", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, prefix + "WARNING_DOWN", OBJPROP_WIDTH, 1);
   ObjectSetString(0, prefix + "WARNING_DOWN", OBJPROP_TEXT, "Warning Down");
}

//+------------------------------------------------------------------+
//| Draw Breakout Levels                                             |
//+------------------------------------------------------------------+
void DrawBreakoutLevels()
{
   string prefix = "SUGAMARA_";

   // Upper Breakout
   ObjectDelete(0, prefix + "UPPER_BREAKOUT");
   ObjectCreate(0, prefix + "UPPER_BREAKOUT", OBJ_HLINE, 0, 0, upperBreakoutLevel);
   ObjectSetInteger(0, prefix + "UPPER_BREAKOUT", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, prefix + "UPPER_BREAKOUT", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, prefix + "UPPER_BREAKOUT", OBJPROP_WIDTH, 2);
   ObjectSetString(0, prefix + "UPPER_BREAKOUT", OBJPROP_TEXT, "Upper Breakout");

   // Lower Breakout
   ObjectDelete(0, prefix + "LOWER_BREAKOUT");
   ObjectCreate(0, prefix + "LOWER_BREAKOUT", OBJ_HLINE, 0, 0, lowerBreakoutLevel);
   ObjectSetInteger(0, prefix + "LOWER_BREAKOUT", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, prefix + "LOWER_BREAKOUT", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, prefix + "LOWER_BREAKOUT", OBJPROP_WIDTH, 2);
   ObjectSetString(0, prefix + "LOWER_BREAKOUT", OBJPROP_TEXT, "Lower Breakout");

   // Upper Reentry
   ObjectDelete(0, prefix + "UPPER_REENTRY");
   ObjectCreate(0, prefix + "UPPER_REENTRY", OBJ_HLINE, 0, 0, upperReentryLevel);
   ObjectSetInteger(0, prefix + "UPPER_REENTRY", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, prefix + "UPPER_REENTRY", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, prefix + "UPPER_REENTRY", OBJPROP_WIDTH, 1);
   ObjectSetString(0, prefix + "UPPER_REENTRY", OBJPROP_TEXT, "Upper Reentry");

   // Lower Reentry
   ObjectDelete(0, prefix + "LOWER_REENTRY");
   ObjectCreate(0, prefix + "LOWER_REENTRY", OBJ_HLINE, 0, 0, lowerReentryLevel);
   ObjectSetInteger(0, prefix + "LOWER_REENTRY", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, prefix + "LOWER_REENTRY", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, prefix + "LOWER_REENTRY", OBJPROP_WIDTH, 1);
   ObjectSetString(0, prefix + "LOWER_REENTRY", OBJPROP_TEXT, "Lower Reentry");

   ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Remove All Shield RangeBox Objects                               |
//+------------------------------------------------------------------+
void DeinitializeRangeBoxShield()
{
   string prefix = "SUGAMARA_";
   ObjectDelete(0, prefix + "WARNING_UP");
   ObjectDelete(0, prefix + "WARNING_DOWN");
   ObjectDelete(0, prefix + "UPPER_BREAKOUT");
   ObjectDelete(0, prefix + "LOWER_BREAKOUT");
   ObjectDelete(0, prefix + "UPPER_REENTRY");
   ObjectDelete(0, prefix + "LOWER_REENTRY");

   RemoveRangeBoxVisualization();

   Print("[RangeBox] Shield visualization removed");
}

// NOTE: PointsToPips and PipsToPoints are defined in Utils/Helpers.mqh
