# Wick Rejection S/R Strategy v2 - Changelog

## Version 2.0 - Optimization & Bug Fixes
**Date**: 2024-12-14

---

## 🐛 Bug Fixes

### 1. **Pine Script Compilation Error**
- **Issue**: `Cannot modify global variable 'levels_changed' in function`
- **Fix**: Refactored `f_add_or_update_support()`, `f_add_or_update_resistance()`, and `f_expire_old_levels()` to **return boolean** instead of modifying global
- **Impact**: None - functions work identically, just return `true`/`false` for caller to update global
- **Files**: Line 188, 212, 225, 234 → Now returns `changed` flag

---

## 🎨 Visual Improvements

### 2. **Signal Label Clutter Fixed**
**Before**: Multi-line labels with 5+ lines of text causing chart overlap
**After**: Compact single-line labels

#### New Format:
```
🔥 BUY SWEEP @4335.79 | SL:4330.89
⚡ SELL ZONE @4301.64 | SL:4304.91
⚠ BUY B/R @4297.23 | SL:4295.18
```

**Changes**:
- Emojis for confidence: 🔥 = HIGH (4-5), ⚡ = MED (3), ⚠ = LOW (1-2)
- Signal type abbreviations: `ZONE`, `SWEEP`, `B/R` (Breakout/Retest)
- Single line with `@level | SL:stop`
- Removed "Entry" (redundant - close price implied)
- Removed multi-line "Conf: HIGH/MED/LOW" text

### 3. **Signal Label Limit**
- **New Input**: `Max Signal Labels` (default: 5, range: 3-10)
- Automatically deletes oldest label when limit exceeded
- Uses `array.shift()` to remove from tracking array
- Prevents chart clutter from hundreds of historical labels

---

## ⚙️ Performance Improvements

### 4. **Reduced Signal Frequency**
- **Changed**: `signal_cooldown` default from `5` to `8` bars
- **Impact**: ~38% fewer signals per level
- Prevents rapid-fire signals at same level
- Still catches meaningful retests/sweeps

### 5. **EMA Filter Already Working Correctly**
- ✅ **Verified**: Lines 438, 447 enforce `overall_bullish`/`overall_bearish` when `use_ema_filter = true`
- BUY signals **require** `overall_bullish` (M5 bullish + H1 confluence if enabled)
- SELL signals **require** `overall_bearish` (M5 bearish + H1 confluence if enabled)
- **No changes needed** - filter was already strict

---

## 📊 Technical Details

### Signal Generation Flow:
1. **Detect** levels at support/resistance based on wick rejections
2. **Check** for sweeps (priority 1) or zone tests (priority 2)
3. **Calculate** confidence (1-5) based on touches, EMA, H1, wick strength
4. **Filter** through `overall_bullish`/`overall_bearish` if `use_ema_filter = true`
5. **Apply** cooldown to prevent duplicate signals
6. **Display** compact label and limit to `max_signal_labels`

### Bias Logic (Unchanged):
```pinescript
overall_bullish = m5_bullish AND (h1_bullish OR not require_h1_align)
overall_bearish = m5_bearish AND (h1_bearish OR not require_h1_align)

m5_bullish = close > ema_9
m5_bearish = close < ema_9
h1_bullish = h1_close > h1_ema9
h1_bearish = h1_close < h1_ema9
```

---

## 🎯 User Settings Reference

### Recommended Settings for Clean Chart:
- **Signal Cooldown**: 8-10 bars (reduce noise)
- **Min Confidence**: 3 (only show medium/high quality)
- **Max Signal Labels**: 5 (keep chart readable)
- **Max Levels**: 4-6 (focus on strongest S/R)
- **Use EMA Filter**: ✅ (strict directional bias)
- **Require H1 Confluence**: ✅ (higher timeframe confirmation)

### For Aggressive Scalping:
- **Signal Cooldown**: 5 bars
- **Min Confidence**: 2
- **Max Signal Labels**: 8
- **Use EMA Filter**: ❌ (allow counter-trend)

---

## 📝 Files Modified

1. `wick_rejection_sr_strategy_v2.pine`
   - Line 38: `signal_cooldown` default → 8
   - Line 39: Added `max_signal_labels` input
   - Lines 165-213: Functions now return `changed` boolean
   - Lines 243-248: Callers update `levels_changed` from return values
   - Lines 660-698: Complete rewrite of signal label logic (compact + limit)

2. `CHANGELOG_v2.md` (this file)
   - New documentation of changes

---

## ✅ Verification Checklist

- [x] No compilation errors
- [x] No linter warnings
- [x] Signal labels are compact (single line)
- [x] Label limit enforced (max 5 default)
- [x] Signal cooldown increased (8 bars)
- [x] EMA filter working correctly
- [x] No BUY signals when bearish (verified by user screenshot)
- [x] All core features working (levels, zones, EMA, table, signals)

---

## 🚀 Next Steps (Optional Future Enhancements)

1. **Dynamic Stop Loss**: Calculate SL based on recent ATR instead of fixed zone_buffer
2. **Take Profit Targets**: Add TP1 (1:1.5), TP2 (1:2.5) to labels
3. **Win Rate Display**: Track and show success rate in info table
4. **Alert Automation**: Webhook support for trade automation
5. **Session Filters**: Only trade during specific sessions (London/NY)

---

## 📞 Support

For issues or suggestions, refer to the Pine Script rules in `.cursor/rules/pinescript.md`

**Version**: 2.0  
**Last Updated**: 2024-12-14  
**Status**: ✅ Production Ready

