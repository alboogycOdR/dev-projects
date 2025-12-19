# Technical Specification: ICT Forever Model Enhancements

**Document Version:** 1.0  
**Date:** December 2024  
**Base Script Version:** Forever Model (Pine Script v6)  
**Author:** KingdomFinancier  

---

## Table of Contents

1. [Executive Summary](#1-executive-summary)
2. [Enhancement 1: Session Filtering](#2-enhancement-1-session-filtering)
3. [Enhancement 2: Optimal Trade Entry (OTE) Levels](#3-enhancement-2-optimal-trade-entry-ote-levels)
4. [Enhancement 3: Time-Based FVG Invalidation](#4-enhancement-3-time-based-fvg-invalidation)
5. [Enhancement 4: Killzone Highlighting](#5-enhancement-4-killzone-highlighting)
6. [Integration Requirements](#6-integration-requirements)
7. [Testing Requirements](#7-testing-requirements)
8. [Appendix: ICT Session Reference](#8-appendix-ict-session-reference)

---

## 1. Executive Summary

This specification defines four enhancements to the existing ICT Forever Trading Model indicator. These features add session-based filtering, Fibonacci OTE levels, time-based FVG decay, and visual killzone boxes to align more closely with ICT methodology.

### Priority Order
1. **Killzone Highlighting** (visual foundation)
2. **Session Filtering** (core logic dependency on killzones)
3. **Time-Based FVG Invalidation** (independent feature)
4. **OTE Levels** (enhancement to existing FVG display)

### Estimated Complexity
| Enhancement | Complexity | New Lines (Est.) |
|-------------|------------|------------------|
| Session Filtering | Medium | 150-200 |
| OTE Levels | Medium | 100-150 |
| Time-Based Invalidation | Low | 80-120 |
| Killzone Highlighting | Medium | 200-250 |

---

## 2. Enhancement 1: Session Filtering

### 2.1 Overview

Implement session-based filtering to restrict signal generation, FVG detection, and/or confirmations to specific ICT trading sessions. ICT methodology emphasizes that institutional activity concentrates during London and New York sessions.

### 2.2 Input Parameters

Add to a new input group `'Session Filter'`:

```pinescript
// Session Filter Settings
enableSessionFilter = input.bool(false, 'Enable Session Filter', group = 'Session Filter', tooltip = 'Only allow signals during selected sessions')

filterMode = input.string('Signals Only', 'Filter Mode', options = ['Signals Only', 'FVGs and Signals', 'Confirmations Only'], group = 'Session Filter', tooltip = 'Signals Only: FVGs form anytime, signals only in session. FVGs and Signals: Both restricted. Confirmations Only: Pending signals form anytime, confirmation must be in session.')

// Individual session toggles
asianSessionEnabled = input.bool(false, 'Asian Session (20:00-00:00 NY)', group = 'Session Filter')
londonSessionEnabled = input.bool(true, 'London Session (02:00-05:00 NY)', group = 'Session Filter')
nyAmSessionEnabled = input.bool(true, 'NY AM Session (07:00-10:00 NY)', group = 'Session Filter')
nyLunchEnabled = input.bool(false, 'NY Lunch (12:00-13:00 NY)', group = 'Session Filter')
nyPmSessionEnabled = input.bool(false, 'NY PM Session (13:30-16:00 NY)', group = 'Session Filter')

// Custom session option
useCustomSession = input.bool(false, 'Use Custom Session', group = 'Session Filter')
customSessionStart = input.session('0700-1000', 'Custom Session Time', group = 'Session Filter')

// Timezone setting
sessionTimezone = input.string('America/New_York', 'Session Timezone', options = ['America/New_York', 'Europe/London', 'Asia/Tokyo', 'Asia/Hong_Kong', 'Australia/Sydney', 'UTC'], group = 'Session Filter')
```

### 2.3 Data Structures

```pinescript
// Session definition type
type SessionDef
    int startHour
    int startMinute
    int endHour
    int endMinute
    string name
    color sessionColor
```

### 2.4 Core Functions

#### 2.4.1 Session Time Check Function

```pinescript
// Returns true if current bar is within any enabled session
isInSession() =>
    if not enableSessionFilter
        true
    else
        // Get current time in session timezone
        int currentHour = hour(time, sessionTimezone)
        int currentMinute = minute(time, sessionTimezone)
        int currentTimeMinutes = currentHour * 60 + currentMinute
        
        bool inSession = false
        
        // Check Asian (20:00-00:00) - crosses midnight
        if asianSessionEnabled
            int asianStart = 20 * 60  // 1200 minutes
            int asianEnd = 24 * 60    // 1440 minutes (midnight)
            if currentTimeMinutes >= asianStart or currentTimeMinutes < 0
                inSession := true
        
        // Check London (02:00-05:00)
        if londonSessionEnabled
            int londonStart = 2 * 60   // 120 minutes
            int londonEnd = 5 * 60     // 300 minutes
            if currentTimeMinutes >= londonStart and currentTimeMinutes < londonEnd
                inSession := true
        
        // Check NY AM (07:00-10:00)
        if nyAmSessionEnabled
            int nyAmStart = 7 * 60     // 420 minutes
            int nyAmEnd = 10 * 60      // 600 minutes
            if currentTimeMinutes >= nyAmStart and currentTimeMinutes < nyAmEnd
                inSession := true
        
        // Check NY Lunch (12:00-13:00)
        if nyLunchEnabled
            int nyLunchStart = 12 * 60  // 720 minutes
            int nyLunchEnd = 13 * 60    // 780 minutes
            if currentTimeMinutes >= nyLunchStart and currentTimeMinutes < nyLunchEnd
                inSession := true
        
        // Check NY PM (13:30-16:00)
        if nyPmSessionEnabled
            int nyPmStart = 13 * 60 + 30  // 810 minutes
            int nyPmEnd = 16 * 60         // 960 minutes
            if currentTimeMinutes >= nyPmStart and currentTimeMinutes < nyPmEnd
                inSession := true
        
        // Check custom session
        if useCustomSession
            inSession := inSession or not na(time(timeframe.period, customSessionStart, sessionTimezone))
        
        inSession
```

#### 2.4.2 Session-Specific Check Functions

```pinescript
// Check if in specific named session (for killzone coloring)
isInSpecificSession(string sessionName) =>
    int currentHour = hour(time, sessionTimezone)
    int currentMinute = minute(time, sessionTimezone)
    int currentTimeMinutes = currentHour * 60 + currentMinute
    
    switch sessionName
        'Asian' => currentTimeMinutes >= 1200 or currentTimeMinutes < 0
        'London' => currentTimeMinutes >= 120 and currentTimeMinutes < 300
        'NY AM' => currentTimeMinutes >= 420 and currentTimeMinutes < 600
        'NY Lunch' => currentTimeMinutes >= 720 and currentTimeMinutes < 780
        'NY PM' => currentTimeMinutes >= 810 and currentTimeMinutes < 960
        => false
```

### 2.5 Integration Points

#### 2.5.1 FVG Detection Filter

Modify the FVG detection block (around line 1087):

```pinescript
// BEFORE (existing):
if htfHasBearishFVG and shouldDetectBearish and not na(htfBearishBottom) and not na(htfBearishTop)

// AFTER (with session filter):
bool sessionAllowsFVG = not enableSessionFilter or filterMode == 'Signals Only' or filterMode == 'Confirmations Only' or isInSession()

if htfHasBearishFVG and shouldDetectBearish and not na(htfBearishBottom) and not na(htfBearishTop) and sessionAllowsFVG
```

Apply same pattern to bullish FVG detection.

#### 2.5.2 Pending Signal Creation Filter

Modify pending signal creation (around line 1316):

```pinescript
// BEFORE:
if r.canCreateSignalFromHigh
    // High (bottom) mitigated - create BEARISH signal
    if not na(pivotLow) and not na(pivotLowBar)
        pendingBearish := PendingSignal.new()

// AFTER:
bool sessionAllowsSignal = not enableSessionFilter or filterMode == 'Confirmations Only' or isInSession()

if r.canCreateSignalFromHigh and sessionAllowsSignal
    // High (bottom) mitigated - create BEARISH signal
    if not na(pivotLow) and not na(pivotLowBar)
        pendingBearish := PendingSignal.new()
```

#### 2.5.3 Signal Confirmation Filter

Modify confirmation logic (around line 1562):

```pinescript
// BEFORE:
if not na(pendingBearish)
    if close < pendingBearish.confirmationLevel

// AFTER:
bool sessionAllowsConfirmation = not enableSessionFilter or filterMode == 'Signals Only' or isInSession()

if not na(pendingBearish) and sessionAllowsConfirmation
    if close < pendingBearish.confirmationLevel
```

### 2.6 Dashboard Integration

Add session status to dashboard (row 4 or new row):

```pinescript
// In dashboard section
if enableSessionFilter
    string sessionStatus = isInSession() ? "IN SESSION" : "OUT OF SESSION"
    string currentSession = ""
    if isInSpecificSession('London')
        currentSession := "London"
    else if isInSpecificSession('NY AM')
        currentSession := "NY AM"
    else if isInSpecificSession('NY PM')
        currentSession := "NY PM"
    else if isInSpecificSession('Asian')
        currentSession := "Asian"
    else if isInSpecificSession('NY Lunch')
        currentSession := "NY Lunch"
    else
        currentSession := "None"
    
    string sessionText = sessionStatus + " (" + currentSession + ")"
    // Add to dashboard table
```

### 2.7 Edge Cases

1. **Weekend handling**: Sessions should not activate on weekends. Add day-of-week check:
   ```pinescript
   int dow = dayofweek(time, sessionTimezone)
   bool isWeekday = dow >= dayofweek.monday and dow <= dayofweek.friday
   ```

2. **DST transitions**: Using named timezone handles DST automatically.

3. **Crypto markets**: For 24/7 markets, sessions still apply (institutional activity patterns persist).

4. **HTF bars spanning sessions**: If an HTF bar spans multiple sessions, consider it "in session" if any part overlaps.

---

## 3. Enhancement 2: Optimal Trade Entry (OTE) Levels

### 3.1 Overview

Add Fibonacci retracement levels within FVG zones to identify optimal entry points. ICT's OTE zone is typically the 62-79% retracement of a swing, but applied to FVGs, we'll show key levels within the gap.

### 3.2 Input Parameters

Add to new input group `'OTE Levels'`:

```pinescript
// OTE Settings
showOTELevels = input.bool(false, 'Show OTE Levels', group = 'OTE Levels', tooltip = 'Display Fibonacci retracement levels within FVG zones')

oteDisplayMode = input.string('Active FVGs Only', 'Display Mode', options = ['Active FVGs Only', 'All FVGs', 'Latest FVG Only'], group = 'OTE Levels')

// Level toggles and values
showOTE_0 = input.bool(true, 'Show 0% (FVG Edge)', group = 'OTE Levels')
showOTE_50 = input.bool(true, 'Show 50% (Equilibrium)', group = 'OTE Levels')
showOTE_618 = input.bool(true, 'Show 61.8% (OTE Start)', group = 'OTE Levels')
showOTE_705 = input.bool(true, 'Show 70.5% (OTE Sweet Spot)', group = 'OTE Levels')
showOTE_79 = input.bool(true, 'Show 79% (OTE End)', group = 'OTE Levels')
showOTE_100 = input.bool(true, 'Show 100% (FVG Edge)', group = 'OTE Levels')

// Custom levels (optional)
useCustomOTELevels = input.bool(false, 'Use Custom Levels', group = 'OTE Levels')
customOTELevel1 = input.float(0.62, 'Custom Level 1', minval = 0, maxval = 1, step = 0.01, group = 'OTE Levels')
customOTELevel2 = input.float(0.705, 'Custom Level 2', minval = 0, maxval = 1, step = 0.01, group = 'OTE Levels')
customOTELevel3 = input.float(0.79, 'Custom Level 3', minval = 0, maxval = 1, step = 0.01, group = 'OTE Levels')

// Visual settings
oteLevelStyle = input.string('Dotted', 'Level Line Style', options = ['Solid', 'Dotted', 'Dashed'], group = 'OTE Levels')
oteLevelWidth = input.int(1, 'Level Line Width', minval = 1, maxval = 3, group = 'OTE Levels')
oteShowLabels = input.bool(true, 'Show Level Labels', group = 'OTE Levels')
oteLabelSize = input.string(size.tiny, 'Label Size', options = [size.tiny, size.small, size.normal], group = 'OTE Levels')
oteTransparency = input.int(30, 'Level Transparency', minval = 0, maxval = 100, group = 'OTE Levels')

// OTE Zone highlight
highlightOTEZone = input.bool(true, 'Highlight OTE Zone (61.8-79%)', group = 'OTE Levels')
oteZoneColor = input.color(color.new(color.orange, 85), 'OTE Zone Color', group = 'OTE Levels')
```

### 3.3 Data Structure Modifications

Extend the `Range` type to include OTE line references:

```pinescript
// Add to existing Range type
type Range
    // ... existing fields ...
    array<line> oteLines      // Array of OTE level lines
    array<label> oteLabels    // Array of OTE level labels
    box oteZoneBox            // OTE zone highlight box (61.8-79%)
```

### 3.4 Core Functions

#### 3.4.1 OTE Level Calculator

```pinescript
// Calculate OTE levels for an FVG
// For Bullish FVG: 0% = bottom (rangeHigh), 100% = top (rangeLow)
// For Bearish FVG: 0% = top (rangeLow), 100% = bottom (rangeHigh)
calculateOTELevel(float fvgBottom, float fvgTop, float level, bool isBullishFVG) =>
    float range = math.abs(fvgTop - fvgBottom)
    float price = na
    
    if isBullishFVG
        // Bullish: price enters from bottom, moves up
        // 0% = bottom, 100% = top
        price := fvgBottom + (range * level)
    else
        // Bearish: price enters from top, moves down
        // 0% = top, 100% = bottom
        price := fvgTop - (range * level)
    
    price
```

#### 3.4.2 OTE Lines Creation Function

```pinescript
// Create OTE lines for a range
createOTELines(Range r, bool isBullishFVG) =>
    if showOTELevels and not r.isSpecial
        // Initialize arrays if needed
        if na(r.oteLines)
            r.oteLines := array.new<line>()
        if na(r.oteLabels)
            r.oteLabels := array.new<label>()
        
        float fvgBottom = r.rangeHigh  // In FVG terms, rangeHigh is the bottom
        float fvgTop = r.rangeLow      // rangeLow is the top
        
        // Get line style
        string lineStyle = switch oteLevelStyle
            'Solid' => line.style_solid
            'Dotted' => line.style_dotted
            'Dashed' => line.style_dashed
            => line.style_dotted
        
        // Determine start time (use high or low start time based on FVG type)
        int startTime = isBullishFVG ? r.highStartTime : r.lowStartTime
        
        // Define levels to draw
        array<float> levels = array.new<float>()
        array<string> levelNames = array.new<string>()
        
        if useCustomOTELevels
            array.push(levels, customOTELevel1)
            array.push(levelNames, str.tostring(customOTELevel1 * 100, '#.#') + '%')
            array.push(levels, customOTELevel2)
            array.push(levelNames, str.tostring(customOTELevel2 * 100, '#.#') + '%')
            array.push(levels, customOTELevel3)
            array.push(levelNames, str.tostring(customOTELevel3 * 100, '#.#') + '%')
        else
            if showOTE_0
                array.push(levels, 0.0)
                array.push(levelNames, '0%')
            if showOTE_50
                array.push(levels, 0.5)
                array.push(levelNames, '50%')
            if showOTE_618
                array.push(levels, 0.618)
                array.push(levelNames, '61.8%')
            if showOTE_705
                array.push(levels, 0.705)
                array.push(levelNames, '70.5%')
            if showOTE_79
                array.push(levels, 0.79)
                array.push(levelNames, '79%')
            if showOTE_100
                array.push(levels, 1.0)
                array.push(levelNames, '100%')
        
        // Get base color from FVG type
        color baseColor = isBullishFVG ? bullishFVGColor : bearishFVGColor
        color levelColor = color.new(baseColor, oteTransparency)
        
        // Create lines for each level
        for i = 0 to array.size(levels) - 1
            float level = array.get(levels, i)
            string levelName = array.get(levelNames, i)
            float price = calculateOTELevel(fvgBottom, fvgTop, level, isBullishFVG)
            
            // Determine end time (mitigation time or current)
            bool isFullyMitigated = r.highMitigated and r.lowMitigated
            int endTime = isFullyMitigated ? math.max(nz(r.highMitigationTime, time), nz(r.lowMitigationTime, time)) : time
            
            // Create line
            line newLine = line.new(startTime, price, endTime, price, xloc = xloc.bar_time, color = levelColor, style = lineStyle, width = oteLevelWidth)
            array.push(r.oteLines, newLine)
            
            // Create label if enabled
            if oteShowLabels
                label newLabel = label.new(endTime, price, levelName, xloc = xloc.bar_time, style = label.style_label_left, color = color.new(color.white, 100), textcolor = levelColor, size = oteLabelSize)
                array.push(r.oteLabels, newLabel)
        
        // Create OTE zone box (61.8% - 79%)
        if highlightOTEZone
            float oteZoneStart = calculateOTELevel(fvgBottom, fvgTop, 0.618, isBullishFVG)
            float oteZoneEnd = calculateOTELevel(fvgBottom, fvgTop, 0.79, isBullishFVG)
            int zoneEndTime = (r.highMitigated and r.lowMitigated) ? math.max(nz(r.highMitigationTime, time), nz(r.lowMitigationTime, time)) : time
            
            r.oteZoneBox := box.new(startTime, math.max(oteZoneStart, oteZoneEnd), zoneEndTime, math.min(oteZoneStart, oteZoneEnd), border_color = na, bgcolor = oteZoneColor, xloc = xloc.bar_time)
```

#### 3.4.3 OTE Lines Update Function

```pinescript
// Update OTE lines for a range (called each bar)
updateOTELines(Range r, bool isBullishFVG) =>
    if showOTELevels and not r.isSpecial and array.size(r.oteLines) > 0
        // Determine end time
        bool isFullyMitigated = r.highMitigated and r.lowMitigated
        int endTime = isFullyMitigated ? math.max(nz(r.highMitigationTime, time), nz(r.lowMitigationTime, time)) : time
        
        // Update all lines
        for i = 0 to array.size(r.oteLines) - 1
            line l = array.get(r.oteLines, i)
            line.set_x2(l, endTime)
        
        // Update all labels
        if oteShowLabels and array.size(r.oteLabels) > 0
            for i = 0 to array.size(r.oteLabels) - 1
                label lbl = array.get(r.oteLabels, i)
                label.set_x(lbl, endTime)
        
        // Update zone box
        if highlightOTEZone and not na(r.oteZoneBox)
            box.set_right(r.oteZoneBox, endTime)
```

#### 3.4.4 OTE Lines Cleanup Function

```pinescript
// Clean up OTE lines when range is deleted
cleanupOTELines(Range r) =>
    if array.size(r.oteLines) > 0
        for i = array.size(r.oteLines) - 1 to 0
            line.delete(array.get(r.oteLines, i))
        array.clear(r.oteLines)
    
    if array.size(r.oteLabels) > 0
        for i = array.size(r.oteLabels) - 1 to 0
            label.delete(array.get(r.oteLabels, i))
        array.clear(r.oteLabels)
    
    if not na(r.oteZoneBox)
        box.delete(r.oteZoneBox)
        r.oteZoneBox := na
```

### 3.5 Integration Points

#### 3.5.1 On FVG Creation

After creating a new Range (around line 1115 for bearish, 1170 for bullish):

```pinescript
// After: array.push(ranges, newRange)
// Add:
if showOTELevels
    createOTELines(newRange, false)  // false for bearish FVG
```

#### 3.5.2 On Range Drawing Loop

In the range drawing loop (around line 1420), add OTE update call:

```pinescript
// Inside the drawing loop for ranges
if showOTELevels and not r.isSpecial
    bool isBullishFVG = r.canCreateSignalFromLow
    updateOTELines(r, isBullishFVG)
```

#### 3.5.3 On Range Deletion

Modify `cleanupFVGBoxes` to also clean OTE lines, or call separately:

```pinescript
// When deleting a range
cleanupFVGBoxes(r)
cleanupOTELines(r)
array.remove(ranges, i)
```

### 3.6 Display Mode Implementation

```pinescript
// In range drawing loop
bool shouldShowOTE = false

if showOTELevels and not r.isSpecial
    switch oteDisplayMode
        'Active FVGs Only' =>
            shouldShowOTE := not (r.highMitigated and r.lowMitigated)
        'All FVGs' =>
            shouldShowOTE := true
        'Latest FVG Only' =>
            // Check if this is the latest FVG
            bool isLatestBullish = r.canCreateSignalFromLow and r.creationBar == latestBullishFVGBar
            bool isLatestBearish = r.canCreateSignalFromHigh and r.creationBar == latestBearishFVGBar
            shouldShowOTE := isLatestBullish or isLatestBearish

    if shouldShowOTE
        updateOTELines(r, r.canCreateSignalFromLow)
    else
        // Hide OTE lines (set transparency to 100)
        hideOTELines(r)
```

### 3.7 Edge Cases

1. **Very small FVGs**: If FVG range is less than 5 * mintick, skip OTE levels (too crowded).

2. **Label overlap**: When multiple levels are close together, consider hiding some labels or using a single combined label.

3. **Mitigated FVGs**: Stop extending OTE lines at mitigation time.

---

## 4. Enhancement 3: Time-Based FVG Invalidation

### 4.1 Overview

Implement automatic FVG invalidation based on time elapsed since creation. ICT theory suggests FVGs lose relevance if not filled within a reasonable timeframe. This feature adds gradual transparency fading and eventual deletion.

### 4.2 Input Parameters

Add to new input group `'FVG Time Decay'`:

```pinescript
// Time Decay Settings
enableTimeDecay = input.bool(false, 'Enable Time-Based Decay', group = 'FVG Time Decay', tooltip = 'FVGs fade and eventually invalidate over time')

decayTimeUnit = input.string('HTF Candles', 'Decay Time Unit', options = ['HTF Candles', 'Chart Bars', 'Hours', 'Days'], group = 'FVG Time Decay')

// Decay thresholds
fadeStartTime = input.int(5, 'Start Fading After', minval = 1, maxval = 100, group = 'FVG Time Decay', tooltip = 'FVG starts fading after this many units')
fullFadeTime = input.int(10, 'Full Fade At', minval = 2, maxval = 200, group = 'FVG Time Decay', tooltip = 'FVG reaches maximum transparency at this many units')
invalidateTime = input.int(20, 'Invalidate After', minval = 3, maxval = 500, group = 'FVG Time Decay', tooltip = 'FVG is deleted after this many units (0 = never delete)')

// Visual settings
maxFadeTransparency = input.int(85, 'Maximum Fade Transparency', minval = 50, maxval = 95, group = 'FVG Time Decay')
showDecayIndicator = input.bool(true, 'Show Decay Progress', group = 'FVG Time Decay', tooltip = 'Show remaining time on FVG labels')

// Decay pause conditions
pauseDecayOnRetest = input.bool(true, 'Pause Decay on Retest', group = 'FVG Time Decay', tooltip = 'Reset decay timer when FVG is retested')
pauseDecayInSession = input.bool(false, 'Only Decay Outside Sessions', group = 'FVG Time Decay', tooltip = 'FVGs only decay when outside active trading sessions')
```

### 4.3 Data Structure Modifications

Extend the `Range` type:

```pinescript
// Add to existing Range type
type Range
    // ... existing fields ...
    int lastRetestBar         // Bar index of last retest (for decay pause)
    int htfCandleAtCreation   // HTF candle count at creation
    float currentDecayLevel   // 0.0 = no decay, 1.0 = fully decayed
```

### 4.4 Core Functions

#### 4.4.1 HTF Candle Counter

```pinescript
// Global HTF candle counter
var int htfCandleCount = 0

if newPeriod
    htfCandleCount += 1
```

#### 4.4.2 Decay Time Calculator

```pinescript
// Calculate elapsed time units since FVG creation
getElapsedTimeUnits(Range r) =>
    float elapsed = 0.0
    
    switch decayTimeUnit
        'HTF Candles' =>
            elapsed := htfCandleCount - r.htfCandleAtCreation
        'Chart Bars' =>
            elapsed := bar_index - r.creationBar
        'Hours' =>
            elapsed := (time - r.highStartTime) / (1000 * 60 * 60)  // milliseconds to hours
        'Days' =>
            elapsed := (time - r.highStartTime) / (1000 * 60 * 60 * 24)  // milliseconds to days
    
    elapsed
```

#### 4.4.3 Decay Level Calculator

```pinescript
// Calculate current decay level (0.0 to 1.0)
calculateDecayLevel(Range r) =>
    if not enableTimeDecay
        0.0
    else
        float elapsed = getElapsedTimeUnits(r)
        
        // Check if decay is paused
        bool decayPaused = false
        if pauseDecayOnRetest and not na(r.lastRetestBar)
            // Reset elapsed time from last retest
            elapsed := bar_index - r.lastRetestBar
        
        if pauseDecayInSession and enableSessionFilter and isInSession()
            decayPaused := true
        
        if decayPaused
            r.currentDecayLevel  // Return current level, don't advance
        else
            float decayLevel = 0.0
            
            if elapsed < fadeStartTime
                decayLevel := 0.0
            else if elapsed >= invalidateTime and invalidateTime > 0
                decayLevel := 1.0  // Fully decayed, mark for deletion
            else if elapsed >= fullFadeTime
                decayLevel := 0.99  // Fully faded but not deleted
            else
                // Linear interpolation between fadeStart and fullFade
                decayLevel := (elapsed - fadeStartTime) / (fullFadeTime - fadeStartTime)
            
            decayLevel
```

#### 4.4.4 Apply Decay to Visuals

```pinescript
// Apply decay transparency to FVG elements
applyDecayTransparency(Range r, float decayLevel) =>
    // Calculate transparency: from base transparency to maxFadeTransparency
    int baseTransparency = 85  // Base FVG box transparency
    int targetTransparency = maxFadeTransparency
    int currentTransparency = int(baseTransparency + (targetTransparency - baseTransparency) * decayLevel)
    
    // Update FVG boxes
    if array.size(r.fvgBoxes) > 0
        bool isBullishFVG = r.canCreateSignalFromLow
        color baseColor = isBullishFVG ? bullishFVGColor : bearishFVGColor
        color fadedColor = color.new(baseColor, currentTransparency)
        
        for i = 0 to array.size(r.fvgBoxes) - 1
            box b = array.get(r.fvgBoxes, i)
            box.set_bgcolor(b, fadedColor)
    
    // Update OTE elements if present
    if showOTELevels and array.size(r.oteLines) > 0
        color baseColor = r.canCreateSignalFromLow ? bullishFVGColor : bearishFVGColor
        color fadedColor = color.new(baseColor, int(oteTransparency + (100 - oteTransparency) * decayLevel))
        
        for i = 0 to array.size(r.oteLines) - 1
            line l = array.get(r.oteLines, i)
            line.set_color(l, fadedColor)
```

#### 4.4.5 Decay Label Update

```pinescript
// Update FVG label with decay indicator
updateDecayLabel(Range r, float decayLevel, float elapsed) =>
    if showDecayIndicator and showLabels
        string decayText = ""
        if decayLevel > 0
            float remaining = invalidateTime - elapsed
            string timeUnit = switch decayTimeUnit
                'HTF Candles' => 'c'
                'Chart Bars' => 'b'
                'Hours' => 'h'
                'Days' => 'd'
                => ''
            decayText := " [" + str.tostring(remaining, '#') + timeUnit + "]"
        
        // Append to existing label text
        // This requires tracking the label reference in Range type
```

### 4.5 Integration Points

#### 4.5.1 On FVG Creation

When creating a new Range:

```pinescript
newRange.htfCandleAtCreation := htfCandleCount
newRange.lastRetestBar := na
newRange.currentDecayLevel := 0.0
```

#### 4.5.2 In Range Update Loop

Add decay processing in the main range loop:

```pinescript
// In range drawing/update loop
if enableTimeDecay and not r.isSpecial
    // Check for retest (price touches FVG)
    if pauseDecayOnRetest
        bool isBullishFVG = r.canCreateSignalFromLow
        bool retested = false
        
        if isBullishFVG
            // Bullish FVG: retest if price touches top (rangeLow)
            retested := high >= r.rangeLow and low <= r.rangeLow
        else
            // Bearish FVG: retest if price touches bottom (rangeHigh)
            retested := low <= r.rangeHigh and high >= r.rangeHigh
        
        if retested
            r.lastRetestBar := bar_index
    
    // Calculate and apply decay
    float decayLevel = calculateDecayLevel(r)
    r.currentDecayLevel := decayLevel
    
    // Check for invalidation
    if decayLevel >= 1.0 and invalidateTime > 0
        cleanupFVGBoxes(r)
        cleanupOTELines(r)
        array.remove(ranges, i)
        continue
    
    // Apply visual decay
    if decayLevel > 0
        applyDecayTransparency(r, decayLevel)
```

### 4.6 Dashboard Integration

Add decay status for active FVGs:

```pinescript
// Count FVGs by decay status
int freshFVGs = 0
int fadingFVGs = 0
int nearInvalidFVGs = 0

for i = 0 to array.size(ranges) - 1
    r = array.get(ranges, i)
    if not r.isSpecial
        if r.currentDecayLevel == 0
            freshFVGs += 1
        else if r.currentDecayLevel < 0.5
            fadingFVGs += 1
        else
            nearInvalidFVGs += 1

// Display in dashboard: "FVGs: 3 fresh | 2 fading | 1 old"
```

### 4.7 Edge Cases

1. **New opposing FVG**: When a new FVG forms in opposite direction, should old FVG decay faster? (Optional parameter)

2. **Partial mitigation**: Decay should only apply to unmitigated portion of FVG.

3. **HTF change**: If user changes HTF mid-session, htfCandleCount needs recalibration.

4. **Very long timeframes**: For daily charts, decay in "days" might need larger default values.

---

## 5. Enhancement 4: Killzone Highlighting

### 5.1 Overview

Add visual session boxes (killzones) to highlight high-probability trading windows. These boxes span the full price range during each session and use distinct colors for easy identification.

### 5.2 Input Parameters

Add to new input group `'Killzones'`:

```pinescript
// Killzone Display Settings
showKillzones = input.bool(true, 'Show Killzones', group = 'Killzones', tooltip = 'Display session boxes on chart')

killzoneDisplayMode = input.string('Background', 'Display Mode', options = ['Background', 'Border Only', 'Full'], group = 'Killzones')

// Individual killzone toggles
showAsianKZ = input.bool(true, 'Show Asian Killzone', group = 'Killzones')
showLondonKZ = input.bool(true, 'Show London Killzone', group = 'Killzones')
showNYOpenKZ = input.bool(true, 'Show NY Open Killzone', group = 'Killzones')
showNYLunchKZ = input.bool(false, 'Show NY Lunch Killzone', group = 'Killzones')
showNYCloseKZ = input.bool(false, 'Show NY Close Killzone', group = 'Killzones')

// Custom killzone times (using NY timezone)
asianKZStart = input.session('2000-0000', 'Asian Session', group = 'Killzones')
londonKZStart = input.session('0200-0500', 'London Session', group = 'Killzones')
nyOpenKZStart = input.session('0700-1000', 'NY Open Session', group = 'Killzones')
nyLunchKZStart = input.session('1200-1300', 'NY Lunch Session', group = 'Killzones')
nyCloseKZStart = input.session('1330-1600', 'NY Close Session', group = 'Killzones')

// Color settings
asianKZColor = input.color(color.new(color.purple, 92), 'Asian Color', group = 'Killzones')
londonKZColor = input.color(color.new(color.blue, 92), 'London Color', group = 'Killzones')
nyOpenKZColor = input.color(color.new(color.orange, 92), 'NY Open Color', group = 'Killzones')
nyLunchKZColor = input.color(color.new(color.gray, 92), 'NY Lunch Color', group = 'Killzones')
nyCloseKZColor = input.color(color.new(color.teal, 92), 'NY Close Color', group = 'Killzones')

// Additional display options
kzBorderWidth = input.int(1, 'Border Width', minval = 0, maxval = 3, group = 'Killzones')
showKZLabels = input.bool(true, 'Show Session Labels', group = 'Killzones')
kzLabelPosition = input.string('Top Right', 'Label Position', options = ['Top Left', 'Top Right', 'Bottom Left', 'Bottom Right'], group = 'Killzones')
kzMaxBoxes = input.int(10, 'Max Boxes Per Session', minval = 1, maxval = 50, group = 'Killzones', tooltip = 'Limit historical boxes to preserve performance')

// Price range options
kzPriceRange = input.string('Session Range', 'Price Range', options = ['Session Range', 'Fixed ATR', 'Full Chart'], group = 'Killzones')
kzATRMultiplier = input.float(1.5, 'ATR Multiplier (if Fixed ATR)', minval = 0.5, maxval = 5.0, step = 0.1, group = 'Killzones')
```

### 5.3 Data Structures

```pinescript
// Killzone box type
type KillzoneBox
    box kzBox                 // The box object
    label kzLabel             // Session label
    string sessionName        // 'Asian', 'London', 'NY Open', etc.
    int sessionStartTime      // Session start timestamp
    int sessionEndTime        // Session end timestamp (na if ongoing)
    float sessionHigh         // Highest price during session
    float sessionLow          // Lowest price during session
    bool isComplete           // True if session has ended

// Arrays for each session type
var array<KillzoneBox> asianKZBoxes = array.new<KillzoneBox>()
var array<KillzoneBox> londonKZBoxes = array.new<KillzoneBox>()
var array<KillzoneBox> nyOpenKZBoxes = array.new<KillzoneBox>()
var array<KillzoneBox> nyLunchKZBoxes = array.new<KillzoneBox>()
var array<KillzoneBox> nyCloseKZBoxes = array.new<KillzoneBox>()
```

### 5.4 Core Functions

#### 5.4.1 Session State Detection

```pinescript
// Track session state transitions
var bool wasInAsian = false
var bool wasInLondon = false
var bool wasInNYOpen = false
var bool wasInNYLunch = false
var bool wasInNYClose = false

// Detect session boundaries
detectSessionTransitions() =>
    bool inAsian = not na(time(timeframe.period, asianKZStart, sessionTimezone))
    bool inLondon = not na(time(timeframe.period, londonKZStart, sessionTimezone))
    bool inNYOpen = not na(time(timeframe.period, nyOpenKZStart, sessionTimezone))
    bool inNYLunch = not na(time(timeframe.period, nyLunchKZStart, sessionTimezone))
    bool inNYClose = not na(time(timeframe.period, nyCloseKZStart, sessionTimezone))
    
    // Detect session starts
    bool asianStart = inAsian and not wasInAsian
    bool londonStart = inLondon and not wasInLondon
    bool nyOpenStart = inNYOpen and not wasInNYOpen
    bool nyLunchStart = inNYLunch and not wasInNYLunch
    bool nyCloseStart = inNYClose and not wasInNYClose
    
    // Detect session ends
    bool asianEnd = not inAsian and wasInAsian
    bool londonEnd = not inLondon and wasInLondon
    bool nyOpenEnd = not inNYOpen and wasInNYOpen
    bool nyLunchEnd = not inNYLunch and wasInNYLunch
    bool nyCloseEnd = not inNYClose and wasInNYClose
    
    // Update state
    wasInAsian := inAsian
    wasInLondon := inLondon
    wasInNYOpen := inNYOpen
    wasInNYLunch := inNYLunch
    wasInNYClose := inNYClose
    
    [asianStart, asianEnd, inAsian, londonStart, londonEnd, inLondon, nyOpenStart, nyOpenEnd, inNYOpen, nyLunchStart, nyLunchEnd, inNYLunch, nyCloseStart, nyCloseEnd, inNYClose]
```

#### 5.4.2 Create Killzone Box

```pinescript
// Create a new killzone box
createKillzoneBox(array<KillzoneBox> kzArray, string sessionName, color kzColor) =>
    // Enforce maximum boxes limit
    if array.size(kzArray) >= kzMaxBoxes
        // Delete oldest box
        KillzoneBox oldest = array.shift(kzArray)
        if not na(oldest.kzBox)
            box.delete(oldest.kzBox)
        if not na(oldest.kzLabel)
            label.delete(oldest.kzLabel)
    
    // Create new killzone
    KillzoneBox newKZ = KillzoneBox.new()
    newKZ.sessionName := sessionName
    newKZ.sessionStartTime := time
    newKZ.sessionEndTime := na
    newKZ.sessionHigh := high
    newKZ.sessionLow := low
    newKZ.isComplete := false
    
    // Determine box style based on display mode
    color bgColor = killzoneDisplayMode == 'Border Only' ? na : kzColor
    color borderColor = killzoneDisplayMode == 'Background' ? na : color.new(kzColor, 50)
    
    // Create box (initial size, will be updated)
    newKZ.kzBox := box.new(time, high, time, low, border_color = borderColor, border_width = kzBorderWidth, bgcolor = bgColor, xloc = xloc.bar_time)
    
    // Create label if enabled
    if showKZLabels
        label.style labelStyle = switch kzLabelPosition
            'Top Left' => label.style_label_lower_right
            'Top Right' => label.style_label_lower_left
            'Bottom Left' => label.style_label_upper_right
            'Bottom Right' => label.style_label_upper_left
            => label.style_label_lower_left
        
        float labelY = str.contains(kzLabelPosition, 'Top') ? high : low
        int labelX = str.contains(kzLabelPosition, 'Left') ? time : time
        
        newKZ.kzLabel := label.new(labelX, labelY, sessionName, xloc = xloc.bar_time, style = labelStyle, color = color.new(color.white, 100), textcolor = color.new(kzColor, 30), size = size.tiny)
    
    array.push(kzArray, newKZ)
```

#### 5.4.3 Update Killzone Box

```pinescript
// Update an active (incomplete) killzone box
updateKillzoneBox(KillzoneBox kz) =>
    if not kz.isComplete
        // Update high/low
        if high > kz.sessionHigh
            kz.sessionHigh := high
        if low < kz.sessionLow
            kz.sessionLow := low
        
        // Update box dimensions
        if not na(kz.kzBox)
            box.set_top(kz.kzBox, kz.sessionHigh)
            box.set_bottom(kz.kzBox, kz.sessionLow)
            box.set_right(kz.kzBox, time)
        
        // Update label position
        if showKZLabels and not na(kz.kzLabel)
            float labelY = str.contains(kzLabelPosition, 'Top') ? kz.sessionHigh : kz.sessionLow
            int labelX = str.contains(kzLabelPosition, 'Right') ? time : kz.sessionStartTime
            label.set_xy(kz.kzLabel, labelX, labelY)
```

#### 5.4.4 Complete Killzone Box

```pinescript
// Finalize a killzone box when session ends
completeKillzoneBox(KillzoneBox kz) =>
    kz.isComplete := true
    kz.sessionEndTime := time
    
    // Final box update
    if not na(kz.kzBox)
        box.set_right(kz.kzBox, time)
```

### 5.5 Main Killzone Logic

```pinescript
// Main killzone processing (call each bar)
if showKillzones
    [asianStart, asianEnd, inAsian, londonStart, londonEnd, inLondon, nyOpenStart, nyOpenEnd, inNYOpen, nyLunchStart, nyLunchEnd, inNYLunch, nyCloseStart, nyCloseEnd, inNYClose] = detectSessionTransitions()
    
    // === ASIAN ===
    if showAsianKZ
        if asianStart
            createKillzoneBox(asianKZBoxes, 'Asian', asianKZColor)
        
        if asianEnd and array.size(asianKZBoxes) > 0
            completeKillzoneBox(array.get(asianKZBoxes, array.size(asianKZBoxes) - 1))
        
        if inAsian and array.size(asianKZBoxes) > 0
            updateKillzoneBox(array.get(asianKZBoxes, array.size(asianKZBoxes) - 1))
    
    // === LONDON ===
    if showLondonKZ
        if londonStart
            createKillzoneBox(londonKZBoxes, 'London', londonKZColor)
        
        if londonEnd and array.size(londonKZBoxes) > 0
            completeKillzoneBox(array.get(londonKZBoxes, array.size(londonKZBoxes) - 1))
        
        if inLondon and array.size(londonKZBoxes) > 0
            updateKillzoneBox(array.get(londonKZBoxes, array.size(londonKZBoxes) - 1))
    
    // === NY OPEN ===
    if showNYOpenKZ
        if nyOpenStart
            createKillzoneBox(nyOpenKZBoxes, 'NY Open', nyOpenKZColor)
        
        if nyOpenEnd and array.size(nyOpenKZBoxes) > 0
            completeKillzoneBox(array.get(nyOpenKZBoxes, array.size(nyOpenKZBoxes) - 1))
        
        if inNYOpen and array.size(nyOpenKZBoxes) > 0
            updateKillzoneBox(array.get(nyOpenKZBoxes, array.size(nyOpenKZBoxes) - 1))
    
    // === NY LUNCH ===
    if showNYLunchKZ
        if nyLunchStart
            createKillzoneBox(nyLunchKZBoxes, 'NY Lunch', nyLunchKZColor)
        
        if nyLunchEnd and array.size(nyLunchKZBoxes) > 0
            completeKillzoneBox(array.get(nyLunchKZBoxes, array.size(nyLunchKZBoxes) - 1))
        
        if inNYLunch and array.size(nyLunchKZBoxes) > 0
            updateKillzoneBox(array.get(nyLunchKZBoxes, array.size(nyLunchKZBoxes) - 1))
    
    // === NY CLOSE ===
    if showNYCloseKZ
        if nyCloseStart
            createKillzoneBox(nyCloseKZBoxes, 'NY Close', nyCloseKZColor)
        
        if nyCloseEnd and array.size(nyCloseKZBoxes) > 0
            completeKillzoneBox(array.get(nyCloseKZBoxes, array.size(nyCloseKZBoxes) - 1))
        
        if inNYClose and array.size(nyCloseKZBoxes) > 0
            updateKillzoneBox(array.get(nyCloseKZBoxes, array.size(nyCloseKZBoxes) - 1))
```

### 5.6 Session Statistics (Optional)

```pinescript
// Calculate session statistics for dashboard
type SessionStats
    float avgRange           // Average session range
    float avgHighTime        // Average time when high is made
    float avgLowTime         // Average time when low is made
    int bullishSessions      // Sessions that closed higher than opened
    int bearishSessions      // Sessions that closed lower than opened

// Function to calculate stats from completed killzone boxes
calculateSessionStats(array<KillzoneBox> kzArray) =>
    SessionStats stats = SessionStats.new()
    // ... implementation
```

### 5.7 Edge Cases

1. **Overnight sessions**: Asian session crosses midnight - handle date transitions properly.

2. **DST transitions**: Session times should remain consistent in local time.

3. **Short timeframes**: On 1m charts, hundreds of bars may be in one session - use efficient updating.

4. **Weekend gaps**: Don't create killzones that span weekends.

5. **Partial sessions**: First bar of session may not be exactly at session start - use `time()` function.

---

## 6. Integration Requirements

### 6.1 Input Group Ordering

Recommended input group order in final script:

1. HTF Settings (existing)
2. Indicator (existing)
3. **Killzones** (new)
4. **Session Filter** (new)
5. **OTE Levels** (new)
6. **FVG Time Decay** (new)
7. Dashboard (existing)
8. Position Sizing (existing)
9. SMT Settings (existing)
10. Range Detection (existing)
11. iFVG Settings (existing)

### 6.2 Performance Considerations

1. **Array limits**: Total boxes/lines should not exceed Pine Script limits:
   - `max_boxes_count = 500`
   - `max_lines_count = 500`
   - `max_labels_count = 500`

   May need to increase from current 500 or implement stricter cleanup.

2. **Calculation efficiency**: Session checks should use cached results when possible.

3. **Loop optimization**: Combine multiple range loops where possible.

### 6.3 Dependency Map

```
Killzones
    └── Session Filter (uses session detection functions)
            └── Signal Generation (conditionally filtered)
            └── FVG Detection (conditionally filtered)

OTE Levels
    └── Range type (extended)
    └── FVG Box creation (triggers OTE creation)
    └── FVG cleanup (triggers OTE cleanup)

Time Decay
    └── Range type (extended)
    └── HTF candle counter (new global)
    └── FVG visual updates (decay applied)
```

### 6.4 Backwards Compatibility

All new features should be **disabled by default** to maintain existing behavior:

```pinescript
enableSessionFilter = input.bool(false, ...)
showOTELevels = input.bool(false, ...)
enableTimeDecay = input.bool(false, ...)
showKillzones = input.bool(true, ...)  // Exception: Killzones enabled by default as they're non-intrusive
```

---

## 7. Testing Requirements

### 7.1 Unit Tests

| Test Case | Feature | Expected Result |
|-----------|---------|-----------------|
| Session boundary detection | Session Filter | Correctly identify session start/end on various timeframes |
| Midnight crossing | Killzones | Asian session box spans correctly across midnight |
| OTE level calculation | OTE | 61.8% level correctly placed within FVG |
| Decay progression | Time Decay | FVG fades linearly from fadeStart to fullFade |
| Filter mode: Signals Only | Session Filter | FVGs form outside session, signals only in session |
| Retest decay pause | Time Decay | Decay timer resets on FVG retest |

### 7.2 Integration Tests

| Test Case | Features Combined | Expected Result |
|-----------|-------------------|-----------------|
| Session + Killzone sync | Session Filter + Killzones | Signals only fire within visible killzone boxes |
| Decay + OTE | Time Decay + OTE | OTE levels fade with FVG |
| All features enabled | All | No errors, performance acceptable (<500ms load) |

### 7.3 Edge Case Tests

| Test Case | Condition | Expected Result |
|-----------|-----------|-----------------|
| Weekend gap | Friday close to Monday open | No killzones span weekend |
| DST transition | March/November | Session times consistent |
| Very small FVG | < 5 pips | OTE levels skipped or combined |
| Rapid FVG creation | Volatile market | Decay timers independent |

### 7.4 Performance Tests

| Metric | Target | Method |
|--------|--------|--------|
| Initial load time | < 3 seconds | 5000 bar chart |
| Per-bar execution | < 50ms | Realtime observation |
| Memory usage | < Pine Script limits | All features enabled |

---

## 8. Appendix: ICT Session Reference

### 8.1 Standard ICT Sessions (New York Time)

| Session | Time (NY) | Characteristics |
|---------|-----------|-----------------|
| Asian | 20:00-00:00 | Range development, accumulation |
| London Open | 02:00-05:00 | **Primary killzone**, trend initiation |
| London Close | 05:00-07:00 | Consolidation, false moves |
| NY Open | 07:00-10:00 | **Primary killzone**, trend continuation |
| NY Lunch | 12:00-13:00 | Low volume, avoid trading |
| NY PM | 13:30-16:00 | Secondary moves, late entries |

### 8.2 ICT Power of 3 Concept

Sessions typically follow:
1. **Accumulation** (Asian range)
2. **Manipulation** (False breakout at session open)
3. **Distribution** (True move in opposite direction)

Killzone visuals help identify these phases.

### 8.3 Optimal Trade Entry (OTE) Zones

Standard Fibonacci levels for OTE:
- **61.8%** - OTE zone start
- **70.5%** - "Sweet spot" (often targeted)
- **79%** - OTE zone end

Entries within this zone have highest probability according to ICT methodology.

---

## Document History

| Version | Date | Changes |
|---------|------|---------|
| 1.0 | Dec 2024 | Initial specification |

---

**END OF SPECIFICATION**
