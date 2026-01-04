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
//| STANDARD MODE:                                                   |
//|   Grid A Upper: Buy Limit  | Grid A Lower: Sell Stop             |
//| v8.0: Grid A = SEMPRE BUY, Grid B = SEMPRE SELL (DEFAULT)       |
//|   Grid A Upper: BUY STOP   | Grid A Lower: BUY LIMIT            |
//|   Grid B Upper: SELL LIMIT | Grid B Lower: SELL STOP            |
//+------------------------------------------------------------------+
ENUM_ORDER_TYPE GetGridOrderType(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone) {
    //═══════════════════════════════════════════════════════════════
    // v8.0: Grid A = SEMPRE BUY, Grid B = SEMPRE SELL (struttura default)
    //═══════════════════════════════════════════════════════════════
    if(side == GRID_A) {
        // Grid A = SOLO ordini BUY
        if(zone == ZONE_UPPER) {
            return ORDER_TYPE_BUY_STOP;    // BUY STOP @ livello (trend capture)
        } else {
            return ORDER_TYPE_BUY_LIMIT;   // BUY LIMIT @ livello (mean reversion)
        }
    } else {  // GRID_B
        // Grid B = SOLO ordini SELL
        if(zone == ZONE_UPPER) {
            return ORDER_TYPE_SELL_LIMIT;  // SELL LIMIT @ livello (mean reversion)
        } else {
            return ORDER_TYPE_SELL_STOP;   // SELL STOP @ livello (trend capture)
        }
    }
}

//+------------------------------------------------------------------+
//| v8.0: FUNZIONI ELIMINATE                                         |
//| - IsCascadeOverlapMode() RIMOSSO (struttura ora default)         |
//| - GetHedgeOffset() RIMOSSO (nessun offset necessario)            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Position Type When Order Fills                               |
//| v8.0: Grid A = SEMPRE BUY, Grid B = SEMPRE SELL                  |
//+------------------------------------------------------------------+
ENUM_POSITION_TYPE GetGridPositionType(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone) {
    // v8.0: Grid A = sempre BUY, Grid B = sempre SELL (struttura default)
    // Il parametro zone non è più necessario ma mantenuto per compatibilità
    return (side == GRID_A) ? POSITION_TYPE_BUY : POSITION_TYPE_SELL;
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
//| v8.0: Nessun hedge offset - tutti i livelli allineati            |
//+------------------------------------------------------------------+
double CalculateGridLevelPrice(double baseEntryPoint, ENUM_GRID_ZONE zone, int level,
                                double spacingPips, ENUM_GRID_SIDE side = GRID_A) {
    double spacingPrice = PipsToPoints(spacingPips);

    // v8.0: Nessun hedge offset - Grid A e B sullo stesso livello
    if(zone == ZONE_UPPER) {
        // Upper zone: prices above entry point
        return NormalizeDouble(baseEntryPoint + (spacingPrice * (level + 1)), symbolDigits);
    } else {
        // Lower zone: prices below entry point
        return NormalizeDouble(baseEntryPoint - (spacingPrice * (level + 1)), symbolDigits);
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
    double orderEntryPrice = CalculateGridLevelPrice(entryPointPrice, zone, level, spacingPips, side);

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
        double cascadeTP;

        // Perfect Cascade: TP = Entry del livello precedente (verso entry point)
        if(level == 0) {
            // Level 1: TP = Entry Point centrale
            cascadeTP = entryPointPrice;
        } else {
            // Livelli successivi: TP = Entry del livello precedente
            cascadeTP = CalculateGridLevelPrice(entryPointPrice, zone, level - 1, spacingPips);
        }

        // ═══════════════════════════════════════════════════════════════
        // FIX v4.5: Validazione direzione TP
        // Per BUY: TP deve essere >= orderEntryPrice (prezzo deve salire)
        // Per SELL: TP deve essere <= orderEntryPrice (prezzo deve scendere)
        // ═══════════════════════════════════════════════════════════════
        bool tpDirectionValid = isBuy ? (cascadeTP >= orderEntryPrice) : (cascadeTP <= orderEntryPrice);

        if(tpDirectionValid) {
            return cascadeTP;
        }

        // TP nella direzione sbagliata! Usa fallback ratio-based
        // Questo garantisce sempre un TP nella direzione corretta
        double tpDistance = spacingPrice * CascadeTP_Ratio;
        if(isBuy) {
            return NormalizeDouble(orderEntryPrice + tpDistance, symbolDigits);
        } else {
            return NormalizeDouble(orderEntryPrice - tpDistance, symbolDigits);
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

    // v8.0: CASCADE_OVERLAP RIMOSSO - Perfect Cascade è default
    // TP = spacing per TUTTI gli ordini (STOP e LIMIT)

    // Fallback: Use fixed TP
    double fixedTP = PipsToPoints(FinalLevel_TP_Pips);
    if(isBuy) {
        return NormalizeDouble(orderEntryPrice + fixedTP, symbolDigits);
    } else {
        return NormalizeDouble(orderEntryPrice - fixedTP, symbolDigits);
    }
}

//+------------------------------------------------------------------+
//| Calculate Stop Loss for Grid Level - REMOVED v5.6                |
//+------------------------------------------------------------------+
// ❌ FUNZIONE RIMOSSA in v5.6
// L'auto-hedging CASCADE_OVERLAP compensa le perdite automaticamente
// Grid A = SOLO BUY, Grid B = SOLO SELL = Hedge naturale
// Stop Loss rompe la logica neutrale
// Funzione stub mantenuta per backward compatibility
double CalculateGridSL(double baseEntryPoint, ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone,
                       int level, double spacingPips, int totalLevels) {
    return 0;  // v5.6: Sempre 0 - No SL
}

//+------------------------------------------------------------------+
//| GRID LOT CALCULATION FUNCTIONS                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Lot Size for Grid Level                                |
//+------------------------------------------------------------------+
double CalculateGridLotSize(int level) {
    double lot = BaseLot;

    // RISK-BASED MODE: usa lot calcolati da capitale rischio
    if(LotMode == LOT_RISK_BASED) {
        if(!riskBasedLotsCalculated) {
            CalculateRiskBasedLots();
        }
        // Progressive con base calcolata da rischio
        lot = riskBasedBaseLot * MathPow(LotMultiplier, level);
    }
    else if(LotMode == LOT_PROGRESSIVE) {
        // Progressive: Lot = BaseLot × Multiplier^level
        lot = BaseLot * MathPow(LotMultiplier, level);
    }
    // LOT_FIXED: Keep BaseLot

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
//| 💰 RISK-BASED LOT CALCULATION SYSTEM                             |
//| Calcola lot automatici per garantire max loss = RiskCapital      |
//| IMPORTANTE: NON piazza SL automatici - Shield gestisce rischio   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Calculate Risk-Based Lot Sizes                                   |
//| Formula: BaseLot = RiskCapital / DrawdownFactor                  |
//| DrawdownFactor = Σ(Distance_i × Mult^i × PipValue) × 2 zones     |
//|                                                                  |
//| ⚠️ IMPORTANTE: Questo sistema NON piazza Stop Loss automatici!   |
//| I lot vengono calcolati per limitare il DD teorico massimo.      |
//| La protezione avviene tramite Shield (hedging), NON chiusure.    |
//+------------------------------------------------------------------+
void CalculateRiskBasedLots() {
    if(riskBasedLotsCalculated) return;  // Gia calcolato

    Print("═══════════════════════════════════════════════════════════════════");
    Print("  💰 RISK-BASED LOT CALCULATION");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  ⚠️ NOTA: Questo sistema calcola SOLO i lot size.");
    Print("  ⚠️ NON vengono piazzati Stop Loss automatici!");
    Print("  ⚠️ La protezione avviene tramite Shield (hedging).");
    Print("───────────────────────────────────────────────────────────────────");

    // Get pip value for 1 lot
    double pipValue = GetPipValueForLot(1.0);
    if(pipValue <= 0) {
        Print("  ❌ ERROR: Cannot calculate pip value");
        Print("     TickValue or TickSize not available from broker");
        riskBasedBaseLot = symbolMinLot;
        riskBasedLotsCalculated = true;
        Print("  ⚠️ Using minimum lot: ", DoubleToString(symbolMinLot, 2));
        Print("═══════════════════════════════════════════════════════════════════");
        return;
    }

    // Get current spacing
    double spacing = (currentSpacing_Pips > 0) ? currentSpacing_Pips : Fixed_Spacing_Pips;

    // Log input parameters
    Print("  📊 INPUT PARAMETERS:");
    PrintFormat("     Symbol: %s", _Symbol);
    PrintFormat("     Risk Capital: $%.2f", RiskCapital_USD);
    PrintFormat("     Risk Buffer: %.1f%%", RiskBuffer_Percent);
    PrintFormat("     Grid Levels: %d per side", GridLevelsPerSide);
    PrintFormat("     Spacing: %.1f pips", spacing);
    PrintFormat("     Lot Multiplier: %.2f", LotMultiplier);
    PrintFormat("     Pip Value (1 lot): $%.4f", pipValue);
    Print("───────────────────────────────────────────────────────────────────");

    // Apply risk buffer
    double effectiveRisk = RiskCapital_USD * (1.0 - RiskBuffer_Percent / 100.0);
    PrintFormat("  💵 Effective Risk: $%.2f (after %.1f%% buffer)", effectiveRisk, RiskBuffer_Percent);

    // Calculate drawdown factor for worst case scenario
    double drawdownFactor = CalculateDrawdownFactor(spacing, pipValue);

    if(drawdownFactor <= 0) {
        Print("  ❌ ERROR: DrawdownFactor is zero or negative");
        riskBasedBaseLot = symbolMinLot;
        riskBasedLotsCalculated = true;
        Print("  ⚠️ Using minimum lot: ", DoubleToString(symbolMinLot, 2));
        Print("═══════════════════════════════════════════════════════════════════");
        return;
    }

    PrintFormat("  📈 Drawdown Factor: %.2f (per 1 base lot)", drawdownFactor);

    // Calculate base lot
    riskBasedBaseLot = effectiveRisk / drawdownFactor;
    PrintFormat("  🔢 Calculated Base Lot: %.4f", riskBasedBaseLot);

    // Apply broker limits
    double originalLot = riskBasedBaseLot;
    riskBasedBaseLot = MathMax(riskBasedBaseLot, symbolMinLot);
    riskBasedBaseLot = MathMin(riskBasedBaseLot, MaxLotPerLevel);

    if(riskBasedBaseLot != originalLot) {
        PrintFormat("  ⚠️ Lot adjusted to broker limits: %.4f -> %.4f", originalLot, riskBasedBaseLot);
        PrintFormat("     Min Lot: %.2f | Max Lot: %.2f", symbolMinLot, MaxLotPerLevel);
    }

    // Normalize to lot step
    riskBasedBaseLot = NormalizeLotSize(riskBasedBaseLot);

    // Store theoretical max drawdown
    maxTheoreticalDrawdown = drawdownFactor * riskBasedBaseLot;

    // Mark as calculated
    riskBasedLotsCalculated = true;
    riskBasedMultiplier = LotMultiplier;

    // Final summary
    Print("───────────────────────────────────────────────────────────────────");
    Print("  ✅ CALCULATION COMPLETE:");
    PrintFormat("     Base Lot (Level 1): %.2f", riskBasedBaseLot);
    PrintFormat("     Max Theoretical DD: $%.2f", maxTheoreticalDrawdown);
    PrintFormat("     Risk Capital: $%.2f", RiskCapital_USD);
    PrintFormat("     DD/Risk Ratio: %.1f%%", (maxTheoreticalDrawdown / RiskCapital_USD) * 100);
    Print("───────────────────────────────────────────────────────────────────");

    // Show lot progression table
    Print("  📋 LOT PROGRESSION TABLE:");
    Print("     Level | Lot Size | Distance | DD Contribution");
    Print("     ------|----------|----------|----------------");

    double totalDD = 0;
    for(int i = 0; i < GridLevelsPerSide; i++) {
        double lot = NormalizeLotSize(riskBasedBaseLot * MathPow(LotMultiplier, i));
        double distance = (i + 1) * spacing;
        double ddContrib = distance * lot * pipValue;
        totalDD += ddContrib;

        PrintFormat("     L%d    | %.2f     | %.0f pips | $%.2f",
                    i + 1, lot, distance, ddContrib);
    }
    Print("     ------|----------|----------|----------------");
    PrintFormat("     TOTAL (1 zone)         | $%.2f", totalDD);
    PrintFormat("     TOTAL (2 zones worst)  | $%.2f", totalDD * 2);

    Print("───────────────────────────────────────────────────────────────────");
    Print("  🛡️ PROTEZIONE:");
    Print("     • NO Stop Loss automatici piazzati");
    Print("     • Shield 3 Fasi gestisce breakout con HEDGING");
    Print("     • Posizioni restano aperte durante protezione");
    Print("     • Possibile recupero su rimbalzo prezzo");
    Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Calculate Drawdown Factor (sum of distance × lot × pipValue)     |
//| Worst case scenario: all levels filled in one direction          |
//+------------------------------------------------------------------+
double CalculateDrawdownFactor(double spacingPips, double pipValuePerLot) {
    double factor = 0;

    // Per ogni livello: distanza dall'entry × lot × pipValue
    // Distanza Level N = (N × spacing) pips
    // Lot Level N = BaseLot × Multiplier^N (normalizzato a BaseLot=1)

    for(int level = 0; level < GridLevelsPerSide; level++) {
        // Distance from entry point to this level (in pips)
        double distancePips = (level + 1) * spacingPips;

        // Lot multiplier at this level (relative to base = 1)
        double lotMult = MathPow(LotMultiplier, level);

        // DD contribution = distance × lot × pipValue (per 1 base lot)
        factor += distancePips * lotMult * pipValuePerLot;
    }

    // Multiply by number of zones that could go against us
    // In worst case, 2 zones on one side (e.g., Upper + Lower BUY-biased)
    // But with Double Grid Neutral, it's 2 grids × 1 bad zone each = 2 zones
    factor *= 2;  // Conservative: 2 zones losing

    return factor;
}

//+------------------------------------------------------------------+
//| Get Pip Value for Specified Lot Size                             |
//+------------------------------------------------------------------+
double GetPipValueForLot(double lotSize) {
    double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    if(tickSize <= 0 || point <= 0) return 0;

    // Pip size (usually 10 points for 5-digit, 1 point for 4-digit)
    double pipSize = GetPipSize();

    // Pip value = (tickValue / tickSize) × pipSize × lotSize
    double pipValue = (tickValue / tickSize) * pipSize * lotSize;

    return pipValue;
}

//+------------------------------------------------------------------+
//| Get Pip Size for Current Symbol                                  |
//+------------------------------------------------------------------+
double GetPipSize() {
    int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // For 5/3 digit brokers, pip = 10 points
    // For 4/2 digit brokers, pip = 1 point
    if(digits == 5 || digits == 3) {
        return point * 10;
    }
    return point;
}

//+------------------------------------------------------------------+
//| Recalculate Risk-Based Lots (call when spacing changes)          |
//+------------------------------------------------------------------+
void RecalculateRiskBasedLots() {
    riskBasedLotsCalculated = false;
    CalculateRiskBasedLots();
}

//+------------------------------------------------------------------+
//| Get Current Risk Status String for Dashboard                     |
//+------------------------------------------------------------------+
string GetRiskStatusString() {
    if(LotMode != LOT_RISK_BASED) {
        return "FIXED";
    }

    double currentDD = GetCurrentUnrealizedDrawdown();
    double riskPercent = (maxTheoreticalDrawdown > 0) ?
                         (currentDD / maxTheoreticalDrawdown * 100.0) : 0;

    return "$" + DoubleToString(currentDD, 0) + " / $" +
           DoubleToString(RiskCapital_USD, 0) + " (" +
           DoubleToString(riskPercent, 0) + "%)";
}

//+------------------------------------------------------------------+
//| Get Current Unrealized Drawdown (floating loss)                  |
//+------------------------------------------------------------------+
double GetCurrentUnrealizedDrawdown() {
    double totalDD = 0;

    // Sum all negative floating P/L from grid positions
    int total = PositionsTotal();
    for(int i = 0; i < total; i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;

        // Check if it's our position
        long posMagic = PositionGetInteger(POSITION_MAGIC);
        if(posMagic >= MagicNumber && posMagic <= MagicNumber + MAGIC_OFFSET_GRID_B + 10000) {
            double profit = PositionGetDouble(POSITION_PROFIT);
            double swap = PositionGetDouble(POSITION_SWAP);
            double commission = 0;  // Commission usually in ticket close

            double netPL = profit + swap + commission;
            if(netPL < 0) {
                totalDD += MathAbs(netPL);
            }
        }
    }

    currentRealizedRisk = totalDD;
    return totalDD;
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
//| GRID VISUALIZATION HELPERS v3.0                                  |
//| Colori per Order Type:                                           |
//|   BUY STOP: Verde Scuro | BUY LIMIT: Verde Chiaro                |
//|   SELL STOP: Rosso      | SELL LIMIT: Arancione                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Color for Grid Line v3.0 - Based on Order Type               |
//+------------------------------------------------------------------+
color GetGridLineColor(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone) {
    // Get the order type for this grid position
    ENUM_ORDER_TYPE orderType = GetGridOrderType(side, zone);

    // v3.0: Color based on order type
    switch(orderType) {
        case ORDER_TYPE_BUY_STOP:   return COLOR_GRIDLINE_BUY_STOP;    // Verde scuro
        case ORDER_TYPE_BUY_LIMIT:  return COLOR_GRIDLINE_BUY_LIMIT;   // Verde chiaro
        case ORDER_TYPE_SELL_STOP:  return COLOR_GRIDLINE_SELL_STOP;   // Rosso
        case ORDER_TYPE_SELL_LIMIT: return COLOR_GRIDLINE_SELL_LIMIT;  // Arancione
        default: break;
    }

    // Fallback to legacy colors
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
//| Create Grid Level Line on Chart v5.9                             |
//| Stesso spessore per tutte le linee                               |
//| v5.9: Labels in colonna fissa vicino ai pannelli laterali        |
//+------------------------------------------------------------------+
void CreateGridLevelLine(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, double price) {
    if(!ShowGridLines) return;

    string name = GetGridObjectPrefix(side, zone) + "L" + IntegerToString(level + 1);
    color clr = GetGridLineColor(side, zone);

    // v3.0: Stesso spessore per tutte le linee (GRIDLINE_WIDTH)
    CreateHLine(name, price, clr, GRIDLINE_WIDTH, STYLE_SOLID);

    // Add order type label
    ENUM_ORDER_TYPE orderType = GetGridOrderType(side, zone);
    string orderTypeLabel = GetOrderTypeString(orderType);
    string labelName = name + "_LBL";

    // v5.9: Convert price to Y pixel coordinate for fixed position
    int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    double priceMax = ChartGetDouble(0, CHART_PRICE_MAX);
    double priceMin = ChartGetDouble(0, CHART_PRICE_MIN);
    int yPixel = (int)((priceMax - price) / (priceMax - priceMin) * chartHeight);

    // v5.9: Fixed X position near side panels (Dashboard ends at ~630px)
    int xPixel = Dashboard_X + 620;

    ObjectDelete(0, labelName);
    if(ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0)) {
        ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, xPixel);
        ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, yPixel);
        ObjectSetString(0, labelName, OBJPROP_TEXT, orderTypeLabel);
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 7);
        ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
        ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
        ObjectSetInteger(0, labelName, OBJPROP_ZORDER, 9500);
    }
}

//+------------------------------------------------------------------+
//| Create TP Line on Chart v5.9                                     |
//| Uses configurable colors: yellow for BUY, red for SELL           |
//| v5.9: Labels in colonna fissa vicino ai pannelli laterali        |
//+------------------------------------------------------------------+
void CreateGridTPLine(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level, double price) {
    // v4.6: Use new ShowTPLines parameter
    if(!ShowTPLines) return;

    string name = GetGridObjectPrefix(side, zone) + "TP" + IntegerToString(level + 1);

    // v4.6: Determine color based on order type (BUY = yellow, SELL = red)
    ENUM_ORDER_TYPE orderType = GetGridOrderType(side, zone);
    bool isBuy = (orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_BUY_STOP);
    color clr = isBuy ? TP_LINE_BUY_COLOR : TP_LINE_SELL_COLOR;

    // v4.6: Use configurable style and width
    CreateHLine(name, price, clr, TP_LINE_WIDTH, TP_LINE_STYLE);

    // v5.9: Convert price to Y pixel coordinate for fixed position
    int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    double priceMax = ChartGetDouble(0, CHART_PRICE_MAX);
    double priceMin = ChartGetDouble(0, CHART_PRICE_MIN);
    int yPixel = (int)((priceMax - price) / (priceMax - priceMin) * chartHeight);

    // v5.9: Fixed X position near side panels (Dashboard ends at ~630px)
    int xPixel = Dashboard_X + 620;

    // Add small TP label
    string labelName = name + "_LBL";
    ObjectDelete(0, labelName);
    if(ObjectCreate(0, labelName, OBJ_LABEL, 0, 0, 0)) {
        ObjectSetInteger(0, labelName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
        ObjectSetInteger(0, labelName, OBJPROP_XDISTANCE, xPixel);
        ObjectSetInteger(0, labelName, OBJPROP_YDISTANCE, yPixel);
        ObjectSetString(0, labelName, OBJPROP_TEXT, "TP");
        ObjectSetInteger(0, labelName, OBJPROP_COLOR, clr);
        ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 6);
        ObjectSetString(0, labelName, OBJPROP_FONT, "Arial");
        ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_RIGHT);
        ObjectSetInteger(0, labelName, OBJPROP_BACK, false);
        ObjectSetInteger(0, labelName, OBJPROP_ZORDER, 9500);
    }
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
//| v4.0: Added safety checks (trend, shield proximity, volatility)  |
//+------------------------------------------------------------------+
bool CanLevelReopen(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    if(!EnableCyclicReopen) return false;

    // ═══════════════════════════════════════════════════════════════════
    // v4.0 SAFETY CHECK 1: Block near Shield activation
    // ═══════════════════════════════════════════════════════════════════
    // v8.0: Rimosso IsCascadeOverlapMode() - struttura è default
    if(PauseReopenNearShield && ShieldMode != SHIELD_DISABLED) {
        double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        double proximityPoints = PipsToPoints(ShieldProximity_Pips);

        // Check distance from breakout levels
        if(upperBreakoutLevel > 0 && (upperBreakoutLevel - currentPrice) < proximityPoints) {
            if(DetailedLogging) {
                Print("Reopen blocked: Too close to upper Shield (",
                      DoubleToString(PointsToPips(upperBreakoutLevel - currentPrice), 1), " pips)");
            }
            return false;
        }
        if(lowerBreakoutLevel > 0 && (currentPrice - lowerBreakoutLevel) < proximityPoints) {
            if(DetailedLogging) {
                Print("Reopen blocked: Too close to lower Shield (",
                      DoubleToString(PointsToPips(currentPrice - lowerBreakoutLevel), 1), " pips)");
            }
            return false;
        }

        // Also block if Shield is already active
        if(shield.isActive) {
            if(DetailedLogging) {
                Print("Reopen blocked: Shield is active");
            }
            return false;
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // v5.8 SAFETY CHECK 3: Block on extreme volatility (simplified)
    // ═══════════════════════════════════════════════════════════════════
    if(PauseReopenOnExtreme) {
        if(currentATR_Condition == ATR_EXTREME) {
            if(DetailedLogging) {
                Print("Reopen blocked: Extreme volatility");
            }
            return false;
        }
    }

    // ═══════════════════════════════════════════════════════════════════
    // ORIGINAL CHECK: Cooldown
    // ═══════════════════════════════════════════════════════════════════
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

    // COOLDOWN REMOVED v5.8 - Reopen sempre immediato

    // ═══════════════════════════════════════════════════════════════════
    // ORIGINAL CHECK: Max cycles
    // ═══════════════════════════════════════════════════════════════════
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

// v8.0: CalculateReopenPrice() ELIMINATO - funzione mai usata
// Reopen usa sempre il prezzo originale memorizzato negli array

//+------------------------------------------------------------------+
//| Check Price Level for Reopen Trigger (Legacy - bidirezionale)    |
//| v8.0: Mantenuto per compatibilità, usare IsPriceAtReopenLevelSmart |
//+------------------------------------------------------------------+
bool IsPriceAtReopenLevel(double levelPrice) {
    if(ReopenTrigger != REOPEN_PRICE_LEVEL) return true;

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // v5.x FIX: Strategy Tester - skip check if no price available
    if(currentPrice <= 0) return false;

    double offsetPrice = PipsToPoints(ReopenOffset_Pips);
    return (MathAbs(currentPrice - levelPrice) <= offsetPrice);
}

//+------------------------------------------------------------------+
//| SMART Reopen Level Check - v8.0                                  |
//| LIMIT: sempre immediato (intrinsecamente protetti dal broker)    |
//| STOP: controllo unidirezionale con offset                        |
//+------------------------------------------------------------------+
bool IsPriceAtReopenLevelSmart(double levelPrice, ENUM_ORDER_TYPE orderType) {
    // v8.0: Per IMMEDIATE trigger, sempre true
    if(ReopenTrigger == REOPEN_IMMEDIATE) return true;

    // LIMIT orders: sempre immediato (broker rifiuta se prezzo non valido)
    if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT) {
        if(DetailedLogging) {
            PrintFormat("[SmartReopen] %s @ %.5f → IMMEDIATO (LIMIT intrinsecamente protetto)",
                        EnumToString(orderType), levelPrice);
        }
        return true;
    }

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(currentPrice <= 0) return false;

    double offsetPoints = PipsToPoints(ReopenOffset_Pips);
    bool canReopen = false;
    string condition = "";
    double targetPrice = 0;
    double distancePips = 0;

    switch(orderType) {
        case ORDER_TYPE_BUY_STOP:
            // BUY STOP: piazza quando prezzo SOTTO entry - garantisce validità
            targetPrice = levelPrice - offsetPoints;
            canReopen = (currentPrice <= targetPrice);
            distancePips = PointsToPips(currentPrice - targetPrice);
            condition = StringFormat("price %.5f <= %.5f (entry-%.1f)",
                                     currentPrice, targetPrice, ReopenOffset_Pips);
            break;

        case ORDER_TYPE_SELL_STOP:
            // SELL STOP: piazza quando prezzo SOPRA entry - garantisce validità
            targetPrice = levelPrice + offsetPoints;
            canReopen = (currentPrice >= targetPrice);
            distancePips = PointsToPips(targetPrice - currentPrice);
            condition = StringFormat("price %.5f >= %.5f (entry+%.1f)",
                                     currentPrice, targetPrice, ReopenOffset_Pips);
            break;

        default:
            return true;
    }

    // Log solo quando cambia stato o ogni N tick (evita spam)
    static datetime lastLogTime = 0;
    if(DetailedLogging && TimeCurrent() - lastLogTime >= 5) {  // Log ogni 5 secondi max
        if(canReopen) {
            PrintFormat("[SmartReopen] %s @ %.5f → PRONTO! %s ✓",
                        EnumToString(orderType), levelPrice, condition);
        } else {
            PrintFormat("[SmartReopen] %s @ %.5f → ATTESA (%.1f pips) %s",
                        EnumToString(orderType), levelPrice, MathAbs(distancePips), condition);
        }
        lastLogTime = TimeCurrent();
    }

    return canReopen;
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

//+------------------------------------------------------------------+
//| ═══════════════════════════════════════════════════════════════ |
//| 📐 DYNAMIC S/R AND WARNING ZONE HELPERS (v4.4)                  |
//| ═══════════════════════════════════════════════════════════════ |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get S/R Multiplier (N + 0.25)                                     |
//| Places S/R immediately after the last fillable grid level         |
//| N=5 → 5.25 | N=7 → 7.25 | N=9 → 9.25                              |
//+------------------------------------------------------------------+
double GetSRMultiplier() {
    return GridLevelsPerSide + 0.25;
}

//+------------------------------------------------------------------+
//| Get Warning Zone Multiplier (N - 0.5)                             |
//| Places warning zone HALFWAY between penultimate and last grid     |
//| N=5 → 4.5 | N=7 → 6.5 | N=9 → 8.5                                 |
//+------------------------------------------------------------------+
double GetWarningZoneMultiplier() {
    return GridLevelsPerSide - 0.5;
}

//+------------------------------------------------------------------+
//| Calculate S/R Level from Entry Point                              |
//| Formula: S/R = entry ± (spacing × (N + 0.25))                     |
//+------------------------------------------------------------------+
double CalculateSRLevel(double entry, double spacingPips, bool isResistance) {
    double multiplier = GetSRMultiplier();
    double spacingPoints = PipsToPoints(spacingPips);

    if(isResistance)
        return NormalizeDouble(entry + (spacingPoints * multiplier), symbolDigits);
    else
        return NormalizeDouble(entry - (spacingPoints * multiplier), symbolDigits);
}

//+------------------------------------------------------------------+
//| Calculate Warning Zone Level from Entry Point                     |
//| Formula: Warning = entry ± (spacing × (N - 0.5))                  |
//+------------------------------------------------------------------+
double CalculateWarningZoneLevel(double entry, double spacingPips, bool isUpper) {
    double multiplier = GetWarningZoneMultiplier();
    double spacingPoints = PipsToPoints(spacingPips);

    if(isUpper)
        return NormalizeDouble(entry + (spacingPoints * multiplier), symbolDigits);
    else
        return NormalizeDouble(entry - (spacingPoints * multiplier), symbolDigits);
}

//+------------------------------------------------------------------+
//| Get Current Spacing in Points (for convenience)                   |
//+------------------------------------------------------------------+
double GetCurrentSpacingPoints() {
    return PipsToPoints(currentSpacing_Pips);
}

//+------------------------------------------------------------------+
//| Log Dynamic Positioning Info                                      |
//+------------------------------------------------------------------+
void LogDynamicPositioningInfo() {
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  📐 DYNAMIC POSITIONING INFO (v4.4)");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  Grid Levels Per Side: ", GridLevelsPerSide);
    Print("  Current Spacing: ", DoubleToString(currentSpacing_Pips, 1), " pips");
    Print("───────────────────────────────────────────────────────────────────");
    Print("  S/R Multiplier: ", DoubleToString(GetSRMultiplier(), 2), " (N+0.25)");
    Print("  Warning Zone Multiplier: ", DoubleToString(GetWarningZoneMultiplier(), 2), " (N-0.5)");
    Print("───────────────────────────────────────────────────────────────────");

    if(entryPoint > 0) {
        double srUp = CalculateSRLevel(entryPoint, currentSpacing_Pips, true);
        double srDown = CalculateSRLevel(entryPoint, currentSpacing_Pips, false);
        double warnUp = CalculateWarningZoneLevel(entryPoint, currentSpacing_Pips, true);
        double warnDown = CalculateWarningZoneLevel(entryPoint, currentSpacing_Pips, false);

        Print("  CALCULATED LEVELS:");
        PrintFormat("    Entry Point: %.5f", entryPoint);
        PrintFormat("    Warning Up: %.5f (%.1f pips)", warnUp, PointsToPips(warnUp - entryPoint));
        PrintFormat("    Warning Down: %.5f (%.1f pips)", warnDown, PointsToPips(entryPoint - warnDown));
        PrintFormat("    S/R Up (Resistance): %.5f (%.1f pips)", srUp, PointsToPips(srUp - entryPoint));
        PrintFormat("    S/R Down (Support): %.5f (%.1f pips)", srDown, PointsToPips(entryPoint - srDown));
    }
    Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| CASCADE_OVERLAP: STUB FUNCTIONS FOR SHIELD (replaces RangeBox)    |
//| These functions use grid edges as breakout levels                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Last Grid B Upper Level (Resistance)                          |
//+------------------------------------------------------------------+
double GetLastGridBLevel() {
    double spacing = (currentSpacing_Pips > 0) ? currentSpacing_Pips : Fixed_Spacing_Pips;
    double spacingPoints = PipsToPoints(spacing);
    return NormalizeDouble(entryPoint + (spacingPoints * GridLevelsPerSide), symbolDigits);
}

//+------------------------------------------------------------------+
//| Get Last Grid A Lower Level (Support)                             |
//+------------------------------------------------------------------+
double GetLastGridALevel() {
    double spacing = (currentSpacing_Pips > 0) ? currentSpacing_Pips : Fixed_Spacing_Pips;
    double spacingPoints = PipsToPoints(spacing);
    return NormalizeDouble(entryPoint - (spacingPoints * GridLevelsPerSide), symbolDigits);
}

//+------------------------------------------------------------------+
//| Calculate Breakout Levels from Grid Edges (replaces RangeBox)     |
//+------------------------------------------------------------------+
bool CalculateBreakoutLevels() {
    if(entryPoint <= 0) {
        Print("[GridHelpers] ERROR: Entry point not set");
        return false;
    }

    double spacing = (currentSpacing_Pips > 0) ? currentSpacing_Pips : Fixed_Spacing_Pips;
    double spacingPoints = PipsToPoints(spacing);

    // Set shieldZone values using grid edges
    shieldZone.resistance = GetLastGridBLevel();  // Upper Grid B last level
    shieldZone.support = GetLastGridALevel();     // Lower Grid A last level

    // Warning zones at N-0.5 levels
    double warningOffset = spacingPoints * (GridLevelsPerSide - 0.5);
    shieldZone.warningZoneUp = NormalizeDouble(entryPoint + warningOffset, symbolDigits);
    shieldZone.warningZoneDown = NormalizeDouble(entryPoint - warningOffset, symbolDigits);

    // Breakout zones at N+0.5 levels (beyond grid edges)
    double breakoutOffset = spacingPoints * (GridLevelsPerSide + 0.5);
    upperBreakoutLevel = NormalizeDouble(entryPoint + breakoutOffset, symbolDigits);
    lowerBreakoutLevel = NormalizeDouble(entryPoint - breakoutOffset, symbolDigits);

    // Reentry zones (same as support/resistance)
    upperReentryLevel = shieldZone.resistance;
    lowerReentryLevel = shieldZone.support;

    shieldZone.isValid = true;

    PrintFormat("[GridHelpers] Breakout levels set from grid edges:");
    PrintFormat("  Support: %.5f | Resistance: %.5f", shieldZone.support, shieldZone.resistance);
    PrintFormat("  Warning Down: %.5f | Warning Up: %.5f", shieldZone.warningZoneDown, shieldZone.warningZoneUp);

    return true;
}

//+------------------------------------------------------------------+
//| Get Price Position in Range (for Shield 3 Phases)                 |
//+------------------------------------------------------------------+
ENUM_SYSTEM_STATE GetPricePositionInRange(double currentPrice) {
    if(!shieldZone.isValid) {
        return STATE_INSIDE_RANGE;
    }

    // Check if price is in warning zone (approaching edges)
    if(currentPrice >= shieldZone.warningZoneUp) {
        return STATE_WARNING_UP;
    }
    if(currentPrice <= shieldZone.warningZoneDown) {
        return STATE_WARNING_DOWN;
    }

    return STATE_INSIDE_RANGE;
}

//+------------------------------------------------------------------+
//| Check Breakout Condition for Shield (v5.6: con conferma candele) |
//| Usa Breakout_Confirm_Candles e Use_Candle_Close per confermare   |
//+------------------------------------------------------------------+
bool CheckBreakoutConditionShield(double currentPrice, ENUM_BREAKOUT_DIRECTION &direction) {
    if(!shieldZone.isValid) {
        direction = BREAKOUT_NONE;
        g_breakoutConfirmCounter = 0;
        g_breakoutPendingDirection = BREAKOUT_NONE;
        return false;
    }

    // Determina direzione breakout
    ENUM_BREAKOUT_DIRECTION currentDirection = BREAKOUT_NONE;

    if(currentPrice > shieldZone.resistance) {
        currentDirection = BREAKOUT_UP;
    }
    else if(currentPrice < shieldZone.support) {
        currentDirection = BREAKOUT_DOWN;
    }

    // Se nessun breakout o direzione cambiata, reset
    if(currentDirection == BREAKOUT_NONE ||
       (g_breakoutPendingDirection != BREAKOUT_NONE && currentDirection != g_breakoutPendingDirection)) {
        g_breakoutConfirmCounter = 0;
        g_breakoutPendingDirection = BREAKOUT_NONE;
        direction = BREAKOUT_NONE;
        return false;
    }

    // Breakout rilevato - inizia/continua conferma
    g_breakoutPendingDirection = currentDirection;
    direction = currentDirection;

    // Se Breakout_Confirm_Candles <= 0, conferma immediata (backward compatible)
    if(Breakout_Confirm_Candles <= 0) {
        return true;
    }

    // Conferma candele
    datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);

    if(currentBar != g_breakoutLastBarTime) {
        g_breakoutLastBarTime = currentBar;

        if(Use_Candle_Close) {
            // Verifica che la candela PRECEDENTE abbia CHIUSO oltre il livello
            double prevClose = iClose(_Symbol, PERIOD_CURRENT, 1);
            bool confirmValid = false;

            if(currentDirection == BREAKOUT_UP && prevClose > shieldZone.resistance) {
                confirmValid = true;
            }
            else if(currentDirection == BREAKOUT_DOWN && prevClose < shieldZone.support) {
                confirmValid = true;
            }

            if(confirmValid) {
                g_breakoutConfirmCounter++;
                if(DetailedLogging) {
                    PrintFormat("[Shield] Breakout confirm %d/%d (candle close: %.5f)",
                                g_breakoutConfirmCounter, Breakout_Confirm_Candles, prevClose);
                }
            }
        }
        else {
            // Conta semplicemente le nuove barre
            g_breakoutConfirmCounter++;
            if(DetailedLogging) {
                PrintFormat("[Shield] Breakout confirm %d/%d (new bar)",
                            g_breakoutConfirmCounter, Breakout_Confirm_Candles);
            }
        }
    }

    // Non ancora confermato
    if(g_breakoutConfirmCounter < Breakout_Confirm_Candles) {
        return false;
    }

    // Breakout confermato!
    if(DetailedLogging) {
        PrintFormat("[Shield] BREAKOUT CONFIRMED! Direction: %s, Counter: %d",
                    (direction == BREAKOUT_UP ? "UP" : "DOWN"), g_breakoutConfirmCounter);
    }

    // Reset per prossimo breakout
    g_breakoutConfirmCounter = 0;
    g_breakoutPendingDirection = BREAKOUT_NONE;

    return true;
}

//+------------------------------------------------------------------+
//| Check Reentry Condition for Shield (v5.6: con hysteresis)         |
//| Il prezzo deve restare dentro il range per X secondi              |
//| Usa Reentry_Confirm_Seconds (0 = disabilitato)                    |
//+------------------------------------------------------------------+
bool CheckReentryConditionShield(double currentPrice) {
    if(!shieldZone.isValid) {
        g_shieldReentryStart = 0;
        return false;
    }

    bool isInsideRange = (currentPrice > shieldZone.support &&
                          currentPrice < shieldZone.resistance);

    // Se fuori dal range, reset timer
    if(!isInsideRange) {
        if(g_shieldReentryStart != 0 && DetailedLogging) {
            Print("[Shield] Reentry cancelled - price exited range");
        }
        g_shieldReentryStart = 0;
        return false;
    }

    // Se hysteresis disabilitata (0), conferma immediata (backward compatible)
    if(Reentry_Confirm_Seconds <= 0) {
        return true;
    }

    // Prima volta dentro il range - avvia timer
    if(g_shieldReentryStart == 0) {
        g_shieldReentryStart = TimeCurrent();
        if(DetailedLogging) {
            PrintFormat("[Shield] Reentry timer started - need %d seconds inside range",
                        Reentry_Confirm_Seconds);
        }
        return false;
    }

    // Calcola tempo trascorso dentro il range
    int timeSinceReentry = (int)(TimeCurrent() - g_shieldReentryStart);

    // Log ogni 10 secondi
    if(DetailedLogging && timeSinceReentry > 0 && timeSinceReentry % 10 == 0) {
        PrintFormat("[Shield] Reentry timer: %d/%d seconds",
                    timeSinceReentry, Reentry_Confirm_Seconds);
    }

    // Conferma dopo X secondi
    if(timeSinceReentry >= Reentry_Confirm_Seconds) {
        PrintFormat("[Shield] Reentry CONFIRMED after %d seconds inside range",
                    timeSinceReentry);
        g_shieldReentryStart = 0;
        return true;
    }

    return false;  // Ancora in attesa conferma
}

