# 🧹 Auto-Cleanup Old Signals Feature

## Problem Solved

Your chart was getting **too busy** with many signal labels (green/red triangles and blue/orange breakout arrows) accumulating over time.

**Your Request:**
> "Can I not purge all the labels older than the last 10 candles on the 5- or 15-minute timeframe?"

**Solution:** Added automatic cleanup of old signal labels!

---

## ✨ What's New

### Automatic Signal Cleanup

The indicator now **automatically deletes** old signal labels (triangles and breakout arrows) after a specified number of bars to keep your chart clean and readable.

---

## ⚙️ New Settings

Located in: **🎯 Entry Signals** section

### 1. Auto-Delete Old Signals
```
✅ Auto-Delete Old Signals (Default: ON)
   "Automatically remove old signal labels to keep chart clean"
```

**Options:**
- ✅ **ON** - Automatically delete old signals (recommended)
- ❌ **OFF** - Keep all signals forever (chart gets busy)

### 2. Signal Lifetime (bars)
```
Signal Lifetime (bars): 10 (Default)
   "Delete signals older than this many bars"
```

**Range:** 1 to 100 bars

**Recommended Settings:**
- **5-minute chart**: 10 bars = 50 minutes of history
- **15-minute chart**: 10 bars = 150 minutes (2.5 hours) of history
- **1-hour chart**: 10 bars = 10 hours of history

---

## 📊 How It Works

### Before (Without Auto-Cleanup)

```
Chart gets cluttered with ALL signals:

14:00  ▲ LONG
14:15  ⬆ BO UP
14:30  ▼ SHORT
14:45  ⬇ BO DOWN
15:00  ▲ LONG
15:15  ⬆ BO UP
15:30  ▼ SHORT  ← Current time
       ↑
    Too many old signals cluttering the chart!
```

### After (With Auto-Cleanup, 10 bars)

```
Chart only shows RECENT signals:

15:00  ▲ LONG
15:15  ⬆ BO UP
15:30  ▼ SHORT  ← Current time
       ↑
    Clean! Only last 10 bars of signals visible
```

---

## 🎯 What Gets Cleaned Up

### Signals That Are Auto-Deleted:

1. **Entry Signal Triangles:**
   - ▲ Green triangles (LONG signals)
   - ▼ Red triangles (SHORT signals)

2. **Breakout Arrows:**
   - ⬆ Blue arrows (Breakout UP)
   - ⬇ Orange arrows (Breakout DOWN)

### What STAYS on Chart:

1. **Support/Resistance Lines:**
   - All horizontal lines remain
   - Inline labels on lines remain
   - Original labels at left remain

2. **Current Price Markers:**
   - Current price indicators stay

3. **Recent Signals:**
   - Signals within the lifetime window stay

---

## 💡 Configuration Examples

### For Day Trading (5-15 minute charts)

**Recommended:**
```
✅ Auto-Delete Old Signals: ON
   Signal Lifetime: 10 bars
```

**Result:**
- 5m chart: Shows last 50 minutes of signals
- 15m chart: Shows last 2.5 hours of signals
- Clean, focused view of recent action

### For Swing Trading (1H-4H charts)

**Recommended:**
```
✅ Auto-Delete Old Signals: ON
   Signal Lifetime: 20 bars
```

**Result:**
- 1H chart: Shows last 20 hours of signals
- 4H chart: Shows last 3+ days of signals
- More history for context

### For Analysis/Review

**If you want to see ALL signals:**
```
❌ Auto-Delete Old Signals: OFF
```

**Result:**
- All signals remain on chart
- Good for backtesting review
- Chart will be busy

---

## 🔄 How the Cleanup Works

### Technical Details

**Cleanup Process:**
1. Runs on every confirmed bar (when `barstate.islast`)
2. Checks age of each signal label
3. If `age > signal_lifetime_bars`:
   - Deletes the label
   - Removes from tracking arrays
4. Keeps recent signals intact

**Age Calculation:**
```
age = current_bar_index - signal_creation_bar
```

**Example:**
- Signal created at bar 100
- Current bar is 115
- Age = 115 - 100 = 15 bars
- If lifetime = 10, signal is deleted (15 > 10)

---

## 📈 Visual Comparison

### Your Chart Before (Cluttered)

```
Multiple overlapping signals:
- 20+ triangles visible
- 15+ breakout arrows
- Hard to see current action
- Confusing which signals are recent
```

### Your Chart After (Clean)

```
Only recent signals:
- ~5-10 triangles visible
- ~3-5 breakout arrows
- Clear view of current action
- Easy to see what's happening now
```

---

## ⚙️ Adjusting the Settings

### If Chart Is Still Too Busy

**Reduce lifetime:**
```
Signal Lifetime: 5 bars (instead of 10)
```

**Result:** Even fewer signals, cleaner chart

### If You Want More History

**Increase lifetime:**
```
Signal Lifetime: 20 bars (instead of 10)
```

**Result:** More signals visible, more context

### If You Want NO Auto-Cleanup

**Disable feature:**
```
❌ Auto-Delete Old Signals: OFF
```

**Result:** All signals remain (like before)

---

## 🎯 Best Practices

### Recommended by Timeframe

| Timeframe | Lifetime (bars) | Time Coverage |
|-----------|----------------|---------------|
| 1-minute | 15 bars | 15 minutes |
| 5-minute | 10 bars | 50 minutes |
| 15-minute | 10 bars | 2.5 hours |
| 1-hour | 12 bars | 12 hours |
| 4-hour | 6 bars | 24 hours |
| Daily | 5 bars | 5 days |

### Trading Style Recommendations

**Scalping (1-5 min):**
- Lifetime: 5-10 bars
- Keep it very clean
- Focus on immediate action

**Day Trading (5-15 min):**
- Lifetime: 10-15 bars
- Balance between clean and context
- See recent session action

**Swing Trading (1H-4H):**
- Lifetime: 15-20 bars
- More history for context
- See multi-day patterns

**Position Trading (Daily):**
- Lifetime: 10-20 bars
- Long-term view
- See weeks of signals

---

## 🔍 Troubleshooting

### "Signals disappear too quickly"

**Solution:**
- Increase "Signal Lifetime" to 15-20 bars
- Or disable auto-cleanup temporarily

### "Chart is still too busy"

**Solution:**
- Decrease "Signal Lifetime" to 5 bars
- Or disable some signal types:
  - Turn off "Show Breakout Signals" if you only want entry signals
  - Turn off "Show Entry Signal Triangles" if you only want breakouts

### "I want to review old signals"

**Solution:**
- Temporarily disable "Auto-Delete Old Signals"
- Scroll back in time
- Re-enable when done reviewing

### "Signals not cleaning up"

**Check:**
- ✅ "Auto-Delete Old Signals" is enabled
- ✅ Chart is receiving real-time data
- ✅ Indicator is not paused
- ✅ You're on the last bar (cleanup only runs on current bar)

---

## 📊 Performance Impact

### Benefits

✅ **Cleaner chart** - Easier to read
✅ **Better performance** - Fewer labels to render
✅ **Focused view** - See what matters now
✅ **Less confusion** - Clear which signals are recent

### Minimal Overhead

- Cleanup runs once per bar
- Very fast (milliseconds)
- No impact on indicator performance
- No impact on signal detection

---

## 🎓 Understanding the Feature

### What This Does

**Keeps your chart clean** by removing old signal labels that are no longer relevant for current trading decisions.

### What This Doesn't Do

- ❌ Doesn't delete support/resistance lines
- ❌ Doesn't delete inline labels on lines
- ❌ Doesn't affect signal detection
- ❌ Doesn't affect alerts
- ❌ Doesn't delete current signals

### Why It's Useful

**Problem:** After a few hours of trading, your chart has 50+ signal labels making it hard to see current action.

**Solution:** Auto-cleanup keeps only the last 10 bars of signals, giving you a clean, focused view.

---

## 📝 Code Changes Summary

### Files Modified
- `MSNR_Ultimate.pine` - Added auto-cleanup system

### New Components

**1. Settings (Lines 105-106):**
```pinescript
auto_delete_old_signals = input.bool(true, "Auto-Delete Old Signals")
signal_lifetime_bars = input.int(10, "Signal Lifetime (bars)")
```

**2. Tracking Arrays (Lines 521-522):**
```pinescript
var array<label> signal_labels = array.new<label>()
var array<int> signal_label_bars = array.new<int>()
```

**3. Label Tracking:**
- Entry signals: Lines 637-644
- Breakout signals: Lines 688-695

**4. Cleanup Logic (Lines 793-806):**
```pinescript
if auto_delete_old_signals and barstate.islast
    // Delete old signals
```

---

## ✅ Summary

### What Changed

✅ Added automatic cleanup of old signal labels
✅ Configurable lifetime (default: 10 bars)
✅ Can be enabled/disabled
✅ Keeps chart clean and readable

### Default Behavior

**With default settings:**
- Auto-cleanup: ON
- Lifetime: 10 bars
- Signals older than 10 bars are automatically deleted

**Result:**
- Clean chart
- Only recent signals visible
- Easy to focus on current action

### How to Use

1. **Enable** "Auto-Delete Old Signals" (default: ON)
2. **Set** "Signal Lifetime" to your preference (default: 10)
3. **Trade** with a clean, uncluttered chart!

---

**Your chart will now stay clean automatically!** 🧹✨

**Version**: 2.2  
**Date**: December 12, 2025  
**Feature**: Auto-Cleanup Old Signals

