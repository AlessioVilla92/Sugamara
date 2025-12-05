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
