//+------------------------------------------------------------------+
//|                                                 ModeLogic.mqh    |
//|                        Sugamara v2.0 - Mode Logic                |
//|                                                                  |
//|  Logica condizionale per le 3 modalità:                         |
//|  - NEUTRAL_PURE: Spacing fisso, TP fisso, NO ATR                |
//|  - NEUTRAL_CASCADE: TP=Entry precedente, ATR opzionale          |
//|  - NEUTRAL_RANGEBOX: Range Box + Hedge, ATR opzionale           |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Verifica se ATR è disponibile per la modalità corrente           |
//| ATR è disponibile SOLO per CASCADE e RANGEBOX                    |
//+------------------------------------------------------------------+
bool IsATRAvailable()
{
   // NEUTRAL_PURE = modalità learning, TUTTO fisso, no ATR
   if(NeutralMode == NEUTRAL_PURE)
      return false;

   // CASCADE e RANGEBOX supportano ATR opzionale
   return true;
}

//+------------------------------------------------------------------+
//| Verifica se ATR è effettivamente abilitato dall'utente           |
//+------------------------------------------------------------------+
bool IsATREnabled()
{
   // Deve essere disponibile per la modalità E abilitato dall'utente
   if(!IsATRAvailable())
      return false;

   return UseATR;
}

//+------------------------------------------------------------------+
//| Verifica se Range Box è disponibile (solo RANGEBOX)              |
//+------------------------------------------------------------------+
bool IsRangeBoxAvailable()
{
   return (NeutralMode == NEUTRAL_RANGEBOX);
}

//+------------------------------------------------------------------+
//| Verifica se Hedging è disponibile (solo RANGEBOX con EnableHedging)|
//+------------------------------------------------------------------+
bool IsHedgingAvailable()
{
   return (NeutralMode == NEUTRAL_RANGEBOX && EnableHedging);
}

//+------------------------------------------------------------------+
//| Verifica se usa TP CASCADE (CASCADE e RANGEBOX)                  |
//+------------------------------------------------------------------+
bool UsesCascadeTP()
{
   // CASCADE e RANGEBOX usano TP cascade (TP = Entry livello precedente)
   // PURE usa TP fisso (spacing × ratio)
   return (NeutralMode == NEUTRAL_CASCADE || NeutralMode == NEUTRAL_RANGEBOX);
}

//+------------------------------------------------------------------+
//| Calcola lo spacing corrente in base a modalità e ATR             |
//+------------------------------------------------------------------+
double CalculateCurrentSpacing()
{
   double spacing = Fixed_Spacing_Pips;

   //--- NEUTRAL_PURE: sempre spacing fisso
   if(NeutralMode == NEUTRAL_PURE)
   {
      return Fixed_Spacing_Pips;
   }

   //--- Se ATR NON abilitato, usa spacing fisso
   if(!IsATREnabled())
   {
      return Fixed_Spacing_Pips;
   }

   //--- ATR ABILITATO: calcola spacing dinamico dalla tabella
   double atrValue = GetATRPips();

   if(atrValue < ATR_Calm_Threshold)
      spacing = ATR_Calm_Spacing;           // ATR < 15 → 15 pips
   else if(atrValue < ATR_Normal_Threshold)
      spacing = ATR_Normal_Spacing;         // ATR 15-30 → 20 pips
   else if(atrValue < ATR_Volatile_Threshold)
      spacing = ATR_Volatile_Spacing;       // ATR 30-50 → 30 pips
   else
      spacing = ATR_Extreme_Spacing;        // ATR > 50 → 40 pips

   if(DetailedLogging)
      PrintFormat("[ModeLogic] ATR: %.1f pips → Spacing: %.1f pips", atrValue, spacing);

   return spacing;
}

//+------------------------------------------------------------------+
//| Calcola ATR corrente in pips                                     |
//+------------------------------------------------------------------+
double GetATRPips()
{
   if(atrHandle == INVALID_HANDLE)
      return Fixed_Spacing_Pips;  // Fallback

   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);

   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0)
      return Fixed_Spacing_Pips;  // Fallback

   // Converti in pips
   double atrPips = atrBuffer[0] / symbolPoint;

   // Correggi per coppie a 5/3 decimali (JPY, etc)
   if(symbolDigits == 5 || symbolDigits == 3)
      atrPips /= 10.0;

   return atrPips;
}

//+------------------------------------------------------------------+
//| Calcola Take Profit in base alla modalità                        |
//| level: numero livello (1-based)                                  |
//| entryPrice: prezzo entry dell'ordine corrente                    |
//| prevEntryPrice: prezzo entry del livello precedente              |
//| isLong: true=BUY, false=SELL                                     |
//+------------------------------------------------------------------+
double CalculateTPForMode(int level, double orderEntryPrice, double prevEntryPrice, bool isLong)
{
   double tpPrice = 0.0;
   double spacing = CalculateCurrentSpacing();
   double spacingPoints = spacing * symbolPoint * ((symbolDigits == 5 || symbolDigits == 3) ? 10 : 1);

   switch(NeutralMode)
   {
      //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      case NEUTRAL_PURE:
      //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
         // TP FISSO = Entry ± (Spacing × Ratio)
         if(isLong)
            tpPrice = orderEntryPrice + (spacingPoints * TP_Ratio_Pure);
         else
            tpPrice = orderEntryPrice - (spacingPoints * TP_Ratio_Pure);
         break;

      //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      case NEUTRAL_CASCADE:
      case NEUTRAL_RANGEBOX:
      //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
         // TP CASCADE = Entry del livello precedente
         if(level == 1)
         {
            // Primo livello: TP al centro (entry point)
            tpPrice = entryPoint;
         }
         else
         {
            // Livelli successivi: TP = Entry livello precedente
            tpPrice = prevEntryPrice;
         }
         break;
   }

   return NormalizeDouble(tpPrice, symbolDigits);
}

//+------------------------------------------------------------------+
//| Calcola Range Box (solo per NEUTRAL_RANGEBOX)                    |
//| Restituisce true se calcolo riuscito                             |
//+------------------------------------------------------------------+
bool CalculateRangeBoxLevels(double &resistance, double &support)
{
   if(!IsRangeBoxAvailable())
   {
      resistance = 0;
      support = 0;
      return false;
   }

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   switch(RangeBoxMode)
   {
      //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      case RANGEBOX_MANUAL:
      //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
         // Usa valori inseriti dall'utente
         if(RangeBox_Resistance <= 0 || RangeBox_Support <= 0)
         {
            Print("[ModeLogic] ERROR: RANGEBOX_MANUAL richiede Resistance e Support > 0!");
            return false;
         }
         resistance = RangeBox_Resistance;
         support = RangeBox_Support;
         break;

      //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      case RANGEBOX_DAILY_HL:
      //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
         {
            // Usa High/Low delle ultime N barre giornaliere
            double highestHigh = 0;
            double lowestLow = DBL_MAX;

            for(int i = 0; i < RangeBox_PeriodBars; i++)
            {
               double h = iHigh(_Symbol, PERIOD_D1, i);
               double l = iLow(_Symbol, PERIOD_D1, i);

               if(h > highestHigh) highestHigh = h;
               if(l < lowestLow) lowestLow = l;
            }

            resistance = highestHigh;
            support = lowestLow;
         }
         break;

      //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
      case RANGEBOX_ATR_BASED:
      //━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
         {
            // Range = Prezzo corrente ± (ATR × Multiplier)
            double atrPips = GetATRPips();
            double rangeHalfPoints = atrPips * RangeBox_ATR_Mult * symbolPoint;

            if(symbolDigits == 5 || symbolDigits == 3)
               rangeHalfPoints *= 10;

            resistance = currentPrice + rangeHalfPoints;
            support = currentPrice - rangeHalfPoints;

            if(DetailedLogging)
               PrintFormat("[ModeLogic] RangeBox ATR: ATR=%.1f, Range=±%.1f pips",
                           atrPips, atrPips * RangeBox_ATR_Mult);
         }
         break;
   }

   // Validazione finale
   if(resistance <= support)
   {
      Print("[ModeLogic] ERROR: Resistance deve essere > Support!");
      return false;
   }

   return true;
}

//+------------------------------------------------------------------+
//| Verifica se prezzo è dentro il Range Box                         |
//+------------------------------------------------------------------+
bool IsPriceInsideRange(double price)
{
   if(!IsRangeBoxAvailable())
      return true;  // Se non c'è Range Box, sempre "dentro"

   double bufferPoints = RangeBox_Buffer_Pips * symbolPoint;
   if(symbolDigits == 5 || symbolDigits == 3)
      bufferPoints *= 10;

   return (price < (rangeBox_Resistance - bufferPoints) &&
           price > (rangeBox_Support + bufferPoints));
}

//+------------------------------------------------------------------+
//| Verifica breakout sopra Resistance                               |
//+------------------------------------------------------------------+
bool IsBreakoutUp(double price)
{
   if(!IsRangeBoxAvailable())
      return false;

   double bufferPoints = RangeBox_Buffer_Pips * symbolPoint;
   if(symbolDigits == 5 || symbolDigits == 3)
      bufferPoints *= 10;

   return (price >= rangeBox_Resistance + bufferPoints);
}

//+------------------------------------------------------------------+
//| Verifica breakout sotto Support                                  |
//+------------------------------------------------------------------+
bool IsBreakoutDown(double price)
{
   if(!IsRangeBoxAvailable())
      return false;

   double bufferPoints = RangeBox_Buffer_Pips * symbolPoint;
   if(symbolDigits == 5 || symbolDigits == 3)
      bufferPoints *= 10;

   return (price <= rangeBox_Support - bufferPoints);
}

//+------------------------------------------------------------------+
//| Restituisce nome della modalità corrente per logging/dashboard   |
//+------------------------------------------------------------------+
string GetModeName()
{
   string name = "";

   switch(NeutralMode)
   {
      case NEUTRAL_PURE:     name = "PURE";     break;
      case NEUTRAL_CASCADE:  name = "CASCADE";  break;
      case NEUTRAL_RANGEBOX: name = "RANGEBOX"; break;
   }

   if(IsATREnabled())
      name += "+ATR";

   return name;
}

//+------------------------------------------------------------------+
//| Restituisce descrizione completa della configurazione            |
//+------------------------------------------------------------------+
string GetModeDescription()
{
   string desc = "";

   switch(NeutralMode)
   {
      case NEUTRAL_PURE:
         desc = "Spacing Fisso + TP Fisso (Learning Mode)";
         break;
      case NEUTRAL_CASCADE:
         desc = "TP=Entry Precedente";
         if(IsATREnabled())
            desc += " + Spacing ATR Adattivo";
         else
            desc += " + Spacing Fisso";
         break;
      case NEUTRAL_RANGEBOX:
         desc = "Range Box + Hedge + CASCADE";
         if(IsATREnabled())
            desc += " + ATR Adattivo";
         break;
   }

   return desc;
}

//+------------------------------------------------------------------+
//| Valida parametri in base alla modalità selezionata               |
//+------------------------------------------------------------------+
bool ValidateModeParameters()
{
   bool isValid = true;

   //--- Validazioni comuni
   if(Fixed_Spacing_Pips < MIN_SPACING_PIPS || Fixed_Spacing_Pips > MAX_SPACING_PIPS)
   {
      PrintFormat("[ModeLogic] ERROR: Spacing deve essere tra %.0f e %.0f pips",
                  MIN_SPACING_PIPS, MAX_SPACING_PIPS);
      isValid = false;
   }

   //--- Validazioni specifiche per modalità
   switch(NeutralMode)
   {
      case NEUTRAL_PURE:
         // PURE richiede TP_Ratio_Pure valido
         if(TP_Ratio_Pure < 0.5 || TP_Ratio_Pure > 3.0)
         {
            Print("[ModeLogic] ERROR: TP_Ratio_Pure deve essere tra 0.5 e 3.0");
            isValid = false;
         }
         break;

      case NEUTRAL_CASCADE:
         // CASCADE non ha parametri specifici aggiuntivi
         break;

      case NEUTRAL_RANGEBOX:
         // RANGEBOX richiede parametri Range Box
         if(RangeBoxMode == RANGEBOX_MANUAL)
         {
            if(RangeBox_Resistance <= 0 || RangeBox_Support <= 0)
            {
               Print("[ModeLogic] ERROR: RANGEBOX_MANUAL richiede Resistance e Support!");
               isValid = false;
            }
            if(RangeBox_Resistance <= RangeBox_Support)
            {
               Print("[ModeLogic] ERROR: Resistance deve essere > Support!");
               isValid = false;
            }
         }

         if(RangeBox_Buffer_Pips < 5 || RangeBox_Buffer_Pips > 50)
         {
            Print("[ModeLogic] ERROR: RangeBox_Buffer_Pips deve essere tra 5 e 50");
            isValid = false;
         }
         break;
   }

   //--- Validazioni ATR (solo se abilitato)
   if(IsATREnabled())
   {
      if(ATR_Period < 5 || ATR_Period > 50)
      {
         Print("[ModeLogic] ERROR: ATR_Period deve essere tra 5 e 50");
         isValid = false;
      }
   }

   return isValid;
}

//+------------------------------------------------------------------+
//| Stampa configurazione modalità                                   |
//+------------------------------------------------------------------+
void PrintModeConfiguration()
{
   Print("═══════════════════════════════════════════════════════════════════");
   Print("  SUGAMARA v2.0 - CONFIGURAZIONE MODALITÀ");
   Print("═══════════════════════════════════════════════════════════════════");
   PrintFormat("  Modalità: %s", GetModeName());
   PrintFormat("  Descrizione: %s", GetModeDescription());
   Print("───────────────────────────────────────────────────────────────────");
   PrintFormat("  ATR Disponibile: %s", IsATRAvailable() ? "Sì" : "No");
   PrintFormat("  ATR Abilitato: %s", IsATREnabled() ? "Sì" : "No");
   PrintFormat("  Range Box: %s", IsRangeBoxAvailable() ? "Sì" : "No");
   PrintFormat("  Hedging: %s", IsHedgingAvailable() ? "Sì" : "No");
   PrintFormat("  TP Mode: %s", UsesCascadeTP() ? "CASCADE" : "FISSO");
   Print("───────────────────────────────────────────────────────────────────");
   PrintFormat("  Spacing Corrente: %.1f pips", CalculateCurrentSpacing());
   Print("═══════════════════════════════════════════════════════════════════");
}
