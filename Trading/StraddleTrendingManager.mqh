//+------------------------------------------------------------------+
//|                                    StraddleTrendingManager.mqh   |
//|                        SUGAMARA RIBELLE v9.0                     |
//|                     Straddle Trending Intelligente               |
//|                                                                  |
//|  Sistema COMPLETAMENTE ISOLATO da CASCADE                        |
//|  Magic Number: 20260101 (separato da CASCADE 20251205)           |
//|                                                                  |
//|  FIX INTEGRATI:                                                  |
//|  - FIX 1: GetStraddleDistance() usa Straddle_Spacing_Pips       |
//|  - FIX 2: StraddleState struct all'inizio file                  |
//|  - FIX 3: Filling type dinamico per broker                      |
//|  - FIX 5: Arrotondamento lot con lotStep broker                 |
//+------------------------------------------------------------------+
#property copyright "SUGAMARA RIBELLE v9.0"
#property version   "9.00"

//+------------------------------------------------------------------+
//| INCLUDES                                                          |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| FIX 2: STRUTTURA STATO STRADDLE (DEVE ESSERE ALL'INIZIO)         |
//+------------------------------------------------------------------+
struct StraddleState {
    bool        isActive;              // Straddle attivo?
    int         currentRound;          // Round corrente (1 = primo fill)
    bool        inCoverMode;           // In modalità copertura?
    double      entryPrice;            // Prezzo entry (centro)
    double      buyStopPrice;          // Prezzo BUY STOP
    double      sellStopPrice;         // Prezzo SELL STOP
    ulong       buyStopTicket;         // Ticket BUY STOP pending
    ulong       sellStopTicket;        // Ticket SELL STOP pending
    double      currentBuyLot;         // Lot corrente per BUY
    double      currentSellLot;        // Lot corrente per SELL
    double      totalBuyLot;           // Lot totale posizioni BUY
    double      totalSellLot;          // Lot totale posizioni SELL
    int         totalBuyPositions;     // Numero posizioni BUY
    int         totalSellPositions;    // Numero posizioni SELL
    datetime    lastCloseTime;         // Ultimo orario chiusura (per delay)
    ENUM_POSITION_TYPE lastFillType;   // Tipo ultimo fill (BUY o SELL)
};

//+------------------------------------------------------------------+
//| VARIABILI GLOBALI STRADDLE                                        |
//+------------------------------------------------------------------+
StraddleState straddle;
CTrade straddleTrade;

// Flag anti-doppio fill
bool g_straddleBuyJustFilled = false;
bool g_straddleSellJustFilled = false;

//+------------------------------------------------------------------+
//| INIZIALIZZAZIONE STRADDLE                                         |
//+------------------------------------------------------------------+
bool StraddleInit() {
    if(!Straddle_Enabled) {
        Log_InitConfig("Straddle", "DISABLED");
        return true;
    }

    if(!ValidateStraddleInputs()) {
        Log_InitFailed("Straddle", "input_validation");
        return false;
    }

    ZeroMemory(straddle);
    straddle.isActive = false;
    straddle.currentRound = 0;
    straddle.inCoverMode = false;
    straddle.lastCloseTime = 0;

    straddleTrade.SetExpertMagicNumber(Straddle_MagicNumber);
    straddleTrade.SetDeviationInPoints(30);

    ENUM_ORDER_TYPE_FILLING filling = ORDER_FILLING_FOK;
    long fillingMode = SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE);

    if((fillingMode & SYMBOL_FILLING_IOC) != 0) {
        filling = ORDER_FILLING_IOC;
    } else if((fillingMode & SYMBOL_FILLING_FOK) != 0) {
        filling = ORDER_FILLING_FOK;
    }
    straddleTrade.SetTypeFilling(filling);

    Log_InitConfig("Straddle.Magic", IntegerToString(Straddle_MagicNumber));
    Log_InitConfigNum("Straddle.Spacing", Straddle_Spacing_Pips);
    Log_InitConfigNum("Straddle.BaseLot", Straddle_BaseLot);
    Log_InitConfig("Straddle.Multiplier", (Straddle_LotMultiplier == STRADDLE_MULT_2X ? "2x" : "1.5x"));
    Log_InitComplete("Straddle");

    return true;
}

//+------------------------------------------------------------------+
//| VALIDAZIONE INPUT STRADDLE                                        |
//+------------------------------------------------------------------+
bool ValidateStraddleInputs() {
    if(Straddle_Spacing_Pips < 5.0) {
        Log_SystemError("Straddle", 0, "Spacing < 5 pips");
        return false;
    }
    if(Straddle_Spacing_Pips > 100.0) {
        Log_SystemError("Straddle", 0, "Spacing > 100 pips");
        return false;
    }
    if(Straddle_BaseLot < 0.01) {
        Log_SystemError("Straddle", 0, "BaseLot < 0.01");
        return false;
    }
    if(Straddle_MaxWhipsaw < 1 || Straddle_MaxWhipsaw > 10) {
        Log_SystemError("Straddle", 0, "MaxWhipsaw out of range 1-10");
        return false;
    }
    if(Straddle_MaxLot < Straddle_BaseLot) {
        Log_SystemError("Straddle", 0, "MaxLot < BaseLot");
        return false;
    }
    return true;
}

//+------------------------------------------------------------------+
//| RECOVER STRADDLE ORDERS FROM BROKER (v9.1)                       |
//| Chiamare dopo StraddleInit() in recovery mode                    |
//| Straddle usa magic 20260101 (hardcoded)                          |
//+------------------------------------------------------------------+
void RecoverStraddleOrdersFromBroker() {
    if(!Straddle_Enabled) return;

    long magicStraddle = Straddle_MagicNumber;  // 20260101

    // Cerca ordini pendenti Straddle
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;
        if(OrderGetInteger(ORDER_MAGIC) != magicStraddle) continue;

        ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
        double price = OrderGetDouble(ORDER_PRICE_OPEN);
        double lots = OrderGetDouble(ORDER_VOLUME_CURRENT);

        if(type == ORDER_TYPE_BUY_STOP) {
            straddle.buyStopTicket = ticket;
            straddle.buyStopPrice = price;
            straddle.currentBuyLot = lots;
        }
        else if(type == ORDER_TYPE_SELL_STOP) {
            straddle.sellStopTicket = ticket;
            straddle.sellStopPrice = price;
            straddle.currentSellLot = lots;
        }
    }

    // Cerca posizioni Straddle aperte
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(!PositionSelectByTicket(ticket)) continue;
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;
        if(PositionGetInteger(POSITION_MAGIC) != magicStraddle) continue;

        ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
        double lots = PositionGetDouble(POSITION_VOLUME);

        if(posType == POSITION_TYPE_BUY) {
            straddle.totalBuyPositions++;
            straddle.totalBuyLot += lots;
        } else {
            straddle.totalSellPositions++;
            straddle.totalSellLot += lots;
        }
    }

    bool hasOrders = (straddle.buyStopTicket > 0 || straddle.sellStopTicket > 0);
    bool hasPositions = (straddle.totalBuyPositions > 0 || straddle.totalSellPositions > 0);

    if(hasOrders || hasPositions) {
        straddle.isActive = true;
        straddle.currentRound = MathMax(straddle.totalBuyPositions, straddle.totalSellPositions);
        if(straddle.currentRound == 0 && hasOrders) straddle.currentRound = 0;

        Log_RecoveryComplete(
            (straddle.buyStopTicket > 0 ? 1 : 0) + (straddle.sellStopTicket > 0 ? 1 : 0),
            straddle.totalBuyPositions + straddle.totalSellPositions,
            straddle.entryPrice);
        Log_Debug("Straddle", StringFormat("Recovery round=%d buy_lot=%.2f sell_lot=%.2f",
                  straddle.currentRound, straddle.totalBuyLot, straddle.totalSellLot));
    }
}

//+------------------------------------------------------------------+
//| FIX 1: OTTIENI DISTANZA STRADDLE (usa input dedicato)            |
//+------------------------------------------------------------------+
double GetStraddleDistance() {
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);

    // Converti pips in price distance
    // Per coppie a 5 decimali (EUR/USD) o 3 decimali (USD/JPY)
    if(digits == 5 || digits == 3) {
        return Straddle_Spacing_Pips * point * 10.0;
    } else {
        return Straddle_Spacing_Pips * point;
    }
}

//+------------------------------------------------------------------+
//| FIX 5: NORMALIZZA LOT CON LOTSTEP BROKER                         |
//+------------------------------------------------------------------+
double NormalizeStraddleLot(double lot) {
    double minLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
    double maxLot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
    double lotStep = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);

    // Arrotonda per difetto al lotStep più vicino
    lot = MathFloor(lot / lotStep) * lotStep;

    // Applica limiti
    if(lot < minLot) lot = minLot;
    if(lot > maxLot) lot = maxLot;
    if(lot > Straddle_MaxLot) lot = Straddle_MaxLot;

    return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| ON TICK STRADDLE (chiamato da OnTick principale)                  |
//+------------------------------------------------------------------+
void StraddleOnTick() {
    if(!Straddle_Enabled) return;

    // Reset flag anti-doppio fill
    g_straddleBuyJustFilled = false;
    g_straddleSellJustFilled = false;

    // 1. Check EOD Close (priorità massima)
    if(CheckStraddleEOD()) return;

    // 2. Aggiorna stato posizioni
    UpdateStraddleState();

    // 3. Check se aprire nuovo Straddle
    if(!straddle.isActive && CanOpenNewStraddle()) {
        OpenNewStraddle();
        return;
    }

    // 4. Check ordini fillati (whipsaw detection)
    CheckStraddleOrderFills();

    // 5. Check Breakeven Exit (priorità su COP)
    if(Straddle_BE_Enabled && straddle.currentRound >= 2) {
        if(CheckStraddleBreakevenExit()) return;
    }

    // 6. Check COP Straddle
    if(Straddle_COP_Enabled) {
        if(CheckStraddleCOP()) return;
    }
}

//+------------------------------------------------------------------+
//| ON TRADE TRANSACTION STRADDLE                                     |
//| Rileva fill ordini in modo robusto                                |
//+------------------------------------------------------------------+
void OnStraddleTradeTransaction(const MqlTradeTransaction& trans,
                                const MqlTradeRequest& request,
                                const MqlTradeResult& result) {
    if(!Straddle_Enabled) return;
    if(trans.type != TRADE_TRANSACTION_DEAL_ADD) return;

    // Verifica se è un deal Straddle
    if(!HistoryDealSelect(trans.deal)) return;

    long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
    if(magic != Straddle_MagicNumber) return;

    string symbol = HistoryDealGetString(trans.deal, DEAL_SYMBOL);
    if(symbol != Symbol()) return;

    ENUM_DEAL_ENTRY entry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
    if(entry != DEAL_ENTRY_IN) return;  // Solo nuove posizioni

    ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(trans.deal, DEAL_TYPE);

    if(dealType == DEAL_TYPE_BUY && !g_straddleBuyJustFilled) {
        g_straddleBuyJustFilled = true;
        OnStraddleBuyFilled();
    }
    else if(dealType == DEAL_TYPE_SELL && !g_straddleSellJustFilled) {
        g_straddleSellJustFilled = true;
        OnStraddleSellFilled();
    }
}

//+------------------------------------------------------------------+
//| AGGIORNA STATO STRADDLE                                           |
//+------------------------------------------------------------------+
void UpdateStraddleState() {
    straddle.totalBuyLot = 0;
    straddle.totalSellLot = 0;
    straddle.totalBuyPositions = 0;
    straddle.totalSellPositions = 0;

    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;

        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
            if(PositionGetInteger(POSITION_MAGIC) != Straddle_MagicNumber) continue;

            double lot = PositionGetDouble(POSITION_VOLUME);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);

            if(type == POSITION_TYPE_BUY) {
                straddle.totalBuyLot += lot;
                straddle.totalBuyPositions++;
            } else {
                straddle.totalSellLot += lot;
                straddle.totalSellPositions++;
            }
        }
    }

    // Straddle attivo se ci sono posizioni O ordini pending
    straddle.isActive = (straddle.totalBuyPositions > 0 ||
                         straddle.totalSellPositions > 0 ||
                         HasStraddlePendingOrders());
}

//+------------------------------------------------------------------+
//| CHECK SE CI SONO ORDINI PENDING STRADDLE                          |
//+------------------------------------------------------------------+
bool HasStraddlePendingOrders() {
    for(int i = 0; i < OrdersTotal(); i++) {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;

        if(OrderSelect(ticket)) {
            if(OrderGetString(ORDER_SYMBOL) != Symbol()) continue;
            if(OrderGetInteger(ORDER_MAGIC) != Straddle_MagicNumber) continue;
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| PUÒ APRIRE NUOVO STRADDLE?                                        |
//+------------------------------------------------------------------+
bool CanOpenNewStraddle() {
    // Check delay dopo chiusura
    if(straddle.lastCloseTime > 0) {
        if((int)(TimeCurrent() - straddle.lastCloseTime) < Straddle_ReopenDelay) {
            return false;
        }
    }

    // Check se riapertura abilitata (dopo prima chiusura)
    if(straddle.lastCloseTime > 0 && !Straddle_ReopenAfterClose) {
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| APRI NUOVO STRADDLE                                               |
//+------------------------------------------------------------------+
void OpenNewStraddle() {
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);

    // Calcola centro (media bid/ask)
    double center = NormalizeDouble((ask + bid) / 2.0, digits);

    // FIX 1: Calcola distanza usando input dedicato
    double distance = GetStraddleDistance();

    // Calcola livelli
    double buyStopPrice = NormalizeDouble(center + distance, digits);
    double sellStopPrice = NormalizeDouble(center - distance, digits);

    // Calcola TP se abilitato
    double buyTP = 0, sellTP = 0;
    if(Straddle_UseTP && Straddle_TP_GridLevel > 1) {
        double tpDistance = distance * (Straddle_TP_GridLevel - 1);
        buyTP = NormalizeDouble(buyStopPrice + tpDistance, digits);
        sellTP = NormalizeDouble(sellStopPrice - tpDistance, digits);
    }

    // Normalizza lot
    double lot = NormalizeStraddleLot(Straddle_BaseLot);

    if(straddleTrade.BuyStop(lot, buyStopPrice, Symbol(), 0, buyTP,
                             ORDER_TIME_GTC, 0, "Straddle BUY R0")) {
        straddle.buyStopTicket = straddleTrade.ResultOrder();
        Log_OrderPlaced("STRADDLE", "UP", 0, "BUY_STOP", straddle.buyStopTicket, buyStopPrice, buyTP, 0, lot);
    } else {
        Log_SystemError("Straddle", GetLastError(), "BUY_STOP placement failed");
    }

    if(straddleTrade.SellStop(lot, sellStopPrice, Symbol(), 0, sellTP,
                              ORDER_TIME_GTC, 0, "Straddle SELL R0")) {
        straddle.sellStopTicket = straddleTrade.ResultOrder();
        Log_OrderPlaced("STRADDLE", "DN", 0, "SELL_STOP", straddle.sellStopTicket, sellStopPrice, sellTP, 0, lot);
    } else {
        Log_SystemError("Straddle", GetLastError(), "SELL_STOP placement failed");
    }

    straddle.isActive = true;
    straddle.currentRound = 0;
    straddle.inCoverMode = false;
    straddle.entryPrice = center;
    straddle.buyStopPrice = buyStopPrice;
    straddle.sellStopPrice = sellStopPrice;
    straddle.currentBuyLot = lot;
    straddle.currentSellLot = lot;

    double distancePips = distance / point;
    if(digits == 5 || digits == 3) distancePips /= 10.0;

    Log_StraddleOpened(center, distancePips, lot);
}

//+------------------------------------------------------------------+
//| CHECK ORDINI FILLATI (WHIPSAW DETECTION - BACKUP)                 |
//| Usato come backup se OnTradeTransaction non rileva               |
//+------------------------------------------------------------------+
void CheckStraddleOrderFills() {
    // Controlla se BUY STOP è stato fillato
    if(straddle.buyStopTicket > 0) {
        if(!OrderSelect(straddle.buyStopTicket)) {
            // L'ordine non esiste più come pending
            if(IsStraddlePositionOpen(POSITION_TYPE_BUY) && !g_straddleBuyJustFilled) {
                g_straddleBuyJustFilled = true;
                OnStraddleBuyFilled();
            }
            straddle.buyStopTicket = 0;
        }
    }

    // Controlla se SELL STOP è stato fillato
    if(straddle.sellStopTicket > 0) {
        if(!OrderSelect(straddle.sellStopTicket)) {
            if(IsStraddlePositionOpen(POSITION_TYPE_SELL) && !g_straddleSellJustFilled) {
                g_straddleSellJustFilled = true;
                OnStraddleSellFilled();
            }
            straddle.sellStopTicket = 0;
        }
    }
}

//+------------------------------------------------------------------+
//| CHECK SE POSIZIONE STRADDLE È APERTA                              |
//+------------------------------------------------------------------+
bool IsStraddlePositionOpen(ENUM_POSITION_TYPE type) {
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;

        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
            if(PositionGetInteger(POSITION_MAGIC) != Straddle_MagicNumber) continue;
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type) continue;
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| ON BUY FILLED                                                     |
//+------------------------------------------------------------------+
void OnStraddleBuyFilled() {
    straddle.currentRound++;
    straddle.lastFillType = POSITION_TYPE_BUY;

    Log_StraddleFilled("BUY", straddle.currentRound, straddle.buyStopPrice, straddle.currentBuyLot);

    if(straddle.inCoverMode) {
        Log_Debug("Straddle", "COVER BUY filled - hedge reached");
        return;
    }

    if(straddle.currentRound > Straddle_MaxWhipsaw) {
        EnterCoverMode();
        return;
    }

    double newLot = CalculateNextLot(straddle.currentSellLot);

    if(straddle.sellStopTicket > 0) {
        straddleTrade.OrderDelete(straddle.sellStopTicket);
        straddle.sellStopTicket = 0;
    }

    double sellTP = 0;
    if(Straddle_UseTP && Straddle_TP_GridLevel > 1) {
        double distance = GetStraddleDistance();
        double tpDistance = distance * (Straddle_TP_GridLevel - 1);
        sellTP = NormalizeDouble(straddle.sellStopPrice - tpDistance,
                                 (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
    }

    if(straddleTrade.SellStop(newLot, straddle.sellStopPrice, Symbol(), 0, sellTP,
                              ORDER_TIME_GTC, 0, "Straddle SELL R" + IntegerToString(straddle.currentRound))) {
        straddle.sellStopTicket = straddleTrade.ResultOrder();
        straddle.currentSellLot = newLot;
        Log_OrderPlaced("STRADDLE", "DN", straddle.currentRound, "SELL_STOP",
                       straddle.sellStopTicket, straddle.sellStopPrice, sellTP, 0, newLot);
    }
}

//+------------------------------------------------------------------+
//| ON SELL FILLED                                                    |
//+------------------------------------------------------------------+
void OnStraddleSellFilled() {
    straddle.currentRound++;
    straddle.lastFillType = POSITION_TYPE_SELL;

    Log_StraddleFilled("SELL", straddle.currentRound, straddle.sellStopPrice, straddle.currentSellLot);

    if(straddle.inCoverMode) {
        Log_Debug("Straddle", "COVER SELL filled - hedge reached");
        return;
    }

    if(straddle.currentRound > Straddle_MaxWhipsaw) {
        EnterCoverMode();
        return;
    }

    double newLot = CalculateNextLot(straddle.currentBuyLot);

    if(straddle.buyStopTicket > 0) {
        straddleTrade.OrderDelete(straddle.buyStopTicket);
        straddle.buyStopTicket = 0;
    }

    double buyTP = 0;
    if(Straddle_UseTP && Straddle_TP_GridLevel > 1) {
        double distance = GetStraddleDistance();
        double tpDistance = distance * (Straddle_TP_GridLevel - 1);
        buyTP = NormalizeDouble(straddle.buyStopPrice + tpDistance,
                                (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
    }

    if(straddleTrade.BuyStop(newLot, straddle.buyStopPrice, Symbol(), 0, buyTP,
                             ORDER_TIME_GTC, 0, "Straddle BUY R" + IntegerToString(straddle.currentRound))) {
        straddle.buyStopTicket = straddleTrade.ResultOrder();
        straddle.currentBuyLot = newLot;
        Log_OrderPlaced("STRADDLE", "UP", straddle.currentRound, "BUY_STOP",
                       straddle.buyStopTicket, straddle.buyStopPrice, buyTP, 0, newLot);
    }
}

//+------------------------------------------------------------------+
//| CALCOLA PROSSIMO LOT                                              |
//+------------------------------------------------------------------+
double CalculateNextLot(double currentLot) {
    double multiplier = (Straddle_LotMultiplier == STRADDLE_MULT_2X) ? 2.0 : 1.5;
    double newLot = currentLot * multiplier;

    newLot = NormalizeStraddleLot(newLot);

    if(newLot >= Straddle_MaxLot) {
        Log_Debug("Straddle", StringFormat("MaxLot reached: %.2f", Straddle_MaxLot));
    }

    return newLot;
}

//+------------------------------------------------------------------+
//| ENTRA IN COVER MODE                                               |
//+------------------------------------------------------------------+
void EnterCoverMode() {
    straddle.inCoverMode = true;

    Log_Debug("Straddle", StringFormat("COVER MODE - MaxWhipsaw=%d reached", Straddle_MaxWhipsaw));

    UpdateStraddleState();
    double straddleNetExposure = straddle.totalBuyLot - straddle.totalSellLot;

    if(MathAbs(straddleNetExposure) < 0.001) {
        Log_Debug("Straddle", "Already in perfect hedge");
        return;
    }

    double coverLot = NormalizeStraddleLot(MathAbs(straddleNetExposure));

    if(straddleNetExposure > 0) {
        if(straddleTrade.SellStop(coverLot, straddle.sellStopPrice, Symbol(), 0, 0,
                                  ORDER_TIME_GTC, 0, "Straddle COVER")) {
            straddle.sellStopTicket = straddleTrade.ResultOrder();
            Log_OrderPlaced("STRADDLE", "DN", 0, "SELL_STOP_COVER",
                           straddle.sellStopTicket, straddle.sellStopPrice, 0, 0, coverLot);
        }
    } else {
        if(straddleTrade.BuyStop(coverLot, straddle.buyStopPrice, Symbol(), 0, 0,
                                 ORDER_TIME_GTC, 0, "Straddle COVER")) {
            straddle.buyStopTicket = straddleTrade.ResultOrder();
            Log_OrderPlaced("STRADDLE", "UP", 0, "BUY_STOP_COVER",
                           straddle.buyStopTicket, straddle.buyStopPrice, 0, 0, coverLot);
        }
    }
}

//+------------------------------------------------------------------+
//| CALCOLA NET PROFIT STRADDLE                                       |
//+------------------------------------------------------------------+
double CalcStraddleNetProfit() {
    double netProfit = 0;

    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;

        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
            if(PositionGetInteger(POSITION_MAGIC) != Straddle_MagicNumber) continue;

            netProfit += PositionGetDouble(POSITION_PROFIT);
            netProfit += PositionGetDouble(POSITION_SWAP);
        }
    }

    return netProfit;
}

//+------------------------------------------------------------------+
//| CHECK COP STRADDLE                                                |
//+------------------------------------------------------------------+
bool CheckStraddleCOP() {
    if(!Straddle_COP_Enabled) return false;
    if(straddle.totalBuyPositions == 0 && straddle.totalSellPositions == 0) return false;

    double netProfit = CalcStraddleNetProfit();

    if(netProfit >= Straddle_COP_Target) {
        Log_COPTargetReached(netProfit, Straddle_COP_Target);
        CloseAllStraddlePositions("COP_TARGET");
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| CHECK BREAKEVEN EXIT                                              |
//+------------------------------------------------------------------+
bool CheckStraddleBreakevenExit() {
    if(!Straddle_BE_Enabled) return false;
    if(straddle.currentRound < 2) return false;
    if(straddle.totalBuyPositions == 0 && straddle.totalSellPositions == 0) return false;

    double netProfit = CalcStraddleNetProfit();

    if(netProfit >= -Straddle_BE_Buffer) {
        Log_Debug("Straddle", StringFormat("BE_EXIT profit=%.2f buffer=%.2f", netProfit, Straddle_BE_Buffer));
        CloseAllStraddlePositions("BE_EXIT");
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| CHECK EOD CLOSE                                                   |
//+------------------------------------------------------------------+
bool CheckStraddleEOD() {
    if(!Straddle_CloseEOD) return false;

    MqlDateTime dt;
    TimeToStruct(TimeGMT(), dt);

    if(Straddle_CloseFriday && dt.day_of_week == 5) {
        if(dt.hour >= Straddle_Friday_Hour) {
            if(straddle.isActive) {
                CloseAllStraddlePositions("FRIDAY_CLOSE");
                CancelAllStraddlePendingOrders();
            }
            return true;
        }
    }

    if(dt.hour >= Straddle_EOD_Hour) {
        if(straddle.isActive) {
            CloseAllStraddlePositions("EOD_CLOSE");
            CancelAllStraddlePendingOrders();
        }
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| CHIUDI TUTTE LE POSIZIONI STRADDLE                                |
//+------------------------------------------------------------------+
void CloseAllStraddlePositions(string reason) {
    int closed = 0;
    double totalProfit = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;

        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
            if(PositionGetInteger(POSITION_MAGIC) != Straddle_MagicNumber) continue;

            totalProfit += PositionGetDouble(POSITION_PROFIT);
            if(straddleTrade.PositionClose(ticket)) {
                closed++;
            }
        }
    }

    CancelAllStraddlePendingOrders();

    straddle.lastCloseTime = TimeCurrent();
    straddle.isActive = false;
    straddle.currentRound = 0;
    straddle.inCoverMode = false;
    straddle.buyStopTicket = 0;
    straddle.sellStopTicket = 0;

    Log_StraddleClosed(reason, totalProfit, closed);
}

//+------------------------------------------------------------------+
//| CANCELLA TUTTI GLI ORDINI PENDING STRADDLE                        |
//+------------------------------------------------------------------+
void CancelAllStraddlePendingOrders() {
    int cancelled = 0;

    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;

        if(OrderSelect(ticket)) {
            if(OrderGetString(ORDER_SYMBOL) != Symbol()) continue;
            if(OrderGetInteger(ORDER_MAGIC) != Straddle_MagicNumber) continue;

            if(straddleTrade.OrderDelete(ticket)) {
                Log_OrderCancelled(ticket, "STRADDLE_CLEANUP");
                cancelled++;
            }
        }
    }

    straddle.buyStopTicket = 0;
    straddle.sellStopTicket = 0;
}

//+------------------------------------------------------------------+
//| GET STRADDLE INFO (per Dashboard)                                 |
//+------------------------------------------------------------------+
string GetStraddleInfo() {
    if(!Straddle_Enabled) return "DISABILITATO";
    if(!straddle.isActive) return "INATTIVO";

    string info = "";
    info += StringFormat("R%d/%d | ", straddle.currentRound, Straddle_MaxWhipsaw);
    info += StringFormat("L:%.2f S:%.2f | ", straddle.totalBuyLot, straddle.totalSellLot);
    info += StringFormat("$%.2f", CalcStraddleNetProfit());

    if(straddle.inCoverMode) info += " [COVER]";

    return info;
}

//+------------------------------------------------------------------+
//| GET STRADDLE STATUS (per log dettagliato)                         |
//+------------------------------------------------------------------+
void LogStraddleStatus() {
    if(!Straddle_Enabled) return;

    Log_Header("STRADDLE STATUS");
    Log_KeyValue("Active", straddle.isActive ? "YES" : "NO");
    Log_KeyValueNum("Round", straddle.currentRound, 0);
    Log_KeyValueNum("MaxWhipsaw", Straddle_MaxWhipsaw, 0);
    Log_KeyValue("Cover Mode", straddle.inCoverMode ? "YES" : "NO");
    Log_KeyValueNum("BUY Positions", straddle.totalBuyPositions, 0);
    Log_KeyValueNum("BUY Lots", straddle.totalBuyLot, 2);
    Log_KeyValueNum("SELL Positions", straddle.totalSellPositions, 0);
    Log_KeyValueNum("SELL Lots", straddle.totalSellLot, 2);
    Log_KeyValueNum("Net Exposure", straddle.totalBuyLot - straddle.totalSellLot, 2);
    Log_KeyValueNum("Net Profit", CalcStraddleNetProfit(), 2);
    Log_Separator();
}

//+------------------------------------------------------------------+
//| DEINIT STRADDLE                                                   |
//+------------------------------------------------------------------+
void StraddleDeinit() {
    if(!Straddle_Enabled) return;

    if(straddle.isActive) {
        Log_Debug("Straddle", StringFormat("DEINIT active=true buy_pos=%d sell_pos=%d profit=%.2f",
                  straddle.totalBuyPositions, straddle.totalSellPositions, CalcStraddleNetProfit()));
    }
}
