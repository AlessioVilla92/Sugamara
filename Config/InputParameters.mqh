//+------------------------------------------------------------------+
//|                                          InputParameters.mqh     |
//|                        Sugamara - Input Parameters               |
//|                                                                  |
//|  User-configurable parameters for Double Grid Neutral            |
//|  v5.8 MULTIMODE - PURE / CASCADE                                 |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

// Visual Theme Constants (hardcoded, not editable in EA settings)
#include "VisualTheme.mqh"

//+------------------------------------------------------------------+
//| 🆕 v3.0 FEATURES ACTIVATION                                      |
//+------------------------------------------------------------------+

input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🆕 SUGAMARA v3.0 - NEW FEATURES                          ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ✅ FEATURE TOGGLES"
input bool      Enable_ATRMultiTF = true;                   // ✅ ATR Multi-Timeframe Dashboard
input bool      Enable_ManualSR = true;                     // ✅ Manual S/R Drag & Drop
// Enable_AdvancedButtons REMOVED (v4.4) - Buttons are ALWAYS active

//+------------------------------------------------------------------+
//| DEBUG MODE - Strategy Tester Auto-Start                          |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  DEBUG MODE - BACKTEST AUTOMATION                        ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    DEBUG SETTINGS"
input bool      EnableDebugMode = false;                     // Enable Debug Mode (Auto Entry)
input bool      DebugImmediateEntry = true;                  // Immediate Entry (First Tick)
input string    DebugEntryTime = "09:30";                    // Entry Time (HH:MM) - se non immediate
input string    DebugCloseTime = "";                         // Close Time (HH:MM) - vuoto = no close

//+------------------------------------------------------------------+
//| 💰 PARTIAL TAKE PROFIT - REMOVED (v5.x cleanup)                  |
//| Dannoso per Cyclic Reopen - riduce profit del 37%                |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 🎰 FOREX PAIR SELECTION (Spostato qui per visibilità)            |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎰 FOREX PAIR SELECTION                                 ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ╔═ SELEZIONA COPPIA ══════════════════════════════════════🔽🔽🔽"
input ENUM_FOREX_PAIR SelectedPair = PAIR_EURUSD;            // 📋 Select Forex Pair ▼
// EUR/USD: Spread basso, range medio, ideale per iniziare
// USD/CAD: Spread basso, range contenuto, ottimo per grid neutral
// AUD/NZD: Range strettissimo, win rate altissimo, BEST per neutral

//+------------------------------------------------------------------+
//| 📐 GRID CONFIGURATION (Spostato qui per visibilità)              |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  📐 GRID CONFIGURATION                                   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📏 GRID STRUCTURE"
input int       GridLevelsPerSide = 7;                       // 🔢 Livelli per Lato (3-10) [Default: 7]
// 7 livelli × 2 zone × 2 grid = 28 ordini totali

input group "    ╔═ SPACING SETTINGS ════════════════════════════════🔽🔽🔽"
input ENUM_SPACING_MODE SpacingMode = SPACING_PAIR_AUTO;     // 📏 Modalità Spacing ▼ (DEFAULT: Pair Auto)
input double    Fixed_Spacing_Pips = 11.0;                   // 📐 Spacing Fisso (pips) - usato solo se SPACING_FIXED

//+------------------------------------------------------------------+
//| 🔒 BREAK ON PROFIT (BOP) v5.1                                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔒 BREAK ON PROFIT (BOP) v5.1                           ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool      Enable_BreakOnProfit = true;                // ✅ Abilita Break On Profit (v5.6: default ON)
// Quando posizione raggiunge X% del TP, sposta SL a Y% del profit

input group "    📊 BOP PARAMETERS"
input double    BOP_TriggerPercent = 75.0;                  // 📊 Trigger: % progress verso TP (es: 75%)
input double    BOP_LockPercent = 50.0;                     // 🔒 Lock: % profit da proteggere (es: 50%)
// Esempio: TP=10 pips, prezzo a 7.5 pips (75%), SL va a 3.75 pips (50% di 7.5)

//+------------------------------------------------------------------+
//| 💵 CLOSE ON PROFIT (COP) v5.1                                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  💵 CLOSE ON PROFIT (COP) v5.1                           ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool      Enable_CloseOnProfit = true;                // ✅ Abilita Close On Profit
// Chiude tutto quando raggiunge il target giornaliero

input group "    💰 COP TARGET"
input double    COP_DailyTarget_USD = 50.0;                 // 💰 Target Giornaliero ($)
input bool      COP_IncludeFloating = true;                 // 📊 Includi Floating P/L nel calcolo

input group "    💳 COMMISSIONI"
input bool      COP_DeductCommissions = true;               // 💳 Sottrai Commissioni
input double    COP_CommissionPerLot = 3.50;                // 💳 Commissione per Lot ($)

input group "    🎯 AZIONI AL TARGET"
input bool      COP_ClosePositions = true;                  // ❌ Chiudi tutte le Posizioni
input bool      COP_DeletePending = true;                   // 🗑️ Cancella tutti i Pending
input bool      COP_PauseTrading = true;                    // ⏸️ Pausa Trading dopo Target


//+------------------------------------------------------------------+
//| 🔄 TRAILING GRID INTELLIGENTE v5.3                                |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🔄 TRAILING GRID INTELLIGENTE (v5.3)                     ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ✅ ATTIVAZIONE"
input bool   Enable_TrailingGrid = true;                    // ✅ Abilita Trailing Grid (v5.4 default ON)
// Quando abilitato, il sistema aggiunge automaticamente nuove grid
// seguendo il movimento del mercato (drift)

input group "    📊 CONFIGURAZIONE"
input int    Trail_Trigger_Level = 2;                       // 🎯 Trigger Level (1=ultima, 2=penultima)
// 1 = Trigger quando l'ultima grid si attiva (breve finestra scoperta)
// 2 = Trigger quando la penultima si attiva (RACCOMANDATO - 1 grid buffer)
// 3 = Trigger quando la terzultima si attiva (2 grid buffer)

input double Trail_Spacing_Multiplier = 1.0;                // 📏 Moltiplicatore Spacing (1.0-2.0)
// 1.0 = Stesso spacing delle grid normali
// 1.5 = 50% piu largo (piu conservativo)

input int    Trail_Max_Extra_Grids = 4;                     // 🔢 Max Grid Extra per Lato (1-4)
// Con GridLevelsPerSide=7: max 7+4=11 grid totali per lato
// 0 = Nessun limite (ATTENZIONE: puo raggiungere limite array!)

input group "    🔧 OPZIONI AVANZATE"
input bool   Trail_Remove_Distant = true;                   // 🗑️ Elimina Grid Lontane (lato opposto)
input bool   Trail_Sync_Shield = true;                      // 🛡️ Sincronizza Shield Zone

//+------------------------------------------------------------------+
//| 🎯 GRID ZERO v5.8 - Center Gap Filler                            |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎯 GRID ZERO v5.8 - Center Gap Filler                    ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ✅ ATTIVAZIONE"
input bool   Enable_GridZero = true;                        // ✅ Abilita Grid Zero (Mean Reversion)
// Grid Zero fills the 27-pip gap at the center of the grid
// Triggered when L2 is filled (price moved 24+ pips from entry)
// Inserts counter-trend orders for mean-reversion strategy

input group "    📊 CONFIGURAZIONE"
input int    GridZero_Trigger_Level = 2;                    // 🎯 Trigger Level (L2 = default)
// 1 = Trigger when L1 filled (12 pips from entry)
// 2 = Trigger when L2 filled (24 pips from entry) - RECOMMENDED
// 3 = Trigger when L3 filled (36 pips from entry) - Conservative

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

// S/R LINE COLORS: Now in VisualTheme.mqh (MANUAL_SR_*)

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

// (VISUAL THEME spostato alla fine del file)

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
input bool      EnableEmergencyStop = false;                 // ❌ DISABILITATO - RIBELLE TOTALE! Nessun limite automatico
input double    EmergencyStop_Percent = 20.0;                // 📉 Emergency Stop DD (%) - Non usato se EnableEmergencyStop=false

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

//+------------------------------------------------------------------+
//| 3️⃣ 📊 ATR SETTINGS                                               |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  3️⃣  📊 ATR SETTINGS (CASCADE Mode)                       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⚡ ATR ACTIVATION"
input bool      UseATR = false;                              // ⭐ Abilita ATR (default FALSE per usare Fixed_Spacing_Pips)

input group "    ⏱️ ATR INDICATOR SETTINGS"
input group "    ╔═ SELEZIONA TIMEFRAME ATR ═══════════════════════════════🔽🔽🔽"
input ENUM_TIMEFRAMES ATR_Timeframe = PERIOD_M5;             // 📊 ATR Timeframe ▼
input int       ATR_Period = 14;                             // 📈 ATR Period (bars)
// v5.8: ATR usato solo per monitoraggio volatilità nel dashboard

//+------------------------------------------------------------------+
//| 3️⃣.8️⃣ 📝 TRAILING GRID LOGGING v5.5                               |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  3️⃣.8️⃣  📝 TRAILING GRID LOGGING v5.5                     ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📝 TRAILING GRID LOGGING"
input bool      Trail_DetailedLogging = true;                // ✅ Log Dettagliato Trailing Grid
input bool      Trail_LogInsertions = true;                  // ➕ Log Inserimenti Nuove Grid
input bool      Trail_LogRemovals = true;                    // ➖ Log Rimozioni Grid Distanti
input bool      Trail_LogTriggerChecks = false;              // 🔍 Log Check Trigger (Debug - HEAVY!)
input bool      Trail_LogShieldSync = true;                  // 🛡️ Log Sync Shield Zone

// (FOREX PAIR SELECTION e GRID CONFIGURATION spostati in alto dopo DEBUG MODE)

//+------------------------------------------------------------------+
//| 🎯 TP SETTINGS (Solo PURE)                                       |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  6️⃣  🎯 TP SETTINGS (Solo PURE Mode)                      ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📍 TAKE PROFIT PURE MODE"
input double    TP_Ratio_Pure = 1.2;                         // 🎯 Ratio TP per PURE (1.0-2.0)
// TP = Spacing × Ratio | 1.2 = TP 20% maggiore di spacing

//+------------------------------------------------------------------+
//| 7️⃣ 🛡️ SHIELD INTELLIGENTE (CASCADE_OVERLAP)                      |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  7️⃣  🛡️ SHIELD INTELLIGENTE (CASCADE_OVERLAP Mode)        ║"
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
input int       Breakout_Confirm_Candles = 2;                // 🔢 Candele Conferma Breakout
input bool      Use_Candle_Close = true;                     // ✅ Usa Chiusura Candela per Conferma
input int       Reentry_Confirm_Seconds = 30;                // ⏱️ Secondi conferma Reentry (0=disabilitato)

input group "    ⚠️ SHIELD 3 FASI PARAMETERS"
input bool      Shield_Use_Trailing = false;                 // ✅ Trailing per Shield
input double    Shield_Trailing_Start = 30.0;                // 📏 Trailing Start (pips)
input double    Shield_Trailing_Step = 10.0;                 // 📏 Trailing Step (pips)

input group "    🎨 SHIELD ZONES VISUAL (Fasce Colorate)"
input bool      Enable_ShieldZonesVisual = true;             // ✅ Mostra Fasce Shield Zones
input bool      Enable_ProfitZoneVisual = true;              // ✅ Mostra Zona Profit (Verde)
// SHIELD ZONE COLORS: Now in VisualTheme.mqh (SHIELDZONE_*, PROFITZONE_*)

input group "    🔧 LEGACY HEDGE (Backward Compatibility)"
input bool      EnableHedging = true;                        // ✅ Abilita hedging (maps to Shield)

//+------------------------------------------------------------------+
//| 9️⃣ 💰 LOT SIZING                                                 |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  9️⃣  💰 LOT SIZING ⚠️ [CRITICAL SECTION]                  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ╔═ SELEZIONA LOT MODE ════════════════════════════════════🔽🔽🔽"
input ENUM_LOT_MODE LotMode = LOT_FIXED;                     // 💵 Lot Calculation Mode ▼ (v5.4: default FIXED per 0.02 su tutte le grid)

input group "    📊 LOT PARAMETERS (FIXED/PROGRESSIVE)"
input double    BaseLot = 0.02;                              // 💵 Lot Base (livello 1)
input double    LotMultiplier = 1.15;                        // 📈 Moltiplicatore Progressivo
// Level 1: 0.02, Level 2: 0.023, Level 3: 0.026, Level 4: 0.03, Level 5: 0.035
input double    MaxLotPerLevel = 0.12;                       // 🔒 Max Lot per Livello

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
input ENUM_CASCADE_MODE CascadeMode = CASCADE_OVERLAP;       // 📊 Modalità Cascade ▼
// CASCADE_PERFECT: TP di ogni ordine = Entry del livello successivo
// Crea una catena perfetta senza gap

input group "    📐 CASCADE PARAMETERS"
input double    CascadeTP_Ratio = 1.0;                       // 📈 Ratio TP (se CASCADE_RATIO)

input group "    🔀 CASCADE OVERLAP (RIBELLE)"
input double    Hedge_Spacing_Pips = 3.0;                    // 📏 Distanza STOP ↔ LIMIT (pips) - Solo se CASCADE_OVERLAP
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
input ENUM_REOPEN_TRIGGER ReopenTrigger = REOPEN_IMMEDIATE;  // 📊 Trigger Reopen ▼ (IMMEDIATE = griglia sempre completa!)

input group "    📐 CYCLIC PARAMETERS"
// Cooldown REMOVED v5.8 - Reopen sempre immediato
input int       MaxCyclesPerLevel = 0;                       // 🔢 Max Cicli per Livello (0=infiniti)
input bool      EnableReopenOffset = true;                   // ✅ Abilita Offset Bidirezionale
input double    ReopenOffset_Pips = 5.0;                     // 📏 Offset Bidirezionale (±pips)
// Riapre ordine quando prezzo torna al livello ± offset (es: 5 pips = zona ±5 pips)

input group "    🔄 REOPEN MODE v4.0"
input ENUM_REOPEN_MODE ReopenMode = REOPEN_MODE_SAME_POINT;  // 📍 Modalità Calcolo Prezzo Reopen ▼
// REOPEN_MODE_SAME_POINT: Riapre esattamente al prezzo originale
// REOPEN_MODE_ATR_DRIVEN: Riapre al prezzo calcolato da ATR corrente
// REOPEN_MODE_HYBRID: Stesso punto se vicino, ATR se lontano (>50% spacing)

input group "    🛡️ SICUREZZA REOPEN v4.0"
input bool      PauseReopenNearShield = false;               // 🛡️ Pausa reopen vicino a Shield ( Disattivato 12dic )
input double    ShieldProximity_Pips = 20.0;                 // 📏 Distanza minima da Shield (pips)
input bool      PauseReopenOnExtreme = false;                // 🛡️ Pausa reopen su ATR EXTREME ( Disattivato 12dic )

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

input group "    ⚠️ NEWS PAUSE"
input bool      PauseOnNews = false;                         // ✅ Pausa durante News (manuale)
// Richiede attivazione manuale 30 min prima di news

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
input int       Dashboard_X = 0;                             // 📍 Posizione X Dashboard (v5.9: 0=nessun margine)
input int       Dashboard_Y = 30;                            // 📍 Posizione Y Dashboard
input bool      ShowGridLines = true;                        // ✅ Mostra Linee Grid su Chart

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

//+------------------------------------------------------------------+
//| 1️⃣9️⃣ 🇪🇺🇺🇸 EUR/USD SOTTOSTANTI                                   |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  1️⃣9️⃣  🇪🇺🇺🇸 SOTTOSTANTI - EUR/USD                        ║"
input group "║      Spread: 0.8-1.5 | Range: 60-100 | Spacing: 9 pips   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 EUR/USD GRID SETTINGS"
input double    EURUSD_DefaultSpacing = 9.0;                 // 📏 Spacing Default (pips)
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
input group "║      Spread: 1.0-1.8 | Range: 50-80 | Spacing: 12 pips   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 USD/CAD GRID SETTINGS"
input double    USDCAD_DefaultSpacing = 12.0;                // 📏 Spacing Default (pips) - v4.6 aumentato per spread
input double    USDCAD_TP_Pips = 20.0;                       // 🎯 TP per livello (pips) - v4.6 aumentato per compensare
input double    USDCAD_EstimatedSpread = 1.3;                // 📊 Spread Stimato (pips)
input double    USDCAD_DailyRange = 65.0;                    // 📈 Range Giornaliero (pips)
input double    USDCAD_ATR_Typical = 22.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 2️⃣1️⃣ 🇦🇺🇳🇿 AUD/NZD SOTTOSTANTI (BEST NEUTRAL)                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  2️⃣1️⃣  🇦🇺🇳🇿 SOTTOSTANTI - AUD/NZD (BEST NEUTRAL)         ║"
input group "║      Spread: 2.5-3.5 | Range: 50-80 | Spacing: 10 pips   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 AUD/NZD GRID SETTINGS"
input double    AUDNZD_DefaultSpacing = 10.0;                // 📏 Spacing Default (pips)
input double    AUDNZD_TP_Pips = 15.0;                       // 🎯 TP per livello (pips)
input double    AUDNZD_EstimatedSpread = 3.0;                // 📊 Spread Stimato (pips)
input double    AUDNZD_DailyRange = 65.0;                    // 📈 Range Giornaliero (pips)
input double    AUDNZD_ATR_Typical = 18.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 2️⃣2️⃣ 🇪🇺🇨🇭 EUR/CHF SOTTOSTANTI                                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  2️⃣2️⃣  🇪🇺🇨🇭 SOTTOSTANTI - EUR/CHF (LOW VOLATILITY)       ║"
input group "║      Spread: 1.2-2.0 | Range: 40-60 | Spacing: 10 pips   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 EUR/CHF GRID SETTINGS"
input double    EURCHF_DefaultSpacing = 10.0;                // 📏 Spacing Default (pips)
input double    EURCHF_TP_Pips = 15.0;                       // 🎯 TP per livello (pips)
input double    EURCHF_EstimatedSpread = 1.5;                // 📊 Spread Stimato (pips)
input double    EURCHF_DailyRange = 50.0;                    // 📈 Range Giornaliero (pips)
input double    EURCHF_ATR_Typical = 15.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 2️⃣3️⃣ 🇦🇺🇨🇦 AUD/CAD SOTTOSTANTI                                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  2️⃣3️⃣  🇦🇺🇨🇦 SOTTOSTANTI - AUD/CAD (COMMODITY)            ║"
input group "║      Spread: 2.0-3.0 | Range: 60-90 | Spacing: 10 pips   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 AUD/CAD GRID SETTINGS"
input double    AUDCAD_DefaultSpacing = 10.0;                // 📏 Spacing Default (pips)
input double    AUDCAD_TP_Pips = 15.0;                       // 🎯 TP per livello (pips)
input double    AUDCAD_EstimatedSpread = 2.5;                // 📊 Spread Stimato (pips)
input double    AUDCAD_DailyRange = 75.0;                    // 📈 Range Giornaliero (pips)
input double    AUDCAD_ATR_Typical = 22.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 2️⃣4️⃣ 🇳🇿🇨🇦 NZD/CAD SOTTOSTANTI                                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  2️⃣4️⃣  🇳🇿🇨🇦 SOTTOSTANTI - NZD/CAD                         ║"
input group "║      Spread: 2.5-3.5 | Range: 55-85 | Spacing: 10 pips   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 NZD/CAD GRID SETTINGS"
input double    NZDCAD_DefaultSpacing = 10.0;                // 📏 Spacing Default (pips)
input double    NZDCAD_TP_Pips = 15.0;                       // 🎯 TP per livello (pips)
input double    NZDCAD_EstimatedSpread = 3.0;                // 📊 Spread Stimato (pips)
input double    NZDCAD_DailyRange = 70.0;                    // 📈 Range Giornaliero (pips)
input double    NZDCAD_ATR_Typical = 20.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 2️⃣5️⃣ 🇪🇺🇬🇧 EUR/GBP SOTTOSTANTI (EXCELLENT NEUTRAL)                |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  2️⃣5️⃣  🇪🇺🇬🇧 SOTTOSTANTI - EUR/GBP (EXCELLENT NEUTRAL)    ║"
input group "║      Spread: 1.2-2.0 | Range: 45-70 | Spacing: 10 pips   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 EUR/GBP GRID SETTINGS"
input double    EURGBP_DefaultSpacing = 10.0;                // 📏 Spacing Default (pips)
input double    EURGBP_TP_Pips = 15.0;                       // 🎯 TP per livello (pips)
input double    EURGBP_EstimatedSpread = 1.5;                // 📊 Spread Stimato (pips)
input double    EURGBP_DailyRange = 55.0;                    // 📈 Range Giornaliero (pips)
input double    EURGBP_ATR_Typical = 16.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 2️⃣6️⃣ 🇬🇧🇺🇸 GBP/USD SOTTOSTANTI                                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  2️⃣6️⃣  🇬🇧🇺🇸 SOTTOSTANTI - GBP/USD (MEAN REVERTING)       ║"
input group "║      Spread: 1.0-1.5 | Range: 80-120 | Spacing: 12 pips  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 GBP/USD GRID SETTINGS"
input double    GBPUSD_DefaultSpacing = 12.0;                // 📏 Spacing Default (pips)
input double    GBPUSD_TP_Pips = 20.0;                       // 🎯 TP per livello (pips)
input double    GBPUSD_EstimatedSpread = 1.2;                // 📊 Spread Stimato (pips)
input double    GBPUSD_DailyRange = 100.0;                   // 📈 Range Giornaliero (pips)
input double    GBPUSD_ATR_Typical = 28.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 2️⃣7️⃣ 🇺🇸🇨🇭 USD/CHF SOTTOSTANTI                                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  2️⃣7️⃣  🇺🇸🇨🇭 SOTTOSTANTI - USD/CHF (SAFE HAVEN)           ║"
input group "║      Spread: 1.2-2.0 | Range: 50-75 | Spacing: 10 pips   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 USD/CHF GRID SETTINGS"
input double    USDCHF_DefaultSpacing = 10.0;                // 📏 Spacing Default (pips)
input double    USDCHF_TP_Pips = 15.0;                       // 🎯 TP per livello (pips)
input double    USDCHF_EstimatedSpread = 1.5;                // 📊 Spread Stimato (pips)
input double    USDCHF_DailyRange = 60.0;                    // 📈 Range Giornaliero (pips)
input double    USDCHF_ATR_Typical = 18.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 2️⃣8️⃣ 🇺🇸🇯🇵 USD/JPY SOTTOSTANTI                                    |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  2️⃣8️⃣  🇺🇸🇯🇵 SOTTOSTANTI - USD/JPY (HIGH VOLATILITY)      ║"
input group "║      Spread: 0.8-1.5 | Range: 80-110 | Spacing: 12 pips  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 USD/JPY GRID SETTINGS"
input double    USDJPY_DefaultSpacing = 12.0;                // 📏 Spacing Default (pips)
input double    USDJPY_TP_Pips = 20.0;                       // 🎯 TP per livello (pips)
input double    USDJPY_EstimatedSpread = 1.0;                // 📊 Spread Stimato (pips)
input double    USDJPY_DailyRange = 95.0;                    // 📈 Range Giornaliero (pips)
input double    USDJPY_ATR_Typical = 28.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 2️⃣9️⃣ 🇪🇺🇯🇵 EUR/JPY SETTINGS                                      |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  2️⃣9️⃣  🇪🇺🇯🇵 SOTTOSTANTI - EUR/JPY (CROSS MAJOR)          ║"
input group "║      Spread: 1.0-1.8 | Range: 80-120 | Spacing: 12 pips  ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 EUR/JPY GRID SETTINGS"
input double    EURJPY_DefaultSpacing = 12.0;                // 📏 Spacing Default (pips)
input double    EURJPY_TP_Pips = 18.0;                       // 🎯 TP per livello (pips)
input double    EURJPY_EstimatedSpread = 1.4;                // 📊 Spread Stimato (pips)
input double    EURJPY_DailyRange = 100.0;                   // 📈 Range Giornaliero (pips)
input double    EURJPY_ATR_Typical = 30.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 3️⃣0️⃣ 🇦🇺🇺🇸 AUD/USD SETTINGS                                      |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  3️⃣0️⃣  🇦🇺🇺🇸 SOTTOSTANTI - AUD/USD (COMMODITY MAJOR)      ║"
input group "║      Spread: 0.8-1.5 | Range: 60-90 | Spacing: 10 pips   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 AUD/USD GRID SETTINGS"
input double    AUDUSD_DefaultSpacing = 10.0;                // 📏 Spacing Default (pips)
input double    AUDUSD_TP_Pips = 15.0;                       // 🎯 TP per livello (pips)
input double    AUDUSD_EstimatedSpread = 1.0;                // 📊 Spread Stimato (pips)
input double    AUDUSD_DailyRange = 75.0;                    // 📈 Range Giornaliero (pips)
input double    AUDUSD_ATR_Typical = 22.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 3️⃣1️⃣ 🇳🇿🇺🇸 NZD/USD SETTINGS                                      |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  3️⃣1️⃣  🇳🇿🇺🇸 SOTTOSTANTI - NZD/USD (COMMODITY PAIR)       ║"
input group "║      Spread: 1.2-2.0 | Range: 50-80 | Spacing: 10 pips   ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 NZD/USD GRID SETTINGS"
input double    NZDUSD_DefaultSpacing = 10.0;                // 📏 Spacing Default (pips)
input double    NZDUSD_TP_Pips = 14.0;                       // 🎯 TP per livello (pips)
input double    NZDUSD_EstimatedSpread = 1.5;                // 📊 Spread Stimato (pips)
input double    NZDUSD_DailyRange = 65.0;                    // 📈 Range Giornaliero (pips)
input double    NZDUSD_ATR_Typical = 20.0;                   // 📊 ATR Tipico (pips)

//+------------------------------------------------------------------+
//| 3️⃣2️⃣ ⚙️ CUSTOM PAIR SETTINGS                                     |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  3️⃣2️⃣  ⚙️ CUSTOM PAIR SETTINGS (if CUSTOM selected)       ║"
input group "║      Spacing: 10 pips (default) - configurabile         ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    📐 CUSTOM PAIR PARAMETERS"
input double    Custom_Spread = 1.5;                         // 📊 Spread Stimato (pips)
input double    Custom_DailyRange = 100.0;                   // 📈 Range Giornaliero (pips)
input double    Custom_ATR_Typical = 25.0;                   // 📊 ATR Tipico (pips)
input double    Custom_MinLot = 0.01;                        // 💵 Lot Minimo
input double    Custom_DefaultSpacing = 10.0;                // 📏 Spacing Default (pips)

// LEGACY COLOR SCHEME REMOVED - Now in VisualTheme.mqh
// COLOR_ENTRY_POINT, COLOR_GRID_A_*, COLOR_GRID_B_* are now #define constants

//+------------------------------------------------------------------+
//| 3️⃣1️⃣ ⏰ AUTOMATIC HOUR SESSION v4.6                              |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  3️⃣1️⃣  ⏰ AUTOMATIC HOUR SESSION v4.6                     ║"
input group "║      Auto Start/Stop trading based on time               ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⏰ SESSION SETTINGS"
input bool      EnableAutoSession = false;                   // ✅ Enable Automatic Session
input bool      EnableSessionStart = true;                   // ✅ Enable Auto Start at Time
input string    SessionStartTime = "09:30";                  // 🕘 Start Time (HH:MM broker time)
input bool      EnableSessionClose = true;                   // ✅ Enable Auto Close at Time
input string    SessionCloseTime = "17:00";                  // 🕔 Close Time (HH:MM broker time)

input group "    🔒 END OF SESSION ACTIONS"
input bool      CloseAllOnSessionEnd = false;                // ❌ DISABILITATO per grid 24/7 puro ribelle
input bool      DeletePendingOnEnd = true;                   // ✅ Delete All Pending Orders at End

//+------------------------------------------------------------------+
//| 3️⃣2️⃣ 🎨 TP VISUAL LINES v4.6                                     |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  3️⃣2️⃣  🎨 TP VISUAL LINES v4.6                            ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input bool      ShowTPLines = true;                          // ✅ Show TP Lines on Chart
// TP LINE COLORS: Now in VisualTheme.mqh (TP_LINE_*)

// VISUAL THEME REMOVED - Now in VisualTheme.mqh
// THEME_CHART_*, THEME_CANDLE_*, THEME_DASHBOARD_*, COLOR_GRIDLINE_* are now #define constants

