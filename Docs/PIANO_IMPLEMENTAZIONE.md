# SUGAMARA - Double Grid Neutral
## Piano di Implementazione EA

**Versione Target:** 1.0.0
**Data Inizio:** Dicembre 2025
**Base:** Breva-Tivan v10.3.30 (Refactored)

---

## 1. SINTESI DEL SISTEMA

### 1.1 Concetto Fondamentale
**Sugamara** (Double Grid Neutral) opera con **DUE GRID SPECULARI SIMULTANEE**:

```
                    PREZZO CORRENTE (1.1000)
                           │
    ┌──────────────────────┼──────────────────────┐
    │      GRID A          │      GRID B          │
    │    (Long Bias)       │    (Short Bias)      │
    ├──────────────────────┼──────────────────────┤
    │                      │                      │
    │ UP-5: Buy Limit      │ UP-5: Sell Limit     │  1.1100
    │ UP-4: Buy Limit      │ UP-4: Sell Limit     │  1.1080
    │ UP-3: Buy Limit      │ UP-3: Sell Limit     │  1.1060
    │ UP-2: Buy Limit      │ UP-2: Sell Limit     │  1.1040
    │ UP-1: Buy Limit      │ UP-1: Sell Limit     │  1.1020
    │                      │                      │
    │      ENTRY           │      ENTRY           │  1.1000
    │                      │                      │
    │ DN-1: Sell Stop      │ DN-1: Buy Stop       │  1.0980
    │ DN-2: Sell Stop      │ DN-2: Buy Stop       │  1.0960
    │ DN-3: Sell Stop      │ DN-3: Buy Stop       │  1.0940
    │ DN-4: Sell Stop      │ DN-4: Buy Stop       │  1.0920
    │ DN-5: Sell Stop      │ DN-5: Buy Stop       │  1.0900
    └──────────────────────┴──────────────────────┘
```

### 1.2 Differenze Chiave vs Breva-Tivan

| Aspetto | Breva-Tivan | Sugamara |
|---------|-------------|----------|
| Dipendenza Direzionale | ALTA | ZERO (neutral) |
| Ordini Totali | 1 main + 10-12 grid | 20 ordini (10+10) |
| Mercati Ideali | Trending | Laterali/Range |
| Main Order | SI (ordine principale) | NO (solo grid) |
| Scout | SI | NO (non necessario) |
| Auto-Hedging | NO | SI (intrinseco) |
| ROI Target | 15-20% | 10-15% |
| Max Drawdown | 15-25% | 8-12% |
| Win Rate | 65-75% | 75-85% |

---

## 2. MODULI RIUTILIZZABILI DA BREVA-TIVAN

### 2.1 Moduli da COPIARE e ADATTARE

| Modulo | File Origine | Adattamenti Richiesti |
|--------|--------------|----------------------|
| **Enums** | Config/Enums.mqh | Aggiungere enum per Double Grid |
| **BrokerValidation** | Core/BrokerValidation.mqh | Minimo (universale) |
| **Helpers** | Utils/Helpers.mqh | Minimo (universale) |
| **GridHelpers** | Utils/GridHelpers.mqh | Adattare per dual grid |
| **Dashboard** | UI/Dashboard.mqh | Ricreare per Double Grid |
| **Indicators** | Indicators/Indicators.mqh | ATR Monitor riutilizzabile |

### 2.2 Moduli da RIMUOVERE (non necessari)

- Trading/MainOrder.mqh (no main order in Sugamara)
- Trading/ScoutSystem.mqh (no scout in Sugamara)
- Trading/HalvingSystem.mqh (no halving)
- Core/DebugMode.mqh (opzionale)

### 2.3 Moduli da CREARE EX-NOVO

| Modulo | Descrizione |
|--------|-------------|
| **GridASystem.mqh** | Gestione Grid A (Long Bias) |
| **GridBSystem.mqh** | Gestione Grid B (Short Bias) |
| **CascadeManager.mqh** | Logica Perfect Cascade (TP = Entry successivo) |
| **AdaptiveSpacing.mqh** | Spacing dinamico basato su ATR |
| **NeutralManager.mqh** | Bilanciamento e hedging automatico |

---

## 3. ARCHITETTURA SUGAMARA

### 3.1 Struttura Cartelle

```
/Sugamara/
├── Sugamara.mq5                 # File principale EA
├── Config/
│   ├── Enums.mqh                # Enumerazioni sistema
│   ├── InputParameters.mqh      # Parametri input utente
│   └── PairPresets.mqh          # Preset per EUR/USD, AUD/NZD
├── Core/
│   ├── GlobalVariables.mqh      # Variabili globali
│   ├── Initialization.mqh       # Inizializzazione sistema
│   └── BrokerValidation.mqh     # Validazione broker
├── Utils/
│   ├── Helpers.mqh              # Funzioni helper generiche
│   ├── GridHelpers.mqh          # Helper calcolo grid
│   └── ATRCalculator.mqh        # Calcolo ATR per spacing
├── Trading/
│   ├── GridASystem.mqh          # Grid A - Long Bias
│   ├── GridBSystem.mqh          # Grid B - Short Bias
│   ├── CascadeManager.mqh       # Perfect Cascade Logic
│   ├── AdaptiveSpacing.mqh      # ATR-based Spacing
│   └── SystemManager.mqh        # Coordinamento generale
├── UI/
│   └── Dashboard.mqh            # Dashboard unificata
├── Indicators/
│   ├── ATRMonitor.mqh           # Monitor ATR
│   └── VolatilityMonitor.mqh    # Monitor volatilità
└── Docs/
    └── PIANO_IMPLEMENTAZIONE.md # Questo documento
```

### 3.2 Flusso Dati

```
OnInit()
    │
    ├── ApplyPairPresets()           → Carica preset EUR/USD o AUD/NZD
    ├── LoadBrokerSpecifications()   → Valida broker
    ├── InitializeATRMonitor()       → Inizializza ATR
    ├── CalculateAdaptiveSpacing()   → Calcola spacing da ATR
    ├── CalculateGridLevels()        → Calcola livelli Grid A + Grid B
    └── CreateDashboard()            → Crea UI

OnTick()
    │
    ├── UpdateATRMonitor()           → Aggiorna ATR (ogni 4 ore)
    │   └── RecalculateSpacing()     → Ricalcola se ATR cambiato
    │
    ├── CheckGridAPending()          → Monitora pending Grid A
    ├── CheckGridBPending()          → Monitora pending Grid B
    │
    ├── CheckGridAFilled()           → Gestisce posizioni Grid A
    │   └── ApplyCascadeTP()         → TP = Entry livello successivo
    │
    ├── CheckGridBFilled()           → Gestisce posizioni Grid B
    │   └── ApplyCascadeTP()         → TP = Entry livello successivo
    │
    ├── CheckNetExposure()           → Verifica bilanciamento
    │
    ├── CheckCyclicReopening()       → Cyclic reopen per entrambe le grid
    │
    └── UpdateDashboard()            → Aggiorna UI
```

---

## 4. PARAMETRI INPUT

### 4.1 Parametri Generali

```cpp
input group "═══════════════════════════════════════════════════════════"
input group "║  SUGAMARA - Double Grid Neutral                         ║"
input group "═══════════════════════════════════════════════════════════"

input group "    📊 General Settings"
input int       MagicNumber = 20251201;              // Magic Number
input double    InitialCapital = 3000;               // Capitale Iniziale ($)
input int       MaxSimultaneousOrders = 20;          // Max Ordini Simultanei

input group "    📈 Pair Selection"
input ENUM_NEUTRAL_PAIR  SelectedPair = NEUTRAL_EURUSD;  // Coppia da Tradare
```

### 4.2 Parametri Grid

```cpp
input group "    🔲 Grid Configuration"
input int       GridLevelsPerSide = 5;               // Livelli per Lato (5-10)
input bool      UseAdaptiveSpacing = true;           // Spacing Adattivo ATR
input double    ManualSpacing_Pips = 20;             // Spacing Manuale (se ATR off)
input double    SpacingATR_Multiplier = 0.7;         // Moltiplicatore ATR

input group "    💰 Lot Sizing"
input ENUM_LOT_MODE  LotMode = LOT_PROGRESSIVE;      // Modalità Lot
input double    BaseLot = 0.02;                      // Lot Base
input double    LotMultiplier = 1.15;                // Moltiplicatore Progressivo
input double    MaxLotCap = 0.12;                    // Max Lot per Livello
```

### 4.3 Parametri CASCADE

```cpp
input group "    🔄 Perfect Cascade"
input bool      EnablePerfectCascade = true;         // Abilita Perfect Cascade
// TP di ogni ordine = Entry del livello successivo

input group "    🔁 Cyclic Reopening"
input bool      EnableCyclicReopen = true;           // Abilita Cyclic Reopen
input int       CyclicCooldown_Seconds = 120;        // Cooldown tra Cicli
input int       MaxCyclesPerLevel = 0;               // Max Cicli (0=infiniti)
```

### 4.4 Parametri Risk Management

```cpp
input group "    ⚠️ Risk Management"
input double    EmergencyStop_Percent = 12;          // Emergency Stop (% equity)
input double    DailyProfitTarget = 0;               // Profit Target Giornaliero ($, 0=off)
input bool      PauseOnHighATR = true;               // Pausa se ATR > 50 pips
input double    HighATR_Threshold = 50;              // Soglia ATR Alta (pips)
```

---

## 5. FASI DI IMPLEMENTAZIONE

### FASE 1: Setup Base (Settimana 1)
- [ ] Creare struttura cartelle
- [ ] Copiare e adattare Enums.mqh
- [ ] Copiare e adattare GlobalVariables.mqh
- [ ] Copiare BrokerValidation.mqh (minime modifiche)
- [ ] Creare InputParameters.mqh per Sugamara
- [ ] Creare PairPresets.mqh (EUR/USD, AUD/NZD)

### FASE 2: Core Grid System (Settimana 2-3)
- [ ] Implementare GridASystem.mqh (Long Bias)
  - [ ] Calcolo livelli Grid A
  - [ ] Piazzamento ordini (Buy Limit sopra, Sell Stop sotto)
  - [ ] Monitoring pending/filled
  - [ ] SL/TP management
- [ ] Implementare GridBSystem.mqh (Short Bias - mirror di Grid A)
  - [ ] Calcolo livelli Grid B
  - [ ] Piazzamento ordini (Sell Limit sopra, Buy Stop sotto)
  - [ ] Monitoring pending/filled
  - [ ] SL/TP management

### FASE 3: CASCADE e Adaptive (Settimana 4)
- [ ] Implementare CascadeManager.mqh
  - [ ] Logica TP = Entry successivo
  - [ ] Sincronizzazione Grid A e Grid B
- [ ] Implementare AdaptiveSpacing.mqh
  - [ ] Calcolo ATR(14, M5)
  - [ ] Tabella decisionale ATR → Spacing
  - [ ] Ricalcolo dinamico ogni 4 ore

### FASE 4: System Integration (Settimana 5)
- [ ] Implementare SystemManager.mqh
  - [ ] Coordinamento Grid A + Grid B
  - [ ] Net Exposure tracking
  - [ ] Risk management globale
- [ ] Implementare Cyclic Reopening
  - [ ] Trigger conditions
  - [ ] Cooldown management

### FASE 5: UI e Testing (Settimana 6)
- [ ] Creare Dashboard.mqh
  - [ ] Pannello Grid A status
  - [ ] Pannello Grid B status
  - [ ] Pannello Net Exposure
  - [ ] Pannello ATR/Volatility
  - [ ] Pannello Performance
- [ ] Testing in Strategy Tester
- [ ] Forward test demo

---

## 6. LOGICA GRID A (Long Bias)

### 6.1 Struttura Ordini

```
ZONA SUPERIORE (prezzo > entry):
- Buy Limit: Compra quando prezzo SCENDE a quel livello
- Accumula posizioni LONG se prezzo oscilla verso l'alto

ZONA INFERIORE (prezzo < entry):
- Sell Stop: Vendi quando prezzo SCENDE a quel livello
- Protegge se prezzo crolla
```

### 6.2 Esempio Numerico (EUR/USD @ 1.1000)

| Zona | Level | Tipo | Entry | TP (Cascade) | Lot |
|------|-------|------|-------|--------------|-----|
| UP | 5 | Buy Limit | 1.1100 | 1.1120 | 0.12 |
| UP | 4 | Buy Limit | 1.1080 | 1.1100 | 0.08 |
| UP | 3 | Buy Limit | 1.1060 | 1.1080 | 0.05 |
| UP | 2 | Buy Limit | 1.1040 | 1.1060 | 0.03 |
| UP | 1 | Buy Limit | 1.1020 | 1.1040 | 0.02 |
| --- | ENTRY | --- | 1.1000 | --- | --- |
| DN | 1 | Sell Stop | 1.0980 | 1.0960 | 0.02 |
| DN | 2 | Sell Stop | 1.0960 | 1.0940 | 0.03 |
| DN | 3 | Sell Stop | 1.0940 | 1.0920 | 0.05 |
| DN | 4 | Sell Stop | 1.0920 | 1.0900 | 0.08 |
| DN | 5 | Sell Stop | 1.0900 | 1.0880 | 0.12 |

---

## 7. LOGICA GRID B (Short Bias) - MIRROR

### 7.1 Struttura Ordini

```
ZONA SUPERIORE (prezzo > entry):
- Sell Limit: Vendi quando prezzo SALE a quel livello
- Accumula posizioni SHORT se prezzo oscilla verso l'alto

ZONA INFERIORE (prezzo < entry):
- Buy Stop: Compra quando prezzo SCENDE a quel livello
- Protegge se prezzo crolla
```

### 7.2 Esempio Numerico (EUR/USD @ 1.1000)

| Zona | Level | Tipo | Entry | TP (Cascade) | Lot |
|------|-------|------|-------|--------------|-----|
| UP | 5 | Sell Limit | 1.1100 | 1.1080 | 0.12 |
| UP | 4 | Sell Limit | 1.1080 | 1.1060 | 0.08 |
| UP | 3 | Sell Limit | 1.1060 | 1.1040 | 0.05 |
| UP | 2 | Sell Limit | 1.1040 | 1.1020 | 0.03 |
| UP | 1 | Sell Limit | 1.1020 | 1.1000 | 0.02 |
| --- | ENTRY | --- | 1.1000 | --- | --- |
| DN | 1 | Buy Stop | 1.0980 | 1.1000 | 0.02 |
| DN | 2 | Buy Stop | 1.0960 | 1.0980 | 0.03 |
| DN | 3 | Buy Stop | 1.0940 | 1.0960 | 0.05 |
| DN | 4 | Buy Stop | 1.0920 | 1.0940 | 0.08 |
| DN | 5 | Buy Stop | 1.0900 | 1.0920 | 0.12 |

---

## 8. AUTO-HEDGING NATURALE

### 8.1 Come Funziona

Quando il prezzo si muove, Grid A e Grid B si COMPENSANO:

```
Prezzo SALE (1.1000 → 1.1040):
├── Grid A: Buy Limit @ 1.1020 APRE (0.02 lot LONG)
├── Grid A: Buy Limit @ 1.1040 APRE (0.03 lot LONG)
├── Grid B: Sell Limit @ 1.1020 APRE (0.02 lot SHORT)
└── Grid B: Sell Limit @ 1.1040 APRE (0.03 lot SHORT)

Posizione NETTA = (0.02 + 0.03) LONG - (0.02 + 0.03) SHORT = 0 (NEUTRALE!)

Prezzo TORNA (1.1040 → 1.1020):
├── Grid A: LONG @ 1.1020 TP HIT → +$4
├── Grid A: LONG @ 1.1040 floating -20 pips
├── Grid B: SHORT @ 1.1040 TP HIT → +$6
└── Grid B: SHORT @ 1.1020 floating +20 pips (ritorno)

PROFITTO TOTALE: +$10 (da oscillazione, non da direzione!)
```

---

## 9. ADAPTIVE SPACING (ATR-Based)

### 9.1 Formula

```
SPACING = MAX(ATR(14, M5) × 0.7, MinBrokerDistance)
```

### 9.2 Tabella Decisionale

| Condizione ATR | Valore ATR | Spacing | Range Totale | Livelli |
|----------------|------------|---------|--------------|---------|
| Mercato CALMO | < 15 pips | 15 pips | ±75 pips | 5 |
| Volatilità NORMALE | 15-30 pips | 20 pips | ±100 pips | 5 |
| Mercato VOLATILE | 30-50 pips | 30 pips | ±150 pips | 5 |
| Volatilità ESTREMA | > 50 pips | 40 pips | ±200 pips | 5 |

### 9.3 Ricalcolo Dinamico

- Frequenza: ogni 4 ore
- Gli ordini pending vengono aggiornati
- Le posizioni aperte mantengono parametri originali

---

## 10. PERFORMANCE ATTESE

### 10.1 EUR/USD (Setup Standard)

| Metrica | Target |
|---------|--------|
| ROI Mensile | 10-15% |
| Win Rate | 75-85% |
| Max Drawdown | 8-12% |
| Trades/Giorno | 8-15 |
| Capitale Minimo | $3,000 |

### 10.2 AUD/NZD (Range Stretto)

| Metrica | Target |
|---------|--------|
| ROI Mensile | 8-12% |
| Win Rate | 80-90% |
| Max Drawdown | 6-10% |
| Trades/Giorno | 5-10 |
| Capitale Minimo | $2,500 |

---

## 11. RISK MANAGEMENT

### 11.1 Emergency Stop
- Trigger: Equity < (Balance - 12%)
- Azione: Chiusura immediata tutte le posizioni

### 11.2 High Volatility Pause
- Trigger: ATR > 50 pips
- Azione: No nuovi ordini, mantieni esistenti

### 11.3 News Filter (opzionale)
- Trigger: 30 min prima/dopo major news
- Azione: Pausa sistema

---

## 12. CHECKLIST PRE-LANCIO

### Pre-Development
- [ ] Capitale disponibile: $______
- [ ] Coppia selezionata: EUR/USD / AUD/NZD
- [ ] Broker verificato (hedging enabled): SI / NO
- [ ] VPS disponibile: SI / NO

### Development
- [ ] Tutti i moduli implementati
- [ ] Compile senza errori
- [ ] Compile senza warnings

### Testing
- [ ] Backtest 6 mesi EUR/USD: WIN RATE ≥ 75%
- [ ] Backtest 6 mesi AUD/NZD: WIN RATE ≥ 80%
- [ ] Forward test demo 2 settimane: POSITIVO
- [ ] Max DD in test: < 12%

### Go-Live
- [ ] Capitale iniziale: 50% del totale
- [ ] Monitor giornaliero prima settimana
- [ ] Scala a 100% dopo 1 mese positivo

---

**FINE PIANO IMPLEMENTAZIONE**

Versione: 1.0
Data: Dicembre 2025
Autore: Sugamara Development Team
