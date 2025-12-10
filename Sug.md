# 🛡️ SUGAMARA - IMPLEMENTAZIONE COMPLETA
# Sistema Shield Intelligente + Funzionalità Mancanti

**Versione:** 2.0 FINAL  
**Data:** Dicembre 2025  
**Obiettivo:** Implementazione completa EA con Shield Intelligente (Simple + 3 Fasi)

---

# ⚠️ ISTRUZIONI PRELIMINARI IMPORTANTI

## COSA RIMUOVERE (Hedge Base - DA ELIMINARE)

Prima di implementare, **RIMUOVERE** ogni traccia dell'Hedge Base dal codice esistente:

```cpp
// ❌ ELIMINARE QUESTI INPUT:
input double Hedge_Multiplier = 1.0;    // RIMUOVERE
input double Hedge_TP_Pips = 20.0;      // RIMUOVERE  
input double Hedge_SL_Pips = 10.0;      // RIMUOVERE

// ❌ ELIMINARE QUESTE FUNZIONI (se presenti):
OpenHedgePosition()      // RIMUOVERE
CloseHedgePosition()     // RIMUOVERE - sostituire con CloseShield()
ActivateHedgeLong()      // RIMUOVERE - sostituire con ActivateShieldLong()
ActivateHedgeShort()     // RIMUOVERE - sostituire con ActivateShieldShort()

// ❌ ELIMINARE QUESTI MAGIC NUMBERS:
MAGIC_HEDGE_LONG = 9001  // RIMUOVERE - sostituire con MAGIC_SHIELD_LONG
MAGIC_HEDGE_SHORT = 9002 // RIMUOVERE - sostituire con MAGIC_SHIELD_SHORT
```

## COSA IMPLEMENTARE

Questo documento contiene **TUTTO** il codice necessario per:

1. ✅ ENUM_NEUTRAL_MODE (PURE, CASCADE, RANGEBOX)
2. ✅ ENUM_SHIELD_MODE (SHIELD_SIMPLE, SHIELD_3_PHASES)
3. ✅ Switch logica OnInit()/OnTick() per modalità
4. ✅ RangeBoxManager.mqh completo
5. ✅ ShieldManager.mqh con entrambe le versioni
6. ✅ Dashboard aggiornata per Shield
7. ✅ Tutte le variabili globali necessarie

---

# INDICE

1. [PARTE 1: Architettura File System](#parte-1-architettura-file-system)
2. [PARTE 2: Enums Completi](#parte-2-enums-completi)
3. [PARTE 3: Input Parameters](#parte-3-input-parameters)
4. [PARTE 4: Variabili Globali](#parte-4-variabili-globali)
5. [PARTE 5: RangeBoxManager.mqh](#parte-5-rangeboxmanagermqh)
6. [PARTE 6: ShieldManager.mqh](#parte-6-shieldmanagermqh)
7. [PARTE 7: Logica Switch Modalità](#parte-7-logica-switch-modalità)
8. [PARTE 8: Dashboard Aggiornata](#parte-8-dashboard-aggiornata)
9. [PARTE 9: Checklist Implementazione](#parte-9-checklist-implementazione)

---

# PARTE 1: ARCHITETTURA FILE SYSTEM

## Struttura Aggiornata

```
/Experts/Sugamara/
│
├── Sugamara.mq5                     # File principale EA
│
├── Config/
│   ├── Enums.mqh                    # ⭐ AGGIORNATO con ENUM_SHIELD_MODE
│   ├── InputParameters.mqh          # ⭐ AGGIORNATO con Shield params
│   └── PairPresets.mqh              # Preset per coppie
│
├── Core/
│   ├── GlobalVariables.mqh          # ⭐ AGGIORNATO con Shield vars
│   ├── Initialization.mqh           # Inizializzazione
│   ├── ModeLogic.mqh                # ⭐ NUOVO - Logica switch modalità
│   └── BrokerValidation.mqh         # Validazione broker
│
├── Utils/
│   ├── Helpers.mqh                  # Helper generiche
│   ├── GridHelpers.mqh              # Helper griglia
│   └── ATRCalculator.mqh            # Calcolo ATR
│
├── Trading/
│   ├── GridASystem.mqh              # Grid A - Long Bias
│   ├── GridBSystem.mqh              # Grid B - Short Bias
│   ├── CascadeManager.mqh           # Perfect Cascade Logic
│   ├── AdaptiveSpacing.mqh          # ATR-based Spacing
│   ├── NeutralManager.mqh           # Bilanciamento
│   ├── RangeBoxManager.mqh          # ⭐ NUOVO - Range Box completo
│   └── ShieldManager.mqh            # ⭐ NUOVO - Shield Intelligente
│
├── UI/
│   └── Dashboard.mqh                # ⭐ AGGIORNATO con Shield panel
│
└── Indicators/
    └── ATRMonitor.mqh               # Monitor ATR
```

---

# PARTE 2: ENUMS COMPLETI

## File: Config/Enums.mqh

```cpp
//+------------------------------------------------------------------+
//|                                                      Enums.mqh   |
//|                        SUGAMARA - Enumerations                   |
//|                        v2.0 - Shield Intelligente                |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property strict

#ifndef ENUMS_MQH
#define ENUMS_MQH

//+------------------------------------------------------------------+
//| ⭐ MODALITÀ PRINCIPALE GRIDBOT                                    |
//+------------------------------------------------------------------+
enum ENUM_NEUTRAL_MODE
{
   NEUTRAL_PURE = 0,           // 1. PURE - Spacing fisso, TP fisso, NO ATR
   NEUTRAL_CASCADE = 1,        // 2. CASCADE - TP=Entry precedente, ATR opzionale
   NEUTRAL_RANGEBOX = 2        // 3. RANGEBOX - CASCADE + Range Box + Shield
};

//+------------------------------------------------------------------+
//| ⭐ MODALITÀ SHIELD INTELLIGENTE (Solo per RANGEBOX)              |
//+------------------------------------------------------------------+
enum ENUM_SHIELD_MODE
{
   SHIELD_DISABLED = 0,        // Shield Disabilitato
   SHIELD_SIMPLE = 1,          // Shield Simple (1 fase - attivazione diretta)
   SHIELD_3_PHASES = 2         // Shield 3 Fasi (Warning → Pre-Shield → Attivo)
};

//+------------------------------------------------------------------+
//| TIPO SHIELD ATTIVO                                               |
//+------------------------------------------------------------------+
enum ENUM_SHIELD_TYPE
{
   SHIELD_NONE = 0,            // Nessuno shield attivo
   SHIELD_LONG = 1,            // Shield LONG (protegge SHORT in perdita)
   SHIELD_SHORT = 2            // Shield SHORT (protegge LONG in perdita)
};

//+------------------------------------------------------------------+
//| FASE SHIELD (Solo per SHIELD_3_PHASES)                           |
//+------------------------------------------------------------------+
enum ENUM_SHIELD_PHASE
{
   PHASE_NORMAL = 0,           // Operatività normale (dentro range)
   PHASE_WARNING = 1,          // Fase 1: Warning Zone (alert)
   PHASE_PRE_SHIELD = 2,       // Fase 2: Pre-Shield (pending pronto)
   PHASE_SHIELD_ACTIVE = 3     // Fase 3: Shield Attivo (protezione)
};

//+------------------------------------------------------------------+
//| DIREZIONE BREAKOUT                                               |
//+------------------------------------------------------------------+
enum ENUM_BREAKOUT_DIRECTION
{
   BREAKOUT_NONE = 0,          // Nessun breakout
   BREAKOUT_UP = 1,            // Breakout verso l'alto
   BREAKOUT_DOWN = 2           // Breakout verso il basso
};

//+------------------------------------------------------------------+
//| MODALITÀ RANGE BOX                                               |
//+------------------------------------------------------------------+
enum ENUM_RANGEBOX_MODE
{
   RANGEBOX_MANUAL = 0,        // Manuale - Resistance/Support inseriti
   RANGEBOX_DAILY_HL = 1,      // Daily High/Low automatico
   RANGEBOX_ATR_BASED = 2      // ATR × Multiplier dal centro
};

//+------------------------------------------------------------------+
//| STATO DEL SISTEMA                                                |
//+------------------------------------------------------------------+
enum ENUM_SYSTEM_STATE
{
   // Stati base
   STATE_INIT = 0,             // Inizializzazione
   STATE_IDLE = 1,             // Inattivo
   STATE_RUNNING = 2,          // Operativo normale
   STATE_PAUSED = 3,           // In pausa
   
   // Stati Range (RANGEBOX mode)
   STATE_INSIDE_RANGE = 10,    // Dentro il range (normale)
   STATE_WARNING_UP = 11,      // Warning zona superiore
   STATE_WARNING_DOWN = 12,    // Warning zona inferiore
   
   // Stati Breakout
   STATE_BREAKOUT_UP = 20,     // Breakout sopra
   STATE_BREAKOUT_DOWN = 21,   // Breakout sotto
   
   // Stati Shield
   STATE_SHIELD_PENDING = 30,  // Shield pending (pronto)
   STATE_SHIELD_LONG = 31,     // Shield LONG attivo
   STATE_SHIELD_SHORT = 32,    // Shield SHORT attivo
   
   // Stati Reentry
   STATE_REENTRY = 40,         // Rientro nel range
   
   // Stati Emergency
   STATE_EMERGENCY = 90,       // Emergency stop
   STATE_ERROR = 99            // Errore
};

//+------------------------------------------------------------------+
//| SELEZIONE COPPIA                                                 |
//+------------------------------------------------------------------+
enum ENUM_PAIR_SELECTION
{
   PAIR_EURUSD,                // EUR/USD
   PAIR_AUDNZD,                // AUD/NZD
   PAIR_EURCHF,                // EUR/CHF
   PAIR_USDCAD,                // USD/CAD
   PAIR_CUSTOM                 // Custom
};

//+------------------------------------------------------------------+
//| LIVELLO ATR                                                      |
//+------------------------------------------------------------------+
enum ENUM_ATR_LEVEL
{
   ATR_VERY_LOW,               // ATR < 15 pips
   ATR_LOW,                    // ATR 15-30 pips
   ATR_MEDIUM,                 // ATR 30-50 pips
   ATR_HIGH                    // ATR > 50 pips
};

//+------------------------------------------------------------------+
//| MAGIC NUMBERS                                                    |
//+------------------------------------------------------------------+
#define MAGIC_GRID_A_BASE      1000    // Grid A: MagicNumber + 1000 + Level
#define MAGIC_GRID_B_BASE      2000    // Grid B: MagicNumber + 2000 + Level
#define MAGIC_SHIELD_LONG      9001    // Shield LONG
#define MAGIC_SHIELD_SHORT     9002    // Shield SHORT

//+------------------------------------------------------------------+
//| COLORI                                                           |
//+------------------------------------------------------------------+
#define COLOR_GRID_A           clrDodgerBlue
#define COLOR_GRID_B           clrOrangeRed
#define COLOR_ENTRY_POINT      clrYellow
#define COLOR_RANGE_BOX        clrGold
#define COLOR_BREAKOUT_LEVEL   clrRed
#define COLOR_REENTRY_LEVEL    clrLime
#define COLOR_WARNING_ZONE     clrOrange
#define COLOR_SHIELD_ACTIVE    clrMagenta

#endif // ENUMS_MQH
```

---

# PARTE 3: INPUT PARAMETERS

## File: Config/InputParameters.mqh

```cpp
//+------------------------------------------------------------------+
//|                                         InputParameters.mqh      |
//|                      SUGAMARA - Input Parameters v2.0            |
//|                      Shield Intelligente Edition                  |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property strict

#ifndef INPUT_PARAMETERS_MQH
#define INPUT_PARAMETERS_MQH

//╔═════════════════════════════════════════════════════════════════╗
//║                    MODALITÀ PRINCIPALE                          ║
//╚═════════════════════════════════════════════════════════════════╝
input group "═══════════════ MODALITÀ SISTEMA ═══════════════"
input ENUM_NEUTRAL_MODE NeutralMode = NEUTRAL_CASCADE;  // Modalità Operativa
input bool UseATR = false;                               // Usa ATR Adattivo (CASCADE/RANGEBOX)

//╔═════════════════════════════════════════════════════════════════╗
//║                    PAIR SELECTION                               ║
//╚═════════════════════════════════════════════════════════════════╝
input group "═══════════════ PAIR SELECTION ═══════════════"
input ENUM_PAIR_SELECTION SelectedPair = PAIR_EURUSD;   // Coppia da Tradare
input int MagicNumber = 777777;                          // Magic Number

//╔═════════════════════════════════════════════════════════════════╗
//║                    PURE MODE (Solo se NeutralMode = PURE)       ║
//╚═════════════════════════════════════════════════════════════════╝
input group "═══════════════ PURE MODE ═══════════════"
input double Pure_Spacing_Pips = 20.0;                  // Spacing Fisso (pips)
input double Pure_TP_Pips = 24.0;                       // Take Profit Fisso (pips)
input double Pure_Lot_Size = 0.01;                      // Lot Size Fisso

//╔═════════════════════════════════════════════════════════════════╗
//║                    ATR ADAPTIVE (CASCADE/RANGEBOX)              ║
//╚═════════════════════════════════════════════════════════════════╝
input group "═══════════════ ATR ADAPTIVE ═══════════════"
input int ATR_Period = 14;                              // ATR Period
input ENUM_TIMEFRAMES ATR_Timeframe = PERIOD_H4;        // ATR Timeframe
input double ATR_Multiplier = 0.8;                      // ATR Multiplier
input int ATR_RecalcMinutes = 240;                      // Ricalcolo ogni N minuti

// Spacing thresholds
input double Spacing_VeryLow = 15;                      // Spacing ATR < 15 pips
input double Spacing_Low = 20;                          // Spacing ATR 15-30 pips
input double Spacing_Medium = 30;                       // Spacing ATR 30-50 pips
input double Spacing_High = 40;                         // Spacing ATR > 50 pips

//╔═════════════════════════════════════════════════════════════════╗
//║                    GRID CONFIGURATION                           ║
//╚═════════════════════════════════════════════════════════════════╝
input group "═══════════════ GRID CONFIGURATION ═══════════════"
input int Grids_Per_Side = 8;                           // Livelli Grid per Lato
input double Spacing_Expansion = 1.08;                  // Fattore Espansione Spacing

//╔═════════════════════════════════════════════════════════════════╗
//║                    LOT SIZING                                   ║
//╚═════════════════════════════════════════════════════════════════╝
input group "═══════════════ LOT SIZING ═══════════════"
input double Lot_Base = 0.01;                           // Lot Base
input double Lot_Multiplier = 1.12;                     // Moltiplicatore Progressivo
input double Lot_Max = 0.50;                            // Lot Massimo

//╔═════════════════════════════════════════════════════════════════╗
//║                    RANGE BOX (Solo RANGEBOX mode)               ║
//╚═════════════════════════════════════════════════════════════════╝
input group "═══════════════ RANGE BOX ═══════════════"
input ENUM_RANGEBOX_MODE RangeBoxMode = RANGEBOX_DAILY_HL; // Modalità Range Box
input double Manual_Resistance = 0.0;                   // Resistance Manuale (0=auto)
input double Manual_Support = 0.0;                      // Support Manuale (0=auto)
input int RangeBox_Period = 20;                         // Periodo Calcolo (barre)
input double RangeBox_ATR_Mult = 3.0;                   // Multiplier ATR per Range
input bool DrawRangeBox = true;                         // Disegna Range Box su Chart

//╔═════════════════════════════════════════════════════════════════╗
//║              🛡️ SHIELD INTELLIGENTE (Solo RANGEBOX)             ║
//╚═════════════════════════════════════════════════════════════════╝
input group "═══════════════ 🛡️ SHIELD INTELLIGENTE ═══════════════"
input ENUM_SHIELD_MODE ShieldMode = SHIELD_3_PHASES;    // Modalità Shield
input double Breakout_Buffer_Pips = 20.0;               // Buffer Breakout oltre ultimo grid
input double Reentry_Buffer_Pips = 30.0;                // Buffer Rientro nel range
input int Breakout_Confirm_Candles = 2;                 // Candele Conferma Breakout
input bool Use_Candle_Close = true;                     // Usa Chiusura Candela per Conferma

// Shield 3 Fasi - Parametri specifici
input group "═══════════════ SHIELD 3 FASI ═══════════════"
input double Warning_Zone_Percent = 10.0;               // Warning Zone (% dal bordo)
input bool Shield_Use_Trailing = false;                 // Trailing per Shield
input double Shield_Trailing_Start = 30.0;              // Trailing Start (pips)
input double Shield_Trailing_Step = 10.0;               // Trailing Step (pips)

//╔═════════════════════════════════════════════════════════════════╗
//║                    CYCLIC REOPEN                                ║
//╚═════════════════════════════════════════════════════════════════╝
input group "═══════════════ CYCLIC REOPEN ═══════════════"
input bool Enable_CyclicReopen = true;                  // Abilita Riapertura Ciclica
input int CyclicReopen_Delay = 300;                     // Delay Riapertura (secondi)

//╔═════════════════════════════════════════════════════════════════╗
//║                    RISK MANAGEMENT                              ║
//╚═════════════════════════════════════════════════════════════════╝
input group "═══════════════ RISK MANAGEMENT ═══════════════"
input bool EnableEmergencyStop = true;                  // Abilita Emergency Stop
input double EmergencyStop_Percent = 20.0;              // Emergency Stop DD%
input double NetExposure_Alert_Percent = 10.0;          // Alert Esposizione Netta %

//╔═════════════════════════════════════════════════════════════════╗
//║                    CAPITAL REQUIREMENTS                         ║
//╚═════════════════════════════════════════════════════════════════╝
input group "═══════════════ CAPITAL ═══════════════"
input double Capital_Minimum = 6000.0;                  // Capitale Minimo Richiesto

//╔═════════════════════════════════════════════════════════════════╗
//║                    DISPLAY OPTIONS                              ║
//╚═════════════════════════════════════════════════════════════════╝
input group "═══════════════ DISPLAY ═══════════════"
input bool ShowDashboard = true;                        // Mostra Dashboard
input bool ShowGridLines = true;                        // Mostra Linee Grid
input bool EnableAlerts = true;                         // Abilita Alert
input bool EnablePushNotifications = false;             // Notifiche Push
input bool DetailedLogging = true;                      // Log Dettagliato

//╔═════════════════════════════════════════════════════════════════╗
//║                    BROKER SETTINGS                              ║
//╚═════════════════════════════════════════════════════════════════╝
input group "═══════════════ BROKER ═══════════════"
input int Slippage = 5;                                 // Slippage (points)

#endif // INPUT_PARAMETERS_MQH
```

---

# PARTE 4: VARIABILI GLOBALI

## File: Core/GlobalVariables.mqh

```cpp
//+------------------------------------------------------------------+
//|                                          GlobalVariables.mqh     |
//|                      SUGAMARA - Global Variables v2.0            |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property strict

#ifndef GLOBAL_VARIABLES_MQH
#define GLOBAL_VARIABLES_MQH

#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| TRADE OBJECT                                                     |
//+------------------------------------------------------------------+
CTrade trade;

//+------------------------------------------------------------------+
//| SYMBOL INFO                                                      |
//+------------------------------------------------------------------+
double symbolPoint = 0;
int symbolDigits = 0;
double symbolSpread = 0;
double symbolMinLot = 0;
double symbolMaxLot = 0;
double symbolLotStep = 0;

//+------------------------------------------------------------------+
//| SYSTEM STATE                                                     |
//+------------------------------------------------------------------+
ENUM_SYSTEM_STATE currentSystemState = STATE_INIT;
ENUM_NEUTRAL_MODE activeNeutralMode = NEUTRAL_CASCADE;
bool isSystemRunning = false;
datetime systemStartTime = 0;

//+------------------------------------------------------------------+
//| ENTRY POINT                                                      |
//+------------------------------------------------------------------+
double entryPrice = 0;
datetime entryTime = 0;

//+------------------------------------------------------------------+
//| GRID STRUCTURES                                                  |
//+------------------------------------------------------------------+
struct GridLevel {
   int level_number;           // Numero livello (1-N)
   double entry_price;         // Prezzo entry
   double tp_price;            // Prezzo TP
   double lot_size;            // Dimensione lot
   double spacing_pips;        // Spacing usato
   ulong pending_ticket;       // Ticket ordine pending
   ulong filled_ticket;        // Ticket posizione filled
   bool is_filled;             // Flag: posizione aperta
   bool is_closed;             // Flag: posizione chiusa
   datetime fill_time;         // Tempo fill
   double fill_price;          // Prezzo fill effettivo
};

// Grid Arrays
GridLevel gridA_levels[];      // Grid A (Long Bias)
GridLevel gridB_levels[];      // Grid B (Short Bias)

// Grid Counters
int gridA_total_levels = 0;
int gridB_total_levels = 0;
int gridA_filled_count = 0;
int gridB_filled_count = 0;
int gridA_pending_count = 0;
int gridB_pending_count = 0;

// Grid Totals
double gridA_total_lots = 0;
double gridB_total_lots = 0;
double gridA_floating_pl = 0;
double gridB_floating_pl = 0;

//+------------------------------------------------------------------+
//| ATR VARIABLES                                                    |
//+------------------------------------------------------------------+
double currentATR = 0;
double atrPips = 0;
double current_spacing_pips = 0;
ENUM_ATR_LEVEL currentATRLevel = ATR_LOW;
datetime lastATRRecalc = 0;

//+------------------------------------------------------------------+
//| RANGE BOX VARIABLES                                              |
//+------------------------------------------------------------------+
struct RangeBoxData {
   double resistance;          // Livello Resistance
   double support;             // Livello Support
   double center;              // Centro range
   double rangeHeight;         // Altezza range (pips)
   double warningZoneUp;       // Zona warning superiore
   double warningZoneDown;     // Zona warning inferiore
   bool isValid;               // Range valido
   datetime lastCalc;          // Ultimo calcolo
};

RangeBoxData rangeBox;

// Breakout Levels (calcolati da ultimo livello grid)
double upperBreakoutLevel = 0;
double lowerBreakoutLevel = 0;
double upperReentryLevel = 0;
double lowerReentryLevel = 0;

// Breakout Detection
bool isBreakoutUp = false;
bool isBreakoutDown = false;
bool isInsideRange = true;
int breakoutConfirmCounter = 0;
datetime breakoutDetectionTime = 0;
ENUM_BREAKOUT_DIRECTION lastBreakoutDirection = BREAKOUT_NONE;

//+------------------------------------------------------------------+
//| 🛡️ SHIELD INTELLIGENTE VARIABLES                                 |
//+------------------------------------------------------------------+
struct ShieldData {
   bool isActive;              // Shield attivo
   ENUM_SHIELD_TYPE type;      // Tipo (LONG/SHORT)
   ENUM_SHIELD_PHASE phase;    // Fase corrente (per 3 fasi)
   ulong ticket;               // Ticket posizione shield
   double lot_size;            // Lot size shield
   double entry_price;         // Prezzo entry
   double current_pl;          // P/L corrente
   double trailing_sl;         // Trailing SL (se attivo)
   datetime activation_time;   // Tempo attivazione
   int activation_count;       // Contatore attivazioni
};

ShieldData shield;

// Shield Statistics
int totalShieldActivations = 0;
double totalShieldPL = 0;
datetime lastShieldClosure = 0;

//+------------------------------------------------------------------+
//| BALANCE TRACKING                                                 |
//+------------------------------------------------------------------+
double initialBalance = 0;
double highWaterMark = 0;
double maxDrawdownReached = 0;
double dailyStartBalance = 0;
double sessionProfit = 0;

//+------------------------------------------------------------------+
//| STATISTICS                                                       |
//+------------------------------------------------------------------+
struct SessionStats {
   int totalTrades;
   int winTrades;
   int lossTrades;
   double grossProfit;
   double grossLoss;
   double netProfit;
   double winRate;
   double profitFactor;
   double currentDrawdown;
   double maxDrawdown;
   int gridACycles;
   int gridBCycles;
};

SessionStats stats;

//+------------------------------------------------------------------+
//| TIMING                                                           |
//+------------------------------------------------------------------+
datetime lastCyclicCheck = 0;
datetime lastDashboardUpdate = 0;
datetime lastSpacingRecalc = 0;

//+------------------------------------------------------------------+
//| HELPER FUNCTIONS DECLARATIONS                                    |
//+------------------------------------------------------------------+
double PipsToPoints(double pips) {
   if(symbolDigits == 5 || symbolDigits == 3)
      return pips * 10.0 * symbolPoint;
   else
      return pips * symbolPoint;
}

double PointsToPips(double points) {
   if(symbolDigits == 5 || symbolDigits == 3)
      return points / (10.0 * symbolPoint);
   else
      return points / symbolPoint;
}

double NormalizeLot(double lot) {
   lot = MathMax(lot, symbolMinLot);
   lot = MathMin(lot, symbolMaxLot);
   lot = MathFloor(lot / symbolLotStep) * symbolLotStep;
   return NormalizeDouble(lot, 2);
}

#endif // GLOBAL_VARIABLES_MQH
```

---

# PARTE 5: RANGEBOXMANAGER.MQH

## File: Trading/RangeBoxManager.mqh

```cpp
//+------------------------------------------------------------------+
//|                                          RangeBoxManager.mqh     |
//|                        SUGAMARA - Range Box System               |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property strict

#ifndef RANGEBOXMANAGER_MQH
#define RANGEBOXMANAGER_MQH

//+------------------------------------------------------------------+
//| Initialize Range Box                                              |
//+------------------------------------------------------------------+
bool InitializeRangeBox() {
   Print("═══ Initializing Range Box ═══");
   
   // Reset structure
   ZeroMemory(rangeBox);
   
   bool success = false;
   
   switch(RangeBoxMode) {
      case RANGEBOX_MANUAL:
         success = CalculateManualRangeBox();
         break;
         
      case RANGEBOX_DAILY_HL:
         success = CalculateDailyHLRangeBox();
         break;
         
      case RANGEBOX_ATR_BASED:
         success = CalculateATRBasedRangeBox();
         break;
   }
   
   if(success) {
      rangeBox.center = (rangeBox.resistance + rangeBox.support) / 2.0;
      rangeBox.rangeHeight = PointsToPips(rangeBox.resistance - rangeBox.support);
      
      // Calcola Warning Zones (per Shield 3 Fasi)
      double warningBuffer = (rangeBox.resistance - rangeBox.support) * (Warning_Zone_Percent / 100.0);
      rangeBox.warningZoneUp = rangeBox.resistance - warningBuffer;
      rangeBox.warningZoneDown = rangeBox.support + warningBuffer;
      
      rangeBox.isValid = true;
      rangeBox.lastCalc = TimeCurrent();
      
      // Disegna su chart
      if(DrawRangeBox)
         DrawRangeBoxOnChart();
      
      Print("  Mode: ", EnumToString(RangeBoxMode));
      Print("  Resistance: ", DoubleToString(rangeBox.resistance, symbolDigits));
      Print("  Support: ", DoubleToString(rangeBox.support, symbolDigits));
      Print("  Range Height: ", DoubleToString(rangeBox.rangeHeight, 1), " pips");
      Print("  Warning Zone Up: ", DoubleToString(rangeBox.warningZoneUp, symbolDigits));
      Print("  Warning Zone Down: ", DoubleToString(rangeBox.warningZoneDown, symbolDigits));
   }
   
   return success;
}

//+------------------------------------------------------------------+
//| Calculate Manual Range Box                                        |
//+------------------------------------------------------------------+
bool CalculateManualRangeBox() {
   if(Manual_Resistance <= Manual_Support || Manual_Resistance == 0 || Manual_Support == 0) {
      Print("ERROR: Invalid manual Resistance/Support values");
      return false;
   }
   
   rangeBox.resistance = Manual_Resistance;
   rangeBox.support = Manual_Support;
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Daily High/Low Range Box                               |
//+------------------------------------------------------------------+
bool CalculateDailyHLRangeBox() {
   double highestHigh = 0;
   double lowestLow = DBL_MAX;
   
   // Cerca High/Low negli ultimi N giorni
   for(int i = 1; i <= RangeBox_Period; i++) {
      double high = iHigh(_Symbol, PERIOD_D1, i);
      double low = iLow(_Symbol, PERIOD_D1, i);
      
      if(high > highestHigh) highestHigh = high;
      if(low < lowestLow) lowestLow = low;
   }
   
   if(highestHigh <= lowestLow) {
      Print("ERROR: Invalid Daily H/L data");
      return false;
   }
   
   rangeBox.resistance = highestHigh;
   rangeBox.support = lowestLow;
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate ATR-Based Range Box                                     |
//+------------------------------------------------------------------+
bool CalculateATRBasedRangeBox() {
   if(atrPips <= 0) {
      Print("ERROR: Invalid ATR value for Range Box");
      return false;
   }
   
   double rangeDistance = PipsToPoints(atrPips * RangeBox_ATR_Mult);
   
   rangeBox.resistance = NormalizeDouble(entryPrice + rangeDistance, symbolDigits);
   rangeBox.support = NormalizeDouble(entryPrice - rangeDistance, symbolDigits);
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Breakout Levels (from Grid edges)                       |
//+------------------------------------------------------------------+
bool CalculateBreakoutLevels() {
   // Trova l'ultimo livello di Grid B (più alto)
   double highestGridBLevel = 0;
   for(int i = 0; i < gridB_total_levels; i++) {
      if(gridB_levels[i].entry_price > highestGridBLevel) {
         highestGridBLevel = gridB_levels[i].entry_price;
      }
   }
   
   // Trova l'ultimo livello di Grid A (più basso)
   double lowestGridALevel = DBL_MAX;
   for(int i = 0; i < gridA_total_levels; i++) {
      if(gridA_levels[i].entry_price < lowestGridALevel) {
         lowestGridALevel = gridA_levels[i].entry_price;
      }
   }
   
   if(highestGridBLevel == 0 || lowestGridALevel == DBL_MAX) {
      Print("ERROR: Cannot calculate breakout levels - grid not initialized");
      return false;
   }
   
   // Breakout Levels = ultimo livello grid + buffer
   double bufferPoints = PipsToPoints(Breakout_Buffer_Pips);
   upperBreakoutLevel = NormalizeDouble(highestGridBLevel + bufferPoints, symbolDigits);
   lowerBreakoutLevel = NormalizeDouble(lowestGridALevel - bufferPoints, symbolDigits);
   
   // Reentry Levels = breakout - buffer
   double reentryBuffer = PipsToPoints(Reentry_Buffer_Pips);
   upperReentryLevel = NormalizeDouble(upperBreakoutLevel - reentryBuffer, symbolDigits);
   lowerReentryLevel = NormalizeDouble(lowerBreakoutLevel + reentryBuffer, symbolDigits);
   
   Print("═══ Breakout Levels Calculated ═══");
   Print("  Upper Breakout: ", DoubleToString(upperBreakoutLevel, symbolDigits));
   Print("  Lower Breakout: ", DoubleToString(lowerBreakoutLevel, symbolDigits));
   Print("  Upper Reentry: ", DoubleToString(upperReentryLevel, symbolDigits));
   Print("  Lower Reentry: ", DoubleToString(lowerReentryLevel, symbolDigits));
   
   // Disegna livelli
   DrawBreakoutLevels();
   
   return true;
}

//+------------------------------------------------------------------+
//| Get Price Position in Range                                       |
//+------------------------------------------------------------------+
ENUM_SYSTEM_STATE GetPricePositionInRange(double price) {
   if(!rangeBox.isValid) return STATE_RUNNING;
   
   // Check breakout
   if(price >= upperBreakoutLevel) {
      return STATE_BREAKOUT_UP;
   }
   if(price <= lowerBreakoutLevel) {
      return STATE_BREAKOUT_DOWN;
   }
   
   // Check warning zones (per Shield 3 Fasi)
   if(ShieldMode == SHIELD_3_PHASES) {
      if(price >= rangeBox.warningZoneUp) {
         return STATE_WARNING_UP;
      }
      if(price <= rangeBox.warningZoneDown) {
         return STATE_WARNING_DOWN;
      }
   }
   
   // Inside normal range
   return STATE_INSIDE_RANGE;
}

//+------------------------------------------------------------------+
//| Check Breakout Condition                                          |
//+------------------------------------------------------------------+
bool CheckBreakoutCondition(double price, ENUM_BREAKOUT_DIRECTION &direction) {
   direction = BREAKOUT_NONE;
   
   // Check UP
   if(price >= upperBreakoutLevel) {
      if(Use_Candle_Close) {
         if(IsBreakoutConfirmed(BREAKOUT_UP)) {
            direction = BREAKOUT_UP;
            return true;
         }
      } else {
         direction = BREAKOUT_UP;
         return true;
      }
   }
   
   // Check DOWN
   if(price <= lowerBreakoutLevel) {
      if(Use_Candle_Close) {
         if(IsBreakoutConfirmed(BREAKOUT_DOWN)) {
            direction = BREAKOUT_DOWN;
            return true;
         }
      } else {
         direction = BREAKOUT_DOWN;
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if Breakout is Confirmed (N candles)                        |
//+------------------------------------------------------------------+
bool IsBreakoutConfirmed(ENUM_BREAKOUT_DIRECTION direction) {
   int confirmedCandles = 0;
   
   for(int i = 0; i < Breakout_Confirm_Candles; i++) {
      double closePrice = iClose(_Symbol, PERIOD_CURRENT, i);
      
      if(direction == BREAKOUT_UP) {
         if(closePrice > upperBreakoutLevel) {
            confirmedCandles++;
         }
      } else {
         if(closePrice < lowerBreakoutLevel) {
            confirmedCandles++;
         }
      }
   }
   
   return (confirmedCandles >= Breakout_Confirm_Candles);
}

//+------------------------------------------------------------------+
//| Check Reentry Condition                                           |
//+------------------------------------------------------------------+
bool CheckReentryCondition(double price) {
   if(!shield.isActive) return false;
   
   if(shield.type == SHIELD_LONG) {
      // Era breakout DOWN, rientra se prezzo sale sopra reentry level
      if(price > lowerReentryLevel) {
         if(Use_Candle_Close) {
            return IsReentryConfirmed(BREAKOUT_DOWN);
         }
         return true;
      }
   }
   else if(shield.type == SHIELD_SHORT) {
      // Era breakout UP, rientra se prezzo scende sotto reentry level
      if(price < upperReentryLevel) {
         if(Use_Candle_Close) {
            return IsReentryConfirmed(BREAKOUT_UP);
         }
         return true;
      }
   }
   
   return false;
}

//+------------------------------------------------------------------+
//| Check if Reentry is Confirmed                                     |
//+------------------------------------------------------------------+
bool IsReentryConfirmed(ENUM_BREAKOUT_DIRECTION originalDirection) {
   int confirmedCandles = 0;
   
   for(int i = 0; i < Breakout_Confirm_Candles; i++) {
      double closePrice = iClose(_Symbol, PERIOD_CURRENT, i);
      
      if(originalDirection == BREAKOUT_UP) {
         if(closePrice < upperReentryLevel) {
            confirmedCandles++;
         }
      } else {
         if(closePrice > lowerReentryLevel) {
            confirmedCandles++;
         }
      }
   }
   
   return (confirmedCandles >= Breakout_Confirm_Candles);
}

//+------------------------------------------------------------------+
//| Update Range Box (periodic)                                       |
//+------------------------------------------------------------------+
void UpdateRangeBox() {
   if(!rangeBox.isValid) return;
   
   // Per DAILY_HL: aggiorna ogni nuovo giorno
   if(RangeBoxMode == RANGEBOX_DAILY_HL) {
      static datetime lastDailyUpdate = 0;
      datetime currentDay = iTime(_Symbol, PERIOD_D1, 0);
      
      if(currentDay != lastDailyUpdate) {
         CalculateDailyHLRangeBox();
         rangeBox.center = (rangeBox.resistance + rangeBox.support) / 2.0;
         rangeBox.rangeHeight = PointsToPips(rangeBox.resistance - rangeBox.support);
         
         if(DrawRangeBox) DrawRangeBoxOnChart();
         lastDailyUpdate = currentDay;
         
         Print("Range Box updated for new day");
      }
   }
   
   // Per ATR_BASED: aggiorna quando ATR cambia significativamente
   if(RangeBoxMode == RANGEBOX_ATR_BASED) {
      static double lastATRForRangeBox = 0;
      
      if(MathAbs(atrPips - lastATRForRangeBox) > atrPips * 0.2) {
         CalculateATRBasedRangeBox();
         rangeBox.center = (rangeBox.resistance + rangeBox.support) / 2.0;
         rangeBox.rangeHeight = PointsToPips(rangeBox.resistance - rangeBox.support);
         
         if(DrawRangeBox) DrawRangeBoxOnChart();
         lastATRForRangeBox = atrPips;
         
         Print("Range Box updated due to ATR change");
      }
   }
}

//+------------------------------------------------------------------+
//| Draw Range Box on Chart                                           |
//+------------------------------------------------------------------+
void DrawRangeBoxOnChart() {
   // Resistance
   ObjectDelete(0, "SUGAMARA_RESISTANCE");
   ObjectCreate(0, "SUGAMARA_RESISTANCE", OBJ_HLINE, 0, 0, rangeBox.resistance);
   ObjectSetInteger(0, "SUGAMARA_RESISTANCE", OBJPROP_COLOR, clrOrangeRed);
   ObjectSetInteger(0, "SUGAMARA_RESISTANCE", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, "SUGAMARA_RESISTANCE", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "SUGAMARA_RESISTANCE", OBJPROP_TOOLTIP, "Resistance");
   
   // Support
   ObjectDelete(0, "SUGAMARA_SUPPORT");
   ObjectCreate(0, "SUGAMARA_SUPPORT", OBJ_HLINE, 0, 0, rangeBox.support);
   ObjectSetInteger(0, "SUGAMARA_SUPPORT", OBJPROP_COLOR, clrLimeGreen);
   ObjectSetInteger(0, "SUGAMARA_SUPPORT", OBJPROP_STYLE, STYLE_SOLID);
   ObjectSetInteger(0, "SUGAMARA_SUPPORT", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "SUGAMARA_SUPPORT", OBJPROP_TOOLTIP, "Support");
   
   // Center
   ObjectDelete(0, "SUGAMARA_CENTER");
   ObjectCreate(0, "SUGAMARA_CENTER", OBJ_HLINE, 0, 0, rangeBox.center);
   ObjectSetInteger(0, "SUGAMARA_CENTER", OBJPROP_COLOR, clrGold);
   ObjectSetInteger(0, "SUGAMARA_CENTER", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "SUGAMARA_CENTER", OBJPROP_WIDTH, 1);
   
   // Warning Zones (solo per Shield 3 Fasi)
   if(ShieldMode == SHIELD_3_PHASES) {
      ObjectDelete(0, "SUGAMARA_WARNING_UP");
      ObjectCreate(0, "SUGAMARA_WARNING_UP", OBJ_HLINE, 0, 0, rangeBox.warningZoneUp);
      ObjectSetInteger(0, "SUGAMARA_WARNING_UP", OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, "SUGAMARA_WARNING_UP", OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, "SUGAMARA_WARNING_UP", OBJPROP_WIDTH, 1);
      
      ObjectDelete(0, "SUGAMARA_WARNING_DOWN");
      ObjectCreate(0, "SUGAMARA_WARNING_DOWN", OBJ_HLINE, 0, 0, rangeBox.warningZoneDown);
      ObjectSetInteger(0, "SUGAMARA_WARNING_DOWN", OBJPROP_COLOR, clrOrange);
      ObjectSetInteger(0, "SUGAMARA_WARNING_DOWN", OBJPROP_STYLE, STYLE_DOT);
      ObjectSetInteger(0, "SUGAMARA_WARNING_DOWN", OBJPROP_WIDTH, 1);
   }
}

//+------------------------------------------------------------------+
//| Draw Breakout Levels                                              |
//+------------------------------------------------------------------+
void DrawBreakoutLevels() {
   // Upper Breakout
   ObjectDelete(0, "SUGAMARA_UPPER_BREAKOUT");
   ObjectCreate(0, "SUGAMARA_UPPER_BREAKOUT", OBJ_HLINE, 0, 0, upperBreakoutLevel);
   ObjectSetInteger(0, "SUGAMARA_UPPER_BREAKOUT", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, "SUGAMARA_UPPER_BREAKOUT", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "SUGAMARA_UPPER_BREAKOUT", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "SUGAMARA_UPPER_BREAKOUT", OBJPROP_TOOLTIP, "Upper Breakout Level");
   
   // Lower Breakout
   ObjectDelete(0, "SUGAMARA_LOWER_BREAKOUT");
   ObjectCreate(0, "SUGAMARA_LOWER_BREAKOUT", OBJ_HLINE, 0, 0, lowerBreakoutLevel);
   ObjectSetInteger(0, "SUGAMARA_LOWER_BREAKOUT", OBJPROP_COLOR, clrRed);
   ObjectSetInteger(0, "SUGAMARA_LOWER_BREAKOUT", OBJPROP_STYLE, STYLE_DASH);
   ObjectSetInteger(0, "SUGAMARA_LOWER_BREAKOUT", OBJPROP_WIDTH, 2);
   ObjectSetString(0, "SUGAMARA_LOWER_BREAKOUT", OBJPROP_TOOLTIP, "Lower Breakout Level");
   
   // Upper Reentry
   ObjectDelete(0, "SUGAMARA_UPPER_REENTRY");
   ObjectCreate(0, "SUGAMARA_UPPER_REENTRY", OBJ_HLINE, 0, 0, upperReentryLevel);
   ObjectSetInteger(0, "SUGAMARA_UPPER_REENTRY", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, "SUGAMARA_UPPER_REENTRY", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "SUGAMARA_UPPER_REENTRY", OBJPROP_WIDTH, 1);
   
   // Lower Reentry
   ObjectDelete(0, "SUGAMARA_LOWER_REENTRY");
   ObjectCreate(0, "SUGAMARA_LOWER_REENTRY", OBJ_HLINE, 0, 0, lowerReentryLevel);
   ObjectSetInteger(0, "SUGAMARA_LOWER_REENTRY", OBJPROP_COLOR, clrLime);
   ObjectSetInteger(0, "SUGAMARA_LOWER_REENTRY", OBJPROP_STYLE, STYLE_DOT);
   ObjectSetInteger(0, "SUGAMARA_LOWER_REENTRY", OBJPROP_WIDTH, 1);
}

//+------------------------------------------------------------------+
//| Deinitialize Range Box                                            |
//+------------------------------------------------------------------+
void DeinitializeRangeBox() {
   ObjectDelete(0, "SUGAMARA_RESISTANCE");
   ObjectDelete(0, "SUGAMARA_SUPPORT");
   ObjectDelete(0, "SUGAMARA_CENTER");
   ObjectDelete(0, "SUGAMARA_WARNING_UP");
   ObjectDelete(0, "SUGAMARA_WARNING_DOWN");
   ObjectDelete(0, "SUGAMARA_UPPER_BREAKOUT");
   ObjectDelete(0, "SUGAMARA_LOWER_BREAKOUT");
   ObjectDelete(0, "SUGAMARA_UPPER_REENTRY");
   ObjectDelete(0, "SUGAMARA_LOWER_REENTRY");
   
   Print("Range Box deinitialized");
}

#endif // RANGEBOXMANAGER_MQH
```

---

# PARTE 6: SHIELDMANAGER.MQH

## File: Trading/ShieldManager.mqh

```cpp
//+------------------------------------------------------------------+
//|                                            ShieldManager.mqh     |
//|                        SUGAMARA - Shield Intelligente            |
//|                        Simple + 3 Fasi Edition                   |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property strict

#ifndef SHIELDMANAGER_MQH
#define SHIELDMANAGER_MQH

//+------------------------------------------------------------------+
//| Initialize Shield System                                          |
//+------------------------------------------------------------------+
bool InitializeShield() {
   if(ShieldMode == SHIELD_DISABLED) {
      Print("Shield Intelligente: DISABILITATO");
      return true;
   }
   
   Print("═══ Initializing Shield Intelligente ═══");
   Print("  Mode: ", (ShieldMode == SHIELD_SIMPLE ? "SIMPLE (1 Fase)" : "3 FASI"));
   
   // Reset structure
   ZeroMemory(shield);
   shield.isActive = false;
   shield.type = SHIELD_NONE;
   shield.phase = PHASE_NORMAL;
   
   // Calcola breakout levels
   if(!CalculateBreakoutLevels()) {
      Print("ERROR: Failed to calculate breakout levels");
      return false;
   }
   
   Print("  Shield System: READY");
   
   return true;
}

//+------------------------------------------------------------------+
//| Calculate Shield Lot Size = Σ(lot grid esposta)                   |
//+------------------------------------------------------------------+
double CalculateShieldLotSize(ENUM_SHIELD_TYPE shieldType) {
   double totalLots = 0;
   
   if(shieldType == SHIELD_LONG) {
      // Shield LONG protegge tutti gli SHORT (Grid B) aperti
      for(int i = 0; i < gridB_total_levels; i++) {
         if(gridB_levels[i].is_filled) {
            totalLots += gridB_levels[i].lot_size;
         }
      }
   }
   else if(shieldType == SHIELD_SHORT) {
      // Shield SHORT protegge tutti i LONG (Grid A) aperti
      for(int i = 0; i < gridA_total_levels; i++) {
         if(gridA_levels[i].is_filled) {
            totalLots += gridA_levels[i].lot_size;
         }
      }
   }
   
   // Normalizza
   totalLots = NormalizeLot(totalLots);
   
   // Minimo 0.01
   if(totalLots < 0.01) totalLots = 0.01;
   
   return totalLots;
}

//+------------------------------------------------------------------+
//|                    SHIELD SIMPLE (1 FASE)                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Process Shield Simple - Attivazione diretta su breakout          |
//+------------------------------------------------------------------+
void ProcessShieldSimple(double currentPrice) {
   if(shield.isActive) {
      // Shield già attivo - gestisci
      ManageActiveShield(currentPrice);
      return;
   }
   
   // Check breakout
   ENUM_BREAKOUT_DIRECTION direction;
   if(CheckBreakoutCondition(currentPrice, direction)) {
      if(direction == BREAKOUT_UP) {
         ActivateShieldLong("SIMPLE");
      }
      else if(direction == BREAKOUT_DOWN) {
         ActivateShieldShort("SIMPLE");
      }
   }
}

//+------------------------------------------------------------------+
//|                    SHIELD 3 FASI                                 |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Process Shield 3 Fasi - Warning → Pre-Shield → Attivo            |
//+------------------------------------------------------------------+
void ProcessShield3Phases(double currentPrice) {
   // Ottieni stato posizione nel range
   ENUM_SYSTEM_STATE priceState = GetPricePositionInRange(currentPrice);
   
   switch(shield.phase) {
      
      //─────────────────────────────────────────────────────────────
      // FASE 0: NORMALE - Dentro il range
      //─────────────────────────────────────────────────────────────
      case PHASE_NORMAL:
         if(priceState == STATE_WARNING_UP) {
            EnterWarningPhase(BREAKOUT_UP);
         }
         else if(priceState == STATE_WARNING_DOWN) {
            EnterWarningPhase(BREAKOUT_DOWN);
         }
         break;
      
      //─────────────────────────────────────────────────────────────
      // FASE 1: WARNING - Prezzo vicino al bordo
      //─────────────────────────────────────────────────────────────
      case PHASE_WARNING:
         // Se torna dentro, resetta
         if(priceState == STATE_INSIDE_RANGE) {
            ExitWarningPhase();
         }
         // Se supera ultimo livello grid, passa a Pre-Shield
         else if(priceState == STATE_WARNING_UP && currentPrice >= GetLastGridBLevel()) {
            EnterPreShieldPhase(BREAKOUT_UP);
         }
         else if(priceState == STATE_WARNING_DOWN && currentPrice <= GetLastGridALevel()) {
            EnterPreShieldPhase(BREAKOUT_DOWN);
         }
         break;
      
      //─────────────────────────────────────────────────────────────
      // FASE 2: PRE-SHIELD - Ordine pending pronto
      //─────────────────────────────────────────────────────────────
      case PHASE_PRE_SHIELD:
         // Se rientra, cancella pending e torna normale
         if(priceState == STATE_INSIDE_RANGE || priceState == STATE_WARNING_UP || priceState == STATE_WARNING_DOWN) {
            CancelPreShield();
         }
         // Se breakout confermato, attiva shield
         else {
            ENUM_BREAKOUT_DIRECTION direction;
            if(CheckBreakoutCondition(currentPrice, direction)) {
               if(direction == BREAKOUT_UP) {
                  ActivateShieldLong("3_PHASES");
               }
               else if(direction == BREAKOUT_DOWN) {
                  ActivateShieldShort("3_PHASES");
               }
            }
         }
         break;
      
      //─────────────────────────────────────────────────────────────
      // FASE 3: SHIELD ATTIVO - Protezione in corso
      //─────────────────────────────────────────────────────────────
      case PHASE_SHIELD_ACTIVE:
         ManageActiveShield(currentPrice);
         break;
   }
}

//+------------------------------------------------------------------+
//| Enter Warning Phase (Fase 1)                                      |
//+------------------------------------------------------------------+
void EnterWarningPhase(ENUM_BREAKOUT_DIRECTION direction) {
   shield.phase = PHASE_WARNING;
   lastBreakoutDirection = direction;
   
   Print("═══ SHIELD FASE 1: WARNING ═══");
   Print("  Direction: ", (direction == BREAKOUT_UP ? "UP" : "DOWN"));
   
   // Alert
   if(EnableAlerts) {
      Alert("SUGAMARA: Warning Zone - Prezzo vicino al bordo range");
   }
   
   // Update dashboard color
   currentSystemState = (direction == BREAKOUT_UP ? STATE_WARNING_UP : STATE_WARNING_DOWN);
}

//+------------------------------------------------------------------+
//| Exit Warning Phase (torna normale)                                |
//+------------------------------------------------------------------+
void ExitWarningPhase() {
   shield.phase = PHASE_NORMAL;
   lastBreakoutDirection = BREAKOUT_NONE;
   currentSystemState = STATE_INSIDE_RANGE;
   
   Print("Shield: Uscita da Warning Zone - Torna normale");
}

//+------------------------------------------------------------------+
//| Enter Pre-Shield Phase (Fase 2)                                   |
//+------------------------------------------------------------------+
void EnterPreShieldPhase(ENUM_BREAKOUT_DIRECTION direction) {
   shield.phase = PHASE_PRE_SHIELD;
   lastBreakoutDirection = direction;
   
   Print("═══ SHIELD FASE 2: PRE-SHIELD ═══");
   Print("  Direction: ", (direction == BREAKOUT_UP ? "UP" : "DOWN"));
   Print("  Shield PENDING pronto all'attivazione");
   
   // Alert
   if(EnableAlerts) {
      Alert("SUGAMARA: Pre-Shield - Breakout imminente, Shield pronto!");
   }
   
   currentSystemState = STATE_SHIELD_PENDING;
}

//+------------------------------------------------------------------+
//| Cancel Pre-Shield (rientra nel range)                             |
//+------------------------------------------------------------------+
void CancelPreShield() {
   shield.phase = PHASE_NORMAL;
   lastBreakoutDirection = BREAKOUT_NONE;
   currentSystemState = STATE_INSIDE_RANGE;
   
   Print("Shield: Pre-Shield cancellato - Prezzo rientrato");
}

//+------------------------------------------------------------------+
//| Get Last Grid B Level (più alto)                                  |
//+------------------------------------------------------------------+
double GetLastGridBLevel() {
   double highest = 0;
   for(int i = 0; i < gridB_total_levels; i++) {
      if(gridB_levels[i].entry_price > highest) {
         highest = gridB_levels[i].entry_price;
      }
   }
   return highest;
}

//+------------------------------------------------------------------+
//| Get Last Grid A Level (più basso)                                 |
//+------------------------------------------------------------------+
double GetLastGridALevel() {
   double lowest = DBL_MAX;
   for(int i = 0; i < gridA_total_levels; i++) {
      if(gridA_levels[i].entry_price < lowest) {
         lowest = gridA_levels[i].entry_price;
      }
   }
   return lowest;
}

//+------------------------------------------------------------------+
//|                    ATTIVAZIONE SHIELD                            |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Activate Shield LONG (Breakout DOWN - protegge LONG)              |
//+------------------------------------------------------------------+
void ActivateShieldLong(string source) {
   Print("═══ ACTIVATING SHIELD LONG ═══");
   Print("  Source: ", source);
   
   double shieldLot = CalculateShieldLotSize(SHIELD_LONG);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   
   // Apri posizione LONG a mercato (NO TP, NO SL)
   int shieldMagic = MagicNumber + MAGIC_SHIELD_LONG;
   trade.SetExpertMagicNumber(shieldMagic);
   
   if(trade.Buy(shieldLot, _Symbol, 0, 0, 0, "SUGAMARA_SHIELD_LONG")) {
      shield.ticket = trade.ResultOrder();
      shield.isActive = true;
      shield.type = SHIELD_LONG;
      shield.phase = PHASE_SHIELD_ACTIVE;
      shield.lot_size = shieldLot;
      shield.entry_price = trade.ResultPrice();
      shield.activation_time = TimeCurrent();
      shield.activation_count++;
      shield.trailing_sl = 0;
      
      totalShieldActivations++;
      currentSystemState = STATE_SHIELD_LONG;
      
      Print("  ✅ Shield LONG ATTIVATO");
      Print("  Ticket: ", shield.ticket);
      Print("  Lot: ", shieldLot);
      Print("  Entry: ", shield.entry_price);
      Print("  Esposizione Grid A coperta: ", gridA_total_lots, " lots");
      
      if(EnableAlerts) {
         Alert("SUGAMARA: Shield LONG attivato! Breakout DOWN - Protezione attiva");
      }
      
      if(EnablePushNotifications) {
         SendNotification("SUGAMARA: Shield LONG attivato!");
      }
   }
   else {
      Print("  ❌ ERRORE apertura Shield LONG: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//| Activate Shield SHORT (Breakout UP - protegge SHORT)              |
//+------------------------------------------------------------------+
void ActivateShieldShort(string source) {
   Print("═══ ACTIVATING SHIELD SHORT ═══");
   Print("  Source: ", source);
   
   double shieldLot = CalculateShieldLotSize(SHIELD_SHORT);
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   // Apri posizione SHORT a mercato (NO TP, NO SL)
   int shieldMagic = MagicNumber + MAGIC_SHIELD_SHORT;
   trade.SetExpertMagicNumber(shieldMagic);
   
   if(trade.Sell(shieldLot, _Symbol, 0, 0, 0, "SUGAMARA_SHIELD_SHORT")) {
      shield.ticket = trade.ResultOrder();
      shield.isActive = true;
      shield.type = SHIELD_SHORT;
      shield.phase = PHASE_SHIELD_ACTIVE;
      shield.lot_size = shieldLot;
      shield.entry_price = trade.ResultPrice();
      shield.activation_time = TimeCurrent();
      shield.activation_count++;
      shield.trailing_sl = 0;
      
      totalShieldActivations++;
      currentSystemState = STATE_SHIELD_SHORT;
      
      Print("  ✅ Shield SHORT ATTIVATO");
      Print("  Ticket: ", shield.ticket);
      Print("  Lot: ", shieldLot);
      Print("  Entry: ", shield.entry_price);
      Print("  Esposizione Grid B coperta: ", gridB_total_lots, " lots");
      
      if(EnableAlerts) {
         Alert("SUGAMARA: Shield SHORT attivato! Breakout UP - Protezione attiva");
      }
      
      if(EnablePushNotifications) {
         SendNotification("SUGAMARA: Shield SHORT attivato!");
      }
   }
   else {
      Print("  ❌ ERRORE apertura Shield SHORT: ", trade.ResultRetcode(), " - ", trade.ResultRetcodeDescription());
   }
}

//+------------------------------------------------------------------+
//|                    GESTIONE SHIELD ATTIVO                        |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Manage Active Shield                                              |
//+------------------------------------------------------------------+
void ManageActiveShield(double currentPrice) {
   if(!shield.isActive || shield.ticket == 0) return;
   
   // Verifica che la posizione esista ancora
   if(!PositionSelectByTicket(shield.ticket)) {
      Print("Shield position not found - may have been closed by SL/TP");
      ResetShield();
      return;
   }
   
   // Aggiorna P/L corrente
   shield.current_pl = PositionGetDouble(POSITION_PROFIT);
   
   // Applica trailing se abilitato
   if(Shield_Use_Trailing) {
      ApplyShieldTrailing(currentPrice);
   }
   
   // Check reentry condition
   if(CheckReentryCondition(currentPrice)) {
      CloseShield("REENTRY");
   }
}

//+------------------------------------------------------------------+
//| Apply Trailing Stop to Shield                                     |
//+------------------------------------------------------------------+
void ApplyShieldTrailing(double currentPrice) {
   if(!PositionSelectByTicket(shield.ticket)) return;
   
   double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
   double currentSL = PositionGetDouble(POSITION_SL);
   double trailingStart = PipsToPoints(Shield_Trailing_Start);
   double trailingStep = PipsToPoints(Shield_Trailing_Step);
   
   if(shield.type == SHIELD_LONG) {
      // LONG: trailing SL verso l'alto
      double profit = currentPrice - openPrice;
      if(profit >= trailingStart) {
         double newSL = NormalizeDouble(currentPrice - trailingStep, symbolDigits);
         if(newSL > currentSL || currentSL == 0) {
            if(trade.PositionModify(shield.ticket, newSL, 0)) {
               shield.trailing_sl = newSL;
               Print("Shield Trailing SL updated: ", newSL);
            }
         }
      }
   }
   else if(shield.type == SHIELD_SHORT) {
      // SHORT: trailing SL verso il basso
      double profit = openPrice - currentPrice;
      if(profit >= trailingStart) {
         double newSL = NormalizeDouble(currentPrice + trailingStep, symbolDigits);
         if(newSL < currentSL || currentSL == 0) {
            if(trade.PositionModify(shield.ticket, newSL, 0)) {
               shield.trailing_sl = newSL;
               Print("Shield Trailing SL updated: ", newSL);
            }
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Close Shield Position                                             |
//+------------------------------------------------------------------+
void CloseShield(string reason) {
   if(!shield.isActive || shield.ticket == 0) return;
   
   Print("═══ CLOSING SHIELD ═══");
   Print("  Reason: ", reason);
   
   if(PositionSelectByTicket(shield.ticket)) {
      double pl = PositionGetDouble(POSITION_PROFIT);
      
      if(trade.PositionClose(shield.ticket)) {
         totalShieldPL += pl;
         lastShieldClosure = TimeCurrent();
         
         Print("  ✅ Shield CHIUSO");
         Print("  P/L: ", pl);
         Print("  Total Shield P/L: ", totalShieldPL);
         Print("  Duration: ", (int)(TimeCurrent() - shield.activation_time), " seconds");
         
         if(EnableAlerts) {
            Alert("SUGAMARA: Shield chiuso - ", reason, " - P/L: ", DoubleToString(pl, 2));
         }
      }
      else {
         Print("  ❌ ERRORE chiusura Shield: ", trade.ResultRetcode());
      }
   }
   
   ResetShield();
}

//+------------------------------------------------------------------+
//| Reset Shield Variables                                            |
//+------------------------------------------------------------------+
void ResetShield() {
   shield.isActive = false;
   shield.type = SHIELD_NONE;
   shield.phase = PHASE_NORMAL;
   shield.ticket = 0;
   shield.lot_size = 0;
   shield.entry_price = 0;
   shield.current_pl = 0;
   shield.trailing_sl = 0;
   
   lastBreakoutDirection = BREAKOUT_NONE;
   currentSystemState = STATE_INSIDE_RANGE;
   
   Print("Shield reset - Sistema torna operativo normale");
}

//+------------------------------------------------------------------+
//|                    MAIN PROCESS FUNCTION                         |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Process Shield (chiamato da OnTick)                               |
//+------------------------------------------------------------------+
void ProcessShield() {
   if(ShieldMode == SHIELD_DISABLED) return;
   if(NeutralMode != NEUTRAL_RANGEBOX) return;
   
   double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   
   switch(ShieldMode) {
      case SHIELD_SIMPLE:
         ProcessShieldSimple(currentPrice);
         break;
         
      case SHIELD_3_PHASES:
         ProcessShield3Phases(currentPrice);
         break;
   }
}

//+------------------------------------------------------------------+
//| Get Shield Status String                                          |
//+------------------------------------------------------------------+
string GetShieldStatusString() {
   if(ShieldMode == SHIELD_DISABLED) return "DISABLED";
   
   if(!shield.isActive) {
      switch(shield.phase) {
         case PHASE_NORMAL: return "IDLE";
         case PHASE_WARNING: return "⚠️ WARNING";
         case PHASE_PRE_SHIELD: return "🔶 PRE-SHIELD";
         default: return "IDLE";
      }
   }
   
   switch(shield.type) {
      case SHIELD_LONG: return "🛡️ SHIELD LONG ACTIVE";
      case SHIELD_SHORT: return "🛡️ SHIELD SHORT ACTIVE";
      default: return "ACTIVE";
   }
}

//+------------------------------------------------------------------+
//| Get Shield Phase String                                           |
//+------------------------------------------------------------------+
string GetShieldPhaseString() {
   switch(shield.phase) {
      case PHASE_NORMAL: return "Normal";
      case PHASE_WARNING: return "Warning";
      case PHASE_PRE_SHIELD: return "Pre-Shield";
      case PHASE_SHIELD_ACTIVE: return "Active";
      default: return "Unknown";
   }
}

//+------------------------------------------------------------------+
//| Emergency Close All Shields                                       |
//+------------------------------------------------------------------+
void EmergencyCloseShield() {
   if(shield.isActive && shield.ticket > 0) {
      CloseShield("EMERGENCY");
   }
}

//+------------------------------------------------------------------+
//| Deinitialize Shield                                               |
//+------------------------------------------------------------------+
void DeinitializeShield() {
   // Chiudi shield se attivo
   if(shield.isActive) {
      CloseShield("DEINIT");
   }
   
   Print("Shield System deinitialized");
   Print("  Total Activations: ", totalShieldActivations);
   Print("  Total Shield P/L: ", totalShieldPL);
}

#endif // SHIELDMANAGER_MQH
```

---

# PARTE 7: LOGICA SWITCH MODALITÀ

## File: Core/ModeLogic.mqh

```cpp
//+------------------------------------------------------------------+
//|                                              ModeLogic.mqh       |
//|                        SUGAMARA - Mode Logic Controller          |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025"
#property strict

#ifndef MODELOGIC_MQH
#define MODELOGIC_MQH

//+------------------------------------------------------------------+
//| Validate Mode Parameters                                          |
//+------------------------------------------------------------------+
bool ValidateModeParameters() {
   Print("═══ Validating Mode Parameters ═══");
   
   // PURE mode validation
   if(NeutralMode == NEUTRAL_PURE) {
      if(Pure_Spacing_Pips < 10) {
         Print("ERROR: Pure_Spacing_Pips must be >= 10");
         return false;
      }
      if(Pure_TP_Pips < 5) {
         Print("ERROR: Pure_TP_Pips must be >= 5");
         return false;
      }
      if(UseATR) {
         Print("WARNING: UseATR ignored in NEUTRAL_PURE mode");
      }
   }
   
   // RANGEBOX mode validation
   if(NeutralMode == NEUTRAL_RANGEBOX) {
      if(RangeBoxMode == RANGEBOX_MANUAL) {
         if(Manual_Resistance <= Manual_Support) {
            Print("ERROR: Manual_Resistance must be > Manual_Support");
            return false;
         }
      }
      if(ShieldMode == SHIELD_DISABLED) {
         Print("WARNING: Shield disabled in RANGEBOX mode - no breakout protection!");
      }
   }
   
   // Shield validation
   if(ShieldMode != SHIELD_DISABLED && NeutralMode != NEUTRAL_RANGEBOX) {
      Print("WARNING: Shield only available in RANGEBOX mode - will be ignored");
   }
   
   Print("  Mode validation: PASSED");
   return true;
}

//+------------------------------------------------------------------+
//| Print Mode Configuration                                          |
//+------------------------------------------------------------------+
void PrintModeConfiguration() {
   Print("═══════════════════════════════════════════════════════════════════");
   Print("  SUGAMARA CONFIGURATION");
   Print("═══════════════════════════════════════════════════════════════════");
   Print("  Neutral Mode: ", GetModeName());
   Print("  ATR Adaptive: ", (IsATREnabled() ? "ENABLED" : "DISABLED"));
   
   switch(NeutralMode) {
      case NEUTRAL_PURE:
         Print("  Spacing: ", Pure_Spacing_Pips, " pips (FIXED)");
         Print("  TP: ", Pure_TP_Pips, " pips (FIXED)");
         Print("  Lot: ", Pure_Lot_Size, " (FIXED)");
         Print("  Shield: NOT AVAILABLE");
         break;
         
      case NEUTRAL_CASCADE:
         Print("  Spacing: ", (UseATR ? "ATR-based" : "Fixed"));
         Print("  TP: CASCADE (Entry precedente)");
         Print("  Lot: Progressive (×", Lot_Multiplier, ")");
         Print("  Shield: NOT AVAILABLE");
         break;
         
      case NEUTRAL_RANGEBOX:
         Print("  Spacing: ", (UseATR ? "ATR-based" : "Fixed"));
         Print("  TP: CASCADE (Entry precedente)");
         Print("  Lot: Progressive (×", Lot_Multiplier, ")");
         Print("  Range Box: ", EnumToString(RangeBoxMode));
         Print("  Shield: ", GetShieldModeName());
         break;
   }
   Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Get Mode Name                                                     |
//+------------------------------------------------------------------+
string GetModeName() {
   string name = "";
   
   switch(NeutralMode) {
      case NEUTRAL_PURE: name = "PURE"; break;
      case NEUTRAL_CASCADE: name = "CASCADE"; break;
      case NEUTRAL_RANGEBOX: name = "RANGEBOX"; break;
   }
   
   if(IsATREnabled()) name += "+ATR";
   
   return name;
}

//+------------------------------------------------------------------+
//| Get Shield Mode Name                                              |
//+------------------------------------------------------------------+
string GetShieldModeName() {
   switch(ShieldMode) {
      case SHIELD_DISABLED: return "DISABLED";
      case SHIELD_SIMPLE: return "SIMPLE (1 Fase)";
      case SHIELD_3_PHASES: return "3 FASI (Warning→Pre→Active)";
      default: return "UNKNOWN";
   }
}

//+------------------------------------------------------------------+
//| Check if ATR is Enabled                                           |
//+------------------------------------------------------------------+
bool IsATREnabled() {
   // ATR non disponibile in PURE mode
   if(NeutralMode == NEUTRAL_PURE) return false;
   return UseATR;
}

//+------------------------------------------------------------------+
//| Check if Shield is Available                                      |
//+------------------------------------------------------------------+
bool IsShieldAvailable() {
   return (NeutralMode == NEUTRAL_RANGEBOX && ShieldMode != SHIELD_DISABLED);
}

//+------------------------------------------------------------------+
//|                    INITIALIZATION PER MODALITÀ                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Initialize Pure Mode                                              |
//+------------------------------------------------------------------+
bool InitializePureMode() {
   Print("═══ Initializing PURE Mode ═══");
   
   current_spacing_pips = Pure_Spacing_Pips;
   
   // In PURE: tutto fisso
   Print("  Spacing: ", current_spacing_pips, " pips");
   Print("  TP: ", Pure_TP_Pips, " pips");
   Print("  Lot: ", Pure_Lot_Size);
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize Cascade Mode                                           |
//+------------------------------------------------------------------+
bool InitializeCascadeMode() {
   Print("═══ Initializing CASCADE Mode ═══");
   
   // ATR opzionale
   if(UseATR) {
      // ATR già inizializzato, calcola spacing
      if(!CalculateAdaptiveSpacing()) return false;
      Print("  ATR: ENABLED");
   } else {
      current_spacing_pips = Spacing_Low;  // Default
      Print("  ATR: DISABLED (fixed spacing)");
   }
   
   Print("  TP Mode: CASCADE");
   Print("  Lot Multiplier: ", Lot_Multiplier);
   
   return true;
}

//+------------------------------------------------------------------+
//| Initialize RangeBox Mode                                          |
//+------------------------------------------------------------------+
bool InitializeRangeBoxMode() {
   Print("═══ Initializing RANGEBOX Mode ═══");
   
   // Prima come CASCADE
   if(!InitializeCascadeMode()) return false;
   
   // Poi Range Box
   if(!InitializeRangeBox()) return false;
   
   // Poi Shield
   if(!InitializeShield()) return false;
   
   Print("  RANGEBOX Mode: READY");
   
   return true;
}

//+------------------------------------------------------------------+
//|                    ONTICK PER MODALITÀ                           |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| OnTick Pure Mode                                                  |
//+------------------------------------------------------------------+
void OnTickPureMode() {
   // Update grids
   UpdateGridASystem();
   UpdateGridBSystem();
   
   // Check TP fisso (non cascade)
   CheckFixedTPCloses();
   
   // Cyclic reopen
   if(Enable_CyclicReopen) {
      CheckCyclicReopening();
   }
}

//+------------------------------------------------------------------+
//| OnTick Cascade Mode                                               |
//+------------------------------------------------------------------+
void OnTickCascadeMode() {
   // ATR recalc (se abilitato)
   if(IsATREnabled()) {
      CheckSpacingRecalculation();
   }
   
   // Update grids
   UpdateGridASystem();
   UpdateGridBSystem();
   
   // Cascade closes
   CheckCascadeCloses();
   
   // Cyclic reopen
   if(Enable_CyclicReopen) {
      CheckCyclicReopening();
   }
}

//+------------------------------------------------------------------+
//| OnTick RangeBox Mode                                              |
//+------------------------------------------------------------------+
void OnTickRangeBoxMode() {
   // Come CASCADE
   if(IsATREnabled()) {
      CheckSpacingRecalculation();
   }
   
   // Update grids
   UpdateGridASystem();
   UpdateGridBSystem();
   CheckCascadeCloses();
   
   // AGGIUNTA: Range Box update
   UpdateRangeBox();
   
   // AGGIUNTA: Shield processing
   ProcessShield();
   
   // Cyclic reopen
   if(Enable_CyclicReopen) {
      CheckCyclicReopening();
   }
}

//+------------------------------------------------------------------+
//| Check Fixed TP Closes (per PURE mode)                             |
//+------------------------------------------------------------------+
void CheckFixedTPCloses() {
   double currentBid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double currentAsk = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double tpPoints = PipsToPoints(Pure_TP_Pips);
   
   // Grid A (LONG) - check TP
   for(int i = 0; i < gridA_total_levels; i++) {
      if(gridA_levels[i].is_filled && gridA_levels[i].filled_ticket > 0) {
         if(PositionSelectByTicket(gridA_levels[i].filled_ticket)) {
            double tp = gridA_levels[i].entry_price + tpPoints;
            if(currentBid >= tp) {
               trade.PositionClose(gridA_levels[i].filled_ticket);
               Print("Grid A L", gridA_levels[i].level_number, " closed at FIXED TP");
               gridA_levels[i].is_filled = false;
               gridA_levels[i].is_closed = true;
            }
         }
      }
   }
   
   // Grid B (SHORT) - check TP
   for(int i = 0; i < gridB_total_levels; i++) {
      if(gridB_levels[i].is_filled && gridB_levels[i].filled_ticket > 0) {
         if(PositionSelectByTicket(gridB_levels[i].filled_ticket)) {
            double tp = gridB_levels[i].entry_price - tpPoints;
            if(currentAsk <= tp) {
               trade.PositionClose(gridB_levels[i].filled_ticket);
               Print("Grid B L", gridB_levels[i].level_number, " closed at FIXED TP");
               gridB_levels[i].is_filled = false;
               gridB_levels[i].is_closed = true;
            }
         }
      }
   }
}

#endif // MODELOGIC_MQH
```

---

# PARTE 8: DASHBOARD AGGIORNATA

## Aggiunte a UI/Dashboard.mqh

```cpp
//+------------------------------------------------------------------+
//| Draw Shield Panel (per RANGEBOX mode)                             |
//+------------------------------------------------------------------+
void DrawShieldPanel(int x, int y) {
   if(NeutralMode != NEUTRAL_RANGEBOX) return;
   
   int panelWidth = 220;
   int panelHeight = 140;
   
   // Background
   string bgName = "DASH_SHIELD_BG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrDarkSlateGray);
   ObjectSetInteger(0, bgName, OBJPROP_BORDER_TYPE, BORDER_FLAT);
   ObjectSetInteger(0, bgName, OBJPROP_CORNER, CORNER_LEFT_UPPER);
   
   // Title
   DrawLabel("DASH_SHIELD_TITLE", x + 10, y + 5, "🛡️ SHIELD INTELLIGENTE", clrWhite, 10, true);
   
   // Mode
   string modeText = "Mode: " + GetShieldModeName();
   DrawLabel("DASH_SHIELD_MODE", x + 10, y + 25, modeText, clrSilver, 8, false);
   
   // Status
   string statusText = GetShieldStatusString();
   color statusColor = clrLime;
   if(shield.isActive) statusColor = clrMagenta;
   else if(shield.phase == PHASE_WARNING) statusColor = clrOrange;
   else if(shield.phase == PHASE_PRE_SHIELD) statusColor = clrYellow;
   DrawLabel("DASH_SHIELD_STATUS", x + 10, y + 45, statusText, statusColor, 9, false);
   
   // Phase (solo per 3 Fasi)
   if(ShieldMode == SHIELD_3_PHASES) {
      string phaseText = "Phase: " + GetShieldPhaseString();
      DrawLabel("DASH_SHIELD_PHASE", x + 10, y + 65, phaseText, clrSilver, 8, false);
   }
   
   // Breakout Levels
   string upperBO = "Upper BO: " + DoubleToString(upperBreakoutLevel, symbolDigits);
   string lowerBO = "Lower BO: " + DoubleToString(lowerBreakoutLevel, symbolDigits);
   DrawLabel("DASH_UPPER_BO", x + 10, y + 85, upperBO, clrSilver, 8, false);
   DrawLabel("DASH_LOWER_BO", x + 10, y + 100, lowerBO, clrSilver, 8, false);
   
   // Shield P/L
   color plColor = (totalShieldPL >= 0) ? clrLime : clrRed;
   string plText = "Shield P/L: " + DoubleToString(totalShieldPL, 2);
   DrawLabel("DASH_SHIELD_PL", x + 10, y + 120, plText, plColor, 9, false);
}

//+------------------------------------------------------------------+
//| Draw Range Box Panel                                              |
//+------------------------------------------------------------------+
void DrawRangeBoxPanel(int x, int y) {
   if(NeutralMode != NEUTRAL_RANGEBOX) return;
   if(!rangeBox.isValid) return;
   
   int panelWidth = 200;
   int panelHeight = 100;
   
   // Background
   string bgName = "DASH_RANGE_BG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrDarkSlateGray);
   
   // Title
   DrawLabel("DASH_RANGE_TITLE", x + 10, y + 5, "📦 RANGE BOX", clrWhite, 10, true);
   
   // Levels
   DrawLabel("DASH_RESISTANCE", x + 10, y + 30, 
             "Resistance: " + DoubleToString(rangeBox.resistance, symbolDigits), 
             clrOrangeRed, 9, false);
   DrawLabel("DASH_SUPPORT", x + 10, y + 50, 
             "Support: " + DoubleToString(rangeBox.support, symbolDigits), 
             clrLimeGreen, 9, false);
   DrawLabel("DASH_RANGE_HEIGHT", x + 10, y + 70, 
             "Range: " + DoubleToString(rangeBox.rangeHeight, 1) + " pips", 
             clrSilver, 9, false);
}

//+------------------------------------------------------------------+
//| Draw System State Panel                                           |
//+------------------------------------------------------------------+
void DrawSystemStatePanel(int x, int y) {
   int panelWidth = 200;
   int panelHeight = 50;
   
   // Background
   string bgName = "DASH_STATE_BG";
   ObjectCreate(0, bgName, OBJ_RECTANGLE_LABEL, 0, 0, 0);
   ObjectSetInteger(0, bgName, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, bgName, OBJPROP_YDISTANCE, y);
   ObjectSetInteger(0, bgName, OBJPROP_XSIZE, panelWidth);
   ObjectSetInteger(0, bgName, OBJPROP_YSIZE, panelHeight);
   ObjectSetInteger(0, bgName, OBJPROP_BGCOLOR, clrDarkSlateGray);
   
   // State
   color stateColor;
   string stateText;
   
   switch(currentSystemState) {
      case STATE_INSIDE_RANGE:
         stateColor = clrLime;
         stateText = "✅ INSIDE RANGE";
         break;
      case STATE_WARNING_UP:
      case STATE_WARNING_DOWN:
         stateColor = clrOrange;
         stateText = "⚠️ WARNING ZONE";
         break;
      case STATE_SHIELD_PENDING:
         stateColor = clrYellow;
         stateText = "🔶 PRE-SHIELD";
         break;
      case STATE_SHIELD_LONG:
         stateColor = clrMagenta;
         stateText = "🛡️ SHIELD LONG";
         break;
      case STATE_SHIELD_SHORT:
         stateColor = clrMagenta;
         stateText = "🛡️ SHIELD SHORT";
         break;
      case STATE_BREAKOUT_UP:
         stateColor = clrRed;
         stateText = "🔺 BREAKOUT UP";
         break;
      case STATE_BREAKOUT_DOWN:
         stateColor = clrRed;
         stateText = "🔻 BREAKOUT DOWN";
         break;
      case STATE_EMERGENCY:
         stateColor = clrRed;
         stateText = "🚨 EMERGENCY";
         break;
      default:
         stateColor = clrGray;
         stateText = EnumToString(currentSystemState);
   }
   
   DrawLabel("DASH_STATE", x + 10, y + 15, stateText, stateColor, 12, true);
}

//+------------------------------------------------------------------+
//| Helper: Draw Label                                                |
//+------------------------------------------------------------------+
void DrawLabel(string name, int x, int y, string text, color clr, int fontSize, bool bold) {
   ObjectCreate(0, name, OBJ_LABEL, 0, 0, 0);
   ObjectSetInteger(0, name, OBJPROP_XDISTANCE, x);
   ObjectSetInteger(0, name, OBJPROP_YDISTANCE, y);
   ObjectSetString(0, name, OBJPROP_TEXT, text);
   ObjectSetInteger(0, name, OBJPROP_COLOR, clr);
   ObjectSetInteger(0, name, OBJPROP_FONTSIZE, fontSize);
   ObjectSetString(0, name, OBJPROP_FONT, bold ? "Arial Bold" : "Arial");
   ObjectSetInteger(0, name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
}
```

---

# PARTE 9: CHECKLIST IMPLEMENTAZIONE

## Checklist Completa

```
╔═══════════════════════════════════════════════════════════════════════════════════════════╗
║                         CHECKLIST IMPLEMENTAZIONE COMPLETA                                 ║
╠═══════════════════════════════════════════════════════════════════════════════════════════╣
║                                                                                            ║
║  FASE 0: PULIZIA (10 minuti)                                                              ║
║  ════════════════════════════                                                              ║
║  □ Rimuovere input Hedge_Multiplier, Hedge_TP_Pips, Hedge_SL_Pips                        ║
║  □ Rimuovere MAGIC_HEDGE_LONG, MAGIC_HEDGE_SHORT se presenti                              ║
║  □ Rimuovere funzioni OpenHedgePosition, CloseHedgePosition se presenti                   ║
║  □ Rimuovere ENUM_HEDGE_DIRECTION (sostituito da ENUM_SHIELD_TYPE)                        ║
║                                                                                            ║
║  FASE 1: ENUMS (15 minuti)                                                                ║
║  ═════════════════════════                                                                ║
║  □ Aggiungere ENUM_NEUTRAL_MODE in Enums.mqh                                              ║
║  □ Aggiungere ENUM_SHIELD_MODE in Enums.mqh                                               ║
║  □ Aggiungere ENUM_SHIELD_TYPE in Enums.mqh                                               ║
║  □ Aggiungere ENUM_SHIELD_PHASE in Enums.mqh                                              ║
║  □ Aggiungere ENUM_BREAKOUT_DIRECTION in Enums.mqh                                        ║
║  □ Aggiungere ENUM_RANGEBOX_MODE in Enums.mqh                                             ║
║  □ Aggiornare ENUM_SYSTEM_STATE con nuovi stati                                           ║
║  □ Aggiungere MAGIC_SHIELD_LONG, MAGIC_SHIELD_SHORT                                       ║
║                                                                                            ║
║  FASE 2: INPUT PARAMETERS (15 minuti)                                                     ║
║  ═════════════════════════════════════                                                    ║
║  □ Aggiungere input NeutralMode                                                           ║
║  □ Aggiungere input UseATR                                                                ║
║  □ Aggiungere input Pure mode (Pure_Spacing_Pips, Pure_TP_Pips, Pure_Lot_Size)           ║
║  □ Aggiungere input Range Box (RangeBoxMode, Manual_R/S, ecc.)                           ║
║  □ Aggiungere input Shield (ShieldMode, Breakout_Buffer, Reentry_Buffer, ecc.)           ║
║  □ Aggiungere input Shield 3 Fasi (Warning_Zone_Percent, Trailing params)                ║
║                                                                                            ║
║  FASE 3: VARIABILI GLOBALI (20 minuti)                                                    ║
║  ══════════════════════════════════════                                                   ║
║  □ Aggiungere struct RangeBoxData                                                         ║
║  □ Aggiungere struct ShieldData                                                           ║
║  □ Aggiungere variabili breakout levels                                                   ║
║  □ Aggiungere variabili shield statistics                                                 ║
║  □ Aggiungere helper functions (PipsToPoints, PointsToPips, NormalizeLot)                ║
║                                                                                            ║
║  FASE 4: RANGEBOXMANAGER (2 ore)                                                          ║
║  ════════════════════════════════                                                         ║
║  □ Creare file Trading/RangeBoxManager.mqh                                                ║
║  □ Implementare InitializeRangeBox()                                                      ║
║  □ Implementare CalculateManualRangeBox()                                                 ║
║  □ Implementare CalculateDailyHLRangeBox()                                                ║
║  □ Implementare CalculateATRBasedRangeBox()                                               ║
║  □ Implementare CalculateBreakoutLevels()                                                 ║
║  □ Implementare GetPricePositionInRange()                                                 ║
║  □ Implementare CheckBreakoutCondition()                                                  ║
║  □ Implementare CheckReentryCondition()                                                   ║
║  □ Implementare IsBreakoutConfirmed()                                                     ║
║  □ Implementare UpdateRangeBox()                                                          ║
║  □ Implementare DrawRangeBoxOnChart()                                                     ║
║  □ Implementare DrawBreakoutLevels()                                                      ║
║  □ Testare tutte le 3 modalità Range Box                                                  ║
║                                                                                            ║
║  FASE 5: SHIELDMANAGER (4 ore)                                                            ║
║  ══════════════════════════════                                                           ║
║  □ Creare file Trading/ShieldManager.mqh                                                  ║
║  □ Implementare InitializeShield()                                                        ║
║  □ Implementare CalculateShieldLotSize()                                                  ║
║  □ Implementare ProcessShieldSimple()                                                     ║
║  □ Implementare ProcessShield3Phases()                                                    ║
║  □ Implementare EnterWarningPhase()                                                       ║
║  □ Implementare EnterPreShieldPhase()                                                     ║
║  □ Implementare ActivateShieldLong()                                                      ║
║  □ Implementare ActivateShieldShort()                                                     ║
║  □ Implementare ManageActiveShield()                                                      ║
║  □ Implementare ApplyShieldTrailing()                                                     ║
║  □ Implementare CloseShield()                                                             ║
║  □ Implementare ResetShield()                                                             ║
║  □ Implementare ProcessShield()                                                           ║
║  □ Testare Shield Simple                                                                  ║
║  □ Testare Shield 3 Fasi                                                                  ║
║  □ Testare chiusura su reentry                                                            ║
║  □ Testare trailing (se abilitato)                                                        ║
║                                                                                            ║
║  FASE 6: MODE LOGIC (2 ore)                                                               ║
║  ═══════════════════════════                                                              ║
║  □ Creare file Core/ModeLogic.mqh                                                         ║
║  □ Implementare ValidateModeParameters()                                                  ║
║  □ Implementare PrintModeConfiguration()                                                  ║
║  □ Implementare InitializePureMode()                                                      ║
║  □ Implementare InitializeCascadeMode()                                                   ║
║  □ Implementare InitializeRangeBoxMode()                                                  ║
║  □ Implementare OnTickPureMode()                                                          ║
║  □ Implementare OnTickCascadeMode()                                                       ║
║  □ Implementare OnTickRangeBoxMode()                                                      ║
║  □ Implementare CheckFixedTPCloses()                                                      ║
║  □ Testare switch tra le 3 modalità                                                       ║
║                                                                                            ║
║  FASE 7: INTEGRAZIONE MAIN FILE (1 ora)                                                   ║
║  ════════════════════════════════════════                                                 ║
║  □ Aggiornare #include in Sugamara.mq5                                                    ║
║  □ Aggiornare OnInit() con switch modalità                                                ║
║  □ Aggiornare OnTick() con switch modalità                                                ║
║  □ Aggiornare OnDeinit() con cleanup                                                      ║
║                                                                                            ║
║  FASE 8: DASHBOARD (1 ora)                                                                ║
║  ═════════════════════════                                                                ║
║  □ Aggiungere DrawShieldPanel()                                                           ║
║  □ Aggiungere DrawRangeBoxPanel()                                                         ║
║  □ Aggiungere DrawSystemStatePanel()                                                      ║
║  □ Integrare nuovi panel in UpdateDashboard()                                             ║
║                                                                                            ║
║  FASE 9: TESTING (4-6 ore)                                                                ║
║  ═════════════════════════                                                                ║
║  □ Test NEUTRAL_PURE su EUR/USD                                                           ║
║  □ Test NEUTRAL_CASCADE senza ATR                                                         ║
║  □ Test NEUTRAL_CASCADE con ATR                                                           ║
║  □ Test NEUTRAL_RANGEBOX + SHIELD_SIMPLE                                                  ║
║  □ Test NEUTRAL_RANGEBOX + SHIELD_3_PHASES                                                ║
║  □ Test breakout UP con Shield activation                                                 ║
║  □ Test breakout DOWN con Shield activation                                               ║
║  □ Test reentry dopo breakout                                                             ║
║  □ Test Warning Zone (solo 3 Fasi)                                                        ║
║  □ Test Pre-Shield cancellation (solo 3 Fasi)                                             ║
║  □ Backtest 1 mese EUR/USD                                                                ║
║                                                                                            ║
║  TEMPO TOTALE STIMATO: 15-18 ore                                                          ║
║                                                                                            ║
╚═══════════════════════════════════════════════════════════════════════════════════════════╝
```

---

# RIEPILOGO FINALE

## Cosa contiene questo documento

| Elemento | Descrizione |
|----------|-------------|
| ENUM_SHIELD_MODE | SHIELD_DISABLED, SHIELD_SIMPLE, SHIELD_3_PHASES |
| Shield Simple | Attivazione diretta su breakout confermato |
| Shield 3 Fasi | Warning → Pre-Shield → Active |
| Calcolo Lot | Σ(lot grid esposta) = copertura 100% |
| Chiusura | Solo su Reentry Level (NO TP/SL fissi) |
| Trailing | Opzionale per massimizzare profitto |

## Cosa è stato RIMOSSO (Hedge Base)

- ❌ `Hedge_Multiplier`
- ❌ `Hedge_TP_Pips`
- ❌ `Hedge_SL_Pips`
- ❌ `OpenHedgePosition()`
- ❌ `CloseHedgePosition()`
- ❌ `ENUM_HEDGE_DIRECTION`

## Files da creare/modificare

1. **Config/Enums.mqh** - Aggiornare
2. **Config/InputParameters.mqh** - Aggiornare
3. **Core/GlobalVariables.mqh** - Aggiornare
4. **Core/ModeLogic.mqh** - NUOVO
5. **Trading/RangeBoxManager.mqh** - NUOVO
6. **Trading/ShieldManager.mqh** - NUOVO
7. **UI/Dashboard.mqh** - Aggiornare
8. **Sugamara.mq5** - Aggiornare

---

**FINE DOCUMENTO**

**Versione:** 2.0 FINAL  
**Completezza:** 100%  
**Pronto per:** Implementazione diretta in MT5

🚀 **GOOD LUCK WITH IMPLEMENTATION!**
