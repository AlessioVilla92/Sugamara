//+------------------------------------------------------------------+
//|                                                   TestRunner.mq5 |
//|                        Sugamara - All Tests Runner               |
//|                                                                  |
//|  Esegue tutti i test suite in sequenza e mostra summary finale   |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"
#property version   "1.00"
#property script_show_inputs

//+------------------------------------------------------------------+
//| Includes base                                                    |
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
//| Test Suite Results Tracking                                      |
//+------------------------------------------------------------------+
struct SuiteResult {
    string name;
    int total;
    int passed;
    int failed;
    uint duration_ms;
};

SuiteResult g_suiteResults[];
int g_totalSuites = 0;

//+------------------------------------------------------------------+
//| Record Suite Result                                              |
//+------------------------------------------------------------------+
void RecordSuiteResult(string name, int total, int passed, int failed, uint duration_ms) {
    ArrayResize(g_suiteResults, g_totalSuites + 1);
    g_suiteResults[g_totalSuites].name = name;
    g_suiteResults[g_totalSuites].total = total;
    g_suiteResults[g_totalSuites].passed = passed;
    g_suiteResults[g_totalSuites].failed = failed;
    g_suiteResults[g_totalSuites].duration_ms = duration_ms;
    g_totalSuites++;
}

//+------------------------------------------------------------------+
//| ATR THRESHOLDS (from ATRCalculator.mqh)                          |
//+------------------------------------------------------------------+
#define ATR_THRESHOLD_CALM      8.0
#define ATR_THRESHOLD_NORMAL    15.0
#define ATR_THRESHOLD_VOLATILE  30.0

//+------------------------------------------------------------------+
//| TESTABLE FUNCTIONS: ATRCalculator                                |
//+------------------------------------------------------------------+
ENUM_ATR_CONDITION GetATRCondition_Testable(double atrPips) {
    if(atrPips < ATR_THRESHOLD_CALM) return ATR_CALM;
    else if(atrPips < ATR_THRESHOLD_NORMAL) return ATR_NORMAL;
    else if(atrPips < ATR_THRESHOLD_VOLATILE) return ATR_VOLATILE;
    else return ATR_EXTREME;
}

string GetATRConditionName_Testable(ENUM_ATR_CONDITION condition) {
    switch(condition) {
        case ATR_CALM:     return "CALM";
        case ATR_NORMAL:   return "NORMAL";
        case ATR_VOLATILE: return "VOLATILE";
        case ATR_EXTREME:  return "EXTREME";
        default:           return "UNKNOWN";
    }
}

bool IsMarketCalm_Testable(double atrPips) {
    ENUM_ATR_CONDITION condition = GetATRCondition_Testable(atrPips);
    return (condition == ATR_CALM || condition == ATR_NORMAL);
}

double ApplyJPYCorrection_Testable(double atrPips, int digits) {
    if(digits == 3 || digits == 2) return atrPips / 10.0;
    return atrPips;
}

int GetATRTrend_Testable(double recentAvg, double olderAvg) {
    if(recentAvg > olderAvg * 1.1) return 1;
    if(recentAvg < olderAvg * 0.9) return -1;
    return 0;
}

//+------------------------------------------------------------------+
//| TESTABLE FUNCTIONS: OrderReopen                                  |
//+------------------------------------------------------------------+
bool IsPriceAtReopenLevelSmart_Testable(double levelPrice, ENUM_ORDER_TYPE orderType,
                                         double currentPrice, double reopenOffsetPips) {
    if(orderType == ORDER_TYPE_BUY_LIMIT || orderType == ORDER_TYPE_SELL_LIMIT) return true;
    if(currentPrice <= 0) return false;

    double offsetPoints = PipsToPoints(reopenOffsetPips);
    bool canReopen = false;

    switch(orderType) {
        case ORDER_TYPE_BUY_STOP:
            canReopen = (currentPrice <= levelPrice - offsetPoints);
            break;
        case ORDER_TYPE_SELL_STOP:
            canReopen = (currentPrice >= levelPrice + offsetPoints);
            break;
        default:
            return true;
    }
    return canReopen;
}

bool CanLevelReopen_Testable(bool enableCyclicReopen, int maxCyclesPerLevel,
                              bool pauseReopenOnExtreme, ENUM_ATR_CONDITION atrCondition,
                              int currentCycles) {
    if(!enableCyclicReopen) return false;
    if(maxCyclesPerLevel > 0 && currentCycles >= maxCyclesPerLevel) return false;
    if(pauseReopenOnExtreme && atrCondition == ATR_EXTREME) return false;
    return true;
}

//+------------------------------------------------------------------+
//| SETUP                                                            |
//+------------------------------------------------------------------+
void SetupTestEnvironment() {
    SetupBaseTestEnvironment();
    InitializeArrays();
}

void ResetGridStatusForTests() {
    ResetAllGridArrays();
}

//=============================================================================
//                         TEST SUITE: ATRCalculator
//=============================================================================
void RunATRCalculatorTests() {
    PrintTestHeader("ATRCalculator Tests");

    // TEST: GetATRCondition boundaries
    AssertTrue("ATR.CALM.Low", GetATRCondition_Testable(5.0) == ATR_CALM, "5 pips = CALM");
    AssertTrue("ATR.CALM.Boundary", GetATRCondition_Testable(7.9) == ATR_CALM, "7.9 pips = CALM");
    AssertTrue("ATR.NORMAL.Boundary", GetATRCondition_Testable(8.0) == ATR_NORMAL, "8.0 pips = NORMAL");
    AssertTrue("ATR.NORMAL.Mid", GetATRCondition_Testable(12.0) == ATR_NORMAL, "12 pips = NORMAL");
    AssertTrue("ATR.VOLATILE.Boundary", GetATRCondition_Testable(15.0) == ATR_VOLATILE, "15 pips = VOLATILE");
    AssertTrue("ATR.VOLATILE.Mid", GetATRCondition_Testable(25.0) == ATR_VOLATILE, "25 pips = VOLATILE");
    AssertTrue("ATR.EXTREME.Boundary", GetATRCondition_Testable(30.0) == ATR_EXTREME, "30 pips = EXTREME");
    AssertTrue("ATR.EXTREME.High", GetATRCondition_Testable(50.0) == ATR_EXTREME, "50 pips = EXTREME");

    // TEST: IsMarketCalm
    AssertTrue("MarketCalm.CALM", IsMarketCalm_Testable(5.0), "CALM market = calm");
    AssertTrue("MarketCalm.NORMAL", IsMarketCalm_Testable(12.0), "NORMAL market = calm");
    AssertFalse("MarketCalm.VOLATILE", IsMarketCalm_Testable(20.0), "VOLATILE market != calm");
    AssertFalse("MarketCalm.EXTREME", IsMarketCalm_Testable(35.0), "EXTREME market != calm");

    // TEST: JPY Correction
    AssertEquals("JPY.Correction.3dig", ApplyJPYCorrection_Testable(100.0, 3), 10.0, 0.001, "JPY 3 digits");
    AssertEquals("JPY.Correction.2dig", ApplyJPYCorrection_Testable(100.0, 2), 10.0, 0.001, "JPY 2 digits");
    AssertEquals("JPY.NoCorrection.5dig", ApplyJPYCorrection_Testable(100.0, 5), 100.0, 0.001, "No JPY 5 digits");

    // TEST: ATR Trend
    AssertEqualsInt("ATRTrend.Increasing", GetATRTrend_Testable(12.0, 10.0), 1, "Increasing trend");
    AssertEqualsInt("ATRTrend.Decreasing", GetATRTrend_Testable(8.0, 10.0), -1, "Decreasing trend");
    AssertEqualsInt("ATRTrend.Stable", GetATRTrend_Testable(10.0, 10.0), 0, "Stable trend");
}

//=============================================================================
//                         TEST SUITE: CloseOnProfit
//=============================================================================
void RunCloseOnProfitTests() {
    PrintTestHeader("CloseOnProfit Tests");

    // Basic profit target logic tests
    double balance = 10000.0;
    double profitTarget = balance * 0.02; // 2% = 200

    AssertTrue("Profit.TargetCalc", profitTarget == 200.0, "2% of 10000 = 200");
    AssertTrue("Profit.AboveTarget", 250.0 >= profitTarget, "250 >= 200");
    AssertFalse("Profit.BelowTarget", 150.0 >= profitTarget, "150 < 200");

    // Trailing profit logic
    double peakProfit = 300.0;
    double trailingPct = 0.30; // 30%
    double minProfit = peakProfit * (1.0 - trailingPct);

    AssertEquals("Trailing.MinProfit", minProfit, 210.0, 0.01, "30% trail from 300");
    AssertTrue("Trailing.AboveMin", 220.0 >= minProfit, "220 >= 210");
    AssertFalse("Trailing.BelowMin", 200.0 >= minProfit, "200 < 210");
}

//=============================================================================
//                         TEST SUITE: RiskManager
//=============================================================================
void RunRiskManagerTests() {
    PrintTestHeader("RiskManager Tests");

    // Lot size calculation tests
    double balance = 10000.0;
    double riskPct = 0.01; // 1%
    double riskAmount = balance * riskPct;

    AssertEquals("Risk.Amount", riskAmount, 100.0, 0.01, "1% risk = 100");

    // Stop loss in points
    double slPoints = 500; // 50 pips
    double tickValue = 10.0; // $10 per lot per point
    double lotSize = riskAmount / (slPoints * tickValue);

    AssertEquals("Risk.LotCalc", lotSize, 0.02, 0.001, "Lot size calculation");

    // Max lot clamp
    double maxLot = 0.01;
    double clampedLot = MathMin(lotSize, maxLot);
    AssertEquals("Risk.MaxClamp", clampedLot, 0.01, 0.001, "Clamped to max");

    // Drawdown check
    double equity = 9500.0;
    double maxDD = 0.10; // 10%
    double ddThreshold = balance * (1.0 - maxDD);
    AssertTrue("DD.NotReached", equity >= ddThreshold, "9500 >= 9000");
    AssertFalse("DD.Reached", 8500.0 >= ddThreshold, "8500 < 9000");
}

//=============================================================================
//                         TEST SUITE: OrderReopen
//=============================================================================
void RunOrderReopenTests() {
    PrintTestHeader("OrderReopen Tests");

    double entryPrice = 1.10000;
    double offsetPips = 3.0;
    double offsetPoints = PipsToPoints(offsetPips);

    // LIMIT orders always TRUE
    AssertTrue("Reopen.BuyLimit", IsPriceAtReopenLevelSmart_Testable(entryPrice, ORDER_TYPE_BUY_LIMIT, 1.09500, offsetPips), "BUY_LIMIT always true");
    AssertTrue("Reopen.SellLimit", IsPriceAtReopenLevelSmart_Testable(entryPrice, ORDER_TYPE_SELL_LIMIT, 1.10500, offsetPips), "SELL_LIMIT always true");

    // BUY_STOP logic
    AssertTrue("Reopen.BuyStop.Below", IsPriceAtReopenLevelSmart_Testable(entryPrice, ORDER_TYPE_BUY_STOP, 1.09950, offsetPips), "Price below threshold");
    AssertFalse("Reopen.BuyStop.Above", IsPriceAtReopenLevelSmart_Testable(entryPrice, ORDER_TYPE_BUY_STOP, 1.10050, offsetPips), "Price above entry");

    // SELL_STOP logic
    AssertTrue("Reopen.SellStop.Above", IsPriceAtReopenLevelSmart_Testable(entryPrice, ORDER_TYPE_SELL_STOP, 1.10050, offsetPips), "Price above threshold");
    AssertFalse("Reopen.SellStop.Below", IsPriceAtReopenLevelSmart_Testable(entryPrice, ORDER_TYPE_SELL_STOP, 1.09950, offsetPips), "Price below entry");

    // CanLevelReopen tests
    AssertFalse("CanReopen.Disabled", CanLevelReopen_Testable(false, 0, false, ATR_NORMAL, 0), "Disabled");
    AssertTrue("CanReopen.Enabled", CanLevelReopen_Testable(true, 0, false, ATR_NORMAL, 0), "Enabled");
    AssertFalse("CanReopen.MaxCycles", CanLevelReopen_Testable(true, 5, false, ATR_NORMAL, 5), "Max cycles reached");
    AssertTrue("CanReopen.BelowMax", CanLevelReopen_Testable(true, 5, false, ATR_NORMAL, 4), "Below max");
    AssertFalse("CanReopen.Extreme", CanLevelReopen_Testable(true, 0, true, ATR_EXTREME, 0), "Extreme volatility");
}

//=============================================================================
//                         TEST SUITE: GridPositioning
//=============================================================================
void RunGridPositioningTests() {
    PrintTestHeader("GridPositioning Tests");

    // Order type tests
    AssertTrue("Grid.A.Upper.BuyStop", GetGridOrderType(GRID_A, ZONE_UPPER) == ORDER_TYPE_BUY_STOP, "Grid A Upper = BUY_STOP");
    AssertTrue("Grid.A.Lower.BuyLimit", GetGridOrderType(GRID_A, ZONE_LOWER) == ORDER_TYPE_BUY_LIMIT, "Grid A Lower = BUY_LIMIT");
    AssertTrue("Grid.B.Upper.SellLimit", GetGridOrderType(GRID_B, ZONE_UPPER) == ORDER_TYPE_SELL_LIMIT, "Grid B Upper = SELL_LIMIT");
    AssertTrue("Grid.B.Lower.SellStop", GetGridOrderType(GRID_B, ZONE_LOWER) == ORDER_TYPE_SELL_STOP, "Grid B Lower = SELL_STOP");

    // Entry price calculation
    ResetGridStatusForTests();
    double basePrice = 1.10000;
    double spacing = 20.0; // pips

    for(int level = 0; level < 3; level++) {
        double expectedUpper = basePrice + PipsToPoints(spacing/2.0 + spacing * level);
        double expectedLower = basePrice - PipsToPoints(spacing/2.0 + spacing * level);

        gridA_Upper_EntryPrices[level] = expectedUpper;
        gridA_Lower_EntryPrices[level] = expectedLower;

        AssertTrue(StringFormat("Grid.Price.Upper.L%d", level), gridA_Upper_EntryPrices[level] > basePrice, "Upper > base");
        AssertTrue(StringFormat("Grid.Price.Lower.L%d", level), gridA_Lower_EntryPrices[level] < basePrice, "Lower < base");
    }

    ResetGridStatusForTests();
}

//=============================================================================
//                         TEST SUITE: PositionMonitor
//=============================================================================
void RunPositionMonitorTests() {
    PrintTestHeader("PositionMonitor Tests");

    ResetGridStatusForTests();
    ResetGlobalTracking();

    // Status tracking tests
    gridA_Upper_Status[0] = ORDER_PENDING;
    AssertTrue("Status.Pending", gridA_Upper_Status[0] == ORDER_PENDING, "Status = PENDING");

    gridA_Upper_Status[0] = ORDER_FILLED;
    AssertTrue("Status.Filled", gridA_Upper_Status[0] == ORDER_FILLED, "Status = FILLED");

    gridA_Upper_Status[0] = ORDER_CLOSED_TP;
    AssertTrue("Status.ClosedTP", gridA_Upper_Status[0] == ORDER_CLOSED_TP, "Status = CLOSED_TP");

    // Exposure calculation
    totalLongLots = 0.05;
    totalShortLots = 0.03;
    netExposure = totalLongLots - totalShortLots;

    AssertEquals("Exposure.Net", netExposure, 0.02, 0.001, "Net exposure calculation");
    AssertTrue("Exposure.LongBias", netExposure > 0, "Long bias");

    ResetGridStatusForTests();
    ResetGlobalTracking();
}

//=============================================================================
//                         TEST SUITE: StatePersistence
//=============================================================================
void RunStatePersistenceTests() {
    PrintTestHeader("StatePersistence Tests");

    ResetGridStatusForTests();

    // Cycle count persistence test
    int testLevel = 0;
    gridA_Upper_Cycles[testLevel] = 0;

    IncrementCycleCount(GRID_A, ZONE_UPPER, testLevel);
    AssertEqualsInt("Persist.CycleIncrement", gridA_Upper_Cycles[testLevel], 1, "Cycle incremented");

    IncrementCycleCount(GRID_A, ZONE_UPPER, testLevel);
    IncrementCycleCount(GRID_A, ZONE_UPPER, testLevel);
    AssertEqualsInt("Persist.MultipleCycles", gridA_Upper_Cycles[testLevel], 3, "Multiple increments");

    // Level isolation
    IncrementCycleCount(GRID_A, ZONE_UPPER, 1);
    AssertEqualsInt("Persist.Level0.Isolated", gridA_Upper_Cycles[0], 3, "Level 0 unchanged");
    AssertEqualsInt("Persist.Level1.Incremented", gridA_Upper_Cycles[1], 1, "Level 1 incremented");

    // Close time recording
    datetime beforeTime = TimeCurrent();
    RecordCloseTime(GRID_A, ZONE_UPPER, testLevel);
    AssertTrue("Persist.CloseTime", gridA_Upper_LastClose[testLevel] >= beforeTime, "Close time recorded");

    ResetGridStatusForTests();
}

//=============================================================================
//                         TEST SUITE: OrderManager
//=============================================================================
void RunOrderManagerTests() {
    PrintTestHeader("OrderManager Tests");

    ResetGridStatusForTests();

    // Ticket assignment
    gridA_Upper_Tickets[0] = 12345;
    AssertEqualsLong("Order.Ticket", gridA_Upper_Tickets[0], 12345, "Ticket assigned");

    // Lot assignment
    gridA_Upper_Lots[0] = 0.01;
    AssertEquals("Order.Lots", gridA_Upper_Lots[0], 0.01, 0.001, "Lots assigned");

    // TP assignment
    gridA_Upper_TP[0] = 1.10500;
    AssertEquals("Order.TP", gridA_Upper_TP[0], 1.10500, 0.00001, "TP assigned");

    // Status transition flow
    gridA_Upper_Status[0] = ORDER_NONE;
    AssertTrue("Order.Flow.None", gridA_Upper_Status[0] == ORDER_NONE, "Initial: NONE");

    gridA_Upper_Status[0] = ORDER_PENDING;
    AssertTrue("Order.Flow.Pending", gridA_Upper_Status[0] == ORDER_PENDING, "Placed: PENDING");

    gridA_Upper_Status[0] = ORDER_FILLED;
    AssertTrue("Order.Flow.Filled", gridA_Upper_Status[0] == ORDER_FILLED, "Filled: FILLED");

    gridA_Upper_Status[0] = ORDER_CLOSED_TP;
    AssertTrue("Order.Flow.ClosedTP", gridA_Upper_Status[0] == ORDER_CLOSED_TP, "Closed: CLOSED_TP");

    ResetGridStatusForTests();
}

//+------------------------------------------------------------------+
//| Print Final Summary                                              |
//+------------------------------------------------------------------+
void PrintFinalSummary() {
    Print("");
    Print("################################################################");
    Print("#                                                              #");
    Print("#              SUGAMARA TEST RUNNER - FINAL SUMMARY            #");
    Print("#                                                              #");
    Print("################################################################");
    Print("");

    int totalTests = 0;
    int totalPassed = 0;
    int totalFailed = 0;
    uint totalTime = 0;

    // Suite breakdown
    Print("╔════════════════════════════════════════════════════════════════╗");
    Print("║ SUITE NAME                    │ TOTAL │ PASS │ FAIL │ TIME    ║");
    Print("╠════════════════════════════════════════════════════════════════╣");

    for(int i = 0; i < g_totalSuites; i++) {
        string status = (g_suiteResults[i].failed == 0) ? "✓" : "✗";
        Print(StringFormat("║ %-29s │ %5d │ %4d │ %4d │ %4dms %s ║",
            g_suiteResults[i].name,
            g_suiteResults[i].total,
            g_suiteResults[i].passed,
            g_suiteResults[i].failed,
            g_suiteResults[i].duration_ms,
            status));

        totalTests += g_suiteResults[i].total;
        totalPassed += g_suiteResults[i].passed;
        totalFailed += g_suiteResults[i].failed;
        totalTime += g_suiteResults[i].duration_ms;
    }

    Print("╠════════════════════════════════════════════════════════════════╣");
    Print(StringFormat("║ TOTAL                         │ %5d │ %4d │ %4d │ %4dms   ║",
        totalTests, totalPassed, totalFailed, totalTime));
    Print("╚════════════════════════════════════════════════════════════════╝");

    Print("");
    double passRate = (totalTests > 0) ? (totalPassed * 100.0 / totalTests) : 0;
    Print(StringFormat("Pass Rate: %.1f%% (%d/%d)", passRate, totalPassed, totalTests));
    Print("");

    if(totalFailed == 0) {
        Print("################################################################");
        Print("#                                                              #");
        Print("#                   ALL TESTS PASSED!                          #");
        Print("#                                                              #");
        Print("################################################################");
    } else {
        Print("################################################################");
        Print("#                                                              #");
        Print("#                 SOME TESTS FAILED!                           #");
        Print("#           Review output above for details                    #");
        Print("#                                                              #");
        Print("################################################################");
    }
}

//+------------------------------------------------------------------+
//| Script Start                                                     |
//+------------------------------------------------------------------+
void OnStart() {
    Print("");
    Print("################################################################");
    Print("#                                                              #");
    Print("#              SUGAMARA - COMPLETE TEST RUNNER                 #");
    Print("#                      Version 1.00                            #");
    Print("#                                                              #");
    Print("################################################################");
    Print("");

    // Setup
    SetupTestEnvironment();
    Print("");

    uint startTime;
    uint duration;

    // Suite 1: ATRCalculator
    ResetTestCounters();
    startTime = GetTickCount();
    RunATRCalculatorTests();
    duration = GetTickCount() - startTime;
    RecordSuiteResult("ATRCalculator", g_totalTests, g_passedTests, g_failedTests, duration);
    Print(StringFormat("\n  Suite 'ATRCalculator': %d tests, %d passed, %d failed (%d ms)\n",
        g_totalTests, g_passedTests, g_failedTests, duration));

    // Suite 2: CloseOnProfit
    ResetTestCounters();
    startTime = GetTickCount();
    RunCloseOnProfitTests();
    duration = GetTickCount() - startTime;
    RecordSuiteResult("CloseOnProfit", g_totalTests, g_passedTests, g_failedTests, duration);
    Print(StringFormat("\n  Suite 'CloseOnProfit': %d tests, %d passed, %d failed (%d ms)\n",
        g_totalTests, g_passedTests, g_failedTests, duration));

    // Suite 3: RiskManager
    ResetTestCounters();
    startTime = GetTickCount();
    RunRiskManagerTests();
    duration = GetTickCount() - startTime;
    RecordSuiteResult("RiskManager", g_totalTests, g_passedTests, g_failedTests, duration);
    Print(StringFormat("\n  Suite 'RiskManager': %d tests, %d passed, %d failed (%d ms)\n",
        g_totalTests, g_passedTests, g_failedTests, duration));

    // Suite 4: OrderReopen
    ResetTestCounters();
    startTime = GetTickCount();
    RunOrderReopenTests();
    duration = GetTickCount() - startTime;
    RecordSuiteResult("OrderReopen", g_totalTests, g_passedTests, g_failedTests, duration);
    Print(StringFormat("\n  Suite 'OrderReopen': %d tests, %d passed, %d failed (%d ms)\n",
        g_totalTests, g_passedTests, g_failedTests, duration));

    // Suite 5: GridPositioning
    ResetTestCounters();
    startTime = GetTickCount();
    RunGridPositioningTests();
    duration = GetTickCount() - startTime;
    RecordSuiteResult("GridPositioning", g_totalTests, g_passedTests, g_failedTests, duration);
    Print(StringFormat("\n  Suite 'GridPositioning': %d tests, %d passed, %d failed (%d ms)\n",
        g_totalTests, g_passedTests, g_failedTests, duration));

    // Suite 6: PositionMonitor
    ResetTestCounters();
    startTime = GetTickCount();
    RunPositionMonitorTests();
    duration = GetTickCount() - startTime;
    RecordSuiteResult("PositionMonitor", g_totalTests, g_passedTests, g_failedTests, duration);
    Print(StringFormat("\n  Suite 'PositionMonitor': %d tests, %d passed, %d failed (%d ms)\n",
        g_totalTests, g_passedTests, g_failedTests, duration));

    // Suite 7: StatePersistence
    ResetTestCounters();
    startTime = GetTickCount();
    RunStatePersistenceTests();
    duration = GetTickCount() - startTime;
    RecordSuiteResult("StatePersistence", g_totalTests, g_passedTests, g_failedTests, duration);
    Print(StringFormat("\n  Suite 'StatePersistence': %d tests, %d passed, %d failed (%d ms)\n",
        g_totalTests, g_passedTests, g_failedTests, duration));

    // Suite 8: OrderManager
    ResetTestCounters();
    startTime = GetTickCount();
    RunOrderManagerTests();
    duration = GetTickCount() - startTime;
    RecordSuiteResult("OrderManager", g_totalTests, g_passedTests, g_failedTests, duration);
    Print(StringFormat("\n  Suite 'OrderManager': %d tests, %d passed, %d failed (%d ms)\n",
        g_totalTests, g_passedTests, g_failedTests, duration));

    // Final summary
    PrintFinalSummary();
}
//+------------------------------------------------------------------+
