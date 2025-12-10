//+------------------------------------------------------------------+
//|                                          InputParameters.mqh     |
//|                        Sugamara - Input Parameters               |
//|                                                                  |
//|  User-configurable parameters for Double Grid Neutral            |
//|  v3.0 MULTIMODE - PURE / CASCADE / RANGEBOX                      |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| 🆕 v3.0 FEATURES ACTIVATION                                      |
//+------------------------------------------------------------------+

input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🆕 SUGAMARA v3.0 - NEW FEATURES                          ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ✅ FEATURE TOGGLES"
input bool      Enable_PartialTP = true;                    // ✅ Partial Take Profit (50%/75%/100%)
input bool      Enable_TrailingAsymmetric = true;           // ✅ Trailing Stop Asimmetrico
input bool      Enable_ATRMultiTF = true;                   // ✅ ATR Multi-Timeframe Dashboard
input bool      Enable_ManualSR = true;                     // ✅ Manual S/R Drag & Drop
input bool      Enable_AdvancedButtons = true;              // ✅ Control Buttons (Market/Limit/Stop)

//+------------------------------------------------------------------+
//| 💰 PARTIAL TAKE PROFIT SETTINGS                                  |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  💰 PARTIAL TAKE PROFIT (v3.0)                            ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📊 PARTIAL TP LEVELS"
input double    PartialTP_Level1_Percent = 50.0;            // 📊 Level 1: % verso TP
input double    PartialTP_Level1_Close = 50.0;              // 📉 Chiudi % posizione a Level 1
input double    PartialTP_Level2_Percent = 75.0;            // 📊 Level 2: % verso TP
input double    PartialTP_Level2_Close = 25.0;              // 📉 Chiudi % posizione a Level 2
input bool      PartialTP_OnShield = true;                  // 🛡️ Applica anche a Shield

//+------------------------------------------------------------------+
//| 📈 TRAILING STOP ASIMMETRICO SETTINGS                            |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📈 TRAILING STOP ASIMMETRICO (v3.0)                      ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🎯 TRAILING PARAMETERS"
input double    Trailing_Aggressive_Pips = 5.0;             // ⚡ Trailing Aggressivo (pips) - verso breakout
input double    Trailing_Conservative_Pips = 15.0;          // 🛡️ Trailing Conservativo (pips) - contro breakout
input double    Trailing_Activation_Pips = 10.0;            // 📏 Attivazione Trailing (pips profit)
input double    Trailing_Step_Pips = 2.0;                   // 📐 Step Trailing (pips)

//+------------------------------------------------------------------+
//| 📊 ATR MULTI-TIMEFRAME SETTINGS                                  |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📊 ATR MULTI-TIMEFRAME DASHBOARD (v3.0)                  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⏱️ TIMEFRAMES"
input ENUM_TIMEFRAMES ATR_MTF_TF1 = PERIOD_M5;              // 📊 TF1: M5
input ENUM_TIMEFRAMES ATR_MTF_TF2 = PERIOD_M15;             // 📊 TF2: M15
input ENUM_TIMEFRAMES ATR_MTF_TF3 = PERIOD_H1;              // 📊 TF3: H1
input ENUM_TIMEFRAMES ATR_MTF_TF4 = PERIOD_H4;              // 📊 TF4: H4
input int       ATR_MTF_Period = 14;                        // 📈 ATR Period per tutti i TF

//+------------------------------------------------------------------+
//| 📍 MANUAL SUPPORT/RESISTANCE SETTINGS                            |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📍 MANUAL S/R DRAG & DROP (v3.0)                         ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🎨 S/R LINE SETTINGS"
input color     ManualSR_ResistanceColor = clrRed;          // 🔺 Colore Resistance
input color     ManualSR_SupportColor = clrLime;            // 🔻 Colore Support
input color     ManualSR_ActivationColor = clrGold;         // ⭐ Colore Activation Level
input int       ManualSR_LineWidth = 2;                     // 📏 Spessore Linee
input bool      ManualSR_ShowLabels = true;                 // 📝 Mostra Etichette

//+------------------------------------------------------------------+
//| 🎮 CONTROL BUTTONS SETTINGS                                      |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎮 CONTROL BUTTONS (v3.0)                                ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ╔═ SELEZIONA ENTRY MODE DEFAULT ════════════════════════🔽🔽🔽"
input ENUM_ENTRY_MODE DefaultEntryMode = ENTRY_MARKET;      // 📊 Entry Mode Default ▼
input double    LimitActivation_Price = 0.0;                // 📍 LIMIT: Prezzo Attivazione (0=manual)
input double    StopActivation_Price = 0.0;                 // 📍 STOP: Prezzo Breakout (0=manual)

//+------------------------------------------------------------------+
//| 🎨 VISUAL THEME SETTINGS (v3.0)                                  |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎨 VISUAL THEME (v3.0)                                   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🖼️ CHART COLORS"
input color     Theme_ChartBackground = clrBlack;           // 🎨 Sfondo Chart (Nero)
input color     Theme_CandleBull = clrDodgerBlue;           // 📈 Candele Bullish (Blu Splendente)
input color     Theme_CandleBear = clrYellow;               // 📉 Candele Bearish (Giallo)

input group "    🎨 DASHBOARD COLORS"
input color     Theme_DashboardBG = C'20,60,80';            // 🎨 Dashboard Background (Blu Turchese)
input color     Theme_DashboardText = clrCyan;              // 📝 Dashboard Text (Azzurro)
input color     Theme_DashboardAccent = clrAqua;            // ⭐ Dashboard Accent

input group "    📏 GRID LINE COLORS"
input color     GridLine_BuyStop = clrDarkGreen;            // 🟢 BUY STOP: Verde Scuro
input color     GridLine_BuyLimit = clrLime;                // 🟢 BUY LIMIT: Verde Chiaro
input color     GridLine_SellStop = clrRed;                 // 🔴 SELL STOP: Rosso
input color     GridLine_SellLimit = clrOrange;             // 🟠 SELL LIMIT: Arancione
input int       GridLine_Width = 2;                         // 📏 Spessore Linee Grid

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
//| 3️⃣.5️⃣ 🔄 ATR DYNAMIC SPACING v4.0                                |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  3️⃣.5️⃣  🔄 ATR DYNAMIC SPACING v4.0                       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⚡ ATTIVAZIONE"
input bool      EnableDynamicATRSpacing = true;              // ✅ Abilita Spacing Dinamico ATR
// Se FALSE: usa Fixed_Spacing_Pips o ATR Decision Table esistente

input group "    ⏱️ TIMING"
input int       ATR_CheckInterval_Seconds = 300;             // ⏱️ Intervallo Check ATR (secondi) [300=5min]
input int       ATR_MinTimeBetweenChanges = 900;             // ⏱️ Min tempo tra cambi (secondi) [900=15min]
input double    ATR_StepChangeThreshold = 15.0;              // 📊 Soglia cambio step (%) [cambio solo se >15%]

input group "    📊 SOGLIE ATR PER STEP (pips)"
input double    ATR_Threshold_VeryLow = 10.0;                // 📊 Soglia VERY_LOW (ATR < X)
input double    ATR_Threshold_Low = 18.0;                    // 📊 Soglia LOW (ATR < X)
input double    ATR_Threshold_Normal = 28.0;                 // 📊 Soglia NORMAL (ATR < X)
input double    ATR_Threshold_High = 40.0;                   // 📊 Soglia HIGH (ATR < X, sopra = EXTREME)

input group "    📏 SPACING PER STEP (pips) - CONFIGURABILI"
input double    Spacing_VeryLow_Pips = 8.0;                  // 📏 Spacing VERY_LOW (mercato piatto)
input double    Spacing_Low_Pips = 12.0;                     // 📏 Spacing LOW (bassa volatilità)
input double    Spacing_Normal_Pips = 18.0;                  // 📏 Spacing NORMAL (condizioni tipiche)
input double    Spacing_High_Pips = 26.0;                    // 📏 Spacing HIGH (volatilità elevata)
input double    Spacing_Extreme_Pips = 35.0;                 // 📏 Spacing EXTREME (news/eventi)

input group "    🔒 LIMITI ASSOLUTI"
input double    DynamicSpacing_Min_Pips = 6.0;               // 🔒 Spacing Minimo Assoluto (pips)
input double    DynamicSpacing_Max_Pips = 50.0;              // 🔒 Spacing Massimo Assoluto (pips)

//+------------------------------------------------------------------+
//| 3️⃣.6️⃣ ⚠️ ATR EXTREME WARNING v4.1                                |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  3️⃣.6️⃣  ⚠️ ATR EXTREME WARNING v4.1                       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⚠️ EXTREME WARNING"
input bool      ATR_EnableExtremeWarning = true;             // ✅ Abilita Warning Veloce su ATR Extreme
input double    ATR_ExtremeThreshold_Pips = 50.0;            // ⚠️ Soglia ATR Extreme (pips) - Warning se >
input int       ATR_ExtremeCheck_Seconds = 10;               // ⏱️ Intervallo Check Extreme (secondi)
input bool      ATR_PauseOnExtreme = false;                  // 🛑 Pausa nuovi ordini su Extreme

//+------------------------------------------------------------------+
//| 3️⃣.7️⃣ 📝 ATR LOGGING v4.2                                        |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  3️⃣.7️⃣  📝 ATR LOGGING v4.2                               ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📝 LOGGING DETTAGLIATO"
input bool      ATR_DetailedLogging = true;                  // ✅ Logging Dettagliato ATR (tutti i cambi)
input bool      ATR_AlertOnSpacingChange = true;             // 🔔 Alert su Cambio Spacing (popup visibile)
input bool      ATR_LogEveryCheck = false;                   // 🔍 Log ogni check ATR (debug mode)
input bool      ATR_LogStepTransitions = true;               // 📊 Log transizioni step ATR

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

input group "    ╔═ SELEZIONA TIPO ORDINE SHIELD ════════════════════════🔽🔽🔽"
input ENUM_SHIELD_ORDER_TYPE ShieldOrderType = SHIELD_ORDER_MARKET; // 🛡️ Tipo Ordine Shield ▼
// SHIELD_ORDER_MARKET = Esecuzione immediata a mercato (CONSIGLIATO)
// SHIELD_ORDER_STOP   = Pending STOP order al livello breakout

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

input group "    🎨 SHIELD ZONES VISUAL (Fasce Colorate)"
input bool      Enable_ShieldZonesVisual = true;             // ✅ Mostra Fasce Shield Zones
input uchar     ShieldZones_Transparency = 210;              // 🔍 Trasparenza Fasce Pericolo (0=opaco, 255=invisibile)
input color     ShieldZone_Phase1_Color = clrYellow;         // 🟡 Fase 1 (Warning) - Giallo
input color     ShieldZone_Phase2_Color = clrOrange;         // 🟠 Fase 2 (Pre-Shield) - Arancione
input color     ShieldZone_Phase3_Color = clrRed;            // 🔴 Fase 3 (Breakout) - Rosso
input color     ShieldEntry_Line_Color = C'139,0,0';         // 🔴 Linea Entry Shield - Rosso Scuro
input int       ShieldEntry_Line_Width = 2;                  // 📏 Spessore Linea Entry Shield
input ENUM_LINE_STYLE ShieldEntry_Line_Style = STYLE_DASH;   // 📐 Stile Linea Entry Shield
input bool      Enable_ProfitZoneVisual = true;              // ✅ Mostra Zona Profit (Verde)
input color     ProfitZone_Color = clrLime;                  // 🟢 Colore Zona Profit - Verde
input uchar     ProfitZone_Transparency = 220;               // 🔍 Trasparenza Zona Profit (molto trasparente)

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

input group "    📊 LOT PARAMETERS (FIXED/PROGRESSIVE)"
input double    BaseLot = 0.02;                              // 💵 Lot Base (livello 1)
input double    LotMultiplier = 1.15;                        // 📈 Moltiplicatore Progressivo
// Level 1: 0.02, Level 2: 0.023, Level 3: 0.026, Level 4: 0.03, Level 5: 0.035
input double    MaxLotPerLevel = 0.12;                       // 🔒 Max Lot per Livello
input double    MaxTotalLot = 0.60;                          // 🔒 Max Lot Totale (tutti gli ordini)

input group "    💰 RISK-BASED LOT SETTINGS (se LOT_RISK_BASED)"
input double    RiskCapital_USD = 100.0;                     // 💰 Capitale Rischio MAX ($)
// Se chiudi TUTTO in loss, perderai massimo questo importo
input bool      IncludeShieldInRisk = true;                  // 🛡️ Includi Shield nel calcolo rischio
// IMPORTANTE: Shield NON piazza SL automatici!
// Shield = protezione tramite hedging, NON chiusura forzata
input double    RiskBuffer_Percent = 10.0;                   // 📊 Buffer Sicurezza (%)
// Calcola lot per perdere (RiskCapital - 10%) come margine

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

input group "    🔄 REOPEN MODE v4.0"
input ENUM_REOPEN_MODE ReopenMode = REOPEN_MODE_SAME_POINT;  // 📍 Modalità Calcolo Prezzo Reopen ▼
// REOPEN_MODE_SAME_POINT: Riapre esattamente al prezzo originale
// REOPEN_MODE_ATR_DRIVEN: Riapre al prezzo calcolato da ATR corrente
// REOPEN_MODE_HYBRID: Stesso punto se vicino, ATR se lontano (>50% spacing)

input group "    🛡️ SICUREZZA REOPEN v4.0"
input bool      PauseReopenOnTrend = true;                   // 🛡️ Pausa reopen se trend forte (ADX alto)
input double    TrendADX_Threshold = 30.0;                   // 📊 Soglia ADX per trend (>30 = trend)
input bool      PauseReopenNearShield = true;                // 🛡️ Pausa reopen vicino a Shield
input double    ShieldProximity_Pips = 20.0;                 // 📏 Distanza minima da Shield (pips)
input bool      PauseReopenOnExtreme = true;                 // 🛡️ Pausa reopen su ATR EXTREME

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
//| 1️⃣7️⃣.5️⃣ 🎯 CENTER INDICATORS v4.0                                |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  1️⃣7️⃣.5️⃣  🎯 CENTER INDICATORS v4.0                       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📊 INDICATORI ATTIVI"
input bool      UsePivotPoint = true;                        // ✅ Usa Pivot Point Daily (40% peso)
input bool      UseEMA50 = true;                             // ✅ Usa EMA 50 (30% peso)
input bool      UseDonchianCenter = true;                    // ✅ Usa Donchian Channel Center (30% peso)

input group "    ⚖️ PESI INDICATORI (%)"
input double    Weight_PivotPoint = 40.0;                    // ⚖️ Peso Pivot Point (%)
input double    Weight_EMA50 = 30.0;                         // ⚖️ Peso EMA 50 (%)
input double    Weight_Donchian = 30.0;                      // ⚖️ Peso Donchian Center (%)
// NOTA: I pesi vengono normalizzati automaticamente a 100%

input group "    ⚙️ PARAMETRI INDICATORI"
input int       EMA_Period = 50;                             // 📊 Periodo EMA
input ENUM_TIMEFRAMES EMA_Timeframe = PERIOD_M15;            // 📊 Timeframe EMA ▼
input int       Donchian_Period = 20;                        // 📊 Periodo Donchian Channel
input ENUM_TIMEFRAMES Donchian_Timeframe = PERIOD_M15;       // 📊 Timeframe Donchian ▼

input group "    🎨 VISUALIZZAZIONE CENTRO"
input bool      ShowCenterIndicators = true;                 // ✅ Mostra indicatori su chart
input color     Color_PivotLine = clrGold;                   // 🟡 Colore Pivot Point
input color     Color_EMALine = clrDodgerBlue;               // 🔵 Colore EMA
input color     Color_DonchianUpper = clrMagenta;            // 🟣 Colore Donchian Upper
input color     Color_DonchianLower = clrMagenta;            // 🟣 Colore Donchian Lower
input color     Color_DonchianCenter = clrOrchid;            // 🟣 Colore Donchian Center
input color     Color_OptimalCenter = clrLime;               // 🟢 Colore Centro Ottimale
input int       CenterLines_Width = 2;                       // 📏 Spessore linee

//+------------------------------------------------------------------+
//| 1️⃣7️⃣.6️⃣ 🔄 AUTO-RECENTER v4.0                                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  1️⃣7️⃣.6️⃣  🔄 AUTO-RECENTER v4.0                           ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⚙️ ATTIVAZIONE"
input bool      EnableAutoRecenter = true;                   // ✅ Abilita Auto-Recenter
input bool      RequireUserConfirm = false;                  // ⚠️ Richiedi conferma utente prima di recenter

input group "    📏 CONDIZIONI TRIGGER"
input double    Recenter_PriceProximity_Pips = 10.0;         // 📏 Prezzo deve essere entro X pips dal centro
input double    Recenter_EntryDistance_Pips = 40.0;          // 📏 Entry deve essere lontano almeno X pips dal centro
input double    Recenter_MinConfidence = 60.0;               // 📊 Confidence minima indicatori (%)

input group "    💰 CONDIZIONI SICUREZZA"
input double    Recenter_MaxFloatingLoss_USD = 50.0;         // 💰 Max floating loss per reset ($)
input double    Recenter_MaxFloatingLoss_Pct = 2.0;          // 💰 Max floating loss per reset (% equity)
input int       Recenter_MinFilledPositions = 0;             // 🔢 Min posizioni filled per bloccare (0=ignora)

input group "    ⏱️ TIMING"
input int       Recenter_MinInterval_Minutes = 240;          // ⏱️ Intervallo minimo tra recenter (minuti)
input bool      Recenter_OnlyOnNewBar = true;                // ⏱️ Recenter solo su nuova barra M15

input group "    🛡️ ECCEZIONI (Blocca Recenter se...)"
input bool      BlockRecenterNearShield = true;              // 🛡️ Blocca recenter vicino a Shield
input bool      BlockRecenterOnTrend = true;                 // 🛡️ Blocca recenter su trend forte (ADX alto)
input bool      BlockRecenterHighVolatility = true;          // 🛡️ Blocca recenter su ATR EXTREME

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

//+------------------------------------------------------------------+
//| 2️⃣2️⃣ 🎨 LEGACY COLOR SCHEME (Grid Lines by Level)                |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  2️⃣2️⃣  🎨 LEGACY COLOR SCHEME - Grid Lines by Level       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    🔵 Main System Colors"
input color COLOR_ENTRY_POINT = clrCyan;              // 🔷 Entry Point Line
input color COLOR_RANGE_UPPER = clrDarkCyan;          // 🔺 Range Upper Bound
input color COLOR_RANGE_LOWER = clrDarkCyan;          // 🔻 Range Lower Bound

input group "    🎨 Grid A Colors (Long Bias - Azure)"
input color COLOR_GRID_A_UPPER = C'100,180,255';      // 🔵 Grid A Upper Zone
input color COLOR_GRID_A_LOWER = C'60,140,205';       // 🔵 Grid A Lower Zone
input color COLOR_GRID_A_TP = C'130,200,255';         // 🎯 Grid A Take Profit
input color COLOR_GRID_A_1 = C'100,180,255';          // 🔵 Grid A Level 1
input color COLOR_GRID_A_2 = C'80,160,230';           // 🔵 Grid A Level 2
input color COLOR_GRID_A_3 = C'60,140,205';           // 🔵 Grid A Level 3
input color COLOR_GRID_A_4 = C'40,120,180';           // 🔵 Grid A Level 4
input color COLOR_GRID_A_5 = C'30,100,160';           // 🔵 Grid A Level 5+

input group "    🎨 Grid B Colors (Short Bias - Cyan)"
input color COLOR_GRID_B_UPPER = C'100,220,255';      // 🔵 Grid B Upper Zone
input color COLOR_GRID_B_LOWER = C'60,180,205';       // 🔵 Grid B Lower Zone
input color COLOR_GRID_B_TP = C'130,240,255';         // 🎯 Grid B Take Profit
input color COLOR_GRID_B_1 = C'100,220,255';          // 🔵 Grid B Level 1
input color COLOR_GRID_B_2 = C'80,200,230';           // 🔵 Grid B Level 2
input color COLOR_GRID_B_3 = C'60,180,205';           // 🔵 Grid B Level 3
input color COLOR_GRID_B_4 = C'40,160,180';           // 🔵 Grid B Level 4
input color COLOR_GRID_B_5 = C'30,140,160';           // 🔵 Grid B Level 5+

