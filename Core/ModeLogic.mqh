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
//| Get Default Spacing for Selected Pair - v5.9                      |
//| Returns the default spacing from the pair preset                  |
//+------------------------------------------------------------------+
double GetPairDefaultSpacing()
{
   switch(SelectedPair) {
      case PAIR_EURUSD:  return EURUSD_DefaultSpacing;
      case PAIR_USDCAD:  return USDCAD_DefaultSpacing;
      case PAIR_AUDNZD:  return AUDNZD_DefaultSpacing;
      case PAIR_EURCHF:  return EURCHF_DefaultSpacing;
      case PAIR_AUDCAD:  return AUDCAD_DefaultSpacing;
      case PAIR_NZDCAD:  return NZDCAD_DefaultSpacing;
      case PAIR_EURGBP:  return EURGBP_DefaultSpacing;
      case PAIR_GBPUSD:  return GBPUSD_DefaultSpacing;
      case PAIR_USDCHF:  return USDCHF_DefaultSpacing;
      case PAIR_USDJPY:  return USDJPY_DefaultSpacing;
      case PAIR_EURJPY:  return EURJPY_DefaultSpacing;
      case PAIR_AUDUSD:  return AUDUSD_DefaultSpacing;
      case PAIR_NZDUSD:  return NZDUSD_DefaultSpacing;
      case PAIR_CUSTOM:  return Custom_DefaultSpacing;
      default:           return Fixed_Spacing_Pips;
   }
}

//+------------------------------------------------------------------+
//| Calcola lo spacing corrente - v5.9 con SPACING_PAIR_AUTO          |
//| Supporta: FIXED, PAIR_AUTO, GEOMETRIC                             |
//+------------------------------------------------------------------+
double CalculateCurrentSpacing()
{
   // v5.9: Supporta SPACING_FIXED, SPACING_PAIR_AUTO, SPACING_GEOMETRIC
   // SPACING_CUSTOM rimosso (era identico a SPACING_FIXED)

   double spacing = Fixed_Spacing_Pips;

   switch(SpacingMode) {
      case SPACING_PAIR_AUTO:
         // Pair Auto: usa spacing preset dalla coppia selezionata
         spacing = GetPairDefaultSpacing();
         break;

      case SPACING_GEOMETRIC:
         // Geometric: spacing as % of current price
         spacing = SymbolInfoDouble(_Symbol, SYMBOL_BID) * SpacingGeometric_Percent / 100.0;
         spacing = spacing / symbolPoint;  // Convert to pips
         break;

      case SPACING_FIXED:
      default:
         spacing = Fixed_Spacing_Pips;
         break;
   }

   // Apply minimum spacing safety limit
   spacing = MathMax(spacing, 5.0);  // Minimum 5 pips

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
//| Check ATR Recalculation - v5.8 Simplified (monitoring only)       |
//| ATR no longer affects spacing, just updates monitoring value      |
//+------------------------------------------------------------------+
void CheckATRRecalculation()
{
   if(!IsATREnabled()) return;

   datetime now = TimeCurrent();
   // Check every hour (3600 seconds)
   if(now - lastATRRecalc < 3600) return;

   double newATR = GetATRPips();
   if(newATR <= 0) return;

   // Update ATR monitoring value
   currentATR_Pips = newATR;
   lastATRRecalc = now;

   // v5.8: Spacing is now fixed, just update for display
   currentSpacing_Pips = CalculateCurrentSpacing();
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
