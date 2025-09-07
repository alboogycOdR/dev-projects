

All three files are **identical** in content. They contain a header file (`CRT_Core.mqh`) that defines a shared logic module for a trading system referred to as **CRT (Closed Range Trading)**. Below is a comprehensive review of the system based on this shared code.

---

## 🔍 **System Overview: CRT (Closed Range Trading)**

The CRT system is a **multi-timeframe price action strategy** based on:
- H4 (Higher Timeframe) bias detection
- M15 (Lower Timeframe) state machine execution
- Key concepts: **Closed Range**, **Sweep**, **MSS**, **FVG**, and **Entry**

It uses a **state-machine approach** to track progression of price action toward a potential entry.

---

## 🧩 Core Components

### 1. **Enums**
```mql5
enum ENUM_BIAS        { NEUTRAL, BULLISH, BEARISH }
enum ENUM_SETUP_STATE { IDLE, SWEEP, MSS, FVG, ENTRY }
```
- These define the directional bias and the progression of setup states.

---

### 2. **Structure: `CRT_State`**
Holds the state of the trading logic per symbol:
```mql5
struct CRT_State
{
   string            symbol;
   ENUM_BIAS         bias;
   double            crt_high;
   double            crt_low;
   double            mss_level;
   double            fvg_high;
   double            fvg_low;
   ENUM_SETUP_STATE  bull_state;
   ENUM_SETUP_STATE  bear_state;
};
```
- Tracks:
  - Bias (from H4)
  - Closed Range (CRT) high/low
  - MSS (Market Structure Shift) level
  - FVG (Fair Value Gap) boundaries
  - Separate state machines for bull and bear setups

---

### 3. **Bias Detection: `CRT_Bias()`**
- Uses **H4 closed candles only** (avoids repainting).
- Compares **two most recent closed H4 bars**:
  - **Range Bar**: Second-last bar (defines the range: `high` and `low`)
  - **Sweep Bar**: Last bar (checks for sweep and close behavior)

#### Bullish Bias:
```mql5
if(sweepL < range_low && close >= range_low) → BULLISH
```
- Price sweeps below range low but **closes back inside or above** — indicates rejection and potential upward move.

#### Bearish Bias:
```mql5
if(sweepH > range_high && close <= range_high) → BEARISH
```
- Price sweeps above range high but **closes back inside or below** — rejection and potential downward move.

> ✅ **Strength**: This avoids false breakouts and focuses on **closed candle confirmation**.

---

### 4. **State Machine: `M15_Step()`**
Executes logic on M15 timeframe once bias is established.

#### State Progression (Bullish Example):
| State | Condition |
|------|----------|
| `IDLE → SWEEP` | M15 low breaks below `crt_low` |
| `SWEEP → MSS`  | Price moves back above the sweep low (now `mss_level`) |
| `MSS → FVG`    | Detects a bullish FVG: `high[i-2] < low[i]` (gap between candles) |
| `FVG → ENTRY`  | Price retests and breaks below the FVG high (i.e., enters the gap) |

> 🔁 Note: For bearish, logic is mirrored.

#### FVG Detection:
- Bullish FVG: `high[i-2] < low[i]` → gap up, potential pullback zone
- Bearish FVG: `low[i-2] > high[i]` → gap down, potential short zone

> ⚠️ **Observation**: The FVG → ENTRY condition appears to be **counter-intuitive**:
- For **bullish setup**, entry triggers when `m15[0].low < fvg_high` — i.e., price breaks **into** the FVG from above.
- That suggests **entry on retest into the FVG**, which is correct for a buy setup.

✅ So logic is sound: FVG is a **demand zone**, and entry is triggered when price returns into it.

---

### 5. **Telegram Integration**
```mql5
bool Telegram_Send(const string token, const string chat_id, const string msg)
```
- Uses `WebRequest()` to send alerts via Telegram bot.
- Full debug output: URL, HTTP status, response body.
- Uses **GET request** with URL parameters (not ideal for security, but functional).

> ✅ Good for alerts and monitoring.
> 🔐 **Note**: Exposing bot tokens in logs is risky — ensure logs are not public.

---

### 6. **Helper: `ResetState()`**
Resets all state variables for a symbol.
- Used when reinitializing or switching symbols.

---

## 📈 Strategy Logic Summary

### Step-by-Step Flow:
1. **Detect H4 Bias**:
   - Use two closed H4 candles.
   - Identify sweep & close behavior.
   - Set `bias`, `crt_high`, `crt_low`.

2. **Track M15 Progression**:
   - If bullish:
     - Wait for sweep below CRT low.
     - Confirm MSS with reversal above sweep low.
     - Detect FVG (gap up).
     - Trigger ENTRY when price pulls back into FVG.
   - Mirror for bearish.

3. **Entry Signal**:
   - State reaches `ENTRY` in either bull or bear machine.
   - Can be used to trigger order placement (in a full EA).

---

## ✅ Strengths

| Feature | Advantage |
|-------|-----------|
| **Closed candles only** | Eliminates repainting, robust for live trading |
| **Multi-timeframe** | H4 for bias, M15 for precision |
| **State machine** | Clear, auditable progression; avoids premature entries |
| **FVG-based entries** | Aligns with order flow / institutional concepts |
| **Telegram alerts** | Enables remote monitoring |
| **Modular design** | `.mqh` header can be reused across scanner & trader EAs |

---

## ⚠️ Potential Issues & Improvements

### 1. **FVG Detection Logic**
```mql5
for(int i=2; i<ArraySize(m15); i++)
  if(m15[i-2].high < m15[i].low)  // Bullish FVG
```
- This detects a gap between `i-2` and `i`, skipping `i-1`.
- But it **does not validate** the middle candle (`i-1`) — which should be a true "gap" candle engulfing the space.

> 🔍 Better: Confirm that `i-1` low > `i-2` high and `i-1` high > `i` low (full gap).

Also, current logic may miss recent FVGs — scanning from `i=2` to end may not prioritize latest candles.

✅ **Suggestion**: Reverse loop (from recent to past) and break on first valid FVG.

---

### 2. **No Position Management**
- This code only detects states.
- No order execution, SL/TP, or risk logic.
- Expected in a shared header, but must be added in EA.

---

### 3. **MSS Level Definition**
- `mss_level = m15[0].low` (on sweep)
- But `m15[0]` is the current (incomplete) candle — may fluctuate.

> ⚠️ Risk of repainting if current candle wiggles.

✅ **Fix**: Use `m15[1].low` (last closed candle) instead.

---

### 4. **Hardcoded Timeframes**
- H4 and M15 are fixed.
- Could be made configurable for reuse on other pairs/timeframes.

---

### 5. **No Volume or Filter Logic**
- Purely price-based.
- Could benefit from:
  - Volatility filter (ATR)
  - Session filter (London/NY open)
  - RSI divergence

---

### 6. **Entry Confirmation**
- `ENTRY` state is set when price touches FVG.
- But no confirmation (e.g., reversal candle, momentum shift).

✅ **Suggestion**: Add confirmation via:
  - Pinbar
  - Bullish/Bearish engulfing
  - RSI/Stochastic reversal

---

## 🧰 Usage in Full System

This `.mqh` file is likely used by:
- **Scanner EA** (`CRT-Scanner.mq5`): Monitors multiple pairs, detects bias and state, sends alerts.
- **Trader EA** (`CRT-Trader.mq5`): Manages orders, entries, exits based on state.

Current code lacks:
- Order execution
- Trade management
- Multi-symbol loop
- Timer for polling

But as a **shared core**, it's well-designed.

---

## ✅ Final Verdict

**CRT_Core.mqh** is a **well-structured, robust foundation** for a price-action-based trading system. It combines:
- Clean state machine design
- Solid bias detection
- FVG logic aligned with modern market structure theory
- Debug-friendly output and Telegram alerts

It is **not a complete trading system** on its own — it's a **shared logic module** — but it serves that purpose excellently.

---

## 🔧 Recommendations

1. **Improve FVG detection** with proper gap validation and reverse loop.
2. **Use closed candles only** in state transitions (avoid `m15[0]` where possible).
3. **Add entry confirmation** logic before triggering trades.
4. **Implement risk management** in the full EA (position sizing, SL/TP).
5. **Make timeframes configurable** for flexibility.
6. **Add logging to file** or alert de-duplication to avoid spam.

---

Would you like me to:
- Provide a **fixed/improved version** of `CRT_Core.mqh`?
- Help build a **scanner EA** using this?
- Design a **trading EA** with entry/exit logic?

Let me know how you'd like to proceed!