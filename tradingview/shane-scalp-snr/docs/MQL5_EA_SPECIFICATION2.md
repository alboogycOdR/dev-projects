# MQL5 Expert Advisor - Technical Specification
## Wick Rejection S/R Strategy

**Version:** 2.0  
**Date:** 2024-12-14  
**Source:** Pine Script v5 Indicator (wick_rejection_sr_strategy_v2.pine)  
**Target Platform:** MetaTrader 5 (MQL5)  
**Strategy Type:** Support/Resistance + Wick Rejection Scalping/Day Trading

---

## 📋 TABLE OF CONTENTS

1. [Executive Summary](#executive-summary)
2. [Strategy Overview](#strategy-overview)
3. [Core Components](#core-components)
4. [User Inputs & Parameters](#user-inputs--parameters)
5. [Technical Implementation](#technical-implementation)
6. [Signal Logic & Entry Rules](#signal-logic--entry-rules)
7. [Risk Management](#risk-management)
8. [Visual Display Requirements](#visual-display-requirements)
9. [Alert System](#alert-system)
10. [Performance Requirements](#performance-requirements)
11. [Testing & Validation](#testing--validation)
12. [Code Structure](#code-structure)
13. [Appendices](#appendices)

---

## 1. EXECUTIVE SUMMARY

### 1.1 Strategy Purpose
Automated trading system that identifies high-probability reversal points at dynamically detected support and resistance levels based on **wick rejection patterns**.

### 1.2 Key Features
- ✅ Dynamic S/R level detection based on wick analysis
- ✅ Three signal types: Zone Tests, Liquidity Sweeps, Breakout Retests
- ✅ Multi-timeframe trend filtering (M5 + H1 confluence)
- ✅ Confidence scoring system (1-5 scale)
- ✅ Automated position management with calculated SL/TP
- ✅ Real-time dashboard with bias indicators
- ✅ Level expiration system (removes stale levels)
- ✅ Signal cooldown to prevent overtrading

### 1.3 Recommended Markets
- **Primary**: Gold (XAUUSD), Forex majors (EURUSD, GBPUSD, etc.)
- **Timeframes**: M5 (primary), M15, M30
- **Session**: London/NY overlap for highest volatility

---

## 2. STRATEGY OVERVIEW

### 2.1 Core Concept
The strategy identifies price levels where market participants have **rejected** price movement (long wicks), treating these as significant S/R zones. It then waits for price to return to these zones and shows similar rejection patterns before generating signals.

### 2.2 Three-Phase Process

#### Phase 1: Level Detection
- Scan historical bars for **rejection candles** (wick threshold: 50%+ of candle range)
- Store level prices in arrays (separate for support/resistance)
- Merge nearby levels within proximity threshold
- Track touches, creation time, and last signal bar for each level

#### Phase 2: Signal Generation
- Monitor when price enters zone boundaries
- Detect three signal types:
  1. **LIQUIDITY SWEEP** (Priority 1): Price breaks level then reverses back
  2. **ZONE TEST** (Priority 2): Price enters zone and shows rejection wick
  3. **BREAKOUT RETEST** (Priority 3): Broken level tested from opposite side
- Calculate confidence score (1-5) based on multiple factors
- Apply cooldown period to prevent duplicate signals

#### Phase 3: Trade Execution (EA Only)
- Filter signals by trend alignment (EMA + H1 confluence)
- Calculate position size based on risk % and SL distance
- Place market order with automatic SL/TP
- Manage open positions (optional trailing stop)
- Close on opposite signal or TP/SL hit

---

## 3. CORE COMPONENTS

### 3.1 Data Structures

#### 3.1.1 Level Data Object
```cpp
struct LevelData {
    double price;              // Level price
    int touches;               // Number of times tested
    datetime bar_created;      // When level was first detected
    datetime last_signal_bar;  // Last time signal was generated here
    int line_id;               // TrendLine object ID for drawing
    int box_id;                // Rectangle object ID for zone
    int label_id;              // Text label object ID
};
```

#### 3.1.2 Arrays
```cpp
LevelData support_levels[];     // Dynamic array of support levels
LevelData resistance_levels[];  // Dynamic array of resistance levels
```

#### 3.1.3 Broken Level Tracking
```cpp
struct BrokenLevel {
    double price;
    datetime bar_broken;
    bool was_support;  // true = was support (now resistance), false = vice versa
};

BrokenLevel broken_levels[];
```

### 3.2 Indicators Required

#### 3.2.1 EMA (Exponential Moving Average)
```cpp
int ema_handle;
double ema_buffer[];
// Parameters: period = 9 (default), applied_price = PRICE_CLOSE
```

#### 3.2.2 Higher Timeframe Data (H1)
```cpp
int h1_close_handle;
int h1_ema_handle;
double h1_close[];
double h1_ema[];
// Fetch using iCustom() or manual calculation on H1 timeframe
```

### 3.3 Signal State Variables
```cpp
struct SignalState {
    bool buy_signal;
    bool sell_signal;
    bool is_sweep_signal;
    bool is_breakout_retest;
    double signal_level;
    int signal_confidence;      // 1-5 scale
    string signal_type;         // "ZONE TEST", "LIQUIDITY SWEEP", "BREAKOUT RETEST"
    double suggested_sl;
    double suggested_tp;        // Calculate as 2x SL distance (default)
};

SignalState current_signal;
```

---

## 4. USER INPUTS & PARAMETERS

### 4.1 Level Detection Settings
```cpp
input group "══════ Level Detection ══════"
input int    lookback_period     = 50;      // Lookback Period (20-200)
input double wick_threshold      = 0.50;    // Wick Threshold % (0.30-0.80)
input double level_proximity     = 2.0;     // Level Merge Distance in points (0.5-20.0)
input int    max_levels          = 6;       // Max Levels to Track (2-12)
input double zone_buffer         = 1.5;     // Zone Buffer in points (0.5-10.0)
input double min_candle_range    = 1.0;     // Min Candle Range in points (0.1-10.0)
input int    level_expiration    = 200;     // Level Expiration in bars (50-500)
```

**Notes:**
- `level_proximity`: For Gold, 2.0 points works well; for Forex adjust to 5-10 pips
- `zone_buffer`: Creates a range [price - buffer, price + buffer] for zone detection
- `level_expiration`: Removes levels older than X bars that haven't been touched

### 4.2 Trend Filter Settings
```cpp
input group "══════ Trend Filter ══════"
input int    ema_length          = 9;       // EMA Length (5-50)
input bool   use_ema_filter      = true;    // Use EMA Filter
input bool   require_h1_align    = true;    // Require H1 Confluence
```

**Logic:**
- If `use_ema_filter = true`: Only BUY when close > EMA, only SELL when close < EMA
- If `require_h1_align = true`: Also check H1 close vs H1 EMA for same direction

### 4.3 Signal Settings
```cpp
input group "══════ Signal Settings ══════"
input bool   show_zone_test      = true;    // Show Zone Test Signals
input bool   show_sweeps         = true;    // Show Liquidity Sweeps
input bool   show_breakout_retest = true;   // Show Breakout Retests
input int    min_confidence      = 2;       // Minimum Confidence Score (1-5)
input int    signal_cooldown     = 8;       // Signal Cooldown in bars (1-20)
input int    max_signal_labels   = 5;       // Max Signal Labels on chart (3-10)
```

### 4.4 Trading Settings (EA Specific)
```cpp
input group "══════ Trading Settings ══════"
input bool   auto_trade          = true;    // Enable Auto Trading
input double risk_percent        = 1.0;     // Risk Per Trade % (0.1-5.0)
input double reward_ratio        = 2.0;     // Risk:Reward Ratio (1.0-5.0)
input int    magic_number        = 234567;  // Magic Number
input string trade_comment       = "WR-SR"; // Trade Comment
input bool   use_trailing_stop   = false;   // Use Trailing Stop
input double trailing_start      = 5.0;     // Trailing Start in points
input double trailing_step       = 2.0;     // Trailing Step in points
input int    max_trades_per_day  = 10;      // Max Trades Per Day (0=unlimited)
input bool   close_on_opposite   = true;    // Close Position on Opposite Signal
```

### 4.5 Visual Settings
```cpp
input group "══════ Visual Settings ══════"
input color  resistance_color    = clrRed;         // Resistance Color
input color  support_color       = clrRed;         // Support Color
input int    zone_transparency   = 90;             // Zone Transparency (70-98)
input bool   show_zones          = true;           // Show Zone Boxes
input bool   show_labels         = true;           // Show Price Labels
input bool   show_info_table     = true;           // Show Info Dashboard
input ENUM_BASE_CORNER table_corner = CORNER_RIGHT_UPPER; // Dashboard Position
input int    table_font_size     = 10;             // Dashboard Font Size (8-14)
input color  buy_signal_color    = clrLime;        // Buy Signal Color
input color  sell_signal_color   = clrRed;         // Sell Signal Color
input color  sweep_color         = clrDodgerBlue;  // Liquidity Sweep Color
```

### 4.6 Alert Settings
```cpp
input group "══════ Alert Settings ══════"
input bool   alert_on_signal     = true;    // Alert on Entry Signal
input bool   alert_on_sweep      = true;    // Alert on Liquidity Sweep
input bool   alert_on_breakout   = true;    // Alert on Breakout Retest
input bool   send_notification   = false;   // Send Push Notification
input bool   send_email          = false;   // Send Email Alert
```

---

## 5. TECHNICAL IMPLEMENTATION

### 5.1 Initialization (OnInit)

```cpp
int OnInit() {
    // 1. Initialize indicator handles
    ema_handle = iMA(_Symbol, PERIOD_CURRENT, ema_length, 0, MODE_EMA, PRICE_CLOSE);
    h1_ema_handle = iMA(_Symbol, PERIOD_H1, ema_length, 0, MODE_EMA, PRICE_CLOSE);
    
    // 2. Validate inputs
    if (wick_threshold < 0.3 || wick_threshold > 0.8) {
        Print("Invalid wick_threshold. Must be 0.3-0.8");
        return INIT_PARAMETERS_INCORRECT;
    }
    
    // 3. Initialize arrays
    ArrayResize(support_levels, 0);
    ArrayResize(resistance_levels, 0);
    ArrayResize(broken_levels, 0);
    
    // 4. Set up chart objects prefix
    obj_prefix = "WR_SR_";
    
    // 5. Create dashboard table
    if (show_info_table) CreateDashboard();
    
    // 6. Load historical levels (scan last lookback_period bars)
    ScanHistoricalLevels();
    
    return INIT_SUCCEEDED;
}
```

### 5.2 Main Loop (OnTick)

```cpp
void OnTick() {
    // 1. Check if new bar formed (only process on bar close for signals)
    if (!IsNewBar()) return;
    
    // 2. Update indicator buffers
    UpdateIndicators();
    
    // 3. Calculate current bias
    CalculateBias();
    
    // 4. Detect new levels from most recent candle
    DetectNewLevels();
    
    // 5. Expire old levels
    ExpireOldLevels();
    
    // 6. Check for signals at existing levels
    CheckForSignals();
    
    // 7. Update visual elements (levels, zones, dashboard)
    if (show_zones || show_labels) UpdateVisuals();
    if (show_info_table) UpdateDashboard();
    
    // 8. Execute trades if auto_trade enabled
    if (auto_trade && (current_signal.buy_signal || current_signal.sell_signal)) {
        ExecuteTrade();
    }
    
    // 9. Manage open positions
    ManageOpenPositions();
    
    // 10. Send alerts if configured
    if (current_signal.buy_signal || current_signal.sell_signal) {
        SendAlerts();
    }
}
```

### 5.3 Key Functions

#### 5.3.1 Wick Calculations

```cpp
// Calculate candle metrics
double CandleRange(int bar) {
    return iHigh(_Symbol, PERIOD_CURRENT, bar) - iLow(_Symbol, PERIOD_CURRENT, bar);
}

double UpperWick(int bar) {
    double high = iHigh(_Symbol, PERIOD_CURRENT, bar);
    double body_top = MathMax(iOpen(_Symbol, PERIOD_CURRENT, bar), 
                              iClose(_Symbol, PERIOD_CURRENT, bar));
    return high - body_top;
}

double LowerWick(int bar) {
    double low = iLow(_Symbol, PERIOD_CURRENT, bar);
    double body_bottom = MathMin(iOpen(_Symbol, PERIOD_CURRENT, bar), 
                                  iClose(_Symbol, PERIOD_CURRENT, bar));
    return body_bottom - low;
}

// Check if candle is a rejection candle
bool IsBullishRejection(int bar) {
    double range = CandleRange(bar);
    if (range < min_candle_range * _Point) return false;
    
    double lower_wick = LowerWick(bar);
    return (lower_wick / range) >= wick_threshold;
}

bool IsBearishRejection(int bar) {
    double range = CandleRange(bar);
    if (range < min_candle_range * _Point) return false;
    
    double upper_wick = UpperWick(bar);
    return (upper_wick / range) >= wick_threshold;
}
```

#### 5.3.2 Level Management

```cpp
// Find if price is near existing level
int FindNearbyLevel(LevelData &levels[], double price, double proximity) {
    for (int i = 0; i < ArraySize(levels); i++) {
        if (MathAbs(levels[i].price - price) <= proximity * _Point) {
            return i;
        }
    }
    return -1;
}

// Add or update support level
void AddOrUpdateSupport(double price) {
    int idx = FindNearbyLevel(support_levels, price, level_proximity);
    
    if (idx >= 0) {
        // Update existing level
        support_levels[idx].touches++;
        support_levels[idx].bar_created = TimeCurrent();  // Refresh age
    } else {
        // Add new level
        if (ArraySize(support_levels) >= max_levels) {
            RemoveWeakestLevel(support_levels);
        }
        
        int new_size = ArraySize(support_levels) + 1;
        ArrayResize(support_levels, new_size);
        
        LevelData new_level;
        new_level.price = price;
        new_level.touches = 1;
        new_level.bar_created = TimeCurrent();
        new_level.last_signal_bar = 0;
        new_level.line_id = -1;
        new_level.box_id = -1;
        new_level.label_id = -1;
        
        support_levels[new_size - 1] = new_level;
    }
}

// Remove weakest level (least touches)
void RemoveWeakestLevel(LevelData &levels[]) {
    int min_touches = 999;
    int min_idx = 0;
    
    for (int i = 0; i < ArraySize(levels); i++) {
        if (levels[i].touches < min_touches) {
            min_touches = levels[i].touches;
            min_idx = i;
        }
    }
    
    // Delete visual objects
    DeleteLevelDrawings(levels[min_idx]);
    
    // Remove from array
    ArrayRemove(levels, min_idx, 1);
}

// Expire levels older than level_expiration bars
void ExpireOldLevels() {
    datetime current_time = TimeCurrent();
    int bar_seconds = PeriodSeconds(PERIOD_CURRENT);
    
    // Check support levels
    for (int i = ArraySize(support_levels) - 1; i >= 0; i--) {
        int bars_old = (int)((current_time - support_levels[i].bar_created) / bar_seconds);
        if (bars_old > level_expiration) {
            DeleteLevelDrawings(support_levels[i]);
            ArrayRemove(support_levels, i, 1);
        }
    }
    
    // Check resistance levels
    for (int i = ArraySize(resistance_levels) - 1; i >= 0; i--) {
        int bars_old = (int)((current_time - resistance_levels[i].bar_created) / bar_seconds);
        if (bars_old > level_expiration) {
            DeleteLevelDrawings(resistance_levels[i]);
            ArrayRemove(resistance_levels, i, 1);
        }
    }
}
```

#### 5.3.3 Bias Calculation

```cpp
void CalculateBias() {
    // Get current EMA value
    double ema_current = ema_buffer[0];
    double close_current = iClose(_Symbol, PERIOD_CURRENT, 0);
    
    // M5 Bias
    bool m5_bullish = close_current > ema_current;
    bool m5_bearish = close_current < ema_current;
    
    // H1 Bias
    bool h1_bullish = false;
    bool h1_bearish = false;
    
    if (require_h1_align) {
        double h1_close_current = h1_close[0];
        double h1_ema_current = h1_ema[0];
        h1_bullish = h1_close_current > h1_ema_current;
        h1_bearish = h1_close_current < h1_ema_current;
    } else {
        // If H1 not required, always true
        h1_bullish = true;
        h1_bearish = true;
    }
    
    // Overall Bias
    overall_bullish = m5_bullish && (h1_bullish || !require_h1_align);
    overall_bearish = m5_bearish && (h1_bearish || !require_h1_align);
}
```

---

## 6. SIGNAL LOGIC & ENTRY RULES

### 6.1 Signal Priority System

Signals are checked in this order (first match wins):

1. **LIQUIDITY SWEEP** (Highest Priority)
2. **ZONE TEST** (Medium Priority)  
3. **BREAKOUT RETEST** (Lower Priority)

### 6.2 Signal Type 1: Liquidity Sweep

#### Definition
Price **breaks through** a level then **reverses back** on the same candle.

#### Detection Logic (BUY Example)
```cpp
bool DetectLiquiditySweepBuy(LevelData &level) {
    double low_bar = iLow(_Symbol, PERIOD_CURRENT, 1);      // Previous bar
    double close_bar = iClose(_Symbol, PERIOD_CURRENT, 1);
    
    // Conditions:
    // 1. Low broke BELOW support level
    // 2. Close is ABOVE support level (reversed back)
    bool swept = (low_bar < level.price) && (close_bar > level.price);
    
    if (!swept) return false;
    
    // Calculate confidence
    int confidence = 3;  // Base for sweep
    if (level.touches >= 3) confidence++;
    if (!use_ema_filter || overall_bullish) confidence++;
    if (!require_h1_align || h1_bullish) confidence++;
    
    if (confidence >= min_confidence) {
        current_signal.buy_signal = true;
        current_signal.is_sweep_signal = true;
        current_signal.signal_level = level.price;
        current_signal.signal_confidence = confidence;
        current_signal.signal_type = "LIQUIDITY SWEEP";
        current_signal.suggested_sl = low_bar - (zone_buffer * 0.5 * _Point);
        current_signal.suggested_tp = level.price + ((level.price - current_signal.suggested_sl) * reward_ratio);
        
        // Update level
        level.last_signal_bar = TimeCurrent();
        return true;
    }
    
    return false;
}
```

#### Detection Logic (SELL Example)
```cpp
bool DetectLiquiditySweepSell(LevelData &level) {
    double high_bar = iHigh(_Symbol, PERIOD_CURRENT, 1);
    double close_bar = iClose(_Symbol, PERIOD_CURRENT, 1);
    
    bool swept = (high_bar > level.price) && (close_bar < level.price);
    
    if (!swept) return false;
    
    int confidence = 3;
    if (level.touches >= 3) confidence++;
    if (!use_ema_filter || overall_bearish) confidence++;
    if (!require_h1_align || h1_bearish) confidence++;
    
    if (confidence >= min_confidence) {
        current_signal.sell_signal = true;
        current_signal.is_sweep_signal = true;
        current_signal.signal_level = level.price;
        current_signal.signal_confidence = confidence;
        current_signal.signal_type = "LIQUIDITY SWEEP";
        current_signal.suggested_sl = high_bar + (zone_buffer * 0.5 * _Point);
        current_signal.suggested_tp = level.price - ((current_signal.suggested_sl - level.price) * reward_ratio);
        
        level.last_signal_bar = TimeCurrent();
        return true;
    }
    
    return false;
}
```

### 6.3 Signal Type 2: Zone Test

#### Definition
Price enters the **zone** around a level and shows a **rejection wick**.

#### Zone Definition
```cpp
// Asymmetric zones (more room on entry side)
double support_zone_above = level.price + (zone_buffer * 1.2 * _Point);
double support_zone_below = level.price - (zone_buffer * 0.8 * _Point);

double resist_zone_above = level.price + (zone_buffer * 0.8 * _Point);
double resist_zone_below = level.price - (zone_buffer * 1.2 * _Point);
```

#### Detection Logic (BUY Example)
```cpp
bool DetectZoneTestBuy(LevelData &level) {
    double low_bar = iLow(_Symbol, PERIOD_CURRENT, 1);
    double zone_top = level.price + (zone_buffer * 1.2 * _Point);
    double zone_bottom = level.price - (zone_buffer * 0.8 * _Point);
    
    // 1. Price is in zone
    bool in_zone = (low_bar <= zone_top) && (low_bar >= zone_bottom);
    if (!in_zone) return false;
    
    // 2. Shows bullish rejection
    if (!IsBullishRejection(1)) return false;
    
    // 3. Calculate confidence
    int confidence = 1;  // Base
    if (level.touches >= 3) confidence++;
    if (!use_ema_filter || overall_bullish) confidence++;
    if (!require_h1_align || h1_bullish) confidence++;
    
    double lower_wick_ratio = LowerWick(1) / CandleRange(1);
    if (lower_wick_ratio > 0.6) confidence++;  // Strong rejection bonus
    
    if (confidence >= min_confidence) {
        current_signal.buy_signal = true;
        current_signal.is_sweep_signal = false;
        current_signal.signal_level = level.price;
        current_signal.signal_confidence = confidence;
        current_signal.signal_type = "ZONE TEST";
        current_signal.suggested_sl = zone_bottom - (zone_buffer * 0.5 * _Point);
        current_signal.suggested_tp = level.price + ((level.price - current_signal.suggested_sl) * reward_ratio);
        
        level.last_signal_bar = TimeCurrent();
        return true;
    }
    
    return false;
}
```

### 6.4 Signal Type 3: Breakout Retest

#### Definition
A level that was **broken** is now being **retested from the opposite side**.

#### Logic Flow
1. Track when levels are broken (close beyond zone)
2. Store in `broken_levels[]` array with timestamp
3. When price returns 3-50 bars later, check for rejection
4. Former resistance becomes support (BUY), former support becomes resistance (SELL)

#### Detection Logic
```cpp
void CheckBreakoutRetests() {
    if (!show_breakout_retest) return;
    if (current_signal.buy_signal || current_signal.sell_signal) return;  // Only if no other signal
    
    for (int i = 0; i < ArraySize(broken_levels); i++) {
        BrokenLevel bl = broken_levels[i];
        int bars_since = BarsSince(bl.bar_broken);
        
        // Must be 3-50 bars ago
        if (bars_since < 3 || bars_since > 50) continue;
        
        // Broken RESISTANCE (now support) - look for BUY
        if (!bl.was_support) {
            double low_bar = iLow(_Symbol, PERIOD_CURRENT, 1);
            bool in_zone = (low_bar <= bl.price + zone_buffer * _Point) && 
                           (low_bar >= bl.price - zone_buffer * _Point);
            
            if (in_zone && IsBullishRejection(1) && overall_bullish) {
                current_signal.buy_signal = true;
                current_signal.is_breakout_retest = true;
                current_signal.signal_level = bl.price;
                current_signal.signal_confidence = 4;  // High confidence
                current_signal.signal_type = "BREAKOUT RETEST";
                current_signal.suggested_sl = low_bar - (zone_buffer * _Point);
                current_signal.suggested_tp = bl.price + ((bl.price - current_signal.suggested_sl) * reward_ratio);
                return;
            }
        }
        
        // Broken SUPPORT (now resistance) - look for SELL
        if (bl.was_support) {
            double high_bar = iHigh(_Symbol, PERIOD_CURRENT, 1);
            bool in_zone = (high_bar >= bl.price - zone_buffer * _Point) && 
                           (high_bar <= bl.price + zone_buffer * _Point);
            
            if (in_zone && IsBearishRejection(1) && overall_bearish) {
                current_signal.sell_signal = true;
                current_signal.is_breakout_retest = true;
                current_signal.signal_level = bl.price;
                current_signal.signal_confidence = 4;
                current_signal.signal_type = "BREAKOUT RETEST";
                current_signal.suggested_sl = high_bar + (zone_buffer * _Point);
                current_signal.suggested_tp = bl.price - ((current_signal.suggested_sl - bl.price) * reward_ratio);
                return;
            }
        }
    }
}
```

### 6.5 Cooldown System

```cpp
bool CheckCooldown(LevelData &level) {
    if (level.last_signal_bar == 0) return true;  // Never signaled
    
    int bars_since = BarsSince(level.last_signal_bar);
    return bars_since >= signal_cooldown;
}
```

### 6.6 Final Signal Check Flow

```cpp
void CheckForSignals() {
    // Reset signal state
    ResetSignalState();
    
    // Priority 1: Check for liquidity sweeps at support levels
    if (show_sweeps) {
        for (int i = 0; i < ArraySize(support_levels); i++) {
            if (!CheckCooldown(support_levels[i])) continue;
            if (DetectLiquiditySweepBuy(support_levels[i])) return;  // Found sweep, stop checking
        }
    }
    
    // Priority 1b: Check sweeps at resistance
    if (show_sweeps) {
        for (int i = 0; i < ArraySize(resistance_levels); i++) {
            if (!CheckCooldown(resistance_levels[i])) continue;
            if (DetectLiquiditySweepSell(resistance_levels[i])) return;
        }
    }
    
    // Priority 2: Check for zone tests at support
    if (show_zone_test) {
        for (int i = 0; i < ArraySize(support_levels); i++) {
            if (!CheckCooldown(support_levels[i])) continue;
            if (DetectZoneTestBuy(support_levels[i])) return;
        }
    }
    
    // Priority 2b: Zone tests at resistance
    if (show_zone_test) {
        for (int i = 0; i < ArraySize(resistance_levels); i++) {
            if (!CheckCooldown(resistance_levels[i])) continue;
            if (DetectZoneTestSell(resistance_levels[i])) return;
        }
    }
    
    // Priority 3: Check for breakout retests
    CheckBreakoutRetests();
}
```

---

## 7. RISK MANAGEMENT

### 7.1 Position Sizing

```cpp
double CalculatePositionSize(double entry_price, double sl_price) {
    // Calculate risk in account currency
    double account_balance = AccountInfoDouble(ACCOUNT_BALANCE);
    double risk_amount = account_balance * (risk_percent / 100.0);
    
    // Calculate SL distance in points
    double sl_distance_points = MathAbs(entry_price - sl_price) / _Point;
    
    // Calculate lot size
    double tick_value = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
    double lot_size = risk_amount / (sl_distance_points * tick_value);
    
    // Normalize lot size
    double min_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
    double max_lot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
    double lot_step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
    
    lot_size = MathMax(min_lot, MathMin(max_lot, lot_size));
    lot_size = MathFloor(lot_size / lot_step) * lot_step;
    
    return lot_size;
}
```

### 7.2 Trade Execution

```cpp
void ExecuteTrade() {
    // Check daily trade limit
    if (max_trades_per_day > 0 && CountTradesToday() >= max_trades_per_day) {
        Print("Daily trade limit reached");
        return;
    }
    
    // Check if opposite position exists
    if (close_on_opposite) {
        if (current_signal.buy_signal && PositionSelect(_Symbol)) {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
                ClosePosition();
            }
        }
        if (current_signal.sell_signal && PositionSelect(_Symbol)) {
            if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
                ClosePosition();
            }
        }
    }
    
    // Don't open new position if one exists
    if (PositionSelect(_Symbol)) return;
    
    // Prepare trade request
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = _Symbol;
    request.magic = magic_number;
    request.comment = trade_comment + " " + current_signal.signal_type;
    
    double entry_price, sl, tp;
    
    if (current_signal.buy_signal) {
        entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        sl = current_signal.suggested_sl;
        tp = current_signal.suggested_tp;
        request.type = ORDER_TYPE_BUY;
    } else {
        entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
        sl = current_signal.suggested_sl;
        tp = current_signal.suggested_tp;
        request.type = ORDER_TYPE_SELL;
    }
    
    // Calculate lot size
    request.volume = CalculatePositionSize(entry_price, sl);
    request.price = entry_price;
    request.sl = sl;
    request.tp = tp;
    request.deviation = 10;
    request.type_filling = ORDER_FILLING_FOK;
    
    // Send order
    if (!OrderSend(request, result)) {
        Print("OrderSend failed: ", GetLastError());
        Print("Result: ", result.retcode, " - ", result.comment);
    } else {
        Print("Trade opened: ", current_signal.signal_type, 
              " at ", entry_price, " SL:", sl, " TP:", tp, " Lot:", request.volume);
    }
}
```

### 7.3 Position Management

```cpp
void ManageOpenPositions() {
    if (!PositionSelect(_Symbol)) return;
    
    ulong ticket = PositionGetInteger(POSITION_TICKET);
    double position_sl = PositionGetDouble(POSITION_SL);
    double position_tp = PositionGetDouble(POSITION_TP);
    
    // Trailing stop logic
    if (use_trailing_stop) {
        double current_price = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 
                                SymbolInfoDouble(_Symbol, SYMBOL_BID) : 
                                SymbolInfoDouble(_Symbol, SYMBOL_ASK);
        double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
        
        if (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            double profit_points = (current_price - open_price) / _Point;
            if (profit_points >= trailing_start) {
                double new_sl = current_price - (trailing_step * _Point);
                if (new_sl > position_sl) {
                    ModifyPosition(ticket, new_sl, position_tp);
                }
            }
        } else {
            double profit_points = (open_price - current_price) / _Point;
            if (profit_points >= trailing_start) {
                double new_sl = current_price + (trailing_step * _Point);
                if (new_sl < position_sl || position_sl == 0) {
                    ModifyPosition(ticket, new_sl, position_tp);
                }
            }
        }
    }
}
```

---

## 8. VISUAL DISPLAY REQUIREMENTS

### 8.1 Support/Resistance Lines

```cpp
void DrawLevel(LevelData &level, bool is_support) {
    string obj_name = obj_prefix + (is_support ? "SUP_" : "RES_") + DoubleToString(level.price, _Digits);
    
    // Delete old line if exists
    if (ObjectFind(0, obj_name) >= 0) {
        ObjectDelete(0, obj_name);
    }
    
    // Line styling based on touches
    int line_width = (level.touches >= 4) ? 3 : (level.touches >= 2) ? 2 : 1;
    ENUM_LINE_STYLE line_style = (level.touches >= 3) ? STYLE_SOLID : STYLE_DASH;
    
    // Calculate age-based transparency (older = more faded)
    int bars_old = BarsSince(level.bar_created);
    double age_factor = MathMax(0.3, 1.0 - ((double)bars_old / level_expiration) * 0.5);
    int alpha = (int)((1.0 - age_factor) * 50);  // 0-50 transparency
    
    color line_color = is_support ? ColorWithAlpha(support_color, alpha) : 
                                     ColorWithAlpha(resistance_color, alpha);
    
    // Create line
    ObjectCreate(0, obj_name, OBJ_HLINE, 0, 0, level.price);
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, line_color);
    ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, line_width);
    ObjectSetInteger(0, obj_name, OBJPROP_STYLE, line_style);
    ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
    
    level.line_id = StringToInteger(obj_name);
}
```

### 8.2 Zone Boxes

```cpp
void DrawZone(LevelData &level, bool is_support) {
    if (!show_zones) return;
    
    string obj_name = obj_prefix + "ZONE_" + (is_support ? "SUP_" : "RES_") + DoubleToString(level.price, _Digits);
    
    if (ObjectFind(0, obj_name) >= 0) {
        ObjectDelete(0, obj_name);
    }
    
    // Asymmetric zone bounds
    double zone_top, zone_bottom;
    if (is_support) {
        zone_top = level.price + (zone_buffer * 1.2 * _Point);
        zone_bottom = level.price - (zone_buffer * 0.8 * _Point);
    } else {
        zone_top = level.price + (zone_buffer * 0.8 * _Point);
        zone_bottom = level.price - (zone_buffer * 1.2 * _Point);
    }
    
    // Create rectangle
    datetime time_start = iTime(_Symbol, PERIOD_CURRENT, lookback_period);
    datetime time_end = iTime(_Symbol, PERIOD_CURRENT, 0) + PeriodSeconds(PERIOD_CURRENT) * 20;
    
    ObjectCreate(0, obj_name, OBJ_RECTANGLE, 0, time_start, zone_top, time_end, zone_bottom);
    
    color zone_color = is_support ? ColorWithAlpha(clrGreen, zone_transparency) : 
                                     ColorWithAlpha(clrRed, zone_transparency);
    color border_color = is_support ? ColorWithAlpha(clrGreen, 70) : 
                                       ColorWithAlpha(clrRed, 70);
    
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, border_color);
    ObjectSetInteger(0, obj_name, OBJPROP_BGCOLOR, zone_color);
    ObjectSetInteger(0, obj_name, OBJPROP_BACK, true);
    ObjectSetInteger(0, obj_name, OBJPROP_FILL, true);
    
    level.box_id = StringToInteger(obj_name);
}
```

### 8.3 Signal Markers

```cpp
void DrawSignalMarker() {
    if (!current_signal.buy_signal && !current_signal.sell_signal) return;
    
    string obj_name = obj_prefix + "SIGNAL_" + TimeToString(TimeCurrent());
    
    // Choose arrow type based on signal type
    int arrow_code;
    color arrow_color;
    
    if (current_signal.buy_signal) {
        if (current_signal.is_sweep_signal) {
            arrow_code = 119;  // Diamond
            arrow_color = sweep_color;
        } else if (current_signal.is_breakout_retest) {
            arrow_code = 159;  // Circle
            arrow_color = buy_signal_color;
        } else {
            arrow_code = 233;  // Triangle up
            arrow_color = buy_signal_color;
        }
    } else {
        if (current_signal.is_sweep_signal) {
            arrow_code = 119;  // Diamond
            arrow_color = sweep_color;
        } else if (current_signal.is_breakout_retest) {
            arrow_code = 159;  // Circle
            arrow_color = sell_signal_color;
        } else {
            arrow_code = 234;  // Triangle down
            arrow_color = sell_signal_color;
        }
    }
    
    double price = current_signal.buy_signal ? iLow(_Symbol, PERIOD_CURRENT, 1) : 
                                                iHigh(_Symbol, PERIOD_CURRENT, 1);
    datetime time = iTime(_Symbol, PERIOD_CURRENT, 1);
    
    ObjectCreate(0, obj_name, OBJ_ARROW, 0, time, price);
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, arrow_color);
    ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, arrow_code);
    ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 3);
}
```

### 8.4 Signal Labels (Compact Format)

```cpp
string signal_labels[];  // Track for max limit

void DrawSignalLabel() {
    if (!current_signal.buy_signal && !current_signal.sell_signal) return;
    
    string obj_name = obj_prefix + "LABEL_" + TimeToString(TimeCurrent());
    
    // Build compact label text
    string emoji = (current_signal.signal_confidence >= 4) ? "🔥" : 
                   (current_signal.signal_confidence >= 3) ? "⚡" : "⚠";
    
    string type_short = current_signal.is_sweep_signal ? "SWEEP" : 
                        current_signal.is_breakout_retest ? "B/R" : "ZONE";
    
    string label_text = emoji + " " + 
                        (current_signal.buy_signal ? "BUY " : "SELL ") + 
                        type_short + " @" + 
                        DoubleToString(current_signal.signal_level, _Digits) + 
                        " | SL:" + DoubleToString(current_signal.suggested_sl, _Digits);
    
    double price = current_signal.buy_signal ? 
                   iLow(_Symbol, PERIOD_CURRENT, 1) - (zone_buffer * 1.5 * _Point) :
                   iHigh(_Symbol, PERIOD_CURRENT, 1) + (zone_buffer * 1.5 * _Point);
    datetime time = iTime(_Symbol, PERIOD_CURRENT, 1);
    
    ObjectCreate(0, obj_name, OBJ_TEXT, 0, time, price);
    ObjectSetString(0, obj_name, OBJPROP_TEXT, label_text);
    ObjectSetInteger(0, obj_name, OBJPROP_COLOR, current_signal.buy_signal ? buy_signal_color : sell_signal_color);
    ObjectSetInteger(0, obj_name, OBJPROP_FONTSIZE, 8);
    ObjectSetString(0, obj_name, OBJPROP_FONT, "Arial");
    
    // Add to tracking array
    ArrayResize(signal_labels, ArraySize(signal_labels) + 1);
    signal_labels[ArraySize(signal_labels) - 1] = obj_name;
    
    // Remove oldest if exceeding limit
    if (ArraySize(signal_labels) > max_signal_labels) {
        ObjectDelete(0, signal_labels[0]);
        ArrayRemove(signal_labels, 0, 1);
    }
}
```

### 8.5 Dashboard/Info Table

```cpp
void CreateDashboard() {
    // Create dashboard panel (9 rows × 2 columns)
    // Row 0: Header
    // Row 1: M5 Bias
    // Row 2: H1 Bias
    // Row 3: Direction (highlighted)
    // Row 4: Separator
    // Row 5: Nearest Support
    // Row 6: Nearest Resistance
    // Row 7: Sup Levels count
    // Row 8: Res Levels count
    
    int x_start = 10;
    int y_start = 30;
    int row_height = 20;
    int col1_width = 80;
    int col2_width = 100;
    
    // Background panel
    string panel_name = obj_prefix + "DASHBOARD_BG";
    ObjectCreate(0, panel_name, OBJ_RECTANGLE_LABEL, 0, 0, 0);
    ObjectSetInteger(0, panel_name, OBJPROP_CORNER, table_corner);
    ObjectSetInteger(0, panel_name, OBJPROP_XDISTANCE, x_start);
    ObjectSetInteger(0, panel_name, OBJPROP_YDISTANCE, y_start);
    ObjectSetInteger(0, panel_name, OBJPROP_XSIZE, col1_width + col2_width);
    ObjectSetInteger(0, panel_name, OBJPROP_YSIZE, row_height * 9);
    ObjectSetInteger(0, panel_name, OBJPROP_BGCOLOR, ColorWithAlpha(clrBlack, 20));
    ObjectSetInteger(0, panel_name, OBJPROP_BORDER_COLOR, clrGray);
    ObjectSetInteger(0, panel_name, OBJPROP_BORDER_TYPE, BORDER_FLAT);
    
    // Create text labels for each cell (implement UpdateDashboard() to populate)
}

void UpdateDashboard() {
    if (!show_info_table) return;
    
    // Update each cell with current values
    // Row 0: Header
    SetDashboardCell(0, 0, "WR-SR v2", clrWhite, clrBlue);
    SetDashboardCell(0, 1, "STATUS", clrWhite, clrBlue);
    
    // Row 1: M5 Bias
    string m5_text = overall_bullish ? "BULLISH ▲" : overall_bearish ? "BEARISH ▼" : "NEUTRAL ●";
    color m5_color = overall_bullish ? clrLime : overall_bearish ? clrRed : clrGray;
    SetDashboardCell(1, 0, "M5 Bias", clrSilver, clrBlack);
    SetDashboardCell(1, 1, m5_text, m5_color, clrBlack);
    
    // ... (continue for all rows)
    
    // Row 3: Direction with background color
    string dir_text = overall_bullish ? "LONGS ONLY" : overall_bearish ? "SHORTS ONLY" : "NO TRADE";
    color dir_color = overall_bullish ? clrLime : overall_bearish ? clrRed : clrOrange;
    color dir_bg = overall_bullish ? ColorWithAlpha(clrGreen, 80) : ColorWithAlpha(clrMaroon, 80);
    SetDashboardCell(3, 0, "Direction", clrWhite, dir_bg);
    SetDashboardCell(3, 1, dir_text, dir_color, dir_bg);
    
    // ... (implement remaining rows)
}
```

---

## 9. ALERT SYSTEM

### 9.1 Alert Types

```cpp
void SendAlerts() {
    if (!alert_on_signal && !alert_on_sweep && !alert_on_breakout) return;
    
    bool should_alert = false;
    string alert_msg = "";
    
    // Check alert conditions
    if (current_signal.is_sweep_signal && alert_on_sweep) {
        should_alert = true;
        alert_msg = "⚡ LIQUIDITY SWEEP DETECTED\n";
    } else if (current_signal.is_breakout_retest && alert_on_breakout) {
        should_alert = true;
        alert_msg = "🔄 BREAKOUT RETEST DETECTED\n";
    } else if (alert_on_signal) {
        should_alert = true;
        alert_msg = current_signal.buy_signal ? "🟢 BUY SIGNAL\n" : "🔴 SELL SIGNAL\n";
    }
    
    if (!should_alert) return;
    
    // Build message
    alert_msg += _Symbol + " " + PeriodToString() + "\n";
    alert_msg += "Type: " + current_signal.signal_type + "\n";
    alert_msg += "Level: " + DoubleToString(current_signal.signal_level, _Digits) + "\n";
    alert_msg += "SL: " + DoubleToString(current_signal.suggested_sl, _Digits) + "\n";
    alert_msg += "TP: " + DoubleToString(current_signal.suggested_tp, _Digits) + "\n";
    alert_msg += "Confidence: " + IntegerToString(current_signal.signal_confidence) + "/5";
    
    // Send alerts
    Alert(alert_msg);
    
    if (send_notification) {
        SendNotification(alert_msg);
    }
    
    if (send_email) {
        SendMail("WR-SR Signal: " + _Symbol, alert_msg);
    }
}
```

---

## 10. PERFORMANCE REQUIREMENTS

### 10.1 Optimization Guidelines

1. **Array Management**
   - Limit `support_levels[]` and `resistance_levels[]` to `max_levels` (default 6)
   - Limit `broken_levels[]` to 10 entries max
   - Limit `signal_labels[]` to `max_signal_labels` (default 5)

2. **Object Cleanup**
   - Delete old chart objects when levels expire
   - Reuse object names where possible
   - Use `ObjectsDeleteAll(0, obj_prefix)` in OnDeinit()

3. **Calculation Frequency**
   - Only process on **new bar** (not every tick)
   - Cache indicator values in OnTick(), don't recalculate
   - Update visuals only when `levels_changed = true`

4. **Memory Management**
   - Use `ArrayResize()` efficiently
   - Free indicator handles in OnDeinit()
   - Avoid large historical scans (limit to `lookback_period`)

### 10.2 Resource Limits

```cpp
// Constants for safety
#define MAX_SUPPORT_LEVELS 12
#define MAX_RESISTANCE_LEVELS 12
#define MAX_BROKEN_LEVELS 10
#define MAX_SIGNAL_LABELS 10
#define MAX_LOOKBACK 200
```

### 10.3 Error Handling

```cpp
// Check for invalid inputs
if (max_levels > MAX_SUPPORT_LEVELS) {
    Print("Warning: max_levels too high. Setting to ", MAX_SUPPORT_LEVELS);
    max_levels = MAX_SUPPORT_LEVELS;
}

// Check for indicator handle failures
if (ema_handle == INVALID_HANDLE) {
    Print("Failed to create EMA indicator handle");
    return INIT_FAILED;
}

// Check for insufficient bars
if (Bars(_Symbol, PERIOD_CURRENT) < lookback_period + ema_length) {
    Print("Insufficient bars. Need at least ", lookback_period + ema_length);
    return INIT_FAILED;
}
```

---

## 11. TESTING & VALIDATION

### 11.1 Unit Testing Checklist

| Test Case | Expected Result | Status |
|-----------|----------------|--------|
| Bullish rejection detected at 4300.00 | Support level added at 4300.00 | ☐ |
| Bearish rejection detected at 4350.00 | Resistance level added at 4350.00 | ☐ |
| Price sweeps 4300 then closes above | BUY signal with "LIQUIDITY SWEEP" | ☐ |
| Price enters 4300 zone, shows wick | BUY signal with "ZONE TEST" | ☐ |
| Resistance broken, price retests | BUY signal with "BREAKOUT RETEST" | ☐ |
| Signal generated 5 bars ago at 4300 | No new signal at 4300 (cooldown) | ☐ |
| Level not touched for 200+ bars | Level removed (expired) | ☐ |
| Confidence score = 1, min = 2 | No signal generated (below threshold) | ☐ |
| Close below EMA, use_ema_filter=true | No BUY signals generated | ☐ |
| H1 bearish, require_h1_align=true | No BUY signals even if M5 bullish | ☐ |

### 11.2 Integration Testing

1. **Backtest Requirements**
   - Symbol: XAUUSD (Gold)
   - Timeframe: M5
   - Period: Last 6 months
   - Expected: 40-60% win rate, 1.5:1+ R:R

2. **Visual Verification**
   - All levels drawn correctly on chart
   - Zones align with level ± buffer
   - Dashboard updates in real-time
   - Signal markers appear on correct bars

3. **Trade Execution Test**
   - Orders open with correct SL/TP
   - Lot size respects risk %
   - Magic number applied correctly
   - Comments include signal type

### 11.3 Edge Cases

| Scenario | Handling |
|----------|----------|
| Market closed | Skip processing, wait for new bar |
| Spread > 5 points | Optional: skip trade or widen SL |
| Account balance < min trade size | Skip trade, log warning |
| Opposite signal while in trade | Close current, open opposite (if enabled) |
| Level price = 0 or invalid | Skip level, log error |
| Array full (max_levels reached) | Remove weakest level (least touches) |

---

## 12. CODE STRUCTURE

### 12.1 File Organization

```
WickRejectionSR_EA.mq5
├── // SECTION 1: HEADER & PROPERTIES
│   ├── #property directives
│   ├── Input parameters
│   └── Global variables
│
├── // SECTION 2: INITIALIZATION
│   ├── OnInit()
│   ├── OnDeinit()
│   └── CreateDashboard()
│
├── // SECTION 3: MAIN LOOP
│   ├── OnTick()
│   ├── IsNewBar()
│   └── UpdateIndicators()
│
├── // SECTION 4: WICK CALCULATIONS
│   ├── CandleRange()
│   ├── UpperWick() / LowerWick()
│   ├── IsBullishRejection()
│   └── IsBearishRejection()
│
├── // SECTION 5: LEVEL MANAGEMENT
│   ├── DetectNewLevels()
│   ├── AddOrUpdateSupport()
│   ├── AddOrUpdateResistance()
│   ├── FindNearbyLevel()
│   ├── RemoveWeakestLevel()
│   └── ExpireOldLevels()
│
├── // SECTION 6: BIAS & TREND
│   ├── CalculateBias()
│   ├── GetH1Data()
│   └── CheckTrendAlignment()
│
├── // SECTION 7: SIGNAL DETECTION
│   ├── CheckForSignals()
│   ├── DetectLiquiditySweepBuy/Sell()
│   ├── DetectZoneTestBuy/Sell()
│   ├── CheckBreakoutRetests()
│   ├── CheckCooldown()
│   └── CalculateConfidence()
│
├── // SECTION 8: TRADE MANAGEMENT
│   ├── ExecuteTrade()
│   ├── CalculatePositionSize()
│   ├── ManageOpenPositions()
│   ├── ModifyPosition()
│   ├── ClosePosition()
│   └── CountTradesToday()
│
├── // SECTION 9: VISUALS
│   ├── UpdateVisuals()
│   ├── DrawLevel()
│   ├── DrawZone()
│   ├── DrawSignalMarker()
│   ├── DrawSignalLabel()
│   ├── UpdateDashboard()
│   └── DeleteLevelDrawings()
│
├── // SECTION 10: ALERTS
│   └── SendAlerts()
│
└── // SECTION 11: UTILITIES
    ├── BarsSince()
    ├── PeriodToString()
    ├── ColorWithAlpha()
    ├── ResetSignalState()
    └── CleanupObjects()
```

### 12.2 Naming Conventions

- **Functions**: `PascalCase` (e.g., `DetectNewLevels()`)
- **Variables**: `snake_case` for inputs/globals (e.g., `wick_threshold`), `camelCase` for locals
- **Constants**: `UPPER_SNAKE_CASE` (e.g., `MAX_SUPPORT_LEVELS`)
- **Objects**: Prefix all with `obj_prefix` (e.g., `"WR_SR_SUP_4300"`)

### 12.3 Comments & Documentation

```cpp
//+------------------------------------------------------------------+
//| Detect liquidity sweep at support levels (BUY signal)            |
//| Returns: true if sweep detected and signal generated             |
//| Logic:                                                           |
//|   1. Check if low broke below level                             |
//|   2. Check if close is back above level                         |
//|   3. Calculate confidence score                                 |
//|   4. Generate signal if above min_confidence                    |
//+------------------------------------------------------------------+
bool DetectLiquiditySweepBuy(LevelData &level) {
    // Implementation...
}
```

---

## 13. APPENDICES

### Appendix A: Confidence Scoring Matrix

| Factor | Points | Condition |
|--------|--------|-----------|
| **Base (Sweep)** | +3 | Liquidity sweep detected |
| **Base (Zone Test)** | +1 | Price in zone with rejection |
| **Base (Breakout)** | +4 | Breakout retest (high confidence) |
| **Strong Level** | +1 | Level touched 3+ times |
| **Trend Alignment** | +1 | EMA filter passed (if enabled) |
| **HTF Confluence** | +1 | H1 bias aligned (if enabled) |
| **Strong Rejection** | +1 | Wick ratio > 60% (zone tests only) |

**Max Score**: 5  
**Recommended Min**: 2-3 for live trading

### Appendix B: Parameter Optimization Ranges

| Parameter | Conservative | Balanced | Aggressive |
|-----------|--------------|----------|------------|
| `wick_threshold` | 0.60 | 0.50 | 0.40 |
| `min_confidence` | 4 | 3 | 2 |
| `signal_cooldown` | 10 | 8 | 5 |
| `level_proximity` | 3.0 | 2.0 | 1.5 |
| `zone_buffer` | 2.0 | 1.5 | 1.0 |
| `use_ema_filter` | true | true | false |
| `require_h1_align` | true | true | false |
| `reward_ratio` | 2.5 | 2.0 | 1.5 |

### Appendix C: Common Issues & Solutions

| Issue | Cause | Solution |
|-------|-------|----------|
| Too many signals | Low `min_confidence` or `signal_cooldown` | Increase to 3+ and 8+ bars |
| No signals | Too high `wick_threshold` or `min_confidence` | Lower to 0.45 and 2 |
| Levels not drawn | `max_levels` too low | Increase to 6-8 |
| Levels drift | Levels being averaged on update | Fixed in v2: levels don't change price |
| Wrong direction trades | `use_ema_filter` disabled | Enable EMA filter |
| High slippage | Market order on news | Add spread filter or time filter |

### Appendix D: Performance Benchmarks

**Expected Metrics (M5 XAUUSD, 6 months backtest):**
- **Total Signals**: 200-400 (depending on settings)
- **Win Rate**: 40-60%
- **Average R:R**: 1.5:1 to 2.5:1
- **Max Drawdown**: < 15% (with 1% risk per trade)
- **Profit Factor**: 1.3-1.8
- **Best Signal Type**: Liquidity Sweeps (~65% win rate)
- **Worst Signal Type**: Zone Tests (~45% win rate)

### Appendix E: MQL5-Specific Notes

1. **CTrade Class**
   ```cpp
   #include <Trade\Trade.mqh>
   CTrade trade;
   trade.SetExpertMagicNumber(magic_number);
   trade.Buy(lot_size, _Symbol, entry_price, sl, tp, trade_comment);
   ```

2. **Array Manipulation**
   ```cpp
   // Add element
   ArrayResize(array, ArraySize(array) + 1);
   array[ArraySize(array) - 1] = new_value;
   
   // Remove element
   ArrayRemove(array, index, 1);
   ```

3. **Timeframe Conversion**
   ```cpp
   ENUM_TIMEFRAMES htf = PERIOD_H1;
   int h1_bars = iBars(_Symbol, htf);
   ```

4. **Object Drawing**
   - Use `OBJ_HLINE` for horizontal lines
   - Use `OBJ_RECTANGLE` for zones
   - Use `OBJ_ARROW` for signal markers
   - Use `OBJ_TEXT` or `OBJ_LABEL` for labels

### Appendix F: Delivery Checklist

**Developer Must Provide:**
- ☐ Compiled `.ex5` file
- ☐ Source `.mq5` file (fully commented)
- ☐ Settings file (`.set`) with default parameters
- ☐ Settings file (`.set`) with optimized parameters for XAUUSD M5
- ☐ User manual (PDF) with:
  - Installation instructions
  - Parameter descriptions
  - Visual examples
  - Trading guidelines
- ☐ Backtest report (6 months XAUUSD M5)
- ☐ Forward test results (1 month demo account)

**Testing Requirements:**
- ☐ Compiles without errors/warnings
- ☐ Passes all unit tests (Section 11.1)
- ☐ Visual elements match Pine Script version
- ☐ Dashboard displays correctly
- ☐ Trades execute with correct SL/TP
- ☐ No memory leaks (tested with 24hr+ run)
- ☐ Works on both demo and live accounts

---

## REVISION HISTORY

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | 2024-12-14 | Initial specification based on Pine Script v2.0 |

---

## CONTACT & SUPPORT

For questions during development:
- Reference Pine Script source: `wick_rejection_sr_strategy_v2.pine`
- Reference changelog: `CHANGELOG_v2.md`
- Reference rules: `.cursor/rules/pinescript.md` (for logic clarification)

---

**END OF SPECIFICATION**

