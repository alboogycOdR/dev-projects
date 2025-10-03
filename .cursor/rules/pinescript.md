# Pine Script Development Rules for CURSOR

## CRITICAL: Pine Script Type System Constraints

### 1. Simple vs Series Types
**RULE**: `request.security()` REQUIRES its symbol parameter to be a "simple string" type.

- ✅ **CORRECT**: Variables from `input.symbol()` are simple strings
- ❌ **WRONG**: Array elements via `array.get()` return series strings
- ❌ **WRONG**: Any computed or concatenated strings in loops

```pinescript
// ✅ CORRECT - Simple string from input
sym1 = input.symbol("OANDA:EURUSD", "Asset 1")
data = request.security(sym1, "240", close)  // Works!

// ❌ WRONG - Array element is series string
symbols = array.from(sym1, sym2, sym3)
data = request.security(array.get(symbols, 0), "240", close)  // ERROR!
```

### 2. Working with Multiple Symbols
**RULE**: When processing multiple symbols with `request.security()`:
- Define each symbol as an individual input variable
- Call `request.security()` with each variable explicitly
- Can create arrays for OTHER purposes, but NOT for security requests

```pinescript
// ✅ CORRECT Pattern
sym1 = input.symbol("EURUSD", "Symbol 1")
sym2 = input.symbol("GBPUSD", "Symbol 2")
sym3 = input.symbol("USDJPY", "Symbol 3")

// Process individually
f_process(sym1, 0)
f_process(sym2, 1)
f_process(sym3, 2)

// ❌ WRONG Pattern
symbols = array.from(sym1, sym2, sym3)
for i = 0 to 2
    f_process(array.get(symbols, i), i)  // Will fail!
```

## KEYLEVEL LABEL POSITIONING RULES - CONSISTENT RIGHT-END PLACEMENT

### 3. Label Positioning Standards
**CRITICAL RULE**: All keylevel labels MUST be positioned at the right end of their horizontal lines with consistent styling.

**Required Label Properties:**
- `style=label.style_label_right` - Positions label to the right of the point
- `textalign=text.align_right` - Right-aligns text within the label
- `label_x_position` calculation for proper offset positioning

**Label Position Calculation:**
```pinescript
// ✅ CORRECT - Standard label positioning for all keylevels
label_x_position = extendRight ? startTime + 50 * bar_width_ms : x2_time

// Create labels with consistent positioning
array.push(highLabels, label.new(label_x_position, price, labelText, 
    xloc=xloc.bar_time, 
    color=color(na), 
    style=label.style_label_right, 
    size=labelSize, 
    textalign=text.align_right))
```

**Label Update Logic for Extending Lines:**
```pinescript
// ✅ CORRECT - Update label positions when lines extend
if extendRight and showLevels
    bar_width_ms = time - nz(time[1], time)
    if array.size(highLabels) > 0
        for i = 0 to array.size(highLabels) - 1
            if i < array.size(highLabels)
                array.get(highLabels, i).set_x(time_close + 50 * bar_width_ms)
```

**❌ WRONG Patterns to Avoid:**
- Using `x2_time` directly without offset calculation
- Using `style=label.style_label_left` for right-end positioning
- Using `textalign=text.align_left` for right-end positioning
- Missing label update logic for extending lines

## VARIABLE DECLARATION RULES - PREVENT UNDECLARED IDENTIFIER ERRORS

### 4. Variable Declaration Requirements
**CRITICAL RULE**: ALL variables must be declared at the top level using `var` before they can be used anywhere in the script.

- ✅ **CORRECT**: Declare all variables at the top level
- ❌ **WRONG**: Declare variables inside conditional blocks or functions
- ❌ **WRONG**: Use variables without declaring them first

```pinescript
// ✅ CORRECT - All variables declared at top level
var float rangeHigh = na
var float rangeLow = na
var line newLineHigh = na
var line newLineLow = na

// Later in code, assign values
if condition
    newLineHigh := line.new(...)  // Works!
    newLineLow := line.new(...)   // Works!

// ❌ WRONG - Declaring inside conditional block
if condition
    line newLineHigh = line.new(...)  // ERROR! Cannot declare here
    line newLineLow = line.new(...)   // ERROR! Cannot declare here

// ❌ WRONG - Using undeclared variable
if condition
    newLineHigh := line.new(...)  // ERROR! Variable not declared
```

### 4. Variable Declaration Checklist
**BEFORE writing any code, ensure ALL variables are declared:**

```pinescript
// ✅ ALWAYS declare these at the top level:
var float price_variable = na
var int state_variable = 0
var bool flag_variable = false
var line drawing_object = na
var array<type> array_variable = array.new<type>()
var map<string, float> map_variable = map.new<string, float>()

// ✅ Then use := for assignments inside blocks
if condition
    price_variable := close
    state_variable := 1
    flag_variable := true
```

### 5. Common Undeclared Identifier Patterns to AVOID
**NEVER do this:**

```pinescript
// ❌ WRONG - Declaring in conditional blocks
if isNewCandle
    float newHigh = high        // ERROR!
    line newLine = line.new()   // ERROR!

// ❌ WRONG - Declaring in loops
for i = 0 to 5
    int counter = i             // ERROR!
    float value = close[i]      // ERROR!

// ❌ WRONG - Declaring in functions
f_process() =>
    string result = "done"      // ERROR!
    return result
```

### 6. Variable Declaration Best Practices
**ALWAYS follow this pattern:**

```pinescript
// ✅ STEP 1: Declare ALL variables at top level
var float rangeHigh = na
var float rangeLow = na
var line lineHigh = na
var line lineLow = na
var int patternState = 0
var bool isActive = false

// ✅ STEP 2: Use := for assignments inside blocks
if condition
    rangeHigh := high           // Assignment, not declaration
    lineHigh := line.new(...)   // Assignment, not declaration
    patternState := 1           // Assignment, not declaration

// ✅ STEP 3: Use = for initial values only
var int startValue = 0          // Initial value
var string defaultText = ""     // Initial value
```

### 7. Pre-Compilation Variable Check
**BEFORE compiling, verify this checklist:**

- [ ] All `float`, `int`, `bool`, `string` variables declared with `var`
- [ ] All `line`, `box`, `label` drawing objects declared with `var`
- [ ] All `array<type>` variables declared with `var`
- [ ] All `map<key, value>` variables declared with `var`
- [ ] No variable declarations inside `if`, `for`, or function blocks
- [ ] All variables used in assignments (`:=`) are declared at top level

## Performance Optimization Rules

### 8. Dynamic Requests
**RULE**: Always use `dynamic_requests=true` when using multiple `request.security()` calls.

```pinescript
indicator("My Indicator", overlay=true, dynamic_requests=true)
```

### 9. Caching Security Data
**RULE**: Implement time-based caching for multiple symbol scanners:
- Cache results between scans
- Only update at specified intervals
- Use `var` arrays to persist data between bars

```pinescript
// Performance variables
var int last_scan_time = 0
var array<string> cached_data = array.new<string>(16)
var bool needs_update = true

// Check if scan needed
f_shouldScan() =>
    time_diff = time - last_scan_time
    scan_interval = scan_freq_minutes * 60 * 1000
    time_diff >= scan_interval or last_scan_time == 0
```

## Reserved Keywords to Avoid

### 10. Variable Naming
**RULE**: Never use Pine Script reserved keywords as variable or field names:

❌ **AVOID**: 
- `range` (use `show_range`, `price_range`, etc.)
- `time` (use `time_val`, `bar_time`, etc.)
- `volume` (use `vol`, `volume_data`, etc.)
- `open`, `high`, `low`, `close` (use prefixes like `prev_high`, `session_low`)

## Custom Types Best Practices

### 11. Type Definitions
**RULE**: When defining custom types, avoid reserved words in field names:

```pinescript
// ✅ CORRECT
type SessionConfig
    bool show
    string name
    string session_time  // Not 'time'
    color col
    bool show_range      // Not 'range'
    float high_val       // Not 'high'
    float low_val        // Not 'low'

// ❌ WRONG
type SessionConfig
    bool show
    string name
    string time          // Reserved!
    color color          // Reserved!
    bool range          // Reserved!
    float high          // Reserved!
```

## Security Request Patterns

### 12. Multiple Data Points
**RULE**: Use tuples to fetch multiple values in one security request:

```pinescript
// ✅ EFFICIENT - One request for multiple values
[h1, l1, c1, h2, l2] = request.security(symbol, "240", 
    [high[1], low[1], close[1], high[2], low[2]], 
    lookahead=barmerge.lookahead_on)

// ❌ INEFFICIENT - Multiple requests
h1 = request.security(symbol, "240", high[1])
l1 = request.security(symbol, "240", low[1])
c1 = request.security(symbol, "240", close[1])
```

## Table Management

### 13. Table Updates
**RULE**: Clear and rebuild tables efficiently:

```pinescript
// Clear only the cells you need
if barstate.islast
    table.clear(my_table, 0, 0, 3, 9)  // Clear specific range
    // Rebuild content
```

## Array Initialization

### 14. Array Creation
**RULE**: Initialize arrays properly based on their use case:

```pinescript
// For caching data between bars
var array<string> cached_symbols = array.new<string>(16)
var array<color> cached_colors = array.new<color>(16)

// For temporary processing (recreated each bar)
temp_values = array.new<float>(0)
```

## Session Handling

### 15. Session Time Checks
**RULE**: Use `math.sign(nz(time(...)))` pattern for session detection:

```pinescript
// Reliable session detection
is_session = math.sign(nz(time(timeframe.period, session_string, timezone)))

// Check session change
if is_session > is_session[1]  // Session just started
    // Initialize session variables
```

## Common Pitfalls to Avoid

### 16. Lookback Limitations
**RULE**: Always set `max_bars_back` appropriately in indicator declaration:

```pinescript
indicator("My Indicator", overlay=true, max_bars_back=500)
```

### 17. Box and Line Limits
**RULE**: Set appropriate limits for drawing objects:

```pinescript
indicator("My Indicator", overlay=true, 
    max_lines_count=500, 
    max_boxes_count=500, 
    max_labels_count=500)
```

## Function Parameter Types

### 18. Function Definitions
**RULE**: Be explicit about parameter types in functions that use `request.security()`:

```pinescript
// Document that symbol must be a simple string
f_getData(symbol) =>  // symbol must be simple string from input.symbol()
    request.security(symbol, "D", close)
```

## Error Prevention

### 19. Null Checks
**RULE**: Always use `nz()` for potentially null values:

```pinescript
// Safe null handling
safe_value = nz(some_calculation, 0)  // Default to 0 if null
is_active = nz(time(timeframe.period, session)) != 0
```

### 20. Division by Zero
**RULE**: Always guard against division by zero:

```pinescript
// Safe division
result = denominator != 0 ? numerator / denominator : 0
```

## Performance Best Practices

### 21. Conditional Processing
**RULE**: Only process heavy calculations when necessary:

```pinescript
if barstate.islast and condition
    // Heavy processing here
```

### 22. Variable Persistence
**RULE**: Use `var` for values that should persist:

```pinescript
var float session_high = na  // Persists between bars
regular_var = high           // Recalculated each bar
```

## Testing Guidelines

### 23. Security Request Testing
**WHEN TESTING** multi-symbol indicators:
1. Start with 2-3 symbols to verify logic
2. Test with different timeframes
3. Verify caching works correctly
4. Check performance with real-time data

## Debugging Tips

### 24. Type Debugging
**RULE**: When getting type errors with `request.security()`:
1. Check if symbol is from `input.symbol()` directly
2. Ensure not using array elements
3. Verify not using computed/concatenated strings
4. Check for proper `dynamic_requests=true` flag

### 25. Common Error Messages
- "Cannot call 'request.security' with 'series string' for 'symbol'" 
  → Symbol parameter is not a simple string
- "Too many securities in script"
  → Add `dynamic_requests=true` to indicator declaration
- "Variable 'range' is a reserved word"
  → Rename variable to avoid reserved keyword
- **"Undeclared identifier 'variable_name'**
  → Variable not declared at top level with `var`

## Chart Object Anchoring Rules

### 26. Price-Level Anchoring
**CRITICAL RULE**: For objects that must stay fixed to price levels when chart moves vertically:

- ✅ **USE**: `label.new()` with `yloc=yloc.price` for price-anchored objects
- ❌ **AVOID**: `plotshape()` or `plotarrow()` for price-anchored objects
- ❌ **AVOID**: `label.new()` without `yloc=yloc.price` for price levels

```pinescript
// ✅ CORRECT - Price-anchored objects
label.new(bar_index[1], low[1], "▲", 
    color=color.new(color.green, 0), 
    textcolor=color.white, 
    style=label.style_triangleup, 
    size=size.normal, 
    yloc=yloc.price)  // CRITICAL for price anchoring

// ❌ WRONG - Not price-anchored
plotshape(condition, "Signal", shape.triangleup, 
    location.belowbar, color.green)  // Will float when chart moves
```

### 27. When to Use Each Plotting Function
**RULE**: Choose the right function for your needs:

```pinescript
// For price-anchored signals (arrows, circles, etc.)
if signal_condition
    label.new(bar_index, price_level, "▲", 
        style=label.style_triangleup, 
        yloc=yloc.price)  // Stays at price level

// For non-price-anchored visuals (backgrounds, etc.)
bgcolor(condition ? color.new(color.green, 85) : na)  // Moves with chart

// For simple markers that don't need price anchoring
plotshape(condition, "Marker", shape.circle, 
    location.abovebar, color.blue)  // Simple visual marker
```

## Multiline Statement Conversion Rules

### 28. Single-Line Function Calls
**CRITICAL RULE**: Always convert multiline function calls to single-line format for Pine Script v5 compatibility:

- ✅ **CORRECT**: All parameters on one line
- ❌ **WRONG**: Parameters spread across multiple lines

```pinescript
// ✅ CORRECT - Single line format
label.new(bar_index, price, "Signal", color=color.blue, textcolor=color.white, style=label.style_label_up, size=size.normal)
plotshape(condition, "Marker", shape.triangleup, location.abovebar, color=color.green, size=size.small)
line.new(x1, y1, x2, y2, color=color.red, width=2, extend=extend.right)
box.new(left, top, right, bottom, border_color=color.blue, bgcolor=color.new(color.blue, 90))

// ❌ WRONG - Multiline format (causes compilation errors)
label.new(bar_index, price, "Signal", 
    color=color.blue, textcolor=color.white, 
    style=label.style_label_up, size=size.normal)
plotshape(condition, "Marker", shape.triangleup, 
    location.abovebar, color=color.green, size=size.small)
```

### 29. Functions Requiring Single-Line Format
**RULE**: These functions MUST be on single lines:
- `label.new()`
- `plotshape()`
- `line.new()`
- `box.new()`
- `request.security()`
- `alertcondition()`
- `strategy.entry()`
- `strategy.exit()`
- Any function with multiple parameters

### 30. Multiline Condition Handling
**RULE**: For complex conditions, use single-line format or break into variables:

```pinescript
// ✅ CORRECT - Single line condition
sellConfirmation = high > candleA_High and close < candleA_High and close >= candleA_Low and close <= candleA_High

// ✅ CORRECT - Break into variables for readability
condition1 = high > candleA_High and close < candleA_High
condition2 = close >= candleA_Low and close <= candleA_High
sellConfirmation = condition1 and condition2

// ❌ WRONG - Multiline condition
sellConfirmation = high > candleA_High and close < candleA_High and 
    close >= candleA_Low and close <= candleA_High
```

## Quick Reference Checklist

Before submitting Pine Script code:
- [ ] All variables declared at top level with `var`
- [ ] All `request.security()` calls use simple string symbols
- [ ] `dynamic_requests=true` set if using multiple securities  
- [ ] No reserved keywords used as variable names
- [ ] Caching implemented for performance
- [ ] Proper var declarations for persistent data
- [ ] Max limits set for boxes/lines/labels
- [ ] Null checks with `nz()` where needed
- [ ] Division by zero protection
- [ ] Table operations optimized
- [ ] Session detection uses proper pattern
- [ ] Price-anchored objects use `label.new()` with `yloc=yloc.price`
- [ ] No variable declarations inside conditional blocks or loops
- [ ] All function calls (`label.new()`, `plotshape()`, `line.new()`, `box.new()`, etc.) are single-line format
- [ ] No multiline conditions or function parameters
- [ ] Complex conditions broken into variables for readability if needed
