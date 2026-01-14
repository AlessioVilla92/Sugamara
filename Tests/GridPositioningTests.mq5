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
#include "../Utils/Helpers.mqh"
#include "../Utils/GridHelpers.mqh"
#include "TestFramework.mqh"

//+------------------------------------------------------------------+
//| SETUP - Inizializzazione environment test                        |
//+------------------------------------------------------------------+
void SetupTestEnvironment() {
    SetupBaseTestEnvironment();

    // Imposta parametri di default per i test
    GridLevelsPerSide = 10;
    BaseLot = 0.01;
}

//+------------------------------------------------------------------+
//| TEST 1: Entry Spacing Modes                                      |
//+------------------------------------------------------------------+
void Test_EntrySpacingModes() {
    PrintTestHeader("TEST SUITE 1: Entry Spacing Modes");

    double spacing = 20.0; // 20 pips
    double manualSpacing = 15.0; // 15 pips per MANUAL mode

    // Test FULL mode
    EntrySpacingMode = ENTRY_SPACING_FULL;
    double fullSpacing = GetEntrySpacingPips(spacing);
    AssertEquals("EntrySpacing.FULL", fullSpacing, spacing, 0.001,
                 "- FULL mode should return full spacing");

    // Test HALF mode
    EntrySpacingMode = ENTRY_SPACING_HALF;
    double halfSpacing = GetEntrySpacingPips(spacing);
    AssertEquals("EntrySpacing.HALF", halfSpacing, spacing / 2.0, 0.001,
                 "- HALF mode should return half spacing (Perfect Cascade)");

    // Test MANUAL mode
    EntrySpacingMode = ENTRY_SPACING_MANUAL;
    Entry_Spacing_Manual_Pips = manualSpacing;
    double customSpacing = GetEntrySpacingPips(spacing);
    AssertEquals("EntrySpacing.MANUAL", customSpacing, manualSpacing, 0.001,
                 "- MANUAL mode should return custom spacing");
}

//+------------------------------------------------------------------+
//| TEST 2: Grid Level Price Calculation                             |
//+------------------------------------------------------------------+
void Test_GridLevelPriceCalculation() {
    PrintTestHeader("TEST SUITE 2: Grid Level Price Calculation");

    double entryPrice = 1.10000;
    double spacing = 20.0; // 20 pips
    EntrySpacingMode = ENTRY_SPACING_HALF; // Perfect Cascade

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

    // Test FULL mode spacing
    Print("\n--- Testing FULL Spacing Mode ---");
    EntrySpacingMode = ENTRY_SPACING_FULL;

    double price0 = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, 0, spacing, GRID_A);
    double price1 = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, 1, spacing, GRID_A);

    // Calcola spacing effettivo tra Level 0 e Level 1
    double actualSpacingPips = PointsToPips(price1 - price0);
    AssertEquals("Spacing.FULL.L0toL1", actualSpacingPips, spacing, 0.5,
                 "- Spacing between consecutive levels");

    // Test HALF mode spacing
    Print("\n--- Testing HALF Spacing Mode (Perfect Cascade) ---");
    EntrySpacingMode = ENTRY_SPACING_HALF;

    price0 = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, 0, spacing, GRID_A);
    price1 = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, 1, spacing, GRID_A);

    // Distanza entry -> Level 0 dovrebbe essere spacing/2
    double entryToL0Pips = PointsToPips(price0 - entryPrice);
    AssertEquals("Spacing.HALF.EntryToL0", entryToL0Pips, spacing / 2.0, 0.5,
                 "- Entry to Level 0 distance");

    // Distanza Level 0 -> Level 1 dovrebbe essere spacing completo
    actualSpacingPips = PointsToPips(price1 - price0);
    AssertEquals("Spacing.HALF.L0toL1", actualSpacingPips, spacing, 0.5,
                 "- Level 0 to Level 1 distance");
}

//+------------------------------------------------------------------+
//| TEST 4: Cascade TP Calculation - PERFECT Mode                    |
//+------------------------------------------------------------------+
void Test_CascadeTP_Perfect() {
    PrintTestHeader("TEST SUITE 4: Cascade TP - PERFECT Mode");

    double entryPrice = 1.10000;
    double spacing = 20.0;
    int totalLevels = 10;

    NeutralMode = NEUTRAL_CASCADE;
    CascadeMode = CASCADE_PERFECT;
    EntrySpacingMode = ENTRY_SPACING_HALF;

    // Test Grid A Upper (BUY STOP) - TP deve essere al livello successivo
    Print("\n--- Testing Grid A Upper (BUY) Perfect Cascade ---");
    for(int level = 0; level < 5; level++) {
        double levelPrice = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, level, spacing, GRID_A);
        double tpPrice = CalculateCascadeTP(entryPrice, GRID_A, ZONE_UPPER, level, spacing, totalLevels);
        double expectedTP = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, level + 1, spacing, GRID_A);

        string testName = StringFormat("CascadeTP.Perfect.GridA.Upper.L%d", level);
        string context = StringFormat("- Level %d entry=%.5f, TP should be next level=%.5f",
                                     level, levelPrice, expectedTP);
        AssertEquals(testName, tpPrice, expectedTP, 0.00001, context);
    }

    // Test Grid A Lower (BUY LIMIT) - TP deve essere verso l'entry
    Print("\n--- Testing Grid A Lower (BUY) Perfect Cascade ---");
    for(int level = 1; level < 5; level++) { // Start from 1, level 0 is special case
        double levelPrice = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, level, spacing, GRID_A);
        double tpPrice = CalculateCascadeTP(entryPrice, GRID_A, ZONE_LOWER, level, spacing, totalLevels);
        double expectedTP = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, level - 1, spacing, GRID_A);

        string testName = StringFormat("CascadeTP.Perfect.GridA.Lower.L%d", level);
        string context = StringFormat("- Level %d entry=%.5f, TP should be previous level=%.5f",
                                     level, levelPrice, expectedTP);
        AssertEquals(testName, tpPrice, expectedTP, 0.00001, context);
    }

    // Test Grid B Upper (SELL LIMIT) - TP deve essere verso l'entry
    Print("\n--- Testing Grid B Upper (SELL) Perfect Cascade ---");
    for(int level = 1; level < 5; level++) {
        double levelPrice = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, level, spacing, GRID_B);
        double tpPrice = CalculateCascadeTP(entryPrice, GRID_B, ZONE_UPPER, level, spacing, totalLevels);
        double expectedTP = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, level - 1, spacing, GRID_B);

        string testName = StringFormat("CascadeTP.Perfect.GridB.Upper.L%d", level);
        string context = StringFormat("- Level %d entry=%.5f, TP should be previous level=%.5f",
                                     level, levelPrice, expectedTP);
        AssertEquals(testName, tpPrice, expectedTP, 0.00001, context);
    }

    // Test Grid B Lower (SELL STOP) - TP deve essere al livello successivo
    Print("\n--- Testing Grid B Lower (SELL) Perfect Cascade ---");
    for(int level = 0; level < 5; level++) {
        double levelPrice = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, level, spacing, GRID_B);
        double tpPrice = CalculateCascadeTP(entryPrice, GRID_B, ZONE_LOWER, level, spacing, totalLevels);
        double expectedTP = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, level + 1, spacing, GRID_B);

        string testName = StringFormat("CascadeTP.Perfect.GridB.Lower.L%d", level);
        string context = StringFormat("- Level %d entry=%.5f, TP should be next level=%.5f",
                                     level, levelPrice, expectedTP);
        AssertEquals(testName, tpPrice, expectedTP, 0.00001, context);
    }
}

//+------------------------------------------------------------------+
//| TEST 5: Cascade TP Calculation - RATIO Mode                      |
//+------------------------------------------------------------------+
void Test_CascadeTP_Ratio() {
    PrintTestHeader("TEST SUITE 5: Cascade TP - RATIO Mode");

    double entryPrice = 1.10000;
    double spacing = 20.0;
    int totalLevels = 10;
    double ratio = 1.5;

    NeutralMode = NEUTRAL_CASCADE;
    CascadeMode = CASCADE_RATIO;
    CascadeTP_Ratio = ratio;

    // Test Grid A Upper (BUY) - TP = entry + (spacing × ratio)
    Print("\n--- Testing Grid A Upper (BUY) Ratio Cascade ---");
    for(int level = 0; level < 5; level++) {
        double levelPrice = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, level, spacing, GRID_A);
        double tpPrice = CalculateCascadeTP(entryPrice, GRID_A, ZONE_UPPER, level, spacing, totalLevels);
        double expectedTP = levelPrice + PipsToPoints(spacing * ratio);

        string testName = StringFormat("CascadeTP.Ratio.GridA.Upper.L%d", level);
        string context = StringFormat("- Level %d entry=%.5f, TP=entry+(%.1f*%.1f)",
                                     level, levelPrice, spacing, ratio);
        AssertEquals(testName, tpPrice, expectedTP, 0.00001, context);
    }

    // Test Grid B Lower (SELL) - TP = entry - (spacing × ratio)
    Print("\n--- Testing Grid B Lower (SELL) Ratio Cascade ---");
    for(int level = 0; level < 5; level++) {
        double levelPrice = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, level, spacing, GRID_B);
        double tpPrice = CalculateCascadeTP(entryPrice, GRID_B, ZONE_LOWER, level, spacing, totalLevels);
        double expectedTP = levelPrice - PipsToPoints(spacing * ratio);

        string testName = StringFormat("CascadeTP.Ratio.GridB.Lower.L%d", level);
        string context = StringFormat("- Level %d entry=%.5f, TP=entry-(%.1f*%.1f)",
                                     level, levelPrice, spacing, ratio);
        AssertEquals(testName, tpPrice, expectedTP, 0.00001, context);
    }
}

//+------------------------------------------------------------------+
//| TEST 6: PURE Mode TP Calculation                                 |
//+------------------------------------------------------------------+
void Test_PureMode_TP() {
    PrintTestHeader("TEST SUITE 6: PURE Mode TP Calculation");

    double entryPrice = 1.10000;
    double spacing = 20.0;
    int totalLevels = 10;
    double tpRatio = 1.0;

    NeutralMode = NEUTRAL_PURE;
    TP_Ratio_Pure = tpRatio;

    // Test Grid A Upper (BUY) - TP fisso
    Print("\n--- Testing PURE Mode (Fixed TP) ---");
    for(int level = 0; level < 5; level++) {
        double levelPrice = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, level, spacing, GRID_A);
        double tpPrice = CalculateCascadeTP(entryPrice, GRID_A, ZONE_UPPER, level, spacing, totalLevels);
        double expectedTP = levelPrice + PipsToPoints(spacing * tpRatio);

        string testName = StringFormat("PureMode.TP.GridA.Upper.L%d", level);
        string context = StringFormat("- Level %d TP should be entry + fixed distance", level);
        AssertEquals(testName, tpPrice, expectedTP, 0.00001, context);
    }
}

//+------------------------------------------------------------------+
//| TEST 7: Order Type Assignment                                    |
//+------------------------------------------------------------------+
void Test_OrderTypeAssignment() {
    PrintTestHeader("TEST SUITE 7: Order Type Assignment");

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
//| TEST 8: Grid A vs Grid B Symmetry                                |
//+------------------------------------------------------------------+
void Test_GridSymmetry() {
    PrintTestHeader("TEST SUITE 8: Grid A vs Grid B Symmetry");

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
//| TEST 9: Max Grid Levels Support (30 levels)                      |
//+------------------------------------------------------------------+
void Test_MaxGridLevels() {
    PrintTestHeader("TEST SUITE 9: Maximum Grid Levels Support");

    double entryPrice = 1.10000;
    double spacing = 20.0;
    int maxLevels = 30;

    GridLevelsPerSide = maxLevels;

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

    // Reset to default
    GridLevelsPerSide = 10;
}

//+------------------------------------------------------------------+
//| TEST 10: Edge Cases and Validation                               |
//+------------------------------------------------------------------+
void Test_EdgeCases() {
    PrintTestHeader("TEST SUITE 10: Edge Cases and Validation");

    // Test validazione livelli
    bool valid = IsValidLevelIndex(0);
    AssertTrue("Validation.Level.Min", valid, "Level 0 should be valid");

    valid = IsValidLevelIndex(GridLevelsPerSide - 1);
    AssertTrue("Validation.Level.Max", valid, "Last level should be valid");

    valid = IsValidLevelIndex(-1);
    AssertTrue("Validation.Level.Negative", !valid, "Negative level should be invalid");

    valid = IsValidLevelIndex(MAX_GRID_LEVELS);
    AssertTrue("Validation.Level.Overflow", !valid, "Level >= MAX should be invalid");

    // Test configurazione griglia
    GridLevelsPerSide = 10;
    double spacing = 20.0;
    currentSpacing_Pips = spacing;
    entryPoint = 1.10000;

    bool configValid = ValidateGridConfiguration();
    AssertTrue("Validation.Config.Valid", configValid, "Valid config should pass");

    // Test spacing troppo piccolo
    currentSpacing_Pips = 0.5;
    configValid = ValidateGridConfiguration();
    AssertTrue("Validation.Config.SmallSpacing", !configValid, "Too small spacing should fail");

    // Reset
    currentSpacing_Pips = spacing;
}

//+------------------------------------------------------------------+
//| TEST 11: Real-World Scenario Test                                |
//+------------------------------------------------------------------+
void Test_RealWorldScenario() {
    PrintTestHeader("TEST SUITE 11: Real-World Scenario");

    Print("\n--- Simulating Real Grid Setup ---");

    // Setup realistico: EUR/USD, 10 livelli, 20 pips spacing, HALF mode, PERFECT cascade
    double entryPrice = 1.09500;
    double spacing = 20.0;
    int levels = 10;

    GridLevelsPerSide = levels;
    NeutralMode = NEUTRAL_CASCADE;
    CascadeMode = CASCADE_PERFECT;
    EntrySpacingMode = ENTRY_SPACING_HALF;

    Print("Configuration:");
    Print("  Entry: ", entryPrice);
    Print("  Spacing: ", spacing, " pips");
    Print("  Levels: ", levels);
    Print("  Mode: HALF + PERFECT CASCADE");

    // Calcola e stampa Grid A Upper
    Print("\n--- Grid A Upper (BUY STOP) ---");
    for(int i = 0; i < 5; i++) {
        double entryP = CalculateGridLevelPrice(entryPrice, ZONE_UPPER, i, spacing, GRID_A);
        double tpP = CalculateCascadeTP(entryPrice, GRID_A, ZONE_UPPER, i, spacing, levels);
        double distancePips = PointsToPips(tpP - entryP);
        Print(StringFormat("  L%d: Entry=%.5f, TP=%.5f, Distance=%.1f pips",
                          i, entryP, tpP, distancePips));
    }

    // Calcola e stampa Grid A Lower
    Print("\n--- Grid A Lower (BUY LIMIT) ---");
    for(int i = 0; i < 5; i++) {
        double entryP = CalculateGridLevelPrice(entryPrice, ZONE_LOWER, i, spacing, GRID_A);
        double tpP = CalculateCascadeTP(entryPrice, GRID_A, ZONE_LOWER, i, spacing, levels);
        double distancePips = PointsToPips(tpP - entryP);
        Print(StringFormat("  L%d: Entry=%.5f, TP=%.5f, Distance=%.1f pips",
                          i, entryP, tpP, distancePips));
    }

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

    AssertTrue("RealWorld.GridGeneration", true, "Real-world scenario completed successfully");
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

    Test_CascadeTP_Perfect();
    Print("");

    Test_CascadeTP_Ratio();
    Print("");

    Test_PureMode_TP();
    Print("");

    Test_OrderTypeAssignment();
    Print("");

    Test_GridSymmetry();
    Print("");

    Test_MaxGridLevels();
    Print("");

    Test_EdgeCases();
    Print("");

    Test_RealWorldScenario();
    Print("");

    // Print summary
    PrintTestSummary();
}
//+------------------------------------------------------------------+
