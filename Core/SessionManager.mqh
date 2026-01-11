//+------------------------------------------------------------------+
//|                                            SessionManager.mqh    |
//|                        Sugamara - Automatic Session Manager      |
//|                                  v4.6 - Trading Hour Control     |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Global Session Variables                                          |
//+------------------------------------------------------------------+
bool   sessionStartTriggered = false;      // Has session start been triggered today?
bool   sessionCloseTriggered = false;      // Has session close been triggered today?
int    lastSessionDay = -1;                // Last day we checked (for daily reset)

//+------------------------------------------------------------------+
//| Parse Time String to Minutes                                      |
//| Converts "HH:MM" format to total minutes from midnight            |
//+------------------------------------------------------------------+
int ParseTimeToMinutes(string timeStr) {
    // Handle empty or invalid input
    if(StringLen(timeStr) < 4) return -1;

    // Find the colon separator
    int colonPos = StringFind(timeStr, ":");
    if(colonPos < 0) return -1;

    // Extract hours and minutes
    string hourStr = StringSubstr(timeStr, 0, colonPos);
    string minStr = StringSubstr(timeStr, colonPos + 1);

    int hours = (int)StringToInteger(hourStr);
    int mins = (int)StringToInteger(minStr);

    // Validate ranges
    if(hours < 0 || hours > 23 || mins < 0 || mins > 59) return -1;

    return hours * 60 + mins;
}

//+------------------------------------------------------------------+
//| Check if Within Trading Session                                   |
//| Returns true if trading is allowed based on session times         |
//+------------------------------------------------------------------+
bool IsWithinTradingSession() {
    // If auto session is disabled, always allow trading
    if(!EnableAutoSession) return true;

    // Get current broker time
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);

    int currentMinutes = dt.hour * 60 + dt.min;

    // Parse start and close times
    int startMinutes = ParseTimeToMinutes(SessionStartTime);
    int closeMinutes = ParseTimeToMinutes(SessionCloseTime);

    if(startMinutes < 0 || closeMinutes < 0) {
        Log_SystemWarning("Session", "Invalid time format, using 09:30-17:00");
        startMinutes = 9 * 60 + 30;
        closeMinutes = 17 * 60;
    }

    // Check if session start is enabled
    if(EnableSessionStart) {
        if(currentMinutes < startMinutes) {
            return false;  // Before session start - don't trade
        }
    }

    // Check if session close is enabled
    if(EnableSessionClose) {
        if(currentMinutes >= closeMinutes) {
            return false;  // After session end - don't trade
        }
    }

    return true;  // Within trading session
}

//+------------------------------------------------------------------+
//| Check if It's Time to Close Session                               |
//| Returns true at exact close time (within 1 minute window)         |
//+------------------------------------------------------------------+
bool IsAtSessionCloseTime() {
    if(!EnableAutoSession || !EnableSessionClose) return false;

    // Get current time
    datetime now = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(now, dt);

    int currentMinutes = dt.hour * 60 + dt.min;
    int closeMinutes = ParseTimeToMinutes(SessionCloseTime);

    if(closeMinutes < 0) return false;

    // Trigger within 1 minute of close time
    return (currentMinutes == closeMinutes);
}

//+------------------------------------------------------------------+
//| Reset Daily Session Flags                                         |
//| Call this at the start of each day                                |
//+------------------------------------------------------------------+
void ResetDailySessionFlags() {
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);

    if(dt.day_of_year != lastSessionDay) {
        sessionStartTriggered = false;
        sessionCloseTriggered = false;
        lastSessionDay = dt.day_of_year;

        if(EnableAutoSession) {
            Log_SessionDailyReset();
        }
    }
}

//+------------------------------------------------------------------+
//| Check and Execute Session Close Actions                           |
//| Closes positions and/or pending orders at session end             |
//+------------------------------------------------------------------+
void CheckSessionClose() {
    // Skip if auto session is disabled
    if(!EnableAutoSession || !EnableSessionClose) return;

    // Reset daily flags if needed
    ResetDailySessionFlags();

    // Skip if already triggered today
    if(sessionCloseTriggered) return;

    // Check if it's close time
    if(!IsAtSessionCloseTime()) return;

    sessionCloseTriggered = true;

    int closedPositions = 0;
    int deletedOrders = 0;

    if(CloseAllOnSessionEnd) {
        closedPositions = CloseAllPositionsForSession();
    }

    if(DeletePendingOnEnd) {
        deletedOrders = DeleteAllPendingOrdersForSession();
    }

    Log_SessionEnd(closedPositions, deletedOrders, sessionRealizedProfit, 0);

    if(EnableAlerts && !MQLInfoInteger(MQL_TESTER)) {
        Alert("SUGAMARA: Session closed - positions=", closedPositions, " orders=", deletedOrders);
    }
}

//+------------------------------------------------------------------+
//| Close All Positions for Session End                               |
//| Returns number of positions closed                                |
//+------------------------------------------------------------------+
int CloseAllPositionsForSession() {
    int closed = 0;

    // Iterate backwards through positions
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;

        // Only close our EA's positions
        if(PositionGetInteger(POSITION_MAGIC) != MagicNumber) continue;

        // Only close positions on current symbol
        if(PositionGetString(POSITION_SYMBOL) != _Symbol) continue;

        if(trade.PositionClose(ticket)) {
            closed++;
            Log_PositionClosed(ticket, "SESSION_END", 0, 0);
        } else {
            Log_SystemError("Session", GetLastError(), StringFormat("Close position #%d failed", ticket));
        }
    }

    return closed;
}

//+------------------------------------------------------------------+
//| Delete All Pending Orders for Session End                         |
//| Returns number of orders deleted                                  |
//+------------------------------------------------------------------+
int DeleteAllPendingOrdersForSession() {
    int deleted = 0;

    // Iterate backwards through orders
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;

        // Only delete our EA's orders
        if(OrderGetInteger(ORDER_MAGIC) != MagicNumber) continue;

        // Only delete orders on current symbol
        if(OrderGetString(ORDER_SYMBOL) != _Symbol) continue;

        if(trade.OrderDelete(ticket)) {
            deleted++;
            Log_OrderCancelled(ticket, "SESSION_END");
        } else {
            Log_SystemError("Session", GetLastError(), StringFormat("Delete order #%d failed", ticket));
        }
    }

    return deleted;
}

//+------------------------------------------------------------------+
//| Get Session Status String                                         |
//| Returns human-readable session status                             |
//+------------------------------------------------------------------+
string GetSessionStatus() {
    if(!EnableAutoSession) return "DISABLED";

    if(IsWithinTradingSession()) {
        return "ACTIVE (" + SessionStartTime + "-" + SessionCloseTime + ")";
    } else {
        MqlDateTime dt;
        TimeToStruct(TimeCurrent(), dt);
        int currentMinutes = dt.hour * 60 + dt.min;
        int startMinutes = ParseTimeToMinutes(SessionStartTime);

        if(currentMinutes < startMinutes) {
            return "WAITING (starts " + SessionStartTime + ")";
        } else {
            return "CLOSED (ended " + SessionCloseTime + ")";
        }
    }
}

//+------------------------------------------------------------------+
//| Initialize Session Manager                                        |
//| Call this in OnInit()                                             |
//+------------------------------------------------------------------+
void InitializeSessionManager() {
    if(!EnableAutoSession) {
        Log_InitConfig("Session", "DISABLED");
        return;
    }

    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    lastSessionDay = dt.day_of_year;
    sessionStartTriggered = false;
    sessionCloseTriggered = false;

    int startMin = ParseTimeToMinutes(SessionStartTime);
    int closeMin = ParseTimeToMinutes(SessionCloseTime);

    if(startMin < 0 || closeMin < 0) {
        Log_SystemWarning("Session", "Invalid time format HH:MM");
    }

    Log_InitConfig("Session.Start", SessionStartTime);
    Log_InitConfig("Session.Close", SessionCloseTime);
    Log_InitConfig("Session.ClosePositions", CloseAllOnSessionEnd ? "YES" : "NO");
    Log_InitConfig("Session.DeletePending", DeletePendingOnEnd ? "YES" : "NO");
    Log_InitComplete("Session");
}

