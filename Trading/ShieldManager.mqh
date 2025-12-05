//+------------------------------------------------------------------+
//|                                            ShieldManager.mqh     |
//|                        SUGAMARA - Shield Intelligente            |
//|                        Simple + 3 Fasi Edition                   |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Initialize Shield System                                          |
//+------------------------------------------------------------------+
bool InitializeShield()
{
   if(ShieldMode == SHIELD_DISABLED) {
      Print("[Shield] Shield Intelligente: DISABLED");
      return true;
   }

   Print("=== Initializing Shield Intelligente ===");
   Print("  Mode: ", (ShieldMode == SHIELD_SIMPLE ? "SIMPLE (1 Phase)" : "3 PHASES"));

   // Reset structure
   ZeroMemory(shield);
   shield.isActive = false;
   shield.type = SHIELD_NONE;
   shield.phase = PHASE_NORMAL;

   // Calculate breakout levels from grid edges
   if(!CalculateBreakoutLevels()) {
      Print("ERROR: Failed to calculate breakout levels");
      return false;
   }

   Print("  Shield System: READY");

   return true;
}

//+------------------------------------------------------------------+
//| Calculate Shield Lot Size = Sum of exposed grid lots              |
//+------------------------------------------------------------------+
double CalculateShieldLotSize(ENUM_SHIELD_TYPE shieldType)
{
   double totalLots = 0;

   if(shieldType == SHIELD_LONG) {
      // Shield LONG protects all open SHORT positions (Grid B Upper + Grid A Lower)
      for(int i = 0; i < GridLevelsPerSide; i++) {
         if(gridB_Upper_Status[i] == ORDER_FILLED) {
            totalLots += gridB_Upper_Lots[i];
         }
         if(gridA_Lower_Status[i] == ORDER_FILLED) {
            totalLots += gridA_Lower_Lots[i];
         }
      }
   }
   else if(shieldType == SHIELD_SHORT) {
      // Shield SHORT protects all open LONG positions (Grid A Upper + Grid B Lower)
      for(int i = 0; i < GridLevelsPerSide; i++) {
         if(gridA_Upper_Status[i] == ORDER_FILLED) {
            totalLots += gridA_Upper_Lots[i];
         }
         if(gridB_Lower_Status[i] == ORDER_FILLED) {
            totalLots += gridB_Lower_Lots[i];
         }
      }
   }

   // Normalize
   totalLots = NormalizeLotSize(totalLots);

   // Minimum 0.01
   if(totalLots < symbolMinLot) totalLots = symbolMinLot;

   return totalLots;
}

//+------------------------------------------------------------------+
//|                    SHIELD SIMPLE (1 PHASE)                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Process Shield Simple - Direct activation on breakout             |
//+------------------------------------------------------------------+
void ProcessShieldSimple(double currentPrice)
{
   if(shield.isActive) {
      // Shield already active - manage it
      ManageActiveShield(currentPrice);
      return;
   }

   // Check breakout
   ENUM_BREAKOUT_DIRECTION direction;
   if(CheckBreakoutConditionShield(currentPrice, direction)) {
      if(direction == BREAKOUT_UP) {
         ActivateShieldShort("SIMPLE");
      }
      else if(direction == BREAKOUT_DOWN) {
         ActivateShieldLong("SIMPLE");
      }
   }
}

//+------------------------------------------------------------------+
//|                    SHIELD 3 PHASES                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Process Shield 3 Phases - Warning -> Pre-Shield -> Active         |
//+------------------------------------------------------------------+
void ProcessShield3Phases(double currentPrice)
{
   // Get price position in range
   ENUM_SYSTEM_STATE priceState = GetPricePositionInRange(currentPrice);

   switch(shield.phase) {

      //-------------------------------------------------------------
      // PHASE 0: NORMAL - Inside range
      //-------------------------------------------------------------
      case PHASE_NORMAL:
         if(priceState == STATE_WARNING_UP) {
            EnterWarningPhase(BREAKOUT_UP);
         }
         else if(priceState == STATE_WARNING_DOWN) {
            EnterWarningPhase(BREAKOUT_DOWN);
         }
         break;

      //-------------------------------------------------------------
      // PHASE 1: WARNING - Price near edge
      //-------------------------------------------------------------
      case PHASE_WARNING:
         // If back inside, reset
         if(priceState == STATE_INSIDE_RANGE) {
            ExitWarningPhase();
         }
         // If past last grid level, enter Pre-Shield
         else if(priceState == STATE_WARNING_UP && currentPrice >= GetLastGridBLevel()) {
            EnterPreShieldPhase(BREAKOUT_UP);
         }
         else if(priceState == STATE_WARNING_DOWN && currentPrice <= GetLastGridALevel()) {
            EnterPreShieldPhase(BREAKOUT_DOWN);
         }
         break;

      //-------------------------------------------------------------
      // PHASE 2: PRE-SHIELD - Pending order ready
      //-------------------------------------------------------------
      case PHASE_PRE_SHIELD:
         // If back inside, cancel pending and return to normal
         if(priceState == STATE_INSIDE_RANGE ||
            priceState == STATE_WARNING_UP ||
            priceState == STATE_WARNING_DOWN) {
            CancelPreShield();
         }
         // If breakout confirmed, activate shield
         else {
            ENUM_BREAKOUT_DIRECTION direction;
            if(CheckBreakoutConditionShield(currentPrice, direction)) {
               if(direction == BREAKOUT_UP) {
                  ActivateShieldShort("3_PHASES");
               }
               else if(direction == BREAKOUT_DOWN) {
                  ActivateShieldLong("3_PHASES");
               }
            }
         }
         break;

      //-------------------------------------------------------------
      // PHASE 3: SHIELD ACTIVE - Protection in progress
      //-------------------------------------------------------------
      case PHASE_SHIELD_ACTIVE:
         ManageActiveShield(currentPrice);
         break;
   }
}

//+------------------------------------------------------------------+
//| Enter Warning Phase (Phase 1)                                     |
//+------------------------------------------------------------------+
void EnterWarningPhase(ENUM_BREAKOUT_DIRECTION direction)
{
   shield.phase = PHASE_WARNING;
   lastBreakoutDirection = direction;

   Print("=== SHIELD PHASE 1: WARNING ===");
   Print("  Direction: ", (direction == BREAKOUT_UP ? "UP" : "DOWN"));

   // Alert
   if(EnableAlerts) {
      Alert("SUGAMARA: Warning Zone - Price near range edge");
   }

   // Update system state
   currentSystemState = (direction == BREAKOUT_UP ? STATE_WARNING_UP : STATE_WARNING_DOWN);
}

//+------------------------------------------------------------------+
//| Exit Warning Phase (return to normal)                             |
//+------------------------------------------------------------------+
void ExitWarningPhase()
{
   shield.phase = PHASE_NORMAL;
   lastBreakoutDirection = BREAKOUT_NONE;
   currentSystemState = STATE_INSIDE_RANGE;

   Print("[Shield] Exited Warning Zone - Back to normal");
}

//+------------------------------------------------------------------+
//| Enter Pre-Shield Phase (Phase 2)                                  |
//+------------------------------------------------------------------+
void EnterPreShieldPhase(ENUM_BREAKOUT_DIRECTION direction)
{
   shield.phase = PHASE_PRE_SHIELD;
   lastBreakoutDirection = direction;

   Print("=== SHIELD PHASE 2: PRE-SHIELD ===");
   Print("  Direction: ", (direction == BREAKOUT_UP ? "UP" : "DOWN"));
   Print("  Shield PENDING ready for activation");

   // Alert
   if(EnableAlerts) {
      Alert("SUGAMARA: Pre-Shield - Breakout imminent, Shield ready!");
   }

   currentSystemState = STATE_SHIELD_PENDING;
}

//+------------------------------------------------------------------+
//| Cancel Pre-Shield (returned to range)                             |
//+------------------------------------------------------------------+
void CancelPreShield()
{
   shield.phase = PHASE_NORMAL;
   lastBreakoutDirection = BREAKOUT_NONE;
   currentSystemState = STATE_INSIDE_RANGE;

   Print("[Shield] Pre-Shield cancelled - Price returned to range");
}

//+------------------------------------------------------------------+
//|                    SHIELD ACTIVATION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Activate Shield LONG (Breakout DOWN - protects LONGs)             |
//+------------------------------------------------------------------+
void ActivateShieldLong(string source)
{
   Print("=== ACTIVATING SHIELD LONG ===");
   Print("  Source: ", source);

   double shieldLot = CalculateShieldLotSize(SHIELD_LONG);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   // Open LONG position at market (NO TP, NO SL)
   int shieldMagic = MagicNumber + MAGIC_SHIELD_LONG;
   trade.SetExpertMagicNumber(shieldMagic);

   if(trade.Buy(shieldLot, _Symbol, 0, 0, 0, "SUGAMARA_SHIELD_LONG")) {
      shield.ticket = trade.ResultOrder();
      shield.isActive = true;
      shield.type = SHIELD_LONG;
      shield.phase = PHASE_SHIELD_ACTIVE;
      shield.lot_size = shieldLot;
      shield.entry_price = trade.ResultPrice();
      shield.activation_time = TimeCurrent();
      shield.activation_count++;
      shield.trailing_sl = 0;

      totalShieldActivations++;
      currentSystemState = STATE_SHIELD_LONG;

      Print("  [OK] Shield LONG ACTIVATED");
      Print("  Ticket: ", shield.ticket);
      Print("  Lot: ", shieldLot);
      Print("  Entry: ", shield.entry_price);
      Print("  Covering Short exposure: ", totalShortLots, " lots");

      if(EnableAlerts) {
         Alert("SUGAMARA: Shield LONG activated! Breakout DOWN - Protection active");
      }
   }
   else {
      Print("  [ERROR] Opening Shield LONG: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Activate Shield SHORT (Breakout UP - protects SHORTs)             |
//+------------------------------------------------------------------+
void ActivateShieldShort(string source)
{
   Print("=== ACTIVATING SHIELD SHORT ===");
   Print("  Source: ", source);

   double shieldLot = CalculateShieldLotSize(SHIELD_SHORT);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   // Open SHORT position at market (NO TP, NO SL)
   int shieldMagic = MagicNumber + MAGIC_SHIELD_SHORT;
   trade.SetExpertMagicNumber(shieldMagic);

   if(trade.Sell(shieldLot, _Symbol, 0, 0, 0, "SUGAMARA_SHIELD_SHORT")) {
      shield.ticket = trade.ResultOrder();
      shield.isActive = true;
      shield.type = SHIELD_SHORT;
      shield.phase = PHASE_SHIELD_ACTIVE;
      shield.lot_size = shieldLot;
      shield.entry_price = trade.ResultPrice();
      shield.activation_time = TimeCurrent();
      shield.activation_count++;
      shield.trailing_sl = 0;

      totalShieldActivations++;
      currentSystemState = STATE_SHIELD_SHORT;

      Print("  [OK] Shield SHORT ACTIVATED");
      Print("  Ticket: ", shield.ticket);
      Print("  Lot: ", shieldLot);
      Print("  Entry: ", shield.entry_price);
      Print("  Covering Long exposure: ", totalLongLots, " lots");

      if(EnableAlerts) {
         Alert("SUGAMARA: Shield SHORT activated! Breakout UP - Protection active");
      }
   }
   else {
      Print("  [ERROR] Opening Shield SHORT: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//|                    ACTIVE SHIELD MANAGEMENT                      |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Manage Active Shield                                              |
//+------------------------------------------------------------------+
void ManageActiveShield(double currentPrice)
{
   if(!shield.isActive || shield.ticket == 0) return;

   // Verify position still exists
   if(!PositionSelectByTicket(shield.ticket)) {
      Print("[Shield] Position not found - may have been closed by SL/TP");
      ResetShield();
      return;
   }

   // Update current P/L
   shield.current_pl = PositionGetDouble(POSITION_PROFIT);

   // Apply trailing if enabled
   if(Shield_Use_Trailing) {
      ApplyShieldTrailing(currentPrice);
   }

   // Check reentry condition
   if(CheckReentryConditionShield(currentPrice)) {
      CloseShield("REENTRY");
   }
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop to Shield                                     |
//+------------------------------------------------------------------+
void ApplyShieldTrailing(double currentPrice)
{
   if(!PositionSelectByTicket(shield.ticket)) return;

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double trailingStart = PipsToPoints(Shield_Trailing_Start);
   double trailingStep = PipsToPoints(Shield_Trailing_Step);

   if(shield.type == SHIELD_LONG) {
      // LONG: trailing SL upwards
      double profit = currentPrice - openPrice;
      if(profit >= trailingStart) {
         double newSL = NormalizeDouble(currentPrice - trailingStep, symbolDigits);
         if(newSL > currentSL || currentSL == 0) {
            if(trade.PositionModify(shield.ticket, newSL, 0)) {
               shield.trailing_sl = newSL;
               Print("[Shield] Trailing SL updated: ", newSL);
            }
         }
      }
   }
   else if(shield.type == SHIELD_SHORT) {
      // SHORT: trailing SL downwards
      double profit = openPrice - currentPrice;
      if(profit >= trailingStart) {
         double newSL = NormalizeDouble(currentPrice + trailingStep, symbolDigits);
         if(newSL < currentSL || currentSL == 0) {
            if(trade.PositionModify(shield.ticket, newSL, 0)) {
               shield.trailing_sl = newSL;
               Print("[Shield] Trailing SL updated: ", newSL);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close Shield Position                                             |
//+------------------------------------------------------------------+
void CloseShield(string reason)
{
   if(!shield.isActive || shield.ticket == 0) return;

   Print("=== CLOSING SHIELD ===");
   Print("  Reason: ", reason);

   if(PositionSelectByTicket(shield.ticket)) {
      double pl = PositionGetDouble(POSITION_PROFIT);

      if(trade.PositionClose(shield.ticket)) {
         totalShieldPL += pl;
         lastShieldClosure = TimeCurrent();

         Print("  [OK] Shield CLOSED");
         Print("  P/L: ", pl);
         Print("  Total Shield P/L: ", totalShieldPL);
         Print("  Duration: ", (int)(TimeCurrent() - shield.activation_time), " seconds");

         if(EnableAlerts) {
            Alert("SUGAMARA: Shield closed - ", reason, " - P/L: ", DoubleToString(pl, 2));
         }
      }
      else {
         Print("  [ERROR] Closing Shield: ", trade.ResultRetcode());
      }
   }

   ResetShield();
}

//+------------------------------------------------------------------+
//| Reset Shield Variables                                            |
//+------------------------------------------------------------------+
void ResetShield()
{
   shield.isActive = false;
   shield.type = SHIELD_NONE;
   shield.phase = PHASE_NORMAL;
   shield.ticket = 0;
   shield.lot_size = 0;
   shield.entry_price = 0;
   shield.current_pl = 0;
   shield.trailing_sl = 0;

   lastBreakoutDirection = BREAKOUT_NONE;
   currentSystemState = STATE_INSIDE_RANGE;

   Print("[Shield] Reset - System returns to normal operation");
}

//+------------------------------------------------------------------+
//|                    MAIN PROCESS FUNCTION                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Process Shield (called from OnTick)                               |
//+------------------------------------------------------------------+
void ProcessShield()
{
   if(ShieldMode == SHIELD_DISABLED) return;
   if(NeutralMode != NEUTRAL_RANGEBOX) return;

   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   switch(ShieldMode) {
      case SHIELD_SIMPLE:
         ProcessShieldSimple(currentPrice);
         break;

      case SHIELD_3_PHASES:
         ProcessShield3Phases(currentPrice);
         break;
   }
}

//+------------------------------------------------------------------+
//| Get Shield Status String                                          |
//+------------------------------------------------------------------+
string GetShieldStatusString()
{
   if(ShieldMode == SHIELD_DISABLED) return "DISABLED";

   if(!shield.isActive) {
      switch(shield.phase) {
         case PHASE_NORMAL: return "IDLE";
         case PHASE_WARNING: return "WARNING";
         case PHASE_PRE_SHIELD: return "PRE-SHIELD";
         default: return "IDLE";
      }
   }

   switch(shield.type) {
      case SHIELD_LONG: return "SHIELD LONG ACTIVE";
      case SHIELD_SHORT: return "SHIELD SHORT ACTIVE";
      default: return "ACTIVE";
   }
}

//+------------------------------------------------------------------+
//| Get Shield Phase String                                           |
//+------------------------------------------------------------------+
string GetShieldPhaseString()
{
   switch(shield.phase) {
      case PHASE_NORMAL: return "Normal";
      case PHASE_WARNING: return "Warning";
      case PHASE_PRE_SHIELD: return "Pre-Shield";
      case PHASE_SHIELD_ACTIVE: return "Active";
      default: return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Emergency Close All Shields                                       |
//+------------------------------------------------------------------+
void EmergencyCloseShield()
{
   if(shield.isActive && shield.ticket > 0) {
      CloseShield("EMERGENCY");
   }
}

//+------------------------------------------------------------------+
//| Deinitialize Shield                                               |
//+------------------------------------------------------------------+
void DeinitializeShield()
{
   // Close shield if active
   if(shield.isActive) {
      CloseShield("DEINIT");
   }

   Print("[Shield] System deinitialized");
   Print("  Total Activations: ", totalShieldActivations);
   Print("  Total Shield P/L: ", totalShieldPL);
}

//+------------------------------------------------------------------+
//| Check if Shield is Available                                      |
//+------------------------------------------------------------------+
bool IsShieldAvailable()
{
   return (NeutralMode == NEUTRAL_RANGEBOX && ShieldMode != SHIELD_DISABLED);
}

//+------------------------------------------------------------------+
//| Get Shield Mode Name                                              |
//+------------------------------------------------------------------+
string GetShieldModeName()
{
   switch(ShieldMode) {
      case SHIELD_DISABLED: return "DISABLED";
      case SHIELD_SIMPLE: return "SIMPLE (1 Phase)";
      case SHIELD_3_PHASES: return "3 PHASES";
      default: return "UNKNOWN";
   }
}
