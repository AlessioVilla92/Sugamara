//+------------------------------------------------------------------+
//|                                           OrderManagerTests.mq5  |
//|                        Sugamara - Order Manager Unit Tests       |
//|                                                                  |
//|  Tests for order validation, retry logic, magic number handling  |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"
#property version   "1.00"
#property script_show_inputs

//+------------------------------------------------------------------+
//| Includes                                                         |
//+------------------------------------------------------------------+
#include "../Config/Enums.mqh"
#include "../Config/InputParameters.mqh"
#include "../Core/GlobalVariables.mqh"

//+------------------------------------------------------------------+
//| STUBS: Mock functions to avoid dependency chains                 |
//+------------------------------------------------------------------+
double GetWinRate() { return 0.0; }
double NormalizeLotSize(double lot) { return lot; }

#include "../Utils/Helpers.mqh"
#include "../Utils/GridHelpers.mqh"
#include "TestFramework.mqh"

//+------------------------------------------------------------------+
//| TESTABLE VERSIONS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Testable: Normalize Lot Size                                     |
//+------------------------------------------------------------------+
double NormalizeLotSize_Testable(double lot, double minLot, double maxLot, double lotStep) {
    // Apply minimum
    if(lot < minLot) lot = minLot;

    // Apply maximum
    if(lot > maxLot) lot = maxLot;

    // Round to step
    lot = MathFloor(lot / lotStep) * lotStep;

    return NormalizeDouble(lot, 2);
}

//+------------------------------------------------------------------+
//| Testable: Is Valid Pending Price (BUY_STOP)                      |
//+------------------------------------------------------------------+
bool IsValidBuyStopPrice_Testable(double orderPrice, double currentAsk, double stopsLevel, double point) {
    // BUY_STOP must be above current ask + stops level
    double minPrice = currentAsk + stopsLevel * point;
    return (orderPrice >= minPrice);
}

//+------------------------------------------------------------------+
//| Testable: Is Valid Pending Price (SELL_STOP)                     |
//+------------------------------------------------------------------+
bool IsValidSellStopPrice_Testable(double orderPrice, double currentBid, double stopsLevel, double point) {
    // SELL_STOP must be below current bid - stops level
    double maxPrice = currentBid - stopsLevel * point;
    return (orderPrice <= maxPrice);
}

//+------------------------------------------------------------------+
//| Testable: Is Valid Pending Price (BUY_LIMIT)                     |
//+------------------------------------------------------------------+
bool IsValidBuyLimitPrice_Testable(double orderPrice, double currentAsk, double stopsLevel, double point) {
    // BUY_LIMIT must be below current ask - stops level
    double maxPrice = currentAsk - stopsLevel * point;
    return (orderPrice <= maxPrice);
}

//+------------------------------------------------------------------+
//| Testable: Is Valid Pending Price (SELL_LIMIT)                    |
//+------------------------------------------------------------------+
bool IsValidSellLimitPrice_Testable(double orderPrice, double currentBid, double stopsLevel, double point) {
    // SELL_LIMIT must be above current bid + stops level
    double minPrice = currentBid + stopsLevel * point;
    return (orderPrice >= minPrice);
}

//+------------------------------------------------------------------+
//| Testable: Get Grid Magic Number                                  |
//+------------------------------------------------------------------+
int GetGridMagic_Testable(ENUM_GRID_SIDE side, int baseMagic) {
    if(side == GRID_A) {
        return baseMagic + MAGIC_OFFSET_GRID_A; // +0
    } else {
        return baseMagic + MAGIC_OFFSET_GRID_B; // +10000
    }
}

//+------------------------------------------------------------------+
//| Testable: Is Sugamara Magic Number                               |
//+------------------------------------------------------------------+
bool IsSugamaraMagic_Testable(long magic, int baseMagic) {
    // Grid A: baseMagic + 0 to +999
    // Grid B: baseMagic + 10000 to +10999
    if(magic >= baseMagic && magic < baseMagic + 1000) return true;
    if(magic >= baseMagic + 10000 && magic < baseMagic + 11000) return true;
    return false;
}

//+------------------------------------------------------------------+
//| Testable: Retry Logic Simulation                                 |
//+------------------------------------------------------------------+
struct RetryResult {
    int attempts;
    bool success;
    int lastErrorCode;
};

RetryResult SimulateRetryLogic_Testable(int maxRetries, int successOnAttempt, int errorCode = 10015) {
    RetryResult result;
    result.attempts = 0;
    result.success = false;
    result.lastErrorCode = 0;

    while(result.attempts < maxRetries) {
        result.attempts++;

        if(result.attempts >= successOnAttempt && successOnAttempt > 0) {
            result.success = true;
            result.lastErrorCode = 0;
            break;
        }

        result.lastErrorCode = errorCode;
    }

    return result;
}

//+------------------------------------------------------------------+
//| TEST SUITE 1: Lot Size Normalization                             |
//+------------------------------------------------------------------+
void Test_LotSizeNormalization() {
    PrintTestHeader("TEST SUITE 1: Lot Size Normalization");

    double minLot = 0.01;
    double maxLot = 100.0;
    double lotStep = 0.01;

    // Test 1.1: Normal lot size
    PrintTestSection("Normal Lot Size");
    AssertEquals("1.1a NormalizeLot.Normal", NormalizeLotSize_Testable(0.05, minLot, maxLot, lotStep), 0.05, 0.001);
    AssertEquals("1.1b NormalizeLot.1Lot", NormalizeLotSize_Testable(1.0, minLot, maxLot, lotStep), 1.0, 0.001);

    // Test 1.2: Below minimum
    PrintTestSection("Below Minimum");
    AssertEquals("1.2a NormalizeLot.BelowMin", NormalizeLotSize_Testable(0.005, minLot, maxLot, lotStep), 0.01, 0.001);
    AssertEquals("1.2b NormalizeLot.Zero", NormalizeLotSize_Testable(0, minLot, maxLot, lotStep), 0.01, 0.001);

    // Test 1.3: Above maximum
    PrintTestSection("Above Maximum");
    AssertEquals("1.3a NormalizeLot.AboveMax", NormalizeLotSize_Testable(150.0, minLot, maxLot, lotStep), 100.0, 0.001);
    AssertEquals("1.3b NormalizeLot.WayAboveMax", NormalizeLotSize_Testable(1000.0, minLot, maxLot, lotStep), 100.0, 0.001);

    // Test 1.4: Step rounding
    PrintTestSection("Step Rounding");
    AssertEquals("1.4a NormalizeLot.StepRound", NormalizeLotSize_Testable(0.125, minLot, maxLot, lotStep), 0.12, 0.001);
    AssertEquals("1.4b NormalizeLot.StepRound2", NormalizeLotSize_Testable(0.129, minLot, maxLot, lotStep), 0.12, 0.001);

    // Test 1.5: Different lot step (0.1)
    PrintTestSection("Different Lot Step");
    lotStep = 0.1;
    AssertEquals("1.5a NormalizeLot.Step0.1", NormalizeLotSize_Testable(0.55, minLot, maxLot, lotStep), 0.5, 0.001);
    AssertEquals("1.5b NormalizeLot.Step0.1b", NormalizeLotSize_Testable(0.99, minLot, maxLot, lotStep), 0.9, 0.001);

    // Test 1.6: Micro lots (0.001 step)
    PrintTestSection("Micro Lots");
    minLot = 0.001;
    lotStep = 0.001;
    AssertEquals("1.6 NormalizeLot.MicroLot", NormalizeLotSize_Testable(0.0015, minLot, maxLot, lotStep), 0.001, 0.0001);
}

//+------------------------------------------------------------------+
//| TEST SUITE 2: Pending Price Validation - BUY STOP                |
//+------------------------------------------------------------------+
void Test_BuyStopPriceValidation() {
    PrintTestHeader("TEST SUITE 2: BUY STOP Price Validation");

    double currentAsk = 1.10000;
    double stopsLevel = 10; // 10 points
    double point = 0.00001;
    // Min valid price = 1.10000 + 10*0.00001 = 1.10010

    // Test 2.1: Valid price (above min)
    PrintTestSection("Valid Prices");
    AssertTrue("2.1a BuyStop.Valid.Above",
               IsValidBuyStopPrice_Testable(1.10020, currentAsk, stopsLevel, point),
               "Price above min should be valid");
    AssertTrue("2.1b BuyStop.Valid.WellAbove",
               IsValidBuyStopPrice_Testable(1.11000, currentAsk, stopsLevel, point),
               "Price well above min should be valid");

    // Test 2.2: Exactly at minimum
    PrintTestSection("At Minimum");
    AssertTrue("2.2 BuyStop.AtMin",
               IsValidBuyStopPrice_Testable(1.10010, currentAsk, stopsLevel, point),
               "Price exactly at min should be valid");

    // Test 2.3: Invalid price (below min)
    PrintTestSection("Invalid Prices");
    AssertFalse("2.3a BuyStop.Invalid.Below",
                IsValidBuyStopPrice_Testable(1.10005, currentAsk, stopsLevel, point),
                "Price below min should be invalid");
    AssertFalse("2.3b BuyStop.Invalid.AtAsk",
                IsValidBuyStopPrice_Testable(1.10000, currentAsk, stopsLevel, point),
                "Price at ask should be invalid");
    AssertFalse("2.3c BuyStop.Invalid.BelowAsk",
                IsValidBuyStopPrice_Testable(1.09990, currentAsk, stopsLevel, point),
                "Price below ask should be invalid");
}

//+------------------------------------------------------------------+
//| TEST SUITE 3: Pending Price Validation - SELL STOP               |
//+------------------------------------------------------------------+
void Test_SellStopPriceValidation() {
    PrintTestHeader("TEST SUITE 3: SELL STOP Price Validation");

    double currentBid = 1.10000;
    double stopsLevel = 10;
    double point = 0.00001;
    // Max valid price = 1.10000 - 10*0.00001 = 1.09990

    // Test 3.1: Valid price (below max)
    PrintTestSection("Valid Prices");
    AssertTrue("3.1a SellStop.Valid.Below",
               IsValidSellStopPrice_Testable(1.09980, currentBid, stopsLevel, point),
               "Price below max should be valid");
    AssertTrue("3.1b SellStop.Valid.WellBelow",
               IsValidSellStopPrice_Testable(1.09000, currentBid, stopsLevel, point),
               "Price well below max should be valid");

    // Test 3.2: Exactly at maximum
    PrintTestSection("At Maximum");
    AssertTrue("3.2 SellStop.AtMax",
               IsValidSellStopPrice_Testable(1.09990, currentBid, stopsLevel, point),
               "Price exactly at max should be valid");

    // Test 3.3: Invalid price (above max)
    PrintTestSection("Invalid Prices");
    AssertFalse("3.3a SellStop.Invalid.Above",
                IsValidSellStopPrice_Testable(1.09995, currentBid, stopsLevel, point),
                "Price above max should be invalid");
    AssertFalse("3.3b SellStop.Invalid.AtBid",
                IsValidSellStopPrice_Testable(1.10000, currentBid, stopsLevel, point),
                "Price at bid should be invalid");
}

//+------------------------------------------------------------------+
//| TEST SUITE 4: Pending Price Validation - BUY LIMIT               |
//+------------------------------------------------------------------+
void Test_BuyLimitPriceValidation() {
    PrintTestHeader("TEST SUITE 4: BUY LIMIT Price Validation");

    double currentAsk = 1.10000;
    double stopsLevel = 10;
    double point = 0.00001;
    // Max valid price = 1.10000 - 10*0.00001 = 1.09990

    // Test 4.1: Valid price (below max)
    PrintTestSection("Valid Prices");
    AssertTrue("4.1a BuyLimit.Valid.Below",
               IsValidBuyLimitPrice_Testable(1.09980, currentAsk, stopsLevel, point),
               "Price below max should be valid");

    // Test 4.2: Exactly at maximum
    PrintTestSection("At Maximum");
    AssertTrue("4.2 BuyLimit.AtMax",
               IsValidBuyLimitPrice_Testable(1.09990, currentAsk, stopsLevel, point),
               "Price exactly at max should be valid");

    // Test 4.3: Invalid price (above max)
    PrintTestSection("Invalid Prices");
    AssertFalse("4.3 BuyLimit.Invalid.Above",
                IsValidBuyLimitPrice_Testable(1.09995, currentAsk, stopsLevel, point),
                "Price above max should be invalid");
}

//+------------------------------------------------------------------+
//| TEST SUITE 5: Pending Price Validation - SELL LIMIT              |
//+------------------------------------------------------------------+
void Test_SellLimitPriceValidation() {
    PrintTestHeader("TEST SUITE 5: SELL LIMIT Price Validation");

    double currentBid = 1.10000;
    double stopsLevel = 10;
    double point = 0.00001;
    // Min valid price = 1.10000 + 10*0.00001 = 1.10010

    // Test 5.1: Valid price (above min)
    PrintTestSection("Valid Prices");
    AssertTrue("5.1a SellLimit.Valid.Above",
               IsValidSellLimitPrice_Testable(1.10020, currentBid, stopsLevel, point),
               "Price above min should be valid");

    // Test 5.2: Exactly at minimum
    PrintTestSection("At Minimum");
    AssertTrue("5.2 SellLimit.AtMin",
               IsValidSellLimitPrice_Testable(1.10010, currentBid, stopsLevel, point),
               "Price exactly at min should be valid");

    // Test 5.3: Invalid price (below min)
    PrintTestSection("Invalid Prices");
    AssertFalse("5.3 SellLimit.Invalid.Below",
                IsValidSellLimitPrice_Testable(1.10005, currentBid, stopsLevel, point),
                "Price below min should be invalid");
}

//+------------------------------------------------------------------+
//| TEST SUITE 6: Magic Number Generation                            |
//+------------------------------------------------------------------+
void Test_MagicNumberGeneration() {
    PrintTestHeader("TEST SUITE 6: Magic Number Generation");

    int baseMagic = 123456;

    // Test 6.1: Grid A magic
    PrintTestSection("Grid A Magic");
    int gridAMagic = GetGridMagic_Testable(GRID_A, baseMagic);
    AssertEqualsInt("6.1 Magic.GridA", gridAMagic, baseMagic, "Grid A magic = base");

    // Test 6.2: Grid B magic
    PrintTestSection("Grid B Magic");
    int gridBMagic = GetGridMagic_Testable(GRID_B, baseMagic);
    AssertEqualsInt("6.2 Magic.GridB", gridBMagic, baseMagic + 10000, "Grid B magic = base + 10000");

    // Test 6.3: Magic difference
    PrintTestSection("Magic Difference");
    AssertEqualsInt("6.3 Magic.Difference", gridBMagic - gridAMagic, 10000, "Difference should be 10000");
}

//+------------------------------------------------------------------+
//| TEST SUITE 7: Is Sugamara Magic                                  |
//+------------------------------------------------------------------+
void Test_IsSugamaraMagic() {
    PrintTestHeader("TEST SUITE 7: Is Sugamara Magic");

    int baseMagic = 123456;

    // Test 7.1: Valid Grid A magic
    PrintTestSection("Valid Grid A");
    AssertTrue("7.1a IsMagic.GridA.Base", IsSugamaraMagic_Testable(123456, baseMagic), "Base magic is Sugamara");
    AssertTrue("7.1b IsMagic.GridA.Plus500", IsSugamaraMagic_Testable(123956, baseMagic), "+500 is Sugamara");
    AssertTrue("7.1c IsMagic.GridA.Plus999", IsSugamaraMagic_Testable(124455, baseMagic), "+999 is Sugamara");

    // Test 7.2: Valid Grid B magic
    PrintTestSection("Valid Grid B");
    AssertTrue("7.2a IsMagic.GridB.Base", IsSugamaraMagic_Testable(133456, baseMagic), "Grid B base is Sugamara");
    AssertTrue("7.2b IsMagic.GridB.Plus500", IsSugamaraMagic_Testable(133956, baseMagic), "Grid B +500 is Sugamara");
    AssertTrue("7.2c IsMagic.GridB.Plus999", IsSugamaraMagic_Testable(134455, baseMagic), "Grid B +999 is Sugamara");

    // Test 7.3: Invalid magic numbers
    PrintTestSection("Invalid Magic");
    AssertFalse("7.3a IsMagic.Invalid.Below", IsSugamaraMagic_Testable(123455, baseMagic), "Below base not Sugamara");
    AssertFalse("7.3b IsMagic.Invalid.Gap", IsSugamaraMagic_Testable(130000, baseMagic), "In gap not Sugamara");
    AssertFalse("7.3c IsMagic.Invalid.Above", IsSugamaraMagic_Testable(140000, baseMagic), "Above Grid B not Sugamara");
    AssertFalse("7.3d IsMagic.Invalid.Other", IsSugamaraMagic_Testable(999999, baseMagic), "Other EA not Sugamara");
}

//+------------------------------------------------------------------+
//| TEST SUITE 8: Retry Logic                                        |
//+------------------------------------------------------------------+
void Test_RetryLogic() {
    PrintTestHeader("TEST SUITE 8: Retry Logic");

    int maxRetries = 5;

    // Test 8.1: Success on first attempt
    PrintTestSection("Success First Attempt");
    RetryResult result = SimulateRetryLogic_Testable(maxRetries, 1);
    AssertTrue("8.1a Retry.FirstAttempt.Success", result.success, "Should succeed");
    AssertEqualsInt("8.1b Retry.FirstAttempt.Attempts", result.attempts, 1, "Should take 1 attempt");

    // Test 8.2: Success on third attempt
    PrintTestSection("Success Third Attempt");
    result = SimulateRetryLogic_Testable(maxRetries, 3);
    AssertTrue("8.2a Retry.ThirdAttempt.Success", result.success, "Should succeed");
    AssertEqualsInt("8.2b Retry.ThirdAttempt.Attempts", result.attempts, 3, "Should take 3 attempts");

    // Test 8.3: Success on last attempt
    PrintTestSection("Success Last Attempt");
    result = SimulateRetryLogic_Testable(maxRetries, 5);
    AssertTrue("8.3a Retry.LastAttempt.Success", result.success, "Should succeed");
    AssertEqualsInt("8.3b Retry.LastAttempt.Attempts", result.attempts, 5, "Should take 5 attempts");

    // Test 8.4: Failure after all retries
    PrintTestSection("Failure After Retries");
    result = SimulateRetryLogic_Testable(maxRetries, 0); // Never succeeds
    AssertFalse("8.4a Retry.AllFailed.Success", result.success, "Should fail");
    AssertEqualsInt("8.4b Retry.AllFailed.Attempts", result.attempts, maxRetries, "Should exhaust all retries");
    AssertEqualsInt("8.4c Retry.AllFailed.ErrorCode", result.lastErrorCode, 10015, "Should have error code");

    // Test 8.5: Different max retries
    PrintTestSection("Different Max Retries");
    result = SimulateRetryLogic_Testable(3, 0);
    AssertEqualsInt("8.5 Retry.MaxRetries3", result.attempts, 3, "Should stop at 3 retries");
}

//+------------------------------------------------------------------+
//| TEST SUITE 9: Edge Cases                                         |
//+------------------------------------------------------------------+
void Test_EdgeCases() {
    PrintTestHeader("TEST SUITE 9: Edge Cases");

    // Test 9.1: Zero stops level
    PrintTestSection("Zero Stops Level");
    double currentAsk = 1.10000;
    double stopsLevel = 0;
    double point = 0.00001;
    AssertTrue("9.1 ZeroStopsLevel",
               IsValidBuyStopPrice_Testable(1.10000, currentAsk, stopsLevel, point),
               "Should be valid with zero stops level");

    // Test 9.2: Very large stops level
    PrintTestSection("Large Stops Level");
    stopsLevel = 1000; // 100 pips
    AssertFalse("9.2 LargeStopsLevel",
                IsValidBuyStopPrice_Testable(1.10050, currentAsk, stopsLevel, point),
                "Should be invalid with large stops level");

    // Test 9.3: Negative lot (edge case)
    PrintTestSection("Negative Lot");
    double lot = NormalizeLotSize_Testable(-0.05, 0.01, 100.0, 0.01);
    AssertEquals("9.3 NegativeLot", lot, 0.01, 0.001, "Negative lot should become minimum");

    // Test 9.4: Magic number boundary
    PrintTestSection("Magic Boundary");
    int baseMagic = 123456;
    AssertTrue("9.4a Magic.Boundary.GridA.Max", IsSugamaraMagic_Testable(124455, baseMagic), "+999 is valid");
    AssertFalse("9.4b Magic.Boundary.GridA.Over", IsSugamaraMagic_Testable(124456, baseMagic), "+1000 is invalid");

    // Test 9.5: Retry with success after max
    PrintTestSection("Success After Max");
    RetryResult result = SimulateRetryLogic_Testable(3, 5); // Would succeed on 5th, but max is 3
    AssertFalse("9.5 RetryAfterMax", result.success, "Should fail if success attempt > max");
}

//+------------------------------------------------------------------+
//| Script Start                                                     |
//+------------------------------------------------------------------+
void OnStart() {
    PrintTestBanner("OrderManagerTests");

    // Setup environment
    SetupBaseTestEnvironment();
    SaveAllInputParameters();

    // Run all test suites
    Test_LotSizeNormalization();
    Test_BuyStopPriceValidation();
    Test_SellStopPriceValidation();
    Test_BuyLimitPriceValidation();
    Test_SellLimitPriceValidation();
    Test_MagicNumberGeneration();
    Test_IsSugamaraMagic();
    Test_RetryLogic();
    Test_EdgeCases();

    // Restore and summarize
    RestoreAllInputParameters();
    PrintTestSummary();
}
//+------------------------------------------------------------------+
