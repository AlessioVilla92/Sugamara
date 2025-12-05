//+------------------------------------------------------------------+
//|                                                 GridHelpers.mqh  |
//|                        Sugamara - Grid Helper Functions          |
//|                                                                  |
//|  Specialized functions for Double Grid Neutral operations        |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| GRID IDENTIFICATION FUNCTIONS                                    |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Magic Number for Grid Side                                   |
//+------------------------------------------------------------------+
int GetGridMagic(ENUM_GRID_SIDE side) {
    if(side == GRID_A) {
        return MagicNumber + MAGIC_OFFSET_GRID_A;
    } else {
        return MagicNumber + MAGIC_OFFSET_GRID_B;
    }
}

//+------------------------------------------------------------------+
//| Get Grid Side from Magic Number                                  |
//+------------------------------------------------------------------+
ENUM_GRID_SIDE GetGridSideFromMagic(int magic) {
    int offset = magic - MagicNumber;
    if(offset >= MAGIC_OFFSET_GRID_B) {
        return GRID_B;
    }
    return GRID_A;
}

//+------------------------------------------------------------------+
//| Get Grid Side Name                                               |
//+------------------------------------------------------------------+
string GetGridSideName(ENUM_GRID_SIDE side) {
    return (side == GRID_A) ? "Grid A" : "Grid B";
}

//+------------------------------------------------------------------+
//| Get Grid Zone Name                                               |
//+------------------------------------------------------------------+
string GetGridZoneName(ENUM_GRID_ZONE zone) {
    return (zone == ZONE_UPPER) ? "Upper" : "Lower";
}

//+------------------------------------------------------------------+
//| Get Full Grid Level Identifier                                   |
//+------------------------------------------------------------------+
string GetGridLevelID(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    return GetGridSideName(side) + "-" + GetGridZoneName(zone) + "-L" + IntegerToString(level + 1);
}

//+------------------------------------------------------------------+
//| GRID ORDER TYPE FUNCTIONS                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Order Type for Grid Position                                 |
//| Grid A Upper: Buy Limit  | Grid A Lower: Sell Stop               |
//| Grid B Upper: Sell Limit | Grid B Lower: Buy Stop                |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetGridOrderType(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone) {
    if(side == GRID_A) {
        if(zone == ZONE_UPPER) {
            return ORDER_TYPE_BUY_LIMIT;   // Grid A Upper: Buy Limit
        } else {
            return ORDER_TYPE_SELL_STOP;   // Grid A Lower: Sell Stop
        }
    } else {  // GRID_B
        if(zone == ZONE_UPPER) {
            return ORDER_TYPE_SELL_LIMIT;  // Grid B Upper: Sell Limit
        } else {
            return ORDER_TYPE_BUY_STOP;    // Grid B Lower: Buy Stop
        }
    }
}

//+------------------------------------------------------------------+
//| Get Position Type When Order Fills                               |
//+------------------------------------------------------------------+
ENUM_POSITION_TYPE GetGridPositionType(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone) {
    if(side == GRID_A) {
        if(zone == ZONE_UPPER) {
            return POSITION_TYPE_BUY;   // Buy Limit fills to Buy
        } else {
            return POSITION_TYPE_SELL;  // Sell Stop fills to Sell
        }
    } else {  // GRID_B
        if(zone == ZONE_UPPER) {
            return POSITION_TYPE_SELL;  // Sell Limit fills to Sell
        } else {
            return POSITION_TYPE_BUY;   // Buy Stop fills to Buy
        }
    }
}

//+------------------------------------------------------------------+
//| Check if Order Type is Buy Direction                             |
//+------------------------------------------------------------------+
bool IsGridOrderBuy(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone) {
    ENUM_POSITION_TYPE posType = GetGridPositionType(side, zone);
    return (posType == POSITION_TYPE_BUY);
}

//+------------------------------------------------------------------+
//| Get Order Type String                                            |
//+------------------------------------------------------------------+
string GetOrderTypeString(ENUM_ORDER_TYPE orderType) {
    switch(orderType) {
        case ORDER_TYPE_BUY_LIMIT:  return "Buy Limit";
        case ORDER_TYPE_SELL_LIMIT: return "Sell Limit";
        case ORDER_TYPE_BUY_STOP:   return "Buy Stop";
        case ORDER_TYPE_SELL_STOP:  return "Sell Stop";
        case ORDER_TYPE_BUY:        return "Buy";
        case ORDER_TYPE_SELL:       return "Sell";
        default:                    return "Unknown";
    }
}

//+------------------------------------------------------------------+
//| GRID PRICE CALCULATION FUNCTIONS                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Entry Price for Grid Level                             |
//+------------------------------------------------------------------+
double CalculateGridLevelPrice(double entryPoint, ENUM_GRID_ZONE zone, int level, double spacingPips) {
    double spacingPrice = PipsToPoints(spacingPips);

    if(zone == ZONE_UPPER) {
        // Upper zone: prices above entry point
        return NormalizeDouble(entryPoint + (spacingPrice * (level + 1)), symbolDigits);
    } else {
        // Lower zone: prices below entry point
        return NormalizeDouble(entryPoint - (spacingPrice * (level + 1)), symbolDigits);
    }
}

//+------------------------------------------------------------------+
//| Calculate Take Profit for Grid Level                             |
//| RISPETTA NeutralMode:                                            |
//| - NEUTRAL_PURE: TP fisso (Spacing × TP_Ratio_Pure)               |
//| - NEUTRAL_CASCADE/RANGEBOX: TP cascade (Entry livello precedente)|
//+------------------------------------------------------------------+
double CalculateCascadeTP(double entryPointPrice, ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone,
                          int level, double spacingPips, int totalLevels) {

    double spacingPrice = PipsToPoints(spacingPips);
    bool isBuy = IsGridOrderBuy(side, zone);
    double orderEntryPrice = CalculateGridLevelPrice(entryPointPrice, zone, level, spacingPips);

    //=================================================================
    // NEUTRAL_PURE: TP FISSO (Spacing × Ratio)
    //=================================================================
    if(NeutralMode == NEUTRAL_PURE) {
        double tpDistance = spacingPrice * TP_Ratio_Pure;
        if(isBuy) {
            return NormalizeDouble(orderEntryPrice + tpDistance, symbolDigits);
        } else {
            return NormalizeDouble(orderEntryPrice - tpDistance, symbolDigits);
        }
    }

    //=================================================================
    // NEUTRAL_CASCADE e NEUTRAL_RANGEBOX: TP CASCADE
    //=================================================================

    // Final level uses fixed TP (non ha livello precedente)
    if(level >= totalLevels - 1) {
        double finalTP_Price = PipsToPoints(FinalLevel_TP_Pips);
        if(isBuy) {
            return NormalizeDouble(orderEntryPrice + finalTP_Price, symbolDigits);
        } else {
            return NormalizeDouble(orderEntryPrice - finalTP_Price, symbolDigits);
        }
    }

    // CASCADE MODE: Decide tra PERFECT e RATIO
    if(CascadeMode == CASCADE_PERFECT) {
        // Perfect Cascade: TP = Entry del livello precedente (verso entry point)
        if(level == 0) {
            // Level 1: TP = Entry Point centrale
            return entryPointPrice;
        } else {
            // Livelli successivi: TP = Entry del livello precedente
            return CalculateGridLevelPrice(entryPointPrice, zone, level - 1, spacingPips);
        }
    }

    // RATIO MODE: TP = Spacing × Ratio
    if(CascadeMode == CASCADE_RATIO) {
        double tpDistance = spacingPrice * CascadeTP_Ratio;
        if(isBuy) {
            return NormalizeDouble(orderEntryPrice + tpDistance, symbolDigits);
        } else {
            return NormalizeDouble(orderEntryPrice - tpDistance, symbolDigits);
        }
    }

    // Fallback: Use fixed TP
    double fixedTP = PipsToPoints(FinalLevel_TP_Pips);
    if(isBuy) {
        return NormalizeDouble(orderEntryPrice + fixedTP, symbolDigits);
    } else {
        return NormalizeDouble(orderEntryPrice - fixedTP, symbolDigits);
    }
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss for Grid Level                               |
//+------------------------------------------------------------------+
double CalculateGridSL(double entryPoint, ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone,
                       int level, double spacingPips, int totalLevels) {

    if(!UseGlobalStopLoss && !UseIndividualSL) {
        return 0;  // No SL
    }

    bool isBuy = IsGridOrderBuy(side, zone);
    double levelPrice = CalculateGridLevelPrice(entryPoint, zone, level, spacingPips);

    // Individual SL
    if(UseIndividualSL) {
        double slDistance = PipsToPoints(IndividualSL_Pips);
        if(isBuy) {
            return NormalizeDouble(levelPrice - slDistance, symbolDigits);
        } else {
            return NormalizeDouble(levelPrice + slDistance, symbolDigits);
        }
    }

    // Global SL (% of range)
    if(UseGlobalStopLoss) {
        double totalRange = spacingPips * totalLevels;
        double slDistance = PipsToPoints(totalRange * GlobalSL_Percent / 100.0);

        if(zone == ZONE_UPPER) {
            // Upper zone: SL above the range
            return NormalizeDouble(entryPoint + PipsToPoints(totalRange) + slDistance, symbolDigits);
        } else {
            // Lower zone: SL below the range
            return NormalizeDouble(entryPoint - PipsToPoints(totalRange) - slDistance, symbolDigits);
        }
    }

    return 0;
}

//+------------------------------------------------------------------+
//| GRID LOT CALCULATION FUNCTIONS                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Lot Size for Grid Level                                |
//+------------------------------------------------------------------+
double CalculateGridLotSize(int level) {
    double lot = BaseLot;

    if(LotMode == LOT_PROGRESSIVE) {
        // Progressive: Lot = BaseLot × Multiplier^level
        lot = BaseLot * MathPow(LotMultiplier, level);
    }
    // LOT_UNIFORM: Keep BaseLot

    // Apply limits and normalize
    return NormalizeLotSize(lot);
}

//+------------------------------------------------------------------+
//| Calculate Total Lot Size for All Levels                          |
//+------------------------------------------------------------------+
double CalculateTotalGridLots(int levels) {
    double totalLot = 0;

    for(int i = 0; i < levels; i++) {
        totalLot += CalculateGridLotSize(i);
    }

    return totalLot;
}

//+------------------------------------------------------------------+
//| Check if Total Lots Exceed Maximum                               |
//+------------------------------------------------------------------+
bool IsWithinMaxTotalLot(int levelsPerSide) {
    // Total = 2 grids × 2 zones × levels
    double totalLots = CalculateTotalGridLots(levelsPerSide) * 4;
    return (totalLots <= MaxTotalLot);
}

//+------------------------------------------------------------------+
//| GRID STATUS FUNCTIONS                                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Array Reference for Grid Zone                                |
//+------------------------------------------------------------------+
void GetGridArrays(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone,
                   ulong &tickets[], double &entryPrices[], double &tpPrices[],
                   double &slPrices[], double &lotSizes[], ENUM_ORDER_STATUS &statuses[]) {

    if(side == GRID_A) {
        if(zone == ZONE_UPPER) {
            ArrayCopy(tickets, gridA_Upper_Tickets);
            ArrayCopy(entryPrices, gridA_Upper_EntryPrices);
            ArrayCopy(tpPrices, gridA_Upper_TP);
            ArrayCopy(slPrices, gridA_Upper_SL);
            ArrayCopy(lotSizes, gridA_Upper_Lots);
            ArrayCopy(statuses, gridA_Upper_Status);
        } else {
            ArrayCopy(tickets, gridA_Lower_Tickets);
            ArrayCopy(entryPrices, gridA_Lower_EntryPrices);
            ArrayCopy(tpPrices, gridA_Lower_TP);
            ArrayCopy(slPrices, gridA_Lower_SL);
            ArrayCopy(lotSizes, gridA_Lower_Lots);
            ArrayCopy(statuses, gridA_Lower_Status);
        }
    } else {
        if(zone == ZONE_UPPER) {
            ArrayCopy(tickets, gridB_Upper_Tickets);
            ArrayCopy(entryPrices, gridB_Upper_EntryPrices);
            ArrayCopy(tpPrices, gridB_Upper_TP);
            ArrayCopy(slPrices, gridB_Upper_SL);
            ArrayCopy(lotSizes, gridB_Upper_Lots);
            ArrayCopy(statuses, gridB_Upper_Status);
        } else {
            ArrayCopy(tickets, gridB_Lower_Tickets);
            ArrayCopy(entryPrices, gridB_Lower_EntryPrices);
            ArrayCopy(tpPrices, gridB_Lower_TP);
            ArrayCopy(slPrices, gridB_Lower_SL);
            ArrayCopy(lotSizes, gridB_Lower_Lots);
            ArrayCopy(statuses, gridB_Lower_Status);
        }
    }
}

//+------------------------------------------------------------------+
//| Count Active Orders in Grid Zone                                 |
//+------------------------------------------------------------------+
int CountActiveOrdersInZone(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone) {
    int count = 0;
    ENUM_ORDER_STATUS statuses[];

    if(side == GRID_A) {
        if(zone == ZONE_UPPER) {
            ArrayCopy(statuses, gridA_Upper_Status);
        } else {
            ArrayCopy(statuses, gridA_Lower_Status);
        }
    } else {
        if(zone == ZONE_UPPER) {
            ArrayCopy(statuses, gridB_Upper_Status);
        } else {
            ArrayCopy(statuses, gridB_Lower_Status);
        }
    }

    for(int i = 0; i < ArraySize(statuses); i++) {
        if(statuses[i] == ORDER_PENDING || statuses[i] == ORDER_FILLED) {
            count++;
        }
    }

    return count;
}

//+------------------------------------------------------------------+
//| Count Total Active Orders in Grid Side                           |
//+------------------------------------------------------------------+
int CountActiveOrdersInGrid(ENUM_GRID_SIDE side) {
    return CountActiveOrdersInZone(side, ZONE_UPPER) + CountActiveOrdersInZone(side, ZONE_LOWER);
}

//+------------------------------------------------------------------+
//| Count Filled Positions in Zone                                   |
//+------------------------------------------------------------------+
int CountFilledPositionsInZone(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone) {
    int count = 0;
    ENUM_ORDER_STATUS statuses[];

    if(side == GRID_A) {
        if(zone == ZONE_UPPER) {
            ArrayCopy(statuses, gridA_Upper_Status);
        } else {
            ArrayCopy(statuses, gridA_Lower_Status);
        }
    } else {
        if(zone == ZONE_UPPER) {
            ArrayCopy(statuses, gridB_Upper_Status);
        } else {
            ArrayCopy(statuses, gridB_Lower_Status);
        }
    }

    for(int i = 0; i < ArraySize(statuses); i++) {
        if(statuses[i] == ORDER_FILLED) {
            count++;
        }
    }

    return count;
}

//+------------------------------------------------------------------+
//| GRID BALANCE FUNCTIONS                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check Grid Balance (Grid A vs Grid B)                            |
//+------------------------------------------------------------------+
bool IsGridBalanced() {
    int gridA_Active = CountActiveOrdersInGrid(GRID_A);
    int gridB_Active = CountActiveOrdersInGrid(GRID_B);

    // Grids should have same number of active orders
    return (gridA_Active == gridB_Active);
}

//+------------------------------------------------------------------+
//| Calculate Grid Imbalance                                         |
//+------------------------------------------------------------------+
int GetGridImbalance() {
    int gridA_Active = CountActiveOrdersInGrid(GRID_A);
    int gridB_Active = CountActiveOrdersInGrid(GRID_B);

    return gridA_Active - gridB_Active;
}

//+------------------------------------------------------------------+
//| Check if Exposure is Neutral                                     |
//+------------------------------------------------------------------+
bool IsExposureNeutral() {
    CalculateNetExposure();
    return isNeutral;
}

//+------------------------------------------------------------------+
//| Get Net Exposure in Lots                                         |
//+------------------------------------------------------------------+
double GetNetExposureLots() {
    CalculateNetExposure();
    return netExposure;
}

//+------------------------------------------------------------------+
//| GRID VISUALIZATION HELPERS                                       |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Color for Grid Line                                          |
//+------------------------------------------------------------------+
color GetGridLineColor(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone) {
    if(side == GRID_A) {
        return (zone == ZONE_UPPER) ? COLOR_GRID_A_UPPER : COLOR_GRID_A_LOWER;
    } else {
        return (zone == ZONE_UPPER) ? COLOR_GRID_B_UPPER : COLOR_GRID_B_LOWER;
    }
}

//+------------------------------------------------------------------+
//| Get Object Name Prefix for Grid                                  |
//+------------------------------------------------------------------+
string GetGridObjectPrefix(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone) {
    string prefix = "SUGAMARA_";
    prefix += (side == GRID_A) ? "GA_" : "GB_";
    prefix += (zone == ZONE_UPPER) ? "UP_" : "LO_";
    return prefix;
}

//+------------------------------------------------------------------+
//| Create Grid Level Line on Chart                                  |
//+------------------------------------------------------------------+
void CreateGridLevelLine(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, double price) {
    if(!ShowGridLines) return;

    string name = GetGridObjectPrefix(side, zone) + "L" + IntegerToString(level + 1);
    color clr = GetGridLineColor(side, zone);

    CreateHLine(name, price, clr, 1, STYLE_DOT);
}

//+------------------------------------------------------------------+
//| Create TP Line on Chart                                          |
//+------------------------------------------------------------------+
void CreateGridTPLine(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, double price) {
    if(!ShowGridLines) return;

    string name = GetGridObjectPrefix(side, zone) + "TP" + IntegerToString(level + 1);
    color clr = (side == GRID_A) ? COLOR_GRID_A_TP : COLOR_GRID_B_TP;

    CreateHLine(name, price, clr, 1, STYLE_DASH);
}

//+------------------------------------------------------------------+
//| Delete All Grid Objects                                          |
//+------------------------------------------------------------------+
void DeleteAllGridObjects() {
    DeleteObjectsByPrefix("SUGAMARA_GA_");
    DeleteObjectsByPrefix("SUGAMARA_GB_");
    DeleteObjectsByPrefix("SUGAMARA_ENTRY");
    DeleteObjectsByPrefix("SUGAMARA_RANGE");
}

//+------------------------------------------------------------------+
//| Draw Entry Point Line                                            |
//+------------------------------------------------------------------+
void DrawEntryPointLine() {
    if(!ShowGridLines) return;

    CreateHLine("SUGAMARA_ENTRY", entryPoint, COLOR_ENTRY_POINT, 2, STYLE_SOLID);
}

//+------------------------------------------------------------------+
//| Draw Range Boundaries                                            |
//+------------------------------------------------------------------+
void DrawRangeBoundaries() {
    if(!ShowRangeBox) return;

    CreateHLine("SUGAMARA_RANGE_UPPER", rangeUpperBound, COLOR_RANGE_UPPER, 1, STYLE_DASHDOT);
    CreateHLine("SUGAMARA_RANGE_LOWER", rangeLowerBound, COLOR_RANGE_LOWER, 1, STYLE_DASHDOT);
}

//+------------------------------------------------------------------+
//| GRID VALIDATION FUNCTIONS                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Validate Grid Level Index                                        |
//+------------------------------------------------------------------+
bool IsValidLevelIndex(int level) {
    return (level >= 0 && level < GridLevelsPerSide && level < MAX_GRID_LEVELS);
}

//+------------------------------------------------------------------+
//| Check if Level Should be Active                                  |
//+------------------------------------------------------------------+
bool ShouldLevelBeActive(int level) {
    return (level < GridLevelsPerSide);
}

//+------------------------------------------------------------------+
//| Validate Grid Configuration                                      |
//+------------------------------------------------------------------+
bool ValidateGridConfiguration() {
    // Check levels
    if(GridLevelsPerSide < 3 || GridLevelsPerSide > MAX_GRID_LEVELS) {
        LogMessage(LOG_ERROR, "Invalid GridLevelsPerSide: " + IntegerToString(GridLevelsPerSide));
        return false;
    }

    // Check spacing
    if(currentSpacing_Pips < MIN_SPACING_PIPS) {
        LogMessage(LOG_ERROR, "Spacing too small: " + DoubleToString(currentSpacing_Pips, 1) + " pips");
        return false;
    }

    // Check total lots
    if(!IsWithinMaxTotalLot(GridLevelsPerSide)) {
        LogMessage(LOG_ERROR, "Total lots exceed MaxTotalLot: " + DoubleToString(MaxTotalLot, 2));
        return false;
    }

    // Check entry point
    if(entryPoint <= 0) {
        LogMessage(LOG_ERROR, "Invalid entry point: " + DoubleToString(entryPoint, symbolDigits));
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| CYCLIC REOPENING HELPERS                                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Check if Level Can Reopen                                        |
//+------------------------------------------------------------------+
bool CanLevelReopen(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(!EnableCyclicReopen) return false;

    // Check cooldown
    datetime lastClose = 0;
    if(side == GRID_A) {
        if(zone == ZONE_UPPER) {
            lastClose = gridA_Upper_LastClose[level];
        } else {
            lastClose = gridA_Lower_LastClose[level];
        }
    } else {
        if(zone == ZONE_UPPER) {
            lastClose = gridB_Upper_LastClose[level];
        } else {
            lastClose = gridB_Lower_LastClose[level];
        }
    }

    if(lastClose == 0) return true;  // Never closed, can open

    int elapsed = SecondsElapsed(lastClose);
    if(elapsed < CyclicCooldown_Seconds) {
        return false;  // Still in cooldown
    }

    // Check max cycles
    if(MaxCyclesPerLevel > 0) {
        int cycles = 0;
        if(side == GRID_A) {
            if(zone == ZONE_UPPER) {
                cycles = gridA_Upper_Cycles[level];
            } else {
                cycles = gridA_Lower_Cycles[level];
            }
        } else {
            if(zone == ZONE_UPPER) {
                cycles = gridB_Upper_Cycles[level];
            } else {
                cycles = gridB_Lower_Cycles[level];
            }
        }

        if(cycles >= MaxCyclesPerLevel) {
            return false;  // Max cycles reached
        }
    }

    return true;
}

//+------------------------------------------------------------------+
//| Check Price Level for Reopen Trigger                             |
//+------------------------------------------------------------------+
bool IsPriceAtReopenLevel(double levelPrice) {
    if(ReopenTrigger != REOPEN_PRICE_LEVEL) return true;

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double offsetPrice = PipsToPoints(ReopenOffset_Pips);

    return (MathAbs(currentPrice - levelPrice) <= offsetPrice);
}

//+------------------------------------------------------------------+
//| Increment Cycle Count for Level                                  |
//+------------------------------------------------------------------+
void IncrementCycleCount(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(side == GRID_A) {
        if(zone == ZONE_UPPER) {
            gridA_Upper_Cycles[level]++;
        } else {
            gridA_Lower_Cycles[level]++;
        }
    } else {
        if(zone == ZONE_UPPER) {
            gridB_Upper_Cycles[level]++;
        } else {
            gridB_Lower_Cycles[level]++;
        }
    }
}

//+------------------------------------------------------------------+
//| Record Close Time for Level                                      |
//+------------------------------------------------------------------+
void RecordCloseTime(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    datetime now = TimeCurrent();

    if(side == GRID_A) {
        if(zone == ZONE_UPPER) {
            gridA_Upper_LastClose[level] = now;
        } else {
            gridA_Lower_LastClose[level] = now;
        }
    } else {
        if(zone == ZONE_UPPER) {
            gridB_Upper_LastClose[level] = now;
        } else {
            gridB_Lower_LastClose[level] = now;
        }
    }
}

