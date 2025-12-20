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
      Print("[Shield] Shield Intelligente: DISABLED");
      return true;
   }

   Print("=== Initializing Shield Intelligente ===");
   Print("  Mode: ", (ShieldMode == SHIELD_SIMPLE ? "SIMPLE (1 Phase)" : "3 PHASES"));
   Print("  Order Type: ", GetShieldOrderTypeName());

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
   int shortPositions = 0;
   int longPositions = 0;

   if(DetailedLogging) {
      Print("[Shield] CalculateShieldLotSize() - Type: ", (shieldType == SHIELD_LONG ? "LONG" : "SHORT"));
   }

   if(shieldType == SHIELD_LONG) {
      // Shield LONG protects all open SHORT positions (Grid B Upper + Grid A Lower)
      for(int i = 0; i < GridLevelsPerSide; i++) {
         if(gridB_Upper_Status[i] == ORDER_FILLED) {
            totalLots += gridB_Upper_Lots[i];
            shortPositions++;
            if(DetailedLogging) {
               PrintFormat("[Shield]   Grid B Upper[%d]: %.2f lots", i, gridB_Upper_Lots[i]);
            }
         }
         if(gridA_Lower_Status[i] == ORDER_FILLED) {
            totalLots += gridA_Lower_Lots[i];
            shortPositions++;
            if(DetailedLogging) {
               PrintFormat("[Shield]   Grid A Lower[%d]: %.2f lots", i, gridA_Lower_Lots[i]);
            }
         }
      }
   }
   else if(shieldType == SHIELD_SHORT) {
      // Shield SHORT protects all open LONG positions (Grid A Upper + Grid B Lower)
      for(int i = 0; i < GridLevelsPerSide; i++) {
         if(gridA_Upper_Status[i] == ORDER_FILLED) {
            totalLots += gridA_Upper_Lots[i];
            longPositions++;
            if(DetailedLogging) {
               PrintFormat("[Shield]   Grid A Upper[%d]: %.2f lots", i, gridA_Upper_Lots[i]);
            }
         }
         if(gridB_Lower_Status[i] == ORDER_FILLED) {
            totalLots += gridB_Lower_Lots[i];
            longPositions++;
            if(DetailedLogging) {
               PrintFormat("[Shield]   Grid B Lower[%d]: %.2f lots", i, gridB_Lower_Lots[i]);
            }
         }
      }
   }

   double rawLots = totalLots;

   // Normalize
   totalLots = NormalizeLotSize(totalLots);

   // Minimum 0.01
   if(totalLots < symbolMinLot) totalLots = symbolMinLot;

   if(DetailedLogging) {
      PrintFormat("[Shield] Lot Calculation Summary:");
      PrintFormat("[Shield]   Positions to cover: %d", (shieldType == SHIELD_LONG ? shortPositions : longPositions));
      PrintFormat("[Shield]   Raw lot sum: %.4f", rawLots);
      PrintFormat("[Shield]   Normalized lot: %.2f", totalLots);
      PrintFormat("[Shield]   Min lot applied: %s", (rawLots < symbolMinLot ? "YES" : "NO"));
   }

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
   if(DetailedLogging) {
      PrintFormat("[Shield] ProcessShieldSimple() - Price: %.5f, Active: %s",
                  currentPrice, (shield.isActive ? "YES" : "NO"));
   }

   if(shield.isActive) {
      // Shield already active - manage it
      if(DetailedLogging) {
         PrintFormat("[Shield]   Managing active shield - Type: %s, P/L: %.2f",
                     (shield.type == SHIELD_LONG ? "LONG" : "SHORT"), shield.current_pl);
      }
      ManageActiveShield(currentPrice);
      return;
   }

   // Check breakout
   ENUM_BREAKOUT_DIRECTION direction;
   bool breakoutDetected = CheckBreakoutConditionShield(currentPrice, direction);

   if(DetailedLogging) {
      PrintFormat("[Shield]   Breakout check: %s, Direction: %s",
                  (breakoutDetected ? "DETECTED" : "None"),
                  (direction == BREAKOUT_UP ? "UP" : (direction == BREAKOUT_DOWN ? "DOWN" : "NONE")));
   }

   if(breakoutDetected) {
      if(direction == BREAKOUT_UP) {
         Print("[Shield] BREAKOUT UP detected - Activating Shield SHORT");
         ActivateShieldShort("SIMPLE");
      }
      else if(direction == BREAKOUT_DOWN) {
         Print("[Shield] BREAKOUT DOWN detected - Activating Shield LONG");
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

   if(DetailedLogging) {
      string phaseStr = GetShieldPhaseString();
      string stateStr = "";
      switch(priceState) {
         case STATE_INSIDE_RANGE: stateStr = "INSIDE_RANGE"; break;
         case STATE_WARNING_UP: stateStr = "WARNING_UP"; break;
         case STATE_WARNING_DOWN: stateStr = "WARNING_DOWN"; break;
         default: stateStr = "OTHER"; break;
      }
      PrintFormat("[Shield] ProcessShield3Phases() - Price: %.5f, Phase: %s, State: %s",
                  currentPrice, phaseStr, stateStr);
   }

   switch(shield.phase) {

      //-------------------------------------------------------------
      // PHASE 0: NORMAL - Inside range
      //-------------------------------------------------------------
      case PHASE_NORMAL:
         if(priceState == STATE_WARNING_UP) {
            Print("[Shield] Phase transition: NORMAL -> WARNING (UP)");
            EnterWarningPhase(BREAKOUT_UP);
         }
         else if(priceState == STATE_WARNING_DOWN) {
            Print("[Shield] Phase transition: NORMAL -> WARNING (DOWN)");
            EnterWarningPhase(BREAKOUT_DOWN);
         }
         break;

      //-------------------------------------------------------------
      // PHASE 1: WARNING - Price near edge
      //-------------------------------------------------------------
      case PHASE_WARNING:
         // If back inside, reset
         if(priceState == STATE_INSIDE_RANGE) {
            Print("[Shield] Phase transition: WARNING -> NORMAL (returned to range)");
            ExitWarningPhase();
         }
         // If past last grid level, enter Pre-Shield
         else if(priceState == STATE_WARNING_UP && currentPrice >= GetLastGridBLevel()) {
            PrintFormat("[Shield] Phase transition: WARNING -> PRE-SHIELD (price %.5f >= lastGridB)", currentPrice);
            EnterPreShieldPhase(BREAKOUT_UP);
         }
         else if(priceState == STATE_WARNING_DOWN && currentPrice <= GetLastGridALevel()) {
            PrintFormat("[Shield] Phase transition: WARNING -> PRE-SHIELD (price %.5f <= lastGridA)", currentPrice);
            EnterPreShieldPhase(BREAKOUT_DOWN);
         }
         break;

      //-------------------------------------------------------------
      // PHASE 2: PRE-SHIELD - Pending order ready
      // v5.5 FIX: Only cancel if FULLY inside range, NOT if still in warning zone!
      // WARNING zone is still a danger zone - don't cancel PRE-SHIELD there
      //-------------------------------------------------------------
      case PHASE_PRE_SHIELD:
         // v5.5: Cancel ONLY if back FULLY inside safe range
         // WARNING zones are still danger zones - keep PRE-SHIELD active!
         if(priceState == STATE_INSIDE_RANGE) {
            // v5.5: Track when price first entered INSIDE_RANGE
            if(g_preShieldInsideRangeStart == 0) {
               g_preShieldInsideRangeStart = TimeCurrent();
            }

            // v5.5: Hysteresis - require 30 seconds CONTINUOUSLY inside range before cancelling
            datetime timeSinceInsideRange = TimeCurrent() - g_preShieldInsideRangeStart;
            if(timeSinceInsideRange >= 30) {  // 30 second cooldown
               PrintFormat("[Shield] PRE-SHIELD -> NORMAL (inside range for %d sec)", (int)timeSinceInsideRange);
               CancelPreShield();
               g_preShieldInsideRangeStart = 0;  // Reset for next time
            }
            // Else: still inside range but cooldown not elapsed - keep PRE-SHIELD active
         }
         else {
            // Price left INSIDE_RANGE (still in WARNING or beyond) - reset timer
            g_preShieldInsideRangeStart = 0;

            // Check for breakout confirmation
            ENUM_BREAKOUT_DIRECTION direction;
            if(CheckBreakoutConditionShield(currentPrice, direction)) {
               Print("[Shield] PRE-SHIELD -> SHIELD_ACTIVE (breakout confirmed)");
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
         if(DetailedLogging) {
            PrintFormat("[Shield] SHIELD_ACTIVE - Managing shield, Current P/L: %.2f", shield.current_pl);
         }
         ManageActiveShield(currentPrice);
         break;
   }
}

//+------------------------------------------------------------------+
//| Enter Warning Phase (Phase 1)                                     |
//| v5.5b: Log ONLY first occurrence, never again                     |
//+------------------------------------------------------------------+
void EnterWarningPhase(ENUM_BREAKOUT_DIRECTION direction)
{
   shield.phase = PHASE_WARNING;
   lastBreakoutDirection = direction;
   g_shieldTransitionLogCount++;

   // v5.5b: Log ONLY first occurrence, never again
   if(!g_loggedWarningPhase) {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double dist = (direction == BREAKOUT_UP) ?
                    PointsToPips(shieldZone.resistance - currentPrice) :
                    PointsToPips(currentPrice - shieldZone.support);
      PrintFormat("[Shield] NORMAL->WARNING | %s | Price:%.5f | Dist:%.1f pips",
                  (direction == BREAKOUT_UP ? "UP" : "DOWN"),
                  currentPrice, dist);
      g_loggedWarningPhase = true;  // Never log again
   }

   // Alert (keep this - alerts are important)
   if(EnableAlerts) {
      Alert("SUGAMARA: Warning Zone - Price near range edge");
   }

   // Update system state
   currentSystemState = (direction == BREAKOUT_UP ? STATE_WARNING_UP : STATE_WARNING_DOWN);
}

//+------------------------------------------------------------------+
//| Exit Warning Phase (return to normal)                             |
//| v5.5b: Log ONLY first occurrence, never again                     |
//+------------------------------------------------------------------+
void ExitWarningPhase()
{
   g_shieldTransitionLogCount++;

   // v5.5b: Log ONLY first occurrence, never again
   if(!g_loggedExitWarning) {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      PrintFormat("[Shield] WARNING->NORMAL | Price:%.5f", currentPrice);
      g_loggedExitWarning = true;  // Never log again
   }

   shield.phase = PHASE_NORMAL;
   lastBreakoutDirection = BREAKOUT_NONE;
   currentSystemState = STATE_INSIDE_RANGE;
}

//+------------------------------------------------------------------+
//| Enter Pre-Shield Phase (Phase 2)                                  |
//| v5.5b: Log ONLY first occurrence, never again                     |
//+------------------------------------------------------------------+
void EnterPreShieldPhase(ENUM_BREAKOUT_DIRECTION direction)
{
   shield.phase = PHASE_PRE_SHIELD;
   lastBreakoutDirection = direction;
   g_shieldTransitionLogCount++;
   g_preShieldInsideRangeStart = 0;  // v5.5: Reset hysteresis timer

   // v5.5b: Log ONLY first occurrence, never again
   if(!g_loggedPreShieldPhase) {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double breakoutLevel = (direction == BREAKOUT_UP) ? upperBreakoutLevel : lowerBreakoutLevel;
      double dist = (direction == BREAKOUT_UP) ?
                    PointsToPips(breakoutLevel - currentPrice) :
                    PointsToPips(currentPrice - breakoutLevel);
      PrintFormat("[Shield] WARNING->PRE-SHIELD | %s | Price:%.5f | Dist:%.1f pips | Type:%s",
                  (direction == BREAKOUT_UP ? "UP" : "DOWN"),
                  currentPrice, dist, GetShieldOrderTypeName());
      g_loggedPreShieldPhase = true;  // Never log again
   }

   // Alert (keep this - this is important for imminent breakout)
   if(EnableAlerts) {
      Alert("SUGAMARA: Pre-Shield - Breakout imminent, Shield ready!");
   }

   currentSystemState = STATE_SHIELD_PENDING;
}

//+------------------------------------------------------------------+
//| Cancel Pre-Shield (returned to range)                             |
//| v5.5b: Log ONLY first occurrence, never again                     |
//+------------------------------------------------------------------+
void CancelPreShield()
{
   g_shieldTransitionLogCount++;

   // v5.5b: Log ONLY first occurrence, never again
   if(!g_loggedCancelPreShield) {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      PrintFormat("[Shield] PRE-SHIELD->NORMAL (cancelled) | Price:%.5f", currentPrice);
      g_loggedCancelPreShield = true;  // Never log again
   }

   // Cancel pending STOP order if exists (keep this logging - order operations are important)
   if(ShieldOrderType == SHIELD_ORDER_STOP && shieldPendingTicket > 0) {
      if(trade.OrderDelete(shieldPendingTicket)) {
         PrintFormat("[Shield] Pending order #%d cancelled", shieldPendingTicket);
      }
      else {
         PrintFormat("[Shield] WARN: Failed to cancel order #%d: %d",
                     shieldPendingTicket, trade.ResultRetcode());
      }

      // Reset pending variables
      shieldPendingTicket = 0;
      shieldPendingType = SHIELD_NONE;
      shieldPendingPrice = 0;
      shieldPendingLot = 0;
   }

   shield.phase = PHASE_NORMAL;
   lastBreakoutDirection = BREAKOUT_NONE;
   currentSystemState = STATE_INSIDE_RANGE;
   g_preShieldInsideRangeStart = 0;  // v5.5: Reset hysteresis timer
}

//+------------------------------------------------------------------+
//| Monitor Pending Shield Orders (for STOP order type)               |
//+------------------------------------------------------------------+
void MonitorPendingShieldOrders()
{
   if(ShieldOrderType != SHIELD_ORDER_STOP || shieldPendingTicket == 0) {
      return;
   }

   // Check if pending order still exists
   if(!OrderSelect(shieldPendingTicket)) {
      // Order not found as pending - check if it was executed
      if(PositionSelectByTicket(shieldPendingTicket)) {
         // Order was executed - update shield structure
         Print("═══════════════════════════════════════════════════════════════════");
         Print("  PENDING SHIELD ORDER EXECUTED!");
         Print("═══════════════════════════════════════════════════════════════════");

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

         Print("  ✅ [STOP] Shield ", (shieldPendingType == SHIELD_LONG ? "LONG" : "SHORT"), " NOW ACTIVE");
         PrintFormat("     Ticket: %d", shield.ticket);
         PrintFormat("     Executed Price: %.5f", shield.entry_price);
         PrintFormat("     Lot: %.2f", shield.lot_size);
         Print("═══════════════════════════════════════════════════════════════════");

         if(EnableAlerts) {
            Alert("SUGAMARA: Shield STOP order executed! Protection now active");
         }

         // Reset pending variables
         shieldPendingTicket = 0;
         shieldPendingType = SHIELD_NONE;
         shieldPendingPrice = 0;
         shieldPendingLot = 0;
      }
      else {
         // Order was cancelled or expired
         Print("[Shield] Pending order ", shieldPendingTicket, " no longer exists (cancelled/expired)");
         shieldPendingTicket = 0;
         shieldPendingType = SHIELD_NONE;
         shieldPendingPrice = 0;
         shieldPendingLot = 0;
      }
   }
   else {
      // Order still pending - log status if detailed logging
      if(DetailedLogging) {
         double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         double distancePips = MathAbs(currentPrice - shieldPendingPrice) / symbolPoint / 10;
         PrintFormat("[Shield] Pending order #%d still waiting - Distance: %.1f pips",
                     shieldPendingTicket, distancePips);
      }
   }
}

//+------------------------------------------------------------------+
//|                    SHIELD ACTIVATION                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Activate Shield LONG (Breakout DOWN - protects LONGs)             |
//+------------------------------------------------------------------+
void ActivateShieldLong(string source)
{
   Print("═══════════════════════════════════════════════════════════════════");
   Print("  ACTIVATING SHIELD LONG");
   Print("═══════════════════════════════════════════════════════════════════");
   Print("  Source: ", source);
   Print("  Order Type: ", GetShieldOrderTypeName());

   double shieldLot = CalculateShieldLotSize(SHIELD_LONG);
   int shieldMagic = MagicNumber + MAGIC_SHIELD_LONG;
   trade.SetExpertMagicNumber(shieldMagic);

   bool success = false;

   //------------------------------------------------------------------
   // MARKET ORDER - Esecuzione immediata
   //------------------------------------------------------------------
   if(ShieldOrderType == SHIELD_ORDER_MARKET) {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      Print("───────────────────────────────────────────────────────────────────");
      Print("  [MARKET] Sending BUY order at market");
      PrintFormat("  [MARKET]   Ask Price: %.5f", currentPrice);
      PrintFormat("  [MARKET]   Lot Size: %.2f", shieldLot);
      PrintFormat("  [MARKET]   Magic: %d", shieldMagic);
      Print("───────────────────────────────────────────────────────────────────");

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
         success = true;

         Print("  ✅ [MARKET] Shield LONG EXECUTED");
         PrintFormat("     Ticket: %d", shield.ticket);
         PrintFormat("     Executed Price: %.5f", shield.entry_price);
         PrintFormat("     Slippage: %.1f pips", MathAbs(shield.entry_price - currentPrice) / symbolPoint / 10);
         PrintFormat("     Lot: %.2f", shieldLot);
         PrintFormat("     Covering Short exposure: %.2f lots", totalShortLots);
      }
      else {
         Print("  ❌ [MARKET] Order FAILED");
         PrintFormat("     Error Code: %d", trade.ResultRetcode());
         PrintFormat("     Description: %s", trade.ResultRetcodeDescription());
      }
   }
   //------------------------------------------------------------------
   // STOP ORDER - Pending order al livello breakout
   //------------------------------------------------------------------
   else if(ShieldOrderType == SHIELD_ORDER_STOP) {
      double stopPrice = lowerBreakoutLevel;  // Breakout level inferiore
      stopPrice = NormalizeDouble(stopPrice, symbolDigits);

      Print("───────────────────────────────────────────────────────────────────");
      Print("  [STOP] Placing BUY STOP pending order");
      PrintFormat("  [STOP]   Stop Price: %.5f", stopPrice);
      PrintFormat("  [STOP]   Current Bid: %.5f", SymbolInfoDouble(_Symbol, SYMBOL_BID));
      PrintFormat("  [STOP]   Lot Size: %.2f", shieldLot);
      PrintFormat("  [STOP]   Magic: %d", shieldMagic);
      Print("───────────────────────────────────────────────────────────────────");

      if(trade.BuyStop(shieldLot, stopPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "SUGAMARA_SHIELD_LONG_STOP")) {
         shieldPendingTicket = trade.ResultOrder();
         shieldPendingType = SHIELD_LONG;
         shieldPendingPrice = stopPrice;
         shieldPendingLot = shieldLot;

         shield.phase = PHASE_PRE_SHIELD;
         currentSystemState = STATE_SHIELD_PENDING;
         success = true;

         Print("  ✅ [STOP] BUY STOP order PLACED");
         PrintFormat("     Pending Ticket: %d", shieldPendingTicket);
         PrintFormat("     Trigger Price: %.5f", stopPrice);
         PrintFormat("     Lot: %.2f", shieldLot);
         Print("     Waiting for price to hit stop level...");
      }
      else {
         Print("  ❌ [STOP] Pending order FAILED");
         PrintFormat("     Error Code: %d", trade.ResultRetcode());
         PrintFormat("     Description: %s", trade.ResultRetcodeDescription());
      }
   }

   Print("═══════════════════════════════════════════════════════════════════");

   if(success && EnableAlerts) {
      string orderTypeStr = (ShieldOrderType == SHIELD_ORDER_MARKET ? "MARKET" : "STOP PENDING");
      Alert("SUGAMARA: Shield LONG ", orderTypeStr, "! Breakout DOWN - Protection ",
            (ShieldOrderType == SHIELD_ORDER_MARKET ? "active" : "pending"));
   }
}

//+------------------------------------------------------------------+
//| Activate Shield SHORT (Breakout UP - protects SHORTs)             |
//+------------------------------------------------------------------+
void ActivateShieldShort(string source)
{
   Print("═══════════════════════════════════════════════════════════════════");
   Print("  ACTIVATING SHIELD SHORT");
   Print("═══════════════════════════════════════════════════════════════════");
   Print("  Source: ", source);
   Print("  Order Type: ", GetShieldOrderTypeName());

   double shieldLot = CalculateShieldLotSize(SHIELD_SHORT);
   int shieldMagic = MagicNumber + MAGIC_SHIELD_SHORT;
   trade.SetExpertMagicNumber(shieldMagic);

   bool success = false;

   //------------------------------------------------------------------
   // MARKET ORDER - Esecuzione immediata
   //------------------------------------------------------------------
   if(ShieldOrderType == SHIELD_ORDER_MARKET) {
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

      Print("───────────────────────────────────────────────────────────────────");
      Print("  [MARKET] Sending SELL order at market");
      PrintFormat("  [MARKET]   Bid Price: %.5f", currentPrice);
      PrintFormat("  [MARKET]   Lot Size: %.2f", shieldLot);
      PrintFormat("  [MARKET]   Magic: %d", shieldMagic);
      Print("───────────────────────────────────────────────────────────────────");

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
         success = true;

         Print("  ✅ [MARKET] Shield SHORT EXECUTED");
         PrintFormat("     Ticket: %d", shield.ticket);
         PrintFormat("     Executed Price: %.5f", shield.entry_price);
         PrintFormat("     Slippage: %.1f pips", MathAbs(shield.entry_price - currentPrice) / symbolPoint / 10);
         PrintFormat("     Lot: %.2f", shieldLot);
         PrintFormat("     Covering Long exposure: %.2f lots", totalLongLots);
      }
      else {
         Print("  ❌ [MARKET] Order FAILED");
         PrintFormat("     Error Code: %d", trade.ResultRetcode());
         PrintFormat("     Description: %s", trade.ResultRetcodeDescription());
      }
   }
   //------------------------------------------------------------------
   // STOP ORDER - Pending order al livello breakout
   //------------------------------------------------------------------
   else if(ShieldOrderType == SHIELD_ORDER_STOP) {
      double stopPrice = upperBreakoutLevel;  // Breakout level superiore
      stopPrice = NormalizeDouble(stopPrice, symbolDigits);

      Print("───────────────────────────────────────────────────────────────────");
      Print("  [STOP] Placing SELL STOP pending order");
      PrintFormat("  [STOP]   Stop Price: %.5f", stopPrice);
      PrintFormat("  [STOP]   Current Ask: %.5f", SymbolInfoDouble(_Symbol, SYMBOL_ASK));
      PrintFormat("  [STOP]   Lot Size: %.2f", shieldLot);
      PrintFormat("  [STOP]   Magic: %d", shieldMagic);
      Print("───────────────────────────────────────────────────────────────────");

      if(trade.SellStop(shieldLot, stopPrice, _Symbol, 0, 0, ORDER_TIME_GTC, 0, "SUGAMARA_SHIELD_SHORT_STOP")) {
         shieldPendingTicket = trade.ResultOrder();
         shieldPendingType = SHIELD_SHORT;
         shieldPendingPrice = stopPrice;
         shieldPendingLot = shieldLot;

         shield.phase = PHASE_PRE_SHIELD;
         currentSystemState = STATE_SHIELD_PENDING;
         success = true;

         Print("  ✅ [STOP] SELL STOP order PLACED");
         PrintFormat("     Pending Ticket: %d", shieldPendingTicket);
         PrintFormat("     Trigger Price: %.5f", stopPrice);
         PrintFormat("     Lot: %.2f", shieldLot);
         Print("     Waiting for price to hit stop level...");
      }
      else {
         Print("  ❌ [STOP] Pending order FAILED");
         PrintFormat("     Error Code: %d", trade.ResultRetcode());
         PrintFormat("     Description: %s", trade.ResultRetcodeDescription());
      }
   }

   Print("═══════════════════════════════════════════════════════════════════");

   if(success && EnableAlerts) {
      string orderTypeStr = (ShieldOrderType == SHIELD_ORDER_MARKET ? "MARKET" : "STOP PENDING");
      Alert("SUGAMARA: Shield SHORT ", orderTypeStr, "! Breakout UP - Protection ",
            (ShieldOrderType == SHIELD_ORDER_MARKET ? "active" : "pending"));
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
      if(DetailedLogging) {
         Print("[Shield] ManageActiveShield() - No active shield to manage");
      }
      return;
   }

   // Verify position still exists
   if(!PositionSelectByTicket(shield.ticket)) {
      Print("[Shield] Position not found - may have been closed by SL/TP");
      PrintFormat("[Shield]   Ticket: %d, Type: %s", shield.ticket, (shield.type == SHIELD_LONG ? "LONG" : "SHORT"));
      PrintFormat("[Shield]   Last known P/L: %.2f", shield.current_pl);
      ResetShield();
      return;
   }

   // Update current P/L
   double previousPL = shield.current_pl;
   shield.current_pl = PositionGetDouble(POSITION_PROFIT);
   double currentSL = PositionGetDouble(POSITION_SL);
   double currentTP = PositionGetDouble(POSITION_TP);

   if(DetailedLogging) {
      PrintFormat("[Shield] ManageActiveShield() - Ticket: %d, Type: %s",
                  shield.ticket, (shield.type == SHIELD_LONG ? "LONG" : "SHORT"));
      PrintFormat("[Shield]   Entry: %.5f, Current: %.5f", shield.entry_price, currentPrice);
      PrintFormat("[Shield]   P/L: %.2f (prev: %.2f), SL: %.5f", shield.current_pl, previousPL, currentSL);
      PrintFormat("[Shield]   Duration: %d sec", (int)(TimeCurrent() - shield.activation_time));
   }

   // Apply trailing if enabled
   if(Shield_Use_Trailing) {
      if(DetailedLogging) {
         Print("[Shield]   Checking trailing stop conditions...");
      }
      ApplyShieldTrailing(currentPrice);
   }

   // Check reentry condition
   bool reentryCondition = CheckReentryConditionShield(currentPrice);
   if(DetailedLogging) {
      PrintFormat("[Shield]   Reentry condition: %s", (reentryCondition ? "TRUE" : "FALSE"));
   }

   if(reentryCondition) {
      Print("[Shield] Reentry condition met - Closing shield");
      CloseShield("REENTRY");
   }
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop to Shield                                     |
//+------------------------------------------------------------------+
void ApplyShieldTrailing(double currentPrice)
{
   if(!PositionSelectByTicket(shield.ticket)) {
      if(DetailedLogging) {
         PrintFormat("[Shield] ApplyShieldTrailing() - Position %d not found", shield.ticket);
      }
      return;
   }

   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double trailingStart = PipsToPoints(Shield_Trailing_Start);
   double trailingStep = PipsToPoints(Shield_Trailing_Step);

   if(DetailedLogging) {
      PrintFormat("[Shield] ApplyShieldTrailing() - Open: %.5f, Current: %.5f, SL: %.5f",
                  openPrice, currentPrice, currentSL);
      PrintFormat("[Shield]   Trailing Start: %.5f, Step: %.5f", trailingStart, trailingStep);
   }

   if(shield.type == SHIELD_LONG) {
      // LONG: trailing SL upwards
      double profit = currentPrice - openPrice;
      if(DetailedLogging) {
         PrintFormat("[Shield]   LONG profit points: %.5f, Required: %.5f", profit, trailingStart);
      }

      if(profit >= trailingStart) {
         double newSL = NormalizeDouble(currentPrice - trailingStep, symbolDigits);
         if(DetailedLogging) {
            PrintFormat("[Shield]   Calculated new SL: %.5f, Current SL: %.5f", newSL, currentSL);
         }

         if(newSL > currentSL || currentSL == 0) {
            if(trade.PositionModify(shield.ticket, newSL, 0)) {
               shield.trailing_sl = newSL;
               PrintFormat("[Shield] Trailing SL UPDATED: %.5f -> %.5f (profit: %.5f)", currentSL, newSL, profit);
            } else {
               PrintFormat("[Shield] Trailing SL FAILED: Error %d - %s",
                          trade.ResultRetcode(), trade.ResultRetcodeDescription());
            }
         }
      }
   }
   else if(shield.type == SHIELD_SHORT) {
      // SHORT: trailing SL downwards
      double profit = openPrice - currentPrice;
      if(DetailedLogging) {
         PrintFormat("[Shield]   SHORT profit points: %.5f, Required: %.5f", profit, trailingStart);
      }

      if(profit >= trailingStart) {
         double newSL = NormalizeDouble(currentPrice + trailingStep, symbolDigits);
         if(DetailedLogging) {
            PrintFormat("[Shield]   Calculated new SL: %.5f, Current SL: %.5f", newSL, currentSL);
         }

         if(newSL < currentSL || currentSL == 0) {
            if(trade.PositionModify(shield.ticket, newSL, 0)) {
               shield.trailing_sl = newSL;
               PrintFormat("[Shield] Trailing SL UPDATED: %.5f -> %.5f (profit: %.5f)", currentSL, newSL, profit);
            } else {
               PrintFormat("[Shield] Trailing SL FAILED: Error %d - %s",
                          trade.ResultRetcode(), trade.ResultRetcodeDescription());
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
   // Save previous state for logging
   bool wasActive = shield.isActive;
   ENUM_SHIELD_TYPE prevType = shield.type;
   ulong prevTicket = shield.ticket;

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
   if(wasActive) {
      PrintFormat("[Shield]   Previous state: Type=%s, Ticket=%d",
                  (prevType == SHIELD_LONG ? "LONG" : "SHORT"), prevTicket);
   }
   PrintFormat("[Shield]   Total activations this session: %d", totalShieldActivations);
   PrintFormat("[Shield]   Total P/L this session: %.2f", totalShieldPL);
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

   // Shield funziona solo con CASCADE_OVERLAP mode
   if(!IsCascadeOverlapMode()) {
      if(DetailedLogging) {
         Print("[Shield] ProcessShield() skipped - Not in CASCADE_OVERLAP mode");
      }
      return;
   }

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
   Print("═══════════════════════════════════════════════════════════════════");
   Print("  SHIELD INTELLIGENT SYSTEM REPORT");
   Print("═══════════════════════════════════════════════════════════════════");
   PrintFormat("  Mode: %s", GetShieldModeName());
   PrintFormat("  Order Type: %s", GetShieldOrderTypeName());
   PrintFormat("  Available: %s", (IsShieldAvailable() ? "YES" : "NO"));
   PrintFormat("  Status: %s", GetShieldStatusString());
   PrintFormat("  Phase: %s", GetShieldPhaseString());
   Print("───────────────────────────────────────────────────────────────────");

   // Pending order info (for STOP order type)
   if(ShieldOrderType == SHIELD_ORDER_STOP && shieldPendingTicket > 0) {
      Print("  PENDING SHIELD ORDER:");
      PrintFormat("    Order Type: %s", (shieldPendingType == SHIELD_LONG ? "BUY STOP" : "SELL STOP"));
      PrintFormat("    Ticket: %d", shieldPendingTicket);
      PrintFormat("    Trigger Price: %.5f", shieldPendingPrice);
      PrintFormat("    Lot Size: %.2f", shieldPendingLot);
      double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double distancePips = MathAbs(currentPrice - shieldPendingPrice) / symbolPoint / 10;
      PrintFormat("    Distance to trigger: %.1f pips", distancePips);
      Print("───────────────────────────────────────────────────────────────────");
   }

   if(shield.isActive) {
      Print("  ACTIVE SHIELD:");
      PrintFormat("    Type: %s", (shield.type == SHIELD_LONG ? "LONG" : "SHORT"));
      PrintFormat("    Execution: %s", GetShieldOrderTypeName());
      PrintFormat("    Ticket: %d", shield.ticket);
      PrintFormat("    Lot Size: %.2f", shield.lot_size);
      PrintFormat("    Entry Price: %.5f", shield.entry_price);
      PrintFormat("    Current P/L: %.2f", shield.current_pl);
      PrintFormat("    Trailing SL: %.5f", shield.trailing_sl);
      PrintFormat("    Activation Time: %s", TimeToString(shield.activation_time, TIME_DATE|TIME_MINUTES));
      PrintFormat("    Duration: %d seconds", (int)(TimeCurrent() - shield.activation_time));
   } else {
      Print("  No active shield");
   }

   Print("───────────────────────────────────────────────────────────────────");
   Print("  SESSION STATISTICS:");
   PrintFormat("    Total Activations: %d", totalShieldActivations);
   PrintFormat("    Total P/L: %.2f", totalShieldPL);
   PrintFormat("    Activation Count (this shield): %d", shield.activation_count);
   Print("═══════════════════════════════════════════════════════════════════");
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
   Print("═══════════════════════════════════════════════════════════════════");
   Print("  DEINITIALIZING SHIELD SYSTEM");
   Print("═══════════════════════════════════════════════════════════════════");

   // Cancel pending STOP order if exists
   if(ShieldOrderType == SHIELD_ORDER_STOP && shieldPendingTicket > 0) {
      Print("  [STOP] Cancelling pending Shield order on deinit...");
      PrintFormat("  [STOP]   Ticket: %d", shieldPendingTicket);

      if(trade.OrderDelete(shieldPendingTicket)) {
         Print("  ✅ [STOP] Pending order cancelled");
      }
      else {
         Print("  ⚠️ [STOP] Failed to cancel pending order");
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

   Print("───────────────────────────────────────────────────────────────────");
   Print("  FINAL STATISTICS:");
   PrintFormat("    Order Type Used: %s", GetShieldOrderTypeName());
   PrintFormat("    Total Activations: %d", totalShieldActivations);
   PrintFormat("    Total Shield P/L: %.2f", totalShieldPL);
   Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Check if Shield is Available                                      |
//+------------------------------------------------------------------+
bool IsShieldAvailable()
{
   // v5.2: Shield now available for CASCADE_OVERLAP mode (RANGEBOX removed)
   return (IsCascadeOverlapMode() && ShieldMode != SHIELD_DISABLED);
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
