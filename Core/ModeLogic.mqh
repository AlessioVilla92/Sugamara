//+------------------------------------------------------------------+
//|                                                 ModeLogic.mqh    |
//|                        Sugamara v5.2 - Mode Logic                |
//|                                                                  |
//|  Logica condizionale per le 2 modalità:                         |
//|  - NEUTRAL_PURE: Spacing fisso, TP fisso, NO ATR                |
//|  - NEUTRAL_CASCADE: TP=Entry precedente, ATR opzionale          |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Verifica se ATR è disponibile per la modalità corrente           |
//| ATR è disponibile SOLO per CASCADE mode                          |
//+------------------------------------------------------------------+
bool IsATRAvailable()
{
   // NEUTRAL_PURE = modalità learning, TUTTO fisso, no ATR
   if(NeutralMode == NEUTRAL_PURE)
      return false;

   // CASCADE supporta ATR opzionale
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
//| Verifica se Hedging è disponibile (CASCADE_OVERLAP con EnableHedging)|
//+------------------------------------------------------------------+
bool IsHedgingAvailable()
{
   // v5.2: Hedging available for CASCADE_OVERLAP mode
   return (IsCascadeOverlapMode() && EnableHedging);
}

//+------------------------------------------------------------------+
//| Verifica se usa TP CASCADE                                       |
//+------------------------------------------------------------------+
bool UsesCascadeTP()
{
   // CASCADE usa TP cascade (TP = Entry livello precedente)
   // PURE usa TP fisso (spacing × ratio)
   return (NeutralMode == NEUTRAL_CASCADE);
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
//| Calcola ATR corrente in pips (v4.7 - con BarsCalculated check)   |
//+------------------------------------------------------------------+
double GetATRPips()
{
   if(atrHandle == INVALID_HANDLE)
      return Fixed_Spacing_Pips;  // Fallback

   // v4.7: Verifica che l'indicatore abbia calcolato abbastanza barre
   int calculated = BarsCalculated(atrHandle);
   if(calculated < 0) {
      static bool errorShown = false;
      if(!errorShown) {
         Print("[ATR] ERROR: BarsCalculated() returned error: ", GetLastError());
         errorShown = true;
      }
      return Fixed_Spacing_Pips;
   }
   if(calculated < ATR_Period + 1) {
      static bool warningShown = false;
      if(!warningShown) {
         Print("[ATR] WARNING: Not ready. Bars calculated: ", calculated, ", Required: ", ATR_Period + 1);
         warningShown = true;
      }
      return Fixed_Spacing_Pips;
   }

   double atrBuffer[];
   ArraySetAsSeries(atrBuffer, true);

   if(CopyBuffer(atrHandle, 0, 0, 1, atrBuffer) <= 0) {
      static bool copyErrorShown = false;
      if(!copyErrorShown) {
         Print("[ATR] ERROR: CopyBuffer failed, error: ", GetLastError());
         copyErrorShown = true;
      }
      return Fixed_Spacing_Pips;  // Fallback
   }

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

      default:
         // Fallback to PURE mode
         if(isLong)
            tpPrice = orderEntryPrice + (spacingPoints * TP_Ratio_Pure);
         else
            tpPrice = orderEntryPrice - (spacingPoints * TP_Ratio_Pure);
         break;
   }

   return NormalizeDouble(tpPrice, symbolDigits);
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
      default:               name = "UNKNOWN";  break;
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
      default:
         desc = "Unknown Mode";
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

      default:
         Print("[ModeLogic] WARNING: Unknown NeutralMode, using defaults");
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
   Print("  SUGAMARA v5.2 - CONFIGURAZIONE MODALITÀ");
   Print("═══════════════════════════════════════════════════════════════════");
   PrintFormat("  Modalità: %s", GetModeName());
   PrintFormat("  Descrizione: %s", GetModeDescription());
   Print("───────────────────────────────────────────────────────────────────");
   PrintFormat("  ATR Disponibile: %s", IsATRAvailable() ? "Sì" : "No");
   PrintFormat("  ATR Abilitato: %s", IsATREnabled() ? "Sì" : "No");
   PrintFormat("  Shield Mode: %s", GetShieldModeNameLogic());
   PrintFormat("  Hedging (CASCADE_OVERLAP): %s", IsHedgingAvailable() ? "Sì" : "No");
   PrintFormat("  TP Mode: %s", UsesCascadeTP() ? "CASCADE" : "FISSO");
   Print("───────────────────────────────────────────────────────────────────");
   PrintFormat("  Spacing Corrente: %.1f pips", CalculateCurrentSpacing());
   Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| ═══════════════════════════════════════════════════════════════ |
//| 🛡️ SHIELD INTELLIGENTE INTEGRATION                              |
//| ═══════════════════════════════════════════════════════════════ |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Shield is Available                                      |
//+------------------------------------------------------------------+
bool IsShieldAvailableLogic()
{
   // v5.2: Shield now available for CASCADE_OVERLAP mode (RANGEBOX removed)
   return (IsCascadeOverlapMode() && ShieldMode != SHIELD_DISABLED);
}

//+------------------------------------------------------------------+
//| Get Shield Mode Name                                              |
//+------------------------------------------------------------------+
string GetShieldModeNameLogic()
{
   // v5.2: Shield available for CASCADE_OVERLAP mode
   if(!IsCascadeOverlapMode()) {
      return "N/A";
   }

   switch(ShieldMode) {
      case SHIELD_DISABLED: return "DISABLED";
      case SHIELD_SIMPLE: return "SIMPLE";
      case SHIELD_3_PHASES: return "3 PHASES";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Initialize Mode (main entry point)                                |
//+------------------------------------------------------------------+
bool InitializeMode()
{
   Print("=== Initializing Mode: ", GetModeName(), " ===");

   // Validate parameters
   if(!ValidateModeParameters()) {
      Print("ERROR: Mode parameter validation failed");
      return false;
   }

   // Mode-specific initialization
   switch(NeutralMode) {
      case NEUTRAL_PURE:
         currentSpacing_Pips = Fixed_Spacing_Pips;
         Print("  PURE Mode: Fixed spacing ", Fixed_Spacing_Pips, " pips");
         break;

      case NEUTRAL_CASCADE:
         if(IsATREnabled() && currentATR_Pips > 0) {
            currentSpacing_Pips = CalculateCurrentSpacing();
         } else {
            currentSpacing_Pips = Fixed_Spacing_Pips;
         }
         Print("  CASCADE Mode: Spacing ", currentSpacing_Pips, " pips");
         break;

      default:
         currentSpacing_Pips = Fixed_Spacing_Pips;
         Print("  Default: Fixed spacing ", Fixed_Spacing_Pips, " pips");
         break;
   }

   PrintModeConfiguration();
   return true;
}

//+------------------------------------------------------------------+
//| Process Mode OnTick                                               |
//+------------------------------------------------------------------+
void ProcessModeOnTick()
{
   switch(NeutralMode) {
      case NEUTRAL_PURE:
         // Pure mode: nothing special, spacing is fixed
         break;

      case NEUTRAL_CASCADE:
         // Cascade mode: check for ATR recalculation
         if(IsATREnabled()) {
            CheckATRRecalculation();
         }
         break;

      default:
         // Unknown mode: nothing special
         break;
   }
}

//+------------------------------------------------------------------+
//| Check ATR Recalculation                                           |
//+------------------------------------------------------------------+
void CheckATRRecalculation()
{
   if(!IsATREnabled()) return;

   datetime now = TimeCurrent();
   if(now - lastATRRecalc < ATR_RecalcHours * 3600) return;

   double newATR = GetATRPips();
   if(newATR <= 0) return;

   double changePercent = 0;
   if(currentATR_Pips > 0) {
      changePercent = MathAbs((newATR - currentATR_Pips) / currentATR_Pips) * 100;
   }

   if(changePercent > ATR_ChangeThreshold || currentATR_Pips == 0) {
      double oldSpacing = currentSpacing_Pips;
      currentATR_Pips = newATR;
      currentSpacing_Pips = CalculateCurrentSpacing();
      lastATRRecalc = now;

      if(DetailedLogging && changePercent > 0) {
         Print("[ModeLogic] ATR recalculated: ", DoubleToString(changePercent, 1), "% change");
         Print("  Old Spacing: ", DoubleToString(oldSpacing, 1), " pips");
         Print("  New Spacing: ", DoubleToString(currentSpacing_Pips, 1), " pips");
      }
   }
}

//+------------------------------------------------------------------+
//| Deinitialize Mode                                                 |
//+------------------------------------------------------------------+
void DeinitializeMode()
{
   Print("[ModeLogic] Deinitializing mode: ", GetModeName());

   // Deinitialize Shield if enabled
   if(ShieldMode != SHIELD_DISABLED) {
      DeinitializeShield();
   }

   Print("[ModeLogic] Mode deinitialized");
}
