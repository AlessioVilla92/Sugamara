//+------------------------------------------------------------------+
//|                                            RiskManagerTests.mq5  |
//|                        Sugamara - Risk Manager Unit Tests        |
//|                                                                  |
//|  Tests for emergency stop, margin checks, drawdown tracking      |
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
void EmergencyCloseAll() { Print("STUB: EmergencyCloseAll"); }
void CalculateTotalExposure() { }
ENUM_ATR_CONDITION GetATRCondition(double atrPips) { return ATR_NORMAL; }
ENUM_ATR_CONDITION GetATRCondition() { return ATR_NORMAL; }
double GetATRPips() { return 10.0; }
string GetATRConditionName(ENUM_ATR_CONDITION condition) { return "NORMAL"; }

#include "../Utils/Helpers.mqh"
#include "../Utils/GridHelpers.mqh"
#include "../Trading/RiskManager.mqh"
#include "TestFramework.mqh"

//+------------------------------------------------------------------+
//| TESTABLE VERSIONS - Accept parameters for deterministic testing  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Testable: Calculate Drawdown Percent                             |
//+------------------------------------------------------------------+
double CalculateDrawdownPercent_Testable(double currentEquity, double startingEquity) {
    if(startingEquity <= 0) return 0;
    if(currentEquity >= startingEquity) return 0;
    return ((startingEquity - currentEquity) / startingEquity) * 100.0;
}

//+------------------------------------------------------------------+
//| Testable: Calculate Drawdown From Peak                           |
//+------------------------------------------------------------------+
double CalculateDrawdownFromPeak_Testable(double currentEquity, double peakEquity) {
    if(peakEquity <= 0) return 0;
    if(currentEquity >= peakEquity) return 0;
    return ((peakEquity - currentEquity) / peakEquity) * 100.0;
}

//+------------------------------------------------------------------+
//| Testable: Check Emergency Stop Condition                         |
//+------------------------------------------------------------------+
bool ShouldTriggerEmergencyStop_Testable(double drawdownPercent, double emergencyThreshold) {
    return (drawdownPercent >= emergencyThreshold);
}

//+------------------------------------------------------------------+
//| Testable: Check Margin Sufficient                                |
//+------------------------------------------------------------------+
bool IsMarginSufficient_Testable(double freeMargin, double equity, double marginLevel) {
    // Dynamic margin check: 1% of equity, minimum $50
    double minMarginRequired = equity * 0.01;
    if(minMarginRequired < 50) minMarginRequired = 50;

    if(freeMargin < minMarginRequired) {
        return false;
    }

    // Margin level check (if positions open)
    if(marginLevel > 0 && marginLevel < 200) {
        return false;
    }

    return true;
}

//+------------------------------------------------------------------+
//| Testable: Get Exposure Risk Level                                |
//+------------------------------------------------------------------+
int GetExposureRiskLevel_Testable(double absNetExposure, double maxAllowed) {
    if(absNetExposure <= maxAllowed * 0.5) return 0;   // Safe
    if(absNetExposure <= maxAllowed) return 1;         // Warning
    return 2;  // Critical
}

//+------------------------------------------------------------------+
//| Testable: Get Volatility Lot Multiplier                          |
//+------------------------------------------------------------------+
double GetVolatilityLotMultiplier_Testable(int volatilityRiskLevel) {
    switch(volatilityRiskLevel) {
        case 0: return 1.0;    // CALM - Full size
        case 1: return 1.0;    // NORMAL - Full size
        case 2: return 0.75;   // VOLATILE - 75% size
        case 3: return 0.5;    // EXTREME - 50% size
    }
    return 1.0;
}

//+------------------------------------------------------------------+
//| TEST SUITE 1: Emergency Stop Trigger                             |
//+------------------------------------------------------------------+
void Test_EmergencyStopTrigger() {
    PrintTestHeader("TEST SUITE 1: Emergency Stop Trigger");

    double startEquity = 10000.0;
    double emergencyThreshold = 20.0; // 20%

    // Test 1.1: No drawdown - should NOT trigger
    PrintTestSection("No Drawdown");
    double currentEquity = 10000.0;
    double dd = CalculateDrawdownPercent_Testable(currentEquity, startEquity);
    AssertEquals("1.1a Drawdown.NoLoss", dd, 0.0, 0.01);
    AssertFalse("1.1b EmergencyStop.NoTrigger",
                ShouldTriggerEmergencyStop_Testable(dd, emergencyThreshold),
                "Should NOT trigger with 0% drawdown");

    // Test 1.2: Small drawdown (5%) - should NOT trigger
    PrintTestSection("Small Drawdown (5%)");
    currentEquity = 9500.0;
    dd = CalculateDrawdownPercent_Testable(currentEquity, startEquity);
    AssertEquals("1.2a Drawdown.5Percent", dd, 5.0, 0.01);
    AssertFalse("1.2b EmergencyStop.NoTrigger",
                ShouldTriggerEmergencyStop_Testable(dd, emergencyThreshold),
                "Should NOT trigger with 5% drawdown");

    // Test 1.3: Medium drawdown (15%) - should NOT trigger
    PrintTestSection("Medium Drawdown (15%)");
    currentEquity = 8500.0;
    dd = CalculateDrawdownPercent_Testable(currentEquity, startEquity);
    AssertEquals("1.3a Drawdown.15Percent", dd, 15.0, 0.01);
    AssertFalse("1.3b EmergencyStop.NoTrigger",
                ShouldTriggerEmergencyStop_Testable(dd, emergencyThreshold),
                "Should NOT trigger with 15% drawdown");

    // Test 1.4: Exactly at threshold (20%) - should trigger
    PrintTestSection("Exactly at Threshold (20%)");
    currentEquity = 8000.0;
    dd = CalculateDrawdownPercent_Testable(currentEquity, startEquity);
    AssertEquals("1.4a Drawdown.20Percent", dd, 20.0, 0.01);
    AssertTrue("1.4b EmergencyStop.Trigger",
               ShouldTriggerEmergencyStop_Testable(dd, emergencyThreshold),
               "Should trigger at exactly 20% drawdown");

    // Test 1.5: Above threshold (25%) - should trigger
    PrintTestSection("Above Threshold (25%)");
    currentEquity = 7500.0;
    dd = CalculateDrawdownPercent_Testable(currentEquity, startEquity);
    AssertEquals("1.5a Drawdown.25Percent", dd, 25.0, 0.01);
    AssertTrue("1.5b EmergencyStop.Trigger",
               ShouldTriggerEmergencyStop_Testable(dd, emergencyThreshold),
               "Should trigger at 25% drawdown");

    // Test 1.6: Severe drawdown (50%) - should trigger
    PrintTestSection("Severe Drawdown (50%)");
    currentEquity = 5000.0;
    dd = CalculateDrawdownPercent_Testable(currentEquity, startEquity);
    AssertEquals("1.6a Drawdown.50Percent", dd, 50.0, 0.01);
    AssertTrue("1.6b EmergencyStop.Trigger",
               ShouldTriggerEmergencyStop_Testable(dd, emergencyThreshold),
               "Should trigger at 50% drawdown");

    // Test 1.7: Different threshold (10%)
    PrintTestSection("Different Threshold (10%)");
    emergencyThreshold = 10.0;
    currentEquity = 9000.0;
    dd = CalculateDrawdownPercent_Testable(currentEquity, startEquity);
    AssertTrue("1.7 EmergencyStop.10PercentThreshold",
               ShouldTriggerEmergencyStop_Testable(dd, emergencyThreshold),
               "Should trigger at 10% DD with 10% threshold");
}

//+------------------------------------------------------------------+
//| TEST SUITE 2: Drawdown From Peak Calculation                     |
//+------------------------------------------------------------------+
void Test_DrawdownFromPeak() {
    PrintTestHeader("TEST SUITE 2: Drawdown From Peak");

    // Test 2.1: At peak - no drawdown
    PrintTestSection("At Peak");
    double peakEquity = 12000.0;
    double currentEquity = 12000.0;
    double dd = CalculateDrawdownFromPeak_Testable(currentEquity, peakEquity);
    AssertEquals("2.1 DrawdownFromPeak.AtPeak", dd, 0.0, 0.01);

    // Test 2.2: Above peak - no drawdown
    PrintTestSection("Above Peak (new high)");
    currentEquity = 13000.0;
    dd = CalculateDrawdownFromPeak_Testable(currentEquity, peakEquity);
    AssertEquals("2.2 DrawdownFromPeak.AbovePeak", dd, 0.0, 0.01);

    // Test 2.3: 10% below peak
    PrintTestSection("10% Below Peak");
    currentEquity = 10800.0;
    dd = CalculateDrawdownFromPeak_Testable(currentEquity, peakEquity);
    AssertEquals("2.3 DrawdownFromPeak.10Percent", dd, 10.0, 0.01);

    // Test 2.4: 25% below peak
    PrintTestSection("25% Below Peak");
    currentEquity = 9000.0;
    dd = CalculateDrawdownFromPeak_Testable(currentEquity, peakEquity);
    AssertEquals("2.4 DrawdownFromPeak.25Percent", dd, 25.0, 0.01);

    // Test 2.5: Peak tracking with rising equity
    PrintTestSection("Peak Tracking Simulation");
    double equityHistory[] = {10000, 10500, 11000, 10800, 11500, 11000, 12000, 11500};
    double maxPeak = 10000;
    double maxDD = 0;

    for(int i = 0; i < ArraySize(equityHistory); i++) {
        if(equityHistory[i] > maxPeak) maxPeak = equityHistory[i];
        double currentDD = CalculateDrawdownFromPeak_Testable(equityHistory[i], maxPeak);
        if(currentDD > maxDD) maxDD = currentDD;
    }

    AssertEquals("2.5a PeakTracking.MaxPeak", maxPeak, 12000.0, 0.01);
    // Max DD should be when equity dropped from 12000 to 11500 = 4.17%
    AssertGreaterThan("2.5b PeakTracking.MaxDD", maxDD, 4.0, "Max DD should be > 4%");
}

//+------------------------------------------------------------------+
//| TEST SUITE 3: Margin Sufficiency Check                           |
//+------------------------------------------------------------------+
void Test_MarginSufficiency() {
    PrintTestHeader("TEST SUITE 3: Margin Sufficiency Check");

    // Test 3.1: Sufficient margin - high equity
    PrintTestSection("Sufficient Margin - High Equity");
    double equity = 10000.0;
    double freeMargin = 5000.0;
    double marginLevel = 500.0;
    AssertTrue("3.1 MarginCheck.Sufficient",
               IsMarginSufficient_Testable(freeMargin, equity, marginLevel),
               "Should pass with adequate margin");

    // Test 3.2: Low free margin (below 1% of equity)
    PrintTestSection("Low Free Margin");
    freeMargin = 80.0; // Below 1% of 10000 = 100
    AssertFalse("3.2 MarginCheck.LowFreeMargin",
                IsMarginSufficient_Testable(freeMargin, equity, marginLevel),
                "Should fail with free margin < 1% of equity");

    // Test 3.3: Minimum absolute $50 check
    PrintTestSection("Minimum $50 Check");
    equity = 3000.0; // 1% = $30, but minimum is $50
    freeMargin = 40.0;
    AssertFalse("3.3a MarginCheck.Below50Min",
                IsMarginSufficient_Testable(freeMargin, equity, marginLevel),
                "Should fail with free margin < $50 minimum");

    freeMargin = 60.0;
    AssertTrue("3.3b MarginCheck.Above50Min",
               IsMarginSufficient_Testable(freeMargin, equity, marginLevel),
               "Should pass with free margin > $50 minimum");

    // Test 3.4: Low margin level (< 200%)
    PrintTestSection("Low Margin Level");
    equity = 10000.0;
    freeMargin = 5000.0;
    marginLevel = 150.0; // Below 200% threshold
    AssertFalse("3.4 MarginCheck.LowMarginLevel",
                IsMarginSufficient_Testable(freeMargin, equity, marginLevel),
                "Should fail with margin level < 200%");

    // Test 3.5: Margin level exactly at 200%
    PrintTestSection("Margin Level at 200%");
    marginLevel = 200.0;
    AssertTrue("3.5 MarginCheck.MarginLevel200",
               IsMarginSufficient_Testable(freeMargin, equity, marginLevel),
               "Should pass with margin level >= 200%");

    // Test 3.6: No positions (margin level = 0)
    PrintTestSection("No Open Positions");
    marginLevel = 0; // No positions
    AssertTrue("3.6 MarginCheck.NoPositions",
               IsMarginSufficient_Testable(freeMargin, equity, marginLevel),
               "Should pass when no positions (margin level = 0)");
}

//+------------------------------------------------------------------+
//| TEST SUITE 4: Exposure Risk Level                                |
//+------------------------------------------------------------------+
void Test_ExposureRiskLevel() {
    PrintTestHeader("TEST SUITE 4: Exposure Risk Level");

    double maxAllowed = 1.0; // 1 lot max

    // Test 4.1: Safe (0-50% of max)
    PrintTestSection("Safe Zone");
    AssertEqualsInt("4.1a ExposureRisk.Zero", GetExposureRiskLevel_Testable(0, maxAllowed), 0);
    AssertEqualsInt("4.1b ExposureRisk.25Percent", GetExposureRiskLevel_Testable(0.25, maxAllowed), 0);
    AssertEqualsInt("4.1c ExposureRisk.50Percent", GetExposureRiskLevel_Testable(0.5, maxAllowed), 0);

    // Test 4.2: Warning (50-100% of max)
    PrintTestSection("Warning Zone");
    AssertEqualsInt("4.2a ExposureRisk.51Percent", GetExposureRiskLevel_Testable(0.51, maxAllowed), 1);
    AssertEqualsInt("4.2b ExposureRisk.75Percent", GetExposureRiskLevel_Testable(0.75, maxAllowed), 1);
    AssertEqualsInt("4.2c ExposureRisk.100Percent", GetExposureRiskLevel_Testable(1.0, maxAllowed), 1);

    // Test 4.3: Critical (> 100% of max)
    PrintTestSection("Critical Zone");
    AssertEqualsInt("4.3a ExposureRisk.101Percent", GetExposureRiskLevel_Testable(1.01, maxAllowed), 2);
    AssertEqualsInt("4.3b ExposureRisk.150Percent", GetExposureRiskLevel_Testable(1.5, maxAllowed), 2);
    AssertEqualsInt("4.3c ExposureRisk.200Percent", GetExposureRiskLevel_Testable(2.0, maxAllowed), 2);
}

//+------------------------------------------------------------------+
//| TEST SUITE 5: Volatility Lot Multiplier                          |
//+------------------------------------------------------------------+
void Test_VolatilityLotMultiplier() {
    PrintTestHeader("TEST SUITE 5: Volatility Lot Multiplier");

    // Test 5.1: CALM (risk level 0) = Full size
    AssertEquals("5.1 LotMultiplier.CALM", GetVolatilityLotMultiplier_Testable(0), 1.0, 0.001);

    // Test 5.2: NORMAL (risk level 1) = Full size
    AssertEquals("5.2 LotMultiplier.NORMAL", GetVolatilityLotMultiplier_Testable(1), 1.0, 0.001);

    // Test 5.3: VOLATILE (risk level 2) = 75%
    AssertEquals("5.3 LotMultiplier.VOLATILE", GetVolatilityLotMultiplier_Testable(2), 0.75, 0.001);

    // Test 5.4: EXTREME (risk level 3) = 50%
    AssertEquals("5.4 LotMultiplier.EXTREME", GetVolatilityLotMultiplier_Testable(3), 0.5, 0.001);

    // Test 5.5: Applied lot calculation
    PrintTestSection("Applied Lot Calculation");
    double baseLot = 0.10;

    double calmLot = baseLot * GetVolatilityLotMultiplier_Testable(0);
    AssertEquals("5.5a AppliedLot.CALM", calmLot, 0.10, 0.001);

    double volatileLot = baseLot * GetVolatilityLotMultiplier_Testable(2);
    AssertEquals("5.5b AppliedLot.VOLATILE", volatileLot, 0.075, 0.001);

    double extremeLot = baseLot * GetVolatilityLotMultiplier_Testable(3);
    AssertEquals("5.5c AppliedLot.EXTREME", extremeLot, 0.05, 0.001);
}

//+------------------------------------------------------------------+
//| TEST SUITE 6: Max Drawdown Tracking                              |
//+------------------------------------------------------------------+
void Test_MaxDrawdownTracking() {
    PrintTestHeader("TEST SUITE 6: Max Drawdown Tracking");

    // Simulate equity sequence with drawdowns
    double equitySequence[] = {10000, 9500, 9800, 9200, 9600, 8800, 9000, 10200, 9800};
    double startEquity = 10000.0;
    double maxDD = 0;

    PrintTestSection("Equity Sequence Analysis");
    for(int i = 0; i < ArraySize(equitySequence); i++) {
        double dd = CalculateDrawdownPercent_Testable(equitySequence[i], startEquity);
        if(dd > maxDD) maxDD = dd;
        Print("  Step ", i, ": Equity=", equitySequence[i], " DD=", DoubleToString(dd, 2), "%");
    }

    // Max DD should be at 8800 = 12%
    AssertEquals("6.1 MaxDD.Tracked", maxDD, 12.0, 0.01, "Max DD should be 12%");

    // Test 6.2: Max DD updates correctly
    PrintTestSection("Max DD Update Logic");
    double newEquity = 8500.0; // 15% DD
    double newDD = CalculateDrawdownPercent_Testable(newEquity, startEquity);
    if(newDD > maxDD) maxDD = newDD;
    AssertEquals("6.2 MaxDD.Updated", maxDD, 15.0, 0.01, "Max DD should update to 15%");

    // Test 6.3: Max DD doesn't decrease
    newEquity = 9500.0; // 5% DD (less than max)
    newDD = CalculateDrawdownPercent_Testable(newEquity, startEquity);
    if(newDD > maxDD) maxDD = newDD;
    AssertEquals("6.3 MaxDD.NotDecreased", maxDD, 15.0, 0.01, "Max DD should stay at 15%");
}

//+------------------------------------------------------------------+
//| TEST SUITE 7: Edge Cases                                         |
//+------------------------------------------------------------------+
void Test_EdgeCases() {
    PrintTestHeader("TEST SUITE 7: Edge Cases");

    // Test 7.1: Zero starting equity
    PrintTestSection("Zero Starting Equity");
    double dd = CalculateDrawdownPercent_Testable(5000, 0);
    AssertEquals("7.1 ZeroStartEquity", dd, 0.0, 0.01, "Should return 0 for zero start");

    // Test 7.2: Negative equity (edge case)
    PrintTestSection("Negative Equity");
    dd = CalculateDrawdownPercent_Testable(-1000, 10000);
    AssertGreaterThan("7.2 NegativeEquity", dd, 100.0, "DD > 100% for negative equity");

    // Test 7.3: Very small equity
    PrintTestSection("Very Small Equity");
    dd = CalculateDrawdownPercent_Testable(100, 10000);
    AssertEquals("7.3 SmallEquity", dd, 99.0, 0.01, "99% DD");

    // Test 7.4: Margin check with very large equity
    PrintTestSection("Large Equity Margin Check");
    bool result = IsMarginSufficient_Testable(50000, 1000000, 500);
    AssertTrue("7.4 LargeEquity.MarginCheck", result, "Should pass with large equity");

    // Test 7.5: Zero exposure
    PrintTestSection("Zero Exposure");
    int riskLevel = GetExposureRiskLevel_Testable(0, 1.0);
    AssertEqualsInt("7.5 ZeroExposure.RiskLevel", riskLevel, 0);

    // Test 7.6: Very large exposure
    PrintTestSection("Very Large Exposure");
    riskLevel = GetExposureRiskLevel_Testable(10.0, 1.0);
    AssertEqualsInt("7.6 LargeExposure.RiskLevel", riskLevel, 2);
}

//+------------------------------------------------------------------+
//| Script Start                                                     |
//+------------------------------------------------------------------+
void OnStart() {
    PrintTestBanner("RiskManagerTests");

    // Setup environment
    SetupBaseTestEnvironment();
    SaveAllInputParameters();

    // Run all test suites
    Test_EmergencyStopTrigger();
    Test_DrawdownFromPeak();
    Test_MarginSufficiency();
    Test_ExposureRiskLevel();
    Test_VolatilityLotMultiplier();
    Test_MaxDrawdownTracking();
    Test_EdgeCases();

    // Restore and summarize
    RestoreAllInputParameters();
    PrintTestSummary();
}
//+------------------------------------------------------------------+
