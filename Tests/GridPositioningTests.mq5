//+------------------------------------------------------------------+
//|                                       GridPositioningTests.mq5   |
//|                        Sugamara - Grid Positioning Unit Tests    |
//|                                                                  |
//|  Unit tests per verificare il corretto posizionamento iniziale   |
//|  della griglia in tutte le modalità di configurazione            |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"
#property version   "1.00"
#property script_show_inputs

//+------------------------------------------------------------------+
//| Include necessari                                                |
//+------------------------------------------------------------------+
#include "../Config/Enums.mqh"
#include "../Config/InputParameters.mqh"
#include "../Core/GlobalVariables.mqh"

//+------------------------------------------------------------------+
//| STUBS: Mock functions to avoid dependency chains                 |
//| Nei test non servono i valori reali, restituiamo valori fissi    |
//+------------------------------------------------------------------+
double GetWinRate() { return 0.0; }
double NormalizeLotSize(double lot) { return lot; }

#include "../Utils/Helpers.mqh"
#include "../Utils/GridHelpers.mqh"

//+------------------------------------------------------------------+
//| TEST FRAMEWORK - Struttura base per i test                       |
//+------------------------------------------------------------------+
struct TestResult {
    string testName;
    bool passed;
    string message;
    datetime executionTime;
};

TestResult g_testResults[];
int g_totalTests = 0;
int g_passedTests = 0;
int g_failedTests = 0;

//+------------------------------------------------------------------+
//| TEST PARAMETERS - Valori locali per i test (non input)           |
//+------------------------------------------------------------------+
ENUM_ENTRY_SPACING_MODE testEntrySpacingMode = ENTRY_SPACING_HALF;
ENUM_NEUTRAL_MODE testNeutralMode = NEUTRAL_CASCADE;
ENUM_CASCADE_MODE testCascadeMode = CASCADE_PERFECT;
double testEntrySpacingManual = 10.0;
double testTPRatioPure = 1.0;
double testCascadeTPRatio = 1.5;
double testCurrentSpacing = 20.0;
double testEntryPoint = 1.10000;
int testGridLevelsPerSide = 10;

//+------------------------------------------------------------------+
//| Get Dynamic Tolerance based on symbol digits                     |
//| JPY pairs (2-3 digits) need larger tolerance                     |
//+------------------------------------------------------------------+
double GetDynamicTolerance() {
    if(symbolDigits <= 3) {
        return 0.001;  // JPY pairs: 0.001
    }
    return 0.00001;    // Standard pairs: 0.00001
}

//+------------------------------------------------------------------+
//| Assert Functions                                                 |
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
        Print("[✓] ", testName, " - PASSED");
    } else {
        g_failedTests++;
        Print("[✗] ", testName, " - FAILED: ", errorMsg);
    }

    return condition;
}

bool AssertEquals(string testName, double actual, double expected, double tolerance = 0.00001, string context = "") {
    bool passed = MathAbs(actual - expected) <= tolerance;
    string msg = passed ? "PASS" :
        StringFormat("Expected %.5f, got %.5f (tolerance %.5f) %s",
                     expected, actual, tolerance, context);
    return AssertTrue(testName, passed, msg);
}

bool AssertGreaterThan(string testName, double actual, double threshold, string context = "") {
    bool passed = actual > threshold;
    string msg = passed ? "PASS" :
        StringFormat("Expected > %.5f, got %.5f %s", threshold, actual, context);
    return AssertTrue(testName, passed, msg);
}

bool AssertLessThan(string testName, double actual, double threshold, string context = "") {
    bool passed = actual < threshold;
    string msg = passed ? "PASS" :
        StringFormat("Expected < %.5f, got %.5f %s", threshold, actual, context);
    return AssertTrue(testName, passed, msg);
}

//+------------------------------------------------------------------+
//| Test Suite Header                                                |
//+------------------------------------------------------------------+
void PrintTestHeader(string suiteName) {
    Print("═══════════════════════════════════════════════════════════════");
    Print("  ", suiteName);
    Print("═══════════════════════════════════════════════════════════════");
}

void PrintTestSummary() {
    Print("");
    Print("═══════════════════════════════════════════════════════════════");
    Print("  TEST SUMMARY");
    Print("═══════════════════════════════════════════════════════════════");
    Print("Total Tests:  ", g_totalTests);
    Print("Passed:       ", g_passedTests, " (", (g_totalTests > 0 ? (g_passedTests*100.0/g_totalTests) : 0), "%)");
    Print("Failed:       ", g_failedTests);
    Print("═══════════════════════════════════════════════════════════════");

    if(g_failedTests == 0) {
        Print("✓ ALL TESTS PASSED!");
    } else {
        Print("✗ SOME TESTS FAILED - Review output above");
    }
}

//+------------------------------------------------------------------+
//| SETUP - Inizializzazione environment test                        |
//+------------------------------------------------------------------+
void SetupTestEnvironment() {
    // Inizializza variabili globali necessarie
    // _Symbol è una costante di sistema, già disponibile
    symbolDigits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
    symbolPoint = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

    // Inizializza variabili globali modificabili per i test
    currentSpacing_Pips = testCurrentSpacing;
    entryPoint = testEntryPoint;

    Print("Test environment initialized:");
    Print("  Symbol: ", _Symbol);
    Print("  Digits: ", symbolDigits);
    Print("  Point: ", symbolPoint);
    Print("  Dynamic Tolerance: ", GetDynamicTolerance());
}

//+------------------------------------------------------------------+
//| TEST 1: Entry Spacing Modes                                      |
//| NOTA: Testa con i valori di input configurati                    |
//+------------------------------------------------------------------+
void Test_EntrySpacingModes() {
    PrintTestHeader("TEST SUITE 1: Entry Spacing Modes");

    double spacing = 20.0; // 20 pips

    // Test con il mode attuale (configurato via input)
    double actualSpacing = GetEntrySpacingPips(spacing);

    Print("Current EntrySpacingMode: ", EnumToString(EntrySpacingMode));
    Print("GetEntrySpacingPips(", spacing, ") = ", actualSpacing);

    // Verifica che il risultato sia coerente con il mode
    if(EntrySpacingMode == ENTRY_SPACING_FULL) {
        AssertEquals("EntrySpacing.FULL", actualSpacing, spacing, 0.001,
                     "- FULL mode should return full spacing");
    } else if(EntrySpacingMode == ENTRY_SPACING_HALF) {
        AssertEquals("EntrySpacing.HALF", actualSpacing, spacing / 2.0, 0.001,
                     "- HALF mode should return half spacing");
    } else if(EntrySpacingMode == ENTRY_SPACING_MANUAL) {
        AssertEquals("EntrySpacing.MANUAL", actualSpacing, Entry_Spacing_Manual_Pips, 0.001,
                     "- MANUAL mode should return custom spacing");
    }
}

//+------------------------------------------------------------------+
//| TEST 2: Grid Level Price Calculation                             |
//+------------------------------------------------------------------+
void Test_GridLevelPriceCalculation() {
    PrintTestHeader("TEST SUITE 2: Grid Level Price Calculation");

    double entryPrice = 1.10000;
    double spacing = 20.0; // 20 pips

    // Test Upper Zone - i prezzi devono essere SOPRA l'entry
    Print("\n--- Testing UPPER Zone (prices above entry) ---");
    for(int level = 0; level < 5; level++) {
        double price = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, level, spacing, GRID_A);
        string testName = StringFormat("GridPrice.Upper.Level%d", level);
        string context = StringFormat("at level %d", level);
        AssertGreaterThan(testName, price, entryPrice, context);
    }

    // Test Lower Zone - i prezzi devono essere SOTTO l'entry
    Print("\n--- Testing LOWER Zone (prices below entry) ---");
    for(int level = 0; level < 5; level++) {
        double price = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, level, spacing, GRID_A);
        string testName = StringFormat("GridPrice.Lower.Level%d", level);
        string context = StringFormat("at level %d", level);
        AssertLessThan(testName, price, entryPrice, context);
    }

    // Test monotonia prezzi Upper (Level N+1 > Level N)
    Print("\n--- Testing UPPER Zone monotonicity ---");
    double prevPrice = 0;
    for(int level = 0; level < 5; level++) {
        double price = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, level, spacing, GRID_A);
        if(level > 0) {
            string testName = StringFormat("GridPrice.Upper.Monotonic.L%d", level);
            string context = StringFormat("- Level %d (%.5f) > Level %d (%.5f)",
                                         level, price, level-1, prevPrice);
            AssertGreaterThan(testName, price, prevPrice, context);
        }
        prevPrice = price;
    }

    // Test monotonia prezzi Lower (Level N+1 < Level N)
    Print("\n--- Testing LOWER Zone monotonicity ---");
    prevPrice = 999999.0;
    for(int level = 0; level < 5; level++) {
        double price = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, level, spacing, GRID_A);
        if(level > 0) {
            string testName = StringFormat("GridPrice.Lower.Monotonic.L%d", level);
            string context = StringFormat("- Level %d (%.5f) < Level %d (%.5f)",
                                         level, price, level-1, prevPrice);
            AssertLessThan(testName, price, prevPrice, context);
        }
        prevPrice = price;
    }
}

//+------------------------------------------------------------------+
//| TEST 3: Spacing Distance Verification                            |
//+------------------------------------------------------------------+
void Test_SpacingDistance() {
    PrintTestHeader("TEST SUITE 3: Spacing Distance Verification");

    double entryPrice = 1.10000;
    double spacing = 20.0; // 20 pips

    // Test spacing con il mode attuale
    Print("\n--- Testing Spacing with current mode ---");
    Print("Current EntrySpacingMode: ", EnumToString(EntrySpacingMode));

    double price0 = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, 0, spacing, GRID_A);
    double price1 = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, 1, spacing, GRID_A);

    // Distanza entry -> Level 0
    double entryToL0Pips = PointsToPips(price0 - entryPrice);
    Print("Entry to Level 0: ", entryToL0Pips, " pips");

    // Distanza Level 0 -> Level 1
    double l0ToL1Pips = PointsToPips(price1 - price0);
    Print("Level 0 to Level 1: ", l0ToL1Pips, " pips");

    // La distanza tra livelli consecutivi (L0->L1) dovrebbe essere il full spacing
    AssertEquals("Spacing.L0toL1", l0ToL1Pips, spacing, 0.5,
                 "- Spacing between consecutive levels should be full spacing");
}

//+------------------------------------------------------------------+
//| TEST 4: Cascade TP Calculation                                   |
//+------------------------------------------------------------------+
void Test_CascadeTP() {
    PrintTestHeader("TEST SUITE 4: Cascade TP Calculation");

    double entryPrice = 1.10000;
    double spacing = 20.0;
    int totalLevels = GridLevelsPerSide;

    Print("Current NeutralMode: ", EnumToString(NeutralMode));
    Print("Current CascadeMode: ", EnumToString(CascadeMode));

    // Test Grid A Upper (BUY STOP)
    Print("\n--- Testing Grid A Upper (BUY) ---");
    for(int level = 0; level < 3; level++) {
        double levelPrice = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, level, spacing, GRID_A);
        double tpPrice = CalculateCascadeTP(entryPrice, GRID_A, ZONE_UPPER, level, spacing, totalLevels);

        string testName = StringFormat("CascadeTP.GridA.Upper.L%d", level);
        // Per BUY, TP deve essere sopra entry
        AssertGreaterThan(testName, tpPrice, levelPrice,
                         StringFormat("- Level %d TP must be above entry for BUY", level));
    }

    // Test Grid A Lower (BUY LIMIT)
    Print("\n--- Testing Grid A Lower (BUY) ---");
    for(int level = 0; level < 3; level++) {
        double levelPrice = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, level, spacing, GRID_A);
        double tpPrice = CalculateCascadeTP(entryPrice, GRID_A, ZONE_LOWER, level, spacing, totalLevels);

        string testName = StringFormat("CascadeTP.GridA.Lower.L%d", level);
        // Per BUY, TP deve essere sopra entry
        AssertGreaterThan(testName, tpPrice, levelPrice,
                         StringFormat("- Level %d TP must be above entry for BUY", level));
    }

    // Test Grid B Upper (SELL LIMIT)
    Print("\n--- Testing Grid B Upper (SELL) ---");
    for(int level = 1; level < 3; level++) {
        double levelPrice = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, level, spacing, GRID_B);
        double tpPrice = CalculateCascadeTP(entryPrice, GRID_B, ZONE_UPPER, level, spacing, totalLevels);

        string testName = StringFormat("CascadeTP.GridB.Upper.L%d", level);
        // Per SELL, TP deve essere sotto entry
        AssertLessThan(testName, tpPrice, levelPrice,
                       StringFormat("- Level %d TP must be below entry for SELL", level));
    }

    // Test Grid B Lower (SELL STOP)
    Print("\n--- Testing Grid B Lower (SELL) ---");
    for(int level = 0; level < 3; level++) {
        double levelPrice = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, level, spacing, GRID_B);
        double tpPrice = CalculateCascadeTP(entryPrice, GRID_B, ZONE_LOWER, level, spacing, totalLevels);

        string testName = StringFormat("CascadeTP.GridB.Lower.L%d", level);
        // Per SELL, TP deve essere sotto entry
        AssertLessThan(testName, tpPrice, levelPrice,
                       StringFormat("- Level %d TP must be below entry for SELL", level));
    }
}

//+------------------------------------------------------------------+
//| TEST 5: Order Type Assignment                                    |
//+------------------------------------------------------------------+
void Test_OrderTypeAssignment() {
    PrintTestHeader("TEST SUITE 5: Order Type Assignment");

    // Grid A = SEMPRE BUY (BUY STOP sopra, BUY LIMIT sotto)
    ENUM_ORDER_TYPE typeA_Upper = GetGridOrderType(GRID_A, ZONE_UPPER);
    AssertTrue("OrderType.GridA.Upper", typeA_Upper == ORDER_TYPE_BUY_STOP,
               "Grid A Upper should be BUY STOP");

    ENUM_ORDER_TYPE typeA_Lower = GetGridOrderType(GRID_A, ZONE_LOWER);
    AssertTrue("OrderType.GridA.Lower", typeA_Lower == ORDER_TYPE_BUY_LIMIT,
               "Grid A Lower should be BUY LIMIT");

    // Grid B = SEMPRE SELL (SELL LIMIT sopra, SELL STOP sotto)
    ENUM_ORDER_TYPE typeB_Upper = GetGridOrderType(GRID_B, ZONE_UPPER);
    AssertTrue("OrderType.GridB.Upper", typeB_Upper == ORDER_TYPE_SELL_LIMIT,
               "Grid B Upper should be SELL LIMIT");

    ENUM_ORDER_TYPE typeB_Lower = GetGridOrderType(GRID_B, ZONE_LOWER);
    AssertTrue("OrderType.GridB.Lower", typeB_Lower == ORDER_TYPE_SELL_STOP,
               "Grid B Lower should be SELL STOP");
}

//+------------------------------------------------------------------+
//| TEST 6: Grid A vs Grid B Symmetry                                |
//+------------------------------------------------------------------+
void Test_GridSymmetry() {
    PrintTestHeader("TEST SUITE 6: Grid A vs Grid B Symmetry");

    double entryPrice = 1.10000;
    double spacing = 20.0;

    // I prezzi devono essere identici, solo i tipi di ordine cambiano
    Print("\n--- Testing Upper Zone Price Symmetry ---");
    for(int level = 0; level < 5; level++) {
        double priceA = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, level, spacing, GRID_A);
        double priceB = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, level, spacing, GRID_B);

        string testName = StringFormat("Symmetry.Upper.L%d", level);
        string context = StringFormat("- Grid A and B should have same prices at level %d", level);
        AssertEquals(testName, priceA, priceB, 0.00001, context);
    }

    Print("\n--- Testing Lower Zone Price Symmetry ---");
    for(int level = 0; level < 5; level++) {
        double priceA = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, level, spacing, GRID_A);
        double priceB = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, level, spacing, GRID_B);

        string testName = StringFormat("Symmetry.Lower.L%d", level);
        string context = StringFormat("- Grid A and B should have same prices at level %d", level);
        AssertEquals(testName, priceA, priceB, 0.00001, context);
    }
}

//+------------------------------------------------------------------+
//| TEST 7: Max Grid Levels Support (30 levels)                      |
//+------------------------------------------------------------------+
void Test_MaxGridLevels() {
    PrintTestHeader("TEST SUITE 7: Maximum Grid Levels Support");

    double entryPrice = 1.10000;
    double spacing = 20.0;
    int maxLevels = 30;

    // Test che tutti i 30 livelli siano calcolabili
    Print("\n--- Testing 30 levels calculation ---");
    bool allLevelsValid = true;
    double prevPrice = 0;

    for(int level = 0; level < maxLevels; level++) {
        double price = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, level, spacing, GRID_A);

        if(price <= entryPrice) {
            allLevelsValid = false;
            Print("  FAIL: Level ", level, " price ", price, " not above entry");
            break;
        }

        if(level > 0 && price <= prevPrice) {
            allLevelsValid = false;
            Print("  FAIL: Level ", level, " price ", price, " not greater than previous ", prevPrice);
            break;
        }

        prevPrice = price;
    }

    AssertTrue("MaxLevels.30Levels.Upper", allLevelsValid,
               "All 30 upper levels should be valid and monotonic");
}

//+------------------------------------------------------------------+
//| TEST 8: Level Index Validation                                   |
//+------------------------------------------------------------------+
void Test_LevelValidation() {
    PrintTestHeader("TEST SUITE 8: Level Index Validation");

    // Test validazione livelli
    bool valid = IsValidLevelIndex(0);
    AssertTrue("Validation.Level.Min", valid, "Level 0 should be valid");

    valid = IsValidLevelIndex(GridLevelsPerSide - 1);
    AssertTrue("Validation.Level.Max", valid, "Last level should be valid");

    valid = IsValidLevelIndex(-1);
    AssertTrue("Validation.Level.Negative", !valid, "Negative level should be invalid");

    valid = IsValidLevelIndex(MAX_GRID_LEVELS);
    AssertTrue("Validation.Level.Overflow", !valid, "Level >= MAX should be invalid");
}

//+------------------------------------------------------------------+
//| TEST 9: Grid Configuration Validation                            |
//+------------------------------------------------------------------+
void Test_ConfigValidation() {
    PrintTestHeader("TEST SUITE 9: Grid Configuration Validation");

    // Salva valori originali
    double origSpacing = currentSpacing_Pips;
    double origEntry = entryPoint;

    // Test configurazione valida
    currentSpacing_Pips = 20.0;
    entryPoint = 1.10000;
    bool configValid = ValidateGridConfiguration();
    AssertTrue("Validation.Config.Valid", configValid, "Valid config should pass");

    // Test spacing troppo piccolo
    currentSpacing_Pips = 0.5;
    configValid = ValidateGridConfiguration();
    AssertTrue("Validation.Config.SmallSpacing", !configValid, "Too small spacing should fail");

    // Ripristina
    currentSpacing_Pips = origSpacing;
    entryPoint = origEntry;
}

//+------------------------------------------------------------------+
//| TEST 10: Real-World Scenario Test                                |
//+------------------------------------------------------------------+
void Test_RealWorldScenario() {
    PrintTestHeader("TEST SUITE 10: Real-World Scenario");

    Print("\n--- Simulating Real Grid Setup ---");

    double entryPrice = 1.09500;
    double spacing = 20.0;
    int levels = GridLevelsPerSide;
    double tol = GetDynamicTolerance();

    Print("Configuration:");
    Print("  Entry: ", entryPrice);
    Print("  Spacing: ", spacing, " pips");
    Print("  Levels: ", levels);
    Print("  EntrySpacingMode: ", EnumToString(EntrySpacingMode));
    Print("  NeutralMode: ", EnumToString(NeutralMode));
    Print("  CascadeMode: ", EnumToString(CascadeMode));

    // Calcola e stampa Grid A Upper
    Print("\n--- Grid A Upper (BUY STOP) ---");
    bool allUpperValid = true;
    for(int i = 0; i < 5; i++) {
        double entryP = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, i, spacing, GRID_A);
        double tpP = CalculateCascadeTP(entryPrice, GRID_A, ZONE_UPPER, i, spacing, levels);
        double distancePips = PointsToPips(tpP - entryP);
        Print(StringFormat("  L%d: Entry=%.5f, TP=%.5f, Distance=%.1f pips",
                          i, entryP, tpP, distancePips));

        // Verifica: TP deve essere sopra entry per BUY
        if(tpP <= entryP) allUpperValid = false;
    }
    AssertTrue("RealWorld.GridA.Upper.Valid", allUpperValid,
               "All Upper BUY entries should have valid TP above entry");

    // Calcola e stampa Grid A Lower
    Print("\n--- Grid A Lower (BUY LIMIT) ---");
    bool allLowerValid = true;
    for(int i = 0; i < 5; i++) {
        double entryP = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, i, spacing, GRID_A);
        double tpP = CalculateCascadeTP(entryPrice, GRID_A, ZONE_LOWER, i, spacing, levels);
        double distancePips = PointsToPips(tpP - entryP);
        Print(StringFormat("  L%d: Entry=%.5f, TP=%.5f, Distance=%.1f pips",
                          i, entryP, tpP, distancePips));

        // Verifica: TP deve essere sopra entry per BUY
        if(tpP <= entryP) allLowerValid = false;
    }
    AssertTrue("RealWorld.GridA.Lower.Valid", allLowerValid,
               "All Lower BUY entries should have valid TP above entry");

    // Verifica range totale
    double firstUpper = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, 0, spacing, GRID_A);
    double lastUpper = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, levels-1, spacing, GRID_A);
    double firstLower = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, 0, spacing, GRID_A);
    double lastLower = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, levels-1, spacing, GRID_A);

    double totalRangePips = PointsToPips(lastUpper - lastLower);
    Print("\n--- Grid Range ---");
    Print("  Upper: ", firstUpper, " to ", lastUpper);
    Print("  Lower: ", firstLower, " to ", lastLower);
    Print("  Total Range: ", totalRangePips, " pips");

    // Verifica simmetria: firstUpper e firstLower equidistanti da entry
    double distToFirstUpper = PointsToPips(firstUpper - entryPrice);
    double distToFirstLower = PointsToPips(entryPrice - firstLower);
    AssertEquals("RealWorld.Symmetry", distToFirstUpper, distToFirstLower, 0.1,
                 "First upper and lower levels should be equidistant from entry");
}

//+------------------------------------------------------------------+
//| TEST 11: Error Handling Tests                                    |
//+------------------------------------------------------------------+
void Test_ErrorHandling() {
    PrintTestHeader("TEST SUITE 11: Error Handling");

    // Salva valori originali
    double origSpacing = currentSpacing_Pips;
    double origEntry = entryPoint;

    // Test 1: Negative level index
    Print("\n--- Testing Negative Level Index ---");
    bool negativeInvalid = !IsValidLevelIndex(-1);
    AssertTrue("Error.NegativeLevel", negativeInvalid, "Negative level index should be invalid");

    // Test 2: Level exceeding MAX_GRID_LEVELS
    Print("\n--- Testing Overflow Level Index ---");
    bool overflowInvalid = !IsValidLevelIndex(MAX_GRID_LEVELS);
    AssertTrue("Error.OverflowLevel", overflowInvalid, "Level at MAX_GRID_LEVELS should be invalid");

    // Test 3: Zero spacing validation
    Print("\n--- Testing Zero Spacing ---");
    currentSpacing_Pips = 0.0;
    entryPoint = 1.10000;
    bool zeroSpacingInvalid = !ValidateGridConfiguration();
    AssertTrue("Error.ZeroSpacing", zeroSpacingInvalid, "Zero spacing should fail validation");

    // Test 4: Negative spacing
    currentSpacing_Pips = -5.0;
    bool negSpacingInvalid = !ValidateGridConfiguration();
    AssertTrue("Error.NegativeSpacing", negSpacingInvalid, "Negative spacing should fail validation");

    // Ripristina
    currentSpacing_Pips = origSpacing;
    entryPoint = origEntry;
}

//+------------------------------------------------------------------+
//| Script Start                                                     |
//+------------------------------------------------------------------+
void OnStart() {
    Print("\n");
    Print("╔═══════════════════════════════════════════════════════════════╗");
    Print("║          SUGAMARA - GRID POSITIONING UNIT TESTS               ║");
    Print("║                     Version 1.00                              ║");
    Print("╚═══════════════════════════════════════════════════════════════╝");
    Print("");

    // Setup environment
    SetupTestEnvironment();
    Print("");

    // Run all test suites
    Test_EntrySpacingModes();
    Print("");

    Test_GridLevelPriceCalculation();
    Print("");

    Test_SpacingDistance();
    Print("");

    Test_CascadeTP();
    Print("");

    Test_OrderTypeAssignment();
    Print("");

    Test_GridSymmetry();
    Print("");

    Test_MaxGridLevels();
    Print("");

    Test_LevelValidation();
    Print("");

    Test_ConfigValidation();
    Print("");

    Test_RealWorldScenario();
    Print("");

    Test_ErrorHandling();
    Print("");

    // Print summary
    PrintTestSummary();
}
//+------------------------------------------------------------------+
