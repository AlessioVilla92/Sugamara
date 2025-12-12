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

    // Validate parsed times
    if(startMinutes < 0 || closeMinutes < 0) {
        Print("WARNING: Invalid session time format. Using 09:30-17:00 defaults.");
        startMinutes = 9 * 60 + 30;   // 09:30
        closeMinutes = 17 * 60;        // 17:00
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

    // If it's a new day, reset the flags
    if(dt.day_of_year != lastSessionDay) {
        sessionStartTriggered = false;
        sessionCloseTriggered = false;
        lastSessionDay = dt.day_of_year;

        if(EnableAutoSession) {
            Print("SESSION MANAGER: Daily flags reset for day ", dt.day_of_year);
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

    // Mark as triggered to prevent multiple executions
    sessionCloseTriggered = true;

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  SESSION MANAGER: AUTOMATIC SESSION CLOSE TRIGGERED");
    Print("  Time: ", SessionCloseTime);
    Print("═══════════════════════════════════════════════════════════════════");

    int closedPositions = 0;
    int deletedOrders = 0;

    // Close all positions if enabled
    if(CloseAllOnSessionEnd) {
        Print("  Closing all positions...");
        closedPositions = CloseAllPositionsForSession();
    }

    // Delete all pending orders if enabled
    if(DeletePendingOnEnd) {
        Print("  Deleting all pending orders...");
        deletedOrders = DeleteAllPendingOrdersForSession();
    }

    Print("  SESSION CLOSE COMPLETE:");
    Print("    Positions Closed: ", closedPositions);
    Print("    Pending Orders Deleted: ", deletedOrders);
    Print("═══════════════════════════════════════════════════════════════════");

    if(EnableAlerts) {
        Alert("SUGAMARA: Session closed at ", SessionCloseTime,
              " | Closed: ", closedPositions, " positions, ",
              deletedOrders, " pending orders");
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

        // Close the position
        if(trade.PositionClose(ticket)) {
            closed++;
            Print("    Closed position #", ticket);
        } else {
            Print("    ERROR closing position #", ticket, ": ", GetLastError());
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

        // Delete the order
        if(trade.OrderDelete(ticket)) {
            deleted++;
            Print("    Deleted order #", ticket);
        } else {
            Print("    ERROR deleting order #", ticket, ": ", GetLastError());
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
        Print("SESSION MANAGER: Disabled");
        return;
    }

    // Reset daily flags
    MqlDateTime dt;
    TimeToStruct(TimeCurrent(), dt);
    lastSessionDay = dt.day_of_year;
    sessionStartTriggered = false;
    sessionCloseTriggered = false;

    // Validate time formats
    int startMin = ParseTimeToMinutes(SessionStartTime);
    int closeMin = ParseTimeToMinutes(SessionCloseTime);

    if(startMin < 0 || closeMin < 0) {
        Print("WARNING: Invalid session time format!");
        Print("  Expected format: HH:MM (e.g., 09:30)");
    }

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  SESSION MANAGER INITIALIZED");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  Auto Session: ", EnableAutoSession ? "ENABLED" : "DISABLED");

    if(EnableSessionStart) {
        Print("  Start Time: ", SessionStartTime, " (", startMin / 60, ":", startMin % 60, ")");
    }

    if(EnableSessionClose) {
        Print("  Close Time: ", SessionCloseTime, " (", closeMin / 60, ":", closeMin % 60, ")");
        Print("  Close Positions: ", CloseAllOnSessionEnd ? "YES" : "NO");
        Print("  Delete Pending: ", DeletePendingOnEnd ? "YES" : "NO");
    }

    Print("  Current Status: ", GetSessionStatus());
    Print("═══════════════════════════════════════════════════════════════════");
}

