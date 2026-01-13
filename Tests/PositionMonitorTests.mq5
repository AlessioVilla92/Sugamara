//+------------------------------------------------------------------+
//|                                         PositionMonitorTests.mq5 |
//|                        Sugamara - Position Monitor Unit Tests    |
//|                                                                  |
//|  Tests for exposure calculation, profit tracking, statistics     |
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
//| TESTABLE VERSIONS                                                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Testable: Calculate Net Exposure                                 |
//+------------------------------------------------------------------+
double CalculateNetExposure_Testable(double longLots, double shortLots) {
    return longLots - shortLots;
}

//+------------------------------------------------------------------+
//| Testable: Is Exposure Neutral                                    |
//+------------------------------------------------------------------+
bool IsExposureNeutral_Testable(double netExposure, double maxAllowed) {
    return (MathAbs(netExposure) <= maxAllowed);
}

//+------------------------------------------------------------------+
//| Testable: Get Exposure Direction                                 |
//+------------------------------------------------------------------+
string GetExposureDirection_Testable(double netExposure) {
    if(netExposure > 0.001) return "LONG";
    if(netExposure < -0.001) return "SHORT";
    return "NEUTRAL";
}

//+------------------------------------------------------------------+
//| Testable: Update Session Statistics                              |
//+------------------------------------------------------------------+
struct SessionStats {
    double realizedProfit;
    double peakProfit;
    double grossProfit;
    double grossLoss;
    int wins;
    int losses;
    int totalTrades;
};

void UpdateSessionStats_Testable(SessionStats &stats, double profit) {
    stats.realizedProfit += profit;
    stats.totalTrades++;

    if(profit >= 0) {
        stats.wins++;
        stats.grossProfit += profit;
    } else {
        stats.losses++;
        stats.grossLoss += MathAbs(profit);
    }

    if(stats.realizedProfit > stats.peakProfit) {
        stats.peakProfit = stats.realizedProfit;
    }
}

//+------------------------------------------------------------------+
//| Testable: Calculate Win Rate                                     |
//+------------------------------------------------------------------+
double CalculateWinRate_Testable(int wins, int losses) {
    int total = wins + losses;
    if(total == 0) return 0;
    return (double)wins / total * 100.0;
}

//+------------------------------------------------------------------+
//| Testable: Calculate Profit Factor                                |
//+------------------------------------------------------------------+
double CalculateProfitFactor_Testable(double grossProfit, double grossLoss) {
    if(grossLoss == 0) return grossProfit > 0 ? 999.99 : 0;
    return grossProfit / grossLoss;
}

//+------------------------------------------------------------------+
//| Testable: Calculate Session Drawdown                             |
//+------------------------------------------------------------------+
double CalculateSessionDrawdown_Testable(double currentProfit, double peakProfit) {
    if(peakProfit <= 0) return 0;
    if(currentProfit >= peakProfit) return 0;
    return ((peakProfit - currentProfit) / peakProfit) * 100.0;
}

//+------------------------------------------------------------------+
//| Testable: Is Sugamara Magic                                      |
//+------------------------------------------------------------------+
bool IsSugamaraMagic_Test(long magic, int baseMagic) {
    if(magic >= baseMagic && magic < baseMagic + 1000) return true;
    if(magic >= baseMagic + 10000 && magic < baseMagic + 11000) return true;
    return false;
}

//+------------------------------------------------------------------+
//| TEST SUITE 1: Net Exposure Calculation                           |
//+------------------------------------------------------------------+
void Test_NetExposureCalculation() {
    PrintTestHeader("TEST SUITE 1: Net Exposure Calculation");

    // Test 1.1: Equal exposure (neutral)
    PrintTestSection("Equal Exposure");
    double netExp = CalculateNetExposure_Testable(1.0, 1.0);
    AssertEquals("1.1 NetExposure.Equal", netExp, 0.0, 0.001);

    // Test 1.2: More long than short
    PrintTestSection("Long Biased");
    netExp = CalculateNetExposure_Testable(1.5, 1.0);
    AssertEquals("1.2 NetExposure.LongBiased", netExp, 0.5, 0.001);

    // Test 1.3: More short than long
    PrintTestSection("Short Biased");
    netExp = CalculateNetExposure_Testable(1.0, 1.5);
    AssertEquals("1.3 NetExposure.ShortBiased", netExp, -0.5, 0.001);

    // Test 1.4: Only long
    PrintTestSection("Only Long");
    netExp = CalculateNetExposure_Testable(2.0, 0);
    AssertEquals("1.4 NetExposure.OnlyLong", netExp, 2.0, 0.001);

    // Test 1.5: Only short
    PrintTestSection("Only Short");
    netExp = CalculateNetExposure_Testable(0, 2.0);
    AssertEquals("1.5 NetExposure.OnlyShort", netExp, -2.0, 0.001);

    // Test 1.6: No positions
    PrintTestSection("No Positions");
    netExp = CalculateNetExposure_Testable(0, 0);
    AssertEquals("1.6 NetExposure.NoPositions", netExp, 0.0, 0.001);
}

//+------------------------------------------------------------------+
//| TEST SUITE 2: Exposure Neutrality Check                          |
//+------------------------------------------------------------------+
void Test_ExposureNeutrality() {
    PrintTestHeader("TEST SUITE 2: Exposure Neutrality Check");

    double maxAllowed = 0.5; // 0.5 lot max net exposure

    // Test 2.1: Exactly neutral
    PrintTestSection("Exactly Neutral");
    AssertTrue("2.1 Neutral.Zero", IsExposureNeutral_Testable(0, maxAllowed), "0 net = neutral");

    // Test 2.2: Within tolerance
    PrintTestSection("Within Tolerance");
    AssertTrue("2.2a Neutral.WithinPos", IsExposureNeutral_Testable(0.3, maxAllowed), "0.3 = neutral");
    AssertTrue("2.2b Neutral.WithinNeg", IsExposureNeutral_Testable(-0.3, maxAllowed), "-0.3 = neutral");
    AssertTrue("2.2c Neutral.AtLimit", IsExposureNeutral_Testable(0.5, maxAllowed), "0.5 = neutral");
    AssertTrue("2.2d Neutral.AtLimitNeg", IsExposureNeutral_Testable(-0.5, maxAllowed), "-0.5 = neutral");

    // Test 2.3: Outside tolerance
    PrintTestSection("Outside Tolerance");
    AssertFalse("2.3a Neutral.OutsidePos", IsExposureNeutral_Testable(0.6, maxAllowed), "0.6 = imbalanced");
    AssertFalse("2.3b Neutral.OutsideNeg", IsExposureNeutral_Testable(-0.6, maxAllowed), "-0.6 = imbalanced");
    AssertFalse("2.3c Neutral.WayOutside", IsExposureNeutral_Testable(2.0, maxAllowed), "2.0 = imbalanced");
}

//+------------------------------------------------------------------+
//| TEST SUITE 3: Exposure Direction                                 |
//+------------------------------------------------------------------+
void Test_ExposureDirection() {
    PrintTestHeader("TEST SUITE 3: Exposure Direction");

    // Test 3.1: Neutral
    PrintTestSection("Neutral Direction");
    AssertEqualsString("3.1a Direction.Zero", GetExposureDirection_Testable(0), "NEUTRAL");
    AssertEqualsString("3.1b Direction.SmallPos", GetExposureDirection_Testable(0.0005), "NEUTRAL");
    AssertEqualsString("3.1c Direction.SmallNeg", GetExposureDirection_Testable(-0.0005), "NEUTRAL");

    // Test 3.2: Long
    PrintTestSection("Long Direction");
    AssertEqualsString("3.2a Direction.Long", GetExposureDirection_Testable(0.5), "LONG");
    AssertEqualsString("3.2b Direction.LongSmall", GetExposureDirection_Testable(0.002), "LONG");

    // Test 3.3: Short
    PrintTestSection("Short Direction");
    AssertEqualsString("3.3a Direction.Short", GetExposureDirection_Testable(-0.5), "SHORT");
    AssertEqualsString("3.3b Direction.ShortSmall", GetExposureDirection_Testable(-0.002), "SHORT");
}

//+------------------------------------------------------------------+
//| TEST SUITE 4: Session Statistics Update                          |
//+------------------------------------------------------------------+
void Test_SessionStatisticsUpdate() {
    PrintTestHeader("TEST SUITE 4: Session Statistics Update");

    SessionStats stats;
    ZeroMemory(stats);

    // Test 4.1: First winning trade
    PrintTestSection("First Win");
    UpdateSessionStats_Testable(stats, 50.0);
    AssertEquals("4.1a Stats.RealizedProfit", stats.realizedProfit, 50.0, 0.01);
    AssertEqualsInt("4.1b Stats.Wins", stats.wins, 1);
    AssertEqualsInt("4.1c Stats.Losses", stats.losses, 0);
    AssertEqualsInt("4.1d Stats.TotalTrades", stats.totalTrades, 1);
    AssertEquals("4.1e Stats.GrossProfit", stats.grossProfit, 50.0, 0.01);
    AssertEquals("4.1f Stats.PeakProfit", stats.peakProfit, 50.0, 0.01);

    // Test 4.2: Second winning trade
    PrintTestSection("Second Win");
    UpdateSessionStats_Testable(stats, 30.0);
    AssertEquals("4.2a Stats.RealizedProfit", stats.realizedProfit, 80.0, 0.01);
    AssertEqualsInt("4.2b Stats.Wins", stats.wins, 2);
    AssertEquals("4.2c Stats.PeakProfit", stats.peakProfit, 80.0, 0.01);

    // Test 4.3: Losing trade
    PrintTestSection("First Loss");
    UpdateSessionStats_Testable(stats, -20.0);
    AssertEquals("4.3a Stats.RealizedProfit", stats.realizedProfit, 60.0, 0.01);
    AssertEqualsInt("4.3b Stats.Losses", stats.losses, 1);
    AssertEquals("4.3c Stats.GrossLoss", stats.grossLoss, 20.0, 0.01);
    AssertEquals("4.3d Stats.PeakProfit", stats.peakProfit, 80.0, 0.01); // Peak unchanged

    // Test 4.4: Zero profit trade (counted as win)
    PrintTestSection("Breakeven Trade");
    UpdateSessionStats_Testable(stats, 0);
    AssertEqualsInt("4.4a Stats.Wins", stats.wins, 3);
    AssertEqualsInt("4.4b Stats.TotalTrades", stats.totalTrades, 4);

    // Test 4.5: New peak
    PrintTestSection("New Peak");
    UpdateSessionStats_Testable(stats, 50.0);
    AssertEquals("4.5 Stats.NewPeak", stats.peakProfit, 110.0, 0.01);
}

//+------------------------------------------------------------------+
//| TEST SUITE 5: Win Rate Calculation                               |
//+------------------------------------------------------------------+
void Test_WinRateCalculation() {
    PrintTestHeader("TEST SUITE 5: Win Rate Calculation");

    // Test 5.1: 100% win rate
    PrintTestSection("100% Win Rate");
    AssertEquals("5.1 WinRate.100", CalculateWinRate_Testable(10, 0), 100.0, 0.01);

    // Test 5.2: 0% win rate
    PrintTestSection("0% Win Rate");
    AssertEquals("5.2 WinRate.0", CalculateWinRate_Testable(0, 10), 0.0, 0.01);

    // Test 5.3: 50% win rate
    PrintTestSection("50% Win Rate");
    AssertEquals("5.3 WinRate.50", CalculateWinRate_Testable(5, 5), 50.0, 0.01);

    // Test 5.4: Various rates
    PrintTestSection("Various Rates");
    AssertEquals("5.4a WinRate.75", CalculateWinRate_Testable(3, 1), 75.0, 0.01);
    AssertEquals("5.4b WinRate.33", CalculateWinRate_Testable(1, 2), 33.33, 0.1);
    AssertEquals("5.4c WinRate.66", CalculateWinRate_Testable(2, 1), 66.67, 0.1);

    // Test 5.5: No trades
    PrintTestSection("No Trades");
    AssertEquals("5.5 WinRate.NoTrades", CalculateWinRate_Testable(0, 0), 0.0, 0.01);
}

//+------------------------------------------------------------------+
//| TEST SUITE 6: Profit Factor Calculation                          |
//+------------------------------------------------------------------+
void Test_ProfitFactorCalculation() {
    PrintTestHeader("TEST SUITE 6: Profit Factor Calculation");

    // Test 6.1: No losses (infinite PF)
    PrintTestSection("No Losses");
    double pf = CalculateProfitFactor_Testable(100.0, 0);
    AssertEquals("6.1 PF.NoLosses", pf, 999.99, 0.01);

    // Test 6.2: No profits
    PrintTestSection("No Profits");
    pf = CalculateProfitFactor_Testable(0, 100.0);
    AssertEquals("6.2 PF.NoProfits", pf, 0.0, 0.01);

    // Test 6.3: Profit = Loss (PF = 1)
    PrintTestSection("Breakeven");
    pf = CalculateProfitFactor_Testable(100.0, 100.0);
    AssertEquals("6.3 PF.Breakeven", pf, 1.0, 0.01);

    // Test 6.4: Profitable (PF > 1)
    PrintTestSection("Profitable");
    pf = CalculateProfitFactor_Testable(200.0, 100.0);
    AssertEquals("6.4 PF.Profitable", pf, 2.0, 0.01);

    // Test 6.5: Unprofitable (PF < 1)
    PrintTestSection("Unprofitable");
    pf = CalculateProfitFactor_Testable(100.0, 200.0);
    AssertEquals("6.5 PF.Unprofitable", pf, 0.5, 0.01);

    // Test 6.6: Both zero
    PrintTestSection("Both Zero");
    pf = CalculateProfitFactor_Testable(0, 0);
    AssertEquals("6.6 PF.BothZero", pf, 0.0, 0.01);
}

//+------------------------------------------------------------------+
//| TEST SUITE 7: Session Drawdown Calculation                       |
//+------------------------------------------------------------------+
void Test_SessionDrawdownCalculation() {
    PrintTestHeader("TEST SUITE 7: Session Drawdown Calculation");

    // Test 7.1: At peak (no drawdown)
    PrintTestSection("At Peak");
    double dd = CalculateSessionDrawdown_Testable(100.0, 100.0);
    AssertEquals("7.1 SessionDD.AtPeak", dd, 0.0, 0.01);

    // Test 7.2: Above peak (no drawdown)
    PrintTestSection("Above Peak");
    dd = CalculateSessionDrawdown_Testable(120.0, 100.0);
    AssertEquals("7.2 SessionDD.AbovePeak", dd, 0.0, 0.01);

    // Test 7.3: 10% drawdown
    PrintTestSection("10% Drawdown");
    dd = CalculateSessionDrawdown_Testable(90.0, 100.0);
    AssertEquals("7.3 SessionDD.10Percent", dd, 10.0, 0.01);

    // Test 7.4: 50% drawdown
    PrintTestSection("50% Drawdown");
    dd = CalculateSessionDrawdown_Testable(50.0, 100.0);
    AssertEquals("7.4 SessionDD.50Percent", dd, 50.0, 0.01);

    // Test 7.5: No peak yet
    PrintTestSection("No Peak");
    dd = CalculateSessionDrawdown_Testable(50.0, 0);
    AssertEquals("7.5 SessionDD.NoPeak", dd, 0.0, 0.01);

    // Test 7.6: Negative profit (loss from start)
    PrintTestSection("Negative Profit");
    dd = CalculateSessionDrawdown_Testable(-20.0, 50.0);
    // DD = (50 - (-20)) / 50 * 100 = 140%
    AssertGreaterThan("7.6 SessionDD.Negative", dd, 100.0, "Can exceed 100%");
}

//+------------------------------------------------------------------+
//| TEST SUITE 8: Magic Number Filtering                             |
//+------------------------------------------------------------------+
void Test_MagicNumberFiltering() {
    PrintTestHeader("TEST SUITE 8: Magic Number Filtering");

    int baseMagic = 123456;

    // Test 8.1: Grid A range
    PrintTestSection("Grid A Range");
    AssertTrue("8.1a MagicFilter.GridA.Min", IsSugamaraMagic_Test(123456, baseMagic), "Base is valid");
    AssertTrue("8.1b MagicFilter.GridA.Mid", IsSugamaraMagic_Test(123800, baseMagic), "Mid is valid");
    AssertTrue("8.1c MagicFilter.GridA.Max", IsSugamaraMagic_Test(124455, baseMagic), "Max is valid");
    AssertFalse("8.1d MagicFilter.GridA.Over", IsSugamaraMagic_Test(124456, baseMagic), "Over is invalid");

    // Test 8.2: Grid B range
    PrintTestSection("Grid B Range");
    AssertTrue("8.2a MagicFilter.GridB.Min", IsSugamaraMagic_Test(133456, baseMagic), "Min is valid");
    AssertTrue("8.2b MagicFilter.GridB.Mid", IsSugamaraMagic_Test(133800, baseMagic), "Mid is valid");
    AssertTrue("8.2c MagicFilter.GridB.Max", IsSugamaraMagic_Test(134455, baseMagic), "Max is valid");
    AssertFalse("8.2d MagicFilter.GridB.Over", IsSugamaraMagic_Test(134456, baseMagic), "Over is invalid");

    // Test 8.3: Gap between grids
    PrintTestSection("Gap Between Grids");
    AssertFalse("8.3a MagicFilter.Gap.Start", IsSugamaraMagic_Test(124500, baseMagic), "Gap start invalid");
    AssertFalse("8.3b MagicFilter.Gap.Mid", IsSugamaraMagic_Test(130000, baseMagic), "Gap mid invalid");
    AssertFalse("8.3c MagicFilter.Gap.End", IsSugamaraMagic_Test(133455, baseMagic), "Gap end invalid");

    // Test 8.4: Other EAs
    PrintTestSection("Other EAs");
    AssertFalse("8.4a MagicFilter.OtherEA.Low", IsSugamaraMagic_Test(100000, baseMagic), "Other EA low");
    AssertFalse("8.4b MagicFilter.OtherEA.High", IsSugamaraMagic_Test(200000, baseMagic), "Other EA high");
}

//+------------------------------------------------------------------+
//| TEST SUITE 9: Integration - Full Position Flow                   |
//+------------------------------------------------------------------+
void Test_FullPositionFlow() {
    PrintTestHeader("TEST SUITE 9: Full Position Flow Integration");

    // Simulate a trading session
    SessionStats stats;
    ZeroMemory(stats);

    double longLots = 0;
    double shortLots = 0;
    double maxAllowed = 0.5;

    // Simulate trades
    PrintTestSection("Trading Session Simulation");

    // Trade 1: Open BUY 0.1
    longLots += 0.1;
    double netExp = CalculateNetExposure_Testable(longLots, shortLots);
    Print("  Open BUY 0.1 -> Net: ", DoubleToString(netExp, 2), " lot");
    AssertTrue("9.1 Flow.BuyOpen.Neutral", IsExposureNeutral_Testable(netExp, maxAllowed), "Still neutral");

    // Trade 2: Open SELL 0.1 (hedge)
    shortLots += 0.1;
    netExp = CalculateNetExposure_Testable(longLots, shortLots);
    Print("  Open SELL 0.1 -> Net: ", DoubleToString(netExp, 2), " lot");
    AssertEquals("9.2 Flow.Hedged", netExp, 0.0, 0.001);

    // Trade 3: Close BUY with profit
    UpdateSessionStats_Testable(stats, 25.0);
    longLots -= 0.1;
    netExp = CalculateNetExposure_Testable(longLots, shortLots);
    Print("  Close BUY +$25 -> Net: ", DoubleToString(netExp, 2), " lot");
    AssertEqualsString("9.3 Flow.ShortExposure", GetExposureDirection_Testable(netExp), "SHORT");

    // Trade 4: Open BUY to rebalance
    longLots += 0.1;
    netExp = CalculateNetExposure_Testable(longLots, shortLots);
    Print("  Open BUY 0.1 -> Net: ", DoubleToString(netExp, 2), " lot");
    AssertEqualsString("9.4 Flow.Rebalanced", GetExposureDirection_Testable(netExp), "NEUTRAL");

    // Trade 5: Close SELL with loss
    UpdateSessionStats_Testable(stats, -10.0);
    shortLots -= 0.1;

    // Final stats check
    PrintTestSection("Final Statistics");
    double winRate = CalculateWinRate_Testable(stats.wins, stats.losses);
    double pf = CalculateProfitFactor_Testable(stats.grossProfit, stats.grossLoss);

    Print("  Realized: $", DoubleToString(stats.realizedProfit, 2));
    Print("  Win Rate: ", DoubleToString(winRate, 1), "%");
    Print("  Profit Factor: ", DoubleToString(pf, 2));

    AssertEquals("9.5a Flow.FinalProfit", stats.realizedProfit, 15.0, 0.01);
    AssertEquals("9.5b Flow.WinRate", winRate, 50.0, 0.1);
    AssertEquals("9.5c Flow.ProfitFactor", pf, 2.5, 0.01);
}

//+------------------------------------------------------------------+
//| Script Start                                                     |
//+------------------------------------------------------------------+
void OnStart() {
    PrintTestBanner("PositionMonitorTests");

    // Setup environment
    SetupBaseTestEnvironment();
    SaveAllInputParameters();

    // Run all test suites
    Test_NetExposureCalculation();
    Test_ExposureNeutrality();
    Test_ExposureDirection();
    Test_SessionStatisticsUpdate();
    Test_WinRateCalculation();
    Test_ProfitFactorCalculation();
    Test_SessionDrawdownCalculation();
    Test_MagicNumberFiltering();
    Test_FullPositionFlow();

    // Restore and summarize
    RestoreAllInputParameters();
    PrintTestSummary();
}
//+------------------------------------------------------------------+
