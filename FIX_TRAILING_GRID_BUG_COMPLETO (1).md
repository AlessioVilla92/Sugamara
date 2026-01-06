# 🔧 FIX TRAILING GRID - DOCUMENTO COMPLETO PER CLAUDE CODE
## SUGAMARA v8.0 - Data: 5 Gennaio 2026

---

# 📋 INDICE

1. [Obiettivo della Funzionalità Trailing Grid](#1-obiettivo-della-funzionalità-trailing-grid)
2. [Come Funziona il Trailing Grid](#2-come-funziona-il-trailing-grid)
3. [Bug Identificati](#3-bug-identificati)
4. [Fix Dettagliati](#4-fix-dettagliati)
5. [Ordine di Implementazione](#5-ordine-di-implementazione)
6. [Verifica Post-Implementazione](#6-verifica-post-implementazione)

---

# 1. OBIETTIVO DELLA FUNZIONALITÀ TRAILING GRID

## Scopo
Il **Trailing Grid** è un sistema che **estende dinamicamente la griglia** quando il prezzo si avvicina ai bordi della griglia esistente.

## Logica Fondamentale
Quando il prezzo **si avvicina e filla** la penultima, terzultima o ultima grid (configurabile tramite `Trail_Trigger_Level`):
1. **INSERISCE** una nuova coppia di grid al livello successivo (identica alle precedenti)
2. **RIMUOVE** (opzionale) la grid più lontana dal lato opposto per bilanciare
3. **AGGIORNA** lo Shield per seguire l'espansione

## Parametri di Configurazione
| Parametro | Default | Descrizione |
|-----------|---------|-------------|
| `Enable_TrailingGrid` | true | Abilita/disabilita il sistema |
| `Trail_Trigger_Level` | 2 | Quando scatta (1=ultima, 2=penultima, 3=terzultima) |
| `Trail_Spacing_Multiplier` | 1.0 | Moltiplicatore spacing per nuove grid |
| `Trail_Max_Extra_Grids` | 4 | Massimo grid extra per lato |
| `Trail_Remove_Distant` | true | Rimuove grid lontane dal lato opposto |
| `Trail_Sync_Shield` | true | Sincronizza Shield con nuovi limiti |

---

# 2. COME FUNZIONA IL TRAILING GRID

## Flusso di Esecuzione

```
OnTick()
   └── ProcessTrailingGridCheck()  [TrailingGridManager.mqh:478]
          │
          ├── CountPendingGridsAbove(currentPrice)  [riga 487]
          │      → Conta quante grid PENDING ci sono SOPRA il prezzo
          │
          ├── SE pendingAbove <= Trail_Trigger_Level:  [riga 492]
          │      │
          │      ├── GetNextGridLevelAbove()  [riga 496]
          │      │      → Calcola il prezzo della nuova grid
          │      │
          │      ├── InsertNewGridAbove(newLevel)  [riga 498]
          │      │      → Inserisce BUY STOP (Grid A) + SELL LIMIT (Grid B)
          │      │      → Aggiorna arrays: gridA_Upper_*, gridB_Upper_*
          │      │      → g_trailExtraGridsAbove++
          │      │
          │      └── RemoveDistantGridBelow()  [riga 512]  ⚠️ BUG QUI!
          │             → Elimina grid lontana sotto
          │             → MA NON decrementa g_trailExtraGridsBelow
          │
          └── (Stessa logica per lato SOTTO)
```

## Array Utilizzati

Le grid trailing vengono salvate negli **STESSI array** delle grid normali, ma con **indici oltre GridLevelsPerSide**:

```
Grid Normali:     indici 0, 1, 2, 3, 4, 5, 6  (GridLevelsPerSide = 7)
Grid Trailing:    indici 7, 8, 9, 10...       (fino a MAX_GRID_LEVELS)

Esempio con GridLevelsPerSide=7 e Trail_Max_Extra_Grids=4:
- gridA_Upper_Tickets[0-6]  = Grid normali
- gridA_Upper_Tickets[7-10] = Grid trailing
```

---

# 3. BUG IDENTIFICATI

## 🔴 BUG 1A: CONTATORI NON DECREMENTATI

### Localizzazione
- **File:** `TrailingGridManager.mqh`
- **Funzione:** `RemoveDistantGridBelow()` riga 364
- **Funzione:** `RemoveDistantGridAbove()` riga 412

### Problema
Quando viene rimossa una grid trailing, la statistica viene incrementata (`g_trailLowerRemoved++`) ma il **contatore attivo NON viene decrementato**.

### Codice Attuale (ERRATO)
```cpp
// RemoveDistantGridBelow() - riga 362-365
LogTrail_GridRemoved("BELOW", lowestIndex, lowestPrice);
g_trailLowerRemoved++;
return true;
// ❌ MANCA: g_trailExtraGridsBelow--;

// RemoveDistantGridAbove() - riga 410-413
LogTrail_GridRemoved("ABOVE", highestIndex, highestPrice);
g_trailUpperRemoved++;
return true;
// ❌ MANCA: g_trailExtraGridsAbove--;
```

### Conseguenza
```
SEQUENZA:
1. Prezzo sale → InsertAbove() → g_trailExtraGridsAbove = 1
2. RemoveDistantBelow() chiamata → g_trailExtraGridsBelow RIMANE 0
3. Prezzo sale ancora → InsertAbove() → g_trailExtraGridsAbove = 2
4. ... continua ...
5. g_trailExtraGridsAbove = 4 (limite raggiunto)
6. SISTEMA BLOCCATO - non inserisce più nuove grid!
7. Anche se le grid rimosse non esistono più, il contatore non lo sa
```

---

## 🔴 BUG 1B: LOOP STATUS LIMITATO A GridLevelsPerSide

### Localizzazione
- **File:** `GridASystem.mqh` righe 259, 264
- **File:** `GridBSystem.mqh` righe 222, 227

### Problema
Le funzioni `UpdateGridAStatuses()` e `UpdateGridBStatuses()` iterano **SOLO** fino a `GridLevelsPerSide`, quindi le grid trailing (indici 7, 8, 9...) **NON vengono MAI monitorate**.

### Codice Attuale (ERRATO)
```cpp
// GridASystem.mqh - UpdateGridAStatuses() riga 257-267
void UpdateGridAStatuses() {
    // Update Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {  // ❌ Solo 0-6!
        UpdateGridAUpperStatus(i);
    }
    
    // Update Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {  // ❌ Solo 0-6!
        UpdateGridALowerStatus(i);
    }
}

// GridBSystem.mqh - UpdateGridBStatuses() riga 220-230
void UpdateGridBStatuses() {
    for(int i = 0; i < GridLevelsPerSide; i++) {  // ❌ Solo 0-6!
        UpdateGridBUpperStatus(i);
    }
    
    for(int i = 0; i < GridLevelsPerSide; i++) {  // ❌ Solo 0-6!
        UpdateGridBLowerStatus(i);
    }
}
```

### Conseguenza
- Grid trailing (indice 7, 8, 9...) **MAI monitorate**
- Stato rimane `ORDER_PENDING` per sempre negli array
- Anche se il broker le ha fillate → il sistema **NON lo sa**
- Anche se sono chiuse in profit → il sistema **NON lo sa**

---

## 🔴 BUG 1C: LOOP REOPEN LIMITATO A GridLevelsPerSide

### Localizzazione
- **File:** `GridASystem.mqh` righe 376, 383
- **File:** `GridBSystem.mqh` righe 334, 341

### Problema
Le funzioni `ProcessGridACyclicReopen()` e `ProcessGridBCyclicReopen()` iterano **SOLO** fino a `GridLevelsPerSide`, quindi le grid trailing chiuse **NON vengono MAI riaperte**.

### Codice Attuale (ERRATO)
```cpp
// GridASystem.mqh - ProcessGridACyclicReopen() riga 371-388
void ProcessGridACyclicReopen() {
    if(!EnableCyclicReopen) return;
    if(IsMarketTooVolatile()) return;
    
    // Upper Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {  // ❌ Solo 0-6!
        if(ShouldReopenGridAUpper(i)) {
            ReopenGridAUpper(i);
        }
    }
    
    // Lower Zone
    for(int i = 0; i < GridLevelsPerSide; i++) {  // ❌ Solo 0-6!
        if(ShouldReopenGridALower(i)) {
            ReopenGridALower(i);
        }
    }
}

// GridBSystem.mqh - ProcessGridBCyclicReopen() riga 329-346
void ProcessGridBCyclicReopen() {
    for(int i = 0; i < GridLevelsPerSide; i++) {  // ❌ Solo 0-6!
        if(ShouldReopenGridBUpper(i)) {
            ReopenGridBUpper(i);
        }
    }
    
    for(int i = 0; i < GridLevelsPerSide; i++) {  // ❌ Solo 0-6!
        if(ShouldReopenGridBLower(i)) {
            ReopenGridBLower(i);
        }
    }
}
```

### Conseguenza
- Grid trailing chiuse **MAI riaperte**
- La strategia perde il suo vantaggio di cycling
- Le grid trailing diventano "usa e getta" invece che cicliche

---

## 🔴 BUG 1D: IsValidLevelIndex BLOCCA INDICI TRAILING

### Localizzazione
- **File:** `GridHelpers.mqh` riga 859-861

### Problema
La funzione `IsValidLevelIndex()` ritorna `false` per qualsiasi indice >= GridLevelsPerSide.

### Codice Attuale (ERRATO)
```cpp
// GridHelpers.mqh riga 859-861
bool IsValidLevelIndex(int level) {
    return (level >= 0 && level < GridLevelsPerSide && level < MAX_GRID_LEVELS);
    //                    ^^^^^^^^^^^^^^^^^^^^^^^^
    //                    ❌ Blocca indici 7, 8, 9...
}
```

### Dove Viene Usata (BLOCCANDO IL TRAILING)
```cpp
// GridASystem.mqh riga 272-273
void UpdateGridAUpperStatus(int level) {
    if(!IsValidLevelIndex(level)) return;  // ❌ Esce subito per indice 7+
    ...
}

// GridASystem.mqh riga 322-323
void UpdateGridALowerStatus(int level) {
    if(!IsValidLevelIndex(level)) return;  // ❌ Esce subito per indice 7+
    ...
}

// GridBSystem.mqh riga 235-236
void UpdateGridBUpperStatus(int level) {
    if(!IsValidLevelIndex(level)) return;  // ❌ Esce subito per indice 7+
    ...
}

// GridBSystem.mqh riga 280-281
void UpdateGridBLowerStatus(int level) {
    if(!IsValidLevelIndex(level)) return;  // ❌ Esce subito per indice 7+
    ...
}
```

### Conseguenza
Anche se correggiamo i loop (BUG 1B e 1C), le funzioni **escono immediatamente** quando ricevono un indice trailing, **senza processare nulla**!

---

# 4. FIX DETTAGLIATI

## ⚠️ ORDINE CRITICO

I fix **DEVONO** essere applicati in questo ordine esatto:
```
1. FIX 1D (GridHelpers.mqh) → Prerequisito per tutti gli altri
2. FIX 1A (TrailingGridManager.mqh)
3. FIX 1B (GridASystem.mqh + GridBSystem.mqh)
4. FIX 1C (GridASystem.mqh + GridBSystem.mqh)
```

---

## FIX 1D: Nuova Funzione IsValidExtendedLevelIndex

### File: `GridHelpers.mqh`
### Azione: AGGIUNGERE nuova funzione DOPO IsValidLevelIndex (riga 861)

```cpp
//+------------------------------------------------------------------+
//| Validate Grid Level Index (Extended for Trailing Grid)           |
//| Include indici trailing: 0 to GridLevelsPerSide + extraGrids     |
//+------------------------------------------------------------------+
bool IsValidExtendedLevelIndex(int level, int extraGrids) {
    int maxLevel = GridLevelsPerSide + extraGrids;
    if(maxLevel > MAX_GRID_LEVELS) maxLevel = MAX_GRID_LEVELS;
    return (level >= 0 && level < maxLevel);
}
```

### Posizione Esatta
Inserire **DOPO** la riga 861 (dopo la chiusura di `IsValidLevelIndex`):

```cpp
// Riga 859-861 ESISTENTE - NON MODIFICARE
bool IsValidLevelIndex(int level) {
    return (level >= 0 && level < GridLevelsPerSide && level < MAX_GRID_LEVELS);
}

// ⬇️ INSERIRE QUI ⬇️
//+------------------------------------------------------------------+
//| Validate Grid Level Index (Extended for Trailing Grid)           |
//| Include indici trailing: 0 to GridLevelsPerSide + extraGrids     |
//+------------------------------------------------------------------+
bool IsValidExtendedLevelIndex(int level, int extraGrids) {
    int maxLevel = GridLevelsPerSide + extraGrids;
    if(maxLevel > MAX_GRID_LEVELS) maxLevel = MAX_GRID_LEVELS;
    return (level >= 0 && level < maxLevel);
}

// Riga 863+ ESISTENTE - NON MODIFICARE
//+------------------------------------------------------------------+
//| Check if Level Should be Active                                  |
//+------------------------------------------------------------------+
```

---

## FIX 1A: Decrementare Contatori alla Rimozione

### File: `TrailingGridManager.mqh`

### Modifica 1 - Funzione RemoveDistantGridBelow()
**Riga:** 364-365
**Azione:** Aggiungere decremento contatore

```cpp
// PRIMA (riga 362-365):
    LogTrail_GridRemoved("BELOW", lowestIndex, lowestPrice);
    g_trailLowerRemoved++;
    return true;
}

// DOPO:
    LogTrail_GridRemoved("BELOW", lowestIndex, lowestPrice);
    g_trailLowerRemoved++;
    g_trailExtraGridsBelow--;  // ⬅️ AGGIUNGERE QUESTA RIGA
    return true;
}
```

### Modifica 2 - Funzione RemoveDistantGridAbove()
**Riga:** 412-413
**Azione:** Aggiungere decremento contatore

```cpp
// PRIMA (riga 410-413):
    LogTrail_GridRemoved("ABOVE", highestIndex, highestPrice);
    g_trailUpperRemoved++;
    return true;
}

// DOPO:
    LogTrail_GridRemoved("ABOVE", highestIndex, highestPrice);
    g_trailUpperRemoved++;
    g_trailExtraGridsAbove--;  // ⬅️ AGGIUNGERE QUESTA RIGA
    return true;
}
```

---

## FIX 1B: Estendere Loop Status Monitoring

### File: `GridASystem.mqh`

### Modifica 1 - UpdateGridAStatuses() Upper Zone
**Riga:** 259
**Azione:** Estendere limite loop

```cpp
// PRIMA (riga 259):
    for(int i = 0; i < GridLevelsPerSide; i++) {

// DOPO:
    int maxLevelUpper = GridLevelsPerSide + g_trailExtraGridsAbove;
    if(maxLevelUpper > MAX_GRID_LEVELS) maxLevelUpper = MAX_GRID_LEVELS;
    for(int i = 0; i < maxLevelUpper; i++) {
```

### Modifica 2 - UpdateGridAStatuses() Lower Zone
**Riga:** 264
**Azione:** Estendere limite loop

```cpp
// PRIMA (riga 264):
    for(int i = 0; i < GridLevelsPerSide; i++) {

// DOPO:
    int maxLevelLower = GridLevelsPerSide + g_trailExtraGridsBelow;
    if(maxLevelLower > MAX_GRID_LEVELS) maxLevelLower = MAX_GRID_LEVELS;
    for(int i = 0; i < maxLevelLower; i++) {
```

### Modifica 3 - UpdateGridAUpperStatus()
**Riga:** 273
**Azione:** Usare funzione Extended

```cpp
// PRIMA (riga 273):
    if(!IsValidLevelIndex(level)) return;

// DOPO:
    if(!IsValidExtendedLevelIndex(level, g_trailExtraGridsAbove)) return;
```

### Modifica 4 - UpdateGridALowerStatus()
**Riga:** 323
**Azione:** Usare funzione Extended

```cpp
// PRIMA (riga 323):
    if(!IsValidLevelIndex(level)) return;

// DOPO:
    if(!IsValidExtendedLevelIndex(level, g_trailExtraGridsBelow)) return;
```

---

### File: `GridBSystem.mqh`

### Modifica 5 - UpdateGridBStatuses() Upper Zone
**Riga:** 222
**Azione:** Estendere limite loop

```cpp
// PRIMA (riga 222):
    for(int i = 0; i < GridLevelsPerSide; i++) {

// DOPO:
    int maxLevelUpper = GridLevelsPerSide + g_trailExtraGridsAbove;
    if(maxLevelUpper > MAX_GRID_LEVELS) maxLevelUpper = MAX_GRID_LEVELS;
    for(int i = 0; i < maxLevelUpper; i++) {
```

### Modifica 6 - UpdateGridBStatuses() Lower Zone
**Riga:** 227
**Azione:** Estendere limite loop

```cpp
// PRIMA (riga 227):
    for(int i = 0; i < GridLevelsPerSide; i++) {

// DOPO:
    int maxLevelLower = GridLevelsPerSide + g_trailExtraGridsBelow;
    if(maxLevelLower > MAX_GRID_LEVELS) maxLevelLower = MAX_GRID_LEVELS;
    for(int i = 0; i < maxLevelLower; i++) {
```

### Modifica 7 - UpdateGridBUpperStatus()
**Riga:** 236
**Azione:** Usare funzione Extended

```cpp
// PRIMA (riga 236):
    if(!IsValidLevelIndex(level)) return;

// DOPO:
    if(!IsValidExtendedLevelIndex(level, g_trailExtraGridsAbove)) return;
```

### Modifica 8 - UpdateGridBLowerStatus()
**Riga:** 281
**Azione:** Usare funzione Extended

```cpp
// PRIMA (riga 281):
    if(!IsValidLevelIndex(level)) return;

// DOPO:
    if(!IsValidExtendedLevelIndex(level, g_trailExtraGridsBelow)) return;
```

---

## FIX 1C: Estendere Loop Cyclic Reopen

### File: `GridASystem.mqh`

### Modifica 9 - ProcessGridACyclicReopen() Upper Zone
**Riga:** 376
**Azione:** Estendere limite loop

```cpp
// PRIMA (riga 376):
    for(int i = 0; i < GridLevelsPerSide; i++) {

// DOPO:
    int maxLevelUpper = GridLevelsPerSide + g_trailExtraGridsAbove;
    if(maxLevelUpper > MAX_GRID_LEVELS) maxLevelUpper = MAX_GRID_LEVELS;
    for(int i = 0; i < maxLevelUpper; i++) {
```

### Modifica 10 - ProcessGridACyclicReopen() Lower Zone
**Riga:** 383
**Azione:** Estendere limite loop

```cpp
// PRIMA (riga 383):
    for(int i = 0; i < GridLevelsPerSide; i++) {

// DOPO:
    int maxLevelLower = GridLevelsPerSide + g_trailExtraGridsBelow;
    if(maxLevelLower > MAX_GRID_LEVELS) maxLevelLower = MAX_GRID_LEVELS;
    for(int i = 0; i < maxLevelLower; i++) {
```

---

### File: `GridBSystem.mqh`

### Modifica 11 - ProcessGridBCyclicReopen() Upper Zone
**Riga:** 334
**Azione:** Estendere limite loop

```cpp
// PRIMA (riga 334):
    for(int i = 0; i < GridLevelsPerSide; i++) {

// DOPO:
    int maxLevelUpper = GridLevelsPerSide + g_trailExtraGridsAbove;
    if(maxLevelUpper > MAX_GRID_LEVELS) maxLevelUpper = MAX_GRID_LEVELS;
    for(int i = 0; i < maxLevelUpper; i++) {
```

### Modifica 12 - ProcessGridBCyclicReopen() Lower Zone
**Riga:** 341
**Azione:** Estendere limite loop

```cpp
// PRIMA (riga 341):
    for(int i = 0; i < GridLevelsPerSide; i++) {

// DOPO:
    int maxLevelLower = GridLevelsPerSide + g_trailExtraGridsBelow;
    if(maxLevelLower > MAX_GRID_LEVELS) maxLevelLower = MAX_GRID_LEVELS;
    for(int i = 0; i < maxLevelLower; i++) {
```

---

# 5. ORDINE DI IMPLEMENTAZIONE

## Checklist per Claude Code

```
╔═══════════════════════════════════════════════════════════════════════════════╗
║  STEP 1: APPLICARE FIX 1D (GridHelpers.mqh)                                   ║
║          → Aggiungere funzione IsValidExtendedLevelIndex DOPO riga 861        ║
║          → Questa funzione è PREREQUISITO per tutti gli altri fix             ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║  STEP 2: APPLICARE FIX 1A (TrailingGridManager.mqh)                           ║
║          → Riga 364: aggiungere g_trailExtraGridsBelow--;                     ║
║          → Riga 412: aggiungere g_trailExtraGridsAbove--;                     ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║  STEP 3: APPLICARE FIX 1B - GridASystem.mqh                                   ║
║          → Riga 259: estendere loop Upper con maxLevelUpper                   ║
║          → Riga 264: estendere loop Lower con maxLevelLower                   ║
║          → Riga 273: cambiare a IsValidExtendedLevelIndex                     ║
║          → Riga 323: cambiare a IsValidExtendedLevelIndex                     ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║  STEP 4: APPLICARE FIX 1B - GridBSystem.mqh                                   ║
║          → Riga 222: estendere loop Upper con maxLevelUpper                   ║
║          → Riga 227: estendere loop Lower con maxLevelLower                   ║
║          → Riga 236: cambiare a IsValidExtendedLevelIndex                     ║
║          → Riga 281: cambiare a IsValidExtendedLevelIndex                     ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║  STEP 5: APPLICARE FIX 1C - GridASystem.mqh                                   ║
║          → Riga 376: estendere loop Upper con maxLevelUpper                   ║
║          → Riga 383: estendere loop Lower con maxLevelLower                   ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║  STEP 6: APPLICARE FIX 1C - GridBSystem.mqh                                   ║
║          → Riga 334: estendere loop Upper con maxLevelUpper                   ║
║          → Riga 341: estendere loop Lower con maxLevelLower                   ║
╠═══════════════════════════════════════════════════════════════════════════════╣
║  STEP 7: COMPILARE E VERIFICARE                                               ║
║          → Nessun errore di compilazione                                      ║
║          → Nessun warning critico                                             ║
║          → EA si carica correttamente                                         ║
╚═══════════════════════════════════════════════════════════════════════════════╝
```

---

# 6. VERIFICA POST-IMPLEMENTAZIONE

## Test da Eseguire in Demo

| Test | Cosa Verificare | Log da Cercare |
|------|-----------------|----------------|
| **Inserimento** | Grid trailing vengono create | `[TrailGrid] INSERTED ABOVE/BELOW` |
| **Trigger** | Sistema si attiva alla penultima | `[TrailGrid] TRIGGERED` |
| **Monitoraggio** | Grid trailing cambiano stato | Log stato PENDING → FILLED |
| **Cycling** | Grid trailing chiuse vengono riaperte | `Reopening Grid A/B` |
| **Rimozione** | Grid lontane vengono eliminate | `[TrailGrid] REMOVED` |
| **Contatori** | Dashboard mostra Up/Dn corretti | `GetTrailingGridStats()` |
| **Limite** | Non supera Trail_Max_Extra_Grids | Contatore fermo a max |

## Scenario di Test Consigliato

1. Caricare EA su EURUSD in demo
2. Impostare `Trail_Trigger_Level = 2`
3. Impostare `Trail_Max_Extra_Grids = 3`
4. Attendere che il prezzo si muova verso una resistenza
5. Verificare che:
   - Quando rimangono 2 pending sopra → inserisce Grid +8
   - Elimina Grid -7 dal lato opposto (se pending)
   - Contatore passa a Up1/3
   - Se Grid +8 viene fillata → stato passa a FILLED
   - Se Grid +8 chiude in profit → viene riaperta

---

# ✅ RIEPILOGO FINALE

## File da Modificare

| File | Modifiche | Righe |
|------|-----------|-------|
| `GridHelpers.mqh` | +1 funzione | dopo 861 |
| `TrailingGridManager.mqh` | +2 righe | 364, 412 |
| `GridASystem.mqh` | 6 modifiche | 259, 264, 273, 323, 376, 383 |
| `GridBSystem.mqh` | 6 modifiche | 222, 227, 236, 281, 334, 341 |

## Totale Modifiche: 15

## Tutti i Fix Sono INTERDIPENDENTI

⚠️ **ATTENZIONE CRITICA:** 
- I fix **DEVONO** essere applicati **TUTTI**
- L'ordine **DEVE** essere rispettato: **1D → 1A → 1B → 1C**
- Il FIX 1D deve essere applicato **PRIMA** perché gli altri dipendono da esso
- Applicare solo alcuni fix **NON RISOLVERÀ** il problema

---

**DOCUMENTO COMPLETATO - PRONTO PER CLAUDE CODE**

*Data: 5 Gennaio 2026*
*Versione: 1.0*
*Focus: Trailing Grid Bug Fix*
*Target: SUGAMARA v8.0*
