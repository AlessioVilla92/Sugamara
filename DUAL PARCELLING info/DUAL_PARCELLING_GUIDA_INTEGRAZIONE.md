# 🎯 DUAL PARCELLING - ANALISI E GUIDA IMPLEMENTAZIONE

## 📋 SPECIFICA FUNZIONALE

### Concetto Base
**DUAL PARCELLING** divide logicamente ogni posizione in 2 "parcels" con Take Profit e Break Even differenziati:

```
ORDINE 0.02 lot @ Entry Grid 1 (posizione ATTIVATA)
                │
    ┌───────────┴───────────┐
    ▼                       ▼
PARCEL A (0.01 lot)    PARCEL B (0.01 lot)
TP1 = Entry Grid 2     TP2 = Entry Grid 3
BE @ 50% progress      BE @ 100% progress
Chiusura PARZIALE      TP finale della posizione
```

### ⚠️ CHIARIMENTO IMPORTANTE

| Aspetto | Valore |
|---------|--------|
| **Numero ordini** | INVARIATO (28 ordini) |
| **Lotti totali** | INVARIATO (0.02 × 28 = 0.56 lot) |
| **Margine richiesto** | INVARIATO |

**Non vengono creati ordini aggiuntivi!** 
La funzionalità gestisce la **chiusura parziale** di posizioni esistenti.

---

## 📐 ESEMPIO PRATICO

### Configurazione
- Spacing: 10 pips
- BaseLot: 0.02
- ParcelA_TP_Levels: 1
- ParcelB_TP_Levels: 2

### Scenario BUY

```
Entry Grid 1: 1.08500 ← Ordine BUY STOP 0.02 lot
Entry Grid 2: 1.08600 (+10 pips) ← TP1 per Parcel A
Entry Grid 3: 1.08700 (+20 pips) ← TP2 per Parcel B

Timeline:
─────────────────────────────────────────────────────────────
Prezzo 1.08500 │ Ordine si attiva → Posizione BUY 0.02 lot
               │ Dual Parcelling: tracking inizia
               │ TP posizione impostato a 1.08700 (TP2)
─────────────────────────────────────────────────────────────
Prezzo 1.08550 │ Progress = 50% verso TP1
               │ → SL si sposta a 1.08500 (BE) ✓
─────────────────────────────────────────────────────────────
Prezzo 1.08600 │ Progress = 100% → TP1 raggiunto!
               │ → CHIUSURA PARZIALE: 0.01 lot (Parcel A)
               │ → Profit Parcel A bloccato
               │ → Rimangono 0.01 lot aperti (Parcel B)
               │ → SL Parcel B già a BE (100% progress)
─────────────────────────────────────────────────────────────
Prezzo 1.08700 │ Progress = 200% → TP2 raggiunto!
               │ → CHIUSURA FINALE: 0.01 lot (Parcel B)
               │ → Trade completato
               │ → Recycling può riaprire il livello
─────────────────────────────────────────────────────────────
```

### Profit Potenziale

| Scenario | Parcel A | Parcel B | Totale |
|----------|----------|----------|--------|
| TP1 + TP2 | +10 pips × 0.01 | +20 pips × 0.01 | **+30 pip-lot** |
| TP1 + BE | +10 pips × 0.01 | 0 pips × 0.01 | **+10 pip-lot** |
| Solo BE | 0 pips × 0.01 | 0 pips × 0.01 | **0 pip-lot** |

---

## 🔧 MODIFICHE RICHIESTE

### 1. Nuovi File

| File | Descrizione |
|------|-------------|
| `Trading/DualParcelManager.mqh` | Modulo principale (già creato) |
| Sezione in `InputParameters.mqh` | Parametri configurazione (già creato) |

### 2. Modifiche a File Esistenti

#### A) `Sugamara.mq5` - Aggiungere include

```mql5
// Dopo la riga 72 (Trading Modules)
#include "Trading/DualParcelManager.mqh"  // v5.2 NEW
```

#### B) `Sugamara.mq5` - OnInit() - Aggiungere inizializzazione

```mql5
// Dopo InitializeCloseOnProfit() (circa linea 227)

//--- STEP 13.8c: Initialize Dual Parcel Manager (v5.2) ---
if(!InitializeDualParcelManager()) {
    Print("WARNING: Failed to initialize Dual Parcel Manager");
}
```

#### C) `Sugamara.mq5` - OnTick() - Aggiungere processing

```mql5
// Dopo ProcessPartialTPs() (circa linea 584) - SOSTITUIRE con:

//--- v5.2: DUAL PARCELLING ---
if(Enable_DualParcelling) {
    ProcessDualParcels();
}

//--- v5.1: BREAK ON PROFIT (BOP) - Skip se Dual Parcelling attivo ---
if(!Enable_DualParcelling) {
    CheckBreakOnProfit();
}
```

#### D) `Sugamara.mq5` - OnDeinit() - Aggiungere cleanup

```mql5
// Prima di Print("SUGAMARA DEINIT") (circa linea 390)

// Deinitialize Dual Parcel Manager
DeinitializeDualParcelManager();
```

#### E) `GridASystem.mqh` - UpdateGridAUpperStatus() - Integrare tracking

```mql5
// Nella funzione UpdateGridAUpperStatus(), dopo la riga che setta ORDER_FILLED:
// if(PositionSelectByTicket(ticket)) {
//     gridA_Upper_Status[level] = ORDER_FILLED;

// AGGIUNGERE dopo gridA_Upper_Status[level] = ORDER_FILLED;
if(Enable_DualParcelling) {
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double lot = PositionGetDouble(POSITION_VOLUME);
    double tp = gridA_Upper_TP[level];
    SetupDualParcelTracking(ticket, GRID_A, ZONE_UPPER, level, entry, lot, tp, currentSpacing_Pips);
}
```

#### F) `GridASystem.mqh` - UpdateGridALowerStatus() - Stessa modifica

```mql5
// AGGIUNGERE dopo gridA_Lower_Status[level] = ORDER_FILLED;
if(Enable_DualParcelling) {
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double lot = PositionGetDouble(POSITION_VOLUME);
    double tp = gridA_Lower_TP[level];
    SetupDualParcelTracking(ticket, GRID_A, ZONE_LOWER, level, entry, lot, tp, currentSpacing_Pips);
}
```

#### G) `GridBSystem.mqh` - Stesse modifiche per Grid B

```mql5
// In UpdateGridBUpperStatus() dopo ORDER_FILLED:
if(Enable_DualParcelling) {
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double lot = PositionGetDouble(POSITION_VOLUME);
    double tp = gridB_Upper_TP[level];
    SetupDualParcelTracking(ticket, GRID_B, ZONE_UPPER, level, entry, lot, tp, currentSpacing_Pips);
}

// In UpdateGridBLowerStatus() dopo ORDER_FILLED:
if(Enable_DualParcelling) {
    double entry = PositionGetDouble(POSITION_PRICE_OPEN);
    double lot = PositionGetDouble(POSITION_VOLUME);
    double tp = gridB_Lower_TP[level];
    SetupDualParcelTracking(ticket, GRID_B, ZONE_LOWER, level, entry, lot, tp, currentSpacing_Pips);
}
```

#### H) `PositionMonitor.mqh` - Recycling Integration

```mql5
// In ProcessGridACyclicReopen(), modificare ShouldReopenGridAUpper():
bool ShouldReopenGridAUpper(int level) {
    ENUM_ORDER_STATUS status = gridA_Upper_Status[level];
    
    if(status != ORDER_CLOSED_TP && status != ORDER_CLOSED_SL && status != ORDER_CANCELLED) {
        return false;
    }
    
    // v5.2: Check Dual Parcel status
    if(Enable_DualParcelling && !IsDualParcelFullyClosed(GRID_A, ZONE_UPPER, level)) {
        return false;  // Wait for both parcels to close
    }
    
    // ... resto della funzione invariato
}
```

---

## 🔄 COMPATIBILITÀ CON ALTRE FUNZIONALITÀ

### ✅ RECYCLING - Compatibile (con modifica)
Il recycling aspetta che **entrambi i parcels siano chiusi** prima di riaprire il livello.

### ✅ SHIELD - Compatibile
Shield protegge l'intera posizione, non interferisce con i parcels.

### ✅ COP (Close On Profit) - Compatibile
COP chiude tutto quando raggiunge target - chiuderà entrambi i parcels.

### ⚠️ BOP (Break On Profit) - DISABILITATO
Quando Dual Parcelling è attivo, BOP viene automaticamente disabilitato.
La logica BE di Dual Parcelling è più sofisticata e specifica per ogni parcel.

---

## 📊 CONFIGURAZIONE CONSIGLIATA

### Setup Conservativo (Default)
```
Enable_DualParcelling = true
ParcelA_TP_Levels = 1        // TP1 = 1 livello
ParcelA_SL_ToBE_Pct = 50.0   // BE al 50%
ParcelB_TP_Levels = 2        // TP2 = 2 livelli  
ParcelB_SL_ToBE_Pct = 100.0  // BE quando Parcel A chiude
DualParcel_LotRatio = 0.5    // 50/50 split
```

### Setup Aggressivo
```
Enable_DualParcelling = true
ParcelA_TP_Levels = 1        
ParcelA_SL_ToBE_Pct = 30.0   // BE precoce al 30%
ParcelB_TP_Levels = 3        // TP2 = 3 livelli (più lontano)
ParcelB_SL_ToBE_Pct = 70.0   // BE prima che Parcel A chiuda
DualParcel_LotRatio = 0.4    // 40/60 - più lot su Parcel B
```

### Setup Ultra-Safe
```
Enable_DualParcelling = true
ParcelA_TP_Levels = 1        
ParcelA_SL_ToBE_Pct = 40.0   
ParcelB_TP_Levels = 2        
ParcelB_SL_ToBE_Pct = 100.0  
DualParcel_LotRatio = 0.6    // 60/40 - più lot su Parcel A (chiude prima)
```

---

## 📁 STRUTTURA FILE

```
Sugamara/
├── Config/
│   ├── Enums.mqh            (nessuna modifica)
│   ├── InputParameters.mqh  (+ sezione Dual Parcelling)
│   └── PairPresets.mqh      (nessuna modifica)
├── Core/
│   └── ...                  (nessuna modifica)
├── Trading/
│   ├── DualParcelManager.mqh  ← NUOVO FILE
│   ├── GridASystem.mqh        (+ integrazione tracking)
│   ├── GridBSystem.mqh        (+ integrazione tracking)
│   ├── OrderManager.mqh       (nessuna modifica)
│   ├── PositionMonitor.mqh    (+ integrazione recycling)
│   ├── RiskManager.mqh        (nessuna modifica)
│   └── ShieldManager.mqh      (nessuna modifica)
├── Utils/
│   └── ...                  (nessuna modifica)
├── UI/
│   └── Dashboard.mqh        (+ display stats opzionale)
└── Sugamara.mq5             (+ include e chiamate)
```

---

## 🎮 HOTKEY SUGGERITA

Aggiungere in `OnChartEvent()`:

```mql5
// P = Dual Parcel Report
if(key == 'P' || key == 'p') {
    LogDualParcelReport();
}
```

---

## ✅ CHECKLIST IMPLEMENTAZIONE

- [ ] Copiare `DualParcelManager.mqh` in `/Trading/`
- [ ] Aggiungere parametri input a `InputParameters.mqh`
- [ ] Aggiungere `#include` in `Sugamara.mq5`
- [ ] Aggiungere `InitializeDualParcelManager()` in OnInit
- [ ] Aggiungere `ProcessDualParcels()` in OnTick
- [ ] Aggiungere `DeinitializeDualParcelManager()` in OnDeinit
- [ ] Modificare `UpdateGridAUpperStatus()` per tracking
- [ ] Modificare `UpdateGridALowerStatus()` per tracking
- [ ] Modificare `UpdateGridBUpperStatus()` per tracking
- [ ] Modificare `UpdateGridBLowerStatus()` per tracking
- [ ] Modificare `ShouldReopenGridAUpper()` per recycling
- [ ] Modificare `ShouldReopenGridALower()` per recycling
- [ ] Modificare `ShouldReopenGridBUpper()` per recycling
- [ ] Modificare `ShouldReopenGridBLower()` per recycling
- [ ] Compilare e verificare 0 errori
- [ ] Test in Strategy Tester
- [ ] Test su Demo Account

---

## 📈 VANTAGGI DUAL PARCELLING

1. **Profit Locking**: Parcel A chiude a TP1 → profit garantito
2. **Upside Potential**: Parcel B può raggiungere TP2 → profit extra
3. **Risk Management**: BE automatico protegge da inversioni
4. **Flessibilità**: Percentuali configurabili per ogni scenario di mercato
5. **Nessun costo extra**: Stesso numero di ordini, stesso margine

---

*Documento generato da Claude - SUGAMARA v5.2*
*Data: Dicembre 2025*
