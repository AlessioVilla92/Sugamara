# PAIR SPACING - Ricerca Sugamara

## Parametri Default per Pair

| Pair | Default Spacing | TP | Spread | Daily Range | ATR Tipico | Note |
|------|-----------------|-----|--------|-------------|------------|------|
| EUR/USD | 9.0 pips | 18.0 pips | 1.0 pips | 80 pips | 25 pips | Standard |
| USD/CAD | 12.0 pips | 20.0 pips | 1.3 pips | 65 pips | 22 pips | Spread più alto |
| AUD/NZD | 10.0 pips | 15.0 pips | 3.0 pips | 65 pips | 18 pips | BEST NEUTRAL |
| EUR/CHF | 10.0 pips | 15.0 pips | 1.5 pips | 50 pips | 15 pips | LOW VOLATILITY |
| AUD/CAD | 10.0 pips | 15.0 pips | 2.5 pips | 75 pips | 22 pips | Commodity |
| NZD/CAD | 10.0 pips | 15.0 pips | 3.0 pips | 70 pips | 20 pips | - |
| EUR/GBP | 10.0 pips | 15.0 pips | 1.5 pips | 55 pips | 16 pips | EXCELLENT NEUTRAL |
| GBP/USD | 12.0 pips | 20.0 pips | 1.2 pips | 100 pips | 28 pips | Mean Reverting |
| USD/CHF | 10.0 pips | 15.0 pips | 1.5 pips | 60 pips | 18 pips | Safe Haven |
| USD/JPY | 12.0 pips | 20.0 pips | 1.0 pips | 95 pips | 28 pips | HIGH VOLATILITY |

---

## Dove sono definiti i parametri

I parametri per pair sono in `Config/InputParameters.mqh` (linee 686-870):

- Sezione 19: EUR/USD (EURUSD_DefaultSpacing, EURUSD_TP_Pips, etc.)
- Sezione 20: USD/CAD
- Sezione 21: AUD/NZD (BEST NEUTRAL)
- Sezione 22: EUR/CHF (LOW VOLATILITY)
- Sezione 23: AUD/CAD
- Sezione 24: NZD/CAD
- Sezione 25: EUR/GBP (EXCELLENT NEUTRAL)
- Sezione 26: GBP/USD (MEAN REVERTING)
- Sezione 27: USD/CHF (SAFE HAVEN)
- Sezione 28: USD/JPY (HIGH VOLATILITY)
- Sezione 29: CUSTOM

---

## Sistema Spacing Attuale

### ENUM_SPACING_MODE (in Config/Enums.mqh)

```mql5
enum ENUM_SPACING_MODE {
    SPACING_FIXED,              // Fixed - Spacing fisso in pips
    SPACING_ATR,                // ATR Based - Spacing basato su ATR (CONSIGLIATO)
    SPACING_GEOMETRIC           // Geometric - Spacing % del prezzo
};
```

### Default nel codice

```mql5
input ENUM_SPACING_MODE SpacingMode = SPACING_ATR;  // Default è ATR, non FIXED!
```

### Comportamento per modalità

| Modalità | Cosa fa | Spacing usato |
|----------|---------|---------------|
| `SPACING_FIXED` | Usa valore fisso | `Fixed_Spacing_Pips` (default 20 pips) |
| `SPACING_ATR` | Calcola da ATR dinamico | Varia in base a volatilità (8-35 pips) |
| `SPACING_GEOMETRIC` | % del prezzo | `SpacingGeometric_Percent` × prezzo |

---

## ATR Dynamic Spacing (v4.0)

Se `EnableDynamicATRSpacing = true` e `SpacingMode = SPACING_ATR`:

| ATR Step | Soglia ATR | Spacing |
|----------|------------|---------|
| VERY_LOW | < 10 pips | 8.0 pips |
| LOW | < 18 pips | 12.0 pips |
| NORMAL | < 28 pips | 18.0 pips |
| HIGH | < 40 pips | 26.0 pips |
| EXTREME | >= 40 pips | 35.0 pips |

**Limiti Assoluti**: Min 6.0 pips, Max 50.0 pips

---

## TP in CASCADE_OVERLAP Mode

Nel modo CASCADE_OVERLAP (RIBELLE) il TP viene calcolato dinamicamente, NON usa i valori `XXX_TP_Pips` dei pair:

- **STOP orders**: TP = spacing
- **LIMIT orders**: TP = spacing + hedge_offset (3 pips default)
- **Ultimo livello**: TP = `FinalLevel_TP_Pips` (15 pips default)

---

## File Rilevanti

- `Config/InputParameters.mqh` - Parametri input per ogni pair
- `Config/Enums.mqh` - ENUM_SPACING_MODE
- `Config/PairPresets.mqh` - Funzione ApplyPairPresets() che setta activePair_RecommendedSpacing
- `Core/ModeLogic.mqh` - Calcolo currentSpacing_Pips
- `Utils/DynamicATRAdapter.mqh` - GetDynamicSpacing()
- `Utils/GridHelpers.mqh` - Usa currentSpacing_Pips per calcolare prezzi grid

---

## Proposta: SPACING_PAIR_DEFAULT

Modalità mancante che userebbe automaticamente il `DefaultSpacing` del pair selezionato:

1. Selezioni il pair (es: EUR/USD)
2. Selezioni `SpacingMode = SPACING_PAIR_DEFAULT`
3. Il sistema usa automaticamente 9.0 pips (EURUSD_DefaultSpacing)

**File da modificare per implementare:**
1. `Config/Enums.mqh` - Aggiungere SPACING_PAIR_DEFAULT all'enum
2. `Core/ModeLogic.mqh` - Gestire la nuova modalità
3. `Utils/DynamicATRAdapter.mqh` - Aggiornare GetDynamicSpacing()

---

*Documento generato da analisi codebase Sugamara - Dicembre 2024*
