//+------------------------------------------------------------------+
//|                                          InputParameters.mqh     |
//|                        Sugamara - Input Parameters               |
//|                                                                  |
//|  User-configurable parameters for Double Grid Neutral            |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| GENERAL SETTINGS                                                 |
//+------------------------------------------------------------------+
input group "══════════════════════════════════════════════════════════════"
input group "║  SUGAMARA v1.0 - DOUBLE GRID NEUTRAL                       ║"
input group "║  Market Neutral • Bidirezionale • Zero Prediction          ║"
input group "══════════════════════════════════════════════════════════════"

input group "    [1] GENERAL SETTINGS"
input int       MagicNumber = 20251201;                      // Magic Number (univoco per EA)
input bool      EnableSystem = true;                         // Abilita Sistema
input bool      DetailedLogging = true;                      // Log Dettagliato
input bool      EnableAlerts = true;                         // Abilita Alert

//+------------------------------------------------------------------+
//| PAIR SELECTION                                                   |
//+------------------------------------------------------------------+
input group "    [2] PAIR SELECTION"
input ENUM_NEUTRAL_PAIR SelectedPair = NEUTRAL_EURUSD;       // Coppia da Tradare
// EUR/USD: Range medio, spread basso, ideale per iniziare
// AUD/NZD: Range stretto, win rate altissimo, ideale per capital preservation

//+------------------------------------------------------------------+
//| GRID CONFIGURATION                                               |
//+------------------------------------------------------------------+
input group "    [3] GRID CONFIGURATION"
input int       GridLevelsPerSide = 5;                       // Livelli per Lato (3-10)
// 5 livelli × 2 zone × 2 grid = 20 ordini totali

input ENUM_SPACING_MODE SpacingMode = SPACING_ATR;           // Modalita Spacing
input double    FixedSpacing_Pips = 20.0;                    // Spacing Fisso (se SPACING_FIXED)
input double    SpacingATR_Multiplier = 0.7;                 // Moltiplicatore ATR (se SPACING_ATR)
// Spacing = ATR(14) × 0.7

input double    SpacingGeometric_Percent = 0.20;             // Spacing % (se SPACING_GEOMETRIC)
// Spacing = Prezzo × 0.20%

//+------------------------------------------------------------------+
//| LOT SIZING                                                       |
//+------------------------------------------------------------------+
input group "    [4] LOT SIZING"
input ENUM_LOT_MODE LotMode = LOT_PROGRESSIVE;               // Modalita Lot Size
input double    BaseLot = 0.02;                              // Lot Base (livello 1)
input double    LotMultiplier = 1.15;                        // Moltiplicatore Progressivo
// Level 1: 0.02, Level 2: 0.023, Level 3: 0.026, Level 4: 0.03, Level 5: 0.035
input double    MaxLotPerLevel = 0.12;                       // Max Lot per Livello
input double    MaxTotalLot = 0.60;                          // Max Lot Totale (tutti gli ordini)

//+------------------------------------------------------------------+
//| PERFECT CASCADE SYSTEM                                           |
//+------------------------------------------------------------------+
input group "    [5] PERFECT CASCADE"
input ENUM_CASCADE_MODE CascadeMode = CASCADE_PERFECT;       // Modalita Cascade
// CASCADE_PERFECT: TP di ogni ordine = Entry del livello successivo
// Crea una catena perfetta senza gap

input double    CascadeTP_Ratio = 1.0;                       // Ratio TP (se CASCADE_RATIO)
// TP = Spacing × Ratio (1.0 = uguale a spacing, 1.2 = 20% in piu)

input double    FinalLevel_TP_Pips = 15.0;                   // TP Ultimo Livello (pips)
// L'ultimo livello non ha "successivo", usa TP fisso

//+------------------------------------------------------------------+
//| ATR ADAPTIVE SPACING                                             |
//+------------------------------------------------------------------+
input group "    [6] ATR ADAPTIVE SPACING"
input int       ATR_Period = 14;                             // Periodo ATR
input ENUM_TIMEFRAMES ATR_Timeframe = PERIOD_M5;             // Timeframe ATR
input int       ATR_RecalcHours = 4;                         // Ore tra Ricalcoli ATR

// Tabella decisionale ATR -> Spacing
input group "    ATR Decision Table"
input double    ATR_Calm_Threshold = 15.0;                   // Soglia ATR Calmo (pips)
input double    ATR_Calm_Spacing = 15.0;                     // Spacing se ATR < 15
input double    ATR_Normal_Threshold = 30.0;                 // Soglia ATR Normale (pips)
input double    ATR_Normal_Spacing = 20.0;                   // Spacing se ATR 15-30
input double    ATR_Volatile_Threshold = 50.0;               // Soglia ATR Volatile (pips)
input double    ATR_Volatile_Spacing = 30.0;                 // Spacing se ATR 30-50
input double    ATR_Extreme_Spacing = 40.0;                  // Spacing se ATR > 50

//+------------------------------------------------------------------+
//| CYCLIC REOPENING                                                 |
//+------------------------------------------------------------------+
input group "    [7] CYCLIC REOPENING"
input bool      EnableCyclicReopen = true;                   // Abilita Cyclic Reopen
input ENUM_REOPEN_TRIGGER ReopenTrigger = REOPEN_PRICE_LEVEL;// Trigger Reopen
input int       CyclicCooldown_Seconds = 120;                // Cooldown tra Cicli (sec)
input int       MaxCyclesPerLevel = 0;                       // Max Cicli per Livello (0=infiniti)
input double    ReopenOffset_Pips = 5.0;                     // Offset Reopen (pips)
// Riapre ordine quando prezzo torna al livello ± offset

//+------------------------------------------------------------------+
//| RISK MANAGEMENT                                                  |
//+------------------------------------------------------------------+
input group "    [8] RISK MANAGEMENT"
input bool      EnableEmergencyStop = true;                  // Abilita Emergency Stop
input double    EmergencyStop_Percent = 12.0;                // Emergency Stop (% equity)
// Chiude tutto se Equity < Balance × (1 - 12%)

input bool      EnableDailyTarget = false;                   // Abilita Target Giornaliero
input double    DailyProfitTarget_USD = 100.0;               // Profit Target ($)
input double    DailyLossLimit_USD = 50.0;                   // Loss Limit ($)

input bool      PauseOnHighATR = true;                       // Pausa se ATR Alto
input double    HighATR_Threshold = 50.0;                    // Soglia ATR Pausa (pips)
// Non piazza nuovi ordini se ATR > 50 pips

input bool      PauseOnNews = false;                         // Pausa durante News (manuale)
// Richiede attivazione manuale 30 min prima di news

//+------------------------------------------------------------------+
//| STOP LOSS CONFIGURATION                                          |
//+------------------------------------------------------------------+
input group "    [9] STOP LOSS"
input bool      UseGlobalStopLoss = true;                    // Usa SL Globale
input double    GlobalSL_Percent = 120.0;                    // SL Globale (% del range)
// SL = Entry ± (Range × 120%) = 20% oltre il range

input bool      UseIndividualSL = false;                     // Usa SL Individuale
input double    IndividualSL_Pips = 50.0;                    // SL per Ordine (pips)

//+------------------------------------------------------------------+
//| BROKER SETTINGS                                                  |
//+------------------------------------------------------------------+
input group "    [10] BROKER SETTINGS"
input int       Slippage = 30;                               // Slippage Max (points)
input int       MaxRetries = 3;                              // Max Tentativi per Ordine
input int       RetryDelay_ms = 500;                         // Delay tra Tentativi (ms)

//+------------------------------------------------------------------+
//| DASHBOARD SETTINGS                                               |
//+------------------------------------------------------------------+
input group "    [11] DASHBOARD"
input bool      ShowDashboard = true;                        // Mostra Dashboard
input int       Dashboard_X = 20;                            // Posizione X Dashboard
input int       Dashboard_Y = 30;                            // Posizione Y Dashboard
input bool      ShowGridLines = true;                        // Mostra Linee Grid su Chart
input bool      ShowRangeBox = true;                         // Mostra Box Range

//+------------------------------------------------------------------+
//| ADVANCED SETTINGS                                                |
//+------------------------------------------------------------------+
input group "    [12] ADVANCED (Experts Only)"
input bool      AllowHedging = true;                         // Permetti Hedging (required!)
input bool      SyncGridAB = true;                           // Sincronizza Grid A e B
// Assicura che Grid A e Grid B siano sempre speculari

input double    NetExposure_MaxLot = 0.10;                   // Max Esposizione Netta (lot)
// Se |LONG - SHORT| > 0.10 lot, sistema in allerta

input bool      AutoAdjustOnATR = true;                      // Auto-Adjust su cambio ATR
// Ricalcola grid se ATR cambia significativamente

input double    ATR_ChangeThreshold = 20.0;                  // Soglia Cambio ATR (%)
// Ricalcola se ATR cambia > 20%

//+------------------------------------------------------------------+
//| MANUAL PAIR SETTINGS (if NEUTRAL_CUSTOM selected)                |
//+------------------------------------------------------------------+
input group "    [13] CUSTOM PAIR SETTINGS"
input double    Custom_Spread = 1.5;                         // Spread Stimato (pips)
input double    Custom_DailyRange = 100.0;                   // Range Giornaliero (pips)
input double    Custom_ATR_Typical = 25.0;                   // ATR Tipico (pips)
input double    Custom_MinLot = 0.01;                        // Lot Minimo

