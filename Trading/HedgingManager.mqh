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
   if(!IsHedgingAvailable())
   {
      if(DetailedLogging)
         Print("[Hedge] Skip - Hedging not available in current mode");
      return true;  // Non è un errore
   }

   Print("[Hedge] Initializing Hedging Manager...");

   // Reset variabili
   currentHedgeDirection = HEDGE_NONE;
   hedgeLongTicket = 0;
   hedgeShortTicket = 0;
   hedgeLotSize = 0;
   hedgeOpenTime = 0;
   hedgeEntryPrice = 0;

   // Verifica se ci sono hedge esistenti da ripristinare
   ScanExistingHedgePositions();

   Print("[Hedge] Initialized. EnableHedging=", EnableHedging ? "YES" : "NO");

   return true;
}

//+------------------------------------------------------------------+
//| Scansiona posizioni hedge esistenti (recovery dopo restart)      |
//+------------------------------------------------------------------+
void ScanExistingHedgePositions()
{
   int totalPositions = PositionsTotal();

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

         PrintFormat("[Hedge] Recovered existing LONG hedge: ticket %d, lot %.2f",
                     hedgeLongTicket, hedgeLotSize);
      }
      else if(posMagic == MagicNumber + MAGIC_HEDGE_SHORT)
      {
         hedgeShortTicket = ticket;
         currentHedgeDirection = HEDGE_SHORT;
         hedgeLotSize = PositionGetDouble(POSITION_VOLUME);
         hedgeEntryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         hedgeOpenTime = (datetime)PositionGetInteger(POSITION_TIME);

         PrintFormat("[Hedge] Recovered existing SHORT hedge: ticket %d, lot %.2f",
                     hedgeShortTicket, hedgeLotSize);
      }
   }
}

//+------------------------------------------------------------------+
//| Calcola lot size per hedge                                       |
//+------------------------------------------------------------------+
double CalculateHedgeLotSize()
{
   // Hedge lot = Esposizione netta × Multiplier
   double lotSize = MathAbs(netExposure) * Hedge_Multiplier;

   // Minimo BaseLot
   if(lotSize < BaseLot)
      lotSize = BaseLot;

   // Normalizza
   lotSize = NormalizeLotSize(lotSize);

   // Max check
   if(lotSize > MaxLotPerLevel)
      lotSize = MaxLotPerLevel;

   return lotSize;
}

//+------------------------------------------------------------------+
//| Normalizza lot size secondo specifiche broker                    |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lot)
{
   if(symbolLotStep == 0)
      symbolLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   lot = MathRound(lot / symbolLotStep) * symbolLotStep;

   if(lot < symbolMinLot)
      lot = symbolMinLot;
   if(lot > symbolMaxLot)
      lot = symbolMaxLot;

   return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Apri posizione hedge                                             |
//+------------------------------------------------------------------+
bool OpenHedgePosition(ENUM_HEDGE_DIRECTION direction)
{
   if(!IsHedgingAvailable())
      return false;

   // Verifica se già c'è un hedge
   if(currentHedgeDirection != HEDGE_NONE)
   {
      PrintFormat("[Hedge] WARNING: Hedge already open (%s)",
                  currentHedgeDirection == HEDGE_LONG ? "LONG" : "SHORT");
      return false;
   }

   // Calcola lot size
   double lotSize = CalculateHedgeLotSize();

   // Prezzi
   double price, sl, tp;

   if(direction == HEDGE_LONG)
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      sl = price - Hedge_SL_Pips * symbolPoint * ((symbolDigits == 5 || symbolDigits == 3) ? 10 : 1);
      tp = price + Hedge_TP_Pips * symbolPoint * ((symbolDigits == 5 || symbolDigits == 3) ? 10 : 1);
   }
   else // HEDGE_SHORT
   {
      price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      sl = price + Hedge_SL_Pips * symbolPoint * ((symbolDigits == 5 || symbolDigits == 3) ? 10 : 1);
      tp = price - Hedge_TP_Pips * symbolPoint * ((symbolDigits == 5 || symbolDigits == 3) ? 10 : 1);
   }

   // Normalizza prezzi
   price = NormalizeDouble(price, symbolDigits);
   sl = NormalizeDouble(sl, symbolDigits);
   tp = NormalizeDouble(tp, symbolDigits);

   // Magic number per hedge
   int hedgeMagic = MagicNumber + (direction == HEDGE_LONG ? MAGIC_HEDGE_LONG : MAGIC_HEDGE_SHORT);

   // Configura trade
   trade.SetExpertMagicNumber(hedgeMagic);
   trade.SetDeviationInPoints(Slippage);

   // Commento ordine
   string comment = StringFormat("SUGAMARA_HEDGE_%s", direction == HEDGE_LONG ? "LONG" : "SHORT");

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

      if(direction == HEDGE_LONG)
         hedgeLongTicket = ticket;
      else
         hedgeShortTicket = ticket;

      currentHedgeDirection = direction;
      hedgeLotSize = lotSize;
      hedgeEntryPrice = price;
      hedgeOpenTime = TimeCurrent();

      LogMessage(LOG_SUCCESS, StringFormat(
         "[Hedge] Opened %s: ticket %d, lot %.2f, price %.5f, SL %.5f, TP %.5f",
         direction == HEDGE_LONG ? "LONG" : "SHORT",
         ticket, lotSize, price, sl, tp));

      return true;
   }
   else
   {
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
   if(currentHedgeDirection == HEDGE_NONE)
      return true;  // Niente da chiudere

   ulong ticket = (currentHedgeDirection == HEDGE_LONG) ? hedgeLongTicket : hedgeShortTicket;

   if(ticket == 0)
   {
      Print("[Hedge] WARNING: No ticket to close");
      ResetHedgeVariables();
      return false;
   }

   // Verifica che la posizione esista
   if(!PositionSelectByTicket(ticket))
   {
      PrintFormat("[Hedge] Position %d not found - already closed?", ticket);
      ResetHedgeVariables();
      return true;
   }

   // Chiudi posizione
   bool result = trade.PositionClose(ticket);

   if(result)
   {
      double closePrice = trade.ResultPrice();
      double profit = PositionGetDouble(POSITION_PROFIT);

      LogMessage(LOG_SUCCESS, StringFormat(
         "[Hedge] Closed %s: ticket %d, profit %.2f",
         currentHedgeDirection == HEDGE_LONG ? "LONG" : "SHORT",
         ticket, profit));

      ResetHedgeVariables();
      return true;
   }
   else
   {
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
   currentHedgeDirection = HEDGE_NONE;
   hedgeLongTicket = 0;
   hedgeShortTicket = 0;
   hedgeLotSize = 0;
   hedgeOpenTime = 0;
   hedgeEntryPrice = 0;
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

   // Verifica se la posizione è ancora aperta
   if(!PositionSelectByTicket(ticket))
   {
      // Posizione chiusa (probabilmente da TP/SL)
      PrintFormat("[Hedge] Position %d closed (TP/SL hit)", ticket);
      ResetHedgeVariables();
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
   if(hedgeLongTicket > 0)
   {
      if(PositionSelectByTicket(hedgeLongTicket))
         trade.PositionClose(hedgeLongTicket);
   }

   if(hedgeShortTicket > 0)
   {
      if(PositionSelectByTicket(hedgeShortTicket))
         trade.PositionClose(hedgeShortTicket);
   }

   ResetHedgeVariables();
   Print("[Hedge] All hedge positions closed");
}
