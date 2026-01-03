//+------------------------------------------------------------------+
//|                                        BrokerValidation.mqh      |
//|                        Sugamara - Broker Validation              |
//|                                                                  |
//|  Validates EA parameters against broker specifications           |
//|  Adapted from Breva-Tivan v10.3.19                              |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| Load Broker Specifications                                       |
//| Populates global variables with broker symbol info               |
//+------------------------------------------------------------------+
bool LoadBrokerSpecifications() {
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  LOADING BROKER SPECIFICATIONS");
    Print("═══════════════════════════════════════════════════════════════════");

    // Symbol basic info
    symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    if(symbolPoint <= 0) {
        Print("ERROR: Invalid symbol point value: ", symbolPoint);
        return false;
    }

    // Stop levels
    symbolStopsLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
    symbolFreezeLevel = (int)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);

    // Lot specifications
    symbolMinLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    symbolMaxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    symbolLotStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

    // Current spread
    symbolSpreadPoints = SymbolInfoInteger(_Symbol, SYMBOL_SPREAD);

    // Validation
    if(symbolMinLot <= 0) {
        Print("ERROR: Invalid minimum lot: ", symbolMinLot);
        return false;
    }

    if(symbolLotStep <= 0) {
        Print("ERROR: Invalid lot step: ", symbolLotStep);
        return false;
    }

    // Log specifications
    Print("Symbol: ", _Symbol);
    Print("Point: ", symbolPoint);
    Print("Digits: ", symbolDigits);
    Print("Stops Level: ", symbolStopsLevel, " points");
    Print("Freeze Level: ", symbolFreezeLevel, " points");
    Print("Min Lot: ", symbolMinLot);
    Print("Max Lot: ", symbolMaxLot);
    Print("Lot Step: ", symbolLotStep);
    Print("Current Spread: ", symbolSpreadPoints, " points (",
          DoubleToString(PointsToPips(symbolSpreadPoints * symbolPoint), 1), " pips)");
    Print("═══════════════════════════════════════════════════════════════════");

    return true;
}

//+------------------------------------------------------------------+
//| Validate Input Parameters                                        |
//| Checks user inputs are within acceptable ranges                  |
//+------------------------------------------------------------------+
bool ValidateInputParameters() {
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  VALIDATING INPUT PARAMETERS");
    Print("═══════════════════════════════════════════════════════════════════");

    int errors = 0;
    int warnings = 0;

    // ====================================================================
    // CHECK 1: Grid Levels
    // ====================================================================
    if(GridLevelsPerSide < 3 || GridLevelsPerSide > MAX_GRID_LEVELS) {
        Print("ERROR: GridLevelsPerSide must be 3-", MAX_GRID_LEVELS,
              " (current: ", GridLevelsPerSide, ")");
        errors++;
    }

    // ====================================================================
    // CHECK 2: Base Lot
    // ====================================================================
    if(BaseLot < symbolMinLot) {
        Print("ERROR: BaseLot ", BaseLot, " below broker minimum ", symbolMinLot);
        errors++;
    }

    if(BaseLot > symbolMaxLot) {
        Print("ERROR: BaseLot ", BaseLot, " exceeds broker maximum ", symbolMaxLot);
        errors++;
    }

    // ====================================================================
    // CHECK 3: Spacing
    // ====================================================================
    if(SpacingMode == SPACING_FIXED) {
        if(Fixed_Spacing_Pips < MIN_SPACING_PIPS) {
            Print("WARNING: Fixed_Spacing_Pips ", Fixed_Spacing_Pips,
                  " below recommended minimum ", MIN_SPACING_PIPS);
            warnings++;
        }
        if(Fixed_Spacing_Pips > MAX_SPACING_PIPS) {
            Print("WARNING: Fixed_Spacing_Pips ", Fixed_Spacing_Pips,
                  " above recommended maximum ", MAX_SPACING_PIPS);
            warnings++;
        }
    }

    // ====================================================================
    // CHECK 4: Lot Multiplier (Progressive mode)
    // ====================================================================
    if(LotMode == LOT_PROGRESSIVE) {
        if(LotMultiplier < 1.0) {
            Print("ERROR: LotMultiplier must be >= 1.0 (current: ", LotMultiplier, ")");
            errors++;
        }
        if(LotMultiplier > 2.0) {
            Print("WARNING: LotMultiplier ", LotMultiplier,
                  " is aggressive - may cause margin issues");
            warnings++;
        }

        // Check if progression exceeds max lot
        double projectedMaxLot = BaseLot * MathPow(LotMultiplier, GridLevelsPerSide - 1);
        if(projectedMaxLot > MaxLotPerLevel) {
            Print("INFO: Lot progression capped at ", MaxLotPerLevel,
                  " (projected: ", DoubleToString(projectedMaxLot, 2), ")");
        }
    }

    // ====================================================================
    // CHECK 6: Emergency Stop
    // ====================================================================
    if(EnableEmergencyStop) {
        if(EmergencyStop_Percent < 5 || EmergencyStop_Percent > 50) {
            Print("WARNING: EmergencyStop_Percent ", EmergencyStop_Percent,
                  "% outside typical range 5-50%");
            warnings++;
        }
    }

    // ====================================================================
    // CHECK 7: Broker Minimum Distance
    // ====================================================================
    double brokerMinPips = PointsToPips(symbolStopsLevel * symbolPoint);
    if(brokerMinPips < 0.1) brokerMinPips = 5.0;  // Default if broker doesn't specify

    if(SpacingMode == SPACING_FIXED && Fixed_Spacing_Pips < brokerMinPips) {
        Print("WARNING: Fixed_Spacing_Pips ", Fixed_Spacing_Pips,
              " below broker stop level ", DoubleToString(brokerMinPips, 1), " pips");
        Print("         Orders may be rejected");
        warnings++;
    }

    // ====================================================================
    // CHECK 8: Hedging Mode Required
    // ====================================================================
    if(AllowHedging) {
        ENUM_ACCOUNT_MARGIN_MODE marginMode =
            (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);

        if(marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
            Print("ERROR: Double Grid Neutral requires HEDGING account mode!");
            Print("       Current mode: ", EnumToString(marginMode));
            Print("       Please switch to a hedging account");
            errors++;
        } else {
            Print("SUCCESS: Account is in HEDGING mode");
        }
    }

    // ====================================================================
    // CHECK 9: Magic Number
    // ====================================================================
    if(MagicNumber <= 0) {
        Print("ERROR: MagicNumber must be positive (current: ", MagicNumber, ")");
        errors++;
    }

    // ====================================================================
    // SUMMARY
    // ====================================================================
    Print("\n═══════════════════════════════════════════════════════════════════");
    Print("  VALIDATION SUMMARY");
    Print("═══════════════════════════════════════════════════════════════════");
    Print("Errors: ", errors);
    Print("Warnings: ", warnings);

    if(errors > 0) {
        Print("RESULT: FAILED - ", errors, " error(s) must be fixed");
        if(EnableAlerts) {
            Alert("SUGAMARA: Input validation FAILED - check Expert Log");
        }
        return false;
    }

    if(warnings > 0) {
        Print("RESULT: PASSED with ", warnings, " warning(s)");
        Print("        EA will start but review warnings for optimal performance");
    } else {
        Print("RESULT: PASSED - All parameters valid");
    }

    Print("═══════════════════════════════════════════════════════════════════");
    return true;
}

//+------------------------------------------------------------------+
//| Validate Broker Minimums (LOG-ONLY - Never blocks)               |
//+------------------------------------------------------------------+
bool ValidateBrokerMinimums() {
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  BROKER DISTANCE CHECK - INFORMATIVE ONLY");
    Print("═══════════════════════════════════════════════════════════════════");

    double brokerStopsPips = PointsToPips(symbolStopsLevel * symbolPoint);
    double brokerFreezePips = PointsToPips(symbolFreezeLevel * symbolPoint);
    double brokerMinimum = MathMax(brokerStopsPips, brokerFreezePips);

    if(brokerMinimum < 0.1) {
        brokerMinimum = 5.0;
        Print("INFO: Broker has no minimum distance - using 5.0 pips default");
    }

    Print("Broker Stops Level: ", DoubleToString(brokerStopsPips, 1), " pips");
    Print("Broker Freeze Level: ", DoubleToString(brokerFreezePips, 1), " pips");
    Print("Effective Minimum: ", DoubleToString(brokerMinimum, 1), " pips");

    // Check current spacing against broker minimum
    if(currentSpacing_Pips > 0 && currentSpacing_Pips < brokerMinimum) {
        Print("WARNING: Current spacing ", DoubleToString(currentSpacing_Pips, 1),
              " pips < broker minimum ", DoubleToString(brokerMinimum, 1), " pips");
        Print("         Some orders may be rejected");
    } else if(currentSpacing_Pips > 0) {
        Print("SUCCESS: Spacing ", DoubleToString(currentSpacing_Pips, 1),
              " pips >= broker minimum");
    }

    Print("═══════════════════════════════════════════════════════════════════");

    // Always return true - this is informative only
    return true;
}

//+------------------------------------------------------------------+
//| Normalize Lot Size to Broker Requirements                        |
//+------------------------------------------------------------------+
double NormalizeLotSize(double lot) {
    // Apply minimum
    if(lot < symbolMinLot) {
        lot = symbolMinLot;
    }

    // Apply maximum
    if(lot > symbolMaxLot) {
        lot = symbolMaxLot;
    }

    // Apply user maximum
    if(lot > MaxLotPerLevel) {
        lot = MaxLotPerLevel;
    }

    // Round to lot step
    if(symbolLotStep > 0) {
        lot = MathFloor(lot / symbolLotStep) * symbolLotStep;
    }

    return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Validate Take Profit Distance                                    |
//| Ensures TP is at least broker minimum distance from price        |
//+------------------------------------------------------------------+
double ValidateTakeProfit(double price, double tp, bool isBuy) {
    if(tp == 0) return 0;

    double minDistance = symbolStopsLevel * symbolPoint;
    if(minDistance < symbolPoint * 10) {
        minDistance = symbolPoint * 30;  // Default 3 pips minimum (was 50=5pips - v4.6 FIX)
    }

    // Add safety margin
    minDistance *= 1.1;  // 10% margin (was 1.2=20% - v4.6 FIX)

    if(isBuy) {
        // For BUY, TP must be above price
        double minTP = price + minDistance;
        if(tp < minTP) {
            tp = minTP;
        }
    } else {
        // For SELL, TP must be below price
        double maxTP = price - minDistance;
        if(tp > maxTP) {
            tp = maxTP;
        }
    }

    return NormalizeDouble(tp, symbolDigits);
}

//+------------------------------------------------------------------+
//| Check if Price is Valid for Pending Order                        |
//+------------------------------------------------------------------+
bool IsValidPendingPrice(double price, ENUM_ORDER_TYPE orderType) {
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // v5.x FIX: Verifica tick validi (CRITICO per Strategy Tester)
    // In Strategy Tester al primo tick ASK/BID possono essere 0
    // In REAL trading sono sempre > 0, quindi questo check non viene mai attivato
    if(currentAsk <= 0 || currentBid <= 0) {
        if(DetailedLogging) {
            Print("[BrokerValidation] WARNING: ASK/BID not available yet - allowing order");
        }
        return true;  // Permetti ordine - cyclic reopen riproverà se necessario
    }

    double minDistance = symbolStopsLevel * symbolPoint;

    if(minDistance < symbolPoint * 10) {
        minDistance = symbolPoint * 30;  // FIX v4.5: Unified to 3 pips minimum
    }

    switch(orderType) {
        case ORDER_TYPE_BUY_LIMIT:
            // Buy Limit must be below current Ask
            return (price < currentAsk - minDistance);

        case ORDER_TYPE_SELL_LIMIT:
            // Sell Limit must be above current Bid
            return (price > currentBid + minDistance);

        case ORDER_TYPE_BUY_STOP:
            // Buy Stop must be above current Ask
            return (price > currentAsk + minDistance);

        case ORDER_TYPE_SELL_STOP:
            // Sell Stop must be below current Bid
            return (price < currentBid - minDistance);

        default:
            return false;
    }
}

//+------------------------------------------------------------------+
//| Get Safe Order Price - v5.20 ADAPTIVE PRICE FIX                  |
//| FIX: Se prezzo invalido, calcola prezzo adattivo valido          |
//| Mantiene ordine pendente, non converte a market                  |
//| v5.x FIX: Gestisce Strategy Tester con ASK/BID=0                 |
//+------------------------------------------------------------------+
double GetSafeOrderPrice(double desiredPrice, ENUM_ORDER_TYPE orderType) {
    double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // v5.x FIX: Se dati non disponibili, ritorna prezzo originale
    // In Strategy Tester al primo tick ASK/BID possono essere 0
    if(currentAsk <= 0 || currentBid <= 0) {
        return NormalizeDouble(desiredPrice, symbolDigits);
    }

    // Calcola distanza minima dal broker
    double minDistance = symbolStopsLevel * symbolPoint;
    if(minDistance < symbolPoint * 10) {
        minDistance = symbolPoint * 30;  // Minimo 3 pips
    }
    minDistance *= 1.5;  // Margine sicurezza 50%

    // Buffer extra per evitare rifiuti marginali
    double buffer = symbolPoint * 10;  // 1 pip extra

    double adaptivePrice = desiredPrice;
    bool priceAdjusted = false;
    string reason = "";

    switch(orderType) {
        case ORDER_TYPE_BUY_LIMIT:
            // BUY LIMIT deve essere SOTTO Ask
            if(desiredPrice >= currentAsk - minDistance) {
                adaptivePrice = currentAsk - minDistance - buffer;
                priceAdjusted = true;
                reason = StringFormat("BUY LIMIT adjusted: %.5f -> %.5f (Ask: %.5f)",
                                      desiredPrice, adaptivePrice, currentAsk);
            }
            break;

        case ORDER_TYPE_SELL_LIMIT:
            // SELL LIMIT deve essere SOPRA Bid
            if(desiredPrice <= currentBid + minDistance) {
                adaptivePrice = currentBid + minDistance + buffer;
                priceAdjusted = true;
                reason = StringFormat("SELL LIMIT adjusted: %.5f -> %.5f (Bid: %.5f)",
                                      desiredPrice, adaptivePrice, currentBid);
            }
            break;

        case ORDER_TYPE_BUY_STOP:
            // BUY STOP deve essere SOPRA Ask
            if(desiredPrice <= currentAsk + minDistance) {
                adaptivePrice = currentAsk + minDistance + buffer;
                priceAdjusted = true;
                reason = StringFormat("BUY STOP adjusted: %.5f -> %.5f (Ask: %.5f)",
                                      desiredPrice, adaptivePrice, currentAsk);
            }
            break;

        case ORDER_TYPE_SELL_STOP:
            // SELL STOP deve essere SOTTO Bid
            if(desiredPrice >= currentBid - minDistance) {
                adaptivePrice = currentBid - minDistance - buffer;
                priceAdjusted = true;
                reason = StringFormat("SELL STOP adjusted: %.5f -> %.5f (Bid: %.5f)",
                                      desiredPrice, adaptivePrice, currentBid);
            }
            break;
    }

    // v5.20 FIX: Log adattamento prezzo e ritorna prezzo valido
    if(priceAdjusted && DetailedLogging) {
        double deviationPips = MathAbs(desiredPrice - adaptivePrice) / symbolPoint / 10;
        Print("[BrokerValidation] ADAPTIVE PRICE: ", reason);
        Print("[BrokerValidation] Deviation: ", DoubleToString(deviationPips, 1), " pips");
    }

    // RETURN ADAPTIVE PRICE - garantisce ordine piazzabile
    return NormalizeDouble(adaptivePrice, symbolDigits);
}

