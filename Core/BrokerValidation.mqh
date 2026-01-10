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
    Log_Header("LOADING BROKER SPECIFICATIONS");

    // Symbol basic info
    symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);

    if(symbolPoint <= 0) {
        Log_SystemError("Broker", 0, StringFormat("Invalid symbol point: %f", symbolPoint));
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
        Log_SystemError("Broker", 0, StringFormat("Invalid min lot: %f", symbolMinLot));
        return false;
    }

    if(symbolLotStep <= 0) {
        Log_SystemError("Broker", 0, StringFormat("Invalid lot step: %f", symbolLotStep));
        return false;
    }

    // Log specifications
    Log_KeyValue("Symbol", _Symbol);
    Log_KeyValueNum("Point", symbolPoint, symbolDigits);
    Log_KeyValueNum("Digits", symbolDigits, 0);
    Log_KeyValueNum("Stops Level", symbolStopsLevel, 0);
    Log_KeyValueNum("Freeze Level", symbolFreezeLevel, 0);
    Log_KeyValueNum("Min Lot", symbolMinLot, 2);
    Log_KeyValueNum("Max Lot", symbolMaxLot, 2);
    Log_KeyValueNum("Lot Step", symbolLotStep, 2);
    Log_KeyValue("Spread", StringFormat("%d pts (%.1f pips)", symbolSpreadPoints, PointsToPips(symbolSpreadPoints * symbolPoint)));
    Log_Separator();

    return true;
}

//+------------------------------------------------------------------+
//| Validate Input Parameters                                        |
//| Checks user inputs are within acceptable ranges                  |
//+------------------------------------------------------------------+
bool ValidateInputParameters() {
    Log_Header("VALIDATING INPUT PARAMETERS");

    int errors = 0;
    int warnings = 0;

    // CHECK 1: Grid Levels
    if(GridLevelsPerSide < 3 || GridLevelsPerSide > MAX_GRID_LEVELS) {
        Log_SystemError("Validation", 0, StringFormat("GridLevelsPerSide must be 3-%d (current: %d)", MAX_GRID_LEVELS, GridLevelsPerSide));
        errors++;
    }

    // CHECK 2: Base Lot
    if(BaseLot < symbolMinLot) {
        Log_SystemError("Validation", 0, StringFormat("BaseLot %.2f below broker min %.2f", BaseLot, symbolMinLot));
        errors++;
    }

    if(BaseLot > symbolMaxLot) {
        Log_SystemError("Validation", 0, StringFormat("BaseLot %.2f exceeds broker max %.2f", BaseLot, symbolMaxLot));
        errors++;
    }

    // CHECK 3: Spacing
    if(SpacingMode == SPACING_FIXED) {
        if(Fixed_Spacing_Pips < MIN_SPACING_PIPS) {
            Log_SystemWarning("Validation", StringFormat("Spacing %.1f below recommended min %.1f", Fixed_Spacing_Pips, MIN_SPACING_PIPS));
            warnings++;
        }
        if(Fixed_Spacing_Pips > MAX_SPACING_PIPS) {
            Log_SystemWarning("Validation", StringFormat("Spacing %.1f above recommended max %.1f", Fixed_Spacing_Pips, MAX_SPACING_PIPS));
            warnings++;
        }
    }

    // CHECK 4: Lot Multiplier (Progressive mode)
    if(LotMode == LOT_PROGRESSIVE) {
        if(LotMultiplier < 1.0) {
            Log_SystemError("Validation", 0, StringFormat("LotMultiplier must be >= 1.0 (current: %.2f)", LotMultiplier));
            errors++;
        }
        if(LotMultiplier > 2.0) {
            Log_SystemWarning("Validation", StringFormat("LotMultiplier %.2f is aggressive", LotMultiplier));
            warnings++;
        }

        // Check if progression exceeds max lot
        double projectedMaxLot = BaseLot * MathPow(LotMultiplier, GridLevelsPerSide - 1);
        if(projectedMaxLot > MaxLotPerLevel) {
            Log_Debug("Validation", StringFormat("Lot progression capped at %.2f (projected: %.2f)", MaxLotPerLevel, projectedMaxLot));
        }
    }

    // CHECK 6: Emergency Stop
    if(EnableEmergencyStop) {
        if(EmergencyStop_Percent < 5 || EmergencyStop_Percent > 50) {
            Log_SystemWarning("Validation", StringFormat("EmergencyStop %.1f%% outside typical 5-50%%", EmergencyStop_Percent));
            warnings++;
        }
    }

    // CHECK 7: Broker Minimum Distance
    double brokerMinPips = PointsToPips(symbolStopsLevel * symbolPoint);
    if(brokerMinPips < 0.1) brokerMinPips = 5.0;

    if(SpacingMode == SPACING_FIXED && Fixed_Spacing_Pips < brokerMinPips) {
        Log_SystemWarning("Validation", StringFormat("Spacing %.1f < broker min %.1f pips - orders may reject", Fixed_Spacing_Pips, brokerMinPips));
        warnings++;
    }

    // CHECK 8: Hedging Mode Required
    if(AllowHedging) {
        ENUM_ACCOUNT_MARGIN_MODE marginMode =
            (ENUM_ACCOUNT_MARGIN_MODE)AccountInfoInteger(ACCOUNT_MARGIN_MODE);

        if(marginMode != ACCOUNT_MARGIN_MODE_RETAIL_HEDGING) {
            Log_SystemError("Validation", 0, StringFormat("Requires HEDGING mode (current: %s)", EnumToString(marginMode)));
            errors++;
        } else {
            Log_Debug("Validation", "Account in HEDGING mode - OK");
        }
    }

    // CHECK 9: Magic Number
    if(MagicNumber <= 0) {
        Log_SystemError("Validation", 0, StringFormat("MagicNumber must be positive (current: %d)", MagicNumber));
        errors++;
    }

    // SUMMARY
    Log_SubHeader("VALIDATION SUMMARY");
    Log_KeyValueNum("Errors", errors, 0);
    Log_KeyValueNum("Warnings", warnings, 0);

    if(errors > 0) {
        Log_KeyValue("Result", StringFormat("FAILED - %d error(s)", errors));
        if(EnableAlerts) {
            Alert("SUGAMARA: Input validation FAILED - check Expert Log");
        }
        Log_Separator();
        return false;
    }

    if(warnings > 0) {
        Log_KeyValue("Result", StringFormat("PASSED with %d warning(s)", warnings));
    } else {
        Log_KeyValue("Result", "PASSED - All parameters valid");
    }

    Log_Separator();
    return true;
}

//+------------------------------------------------------------------+
//| Validate Broker Minimums (LOG-ONLY - Never blocks)               |
//+------------------------------------------------------------------+
bool ValidateBrokerMinimums() {
    Log_SubHeader("BROKER DISTANCE CHECK");

    double brokerStopsPips = PointsToPips(symbolStopsLevel * symbolPoint);
    double brokerFreezePips = PointsToPips(symbolFreezeLevel * symbolPoint);
    double brokerMinimum = MathMax(brokerStopsPips, brokerFreezePips);

    if(brokerMinimum < 0.1) {
        brokerMinimum = 5.0;
        Log_Debug("Broker", "No min distance from broker - using 5.0 pips default");
    }

    Log_KeyValueNum("Stops Level", brokerStopsPips, 1);
    Log_KeyValueNum("Freeze Level", brokerFreezePips, 1);
    Log_KeyValueNum("Effective Min", brokerMinimum, 1);

    // Check current spacing against broker minimum
    if(currentSpacing_Pips > 0 && currentSpacing_Pips < brokerMinimum) {
        Log_SystemWarning("Broker", StringFormat("Spacing %.1f < broker min %.1f - orders may reject", currentSpacing_Pips, brokerMinimum));
    } else if(currentSpacing_Pips > 0) {
        Log_Debug("Broker", StringFormat("Spacing %.1f >= broker min - OK", currentSpacing_Pips));
    }

    Log_Separator();

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

