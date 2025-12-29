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
//| ENHANCED LOGGING SYSTEM v5.1 - SUGAMARA RIBELLE                  |
//| Detailed logging for all EA functionalities                      |
//+------------------------------------------------------------------+

// Log Categories
#define LOG_CAT_SYSTEM    "[SYSTEM]"
#define LOG_CAT_GRID      "[GRID]"
#define LOG_CAT_ORDER     "[ORDER]"
#define LOG_CAT_CASCADE   "[CASCADE]"
#define LOG_CAT_SHIELD    "[SHIELD]"
#define LOG_CAT_ATR       "[ATR]"
#define LOG_CAT_CYCLE     "[CYCLE]"
#define LOG_CAT_REOPEN    "[REOPEN]"
#define LOG_CAT_DP        "[DP]"
#define LOG_CAT_TRAIL     "[TRAIL]"

//+------------------------------------------------------------------+
//| Get Current Timestamp String                                      |
//+------------------------------------------------------------------+
string GetLogTimestamp() {
    datetime now = TimeCurrent();
    return TimeToString(now, TIME_DATE|TIME_SECONDS);
}

//+------------------------------------------------------------------+
//| Log System Event (Initialization, Shutdown, State Changes)        |
//+------------------------------------------------------------------+
void LogSystem(string message, bool forceLog = false) {
    if(!DetailedLogging && !forceLog) return;
    PrintFormat("%s %s %s", GetLogTimestamp(), LOG_CAT_SYSTEM, message);
}

//+------------------------------------------------------------------+
//| Log Grid Event (Level calculations, prices, state)                |
//+------------------------------------------------------------------+
void LogGrid(ENUM_GRID_SIDE side, string message) {
    if(!DetailedLogging) return;
    string gridName = (side == GRID_A) ? "A" : "B";
    PrintFormat("%s %s Grid%s: %s", GetLogTimestamp(), LOG_CAT_GRID, gridName, message);
}

//+------------------------------------------------------------------+
//| Log Order Event (Placement, Fill, Close, Modify)                  |
//+------------------------------------------------------------------+
void LogOrder(string action, ulong ticket, string details) {
    if(!DetailedLogging) return;
    PrintFormat("%s %s %s #%d - %s", GetLogTimestamp(), LOG_CAT_ORDER, action, ticket, details);
}

//+------------------------------------------------------------------+
//| Log CASCADE_OVERLAP Specific Events                               |
//+------------------------------------------------------------------+
void LogCascadeOverlap(string event, string details) {
    if(!DetailedLogging) return;
    PrintFormat("%s %s [OVERLAP] %s: %s", GetLogTimestamp(), LOG_CAT_CASCADE, event, details);
}

//+------------------------------------------------------------------+
//| Log Shield Events (3 Phases, Activation, Deactivation)            |
//+------------------------------------------------------------------+
void LogShield(string phase, string action, string details = "") {
    if(!DetailedLogging) return;
    if(details != "") {
        PrintFormat("%s %s [%s] %s - %s", GetLogTimestamp(), LOG_CAT_SHIELD, phase, action, details);
    } else {
        PrintFormat("%s %s [%s] %s", GetLogTimestamp(), LOG_CAT_SHIELD, phase, action);
    }
}

//+------------------------------------------------------------------+
//| Log ATR/Volatility Events                                         |
//+------------------------------------------------------------------+
void LogATR(double atrValue, double spacing, string condition) {
    if(!DetailedLogging) return;
    PrintFormat("%s %s ATR=%.2f pips | Spacing=%.1f pips | Condition: %s",
                GetLogTimestamp(), LOG_CAT_ATR, atrValue, spacing, condition);
}

//+------------------------------------------------------------------+
//| Log Cycle Completion                                              |
//+------------------------------------------------------------------+
void LogCycle(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, int cycleNum, double profit) {
    string gridName = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    PrintFormat("%s %s Grid%s-%s-L%d: Cycle #%d completed | Profit: $%.2f",
                GetLogTimestamp(), LOG_CAT_CYCLE, gridName, zoneName, level+1, cycleNum, profit);
}

//+------------------------------------------------------------------+
//| Log Reopen Event                                                  |
//+------------------------------------------------------------------+
void LogReopen(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, string reason) {
    if(!DetailedLogging) return;
    string gridName = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    PrintFormat("%s %s Grid%s-%s-L%d: %s",
                GetLogTimestamp(), LOG_CAT_REOPEN, gridName, zoneName, level+1, reason);
}

//+------------------------------------------------------------------+
//| DOUBLE PARCELLING LOGGING FUNCTIONS v5.4                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Log DP Setup Event                                                |
//+------------------------------------------------------------------+
void LogDP_Setup(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level,
                 ulong ticket, double entryPrice, double lots,
                 double parcelA_Lots, double parcelB_Lots) {
    if(!DP_DetailedLogging) return;
    string gridName = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    PrintFormat("%s %s SETUP Grid%s-%s-L%d | Ticket:#%d | Entry:%.5f | Total:%.2f lots (A:%.2f + B:%.2f)",
                GetLogTimestamp(), LOG_CAT_DP, gridName, zoneName, level+1,
                ticket, entryPrice, lots, parcelA_Lots, parcelB_Lots);
}

//+------------------------------------------------------------------+
//| Log DP TP Levels Calculated                                       |
//+------------------------------------------------------------------+
void LogDP_TPLevels(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level,
                    double tp1, double tp2, double bop1_trigger, double bop2_trigger) {
    if(!DP_DetailedLogging || !DP_LogPhaseChanges) return;
    string gridName = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    PrintFormat("%s %s LEVELS Grid%s-%s-L%d | TP1:%.5f | TP2:%.5f | BOP1@%.5f | BOP2@%.5f",
                GetLogTimestamp(), LOG_CAT_DP, gridName, zoneName, level+1,
                tp1, tp2, bop1_trigger, bop2_trigger);
}

//+------------------------------------------------------------------+
//| Log DP Phase Change                                               |
//+------------------------------------------------------------------+
void LogDP_PhaseChange(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level,
                       string fromPhase, string toPhase, string details = "") {
    if(!DP_DetailedLogging || !DP_LogPhaseChanges) return;
    string gridName = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    if(details != "") {
        PrintFormat("%s %s PHASE Grid%s-%s-L%d | %s -> %s | %s",
                    GetLogTimestamp(), LOG_CAT_DP, gridName, zoneName, level+1,
                    fromPhase, toPhase, details);
    } else {
        PrintFormat("%s %s PHASE Grid%s-%s-L%d | %s -> %s",
                    GetLogTimestamp(), LOG_CAT_DP, gridName, zoneName, level+1,
                    fromPhase, toPhase);
    }
}

//+------------------------------------------------------------------+
//| Log DP BOP Activation                                             |
//+------------------------------------------------------------------+
void LogDP_BOPActivated(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level,
                        int bopNum, double triggerPrice, double newSL) {
    if(!DP_DetailedLogging) return;
    string gridName = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    PrintFormat("%s %s BOP%d ACTIVATED Grid%s-%s-L%d | Trigger@%.5f | SL moved to %.5f",
                GetLogTimestamp(), LOG_CAT_DP, bopNum, gridName, zoneName, level+1,
                triggerPrice, newSL);
}

//+------------------------------------------------------------------+
//| Log DP Parcel Close                                               |
//+------------------------------------------------------------------+
void LogDP_ParcelClosed(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level,
                        string parcel, double lots, double profit, double closePrice) {
    if(!DP_DetailedLogging) return;
    string gridName = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    PrintFormat("%s %s PARCEL %s CLOSED Grid%s-%s-L%d | Lots:%.2f | Profit:$%.2f | Close@%.5f",
                GetLogTimestamp(), LOG_CAT_DP, parcel, gridName, zoneName, level+1,
                lots, profit, closePrice);
}

//+------------------------------------------------------------------+
//| Log DP Cycle Complete                                             |
//+------------------------------------------------------------------+
void LogDP_CycleComplete(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level,
                         double parcelA_Profit, double parcelB_Profit, double totalProfit) {
    // Always log cycle completions (important event)
    string gridName = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    PrintFormat("%s %s ═══ CYCLE COMPLETE ═══ Grid%s-%s-L%d | A:$%.2f + B:$%.2f = Total:$%.2f",
                GetLogTimestamp(), LOG_CAT_DP, gridName, zoneName, level+1,
                parcelA_Profit, parcelB_Profit, totalProfit);
}

//+------------------------------------------------------------------+
//| Log DP Tick Progress (Debug Only)                                 |
//+------------------------------------------------------------------+
void LogDP_TickProgress(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level,
                        double currentPrice, double tp1Progress, double tp2Progress) {
    if(!DP_LogTickProgress) return;
    string gridName = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    PrintFormat("%s %s TICK Grid%s-%s-L%d | Price:%.5f | TP1:%.1f%% | TP2:%.1f%%",
                GetLogTimestamp(), LOG_CAT_DP, gridName, zoneName, level+1,
                currentPrice, tp1Progress, tp2Progress);
}

//+------------------------------------------------------------------+
//| Log DP Statistics                                                 |
//+------------------------------------------------------------------+
void LogDP_Statistics(int totalCycles, double totalProfit, int activeA, int activeB) {
    if(!DP_DetailedLogging || !DP_LogProfitDetails) return;
    PrintFormat("%s %s STATS | Cycles:%d | Total Profit:$%.2f | Active: A=%d B=%d",
                GetLogTimestamp(), LOG_CAT_DP, totalCycles, totalProfit, activeA, activeB);
}

//+------------------------------------------------------------------+
//| TRAILING GRID LOGGING FUNCTIONS v5.4                              |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Log Trail Initialization                                          |
//+------------------------------------------------------------------+
void LogTrail_Init(int triggerLevel, double spacingMult, int maxExtra, bool syncShield) {
    if(!Trail_DetailedLogging) return;
    PrintFormat("%s %s INIT | Trigger:L%d | SpacingMult:%.2f | MaxExtra:%d | SyncShield:%s",
                GetLogTimestamp(), LOG_CAT_TRAIL, triggerLevel, spacingMult, maxExtra,
                syncShield ? "YES" : "NO");
}

//+------------------------------------------------------------------+
//| Log Trail Trigger Check (Debug)                                   |
//+------------------------------------------------------------------+
void LogTrail_TriggerCheck(string direction, int pendingCount, int triggerLevel, double currentPrice) {
    if(!Trail_LogTriggerChecks) return;
    PrintFormat("%s %s CHECK %s | Pending:%d (trigger<=%d) | Price:%.5f",
                GetLogTimestamp(), LOG_CAT_TRAIL, direction, pendingCount, triggerLevel, currentPrice);
}

//+------------------------------------------------------------------+
//| Log Trail Grid Insertion                                          |
//+------------------------------------------------------------------+
void LogTrail_GridInserted(string direction, int newIndex, double gridAPrice, double gridBPrice,
                           double lotSize, double tpA, double tpB) {
    if(!Trail_DetailedLogging || !Trail_LogInsertions) return;
    PrintFormat("%s %s ➕ INSERT %s [%d] | GridA@%.5f (TP:%.5f) | GridB@%.5f (TP:%.5f) | Lot:%.2f",
                GetLogTimestamp(), LOG_CAT_TRAIL, direction, newIndex,
                gridAPrice, tpA, gridBPrice, tpB, lotSize);
}

//+------------------------------------------------------------------+
//| Log Trail Grid Removal                                            |
//+------------------------------------------------------------------+
void LogTrail_GridRemoved(string direction, int index, double price) {
    if(!Trail_DetailedLogging || !Trail_LogRemovals) return;
    PrintFormat("%s %s ➖ REMOVE %s [%d] @ %.5f",
                GetLogTimestamp(), LOG_CAT_TRAIL, direction, index, price);
}

//+------------------------------------------------------------------+
//| Log Trail Shield Zone Update                                      |
//+------------------------------------------------------------------+
void LogTrail_ShieldUpdate(double newResistance, double newSupport, double rangeHeight) {
    if(!Trail_DetailedLogging || !Trail_LogShieldSync) return;
    PrintFormat("%s %s 🛡️ SHIELD SYNC | R:%.5f | S:%.5f | Range:%.1f pips",
                GetLogTimestamp(), LOG_CAT_TRAIL, newResistance, newSupport, rangeHeight);
}

//+------------------------------------------------------------------+
//| Log Trail Trigger Event                                           |
//+------------------------------------------------------------------+
void LogTrail_Triggered(string direction, int pendingCount, double newLevel, int extraCount) {
    if(!Trail_DetailedLogging) return;
    PrintFormat("%s %s TRIGGER %s | Pending:%d | NewLevel:%.5f | ExtraGrids:%d",
                GetLogTimestamp(), LOG_CAT_TRAIL, direction, pendingCount, newLevel, extraCount);
}

//+------------------------------------------------------------------+
//| Log Trail Statistics                                              |
//+------------------------------------------------------------------+
void LogTrail_Statistics(int upperAdded, int upperRemoved, int lowerAdded, int lowerRemoved) {
    if(!Trail_DetailedLogging) return;
    PrintFormat("%s %s STATS | Upper: +%d/-%d | Lower: +%d/-%d",
                GetLogTimestamp(), LOG_CAT_TRAIL, upperAdded, upperRemoved, lowerAdded, lowerRemoved);
}

//+------------------------------------------------------------------+
//| Log Trail Error                                                   |
//+------------------------------------------------------------------+
void LogTrail_Error(string operation, string errorMessage) {
    // Always log errors
    PrintFormat("%s %s ERROR in %s: %s",
                GetLogTimestamp(), LOG_CAT_TRAIL, operation, errorMessage);
}

//+------------------------------------------------------------------+
//| Log Detailed Order Placement (CASCADE_OVERLAP)                    |
//+------------------------------------------------------------------+
void LogOrderPlacement(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level,
                       ENUM_ORDER_TYPE orderType, double price, double tp, double sl, double lot) {
    if(!DetailedLogging) return;

    string gridName = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    string typeName = "";

    switch(orderType) {
        case ORDER_TYPE_BUY_LIMIT:  typeName = "BUY_LIMIT"; break;
        case ORDER_TYPE_BUY_STOP:   typeName = "BUY_STOP"; break;
        case ORDER_TYPE_SELL_LIMIT: typeName = "SELL_LIMIT"; break;
        case ORDER_TYPE_SELL_STOP:  typeName = "SELL_STOP"; break;
        default: typeName = "UNKNOWN"; break;
    }

    // Check if this is a hedge order (CASCADE_OVERLAP)
    string hedgeInfo = "";
    if(IsCascadeOverlapMode()) {
        if((side == GRID_A && zone == ZONE_LOWER) || (side == GRID_B && zone == ZONE_UPPER)) {
            hedgeInfo = " [HEDGE -3pip]";
        } else {
            hedgeInfo = " [TREND]";
        }
    }

    PrintFormat("%s %s Grid%s-%s-L%d: %s%s @ %.5f | TP=%.5f | SL=%.5f | Lot=%.2f",
                GetLogTimestamp(), LOG_CAT_ORDER, gridName, zoneName, level+1,
                typeName, hedgeInfo, price, tp, sl, lot);
}

//+------------------------------------------------------------------+
//| Log Order Fill (Position Opened)                                  |
//+------------------------------------------------------------------+
void LogOrderFill(ulong ticket, ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, double fillPrice) {
    string gridName = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";

    string direction = "";
    if(IsCascadeOverlapMode()) {
        direction = (side == GRID_A) ? "LONG" : "SHORT";
    } else {
        direction = ((side == GRID_A && zone == ZONE_UPPER) || (side == GRID_B && zone == ZONE_LOWER)) ? "LONG" : "SHORT";
    }

    PrintFormat("%s %s FILLED #%d | Grid%s-%s-L%d | %s @ %.5f",
                GetLogTimestamp(), LOG_CAT_ORDER, ticket, gridName, zoneName, level+1, direction, fillPrice);
}

//+------------------------------------------------------------------+
//| Log Position Close (TP Hit, SL Hit, Manual)                       |
//+------------------------------------------------------------------+
void LogPositionClose(ulong ticket, string reason, double profit, double closePrice) {
    string profitStr = (profit >= 0) ? StringFormat("+$%.2f", profit) : StringFormat("-$%.2f", MathAbs(profit));
    PrintFormat("%s %s CLOSED #%d | %s | %s @ %.5f",
                GetLogTimestamp(), LOG_CAT_ORDER, ticket, reason, profitStr, closePrice);
}

//+------------------------------------------------------------------+
//| Log Session Summary                                               |
//+------------------------------------------------------------------+
void LogSessionSummary() {
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  SUGAMARA RIBELLE - SESSION SUMMARY");
    Print("═══════════════════════════════════════════════════════════════════");
    PrintFormat("  Timestamp: %s", GetLogTimestamp());
    PrintFormat("  Total Wins: %d | Total Losses: %d", sessionWins, sessionLosses);
    PrintFormat("  Win Rate: %.1f%%", GetWinRate());
    PrintFormat("  Realized P/L: $%.2f", sessionRealizedProfit);
    if(IsCascadeOverlapMode()) {
        Print("  Mode: CASCADE_OVERLAP (Grid A=BUY, Grid B=SELL)");
        PrintFormat("  Hedge Spacing: %.1f pips", Hedge_Spacing_Pips);
    }
    Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Log Grid Initialization Summary                                   |
//+------------------------------------------------------------------+
void LogGridInitSummary(ENUM_GRID_SIDE side) {
    if(!DetailedLogging) return;

    string gridName = (side == GRID_A) ? "A" : "B";
    string orderTypes = "";

    if(IsCascadeOverlapMode()) {
        if(side == GRID_A) {
            orderTypes = "Upper=BUY_STOP, Lower=BUY_LIMIT(-3pip)";
        } else {
            orderTypes = "Upper=SELL_LIMIT(+3pip), Lower=SELL_STOP";
        }
    } else {
        if(side == GRID_A) {
            orderTypes = "Upper=BUY_LIMIT, Lower=SELL_STOP";
        } else {
            orderTypes = "Upper=SELL_LIMIT, Lower=BUY_STOP";
        }
    }

    Print("───────────────────────────────────────────────────────────────────");
    PrintFormat("  GRID %s INITIALIZED", gridName);
    PrintFormat("  Entry Point: %.5f", entryPoint);
    PrintFormat("  Spacing: %.1f pips", currentSpacing_Pips);
    PrintFormat("  Levels per side: %d", GridLevelsPerSide);
    PrintFormat("  Order Types: %s", orderTypes);
    Print("───────────────────────────────────────────────────────────────────");
}

//+------------------------------------------------------------------+
//| Log Price Movement Alert                                          |
//+------------------------------------------------------------------+
void LogPriceAlert(string zone, double currentPrice, double triggerLevel, double distance) {
    if(!DetailedLogging) return;
    PrintFormat("%s [ALERT] Price in %s zone | Current=%.5f | Trigger=%.5f | Distance=%.1f pips",
                GetLogTimestamp(), zone, currentPrice, triggerLevel, distance);
}

//+------------------------------------------------------------------+
//| Log Startup Banner                                                |
//+------------------------------------------------------------------+
void LogStartupBanner() {
    Print("");
    Print("╔═══════════════════════════════════════════════════════════════════╗");
    Print("║                                                                   ║");
    Print("║     ███████╗██╗   ██╗ ██████╗  █████╗ ███╗   ███╗ █████╗ ██████╗  ║");
    Print("║     ██╔════╝██║   ██║██╔════╝ ██╔══██╗████╗ ████║██╔══██╗██╔══██╗ ║");
    Print("║     ███████╗██║   ██║██║  ███╗███████║██╔████╔██║███████║██████╔╝ ║");
    Print("║     ╚════██║██║   ██║██║   ██║██╔══██║██║╚██╔╝██║██╔══██║██╔══██╗ ║");
    Print("║     ███████║╚██████╔╝╚██████╔╝██║  ██║██║ ╚═╝ ██║██║  ██║██║  ██║ ║");
    Print("║     ╚══════╝ ╚═════╝  ╚═════╝ ╚═╝  ╚═╝╚═╝     ╚═╝╚═╝  ╚═╝╚═╝  ╚═╝ ║");
    Print("║                                                                   ║");
    Print("║                      R I B E L L E   v5.1                         ║");
    Print("║              CASCADE SOVRAPPOSTO - DUNE THEME                     ║");
    Print("║                  \"The Spice Must Flow\"                            ║");
    Print("║                                                                   ║");
    Print("╚═══════════════════════════════════════════════════════════════════╝");
    Print("");
    PrintFormat("  Symbol: %s | Timeframe: %s", _Symbol, EnumToString((ENUM_TIMEFRAMES)Period()));
    PrintFormat("  Start Time: %s", GetLogTimestamp());
    if(IsCascadeOverlapMode()) {
        Print("  Mode: CASCADE_OVERLAP (Grid A=SOLO BUY, Grid B=SOLO SELL)");
        PrintFormat("  Hedge Spacing: %.1f pips", Hedge_Spacing_Pips);
    }
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

