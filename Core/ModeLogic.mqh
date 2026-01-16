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
//| Verifica se Hedging è disponibile                                 |
//+------------------------------------------------------------------+
bool IsHedgingAvailable()
{
   // v9.12: Fixed - usa AllowHedging (input parameter)
   return AllowHedging;
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
//| Calcola lo spacing corrente - v9.26 con Progressive Spacing       |
//| Supporta: FIXED, PAIR_AUTO, PROGRESSIVE_PERCENTAGE, PROGRESSIVE_LINEAR |
//+------------------------------------------------------------------+
double CalculateCurrentSpacing()
{
   // v9.26: Supporta SPACING_FIXED, SPACING_PAIR_AUTO, SPACING_PROGRESSIVE_*
   // Per progressive modes, ritorna lo spacing BASE (livello 0)

   double spacing = Fixed_Spacing_Pips;

   switch(SpacingMode) {
      case SPACING_PAIR_AUTO:
         // Pair Auto: usa spacing preset dalla coppia selezionata (DEFAULT)
         spacing = GetPairDefaultSpacing();
         break;

      case SPACING_PROGRESSIVE_PERCENTAGE:
      case SPACING_PROGRESSIVE_LINEAR:
         // Progressive: usa spacing base (come PAIR_AUTO o FIXED)
         // Lo spacing effettivo per livello è calcolato da CalculateProgressiveSpacing()
         spacing = GetPairDefaultSpacing();
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
//| 📐 PROGRESSIVE SPACING FUNCTIONS v9.26                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Progressive Spacing Variables                          |
//| Chiamare dopo CalculateCurrentSpacing() in OnInit                 |
//+------------------------------------------------------------------+
void InitializeProgressiveSpacing()
{
   // Se già inizializzato (es. dopo recovery), non sovrascrivere
   if(g_progressiveInitialized) {
      Print("[Progressive] Already initialized from recovery, keeping values");
      return;
   }

   // Usa currentSpacing_Pips come base
   progressiveSpacingBase = currentSpacing_Pips;

   // Rate percentuale: 20% -> 0.20
   progressiveSpacingRate = Progressive_Spacing_Percentage / 100.0;

   // Incremento lineare in pips
   progressiveLinearIncrement = Progressive_Spacing_Linear_Pips;

   // Livello da cui inizia la progressione
   progressiveStartLevel = Progressive_Start_Level;

   // Clamp start level
   if(progressiveStartLevel < 0) progressiveStartLevel = 0;
   if(progressiveStartLevel >= GridLevelsPerSide) progressiveStartLevel = GridLevelsPerSide - 1;

   g_progressiveInitialized = true;

   if(SpacingMode == SPACING_PROGRESSIVE_PERCENTAGE || SpacingMode == SPACING_PROGRESSIVE_LINEAR) {
      Print("[Progressive] Initialized: Base=", progressiveSpacingBase,
            " Rate=", progressiveSpacingRate * 100, "%",
            " Linear=", progressiveLinearIncrement, " pips",
            " StartLevel=", progressiveStartLevel);
   }
}

//+------------------------------------------------------------------+
//| Calculate Progressive Spacing for Specific Level                   |
//| Returns spacing in PIPS for the given level                        |
//| Level 0 = first grid level (closest to entry)                      |
//+------------------------------------------------------------------+
double CalculateProgressiveSpacing(int level)
{
   // Se non siamo in modalità progressiva, ritorna spacing fisso
   if(SpacingMode != SPACING_PROGRESSIVE_PERCENTAGE &&
      SpacingMode != SPACING_PROGRESSIVE_LINEAR) {
      return currentSpacing_Pips;
   }

   // Prima del livello di start, usa spacing fisso
   if(level < progressiveStartLevel) {
      return progressiveSpacingBase;
   }

   double spacing = progressiveSpacingBase;
   int effectiveLevel = level - progressiveStartLevel;

   if(SpacingMode == SPACING_PROGRESSIVE_PERCENTAGE) {
      // Formula geometrica: S(n) = Base × (1 + Rate)^n
      // Rate già in decimale (es. 0.20 per 20%)
      double progressionFactor = MathPow(1.0 + progressiveSpacingRate, effectiveLevel);
      spacing = progressiveSpacingBase * progressionFactor;
   }
   else if(SpacingMode == SPACING_PROGRESSIVE_LINEAR) {
      // Formula aritmetica: S(n) = Base + (n × Increment)
      spacing = progressiveSpacingBase + (effectiveLevel * progressiveLinearIncrement);
   }

   // Applica cap massimo
   spacing = MathMin(spacing, Progressive_Max_Spacing_Pips);

   // Applica minimo di sicurezza
   spacing = MathMax(spacing, 5.0);

   return spacing;
}

//+------------------------------------------------------------------+
//| Calculate Progressive Cumulative Distance from Entry               |
//| Returns TOTAL distance in PIPS from entry point to level N         |
//| Uses geometric/arithmetic series for efficiency                    |
//+------------------------------------------------------------------+
double CalculateProgressiveCumulativeDistance(int level)
{
   // Se non siamo in modalità progressiva, usa calcolo lineare standard
   if(SpacingMode != SPACING_PROGRESSIVE_PERCENTAGE &&
      SpacingMode != SPACING_PROGRESSIVE_LINEAR) {
      // Standard: entrySpacing + (level × spacing)
      double entrySpacingPips = GetEntrySpacingPips(currentSpacing_Pips);
      return entrySpacingPips + (level * currentSpacing_Pips);
   }

   // Calcola entry spacing (distanza entry -> livello 0)
   double entrySpacingPips = GetEntrySpacingPips(progressiveSpacingBase);
   double totalDistance = entrySpacingPips;

   // Numero di spaziature da sommare (da livello 0 a livello N)
   int totalSpacings = level;

   if(totalSpacings <= 0) {
      return totalDistance;  // Solo entry spacing per livello 0
   }

   // Parte 1: Spaziature FISSE (prima di progressiveStartLevel)
   int fixedSpacings = MathMin(totalSpacings, progressiveStartLevel);
   totalDistance += fixedSpacings * progressiveSpacingBase;

   // Parte 2: Spaziature PROGRESSIVE (da progressiveStartLevel in poi)
   int progressiveSpacings = MathMax(0, totalSpacings - progressiveStartLevel);

   if(progressiveSpacings > 0) {
      if(SpacingMode == SPACING_PROGRESSIVE_PERCENTAGE) {
         // Serie geometrica: Sum = Base × [(1+r)^n - 1] / r
         // Dove r = rate, n = numero spaziature progressive
         double r = progressiveSpacingRate;
         if(r > 0.0001) {  // Evita divisione per zero
            double geometricSum = progressiveSpacingBase * (MathPow(1.0 + r, progressiveSpacings) - 1.0) / r;
            totalDistance += geometricSum;
         } else {
            // Se rate ~0, usa lineare
            totalDistance += progressiveSpacings * progressiveSpacingBase;
         }
      }
      else if(SpacingMode == SPACING_PROGRESSIVE_LINEAR) {
         // Serie aritmetica: Sum = n×Base + Increment×n×(n-1)/2
         // Dove n = numero spaziature progressive
         int n = progressiveSpacings;
         double arithmeticSum = n * progressiveSpacingBase +
                                progressiveLinearIncrement * n * (n - 1) / 2.0;
         totalDistance += arithmeticSum;
      }
   }

   return totalDistance;
}

//+------------------------------------------------------------------+
//| Get Spacing Mode Name for Dashboard/Logging                        |
//+------------------------------------------------------------------+
string GetSpacingModeName()
{
   switch(SpacingMode) {
      case SPACING_FIXED:                   return "FIXED";
      case SPACING_PAIR_AUTO:               return "PAIR AUTO";
      case SPACING_PROGRESSIVE_PERCENTAGE:  return "PROGRESSIVE %";
      case SPACING_PROGRESSIVE_LINEAR:      return "PROGRESSIVE LINEAR";
      default:                              return "UNKNOWN";
   }
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

   //--- v9.26: Validazioni Progressive Spacing
   if(SpacingMode == SPACING_PROGRESSIVE_PERCENTAGE)
   {
      if(Progressive_Spacing_Percentage < 5.0 || Progressive_Spacing_Percentage > 100.0)
      {
         Print("[ModeLogic] ERROR: Progressive_Spacing_Percentage deve essere tra 5% e 100%");
         isValid = false;
      }

      // Warning se ultimo livello supera il cap
      double baseSpacing = GetPairDefaultSpacing();
      int lastLevel = GridLevelsPerSide - 1;
      int effectiveLevel = MathMax(0, lastLevel - Progressive_Start_Level);
      double lastSpacing = baseSpacing * MathPow(1.0 + Progressive_Spacing_Percentage/100.0, effectiveLevel);
      if(lastSpacing > Progressive_Max_Spacing_Pips)
      {
         PrintFormat("[ModeLogic] INFO: Ultimo livello spacing (%.1f pips) sarà capped a %.1f pips",
                     lastSpacing, Progressive_Max_Spacing_Pips);
      }
   }

   if(SpacingMode == SPACING_PROGRESSIVE_LINEAR)
   {
      if(Progressive_Spacing_Linear_Pips < 0.5 || Progressive_Spacing_Linear_Pips > 10.0)
      {
         Print("[ModeLogic] ERROR: Progressive_Spacing_Linear_Pips deve essere tra 0.5 e 10 pips");
         isValid = false;
      }
   }

   if(SpacingMode == SPACING_PROGRESSIVE_PERCENTAGE || SpacingMode == SPACING_PROGRESSIVE_LINEAR)
   {
      if(Progressive_Start_Level < 0 || Progressive_Start_Level >= GridLevelsPerSide)
      {
         PrintFormat("[ModeLogic] ERROR: Progressive_Start_Level deve essere tra 0 e %d",
                     GridLevelsPerSide - 1);
         isValid = false;
      }

      if(Progressive_Max_Spacing_Pips < 20.0 || Progressive_Max_Spacing_Pips > 200.0)
      {
         Print("[ModeLogic] ERROR: Progressive_Max_Spacing_Pips deve essere tra 20 e 200 pips");
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
   Log_Header("MODE CONFIGURATION");
   Log_KeyValue("Mode", GetModeName());
   Log_KeyValue("Description", GetModeDescription());
   Log_KeyValue("ATR Available", IsATRAvailable() ? "YES" : "NO");
   Log_KeyValue("ATR Enabled", IsATREnabled() ? "YES" : "NO");
   Log_KeyValue("Auto-Hedging", IsHedgingAvailable() ? "YES" : "NO");
   Log_KeyValue("TP Mode", UsesCascadeTP() ? "CASCADE" : "FIXED");
   Log_KeyValue("Spacing Mode", GetSpacingModeName());
   Log_KeyValueNum("Base Spacing", currentSpacing_Pips, 1);

   // v9.26: Show progressive details if enabled
   if(SpacingMode == SPACING_PROGRESSIVE_PERCENTAGE) {
      Log_KeyValueNum("Progressive Rate", Progressive_Spacing_Percentage, 0);
      Log_KeyValueNum("Start Level", progressiveStartLevel, 0);
      Log_KeyValueNum("Max Spacing Cap", Progressive_Max_Spacing_Pips, 1);
   }
   else if(SpacingMode == SPACING_PROGRESSIVE_LINEAR) {
      Log_KeyValueNum("Linear Increment", Progressive_Spacing_Linear_Pips, 1);
      Log_KeyValueNum("Start Level", progressiveStartLevel, 0);
      Log_KeyValueNum("Max Spacing Cap", Progressive_Max_Spacing_Pips, 1);
   }

   Log_Separator();
}

//+------------------------------------------------------------------+
//| 🛡️ SHIELD REMOVED in v9.12                                       |
//+------------------------------------------------------------------+

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
            currentSpacing_Pips = CalculateCurrentSpacing();  // v9.26: Usa sempre CalculateCurrentSpacing
         }
         Print("  CASCADE Mode: Spacing ", currentSpacing_Pips, " pips");
         break;

      default:
         currentSpacing_Pips = CalculateCurrentSpacing();
         Print("  Default: Spacing ", currentSpacing_Pips, " pips");
         break;
   }

   // v9.26: Initialize progressive spacing after currentSpacing_Pips is set
   InitializeProgressiveSpacing();

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
   // Shield REMOVED in v9.12
   Print("[ModeLogic] Mode deinitialized");
}
