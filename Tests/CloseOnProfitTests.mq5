//+------------------------------------------------------------------+
//|                                          CloseOnProfitTests.mq5  |
//|                        Sugamara - Close On Profit Unit Tests     |
//|                                                                  |
//|  Tests for COP target calculation, daily reset, profit tracking  |
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
#include "TestFramework.mqh"

//+------------------------------------------------------------------+
//| TESTABLE VERSIONS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Testable: Check if New Day                                       |
//+------------------------------------------------------------------+
bool COP_IsNewDay_Testable(datetime lastResetDate, datetime currentTime) {
    MqlDateTime current, lastReset;
    TimeToStruct(currentTime, current);
    TimeToStruct(lastResetDate, lastReset);

    return (current.day != lastReset.day ||
            current.mon != lastReset.mon ||
            current.year != lastReset.year);
}

//+------------------------------------------------------------------+
//| Testable: Check Target Reached                                   |
//+------------------------------------------------------------------+
bool COP_IsTargetReached_Testable(double netProfit, double targetUSD) {
    return (netProfit >= targetUSD);
}

//+------------------------------------------------------------------+
//| Testable: Calculate Net Profit                                   |
//+------------------------------------------------------------------+
double COP_CalculateNetProfit_Testable(double realizedProfit, double floatingProfit, bool includeFloating) {
    if(includeFloating) {
        return realizedProfit + floatingProfit;
    }
    return realizedProfit;
}

//+------------------------------------------------------------------+
//| Testable: Calculate Progress Percent                             |
//+------------------------------------------------------------------+
double COP_GetProgressPercent_Testable(double netProfit, double targetUSD) {
    if(targetUSD <= 0) return 0;
    double progress = (netProfit / targetUSD) * 100.0;
    return MathMax(0, MathMin(100, progress));
}

//+------------------------------------------------------------------+
//| Testable: Should Block Trading                                   |
//+------------------------------------------------------------------+
bool COP_ShouldBlockTrading_Testable(bool enabled, bool pauseTrading, bool targetReached) {
    if(!enabled) return false;
    if(!pauseTrading) return false;
    return targetReached;
}

//+------------------------------------------------------------------+
//| Testable: Calculate Commissions                                  |
//+------------------------------------------------------------------+
double COP_CalculateCommissions_Testable(double totalLotsToday, double commissionPerLot, bool deductCommissions) {
    if(!deductCommissions) return 0;
    return totalLotsToday * commissionPerLot;
}

//+------------------------------------------------------------------+
//| TEST SUITE 1: New Day Detection                                  |
//+------------------------------------------------------------------+
void Test_NewDayDetection() {
    PrintTestHeader("TEST SUITE 1: New Day Detection");

    // Test 1.1: Same day - should return FALSE
    PrintTestSection("Same Day");
    datetime lastReset = StringToTime("2025.01.15 08:00:00");
    datetime current = StringToTime("2025.01.15 14:30:00");
    AssertFalse("1.1 SameDay.NotNewDay",
                COP_IsNewDay_Testable(lastReset, current),
                "Same day should return FALSE");

    // Test 1.2: Next day - should return TRUE
    PrintTestSection("Next Day");
    current = StringToTime("2025.01.16 00:01:00");
    AssertTrue("1.2 NextDay.IsNewDay",
               COP_IsNewDay_Testable(lastReset, current),
               "Next day should return TRUE");

    // Test 1.3: Exactly midnight boundary
    PrintTestSection("Midnight Boundary");
    current = StringToTime("2025.01.16 00:00:00");
    AssertTrue("1.3 Midnight.IsNewDay",
               COP_IsNewDay_Testable(lastReset, current),
               "Midnight of next day should return TRUE");

    // Test 1.4: End of month transition
    PrintTestSection("End of Month Transition");
    lastReset = StringToTime("2025.01.31 23:59:00");
    current = StringToTime("2025.02.01 00:01:00");
    AssertTrue("1.4 MonthEnd.IsNewDay",
               COP_IsNewDay_Testable(lastReset, current),
               "Month transition should return TRUE");

    // Test 1.5: End of year transition
    PrintTestSection("End of Year Transition");
    lastReset = StringToTime("2024.12.31 23:59:00");
    current = StringToTime("2025.01.01 00:01:00");
    AssertTrue("1.5 YearEnd.IsNewDay",
               COP_IsNewDay_Testable(lastReset, current),
               "Year transition should return TRUE");

    // Test 1.6: Same time next day
    PrintTestSection("Same Time Next Day");
    lastReset = StringToTime("2025.01.15 10:30:00");
    current = StringToTime("2025.01.16 10:30:00");
    AssertTrue("1.6 SameTimeNextDay.IsNewDay",
               COP_IsNewDay_Testable(lastReset, current),
               "Same time next day should return TRUE");
}

//+------------------------------------------------------------------+
//| TEST SUITE 2: Target Reached Check                               |
//+------------------------------------------------------------------+
void Test_TargetReachedCheck() {
    PrintTestHeader("TEST SUITE 2: Target Reached Check");

    double target = 100.0; // $100 target

    // Test 2.1: Below target
    PrintTestSection("Below Target");
    AssertFalse("2.1a Target.50Dollars",
                COP_IsTargetReached_Testable(50.0, target),
                "$50 should not reach $100 target");
    AssertFalse("2.1b Target.99Dollars",
                COP_IsTargetReached_Testable(99.99, target),
                "$99.99 should not reach $100 target");

    // Test 2.2: Exactly at target
    PrintTestSection("Exactly at Target");
    AssertTrue("2.2 Target.Exactly100",
               COP_IsTargetReached_Testable(100.0, target),
               "$100 should reach $100 target");

    // Test 2.3: Above target
    PrintTestSection("Above Target");
    AssertTrue("2.3a Target.101Dollars",
               COP_IsTargetReached_Testable(101.0, target),
               "$101 should exceed $100 target");
    AssertTrue("2.3b Target.200Dollars",
               COP_IsTargetReached_Testable(200.0, target),
               "$200 should exceed $100 target");

    // Test 2.4: Negative profit
    PrintTestSection("Negative Profit");
    AssertFalse("2.4 Target.NegativeProfit",
                COP_IsTargetReached_Testable(-50.0, target),
                "Negative profit should not reach target");

    // Test 2.5: Zero target (edge case)
    PrintTestSection("Zero Target");
    AssertTrue("2.5 Target.ZeroTarget",
               COP_IsTargetReached_Testable(1.0, 0.0),
               "Any positive profit reaches zero target");
}

//+------------------------------------------------------------------+
//| TEST SUITE 3: Net Profit Calculation                             |
//+------------------------------------------------------------------+
void Test_NetProfitCalculation() {
    PrintTestHeader("TEST SUITE 3: Net Profit Calculation");

    // Test 3.1: Only realized profit
    PrintTestSection("Realized Only");
    double realized = 80.0;
    double floating = 20.0;
    double net = COP_CalculateNetProfit_Testable(realized, floating, false);
    AssertEquals("3.1 NetProfit.RealizedOnly", net, 80.0, 0.01);

    // Test 3.2: Realized + Floating
    PrintTestSection("Realized + Floating");
    net = COP_CalculateNetProfit_Testable(realized, floating, true);
    AssertEquals("3.2 NetProfit.WithFloating", net, 100.0, 0.01);

    // Test 3.3: Negative floating
    PrintTestSection("Negative Floating");
    floating = -30.0;
    net = COP_CalculateNetProfit_Testable(realized, floating, true);
    AssertEquals("3.3 NetProfit.NegativeFloating", net, 50.0, 0.01);

    // Test 3.4: Both negative
    PrintTestSection("Both Negative");
    realized = -20.0;
    floating = -30.0;
    net = COP_CalculateNetProfit_Testable(realized, floating, true);
    AssertEquals("3.4 NetProfit.BothNegative", net, -50.0, 0.01);

    // Test 3.5: Floating ignored when disabled
    PrintTestSection("Floating Ignored");
    realized = 50.0;
    floating = 100.0;
    net = COP_CalculateNetProfit_Testable(realized, floating, false);
    AssertEquals("3.5 NetProfit.FloatingIgnored", net, 50.0, 0.01);
}

//+------------------------------------------------------------------+
//| TEST SUITE 4: Progress Percent Calculation                       |
//+------------------------------------------------------------------+
void Test_ProgressPercent() {
    PrintTestHeader("TEST SUITE 4: Progress Percent Calculation");

    double target = 100.0;

    // Test 4.1: Zero progress
    PrintTestSection("Zero Progress");
    AssertEquals("4.1 Progress.Zero", COP_GetProgressPercent_Testable(0, target), 0.0, 0.01);

    // Test 4.2: 25% progress
    PrintTestSection("25% Progress");
    AssertEquals("4.2 Progress.25Percent", COP_GetProgressPercent_Testable(25.0, target), 25.0, 0.01);

    // Test 4.3: 50% progress
    PrintTestSection("50% Progress");
    AssertEquals("4.3 Progress.50Percent", COP_GetProgressPercent_Testable(50.0, target), 50.0, 0.01);

    // Test 4.4: 100% progress
    PrintTestSection("100% Progress");
    AssertEquals("4.4 Progress.100Percent", COP_GetProgressPercent_Testable(100.0, target), 100.0, 0.01);

    // Test 4.5: Over 100% - capped at 100
    PrintTestSection("Over 100% (Capped)");
    AssertEquals("4.5 Progress.Capped", COP_GetProgressPercent_Testable(150.0, target), 100.0, 0.01);

    // Test 4.6: Negative progress - capped at 0
    PrintTestSection("Negative Progress (Capped)");
    AssertEquals("4.6 Progress.NegativeCapped", COP_GetProgressPercent_Testable(-50.0, target), 0.0, 0.01);

    // Test 4.7: Zero target - returns 0
    PrintTestSection("Zero Target");
    AssertEquals("4.7 Progress.ZeroTarget", COP_GetProgressPercent_Testable(50.0, 0), 0.0, 0.01);
}

//+------------------------------------------------------------------+
//| TEST SUITE 5: Should Block Trading                               |
//+------------------------------------------------------------------+
void Test_ShouldBlockTrading() {
    PrintTestHeader("TEST SUITE 5: Should Block Trading");

    // Test 5.1: COP disabled
    PrintTestSection("COP Disabled");
    AssertFalse("5.1 BlockTrading.COPDisabled",
                COP_ShouldBlockTrading_Testable(false, true, true),
                "Should not block when COP disabled");

    // Test 5.2: Pause trading disabled
    PrintTestSection("Pause Trading Disabled");
    AssertFalse("5.2 BlockTrading.PauseDisabled",
                COP_ShouldBlockTrading_Testable(true, false, true),
                "Should not block when pause disabled");

    // Test 5.3: Target not reached
    PrintTestSection("Target Not Reached");
    AssertFalse("5.3 BlockTrading.TargetNotReached",
                COP_ShouldBlockTrading_Testable(true, true, false),
                "Should not block when target not reached");

    // Test 5.4: All conditions met - should block
    PrintTestSection("All Conditions Met");
    AssertTrue("5.4 BlockTrading.ShouldBlock",
               COP_ShouldBlockTrading_Testable(true, true, true),
               "Should block when all conditions met");

    // Test 5.5: Multiple combinations
    PrintTestSection("All Combinations");
    AssertFalse("5.5a", COP_ShouldBlockTrading_Testable(false, false, false), "fff");
    AssertFalse("5.5b", COP_ShouldBlockTrading_Testable(false, false, true), "fft");
    AssertFalse("5.5c", COP_ShouldBlockTrading_Testable(false, true, false), "ftf");
    AssertFalse("5.5d", COP_ShouldBlockTrading_Testable(false, true, true), "ftt");
    AssertFalse("5.5e", COP_ShouldBlockTrading_Testable(true, false, false), "tff");
    AssertFalse("5.5f", COP_ShouldBlockTrading_Testable(true, false, true), "tft");
    AssertFalse("5.5g", COP_ShouldBlockTrading_Testable(true, true, false), "ttf");
    AssertTrue("5.5h", COP_ShouldBlockTrading_Testable(true, true, true), "ttt");
}

//+------------------------------------------------------------------+
//| TEST SUITE 6: Commission Calculation                             |
//+------------------------------------------------------------------+
void Test_CommissionCalculation() {
    PrintTestHeader("TEST SUITE 6: Commission Calculation");

    double commissionPerLot = 7.0; // $7 per lot

    // Test 6.1: Commissions disabled
    PrintTestSection("Commissions Disabled");
    double comm = COP_CalculateCommissions_Testable(10.0, commissionPerLot, false);
    AssertEquals("6.1 Commission.Disabled", comm, 0.0, 0.01);

    // Test 6.2: Single lot
    PrintTestSection("Single Lot");
    comm = COP_CalculateCommissions_Testable(1.0, commissionPerLot, true);
    AssertEquals("6.2 Commission.SingleLot", comm, 7.0, 0.01);

    // Test 6.3: Multiple lots
    PrintTestSection("Multiple Lots");
    comm = COP_CalculateCommissions_Testable(5.0, commissionPerLot, true);
    AssertEquals("6.3 Commission.MultipleLots", comm, 35.0, 0.01);

    // Test 6.4: Fractional lots
    PrintTestSection("Fractional Lots");
    comm = COP_CalculateCommissions_Testable(0.5, commissionPerLot, true);
    AssertEquals("6.4 Commission.FractionalLots", comm, 3.5, 0.01);

    // Test 6.5: Zero lots
    PrintTestSection("Zero Lots");
    comm = COP_CalculateCommissions_Testable(0, commissionPerLot, true);
    AssertEquals("6.5 Commission.ZeroLots", comm, 0.0, 0.01);

    // Test 6.6: Different commission rates
    PrintTestSection("Different Rates");
    comm = COP_CalculateCommissions_Testable(2.0, 3.5, true);
    AssertEquals("6.6 Commission.DifferentRate", comm, 7.0, 0.01);
}

//+------------------------------------------------------------------+
//| TEST SUITE 7: Integration - Full COP Flow                        |
//+------------------------------------------------------------------+
void Test_FullCOPFlow() {
    PrintTestHeader("TEST SUITE 7: Full COP Flow Integration");

    double target = 100.0;
    double commissionPerLot = 7.0;

    // Simulate trading day
    PrintTestSection("Trading Day Simulation");

    // Initial state
    double realized = 0;
    double floating = 0;
    double totalLots = 0;
    bool targetReached = false;

    // Trade 1: Win $30
    realized += 30.0;
    totalLots += 0.1;
    double net = COP_CalculateNetProfit_Testable(realized, floating, true);
    double progress = COP_GetProgressPercent_Testable(net, target);
    targetReached = COP_IsTargetReached_Testable(net, target);

    AssertEquals("7.1a Trade1.Progress", progress, 30.0, 0.1);
    AssertFalse("7.1b Trade1.TargetNotReached", targetReached, "Target not reached yet");

    // Trade 2: Win $40
    realized += 40.0;
    totalLots += 0.1;
    net = COP_CalculateNetProfit_Testable(realized, floating, true);
    progress = COP_GetProgressPercent_Testable(net, target);
    targetReached = COP_IsTargetReached_Testable(net, target);

    AssertEquals("7.2a Trade2.Progress", progress, 70.0, 0.1);
    AssertFalse("7.2b Trade2.TargetNotReached", targetReached, "Target not reached yet");

    // Floating profit appears
    floating = 35.0;
    net = COP_CalculateNetProfit_Testable(realized, floating, true);
    progress = COP_GetProgressPercent_Testable(net, target);
    targetReached = COP_IsTargetReached_Testable(net, target);

    AssertEquals("7.3a WithFloating.Progress", progress, 100.0, 0.1);
    AssertTrue("7.3b WithFloating.TargetReached", targetReached, "Target reached with floating");

    // Check blocking
    bool shouldBlock = COP_ShouldBlockTrading_Testable(true, true, targetReached);
    AssertTrue("7.4 ShouldBlock", shouldBlock, "Trading should be blocked");

    // Calculate final commissions
    double commissions = COP_CalculateCommissions_Testable(totalLots, commissionPerLot, true);
    AssertEquals("7.5 FinalCommissions", commissions, 1.4, 0.01);
}

//+------------------------------------------------------------------+
//| TEST SUITE 8: Edge Cases                                         |
//+------------------------------------------------------------------+
void Test_EdgeCases() {
    PrintTestHeader("TEST SUITE 8: Edge Cases");

    // Test 8.1: Very small target
    PrintTestSection("Very Small Target");
    AssertTrue("8.1 SmallTarget",
               COP_IsTargetReached_Testable(0.01, 0.01),
               "0.01 should reach 0.01 target");

    // Test 8.2: Very large target
    PrintTestSection("Very Large Target");
    double progress = COP_GetProgressPercent_Testable(1000, 1000000);
    AssertEquals("8.2 LargeTarget.Progress", progress, 0.1, 0.01);

    // Test 8.3: Negative target (invalid but should handle)
    PrintTestSection("Negative Target");
    AssertTrue("8.3 NegativeTarget",
               COP_IsTargetReached_Testable(0, -100),
               "Any profit reaches negative target");

    // Test 8.4: Same day different hours
    PrintTestSection("Same Day Different Hours");
    datetime morning = StringToTime("2025.01.15 08:00:00");
    datetime evening = StringToTime("2025.01.15 22:00:00");
    AssertFalse("8.4 SameDayDifferentHours",
                COP_IsNewDay_Testable(morning, evening),
                "Same day should not be new day");

    // Test 8.5: Leap year boundary
    PrintTestSection("Leap Year Boundary");
    datetime feb28 = StringToTime("2024.02.28 23:00:00");
    datetime feb29 = StringToTime("2024.02.29 01:00:00");
    AssertTrue("8.5 LeapYear",
               COP_IsNewDay_Testable(feb28, feb29),
               "Feb 28 to Feb 29 (leap) is new day");
}

//+------------------------------------------------------------------+
//| Script Start                                                     |
//+------------------------------------------------------------------+
void OnStart() {
    PrintTestBanner("CloseOnProfitTests");

    // Setup environment
    SetupBaseTestEnvironment();
    SaveAllInputParameters();

    // Run all test suites
    Test_NewDayDetection();
    Test_TargetReachedCheck();
    Test_NetProfitCalculation();
    Test_ProgressPercent();
    Test_ShouldBlockTrading();
    Test_CommissionCalculation();
    Test_FullCOPFlow();
    Test_EdgeCases();

    // Restore and summarize
    RestoreAllInputParameters();
    PrintTestSummary();
}
//+------------------------------------------------------------------+
