//+------------------------------------------------------------------+
//|                                             RecoveryManager.mqh  |
//|                        Sugamara v5.9 - Recovery Manager          |
//|                                                                  |
//|  Recovery automatico ordini dopo riavvio MT5/VPS                 |
//|  - Scansiona ordini pendenti e posizioni aperte dal broker       |
//|  - Ricostruisce array interni (tickets, status, ecc.)            |
//|  - Calcola entry point dai livelli esistenti                     |
//|  - Permette ripresa operazioni senza intervento manuale          |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| RECOVERY GLOBAL VARIABLES                                        |
//+------------------------------------------------------------------+
bool g_recoveryPerformed = false;           // Flag: recovery eseguito in questa sessione
int g_recoveredOrdersCount = 0;             // Numero ordini pending recuperati
int g_recoveredPositionsCount = 0;          // Numero posizioni aperte recuperate
datetime g_lastRecoveryTime = 0;            // Timestamp ultimo recovery

// GlobalVariable keys per persistenza entry point
string GetEntryPointGlobalKey() {
    return "SUGAMARA_ENTRY_" + _Symbol;
}

string GetEntryPointTimeGlobalKey() {
    return "SUGAMARA_ENTRY_TIME_" + _Symbol;
}

//+------------------------------------------------------------------+
//| Check if there are existing Sugamara orders for this symbol      |
//| Returns true if at least 1 order/position found                  |
//+------------------------------------------------------------------+
bool HasExistingOrders() {
    int magicA = MagicNumber + MAGIC_OFFSET_GRID_A;
    int magicB = MagicNumber + MAGIC_OFFSET_GRID_B;

    // Check pending orders
    int totalOrders = OrdersTotal();
    for(int i = 0; i < totalOrders; i++) {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;

        if(OrderSelect(ticket)) {
            string symbol = OrderGetString(ORDER_SYMBOL);
            long magic = OrderGetInteger(ORDER_MAGIC);

            if(symbol == _Symbol && (magic == magicA || magic == magicB)) {
                return true;
            }
        }
    }

    // Check open positions
    int totalPositions = PositionsTotal();
    for(int i = 0; i < totalPositions; i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;

        if(PositionSelectByTicket(ticket)) {
            string symbol = PositionGetString(POSITION_SYMBOL);
            long magic = PositionGetInteger(POSITION_MAGIC);

            if(symbol == _Symbol && (magic == magicA || magic == magicB)) {
                return true;
            }
        }
    }

    return false;
}

//+------------------------------------------------------------------+
//| Main Recovery Function - Recovers all existing orders/positions  |
//| Returns true if recovery successful (at least 1 item recovered)  |
//+------------------------------------------------------------------+
bool RecoverExistingOrders() {
    Log_RecoveryStart(OrdersTotal(), PositionsTotal());

    g_recoveredOrdersCount = 0;
    g_recoveredPositionsCount = 0;

    ResetArraysForRecovery();

    bool ordersRecovered = RecoverPendingOrders();
    bool positionsRecovered = RecoverOpenPositions();

    double recoveredEntry = CalculateEntryPointFromRecoveredOrders();
    double savedEntry = LoadEntryPointFromGlobal();

    if(savedEntry > 0) {
        entryPoint = savedEntry;
        Log_Debug("Recovery", StringFormat("Entry from GlobalVar: %.5f", entryPoint));
    } else if(recoveredEntry > 0) {
        entryPoint = recoveredEntry;
        Log_Debug("Recovery", StringFormat("Entry from orders: %.5f", entryPoint));
    } else {
        entryPoint = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        Log_Debug("Recovery", StringFormat("Entry from current price: %.5f", entryPoint));
    }

    entryPointTime = TimeCurrent();

    int totalRecovered = g_recoveredOrdersCount + g_recoveredPositionsCount;

    if(totalRecovered > 0) {
        g_recoveryPerformed = true;
        g_lastRecoveryTime = TimeCurrent();

        CalculateBreakoutLevels();

        Log_RecoveryComplete(g_recoveredOrdersCount, g_recoveredPositionsCount, entryPoint);
        return true;
    }

    Log_SystemWarning("Recovery", "No orders/positions found");
    return false;
}

//+------------------------------------------------------------------+
//| Reset arrays for recovery (without full initialization)          |
//+------------------------------------------------------------------+
void ResetArraysForRecovery() {
    // Grid A Upper
    ArrayInitialize(gridA_Upper_Tickets, 0);
    ArrayInitialize(gridA_Upper_EntryPrices, 0);
    ArrayInitialize(gridA_Upper_Lots, 0);
    ArrayInitialize(gridA_Upper_TP, 0);
    ArrayInitialize(gridA_Upper_SL, 0);
    ArrayInitialize(gridA_Upper_LastClose, 0);
    ArrayInitialize(gridA_Upper_Cycles, 0);
    for(int i = 0; i < MAX_GRID_LEVELS; i++) gridA_Upper_Status[i] = ORDER_NONE;

    // Grid A Lower
    ArrayInitialize(gridA_Lower_Tickets, 0);
    ArrayInitialize(gridA_Lower_EntryPrices, 0);
    ArrayInitialize(gridA_Lower_Lots, 0);
    ArrayInitialize(gridA_Lower_TP, 0);
    ArrayInitialize(gridA_Lower_SL, 0);
    ArrayInitialize(gridA_Lower_LastClose, 0);
    ArrayInitialize(gridA_Lower_Cycles, 0);
    for(int i = 0; i < MAX_GRID_LEVELS; i++) gridA_Lower_Status[i] = ORDER_NONE;

    // Grid B Upper
    ArrayInitialize(gridB_Upper_Tickets, 0);
    ArrayInitialize(gridB_Upper_EntryPrices, 0);
    ArrayInitialize(gridB_Upper_Lots, 0);
    ArrayInitialize(gridB_Upper_TP, 0);
    ArrayInitialize(gridB_Upper_SL, 0);
    ArrayInitialize(gridB_Upper_LastClose, 0);
    ArrayInitialize(gridB_Upper_Cycles, 0);
    for(int i = 0; i < MAX_GRID_LEVELS; i++) gridB_Upper_Status[i] = ORDER_NONE;

    // Grid B Lower
    ArrayInitialize(gridB_Lower_Tickets, 0);
    ArrayInitialize(gridB_Lower_EntryPrices, 0);
    ArrayInitialize(gridB_Lower_Lots, 0);
    ArrayInitialize(gridB_Lower_TP, 0);
    ArrayInitialize(gridB_Lower_SL, 0);
    ArrayInitialize(gridB_Lower_LastClose, 0);
    ArrayInitialize(gridB_Lower_Cycles, 0);
    for(int i = 0; i < MAX_GRID_LEVELS; i++) gridB_Lower_Status[i] = ORDER_NONE;
}

//+------------------------------------------------------------------+
//| Recover Pending Orders from broker                               |
//+------------------------------------------------------------------+
bool RecoverPendingOrders() {
    int magicA = MagicNumber + MAGIC_OFFSET_GRID_A;
    int magicB = MagicNumber + MAGIC_OFFSET_GRID_B;
    int recovered = 0;

    int totalOrders = OrdersTotal();

    for(int i = 0; i < totalOrders; i++) {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;

        if(!OrderSelect(ticket)) continue;

        string symbol = OrderGetString(ORDER_SYMBOL);
        long magic = OrderGetInteger(ORDER_MAGIC);
        string comment = OrderGetString(ORDER_COMMENT);

        if(symbol != _Symbol) continue;
        if(magic != magicA && magic != magicB) continue;

        ENUM_GRID_SIDE side;
        ENUM_GRID_ZONE zone;
        int level = ParseGridLevelFromComment(comment, side, zone);

        if(level < 0 || level >= MAX_GRID_LEVELS) {
            Log_Debug("Recovery", StringFormat("Cannot parse comment: %s", comment));
            continue;
        }

        double entryPrice = OrderGetDouble(ORDER_PRICE_OPEN);
        double lot = OrderGetDouble(ORDER_VOLUME_CURRENT);
        double tp = OrderGetDouble(ORDER_TP);
        double sl = OrderGetDouble(ORDER_SL);

        if(side == GRID_A) {
            if(zone == ZONE_UPPER) {
                gridA_Upper_Tickets[level] = ticket;
                gridA_Upper_EntryPrices[level] = entryPrice;
                gridA_Upper_Lots[level] = lot;
                gridA_Upper_TP[level] = tp;
                gridA_Upper_SL[level] = sl;
                gridA_Upper_Status[level] = ORDER_PENDING;
            } else {
                gridA_Lower_Tickets[level] = ticket;
                gridA_Lower_EntryPrices[level] = entryPrice;
                gridA_Lower_Lots[level] = lot;
                gridA_Lower_TP[level] = tp;
                gridA_Lower_SL[level] = sl;
                gridA_Lower_Status[level] = ORDER_PENDING;
            }
        } else {
            if(zone == ZONE_UPPER) {
                gridB_Upper_Tickets[level] = ticket;
                gridB_Upper_EntryPrices[level] = entryPrice;
                gridB_Upper_Lots[level] = lot;
                gridB_Upper_TP[level] = tp;
                gridB_Upper_SL[level] = sl;
                gridB_Upper_Status[level] = ORDER_PENDING;
            } else {
                gridB_Lower_Tickets[level] = ticket;
                gridB_Lower_EntryPrices[level] = entryPrice;
                gridB_Lower_Lots[level] = lot;
                gridB_Lower_TP[level] = tp;
                gridB_Lower_SL[level] = sl;
                gridB_Lower_Status[level] = ORDER_PENDING;
            }
        }

        recovered++;
        Log_Debug("Recovery", StringFormat("PENDING %s ticket=%d price=%.5f lot=%.2f",
                  comment, ticket, entryPrice, lot));
    }

    g_recoveredOrdersCount = recovered;
    return (recovered > 0);
}

//+------------------------------------------------------------------+
//| Recover Open Positions from broker                               |
//+------------------------------------------------------------------+
bool RecoverOpenPositions() {
    int magicA = MagicNumber + MAGIC_OFFSET_GRID_A;
    int magicB = MagicNumber + MAGIC_OFFSET_GRID_B;
    int recovered = 0;

    int totalPositions = PositionsTotal();

    for(int i = 0; i < totalPositions; i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;

        if(!PositionSelectByTicket(ticket)) continue;

        string symbol = PositionGetString(POSITION_SYMBOL);
        long magic = PositionGetInteger(POSITION_MAGIC);
        string comment = PositionGetString(POSITION_COMMENT);

        if(symbol != _Symbol) continue;
        if(magic != magicA && magic != magicB) continue;

        ENUM_GRID_SIDE side;
        ENUM_GRID_ZONE zone;
        int level = ParseGridLevelFromComment(comment, side, zone);

        if(level < 0 || level >= MAX_GRID_LEVELS) {
            Log_Debug("Recovery", StringFormat("Cannot parse comment: %s", comment));
            continue;
        }

        double entryPrice = PositionGetDouble(POSITION_PRICE_OPEN);
        double lot = PositionGetDouble(POSITION_VOLUME);
        double tp = PositionGetDouble(POSITION_TP);
        double sl = PositionGetDouble(POSITION_SL);
        double profit = PositionGetDouble(POSITION_PROFIT);

        if(side == GRID_A) {
            if(zone == ZONE_UPPER) {
                gridA_Upper_Tickets[level] = ticket;
                gridA_Upper_EntryPrices[level] = entryPrice;
                gridA_Upper_Lots[level] = lot;
                gridA_Upper_TP[level] = tp;
                gridA_Upper_SL[level] = sl;
                gridA_Upper_Status[level] = ORDER_FILLED;
            } else {
                gridA_Lower_Tickets[level] = ticket;
                gridA_Lower_EntryPrices[level] = entryPrice;
                gridA_Lower_Lots[level] = lot;
                gridA_Lower_TP[level] = tp;
                gridA_Lower_SL[level] = sl;
                gridA_Lower_Status[level] = ORDER_FILLED;
            }
        } else {
            if(zone == ZONE_UPPER) {
                gridB_Upper_Tickets[level] = ticket;
                gridB_Upper_EntryPrices[level] = entryPrice;
                gridB_Upper_Lots[level] = lot;
                gridB_Upper_TP[level] = tp;
                gridB_Upper_SL[level] = sl;
                gridB_Upper_Status[level] = ORDER_FILLED;
            } else {
                gridB_Lower_Tickets[level] = ticket;
                gridB_Lower_EntryPrices[level] = entryPrice;
                gridB_Lower_Lots[level] = lot;
                gridB_Lower_TP[level] = tp;
                gridB_Lower_SL[level] = sl;
                gridB_Lower_Status[level] = ORDER_FILLED;
            }
        }

        recovered++;
        Log_Debug("Recovery", StringFormat("POSITION %s ticket=%d price=%.5f lot=%.2f profit=%.2f",
                  comment, ticket, entryPrice, lot, profit));
    }

    g_recoveredPositionsCount = recovered;
    return (recovered > 0);
}

//+------------------------------------------------------------------+
//| Parse Grid Level from order/position comment                     |
//| Format: "Grid A-Upper-L1", "Grid B-Lower-L5", etc.               |
//| Returns level (0-indexed) or -1 if not recognized                |
//+------------------------------------------------------------------+
int ParseGridLevelFromComment(string comment, ENUM_GRID_SIDE &side, ENUM_GRID_ZONE &zone) {
    // Default values
    side = GRID_A;
    zone = ZONE_UPPER;

    // Check for Grid A or Grid B
    if(StringFind(comment, "Grid A") >= 0) {
        side = GRID_A;
    } else if(StringFind(comment, "Grid B") >= 0) {
        side = GRID_B;
    } else {
        return -1;  // Not a Sugamara grid order
    }

    // Check for Upper or Lower zone
    if(StringFind(comment, "Upper") >= 0) {
        zone = ZONE_UPPER;
    } else if(StringFind(comment, "Lower") >= 0) {
        zone = ZONE_LOWER;
    } else {
        return -1;  // Zone not found
    }

    // Extract level number (L1, L2, etc.)
    int levelPos = StringFind(comment, "-L");
    if(levelPos < 0) {
        return -1;  // Level marker not found
    }

    // Get the number after "-L"
    string levelStr = StringSubstr(comment, levelPos + 2);

    // Remove any trailing characters (like spaces)
    int spacePos = StringFind(levelStr, " ");
    if(spacePos > 0) {
        levelStr = StringSubstr(levelStr, 0, spacePos);
    }

    int levelNum = (int)StringToInteger(levelStr);

    if(levelNum < 1 || levelNum > MAX_GRID_LEVELS) {
        return -1;  // Invalid level number
    }

    // Return 0-indexed level
    return levelNum - 1;
}

//+------------------------------------------------------------------+
//| Calculate Entry Point from recovered order prices                |
//| Uses the median of all recovered entry prices                    |
//+------------------------------------------------------------------+
double CalculateEntryPointFromRecoveredOrders() {
    double prices[];
    int count = 0;

    // Collect all entry prices
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        if(gridA_Upper_EntryPrices[i] > 0) {
            ArrayResize(prices, count + 1);
            prices[count++] = gridA_Upper_EntryPrices[i];
        }
        if(gridA_Lower_EntryPrices[i] > 0) {
            ArrayResize(prices, count + 1);
            prices[count++] = gridA_Lower_EntryPrices[i];
        }
        if(gridB_Upper_EntryPrices[i] > 0) {
            ArrayResize(prices, count + 1);
            prices[count++] = gridB_Upper_EntryPrices[i];
        }
        if(gridB_Lower_EntryPrices[i] > 0) {
            ArrayResize(prices, count + 1);
            prices[count++] = gridB_Lower_EntryPrices[i];
        }
    }

    if(count == 0) return 0;

    // Sort prices
    ArraySort(prices);

    // Calculate median (better than average - resistant to outliers)
    double median;
    if(count % 2 == 0) {
        median = (prices[count/2 - 1] + prices[count/2]) / 2.0;
    } else {
        median = prices[count/2];
    }

    // Round to symbol digits
    return NormalizeDouble(median, symbolDigits);
}

//+------------------------------------------------------------------+
//| Save Entry Point to GlobalVariable (persistent across restarts)  |
//+------------------------------------------------------------------+
void SaveEntryPointToGlobal() {
    if(entryPoint <= 0) return;

    string keyEntry = GetEntryPointGlobalKey();
    string keyTime = GetEntryPointTimeGlobalKey();

    GlobalVariableSet(keyEntry, entryPoint);
    GlobalVariableSet(keyTime, (double)entryPointTime);

    Log_Debug("Recovery", StringFormat("Entry saved to GlobalVar: %.5f", entryPoint));
}

//+------------------------------------------------------------------+
//| Load Entry Point from GlobalVariable                             |
//| Returns 0 if not found or expired                                |
//+------------------------------------------------------------------+
double LoadEntryPointFromGlobal() {
    string keyEntry = GetEntryPointGlobalKey();
    string keyTime = GetEntryPointTimeGlobalKey();

    // Check if global variable exists
    if(!GlobalVariableCheck(keyEntry)) {
        return 0;
    }

    double savedEntry = GlobalVariableGet(keyEntry);

    // Validate the saved entry point
    if(savedEntry <= 0) {
        return 0;
    }

    if(GlobalVariableCheck(keyTime)) {
        datetime savedTime = (datetime)GlobalVariableGet(keyTime);
        datetime now = TimeCurrent();

        if(now - savedTime > 7 * 24 * 60 * 60) {
            Log_Debug("Recovery", "Saved entry older than 7 days - ignoring");
            return 0;
        }
    }

    return savedEntry;
}

//+------------------------------------------------------------------+
//| Delete Entry Point GlobalVariables (cleanup)                     |
//+------------------------------------------------------------------+
void ClearEntryPointGlobal() {
    string keyEntry = GetEntryPointGlobalKey();
    string keyTime = GetEntryPointTimeGlobalKey();

    if(GlobalVariableCheck(keyEntry)) {
        GlobalVariableDel(keyEntry);
    }
    if(GlobalVariableCheck(keyTime)) {
        GlobalVariableDel(keyTime);
    }
}

//+------------------------------------------------------------------+
//| Force Recovery from Broker (manual trigger via button)           |
//| Same as RecoverExistingOrders but can be called anytime          |
//+------------------------------------------------------------------+
bool ForceRecoveryFromBroker() {
    if(systemState == STATE_ACTIVE) {
        Log_Debug("Recovery", "Manual recovery - system already active");
    }

    return RecoverExistingOrders();
}

//+------------------------------------------------------------------+
//| Log Detailed Recovery Report                                     |
//+------------------------------------------------------------------+
void LogRecoveryReport() {
    Log_Header("RECOVERY REPORT");
    Log_KeyValue("Symbol", _Symbol);
    Log_KeyValueNum("Pending Orders", g_recoveredOrdersCount, 0);
    Log_KeyValueNum("Open Positions", g_recoveredPositionsCount, 0);
    Log_KeyValueNum("Entry Point", entryPoint, symbolDigits);
    Log_Separator();

    // Grid A
    Log_SubHeader("GRID A (BUY)");
    bool hasGridA = false;
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_Tickets[i] > 0) {
            hasGridA = true;
            Log_KeyValue(StringFormat("Upper L%d", i+1),
                        StringFormat("#%d @ %.5f [%s]", gridA_Upper_Tickets[i],
                                    gridA_Upper_EntryPrices[i], GetRecoveryStatusName(gridA_Upper_Status[i])));
        }
        if(gridA_Lower_Tickets[i] > 0) {
            hasGridA = true;
            Log_KeyValue(StringFormat("Lower L%d", i+1),
                        StringFormat("#%d @ %.5f [%s]", gridA_Lower_Tickets[i],
                                    gridA_Lower_EntryPrices[i], GetRecoveryStatusName(gridA_Lower_Status[i])));
        }
    }
    if(!hasGridA) Log_KeyValue("Status", "No orders recovered");

    // Grid B
    Log_SubHeader("GRID B (SELL)");
    bool hasGridB = false;
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_Tickets[i] > 0) {
            hasGridB = true;
            Log_KeyValue(StringFormat("Upper L%d", i+1),
                        StringFormat("#%d @ %.5f [%s]", gridB_Upper_Tickets[i],
                                    gridB_Upper_EntryPrices[i], GetRecoveryStatusName(gridB_Upper_Status[i])));
        }
        if(gridB_Lower_Tickets[i] > 0) {
            hasGridB = true;
            Log_KeyValue(StringFormat("Lower L%d", i+1),
                        StringFormat("#%d @ %.5f [%s]", gridB_Lower_Tickets[i],
                                    gridB_Lower_EntryPrices[i], GetRecoveryStatusName(gridB_Lower_Status[i])));
        }
    }
    if(!hasGridB) Log_KeyValue("Status", "No orders recovered");
    Log_Separator();
}

//+------------------------------------------------------------------+
//| Get Order Status Name for logging (Recovery version)             |
//| Note: Uses GetOrderStatusText from GridHelpers.mqh if available  |
//+------------------------------------------------------------------+
string GetRecoveryStatusName(ENUM_ORDER_STATUS status) {
    switch(status) {
        case ORDER_NONE:       return "NONE";
        case ORDER_PENDING:    return "PENDING";
        case ORDER_FILLED:     return "FILLED";
        case ORDER_CLOSED:     return "CLOSED";
        case ORDER_CLOSED_TP:  return "CLOSED_TP";
        case ORDER_CLOSED_SL:  return "CLOSED_SL";
        case ORDER_CANCELLED:  return "CANCELLED";
        case ORDER_ERROR:      return "ERROR";
        default:               return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Check if Recovery was performed in this session                  |
//+------------------------------------------------------------------+
bool WasRecoveryPerformed() {
    return g_recoveryPerformed;
}

//+------------------------------------------------------------------+
//| Get Recovery Statistics                                          |
//+------------------------------------------------------------------+
int GetRecoveredOrdersCount() {
    return g_recoveredOrdersCount;
}

int GetRecoveredPositionsCount() {
    return g_recoveredPositionsCount;
}

datetime GetLastRecoveryTime() {
    return g_lastRecoveryTime;
}

//+------------------------------------------------------------------+
