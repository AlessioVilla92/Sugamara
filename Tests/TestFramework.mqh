//+------------------------------------------------------------------+
//|                                                TestFramework.mqh |
//|                        Sugamara - Unit Test Framework            |
//|                                                                  |
//|  Common testing utilities for all Sugamara unit tests            |
//|  Include this file in all test scripts                           |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| TEST RESULT STRUCTURE                                            |
//+------------------------------------------------------------------+
struct TestResult {
    string testName;
    bool passed;
    string message;
    datetime executionTime;
};

//+------------------------------------------------------------------+
//| GLOBAL TEST TRACKING VARIABLES                                   |
//+------------------------------------------------------------------+
TestResult g_testResults[];
int g_totalTests = 0;
int g_passedTests = 0;
int g_failedTests = 0;

//+------------------------------------------------------------------+
//| ASSERT FUNCTIONS                                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Assert True - Base assertion function                            |
//+------------------------------------------------------------------+
bool AssertTrue(string testName, bool condition, string errorMsg = "") {
    ArrayResize(g_testResults, g_totalTests + 1);
    g_testResults[g_totalTests].testName = testName;
    g_testResults[g_totalTests].passed = condition;
    g_testResults[g_totalTests].message = condition ? "PASS" : ("FAIL: " + errorMsg);
    g_testResults[g_totalTests].executionTime = TimeCurrent();

    g_totalTests++;
    if(condition) {
        g_passedTests++;
        Print("[PASS] ", testName);
    } else {
        g_failedTests++;
        Print("[FAIL] ", testName, " - ", errorMsg);
    }

    return condition;
}

//+------------------------------------------------------------------+
//| Assert False - Inverse assertion                                 |
//+------------------------------------------------------------------+
bool AssertFalse(string testName, bool condition, string errorMsg = "") {
    return AssertTrue(testName, !condition, errorMsg);
}

//+------------------------------------------------------------------+
//| Assert Equals Double - Compare doubles with tolerance            |
//+------------------------------------------------------------------+
bool AssertEquals(string testName, double actual, double expected, double tolerance = 0.00001, string context = "") {
    bool passed = MathAbs(actual - expected) <= tolerance;
    string msg = passed ? "PASS" :
        StringFormat("Expected %.5f, got %.5f (tolerance %.5f) %s",
                     expected, actual, tolerance, context);
    return AssertTrue(testName, passed, msg);
}

//+------------------------------------------------------------------+
//| Assert Equals Int - Compare integers                             |
//+------------------------------------------------------------------+
bool AssertEqualsInt(string testName, int actual, int expected, string context = "") {
    bool passed = (actual == expected);
    string msg = passed ? "PASS" :
        StringFormat("Expected %d, got %d %s", expected, actual, context);
    return AssertTrue(testName, passed, msg);
}

//+------------------------------------------------------------------+
//| Assert Equals Long - Compare long integers                       |
//+------------------------------------------------------------------+
bool AssertEqualsLong(string testName, long actual, long expected, string context = "") {
    bool passed = (actual == expected);
    string msg = passed ? "PASS" :
        StringFormat("Expected %I64d, got %I64d %s", expected, actual, context);
    return AssertTrue(testName, passed, msg);
}

//+------------------------------------------------------------------+
//| Assert Equals String - Compare strings                           |
//+------------------------------------------------------------------+
bool AssertEqualsString(string testName, string actual, string expected, string context = "") {
    bool passed = (actual == expected);
    string msg = passed ? "PASS" :
        StringFormat("Expected '%s', got '%s' %s", expected, actual, context);
    return AssertTrue(testName, passed, msg);
}

//+------------------------------------------------------------------+
//| Assert Greater Than - Value comparison                           |
//+------------------------------------------------------------------+
bool AssertGreaterThan(string testName, double actual, double threshold, string context = "") {
    bool passed = actual > threshold;
    string msg = passed ? "PASS" :
        StringFormat("Expected > %.5f, got %.5f %s", threshold, actual, context);
    return AssertTrue(testName, passed, msg);
}

//+------------------------------------------------------------------+
//| Assert Greater Than Or Equal - Value comparison                  |
//+------------------------------------------------------------------+
bool AssertGreaterOrEqual(string testName, double actual, double threshold, string context = "") {
    bool passed = actual >= threshold;
    string msg = passed ? "PASS" :
        StringFormat("Expected >= %.5f, got %.5f %s", threshold, actual, context);
    return AssertTrue(testName, passed, msg);
}

//+------------------------------------------------------------------+
//| Assert Less Than - Value comparison                              |
//+------------------------------------------------------------------+
bool AssertLessThan(string testName, double actual, double threshold, string context = "") {
    bool passed = actual < threshold;
    string msg = passed ? "PASS" :
        StringFormat("Expected < %.5f, got %.5f %s", threshold, actual, context);
    return AssertTrue(testName, passed, msg);
}

//+------------------------------------------------------------------+
//| Assert Less Than Or Equal - Value comparison                     |
//+------------------------------------------------------------------+
bool AssertLessOrEqual(string testName, double actual, double threshold, string context = "") {
    bool passed = actual <= threshold;
    string msg = passed ? "PASS" :
        StringFormat("Expected <= %.5f, got %.5f %s", threshold, actual, context);
    return AssertTrue(testName, passed, msg);
}

//+------------------------------------------------------------------+
//| Assert In Range - Value within bounds                            |
//+------------------------------------------------------------------+
bool AssertInRange(string testName, double actual, double min, double max, string context = "") {
    bool passed = (actual >= min && actual <= max);
    string msg = passed ? "PASS" :
        StringFormat("Expected %.5f to be in [%.5f, %.5f] %s", actual, min, max, context);
    return AssertTrue(testName, passed, msg);
}

//+------------------------------------------------------------------+
//| Assert Not Null - Check non-zero value                           |
//+------------------------------------------------------------------+
bool AssertNotNull(string testName, double value, string context = "") {
    bool passed = (value != 0);
    string msg = passed ? "PASS" :
        StringFormat("Expected non-zero value, got %.5f %s", value, context);
    return AssertTrue(testName, passed, msg);
}

//+------------------------------------------------------------------+
//| Assert Null - Check zero value                                   |
//+------------------------------------------------------------------+
bool AssertNull(string testName, double value, string context = "") {
    bool passed = (value == 0);
    string msg = passed ? "PASS" :
        StringFormat("Expected zero, got %.5f %s", value, context);
    return AssertTrue(testName, passed, msg);
}

//+------------------------------------------------------------------+
//| TEST OUTPUT FORMATTING                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Print Test Suite Header                                          |
//+------------------------------------------------------------------+
void PrintTestHeader(string suiteName) {
    Print("");
    Print("================================================================");
    Print("  ", suiteName);
    Print("================================================================");
}

//+------------------------------------------------------------------+
//| Print Test Section                                               |
//+------------------------------------------------------------------+
void PrintTestSection(string sectionName) {
    Print("");
    Print("--- ", sectionName, " ---");
}

//+------------------------------------------------------------------+
//| Print Test Summary                                               |
//+------------------------------------------------------------------+
void PrintTestSummary() {
    Print("");
    Print("================================================================");
    Print("  TEST SUMMARY");
    Print("================================================================");
    Print("Total Tests:  ", g_totalTests);
    double passRate = (g_totalTests > 0) ? (g_passedTests * 100.0 / g_totalTests) : 0;
    Print("Passed:       ", g_passedTests, " (", DoubleToString(passRate, 1), "%)");
    Print("Failed:       ", g_failedTests);
    Print("================================================================");

    if(g_failedTests == 0) {
        Print("ALL TESTS PASSED!");
    } else {
        Print("SOME TESTS FAILED - Review output above");
    }
}

//+------------------------------------------------------------------+
//| Print Banner - For script start                                  |
//+------------------------------------------------------------------+
void PrintTestBanner(string testFileName, string version = "1.00") {
    Print("");
    Print("================================================================");
    Print("          SUGAMARA UNIT TESTS - ", testFileName);
    Print("                     Version ", version);
    Print("================================================================");
    Print("");
}

//+------------------------------------------------------------------+
//| Reset Test Counters - Call between test files                    |
//+------------------------------------------------------------------+
void ResetTestCounters() {
    ArrayResize(g_testResults, 0);
    g_totalTests = 0;
    g_passedTests = 0;
    g_failedTests = 0;
}

//+------------------------------------------------------------------+
//| TEST ENVIRONMENT SETUP                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Setup Base Test Environment                                      |
//+------------------------------------------------------------------+
void SetupBaseTestEnvironment() {
    // Initialize symbol info
    // _Symbol è una costante di sistema, già disponibile
    symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    Print("Test Environment:");
    Print("  Symbol: ", _Symbol);
    Print("  Digits: ", symbolDigits);
    Print("  Point:  ", symbolPoint);
}

//+------------------------------------------------------------------+
//| MOCK DATA HELPERS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Generate Mock Price                                              |
//+------------------------------------------------------------------+
double MockPrice(double base, double offsetPips) {
    return base + PipsToPoints(offsetPips);
}

//+------------------------------------------------------------------+
//| Generate Mock Lot Size                                           |
//+------------------------------------------------------------------+
double MockLotSize(double baseLot = 0.01) {
    return baseLot;
}

//+------------------------------------------------------------------+
//| TIME HELPERS                                                     |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Get Start of Today                                               |
//+------------------------------------------------------------------+
datetime GetStartOfToday() {
    return StringToTime(TimeToString(TimeCurrent(), TIME_DATE));
}

//+------------------------------------------------------------------+
//| Get Yesterday                                                    |
//+------------------------------------------------------------------+
datetime GetYesterday() {
    return GetStartOfToday() - 86400;
}

//+------------------------------------------------------------------+
//| Get Days Ago                                                     |
//+------------------------------------------------------------------+
datetime GetDaysAgo(int days) {
    return TimeCurrent() - (days * 86400);
}

//+------------------------------------------------------------------+
//| CONVERSION HELPERS                                               |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Pips to Points (if not already defined)                          |
//+------------------------------------------------------------------+
#ifndef PIPS_TO_POINTS_DEFINED
#define PIPS_TO_POINTS_DEFINED
double PipsToPoints_Test(double pips) {
    if(symbolDigits == 3 || symbolDigits == 5) {
        return pips * 10 * symbolPoint;
    }
    return pips * symbolPoint;
}
#endif

//+------------------------------------------------------------------+
//| Points to Pips (if not already defined)                          |
//+------------------------------------------------------------------+
#ifndef POINTS_TO_PIPS_DEFINED
#define POINTS_TO_PIPS_DEFINED
double PointsToPips_Test(double points) {
    if(symbolDigits == 3 || symbolDigits == 5) {
        return points / (10 * symbolPoint);
    }
    return points / symbolPoint;
}
#endif

//+------------------------------------------------------------------+
//| TEST ISOLATION HELPERS                                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| TEST ISOLATION - NOTA IMPORTANTE                                 |
//|                                                                  |
//| I parametri 'input' in MQL5 sono READ-ONLY a runtime.            |
//| Non è possibile modificarli o ripristinarli durante l'esecuzione.|
//|                                                                  |
//| I test devono usare variabili locali per valori di test.         |
//| Le funzioni SaveAllInputParameters/RestoreAllInputParameters     |
//| sono mantenute per compatibilità ma non modificano nulla.        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Save Input Parameters (no-op per compatibilità)                  |
//+------------------------------------------------------------------+
void SaveAllInputParameters() {
    // I parametri input sono read-only in MQL5
    // Questa funzione è mantenuta solo per compatibilità
    Print("  [Info] Input parameters are read-only, using current configuration");
}

//+------------------------------------------------------------------+
//| Restore Input Parameters (no-op per compatibilità)               |
//+------------------------------------------------------------------+
void RestoreAllInputParameters() {
    // I parametri input sono read-only in MQL5
    // Questa funzione è mantenuta solo per compatibilità
}

//+------------------------------------------------------------------+
//| Reset Grid Status Arrays                                         |
//+------------------------------------------------------------------+
void ResetAllGridArrays() {
    for(int i = 0; i < MAX_GRID_LEVELS; i++) {
        gridA_Upper_Status[i] = ORDER_NONE;
        gridA_Lower_Status[i] = ORDER_NONE;
        gridB_Upper_Status[i] = ORDER_NONE;
        gridB_Lower_Status[i] = ORDER_NONE;

        gridA_Upper_Cycles[i] = 0;
        gridA_Lower_Cycles[i] = 0;
        gridB_Upper_Cycles[i] = 0;
        gridB_Lower_Cycles[i] = 0;

        gridA_Upper_LastClose[i] = 0;
        gridA_Lower_LastClose[i] = 0;
        gridB_Upper_LastClose[i] = 0;
        gridB_Lower_LastClose[i] = 0;

        gridA_Upper_EntryPrices[i] = 0;
        gridA_Lower_EntryPrices[i] = 0;
        gridB_Upper_EntryPrices[i] = 0;
        gridB_Lower_EntryPrices[i] = 0;

        gridA_Upper_Tickets[i] = 0;
        gridA_Lower_Tickets[i] = 0;
        gridB_Upper_Tickets[i] = 0;
        gridB_Lower_Tickets[i] = 0;

        gridA_Upper_Lots[i] = 0;
        gridA_Lower_Lots[i] = 0;
        gridB_Upper_Lots[i] = 0;
        gridB_Lower_Lots[i] = 0;

        gridA_Upper_TP[i] = 0;
        gridA_Lower_TP[i] = 0;
        gridB_Upper_TP[i] = 0;
        gridB_Lower_TP[i] = 0;
    }
}

//+------------------------------------------------------------------+
//| Reset Global Tracking Variables                                  |
//+------------------------------------------------------------------+
void ResetGlobalTracking() {
    totalLongLots = 0;
    totalShortLots = 0;
    netExposure = 0;
    isNeutral = true;

    sessionRealizedProfit = 0;
    sessionPeakProfit = 0;
    sessionGrossProfit = 0;
    sessionGrossLoss = 0;
    sessionWins = 0;
    sessionLosses = 0;
    totalTrades = 0;

    maxDrawdownReached = 0;
    maxEquityReached = 0;
}

//+------------------------------------------------------------------+
