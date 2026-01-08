# VIRTUAL STOP ORDER MANAGER

## Sistema di Gestione Grid con Ordini STOP Virtuali

**Versione**: 1.0
**Data**: Gennaio 2026
**Autore**: Sugamara Development Team
**Compatibilità**: MetaTrader 5 / MQL5

---

# INDICE

1. [Introduzione e Motivazione](#1-introduzione-e-motivazione)
2. [Il Problema degli Ordini LIMIT](#2-il-problema-degli-ordini-limit)
3. [La Soluzione: Virtual Stop Order Manager](#3-la-soluzione-virtual-stop-order-manager)
4. [Architettura del Sistema](#4-architettura-del-sistema)
5. [Logica dei Trigger](#5-logica-dei-trigger)
6. [State Machine](#6-state-machine)
7. [Flussi Operativi con Esempi](#7-flussi-operativi-con-esempi)
8. [Strutture Dati MQL5](#8-strutture-dati-mql5)
9. [Istruzioni di Implementazione](#9-istruzioni-di-implementazione)
10. [Gestione Recovery](#10-gestione-recovery)
11. [Parametri Configurabili](#11-parametri-configurabili)
12. [Vantaggi e Svantaggi](#12-vantaggi-e-svantaggi)
13. [Test Cases](#13-test-cases)

---

# 1. INTRODUZIONE E MOTIVAZIONE

## 1.1 Contesto

Nel sistema di grid trading tradizionale, vengono utilizzati quattro tipi di ordini:

| Grid | Zona | Tipo Ordine | Comportamento |
|------|------|-------------|---------------|
| Grid A | Upper | BUY STOP | Fill quando prezzo SALE |
| Grid A | Lower | BUY LIMIT | Fill quando prezzo SCENDE |
| Grid B | Upper | SELL LIMIT | Fill quando prezzo SALE |
| Grid B | Lower | SELL STOP | Fill quando prezzo SCENDE |

## 1.2 Il Problema Identificato

Durante movimenti di prezzo **unidirezionali e violenti** (spike, trending), gli ordini LIMIT vengono fillati in sequenza, creando posizioni contro-trend con **drawdown significativo**.

### Esempio Problematico: Spike Rialzista

```
Prezzo
  ^
  |    SPIKE RIALZISTA VIOLENTO
  |
1.04500 --- SELL LIMIT L4 -> FILL! -> Floating Loss -30 pips
  |              |
1.04400 --- SELL LIMIT L3 -> FILL! -> Floating Loss -20 pips
  |              |
1.04300 --- SELL LIMIT L2 -> FILL! -> Floating Loss -10 pips
  |              |
1.04200 --- SELL LIMIT L1 -> FILL! -> Floating Loss  -0 pips
  |              |
  |         Prezzo continua a salire...
  |         TUTTI i SELL LIMIT fillati!
  |         DRAWDOWN MASSIVO!
  v
```

## 1.3 Obiettivo del Virtual Stop Order Manager

Creare un sistema che:
- **Elimina** completamente gli ordini LIMIT dal broker
- **Gestisce** virtualmente i livelli tramite software
- **Piazza** ordini STOP solo quando le condizioni sono favorevoli
- **Protegge** da fill indesiderati durante trending

---

# 2. IL PROBLEMA DEGLI ORDINI LIMIT

## 2.1 Comportamento Intrinseco

```
+-----------------------------------------------------------------------+
|  SELL LIMIT - Comportamento                                           |
+-----------------------------------------------------------------------+
|                                                                       |
|  SELL LIMIT @ 1.04200                                                 |
|                                                                       |
|  - Prezzo attuale = 1.04100 (SOTTO entry)                             |
|    -> Ordine PENDENTE (aspetta che prezzo SALGA)                      |
|                                                                       |
|  - Prezzo attuale = 1.04300 (SOPRA entry)                             |
|    -> FILL IMMEDIATO! (prezzo gia' oltre)                             |
|                                                                       |
+-----------------------------------------------------------------------+
```

## 2.2 Perche' il LIMIT e' Problematico in Trending

### Scenario: Mercato in Uptrend

```
Tempo -->

        L4 FILL!
           |
     L3 FILL!
        |
   L2 FILL!
      |
 L1 FILL!
    |
----+----+----+----+----+----+----+----+----
    T1   T2   T3   T4   T5   T6   T7   T8

Risultato: 4 posizioni SHORT aperte in 8 tick
           Tutte in perdita crescente
```

### Cosa Vorremmo Invece

```
Tempo -->

        L4 (monitorato, NON fillato)
           |
     L3 (monitorato, NON fillato)
        |
   L2 (monitorato, NON fillato)
      |
 L1 (monitorato, NON fillato)
    |            |
    |            v Prezzo inizia pullback
    |            |
    +-------> L1 FILL! (in contro-trend)

Risultato: 1 sola posizione SHORT
           Aperta nella direzione favorevole
```

---

# 3. LA SOLUZIONE: VIRTUAL STOP ORDER MANAGER

## 3.1 Concetto Fondamentale

```
+-----------------------------------------------------------------------+
|                                                                       |
|  INVECE DI:                                                           |
|  Piazzare SELL LIMIT @ 1.04200 sul broker                             |
|  (rischio fill durante spike UP)                                      |
|                                                                       |
|  FACCIAMO:                                                            |
|  1. Monitoriamo quando prezzo SUPERA 1.04200 (trigger)                |
|  2. Aspettiamo che prezzo TORNI GIU' (pullback)                       |
|  3. SOLO ALLORA piazziamo SELL STOP sotto prezzo corrente             |
|  4. Fill garantito in direzione favorevole                            |
|                                                                       |
+-----------------------------------------------------------------------+
```

## 3.2 Differenza Chiave

| Aspetto | Sistema LIMIT (attuale) | Sistema Virtual STOP |
|---------|------------------------|---------------------|
| Ordini sul broker | LIMIT sempre presenti | Solo STOP quando confermato |
| Fill durante spike | SI (problematico) | NO (protetto) |
| Controllo | Delegato al broker | Gestito dal software |
| Flessibilita' | Limitata | Totale |

## 3.3 Architettura Generale

```
+---------------------------+
|     ORDINI FISSI          |
|     (sempre sul broker)   |
+---------------------------+
|                           |
|  Upper: BUY STOP          |
|  Lower: SELL STOP         |
|                           |
+---------------------------+
            |
            | Coesistono con
            v
+---------------------------+
|    ORDINI VIRTUALI        |
|    (gestiti da software)  |
+---------------------------+
|                           |
|  Upper: Virtual SELL      |
|  Lower: Virtual BUY       |
|                           |
|  -> Diventano STOP solo   |
|     dopo trigger+pullback |
|                           |
+---------------------------+
```

---

# 4. ARCHITETTURA DEL SISTEMA

## 4.1 Moduli Principali

```
+-----------------------------------------------------------------------+
|                    VIRTUAL STOP ORDER MANAGER                         |
+-----------------------------------------------------------------------+
|                                                                       |
|  +-------------------+  +-------------------+  +-------------------+   |
|  |                   |  |                   |  |                   |   |
|  | VirtualOrder      |  | TriggerEngine     |  | StopOrderPlacer   |   |
|  | Manager           |  |                   |  |                   |   |
|  |                   |  |                   |  |                   |   |
|  | - Stato ordini    |  | - Monitora prezzi |  | - Piazza STOP     |   |
|  | - Persistenza     |  | - Rileva trigger  |  | - Gestisce retry  |   |
|  | - Recovery        |  | - Conferma pullb. |  | - Error handling  |   |
|  |                   |  |                   |  |                   |   |
|  +--------+----------+  +--------+----------+  +--------+----------+   |
|           |                      |                      |              |
|           +----------------------+----------------------+              |
|                                  |                                     |
|                                  v                                     |
|                    +----------------------------+                      |
|                    |      Event Dispatcher      |                      |
|                    +----------------------------+                      |
|                    | ON_TRIGGER                 |                      |
|                    | ON_PULLBACK_CONFIRMED      |                      |
|                    | ON_STOP_PLACED             |                      |
|                    | ON_STOP_FILLED             |                      |
|                    | ON_POSITION_CLOSED         |                      |
|                    +----------------------------+                      |
|                                                                       |
+-----------------------------------------------------------------------+
```

## 4.2 Flusso Dati

```
OnTick()
    |
    v
+-------------------+
| TriggerEngine     |
| CheckAllLevels()  |
+-------------------+
    |
    | Eventi
    v
+-------------------+
| VirtualOrder      |
| Manager           |
| UpdateStates()    |
+-------------------+
    |
    | Se stato = CONFIRMED
    v
+-------------------+
| StopOrderPlacer   |
| PlaceStopOrder()  |
+-------------------+
    |
    v
[Ordine STOP sul Broker]
```

---

# 5. LOGICA DEI TRIGGER

## 5.1 Concetto del Trigger al 70%

Il trigger non avviene all'esatto livello di entry, ma al **70% della distanza** verso il livello successivo.

```
Prezzo
  ^
  |
1.04200 ---+--- Livello L2 -----------------------------------------
  |        |
  |        |   ^ 30% rimanente (zona sicura per pullback)
  |        |
1.04170 - -|- - TRIGGER 70% - - - - - - - - - - - - - - - - - - - -
  |        |
  |        |   ^ 70% del spacing (zona di conferma trend)
  |        |
1.04100 ---+--- BUY STOP L1 (entry) --------------------------------
  |
  v

Spacing = 10 pips
Trigger = Entry + (Spacing * 0.70) = 1.04100 + 7 pips = 1.04170
```

## 5.2 Perche' il 70%?

```
+-----------------------------------------------------------------------+
|  MOTIVAZIONE DEL TRIGGER AL 70%                                       |
+-----------------------------------------------------------------------+
|                                                                       |
|  1. CONFERMA MOVIMENTO                                                |
|     Se il prezzo ha percorso il 70% verso il prossimo livello,        |
|     il movimento e' "significativo" e non solo rumore                 |
|                                                                       |
|  2. SPAZIO PER PULLBACK                                               |
|     Rimane il 30% di spazio per il pullback prima del livello         |
|     successivo, dando tempo al software di reagire                    |
|                                                                       |
|  3. EVITA FALSE ATTIVAZIONI                                           |
|     Trigger troppo vicino all'entry (es. 50%) causerebbe              |
|     troppe attivazioni su movimenti minori                            |
|                                                                       |
|  4. BILANCIAMENTO                                                     |
|     70% e' un buon compromesso tra:                                   |
|     - Conferma trend (piu' alto = piu' sicuro)                        |
|     - Opportunita' di trading (piu' basso = piu' trades)              |
|                                                                       |
+-----------------------------------------------------------------------+
```

## 5.3 Trigger per Virtual SELL (Upper Zone)

```
Condizione: Prezzo corrente >= Trigger Price (70%)

Prezzo
  ^
  |
  |              * Prezzo qui o sopra = TRIGGER!
  |             /
1.04170 ------*------ TRIGGER LINE (70%) --------------------------
  |          /
  |         /  Prezzo sale
  |        /
1.04100 --*-------- Entry BUY STOP L1 ------------------------------
  |
  v

Azione quando TRIGGERED:
- Marca VirtualSell[level].state = VIRTUAL_TRIGGERED
- Salva VirtualSell[level].triggerTime = TimeCurrent()
- Inizia monitoraggio pullback
```

## 5.4 Conferma Pullback per Virtual SELL

```
Condizione: Prezzo corrente < Trigger Price - PullbackOffset

Prezzo
  ^
  |
1.04200 --*-------- Massimo raggiunto ------------------------------
  |        \
  |         \  Prezzo inizia a scendere
  |          \
1.04170 ------\------ TRIGGER LINE (70%) --------------------------
  |            \
  |             \
1.04150 --------*---- PULLBACK CONFIRMED! (trigger - 2 pips) ------
  |
  v

Azione quando PULLBACK CONFIRMED:
- Marca VirtualSell[level].state = VIRTUAL_CONFIRMED
- Calcola stopEntryPrice = CurrentPrice - StopOffset
- Prepara piazzamento SELL STOP
```

## 5.5 Logica Speculare per Virtual BUY (Lower Zone)

```
Virtual BUY - Trigger quando prezzo SCENDE

Prezzo
  ^
  |
1.04000 --*-------- Entry SELL STOP L1 -----------------------------
  |        \
  |         \  Prezzo scende
  |          \
1.03930 ------*------ TRIGGER LINE (70% sotto) ---------------------
  |            \
  |             \  Prezzo continua a scendere
  |              \
1.03900 ----------*-- Minimo raggiunto -----------------------------
  |              /
  |             /  Prezzo inizia a RISALIRE (pullback UP)
  |            /
1.03950 ------*------ PULLBACK CONFIRMED! --------------------------
  |
  v

Azione: Piazza BUY STOP sopra prezzo corrente
```

---

# 6. STATE MACHINE

## 6.1 Stati del Virtual Order

```
+-----------------------------------------------------------------------+
|                    STATI DEL VIRTUAL ORDER                            |
+-----------------------------------------------------------------------+

  +----------------+
  |   INACTIVE     |  Stato iniziale, livello non ancora raggiunto
  +-------+--------+
          |
          | Prezzo raggiunge trigger (70%)
          v
  +----------------+
  |   TRIGGERED    |  Livello attivato, in attesa di pullback
  +-------+--------+
          |
          | Prezzo conferma pullback (scende/sale abbastanza)
          v
  +----------------+
  |   CONFIRMED    |  Pullback confermato, pronto per piazzare STOP
  +-------+--------+
          |
          | STOP order piazzato con successo
          v
  +----------------+
  |   PLACED       |  STOP order sul broker, in attesa di fill
  +-------+--------+
          |
          | STOP order fillato
          v
  +----------------+
  |   FILLED       |  Posizione aperta, in attesa di TP/SL
  +-------+--------+
          |
          | Posizione chiusa (TP o SL)
          v
  +----------------+
  |   CLOSED       |  Ciclo completato, pronto per reset
  +-------+--------+
          |
          | Reset per nuovo ciclo
          v
  +----------------+
  |   INACTIVE     |  Torna allo stato iniziale
  +----------------+
```

## 6.2 Transizioni di Stato

```
+---------------+-------------------+----------------------------------+
| Stato Attuale | Condizione        | Nuovo Stato                      |
+---------------+-------------------+----------------------------------+
| INACTIVE      | price >= trigger  | TRIGGERED (per SELL)             |
| INACTIVE      | price <= trigger  | TRIGGERED (per BUY)              |
+---------------+-------------------+----------------------------------+
| TRIGGERED     | pullback confirm  | CONFIRMED                        |
| TRIGGERED     | timeout expired   | INACTIVE (reset)                 |
+---------------+-------------------+----------------------------------+
| CONFIRMED     | STOP placed OK    | PLACED                           |
| CONFIRMED     | STOP place FAIL   | CONFIRMED (retry next tick)      |
+---------------+-------------------+----------------------------------+
| PLACED        | STOP filled       | FILLED                           |
| PLACED        | STOP cancelled    | INACTIVE (reset)                 |
+---------------+-------------------+----------------------------------+
| FILLED        | position closed   | CLOSED                           |
+---------------+-------------------+----------------------------------+
| CLOSED        | cyclic reopen     | INACTIVE (new cycle)             |
+---------------+-------------------+----------------------------------+
```

## 6.3 Diagramma Visivo

```
                    +-------------+
                    |  INACTIVE   |<-----------------------+
                    +------+------+                        |
                           |                               |
              price crosses trigger                        |
                           |                               |
                    +------v------+                        |
            +------>|  TRIGGERED  |                        |
            |       +------+------+                        |
            |              |                               |
      timeout              | pullback confirmed            |
      expired              |                               |
            |       +------v------+                        |
            +-------+  CONFIRMED  |                        |
                    +------+------+                        |
                           |                               |
                    STOP placed                            |
                           |                               |
                    +------v------+                        |
                    |   PLACED    |                        |
                    +------+------+                        |
                           |                               |
                    STOP filled                            |
                           |                               |
                    +------v------+                        |
                    |   FILLED    |                        |
                    +------+------+                        |
                           |                               |
                    position closed                        |
                           |                               |
                    +------v------+                        |
                    |   CLOSED    +------------------------+
                    +-------------+
                         cyclic reopen
```

---

# 7. FLUSSI OPERATIVI CON ESEMPI

## 7.1 Esempio Completo: Virtual SELL durante Uptrend

### Setup Iniziale

```
Entry Point: 1.04100
Spacing: 10 pips
Trigger: 70% = 7 pips
Pullback Offset: 2 pips
Stop Offset: 3 pips

Livelli:
- BUY STOP L1 @ 1.04200 (fisso sul broker)
- Virtual SELL L1: trigger @ 1.04170
```

### Fase 1: Prezzo Sale (T1-T3)

```
Tempo: T1
Prezzo: 1.04120
Virtual SELL L1: INACTIVE
Azione: Nessuna

Prezzo
  ^
  |
1.04200 --------- BUY STOP L1 ----------
  |
1.04170 - - - - - Trigger - - - - - - -
  |
1.04120 ----*---- Prezzo qui -----------
  |
1.04100 --------- Entry Point ----------
  v

---

Tempo: T2
Prezzo: 1.04155
Virtual SELL L1: INACTIVE
Azione: Nessuna (sotto trigger)

---

Tempo: T3
Prezzo: 1.04175
Virtual SELL L1: INACTIVE -> TRIGGERED!
Azione: Stato cambia, inizia monitoraggio pullback

Prezzo
  ^
  |
1.04200 --------- BUY STOP L1 ----------
  |
1.04175 ----*---- Prezzo SOPRA trigger!
  |
1.04170 - - - - - Trigger - - - - - - -
  |
1.04100 --------- Entry Point ----------
  v

Log: "[VirtualOrder] SELL L1 TRIGGERED @ 1.04175"
```

### Fase 2: Prezzo Continua a Salire (T4-T5) - PROTEZIONE ATTIVA

```
Tempo: T4
Prezzo: 1.04195
Virtual SELL L1: TRIGGERED (in attesa pullback)
Azione: Nessuna - Il prezzo sale ma NON c'e' fill!

Prezzo
  ^
  |
1.04200 --------- BUY STOP L1 ----------
  |
1.04195 ----*---- Prezzo qui -----------
  |
1.04170 - - - - - Trigger - - - - - - -
  |
  |
1.04100 --------- Entry Point ----------
  v

IMPORTANTE: Con SELL LIMIT tradizionale, qui avremmo gia' una
            posizione SHORT aperta! Con Virtual STOP, nessun fill.

---

Tempo: T5
Prezzo: 1.04210
Virtual SELL L1: TRIGGERED
BUY STOP L1: FILLED! (posizione LONG aperta)
Azione: Monitora sia LONG che virtual SELL

Prezzo
  ^
  |
1.04210 ----*---- Prezzo qui (sopra L1)
  |
1.04200 --------- BUY STOP L1 FILL! ----
  |
1.04170 - - - - - Trigger - - - - - - -
  |
1.04100 --------- Entry Point ----------
  v

Log: "[Grid] BUY STOP L1 FILLED @ 1.04200"
```

### Fase 3: Pullback Inizia (T6-T7)

```
Tempo: T6
Prezzo: 1.04180
Virtual SELL L1: TRIGGERED
Azione: Prezzo scende ma non ancora sotto (trigger - pullbackOffset)
        PullbackConfirm = 1.04170 - 2 = 1.04168

Prezzo
  ^
  |
1.04200 --------- BUY STOP L1 (filled) -
  |
1.04180 ----*---- Prezzo qui -----------
  |
1.04170 - - - - - Trigger - - - - - - -
1.04168 . . . . . Pullback Confirm . . .
  |
1.04100 --------- Entry Point ----------
  v

---

Tempo: T7
Prezzo: 1.04165
Virtual SELL L1: TRIGGERED -> CONFIRMED!
Azione: Pullback confermato! Prepara SELL STOP

Prezzo
  ^
  |
1.04200 --------- BUY STOP L1 (filled) -
  |
1.04170 - - - - - Trigger - - - - - - -
1.04168 . . . . . Pullback Confirm . . .
  |
1.04165 ----*---- Prezzo SOTTO confirm!
  |
1.04100 --------- Entry Point ----------
  v

Log: "[VirtualOrder] SELL L1 PULLBACK CONFIRMED @ 1.04165"
```

### Fase 4: Piazzamento SELL STOP (T8)

```
Tempo: T8
Prezzo: 1.04165
Virtual SELL L1: CONFIRMED -> PLACED
Azione: Piazza SELL STOP @ 1.04162 (prezzo - 3 pips offset)

Prezzo
  ^
  |
1.04200 --------- BUY STOP L1 (filled) -
  |
1.04170 - - - - - Trigger - - - - - - -
  |
1.04165 ----*---- Prezzo qui -----------
  |
1.04162 ========= SELL STOP PIAZZATO ===
  |
1.04100 --------- Entry Point ----------
  v

Log: "[VirtualOrder] SELL STOP L1 PLACED @ 1.04162"
```

### Fase 5: Fill e Profitto (T9-T10)

```
Tempo: T9
Prezzo: 1.04155
Virtual SELL L1: PLACED -> FILLED
SELL STOP: Fillato!
Azione: Posizione SHORT aperta, TP @ 1.04062

Prezzo
  ^
  |
1.04200 --------- BUY STOP L1 (filled) -
  |
1.04162 ========= SELL STOP FILLED! ====
  |
1.04155 ----*---- Prezzo qui -----------
  |
1.04100 --------- Entry Point ----------
  |
1.04062 - - - - - TP SELL - - - - - - -
  v

Log: "[VirtualOrder] SELL STOP L1 FILLED @ 1.04162"

---

Tempo: T10
Prezzo: 1.04062
Virtual SELL L1: FILLED -> CLOSED
Azione: TP raggiunto! Profit = 10 pips

Prezzo
  ^
  |
1.04200 --------- BUY STOP L1 (filled) -
  |
1.04162 ========= SELL entry ===========
  |
1.04100 --------- Entry Point ----------
  |
1.04062 ----*---- TP HIT! Profit +10 ---
  v

Log: "[VirtualOrder] SELL L1 CLOSED @ TP +10 pips"
```

## 7.2 Esempio: Spike Senza Pullback (Protezione Attiva)

```
Scenario: Prezzo sale violentemente senza mai ritracciare

Tempo: T1-T5
Prezzo: 1.04100 -> 1.04200 -> 1.04300 -> 1.04400 -> 1.04500

Virtual SELL L1: INACTIVE -> TRIGGERED (resta TRIGGERED)
Virtual SELL L2: INACTIVE -> TRIGGERED (resta TRIGGERED)
Virtual SELL L3: INACTIVE -> TRIGGERED (resta TRIGGERED)

NESSUN SELL STOP PIAZZATO!
NESSUNA POSIZIONE SHORT!
ZERO DRAWDOWN!

+-----------------------------------------------------------------------+
|  CONFRONTO                                                            |
+-----------------------------------------------------------------------+
|                                                                       |
|  Con SELL LIMIT tradizionali:                                         |
|  - 4 posizioni SHORT aperte                                           |
|  - Drawdown: -10 -20 -30 -40 = -100 pips                              |
|                                                                       |
|  Con Virtual STOP:                                                    |
|  - 0 posizioni SHORT aperte                                           |
|  - Drawdown: 0 pips                                                   |
|                                                                       |
+-----------------------------------------------------------------------+
```

---

# 8. STRUTTURE DATI MQL5

## 8.1 Enumerazioni

```cpp
//+------------------------------------------------------------------+
//| VIRTUAL ORDER ENUMS                                              |
//+------------------------------------------------------------------+

// Stato del virtual order
enum ENUM_VIRTUAL_STATE {
    VIRTUAL_INACTIVE,      // Non ancora triggerato
    VIRTUAL_TRIGGERED,     // Prezzo ha superato il trigger
    VIRTUAL_CONFIRMED,     // Pullback confermato
    VIRTUAL_PLACED,        // STOP order piazzato sul broker
    VIRTUAL_FILLED,        // STOP fillato, posizione aperta
    VIRTUAL_CLOSED         // Posizione chiusa (TP/SL)
};

// Tipo di virtual order
enum ENUM_VIRTUAL_TYPE {
    VIRTUAL_SELL,          // Virtual SELL (sostituisce SELL LIMIT)
    VIRTUAL_BUY            // Virtual BUY (sostituisce BUY LIMIT)
};

// Direzione pullback richiesta
enum ENUM_PULLBACK_DIR {
    PULLBACK_DOWN,         // Per SELL: prezzo deve scendere
    PULLBACK_UP            // Per BUY: prezzo deve salire
};
```

## 8.2 Struttura Virtual Order

```cpp
//+------------------------------------------------------------------+
//| VIRTUAL ORDER STRUCTURE                                          |
//+------------------------------------------------------------------+
struct VirtualOrder {
    // Identificazione
    int                 level;              // Livello grid (1, 2, 3...)
    ENUM_VIRTUAL_TYPE   type;               // VIRTUAL_SELL o VIRTUAL_BUY

    // Prezzi
    double              baseEntryPrice;     // Entry originale (livello grid)
    double              triggerPrice;       // Prezzo trigger (70%)
    double              pullbackConfirm;    // Prezzo conferma pullback
    double              stopEntryPrice;     // Dove piazzare lo STOP
    double              tpPrice;            // Take Profit
    double              slPrice;            // Stop Loss (se usato)

    // Stato
    ENUM_VIRTUAL_STATE  state;              // Stato corrente
    datetime            triggerTime;        // Quando e' stato triggerato
    datetime            confirmTime;        // Quando pullback confermato
    int                 cycleCount;         // Numero di cicli completati

    // Ordine reale (quando piazzato)
    ulong               stopTicket;         // Ticket dello STOP order
    ulong               positionTicket;     // Ticket della posizione

    // Statistiche
    double              realizedProfit;     // Profitto realizzato totale
    int                 wins;               // Cicli in profitto
    int                 losses;             // Cicli in perdita
};
```

## 8.3 Manager Arrays

```cpp
//+------------------------------------------------------------------+
//| VIRTUAL ORDER MANAGER ARRAYS                                     |
//+------------------------------------------------------------------+

// Array di virtual orders per zona
VirtualOrder g_virtualSells[];    // Upper zone (sostituisce SELL LIMIT)
VirtualOrder g_virtualBuys[];     // Lower zone (sostituisce BUY LIMIT)

// Contatori
int g_virtualSellsCount = 0;
int g_virtualBuysCount = 0;

// Costanti
#define MAX_VIRTUAL_LEVELS 20
```

## 8.4 Funzioni di Inizializzazione

```cpp
//+------------------------------------------------------------------+
//| Initialize Virtual Orders                                        |
//+------------------------------------------------------------------+
bool InitializeVirtualOrders() {
    // Resize arrays
    ArrayResize(g_virtualSells, GridLevelsPerSide);
    ArrayResize(g_virtualBuys, GridLevelsPerSide);

    double spacing = PipsToPoints(currentSpacing_Pips);
    double triggerOffset = spacing * (TriggerPercent / 100.0);
    double pullbackOffset = PipsToPoints(PullbackConfirm_Pips);

    // Initialize Virtual SELL orders (Upper zone)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        g_virtualSells[i].level = i + 1;
        g_virtualSells[i].type = VIRTUAL_SELL;
        g_virtualSells[i].baseEntryPrice = entryPoint + (spacing * (i + 1));
        g_virtualSells[i].triggerPrice = entryPoint + (triggerOffset * (i + 1));
        g_virtualSells[i].pullbackConfirm = g_virtualSells[i].triggerPrice - pullbackOffset;
        g_virtualSells[i].state = VIRTUAL_INACTIVE;
        g_virtualSells[i].stopTicket = 0;
        g_virtualSells[i].cycleCount = 0;

        // TP = entry - spacing (come SELL LIMIT originale)
        g_virtualSells[i].tpPrice = g_virtualSells[i].baseEntryPrice - spacing;
    }

    // Initialize Virtual BUY orders (Lower zone)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        g_virtualBuys[i].level = i + 1;
        g_virtualBuys[i].type = VIRTUAL_BUY;
        g_virtualBuys[i].baseEntryPrice = entryPoint - (spacing * (i + 1));
        g_virtualBuys[i].triggerPrice = entryPoint - (triggerOffset * (i + 1));
        g_virtualBuys[i].pullbackConfirm = g_virtualBuys[i].triggerPrice + pullbackOffset;
        g_virtualBuys[i].state = VIRTUAL_INACTIVE;
        g_virtualBuys[i].stopTicket = 0;
        g_virtualBuys[i].cycleCount = 0;

        // TP = entry + spacing (come BUY LIMIT originale)
        g_virtualBuys[i].tpPrice = g_virtualBuys[i].baseEntryPrice + spacing;
    }

    g_virtualSellsCount = GridLevelsPerSide;
    g_virtualBuysCount = GridLevelsPerSide;

    LogVirtualOrdersConfig();
    return true;
}
```

---

# 9. ISTRUZIONI DI IMPLEMENTAZIONE

## 9.1 File da Creare

```
Trading/
    |
    +-- VirtualOrderManager.mqh      // Gestione stato virtual orders
    |
    +-- TriggerEngine.mqh            // Logica trigger e pullback
    |
    +-- VirtualStopPlacer.mqh        // Piazzamento STOP orders
```

## 9.2 Modifiche ai File Esistenti

```
Sugamara.mq5
    |
    +-- #include "Trading/VirtualOrderManager.mqh"
    +-- #include "Trading/TriggerEngine.mqh"
    +-- #include "Trading/VirtualStopPlacer.mqh"
    |
    +-- OnInit(): InitializeVirtualOrders()
    +-- OnTick(): ProcessVirtualOrders()
    +-- OnDeinit(): SaveVirtualOrdersState()

Config/InputParameters.mqh
    |
    +-- Nuova sezione: "VIRTUAL STOP ORDER MANAGER"
    +-- EnableVirtualStopMode
    +-- TriggerPercent
    +-- PullbackConfirm_Pips
    +-- StopPlacementOffset_Pips
```

## 9.3 Funzione Principale OnTick

```cpp
//+------------------------------------------------------------------+
//| Process Virtual Orders - Called from OnTick()                    |
//+------------------------------------------------------------------+
void ProcessVirtualOrders() {
    if(!EnableVirtualStopMode) return;

    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);

    // Process Virtual SELL orders (Upper zone)
    for(int i = 0; i < g_virtualSellsCount; i++) {
        ProcessVirtualSell(i, currentPrice);
    }

    // Process Virtual BUY orders (Lower zone)
    for(int i = 0; i < g_virtualBuysCount; i++) {
        ProcessVirtualBuy(i, currentPrice);
    }
}

//+------------------------------------------------------------------+
//| Process Single Virtual SELL Order                                |
//+------------------------------------------------------------------+
void ProcessVirtualSell(int index, double currentPrice) {
    VirtualOrder* vo = GetPointer(g_virtualSells[index]);

    switch(vo.state) {
        case VIRTUAL_INACTIVE:
            // Check if price reached trigger (going UP)
            if(currentPrice >= vo.triggerPrice) {
                vo.state = VIRTUAL_TRIGGERED;
                vo.triggerTime = TimeCurrent();
                PrintFormat("[Virtual] SELL L%d TRIGGERED @ %.5f",
                            vo.level, currentPrice);
            }
            break;

        case VIRTUAL_TRIGGERED:
            // Check for pullback confirmation (price going DOWN)
            if(currentPrice <= vo.pullbackConfirm) {
                vo.state = VIRTUAL_CONFIRMED;
                vo.confirmTime = TimeCurrent();
                // Calculate STOP entry price
                vo.stopEntryPrice = currentPrice - PipsToPoints(StopPlacementOffset_Pips);
                PrintFormat("[Virtual] SELL L%d PULLBACK CONFIRMED @ %.5f",
                            vo.level, currentPrice);
            }
            // Optional: timeout reset
            else if(TimeCurrent() - vo.triggerTime > TriggerTimeout_Seconds) {
                vo.state = VIRTUAL_INACTIVE;
                PrintFormat("[Virtual] SELL L%d TRIGGER TIMEOUT - Reset", vo.level);
            }
            break;

        case VIRTUAL_CONFIRMED:
            // Place SELL STOP order
            if(PlaceVirtualSellStop(index)) {
                vo.state = VIRTUAL_PLACED;
            }
            break;

        case VIRTUAL_PLACED:
            // Monitor STOP order status
            CheckVirtualSellStopStatus(index);
            break;

        case VIRTUAL_FILLED:
            // Monitor position for TP/SL
            CheckVirtualSellPositionStatus(index);
            break;

        case VIRTUAL_CLOSED:
            // Ready for cyclic reopen
            if(EnableCyclicReopen) {
                vo.state = VIRTUAL_INACTIVE;
                vo.cycleCount++;
                PrintFormat("[Virtual] SELL L%d RESET for cycle %d",
                            vo.level, vo.cycleCount);
            }
            break;
    }
}
```

## 9.4 Funzione Piazzamento STOP

```cpp
//+------------------------------------------------------------------+
//| Place Virtual SELL STOP Order                                    |
//+------------------------------------------------------------------+
bool PlaceVirtualSellStop(int index) {
    VirtualOrder* vo = GetPointer(g_virtualSells[index]);

    double entryPrice = vo.stopEntryPrice;
    double tp = vo.tpPrice;
    double sl = 0;  // No SL, gestito da hedging
    double lot = CalculateGridLotSize(vo.level - 1);

    // Validate entry price for SELL STOP
    double currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    if(entryPrice >= currentPrice) {
        // Invalid: SELL STOP must be below current price
        PrintFormat("[Virtual] SELL STOP L%d invalid price: entry %.5f >= current %.5f",
                    vo.level, entryPrice, currentPrice);
        return false;
    }

    // Place order
    ulong ticket = PlacePendingOrder(
        ORDER_TYPE_SELL_STOP,
        lot,
        entryPrice,
        sl,
        tp,
        "VSELL_L" + IntegerToString(vo.level),
        MAGIC_VIRTUAL_SELL
    );

    if(ticket > 0) {
        vo.stopTicket = ticket;
        PrintFormat("[Virtual] SELL STOP L%d PLACED @ %.5f (ticket %d)",
                    vo.level, entryPrice, ticket);
        return true;
    }

    PrintFormat("[Virtual] SELL STOP L%d FAILED to place", vo.level);
    return false;
}
```

---

# 10. GESTIONE RECOVERY

## 10.1 Salvataggio Stato

```cpp
//+------------------------------------------------------------------+
//| Save Virtual Orders State to GlobalVariables                     |
//+------------------------------------------------------------------+
void SaveVirtualOrdersState() {
    string prefix = "VSOM_" + _Symbol + "_";

    // Save Virtual SELL states
    for(int i = 0; i < g_virtualSellsCount; i++) {
        string key = prefix + "SELL_" + IntegerToString(i);
        GlobalVariableSet(key + "_state", (double)g_virtualSells[i].state);
        GlobalVariableSet(key + "_trigger", g_virtualSells[i].triggerPrice);
        GlobalVariableSet(key + "_ticket", (double)g_virtualSells[i].stopTicket);
        GlobalVariableSet(key + "_cycles", (double)g_virtualSells[i].cycleCount);
    }

    // Save Virtual BUY states
    for(int i = 0; i < g_virtualBuysCount; i++) {
        string key = prefix + "BUY_" + IntegerToString(i);
        GlobalVariableSet(key + "_state", (double)g_virtualBuys[i].state);
        GlobalVariableSet(key + "_trigger", g_virtualBuys[i].triggerPrice);
        GlobalVariableSet(key + "_ticket", (double)g_virtualBuys[i].stopTicket);
        GlobalVariableSet(key + "_cycles", (double)g_virtualBuys[i].cycleCount);
    }

    Print("[Virtual] State saved to GlobalVariables");
}

//+------------------------------------------------------------------+
//| Load Virtual Orders State from GlobalVariables                   |
//+------------------------------------------------------------------+
bool LoadVirtualOrdersState() {
    string prefix = "VSOM_" + _Symbol + "_";

    // Check if saved state exists
    if(!GlobalVariableCheck(prefix + "SELL_0_state")) {
        Print("[Virtual] No saved state found - starting fresh");
        return false;
    }

    // Load Virtual SELL states
    for(int i = 0; i < g_virtualSellsCount; i++) {
        string key = prefix + "SELL_" + IntegerToString(i);
        g_virtualSells[i].state = (ENUM_VIRTUAL_STATE)GlobalVariableGet(key + "_state");
        g_virtualSells[i].triggerPrice = GlobalVariableGet(key + "_trigger");
        g_virtualSells[i].stopTicket = (ulong)GlobalVariableGet(key + "_ticket");
        g_virtualSells[i].cycleCount = (int)GlobalVariableGet(key + "_cycles");
    }

    // Load Virtual BUY states
    for(int i = 0; i < g_virtualBuysCount; i++) {
        string key = prefix + "BUY_" + IntegerToString(i);
        g_virtualBuys[i].state = (ENUM_VIRTUAL_STATE)GlobalVariableGet(key + "_state");
        g_virtualBuys[i].triggerPrice = GlobalVariableGet(key + "_trigger");
        g_virtualBuys[i].stopTicket = (ulong)GlobalVariableGet(key + "_ticket");
        g_virtualBuys[i].cycleCount = (int)GlobalVariableGet(key + "_cycles");
    }

    Print("[Virtual] State loaded from GlobalVariables");
    return true;
}
```

## 10.2 Sincronizzazione con Ordini Broker

```cpp
//+------------------------------------------------------------------+
//| Sync Virtual Orders with Broker Orders                           |
//+------------------------------------------------------------------+
void SyncVirtualOrdersWithBroker() {
    // Per ogni virtual order con stato PLACED o FILLED
    // Verifica che l'ordine/posizione esista ancora sul broker

    for(int i = 0; i < g_virtualSellsCount; i++) {
        if(g_virtualSells[i].state == VIRTUAL_PLACED) {
            // Verifica se l'ordine pendente esiste
            if(!OrderSelect(g_virtualSells[i].stopTicket)) {
                // Ordine non esiste - potrebbe essere stato fillato
                if(PositionSelectByTicket(g_virtualSells[i].stopTicket)) {
                    g_virtualSells[i].state = VIRTUAL_FILLED;
                    Print("[Virtual] SELL L", i+1, " synced to FILLED");
                } else {
                    // Ordine cancellato - reset
                    g_virtualSells[i].state = VIRTUAL_INACTIVE;
                    g_virtualSells[i].stopTicket = 0;
                    Print("[Virtual] SELL L", i+1, " order lost - reset");
                }
            }
        }
        else if(g_virtualSells[i].state == VIRTUAL_FILLED) {
            // Verifica se la posizione esiste ancora
            if(!PositionSelectByTicket(g_virtualSells[i].stopTicket)) {
                g_virtualSells[i].state = VIRTUAL_CLOSED;
                Print("[Virtual] SELL L", i+1, " position closed - synced");
            }
        }
    }

    // Stessa logica per Virtual BUY...
}
```

---

# 11. PARAMETRI CONFIGURABILI

## 11.1 Input Parameters

```cpp
//+------------------------------------------------------------------+
//| VIRTUAL STOP ORDER MANAGER - Input Parameters                    |
//+------------------------------------------------------------------+

input string VSM_Settings = "=== VIRTUAL STOP ORDER MANAGER ===";

input bool   EnableVirtualStopMode = false;        // Attiva Virtual Stop Mode
                                                   // true = Usa virtual orders invece di LIMIT
                                                   // false = Usa LIMIT tradizionali

input double TriggerPercent = 70.0;                // Trigger % del spacing
                                                   // 70 = trigger al 70% verso livello successivo
                                                   // Range consigliato: 60-80%

input double PullbackConfirm_Pips = 2.0;           // Pips pullback per conferma
                                                   // Quanto deve ritracciare per confermare
                                                   // Range consigliato: 1-5 pips

input double StopPlacementOffset_Pips = 3.0;       // Offset piazzamento STOP
                                                   // Distanza STOP da prezzo corrente
                                                   // Range consigliato: 2-5 pips

input int    TriggerTimeout_Seconds = 300;         // Timeout trigger (secondi)
                                                   // Dopo questo tempo senza pullback, reset
                                                   // 0 = nessun timeout

input bool   VSM_DetailedLogging = false;          // Log dettagliato VSM
                                                   // Abilita per debug
```

## 11.2 Tabella Configurazioni Consigliate

```
+-----------------------------------------------------------------------+
|  CONFIGURAZIONI CONSIGLIATE PER SCENARI                               |
+-----------------------------------------------------------------------+

CONSERVATIVO (massima protezione):
- TriggerPercent = 80%
- PullbackConfirm_Pips = 3.0
- StopPlacementOffset_Pips = 5.0
- TriggerTimeout_Seconds = 600

Pro: Massima protezione da spike
Contro: Meno trades, alcuni cicli persi

---

BILANCIATO (default consigliato):
- TriggerPercent = 70%
- PullbackConfirm_Pips = 2.0
- StopPlacementOffset_Pips = 3.0
- TriggerTimeout_Seconds = 300

Pro: Buon equilibrio protezione/opportunita'
Contro: -

---

AGGRESSIVO (piu' trades):
- TriggerPercent = 60%
- PullbackConfirm_Pips = 1.0
- StopPlacementOffset_Pips = 2.0
- TriggerTimeout_Seconds = 120

Pro: Piu' trades, piu' cicli
Contro: Minore protezione da spike

+-----------------------------------------------------------------------+
```

---

# 12. VANTAGGI E SVANTAGGI

## 12.1 Vantaggi

```
+-----------------------------------------------------------------------+
|  VANTAGGI DEL VIRTUAL STOP ORDER MANAGER                              |
+-----------------------------------------------------------------------+

1. PROTEZIONE TOTALE DA SPIKE
   -------------------------
   - Durante movimenti unidirezionali violenti, NESSUN fill indesiderato
   - Zero drawdown da posizioni contro-trend
   - Il sistema "aspetta" che il mercato confermi il pullback

2. CONTROLLO COMPLETO
   ------------------
   - Ogni ordine e' piazzato solo quando le condizioni sono ideali
   - Possibilita' di aggiungere filtri (momentum, ATR, news)
   - Logica completamente personalizzabile

3. FILL IN DIREZIONE FAVOREVOLE
   ----------------------------
   - Gli ordini vengono fillati solo quando il mercato va nella
     direzione del trade (pullback confermato)
   - Migliore win rate teorico

4. ORDINI STOP PIU' PREVEDIBILI
   ----------------------------
   - Comportamento STOP e' lineare: "se prezzo arriva qui, esegui"
   - Meno ambiguita' rispetto ai LIMIT

5. RECOVERY ROBUSTO
   -----------------
   - Stato salvato in GlobalVariables
   - Al restart, ricostruzione automatica dello stato

6. STATISTICHE DETTAGLIATE
   -----------------------
   - Tracking per ogni livello: cicli, win/loss, profit
   - Analisi performance granulare

+-----------------------------------------------------------------------+
```

## 12.2 Svantaggi

```
+-----------------------------------------------------------------------+
|  SVANTAGGI E MITIGAZIONI                                              |
+-----------------------------------------------------------------------+

1. COMPLESSITA' CODICE
   --------------------
   Problema: Piu' codice da scrivere e mantenere
   Mitigazione: Architettura modulare, documentazione completa

2. ENTRY PRICE POTENZIALMENTE PEGGIORE
   ------------------------------------
   Problema: STOP piazzato sotto/sopra il livello originale
   Mitigazione: Offset configurabile, entry comunque in direzione favorevole

3. CICLI PERSI
   ------------
   Problema: Se non c'e' pullback, nessun trade
   Mitigazione: Timeout configurabile, in trending e' meglio NON tradare

4. LATENZA
   --------
   Problema: Tempo tra conferma e piazzamento ordine
   Mitigazione: Esecuzione immediata dopo conferma, offset di sicurezza

5. GAP DI PREZZO
   --------------
   Problema: Prezzo salta piu' livelli in un tick
   Mitigazione: Loop su tutti i livelli ogni tick, gestione multi-trigger

6. DIPENDENZA DA EA ATTIVO
   ------------------------
   Problema: Se EA si ferma, virtual orders non esistono
   Mitigazione: Persistenza stato, recovery automatico

+-----------------------------------------------------------------------+
```

---

# 13. TEST CASES

## 13.1 Test Case 1: Spike UP Senza Pullback

```
SCENARIO:
- Entry Point: 1.04100
- Prezzo sale da 1.04100 a 1.04500 senza mai ritracciare
- 4 livelli Virtual SELL triggerati

COMPORTAMENTO ATTESO:
- Virtual SELL L1: INACTIVE -> TRIGGERED (resta TRIGGERED)
- Virtual SELL L2: INACTIVE -> TRIGGERED (resta TRIGGERED)
- Virtual SELL L3: INACTIVE -> TRIGGERED (resta TRIGGERED)
- Virtual SELL L4: INACTIVE -> TRIGGERED (resta TRIGGERED)
- NESSUN SELL STOP piazzato
- ZERO posizioni SHORT

VERIFICA:
[ ] Tutti i livelli in stato TRIGGERED
[ ] Nessun ordine SELL STOP sul broker
[ ] Log mostra "TRIGGERED" ma mai "CONFIRMED"
```

## 13.2 Test Case 2: Spike UP con Pullback

```
SCENARIO:
- Entry Point: 1.04100
- Prezzo sale a 1.04250 (trigger L1 = 1.04170)
- Prezzo ritraccia a 1.04160 (sotto pullback confirm)
- Prezzo continua a scendere

COMPORTAMENTO ATTESO:
- Virtual SELL L1: INACTIVE -> TRIGGERED -> CONFIRMED -> PLACED -> FILLED
- SELL STOP piazzato @ ~1.04157 (prezzo - offset)
- Fill quando prezzo scende a 1.04157
- TP @ 1.04057

VERIFICA:
[ ] Virtual SELL L1 passa tutti gli stati
[ ] SELL STOP visibile sul broker
[ ] Fill avviene a prezzo corretto
[ ] TP raggiunto
```

## 13.3 Test Case 3: Timeout Trigger

```
SCENARIO:
- Entry Point: 1.04100
- Prezzo sale a 1.04180 (trigger L1)
- Prezzo resta tra 1.04180 e 1.04250 per 5 minuti
- Nessun pullback sotto 1.04168

COMPORTAMENTO ATTESO:
- Virtual SELL L1: INACTIVE -> TRIGGERED
- Dopo TriggerTimeout_Seconds (300s): TRIGGERED -> INACTIVE (reset)

VERIFICA:
[ ] Stato resettato dopo timeout
[ ] Log mostra "TRIGGER TIMEOUT - Reset"
[ ] Livello pronto per nuovo trigger
```

## 13.4 Test Case 4: Recovery dopo Restart

```
SCENARIO:
- EA attivo con Virtual SELL L1 in stato PLACED (ticket 12345)
- EA viene fermato/riavviato
- Ordine 12345 ancora esistente sul broker

COMPORTAMENTO ATTESO:
- Al restart: LoadVirtualOrdersState() carica stato salvato
- SyncVirtualOrdersWithBroker() verifica ordine 12345 esiste
- Virtual SELL L1 ripristinato in stato PLACED
- Monitoraggio continua normalmente

VERIFICA:
[ ] Stato caricato da GlobalVariables
[ ] Ordine sincronizzato correttamente
[ ] Nessun ordine duplicato
```

## 13.5 Test Case 5: Multi-Level Trigger

```
SCENARIO:
- Entry Point: 1.04100
- Gap notturno: prezzo apre a 1.04350
- Tutti i trigger sotto 1.04350 attivati simultaneamente

COMPORTAMENTO ATTESO:
- Virtual SELL L1: TRIGGERED (trigger 1.04170)
- Virtual SELL L2: TRIGGERED (trigger 1.04270)
- Tutti in attesa di pullback

VERIFICA:
[ ] Tutti i livelli in TRIGGERED
[ ] Nessun ordine piazzato (no pullback)
[ ] Al primo pullback, conferma del livello appropriato
```

---

# APPENDICE A: DIAGRAMMA ARCHITETTURA COMPLETA

```
+-----------------------------------------------------------------------+
|                         SUGAMARA EA v10.0                             |
|                    (con Virtual Stop Order Manager)                   |
+-----------------------------------------------------------------------+
|                                                                       |
|  +---------------------------+     +---------------------------+      |
|  |    ORDINI FISSI           |     |    ORDINI VIRTUALI        |      |
|  |    (sempre sul broker)    |     |    (gestiti da software)  |      |
|  +---------------------------+     +---------------------------+      |
|  |                           |     |                           |      |
|  | Grid A Upper: BUY STOP    |     | Grid A Lower: Virtual BUY |      |
|  | Grid B Lower: SELL STOP   |     | Grid B Upper: Virtual SELL|      |
|  |                           |     |                           |      |
|  +-------------+-------------+     +-------------+-------------+      |
|                |                                 |                    |
|                |     +---------------------------+                    |
|                |     |                                                |
|                v     v                                                |
|  +---------------------------------------------------------------+   |
|  |                   VIRTUAL ORDER MANAGER                        |   |
|  +---------------------------------------------------------------+   |
|  |                                                                |   |
|  |  +-------------------+  +-------------------+  +-------------+ |   |
|  |  | State Machine     |  | Trigger Engine    |  | STOP Placer | |   |
|  |  |                   |  |                   |  |             | |   |
|  |  | - INACTIVE        |  | - Price Monitor   |  | - Validate  | |   |
|  |  | - TRIGGERED       |  | - Trigger Check   |  | - Place     | |   |
|  |  | - CONFIRMED       |  | - Pullback Check  |  | - Retry     | |   |
|  |  | - PLACED          |  | - Timeout Check   |  |             | |   |
|  |  | - FILLED          |  |                   |  |             | |   |
|  |  | - CLOSED          |  |                   |  |             | |   |
|  |  +-------------------+  +-------------------+  +-------------+ |   |
|  |                                                                |   |
|  +---------------------------------------------------------------+   |
|                                  |                                    |
|                                  v                                    |
|  +---------------------------------------------------------------+   |
|  |                      BROKER (MT5)                              |   |
|  +---------------------------------------------------------------+   |
|  | Pending Orders: BUY STOP, SELL STOP (solo quando confermati)   |   |
|  | Positions: Gestite normalmente con TP                          |   |
|  +---------------------------------------------------------------+   |
|                                                                       |
+-----------------------------------------------------------------------+
```

---

# APPENDICE B: CHECKLIST IMPLEMENTAZIONE

```
[ ] FASE 1: Strutture Dati
    [ ] Creare enum ENUM_VIRTUAL_STATE
    [ ] Creare struct VirtualOrder
    [ ] Creare array g_virtualSells[] e g_virtualBuys[]

[ ] FASE 2: Input Parameters
    [ ] Aggiungere EnableVirtualStopMode
    [ ] Aggiungere TriggerPercent
    [ ] Aggiungere PullbackConfirm_Pips
    [ ] Aggiungere StopPlacementOffset_Pips
    [ ] Aggiungere TriggerTimeout_Seconds

[ ] FASE 3: Inizializzazione
    [ ] InitializeVirtualOrders()
    [ ] Calcolo trigger prices
    [ ] Calcolo pullback confirm prices

[ ] FASE 4: Processing Loop
    [ ] ProcessVirtualOrders() in OnTick()
    [ ] ProcessVirtualSell() per ogni livello
    [ ] ProcessVirtualBuy() per ogni livello

[ ] FASE 5: State Machine
    [ ] Gestione INACTIVE -> TRIGGERED
    [ ] Gestione TRIGGERED -> CONFIRMED
    [ ] Gestione CONFIRMED -> PLACED
    [ ] Gestione PLACED -> FILLED
    [ ] Gestione FILLED -> CLOSED
    [ ] Gestione CLOSED -> INACTIVE (cyclic)

[ ] FASE 6: Order Placement
    [ ] PlaceVirtualSellStop()
    [ ] PlaceVirtualBuyStop()
    [ ] Validazione prezzi
    [ ] Error handling

[ ] FASE 7: Recovery
    [ ] SaveVirtualOrdersState()
    [ ] LoadVirtualOrdersState()
    [ ] SyncVirtualOrdersWithBroker()

[ ] FASE 8: Testing
    [ ] Test spike senza pullback
    [ ] Test spike con pullback
    [ ] Test timeout
    [ ] Test recovery
    [ ] Test multi-level trigger

[ ] FASE 9: Integrazione
    [ ] Modifica OnInit()
    [ ] Modifica OnTick()
    [ ] Modifica OnDeinit()
    [ ] Dashboard update
```

---

**FINE DOCUMENTO**

*Virtual Stop Order Manager v1.0*
*Sugamara Development Team - Gennaio 2026*
