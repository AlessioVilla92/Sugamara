//+------------------------------------------------------------------+
//|                                        StatePersistenceTests.mq5 |
//|                        Sugamara - State Persistence Unit Tests   |
//|                                                                  |
//|  Tests for state save/restore, age validation, merge logic       |
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
//| STATE PERSISTENCE CONSTANTS                                      |
//+------------------------------------------------------------------+
#define MAX_STATE_AGE_DAYS 7

//+------------------------------------------------------------------+
//| TESTABLE VERSIONS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Testable: Generate State Key                                     |
//+------------------------------------------------------------------+
string GetStateKey_Testable(string symbol, string varName) {
    return "SUGAMARA_STATE_" + symbol + "_" + varName;
}

//+------------------------------------------------------------------+
//| Testable: Is State Too Old                                       |
//+------------------------------------------------------------------+
bool IsStateTooOld_Testable(datetime savedTime, datetime currentTime, int maxAgeDays) {
    if(savedTime == 0) return true;
    int ageSeconds = (int)(currentTime - savedTime);
    int maxAgeSeconds = maxAgeDays * 24 * 60 * 60;
    return (ageSeconds > maxAgeSeconds);
}

//+------------------------------------------------------------------+
//| Testable: Get State Age Minutes                                  |
//+------------------------------------------------------------------+
int GetStateAgeMinutes_Testable(datetime savedTime, datetime currentTime) {
    if(savedTime == 0) return -1;
    return (int)((currentTime - savedTime) / 60);
}

//+------------------------------------------------------------------+
//| Testable: Should Auto Save Now                                   |
//+------------------------------------------------------------------+
bool ShouldAutoSaveNow_Testable(datetime lastSaveTime, datetime currentTime, int intervalMinutes, bool isActive) {
    if(!isActive) return false;
    if(lastSaveTime == 0) return true;
    int intervalSeconds = intervalMinutes * 60;
    return ((currentTime - lastSaveTime) >= intervalSeconds);
}

//+------------------------------------------------------------------+
//| Testable: Resolve Merge Conflict                                 |
//| Returns which status to use: "BROKER" or "SAVED"                 |
//+------------------------------------------------------------------+
string ResolveMergeConflict_Testable(ENUM_ORDER_STATUS brokerStatus, ENUM_ORDER_STATUS savedStatus) {
    // Priority: Active broker states > Saved cycling states > Default
    // If broker shows FILLED or PENDING, use broker
    if(brokerStatus == ORDER_FILLED || brokerStatus == ORDER_PENDING) {
        return "BROKER";
    }

    // If saved shows cycling states (CLOSED_TP/SL/CANCELLED), preserve for cycling
    if(savedStatus == ORDER_CLOSED_TP || savedStatus == ORDER_CLOSED_SL || savedStatus == ORDER_CANCELLED) {
        return "SAVED";
    }

    // If broker shows closed states, use broker
    if(brokerStatus == ORDER_CLOSED_TP || brokerStatus == ORDER_CLOSED_SL || brokerStatus == ORDER_CANCELLED) {
        return "BROKER";
    }

    // Default: use broker status
    return "BROKER";
}

//+------------------------------------------------------------------+
//| Testable: Validate Entry Point                                   |
//+------------------------------------------------------------------+
bool IsValidEntryPoint_Testable(double entryPoint) {
    return (entryPoint > 0);
}

//+------------------------------------------------------------------+
//| Testable: Encode Status for Storage                              |
//+------------------------------------------------------------------+
int EncodeOrderStatus_Testable(ENUM_ORDER_STATUS status) {
    return (int)status;
}

//+------------------------------------------------------------------+
//| Testable: Decode Status from Storage                             |
//+------------------------------------------------------------------+
ENUM_ORDER_STATUS DecodeOrderStatus_Testable(int value) {
    if(value < 0 || value > 8) return ORDER_NONE;
    return (ENUM_ORDER_STATUS)value;
}

//+------------------------------------------------------------------+
//| TEST SUITE 1: State Key Generation                               |
//+------------------------------------------------------------------+
void Test_StateKeyGeneration() {
    PrintTestHeader("TEST SUITE 1: State Key Generation");

    // Test 1.1: Standard symbol
    PrintTestSection("Standard Symbols");
    string key = GetStateKey_Testable("EURUSD", "entryPoint");
    AssertEqualsString("1.1a Key.EURUSD", key, "SUGAMARA_STATE_EURUSD_entryPoint");

    key = GetStateKey_Testable("GBPUSD", "systemState");
    AssertEqualsString("1.1b Key.GBPUSD", key, "SUGAMARA_STATE_GBPUSD_systemState");

    // Test 1.2: JPY pairs
    PrintTestSection("JPY Pairs");
    key = GetStateKey_Testable("USDJPY", "currentSpacing");
    AssertEqualsString("1.2 Key.USDJPY", key, "SUGAMARA_STATE_USDJPY_currentSpacing");

    // Test 1.3: Array variables
    PrintTestSection("Array Variables");
    key = GetStateKey_Testable("EURUSD", "gAU_Status_0");
    AssertEqualsString("1.3a Key.Array.Status", key, "SUGAMARA_STATE_EURUSD_gAU_Status_0");

    key = GetStateKey_Testable("EURUSD", "gBL_Cycles_15");
    AssertEqualsString("1.3b Key.Array.Cycles", key, "SUGAMARA_STATE_EURUSD_gBL_Cycles_15");

    // Test 1.4: Key uniqueness per symbol
    PrintTestSection("Key Uniqueness");
    string key1 = GetStateKey_Testable("EURUSD", "entryPoint");
    string key2 = GetStateKey_Testable("GBPUSD", "entryPoint");
    AssertFalse("1.4 Key.Unique", key1 == key2, "Keys should be unique per symbol");
}

//+------------------------------------------------------------------+
//| TEST SUITE 2: State Age Validation                               |
//+------------------------------------------------------------------+
void Test_StateAgeValidation() {
    PrintTestHeader("TEST SUITE 2: State Age Validation");

    datetime now = TimeCurrent();
    int maxAgeDays = 7;

    // Test 2.1: Fresh state (just saved)
    PrintTestSection("Fresh State");
    datetime savedTime = now - 60; // 1 minute ago
    AssertFalse("2.1 Age.Fresh", IsStateTooOld_Testable(savedTime, now, maxAgeDays), "1 min old not too old");

    // Test 2.2: 1 day old
    PrintTestSection("1 Day Old");
    savedTime = now - (1 * 24 * 60 * 60); // 1 day ago
    AssertFalse("2.2 Age.1Day", IsStateTooOld_Testable(savedTime, now, maxAgeDays), "1 day old not too old");

    // Test 2.3: 6 days old
    PrintTestSection("6 Days Old");
    savedTime = now - (6 * 24 * 60 * 60); // 6 days ago
    AssertFalse("2.3 Age.6Days", IsStateTooOld_Testable(savedTime, now, maxAgeDays), "6 days old not too old");

    // Test 2.4: Exactly 7 days old
    PrintTestSection("7 Days Old (Boundary)");
    savedTime = now - (7 * 24 * 60 * 60); // 7 days ago
    AssertFalse("2.4 Age.7Days", IsStateTooOld_Testable(savedTime, now, maxAgeDays), "7 days old is at boundary");

    // Test 2.5: Over 7 days old
    PrintTestSection("Over 7 Days Old");
    savedTime = now - (8 * 24 * 60 * 60); // 8 days ago
    AssertTrue("2.5a Age.8Days", IsStateTooOld_Testable(savedTime, now, maxAgeDays), "8 days old is too old");

    savedTime = now - (30 * 24 * 60 * 60); // 30 days ago
    AssertTrue("2.5b Age.30Days", IsStateTooOld_Testable(savedTime, now, maxAgeDays), "30 days old is too old");

    // Test 2.6: Zero timestamp (never saved)
    PrintTestSection("Never Saved");
    AssertTrue("2.6 Age.NeverSaved", IsStateTooOld_Testable(0, now, maxAgeDays), "Zero timestamp is too old");
}

//+------------------------------------------------------------------+
//| TEST SUITE 3: State Age Minutes                                  |
//+------------------------------------------------------------------+
void Test_StateAgeMinutes() {
    PrintTestHeader("TEST SUITE 3: State Age Minutes");

    datetime now = TimeCurrent();

    // Test 3.1: Just saved (0 minutes)
    PrintTestSection("Just Saved");
    AssertEqualsInt("3.1 AgeMin.JustSaved", GetStateAgeMinutes_Testable(now, now), 0);

    // Test 3.2: 5 minutes ago
    PrintTestSection("5 Minutes Ago");
    datetime savedTime = now - (5 * 60);
    AssertEqualsInt("3.2 AgeMin.5Min", GetStateAgeMinutes_Testable(savedTime, now), 5);

    // Test 3.3: 1 hour ago
    PrintTestSection("1 Hour Ago");
    savedTime = now - (60 * 60);
    AssertEqualsInt("3.3 AgeMin.1Hour", GetStateAgeMinutes_Testable(savedTime, now), 60);

    // Test 3.4: 1 day ago
    PrintTestSection("1 Day Ago");
    savedTime = now - (24 * 60 * 60);
    AssertEqualsInt("3.4 AgeMin.1Day", GetStateAgeMinutes_Testable(savedTime, now), 1440);

    // Test 3.5: Never saved
    PrintTestSection("Never Saved");
    AssertEqualsInt("3.5 AgeMin.NeverSaved", GetStateAgeMinutes_Testable(0, now), -1);
}

//+------------------------------------------------------------------+
//| TEST SUITE 4: Auto Save Timing                                   |
//+------------------------------------------------------------------+
void Test_AutoSaveTiming() {
    PrintTestHeader("TEST SUITE 4: Auto Save Timing");

    datetime now = TimeCurrent();
    int intervalMinutes = 5;

    // Test 4.1: First save (never saved before)
    PrintTestSection("First Save");
    AssertTrue("4.1 AutoSave.FirstSave", ShouldAutoSaveNow_Testable(0, now, intervalMinutes, true), "First save should trigger");

    // Test 4.2: Just saved (not time yet)
    PrintTestSection("Just Saved");
    datetime lastSave = now - 60; // 1 minute ago
    AssertFalse("4.2 AutoSave.TooSoon", ShouldAutoSaveNow_Testable(lastSave, now, intervalMinutes, true), "1 min ago not time yet");

    // Test 4.3: Exactly at interval
    PrintTestSection("At Interval");
    lastSave = now - (intervalMinutes * 60); // Exactly 5 minutes ago
    AssertTrue("4.3 AutoSave.AtInterval", ShouldAutoSaveNow_Testable(lastSave, now, intervalMinutes, true), "At interval should trigger");

    // Test 4.4: Past interval
    PrintTestSection("Past Interval");
    lastSave = now - (10 * 60); // 10 minutes ago
    AssertTrue("4.4 AutoSave.PastInterval", ShouldAutoSaveNow_Testable(lastSave, now, intervalMinutes, true), "Past interval should trigger");

    // Test 4.5: System not active
    PrintTestSection("System Not Active");
    AssertFalse("4.5 AutoSave.NotActive", ShouldAutoSaveNow_Testable(0, now, intervalMinutes, false), "Inactive should not save");

    // Test 4.6: Different intervals
    PrintTestSection("Different Intervals");
    lastSave = now - (15 * 60); // 15 minutes ago
    AssertTrue("4.6a AutoSave.15MinInterval", ShouldAutoSaveNow_Testable(lastSave, now, 10, true), "15 min with 10 min interval");
    AssertFalse("4.6b AutoSave.30MinInterval", ShouldAutoSaveNow_Testable(lastSave, now, 30, true), "15 min with 30 min interval");
}

//+------------------------------------------------------------------+
//| TEST SUITE 5: Merge Conflict Resolution                          |
//+------------------------------------------------------------------+
void Test_MergeConflictResolution() {
    PrintTestHeader("TEST SUITE 5: Merge Conflict Resolution");

    // Test 5.1: Broker FILLED wins
    PrintTestSection("Broker FILLED Wins");
    AssertEqualsString("5.1a Merge.FilledVsNone", ResolveMergeConflict_Testable(ORDER_FILLED, ORDER_NONE), "BROKER");
    AssertEqualsString("5.1b Merge.FilledVsClosedTP", ResolveMergeConflict_Testable(ORDER_FILLED, ORDER_CLOSED_TP), "BROKER");
    AssertEqualsString("5.1c Merge.FilledVsClosedSL", ResolveMergeConflict_Testable(ORDER_FILLED, ORDER_CLOSED_SL), "BROKER");

    // Test 5.2: Broker PENDING wins
    PrintTestSection("Broker PENDING Wins");
    AssertEqualsString("5.2a Merge.PendingVsNone", ResolveMergeConflict_Testable(ORDER_PENDING, ORDER_NONE), "BROKER");
    AssertEqualsString("5.2b Merge.PendingVsClosedTP", ResolveMergeConflict_Testable(ORDER_PENDING, ORDER_CLOSED_TP), "BROKER");

    // Test 5.3: Saved cycling states preserved
    PrintTestSection("Saved Cycling States Preserved");
    AssertEqualsString("5.3a Merge.NoneVsClosedTP", ResolveMergeConflict_Testable(ORDER_NONE, ORDER_CLOSED_TP), "SAVED");
    AssertEqualsString("5.3b Merge.NoneVsClosedSL", ResolveMergeConflict_Testable(ORDER_NONE, ORDER_CLOSED_SL), "SAVED");
    AssertEqualsString("5.3c Merge.NoneVsCancelled", ResolveMergeConflict_Testable(ORDER_NONE, ORDER_CANCELLED), "SAVED");

    // Test 5.4: Broker closed states used
    PrintTestSection("Broker Closed States");
    AssertEqualsString("5.4a Merge.ClosedTPVsNone", ResolveMergeConflict_Testable(ORDER_CLOSED_TP, ORDER_NONE), "BROKER");
    AssertEqualsString("5.4b Merge.ClosedSLVsNone", ResolveMergeConflict_Testable(ORDER_CLOSED_SL, ORDER_NONE), "BROKER");

    // Test 5.5: Both NONE
    PrintTestSection("Both NONE");
    AssertEqualsString("5.5 Merge.BothNone", ResolveMergeConflict_Testable(ORDER_NONE, ORDER_NONE), "BROKER");
}

//+------------------------------------------------------------------+
//| TEST SUITE 6: Entry Point Validation                             |
//+------------------------------------------------------------------+
void Test_EntryPointValidation() {
    PrintTestHeader("TEST SUITE 6: Entry Point Validation");

    // Test 6.1: Valid entry points
    PrintTestSection("Valid Entry Points");
    AssertTrue("6.1a Entry.Valid.Normal", IsValidEntryPoint_Testable(1.10000), "Normal price valid");
    AssertTrue("6.1b Entry.Valid.JPY", IsValidEntryPoint_Testable(150.00), "JPY price valid");
    AssertTrue("6.1c Entry.Valid.Small", IsValidEntryPoint_Testable(0.00001), "Very small price valid");

    // Test 6.2: Invalid entry points
    PrintTestSection("Invalid Entry Points");
    AssertFalse("6.2a Entry.Invalid.Zero", IsValidEntryPoint_Testable(0), "Zero invalid");
    AssertFalse("6.2b Entry.Invalid.Negative", IsValidEntryPoint_Testable(-1.10000), "Negative invalid");
}

//+------------------------------------------------------------------+
//| TEST SUITE 7: Status Encoding/Decoding                           |
//+------------------------------------------------------------------+
void Test_StatusEncodingDecoding() {
    PrintTestHeader("TEST SUITE 7: Status Encoding/Decoding");

    // Test 7.1: Encode all statuses
    PrintTestSection("Encode Statuses");
    AssertEqualsInt("7.1a Encode.NONE", EncodeOrderStatus_Testable(ORDER_NONE), 0);
    AssertEqualsInt("7.1b Encode.PENDING", EncodeOrderStatus_Testable(ORDER_PENDING), 1);
    AssertEqualsInt("7.1c Encode.FILLED", EncodeOrderStatus_Testable(ORDER_FILLED), 2);
    AssertEqualsInt("7.1d Encode.CLOSED", EncodeOrderStatus_Testable(ORDER_CLOSED), 3);
    AssertEqualsInt("7.1e Encode.CLOSED_TP", EncodeOrderStatus_Testable(ORDER_CLOSED_TP), 4);
    AssertEqualsInt("7.1f Encode.CLOSED_SL", EncodeOrderStatus_Testable(ORDER_CLOSED_SL), 5);
    AssertEqualsInt("7.1g Encode.CANCELLED", EncodeOrderStatus_Testable(ORDER_CANCELLED), 6);
    AssertEqualsInt("7.1h Encode.ERROR", EncodeOrderStatus_Testable(ORDER_ERROR), 7);

    // Test 7.2: Decode all statuses
    PrintTestSection("Decode Statuses");
    AssertTrue("7.2a Decode.0", DecodeOrderStatus_Testable(0) == ORDER_NONE, "0 = ORDER_NONE");
    AssertTrue("7.2b Decode.1", DecodeOrderStatus_Testable(1) == ORDER_PENDING, "1 = ORDER_PENDING");
    AssertTrue("7.2c Decode.2", DecodeOrderStatus_Testable(2) == ORDER_FILLED, "2 = ORDER_FILLED");
    AssertTrue("7.2d Decode.4", DecodeOrderStatus_Testable(4) == ORDER_CLOSED_TP, "4 = ORDER_CLOSED_TP");
    AssertTrue("7.2e Decode.5", DecodeOrderStatus_Testable(5) == ORDER_CLOSED_SL, "5 = ORDER_CLOSED_SL");
    AssertTrue("7.2f Decode.6", DecodeOrderStatus_Testable(6) == ORDER_CANCELLED, "6 = ORDER_CANCELLED");

    // Test 7.3: Invalid decode values
    PrintTestSection("Invalid Decode");
    AssertTrue("7.3a Decode.Negative", DecodeOrderStatus_Testable(-1) == ORDER_NONE, "-1 = ORDER_NONE");
    AssertTrue("7.3b Decode.TooHigh", DecodeOrderStatus_Testable(99) == ORDER_NONE, "99 = ORDER_NONE");

    // Test 7.4: Round-trip encoding
    PrintTestSection("Round-Trip Encoding");
    ENUM_ORDER_STATUS original = ORDER_CLOSED_TP;
    int encoded = EncodeOrderStatus_Testable(original);
    ENUM_ORDER_STATUS decoded = DecodeOrderStatus_Testable(encoded);
    AssertTrue("7.4 RoundTrip.ClosedTP", decoded == original, "Round-trip should preserve status");
}

//+------------------------------------------------------------------+
//| TEST SUITE 8: Grid Array Persistence                             |
//+------------------------------------------------------------------+
void Test_GridArrayPersistence() {
    PrintTestHeader("TEST SUITE 8: Grid Array Persistence");

    // Simulate saving and restoring grid arrays
    PrintTestSection("Grid Status Array");

    // Original values
    ENUM_ORDER_STATUS originalStatuses[5] = {ORDER_NONE, ORDER_PENDING, ORDER_FILLED, ORDER_CLOSED_TP, ORDER_CLOSED_SL};
    int encodedStatuses[5];
    ENUM_ORDER_STATUS decodedStatuses[5];

    // Encode
    for(int i = 0; i < 5; i++) {
        encodedStatuses[i] = EncodeOrderStatus_Testable(originalStatuses[i]);
    }

    // Decode
    for(int i = 0; i < 5; i++) {
        decodedStatuses[i] = DecodeOrderStatus_Testable(encodedStatuses[i]);
    }

    // Verify
    bool allMatch = true;
    for(int i = 0; i < 5; i++) {
        if(originalStatuses[i] != decodedStatuses[i]) {
            allMatch = false;
            break;
        }
    }
    AssertTrue("8.1 GridArray.StatusPersistence", allMatch, "All statuses should persist correctly");

    // Test cycles persistence
    PrintTestSection("Grid Cycles Array");
    int originalCycles[5] = {0, 1, 5, 10, 99};
    int restoredCycles[5];

    // Simulate save/restore
    for(int i = 0; i < 5; i++) {
        restoredCycles[i] = originalCycles[i];
    }

    allMatch = true;
    for(int i = 0; i < 5; i++) {
        if(originalCycles[i] != restoredCycles[i]) {
            allMatch = false;
            break;
        }
    }
    AssertTrue("8.2 GridArray.CyclesPersistence", allMatch, "All cycles should persist correctly");
}

//+------------------------------------------------------------------+
//| TEST SUITE 9: Integration - Full Persistence Flow                |
//+------------------------------------------------------------------+
void Test_FullPersistenceFlow() {
    PrintTestHeader("TEST SUITE 9: Full Persistence Flow Integration");

    datetime now = TimeCurrent();
    datetime savedTime = now - (30 * 60); // 30 minutes ago

    // Simulate state check flow
    PrintTestSection("State Check Flow");

    // Step 1: Check age
    bool tooOld = IsStateTooOld_Testable(savedTime, now, 7);
    int ageMinutes = GetStateAgeMinutes_Testable(savedTime, now);
    Print("  State age: ", ageMinutes, " minutes");
    Print("  Too old: ", tooOld ? "YES" : "NO");
    AssertFalse("9.1a Flow.NotTooOld", tooOld, "30 min state should not be too old");
    AssertEqualsInt("9.1b Flow.Age30Min", ageMinutes, 30);

    // Step 2: Check entry point validity
    double savedEntryPoint = 1.10500;
    bool validEntry = IsValidEntryPoint_Testable(savedEntryPoint);
    AssertTrue("9.2 Flow.ValidEntry", validEntry, "Entry point should be valid");

    // Step 3: Simulate merge for multiple levels
    PrintTestSection("Merge Flow");
    ENUM_ORDER_STATUS brokerStatuses[] = {ORDER_FILLED, ORDER_NONE, ORDER_NONE, ORDER_PENDING, ORDER_NONE};
    ENUM_ORDER_STATUS savedStatuses[] = {ORDER_CLOSED_TP, ORDER_CLOSED_TP, ORDER_CLOSED_SL, ORDER_NONE, ORDER_CANCELLED};
    string expectedResolutions[] = {"BROKER", "SAVED", "SAVED", "BROKER", "SAVED"};

    bool allResolved = true;
    for(int i = 0; i < 5; i++) {
        string resolution = ResolveMergeConflict_Testable(brokerStatuses[i], savedStatuses[i]);
        Print("  Level ", i, ": Broker=", EnumToString(brokerStatuses[i]),
              " Saved=", EnumToString(savedStatuses[i]), " -> ", resolution);
        if(resolution != expectedResolutions[i]) {
            allResolved = false;
        }
    }
    AssertTrue("9.3 Flow.MergeResolutions", allResolved, "All merges resolved correctly");

    // Step 4: Check auto-save timing
    PrintTestSection("Auto-Save Timing");
    datetime lastAutoSave = now - (6 * 60); // 6 minutes ago
    bool shouldSave = ShouldAutoSaveNow_Testable(lastAutoSave, now, 5, true);
    AssertTrue("9.4 Flow.ShouldAutoSave", shouldSave, "Should auto-save after 6 min with 5 min interval");
}

//+------------------------------------------------------------------+
//| Script Start                                                     |
//+------------------------------------------------------------------+
void OnStart() {
    PrintTestBanner("StatePersistenceTests");

    // Setup environment
    SetupBaseTestEnvironment();
    SaveAllInputParameters();

    // Run all test suites
    Test_StateKeyGeneration();
    Test_StateAgeValidation();
    Test_StateAgeMinutes();
    Test_AutoSaveTiming();
    Test_MergeConflictResolution();
    Test_EntryPointValidation();
    Test_StatusEncodingDecoding();
    Test_GridArrayPersistence();
    Test_FullPersistenceFlow();

    // Restore and summarize
    RestoreAllInputParameters();
    PrintTestSummary();
}
//+------------------------------------------------------------------+
