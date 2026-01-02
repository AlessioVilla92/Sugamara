# 📋 ISTRUZIONI IMPLEMENTAZIONE: STRADDLE TRENDING INTELLIGENTE
## Funzionalità Complementare per SUGAMARA RIBELLE v5.8

**Data:** 1 Gennaio 2026  
**Versione Documento:** 1.0  
**Autore:** Claude AI per Alessio  
**Stato:** PRONTO PER IMPLEMENTAZIONE

---

# PARTE 1: ANALISI DELLA LOGICA

## 1.1 Conferma: È Come un'Opzione?

```
╔═══════════════════════════════════════════════════════════════════════════╗
║  CONFERMA FINALE: STRADDLE = OPZIONE-LIKE                                ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  ✅ RISCHIO DEFINITO:                                                    ║
║     Max loss calcolabile in anticipo                                     ║
║     Con 3 whipsaw e 2×: max -$21 (per 0.01 lot, 30 pips spacing)         ║
║     Il Cover limita la perdita massima                                   ║
║                                                                           ║
║  ✅ PROFIT POTENZIALMENTE ILLIMITATO:                                    ║
║     Dopo breakeven, ogni pip = profit                                    ║
║     Con 3 whipsaw: $0.35/pip di profit                                   ║
║     Se trend continua, profit continua                                   ║
║                                                                           ║
║  ✅ BREAKEVEN DEFINITO:                                                  ║
║     Sempre = Distanza BUY-SELL (Spacing × 2)                             ║
║     Con 30 pips distanza: BE a 30 pips dal fill                          ║
║                                                                           ║
║  ⚠️ DIFFERENZA CON OPZIONE VERA:                                         ║
║     Non scegli TU la direzione                                           ║
║     La direzione è determinata dall'ultimo whipsaw                       ║
║     Ma su strumenti trending (USD/JPY), questo è gestibile               ║
║                                                                           ║
║  VERDETTO: SÌ, È ASSIMILABILE A UN'OPZIONE CON:                          ║
║  • Premio = Loss flottante dopo whipsaw                                  ║
║  • Strike = Livelli entry Straddle                                       ║
║  • Payoff = Asimmetrico (loss limitata, profit illimitato)               ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

## 1.2 Architettura del Sistema

```
╔═══════════════════════════════════════════════════════════════════════════╗
║  ARCHITETTURA STRADDLE TRENDING INTELLIGENTE                             ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  ┌─────────────────────────────────────────────────────────────────┐     ║
║  │                    SUGAMARA RIBELLE v5.8                        │     ║
║  │                                                                 │     ║
║  │  ┌─────────────────┐    ┌─────────────────────────────────┐    │     ║
║  │  │                 │    │                                 │    │     ║
║  │  │   CASCADE       │    │   STRADDLE TRENDING             │    │     ║
║  │  │   SOVRAPPOSTO   │    │   INTELLIGENTE                  │    │     ║
║  │  │                 │    │                                 │    │     ║
║  │  │  MagicNumber:   │    │  MagicNumber:                   │    │     ║
║  │  │  20251205       │    │  20260101                       │    │     ║
║  │  │                 │    │                                 │    │     ║
║  │  │  (Sistema Core) │    │  (Funzionalità Opzionale)       │    │     ║
║  │  │                 │    │                                 │    │     ║
║  │  └─────────────────┘    └─────────────────────────────────┘    │     ║
║  │           │                          │                          │     ║
║  │           │    COMPLETAMENTE         │                          │     ║
║  │           │      ISOLATI             │                          │     ║
║  │           │   (Magic Number          │                          │     ║
║  │           │    diversi)              │                          │     ║
║  │           ▼                          ▼                          │     ║
║  │  ┌─────────────────────────────────────────────────────────┐   │     ║
║  │  │              BROKER (IC Markets, Pepperstone)           │   │     ║
║  │  └─────────────────────────────────────────────────────────┘   │     ║
║  └─────────────────────────────────────────────────────────────────┘     ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

## 1.3 Flusso Operativo

```
╔═══════════════════════════════════════════════════════════════════════════╗
║  FLUSSO OPERATIVO STRADDLE                                               ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  1. VERIFICA ABILITAZIONE                                                ║
║     │                                                                    ║
║     ▼                                                                    ║
║  ┌──────────────────┐                                                    ║
║  │ Straddle_Enabled │──NO──► EXIT                                        ║
║  │      = true?     │                                                    ║
║  └────────┬─────────┘                                                    ║
║           │ YES                                                          ║
║           ▼                                                              ║
║  2. CALCOLO LIVELLI                                                      ║
║     │  BUY_STOP = Center + Spacing                                       ║
║     │  SELL_STOP = Center - Spacing                                      ║
║     ▼                                                                    ║
║  3. APERTURA STRADDLE                                                    ║
║     │  Piazza BUY STOP e SELL STOP con BaseLot                          ║
║     ▼                                                                    ║
║  4. PRIMO FILL                                                           ║
║     │  Round = 1                                                         ║
║     │  Aumenta lot ordine opposto × LotMultiplier                       ║
║     ▼                                                                    ║
║  5. LOOP MONITORAGGIO                                                    ║
║     │                                                                    ║
║     ├──► Check Take Profit (se abilitato)                               ║
║     │    Se prezzo raggiunge TP → Chiudi posizione singola              ║
║     │                                                                    ║
║     ├──► Check COP Straddle                                             ║
║     │    Se NetProfit ≥ COP_Target → Chiudi TUTTO                       ║
║     │                                                                    ║
║     ├──► Check Breakeven Exit                                           ║
║     │    Se BE_Enabled E NetProfit ≥ 0 (dopo whipsaw) → Chiudi TUTTO    ║
║     │                                                                    ║
║     ├──► Check Whipsaw                                                  ║
║     │    Se ordine opposto fillato:                                     ║
║     │    - Round++                                                       ║
║     │    - Se Round > MaxWhipsaw → COVER MODE                           ║
║     │    - Altrimenti: piazza nuovo ordine × LotMultiplier              ║
║     │                                                                    ║
║     ├──► Check EOD Close                                                ║
║     │    Se ora ≥ EOD_Hour → Chiudi TUTTO                               ║
║     │                                                                    ║
║     └──► LOOP                                                           ║
║                                                                           ║
║  6. DOPO CHIUSURA                                                        ║
║     │                                                                    ║
║     ├──► Se ReopenAfterClose = true → Torna a step 2                    ║
║     └──► Altrimenti → EXIT                                              ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

## 1.4 Logica Take Profit

```
╔═══════════════════════════════════════════════════════════════════════════╗
║  LOGICA TAKE PROFIT - ANALISI                                            ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  DOMANDA: Dove mettere il TP?                                            ║
║                                                                           ║
║  OPZIONE 1: TP @ Entry Grid +4/-4 (o +5/-5)                              ║
║  ───────────────────────────────────────────                             ║
║  • TP BUY = Entry BUY + (Spacing × 3) = Grid +4                          ║
║  • TP SELL = Entry SELL - (Spacing × 3) = Grid -4                        ║
║  • Distanza TP = 3× Spacing                                              ║
║                                                                           ║
║  Con Spacing 12 pips:                                                    ║
║  • Entry BUY @ Grid +1 (+12 pips)                                        ║
║  • TP BUY @ Grid +4 (+48 pips) = +36 pips dal fill                       ║
║                                                                           ║
║  PRO: Target chiaro, profit definito                                     ║
║  CONTRO: Dopo whipsaw, TP singolo non garantisce profit globale          ║
║                                                                           ║
║  ─────────────────────────────────────────────────────────────────────── ║
║                                                                           ║
║  OPZIONE 2: NESSUN TP, SOLO COP                                          ║
║  ───────────────────────────────                                         ║
║  • Ordini SENZA Take Profit                                              ║
║  • Solo COP Straddle monitora il NET profit                              ║
║  • Chiude quando NET ≥ Target                                            ║
║                                                                           ║
║  PRO: Funziona perfettamente dopo whipsaw                                ║
║  CONTRO: Potrebbe perdere profit se non c'è COP attivo                   ║
║                                                                           ║
║  ─────────────────────────────────────────────────────────────────────── ║
║                                                                           ║
║  OPZIONE 3: TP OPZIONALE + COP (RACCOMANDATA)                            ║
║  ─────────────────────────────────────────────                           ║
║  • TP configurabile dall'utente (Grid +4, +5, etc.)                      ║
║  • TP può essere disabilitato                                            ║
║  • COP sempre attivo come safety net                                     ║
║  • Chi arriva prima (TP singolo o COP) chiude                            ║
║                                                                           ║
║  LOGICA:                                                                 ║
║  IF Straddle_UseTP = true:                                               ║
║     Piazza ordini CON TP @ Grid +/- TP_GridLevel                         ║
║  ELSE:                                                                   ║
║     Piazza ordini SENZA TP                                               ║
║                                                                           ║
║  SEMPRE: COP monitora NET profit e chiude se ≥ target                    ║
║                                                                           ║
║  ✅ DECISIONE FINALE: OPZIONE 3 (TP OPZIONALE + COP)                     ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

## 1.5 Logica Breakeven Exit

```
╔═══════════════════════════════════════════════════════════════════════════╗
║  LOGICA BREAKEVEN EXIT                                                   ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  SCOPO: Uscire a pari dopo whipsaw, senza perdita                        ║
║                                                                           ║
║  LOGICA:                                                                 ║
║  IF Straddle_BE_Enabled = true                                           ║
║  AND currentRound >= 2 (almeno 1 whipsaw avvenuto)                       ║
║  AND NetProfit >= -Straddle_BE_Buffer (es: -$0.50)                       ║
║  THEN:                                                                   ║
║     Chiudi TUTTE le posizioni Straddle                                   ║
║     Log: "Breakeven Exit eseguito"                                       ║
║     Se ReopenAfterClose → Riapri nuovo Straddle                          ║
║                                                                           ║
║  PARAMETRI:                                                              ║
║  • Straddle_BE_Enabled: true/false                                       ║
║  • Straddle_BE_Buffer: tolleranza in $ (default: 0.50)                   ║
║    (chiude se NET ≥ -$0.50, cioè praticamente pari)                      ║
║                                                                           ║
║  INTERAZIONE CON COP:                                                    ║
║  • SE COP_Target = $5 e BE_Buffer = $0.50                                ║
║  • Breakeven Exit si attiva PRIMA di COP                                 ║
║  • Utile per uscire puliti quando non si raggiunge il target             ║
║                                                                           ║
║  NOTA: Se BE_Enabled = true, il COP Target viene "overridden" a          ║
║        breakeven. Quindi COP e BE sono mutualmente esclusivi:            ║
║        - Se vuoi uscire a pari: abilita BE, disabilita COP               ║
║        - Se vuoi profit: abilita COP, disabilita BE                      ║
║        - Oppure: COP sempre attivo, BE come "safety exit"                ║
║                                                                           ║
║  ✅ IMPLEMENTAZIONE: BE come opzione separata che "anticipa" COP         ║
║     Se BE attivo E NetProfit ≥ 0 → Chiudi (prima di aspettare COP)       ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

## 1.6 Calcolo NetProfit Straddle

```
╔═══════════════════════════════════════════════════════════════════════════╗
║  CALCOLO NET PROFIT STRADDLE                                             ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  FUNZIONE: CalcStraddleNetProfit()                                       ║
║                                                                           ║
║  LOGICA:                                                                 ║
║  1. Itera su TUTTE le posizioni aperte                                   ║
║  2. Filtra per Symbol() E Magic == Straddle_MagicNumber                  ║
║  3. Somma PositionGetDouble(POSITION_PROFIT)                             ║
║  4. Aggiungi swap se presente                                            ║
║  5. Return netProfit                                                     ║
║                                                                           ║
║  PSEUDOCODICE:                                                           ║
║  ```                                                                     ║
║  double CalcStraddleNetProfit() {                                        ║
║      double netProfit = 0;                                               ║
║      for(int i = 0; i < PositionsTotal(); i++) {                         ║
║          if(PositionSelectByTicket(PositionGetTicket(i))) {              ║
║              if(PositionGetString(POSITION_SYMBOL) == Symbol() &&        ║
║                 PositionGetInteger(POSITION_MAGIC) == Straddle_Magic) {  ║
║                  netProfit += PositionGetDouble(POSITION_PROFIT);        ║
║                  netProfit += PositionGetDouble(POSITION_SWAP);          ║
║              }                                                           ║
║          }                                                               ║
║      }                                                                   ║
║      return netProfit;                                                   ║
║  }                                                                       ║
║  ```                                                                     ║
║                                                                           ║
║  NOTA: Usa Straddle_MagicNumber, NON il MagicNumber CASCADE!             ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

---

# PARTE 2: SPECIFICHE TECNICHE

## 2.1 Parametri Input (Sottomenu Straddle)

```cpp
//+------------------------------------------------------------------+
//| STRADDLE TRENDING INTELLIGENTE - INPUT PARAMETERS                 |
//| Sottomenu separato nelle impostazioni EA                          |
//+------------------------------------------------------------------+

//--- ABILITAZIONE
input group "═══════════ STRADDLE TRENDING INTELLIGENTE ═══════════"

input bool      Straddle_Enabled = false;                  // ▶ Abilita Straddle Trending
input int       Straddle_MagicNumber = 20260101;           // 🆔 Magic Number Straddle

//--- LOT SIZING
input group "────────── Lot Sizing ──────────"

input double    Straddle_BaseLot = 0.01;                   // 💰 Lot Iniziale
input ENUM_STRADDLE_MULTIPLIER Straddle_LotMultiplier = MULT_2X; // 📈 Moltiplicatore Whipsaw

//--- LIMITI WHIPSAW
input group "────────── Limiti Whipsaw ──────────"

input int       Straddle_MaxWhipsaw = 3;                   // 🔄 Max Whipsaw (poi Cover)
input double    Straddle_MaxLot = 0.50;                    // ⚠️ Lot Massimo Raggiungibile

//--- TAKE PROFIT
input group "────────── Take Profit ──────────"

input bool      Straddle_UseTP = true;                     // 🎯 Usa Take Profit
input int       Straddle_TP_GridLevel = 4;                 // 📍 TP @ Entry Grid +/- N

//--- CLOSE ON PROFIT STRADDLE
input group "────────── Close On Profit Straddle ──────────"

input bool      Straddle_COP_Enabled = true;               // ✅ Abilita COP Straddle
input double    Straddle_COP_Target = 10.00;               // 💵 Target Profit ($)

//--- BREAKEVEN EXIT
input group "────────── Breakeven Exit ──────────"

input bool      Straddle_BE_Enabled = false;               // ⚖️ Abilita Chiusura a Pari
input double    Straddle_BE_Buffer = 0.50;                 // 📊 Buffer BE ($) - chiude se NET ≥ -buffer

//--- CHIUSURA EOD
input group "────────── Chiusura EOD ──────────"

input bool      Straddle_CloseEOD = true;                  // 🌙 Chiudi Fine Giornata
input int       Straddle_EOD_Hour = 21;                    // ⏰ Ora EOD (GMT)
input bool      Straddle_CloseFriday = true;               // 📅 Chiudi Venerdì Anticipato
input int       Straddle_Friday_Hour = 19;                 // ⏰ Ora Venerdì (GMT)

//--- RIAPERTURA
input group "────────── Riapertura ──────────"

input bool      Straddle_ReopenAfterClose = true;          // 🔁 Riapri Dopo Chiusura
input int       Straddle_ReopenDelay = 30;                 // ⏱️ Delay Riapertura (secondi)
```

## 2.2 Enum per Moltiplicatore

```cpp
//+------------------------------------------------------------------+
//| ENUM: Moltiplicatore Lot Straddle                                 |
//+------------------------------------------------------------------+
enum ENUM_STRADDLE_MULTIPLIER {
    MULT_1_5X = 0,    // 1.5× (Conservativo)
    MULT_2X = 1       // 2× (Standard - Breakeven più veloce)
};
```

## 2.3 Struttura Stato Straddle

```cpp
//+------------------------------------------------------------------+
//| STRUTTURA: Stato Straddle                                         |
//+------------------------------------------------------------------+
struct StraddleState {
    bool        isActive;              // Straddle attivo?
    int         currentRound;          // Round corrente (1 = primo fill)
    bool        inCoverMode;           // In modalità copertura?
    double      entryPrice;            // Prezzo entry (centro)
    double      buyStopPrice;          // Prezzo BUY STOP
    double      sellStopPrice;         // Prezzo SELL STOP
    ulong       buyStopTicket;         // Ticket BUY STOP pending
    ulong       sellStopTicket;        // Ticket SELL STOP pending
    double      currentBuyLot;         // Lot corrente per BUY
    double      currentSellLot;        // Lot corrente per SELL
    double      totalBuyLot;           // Lot totale posizioni BUY
    double      totalSellLot;          // Lot totale posizioni SELL
    int         totalBuyPositions;     // Numero posizioni BUY
    int         totalSellPositions;    // Numero posizioni SELL
    datetime    lastCloseTime;         // Ultimo orario chiusura (per delay)
    ENUM_POSITION_TYPE lastFillType;   // Tipo ultimo fill (BUY o SELL)
};

StraddleState straddle;
```

---

# PARTE 3: CODICE MQL5 COMPLETO

## 3.1 File: StraddleTrendingManager.mqh

```cpp
//+------------------------------------------------------------------+
//|                                    StraddleTrendingManager.mqh    |
//|                        SUGAMARA RIBELLE v5.8                      |
//|                     Straddle Trending Intelligente                |
//+------------------------------------------------------------------+
#property copyright "SUGAMARA RIBELLE"
#property version   "1.00"

//+------------------------------------------------------------------+
//| INCLUDES                                                          |
//+------------------------------------------------------------------+
#include <Trade/Trade.mqh>

//+------------------------------------------------------------------+
//| VARIABILI GLOBALI STRADDLE                                        |
//+------------------------------------------------------------------+
StraddleState straddle;
CTrade straddleTrade;

//+------------------------------------------------------------------+
//| INIZIALIZZAZIONE STRADDLE                                         |
//+------------------------------------------------------------------+
void StraddleInit() {
    if(!Straddle_Enabled) return;
    
    // Reset stato
    ZeroMemory(straddle);
    straddle.isActive = false;
    straddle.currentRound = 0;
    straddle.inCoverMode = false;
    straddle.lastCloseTime = 0;
    
    // Configura trade object
    straddleTrade.SetExpertMagicNumber(Straddle_MagicNumber);
    straddleTrade.SetDeviationInPoints(10);
    straddleTrade.SetTypeFilling(ORDER_FILLING_IOC);
    
    // Log
    PrintFormat("[STRADDLE] Inizializzato - Magic: %d, BaseLot: %.2f, Multiplier: %s, MaxWhipsaw: %d",
                Straddle_MagicNumber, 
                Straddle_BaseLot,
                Straddle_LotMultiplier == MULT_2X ? "2×" : "1.5×",
                Straddle_MaxWhipsaw);
}

//+------------------------------------------------------------------+
//| ON TICK STRADDLE (chiamato da OnTick principale)                  |
//+------------------------------------------------------------------+
void StraddleOnTick() {
    if(!Straddle_Enabled) return;
    
    // 1. Check EOD Close
    if(CheckStraddleEOD()) return;
    
    // 2. Aggiorna stato posizioni
    UpdateStraddleState();
    
    // 3. Check se aprire nuovo Straddle
    if(!straddle.isActive && CanOpenNewStraddle()) {
        OpenNewStraddle();
        return;
    }
    
    // 4. Check ordini fillati (whipsaw detection)
    CheckStraddleOrderFills();
    
    // 5. Check Breakeven Exit (priorità su COP)
    if(Straddle_BE_Enabled && straddle.currentRound >= 2) {
        if(CheckStraddleBreakevenExit()) return;
    }
    
    // 6. Check COP Straddle
    if(Straddle_COP_Enabled) {
        if(CheckStraddleCOP()) return;
    }
}

//+------------------------------------------------------------------+
//| AGGIORNA STATO STRADDLE                                           |
//+------------------------------------------------------------------+
void UpdateStraddleState() {
    straddle.totalBuyLot = 0;
    straddle.totalSellLot = 0;
    straddle.totalBuyPositions = 0;
    straddle.totalSellPositions = 0;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
            if(PositionGetInteger(POSITION_MAGIC) != Straddle_MagicNumber) continue;
            
            double lot = PositionGetDouble(POSITION_VOLUME);
            ENUM_POSITION_TYPE type = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            
            if(type == POSITION_TYPE_BUY) {
                straddle.totalBuyLot += lot;
                straddle.totalBuyPositions++;
            } else {
                straddle.totalSellLot += lot;
                straddle.totalSellPositions++;
            }
        }
    }
    
    // Straddle attivo se ci sono posizioni O ordini pending
    straddle.isActive = (straddle.totalBuyPositions > 0 || 
                         straddle.totalSellPositions > 0 ||
                         HasStraddlePendingOrders());
}

//+------------------------------------------------------------------+
//| CHECK SE CI SONO ORDINI PENDING STRADDLE                          |
//+------------------------------------------------------------------+
bool HasStraddlePendingOrders() {
    for(int i = 0; i < OrdersTotal(); i++) {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        
        if(OrderSelect(ticket)) {
            if(OrderGetString(ORDER_SYMBOL) != Symbol()) continue;
            if(OrderGetInteger(ORDER_MAGIC) != Straddle_MagicNumber) continue;
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| PUÒ APRIRE NUOVO STRADDLE?                                        |
//+------------------------------------------------------------------+
bool CanOpenNewStraddle() {
    // Check delay dopo chiusura
    if(straddle.lastCloseTime > 0) {
        if(TimeCurrent() - straddle.lastCloseTime < Straddle_ReopenDelay) {
            return false;
        }
    }
    
    // Check se riapertura abilitata (dopo prima chiusura)
    if(straddle.lastCloseTime > 0 && !Straddle_ReopenAfterClose) {
        return false;
    }
    
    return true;
}

//+------------------------------------------------------------------+
//| APRI NUOVO STRADDLE                                               |
//+------------------------------------------------------------------+
void OpenNewStraddle() {
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double spread = ask - bid;
    double point = SymbolInfoDouble(Symbol(), SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS);
    
    // Calcola centro (media bid/ask)
    double center = NormalizeDouble((ask + bid) / 2, digits);
    
    // Calcola distanza (usa Spacing SUGAMARA se disponibile, altrimenti ATR)
    double distance = GetStraddleDistance();
    
    // Calcola livelli
    double buyStopPrice = NormalizeDouble(center + distance, digits);
    double sellStopPrice = NormalizeDouble(center - distance, digits);
    
    // Calcola TP se abilitato
    double buyTP = 0, sellTP = 0;
    if(Straddle_UseTP) {
        double tpDistance = distance * Straddle_TP_GridLevel;
        buyTP = NormalizeDouble(buyStopPrice + tpDistance - distance, digits);  // TP @ Grid +N
        sellTP = NormalizeDouble(sellStopPrice - tpDistance + distance, digits); // TP @ Grid -N
    }
    
    // Piazza BUY STOP
    if(straddleTrade.BuyStop(Straddle_BaseLot, buyStopPrice, Symbol(), 0, buyTP, 
                             ORDER_TIME_GTC, 0, "Straddle BUY")) {
        straddle.buyStopTicket = straddleTrade.ResultOrder();
        PrintFormat("[STRADDLE] BUY STOP piazzato @ %.5f, Lot: %.2f, TP: %.5f", 
                    buyStopPrice, Straddle_BaseLot, buyTP);
    }
    
    // Piazza SELL STOP
    if(straddleTrade.SellStop(Straddle_BaseLot, sellStopPrice, Symbol(), 0, sellTP,
                              ORDER_TIME_GTC, 0, "Straddle SELL")) {
        straddle.sellStopTicket = straddleTrade.ResultOrder();
        PrintFormat("[STRADDLE] SELL STOP piazzato @ %.5f, Lot: %.2f, TP: %.5f", 
                    sellStopPrice, Straddle_BaseLot, sellTP);
    }
    
    // Aggiorna stato
    straddle.isActive = true;
    straddle.currentRound = 0;
    straddle.inCoverMode = false;
    straddle.entryPrice = center;
    straddle.buyStopPrice = buyStopPrice;
    straddle.sellStopPrice = sellStopPrice;
    straddle.currentBuyLot = Straddle_BaseLot;
    straddle.currentSellLot = Straddle_BaseLot;
    
    PrintFormat("[STRADDLE] Nuovo Straddle aperto - Centro: %.5f, Distanza: %.1f pips", 
                center, distance / point);
}

//+------------------------------------------------------------------+
//| OTTIENI DISTANZA STRADDLE                                         |
//+------------------------------------------------------------------+
double GetStraddleDistance() {
    // Usa Spacing SUGAMARA (variabile globale)
    // Se non disponibile, usa valore di default
    
    extern double Spacing;  // Da SUGAMARA
    
    if(Spacing > 0) {
        return Spacing * SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10; // Spacing in pips → price
    }
    
    // Fallback: 20 pips
    return 20 * SymbolInfoDouble(Symbol(), SYMBOL_POINT) * 10;
}

//+------------------------------------------------------------------+
//| CHECK ORDINI FILLATI (WHIPSAW DETECTION)                          |
//+------------------------------------------------------------------+
void CheckStraddleOrderFills() {
    // Controlla se BUY STOP è stato fillato
    if(straddle.buyStopTicket > 0 && !OrderSelect(straddle.buyStopTicket)) {
        // L'ordine non esiste più come pending → probabilmente fillato
        if(IsStraddlePositionOpen(POSITION_TYPE_BUY, straddle.buyStopTicket)) {
            OnStraddleBuyFilled();
        }
        straddle.buyStopTicket = 0;
    }
    
    // Controlla se SELL STOP è stato fillato
    if(straddle.sellStopTicket > 0 && !OrderSelect(straddle.sellStopTicket)) {
        if(IsStraddlePositionOpen(POSITION_TYPE_SELL, straddle.sellStopTicket)) {
            OnStraddleSellFilled();
        }
        straddle.sellStopTicket = 0;
    }
}

//+------------------------------------------------------------------+
//| CHECK SE POSIZIONE STRADDLE È APERTA                              |
//+------------------------------------------------------------------+
bool IsStraddlePositionOpen(ENUM_POSITION_TYPE type, ulong originalTicket) {
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
            if(PositionGetInteger(POSITION_MAGIC) != Straddle_MagicNumber) continue;
            if((ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE) != type) continue;
            return true;
        }
    }
    return false;
}

//+------------------------------------------------------------------+
//| ON BUY FILLED                                                     |
//+------------------------------------------------------------------+
void OnStraddleBuyFilled() {
    straddle.currentRound++;
    straddle.lastFillType = POSITION_TYPE_BUY;
    
    PrintFormat("[STRADDLE] BUY FILLATO - Round: %d", straddle.currentRound);
    
    // Se è il primo fill, aumenta il SELL STOP
    // Se è un whipsaw (round > 1), gestisci
    
    if(straddle.inCoverMode) {
        // In cover mode, questo è l'ordine di copertura
        PrintFormat("[STRADDLE] COVER BUY fillato - Hedge perfetto raggiunto");
        return;
    }
    
    // Check se raggiunto max whipsaw
    if(straddle.currentRound > Straddle_MaxWhipsaw) {
        EnterCoverMode();
        return;
    }
    
    // Aumenta lot per prossimo SELL STOP
    double newLot = CalculateNextLot(straddle.currentSellLot);
    
    // Cancella vecchio SELL STOP se esiste
    if(straddle.sellStopTicket > 0) {
        straddleTrade.OrderDelete(straddle.sellStopTicket);
    }
    
    // Piazza nuovo SELL STOP con lot aumentato
    double sellTP = 0;
    if(Straddle_UseTP) {
        double distance = GetStraddleDistance();
        double tpDistance = distance * Straddle_TP_GridLevel;
        sellTP = NormalizeDouble(straddle.sellStopPrice - tpDistance + distance, 
                                 (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
    }
    
    if(straddleTrade.SellStop(newLot, straddle.sellStopPrice, Symbol(), 0, sellTP,
                              ORDER_TIME_GTC, 0, "Straddle SELL R" + IntegerToString(straddle.currentRound))) {
        straddle.sellStopTicket = straddleTrade.ResultOrder();
        straddle.currentSellLot = newLot;
        PrintFormat("[STRADDLE] Nuovo SELL STOP @ %.5f, Lot: %.2f", straddle.sellStopPrice, newLot);
    }
}

//+------------------------------------------------------------------+
//| ON SELL FILLED                                                    |
//+------------------------------------------------------------------+
void OnStraddleSellFilled() {
    straddle.currentRound++;
    straddle.lastFillType = POSITION_TYPE_SELL;
    
    PrintFormat("[STRADDLE] SELL FILLATO - Round: %d", straddle.currentRound);
    
    if(straddle.inCoverMode) {
        PrintFormat("[STRADDLE] COVER SELL fillato - Hedge perfetto raggiunto");
        return;
    }
    
    if(straddle.currentRound > Straddle_MaxWhipsaw) {
        EnterCoverMode();
        return;
    }
    
    // Aumenta lot per prossimo BUY STOP
    double newLot = CalculateNextLot(straddle.currentBuyLot);
    
    // Cancella vecchio BUY STOP se esiste
    if(straddle.buyStopTicket > 0) {
        straddleTrade.OrderDelete(straddle.buyStopTicket);
    }
    
    // Piazza nuovo BUY STOP con lot aumentato
    double buyTP = 0;
    if(Straddle_UseTP) {
        double distance = GetStraddleDistance();
        double tpDistance = distance * Straddle_TP_GridLevel;
        buyTP = NormalizeDouble(straddle.buyStopPrice + tpDistance - distance,
                                (int)SymbolInfoInteger(Symbol(), SYMBOL_DIGITS));
    }
    
    if(straddleTrade.BuyStop(newLot, straddle.buyStopPrice, Symbol(), 0, buyTP,
                             ORDER_TIME_GTC, 0, "Straddle BUY R" + IntegerToString(straddle.currentRound))) {
        straddle.buyStopTicket = straddleTrade.ResultOrder();
        straddle.currentBuyLot = newLot;
        PrintFormat("[STRADDLE] Nuovo BUY STOP @ %.5f, Lot: %.2f", straddle.buyStopPrice, newLot);
    }
}

//+------------------------------------------------------------------+
//| CALCOLA PROSSIMO LOT                                              |
//+------------------------------------------------------------------+
double CalculateNextLot(double currentLot) {
    double multiplier = (Straddle_LotMultiplier == MULT_2X) ? 2.0 : 1.5;
    double newLot = NormalizeDouble(currentLot * multiplier, 2);
    
    // Applica limite max lot
    if(newLot > Straddle_MaxLot) {
        newLot = Straddle_MaxLot;
        PrintFormat("[STRADDLE] ⚠️ Max Lot raggiunto: %.2f", Straddle_MaxLot);
    }
    
    return newLot;
}

//+------------------------------------------------------------------+
//| ENTRA IN COVER MODE                                               |
//+------------------------------------------------------------------+
void EnterCoverMode() {
    straddle.inCoverMode = true;
    
    PrintFormat("[STRADDLE] ⚠️ COVER MODE - Max Whipsaw raggiunto (%d)", Straddle_MaxWhipsaw);
    
    // Calcola esposizione netta
    UpdateStraddleState();
    double netExposure = straddle.totalBuyLot - straddle.totalSellLot;
    
    if(MathAbs(netExposure) < 0.001) {
        // Già bilanciato
        PrintFormat("[STRADDLE] Già in hedge perfetto");
        return;
    }
    
    // Piazza ordine di copertura
    if(netExposure > 0) {
        // Long netto → piazza SELL STOP per coprire
        double coverLot = NormalizeDouble(MathAbs(netExposure), 2);
        if(straddleTrade.SellStop(coverLot, straddle.sellStopPrice, Symbol(), 0, 0,
                                  ORDER_TIME_GTC, 0, "Straddle COVER")) {
            straddle.sellStopTicket = straddleTrade.ResultOrder();
            PrintFormat("[STRADDLE] COVER SELL STOP @ %.5f, Lot: %.2f", straddle.sellStopPrice, coverLot);
        }
    } else {
        // Short netto → piazza BUY STOP per coprire
        double coverLot = NormalizeDouble(MathAbs(netExposure), 2);
        if(straddleTrade.BuyStop(coverLot, straddle.buyStopPrice, Symbol(), 0, 0,
                                 ORDER_TIME_GTC, 0, "Straddle COVER")) {
            straddle.buyStopTicket = straddleTrade.ResultOrder();
            PrintFormat("[STRADDLE] COVER BUY STOP @ %.5f, Lot: %.2f", straddle.buyStopPrice, coverLot);
        }
    }
}

//+------------------------------------------------------------------+
//| CALCOLA NET PROFIT STRADDLE                                       |
//+------------------------------------------------------------------+
double CalcStraddleNetProfit() {
    double netProfit = 0;
    
    for(int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
            if(PositionGetInteger(POSITION_MAGIC) != Straddle_MagicNumber) continue;
            
            netProfit += PositionGetDouble(POSITION_PROFIT);
            netProfit += PositionGetDouble(POSITION_SWAP);
        }
    }
    
    return netProfit;
}

//+------------------------------------------------------------------+
//| CHECK COP STRADDLE                                                |
//+------------------------------------------------------------------+
bool CheckStraddleCOP() {
    if(!Straddle_COP_Enabled) return false;
    if(straddle.totalBuyPositions == 0 && straddle.totalSellPositions == 0) return false;
    
    double netProfit = CalcStraddleNetProfit();
    
    if(netProfit >= Straddle_COP_Target) {
        PrintFormat("[STRADDLE] 🎯 COP TARGET RAGGIUNTO! NetProfit: $%.2f >= Target: $%.2f",
                    netProfit, Straddle_COP_Target);
        CloseAllStraddlePositions("COP Target");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| CHECK BREAKEVEN EXIT                                              |
//+------------------------------------------------------------------+
bool CheckStraddleBreakevenExit() {
    if(!Straddle_BE_Enabled) return false;
    if(straddle.currentRound < 2) return false;  // Solo dopo almeno 1 whipsaw
    if(straddle.totalBuyPositions == 0 && straddle.totalSellPositions == 0) return false;
    
    double netProfit = CalcStraddleNetProfit();
    
    if(netProfit >= -Straddle_BE_Buffer) {
        PrintFormat("[STRADDLE] ⚖️ BREAKEVEN EXIT! NetProfit: $%.2f >= Buffer: -$%.2f",
                    netProfit, Straddle_BE_Buffer);
        CloseAllStraddlePositions("Breakeven Exit");
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| CHECK EOD CLOSE                                                   |
//+------------------------------------------------------------------+
bool CheckStraddleEOD() {
    if(!Straddle_CloseEOD) return false;
    
    MqlDateTime dt;
    TimeToStruct(TimeGMT(), dt);
    
    // Venerdì anticipato
    if(Straddle_CloseFriday && dt.day_of_week == 5) {
        if(dt.hour >= Straddle_Friday_Hour) {
            PrintFormat("[STRADDLE] 📅 Chiusura Venerdì anticipata - Ora: %d:00 GMT", dt.hour);
            CloseAllStraddlePositions("Friday Close");
            CancelAllStraddlePendingOrders();
            return true;
        }
    }
    
    // EOD normale
    if(dt.hour >= Straddle_EOD_Hour) {
        PrintFormat("[STRADDLE] 🌙 Chiusura EOD - Ora: %d:00 GMT", dt.hour);
        CloseAllStraddlePositions("EOD Close");
        CancelAllStraddlePendingOrders();
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| CHIUDI TUTTE LE POSIZIONI STRADDLE                                |
//+------------------------------------------------------------------+
void CloseAllStraddlePositions(string reason) {
    for(int i = PositionsTotal() - 1; i >= 0; i--) {
        ulong ticket = PositionGetTicket(i);
        if(ticket == 0) continue;
        
        if(PositionSelectByTicket(ticket)) {
            if(PositionGetString(POSITION_SYMBOL) != Symbol()) continue;
            if(PositionGetInteger(POSITION_MAGIC) != Straddle_MagicNumber) continue;
            
            straddleTrade.PositionClose(ticket);
            PrintFormat("[STRADDLE] Chiusa posizione #%d - Motivo: %s", ticket, reason);
        }
    }
    
    // Cancella ordini pending
    CancelAllStraddlePendingOrders();
    
    // Reset stato
    straddle.lastCloseTime = TimeCurrent();
    straddle.isActive = false;
    straddle.currentRound = 0;
    straddle.inCoverMode = false;
}

//+------------------------------------------------------------------+
//| CANCELLA TUTTI GLI ORDINI PENDING STRADDLE                        |
//+------------------------------------------------------------------+
void CancelAllStraddlePendingOrders() {
    for(int i = OrdersTotal() - 1; i >= 0; i--) {
        ulong ticket = OrderGetTicket(i);
        if(ticket == 0) continue;
        
        if(OrderSelect(ticket)) {
            if(OrderGetString(ORDER_SYMBOL) != Symbol()) continue;
            if(OrderGetInteger(ORDER_MAGIC) != Straddle_MagicNumber) continue;
            
            straddleTrade.OrderDelete(ticket);
            PrintFormat("[STRADDLE] Cancellato ordine pending #%d", ticket);
        }
    }
    
    straddle.buyStopTicket = 0;
    straddle.sellStopTicket = 0;
}

//+------------------------------------------------------------------+
//| GET STRADDLE INFO (per Dashboard)                                 |
//+------------------------------------------------------------------+
string GetStraddleInfo() {
    if(!Straddle_Enabled) return "DISABILITATO";
    if(!straddle.isActive) return "INATTIVO";
    
    string info = "";
    info += StringFormat("Round: %d/%d | ", straddle.currentRound, Straddle_MaxWhipsaw);
    info += StringFormat("LONG: %.2f | SHORT: %.2f | ", straddle.totalBuyLot, straddle.totalSellLot);
    info += StringFormat("NET: $%.2f", CalcStraddleNetProfit());
    
    if(straddle.inCoverMode) info += " [COVER]";
    
    return info;
}

//+------------------------------------------------------------------+
//| DEINIT STRADDLE                                                   |
//+------------------------------------------------------------------+
void StraddleDeinit() {
    // Opzionale: chiudi tutto alla deinizializzazione
    // CloseAllStraddlePositions("EA Deinit");
    PrintFormat("[STRADDLE] Deinizializzato");
}
```

---

# PARTE 4: INTEGRAZIONE IN SUGAMARA

## 4.1 Modifiche a Sugamara.mq5

```cpp
//+------------------------------------------------------------------+
//| Sugamara.mq5 - MODIFICHE PER STRADDLE                             |
//+------------------------------------------------------------------+

// Aggiungi include all'inizio del file (dopo gli altri include)
#include "StraddleTrendingManager.mqh"

//+------------------------------------------------------------------+
//| OnInit - Aggiungi inizializzazione Straddle                       |
//+------------------------------------------------------------------+
int OnInit() {
    // ... codice esistente ...
    
    // AGGIUNGI: Inizializza Straddle
    StraddleInit();
    
    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| OnTick - Aggiungi chiamata Straddle                               |
//+------------------------------------------------------------------+
void OnTick() {
    // ... codice esistente ...
    
    // AGGIUNGI: Esegui logica Straddle
    StraddleOnTick();
    
    // ... resto del codice ...
}

//+------------------------------------------------------------------+
//| OnDeinit - Aggiungi deinizializzazione Straddle                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason) {
    // ... codice esistente ...
    
    // AGGIUNGI: Deinizializza Straddle
    StraddleDeinit();
}
```

## 4.2 Modifiche a InputParameters.mqh

```cpp
//+------------------------------------------------------------------+
//| InputParameters.mqh - AGGIUNGI SEZIONE STRADDLE                   |
//+------------------------------------------------------------------+

// AGGIUNGI alla fine del file, PRIMA della chiusura

//+------------------------------------------------------------------+
//| STRADDLE TRENDING INTELLIGENTE                                    |
//+------------------------------------------------------------------+
input group "═══════════════════════════════════════════════════════════"
input group "═══════════ STRADDLE TRENDING INTELLIGENTE ═══════════"
input group "═══════════════════════════════════════════════════════════"

input bool      Straddle_Enabled = false;                  // ▶ Abilita Straddle Trending
input int       Straddle_MagicNumber = 20260101;           // 🆔 Magic Number Straddle

input group "────────── Lot Sizing ──────────"
input double    Straddle_BaseLot = 0.01;                   // 💰 Lot Iniziale
input ENUM_STRADDLE_MULTIPLIER Straddle_LotMultiplier = MULT_2X; // 📈 Moltiplicatore (1.5× o 2×)

input group "────────── Limiti Whipsaw ──────────"
input int       Straddle_MaxWhipsaw = 3;                   // 🔄 Max Whipsaw (poi Cover)
input double    Straddle_MaxLot = 0.50;                    // ⚠️ Lot Massimo Raggiungibile

input group "────────── Take Profit ──────────"
input bool      Straddle_UseTP = true;                     // 🎯 Usa Take Profit
input int       Straddle_TP_GridLevel = 4;                 // 📍 TP @ Entry Grid +/- N (3=vicino, 5=lontano)

input group "────────── Close On Profit Straddle ──────────"
input bool      Straddle_COP_Enabled = true;               // ✅ Abilita COP Straddle
input double    Straddle_COP_Target = 10.00;               // 💵 Target Profit ($)

input group "────────── Breakeven Exit ──────────"
input bool      Straddle_BE_Enabled = false;               // ⚖️ Abilita Chiusura a Pari
input double    Straddle_BE_Buffer = 0.50;                 // 📊 Buffer BE ($)

input group "────────── Chiusura EOD ──────────"
input bool      Straddle_CloseEOD = true;                  // 🌙 Chiudi Fine Giornata
input int       Straddle_EOD_Hour = 21;                    // ⏰ Ora EOD (GMT)
input bool      Straddle_CloseFriday = true;               // 📅 Chiudi Venerdì Anticipato
input int       Straddle_Friday_Hour = 19;                 // ⏰ Ora Venerdì (GMT)

input group "────────── Riapertura ──────────"
input bool      Straddle_ReopenAfterClose = true;          // 🔁 Riapri Dopo Chiusura
input int       Straddle_ReopenDelay = 30;                 // ⏱️ Delay Riapertura (sec)
```

## 4.3 Modifiche a Enums.mqh

```cpp
//+------------------------------------------------------------------+
//| Enums.mqh - AGGIUNGI ENUM STRADDLE                                |
//+------------------------------------------------------------------+

// AGGIUNGI alla fine del file

//+------------------------------------------------------------------+
//| ENUM: Moltiplicatore Lot Straddle                                 |
//+------------------------------------------------------------------+
enum ENUM_STRADDLE_MULTIPLIER {
    MULT_1_5X = 0,    // 1.5× (Conservativo)
    MULT_2X = 1       // 2× (Standard - BE più veloce)
};
```

## 4.4 Modifiche a Dashboard.mqh (Opzionale)

```cpp
//+------------------------------------------------------------------+
//| Dashboard.mqh - AGGIUNGI SEZIONE STRADDLE                         |
//+------------------------------------------------------------------+

// Nella funzione DrawDashboard(), aggiungi:

void DrawDashboardStraddleSection(int &y) {
    if(!Straddle_Enabled) return;
    
    // Header Straddle
    DrawLabel("lbl_straddle_header", "═══ STRADDLE ═══", 10, y, clrGold);
    y += 15;
    
    // Info Straddle
    string straddleInfo = GetStraddleInfo();
    DrawLabel("lbl_straddle_info", straddleInfo, 10, y, clrWhite);
    y += 15;
    
    // Net Profit
    double netProfit = CalcStraddleNetProfit();
    color profitColor = netProfit >= 0 ? clrLime : clrRed;
    DrawLabel("lbl_straddle_profit", StringFormat("P&L: $%.2f", netProfit), 10, y, profitColor);
    y += 20;
}
```

---

# PARTE 5: CHECKLIST IMPLEMENTAZIONE

## 5.1 File da Creare

```
□ /MQL5/Include/Sugamara/StraddleTrendingManager.mqh
```

## 5.2 File da Modificare

```
□ /MQL5/Experts/Sugamara.mq5
  - Aggiungi #include "StraddleTrendingManager.mqh"
  - Aggiungi StraddleInit() in OnInit()
  - Aggiungi StraddleOnTick() in OnTick()
  - Aggiungi StraddleDeinit() in OnDeinit()

□ /MQL5/Include/Sugamara/InputParameters.mqh
  - Aggiungi sezione parametri Straddle

□ /MQL5/Include/Sugamara/Enums.mqh
  - Aggiungi ENUM_STRADDLE_MULTIPLIER

□ /MQL5/Include/Sugamara/Dashboard.mqh (opzionale)
  - Aggiungi sezione visualizzazione Straddle
```

## 5.3 Test da Eseguire

```
□ Test 1: Apertura Straddle
  - Verifica BUY STOP e SELL STOP piazzati correttamente
  - Verifica distanza = Spacing SUGAMARA

□ Test 2: Primo Fill
  - Verifica Round = 1
  - Verifica ordine opposto aumentato di 2× (o 1.5×)

□ Test 3: Whipsaw (Round 2, 3)
  - Verifica lot aumentano correttamente
  - Verifica TP piazzati se abilitati

□ Test 4: Cover Mode
  - Verifica entrata in Cover dopo MaxWhipsaw
  - Verifica ordine di copertura corretto

□ Test 5: COP Straddle
  - Verifica chiusura quando NetProfit ≥ Target
  - Verifica log corretto

□ Test 6: Breakeven Exit
  - Verifica chiusura quando NetProfit ≥ -Buffer
  - Verifica solo dopo Round ≥ 2

□ Test 7: EOD Close
  - Verifica chiusura all'ora EOD
  - Verifica chiusura anticipata Venerdì

□ Test 8: Riapertura
  - Verifica riapertura dopo delay
  - Verifica che non riapre se disabilitato

□ Test 9: Isolamento da CASCADE
  - Verifica Magic Number separato
  - Verifica che ordini CASCADE non interferiscono
  - Verifica P&L separato
```

---

# PARTE 6: CONFIGURAZIONI RACCOMANDATE

## 6.1 Configurazione Conservativa (€500-1000)

```
Straddle_Enabled = true
Straddle_BaseLot = 0.01
Straddle_LotMultiplier = MULT_1_5X      // 1.5×
Straddle_MaxWhipsaw = 3
Straddle_MaxLot = 0.10
Straddle_UseTP = true
Straddle_TP_GridLevel = 4
Straddle_COP_Enabled = true
Straddle_COP_Target = 5.00
Straddle_BE_Enabled = true              // Uscita a pari come safety
Straddle_BE_Buffer = 0.50
Straddle_CloseEOD = true
```

## 6.2 Configurazione Standard (€1000-2000)

```
Straddle_Enabled = true
Straddle_BaseLot = 0.01
Straddle_LotMultiplier = MULT_2X        // 2×
Straddle_MaxWhipsaw = 3
Straddle_MaxLot = 0.20
Straddle_UseTP = true
Straddle_TP_GridLevel = 4
Straddle_COP_Enabled = true
Straddle_COP_Target = 10.00
Straddle_BE_Enabled = false
Straddle_CloseEOD = true
```

## 6.3 Configurazione Aggressiva (€2000+)

```
Straddle_Enabled = true
Straddle_BaseLot = 0.02
Straddle_LotMultiplier = MULT_2X        // 2×
Straddle_MaxWhipsaw = 4
Straddle_MaxLot = 0.50
Straddle_UseTP = false                  // Solo COP
Straddle_COP_Enabled = true
Straddle_COP_Target = 20.00
Straddle_BE_Enabled = false
Straddle_CloseEOD = true
```

---

# PARTE 7: RIEPILOGO FORMULE

```
╔═══════════════════════════════════════════════════════════════════════════╗
║  FORMULE STRADDLE TRENDING INTELLIGENTE                                  ║
╠═══════════════════════════════════════════════════════════════════════════╣
║                                                                           ║
║  DISTANZA:                                                                ║
║  Distance = Spacing_SUGAMARA (in pips)                                   ║
║  BUY_STOP = Center + Distance                                            ║
║  SELL_STOP = Center - Distance                                           ║
║                                                                           ║
║  LOT SIZING:                                                             ║
║  Lot[n] = Lot[n-1] × Multiplier                                          ║
║  Con 2×: 0.01 → 0.02 → 0.04 → 0.08                                       ║
║  Con 1.5×: 0.01 → 0.015 → 0.0225 → 0.034                                 ║
║                                                                           ║
║  TAKE PROFIT:                                                            ║
║  TP_BUY = BUY_Entry + (Distance × (TP_GridLevel - 1))                    ║
║  TP_SELL = SELL_Entry - (Distance × (TP_GridLevel - 1))                  ║
║  Con GridLevel = 4: TP = Entry ± (Distance × 3)                          ║
║                                                                           ║
║  BREAKEVEN (dopo whipsaw):                                               ║
║  Sempre = Distance dal prezzo corrente nella direzione favorevole        ║
║                                                                           ║
║  MAX LOSS (con Cover):                                                   ║
║  Max_Loss = BaseLot × (2^MaxWhipsaw - 1) × Distance × PipValue           ║
║  Con 0.01 lot, 3 WS, 30 pips, 2×: ~$21                                   ║
║                                                                           ║
║  PROFIT DOPO BE:                                                         ║
║  Profit_per_pip = Esposizione_Netta × PipValue                           ║
║  Con 3 WS e 2×: Esposizione = 0.05 lot → $0.35/pip                       ║
║                                                                           ║
╚═══════════════════════════════════════════════════════════════════════════╝
```

---

**Documento Completo v1.0 - 1 Gennaio 2026**  
**SUGAMARA RIBELLE v5.8 - Straddle Trending Intelligente**  
*"Rischio Definito, Profit Potenzialmente Illimitato"* 🎯

---

## CHANGELOG

| Versione | Data | Modifiche |
|----------|------|-----------|
| 1.0 | 01/01/2026 | Documento iniziale completo |
