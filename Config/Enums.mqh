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
    NEUTRAL_CASCADE = 1,        // 2. CASCADE - TP=Entry precedente, ATR opzionale (CONSIGLIATO)
    NEUTRAL_RANGEBOX = 2        // 3. RANGEBOX - Range Box + Hedge, ATR opzionale (Produzione)
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
    PAIR_CUSTOM     // ⚙️ Custom (Impostazioni Manuali)
};

//+------------------------------------------------------------------+
//| 📦 RANGEBOX MODE - Calcolo Range Box (solo RANGEBOX)             |
//+------------------------------------------------------------------+
enum ENUM_RANGEBOX_MODE {
    RANGEBOX_MANUAL = 0,        // Manuale - Resistance/Support inseriti
    RANGEBOX_DAILY_HL = 1,      // Daily High/Low - Ultimi N giorni (CONSIGLIATO)
    RANGEBOX_ATR_BASED = 2      // ATR Based - Centro ± (ATR × Multiplier)
};

//+------------------------------------------------------------------+
//| 🛡️ HEDGE DIRECTION - Direzione hedge attivo (solo RANGEBOX)      |
//+------------------------------------------------------------------+
enum ENUM_HEDGE_DIRECTION {
    HEDGE_NONE = 0,             // Nessun hedge attivo
    HEDGE_LONG = 1,             // Hedge LONG (breakout sotto Support)
    HEDGE_SHORT = 2             // Hedge SHORT (breakout sopra Resistance)
};

//+------------------------------------------------------------------+
//| 📏 SPACING MODE - Modalità calcolo spacing griglia               |
//+------------------------------------------------------------------+
enum ENUM_SPACING_MODE {
    SPACING_FIXED,              // Fixed - Spacing fisso in pips
    SPACING_ATR,                // ATR Based - Spacing basato su ATR (CONSIGLIATO)
    SPACING_GEOMETRIC           // Geometric - Spacing % del prezzo
};

//+------------------------------------------------------------------+
//| 💰 LOT MODE - Modalità calcolo lot size                          |
//+------------------------------------------------------------------+
enum ENUM_LOT_MODE {
    LOT_FIXED,                  // Fixed - Lot size fisso per tutti i livelli
    LOT_PROGRESSIVE             // Progressive - Lot crescente per livello (CONSIGLIATO)
};

//+------------------------------------------------------------------+
//| 🎯 CASCADE MODE - Modalità cascade per Take Profit               |
//+------------------------------------------------------------------+
enum ENUM_CASCADE_MODE {
    CASCADE_PERFECT,            // Perfect - TP = Entry livello precedente (CONSIGLIATO)
    CASCADE_RATIO               // Ratio - TP = Spacing × Ratio
};

//+------------------------------------------------------------------+
//| 🔄 REOPEN TRIGGER - Trigger per riapertura ciclica               |
//+------------------------------------------------------------------+
enum ENUM_REOPEN_TRIGGER {
    REOPEN_PRICE_LEVEL,         // Price Level - Riapre quando prezzo torna al livello
    REOPEN_TIME_BASED,          // Time Based - Riapre dopo X secondi
    REOPEN_HYBRID               // Hybrid - Price Level + Time Based
};

//+------------------------------------------------------------------+
//| ⚙️ SYSTEM STATE - Stati del sistema                              |
//+------------------------------------------------------------------+
enum ENUM_SYSTEM_STATE {
    STATE_IDLE,                 // Sistema inattivo
    STATE_INITIALIZING,         // Inizializzazione in corso
    STATE_ACTIVE,               // Sistema attivo e operativo
    STATE_PAUSED,               // Sistema in pausa
    STATE_CLOSING,              // Chiusura posizioni in corso
    STATE_ERROR                 // Stato di errore
};

//+------------------------------------------------------------------+
//| 📋 ORDER STATUS - Stati degli ordini grid                        |
//+------------------------------------------------------------------+
enum ENUM_ORDER_STATUS {
    ORDER_NONE,                 // Nessun ordine
    ORDER_PENDING,              // Ordine pending piazzato
    ORDER_FILLED,               // Ordine eseguito (posizione aperta)
    ORDER_CLOSED,               // Ordine chiuso (TP/SL hit)
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
//| 🎨 COLOR SCHEME - Colori configurabili Grid Lines                |
//+------------------------------------------------------------------+
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎨 COLOR SCHEME - Grid Lines (User Configurable)        ║"
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

//+------------------------------------------------------------------+
//| CONSTANTS - Costanti di sistema                                  |
//+------------------------------------------------------------------+
const int MAX_GRID_LEVELS = 10;           // Max livelli per lato
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
const int MAGIC_HEDGE_LONG = 9001;        // Hedge LONG
const int MAGIC_HEDGE_SHORT = 9002;       // Hedge SHORT

