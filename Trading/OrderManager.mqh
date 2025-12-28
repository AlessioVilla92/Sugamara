//+------------------------------------------------------------------+
//|                                                OrderManager.mqh  |
//|                        Sugamara - Order Manager                  |
//|                                                                  |
//|  Handles all order/position operations with retry logic          |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

// NOTE: CTrade trade is already defined in GlobalVariables.mqh
// Do NOT redeclare it here to avoid multiple definition error

//+------------------------------------------------------------------+
//| INITIALIZATION                                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Order Manager                                         |
//+------------------------------------------------------------------+
bool InitializeOrderManager() {
    // Set slippage
    trade.SetDeviationInPoints(Slippage);

    // Set magic number (will be overridden per grid)
    trade.SetExpertMagicNumber(MagicNumber);

    // Set async mode off for reliable execution
    trade.SetAsyncMode(false);

    // Set type filling
    trade.SetTypeFilling(ORDER_FILLING_FOK);

    LogMessage(LOG_SUCCESS, "Order Manager initialized");
    return true;
}

//+------------------------------------------------------------------+
//| PENDING ORDER FUNCTIONS                                          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Place Pending Order with Retry Logic                             |
//+------------------------------------------------------------------+
ulong PlacePendingOrder(ENUM_ORDER_TYPE orderType, double lot, double price,
                        double sl, double tp, string comment, int magic) {

    // Normalize values
    price = NormalizeDouble(price, symbolDigits);
    sl = NormalizeDouble(sl, symbolDigits);
    tp = NormalizeDouble(tp, symbolDigits);
    lot = NormalizeLotSize(lot);

    // ═══════════════════════════════════════════════════════════════════
    // v5.10 FIX: Check price validity BEFORE attempting order
    // This prevents error 10015 from flooding the log
    // Cyclic reopen will automatically retry when price moves
    // ═══════════════════════════════════════════════════════════════════
    if(!IsValidPendingPrice(price, orderType)) {
        if(DetailedLogging) {
            Print("[OrderManager] Skipping ", GetOrderTypeString(orderType),
                  " @ ", FormatPrice(price), " - price not yet valid (cyclic reopen will retry)");
        }
        return 0;
    }

    // Set magic for this order
    trade.SetExpertMagicNumber(magic);

    int retries = 0;
    ulong ticket = 0;

    while(retries < MaxRetries) {
        bool result = false;

        // Refresh rates before each attempt
        if(!RefreshRates()) {
            LogMessage(LOG_WARNING, "Failed to refresh rates, retry " + IntegerToString(retries + 1));
            retries++;
            Sleep(RetryDelay_ms);
            continue;
        }

        // Execute order based on type
        switch(orderType) {
            case ORDER_TYPE_BUY_LIMIT:
                result = trade.BuyLimit(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
                break;

            case ORDER_TYPE_SELL_LIMIT:
                result = trade.SellLimit(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
                break;

            case ORDER_TYPE_BUY_STOP:
                result = trade.BuyStop(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
                break;

            case ORDER_TYPE_SELL_STOP:
                result = trade.SellStop(lot, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, comment);
                break;

            default:
                LogMessage(LOG_ERROR, "Invalid order type for pending: " + IntegerToString(orderType));
                return 0;
        }

        if(result) {
            ticket = trade.ResultOrder();
            if(ticket > 0) {
                if(DetailedLogging) {
                    LogMessage(LOG_SUCCESS, "Pending order placed: #" + IntegerToString(ticket) +
                               " " + GetOrderTypeString(orderType) + " " + DoubleToString(lot, 2) +
                               " @ " + FormatPrice(price));
                }
                return ticket;
            }
        }

        // Log error and retry
        uint errorCode = trade.ResultRetcode();
        string errorDesc = trade.ResultRetcodeDescription();
        LogMessage(LOG_WARNING, "Order failed: " + errorDesc + " (code " + IntegerToString(errorCode) +
                   "), retry " + IntegerToString(retries + 1));

        retries++;
        if(retries < MaxRetries) {
            Sleep(RetryDelay_ms);
        }
    }

    LogMessage(LOG_ERROR, "Failed to place pending order after " + IntegerToString(MaxRetries) + " retries");
    return 0;
}

//+------------------------------------------------------------------+
//| Delete Pending Order                                             |
//+------------------------------------------------------------------+
bool DeletePendingOrder(ulong ticket) {
    if(ticket == 0) return false;

    // Check if order exists
    if(!OrderSelect(ticket)) {
        // Order may have been filled or already deleted
        return true;
    }

    int retries = 0;

    while(retries < MaxRetries) {
        if(trade.OrderDelete(ticket)) {
            if(DetailedLogging) {
                LogMessage(LOG_SUCCESS, "Order deleted: #" + IntegerToString(ticket));
            }
            return true;
        }

        uint errorCode = trade.ResultRetcode();
        string errorDesc = trade.ResultRetcodeDescription();
        LogMessage(LOG_WARNING, "Delete failed: " + errorDesc + ", retry " + IntegerToString(retries + 1));

        retries++;
        if(retries < MaxRetries) {
            Sleep(RetryDelay_ms);
        }
    }

    LogMessage(LOG_ERROR, "Failed to delete order #" + IntegerToString(ticket));
    return false;
}

//+------------------------------------------------------------------+
//| Modify Pending Order                                             |
//+------------------------------------------------------------------+
bool ModifyPendingOrder(ulong ticket, double newPrice, double newSL, double newTP) {
    if(ticket == 0) return false;
    if(!OrderSelect(ticket)) return false;

    newPrice = NormalizeDouble(newPrice, symbolDigits);
    newSL = NormalizeDouble(newSL, symbolDigits);
    newTP = NormalizeDouble(newTP, symbolDigits);

    int retries = 0;

    while(retries < MaxRetries) {
        if(trade.OrderModify(ticket, newPrice, newSL, newTP, ORDER_TIME_GTC, 0)) {
            if(DetailedLogging) {
                LogMessage(LOG_SUCCESS, "Order modified: #" + IntegerToString(ticket));
            }
            return true;
        }

        uint errorCode = trade.ResultRetcode();
        LogMessage(LOG_WARNING, "Modify failed: " + trade.ResultRetcodeDescription() +
                   ", retry " + IntegerToString(retries + 1));

        retries++;
        if(retries < MaxRetries) {
            Sleep(RetryDelay_ms);
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| POSITION FUNCTIONS                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Close Position by Ticket                                         |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket) {
    if(ticket == 0) return false;

    if(!PositionSelectByTicket(ticket)) {
        // Position may already be closed
        return true;
    }

    int retries = 0;

    while(retries < MaxRetries) {
        if(trade.PositionClose(ticket, Slippage)) {
            if(DetailedLogging) {
                LogMessage(LOG_SUCCESS, "Position closed: #" + IntegerToString(ticket));
            }
            return true;
        }

        uint errorCode = trade.ResultRetcode();
        LogMessage(LOG_WARNING, "Close failed: " + trade.ResultRetcodeDescription() +
                   ", retry " + IntegerToString(retries + 1));

        retries++;
        if(retries < MaxRetries) {
            Sleep(RetryDelay_ms);
        }
    }

    LogMessage(LOG_ERROR, "Failed to close position #" + IntegerToString(ticket));
    return false;
}

//+------------------------------------------------------------------+
//| Close Position Partial - v5.2 Double Parcelling                  |
//| Chiude parzialmente una posizione e ritorna il nuovo ticket      |
//+------------------------------------------------------------------+
ulong ClosePositionPartial_AndTrack(ulong oldTicket, double lotsToClose,
                                     ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(oldTicket == 0) return 0;
    if(!PositionSelectByTicket(oldTicket)) return 0;

    // Salva info per trovare nuovo ticket
    double currentVolume = PositionGetDouble(POSITION_VOLUME);
    string symbol = PositionGetString(POSITION_SYMBOL);
    long magic = PositionGetInteger(POSITION_MAGIC);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    double expectedRemainingVolume = NormalizeDouble(currentVolume - lotsToClose, 2);

    // Verifica che ci sia abbastanza volume
    if(lotsToClose >= currentVolume) {
        LogMessage(LOG_WARNING, "[DP] Partial close: lotsToClose >= currentVolume, closing all");
        if(ClosePosition(oldTicket)) {
            return 0;  // Posizione completamente chiusa
        }
        return oldTicket;  // Fallito
    }

    // Esegui chiusura parziale usando OrderSend
    MqlTradeRequest request = {};
    MqlTradeResult result = {};

    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = NormalizeDouble(lotsToClose, 2);
    request.type = (posType == POSITION_TYPE_BUY) ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.position = oldTicket;  // CRITICO: specifica quale posizione chiudere
    request.price = (posType == POSITION_TYPE_BUY) ?
                    SymbolInfoDouble(symbol, SYMBOL_BID) :
                    SymbolInfoDouble(symbol, SYMBOL_ASK);
    request.deviation = Slippage;
    request.magic = magic;
    request.comment = "DP Partial Close";

    int retries = 0;
    while(retries < MaxRetries) {
        if(OrderSend(request, result)) {
            if(result.retcode == TRADE_RETCODE_DONE || result.retcode == TRADE_RETCODE_PLACED) {
                LogMessage(LOG_SUCCESS, "[DP] Partial close OK: " + DoubleToString(lotsToClose, 2) +
                           " lots from #" + IntegerToString(oldTicket));
                break;
            }
        }

        LogMessage(LOG_WARNING, "[DP] Partial close retry " + IntegerToString(retries+1) +
                   ": " + IntegerToString(result.retcode) + " - " + result.comment);
        retries++;
        if(retries < MaxRetries) {
            Sleep(RetryDelay_ms);
            // Aggiorna prezzo per il prossimo tentativo
            request.price = (posType == POSITION_TYPE_BUY) ?
                            SymbolInfoDouble(symbol, SYMBOL_BID) :
                            SymbolInfoDouble(symbol, SYMBOL_ASK);
        }
    }

    if(retries >= MaxRetries) {
        LogMessage(LOG_ERROR, "[DP] Partial close FAILED after " + IntegerToString(MaxRetries) + " retries");
        return oldTicket;  // Ritorna vecchio ticket (operazione fallita)
    }

    // Attendi che MT5 processi
    Sleep(100);

    // Cerca il nuovo ticket
    ulong newTicket = FindNewTicketAfterPartialClose(symbol, magic, posType, expectedRemainingVolume);

    if(newTicket > 0 && newTicket != oldTicket) {
        LogMessage(LOG_INFO, "[DP] New ticket found: #" + IntegerToString(newTicket) +
                   " (remaining: " + DoubleToString(expectedRemainingVolume, 2) + " lots)");

        // CRITICO: Aggiorna il ticket nell'array della grid!
        UpdateGridTicket(side, zone, level, newTicket);

        return newTicket;
    }

    // Verifica se la posizione originale esiste ancora
    if(PositionSelectByTicket(oldTicket)) {
        double remainingVol = PositionGetDouble(POSITION_VOLUME);
        if(MathAbs(remainingVol - expectedRemainingVolume) < 0.001) {
            LogMessage(LOG_INFO, "[DP] Position still exists with same ticket: #" + IntegerToString(oldTicket));
            return oldTicket;  // Alcuni broker mantengono lo stesso ticket
        }
    }

    LogMessage(LOG_WARNING, "[DP] Could not find new ticket - position may be fully closed");
    return 0;
}

//+------------------------------------------------------------------+
//| Find New Ticket After Partial Close                              |
//+------------------------------------------------------------------+
ulong FindNewTicketAfterPartialClose(string symbol, long magic,
                                      ENUM_POSITION_TYPE posType, double expectedVolume) {
    // Cerca nelle posizioni aperte quella con parametri corrispondenti
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && PositionSelectByTicket(ticket)) {
            // Verifica corrispondenza completa
            if(PositionGetString(POSITION_SYMBOL) != symbol) continue;
            if(PositionGetInteger(POSITION_MAGIC) != magic) continue;
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != posType) continue;

            // Verifica volume (con tolleranza)
            double volume = PositionGetDouble(POSITION_VOLUME);
            if(MathAbs(volume - expectedVolume) < 0.001) {
                return ticket;
            }
        }
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Update Grid Ticket After Partial Close                           |
//+------------------------------------------------------------------+
void UpdateGridTicket(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, ulong newTicket) {
    if(side == GRID_A) {
        if(zone == ZONE_UPPER) {
            gridA_Upper_Tickets[level] = newTicket;
        } else {
            gridA_Lower_Tickets[level] = newTicket;
        }
    } else {
        if(zone == ZONE_UPPER) {
            gridB_Upper_Tickets[level] = newTicket;
        } else {
            gridB_Lower_Tickets[level] = newTicket;
        }
    }

    string gridStr = (side == GRID_A) ? "A" : "B";
    string zoneStr = (zone == ZONE_UPPER) ? "Upper" : "Lower";

    LogMessage(LOG_INFO, "[DP] Grid ticket updated: " + gridStr + "-" + zoneStr +
               " L" + IntegerToString(level+1) +
               " → #" + IntegerToString(newTicket));
}

//+------------------------------------------------------------------+
//| Modify Position SL/TP                                            |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double newSL, double newTP) {
    if(ticket == 0) return false;
    if(!PositionSelectByTicket(ticket)) return false;

    newSL = NormalizeDouble(newSL, symbolDigits);
    newTP = NormalizeDouble(newTP, symbolDigits);

    int retries = 0;

    while(retries < MaxRetries) {
        if(trade.PositionModify(ticket, newSL, newTP)) {
            if(DetailedLogging) {
                LogMessage(LOG_SUCCESS, "Position modified: #" + IntegerToString(ticket));
            }
            return true;
        }

        uint errorCode = trade.ResultRetcode();
        LogMessage(LOG_WARNING, "Position modify failed: " + trade.ResultRetcodeDescription() +
                   ", retry " + IntegerToString(retries + 1));

        retries++;
        if(retries < MaxRetries) {
            Sleep(RetryDelay_ms);
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| MARKET ORDER FUNCTIONS                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Place Market Buy Order                                           |
//+------------------------------------------------------------------+
ulong PlaceMarketBuy(double lot, double sl, double tp, string comment, int magic) {
    lot = NormalizeLotSize(lot);
    sl = NormalizeDouble(sl, symbolDigits);
    tp = NormalizeDouble(tp, symbolDigits);

    trade.SetExpertMagicNumber(magic);

    int retries = 0;

    while(retries < MaxRetries) {
        if(!RefreshRates()) {
            retries++;
            Sleep(RetryDelay_ms);
            continue;
        }

        if(trade.Buy(lot, _Symbol, 0, sl, tp, comment)) {
            ulong ticket = trade.ResultOrder();
            if(ticket > 0) {
                if(DetailedLogging) {
                    LogMessage(LOG_SUCCESS, "Market Buy: #" + IntegerToString(ticket) +
                               " " + DoubleToString(lot, 2) + " lot");
                }
                return ticket;
            }
        }

        LogMessage(LOG_WARNING, "Market Buy failed: " + trade.ResultRetcodeDescription() +
                   ", retry " + IntegerToString(retries + 1));

        retries++;
        if(retries < MaxRetries) {
            Sleep(RetryDelay_ms);
        }
    }

    return 0;
}

//+------------------------------------------------------------------+
//| Place Market Sell Order                                          |
//+------------------------------------------------------------------+
ulong PlaceMarketSell(double lot, double sl, double tp, string comment, int magic) {
    lot = NormalizeLotSize(lot);
    sl = NormalizeDouble(sl, symbolDigits);
    tp = NormalizeDouble(tp, symbolDigits);

    trade.SetExpertMagicNumber(magic);

    int retries = 0;

    while(retries < MaxRetries) {
        if(!RefreshRates()) {
            retries++;
            Sleep(RetryDelay_ms);
            continue;
        }

        if(trade.Sell(lot, _Symbol, 0, sl, tp, comment)) {
            ulong ticket = trade.ResultOrder();
            if(ticket > 0) {
                if(DetailedLogging) {
                    LogMessage(LOG_SUCCESS, "Market Sell: #" + IntegerToString(ticket) +
                               " " + DoubleToString(lot, 2) + " lot");
                }
                return ticket;
            }
        }

        LogMessage(LOG_WARNING, "Market Sell failed: " + trade.ResultRetcodeDescription() +
                   ", retry " + IntegerToString(retries + 1));

        retries++;
        if(retries < MaxRetries) {
            Sleep(RetryDelay_ms);
        }
    }

    return 0;
}

//+------------------------------------------------------------------+
//| BATCH OPERATIONS                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Close All Positions by Magic                                     |
//+------------------------------------------------------------------+
int CloseAllPositionsByMagic(int magic) {
    int closed = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == magic &&
               PositionGetString(POSITION_SYMBOL) == _Symbol) {

                if(ClosePosition(ticket)) {
                    closed++;
                }
            }
        }
    }

    return closed;
}

//+------------------------------------------------------------------+
//| Delete All Pending Orders by Magic                               |
//+------------------------------------------------------------------+
int DeleteAllOrdersByMagic(int magic) {
    int deleted = 0;

    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(OrderSelect(ticket)) {
            if(OrderGetInteger(ORDER_MAGIC) == magic &&
               OrderGetString(ORDER_SYMBOL) == _Symbol) {

                if(DeletePendingOrder(ticket)) {
                    deleted++;
                }
            }
        }
    }

    return deleted;
}

//+------------------------------------------------------------------+
//| Close All Grid A (Positions + Orders)                            |
//+------------------------------------------------------------------+
void CloseAllGridAOrders() {
    int magic = GetGridMagic(GRID_A);

    int positions = CloseAllPositionsByMagic(magic);
    int orders = DeleteAllOrdersByMagic(magic);

    LogMessage(LOG_INFO, "Grid A closed: " + IntegerToString(positions) +
               " positions, " + IntegerToString(orders) + " orders");
}

//+------------------------------------------------------------------+
//| Close All Grid B (Positions + Orders)                            |
//+------------------------------------------------------------------+
void CloseAllGridBOrders() {
    int magic = GetGridMagic(GRID_B);

    int positions = CloseAllPositionsByMagic(magic);
    int orders = DeleteAllOrdersByMagic(magic);

    LogMessage(LOG_INFO, "Grid B closed: " + IntegerToString(positions) +
               " positions, " + IntegerToString(orders) + " orders");
}

//+------------------------------------------------------------------+
//| Close All Sugamara Orders (Both Grids)                           |
//+------------------------------------------------------------------+
void CloseAllSugamaraOrders() {
    LogMessage(LOG_WARNING, "EMERGENCY: Closing ALL orders and positions...");

    CloseAllGridAOrders();
    CloseAllGridBOrders();

    LogMessage(LOG_INFO, "All Sugamara orders closed");
}

//+------------------------------------------------------------------+
//| UTILITY FUNCTIONS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Refresh Symbol Rates                                             |
//+------------------------------------------------------------------+
bool RefreshRates() {
    MqlTick tick;
    if(!SymbolInfoTick(_Symbol, tick)) {
        return false;
    }
    return (tick.ask > 0 && tick.bid > 0);
}

//+------------------------------------------------------------------+
//| Get Historical Order Profit                                      |
//+------------------------------------------------------------------+
double GetHistoricalOrderProfit(ulong ticket) {
    // Select deal from history
    datetime fromDate = TimeCurrent() - 86400 * 30;  // Last 30 days
    datetime toDate = TimeCurrent();

    if(!HistorySelect(fromDate, toDate)) {
        return 0;
    }

    // Search for deals with this ticket
    int totalDeals = HistoryDealsTotal();
    double profit = 0;

    for(int i = totalDeals - 1; i >= 0; i--) {
        ulong dealTicket = HistoryDealGetTicket(i);
        if(HistoryDealGetInteger(dealTicket, DEAL_POSITION_ID) == ticket ||
           HistoryDealGetInteger(dealTicket, DEAL_ORDER) == ticket) {

            profit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT);
            profit += HistoryDealGetDouble(dealTicket, DEAL_SWAP);
            profit += HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
        }
    }

    return profit;
}

//+------------------------------------------------------------------+
//| Get Last Order Error Code                                        |
//+------------------------------------------------------------------+
uint GetLastOrderError() {
    return trade.ResultRetcode();
}

//+------------------------------------------------------------------+
//| Get Last Order Error Description                                 |
//+------------------------------------------------------------------+
string GetLastOrderErrorDescription() {
    return trade.ResultRetcodeDescription();
}

//+------------------------------------------------------------------+
//| Check if Order Operation is Safe                                 |
//+------------------------------------------------------------------+
bool IsOrderOperationSafe() {
    // Check margin
    double freeMargin = GetFreeMargin();
    if(freeMargin < 100) {
        LogMessage(LOG_WARNING, "Low free margin: " + FormatMoney(freeMargin));
        return false;
    }

    // Check spread
    double spreadPips = GetSpreadPips();
    if(spreadPips > 10) {
        LogMessage(LOG_WARNING, "High spread: " + DoubleToString(spreadPips, 1) + " pips");
        return false;
    }

    // Check if trading is allowed
    if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)) {
        LogMessage(LOG_WARNING, "Trading not allowed by terminal");
        return false;
    }

    if(!MQLInfoInteger(MQL_TRADE_ALLOWED)) {
        LogMessage(LOG_WARNING, "Trading not allowed for EA");
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| EMERGENCY OPERATIONS                                             |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Emergency Close All (No Retries, Fastest Execution)              |
//+------------------------------------------------------------------+
void EmergencyCloseAll() {
    Print("!!! EMERGENCY CLOSE ALL !!!");

    trade.SetAsyncMode(true);  // Fast async mode

    // Close positions first
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            long magic = PositionGetInteger(POSITION_MAGIC);
            if(magic >= MagicNumber && magic <= MagicNumber + MAGIC_OFFSET_GRID_B + 1000) {
                trade.PositionClose(ticket);
            }
        }
    }

    // Delete pending orders
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(OrderSelect(ticket)) {
            long magic = OrderGetInteger(ORDER_MAGIC);
            if(magic >= MagicNumber && magic <= MagicNumber + MAGIC_OFFSET_GRID_B + 1000) {
                trade.OrderDelete(ticket);
            }
        }
    }

    trade.SetAsyncMode(false);  // Back to sync mode

    Print("!!! EMERGENCY CLOSE COMPLETE !!!");
}

