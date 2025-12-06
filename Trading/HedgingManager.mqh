//+------------------------------------------------------------------+
//|                                            HedgingManager.mqh    |
//|                        Sugamara v2.0 - Hedging Manager           |
//|                                                                  |
//|  Gestisce l'hedging per la modalità NEUTRAL_RANGEBOX             |
//|  - Apertura hedge su breakout                                    |
//|  - Chiusura hedge su rientro nel range                           |
//|  - Gestione TP/SL hedge                                          |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Magic Numbers per Hedge                                          |
//+------------------------------------------------------------------+
#define MAGIC_HEDGE_LONG   9001  // Base + 9001 = Hedge LONG
#define MAGIC_HEDGE_SHORT  9002  // Base + 9002 = Hedge SHORT

//+------------------------------------------------------------------+
//| Inizializza Hedging Manager (solo se NEUTRAL_RANGEBOX)           |
//+------------------------------------------------------------------+
bool InitializeHedgingManager()
{
   Print("═══════════════════════════════════════════════════════════════════");
   Print("  INITIALIZING HEDGING MANAGER");
   Print("═══════════════════════════════════════════════════════════════════");

   if(!IsHedgingAvailable())
   {
      Print("[Hedge] Skip - Hedging not available in current mode");
      PrintFormat("[Hedge]   Mode: %s, EnableHedging: %s",
                  EnumToString(NeutralMode), (EnableHedging ? "YES" : "NO"));
      return true;  // Non è un errore
   }

   Print("[Hedge] Initializing Hedging Manager...");
   PrintFormat("[Hedge]   Hedge Multiplier: %.2f", Hedge_Multiplier);
   PrintFormat("[Hedge]   Hedge TP: %.1f pips", Hedge_TP_Pips);
   PrintFormat("[Hedge]   Hedge SL: %.1f pips", Hedge_SL_Pips);

   // Reset variabili
   currentHedgeDirection = HEDGE_NONE;
   hedgeLongTicket = 0;
   hedgeShortTicket = 0;
   hedgeLotSize = 0;
   hedgeOpenTime = 0;
   hedgeEntryPrice = 0;

   Print("[Hedge] Variables reset to default");

   // Verifica se ci sono hedge esistenti da ripristinare
   ScanExistingHedgePositions();

   Print("[Hedge] Initialized. EnableHedging=", EnableHedging ? "YES" : "NO");
   Print("═══════════════════════════════════════════════════════════════════");

   return true;
}

//+------------------------------------------------------------------+
//| Scansiona posizioni hedge esistenti (recovery dopo restart)      |
//+------------------------------------------------------------------+
void ScanExistingHedgePositions()
{
   int totalPositions = PositionsTotal();
   int hedgesFound = 0;

   if(DetailedLogging) {
      PrintFormat("[Hedge] ScanExistingHedgePositions() - Scanning %d positions", totalPositions);
      PrintFormat("[Hedge]   Looking for Magic: %d (LONG) or %d (SHORT)",
                  MagicNumber + MAGIC_HEDGE_LONG, MagicNumber + MAGIC_HEDGE_SHORT);
   }

   for(int i = 0; i < totalPositions; i++)
   {
      ulong ticket = PositionGetTicket(i);
      if(ticket == 0) continue;

      // Verifica se è nostro (magic number)
      long posMagic = PositionGetInteger(POSITION_MAGIC);

      if(posMagic == MagicNumber + MAGIC_HEDGE_LONG)
      {
         hedgeLongTicket = ticket;
         currentHedgeDirection = HEDGE_LONG;
         hedgeLotSize = PositionGetDouble(POSITION_VOLUME);
         hedgeEntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         hedgeOpenTime = (datetime)PositionGetInteger(POSITION_TIME);
         hedgesFound++;

         Print("[Hedge] *** RECOVERED EXISTING LONG HEDGE ***");
         PrintFormat("[Hedge]   Ticket: %d", hedgeLongTicket);
         PrintFormat("[Hedge]   Lot Size: %.2f", hedgeLotSize);
         PrintFormat("[Hedge]   Entry Price: %.5f", hedgeEntryPrice);
         PrintFormat("[Hedge]   Open Time: %s", TimeToString(hedgeOpenTime, TIME_DATE|TIME_MINUTES));
         PrintFormat("[Hedge]   Current P/L: %.2f", PositionGetDouble(POSITION_PROFIT));
      }
      else if(posMagic == MagicNumber + MAGIC_HEDGE_SHORT)
      {
         hedgeShortTicket = ticket;
         currentHedgeDirection = HEDGE_SHORT;
         hedgeLotSize = PositionGetDouble(POSITION_VOLUME);
         hedgeEntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         hedgeOpenTime = (datetime)PositionGetInteger(POSITION_TIME);
         hedgesFound++;

         Print("[Hedge] *** RECOVERED EXISTING SHORT HEDGE ***");
         PrintFormat("[Hedge]   Ticket: %d", hedgeShortTicket);
         PrintFormat("[Hedge]   Lot Size: %.2f", hedgeLotSize);
         PrintFormat("[Hedge]   Entry Price: %.5f", hedgeEntryPrice);
         PrintFormat("[Hedge]   Open Time: %s", TimeToString(hedgeOpenTime, TIME_DATE|TIME_MINUTES));
         PrintFormat("[Hedge]   Current P/L: %.2f", PositionGetDouble(POSITION_PROFIT));
      }
   }

   if(hedgesFound == 0) {
      Print("[Hedge] No existing hedge positions found");
   } else {
      PrintFormat("[Hedge] Recovery complete: %d hedge(s) found", hedgesFound);
   }
}

//+------------------------------------------------------------------+
//| Calcola lot size per hedge                                       |
//+------------------------------------------------------------------+
double CalculateHedgeLotSize()
{
   if(DetailedLogging) {
      Print("[Hedge] CalculateHedgeLotSize() - Starting calculation");
      PrintFormat("[Hedge]   Net Exposure: %.4f lots", netExposure);
      PrintFormat("[Hedge]   Hedge Multiplier: %.2f", Hedge_Multiplier);
   }

   // Hedge lot = Esposizione netta × Multiplier
   double rawLot = MathAbs(netExposure) * Hedge_Multiplier;
   double lotSize = rawLot;

   if(DetailedLogging) {
      PrintFormat("[Hedge]   Raw calculation: |%.4f| × %.2f = %.4f", netExposure, Hedge_Multiplier, rawLot);
   }

   // Minimo BaseLot
   bool minApplied = false;
   if(lotSize < BaseLot) {
      lotSize = BaseLot;
      minApplied = true;
   }

   // Normalizza
   double beforeNorm = lotSize;
   lotSize = NormalizeLotSize(lotSize);

   // Max check
   bool maxApplied = false;
   if(lotSize > MaxLotPerLevel) {
      lotSize = MaxLotPerLevel;
      maxApplied = true;
   }

   if(DetailedLogging) {
      PrintFormat("[Hedge] Lot Calculation Summary:");
      PrintFormat("[Hedge]   Raw lot: %.4f", rawLot);
      PrintFormat("[Hedge]   Min lot applied (%.2f): %s", BaseLot, (minApplied ? "YES" : "NO"));
      PrintFormat("[Hedge]   After normalization: %.2f (was %.4f)", lotSize, beforeNorm);
      PrintFormat("[Hedge]   Max lot applied (%.2f): %s", MaxLotPerLevel, (maxApplied ? "YES" : "NO"));
      PrintFormat("[Hedge]   Final lot size: %.2f", lotSize);
   }

   return lotSize;
}

//+------------------------------------------------------------------+
//| NOTE: NormalizeLotSize() is defined in Core/BrokerValidation.mqh |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Apri posizione hedge                                             |
//+------------------------------------------------------------------+
bool OpenHedgePosition(ENUM_HEDGE_DIRECTION direction)
{
   Print("═══════════════════════════════════════════════════════════════════");
   PrintFormat("  OPENING HEDGE POSITION: %s", (direction == HEDGE_LONG ? "LONG" : "SHORT"));
   Print("═══════════════════════════════════════════════════════════════════");

   if(!IsHedgingAvailable()) {
      Print("[Hedge] FAILED: Hedging not available");
      PrintFormat("[Hedge]   Mode: %s, EnableHedging: %s",
                  EnumToString(NeutralMode), (EnableHedging ? "YES" : "NO"));
      return false;
   }

   // Verifica se già c'è un hedge
   if(currentHedgeDirection != HEDGE_NONE)
   {
      PrintFormat("[Hedge] WARNING: Hedge already open (%s)",
                  currentHedgeDirection == HEDGE_LONG ? "LONG" : "SHORT");
      PrintFormat("[Hedge]   Current ticket: %d",
                  (currentHedgeDirection == HEDGE_LONG ? hedgeLongTicket : hedgeShortTicket));
      return false;
   }

   // Calcola lot size
   double lotSize = CalculateHedgeLotSize();
   PrintFormat("[Hedge] Calculated lot size: %.2f", lotSize);

   // Prezzi
   double price, sl, tp;
   double pipValue = symbolPoint * ((symbolDigits == 5 || symbolDigits == 3) ? 10 : 1);

   if(direction == HEDGE_LONG)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = price - Hedge_SL_Pips * pipValue;
      tp = price + Hedge_TP_Pips * pipValue;
   }
   else // HEDGE_SHORT
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = price + Hedge_SL_Pips * pipValue;
      tp = price - Hedge_TP_Pips * pipValue;
   }

   // Normalizza prezzi
   price = NormalizeDouble(price, symbolDigits);
   sl = NormalizeDouble(sl, symbolDigits);
   tp = NormalizeDouble(tp, symbolDigits);

   PrintFormat("[Hedge] Price levels:");
   PrintFormat("[Hedge]   Entry: %.5f", price);
   PrintFormat("[Hedge]   SL: %.5f (%.1f pips)", sl, Hedge_SL_Pips);
   PrintFormat("[Hedge]   TP: %.5f (%.1f pips)", tp, Hedge_TP_Pips);

   // Magic number per hedge
   int hedgeMagic = MagicNumber + (direction == HEDGE_LONG ? MAGIC_HEDGE_LONG : MAGIC_HEDGE_SHORT);
   PrintFormat("[Hedge] Magic Number: %d", hedgeMagic);

   // Configura trade
   trade.SetExpertMagicNumber(hedgeMagic);
   trade.SetDeviationInPoints(Slippage);

   // Commento ordine
   string comment = StringFormat("SUGAMARA_HEDGE_%s", direction == HEDGE_LONG ? "LONG" : "SHORT");

   Print("[Hedge] Sending order to broker...");

   // Esegui ordine
   bool result;

   if(direction == HEDGE_LONG)
   {
      result = trade.Buy(lotSize, _Symbol, price, sl, tp, comment);
   }
   else
   {
      result = trade.Sell(lotSize, _Symbol, price, sl, tp, comment);
   }

   if(result)
   {
      ulong ticket = trade.ResultOrder();
      double executedPrice = trade.ResultPrice();

      if(direction == HEDGE_LONG)
         hedgeLongTicket = ticket;
      else
         hedgeShortTicket = ticket;

      currentHedgeDirection = direction;
      hedgeLotSize = lotSize;
      hedgeEntryPrice = executedPrice;
      hedgeOpenTime = TimeCurrent();

      Print("[Hedge] *** ORDER EXECUTED SUCCESSFULLY ***");
      PrintFormat("[Hedge]   Ticket: %d", ticket);
      PrintFormat("[Hedge]   Type: %s", (direction == HEDGE_LONG ? "BUY" : "SELL"));
      PrintFormat("[Hedge]   Lot Size: %.2f", lotSize);
      PrintFormat("[Hedge]   Executed Price: %.5f (requested: %.5f)", executedPrice, price);
      PrintFormat("[Hedge]   Slippage: %.1f pips", MathAbs(executedPrice - price) / pipValue);
      PrintFormat("[Hedge]   SL: %.5f, TP: %.5f", sl, tp);
      PrintFormat("[Hedge]   Time: %s", TimeToString(hedgeOpenTime, TIME_DATE|TIME_MINUTES|TIME_SECONDS));

      LogMessage(LOG_SUCCESS, StringFormat(
         "[Hedge] Opened %s: ticket %d, lot %.2f, price %.5f, SL %.5f, TP %.5f",
         direction == HEDGE_LONG ? "LONG" : "SHORT",
         ticket, lotSize, executedPrice, sl, tp));

      return true;
   }
   else
   {
      Print("[Hedge] *** ORDER FAILED ***");
      PrintFormat("[Hedge]   Error Code: %d", trade.ResultRetcode());
      PrintFormat("[Hedge]   Error Description: %s", trade.ResultRetcodeDescription());
      PrintFormat("[Hedge]   Requested: %s %.2f @ %.5f",
                  (direction == HEDGE_LONG ? "BUY" : "SELL"), lotSize, price);

      LogMessage(LOG_ERROR, StringFormat(
         "[Hedge] FAILED to open %s: error %d - %s",
         direction == HEDGE_LONG ? "LONG" : "SHORT",
         trade.ResultRetcode(), trade.ResultRetcodeDescription()));

      return false;
   }
}

//+------------------------------------------------------------------+
//| Chiudi posizione hedge                                           |
//+------------------------------------------------------------------+
bool CloseHedgePosition()
{
   Print("═══════════════════════════════════════════════════════════════════");
   Print("  CLOSING HEDGE POSITION");
   Print("═══════════════════════════════════════════════════════════════════");

   if(currentHedgeDirection == HEDGE_NONE) {
      Print("[Hedge] No hedge position to close");
      return true;  // Niente da chiudere
   }

   ulong ticket = (currentHedgeDirection == HEDGE_LONG) ? hedgeLongTicket : hedgeShortTicket;
   string hedgeType = (currentHedgeDirection == HEDGE_LONG) ? "LONG" : "SHORT";

   PrintFormat("[Hedge] Closing %s hedge, Ticket: %d", hedgeType, ticket);

   if(ticket == 0)
   {
      Print("[Hedge] WARNING: No ticket to close - resetting variables");
      ResetHedgeVariables();
      return false;
   }

   // Verifica che la posizione esista
   if(!PositionSelectByTicket(ticket))
   {
      PrintFormat("[Hedge] Position %d not found - already closed?", ticket);
      Print("[Hedge] Resetting hedge variables");
      ResetHedgeVariables();
      return true;
   }

   // Get position details before closing
   double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
   double profit = PositionGetDouble(POSITION_PROFIT);
   double lots = PositionGetDouble(POSITION_VOLUME);
   datetime openTime = (datetime)PositionGetInteger(POSITION_TIME);
   int duration = (int)(TimeCurrent() - openTime);

   PrintFormat("[Hedge] Position details:");
   PrintFormat("[Hedge]   Entry: %.5f", entryPrice);
   PrintFormat("[Hedge]   Current: %.5f", currentPrice);
   PrintFormat("[Hedge]   Lots: %.2f", lots);
   PrintFormat("[Hedge]   Unrealized P/L: %.2f", profit);
   PrintFormat("[Hedge]   Duration: %d seconds", duration);

   Print("[Hedge] Sending close request to broker...");

   // Chiudi posizione
   bool result = trade.PositionClose(ticket);

   if(result)
   {
      double closePrice = trade.ResultPrice();

      Print("[Hedge] *** POSITION CLOSED SUCCESSFULLY ***");
      PrintFormat("[Hedge]   Ticket: %d", ticket);
      PrintFormat("[Hedge]   Type: %s", hedgeType);
      PrintFormat("[Hedge]   Close Price: %.5f", closePrice);
      PrintFormat("[Hedge]   Realized P/L: %.2f", profit);
      PrintFormat("[Hedge]   Duration: %d seconds", duration);

      LogMessage(LOG_SUCCESS, StringFormat(
         "[Hedge] Closed %s: ticket %d, profit %.2f",
         hedgeType, ticket, profit));

      ResetHedgeVariables();
      return true;
   }
   else
   {
      Print("[Hedge] *** CLOSE FAILED ***");
      PrintFormat("[Hedge]   Error Code: %d", trade.ResultRetcode());
      PrintFormat("[Hedge]   Error Description: %s", trade.ResultRetcodeDescription());

      LogMessage(LOG_ERROR, StringFormat(
         "[Hedge] FAILED to close: error %d - %s",
         trade.ResultRetcode(), trade.ResultRetcodeDescription()));

      return false;
   }
}

//+------------------------------------------------------------------+
//| Reset variabili hedge                                            |
//+------------------------------------------------------------------+
void ResetHedgeVariables()
{
   // Save previous state for logging
   ENUM_HEDGE_DIRECTION prevDirection = currentHedgeDirection;
   ulong prevTicket = (currentHedgeDirection == HEDGE_LONG) ? hedgeLongTicket : hedgeShortTicket;
   double prevLot = hedgeLotSize;

   currentHedgeDirection = HEDGE_NONE;
   hedgeLongTicket = 0;
   hedgeShortTicket = 0;
   hedgeLotSize = 0;
   hedgeOpenTime = 0;
   hedgeEntryPrice = 0;

   if(DetailedLogging) {
      Print("[Hedge] ResetHedgeVariables() - Variables reset to default");
      if(prevDirection != HEDGE_NONE) {
         PrintFormat("[Hedge]   Previous state: %s, Ticket: %d, Lot: %.2f",
                     (prevDirection == HEDGE_LONG ? "LONG" : "SHORT"), prevTicket, prevLot);
      }
      Print("[Hedge]   All hedge variables cleared");
   }
}

//+------------------------------------------------------------------+
//| Monitora posizioni hedge (chiamato ogni tick)                    |
//+------------------------------------------------------------------+
void MonitorHedgePositions()
{
   if(!IsHedgingAvailable())
      return;

   if(currentHedgeDirection == HEDGE_NONE)
      return;

   ulong ticket = (currentHedgeDirection == HEDGE_LONG) ? hedgeLongTicket : hedgeShortTicket;
   string hedgeType = (currentHedgeDirection == HEDGE_LONG) ? "LONG" : "SHORT";

   // Verifica se la posizione è ancora aperta
   if(!PositionSelectByTicket(ticket))
   {
      // Posizione chiusa (probabilmente da TP/SL)
      Print("[Hedge] *** HEDGE POSITION CLOSED EXTERNALLY ***");
      PrintFormat("[Hedge]   Ticket: %d", ticket);
      PrintFormat("[Hedge]   Type: %s", hedgeType);
      PrintFormat("[Hedge]   Entry Price: %.5f", hedgeEntryPrice);
      PrintFormat("[Hedge]   Lot Size: %.2f", hedgeLotSize);
      PrintFormat("[Hedge]   Duration: %d seconds", (int)(TimeCurrent() - hedgeOpenTime));
      Print("[Hedge]   Reason: Likely TP or SL hit");

      ResetHedgeVariables();
   }
   else if(DetailedLogging)
   {
      // Position still open - log current status
      double profit = PositionGetDouble(POSITION_PROFIT);
      double currentPrice = PositionGetDouble(POSITION_PRICE_CURRENT);
      double sl = PositionGetDouble(POSITION_SL);
      double tp = PositionGetDouble(POSITION_TP);

      PrintFormat("[Hedge] Monitor: %s #%d - Price: %.5f, P/L: %.2f, SL: %.5f, TP: %.5f",
                  hedgeType, ticket, currentPrice, profit, sl, tp);
   }
}

//+------------------------------------------------------------------+
//| Restituisce profitto hedge corrente                              |
//+------------------------------------------------------------------+
double GetHedgeProfit()
{
   if(currentHedgeDirection == HEDGE_NONE)
      return 0;

   ulong ticket = (currentHedgeDirection == HEDGE_LONG) ? hedgeLongTicket : hedgeShortTicket;

   if(!PositionSelectByTicket(ticket))
      return 0;

   return PositionGetDouble(POSITION_PROFIT);
}

//+------------------------------------------------------------------+
//| Verifica se hedge è in profitto                                  |
//+------------------------------------------------------------------+
bool IsHedgeInProfit()
{
   return GetHedgeProfit() > 0;
}

//+------------------------------------------------------------------+
//| Log report Hedging                                               |
//+------------------------------------------------------------------+
void LogHedgeReport()
{
   if(!IsHedgingAvailable())
   {
      Print("[Hedge] Not available in current mode");
      return;
   }

   Print("═══════════════════════════════════════════════════════════════════");
   Print("  HEDGE REPORT");
   Print("═══════════════════════════════════════════════════════════════════");
   PrintFormat("  Hedging Enabled: %s", EnableHedging ? "YES" : "NO");
   PrintFormat("  Hedge Multiplier: %.2f", Hedge_Multiplier);
   PrintFormat("  Hedge TP: %.1f pips", Hedge_TP_Pips);
   PrintFormat("  Hedge SL: %.1f pips", Hedge_SL_Pips);
   Print("───────────────────────────────────────────────────────────────────");

   if(currentHedgeDirection == HEDGE_NONE)
   {
      Print("  Status: NO ACTIVE HEDGE");
   }
   else
   {
      PrintFormat("  Status: %s HEDGE ACTIVE",
                  currentHedgeDirection == HEDGE_LONG ? "LONG" : "SHORT");
      PrintFormat("  Ticket: %d", currentHedgeDirection == HEDGE_LONG ? hedgeLongTicket : hedgeShortTicket);
      PrintFormat("  Lot Size: %.2f", hedgeLotSize);
      PrintFormat("  Entry Price: %.5f", hedgeEntryPrice);
      PrintFormat("  Open Time: %s", TimeToString(hedgeOpenTime, TIME_DATE|TIME_MINUTES));
      PrintFormat("  Current Profit: %.2f", GetHedgeProfit());
   }

   Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Gestisce evento OnTradeTransaction per hedge                     |
//+------------------------------------------------------------------+
void OnHedgeTradeTransaction(const MqlTradeTransaction& trans,
                              const MqlTradeRequest& request,
                              const MqlTradeResult& result)
{
   if(!IsHedgingAvailable())
      return;

   // Monitora chiusure di posizioni hedge
   if(trans.type == TRADE_TRANSACTION_DEAL_ADD)
   {
      // Una deal è stata aggiunta - potrebbe essere chiusura hedge
      if(trans.deal > 0)
      {
         // Verifica se è una nostra posizione hedge
         if(HistoryDealSelect(trans.deal))
         {
            long dealMagic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);

            if(dealMagic == MagicNumber + MAGIC_HEDGE_LONG ||
               dealMagic == MagicNumber + MAGIC_HEDGE_SHORT)
            {
               ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);

               if(entry == DEAL_ENTRY_OUT || entry == DEAL_ENTRY_OUT_BY)
               {
                  double profit = HistoryDealGetDouble(trans.deal, DEAL_PROFIT);

                  LogMessage(LOG_INFO, StringFormat(
                     "[Hedge] Position closed by TP/SL - Profit: %.2f", profit));

                  ResetHedgeVariables();
               }
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Chiudi tutti gli hedge (emergency)                               |
//+------------------------------------------------------------------+
void CloseAllHedges()
{
   Print("═══════════════════════════════════════════════════════════════════");
   Print("  EMERGENCY: CLOSING ALL HEDGE POSITIONS");
   Print("═══════════════════════════════════════════════════════════════════");

   int closedCount = 0;
   double totalProfit = 0;

   if(hedgeLongTicket > 0)
   {
      PrintFormat("[Hedge] Closing LONG hedge, Ticket: %d", hedgeLongTicket);
      if(PositionSelectByTicket(hedgeLongTicket)) {
         double profit = PositionGetDouble(POSITION_PROFIT);
         if(trade.PositionClose(hedgeLongTicket)) {
            PrintFormat("[Hedge]   LONG hedge closed - P/L: %.2f", profit);
            totalProfit += profit;
            closedCount++;
         } else {
            PrintFormat("[Hedge]   FAILED to close LONG: %d - %s",
                        trade.ResultRetcode(), trade.ResultRetcodeDescription());
         }
      } else {
         Print("[Hedge]   LONG position not found (already closed?)");
      }
   }

   if(hedgeShortTicket > 0)
   {
      PrintFormat("[Hedge] Closing SHORT hedge, Ticket: %d", hedgeShortTicket);
      if(PositionSelectByTicket(hedgeShortTicket)) {
         double profit = PositionGetDouble(POSITION_PROFIT);
         if(trade.PositionClose(hedgeShortTicket)) {
            PrintFormat("[Hedge]   SHORT hedge closed - P/L: %.2f", profit);
            totalProfit += profit;
            closedCount++;
         } else {
            PrintFormat("[Hedge]   FAILED to close SHORT: %d - %s",
                        trade.ResultRetcode(), trade.ResultRetcodeDescription());
         }
      } else {
         Print("[Hedge]   SHORT position not found (already closed?)");
      }
   }

   ResetHedgeVariables();

   Print("───────────────────────────────────────────────────────────────────");
   PrintFormat("[Hedge] Emergency close complete: %d positions closed", closedCount);
   PrintFormat("[Hedge] Total P/L: %.2f", totalProfit);
   Print("═══════════════════════════════════════════════════════════════════");
}
