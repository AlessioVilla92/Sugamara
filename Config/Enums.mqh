//+------------------------------------------------------------------+
//|                                                      Enums.mqh   |
//|                        Sugamara - Enumerations                   |
//|                                                                  |
//|  All system enumerations for Double Grid Neutral                 |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| PAIR SELECTION - Ottimizzate per mercati laterali                |
//+------------------------------------------------------------------+
enum ENUM_NEUTRAL_PAIR {
    NEUTRAL_EURUSD,     // EUR/USD (Spread: 0.5-1 pip, Range: 80-120 pips/day)
    NEUTRAL_AUDNZD,     // AUD/NZD (Spread: 2-4 pips, Range: 50-80 pips/day) - BEST
    NEUTRAL_EURCHF,     // EUR/CHF (Spread: 1-2 pips, Range: 40-60 pips/day)
    NEUTRAL_AUDCAD,     // AUD/CAD (Spread: 2-3 pips, Range: 60-90 pips/day)
    NEUTRAL_NZDCAD,     // NZD/CAD (Spread: 2-3 pips, Range: 50-80 pips/day)
    NEUTRAL_CUSTOM      // Custom (Manual Settings)
};

//+------------------------------------------------------------------+
//| SYSTEM STATE - Stati del sistema Double Grid                     |
//+------------------------------------------------------------------+
enum ENUM_SYSTEM_STATE {
    STATE_IDLE,             // Sistema in attesa
    STATE_INITIALIZING,     // Inizializzazione grid
    STATE_ACTIVE,           // Grid A + Grid B attive
    STATE_PAUSED,           // Pausa (high volatility)
    STATE_CLOSING,          // Chiusura in corso
    STATE_ERROR             // Errore critico
};

//+------------------------------------------------------------------+
//| GRID SIDE - Identificazione lato grid                            |
//+------------------------------------------------------------------+
enum ENUM_GRID_SIDE {
    GRID_A,     // Grid A - Long Bias (Buy Limit sopra, Sell Stop sotto)
    GRID_B      // Grid B - Short Bias (Sell Limit sopra, Buy Stop sotto)
};

//+------------------------------------------------------------------+
//| GRID ZONE - Zona relativa al prezzo entry                        |
//+------------------------------------------------------------------+
enum ENUM_GRID_ZONE {
    ZONE_UPPER,     // Zona Superiore (sopra Entry Point)
    ZONE_LOWER      // Zona Inferiore (sotto Entry Point)
};

//+------------------------------------------------------------------+
//| LOT MODE - Modalita calcolo lotti                                |
//+------------------------------------------------------------------+
enum ENUM_LOT_MODE {
    LOT_UNIFORM,        // Lot Uniforme (stesso lot per tutti i livelli)
    LOT_PROGRESSIVE     // Lot Progressivo (aumenta con distanza da entry)
};

//+------------------------------------------------------------------+
//| SPACING MODE - Modalita calcolo spacing                          |
//+------------------------------------------------------------------+
enum ENUM_SPACING_MODE {
    SPACING_FIXED,      // Spacing Fisso (pips manuali)
    SPACING_ATR,        // Spacing Adattivo (basato su ATR)
    SPACING_GEOMETRIC   // Spacing Geometrico (percentuale)
};

//+------------------------------------------------------------------+
//| ATR CONDITION - Condizioni volatilita ATR                        |
//+------------------------------------------------------------------+
enum ENUM_ATR_CONDITION {
    ATR_CALM,       // Mercato Calmo (ATR < 15 pips)
    ATR_NORMAL,     // Volatilita Normale (ATR 15-30 pips)
    ATR_VOLATILE,   // Mercato Volatile (ATR 30-50 pips)
    ATR_EXTREME     // Volatilita Estrema (ATR > 50 pips)
};

//+------------------------------------------------------------------+
//| ORDER STATUS - Stato ordini grid                                 |
//+------------------------------------------------------------------+
enum ENUM_ORDER_STATUS {
    ORDER_NONE,         // Nessun ordine
    ORDER_PENDING,      // Ordine pending (Limit/Stop)
    ORDER_FILLED,       // Posizione aperta
    ORDER_CLOSED_TP,    // Chiuso in Take Profit
    ORDER_CLOSED_SL,    // Chiuso in Stop Loss
    ORDER_CANCELLED     // Ordine cancellato
};

//+------------------------------------------------------------------+
//| CASCADE MODE - Modalita Perfect Cascade                          |
//+------------------------------------------------------------------+
enum ENUM_CASCADE_MODE {
    CASCADE_OFF,        // Cascade disabilitato (TP fisso)
    CASCADE_PERFECT,    // Perfect Cascade (TP = Entry successivo)
    CASCADE_RATIO       // Cascade Ratio (TP = Spacing × ratio)
};

//+------------------------------------------------------------------+
//| LOG TYPE - Tipi di log per debugging                             |
//+------------------------------------------------------------------+
enum ENUM_LOG_TYPE {
    LOG_INFO,       // Informazione generale
    LOG_SUCCESS,    // Operazione riuscita
    LOG_WARNING,    // Avviso
    LOG_ERROR,      // Errore
    LOG_DEBUG       // Debug dettagliato
};

//+------------------------------------------------------------------+
//| REOPEN TRIGGER - Trigger per cyclic reopening                    |
//+------------------------------------------------------------------+
enum ENUM_REOPEN_TRIGGER {
    REOPEN_IMMEDIATE,       // Immediato dopo cooldown
    REOPEN_PRICE_LEVEL,     // Quando prezzo torna a livello
    REOPEN_ATR_CONFIRM      // Conferma ATR favorevole
};

//+------------------------------------------------------------------+
//| COLOR SCHEME - Colori per Dashboard e Chart Objects              |
//+------------------------------------------------------------------+

// Grid A Colors (Long Bias - Toni Blu/Verde)
const color COLOR_GRID_A_ENTRY = clrDodgerBlue;       // Entry point Grid A
const color COLOR_GRID_A_UPPER = clrLightSkyBlue;     // Zona superiore Grid A
const color COLOR_GRID_A_LOWER = clrSteelBlue;        // Zona inferiore Grid A
const color COLOR_GRID_A_TP = clrLimeGreen;           // Take Profit Grid A
const color COLOR_GRID_A_SL = clrOrangeRed;           // Stop Loss Grid A

// Grid B Colors (Short Bias - Toni Rosso/Arancio)
const color COLOR_GRID_B_ENTRY = clrOrange;           // Entry point Grid B
const color COLOR_GRID_B_UPPER = clrCoral;            // Zona superiore Grid B
const color COLOR_GRID_B_LOWER = clrSalmon;           // Zona inferiore Grid B
const color COLOR_GRID_B_TP = clrGold;                // Take Profit Grid B
const color COLOR_GRID_B_SL = clrCrimson;             // Stop Loss Grid B

// System Colors
const color COLOR_ENTRY_POINT = clrWhite;             // Entry Point centrale
const color COLOR_RANGE_UPPER = clrLightGray;         // Limite superiore range
const color COLOR_RANGE_LOWER = clrDarkGray;          // Limite inferiore range
const color COLOR_NEUTRAL = clrYellow;                // Esposizione neutra
const color COLOR_PROFIT = clrLime;                   // Profitto
const color COLOR_LOSS = clrRed;                      // Perdita

// Dashboard Colors
const color COLOR_PANEL_BG = C'32,32,32';             // Sfondo pannello
const color COLOR_PANEL_BORDER = C'64,64,64';         // Bordo pannello
const color COLOR_TEXT_HEADER = clrWhite;             // Testo header
const color COLOR_TEXT_NORMAL = clrSilver;            // Testo normale
const color COLOR_TEXT_HIGHLIGHT = clrAqua;           // Testo evidenziato

//+------------------------------------------------------------------+
//| MAGIC NUMBER OFFSETS - Per distinguere Grid A da Grid B          |
//+------------------------------------------------------------------+
const int MAGIC_OFFSET_GRID_A = 0;        // Grid A: MagicNumber + 0
const int MAGIC_OFFSET_GRID_B = 10000;    // Grid B: MagicNumber + 10000

//+------------------------------------------------------------------+
//| CONSTANTS - Costanti di sistema                                  |
//+------------------------------------------------------------------+
const int MAX_GRID_LEVELS = 10;           // Max livelli per lato (10 + 10 = 20 ordini)
const int MAX_TOTAL_ORDERS = 20;          // Max ordini totali (Grid A + Grid B)
const double MIN_SPACING_PIPS = 10.0;     // Spacing minimo (pips)
const double MAX_SPACING_PIPS = 100.0;    // Spacing massimo (pips)
const int ATR_RECALC_HOURS = 4;           // Ore tra ricalcoli ATR
const int DEFAULT_COOLDOWN_SEC = 120;     // Cooldown default cyclic (secondi)

