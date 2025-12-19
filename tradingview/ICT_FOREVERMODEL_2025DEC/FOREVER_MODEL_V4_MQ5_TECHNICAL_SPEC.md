# Forever Model v4.0 - MetaTrader 5 (MQ5) Technical Specification

## Document Information
- **Version:** 1.0
- **Date:** January 2025
- **Base System:** Forever Model v4.0 Strategy (Pine Script)
- **Target Platform:** MetaTrader 5 (MQL5)
- **Document Type:** Technical Specification for MQ5 Development

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [System Architecture](#2-system-architecture)
3. [Data Structures](#3-data-structures)
4. [Core Algorithms](#4-core-algorithms)
5. [Trading Logic](#5-trading-logic)
6. [Risk Management](#6-risk-management)
7. [Visual Elements](#7-visual-elements)
8. [Configuration Parameters](#8-configuration-parameters)
9. [MQ5 Implementation Guidelines](#9-mq5-implementation-guidelines)
10. [Testing Requirements](#10-testing-requirements)

---

## 1. Executive Summary

### 1.1 Overview
The Forever Model v4.0 is an automated trading system based on ICT (Inner Circle Trader) concepts that identifies institutional order flow imbalances and executes trades based on Change in State of Delivery (CISD) confirmations. The system supports two execution modes: Werlein Standard (Mode A) and Sniper/Obi Variant (Mode B).

### 1.2 Core Components
1. **HTF FVG Detection** - Identifies Fair Value Gaps on Higher Timeframe
2. **Manipulation Leg Identification** - Tracks liquidity sweeps
3. **iFVG Detection** - Identifies Inverse Fair Value Gaps (chart timeframe)
4. **CISD Confirmation** - Validates trade entry signals
5. **SMT Divergence** - Optional filter for enhanced signal quality
6. **Risk Management** - Dynamic position sizing, stop loss, take profit
7. **Visual Dashboard** - Real-time system status and trade information

### 1.3 Key Features
- Dual execution modes (Werlein Standard / Sniper/Obi Variant)
- HTF context validation
- Signal quality grading (A, A+, A++)
- Session-based filtering
- Dynamic risk management
- Visual confirmation lines and FVG boxes

---

## 2. System Architecture

### 2.1 Class Structure

```
ForeverModelEA (Main Expert Advisor)
├── CHTFManager (Higher Timeframe Data Manager)
├── CFVGDetector (Fair Value Gap Detector)
├── CManipulationTracker (Manipulation Leg Tracker)
├── CiFVGDetector (Inverse FVG Detector)
├── CCISDConfirmation (CISD Confirmation Handler)
├── CSMTDetector (SMT Divergence Detector)
├── CRiskManager (Risk Management)
├── CVisualManager (Chart Drawing Manager)
└── CDashboard (Dashboard Display)
```

### 2.2 Main Processing Flow

```
1. OnInit()
   ├── Initialize all managers
   ├── Load configuration
   └── Set up event handlers

2. OnTick()
   ├── Update HTF data
   ├── Detect new HTF candles
   ├── Detect FVGs
   ├── Track manipulation legs
   ├── Detect iFVGs
   ├── Check CISD confirmations
   ├── Update pending signals
   ├── Execute trades
   ├── Manage open positions
   └── Update visual elements

3. OnTimer()
   ├── Update dashboard
   └── Clean up old visual objects
```

### 2.3 Data Flow

```
HTF Data → FVG Detection → FVG Mitigation → Pivot Formation → 
Manipulation Tracking → iFVG Detection → CISD Confirmation → 
Signal Quality Check → Trade Execution → Position Management
```

---

## 3. Data Structures

### 3.1 FVG Structure

```cpp
struct SFVG
{
    double dRangeHigh;          // FVG top (for bearish) or bottom (for bullish)
    double dRangeLow;           // FVG bottom (for bearish) or top (for bullish)
    datetime dtHighStartTime;   // Time when high extreme was formed
    datetime dtLowStartTime;    // Time when low extreme was formed
    bool bHighMitigated;        // True if high extreme has been mitigated
    bool bLowMitigated;         // True if low extreme has been mitigated
    datetime dtHighMitigationTime;  // Time when high was mitigated
    datetime dtLowMitigationTime;   // Time when low was mitigated
    bool bIsSpecial;            // True if special range (one extreme only)
    int iCreationBar;           // Bar index where FVG was created
    bool bCanCreateSignalFromHigh;  // True if high mitigation creates signal
    bool bCanCreateSignalFromLow;   // True if low mitigation creates signal
    bool bIsOIBased;            // True if created from OI pivot
    bool bIsSignalBased;       // True if created from signal stop
    int iHTFCandleAtCreation;  // HTF candle count at creation (for decay)
    int iLastRetestBar;        // Bar index of last retest (for decay pause)
    double dCurrentDecayLevel; // 0.0 = no decay, 1.0 = fully decayed
};
```

### 3.2 Pending Signal Structure

```cpp
struct SPendingSignal
{
    string sSignalType;         // "BEARISH" or "BULLISH"
    double dConfirmationLevel;  // Pivot level that needs to be crossed
    int iCreationBar;           // Bar index where signal was created
    int iPivotBarIndex;         // Bar index where pivot was formed
    double dMaxPrice;           // Max price from creation to confirmation (bearish)
    double dMinPrice;           // Min price from creation to confirmation (bullish)
    double dMitigatedLevel;     // The range level that was mitigated
    double dFVGRangeHigh;       // FVG range high
    double dFVGRangeLow;        // FVG range low
    int iFVGTouchBar;           // Bar index where FVG was initially touched
    
    // v4.0: Manipulation candle tracking
    double dManipulationCandleOpen;   // Open price of manipulation candle
    double dManipulationCandleHigh;   // High of manipulation candle
    double dManipulationCandleLow;    // Low of manipulation candle
    int iManipulationCandleBar;       // Bar index of manipulation candle
    
    // v4.0: Signal quality
    bool bHasViolentRejection;       // True if iFVG created with violent rejection
    bool bLacksDisplacement;         // True if manipulation leg lacks displacement
    bool bHasSMTDivergence;          // True if SMT divergence present
    string sSignalGrade;             // "A", "A+", or "A++"
};
```

### 3.3 iFVG Structure

```cpp
struct SiFVG
{
    datetime dtLeft;            // Left time of the FVG
    double dTop;                // Top of the FVG gap
    datetime dtRight;           // Right time (0 = still extending)
    double dBot;                // Bottom of the FVG gap
    double dMid;                // Midline of the FVG
    int iDir;                   // 1 for bullish iFVG, -1 for bearish iFVG
    int iState;                 // 0 = just inverted, 1 = confirmed
    int iCreationBar;           // Bar index where FVG was created
    int iInversionBar;          // Bar index where FVG was inverted
    bool bMitigated;            // True if fully mitigated (gap filled)
    datetime dtMitigationTime;  // Time when iFVG was mitigated
};
```

### 3.4 ERL Structure

```cpp
struct SERL
{
    double dHighLevel;          // Latest HTF pivot high
    datetime dtHighTime;        // Time when pivot high was formed
    bool bHighMitigated;        // True if pivot high ERL has been mitigated
    datetime dtHighMitigationTime;  // Time when pivot high was mitigated
    
    double dLowLevel;           // Latest HTF pivot low
    datetime dtLowTime;         // Time when pivot low was formed
    bool bLowMitigated;         // True if pivot low ERL has been mitigated
    datetime dtLowMitigationTime;   // Time when pivot low was mitigated
};
```

### 3.5 SMT Structure

```cpp
struct SSMT
{
    string sSMTType;            // "BEARISH" or "BULLISH"
    string sDetectionMode;      // "HTF" or "PIVOT"
    string sSMTPair;            // SMT pair symbol
    double dPrevChartHigh;      // Previous chart high
    double dCurrChartHigh;      // Current chart high
    datetime dtPrevChartHighTime;
    datetime dtCurrChartHighTime;
    double dPrevChartLow;       // Previous chart low
    double dCurrChartLow;       // Current chart low
    datetime dtPrevChartLowTime;
    datetime dtCurrChartLowTime;
    bool bConfirmed;            // True if confirmed
    int iCreationBar;           // Bar index where SMT was created
};
```

### 3.6 Confirmation Line Structure

```cpp
struct SConfirmationLine
{
    string sSignalType;         // "BEARISH" or "BULLISH"
    double dConfirmationLevel;  // The confirmation level
    datetime dtStartTime;       // Time where line starts
    datetime dtConfirmationTime; // Time when signal was confirmed
    double dStopPrice;          // Stop price for this signal
    double dEntryPrice;         // Entry price for this signal
    double dPositionSize;       // Position size for this signal
    double dFVGRangeHigh;       // FVG range high
    double dFVGRangeLow;        // FVG range low
    int iFVGTouchBar;           // Bar index where FVG was initially touched
    int iPivotBar;              // Bar index where pivot was formed
    vector<SiFVG> vIFVGs;       // Array of inversion FVGs
    string sSignalGrade;        // Signal grade (A, A+, A++)
};
```

---

## 4. Core Algorithms

### 4.1 HTF Period Selection

**Algorithm: Auto HTF Selection**
```
Input: Current chart timeframe (enum PERIOD)
Output: HTF period (enum PERIOD)

Switch (Current Timeframe):
    Case M1:  Return M15 (15x)
    Case M3:  Return M30 (10x)
    Case M5:  Return H1 (12x)
    Case M10: Return M150 (15x)
    Case M15: Return H4 (16x)
    Case M30: Return D1 (48x)
    Case H1:  Return D1 (24x)
    Case H2:  Return D2 (24x)
    Case H4:  Return W1 (42x)
    Case D1:  Return W2 (15x)
    Case W1:  Return MN1 (4x)
    Default:  Return D1
```

**MQ5 Implementation:**
```cpp
ENUM_TIMEFRAMES GetHTFPeriod(ENUM_TIMEFRAMES currentTF)
{
    switch(currentTF)
    {
        case PERIOD_M1:  return PERIOD_M15;
        case PERIOD_M3:  return PERIOD_M30;
        case PERIOD_M5:  return PERIOD_H1;
        case PERIOD_M10: return PERIOD_MN1; // M150 not available, use closest
        case PERIOD_M15: return PERIOD_H4;
        case PERIOD_M30: return PERIOD_D1;
        case PERIOD_H1:  return PERIOD_D1;
        case PERIOD_H2:  return PERIOD_D1;  // D2 not available
        case PERIOD_H4:  return PERIOD_W1;
        case PERIOD_D1:  return PERIOD_W1;  // W2 not available
        case PERIOD_W1:  return PERIOD_MN1;
        default: return PERIOD_D1;
    }
}
```

### 4.2 HTF FVG Detection

**Algorithm: HTF FVG Detection**
```
Input: HTF OHLC data (array)
Output: FVG structure or NULL

Function DetectHTFFVG(htfHigh[], htfLow[], htfTime[]):
    // Bearish FVG: HTF[0] high < HTF[2] low
    if (htfHigh[0] < htfLow[2]):
        fvg = new SFVG()
        fvg.dRangeHigh = htfHigh[0]  // Bottom of FVG
        fvg.dRangeLow = htfLow[2]    // Top of FVG
        fvg.dtHighStartTime = htfTime[0]
        fvg.dtLowStartTime = htfTime[2]
        fvg.bCanCreateSignalFromHigh = true
        fvg.bCanCreateSignalFromLow = false
        return fvg
    
    // Bullish FVG: HTF[0] low > HTF[2] high
    if (htfLow[0] > htfHigh[2]):
        fvg = new SFVG()
        fvg.dRangeHigh = htfHigh[2]  // Bottom of FVG
        fvg.dRangeLow = htfLow[0]   // Top of FVG
        fvg.dtHighStartTime = htfTime[2]
        fvg.dtLowStartTime = htfTime[0]
        fvg.bCanCreateSignalFromHigh = false
        fvg.bCanCreateSignalFromLow = true
        return fvg
    
    return NULL
```

**MQ5 Implementation:**
```cpp
bool DetectHTFFVG(double htfHigh[], double htfLow[], datetime htfTime[], 
                   SFVG &fvg, bool &bIsBullish)
{
    // Bearish FVG: HTF[0] high < HTF[2] low
    if(htfHigh[0] < htfLow[2])
    {
        fvg.dRangeHigh = htfHigh[0];
        fvg.dRangeLow = htfLow[2];
        fvg.dtHighStartTime = htfTime[0];
        fvg.dtLowStartTime = htfTime[2];
        fvg.bCanCreateSignalFromHigh = true;
        fvg.bCanCreateSignalFromLow = false;
        bIsBullish = false;
        return true;
    }
    
    // Bullish FVG: HTF[0] low > HTF[2] high
    if(htfLow[0] > htfHigh[2])
    {
        fvg.dRangeHigh = htfHigh[2];
        fvg.dRangeLow = htfLow[0];
        fvg.dtHighStartTime = htfTime[2];
        fvg.dtLowStartTime = htfTime[0];
        fvg.bCanCreateSignalFromHigh = false;
        fvg.bCanCreateSignalFromLow = true;
        bIsBullish = true;
        return true;
    }
    
    return false;
}
```

### 4.3 Pivot Detection

**Algorithm: Pivot Detection (Chart Timeframe)**
```
Input: Current and previous candle OHLC
Output: Pivot high/low and bar index

Function DetectPivot():
    bool bIsBullish = (Close > Open)
    bool bWasBullish = (Close[1] > Open[1])
    
    // Bullish candle after bearish → new pivot low
    if (bIsBullish && !bWasBullish):
        pivotLow = min(Low, Low[1])
        pivotLowBar = (Low < Low[1]) ? bar_index : bar_index - 1
        return (NULL, pivotLow, pivotLowBar)
    
    // Bearish candle after bullish → new pivot high
    if (!bIsBullish && bWasBullish):
        pivotHigh = max(High, High[1])
        pivotHighBar = (High > High[1]) ? bar_index : bar_index - 1
        return (pivotHigh, NULL, pivotHighBar)
    
    return (NULL, NULL, -1)
```

**MQ5 Implementation:**
```cpp
bool DetectPivot(double &dPivotHigh, double &dPivotLow, int &iPivotBar)
{
    double dClose0 = iClose(_Symbol, PERIOD_CURRENT, 0);
    double dOpen0 = iOpen(_Symbol, PERIOD_CURRENT, 0);
    double dClose1 = iClose(_Symbol, PERIOD_CURRENT, 1);
    double dOpen1 = iOpen(_Symbol, PERIOD_CURRENT, 1);
    
    bool bIsBullish = (dClose0 > dOpen0);
    bool bWasBullish = (dClose1 > dOpen1);
    
    dPivotHigh = 0;
    dPivotLow = 0;
    iPivotBar = -1;
    
    // Bullish candle after bearish → new pivot low
    if(bIsBullish && !bWasBullish)
    {
        double dLow0 = iLow(_Symbol, PERIOD_CURRENT, 0);
        double dLow1 = iLow(_Symbol, PERIOD_CURRENT, 1);
        dPivotLow = MathMin(dLow0, dLow1);
        iPivotBar = (dLow0 < dLow1) ? 0 : 1;
        return true;
    }
    
    // Bearish candle after bullish → new pivot high
    if(!bIsBullish && bWasBullish)
    {
        double dHigh0 = iHigh(_Symbol, PERIOD_CURRENT, 0);
        double dHigh1 = iHigh(_Symbol, PERIOD_CURRENT, 1);
        dPivotHigh = MathMax(dHigh0, dHigh1);
        iPivotBar = (dHigh0 > dHigh1) ? 0 : 1;
        return true;
    }
    
    return false;
}
```

### 4.4 FVG Mitigation Check

**Algorithm: FVG Mitigation**
```
Input: FVG structure, current price data
Output: Updated FVG structure with mitigation flags

Function CheckFVGMitigation(fvg, currentHigh, currentLow):
    bool bIsBearishFVG = fvg.bCanCreateSignalFromHigh
    bool bIsBullishFVG = fvg.bCanCreateSignalFromLow
    
    // Check high mitigation
    if (!fvg.bHighMitigated && fvg.dRangeHigh != 0):
        if (bIsBullishFVG):
            // Bullish FVG: bottom (rangeHigh) mitigated when price goes BELOW
            if (currentLow <= fvg.dRangeHigh):
                fvg.bHighMitigated = true
                fvg.dtHighMitigationTime = currentTime
        else:
            // Bearish FVG or standard: high mitigated when price goes ABOVE
            if (currentHigh >= fvg.dRangeHigh):
                fvg.bHighMitigated = true
                fvg.dtHighMitigationTime = currentTime
    
    // Check low mitigation
    if (!fvg.bLowMitigated && fvg.dRangeLow != 0):
        if (bIsBearishFVG):
            // Bearish FVG: top (rangeLow) mitigated when price goes ABOVE
            if (currentHigh >= fvg.dRangeLow):
                fvg.bLowMitigated = true
                fvg.dtLowMitigationTime = currentTime
        else:
            // Bullish FVG or standard: low mitigated when price goes BELOW
            if (currentLow <= fvg.dRangeLow):
                fvg.bLowMitigated = true
                fvg.dtLowMitigationTime = currentTime
```

### 4.5 Manipulation Candle Identification

**Algorithm: Manipulation Candle Detection**
```
Input: FVG creation bar, current bar, price data
Output: Manipulation candle data (open, high, low, bar index)

Function IdentifyManipulationCandle(fvgCreationBar, currentBar, signalType):
    double dManipulationHigh = 0
    double dManipulationLow = DBL_MAX
    double dManipulationOpen = 0
    int iManipulationBar = currentBar
    
    if (signalType == "BEARISH"):
        // Find candle with highest high since FVG creation
        for (i = fvgCreationBar to currentBar):
            if (High[i] > dManipulationHigh):
                dManipulationHigh = High[i]
                dManipulationLow = Low[i]
                dManipulationOpen = Open[i]
                iManipulationBar = i
    else: // BULLISH
        // Find candle with lowest low since FVG creation
        for (i = fvgCreationBar to currentBar):
            if (Low[i] < dManipulationLow):
                dManipulationHigh = High[i]
                dManipulationLow = Low[i]
                dManipulationOpen = Open[i]
                iManipulationBar = i
    
    return (dManipulationOpen, dManipulationHigh, dManipulationLow, iManipulationBar)
```

### 4.6 iFVG Detection (Chart Timeframe)

**Algorithm: Chart Timeframe FVG Detection**
```
Input: Current and previous candles
Output: FVG structure or NULL

Function DetectChartFVG():
    // Bullish FVG: Low[0] > High[2] and Close[1] > High[2]
    if (Low[0] > High[2] && Close[1] > High[2]):
        fvg = new SiFVG()
        fvg.dBot = High[2]      // Bottom
        fvg.dTop = Low[0]       // Top
        fvg.dMid = (fvg.dBot + fvg.dTop) / 2
        fvg.iDir = 1            // Bullish
        fvg.iState = 0
        fvg.dtLeft = Time[1]
        fvg.dtRight = 0         // Extends until inverted
        return fvg
    
    // Bearish FVG: High[0] < Low[2] and Close[1] < Low[2]
    if (High[0] < Low[2] && Close[1] < Low[2]):
        fvg = new SiFVG()
        fvg.dBot = High[0]      // Bottom
        fvg.dTop = Low[2]       // Top
        fvg.dMid = (fvg.dBot + fvg.dTop) / 2
        fvg.iDir = -1           // Bearish
        fvg.iState = 0
        fvg.dtLeft = Time[1]
        fvg.dtRight = 0         // Extends until inverted
        return fvg
    
    return NULL
```

**Algorithm: iFVG Inversion**
```
Input: FVG structure, current price
Output: Updated FVG structure (inverted)

Function CheckFVGInversion(fvg, currentHigh, currentLow):
    // Bullish FVG becomes bearish iFVG when price breaks below gap bottom
    if (fvg.iDir == 1 && currentLow < fvg.dBot):
        fvg.iInversionBar = currentBar
        fvg.dtRight = currentTime
        fvg.iDir = -1           // Flip direction
        fvg.iState = 1          // Confirmed
        return true
    
    // Bearish FVG becomes bullish iFVG when price breaks above gap top
    if (fvg.iDir == -1 && currentHigh > fvg.dTop):
        fvg.iInversionBar = currentBar
        fvg.dtRight = currentTime
        fvg.iDir = 1            // Flip direction
        fvg.iState = 1          // Confirmed
        return true
    
    return false
```

### 4.7 HTF Context Validation

**Algorithm: HTF POI Check**
```
Input: Active FVGs, ERL levels, current price
Output: Boolean (true if at HTF POI)

Function IsAtHTFPOI():
    // Check if price is inside any active HTF FVG
    for each fvg in activeFVGs:
        if (!fvg.bHighMitigated && !fvg.bLowMitigated):
            double dFVGMin = min(fvg.dRangeHigh, fvg.dRangeLow)
            double dFVGMax = max(fvg.dRangeHigh, fvg.dRangeLow)
            if (currentLow <= dFVGMax && currentHigh >= dFVGMin):
                return true
    
    // Check if price has swept HTF ERL (liquidity)
    if (erlHighLevel != 0 && !erlHighMitigated):
        if (currentHigh >= erlHighLevel):
            return true
    
    if (erlLowLevel != 0 && !erlLowMitigated):
        if (currentLow <= erlLowLevel):
            return true
    
    return false
```

### 4.8 Violent Rejection Validation

**Algorithm: Violent Rejection Check**
```
Input: Pivot bar index, confirmation bar index, price data
Output: Boolean (true if violent rejection detected)

Function HasViolentRejection(iPivotBar, iConfirmationBar):
    if (iConfirmationBar <= iPivotBar):
        return false
    
    int iOffset = iConfirmationBar - iPivotBar
    double dBodySize = abs(Close[iOffset] - Open[iOffset])
    double dATR = iATR(Symbol, Period, 14, iOffset)
    double dBodyATR = (dATR > 0) ? dBodySize / dATR : 0
    
    // Check volume (if available)
    long lVolume = iVolume(Symbol, Period, iOffset)
    long lAvgVolume = 0
    for (i = 1 to 20):
        lAvgVolume += iVolume(Symbol, Period, iOffset + i)
    lAvgVolume /= 20
    double dVolumeRatio = (lAvgVolume > 0) ? (double)lVolume / lAvgVolume : 0
    
    // Violent if: large body (>1.5 ATR) OR high volume (>2x average)
    return (dBodyATR > 1.5 || dVolumeRatio > 2.0)
```

### 4.9 Displacement Check

**Algorithm: Displacement Validation**
```
Input: Manipulation candle bar index
Output: Boolean (true if lacks displacement)

Function LacksDisplacement(iManipulationBar):
    if (iManipulationBar < 0):
        return false
    
    double dCandleBody = abs(Close[iManipulationBar] - Open[iManipulationBar])
    double dCandleWick = 0
    
    if (Close[iManipulationBar] > Open[iManipulationBar]):
        // Bullish candle
        dCandleWick = (High[iManipulationBar] - Close[iManipulationBar]) + 
                      (Open[iManipulationBar] - Low[iManipulationBar])
    else:
        // Bearish candle
        dCandleWick = (High[iManipulationBar] - Open[iManipulationBar]) + 
                      (Close[iManipulationBar] - Low[iManipulationBar])
    
    // Lacks displacement if wick is larger than body (sluggish move)
    return (dCandleWick > dCandleBody)
```

### 4.10 CISD Confirmation

**Algorithm: CISD Confirmation Check**
```
Input: Pending signal, current price
Output: Boolean (true if confirmed)

Function CheckCISDConfirmation(signal):
    if (signal.sSignalType == "BEARISH"):
        // Bearish confirmed when price CLOSES below confirmation level
        if (Close < signal.dConfirmationLevel):
            return true
    else: // BULLISH
        // Bullish confirmed when price CLOSES above confirmation level
        if (Close > signal.dConfirmationLevel):
            return true
    
    return false
```

### 4.11 Entry Price Calculation

**Algorithm: Entry Price Calculation (v4.0)**
```
Input: Execution mode, signal type, iFVG data, manipulation candle data
Output: Entry price

Function CalculateEntryPrice(executionMode, signalType, iFVG, manipulationCandle):
    if (executionMode == "Werlein Standard"):  // Mode A
        if (signalType == "BEARISH"):
            // Entry at iFVG ceiling (top)
            return iFVG.dTop
        else: // BULLISH
            // Entry at iFVG floor (bot)
            return iFVG.dBot
    else: // "Sniper/Obi Variant" - Mode B
        // Entry at manipulation candle open
        return manipulationCandle.dOpen
```

### 4.12 Stop Loss Calculation

**Algorithm: Stop Loss Calculation (v4.0)**
```
Input: Stop loss type, signal type, entry price, signal data
Output: Stop loss price

Function CalculateStopLoss(stopLossType, signalType, entryPrice, signal):
    switch (stopLossType):
        case "Signal-Based":
            // Use max/min price from signal creation to confirmation
            return (signalType == "BEARISH") ? signal.dMaxPrice : signal.dMinPrice
        
        case "Swing-Based":
            // Use HTF ERL levels
            if (signalType == "BEARISH"):
                return (erlHighLevel != 0 && !erlHighMitigated) ? erlHighLevel : signal.dMaxPrice
            else:
                return (erlLowLevel != 0 && !erlLowMitigated) ? erlLowLevel : signal.dMinPrice
        
        case "Manipulation Candle":
            // Use manipulation candle wick
            if (signalType == "BEARISH"):
                return signal.dManipulationCandleHigh
            else:
                return signal.dManipulationCandleLow
        
        case "Fixed Points":
            double dPoints = fixedStopPoints * Point
            return (signalType == "BEARISH") ? entryPrice + dPoints : entryPrice - dPoints
        
        case "Fixed Percent":
            double dPercent = fixedStopPercent / 100.0
            return (signalType == "BEARISH") ? entryPrice * (1 + dPercent) : entryPrice * (1 - dPercent)
        
        case "ATR-Based":
            double dATR = iATR(Symbol, Period, atrStopLength, 0)
            double dStopDistance = dATR * atrStopMultiplier
            return (signalType == "BEARISH") ? entryPrice + dStopDistance : entryPrice - dStopDistance
```

### 4.13 Position Size Calculation

**Algorithm: Position Size Calculation**
```
Input: Entry price, stop price, risk amount, position size type
Output: Position size (lots/contracts)

Function CalculatePositionSize(entryPrice, stopPrice, riskAmount, sizeType):
    double dRiskPerUnit = abs(entryPrice - stopPrice)
    
    if (dRiskPerUnit == 0):
        return 0
    
    switch (sizeType):
        case "Percent of Equity":
            double dEquity = AccountInfoDouble(ACCOUNT_EQUITY)
            double dPositionValue = dEquity * positionSizeValue / 100.0
            return dPositionValue / entryPrice
        
        case "Fixed Contracts":
            return positionSizeValue
        
        case "Fixed USD":
            return positionSizeValue / entryPrice
        
        case "Risk-Based":
            double dRiskUSD = dEquity * positionSizeValue / 100.0
            double dRawSize = dRiskUSD / dRiskPerUnit
            // Adjust for contract size
            return AdjustForContractSize(dRawSize)
    
    return 0
```

### 4.14 SMT Divergence Detection

**Algorithm: SMT Detection (HTF Mode)**
```
Input: Chart HTF data, SMT pair HTF data
Output: SMT structure or NULL

Function DetectSMTDivergenceHTF():
    bool bBearishHTF = (htfClose < htfOpen)
    bool bBullishHTF = (htfClose > htfOpen)
    
    // Bearish divergence: Chart makes HH but SMT doesn't
    bool bBearDiv = bBearishHTF && 
                    (htfHigh < htfHigh[1]) && 
                    (smtHtfHigh > smtHtfHigh[1])
    
    // Bullish divergence: Chart makes LL but SMT doesn't
    bool bBullDiv = bBullishHTF && 
                    (htfLow > htfLow[1]) && 
                    (smtHtfLow < smtHtfLow[1])
    
    if (bBearDiv):
        smt = new SSMT()
        smt.sSMTType = "BEARISH"
        smt.sDetectionMode = "HTF"
        smt.dPrevChartHigh = htfHigh[1]
        smt.dCurrChartHigh = htfHigh
        smt.bConfirmed = true
        return smt
    
    if (bBullDiv):
        smt = new SSMT()
        smt.sSMTType = "BULLISH"
        smt.sDetectionMode = "HTF"
        smt.dPrevChartLow = htfLow[1]
        smt.dCurrChartLow = htfLow
        smt.bConfirmed = true
        return smt
    
    return NULL
```

---

## 5. Trading Logic

### 5.1 Signal Creation Flow

```
1. HTF FVG Detection
   ├── Check for new HTF candle
   ├── Detect FVG pattern (3-candle)
   ├── Validate HTF context (if required)
   └── Create FVG structure

2. FVG Mitigation
   ├── Check if price interacts with FVG extreme
   ├── Mark extreme as mitigated
   └── Check if signal can be created

3. Pivot Formation
   ├── Detect pivot high/low
   └── Store pivot level and bar index

4. Signal Creation
   ├── Identify manipulation candle
   ├── Track manipulation candle data
   ├── Set confirmation level (pivot)
   ├── Initialize quality flags
   └── Create pending signal structure
```

### 5.2 CISD Confirmation Flow

```
1. Check Pending Signal
   ├── Verify signal still valid
   ├── Check if FVG still exists
   └── Update max/min price tracking

2. CISD Validation
   ├── Check if price closes beyond confirmation level
   ├── Validate session filter (if enabled)
   ├── Check SMT requirement (if enabled)
   ├── Validate violent rejection (if required)
   ├── Validate displacement (if required)
   └── Check HTF context (if required)

3. Signal Quality Assessment
   ├── Check for violent rejection
   ├── Check for displacement
   ├── Check for SMT divergence
   └── Assign signal grade (A, A+, A++)

4. Entry Price Calculation
   ├── Determine execution mode
   ├── Mode A: Find iFVG floor/ceiling
   ├── Mode B: Use manipulation candle open
   └── Store entry price

5. Stop Loss Calculation
   ├── Determine stop loss type
   ├── Calculate based on type
   └── Store stop price

6. Position Size Calculation
   ├── Calculate risk per unit
   ├── Determine position size type
   ├── Calculate raw size
   └── Adjust for contract size

7. Create Confirmation Line
   ├── Draw confirmation line
   ├── Create label with signal grade
   └── Store in confirmation lines array
```

### 5.3 Trade Execution Flow

```
1. Entry Condition Check
   ├── Verify CISD confirmed
   ├── Check trade direction filter
   ├── Check session filter
   ├── Check time filter
   ├── Check day filter
   ├── Check max trades per day
   ├── Check consecutive losses
   ├── Check volatility filter
   ├── Check SMT filter
   ├── Check ERL alignment
   ├── Check HTF bias
   ├── Check FVG quality
   ├── Check confirmation timing
   └── Verify no existing position

2. Order Placement
   ├── Calculate entry price
   ├── Calculate stop loss
   ├── Calculate take profit
   ├── Calculate position size
   ├── Place market order (or limit if Mode A)
   ├── Set stop loss order
   ├── Set take profit order
   └── Update trade tracking variables

3. Position Management
   ├── Check for break-even trigger
   ├── Update stop to break-even
   ├── Check for trailing stop activation
   ├── Update trailing stop
   ├── Check for partial TP
   ├── Close partial position
   └── Monitor exit conditions
```

### 5.4 Exit Logic

```
1. Opposite Signal Exit
   ├── Check if opposite signal confirmed
   └── Close position if true

2. Time-Based Exit
   ├── Check bars in trade
   └── Close if exceeds limit

3. End of Day Exit
   ├── Check current time
   └── Close at specified time

4. New HTF Candle Exit
   ├── Detect new HTF candle
   └── Close position

5. FVG Invalidation Exit
   ├── Check if triggering FVG fully mitigated
   └── Close position if true

6. Stop Loss / Take Profit
   ├── Monitor price vs stop
   ├── Monitor price vs TP
   └── Execute when hit
```

---

## 6. Risk Management

### 6.1 Position Sizing Methods

**1. Percent of Equity**
```
Position Size = (Equity × Position Size Value / 100) / Entry Price
```

**2. Fixed Contracts**
```
Position Size = Position Size Value
```

**3. Fixed USD**
```
Position Size = Position Size Value / Entry Price
```

**4. Risk-Based**
```
Risk USD = Equity × Risk Amount / 100
Risk Per Unit = |Entry Price - Stop Price|
Position Size = Risk USD / Risk Per Unit
Position Size = AdjustForContractSize(Position Size)
```

### 6.2 Contract Size Adjustment

**Algorithm: Contract Size Adjustment**
```
Input: Raw position size, symbol type
Output: Adjusted position size

Function AdjustForContractSize(rawSize, symbolType):
    if (symbolType == "Forex"):
        return rawSize / 100000.0  // Standard lot size
    else if (symbolType == "Futures"):
        contractSize = GetContractSize(symbol)
        return rawSize / contractSize
    else:
        return rawSize
```

### 6.3 Break-Even Logic

**Algorithm: Break-Even Stop Management**
```
Input: Entry price, current price, stop price, break-even trigger R:R
Output: New stop price

Function ManageBreakEven(entryPrice, currentPrice, stopPrice, triggerRR):
    double dInitialRisk = abs(entryPrice - stopPrice)
    double dCurrentProfit = (currentPrice - entryPrice)  // For long
    double dRMultiple = (dInitialRisk > 0) ? dCurrentProfit / dInitialRisk : 0
    
    if (dRMultiple >= triggerRR):
        // Move stop to break-even + offset
        double dOffset = breakEvenOffset * Point
        return entryPrice + dOffset  // For long
    else:
        return stopPrice
```

### 6.4 Trailing Stop Logic

**Algorithm: Trailing Stop Management**
```
Input: Entry price, current price, current stop, trailing type, distance
Output: New stop price

Function ManageTrailingStop(entryPrice, currentPrice, currentStop, type, distance):
    double dInitialRisk = abs(entryPrice - currentStop)
    double dCurrentProfit = abs(currentPrice - entryPrice)
    double dRMultiple = (dInitialRisk > 0) ? dCurrentProfit / dInitialRisk : 0
    
    if (dRMultiple >= trailingActivationRR):
        double dTrailDistance = 0
        
        switch (type):
            case "Fixed Points":
                dTrailDistance = distance * Point
            case "Fixed Percent":
                dTrailDistance = currentPrice * distance / 100.0
            case "ATR-Based":
                double dATR = iATR(Symbol, Period, atrStopLength, 0)
                dTrailDistance = dATR * distance
        
        double dTrailStop = currentPrice - dTrailDistance  // For long
        
        // Only move stop in favorable direction
        if (dTrailStop > currentStop):
            return dTrailStop
    
    return currentStop
```

### 6.5 Partial Take Profit

**Algorithm: Partial Take Profit**
```
Input: Entry price, stop price, partial TP ratio, partial TP percent
Output: Partial TP price and close quantity

Function CalculatePartialTP(entryPrice, stopPrice, ratio, percent):
    double dRiskDistance = abs(entryPrice - stopPrice)
    double dPartialReward = dRiskDistance * ratio
    double dPartialTP = entryPrice + dPartialReward  // For long
    
    double dCloseQty = PositionSize * percent / 100.0
    
    return (dPartialTP, dCloseQty)
```

---

## 7. Visual Elements

### 7.1 FVG Boxes

**Drawing Specification:**
- **Type:** Rectangle (box)
- **Color:** Green for bullish FVG, Red for bearish FVG
- **Transparency:** 85% (configurable)
- **Segments:** 10-15 segments per FVG (based on FVG size)
- **Update:** Extend right edge to current time until mitigated

**MQ5 Implementation:**
```cpp
void DrawFVGBox(SFVG &fvg, bool bIsBullish)
{
    double dFVGSize = MathAbs(fvg.dRangeHigh - fvg.dRangeLow);
    int iSegments = (int)MathMax(10, MathMin(15, dFVGSize / _Point / 10));
    double dBoxHeight = dFVGSize / iSegments;
    
    for(int i = 0; i < iSegments; i++)
    {
        double dBoxTop = fvg.dRangeHigh + (i + 1) * dBoxHeight;
        double dBoxBottom = fvg.dRangeHigh + i * dBoxHeight;
        
        datetime dtRight = (fvg.bHighMitigated && fvg.bLowMitigated) ? 
                          MathMax(fvg.dtHighMitigationTime, fvg.dtLowMitigationTime) : 
                          TimeCurrent();
        
        string sName = "FVG_" + IntegerToString(fvg.iCreationBar) + "_" + IntegerToString(i);
        color clrBox = bIsBullish ? clrGreen : clrRed;
        
        ObjectCreate(0, sName, OBJ_RECTANGLE, 0, fvg.dtHighStartTime, dBoxTop, dtRight, dBoxBottom);
        ObjectSetInteger(0, sName, OBJPROP_COLOR, clrBox);
        ObjectSetInteger(0, sName, OBJPROP_STYLE, STYLE_SOLID);
        ObjectSetInteger(0, sName, OBJPROP_WIDTH, 1);
        ObjectSetInteger(0, sName, OBJPROP_BACK, true);
        ObjectSetInteger(0, sName, OBJPROP_FILL, true);
    }
}
```

### 7.2 Confirmation Lines

**Drawing Specification:**
- **Type:** Horizontal line
- **Color:** Red for bearish, Green for bullish
- **Style:** Solid
- **Width:** 1 pixel
- **Label:** "OB-" for bearish, "OB+" for bullish, with signal grade (A/A+/A++)

**MQ5 Implementation:**
```cpp
void DrawConfirmationLine(SConfirmationLine &conf)
{
    string sLineName = "ConfLine_" + IntegerToString(conf.dtConfirmationTime);
    string sLabelName = "ConfLabel_" + IntegerToString(conf.dtConfirmationTime);
    
    datetime dtEnd = (bExtendOnlyLatest && IsLatestConfirmation(conf)) ? 
                     TimeCurrent() : conf.dtConfirmationTime;
    
    // Draw line
    ObjectCreate(0, sLineName, OBJ_TREND, 0, conf.dtStartTime, conf.dConfirmationLevel, 
                 dtEnd, conf.dConfirmationLevel);
    color clrLine = (conf.sSignalType == "BEARISH") ? clrRed : clrGreen;
    ObjectSetInteger(0, sLineName, OBJPROP_COLOR, clrLine);
    ObjectSetInteger(0, sLineName, OBJPROP_STYLE, STYLE_SOLID);
    ObjectSetInteger(0, sLineName, OBJPROP_WIDTH, 1);
    ObjectSetInteger(0, sLineName, OBJPROP_RAY_RIGHT, false);
    
    // Draw label
    string sLabelText = (conf.sSignalType == "BEARISH") ? "OB-" : "OB+";
    if(bShowSignalGrade && conf.sSignalGrade != "")
        sLabelText += " " + conf.sSignalGrade;
    
    ObjectCreate(0, sLabelName, OBJ_TEXT, 0, dtEnd, conf.dConfirmationLevel);
    ObjectSetString(0, sLabelName, OBJPROP_TEXT, sLabelText);
    ObjectSetInteger(0, sLabelName, OBJPROP_COLOR, clrLine);
    ObjectSetInteger(0, sLabelName, OBJPROP_FONTSIZE, 8);
}
```

### 7.3 ERL Lines

**Drawing Specification:**
- **Type:** Horizontal line
- **Color:** Yellow (configurable)
- **Style:** Solid
- **Width:** 1 pixel
- **Label:** "ERL-" for high, "ERL+" for low
- **Update:** Extend until mitigated, then stop

### 7.4 Dashboard

**Layout Specification:**
```
┌─────────────────────────────┐
│ Title: [TF]-[HTF] Model     │
├─────────────────────────────┤
│ Timer: [Time to next HTF]   │
├─────────────────────────────┤
│ Bias: [Neutral/Bullish/Bear]│
├─────────────────────────────┤
│ Session: [IN/OUT] ([Name])  │
├─────────────────────────────┤
│ Signal: [Pending/Confirmed] │
│         [Entry/Stop/Size]   │
├─────────────────────────────┤
│ Position: [LONG/SHORT/FLAT]  │
│            P&L: [Value]      │
├─────────────────────────────┤
│ Stats: Trades: [Count]      │
│        Win%: [Percent]      │
│        PF: [Factor]          │
└─────────────────────────────┘
```

**MQ5 Implementation:**
```cpp
void UpdateDashboard()
{
    string sTitle = GetCurrentTimeframe() + "-" + GetHTFString() + " Model";
    string sTimer = GetRemainingTimeToHTF();
    string sBias = GetBiasString();
    string sSession = GetSessionStatus();
    string sSignal = GetSignalInfo();
    string sPosition = GetPositionInfo();
    string sStats = GetPerformanceStats();
    
    // Create or update dashboard panel
    // Use OBJ_RECTANGLE_LABEL for panel background
    // Use OBJ_LABEL for text elements
}
```

### 7.5 Killzone Boxes

**Drawing Specification:**
- **Type:** Rectangle (session boxes)
- **Sessions:** Asian, London, NY Open, NY Lunch, NY Close
- **Color:** Configurable per session
- **Transparency:** 92% (configurable)
- **Update:** Extend during session, finalize at session end

---

## 8. Configuration Parameters

### 8.1 HTF Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| AutoMode | bool | true | Automatically select HTF based on chart timeframe |
| ManualHTF | ENUM_TIMEFRAMES | PERIOD_D1 | Manual HTF selection (when AutoMode = false) |

### 8.2 Strategy Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| ExecutionMode | enum | Werlein Standard | Execution mode: Werlein Standard or Sniper/Obi Variant |
| TradeDirection | enum | Both | Trade direction: Both, Long Only, Short Only |
| PositionSizeType | enum | Percent of Equity | Position sizing method |
| PositionSizeValue | double | 100.0 | Position size value (depends on type) |
| UseStopLoss | bool | true | Enable stop loss |
| StopLossType | enum | Signal-Based | Stop loss type |
| UseTakeProfit | bool | true | Enable take profit |
| TakeProfitType | enum | Risk:Reward | Take profit type |
| RiskRewardRatio | double | 2.0 | Risk:Reward ratio for TP |
| UsePartialTP | bool | false | Enable partial take profit |
| PartialTPPercent | double | 50.0 | Percentage of position to close at partial TP |
| UseBreakEven | bool | false | Move stop to break-even |
| BreakEvenTriggerRR | double | 1.0 | R:R trigger for break-even |
| UseTrailingStop | bool | false | Enable trailing stop |
| TrailingStopType | enum | ATR-Based | Trailing stop type |
| TrailingStopActivation | double | 1.5 | R:R activation for trailing stop |

### 8.3 Signal Filters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| RequireHTFContext | bool | true | Only create signals when price is at HTF POI |
| RequireViolentRejection | bool | false | Only confirm signals with strong rejection |
| RequireDisplacementCheck | bool | false | Filter out true breakouts |
| ShowSignalGrade | bool | true | Display signal grade (A/A+/A++) |
| MinFVGSize | double | 0.0 | Minimum FVG size in points |
| MaxFVGSize | double | 0.0 | Maximum FVG size in points (0 = no max) |
| MaxBarsToConfirm | int | 0 | Max bars to confirmation (0 = unlimited) |
| MinBarsToConfirm | int | 0 | Min bars to confirmation |
| RequireSMTConfirmation | bool | false | Require SMT for entry |
| RequireERLAlignment | bool | false | Require ERL alignment |

### 8.4 Trade Filters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| UseTimeFilter | bool | false | Enable time filter |
| TradingStartHour | int | 7 | Trading start hour |
| TradingStartMinute | int | 0 | Trading start minute |
| TradingEndHour | int | 16 | Trading end hour |
| TradingEndMinute | int | 0 | Trading end minute |
| TradeMon | bool | true | Trade Monday |
| TradeTue | bool | true | Trade Tuesday |
| TradeWed | bool | true | Trade Wednesday |
| TradeThu | bool | true | Trade Thursday |
| TradeFri | bool | true | Trade Friday |
| MaxTradesPerDay | int | 0 | Max trades per day (0 = unlimited) |
| MaxConsecutiveLosses | int | 0 | Max consecutive losses (0 = unlimited) |
| UseVolatilityFilter | bool | false | Use volatility filter |
| MinATR | double | 0.0 | Minimum ATR |
| MaxATR | double | 0.0 | Maximum ATR (0 = no max) |

### 8.5 Session Filter

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| EnableSessionFilter | bool | false | Enable session filter |
| FilterMode | enum | Signals Only | Filter mode |
| AsianSessionEnabled | bool | false | Enable Asian session |
| LondonSessionEnabled | bool | true | Enable London session |
| NYAmSessionEnabled | bool | true | Enable NY AM session |
| NYLunchEnabled | bool | false | Enable NY Lunch |
| NYPmSessionEnabled | bool | false | Enable NY PM session |
| SessionTimezone | string | "America/New_York" | Session timezone |

### 8.6 Visual Settings

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| ShowConfirmationLines | bool | true | Show confirmation lines |
| ShowFVGBoxes | bool | true | Show FVG boxes |
| ShowLabels | bool | false | Show labels |
| ShowDashboard | bool | true | Show dashboard |
| DashboardPosition | enum | Top Right | Dashboard position |
| ShowKillzones | bool | true | Show killzone boxes |

---

## 9. MQ5 Implementation Guidelines

### 9.1 Class Structure Recommendations

```cpp
// Main Expert Advisor
class CForeverModelEA : public CExpert
{
private:
    CHTFManager* m_htfManager;
    CFVGDetector* m_fvgDetector;
    CManipulationTracker* m_manipulationTracker;
    CiFVGDetector* m_ifvgDetector;
    CCISDConfirmation* m_cisdConfirmation;
    CSMTDetector* m_smtDetector;
    CRiskManager* m_riskManager;
    CVisualManager* m_visualManager;
    CDashboard* m_dashboard;
    
    // Configuration
    SConfig m_config;
    
    // State
    vector<SFVG> m_activeFVGs;
    vector<SiFVG> m_bullFVGArray;
    vector<SiFVG> m_bearFVGArray;
    vector<SiFVG> m_bullInvArray;
    vector<SiFVG> m_bearInvArray;
    SPendingSignal m_pendingBearish;
    SPendingSignal m_pendingBullish;
    SERL m_erl;
    vector<SSMT> m_smtArray;
    vector<SConfirmationLine> m_confirmationLines;
    
public:
    bool OnInit();
    void OnDeinit();
    void OnTick();
    void OnTimer();
};
```

### 9.2 HTF Data Management

```cpp
class CHTFManager
{
private:
    ENUM_TIMEFRAMES m_htfPeriod;
    int m_iHTFHandle;
    double m_htfHigh[];
    double m_htfLow[];
    double m_htfOpen[];
    double m_htfClose[];
    datetime m_htfTime[];
    int m_iHTFCandleCount;
    bool m_bNewHTFCandle;
    
public:
    bool Initialize(ENUM_TIMEFRAMES htf);
    void Update();
    bool IsNewHTFCandle();
    void GetHTFData(int bars, double &high[], double &low[], double &open[], 
                    double &close[], datetime &time[]);
    int GetHTFCandleCount();
};
```

### 9.3 FVG Detection

```cpp
class CFVGDetector
{
private:
    CHTFManager* m_htfManager;
    vector<SFVG> m_fvgs;
    
public:
    bool Initialize(CHTFManager* htfManager);
    void Update();
    void DetectNewFVGs();
    void CheckMitigation();
    vector<SFVG>& GetActiveFVGs();
    bool IsAtHTFPOI();
};
```

### 9.4 Data Storage

**Recommendation:** Use arrays or vectors for dynamic data structures:
- `vector<SFVG>` for active FVGs
- `vector<SiFVG>` for iFVGs
- `vector<SSMT>` for SMTs
- `vector<SConfirmationLine>` for confirmation lines

**Cleanup Strategy:**
- Remove FVGs older than 2500 bars
- Remove mitigated FVGs older than 1250 bars
- Keep only last 50 confirmation lines
- Keep only last 100 iFVGs

### 9.5 Event Handling

```cpp
void CForeverModelEA::OnTick()
{
    // Update HTF data
    m_htfManager.Update();
    
    // Detect new HTF candle
    if(m_htfManager.IsNewHTFCandle())
    {
        m_htfManager.IncrementCandleCount();
        // Process HTF-specific logic
    }
    
    // Update FVG detection
    m_fvgDetector.Update();
    
    // Update manipulation tracking
    m_manipulationTracker.Update();
    
    // Update iFVG detection
    m_ifvgDetector.Update();
    
    // Check CISD confirmations
    m_cisdConfirmation.Update();
    
    // Update SMT detection
    if(m_config.bEnableSMT)
        m_smtDetector.Update();
    
    // Execute trades
    ExecuteTrades();
    
    // Manage open positions
    ManagePositions();
    
    // Update visual elements
    m_visualManager.Update();
}

void CForeverModelEA::OnTimer()
{
    // Update dashboard
    m_dashboard.Update();
    
    // Clean up old visual objects
    m_visualManager.Cleanup();
}
```

### 9.6 Order Management

```cpp
class CRiskManager
{
public:
    double CalculatePositionSize(double entryPrice, double stopPrice);
    double CalculateStopLoss(string signalType, double entryPrice, SPendingSignal* signal);
    double CalculateTakeProfit(string signalType, double entryPrice, double stopPrice);
    bool PlaceTrade(string signalType, double entryPrice, double stopPrice, double tpPrice);
    void ManageBreakEven();
    void ManageTrailingStop();
    void CheckPartialTP();
};
```

### 9.7 Visual Object Management

```cpp
class CVisualManager
{
private:
    vector<string> m_objectNames;
    
public:
    void DrawFVGBox(SFVG &fvg, bool bIsBullish);
    void DrawConfirmationLine(SConfirmationLine &conf);
    void DrawERLLine(SERL &erl);
    void UpdateFVGBoxes();
    void UpdateConfirmationLines();
    void CleanupOldObjects();
    string GenerateObjectName(string prefix, int id);
};
```

### 9.8 Error Handling

**Critical Checks:**
1. Verify HTF data is available before processing
2. Check array bounds before accessing historical data
3. Validate price data before calculations
4. Verify order placement success
5. Handle symbol-specific contract sizes

**MQ5 Implementation:**
```cpp
bool CForeverModelEA::OnInit()
{
    // Initialize HTF manager
    if(!m_htfManager.Initialize(m_config.htfPeriod))
    {
        Print("Failed to initialize HTF manager");
        return false;
    }
    
    // Initialize other components...
    
    // Verify symbol properties
    if(SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE) == 0)
    {
        Print("Invalid symbol tick size");
        return false;
    }
    
    return true;
}
```

### 9.9 Performance Optimization

**Recommendations:**
1. Use `ArraySetAsSeries()` for historical data arrays
2. Limit lookback periods (max 500 bars)
3. Cache frequently accessed data (HTF data, ATR)
4. Use `OnTimer()` for non-critical updates (dashboard)
5. Clean up old visual objects regularly
6. Use `CopyBuffer()` efficiently for indicator data

---

## 10. Testing Requirements

### 10.1 Unit Tests

**Test Cases:**
1. HTF period selection (auto mode)
2. FVG detection (bearish and bullish)
3. FVG mitigation logic
4. Pivot detection
5. Manipulation candle identification
6. iFVG detection and inversion
7. HTF context validation
8. Violent rejection validation
9. Displacement check
10. CISD confirmation
11. Entry price calculation (Mode A and B)
12. Stop loss calculation (all types)
13. Position size calculation (all types)
14. SMT divergence detection

### 10.2 Integration Tests

**Test Scenarios:**
1. Complete signal creation flow
2. CISD confirmation with Mode A entry
3. CISD confirmation with Mode B entry
4. Trade execution and position management
5. Break-even and trailing stop logic
6. Partial take profit execution
7. Exit conditions (opposite signal, time, EOD, etc.)

### 10.3 Backtesting Requirements

**Test Periods:**
- At least 1 year of historical data
- Multiple market conditions (trending, ranging, volatile)
- Different timeframes (M15, H1, H4, D1)
- Different instruments (forex, futures, indices)

**Metrics to Track:**
- Total trades
- Win rate
- Profit factor
- Maximum drawdown
- Average R:R
- Mode A vs Mode B performance
- Signal grade performance (A vs A+ vs A++)

### 10.4 Forward Testing

**Requirements:**
- Minimum 3 months forward testing
- Real account (demo acceptable)
- Monitor all execution modes
- Track signal quality grades
- Verify visual elements display correctly
- Monitor performance metrics

---

## 11. Additional Notes

### 11.1 MQ5-Specific Considerations

1. **Time Handling:** Use `MqlDateTime` structure for timezone conversions
2. **Symbol Properties:** Use `SymbolInfo*()` functions for symbol data
3. **Order Management:** Use `CTrade` class or `OrderSend()` function
4. **Visual Objects:** Use `ObjectCreate()`, `ObjectSet*()` functions
5. **Indicator Data:** Use `iATR()`, `iMA()`, etc. or `CopyBuffer()` for custom indicators
6. **Array Management:** Use `ArrayResize()`, `ArraySetAsSeries()` for efficient data handling

### 11.2 Differences from Pine Script

1. **Bar Indexing:** MQ5 uses 0 for current bar, Pine Script uses 0 for current bar (similar)
2. **Time Handling:** MQ5 uses datetime (seconds since 1970), Pine Script uses timestamp (milliseconds)
3. **Order Execution:** MQ5 requires explicit order management, Pine Script has strategy.* functions
4. **Visual Objects:** MQ5 uses ObjectCreate/Set functions, Pine Script has built-in drawing functions
5. **Data Access:** MQ5 uses CopyBuffer for indicator data, Pine Script has direct access

### 11.3 Recommended Libraries

1. **Standard Library:** Use MQL5 Standard Library classes
   - `CTrade` for order management
   - `CIndicator` base classes for indicators
   - `CDraw` for visual elements (if available)

2. **Custom Classes:**
   - `CArrayObj` or `CList` for dynamic arrays
   - Custom datetime/timezone handling
   - Custom visual object manager

---

## 12. Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | January 2025 | Initial technical specification for MQ5 development |

---

## 13. Contact and Support

For questions or clarifications regarding this specification, please refer to:
- Base Implementation: `forever_indi_v4_strategy.pine`
- Meta-Analysis Document: `FOREEVER MODEL - META ANALYSIS.pdf`
- Comparison Document: `FOREVER_MODEL_COMPARISON_AND_ENHANCEMENTS.md`

---

**End of Technical Specification**

