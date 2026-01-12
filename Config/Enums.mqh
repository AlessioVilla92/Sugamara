//+------------------------------------------------------------------+
//|                                                      Enums.mqh   |
//|                        Sugamara - Enumerations                   |
//|                                                                  |
//|  All system enumerations for Double Grid Neutral                 |
//|  v2.0 MULTIMODE - PURE / CASCADE / RANGEBOX                      |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| ⭐ NEUTRAL MODE - Selezione modalità principale EA ⭐            |
//+------------------------------------------------------------------+
enum ENUM_NEUTRAL_MODE {
    NEUTRAL_PURE = 0,           // 1. PURE - Spacing fisso, TP fisso, NO ATR (Learning)
    NEUTRAL_CASCADE = 1         // 2. CASCADE - TP=Entry precedente, ATR opzionale (CONSIGLIATO)
};

//+------------------------------------------------------------------+
//| 🎰 FOREX PAIR SELECTION - Coppie ottimizzate per Grid Neutral    |
//+------------------------------------------------------------------+
enum ENUM_FOREX_PAIR {
    PAIR_EURUSD,    // 🇪🇺🇺🇸 EUR/USD (Spread: 0.8-1.5, Range: 60-100 pips)
    PAIR_USDCAD,    // 🇺🇸🇨🇦 USD/CAD (Spread: 1.0-1.8, Range: 50-80 pips)
    PAIR_AUDNZD,    // 🇦🇺🇳🇿 AUD/NZD (Spread: 2-4, Range: 40-70 pips) - BEST NEUTRAL
    PAIR_EURCHF,    // 🇪🇺🇨🇭 EUR/CHF (Spread: 1.5-2.5, Range: 35-60 pips)
    PAIR_AUDCAD,    // 🇦🇺🇨🇦 AUD/CAD (Spread: 2-3, Range: 50-80 pips)
    PAIR_NZDCAD,    // 🇳🇿🇨🇦 NZD/CAD (Spread: 2-3, Range: 45-75 pips)
    PAIR_EURGBP,    // 🇪🇺🇬🇧 EUR/GBP (Spread: 1-2, Range: 40-70 pips) - EXCELLENT NEUTRAL
    PAIR_GBPUSD,    // 🇬🇧🇺🇸 GBP/USD (Spread: 1-2, Range: 80-120 pips) - Mean Reverting
    PAIR_USDCHF,    // 🇺🇸🇨🇭 USD/CHF (Spread: 1-2, Range: 50-70 pips) - Safe Haven
    PAIR_USDJPY,    // 🇺🇸🇯🇵 USD/JPY - Test Breakout (Spread: 0.8-1.5, Range: 70-120 pips)
    PAIR_EURJPY,    // 🇪🇺🇯🇵 EUR/JPY (Spread: 1.0-1.8, Range: 80-120 pips) - Cross Major
    PAIR_AUDUSD,    // 🇦🇺🇺🇸 AUD/USD (Spread: 0.8-1.5, Range: 60-90 pips) - Commodity Major
    PAIR_NZDUSD,    // 🇳🇿🇺🇸 NZD/USD (Spread: 1.2-2.0, Range: 50-80 pips) - Commodity Pair
    PAIR_CUSTOM     // ⚙️ Custom (Impostazioni Manuali)
};

//+------------------------------------------------------------------+
//| 🛡️ SHIELD ENUMS REMOVED in v9.12                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 📏 SPACING MODE - Modalità calcolo spacing griglia               |
//| v5.9: SPACING_PAIR_AUTO aggiunto - legge spacing dal pair preset |
//+------------------------------------------------------------------+
enum ENUM_SPACING_MODE {
    SPACING_FIXED,              // Fixed - Spacing fisso manuale (pips)
    SPACING_PAIR_AUTO           // Pair Auto - Usa spacing preset della coppia (DEFAULT)
};

//+------------------------------------------------------------------+
//| 📐 ENTRY SPACING MODE v9.8 - Distanza Entry → Grid±1             |
//| Configura la distanza tra Entry Point e prima griglia            |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_SPACING_MODE {
    ENTRY_SPACING_FULL = 0,     // FULL - Prima grid a spacing completo (buco = 2×spacing)
    ENTRY_SPACING_HALF = 1,     // HALF - Prima grid a metà spacing (PERFECT CASCADE!)
    ENTRY_SPACING_MANUAL = 2    // MANUAL - Prima grid a distanza personalizzata
};

//+------------------------------------------------------------------+
//| 💰 LOT MODE - Modalità calcolo lot size                          |
//+------------------------------------------------------------------+
enum ENUM_LOT_MODE {
    LOT_FIXED,                  // Fixed - Lot size fisso per tutti i livelli
    LOT_PROGRESSIVE,            // Progressive - Lot crescente per livello
    LOT_RISK_BASED              // Risk-Based - Calcola lot da capitale rischio (CONSIGLIATO)
};

//+------------------------------------------------------------------+
//| 🎯 CASCADE MODE - Modalità cascade per Take Profit               |
//+------------------------------------------------------------------+
enum ENUM_CASCADE_MODE {
    CASCADE_PERFECT,            // Perfect - TP = Entry livello precedente (CONSIGLIATO)
    CASCADE_RATIO               // Ratio - TP = Spacing × Ratio
    // v9.0: CASCADE_OVERLAP RIMOSSO - Struttura Grid A=BUY / Grid B=SELL ora DEFAULT
};

//+------------------------------------------------------------------+
//| 🔄 REOPEN TRIGGER - Trigger per riapertura ciclica               |
//+------------------------------------------------------------------+
enum ENUM_REOPEN_TRIGGER {
    REOPEN_IMMEDIATE,           // Immediate - Riapre SUBITO dopo chiusura (griglia sempre completa!)
    REOPEN_PRICE_LEVEL,         // Price Level - Riapre quando prezzo torna al livello
    REOPEN_TIME_BASED,          // Time Based - Riapre dopo X secondi
    REOPEN_HYBRID               // Hybrid - Price Level + Time Based
};

//+------------------------------------------------------------------+
//| ⚙️ SYSTEM STATE - Stati del sistema                              |
//+------------------------------------------------------------------+
enum ENUM_SYSTEM_STATE {
    // Stati base
    STATE_INIT = 0,             // Inizializzazione
    STATE_IDLE = 1,             // Inattivo
    STATE_RUNNING = 2,          // Operativo normale
    STATE_ACTIVE = 2,           // Alias per STATE_RUNNING
    STATE_PAUSED = 3,           // In pausa
    STATE_INITIALIZING = 4,     // Inizializzazione in corso
    STATE_CLOSING = 5,          // Chiusura posizioni in corso

    // Stati Emergency
    STATE_EMERGENCY = 90,       // Emergency stop
    STATE_ERROR = 99            // Errore
};

//+------------------------------------------------------------------+
//| 📋 ORDER STATUS - Stati degli ordini grid                        |
//+------------------------------------------------------------------+
enum ENUM_ORDER_STATUS {
    ORDER_NONE,                 // Nessun ordine
    ORDER_PENDING,              // Ordine pending piazzato
    ORDER_FILLED,               // Ordine eseguito (posizione aperta)
    ORDER_CLOSED,               // Ordine chiuso (generico)
    ORDER_CLOSED_TP,            // Ordine chiuso in Take Profit
    ORDER_CLOSED_SL,            // Ordine chiuso in Stop Loss
    ORDER_CANCELLED,            // Ordine cancellato
    ORDER_ERROR                 // Errore ordine
};

//+------------------------------------------------------------------+
//| 🔵🟠 GRID SIDE - Identificazione Grid A / Grid B                  |
//+------------------------------------------------------------------+
enum ENUM_GRID_SIDE {
    GRID_A,                     // Grid A - Long Bias (Azzurro)
    GRID_B                      // Grid B - Short Bias (Arancio)
};

//+------------------------------------------------------------------+
//| ⬆️⬇️ GRID ZONE - Zona della griglia (sopra/sotto entry)           |
//+------------------------------------------------------------------+
enum ENUM_GRID_ZONE {
    ZONE_UPPER,                 // Sopra Entry Point
    ZONE_LOWER                  // Sotto Entry Point
};

//+------------------------------------------------------------------+
//| 📊 ATR CONDITION - Condizione volatilità basata su ATR           |
//+------------------------------------------------------------------+
enum ENUM_ATR_CONDITION {
    ATR_CALM,                   // ATR < 15 pips - Mercato calmo
    ATR_NORMAL,                 // ATR 15-30 pips - Condizioni normali
    ATR_VOLATILE,               // ATR 30-50 pips - Mercato volatile
    ATR_EXTREME                 // ATR > 50 pips - Volatilità estrema
};

// v5.8: ENUM_ATR_STEP rimosso - ATR dynamic spacing eliminato

//+------------------------------------------------------------------+
//| 🔄 REOPEN MODE v4.0 - Modalità calcolo prezzo riapertura         |
//+------------------------------------------------------------------+
enum ENUM_REOPEN_MODE {
    REOPEN_MODE_SAME_POINT = 0,     // Stesso Punto - Riapre esattamente al prezzo originale
    REOPEN_MODE_ATR_DRIVEN = 1,     // ATR Driven - Riapre al prezzo calcolato da ATR corrente
    REOPEN_MODE_HYBRID = 2          // Ibrido - Stesso punto se vicino, ATR se lontano
};

//+------------------------------------------------------------------+
//| 📝 LOG LEVEL - Livello di logging                                |
//+------------------------------------------------------------------+
enum ENUM_LOG_LEVEL {
    LOG_DEBUG,                  // Debug - Tutto
    LOG_INFO,                   // Info - Informazioni generali
    LOG_WARNING,                // Warning - Avvisi
    LOG_ERROR,                  // Error - Errori
    LOG_SUCCESS                 // Success - Operazioni riuscite
};

//+------------------------------------------------------------------+
//| 🎮 ENTRY MODE - Modalità di ingresso v3.0                        |
//+------------------------------------------------------------------+
enum ENUM_ENTRY_MODE {
    ENTRY_MARKET = 0,           // MARKET - Partenza immediata @ prezzo corrente
    ENTRY_LIMIT = 1,            // LIMIT - Aspetta che prezzo torni a livello
    ENTRY_STOP = 2              // STOP - Aspetta breakout di un livello
};

//+------------------------------------------------------------------+
//| 💰 PARTIAL TP STATUS - REMOVED (v5.x cleanup)                    |
//| Dannoso per Cyclic Reopen                                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 📍 MANUAL SR LINE TYPE - Tipo linea S/R manuale v3.0             |
//+------------------------------------------------------------------+
enum ENUM_SR_LINE_TYPE {
    SR_RESISTANCE = 0,          // Linea Resistance
    SR_SUPPORT = 1,             // Linea Support
    SR_ACTIVATION = 2           // Linea Activation (per LIMIT/STOP mode)
};

//+------------------------------------------------------------------+
//| 🎮 BUTTON STATE - Stato bottoni v3.0                             |
//+------------------------------------------------------------------+
enum ENUM_BUTTON_STATE {
    BTN_STATE_IDLE = 0,         // Bottone inattivo
    BTN_STATE_WAITING = 1,      // In attesa di attivazione (LIMIT/STOP)
    BTN_STATE_ACTIVE = 2        // Sistema attivo
};

//+------------------------------------------------------------------+
//| NOTE: Color inputs moved to Config/InputParameters.mqh           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 🎯 STRADDLE MULTIPLIER - Moltiplicatore lot Straddle (v6.0)      |
//+------------------------------------------------------------------+
enum ENUM_STRADDLE_MULTIPLIER {
    STRADDLE_MULT_1_5X = 0,     // 1.5× (Conservativo - BE più lento)
    STRADDLE_MULT_2X = 1        // 2× (Standard - BE più veloce)
};

//+------------------------------------------------------------------+
//| CONSTANTS - Costanti di sistema                                  |
//+------------------------------------------------------------------+
const int MAX_GRID_LEVELS = 20;           // Max livelli per lato (v9.0: Esteso a 20)
const int MAX_TOTAL_ORDERS = 40;          // Max ordini totali (Grid A + Grid B)
const double MIN_SPACING_PIPS = 10.0;     // Spacing minimo (pips)
const double MAX_SPACING_PIPS = 100.0;    // Spacing massimo (pips)
const int ATR_RECALC_HOURS = 4;           // Ore tra ricalcoli ATR
const int DEFAULT_COOLDOWN_SEC = 120;     // Cooldown default cyclic (secondi)

//+------------------------------------------------------------------+
//| MAGIC NUMBER OFFSETS                                             |
//+------------------------------------------------------------------+
const int MAGIC_OFFSET_GRID_A = 0;        // Grid A: MagicNumber + 0
const int MAGIC_OFFSET_GRID_B = 10000;    // Grid B: MagicNumber + 10000

// Shield Magic Numbers REMOVED in v9.12

