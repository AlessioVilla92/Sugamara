//+------------------------------------------------------------------+
//|                                          InputParameters.mqh     |
//|                        Sugamara - Input Parameters               |
//|                                                                  |
//|  User-configurable parameters for Double Grid Neutral            |
//|  v2.0 MULTIMODE - PURE / CASCADE / RANGEBOX                      |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| 1️⃣ ⚙️ SYSTEM CONFIGURATION                                      |
//+------------------------------------------------------------------+

input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  1️⃣  ⚙️ SYSTEM CONFIGURATION                              ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🔧 CORE SETTINGS"
input int       MagicNumber = 20251205;                      // 🆔 Magic Number (Unique EA ID)
input bool      EnableSystem = true;                         // ✅ Enable System
input bool      DetailedLogging = true;                      // 📝 Detailed Logging
input bool      EnableAlerts = true;                         // 🔔 Enable Alerts

input group "    🚨 EMERGENCY PROTECTION"
input bool      EnableEmergencyStop = true;                  // ✅ Enable Emergency Stop
input double    EmergencyStop_Percent = 12.0;                // 📉 Emergency Stop DD (%)

//+------------------------------------------------------------------+
//| 2️⃣ ⭐ MODALITÀ GRIDBOT ⭐                                        |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  2️⃣  ⭐ MODALITÀ GRIDBOT                                  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ╔═ SELEZIONA MODALITÀ ════════════════════════════════════🔽🔽🔽"
input ENUM_NEUTRAL_MODE NeutralMode = NEUTRAL_CASCADE;       // 📊 Modalità GridBot ▼
// NEUTRAL_PURE     = Spacing fisso, TP fisso, NO ATR (learning)
// NEUTRAL_CASCADE  = TP=Entry precedente, ATR opzionale (CONSIGLIATO)
// NEUTRAL_RANGEBOX = Range Box + Hedge, ATR opzionale (produzione)

//+------------------------------------------------------------------+
//| 3️⃣ 📊 ATR SETTINGS                                               |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  3️⃣  📊 ATR SETTINGS (CASCADE/RANGEBOX)                   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⚡ ATR ACTIVATION"
input bool      UseATR = true;                               // ⭐ Abilita ATR (ignora se PURE)

input group "    ⏱️ TIMEFRAME SETTINGS"
input group "    ╔═ SELEZIONA TIMEFRAME ATR ═══════════════════════════════🔽🔽🔽"
input ENUM_TIMEFRAMES ATR_Timeframe = PERIOD_M5;             // 📊 ATR Timeframe ▼
input int       ATR_Period = 14;                             // 📈 ATR Period (bars)
input int       ATR_RecalcHours = 4;                         // 🔄 Ore tra Ricalcoli ATR

input group "    🎯 ATR DECISION TABLE (Spacing Adattivo)"
input double    ATR_Calm_Threshold = 15.0;                   // 📊 Soglia ATR Calmo (pips)
input double    ATR_Calm_Spacing = 15.0;                     // 📏 Spacing se ATR < 15
input double    ATR_Normal_Threshold = 30.0;                 // 📊 Soglia ATR Normale (pips)
input double    ATR_Normal_Spacing = 20.0;                   // 📏 Spacing se ATR 15-30
input double    ATR_Volatile_Threshold = 50.0;               // 📊 Soglia ATR Volatile (pips)
input double    ATR_Volatile_Spacing = 30.0;                 // 📏 Spacing se ATR 30-50
input double    ATR_Extreme_Spacing = 40.0;                  // 📏 Spacing se ATR > 50

//+------------------------------------------------------------------+
//| 4️⃣ 🎰 FOREX PAIR SELECTION                                       |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  4️⃣  🎰 FOREX PAIR SELECTION                              ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ╔═ SELEZIONA COPPIA ══════════════════════════════════════🔽🔽🔽"
input ENUM_FOREX_PAIR SelectedPair = PAIR_EURUSD;            // 📋 Select Forex Pair ▼
// EUR/USD: Spread basso, range medio, ideale per iniziare
// USD/CAD: Spread basso, range contenuto, ottimo per grid neutral
// AUD/NZD: Range strettissimo, win rate altissimo, BEST per neutral

//+------------------------------------------------------------------+
//| 5️⃣ 📐 GRID CONFIGURATION                                         |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  5️⃣  📐 GRID CONFIGURATION                                ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📏 GRID STRUCTURE"
input int       GridLevelsPerSide = 5;                       // 🔢 Livelli per Lato (3-10)
// 5 livelli × 2 zone × 2 grid = 20 ordini totali

input group "    ╔═ SELEZIONA SPACING MODE ════════════════════════════════🔽🔽🔽"
input ENUM_SPACING_MODE SpacingMode = SPACING_ATR;           // 📏 Modalità Spacing ▼
input double    Fixed_Spacing_Pips = 20.0;                   // 📐 Spacing Fisso (pips)
input double    SpacingATR_Multiplier = 0.7;                 // 📈 Moltiplicatore ATR (se SPACING_ATR)
// Spacing = ATR(14) × 0.7
input double    SpacingGeometric_Percent = 0.20;             // 📊 Spacing % (se SPACING_GEOMETRIC)
// Spacing = Prezzo × 0.20%

//+------------------------------------------------------------------+
//| 6️⃣ 🎯 TP SETTINGS (Solo PURE)                                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  6️⃣  🎯 TP SETTINGS (Solo PURE Mode)                      ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📍 TAKE PROFIT PURE MODE"
input double    TP_Ratio_Pure = 1.2;                         // 🎯 Ratio TP per PURE (1.0-2.0)
// TP = Spacing × Ratio | 1.2 = TP 20% maggiore di spacing

//+------------------------------------------------------------------+
//| 7️⃣ 📦 RANGEBOX SETTINGS (Solo RANGEBOX)                          |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  7️⃣  📦 RANGEBOX SETTINGS (Solo RANGEBOX Mode)            ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ╔═ SELEZIONA RANGEBOX MODE ═══════════════════════════════🔽🔽🔽"
input ENUM_RANGEBOX_MODE RangeBoxMode = RANGEBOX_DAILY_HL;   // 📊 Modalità Range Box ▼

input group "    📐 RANGEBOX LEVELS"
input double    RangeBox_Resistance = 0.0;                   // 🔺 Resistance manuale (0=auto)
input double    RangeBox_Support = 0.0;                      // 🔻 Support manuale (0=auto)
input double    RangeBox_Buffer_Pips = 10.0;                 // 📏 Buffer per breakout (pips)
input int       RangeBox_PeriodBars = 20;                    // 📅 Periodo calcolo auto (barre D1)
input double    RangeBox_ATR_Mult = 3.0;                     // 📈 Moltiplicatore ATR per range

//+------------------------------------------------------------------+
//| 8️⃣ 🛡️ SHIELD INTELLIGENTE (Solo RANGEBOX)                        |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  8️⃣  🛡️ SHIELD INTELLIGENTE (Solo RANGEBOX Mode)          ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ╔═ SELEZIONA SHIELD MODE ═══════════════════════════════🔽🔽🔽"
input ENUM_SHIELD_MODE ShieldMode = SHIELD_3_PHASES;         // 🛡️ Modalita Shield ▼
// SHIELD_DISABLED  = Nessuna protezione
// SHIELD_SIMPLE    = Attivazione diretta su breakout
// SHIELD_3_PHASES  = Warning -> Pre-Shield -> Active (CONSIGLIATO)

input group "    📐 SHIELD BREAKOUT PARAMETERS"
input double    Breakout_Buffer_Pips = 20.0;                 // 📏 Buffer Breakout oltre ultimo grid (pips)
input double    Reentry_Buffer_Pips = 30.0;                  // 📏 Buffer Rientro nel range (pips)
input int       Breakout_Confirm_Candles = 2;                // 🔢 Candele Conferma Breakout
input bool      Use_Candle_Close = true;                     // ✅ Usa Chiusura Candela per Conferma

input group "    ⚠️ SHIELD 3 FASI PARAMETERS"
input double    Warning_Zone_Percent = 10.0;                 // 📊 Warning Zone (% dal bordo)
input bool      Shield_Use_Trailing = false;                 // ✅ Trailing per Shield
input double    Shield_Trailing_Start = 30.0;                // 📏 Trailing Start (pips)
input double    Shield_Trailing_Step = 10.0;                 // 📏 Trailing Step (pips)

input group "    🔧 LEGACY HEDGE (Backward Compatibility)"
input bool      EnableHedging = true;                        // ✅ Abilita hedging (maps to Shield)
input double    Hedge_Multiplier = 1.0;                      // 📈 Moltiplicatore (legacy, ignored)
input double    Hedge_TP_Pips = 20.0;                        // 🎯 TP hedge (legacy, ignored)
input double    Hedge_SL_Pips = 10.0;                        // 🛑 SL hedge (legacy, ignored)

//+------------------------------------------------------------------+
//| 9️⃣ 💰 LOT SIZING                                                 |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  9️⃣  💰 LOT SIZING ⚠️ [CRITICAL SECTION]                  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ╔═ SELEZIONA LOT MODE ════════════════════════════════════🔽🔽🔽"
input ENUM_LOT_MODE LotMode = LOT_PROGRESSIVE;               // 💵 Lot Calculation Mode ▼

input group "    📊 LOT PARAMETERS"
input double    BaseLot = 0.02;                              // 💵 Lot Base (livello 1)
input double    LotMultiplier = 1.15;                        // 📈 Moltiplicatore Progressivo
// Level 1: 0.02, Level 2: 0.023, Level 3: 0.026, Level 4: 0.03, Level 5: 0.035
input double    MaxLotPerLevel = 0.12;                       // 🔒 Max Lot per Livello
input double    MaxTotalLot = 0.60;                          // 🔒 Max Lot Totale (tutti gli ordini)

//+------------------------------------------------------------------+
//| 🔟 🎯 PERFECT CASCADE SYSTEM                                      |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔟  🎯 PERFECT CASCADE SYSTEM                             ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ╔═ SELEZIONA CASCADE MODE ════════════════════════════════🔽🔽🔽"
input ENUM_CASCADE_MODE CascadeMode = CASCADE_PERFECT;       // 📊 Modalità Cascade ▼
// CASCADE_PERFECT: TP di ogni ordine = Entry del livello successivo
// Crea una catena perfetta senza gap

input group "    📐 CASCADE PARAMETERS"
input double    CascadeTP_Ratio = 1.0;                       // 📈 Ratio TP (se CASCADE_RATIO)
// TP = Spacing × Ratio (1.0 = uguale a spacing, 1.2 = 20% in più)
input double    FinalLevel_TP_Pips = 15.0;                   // 🎯 TP Ultimo Livello (pips)
// L'ultimo livello non ha "successivo", usa TP fisso

//+------------------------------------------------------------------+
//| 1️⃣1️⃣ 🔄 CYCLIC REOPENING                                         |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  1️⃣1️⃣  🔄 CYCLIC REOPENING                                ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ♻️ CYCLIC ACTIVATION"
input bool      EnableCyclicReopen = true;                   // ✅ Abilita Cyclic Reopen

input group "    ╔═ SELEZIONA TRIGGER MODE ════════════════════════════════🔽🔽🔽"
input ENUM_REOPEN_TRIGGER ReopenTrigger = REOPEN_PRICE_LEVEL;// 📊 Trigger Reopen ▼

input group "    📐 CYCLIC PARAMETERS"
input int       CyclicCooldown_Seconds = 120;                // ⏱️ Cooldown tra Cicli (sec)
input int       MaxCyclesPerLevel = 0;                       // 🔢 Max Cicli per Livello (0=infiniti)
input double    ReopenOffset_Pips = 5.0;                     // 📏 Offset Reopen (pips)
// Riapre ordine quando prezzo torna al livello ± offset

//+------------------------------------------------------------------+
//| 1️⃣2️⃣ 🚨 RISK MANAGEMENT                                          |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  1️⃣2️⃣  🚨 RISK MANAGEMENT                                 ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🎯 DAILY TARGETS"
input bool      EnableDailyTarget = false;                   // ✅ Abilita Target Giornaliero
input double    DailyProfitTarget_USD = 100.0;               // 💵 Profit Target ($)
input double    DailyLossLimit_USD = 50.0;                   // 📉 Loss Limit ($)

input group "    ⚠️ VOLATILITY PAUSE"
input bool      PauseOnHighATR = true;                       // ✅ Pausa se ATR Alto
input double    HighATR_Threshold = 50.0;                    // 📊 Soglia ATR Pausa (pips)
// Non piazza nuovi ordini se ATR > 50 pips

input bool      PauseOnNews = false;                         // ✅ Pausa durante News (manuale)
// Richiede attivazione manuale 30 min prima di news

//+------------------------------------------------------------------+
//| 1️⃣3️⃣ 🛑 STOP LOSS CONFIGURATION                                  |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  1️⃣3️⃣  🛑 STOP LOSS CONFIGURATION                         ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🌐 GLOBAL STOP LOSS"
input bool      UseGlobalStopLoss = true;                    // ✅ Usa SL Globale
input double    GlobalSL_Percent = 120.0;                    // 📊 SL Globale (% del range)
// SL = Entry ± (Range × 120%) = 20% oltre il range

input group "    📍 INDIVIDUAL STOP LOSS"
input bool      UseIndividualSL = false;                     // ✅ Usa SL Individuale
input double    IndividualSL_Pips = 50.0;                    // 📏 SL per Ordine (pips)

//+------------------------------------------------------------------+
//| 1️⃣4️⃣ 🔧 BROKER SETTINGS                                          |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  1️⃣4️⃣  🔧 BROKER SETTINGS                                 ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⚡ ORDER EXECUTION"
input int       Slippage = 30;                               // 📊 Slippage Max (points)
input int       MaxRetries = 3;                              // 🔄 Max Tentativi per Ordine
input int       RetryDelay_ms = 500;                         // ⏱️ Delay tra Tentativi (ms)

//+------------------------------------------------------------------+
//| 1️⃣5️⃣ 🎨 DASHBOARD SETTINGS                                       |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  1️⃣5️⃣  🎨 DASHBOARD SETTINGS                              ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📊 DASHBOARD DISPLAY"
input bool      ShowDashboard = true;                        // ✅ Mostra Dashboard
input int       Dashboard_X = 20;                            // 📍 Posizione X Dashboard
input int       Dashboard_Y = 30;                            // 📍 Posizione Y Dashboard
input bool      ShowGridLines = true;                        // ✅ Mostra Linee Grid su Chart
input bool      ShowRangeBox = true;                         // ✅ Mostra Box Range (solo RANGEBOX)

//+------------------------------------------------------------------+
//| 1️⃣6️⃣ 📊 VOLATILITY MONITOR                                       |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  1️⃣6️⃣  📊 VOLATILITY MONITOR                              ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool      EnableVolatilityMonitor = true;              // ✅ Enable Volatility Monitor

input group "    ⏱️ DUAL TIMEFRAME SETTINGS"
input group "    ╔═ SELEZIONA TIMEFRAME ═══════════════════════════════════🔽🔽🔽"
input ENUM_TIMEFRAMES Vol_TF_Immediate = PERIOD_M5;          // 🔴 Immediate TF ▼
input ENUM_TIMEFRAMES Vol_TF_Context = PERIOD_CURRENT;       // 🔵 Context TF ▼
input int       Vol_ATR_Period = 14;                         // 📈 ATR Period (bars)

input group "    🎯 RATING THRESHOLDS (1-9 Scale)"
input double    Volatility_Rating1 = 0.10;                   // 📊 Rating 1→2 threshold (%)
input double    Volatility_Rating2 = 0.20;                   // 📊 Rating 2→3 threshold (%)
input double    Volatility_Rating3 = 0.35;                   // 📊 Rating 3→4 threshold (%)
input double    Volatility_Rating4 = 0.50;                   // 📊 Rating 4→5 threshold (%)
input double    Volatility_Rating5 = 0.70;                   // 📊 Rating 5→6 threshold (%)
input double    Volatility_Rating6 = 1.00;                   // 📊 Rating 6→7 threshold (%)
input double    Volatility_Rating7 = 1.40;                   // 📊 Rating 7→8 threshold (%)
input double    Volatility_Rating8 = 2.00;                   // 📊 Rating 8→9 threshold (%)

//+------------------------------------------------------------------+
//| 1️⃣7️⃣ 📈 ADX TREND STRENGTH                                       |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  1️⃣7️⃣  📈 ADX TREND STRENGTH MONITOR                      ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool      EnableADXMonitor = true;                     // ✅ Enable ADX Trend Monitor

input group "    ⏱️ DUAL TIMEFRAME SETTINGS ADX"
input group "    ╔═ SELEZIONA TIMEFRAME ADX ═══════════════════════════════🔽🔽🔽"
input ENUM_TIMEFRAMES ADX_TF_Immediate = PERIOD_M15;         // 🔴 Immediate TF ▼
input ENUM_TIMEFRAMES ADX_TF_Context = PERIOD_CURRENT;       // 🔵 Context TF ▼
input int       ADX_Period_Monitor = 14;                     // 📈 ADX Period (bars)

input group "    🎯 RATING THRESHOLDS (1-9 Scale)"
input double    ADX_Rating_1 = 12.0;                         // 📊 Rating 1→2: No Trend
input double    ADX_Rating_2 = 18.0;                         // 📊 Rating 2→3: Very Weak
input double    ADX_Rating_3 = 22.0;                         // 📊 Rating 3→4: Weak
input double    ADX_Rating_4 = 25.0;                         // 📊 Rating 4→5: CRITICAL
input double    ADX_Rating_5 = 30.0;                         // 📊 Rating 5→6: Confirmed
input double    ADX_Rating_6 = 40.0;                         // 📊 Rating 6→7: Strong
input double    ADX_Rating_7 = 50.0;                         // 📊 Rating 7→8: Very Strong
input double    ADX_Rating_8 = 65.0;                         // 📊 Rating 8→9: Extreme

//+------------------------------------------------------------------+
//| 1️⃣8️⃣ ⚙️ ADVANCED SETTINGS                                        |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  1️⃣8️⃣  ⚙️ ADVANCED SETTINGS (Experts Only)                ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🔐 HEDGING & SYNC"
input bool      AllowHedging = true;                         // ✅ Permetti Hedging (required!)
input bool      SyncGridAB = true;                           // ✅ Sincronizza Grid A e B
// Assicura che Grid A e Grid B siano sempre speculari

input group "    ⚖️ NET EXPOSURE"
input double    NetExposure_MaxLot = 0.10;                   // 📊 Max Esposizione Netta (lot)
// Se |LONG - SHORT| > 0.10 lot, sistema in allerta

input group "    🔄 AUTO ADJUST"
input bool      AutoAdjustOnATR = true;                      // ✅ Auto-Adjust su cambio ATR
// Ricalcola grid se ATR cambia significativamente
input double    ATR_ChangeThreshold = 20.0;                  // 📊 Soglia Cambio ATR (%)
// Ricalcola se ATR cambia > 20%

//+------------------------------------------------------------------+
//| 1️⃣9️⃣ 🇪🇺🇺🇸 EUR/USD SOTTOSTANTI                                   |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  1️⃣9️⃣  🇪🇺🇺🇸 SOTTOSTANTI - EUR/USD                        ║"
input group "║      Spread: 0.8-1.5 pips | Range: 60-100 pips/day       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 EUR/USD GRID SETTINGS"
input double    EURUSD_DefaultSpacing = 20.0;                // 📏 Spacing Default (pips)
input double    EURUSD_TP_Pips = 18.0;                       // 🎯 TP per livello (pips)
input double    EURUSD_EstimatedSpread = 1.0;                // 📊 Spread Stimato (pips)
input double    EURUSD_DailyRange = 80.0;                    // 📈 Range Giornaliero (pips)
input double    EURUSD_ATR_Typical = 25.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 2️⃣0️⃣ 🇺🇸🇨🇦 USD/CAD SOTTOSTANTI                                   |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  2️⃣0️⃣  🇺🇸🇨🇦 SOTTOSTANTI - USD/CAD                        ║"
input group "║      Spread: 1.0-1.8 pips | Range: 50-80 pips/day        ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 USD/CAD GRID SETTINGS"
input double    USDCAD_DefaultSpacing = 18.0;                // 📏 Spacing Default (pips)
input double    USDCAD_TP_Pips = 16.0;                       // 🎯 TP per livello (pips)
input double    USDCAD_EstimatedSpread = 1.3;                // 📊 Spread Stimato (pips)
input double    USDCAD_DailyRange = 65.0;                    // 📈 Range Giornaliero (pips)
input double    USDCAD_ATR_Typical = 22.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 2️⃣1️⃣ ⚙️ CUSTOM PAIR SETTINGS                                     |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  2️⃣1️⃣  ⚙️ CUSTOM PAIR SETTINGS (if CUSTOM selected)       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 CUSTOM PAIR PARAMETERS"
input double    Custom_Spread = 1.5;                         // 📊 Spread Stimato (pips)
input double    Custom_DailyRange = 100.0;                   // 📈 Range Giornaliero (pips)
input double    Custom_ATR_Typical = 25.0;                   // 📊 ATR Tipico (pips)
input double    Custom_MinLot = 0.01;                        // 💵 Lot Minimo
input double    Custom_DefaultSpacing = 20.0;                // 📏 Spacing Default (pips)

