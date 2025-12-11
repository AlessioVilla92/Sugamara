//+------------------------------------------------------------------+
//|                                                   Helpers.mqh    |
//|                        Sugamara - Helper Functions               |
//|                                                                  |
//|  Common utility functions for Double Grid Neutral                |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| PRICE CONVERSION FUNCTIONS                                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Convert Points to Pips                                           |
//| Handles both 4-digit and 5-digit brokers                         |
//+------------------------------------------------------------------+
double PointsToPips(double points) {
    if(symbolDigits == 3 || symbolDigits == 5) {
        return points / (10 * symbolPoint);
    } else {
        return points / symbolPoint;
    }
}

//+------------------------------------------------------------------+
//| Convert Pips to Points                                           |
//+------------------------------------------------------------------+
double PipsToPoints(double pips) {
    if(symbolDigits == 3 || symbolDigits == 5) {
        return pips * 10 * symbolPoint;
    } else {
        return pips * symbolPoint;
    }
}

//+------------------------------------------------------------------+
//| Convert Points to Price Distance                                 |
//+------------------------------------------------------------------+
double PointsToPrice(int points) {
    return points * symbolPoint;
}

//+------------------------------------------------------------------+
//| Convert Price Distance to Points                                 |
//+------------------------------------------------------------------+
int PriceToPoints(double price) {
    if(symbolPoint > 0) {
        return (int)MathRound(price / symbolPoint);
    }
    return 0;
}

//+------------------------------------------------------------------+
//| Get Current Spread in Pips                                       |
//+------------------------------------------------------------------+
double GetSpreadPips() {
    double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    return PointsToPips(ask - bid);
}

//+------------------------------------------------------------------+
//| TIME & DATE FUNCTIONS                                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if New Day Started                                         |
//+------------------------------------------------------------------+
bool IsNewDay() {
    static datetime lastDay = 0;
    datetime currentDay = StringToTime(TimeToString(TimeCurrent(), TIME_DATE));

    if(currentDay != lastDay) {
        lastDay = currentDay;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Check if New Hour Started                                        |
//+------------------------------------------------------------------+
bool IsNewHour() {
    static int lastHour = -1;
    MqlDateTime dt;
    TimeCurrent(dt);

    if(dt.hour != lastHour) {
        lastHour = dt.hour;
        return true;
    }
    return false;
}

//+------------------------------------------------------------------+
//| Get Hours Elapsed Since Datetime                                 |
//+------------------------------------------------------------------+
double HoursElapsed(datetime startTime) {
    if(startTime == 0) return 0;
    return (double)(TimeCurrent() - startTime) / 3600.0;
}

//+------------------------------------------------------------------+
//| Get Minutes Elapsed Since Datetime                               |
//+------------------------------------------------------------------+
double MinutesElapsed(datetime startTime) {
    if(startTime == 0) return 0;
    return (double)(TimeCurrent() - startTime) / 60.0;
}

//+------------------------------------------------------------------+
//| Get Seconds Elapsed Since Datetime                               |
//+------------------------------------------------------------------+
int SecondsElapsed(datetime startTime) {
    if(startTime == 0) return 0;
    return (int)(TimeCurrent() - startTime);
}

//+------------------------------------------------------------------+
//| FORMAT & STRING FUNCTIONS                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Format Price with Correct Digits                                 |
//+------------------------------------------------------------------+
string FormatPrice(double price) {
    return DoubleToString(price, symbolDigits);
}

//+------------------------------------------------------------------+
//| Format Pips Value                                                |
//+------------------------------------------------------------------+
string FormatPips(double pips) {
    return DoubleToString(pips, 1) + " pips";
}

//+------------------------------------------------------------------+
//| Format Lot Size                                                  |
//+------------------------------------------------------------------+
string FormatLot(double lot) {
    return DoubleToString(lot, 2) + " lot";
}

//+------------------------------------------------------------------+
//| Format Money Value                                               |
//+------------------------------------------------------------------+
string FormatMoney(double amount) {
    if(amount >= 0) {
        return "$" + DoubleToString(amount, 2);
    } else {
        return "-$" + DoubleToString(MathAbs(amount), 2);
    }
}

//+------------------------------------------------------------------+
//| Format Percentage                                                |
//+------------------------------------------------------------------+
string FormatPercent(double percent) {
    return DoubleToString(percent, 2) + "%";
}

//+------------------------------------------------------------------+
//| Format Time Duration (seconds to HH:MM:SS)                       |
//+------------------------------------------------------------------+
string FormatDuration(int seconds) {
    int hours = seconds / 3600;
    int minutes = (seconds % 3600) / 60;
    int secs = seconds % 60;

    return StringFormat("%02d:%02d:%02d", hours, minutes, secs);
}

//+------------------------------------------------------------------+
//| LOGGING FUNCTIONS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Log Message with Type Prefix                                     |
//+------------------------------------------------------------------+
void LogMessage(ENUM_LOG_LEVEL type, string message) {
    string prefix = "";

    switch(type) {
        case LOG_INFO:
            prefix = "INFO: ";
            break;
        case LOG_SUCCESS:
            prefix = "SUCCESS: ";
            break;
        case LOG_WARNING:
            prefix = "WARNING: ";
            break;
        case LOG_ERROR:
            prefix = "ERROR: ";
            break;
        case LOG_DEBUG:
            if(!DetailedLogging) return;  // Skip debug if not enabled
            prefix = "DEBUG: ";
            break;
    }

    Print(prefix, message);
}

//+------------------------------------------------------------------+
//| Log Grid Status                                                  |
//+------------------------------------------------------------------+
void LogGridStatus(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, string status) {
    string sideStr = (side == GRID_A) ? "GridA" : "GridB";
    string zoneStr = (zone == ZONE_UPPER) ? "Upper" : "Lower";

    Print("[", sideStr, "-", zoneStr, "-L", level+1, "] ", status);
}

//+------------------------------------------------------------------+
//| MATH & CALCULATION FUNCTIONS                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Safe Division (prevents division by zero)                        |
//+------------------------------------------------------------------+
double SafeDivide(double numerator, double denominator, double defaultValue = 0) {
    if(MathAbs(denominator) < 0.0000001) {
        return defaultValue;
    }
    return numerator / denominator;
}

//+------------------------------------------------------------------+
//| Calculate Percentage Change                                      |
//+------------------------------------------------------------------+
double PercentChange(double oldValue, double newValue) {
    if(MathAbs(oldValue) < 0.0000001) return 0;
    return ((newValue - oldValue) / oldValue) * 100.0;
}

//+------------------------------------------------------------------+
//| Calculate Win Rate                                               |
//+------------------------------------------------------------------+
double CalculateWinRate(int wins, int losses) {
    int total = wins + losses;
    if(total == 0) return 0;
    return (double)wins / total * 100.0;
}

//+------------------------------------------------------------------+
//| Calculate Profit Factor                                          |
//+------------------------------------------------------------------+
double CalculateProfitFactor(double grossProfit, double grossLoss) {
    if(MathAbs(grossLoss) < 0.01) return 0;
    return grossProfit / MathAbs(grossLoss);
}

//+------------------------------------------------------------------+
//| Round to Nearest Value                                           |
//+------------------------------------------------------------------+
double RoundToNearest(double value, double step) {
    if(step <= 0) return value;
    return MathRound(value / step) * step;
}

//+------------------------------------------------------------------+
//| ORDER & POSITION FUNCTIONS                                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Order Exists                                            |
//+------------------------------------------------------------------+
bool OrderExists(ulong ticket) {
    if(ticket == 0) return false;
    return OrderSelect(ticket);
}

//+------------------------------------------------------------------+
//| Check if Position Exists                                         |
//+------------------------------------------------------------------+
bool PositionExists(ulong ticket) {
    if(ticket == 0) return false;
    return PositionSelectByTicket(ticket);
}

//+------------------------------------------------------------------+
//| Get Position Profit by Ticket                                    |
//+------------------------------------------------------------------+
double GetPositionProfit(ulong ticket) {
    if(!PositionSelectByTicket(ticket)) return 0;

    double profit = PositionGetDouble(POSITION_PROFIT);
    profit += PositionGetDouble(POSITION_SWAP);

    return profit;
}

//+------------------------------------------------------------------+
//| Count Positions by Magic Number                                  |
//+------------------------------------------------------------------+
int CountPositionsByMagic(int magic) {
    int count = 0;

    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetInteger(POSITION_MAGIC) == magic &&
               PositionGetString(POSITION_SYMBOL) == _Symbol) {
                count++;
            }
        }
    }

    return count;
}

//+------------------------------------------------------------------+
//| Count Orders by Magic Number                                     |
//+------------------------------------------------------------------+
int CountOrdersByMagic(int magic) {
    int count = 0;

    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(OrderSelect(ticket)) {
            if(OrderGetInteger(ORDER_MAGIC) == magic &&
               OrderGetString(ORDER_SYMBOL) == _Symbol) {
                count++;
            }
        }
    }

    return count;
}

//+------------------------------------------------------------------+
//| ACCOUNT FUNCTIONS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Account Equity                                               |
//+------------------------------------------------------------------+
double GetEquity() {
    return AccountInfoDouble(ACCOUNT_EQUITY);
}

//+------------------------------------------------------------------+
//| Get Account Balance                                              |
//+------------------------------------------------------------------+
double GetBalance() {
    return AccountInfoDouble(ACCOUNT_BALANCE);
}

//+------------------------------------------------------------------+
//| Get Account Free Margin                                          |
//+------------------------------------------------------------------+
double GetFreeMargin() {
    return AccountInfoDouble(ACCOUNT_MARGIN_FREE);
}

//+------------------------------------------------------------------+
//| Get Margin Level (%)                                             |
//+------------------------------------------------------------------+
double GetMarginLevel() {
    double margin = AccountInfoDouble(ACCOUNT_MARGIN);
    if(margin <= 0) return 0;
    return (AccountInfoDouble(ACCOUNT_EQUITY) / margin) * 100.0;
}

//+------------------------------------------------------------------+
//| Calculate Current Drawdown (%)                                   |
//+------------------------------------------------------------------+
double GetCurrentDrawdown() {
    double balance = GetBalance();
    double equity = GetEquity();

    if(balance <= 0) return 0;

    if(equity >= balance) return 0;  // No drawdown if in profit

    return ((balance - equity) / balance) * 100.0;
}

//+------------------------------------------------------------------+
//| CHART OBJECT FUNCTIONS                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Create Horizontal Line                                           |
//+------------------------------------------------------------------+
void CreateHLine(string name, double price, color clr, int width = 1, ENUM_LINE_STYLE style = STYLE_SOLID) {
    if(ObjectFind(0, name) >= 0) {
        ObjectSetDouble(0, name, OBJPROP_PRICE, price);
        return;
    }

    ObjectCreate(0, name, OBJ_HLINE, 0, 0, price);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
    ObjectSetInteger(0, name, OBJPROP_STYLE, style);
    ObjectSetInteger(0, name, OBJPROP_BACK, true);
    ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false);
}

//+------------------------------------------------------------------+
//| Create Text Label                                                |
//+------------------------------------------------------------------+
void CreateLabel(string name, int x, int y, string text, color clr, int fontSize = 10) {
    if(ObjectFind(0, name) >= 0) {
        ObjectSetString(0, name, OBJPROP_TEXT, text);
        return;
    }

    ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
    ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
    ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
    ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
    ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
    ObjectSetString(0, name, OBJPROP_TEXT, text);
    ObjectSetString(0, name, OBJPROP_FONT, "Consolas");
    ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}

//+------------------------------------------------------------------+
//| Delete Object by Name                                            |
//+------------------------------------------------------------------+
void DeleteObject(string name) {
    if(ObjectFind(0, name) >= 0) {
        ObjectDelete(0, name);
    }
}

//+------------------------------------------------------------------+
//| Delete All Objects with Prefix                                   |
//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix) {
    int total = ObjectsTotal(0);
    for(int i = total - 1; i >= 0; i--) {
        string name = ObjectName(0, i);
        if(StringFind(name, prefix) == 0) {
            ObjectDelete(0, name);
        }
    }
}

