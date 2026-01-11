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

    // v5.x FIX: Strategy Tester compatibility - return default if no price
    if(ask <= 0 || bid <= 0) {
        return 1.0;  // Default 1 pip spread
    }

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
//| LOGGING SYSTEM v10.0 - PROFESSIONAL & AI-PARSABLE                |
//+------------------------------------------------------------------+
//| Format: [TIMESTAMP] [CATEGORY] [EVENT] key=value key=value       |
//| Categories: INIT, GRID, ORDER, POSITION, SHIELD, SESSION, SYSTEM |
//| Events are logged only on state changes, not on every tick       |
//+------------------------------------------------------------------+

// Log Categories - uppercase, fixed width for easy parsing
#define LOG_CAT_INIT      "[INIT]"
#define LOG_CAT_GRID      "[GRID]"
#define LOG_CAT_ORDER     "[ORDER]"
#define LOG_CAT_POSITION  "[POSITION]"
#define LOG_CAT_SHIELD    "[SHIELD]"
#define LOG_CAT_SESSION   "[SESSION]"
#define LOG_CAT_SYSTEM    "[SYSTEM]"
#define LOG_CAT_RECOVERY  "[RECOVERY]"
#define LOG_CAT_STRADDLE  "[STRADDLE]"
#define LOG_CAT_COP       "[COP]"
#define LOG_CAT_DEBUG     "[DEBUG]"

//+------------------------------------------------------------------+
//| Get Current Timestamp String (ISO-like format)                    |
//+------------------------------------------------------------------+
string GetLogTimestamp() {
    datetime now = TimeCurrent();
    return TimeToString(now, TIME_DATE|TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| CORE LOGGING FUNCTIONS - Always log (fundamental events)          |
//+------------------------------------------------------------------+

// Log grid start/stop - ALWAYS logged
void Log_GridStart(string grid, double entryPrice, double spacing, int levels) {
    PrintFormat("%s %s START grid=%s entry=%.5f spacing=%.1f levels=%d",
                GetLogTimestamp(), LOG_CAT_GRID, grid, entryPrice, spacing, levels);
}

void Log_GridStop(string grid, string reason) {
    PrintFormat("%s %s STOP grid=%s reason=%s",
                GetLogTimestamp(), LOG_CAT_GRID, grid, reason);
}

// Log order placement - ALWAYS logged
void Log_OrderPlaced(string grid, string zone, int level, string orderType,
                     ulong ticket, double price, double tp, double sl, double lot) {
    PrintFormat("%s %s PLACED grid=%s zone=%s level=%d type=%s ticket=%d price=%.5f tp=%.5f sl=%.5f lot=%.2f",
                GetLogTimestamp(), LOG_CAT_ORDER, grid, zone, level, orderType, ticket, price, tp, sl, lot);
}

// Log order cancelled - ALWAYS logged
void Log_OrderCancelled(ulong ticket, string reason) {
    PrintFormat("%s %s CANCELLED ticket=%d reason=%s",
                GetLogTimestamp(), LOG_CAT_ORDER, ticket, reason);
}

// Log position opened (order filled) - ALWAYS logged
void Log_PositionOpened(string grid, string zone, int level, string direction,
                        ulong ticket, double price, double lot) {
    PrintFormat("%s %s OPENED grid=%s zone=%s level=%d direction=%s ticket=%d price=%.5f lot=%.2f",
                GetLogTimestamp(), LOG_CAT_POSITION, grid, zone, level, direction, ticket, price, lot);
}

// Log position closed - ALWAYS logged
void Log_PositionClosed(ulong ticket, string reason, double profit, double closePrice) {
    PrintFormat("%s %s CLOSED ticket=%d reason=%s profit=%.2f price=%.5f",
                GetLogTimestamp(), LOG_CAT_POSITION, ticket, reason, profit, closePrice);
}

// Log SL/TP modification - ALWAYS logged
void Log_PositionModified(ulong ticket, string field, double oldValue, double newValue) {
    PrintFormat("%s %s MODIFIED ticket=%d field=%s old=%.5f new=%.5f",
                GetLogTimestamp(), LOG_CAT_POSITION, ticket, field, oldValue, newValue);
}

// Log cycle completion - ALWAYS logged
void Log_CycleCompleted(string grid, string zone, int level, int cycleNum, double profit) {
    PrintFormat("%s %s CYCLE_COMPLETE grid=%s zone=%s level=%d cycle=%d profit=%.2f",
                GetLogTimestamp(), LOG_CAT_POSITION, grid, zone, level, cycleNum, profit);
}

// Log shield events - ALWAYS logged (important state changes)
void Log_ShieldPhaseChange(string fromPhase, string toPhase, double price) {
    PrintFormat("%s %s PHASE_CHANGE from=%s to=%s price=%.5f",
                GetLogTimestamp(), LOG_CAT_SHIELD, fromPhase, toPhase, price);
}

void Log_ShieldActivated(string type, ulong ticket, double price, double lot, double exposure) {
    PrintFormat("%s %s ACTIVATED type=%s ticket=%d price=%.5f lot=%.2f exposure=%.2f",
                GetLogTimestamp(), LOG_CAT_SHIELD, type, ticket, price, lot, exposure);
}

void Log_ShieldClosed(ulong ticket, string reason, double profit, int duration) {
    PrintFormat("%s %s CLOSED ticket=%d reason=%s profit=%.2f duration=%ds",
                GetLogTimestamp(), LOG_CAT_SHIELD, ticket, reason, profit, duration);
}

// Log session events - ALWAYS logged
void Log_SessionStart(string symbol, string mode) {
    PrintFormat("%s %s START symbol=%s mode=%s",
                GetLogTimestamp(), LOG_CAT_SESSION, symbol, mode);
}

void Log_SessionEnd(int wins, int losses, double profit, int duration) {
    PrintFormat("%s %s END wins=%d losses=%d profit=%.2f duration=%ds",
                GetLogTimestamp(), LOG_CAT_SESSION, wins, losses, profit, duration);
}

void Log_SessionDailyReset() {
    PrintFormat("%s %s DAILY_RESET", GetLogTimestamp(), LOG_CAT_SESSION);
}

// Log system events - ALWAYS logged
void Log_SystemInit(string version, string symbol, double balance) {
    PrintFormat("%s %s INIT version=%s symbol=%s balance=%.2f",
                GetLogTimestamp(), LOG_CAT_SYSTEM, version, symbol, balance);
}

void Log_SystemShutdown(string reason) {
    PrintFormat("%s %s SHUTDOWN reason=%s", GetLogTimestamp(), LOG_CAT_SYSTEM, reason);
}

void Log_SystemError(string component, int code, string message) {
    PrintFormat("%s %s ERROR component=%s code=%d message=%s",
                GetLogTimestamp(), LOG_CAT_SYSTEM, component, code, message);
}

void Log_SystemWarning(string component, string message) {
    PrintFormat("%s %s WARNING component=%s message=%s",
                GetLogTimestamp(), LOG_CAT_SYSTEM, component, message);
}

// Log recovery events - ALWAYS logged
void Log_RecoveryStart(int orders, int positions) {
    PrintFormat("%s %s START orders=%d positions=%d",
                GetLogTimestamp(), LOG_CAT_RECOVERY, orders, positions);
}

void Log_RecoveryComplete(int recoveredOrders, int recoveredPositions, double recoveredEntryPoint) {
    PrintFormat("%s %s COMPLETE orders=%d positions=%d entry=%.5f",
                GetLogTimestamp(), LOG_CAT_RECOVERY, recoveredOrders, recoveredPositions, recoveredEntryPoint);
}

// v9.11: Recovery con Alert - ALWAYS logged
void Log_RecoveryAlert(string event, string details, bool success) {
    string status = success ? "SUCCESS" : "FAILED";
    string msg = StringFormat("[%s] RECOVERY %s: %s | %s", _Symbol, status, event, details);
    PrintFormat("%s %s %s", GetLogTimestamp(), LOG_CAT_RECOVERY, msg);

    if(EnableAlerts && !MQLInfoInteger(MQL_TESTER)) {
        Alert("SUGAMARA [", _Symbol, "]: ", event, " - ", status);
    }
}

// v9.11: Crash/Error con Alert - ALWAYS logged
void Log_CrashAlert(string component, int errorCode, string details) {
    string msg = StringFormat("CRASH in %s | Error: %d | %s", component, errorCode, details);
    PrintFormat("%s [CRASH] %s", GetLogTimestamp(), msg);

    if(EnableAlerts && !MQLInfoInteger(MQL_TESTER)) {
        Alert("SUGAMARA CRASH: ", component, " - ", details);
    }
}

// v9.11: Dashboard Recovery con dettagli - ALWAYS logged
void Log_DashboardRecovery(int missingCount, string missingList) {
    PrintFormat("%s [UI-RECOVERY] %d objects missing: %s", GetLogTimestamp(), missingCount, missingList);

    if(EnableAlerts && !MQLInfoInteger(MQL_TESTER)) {
        Alert("SUGAMARA [", _Symbol, "]: Dashboard recreated (", missingCount, " objects missing)");
    }
}

// Log straddle events - ALWAYS logged
void Log_StraddleOpened(double center, double spacing, double lot) {
    PrintFormat("%s %s OPENED center=%.5f spacing=%.1f lot=%.2f",
                GetLogTimestamp(), LOG_CAT_STRADDLE, center, spacing, lot);
}

void Log_StraddleFilled(string direction, int round, double price, double lot) {
    PrintFormat("%s %s FILLED direction=%s round=%d price=%.5f lot=%.2f",
                GetLogTimestamp(), LOG_CAT_STRADDLE, direction, round, price, lot);
}

void Log_StraddleClosed(string reason, double profit, int rounds) {
    PrintFormat("%s %s CLOSED reason=%s profit=%.2f rounds=%d",
                GetLogTimestamp(), LOG_CAT_STRADDLE, reason, profit, rounds);
}

// Log COP events - ALWAYS logged
void Log_COPTargetReached(double profit, double target) {
    PrintFormat("%s %s TARGET_REACHED profit=%.2f target=%.2f",
                GetLogTimestamp(), LOG_CAT_COP, profit, target);
}

void Log_COPReset(string reason) {
    PrintFormat("%s %s RESET reason=%s", GetLogTimestamp(), LOG_CAT_COP, reason);
}

//+------------------------------------------------------------------+
//| DEBUG LOGGING FUNCTIONS - Only when DetailedLogging=true          |
//+------------------------------------------------------------------+

void Log_Debug(string component, string message) {
    if(!DetailedLogging) return;
    PrintFormat("%s %s %s: %s", GetLogTimestamp(), LOG_CAT_DEBUG, component, message);
}

void Log_DebugPrice(string context, double bid, double ask, double spread) {
    if(!DetailedLogging) return;
    PrintFormat("%s %s PRICE context=%s bid=%.5f ask=%.5f spread=%.1f",
                GetLogTimestamp(), LOG_CAT_DEBUG, context, bid, ask, spread);
}

void Log_DebugATR(double atr, double spacing, string condition) {
    if(!DetailedLogging) return;
    PrintFormat("%s %s ATR value=%.2f spacing=%.1f condition=%s",
                GetLogTimestamp(), LOG_CAT_DEBUG, atr, spacing, condition);
}

void Log_DebugShield(string phase, string state, double price, double distance) {
    if(!DetailedLogging) return;
    PrintFormat("%s %s SHIELD_STATE phase=%s state=%s price=%.5f distance=%.1f",
                GetLogTimestamp(), LOG_CAT_DEBUG, phase, state, price, distance);
}

void Log_DebugReopen(string grid, string zone, int level, string status, double price) {
    if(!DetailedLogging) return;
    PrintFormat("%s %s REOPEN grid=%s zone=%s level=%d status=%s price=%.5f",
                GetLogTimestamp(), LOG_CAT_DEBUG, grid, zone, level, status, price);
}

//+------------------------------------------------------------------+
//| INITIALIZATION LOGGING - Called once at startup                   |
//+------------------------------------------------------------------+

void Log_InitConfig(string key, string value) {
    PrintFormat("%s %s CONFIG %s=%s", GetLogTimestamp(), LOG_CAT_INIT, key, value);
}

void Log_InitConfigNum(string key, double value) {
    PrintFormat("%s %s CONFIG %s=%.5f", GetLogTimestamp(), LOG_CAT_INIT, key, value);
}

void Log_InitComplete(string component) {
    PrintFormat("%s %s COMPLETE component=%s", GetLogTimestamp(), LOG_CAT_INIT, component);
}

void Log_InitFailed(string component, string reason) {
    PrintFormat("%s %s FAILED component=%s reason=%s", GetLogTimestamp(), LOG_CAT_INIT, component, reason);
}

//+------------------------------------------------------------------+
//| SUMMARY/REPORT FUNCTIONS - On demand only                         |
//+------------------------------------------------------------------+

void Log_Separator() {
    Print("--------------------------------------------------------------------------------");
}

void Log_Header(string title) {
    Print("================================================================================");
    PrintFormat("  %s", title);
    Print("================================================================================");
}

void Log_SubHeader(string title) {
    Print("--------------------------------------------------------------------------------");
    PrintFormat("  %s", title);
    Print("--------------------------------------------------------------------------------");
}

void Log_KeyValue(string key, string value) {
    PrintFormat("  %-30s %s", key + ":", value);
}

void Log_KeyValueNum(string key, double value, int decimals = 2) {
    PrintFormat("  %-30s %.*f", key + ":", decimals, value);
}

//+------------------------------------------------------------------+
//| LEGACY COMPATIBILITY - Wrapper functions (to be phased out)       |
//+------------------------------------------------------------------+

void LogMessage(ENUM_LOG_LEVEL type, string message) {
    string prefix = "";
    switch(type) {
        case LOG_INFO:    prefix = "INFO"; break;
        case LOG_SUCCESS: prefix = "SUCCESS"; break;
        case LOG_WARNING: prefix = "WARNING"; break;
        case LOG_ERROR:   prefix = "ERROR"; break;
        case LOG_DEBUG:
            if(!DetailedLogging) return;
            prefix = "DEBUG";
            break;
    }
    PrintFormat("%s [%s] %s", GetLogTimestamp(), prefix, message);
}

void LogGridStatus(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, string status) {
    string grid = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    PrintFormat("%s %s STATUS grid=%s zone=%s level=%d status=%s",
                GetLogTimestamp(), LOG_CAT_GRID, grid, zoneName, level+1, status);
}

void LogSystem(string message, bool forceLog = false) {
    if(!DetailedLogging && !forceLog) return;
    PrintFormat("%s %s %s", GetLogTimestamp(), LOG_CAT_SYSTEM, message);
}

void LogGrid(ENUM_GRID_SIDE side, string message) {
    if(!DetailedLogging) return;
    string grid = (side == GRID_A) ? "A" : "B";
    PrintFormat("%s %s grid=%s %s", GetLogTimestamp(), LOG_CAT_GRID, grid, message);
}

void LogOrder(string action, ulong ticket, string details) {
    if(!DetailedLogging) return;
    PrintFormat("%s %s %s ticket=%d %s", GetLogTimestamp(), LOG_CAT_ORDER, action, ticket, details);
}

void LogShield(string phase, string action, string details = "") {
    if(!DetailedLogging) return;
    if(details != "") {
        PrintFormat("%s %s phase=%s action=%s details=%s", GetLogTimestamp(), LOG_CAT_SHIELD, phase, action, details);
    } else {
        PrintFormat("%s %s phase=%s action=%s", GetLogTimestamp(), LOG_CAT_SHIELD, phase, action);
    }
}

void LogATR(double atrValue, double spacing, string condition) {
    if(!DetailedLogging) return;
    Log_DebugATR(atrValue, spacing, condition);
}

void LogCycle(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, int cycleNum, double profit) {
    string grid = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    Log_CycleCompleted(grid, zoneName, level+1, cycleNum, profit);
}

void LogReopen(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, string reason) {
    if(!DetailedLogging) return;
    string grid = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    Log_DebugReopen(grid, zoneName, level+1, reason, 0);
}

void LogOrderPlacement(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level,
                       ENUM_ORDER_TYPE orderType, double price, double tp, double sl, double lot) {
    if(!DetailedLogging) return;
    string grid = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    string typeName = "";
    switch(orderType) {
        case ORDER_TYPE_BUY_LIMIT:  typeName = "BUY_LIMIT"; break;
        case ORDER_TYPE_BUY_STOP:   typeName = "BUY_STOP"; break;
        case ORDER_TYPE_SELL_LIMIT: typeName = "SELL_LIMIT"; break;
        case ORDER_TYPE_SELL_STOP:  typeName = "SELL_STOP"; break;
        default: typeName = "UNKNOWN"; break;
    }
    Log_OrderPlaced(grid, zoneName, level+1, typeName, 0, price, tp, sl, lot);
}

void LogOrderFill(ulong ticket, ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, double fillPrice) {
    string grid = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    string direction = (side == GRID_A) ? "LONG" : "SHORT";
    Log_PositionOpened(grid, zoneName, level+1, direction, ticket, fillPrice, 0);
}

void LogPositionClose(ulong ticket, string reason, double profit, double closePrice) {
    Log_PositionClosed(ticket, reason, profit, closePrice);
}

void LogSessionSummary() {
    Log_Header("SUGAMARA SESSION SUMMARY");
    Log_KeyValue("Timestamp", GetLogTimestamp());
    Log_KeyValueNum("Wins", sessionWins, 0);
    Log_KeyValueNum("Losses", sessionLosses, 0);
    Log_KeyValueNum("Win Rate", GetWinRate(), 1);
    Log_KeyValueNum("Realized P/L", sessionRealizedProfit, 2);
    Log_KeyValue("Mode", "v9.0 Perfect Cascade");
    Log_Separator();
}

void LogGridInitSummary(ENUM_GRID_SIDE side) {
    if(!DetailedLogging) return;
    string grid = (side == GRID_A) ? "A" : "B";
    string orderTypes = (side == GRID_A) ? "Upper=BUY_STOP,Lower=BUY_LIMIT" : "Upper=SELL_LIMIT,Lower=SELL_STOP";
    Log_SubHeader("GRID " + grid + " INITIALIZED");
    Log_KeyValueNum("Entry Point", entryPoint, 5);
    Log_KeyValueNum("Spacing (pips)", currentSpacing_Pips, 1);
    Log_KeyValueNum("Levels per side", GridLevelsPerSide, 0);
    Log_KeyValue("Order Types", orderTypes);
    Log_Separator();
}

void LogPriceAlert(string zone, double currentPrice, double triggerLevel, double distance) {
    if(!DetailedLogging) return;
    PrintFormat("%s %s ALERT zone=%s price=%.5f trigger=%.5f distance=%.1f",
                GetLogTimestamp(), LOG_CAT_SHIELD, zone, currentPrice, triggerLevel, distance);
}

void LogStartupBanner() {
    Print("");
    Print("================================================================================");
    Print("  SUGAMARA RIBELLE v9.10");
    Print("  Perfect Cascade Trading System");
    Print("================================================================================");
    Log_KeyValue("Symbol", _Symbol);
    Log_KeyValue("Timeframe", EnumToString((ENUM_TIMEFRAMES)Period()));
    Log_KeyValue("Start Time", GetLogTimestamp());
    Log_KeyValue("Mode", "Grid A=BUY, Grid B=SELL");
    Print("================================================================================");
    Print("");
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

