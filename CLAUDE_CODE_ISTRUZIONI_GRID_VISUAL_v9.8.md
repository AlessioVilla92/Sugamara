# SUGAMARA v9.8 - GRID LINES VISUAL SYSTEM

## 📋 OBIETTIVO

Implementare un sistema di visualizzazione delle grid lines che permetta di distinguere chiaramente:
- I 4 tipi di ordine (BUY STOP, BUY LIMIT, SELL LIMIT, SELL STOP)
- Grid A (BUY) vs Grid B (SELL)
- Status dell'ordine (PENDING vs FILLED)

---

## 🎯 SPECIFICHE TECNICHE

### Configurazione Linee:

| Tipo Ordine | Grid | Zona | Spessore | Offset Pixel |
|-------------|------|------|----------|--------------|
| BUY STOP | Grid A | Upper | 2 px | -1 px (giù) |
| BUY LIMIT | Grid A | Lower | 2 px | -1 px (giù) |
| SELL LIMIT | Grid B | Upper | 2 px | +1 px (su) |
| SELL STOP | Grid B | Lower | 2 px | +1 px (su) |

### Regola Generale:
- **Tutte le linee SELL**: Offset +1 pixel (verso l'alto)
- **Tutte le linee BUY**: Offset -1 pixel (verso il basso)
- **Distanza visiva totale**: 2 pixel tra BUY e SELL sullo stesso livello

### Colori (configurabili dall'utente):
I colori saranno definiti come input parameters per permettere personalizzazione.

---

## 📁 FILE DA CREARE/MODIFICARE

### File coinvolti:
1. `Config/VisualTheme.mqh` - Aggiungere costanti colori default
2. `Config/InputParameters.mqh` - Aggiungere input per colori personalizzabili
3. `Utils/GridVisual.mqh` - **NUOVO FILE** - Funzioni visualizzazione grid
4. `Sugamara.mq5` - Include del nuovo file e chiamate
5. `Trading/GridASystem.mqh` - Chiamare DrawGridLine dopo piazzamento
6. `Trading/GridBSystem.mqh` - Chiamare DrawGridLine dopo piazzamento

---

## 📝 IMPLEMENTAZIONE DETTAGLIATA

---

### 1️⃣ Config/VisualTheme.mqh

**AGGIUNGERE** alla fine del file (dopo le altre costanti colore):

```cpp
//+------------------------------------------------------------------+
//| 🎨 v9.8 GRID LINES VISUAL COLORS                                  |
//+------------------------------------------------------------------+

// Colori Default Grid Lines (modificabili via Input Parameters)
#define DEFAULT_COLOR_BUY_STOP      clrLime        // Verde brillante
#define DEFAULT_COLOR_BUY_LIMIT     clrSeaGreen    // Verde scuro
#define DEFAULT_COLOR_SELL_LIMIT    clrCoral       // Arancio/Corallo
#define DEFAULT_COLOR_SELL_STOP     clrCrimson     // Rosso scuro
#define DEFAULT_COLOR_ENTRY_LINE    clrGold        // Oro per Entry Point

// Spessore Linee
#define GRID_LINE_WIDTH             2              // 2 pixel per tutte le grid
#define ENTRY_LINE_WIDTH            3              // 3 pixel per Entry Point

// Offset Pixel (per separazione visiva)
#define PIXEL_OFFSET_SELL           1              // SELL verso l'alto (+1 px)
#define PIXEL_OFFSET_BUY            -1             // BUY verso il basso (-1 px)

// Stili Linea per Status
#define STYLE_PENDING               STYLE_SOLID    // Pending = Solida
#define STYLE_FILLED                STYLE_SOLID    // Filled = Solida (stesso, distingui per colore)
```

---

### 2️⃣ Config/InputParameters.mqh

**AGGIUNGERE** una nuova sezione dopo DASHBOARD SETTINGS (circa riga 760):

```cpp
//+------------------------------------------------------------------+
//| 🎨 GRID LINES VISUAL v9.8                                         |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔════════════════════════════════════════════════════════════╗"
input group "║  🎨 GRID LINES VISUAL v9.8                                 ║"
input group "╚════════════════════════════════════════════════════════════╝"

input group "    ✅ ATTIVAZIONE"
input bool      ShowGridLines = true;                        // ✅ Mostra Linee Grid su Chart
input bool      ShowEntryLine = true;                        // ✅ Mostra Linea Entry Point

input group "    🎨 COLORI GRID LINES"
input color     Color_BuyStop = clrLime;                     // 🟢 BUY STOP (Grid A Upper)
input color     Color_BuyLimit = clrSeaGreen;                // 🟢 BUY LIMIT (Grid A Lower)
input color     Color_SellLimit = clrCoral;                  // 🔴 SELL LIMIT (Grid B Upper)
input color     Color_SellStop = clrCrimson;                 // 🔴 SELL STOP (Grid B Lower)
input color     Color_EntryLine = clrGold;                   // 🟡 Entry Point

input group "    📐 DIMENSIONI"
input int       GridLine_Width = 2;                          // 📏 Spessore Linee Grid (pixel)
input int       EntryLine_Width = 3;                         // 📏 Spessore Linea Entry (pixel)
input int       GridLine_PixelOffset = 1;                    // 📐 Offset Separazione BUY/SELL (pixel)

input group "    🎯 OPZIONI AVANZATE"
input bool      GridLine_ShowLabels = false;                 // 🏷️ Mostra Etichette (A+1, B+1, ecc.)
input bool      GridLine_ShowTooltip = true;                 // 💬 Mostra Tooltip al passaggio mouse
input bool      GridLine_DifferentStyleFilled = false;       // 🔄 Stile diverso per FILLED (tratteggiata)
```

---

### 3️⃣ Utils/GridVisual.mqh (NUOVO FILE)

**CREARE** questo nuovo file:

```cpp
//+------------------------------------------------------------------+
//|                                                  GridVisual.mqh   |
//|                        Sugamara v9.8 - Grid Visualization         |
//|                                                                   |
//|  Sistema di visualizzazione grid lines con:                       |
//|  - 4 colori per tipo ordine (BUY STOP/LIMIT, SELL STOP/LIMIT)     |
//|  - Offset pixel per separazione BUY/SELL                          |
//|  - Tooltip informativi                                            |
//+------------------------------------------------------------------+
#property copyright "Sugamara (C) 2025-2026"
#property link      "https://sugamara.com"

//+------------------------------------------------------------------+
//| COSTANTI INTERNE                                                  |
//+------------------------------------------------------------------+
#define GRID_LINE_PREFIX        "SUGAMARA_GRID_"
#define ENTRY_LINE_NAME         "SUGAMARA_ENTRY"
#define GRID_LABEL_PREFIX       "SUGAMARA_LABEL_"

//+------------------------------------------------------------------+
//| VARIABILI GLOBALI MODULO                                          |
//+------------------------------------------------------------------+
bool g_gridLinesInitialized = false;
int g_totalGridLinesDrawn = 0;

//+------------------------------------------------------------------+
//| Inizializza Sistema Grid Visual                                   |
//+------------------------------------------------------------------+
void InitGridVisual() {
    g_gridLinesInitialized = true;
    g_totalGridLinesDrawn = 0;
    
    if(DetailedLogging) {
        Print("[GridVisual] Sistema inizializzato");
        PrintFormat("[GridVisual] ShowGridLines: %s", ShowGridLines ? "ON" : "OFF");
        PrintFormat("[GridVisual] Pixel Offset: %d", GridLine_PixelOffset);
    }
}

//+------------------------------------------------------------------+
//| Deinizializza - Rimuove tutte le linee                            |
//+------------------------------------------------------------------+
void DeinitGridVisual() {
    RemoveAllGridLines();
    g_gridLinesInitialized = false;
    
    if(DetailedLogging) {
        PrintFormat("[GridVisual] Rimosse %d linee", g_totalGridLinesDrawn);
    }
}

//+------------------------------------------------------------------+
//| Calcola Offset Prezzo per N Pixel                                 |
//| Converte pixel in prezzo basandosi sullo zoom corrente del chart  |
//+------------------------------------------------------------------+
double PixelsToPrice(int pixels) {
    // Ottieni range prezzo visibile sul chart
    double chartHigh = ChartGetDouble(0, CHART_PRICE_MAX);
    double chartLow = ChartGetDouble(0, CHART_PRICE_MIN);
    double priceRange = chartHigh - chartLow;
    
    // Ottieni altezza chart in pixel
    int chartHeight = (int)ChartGetInteger(0, CHART_HEIGHT_IN_PIXELS);
    
    // Evita divisione per zero
    if(chartHeight <= 0) return 0;
    
    // Calcola prezzo per pixel
    double pricePerPixel = priceRange / chartHeight;
    
    // Ritorna offset prezzo per N pixel
    return pricePerPixel * pixels;
}

//+------------------------------------------------------------------+
//| Ottieni Colore per Tipo Ordine                                    |
//+------------------------------------------------------------------+
color GetGridLineColor(ENUM_ORDER_TYPE orderType) {
    switch(orderType) {
        case ORDER_TYPE_BUY_STOP:   return Color_BuyStop;
        case ORDER_TYPE_BUY_LIMIT:  return Color_BuyLimit;
        case ORDER_TYPE_SELL_LIMIT: return Color_SellLimit;
        case ORDER_TYPE_SELL_STOP:  return Color_SellStop;
        default:                    return clrGray;
    }
}

//+------------------------------------------------------------------+
//| Ottieni Nome Tipo Ordine (per tooltip/label)                      |
//+------------------------------------------------------------------+
string GetOrderTypeName(ENUM_ORDER_TYPE orderType) {
    switch(orderType) {
        case ORDER_TYPE_BUY_STOP:   return "BUY STOP";
        case ORDER_TYPE_BUY_LIMIT:  return "BUY LIMIT";
        case ORDER_TYPE_SELL_LIMIT: return "SELL LIMIT";
        case ORDER_TYPE_SELL_STOP:  return "SELL STOP";
        default:                    return "UNKNOWN";
    }
}

//+------------------------------------------------------------------+
//| Calcola Offset Pixel per Tipo Ordine                              |
//| BUY = verso il basso (-), SELL = verso l'alto (+)                 |
//+------------------------------------------------------------------+
int GetPixelOffset(ENUM_ORDER_TYPE orderType) {
    switch(orderType) {
        case ORDER_TYPE_BUY_STOP:
        case ORDER_TYPE_BUY_LIMIT:
            return -GridLine_PixelOffset;  // BUY verso il basso
            
        case ORDER_TYPE_SELL_LIMIT:
        case ORDER_TYPE_SELL_STOP:
            return +GridLine_PixelOffset;  // SELL verso l'alto
            
        default:
            return 0;
    }
}

//+------------------------------------------------------------------+
//| Genera Nome Univoco per Linea Grid                                |
//+------------------------------------------------------------------+
string GetGridLineName(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    string sideName = (side == GRID_A) ? "A" : "B";
    string zoneName = (zone == ZONE_UPPER) ? "UP" : "DN";
    return GRID_LINE_PREFIX + sideName + "_" + zoneName + "_L" + IntegerToString(level);
}

//+------------------------------------------------------------------+
//| Genera Nome per Label Grid                                        |
//+------------------------------------------------------------------+
string GetGridLabelName(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    return GRID_LABEL_PREFIX + GetGridLineName(side, zone, level);
}

//+------------------------------------------------------------------+
//| Disegna Singola Linea Grid                                        |
//+------------------------------------------------------------------+
void DrawSingleGridLine(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level,
                        double realPrice, ENUM_ORDER_STATUS status) {
    
    if(!ShowGridLines) return;
    if(realPrice <= 0) return;
    
    // Determina tipo ordine
    ENUM_ORDER_TYPE orderType = GetGridOrderType(side, zone);
    
    // Calcola prezzo visivo con offset pixel
    int pixelOffset = GetPixelOffset(orderType);
    double priceOffset = PixelsToPrice(pixelOffset);
    double visualPrice = realPrice + priceOffset;
    
    // Ottieni colore
    color lineColor = GetGridLineColor(orderType);
    
    // Determina stile (se opzione attiva, FILLED = tratteggiata)
    ENUM_LINE_STYLE lineStyle = STYLE_SOLID;
    if(GridLine_DifferentStyleFilled && status == ORDER_FILLED) {
        lineStyle = STYLE_DASH;
    }
    
    // Nome linea
    string lineName = GetGridLineName(side, zone, level);
    
    // Crea o aggiorna linea
    if(ObjectFind(0, lineName) < 0) {
        if(!ObjectCreate(0, lineName, OBJ_HLINE, 0, 0, visualPrice)) {
            if(DetailedLogging) {
                PrintFormat("[GridVisual] ERRORE creazione linea %s", lineName);
            }
            return;
        }
        g_totalGridLinesDrawn++;
    }
    
    // Imposta proprietà linea
    ObjectSetDouble(0, lineName, OBJPROP_PRICE, visualPrice);
    ObjectSetInteger(0, lineName, OBJPROP_COLOR, lineColor);
    ObjectSetInteger(0, lineName, OBJPROP_WIDTH, GridLine_Width);
    ObjectSetInteger(0, lineName, OBJPROP_STYLE, lineStyle);
    ObjectSetInteger(0, lineName, OBJPROP_BACK, false);  // In primo piano
    ObjectSetInteger(0, lineName, OBJPROP_SELECTABLE, false);
    ObjectSetInteger(0, lineName, OBJPROP_HIDDEN, true);  // Nascondi dalla lista oggetti
    
    // Tooltip con informazioni dettagliate
    if(GridLine_ShowTooltip) {
        string tooltip = GetOrderTypeName(orderType);
        tooltip += " | Grid " + (side == GRID_A ? "A" : "B");
        tooltip += " | L" + IntegerToString(level + 1);
        tooltip += " | @ " + DoubleToString(realPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
        tooltip += " | " + EnumToString(status);
        ObjectSetString(0, lineName, OBJPROP_TOOLTIP, tooltip);
    }
    
    // Label opzionale
    if(GridLine_ShowLabels) {
        DrawGridLabel(side, zone, level, realPrice, orderType);
    }
}

//+------------------------------------------------------------------+
//| Disegna Label per Grid Line                                       |
//+------------------------------------------------------------------+
void DrawGridLabel(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level,
                   double price, ENUM_ORDER_TYPE orderType) {
    
    string labelName = GetGridLabelName(side, zone, level);
    string labelText = (side == GRID_A ? "A" : "B") + IntegerToString(level + 1);
    
    // Posiziona label sul lato destro del chart
    datetime labelTime = TimeCurrent() + PeriodSeconds(PERIOD_CURRENT) * 5;
    
    if(ObjectFind(0, labelName) < 0) {
        ObjectCreate(0, labelName, OBJ_TEXT, 0, labelTime, price);
    }
    
    ObjectSetDouble(0, labelName, OBJPROP_PRICE, price);
    ObjectSetInteger(0, labelName, OBJPROP_TIME, labelTime);
    ObjectSetString(0, labelName, OBJPROP_TEXT, labelText);
    ObjectSetInteger(0, labelName, OBJPROP_COLOR, GetGridLineColor(orderType));
    ObjectSetInteger(0, labelName, OBJPROP_FONTSIZE, 8);
    ObjectSetInteger(0, labelName, OBJPROP_ANCHOR, ANCHOR_LEFT);
    ObjectSetInteger(0, labelName, OBJPROP_HIDDEN, true);
}

//+------------------------------------------------------------------+
//| Disegna Linea Entry Point                                         |
//+------------------------------------------------------------------+
void DrawEntryLine(double entryPrice) {
    if(!ShowEntryLine) return;
    if(entryPrice <= 0) return;
    
    if(ObjectFind(0, ENTRY_LINE_NAME) < 0) {
        ObjectCreate(0, ENTRY_LINE_NAME, OBJ_HLINE, 0, 0, entryPrice);
    }
    
    ObjectSetDouble(0, ENTRY_LINE_NAME, OBJPROP_PRICE, entryPrice);
    ObjectSetInteger(0, ENTRY_LINE_NAME, OBJPROP_COLOR, Color_EntryLine);
    ObjectSetInteger(0, ENTRY_LINE_NAME, OBJPROP_WIDTH, EntryLine_Width);
    ObjectSetInteger(0, ENTRY_LINE_NAME, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, ENTRY_LINE_NAME, OBJPROP_BACK, false);
    ObjectSetInteger(0, ENTRY_LINE_NAME, OBJPROP_SELECTABLE, false);
    
    if(GridLine_ShowTooltip) {
        string tooltip = "ENTRY POINT @ " + DoubleToString(entryPrice, (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS));
        ObjectSetString(0, ENTRY_LINE_NAME, OBJPROP_TOOLTIP, tooltip);
    }
}

//+------------------------------------------------------------------+
//| Rimuovi Singola Linea Grid                                        |
//+------------------------------------------------------------------+
void RemoveSingleGridLine(ENUM_GRID_SIDE side, ENUM_GRID_ZONE zone, int level) {
    string lineName = GetGridLineName(side, zone, level);
    string labelName = GetGridLabelName(side, zone, level);
    
    if(ObjectFind(0, lineName) >= 0) {
        ObjectDelete(0, lineName);
        g_totalGridLinesDrawn--;
    }
    
    if(ObjectFind(0, labelName) >= 0) {
        ObjectDelete(0, labelName);
    }
}

//+------------------------------------------------------------------+
//| Rimuovi Linea Entry Point                                         |
//+------------------------------------------------------------------+
void RemoveEntryLine() {
    if(ObjectFind(0, ENTRY_LINE_NAME) >= 0) {
        ObjectDelete(0, ENTRY_LINE_NAME);
    }
}

//+------------------------------------------------------------------+
//| Rimuovi Tutte le Linee Grid                                       |
//+------------------------------------------------------------------+
void RemoveAllGridLines() {
    // Rimuovi tutte le linee con prefisso SUGAMARA_GRID_
    int totalObjects = ObjectsTotal(0);
    
    for(int i = totalObjects - 1; i >= 0; i--) {
        string objName = ObjectName(0, i);
        
        if(StringFind(objName, GRID_LINE_PREFIX) >= 0 ||
           StringFind(objName, GRID_LABEL_PREFIX) >= 0) {
            ObjectDelete(0, objName);
        }
    }
    
    // Rimuovi entry line
    RemoveEntryLine();
    
    g_totalGridLinesDrawn = 0;
    
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Aggiorna Tutte le Linee Grid (chiamare da OnTick o OnTimer)       |
//| Ricalcola offset pixel quando l'utente fa zoom                    |
//+------------------------------------------------------------------+
void UpdateAllGridLines() {
    if(!ShowGridLines) return;
    if(!g_gridLinesInitialized) return;
    
    // Aggiorna Entry Line
    if(entryPoint > 0) {
        DrawEntryLine(entryPoint);
    }
    
    // Aggiorna Grid A Upper (BUY STOP)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Upper_EntryPrices[i] > 0) {
            DrawSingleGridLine(GRID_A, ZONE_UPPER, i, 
                              gridA_Upper_EntryPrices[i], 
                              gridA_Upper_Status[i]);
        }
    }
    
    // Aggiorna Grid A Lower (BUY LIMIT)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridA_Lower_EntryPrices[i] > 0) {
            DrawSingleGridLine(GRID_A, ZONE_LOWER, i,
                              gridA_Lower_EntryPrices[i],
                              gridA_Lower_Status[i]);
        }
    }
    
    // Aggiorna Grid B Upper (SELL LIMIT)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Upper_EntryPrices[i] > 0) {
            DrawSingleGridLine(GRID_B, ZONE_UPPER, i,
                              gridB_Upper_EntryPrices[i],
                              gridB_Upper_Status[i]);
        }
    }
    
    // Aggiorna Grid B Lower (SELL STOP)
    for(int i = 0; i < GridLevelsPerSide; i++) {
        if(gridB_Lower_EntryPrices[i] > 0) {
            DrawSingleGridLine(GRID_B, ZONE_LOWER, i,
                              gridB_Lower_EntryPrices[i],
                              gridB_Lower_Status[i]);
        }
    }
    
    ChartRedraw(0);
}

//+------------------------------------------------------------------+
//| Disegna Tutte le Linee Grid (chiamare dopo inizializzazione)      |
//+------------------------------------------------------------------+
void DrawAllGridLines() {
    if(!ShowGridLines) {
        if(DetailedLogging) {
            Print("[GridVisual] ShowGridLines = false, skip drawing");
        }
        return;
    }
    
    // Prima rimuovi eventuali linee vecchie
    RemoveAllGridLines();
    
    // Poi disegna tutte le nuove
    UpdateAllGridLines();
    
    if(DetailedLogging) {
        PrintFormat("[GridVisual] Disegnate %d linee grid", g_totalGridLinesDrawn);
    }
}

//+------------------------------------------------------------------+
//| Gestione Evento Chart (zoom, scroll)                              |
//| Chiamare da OnChartEvent per aggiornare offset pixel              |
//+------------------------------------------------------------------+
void OnGridVisualChartEvent(const int id) {
    // Aggiorna linee quando cambia lo zoom o la visualizzazione
    if(id == CHARTEVENT_CHART_CHANGE) {
        if(ShowGridLines && g_gridLinesInitialized) {
            UpdateAllGridLines();
        }
    }
}

//+------------------------------------------------------------------+
//| Log Configurazione Grid Visual                                    |
//+------------------------------------------------------------------+
void LogGridVisualConfig() {
    Print("═══════════════════════════════════════════════════════════════════");
    Print("  🎨 v9.8 GRID VISUAL CONFIGURATION");
    Print("═══════════════════════════════════════════════════════════════════");
    PrintFormat("  Show Grid Lines: %s", ShowGridLines ? "ON" : "OFF");
    PrintFormat("  Show Entry Line: %s", ShowEntryLine ? "ON" : "OFF");
    PrintFormat("  Line Width: %d px", GridLine_Width);
    PrintFormat("  Pixel Offset: %d px (BUY giù, SELL su)", GridLine_PixelOffset);
    Print("");
    Print("  Colori:");
    PrintFormat("    BUY STOP:   RGB(%d,%d,%d)", 
                (Color_BuyStop >> 0) & 0xFF,
                (Color_BuyStop >> 8) & 0xFF, 
                (Color_BuyStop >> 16) & 0xFF);
    PrintFormat("    BUY LIMIT:  RGB(%d,%d,%d)",
                (Color_BuyLimit >> 0) & 0xFF,
                (Color_BuyLimit >> 8) & 0xFF,
                (Color_BuyLimit >> 16) & 0xFF);
    PrintFormat("    SELL LIMIT: RGB(%d,%d,%d)",
                (Color_SellLimit >> 0) & 0xFF,
                (Color_SellLimit >> 8) & 0xFF,
                (Color_SellLimit >> 16) & 0xFF);
    PrintFormat("    SELL STOP:  RGB(%d,%d,%d)",
                (Color_SellStop >> 0) & 0xFF,
                (Color_SellStop >> 8) & 0xFF,
                (Color_SellStop >> 16) & 0xFF);
    Print("═══════════════════════════════════════════════════════════════════");
}

//+------------------------------------------------------------------+
//| Get Grid Visual Statistics (per Dashboard)                        |
//+------------------------------------------------------------------+
string GetGridVisualStats() {
    if(!ShowGridLines) return "OFF";
    return IntegerToString(g_totalGridLinesDrawn) + " lines";
}

//+------------------------------------------------------------------+
```

---

### 4️⃣ Sugamara.mq5

#### A) Aggiungere include del nuovo file

**POSIZIONE**: Dopo gli altri include Utils (circa riga 58)

```cpp
// Utility Modules
#include "Utils/Helpers.mqh"
#include "Utils/GridHelpers.mqh"
#include "Utils/ATRCalculator.mqh"
#include "Utils/GridVisual.mqh"        // 🆕 v9.8 Grid Visual System
```

#### B) In OnInit() - Inizializzare Grid Visual

**POSIZIONE**: Dopo `InitializeArrays();` (circa riga 181)

```cpp
    //--- v9.8: Initialize Grid Visual System ---
    InitGridVisual();
    LogGridVisualConfig();
```

#### C) In OnInit() - Disegnare linee dopo creazione grid

**POSIZIONE**: Dopo `PlaceAllGridBOrders();` (circa riga 220, dopo che tutte le grid sono piazzate)

```cpp
    //--- v9.8: Draw all grid lines ---
    DrawAllGridLines();
```

#### D) In OnDeinit() - Pulizia linee

**POSIZIONE**: All'inizio di `OnDeinit()` 

```cpp
void OnDeinit(const int reason) {
    //--- v9.8: Remove grid visual lines ---
    DeinitGridVisual();
    
    // ... resto del codice esistente ...
}
```

#### E) In OnTick() - Aggiornamento periodico (opzionale)

**POSIZIONE**: Alla fine di `OnTick()`, prima della chiusura funzione

```cpp
    //--- v9.8: Update grid lines (per cambio status) ---
    // Nota: Chiamare solo se necessario, non ad ogni tick per performance
    static datetime lastVisualUpdate = 0;
    if(TimeCurrent() - lastVisualUpdate >= 1) {  // Aggiorna ogni 1 secondo
        UpdateAllGridLines();
        lastVisualUpdate = TimeCurrent();
    }
```

#### F) In OnChartEvent() - Gestione zoom/scroll

**POSIZIONE**: Dentro `OnChartEvent()`, all'inizio

```cpp
void OnChartEvent(const int id, const long& lparam, const double& dparam, const string& sparam) {
    
    //--- v9.8: Handle chart zoom/scroll for grid lines ---
    OnGridVisualChartEvent(id);
    
    // ... resto del codice esistente ...
}
```

---

### 5️⃣ Aggiornamento dopo Cyclic Reopen

**FILE**: `Trading/GridASystem.mqh` e `Trading/GridBSystem.mqh`

Dopo ogni `PlaceGridAUpperOrder()`, `PlaceGridALowerOrder()`, ecc., aggiornare la linea:

```cpp
// Esempio in GridASystem.mqh, funzione ReopenGridA_Upper():
if(PlaceGridAUpperOrder(level)) {
    // ... codice esistente ...
    
    // 🆕 v9.8: Aggiorna linea visiva
    DrawSingleGridLine(GRID_A, ZONE_UPPER, level, 
                      gridA_Upper_EntryPrices[level], 
                      gridA_Upper_Status[level]);
}
```

---

## 📊 RISULTATO VISIVO ATTESO

```
UPPER ZONE (+50 pips - stesso prezzo reale):

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  SELL LIMIT (Coral) ← +1 pixel
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  BUY STOP (Lime)    ← -1 pixel
    
    Distanza visiva: 2 pixel


ENTRY POINT (0 pips):

    ═══════════════════════════════════════════════════  ENTRY (Gold, 3px)


LOWER ZONE (-50 pips - stesso prezzo reale):

    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  SELL STOP (Crimson) ← +1 pixel
    ━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━  BUY LIMIT (SeaGreen) ← -1 pixel
```

---

## 🎨 LEGENDA COLORI DEFAULT

| Tipo Ordine | Colore | Posizione |
|-------------|--------|-----------|
| BUY STOP | 🟢 Lime (Verde brillante) | Grid A Upper, -1px |
| BUY LIMIT | 🟢 SeaGreen (Verde scuro) | Grid A Lower, -1px |
| SELL LIMIT | 🟠 Coral (Arancio) | Grid B Upper, +1px |
| SELL STOP | 🔴 Crimson (Rosso scuro) | Grid B Lower, +1px |
| ENTRY | 🟡 Gold (Oro) | Centro, no offset |

---

## ✅ CHECKLIST VERIFICA

Dopo l'implementazione, verificare:

- [ ] File `GridVisual.mqh` creato correttamente
- [ ] Include aggiunto in `Sugamara.mq5`
- [ ] Input parameters visibili nel pannello MT5
- [ ] Linee grid visibili sul chart
- [ ] 4 colori diversi distinguibili
- [ ] BUY sotto, SELL sopra (offset pixel)
- [ ] Entry line in oro visibile
- [ ] Tooltip funzionante al passaggio mouse
- [ ] Linee si aggiornano con zoom/scroll
- [ ] Linee rimosse correttamente a chiusura EA

---

## 🔧 PERSONALIZZAZIONE COLORI

L'utente può cambiare i colori direttamente dal pannello Input Parameters:

1. Aprire proprietà EA (tasto destro → Properties)
2. Tab "Inputs"
3. Sezione "🎨 GRID LINES VISUAL v9.8"
4. Cliccare sul colore da cambiare
5. Scegliere nuovo colore dal picker

---

## 📝 NOTE TECNICHE

### Calcolo Dinamico Pixel → Prezzo

La funzione `PixelsToPrice()` calcola l'offset in base allo zoom corrente:
- Zoom alto (candele grandi): 1 pixel = pochi pips
- Zoom basso (candele piccole): 1 pixel = più pips

Questo garantisce che la separazione visiva sia **sempre di 2 pixel** indipendentemente dallo zoom.

### Performance

- Le linee vengono aggiornate ogni 1 secondo (non ad ogni tick)
- L'evento `CHARTEVENT_CHART_CHANGE` gestisce zoom/scroll
- Gli oggetti sono nascosti dalla lista oggetti (`OBJPROP_HIDDEN`)

### Compatibilità

- Funziona con MT5 (non MT4)
- Compatibile con tutti i timeframe
- Non interferisce con altri indicatori

---

Documento creato: Gennaio 2026
Versione target: 9.8.0
