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
        Print("[STRADDLE] Sistema DISABILITATO");
        return true;
    }

    // Validazione input
    if(!ValidateStraddleInputs()) {
        Print("[STRADDLE] ERRORE: Validazione input fallita");
        return false;
    }

    // Reset stato
    ZeroMemory(straddle);
    straddle.isActive = false;
    straddle.currentRound = 0;
    straddle.inCoverMode = false;
    straddle.lastCloseTime = 0;

    // Configura trade object con magic separato
    straddleTrade.SetExpertMagicNumber(Straddle_MagicNumber);
    straddleTrade.SetDeviationInPoints(30);

    // FIX 3: Filling type dinamico per broker
    ENUM_ORDER_TYPE_FILLING filling = ORDER_FILLING_FOK;  // Default sicuro
    long fillingMode = SymbolInfoInteger(Symbol(), SYMBOL_FILLING_MODE);

    if((fillingMode & SYMBOL_FILLING_IOC) != 0) {
        filling = ORDER_FILLING_IOC;
    } else if((fillingMode & SYMBOL_FILLING_FOK) != 0) {
        filling = ORDER_FILLING_FOK;
    }
    straddleTrade.SetTypeFilling(filling);

    // Log inizializzazione
    Print("");
    Print("=======================================================================");
    Print("  STRADDLE TRENDING INTELLIGENTE v6.0 - INIZIALIZZATO");
    Print("=======================================================================");
    PrintFormat("  Magic Number: %d (ISOLATO da CASCADE)", Straddle_MagicNumber);
    PrintFormat("  Spacing: %.1f pips", Straddle_Spacing_Pips);
    PrintFormat("  Base Lot: %.2f", Straddle_BaseLot);
    PrintFormat("  Multiplier: %s", Straddle_LotMultiplier == STRADDLE_MULT_2X ? "2x" : "1.5x");
    PrintFormat("  Max Whipsaw: %d", Straddle_MaxWhipsaw);
    PrintFormat("  Filling Mode: %s", EnumToString(filling));
    Print("=======================================================================");

    return true;
}

//+------------------------------------------------------------------+
//| VALIDAZIONE INPUT STRADDLE                                        |
//+------------------------------------------------------------------+
bool ValidateStraddleInputs() {
    if(Straddle_Spacing_Pips < 5.0) {
        Print("[STRADDLE] ERROR: Spacing troppo basso (< 5 pips)");
        return false;
    }
    if(Straddle_Spacing_Pips > 100.0) {
        Print("[STRADDLE] ERROR: Spacing troppo alto (> 100 pips)");
        return false;
    }
    if(Straddle_BaseLot < 0.01) {
        Print("[STRADDLE] ERROR: BaseLot troppo basso (< 0.01)");
        return false;
    }
    if(Straddle_MaxWhipsaw < 1 || Straddle_MaxWhipsaw > 10) {
        Print("[STRADDLE] ERROR: MaxWhipsaw deve essere 1-10");
        return false;
    }
    if(Straddle_MaxLot < Straddle_BaseLot) {
        Print("[STRADDLE] ERROR: MaxLot deve essere >= BaseLot");
        return false;
    }
    return true;
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

    // Piazza BUY STOP
    if(straddleTrade.BuyStop(lot, buyStopPrice, Symbol(), 0, buyTP,
                             ORDER_TIME_GTC, 0, "Straddle BUY R0")) {
        straddle.buyStopTicket = straddleTrade.ResultOrder();
        PrintFormat("[STRADDLE] BUY STOP piazzato @ %.5f, Lot: %.2f, TP: %.5f",
                    buyStopPrice, lot, buyTP);
    } else {
        PrintFormat("[STRADDLE] ERRORE BUY STOP: %d", GetLastError());
    }

    // Piazza SELL STOP
    if(straddleTrade.SellStop(lot, sellStopPrice, Symbol(), 0, sellTP,
                              ORDER_TIME_GTC, 0, "Straddle SELL R0")) {
        straddle.sellStopTicket = straddleTrade.ResultOrder();
        PrintFormat("[STRADDLE] SELL STOP piazzato @ %.5f, Lot: %.2f, TP: %.5f",
                    sellStopPrice, lot, sellTP);
    } else {
        PrintFormat("[STRADDLE] ERRORE SELL STOP: %d", GetLastError());
    }

    // Aggiorna stato
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

    PrintFormat("[STRADDLE] Nuovo Straddle aperto - Centro: %.5f, Distanza: %.1f pips",
                center, distancePips);
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

    PrintFormat("[STRADDLE] BUY FILLATO - Round: %d", straddle.currentRound);

    if(straddle.inCoverMode) {
        PrintFormat("[STRADDLE] COVER BUY fillato - Hedge raggiunto");
        return;
    }

    // Check se raggiunto max whipsaw
    if(straddle.currentRound > Straddle_MaxWhipsaw) {
        EnterCoverMode();
        return;
    }

    // Aumenta lot per prossimo SELL STOP
    double newLot = CalculateNextLot(straddle.currentSellLot);

    // Cancella vecchio SELL STOP se esiste
    if(straddle.sellStopTicket > 0) {
        straddleTrade.OrderDelete(straddle.sellStopTicket);
        straddle.sellStopTicket = 0;
    }

    // Piazza nuovo SELL STOP con lot aumentato
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
        PrintFormat("[STRADDLE] Nuovo SELL STOP @ %.5f, Lot: %.2f (Round %d)",
                    straddle.sellStopPrice, newLot, straddle.currentRound);
    }
}

//+------------------------------------------------------------------+
//| ON SELL FILLED                                                    |
//+------------------------------------------------------------------+
void OnStraddleSellFilled() {
    straddle.currentRound++;
    straddle.lastFillType = POSITION_TYPE_SELL;

    PrintFormat("[STRADDLE] SELL FILLATO - Round: %d", straddle.currentRound);

    if(straddle.inCoverMode) {
        PrintFormat("[STRADDLE] COVER SELL fillato - Hedge raggiunto");
        return;
    }

    if(straddle.currentRound > Straddle_MaxWhipsaw) {
        EnterCoverMode();
        return;
    }

    // Aumenta lot per prossimo BUY STOP
    double newLot = CalculateNextLot(straddle.currentBuyLot);

    // Cancella vecchio BUY STOP se esiste
    if(straddle.buyStopTicket > 0) {
        straddleTrade.OrderDelete(straddle.buyStopTicket);
        straddle.buyStopTicket = 0;
    }

    // Piazza nuovo BUY STOP con lot aumentato
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
        PrintFormat("[STRADDLE] Nuovo BUY STOP @ %.5f, Lot: %.2f (Round %d)",
                    straddle.buyStopPrice, newLot, straddle.currentRound);
    }
}

//+------------------------------------------------------------------+
//| CALCOLA PROSSIMO LOT                                              |
//+------------------------------------------------------------------+
double CalculateNextLot(double currentLot) {
    double multiplier = (Straddle_LotMultiplier == STRADDLE_MULT_2X) ? 2.0 : 1.5;
    double newLot = currentLot * multiplier;

    // FIX 5: Normalizza con lotStep broker
    newLot = NormalizeStraddleLot(newLot);

    if(newLot >= Straddle_MaxLot) {
        PrintFormat("[STRADDLE] Max Lot raggiunto: %.2f", Straddle_MaxLot);
    }

    return newLot;
}

//+------------------------------------------------------------------+
//| ENTRA IN COVER MODE                                               |
//+------------------------------------------------------------------+
void EnterCoverMode() {
    straddle.inCoverMode = true;

    PrintFormat("[STRADDLE] COVER MODE - Max Whipsaw raggiunto (%d)", Straddle_MaxWhipsaw);

    // Calcola esposizione netta
    UpdateStraddleState();
    double straddleNetExposure = straddle.totalBuyLot - straddle.totalSellLot;

    if(MathAbs(straddleNetExposure) < 0.001) {
        PrintFormat("[STRADDLE] Gia in hedge perfetto");
        return;
    }

    // FIX 5: Normalizza cover lot con lotStep
    double coverLot = NormalizeStraddleLot(MathAbs(straddleNetExposure));

    // Piazza ordine di copertura
    if(straddleNetExposure > 0) {
        // Long netto -> piazza SELL STOP per coprire
        if(straddleTrade.SellStop(coverLot, straddle.sellStopPrice, Symbol(), 0, 0,
                                  ORDER_TIME_GTC, 0, "Straddle COVER")) {
            straddle.sellStopTicket = straddleTrade.ResultOrder();
            PrintFormat("[STRADDLE] COVER SELL STOP @ %.5f, Lot: %.2f",
                        straddle.sellStopPrice, coverLot);
        }
    } else {
        // Short netto -> piazza BUY STOP per coprire
        if(straddleTrade.BuyStop(coverLot, straddle.buyStopPrice, Symbol(), 0, 0,
                                 ORDER_TIME_GTC, 0, "Straddle COVER")) {
            straddle.buyStopTicket = straddleTrade.ResultOrder();
            PrintFormat("[STRADDLE] COVER BUY STOP @ %.5f, Lot: %.2f",
                        straddle.buyStopPrice, coverLot);
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
        PrintFormat("[STRADDLE] COP TARGET RAGGIUNTO! NetProfit: $%.2f >= Target: $%.2f",
                    netProfit, Straddle_COP_Target);
        CloseAllStraddlePositions("COP Target");
        return true;
    }

    return false;
}

//+------------------------------------------------------------------+
//| CHECK BREAKEVEN EXIT                                              |
//+------------------------------------------------------------------+
bool CheckStraddleBreakevenExit() {
    if(!Straddle_BE_Enabled) return false;
    if(straddle.currentRound < 2) return false;  // Solo dopo almeno 1 whipsaw
    if(straddle.totalBuyPositions == 0 && straddle.totalSellPositions == 0) return false;

    double netProfit = CalcStraddleNetProfit();

    if(netProfit >= -Straddle_BE_Buffer) {
        PrintFormat("[STRADDLE] BREAKEVEN EXIT! NetProfit: $%.2f >= Buffer: -$%.2f",
                    netProfit, Straddle_BE_Buffer);
        CloseAllStraddlePositions("Breakeven Exit");
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

    // Venerdi anticipato
    if(Straddle_CloseFriday && dt.day_of_week == 5) {
        if(dt.hour >= Straddle_Friday_Hour) {
            if(straddle.isActive) {
                PrintFormat("[STRADDLE] Chiusura Venerdi anticipata - Ora: %d:00 GMT", dt.hour);
                CloseAllStraddlePositions("Friday Close");
                CancelAllStraddlePendingOrders();
            }
            return true;
        }
    }

    // EOD normale
    if(dt.hour >= Straddle_EOD_Hour) {
        if(straddle.isActive) {
            PrintFormat("[STRADDLE] Chiusura EOD - Ora: %d:00 GMT", dt.hour);
            CloseAllStraddlePositions("EOD Close");
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

    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;

        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
            if(PositionGetInteger(POSITION_MAGIC) != Straddle_MagicNumber) continue;

            if(straddleTrade.PositionClose(ticket)) {
                PrintFormat("[STRADDLE] Chiusa posizione #%d - Motivo: %s", ticket, reason);
                closed++;
            }
        }
    }

    // Cancella ordini pending
    CancelAllStraddlePendingOrders();

    // Reset stato
    straddle.lastCloseTime = TimeCurrent();
    straddle.isActive = false;
    straddle.currentRound = 0;
    straddle.inCoverMode = false;
    straddle.buyStopTicket = 0;
    straddle.sellStopTicket = 0;

    PrintFormat("[STRADDLE] Chiuse %d posizioni - Motivo: %s", closed, reason);
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
                cancelled++;
            }
        }
    }

    straddle.buyStopTicket = 0;
    straddle.sellStopTicket = 0;

    if(cancelled > 0) {
        PrintFormat("[STRADDLE] Cancellati %d ordini pending", cancelled);
    }
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

    Print("");
    Print("+-------------------------------------------------------------------+");
    Print("|  STRADDLE TRENDING STATUS                                        |");
    Print("+-------------------------------------------------------------------+");
    PrintFormat("|  Active: %s", straddle.isActive ? "YES" : "NO");
    PrintFormat("|  Round: %d / %d", straddle.currentRound, Straddle_MaxWhipsaw);
    PrintFormat("|  Cover Mode: %s", straddle.inCoverMode ? "YES" : "NO");
    PrintFormat("|  BUY Positions: %d (%.2f lot)", straddle.totalBuyPositions, straddle.totalBuyLot);
    PrintFormat("|  SELL Positions: %d (%.2f lot)", straddle.totalSellPositions, straddle.totalSellLot);
    PrintFormat("|  Net Exposure: %.2f lot", straddle.totalBuyLot - straddle.totalSellLot);
    PrintFormat("|  Net Profit: $%.2f", CalcStraddleNetProfit());
    Print("+-------------------------------------------------------------------+");
}

//+------------------------------------------------------------------+
//| DEINIT STRADDLE                                                   |
//+------------------------------------------------------------------+
void StraddleDeinit() {
    if(!Straddle_Enabled) return;

    Print("");
    Print("=======================================================================");
    Print("  STRADDLE TRENDING DEINIT");
    Print("=======================================================================");

    // Log stato finale
    if(straddle.isActive) {
        PrintFormat("  Posizioni BUY: %d (%.2f lot)", straddle.totalBuyPositions, straddle.totalBuyLot);
        PrintFormat("  Posizioni SELL: %d (%.2f lot)", straddle.totalSellPositions, straddle.totalSellLot);
        PrintFormat("  Net Profit: $%.2f", CalcStraddleNetProfit());
    }

    Print("  NOTA: Posizioni Straddle NON chiuse automaticamente");
    Print("=======================================================================");
}
