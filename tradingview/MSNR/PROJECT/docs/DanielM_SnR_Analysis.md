# Malaysian SnR [by DanielM] - Performance Analysis & Optimization Guide

## 📊 Overview

This is a simpler, more straightforward MSNR implementation compared to the first indicator. It focuses on:
- **Resistance/Support levels** (A/V) via pivot detection
- **Gap levels** with fresh/unfresh tracking
- **Custom alerts** for level touches/crosses
- **Cleaner architecture** with fewer parallel arrays

**Code Length:** ~280 lines (vs 620 for the first MSNR)
**Complexity:** Medium (simpler logic flow, but some inefficiencies)

---

## 🔴 CRITICAL PERFORMANCE ISSUES

### **1. FUNCTION CALLED EVERY BAR WITH NESTED LOOPS (Highest Impact)**

**Location:** Lines 195-255 (`updateLineStyles()` function)

```pinescript
// Called TWICE per bar: once for resistance, once for support
updateLineStyles(resLines, resStates, true)    // Line 270
updateLineStyles(supLines, supStates, false)   // Line 273

// Inside function:
if array.size(arr) > 0 and array.size(stateArr) > 0
    for i = 0 to array.size(arr) - 1
        currentLine = array.get(arr, i)
        linePrice = line.get_y1(currentLine)   // ⚠️ Expensive operation
        lineState = array.get(stateArr, i)
        
        wickTouched = isResistance ? (high >= linePrice and low < linePrice) : (low <= linePrice and high > linePrice)
        bodyCrossed = isResistance ? (...) : (...)
        
        if wickTouched and lineState
            array.set(stateArr, i, false)
            if showOnlyFresh
                line.set_color(currentLine, color.new(...))
            else
                line.set_style(currentLine, line.style_dashed)
        
        if bodyCrossed
            array.set(stateArr, i, true)
            line.set_style(currentLine, line.style_solid)
        
        finalState = array.get(stateArr, i)    // ⚠️ Re-read after write
        if showOnlyFresh
            line.set_color(currentLine, ...)
        else
            line.set_color(currentLine, ...)
```

**Problems:**
1. **`line.get_y1()` is expensive** - Retrieves line object properties from memory
2. **Called TWICE per bar** (once for res, once for sup) with potentially 10 lines each
3. **Redundant state reads** - `array.get(stateArr, i)` called 4+ times per iteration
4. **Redundant line operations** - `line.set_color()` and `line.set_style()` called multiple times in conditional branches

**Performance Impact:** ⚠️ **SEVERE** - This is the main bottleneck

**Example Calculation:**
- 5 resistance lines + 5 support lines = 10 total lines
- Called 2x per bar = 20 array iterations per bar
- 1-minute chart, 1 year of history = ~250,000 bars = **5 million iterations**

**Optimization Strategy:**

```pinescript
// IMPROVED: Cache line price and state, reduce redundant operations
f_update_line_styles(arr, stateArr, isResistance) =>
    arr_size = array.size(arr)
    if arr_size > 0
        for i = 0 to arr_size - 1
            // Cache all reads at start
            currentLine = array.get(arr, i)
            linePrice = line.get_y1(currentLine)  // Only call once
            lineState = array.get(stateArr, i)   // Only call once
            
            // Evaluate conditions
            wickTouched = isResistance ? (high >= linePrice and low < linePrice) : (low <= linePrice and high > linePrice)
            bodyCrossed = isResistance ? ((open < linePrice and close > linePrice) or (open > linePrice and close < linePrice))
                                      : ((open > linePrice and close < linePrice) or (open < linePrice and close > linePrice))
            
            // Determine new state (calculate once)
            new_state = lineState
            needs_update = false
            
            if wickTouched and lineState
                new_state := false
                needs_update := true
            
            if bodyCrossed
                new_state := true
                needs_update := true
            
            // Apply update only once
            if needs_update
                array.set(stateArr, i, new_state)
                
                if showOnlyFresh
                    color_to_set = new_state ? (isResistance ? color.red : color.green) : color.new(isResistance ? color.red : color.green, 100)
                    line.set_color(currentLine, color_to_set)
                else
                    style_to_set = new_state ? line.style_solid : line.style_dashed
                    line.set_style(currentLine, style_to_set)
                    line.set_color(currentLine, isResistance ? color.red : color.green)
            else
                // No state change, but still apply styling if showOnlyFresh
                if showOnlyFresh
                    color_to_set = new_state ? (isResistance ? color.red : color.green) : color.new(isResistance ? color.red : color.green, 100)
                    line.set_color(currentLine, color_to_set)
```

**Estimated Improvement:** 50-65% reduction in execution time for this function

---

### **2. GAP DETECTION LOOP WITH REDUNDANT ARRAY OPERATIONS (High Impact)**

**Location:** Lines 162-190 (`detectAndDrawGaps()` function)

```pinescript
detectAndDrawGaps() =>
    for i = 1 to gapsLength  // gapsLength = 3 (typical)
        if i < bar_index
            isBullishGap = (close[i] > open[i] and close[i - 1] > open[i - 1])
            isBearishGap = (close[i] < open[i] and close[i - 1] < open[i - 1])

            if isBullishGap
                gapPrice = close[i]
                gapBar = bar_index - i

                if barstate.isconfirmed
                    gapLine = line.new(...)
                    array.push(gapLines, gapLine)      // 1st push
                    array.push(gapLevels, gapPrice)    // 2nd push
                    array.push(gapFreshStates, true)   // 3rd push
                    array.push(gapCreatedAtBars, gapBar) // 4th push
                    array.push(gapColors, color.blue)  // 5th push
                    // ⚠️ 5 separate array operations for one gap

            if isBearishGap
                // Same pattern: 5 more pushes
```

**Problems:**
1. **5 separate `array.push()` calls** per gap detection (10 per confirmed bar if both conditions met)
2. **No duplicate checking** - Could create duplicate gaps at same price
3. **Called every confirmed bar** - Multiple gaps could be detected in single candle
4. **Inefficient gap level tracking** - Storing same data in 5 different arrays instead of structured approach

**Performance Impact:** 🟡 **MEDIUM** - Adds up on high volatility

**Optimization Strategy:**

```pinescript
// IMPROVED: Batch array operations, add duplicate checking
var float last_gap_price = na
var int last_gap_bar = -100

f_detect_and_draw_gaps() =>
    if not barstate.isconfirmed
        return
    
    for i = 1 to gapsLength
        if i >= bar_index
            continue
        
        isBullishGap = (close[i] > open[i] and close[i - 1] > open[i - 1])
        isBearishGap = (close[i] < open[i] and close[i - 1] < open[i - 1])
        
        if isBullishGap or isBearishGap
            gapPrice = close[i]
            gapBar = bar_index - i
            gap_color = isBullishGap ? color.blue : #b121f3
            
            // Skip if duplicate (same price and bar recently)
            if math.abs(gapPrice - last_gap_price) < 0.0001 and bar_index - last_gap_bar < 5
                continue
            
            gapLine = line.new(x1=gapBar, y1=gapPrice, x2=bar_index, y2=gapPrice, color=gap_color, width=1, style=line.style_solid, extend=extend.right)
            
            // Batch push operations
            array.push(gapLines, gapLine)
            array.push(gapLevels, gapPrice)
            array.push(gapFreshStates, true)
            array.push(gapCreatedAtBars, gapBar)
            array.push(gapColors, gap_color)
            
            last_gap_price := gapPrice
            last_gap_bar := gapBar
    
    limitGapArraySize(gapLines, gapLevels, gapFreshStates, gapCreatedAtBars, gapColors, maxGapLines)
```

**Estimated Improvement:** 20-30% reduction in gap detection overhead

---

### **3. REDUNDANT ARRAY SIZE CHECKS & READS (Medium Impact)**

**Location:** Lines 195-210, 275-285, etc.

```pinescript
// CURRENT (Inefficient)
updateLineStyles(resLines, resStates, true)

// Inside function:
if array.size(arr) > 0 and array.size(stateArr) > 0  // 2 size checks
    for i = 0 to array.size(arr) - 1                 // 3rd size check
        currentLine = array.get(arr, i)              // Read 1
        linePrice = line.get_y1(currentLine)         
        lineState = array.get(stateArr, i)           // Read 2
        
        // ... later ...
        
        finalState = array.get(stateArr, i)          // Read 3 (redundant)
```

**Problem:**
- `array.size()` called 3+ times when could be called once
- `array.get(stateArr, i)` called 2-3 times per iteration
- Defensive programming is good, but overused here

**Optimization Strategy:**

```pinescript
// IMPROVED
f_update_line_styles(arr, stateArr, isResistance) =>
    arr_size = array.size(arr)
    state_size = array.size(stateArr)
    
    // Single check
    if arr_size == 0 or state_size == 0
        return
    
    for i = 0 to arr_size - 1
        // Cache both values once
        currentLine = array.get(arr, i)
        lineState = array.get(stateArr, i)
        linePrice = line.get_y1(currentLine)
        
        // Use cached values throughout
        wickTouched = isResistance ? (high >= linePrice and low < linePrice) : (low <= linePrice and high > linePrice)
        bodyCrossed = (...)
        
        // Determine state once
        new_state = (wickTouched and lineState) ? false : (bodyCrossed ? true : lineState)
        
        if new_state != lineState  // Only update if changed
            array.set(stateArr, i, new_state)
            // Apply styling...
```

**Estimated Improvement:** 10-15% reduction in array overhead

---

### **4. ALERT CHECKING WITH REDUNDANT LOOPS (Medium Impact)**

**Location:** Lines 285-350 (Alert checking section)

```pinescript
// CURRENT
if (enableAlertFreshAV or enableAlertUnfreshAV) and (array.size(resLines) > 0 or array.size(supLines) > 0)
    // Check Resistance Lines
    resLoopSize = minSize(resLines, resStates)
    if resLoopSize > 0
        for i = 0 to resLoopSize - 1
            resLine = array.get(resLines, i)
            resPrice = line.get_y1(resLine)           // Expensive
            resState = array.get(resStates, i)
            
            touchUp    = (high >= resPrice and low < resPrice)
            touchDown  = (low <= resPrice and high > resPrice)
            touched    = touchUp or touchDown
            
            crossUp    = (open < resPrice and close > resPrice)
            crossDown  = (open > resPrice and close < resPrice)
            crossed    = crossUp or crossDown
            
            if (touched or crossed)
                if resState and enableAlertFreshAV
                    alertFreshAVTriggered := true
                if not resState and enableAlertUnfreshAV
                    alertUnfreshAVTriggered := true
    
    // Check Support Lines - DUPLICATE LOGIC
    supLoopSize = minSize(supLines, supStates)
    if supLoopSize > 0
        for i = 0 to supLoopSize - 1
            supLine = array.get(supLines, i)
            supPrice = line.get_y1(supLine)
            supState = array.get(supStates, i)
            
            // IDENTICAL LOGIC - just repeat
            touched = (high >= supPrice and low < supPrice) or (low <= supPrice and high > supPrice)
            crossed = (open < supPrice and close > supPrice) or (open > supPrice and close < supPrice)
            
            if (touched or crossed)
                if supState and enableAlertFreshAV
                    alertFreshAVTriggered := true
                if not supState and enableAlertUnfreshAV
                    alertUnfreshAVTriggered := true
```

**Problems:**
1. **Duplicate logic** - Resistance and support checking is nearly identical
2. **Called every bar** - Even if no levels exist
3. **Multiple `line.get_y1()` calls** - Expensive line object access
4. **Redundant variable creation** - `touchUp`, `touchDown`, `touched` when simpler logic suffices

**Optimization Strategy:**

```pinescript
// IMPROVED: Combine resistance and support checking into single function
f_check_level_interactions(lineArr, stateArr, alert_fresh_flag, alert_unfresh_flag) =>
    arr_size = array.size(lineArr)
    if arr_size == 0
        return [false, false]
    
    fresh_triggered = false
    unfresh_triggered = false
    
    for i = 0 to arr_size - 1
        // Single cache operation
        linePrice = line.get_y1(array.get(lineArr, i))
        levelState = array.get(stateArr, i)
        
        // Simplified condition
        is_touched_or_crossed = (high >= linePrice and low <= linePrice) or 
                                ((open < linePrice and close > linePrice) or 
                                 (open > linePrice and close < linePrice))
        
        if is_touched_or_crossed
            fresh_triggered := fresh_triggered or (levelState and alert_fresh_flag)
            unfresh_triggered := unfresh_triggered or (not levelState and alert_unfresh_flag)
    
    [fresh_triggered, unfresh_triggered]

// Usage
if (enableAlertFreshAV or enableAlertUnfreshAV)
    [fresh_res, unfresh_res] = f_check_level_interactions(resLines, resStates, enableAlertFreshAV, enableAlertUnfreshAV)
    [fresh_sup, unfresh_sup] = f_check_level_interactions(supLines, supStates, enableAlertFreshAV, enableAlertUnfreshAV)
    
    alertFreshAVTriggered := fresh_res or fresh_sup
    alertUnfreshAVTriggered := unfresh_res or unfresh_sup
    
    if (enableAlertFreshGaps or enableAlertUnfreshGaps) and array.size(gapLines) > 0
        [fresh_gaps, unfresh_gaps] = f_check_level_interactions(gapLines, gapFreshStates, enableAlertFreshGaps, enableAlertUnfreshGaps)
        alertFreshGapsTriggered := fresh_gaps
        alertUnfreshGapsTriggered := unfresh_gaps
```

**Estimated Improvement:** 40-50% reduction in alert checking logic

---

## 🟡 MODERATE ISSUES

### **5. `limitLineArraySize()` WITH SHIFT OPERATIONS (Medium Impact)**

**Location:** Lines 112-123, 127-138

```pinescript
limitLineArraySize(arr, stateArr, maxSize) =>
    while array.size(arr) > maxSize
        if array.size(arr) > 0
            lineToRemove = array.shift(arr)    // ⚠️ O(n) operation
            if not na(lineToRemove)
                line.delete(lineToRemove)
            array.shift(stateArr)              // Another O(n) operation

limitGapArraySize(arr, levelArr, stateArr, gapCreatedAtBars, colorArr, maxSize) =>
    while array.size(arr) > maxSize
        if array.size(arr) > 0
            lineToRemove = array.shift(arr)    // Remove first element
        if array.size(levelArr) > 0
            array.shift(levelArr)              // 5 separate shift operations
        if array.size(stateArr) > 0
            array.shift(stateArr)
        if array.size(gapCreatedAtBars) > 0
            array.shift(gapCreatedAtBars)
        if array.size(colorArr) > 0
            array.shift(colorArr)
```

**Problems:**
1. **`array.shift()` is O(n)** - Removes first element and shifts all others
2. **Multiple shift calls** - 5 separate O(n) operations in gap limiting function
3. **While loop** - If max exceeded by multiple, could be very slow
4. **Could accumulate** - On volatile markets with many gaps, could trigger multiple times per bar

**Performance Impact:** 🟡 **MEDIUM** - Only when limits exceeded, but can be severe

**Optimization Strategy:**

```pinescript
// IMPROVED: Use index tracking instead of shift
var int gap_start_idx = 0

f_trim_gaps_by_index(maxSize) =>
    total_gaps = array.size(gapLines) - gap_start_idx
    if total_gaps > maxSize
        to_delete = total_gaps - maxSize
        
        for j = 0 to to_delete - 1
            idx = gap_start_idx
            if idx < array.size(gapLines)
                ln = array.get(gapLines, idx)
                if not na(ln)
                    line.delete(ln)
        
        gap_start_idx += to_delete

// Alternative: Use pop/unshift-free approach
f_limit_size_safe(arr, stateArr, maxSize) =>
    while array.size(arr) > maxSize
        idx_to_remove = 0  // Remove oldest (front)
        if idx_to_remove < array.size(arr)
            line.delete(array.get(arr, idx_to_remove))
            array.remove(arr, idx_to_remove)
            if idx_to_remove < array.size(stateArr)
                array.remove(stateArr, idx_to_remove)
```

**Estimated Improvement:** 30-40% when array limiting occurs

---

### **6. CONDITIONAL NESTING WITH REPEATED LOGIC (Low-Medium Impact)**

**Location:** Lines 70-100 (Line style updating)

```pinescript
if wickTouched and lineState
    array.set(stateArr, i, false)
    if showOnlyFresh
        line.set_color(currentLine, color.new(isResistance ? color.red : color.green, 100))
    else
        line.set_style(currentLine, line.style_dashed)

if bodyCrossed
    array.set(stateArr, i, true)
    line.set_style(currentLine, line.style_solid)

finalState = array.get(stateArr, i)
if showOnlyFresh
    if finalState
        line.set_color(currentLine, isResistance ? color.red : color.green)
    else
        line.set_color(currentLine, color.new(isResistance ? color.red : color.green, 100))
else
    line.set_color(currentLine, isResistance ? color.red : color.green)
```

**Problems:**
1. **Color computation repeated** - `isResistance ? color.red : color.green` computed 3+ times
2. **State updated then read** - Set state, then immediately read it back
3. **Conditional nesting** - Multiple if/else blocks doing similar things

**Optimization Strategy:**

```pinescript
// IMPROVED: Compute once, use cached values
if wickTouched and lineState
    array.set(stateArr, i, false)
    new_state := false
else if bodyCrossed
    array.set(stateArr, i, true)
    new_state := true

// Compute color once
base_color = isResistance ? color.red : color.green
final_color = new_state ? base_color : color.new(base_color, 100)

if showOnlyFresh
    line.set_color(currentLine, final_color)
else
    if not new_state
        line.set_style(currentLine, line.style_dashed)
    else
        line.set_style(currentLine, line.style_solid)
```

**Estimated Improvement:** 5-10% reduction in color/style operations

---

## 🟢 MINOR ISSUES

### **7. HELPER FUNCTION `minSize()` - Trivial Optimization**

**Location:** Line 264

```pinescript
minSize(arr1, arr2) =>
    math.min(array.size(arr1), array.size(arr2))
```

**Issue:** Simple wrapper that could be inlined, but negligible performance impact.

---

## 📊 COMPARISON: DanielM vs MSNR Indicator

| Aspect | DanielM | MSNR (Original) |
|--------|---------|-----------------|
| Lines of Code | ~280 | ~620 |
| Parallel Arrays | 2 (res) + 2 (sup) + 5 (gap) = 9 | 11 |
| Array Iterations/Bar | 10-20 | 100+ |
| HTF Support | ❌ No | ✅ Yes |
| Gap Detection | ✅ Yes | ✅ Yes |
| QM Levels | ❌ No | ✅ Yes |
| Alerts | ✅ Basic | ❌ No |
| **Overall Performance** | ⭐⭐⭐⭐ Better | ⭐⭐⭐ Slower |
| **Simplicity** | ⭐⭐⭐⭐⭐ | ⭐⭐⭐ |

**DanielM indicator is simpler but has concentrated bottlenecks. MSNR is feature-rich but spread-out complexity.**

---

## 🎯 OPTIMIZATION PRIORITY

| Issue | Severity | Impact | Effort | Priority |
|-------|----------|--------|--------|----------|
| updateLineStyles loop | 🔴 CRITICAL | 50-65% | Medium | 1️⃣ |
| Alert checking loops | 🟡 MEDIUM | 40-50% | Easy | 2️⃣ |
| Gap detection redundancy | 🟡 MEDIUM | 20-30% | Easy | 3️⃣ |
| Array limiting with shift | 🟡 MEDIUM | 30-40% | Medium | 4️⃣ |
| Array size caching | 🟡 MEDIUM | 10-15% | Trivial | 5️⃣ |
| Color/style optimization | 🟢 LOW | 5-10% | Trivial | 6️⃣ |

---

## 📈 ESTIMATED IMPROVEMENTS

**Best Case (All optimizations):** **60-75% improvement**
- Critical issues: 50-65% + 40-50% = 90-115% cumulative
- But overlapping benefits reduce to ~65%

**Realistic Case (High-impact only):** **50-65% improvement**
- Focus on updateLineStyles, alert checking, array limiting

**Quick Wins (10 min implementation):** **20-30% improvement**
- Cache array values in updateLineStyles
- Consolidate alert logic
- Optimize color computation

---

## ⚠️ SPECIFIC BOTTLENECK ANALYSIS

Without actual profiling, estimated CPU time distribution:

- **updateLineStyles() calls (lines 270-273):** 45-50% of total time
  - 20 array iterations (10 lines × 2 functions)
  - `line.get_y1()` calls (expensive)
  - Multiple state reads/writes
  
- **Gap freshness updates (lines 255-262):** 15-20% of total time
  - Loop through all gap levels
  - Multiple array operations
  - Gap state checking
  
- **Alert checking (lines 285-350):** 20-25% of total time
  - Duplicate resistance/support logic
  - Multiple `line.get_y1()` calls
  - Redundant condition evaluation
  
- **Array limiting (lines 112-138):** 5-10% of total time
  - Only when limits exceeded
  - `array.shift()` is O(n)
  
- **Other (gap detection, initialization):** 5-10% of total time

**updateLineStyles is your bottleneck—fix it first.**

---

## 💡 KEY INSIGHTS

**DanielM's Code Strengths:**
1. ✅ Simple, readable structure
2. ✅ Clear separation of concerns
3. ✅ Good alert functionality
4. ✅ Efficient compared to MSNR for basic use

**DanielM's Code Weaknesses:**
1. ❌ Centralized bottleneck in updateLineStyles
2. ❌ Duplicated logic in alert checking
3. ❌ Inefficient array shift operations
4. ❌ Missing HTF and QM level support
5. ❌ No sophisticated freshness logic

**Best Use Case:**
- Simpler markets (fewer levels)
- Slower timeframes (4H+)
- Users who want alerts above all else

**When to Choose This Over MSNR:**
- Need clear, understandable code
- Want built-in alerts (MSNR has none)
- Don't need HTF analysis
- Prefer simplicity over features

