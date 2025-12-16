# 🔧 Settings Fix: Detecting Missing S/R Levels

## 🚨 **Problem:**
Strategy is not detecting the resistance zone at 4,348-4,350 where clear rejections are visible.

## ✅ **Solution:**

Change these 4 settings in **"Level Detection"** section:

```
BEFORE (Current):                    AFTER (Recommended):
═══════════════════════════════════════════════════════════════════
Lookback Period:           50   →   100
Wick Threshold %:          0.5  →   0.35
Max Levels to Show:        6    →   10
Level Expiration (bars):   200  →   500
```

---

## 📋 **Step-by-Step Instructions:**

### **Step 1: Open Strategy Settings**
1. Click on "WR-SR v3.1" in the chart header
2. Click the **gear icon** ⚙️ (Settings)

### **Step 2: Scroll to "LEVEL DETECTION" Section**

### **Step 3: Change These Values:**

**Setting #1:**
```
Lookback Period: 100
```
**Why:** Scans 500 minutes (8+ hours) of history instead of just 4 hours.

**Setting #2:**
```
Wick Threshold %: 0.35
```
**Why:** Detects rejection wicks that are 35%+ of candle range (instead of 50%+).
This will capture the rejections at 4,348-4,350.

**Setting #3:**
```
Max Levels to Show: 10
```
**Why:** Allows more S/R levels to coexist without removing important ones.

**Setting #4:**
```
Level Expiration (bars): 500
```
**Why:** Keeps levels valid for 2,500 minutes (41 hours) instead of 16 hours.

### **Step 4: Click OK**

### **Step 5: Wait 5-10 Seconds**
Strategy will recalculate all levels.

---

## 🎯 **Expected Result:**

After changing these settings, you should see:

✅ **New resistance line/box appears at 4,348-4,350**  
✅ **More S/R levels detected overall (8-10 instead of 4-5)**  
✅ **SELL signals start firing at the 4,348-4,350 zone**  
✅ **Strategy Tester shows 20-50+ trades instead of 0-2**

---

## 🔍 **Visual Confirmation:**

After applying settings, check your chart for:

1. **Red horizontal line** at ~4,348-4,350 (resistance)
2. **Red zone box** (shaded area) around that line
3. **Price label** on the right showing "4348.xx" or "4350.xx"
4. **SELL signal labels** (⚡ or 🔥) appearing when price tests that zone

---

## ⚠️ **If Still No Levels Detected:**

If you still don't see the 4,348-4,350 level after changing settings:

### **Option A: Lower Wick Threshold Even More**
```
Wick Threshold %: 0.30 (instead of 0.35)
```

### **Option B: Increase Lookback Even More**
```
Lookback Period: 150 (instead of 100)
```

### **Option C: Check Min Candle Range**
```
Min Candle Range: 0.5 (lower from 1.0)
```
**Why:** If rejection candles at 4,348-4,350 have a range <1 point, they're being ignored.

---

## 📊 **Understanding the Settings:**

### **Wick Threshold % - How It Works:**

```
Example Candle:
├─ High: 4,350.00
├─ Close: 4,348.50 (bearish rejection)
├─ Open: 4,347.00
└─ Low: 4,346.00

Calculation:
├─ Total Range: 4,350 - 4,346 = 4.0 points
├─ Upper Wick: 4,350 - 4,348.5 = 1.5 points
└─ Wick Ratio: 1.5 / 4.0 = 37.5%

Result:
├─ With threshold 0.50 (50%): ❌ NOT DETECTED
└─ With threshold 0.35 (35%): ✅ DETECTED
```

### **Max Levels - How It Works:**

```
Current Situation (Max = 6):
├─ Level 1: 4,340.84 (Support, 3 touches)
├─ Level 2: 4,338.44 (Resistance, 2 touches)
├─ Level 3: 4,330.xx (Support, 1 touch)
├─ Level 4: 4,328.xx (Resistance, 2 touches)
├─ Level 5: 4,326.xx (Support, 1 touch)
└─ Level 6: 4,320.xx (Support, 1 touch)

When new level detected at 4,348:
├─ Strategy must remove weakest level (Level 6)
└─ If 4,348 level is weak (1 touch), it might be removed next!

With Max = 10:
├─ All 6 existing levels stay
├─ New level at 4,348 added
└─ Room for 3 more levels
```

### **Lookback Period - How It Works:**

```
Current Time: 12:00 PM
Lookback = 50 bars (M5 timeframe)

Scanning window:
├─ 50 bars × 5 minutes = 250 minutes
├─ 250 minutes = 4 hours 10 minutes
└─ Scans back to: 7:50 AM

If rejection wick at 4,348 happened at 7:00 AM:
├─ With Lookback 50: ❌ NOT SCANNED (too old)
└─ With Lookback 100: ✅ SCANNED (within 8 hours)
```

---

## 🎯 **Quick Reference Card:**

Copy these settings for **GOLD (XAUUSD) M5 Scalping:**

```
═══════════════════════════════════════════════════════════
LEVEL DETECTION - RECOMMENDED FOR XAUUSD M5
═══════════════════════════════════════════════════════════
Lookback Period:           100
Wick Threshold %:          0.35
Level Merge Distance:      2.0 (keep default)
Max Levels to Show:        10
Zone Buffer (points):      1.5 (keep default)
Min Candle Range:          1.0 (keep default)
Level Expiration (bars):   500
═══════════════════════════════════════════════════════════
```

For **more aggressive** level detection (more signals):
```
Lookback Period:           150
Wick Threshold %:          0.30
Max Levels to Show:        12
Level Expiration (bars):   600
```

For **more conservative** level detection (fewer, stronger signals):
```
Lookback Period:           80
Wick Threshold %:          0.40
Max Levels to Show:        8
Level Expiration (bars):   400
```

---

## 📞 **Next Steps:**

1. ✅ Apply the recommended settings above
2. ✅ Take a screenshot of your chart after 10 seconds
3. ✅ Share screenshot showing if 4,348-4,350 level now appears
4. ✅ Check Strategy Tester > List of Trades for new trades

If you still don't see levels/trades after this, we'll investigate:
- Signal Settings (might be blocking valid signals)
- Strategy execution settings
- Chart data quality

---

*Settings Fix Guide v1.0*  
*Created: 2024-12-14*  
*Strategy: WR-SR v3.1*

