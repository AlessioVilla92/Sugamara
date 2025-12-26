//+------------------------------------------------------------------+
//| DUAL PARCELLING INPUT PARAMETERS                                 |
//| Da aggiungere a InputParameters.mqh dopo la sezione BOP          |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| 🎯 DUAL PARCELLING v5.2                                          |
//+------------------------------------------------------------------+

input group "                                                           "
input group "╔═══════════════════════════════════════════════════════════╗"
input group "║  🎯 DUAL PARCELLING (v5.2)                                ║"
input group "║      Split ogni ordine in 2 parcels con TP diversi       ║"
input group "╚═══════════════════════════════════════════════════════════╝"

input group "    ⚡ ATTIVAZIONE"
input bool      Enable_DualParcelling = false;          // ✅ Abilita Dual Parcelling
// NOTA: Quando attivo, usa lot multipli di 2 (es: 0.02, 0.04, 0.06)
// NOTA: Disabilita automaticamente BOP (Break On Profit) - logica integrata

input group "    📊 PARCEL A (TP CORTO - Prima metà)"
input int       ParcelA_TP_Levels = 1;                  // 🎯 TP = Entry + N livelli grid
// 1 = TP al livello successivo (es: L1 → L2)
input double    ParcelA_SL_ToBE_Pct = 50.0;             // 📊 SL→BE: % progress verso TP1
// Quando raggiunge 50% del percorso verso TP1, sposta SL a Entry
input double    ParcelA_BE_Trigger_Pct = 70.0;          // 📊 BE Confirm: % progress
// A 70% conferma il BE (non usato per Parcel A, solo per log)

input group "    📊 PARCEL B (TP LUNGO - Seconda metà)"  
input int       ParcelB_TP_Levels = 2;                  // 🎯 TP = Entry + N livelli grid
// 2 = TP due livelli più avanti (es: L1 → L3)
input double    ParcelB_SL_ToBE_Pct = 100.0;            // 📊 SL→BE: % progress verso TP1
// 100% = quando Parcel A chiude (raggiunge TP1)
input double    ParcelB_BE_Trigger_Pct = 150.0;         // 📊 BE Confirm: % progress
// 150% = 1.5× la distanza verso TP1 (a metà strada verso TP2)

input group "    💰 LOT SPLIT SETTINGS"
input bool      DualParcel_ForcePairLot = true;         // ✅ Forza lot divisibile per 2
// Se true, arrotonda BaseLot al multiplo di 0.02 più vicino
input double    DualParcel_LotRatio = 0.5;              // 📊 Ratio split Parcel A
// 0.5 = 50%/50% (ParcelA: 0.01, ParcelB: 0.01 se BaseLot=0.02)
// 0.6 = 60%/40% (ParcelA: 0.012, ParcelB: 0.008 se BaseLot=0.02)
// 0.4 = 40%/60% (ParcelA: 0.008, ParcelB: 0.012 se BaseLot=0.02)

