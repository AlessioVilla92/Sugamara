//+------------------------------------------------------------------+
//|                                           ATRCalculatorTests.mq5 |
//|                        Sugamara - ATR Calculator Unit Tests      |
//|                                                                  |
//|  Tests for ATR condition classification, JPY correction, cache   |
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
#include "../Utils/Helpers.mqh"
#include "TestFramework.mqh"

//+------------------------------------------------------------------+
//| ATR THRESHOLDS (from ATRCalculator.mqh)                          |
//+------------------------------------------------------------------+
#define ATR_THRESHOLD_CALM      8.0
#define ATR_THRESHOLD_NORMAL    15.0
#define ATR_THRESHOLD_VOLATILE  30.0

//+------------------------------------------------------------------+
//| TESTABLE VERSIONS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Testable: Get ATR Condition                                      |
//+------------------------------------------------------------------+
ENUM_ATR_CONDITION GetATRCondition_Testable(double atrPips) {
    if(atrPips < ATR_THRESHOLD_CALM) {
        return ATR_CALM;
    } else if(atrPips < ATR_THRESHOLD_NORMAL) {
        return ATR_NORMAL;
    } else if(atrPips < ATR_THRESHOLD_VOLATILE) {
        return ATR_VOLATILE;
    } else {
        return ATR_EXTREME;
    }
}

//+------------------------------------------------------------------+
//| Testable: Get ATR Condition Name                                 |
//+------------------------------------------------------------------+
string GetATRConditionName_Testable(ENUM_ATR_CONDITION condition) {
    switch(condition) {
        case ATR_CALM:     return "CALM";
        case ATR_NORMAL:   return "NORMAL";
        case ATR_VOLATILE: return "VOLATILE";
        case ATR_EXTREME:  return "EXTREME";
        default:           return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Testable: Is Market Calm                                         |
//+------------------------------------------------------------------+
bool IsMarketCalm_Testable(double atrPips) {
    ENUM_ATR_CONDITION condition = GetATRCondition_Testable(atrPips);
    return (condition == ATR_CALM || condition == ATR_NORMAL);
}

//+------------------------------------------------------------------+
//| Testable: Apply JPY Correction                                   |
//+------------------------------------------------------------------+
double ApplyJPYCorrection_Testable(double atrPips, int digits) {
    // JPY pairs have 3 digits (or 5 with fractional pips)
    if(digits == 3 || digits == 2) {
        return atrPips / 10.0;
    }
    return atrPips;
}

//+------------------------------------------------------------------+
//| Testable: Get ATR Trend                                          |
//+------------------------------------------------------------------+
int GetATRTrend_Testable(double recentAvg, double olderAvg) {
    if(recentAvg > olderAvg * 1.1) return 1;   // Increasing
    if(recentAvg < olderAvg * 0.9) return -1;  // Decreasing
    return 0;  // Stable
}

//+------------------------------------------------------------------+
//| Testable: Calculate Average                                      |
//+------------------------------------------------------------------+
double CalculateAverage_Testable(double &values[], int count) {
    if(count <= 0) return 0;
    double sum = 0;
    for(int i = 0; i < count; i++) {
        sum += values[i];
    }
    return sum / count;
}

//+------------------------------------------------------------------+
//| Testable: Is Cache Valid                                         |
//+------------------------------------------------------------------+
bool IsCacheValid_Testable(datetime lastBarTime, datetime currentBarTime, bool isValid) {
    if(!isValid) return false;
    return (lastBarTime == currentBarTime);
}

//+------------------------------------------------------------------+
//| TEST SUITE 1: ATR Condition Classification                       |
//+------------------------------------------------------------------+
void Test_ATRConditionClassification() {
    PrintTestHeader("TEST SUITE 1: ATR Condition Classification");

    // Test 1.1: CALM condition (< 8 pips)
    PrintTestSection("CALM Condition (< 8 pips)");
    AssertTrue("1.1a ATR.CALM.0", GetATRCondition_Testable(0) == ATR_CALM, "0 pips = CALM");
    AssertTrue("1.1b ATR.CALM.5", GetATRCondition_Testable(5.0) == ATR_CALM, "5 pips = CALM");
    AssertTrue("1.1c ATR.CALM.7.9", GetATRCondition_Testable(7.9) == ATR_CALM, "7.9 pips = CALM");

    // Test 1.2: NORMAL condition (8-15 pips)
    PrintTestSection("NORMAL Condition (8-15 pips)");
    AssertTrue("1.2a ATR.NORMAL.8", GetATRCondition_Testable(8.0) == ATR_NORMAL, "8 pips = NORMAL");
    AssertTrue("1.2b ATR.NORMAL.10", GetATRCondition_Testable(10.0) == ATR_NORMAL, "10 pips = NORMAL");
    AssertTrue("1.2c ATR.NORMAL.14.9", GetATRCondition_Testable(14.9) == ATR_NORMAL, "14.9 pips = NORMAL");

    // Test 1.3: VOLATILE condition (15-30 pips)
    PrintTestSection("VOLATILE Condition (15-30 pips)");
    AssertTrue("1.3a ATR.VOLATILE.15", GetATRCondition_Testable(15.0) == ATR_VOLATILE, "15 pips = VOLATILE");
    AssertTrue("1.3b ATR.VOLATILE.20", GetATRCondition_Testable(20.0) == ATR_VOLATILE, "20 pips = VOLATILE");
    AssertTrue("1.3c ATR.VOLATILE.29.9", GetATRCondition_Testable(29.9) == ATR_VOLATILE, "29.9 pips = VOLATILE");

    // Test 1.4: EXTREME condition (>= 30 pips)
    PrintTestSection("EXTREME Condition (>= 30 pips)");
    AssertTrue("1.4a ATR.EXTREME.30", GetATRCondition_Testable(30.0) == ATR_EXTREME, "30 pips = EXTREME");
    AssertTrue("1.4b ATR.EXTREME.50", GetATRCondition_Testable(50.0) == ATR_EXTREME, "50 pips = EXTREME");
    AssertTrue("1.4c ATR.EXTREME.100", GetATRCondition_Testable(100.0) == ATR_EXTREME, "100 pips = EXTREME");

    // Test 1.5: Boundary values
    PrintTestSection("Boundary Values");
    AssertTrue("1.5a Boundary.7.99", GetATRCondition_Testable(7.99) == ATR_CALM, "7.99 = CALM");
    AssertTrue("1.5b Boundary.8.00", GetATRCondition_Testable(8.00) == ATR_NORMAL, "8.00 = NORMAL");
    AssertTrue("1.5c Boundary.14.99", GetATRCondition_Testable(14.99) == ATR_NORMAL, "14.99 = NORMAL");
    AssertTrue("1.5d Boundary.15.00", GetATRCondition_Testable(15.00) == ATR_VOLATILE, "15.00 = VOLATILE");
    AssertTrue("1.5e Boundary.29.99", GetATRCondition_Testable(29.99) == ATR_VOLATILE, "29.99 = VOLATILE");
    AssertTrue("1.5f Boundary.30.00", GetATRCondition_Testable(30.00) == ATR_EXTREME, "30.00 = EXTREME");
}

//+------------------------------------------------------------------+
//| TEST SUITE 2: ATR Condition Names                                |
//+------------------------------------------------------------------+
void Test_ATRConditionNames() {
    PrintTestHeader("TEST SUITE 2: ATR Condition Names");

    AssertEqualsString("2.1 Name.CALM", GetATRConditionName_Testable(ATR_CALM), "CALM");
    AssertEqualsString("2.2 Name.NORMAL", GetATRConditionName_Testable(ATR_NORMAL), "NORMAL");
    AssertEqualsString("2.3 Name.VOLATILE", GetATRConditionName_Testable(ATR_VOLATILE), "VOLATILE");
    AssertEqualsString("2.4 Name.EXTREME", GetATRConditionName_Testable(ATR_EXTREME), "EXTREME");
}

//+------------------------------------------------------------------+
//| TEST SUITE 3: Is Market Calm                                     |
//+------------------------------------------------------------------+
void Test_IsMarketCalm() {
    PrintTestHeader("TEST SUITE 3: Is Market Calm");

    // Test 3.1: CALM = calm market
    PrintTestSection("CALM = Calm");
    AssertTrue("3.1 IsCalm.CALM", IsMarketCalm_Testable(5.0), "5 pips should be calm");

    // Test 3.2: NORMAL = calm market
    PrintTestSection("NORMAL = Calm");
    AssertTrue("3.2 IsCalm.NORMAL", IsMarketCalm_Testable(10.0), "10 pips should be calm");

    // Test 3.3: VOLATILE = not calm
    PrintTestSection("VOLATILE = Not Calm");
    AssertFalse("3.3 IsCalm.VOLATILE", IsMarketCalm_Testable(20.0), "20 pips should not be calm");

    // Test 3.4: EXTREME = not calm
    PrintTestSection("EXTREME = Not Calm");
    AssertFalse("3.4 IsCalm.EXTREME", IsMarketCalm_Testable(40.0), "40 pips should not be calm");
}

//+------------------------------------------------------------------+
//| TEST SUITE 4: JPY Correction                                     |
//+------------------------------------------------------------------+
void Test_JPYCorrection() {
    PrintTestHeader("TEST SUITE 4: JPY Correction");

    double rawATR = 100.0;

    // Test 4.1: Standard pairs (5 digits) - no correction
    PrintTestSection("Standard Pairs (5 digits)");
    double corrected = ApplyJPYCorrection_Testable(rawATR, 5);
    AssertEquals("4.1 JPY.5Digits.NoCorrection", corrected, 100.0, 0.01);

    // Test 4.2: Standard pairs (4 digits) - no correction
    PrintTestSection("Standard Pairs (4 digits)");
    corrected = ApplyJPYCorrection_Testable(rawATR, 4);
    AssertEquals("4.2 JPY.4Digits.NoCorrection", corrected, 100.0, 0.01);

    // Test 4.3: JPY pairs (3 digits) - divide by 10
    PrintTestSection("JPY Pairs (3 digits)");
    corrected = ApplyJPYCorrection_Testable(rawATR, 3);
    AssertEquals("4.3 JPY.3Digits.Correction", corrected, 10.0, 0.01);

    // Test 4.4: JPY pairs (2 digits) - divide by 10
    PrintTestSection("JPY Pairs (2 digits)");
    corrected = ApplyJPYCorrection_Testable(rawATR, 2);
    AssertEquals("4.4 JPY.2Digits.Correction", corrected, 10.0, 0.01);

    // Test 4.5: Real-world example
    PrintTestSection("Real-World JPY Example");
    // USDJPY: ATR raw value might be 0.50 (50 pips for JPY)
    // After correction should be 5.0 pips
    double usdjpyATR = 50.0; // Raw value
    corrected = ApplyJPYCorrection_Testable(usdjpyATR, 3);
    AssertEquals("4.5 JPY.USDJPY.Example", corrected, 5.0, 0.01);
}

//+------------------------------------------------------------------+
//| TEST SUITE 5: ATR Trend Detection                                |
//+------------------------------------------------------------------+
void Test_ATRTrend() {
    PrintTestHeader("TEST SUITE 5: ATR Trend Detection");

    // Test 5.1: Increasing trend (recent > older * 1.1)
    PrintTestSection("Increasing Trend");
    double recentAvg = 15.0;
    double olderAvg = 10.0; // 15 > 10*1.1=11 -> Increasing
    AssertEqualsInt("5.1 Trend.Increasing", GetATRTrend_Testable(recentAvg, olderAvg), 1);

    // Test 5.2: Decreasing trend (recent < older * 0.9)
    PrintTestSection("Decreasing Trend");
    recentAvg = 8.0;
    olderAvg = 10.0; // 8 < 10*0.9=9 -> Decreasing
    AssertEqualsInt("5.2 Trend.Decreasing", GetATRTrend_Testable(recentAvg, olderAvg), -1);

    // Test 5.3: Stable (within 10% band)
    PrintTestSection("Stable Trend");
    recentAvg = 10.0;
    olderAvg = 10.0; // Equal -> Stable
    AssertEqualsInt("5.3a Trend.Stable.Equal", GetATRTrend_Testable(recentAvg, olderAvg), 0);

    recentAvg = 10.5;
    olderAvg = 10.0; // 10.5 < 11 and 10.5 > 9 -> Stable
    AssertEqualsInt("5.3b Trend.Stable.SlightUp", GetATRTrend_Testable(recentAvg, olderAvg), 0);

    recentAvg = 9.5;
    olderAvg = 10.0; // 9.5 < 11 and 9.5 > 9 -> Stable
    AssertEqualsInt("5.3c Trend.Stable.SlightDown", GetATRTrend_Testable(recentAvg, olderAvg), 0);

    // Test 5.4: Edge cases
    PrintTestSection("Boundary Cases");
    recentAvg = 11.0;
    olderAvg = 10.0; // Exactly at 1.1x boundary
    AssertEqualsInt("5.4a Trend.Boundary.Upper", GetATRTrend_Testable(recentAvg, olderAvg), 0);

    recentAvg = 11.01;
    AssertEqualsInt("5.4b Trend.Boundary.JustAbove", GetATRTrend_Testable(recentAvg, olderAvg), 1);

    recentAvg = 9.0;
    AssertEqualsInt("5.4c Trend.Boundary.Lower", GetATRTrend_Testable(recentAvg, olderAvg), 0);

    recentAvg = 8.99;
    AssertEqualsInt("5.4d Trend.Boundary.JustBelow", GetATRTrend_Testable(recentAvg, olderAvg), -1);
}

//+------------------------------------------------------------------+
//| TEST SUITE 6: Average Calculation                                |
//+------------------------------------------------------------------+
void Test_AverageCalculation() {
    PrintTestHeader("TEST SUITE 6: Average Calculation");

    // Test 6.1: Simple average
    PrintTestSection("Simple Average");
    double values1[] = {10, 20, 30, 40, 50};
    AssertEquals("6.1 Average.Simple", CalculateAverage_Testable(values1, 5), 30.0, 0.01);

    // Test 6.2: Single value
    PrintTestSection("Single Value");
    double values2[] = {25.0};
    AssertEquals("6.2 Average.Single", CalculateAverage_Testable(values2, 1), 25.0, 0.01);

    // Test 6.3: Zero count
    PrintTestSection("Zero Count");
    double values3[] = {10, 20};
    AssertEquals("6.3 Average.ZeroCount", CalculateAverage_Testable(values3, 0), 0.0, 0.01);

    // Test 6.4: Decimal values
    PrintTestSection("Decimal Values");
    double values4[] = {10.5, 11.5, 12.5, 13.5};
    AssertEquals("6.4 Average.Decimal", CalculateAverage_Testable(values4, 4), 12.0, 0.01);

    // Test 6.5: Large dataset
    PrintTestSection("Large Dataset");
    double values5[100];
    for(int i = 0; i < 100; i++) values5[i] = i + 1; // 1 to 100
    // Average of 1-100 = 50.5
    AssertEquals("6.5 Average.LargeDataset", CalculateAverage_Testable(values5, 100), 50.5, 0.01);
}

//+------------------------------------------------------------------+
//| TEST SUITE 7: Cache Validity                                     |
//+------------------------------------------------------------------+
void Test_CacheValidity() {
    PrintTestHeader("TEST SUITE 7: Cache Validity");

    datetime lastBarTime = StringToTime("2025.01.15 10:00:00");
    datetime currentBarTime = StringToTime("2025.01.15 10:00:00");

    // Test 7.1: Valid cache - same bar
    PrintTestSection("Valid Cache - Same Bar");
    AssertTrue("7.1 Cache.Valid.SameBar",
               IsCacheValid_Testable(lastBarTime, currentBarTime, true),
               "Cache should be valid for same bar");

    // Test 7.2: Invalid cache - new bar
    PrintTestSection("Invalid Cache - New Bar");
    currentBarTime = StringToTime("2025.01.15 11:00:00");
    AssertFalse("7.2 Cache.Invalid.NewBar",
                IsCacheValid_Testable(lastBarTime, currentBarTime, true),
                "Cache should be invalid for new bar");

    // Test 7.3: Invalid cache flag
    PrintTestSection("Invalid Cache Flag");
    currentBarTime = lastBarTime;
    AssertFalse("7.3 Cache.Invalid.Flag",
                IsCacheValid_Testable(lastBarTime, currentBarTime, false),
                "Cache should be invalid when flag is false");

    // Test 7.4: Both invalid
    PrintTestSection("Both Invalid");
    currentBarTime = StringToTime("2025.01.15 12:00:00");
    AssertFalse("7.4 Cache.Invalid.Both",
                IsCacheValid_Testable(lastBarTime, currentBarTime, false),
                "Cache should be invalid when both conditions fail");
}

//+------------------------------------------------------------------+
//| TEST SUITE 8: Integration - Full ATR Flow                        |
//+------------------------------------------------------------------+
void Test_FullATRFlow() {
    PrintTestHeader("TEST SUITE 8: Full ATR Flow Integration");

    // Simulate ATR values over time
    double atrHistory[] = {5.0, 6.0, 7.0, 10.0, 12.0, 18.0, 25.0, 35.0, 30.0, 20.0};

    PrintTestSection("ATR Sequence Analysis");
    for(int i = 0; i < ArraySize(atrHistory); i++) {
        ENUM_ATR_CONDITION cond = GetATRCondition_Testable(atrHistory[i]);
        bool isCalm = IsMarketCalm_Testable(atrHistory[i]);
        Print("  ATR=", DoubleToString(atrHistory[i], 1),
              " -> ", GetATRConditionName_Testable(cond),
              " (Calm=", isCalm ? "YES" : "NO", ")");
    }

    // Verify transitions
    AssertTrue("8.1a Transition.CalmToNormal",
               GetATRCondition_Testable(atrHistory[0]) == ATR_CALM &&
               GetATRCondition_Testable(atrHistory[3]) == ATR_NORMAL,
               "Should transition from CALM to NORMAL");

    AssertTrue("8.1b Transition.NormalToVolatile",
               GetATRCondition_Testable(atrHistory[4]) == ATR_NORMAL &&
               GetATRCondition_Testable(atrHistory[5]) == ATR_VOLATILE,
               "Should transition from NORMAL to VOLATILE");

    AssertTrue("8.1c Transition.VolatileToExtreme",
               GetATRCondition_Testable(atrHistory[6]) == ATR_VOLATILE &&
               GetATRCondition_Testable(atrHistory[7]) == ATR_EXTREME,
               "Should transition from VOLATILE to EXTREME");

    // Test trend detection
    PrintTestSection("Trend Detection");
    double firstHalf[] = {5.0, 6.0, 7.0, 10.0, 12.0};
    double secondHalf[] = {18.0, 25.0, 35.0, 30.0, 20.0};

    double avgFirst = CalculateAverage_Testable(firstHalf, 5);
    double avgSecond = CalculateAverage_Testable(secondHalf, 5);

    Print("  First half avg: ", DoubleToString(avgFirst, 1));
    Print("  Second half avg: ", DoubleToString(avgSecond, 1));

    // Second half has higher values = increasing trend
    int trend = GetATRTrend_Testable(avgSecond, avgFirst);
    AssertEqualsInt("8.2 Trend.Increasing", trend, 1, "Should detect increasing trend");
}

//+------------------------------------------------------------------+
//| TEST SUITE 9: Edge Cases                                         |
//+------------------------------------------------------------------+
void Test_EdgeCases() {
    PrintTestHeader("TEST SUITE 9: Edge Cases");

    // Test 9.1: Zero ATR
    PrintTestSection("Zero ATR");
    AssertTrue("9.1 ZeroATR", GetATRCondition_Testable(0) == ATR_CALM, "0 ATR = CALM");

    // Test 9.2: Negative ATR (invalid but should handle)
    PrintTestSection("Negative ATR");
    AssertTrue("9.2 NegativeATR", GetATRCondition_Testable(-5.0) == ATR_CALM, "Negative ATR = CALM");

    // Test 9.3: Very large ATR
    PrintTestSection("Very Large ATR");
    AssertTrue("9.3 VeryLargeATR", GetATRCondition_Testable(500.0) == ATR_EXTREME, "500 pips = EXTREME");

    // Test 9.4: Fractional pips
    PrintTestSection("Fractional Pips");
    AssertTrue("9.4a Fractional.7.5", GetATRCondition_Testable(7.5) == ATR_CALM, "7.5 = CALM");
    AssertTrue("9.4b Fractional.8.5", GetATRCondition_Testable(8.5) == ATR_NORMAL, "8.5 = NORMAL");
    AssertTrue("9.4c Fractional.15.5", GetATRCondition_Testable(15.5) == ATR_VOLATILE, "15.5 = VOLATILE");

    // Test 9.5: Trend with zero older value
    PrintTestSection("Trend with Zero");
    // Avoid division by zero in real code
    int trend = GetATRTrend_Testable(10.0, 0.001); // Near-zero
    AssertEqualsInt("9.5 TrendZeroOlder", trend, 1, "Should handle near-zero older value");
}

//+------------------------------------------------------------------+
//| Script Start                                                     |
//+------------------------------------------------------------------+
void OnStart() {
    PrintTestBanner("ATRCalculatorTests");

    // Setup environment
    SetupBaseTestEnvironment();
    SaveAllInputParameters();

    // Run all test suites
    Test_ATRConditionClassification();
    Test_ATRConditionNames();
    Test_IsMarketCalm();
    Test_JPYCorrection();
    Test_ATRTrend();
    Test_AverageCalculation();
    Test_CacheValidity();
    Test_FullATRFlow();
    Test_EdgeCases();

    // Restore and summarize
    RestoreAllInputParameters();
    PrintTestSummary();
}
//+------------------------------------------------------------------+
