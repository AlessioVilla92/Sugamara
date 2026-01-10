//+------------------------------------------------------------------+
//|                                            ShieldManager.mqh     |
//|                        SUGAMARA - Shield Intelligente            |
//|                        Simple + 3 Fasi Edition                   |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| GLOBAL VARIABLES FOR PENDING SHIELD ORDERS                       |
//+------------------------------------------------------------------+
ulong shieldPendingTicket = 0;           // Ticket ordine pending Shield
ENUM_SHIELD_TYPE shieldPendingType = SHIELD_NONE;  // Tipo shield pending
double shieldPendingPrice = 0;           // Prezzo ordine pending
double shieldPendingLot = 0;             // Lot ordine pending

//+------------------------------------------------------------------+
//| v5.5: HYSTERESIS VARIABLES FOR PRE-SHIELD CANCELLATION           |
//+------------------------------------------------------------------+
datetime g_preShieldInsideRangeStart = 0;  // When price entered INSIDE_RANGE from PRE-SHIELD
int g_shieldTransitionLogCount = 0;        // Counter for log throttling

//+------------------------------------------------------------------+
//| v5.5b: FLAGS FOR "FIRST OCCURRENCE ONLY" LOGGING                  |
//+------------------------------------------------------------------+
bool g_loggedWarningPhase = false;     // NORMAL->WARNING logged?
bool g_loggedExitWarning = false;      // WARNING->NORMAL logged?
bool g_loggedPreShieldPhase = false;   // WARNING->PRE-SHIELD logged?
bool g_loggedCancelPreShield = false;  // PRE-SHIELD->NORMAL logged?
bool g_loggedShieldActive = false;     // PRE-SHIELD->ACTIVE logged?

//+------------------------------------------------------------------+
//| v5.7: HEARTBEAT THROTTLING FOR LOG OPTIMIZATION                   |
//+------------------------------------------------------------------+
datetime g_lastShieldHeartbeat = 0;    // Last heartbeat log time
string   g_lastShieldState = "";       // Last logged state
int      g_shieldHeartbeatSec = 3600;  // Heartbeat every 1 hour when INSIDE_RANGE

//+------------------------------------------------------------------+
//| Get Shield Order Type Name                                        |
//+------------------------------------------------------------------+
string GetShieldOrderTypeName()
{
   return (ShieldOrderType == SHIELD_ORDER_MARKET ? "MARKET" : "STOP");
}

//+------------------------------------------------------------------+
//| Initialize Shield System                                          |
//+------------------------------------------------------------------+
bool InitializeShield()
{
   if(ShieldMode == SHIELD_DISABLED) {
      Log_InitConfig("Shield", "DISABLED");
      return true;
   }

   // Reset pending shield variables
   shieldPendingTicket = 0;
   shieldPendingType = SHIELD_NONE;
   shieldPendingPrice = 0;
   shieldPendingLot = 0;

   // Reset structure
   ZeroMemory(shield);
   shield.isActive = false;
   shield.type = SHIELD_NONE;
   shield.phase = PHASE_NORMAL;

   // Calculate breakout levels from grid edges
   if(!CalculateBreakoutLevels()) {
      Log_InitFailed("Shield", "breakout_levels_calculation");
      return false;
   }

   Log_InitConfig("Shield.Mode", (ShieldMode == SHIELD_SIMPLE ? "SIMPLE" : "3_PHASES"));
   Log_InitConfig("Shield.OrderType", GetShieldOrderTypeName());
   Log_InitComplete("Shield");

   return true;
}

//+------------------------------------------------------------------+
//| Calculate Shield Lot Size = Sum of exposed grid lots              |
//| v9.0: Grid A=BUY, Grid B=SELL (struttura default)                 |
//|   SHIELD_LONG protegge SHORT = Grid B (Upper + Lower)             |
//|   SHIELD_SHORT protegge LONG = Grid A (Upper + Lower)             |
//+------------------------------------------------------------------+
double CalculateShieldLotSize(ENUM_SHIELD_TYPE shieldType)
{
   double totalLots = 0;
   int positionsCount = 0;

   if(shieldType == SHIELD_LONG) {
      // Shield LONG protegge SHORT = SOLO Grid B (entrambe le zone)
      for(int i = 0; i < GridLevelsPerSide; i++) {
         if(gridB_Upper_Status[i] == ORDER_FILLED) {
            totalLots += gridB_Upper_Lots[i];
            positionsCount++;
         }
         if(gridB_Lower_Status[i] == ORDER_FILLED) {
            totalLots += gridB_Lower_Lots[i];
            positionsCount++;
         }
      }
   }
   else if(shieldType == SHIELD_SHORT) {
      // Shield SHORT protegge LONG = SOLO Grid A (entrambe le zone)
      for(int i = 0; i < GridLevelsPerSide; i++) {
         if(gridA_Upper_Status[i] == ORDER_FILLED) {
            totalLots += gridA_Upper_Lots[i];
            positionsCount++;
         }
         if(gridA_Lower_Status[i] == ORDER_FILLED) {
            totalLots += gridA_Lower_Lots[i];
            positionsCount++;
         }
      }
   }

   double rawLots = totalLots;
   totalLots = NormalizeLotSize(totalLots);
   if(totalLots < symbolMinLot) totalLots = symbolMinLot;

   Log_Debug("Shield", StringFormat("LotCalc type=%s positions=%d raw=%.4f normalized=%.2f",
             (shieldType == SHIELD_LONG ? "LONG" : "SHORT"), positionsCount, rawLots, totalLots));

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
      ManageActiveShield(currentPrice);
      return;
   }

   // Check breakout
   ENUM_BREAKOUT_DIRECTION direction;
   bool breakoutDetected = CheckBreakoutConditionShield(currentPrice, direction);

   if(breakoutDetected) {
      if(direction == BREAKOUT_UP) {
         Log_ShieldPhaseChange("NORMAL", "BREAKOUT_UP", currentPrice);
         ActivateShieldShort("SIMPLE");
      }
      else if(direction == BREAKOUT_DOWN) {
         Log_ShieldPhaseChange("NORMAL", "BREAKOUT_DOWN", currentPrice);
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
   ENUM_SYSTEM_STATE priceState = GetPricePositionInRange(currentPrice);

   switch(shield.phase) {

      //--- PHASE 0: NORMAL - Inside range
      case PHASE_NORMAL:
         if(priceState == STATE_WARNING_UP) {
            EnterWarningPhase(BREAKOUT_UP);
         }
         else if(priceState == STATE_WARNING_DOWN) {
            EnterWarningPhase(BREAKOUT_DOWN);
         }
         break;

      //--- PHASE 1: WARNING - Price near edge
      case PHASE_WARNING:
         if(priceState == STATE_INSIDE_RANGE) {
            ExitWarningPhase();
         }
         else if(priceState == STATE_WARNING_UP && currentPrice >= GetLastGridBLevel()) {
            EnterPreShieldPhase(BREAKOUT_UP);
         }
         else if(priceState == STATE_WARNING_DOWN && currentPrice <= GetLastGridALevel()) {
            EnterPreShieldPhase(BREAKOUT_DOWN);
         }
         break;

      //--- PHASE 2: PRE-SHIELD - Pending order ready
      case PHASE_PRE_SHIELD:
         if(priceState == STATE_INSIDE_RANGE) {
            if(g_preShieldInsideRangeStart == 0) {
               g_preShieldInsideRangeStart = TimeCurrent();
            }
            // Hysteresis: require 30 seconds inside range before cancelling
            datetime timeSinceInsideRange = TimeCurrent() - g_preShieldInsideRangeStart;
            if(timeSinceInsideRange >= 30) {
               CancelPreShield();
               g_preShieldInsideRangeStart = 0;
            }
         }
         else {
            g_preShieldInsideRangeStart = 0;
            // Check for breakout confirmation
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

      //--- PHASE 3: SHIELD ACTIVE - Protection in progress
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

   // Log only first occurrence
   if(!g_loggedWarningPhase) {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      Log_ShieldPhaseChange("NORMAL", (direction == BREAKOUT_UP ? "WARNING_UP" : "WARNING_DOWN"), currentPrice);
      g_loggedWarningPhase = true;
   }

   currentSystemState = (direction == BREAKOUT_UP ? STATE_WARNING_UP : STATE_WARNING_DOWN);
}

//+------------------------------------------------------------------+
//| Exit Warning Phase (return to normal)                             |
//+------------------------------------------------------------------+
void ExitWarningPhase()
{
   if(!g_loggedExitWarning) {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      Log_ShieldPhaseChange("WARNING", "NORMAL", currentPrice);
      g_loggedExitWarning = true;
   }

   shield.phase = PHASE_NORMAL;
   lastBreakoutDirection = BREAKOUT_NONE;
   currentSystemState = STATE_INSIDE_RANGE;
}

//+------------------------------------------------------------------+
//| Enter Pre-Shield Phase (Phase 2)                                  |
//+------------------------------------------------------------------+
void EnterPreShieldPhase(ENUM_BREAKOUT_DIRECTION direction)
{
   shield.phase = PHASE_PRE_SHIELD;
   lastBreakoutDirection = direction;
   g_preShieldInsideRangeStart = 0;

   if(!g_loggedPreShieldPhase) {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      Log_ShieldPhaseChange("WARNING", (direction == BREAKOUT_UP ? "PRE-SHIELD_UP" : "PRE-SHIELD_DOWN"), currentPrice);
      g_loggedPreShieldPhase = true;
   }

   if(EnableAlerts) {
      Alert("SUGAMARA: Shield pending - Breakout ", (direction == BREAKOUT_UP ? "UP" : "DOWN"), " imminent");
   }

   currentSystemState = STATE_SHIELD_PENDING;
}

//+------------------------------------------------------------------+
//| Cancel Pre-Shield (returned to range)                             |
//+------------------------------------------------------------------+
void CancelPreShield()
{
   if(!g_loggedCancelPreShield) {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      Log_ShieldPhaseChange("PRE-SHIELD", "NORMAL", currentPrice);
      g_loggedCancelPreShield = true;
   }

   // Cancel pending STOP order if exists
   if(ShieldOrderType == SHIELD_ORDER_STOP && shieldPendingTicket > 0) {
      if(trade.OrderDelete(shieldPendingTicket)) {
         Log_OrderCancelled(shieldPendingTicket, "PRE-SHIELD_CANCELLED");
      }
      else {
         Log_SystemError("Shield", trade.ResultRetcode(), "Failed to cancel pending order");
      }
      shieldPendingTicket = 0;
      shieldPendingType = SHIELD_NONE;
      shieldPendingPrice = 0;
      shieldPendingLot = 0;
   }

   shield.phase = PHASE_NORMAL;
   lastBreakoutDirection = BREAKOUT_NONE;
   currentSystemState = STATE_INSIDE_RANGE;
   g_preShieldInsideRangeStart = 0;
}

//+------------------------------------------------------------------+
//| Monitor Pending Shield Orders (for STOP order type)               |
//+------------------------------------------------------------------+
void MonitorPendingShieldOrders()
{
   if(ShieldOrderType != SHIELD_ORDER_STOP || shieldPendingTicket == 0) {
      return;
   }

   if(!OrderSelect(shieldPendingTicket)) {
      // Order not found as pending - check if it was executed
      if(PositionSelectByTicket(shieldPendingTicket)) {
         // Order was executed
         shield.ticket = shieldPendingTicket;
         shield.isActive = true;
         shield.type = shieldPendingType;
         shield.phase = PHASE_SHIELD_ACTIVE;
         shield.lot_size = PositionGetDouble(POSITION_VOLUME);
         shield.entry_price = PositionGetDouble(POSITION_PRICE_OPEN);
         shield.activation_time = TimeCurrent();
         shield.activation_count++;
         shield.trailing_sl = 0;

         totalShieldActivations++;
         currentSystemState = (shieldPendingType == SHIELD_LONG ? STATE_SHIELD_LONG : STATE_SHIELD_SHORT);

         // Calculate exposure covered
         double exposure = (shieldPendingType == SHIELD_LONG) ? totalShortLots : totalLongLots;
         Log_ShieldActivated((shieldPendingType == SHIELD_LONG ? "LONG" : "SHORT"),
                            shield.ticket, shield.entry_price, shield.lot_size, exposure);

         if(EnableAlerts) {
            Alert("SUGAMARA: Shield ", (shieldPendingType == SHIELD_LONG ? "LONG" : "SHORT"),
                  " ACTIVE @ ", DoubleToString(shield.entry_price, symbolDigits));
         }

         shieldPendingTicket = 0;
         shieldPendingType = SHIELD_NONE;
         shieldPendingPrice = 0;
         shieldPendingLot = 0;
      }
      else {
         // Order was cancelled or expired
         Log_OrderCancelled(shieldPendingTicket, "EXPIRED_OR_CANCELLED");
         shieldPendingTicket = 0;
         shieldPendingType = SHIELD_NONE;
         shieldPendingPrice = 0;
         shieldPendingLot = 0;
      }
   }
}

//+------------------------------------------------------------------+
//|                    SHIELD ACTIVATION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Activate Shield LONG (Breakout DOWN - protects SHORTs)            |
//+------------------------------------------------------------------+
void ActivateShieldLong(string source)
{
   double shieldLot = CalculateShieldLotSize(SHIELD_LONG);
   int shieldMagic = MagicNumber + MAGIC_SHIELD_LONG;
   trade.SetExpertMagicNumber(shieldMagic);

   if(ShieldOrderType == SHIELD_ORDER_MARKET) {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

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

         Log_ShieldActivated("LONG", shield.ticket, shield.entry_price, shieldLot, totalShortLots);

         if(EnableAlerts) {
            Alert("SUGAMARA: Shield LONG ACTIVE @ ", DoubleToString(shield.entry_price, symbolDigits));
         }
      }
      else {
         Log_SystemError("Shield", trade.ResultRetcode(), trade.ResultRetcodeDescription());
      }
   }
   else if(ShieldOrderType == SHIELD_ORDER_STOP) {
      double stopPrice = NormalizeDouble(lowerBreakoutLevel, symbolDigits);

      if(trade.BuyStop(shieldLot, stopPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "SUGAMARA_SHIELD_LONG_STOP")) {
         shieldPendingTicket = trade.ResultOrder();
         shieldPendingType = SHIELD_LONG;
         shieldPendingPrice = stopPrice;
         shieldPendingLot = shieldLot;

         shield.phase = PHASE_PRE_SHIELD;
         currentSystemState = STATE_SHIELD_PENDING;

         Log_OrderPlaced("SHIELD", "PENDING", 0, "BUY_STOP", shieldPendingTicket, stopPrice, 0, 0, shieldLot);
      }
      else {
         Log_SystemError("Shield", trade.ResultRetcode(), trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| Activate Shield SHORT (Breakout UP - protects LONGs)              |
//+------------------------------------------------------------------+
void ActivateShieldShort(string source)
{
   double shieldLot = CalculateShieldLotSize(SHIELD_SHORT);
   int shieldMagic = MagicNumber + MAGIC_SHIELD_SHORT;
   trade.SetExpertMagicNumber(shieldMagic);

   if(ShieldOrderType == SHIELD_ORDER_MARKET) {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

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

         Log_ShieldActivated("SHORT", shield.ticket, shield.entry_price, shieldLot, totalLongLots);

         if(EnableAlerts) {
            Alert("SUGAMARA: Shield SHORT ACTIVE @ ", DoubleToString(shield.entry_price, symbolDigits));
         }
      }
      else {
         Log_SystemError("Shield", trade.ResultRetcode(), trade.ResultRetcodeDescription());
      }
   }
   else if(ShieldOrderType == SHIELD_ORDER_STOP) {
      double stopPrice = NormalizeDouble(upperBreakoutLevel, symbolDigits);

      if(trade.SellStop(shieldLot, stopPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "SUGAMARA_SHIELD_SHORT_STOP")) {
         shieldPendingTicket = trade.ResultOrder();
         shieldPendingType = SHIELD_SHORT;
         shieldPendingPrice = stopPrice;
         shieldPendingLot = shieldLot;

         shield.phase = PHASE_PRE_SHIELD;
         currentSystemState = STATE_SHIELD_PENDING;

         Log_OrderPlaced("SHIELD", "PENDING", 0, "SELL_STOP", shieldPendingTicket, stopPrice, 0, 0, shieldLot);
      }
      else {
         Log_SystemError("Shield", trade.ResultRetcode(), trade.ResultRetcodeDescription());
      }
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
   if(!shield.isActive || shield.ticket == 0) {
      return;
   }

   // Verify position still exists
   if(!PositionSelectByTicket(shield.ticket)) {
      // Position closed externally (SL/TP hit)
      int duration = (int)(TimeCurrent() - shield.activation_time);
      Log_ShieldClosed(shield.ticket, "SL_TP_HIT", shield.current_pl, duration);
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
   if(!PositionSelectByTicket(shield.ticket)) {
      return;
   }

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double trailingStart = PipsToPoints(Shield_Trailing_Start);
   double trailingStep = PipsToPoints(Shield_Trailing_Step);

   double newSL = 0;
   bool shouldModify = false;

   if(shield.type == SHIELD_LONG) {
      double profit = currentPrice - openPrice;
      if(profit >= trailingStart) {
         newSL = NormalizeDouble(currentPrice - trailingStep, symbolDigits);
         shouldModify = (newSL > currentSL || currentSL == 0);
      }
   }
   else if(shield.type == SHIELD_SHORT) {
      double profit = openPrice - currentPrice;
      if(profit >= trailingStart) {
         newSL = NormalizeDouble(currentPrice + trailingStep, symbolDigits);
         shouldModify = (newSL < currentSL || currentSL == 0);
      }
   }

   if(shouldModify && newSL > 0) {
      if(trade.PositionModify(shield.ticket, newSL, 0)) {
         shield.trailing_sl = newSL;
         Log_PositionModified(shield.ticket, "SL", currentSL, newSL);
      } else {
         Log_SystemError("Shield.Trailing", trade.ResultRetcode(), trade.ResultRetcodeDescription());
      }
   }
}

//+------------------------------------------------------------------+
//| Close Shield Position                                             |
//+------------------------------------------------------------------+
void CloseShield(string reason)
{
   if(!shield.isActive || shield.ticket == 0) return;

   if(PositionSelectByTicket(shield.ticket)) {
      double pl = PositionGetDouble(POSITION_PROFIT);
      int duration = (int)(TimeCurrent() - shield.activation_time);

      if(trade.PositionClose(shield.ticket)) {
         totalShieldPL += pl;
         lastShieldClosure = TimeCurrent();
         Log_ShieldClosed(shield.ticket, reason, pl, duration);
      }
      else {
         Log_SystemError("Shield.Close", trade.ResultRetcode(), trade.ResultRetcodeDescription());
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

   // Reset phase logging flags for next cycle
   g_loggedWarningPhase = false;
   g_loggedExitWarning = false;
   g_loggedPreShieldPhase = false;
   g_loggedCancelPreShield = false;
}

//+------------------------------------------------------------------+
//|                    MAIN PROCESS FUNCTION                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Process Shield (called from OnTick)                               |
//+------------------------------------------------------------------+
void ProcessShield()
{
   if(ShieldMode == SHIELD_DISABLED) {
      return;
   }

   // v9.0: Rimosso check IsCascadeOverlapMode() - struttura è default

   // Monitor pending STOP orders if using STOP order type
   if(ShieldOrderType == SHIELD_ORDER_STOP) {
      MonitorPendingShieldOrders();
   }

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
//| Log Full Shield Report                                            |
//+------------------------------------------------------------------+
void LogShieldReport()
{
   Log_Header("SHIELD SYSTEM REPORT");
   Log_KeyValue("Mode", GetShieldModeName());
   Log_KeyValue("Order Type", GetShieldOrderTypeName());
   Log_KeyValue("Status", GetShieldStatusString());
   Log_KeyValue("Phase", GetShieldPhaseString());
   Log_Separator();

   if(ShieldOrderType == SHIELD_ORDER_STOP && shieldPendingTicket > 0) {
      Log_KeyValue("Pending Order", (shieldPendingType == SHIELD_LONG ? "BUY_STOP" : "SELL_STOP"));
      Log_KeyValueNum("Pending Ticket", shieldPendingTicket, 0);
      Log_KeyValueNum("Trigger Price", shieldPendingPrice, 5);
      Log_KeyValueNum("Lot Size", shieldPendingLot, 2);
      Log_Separator();
   }

   if(shield.isActive) {
      Log_KeyValue("Active Type", (shield.type == SHIELD_LONG ? "LONG" : "SHORT"));
      Log_KeyValueNum("Ticket", shield.ticket, 0);
      Log_KeyValueNum("Entry Price", shield.entry_price, 5);
      Log_KeyValueNum("Current P/L", shield.current_pl, 2);
      Log_KeyValueNum("Trailing SL", shield.trailing_sl, 5);
      Log_KeyValueNum("Duration (sec)", (int)(TimeCurrent() - shield.activation_time), 0);
   } else {
      Log_KeyValue("Active Shield", "NONE");
   }

   Log_Separator();
   Log_KeyValueNum("Total Activations", totalShieldActivations, 0);
   Log_KeyValueNum("Total P/L", totalShieldPL, 2);
   Log_Separator();
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
   // Cancel pending STOP order if exists
   if(ShieldOrderType == SHIELD_ORDER_STOP && shieldPendingTicket > 0) {
      if(trade.OrderDelete(shieldPendingTicket)) {
         Log_OrderCancelled(shieldPendingTicket, "DEINIT");
      }
      shieldPendingTicket = 0;
      shieldPendingType = SHIELD_NONE;
      shieldPendingPrice = 0;
      shieldPendingLot = 0;
   }

   // Close shield if active
   if(shield.isActive) {
      CloseShield("DEINIT");
   }

   // Log final stats
   Log_Debug("Shield", StringFormat("DEINIT activations=%d total_pl=%.2f", totalShieldActivations, totalShieldPL));
}

//+------------------------------------------------------------------+
//| Check if Shield is Available                                      |
//+------------------------------------------------------------------+
bool IsShieldAvailable()
{
   // v9.0: Shield sempre disponibile (struttura Grid A=BUY, Grid B=SELL è default)
   return (ShieldMode != SHIELD_DISABLED);
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
