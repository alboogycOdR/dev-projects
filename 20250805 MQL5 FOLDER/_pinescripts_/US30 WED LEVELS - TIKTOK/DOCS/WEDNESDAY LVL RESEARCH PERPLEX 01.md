<img src="https://r2cdn.perplexity.ai/pplx-full-logo-primary-dark%402x.png" class="logo" width="120"/>

# what about all the other wednesdays of this month? the pinescript is incomplete

You're absolutely right! The current Pine Script only shows **the most recent Wednesday** 13:30 EST candle levels, but for comprehensive analysis, you need to see **all Wednesdays of the current month** to identify multiple support/resistance zones and confluence areas.

Here's the **complete Pine Script** that will mark all Wednesday 13:30 EST levels for the current month:

```pinescript
//@version=5
indicator("All Wednesday 13:30 EST Levels - Monthly", overlay=true, max_lines_count=500)

// Input settings
show_labels = input.bool(true, "Show Labels", group="Display Settings")
show_current_month_only = input.bool(true, "Show Current Month Only", group="Display Settings")
max_wednesdays = input.int(8, "Maximum Wednesdays to Show", minval=1, maxval=20, group="Display Settings")
line_style = input.string("Solid", "Line Style", options=["Solid", "Dashed", "Dotted"], group="Display Settings")
line_width = input.int(2, "Line Width", minval=1, maxval=5, group="Display Settings")
extend_right = input.bool(true, "Extend Lines Right", group="Display Settings")

// Colors for different Wednesdays
wed1_high_color = input.color(color.red, "Wednesday 1 - High Color", group="Colors")
wed1_low_color = input.color(color.blue, "Wednesday 1 - Low Color", group="Colors")
wed2_high_color = input.color(color.orange, "Wednesday 2 - High Color", group="Colors")
wed2_low_color = input.color(color.purple, "Wednesday 2 - Low Color", group="Colors")
wed3_high_color = input.color(color.green, "Wednesday 3 - High Color", group="Colors")
wed3_low_color = input.color(color.maroon, "Wednesday 3 - Low Color", group="Colors")
wed4_high_color = input.color(color.yellow, "Wednesday 4 - High Color", group="Colors")
wed4_low_color = input.color(color.navy, "Wednesday 4 - Low Color", group="Colors")
wed5_high_color = input.color(color.lime, "Wednesday 5+ - High Color", group="Colors")
wed5_low_color = input.color(color.gray, "Wednesday 5+ - Low Color", group="Colors")

show_range_boxes = input.bool(false, "Show Range Boxes", group="Colors")
box_transparency = input.int(90, "Box Transparency", minval=50, maxval=95, group="Colors")

// Time settings
timezone = input.string("America/New_York", "Timezone", group="Time Settings")

// Arrays to store Wednesday data
var array<float> wed_highs = array.new<float>()
var array<float> wed_lows = array.new<float>()
var array<int> wed_times = array.new<int>()
var array<int> wed_bar_indices = array.new<int>()
var array<line> high_lines = array.new<line>()
var array<line> low_lines = array.new<line>()
var array<box> range_boxes = array.new<box>()

// Function to check if current bar is Wednesday 13:30 EST
is_wednesday_1330() =>
    t = time(timeframe.period, "1330-1345:23456", timezone)
    dayofweek(time, timezone) == dayofweek.wednesday and not na(t)

// Function to get colors based on Wednesday number
get_colors(wed_num) =>
    switch wed_num
        1 => [wed1_high_color, wed1_low_color]
        2 => [wed2_high_color, wed2_low_color]
        3 => [wed3_high_color, wed3_low_color]
        4 => [wed4_high_color, wed4_low_color]
        => [wed5_high_color, wed5_low_color]

// Function to check if time is in current month
is_current_month(check_time) =>
    current_month = month(timenow)
    current_year = year(timenow)
    check_month = month(check_time)
    check_year = year(check_time)
    check_month == current_month and check_year == current_year

// Clean up old lines and boxes that are not in current month
cleanup_old_data() =>
    if show_current_month_only
        // Clean arrays based on current month
        for i = array.size(wed_times) - 1 to 0
            if array.size(wed_times) > 0
                wed_time = array.get(wed_times, i)
                if not is_current_month(wed_time)
                    // Delete corresponding lines and boxes
                    if i < array.size(high_lines)
                        line.delete(array.get(high_lines, i))
                        array.remove(high_lines, i)
                    if i < array.size(low_lines)
                        line.delete(array.get(low_lines, i))
                        array.remove(low_lines, i)
                    if i < array.size(range_boxes)
                        box.delete(array.get(range_boxes, i))
                        array.remove(range_boxes, i)
                    
                    // Remove data from arrays
                    array.remove(wed_highs, i)
                    array.remove(wed_lows, i)
                    array.remove(wed_times, i)
                    array.remove(wed_bar_indices, i)
    
    // Limit total number of Wednesdays
    while array.size(wed_highs) > max_wednesdays
        // Remove oldest data
        if array.size(high_lines) > 0
            line.delete(array.get(high_lines, 0))
            array.shift(high_lines)
        if array.size(low_lines) > 0
            line.delete(array.get(low_lines, 0))
            array.shift(low_lines)
        if array.size(range_boxes) > 0
            box.delete(array.get(range_boxes, 0))
            array.shift(range_boxes)
        
        array.shift(wed_highs)
        array.shift(wed_lows)
        array.shift(wed_times)
        array.shift(wed_bar_indices)

// Main logic for detecting Wednesday 13:30 candles
if is_wednesday_1330()
    // Clean up old data first
    cleanup_old_data()
    
    // Add new Wednesday data
    array.push(wed_highs, high)
    array.push(wed_lows, low)
    array.push(wed_times, time)
    array.push(wed_bar_indices, bar_index)
    
    // Get current Wednesday number (position in array)
    wed_number = array.size(wed_highs)
    colors = get_colors(wed_number)
    high_color = array.get(colors, 0)
    low_color = array.get(colors, 1)
    
    // Line style conversion
    line_style_converted = line_style == "Dashed" ? line.style_dashed : line_style == "Dotted" ? line.style_dotted : line.style_solid
    
    // Create high line
    high_line = line.new(
        x1=bar_index, y1=high,
        x2=bar_index + 100, y2=high,
        color=high_color,
        style=line_style_converted,
        width=line_width,
        extend=extend_right ? extend.right : extend.none
    )
    array.push(high_lines, high_line)
    
    // Create low line
    low_line = line.new(
        x1=bar_index, y1=low,
        x2=bar_index + 100, y2=low,
        color=low_color,
        style=line_style_converted,
        width=line_width,
        extend=extend_right ? extend.right : extend.none
    )
    array.push(low_lines, low_line)
    
    // Create range box if enabled
    if show_range_boxes
        range_box = box.new(
            left=bar_index, top=high,
            right=bar_index + 50, bottom=low,
            border_color=color.new(high_color, 50),
            bgcolor=color.new(high_color, box_transparency),
            border_width=1,
            extend=extend.right
        )
        array.push(range_boxes, range_box)

// Create labels for all Wednesday levels
if show_labels and barstate.islast
    for i = 0 to array.size(wed_highs) - 1
        if i < array.size(wed_highs)
            wed_high = array.get(wed_highs, i)
            wed_low = array.get(wed_lows, i)
            wed_time = array.get(wed_times, i)
            colors = get_colors(i + 1)
            high_color = array.get(colors, 0)
            low_color = array.get(colors, 1)
            
            // Format date for label
            date_str = str.format("{0}/{1}", month(wed_time), dayofmonth(wed_time))
            
            // High label
            label.new(
                x=bar_index - 10, y=wed_high,
                text=str.format("W{0} H: {1} ({2})", i + 1, str.tostring(wed_high, "#.##"), date_str),
                style=label.style_label_down,
                color=high_color,
                textcolor=color.white,
                size=size.small
            )
            
            // Low label
            label.new(
                x=bar_index - 10, y=wed_low,
                text=str.format("W{0} L: {1} ({2})", i + 1, str.tostring(wed_low, "#.##"), date_str),
                style=label.style_label_up,
                color=low_color,
                textcolor=color.white,
                size=size.small
            )

// Enhanced alert conditions for all Wednesday levels
for i = 0 to array.size(wed_highs) - 1
    if i < array.size(wed_highs)
        wed_high = array.get(wed_highs, i)
        wed_low = array.get(wed_lows, i)
        
        alertcondition(close > wed_high and close[1] <= wed_high, 
            str.format("Above Wednesday {0} High", i + 1), 
            str.format("Price broke above Wednesday {0} high at {1}", i + 1, wed_high))
        
        alertcondition(close < wed_low and close[1] >= wed_low, 
            str.format("Below Wednesday {0} Low", i + 1), 
            str.format("Price broke below Wednesday {0} low at {1}", i + 1, wed_low))

// Enhanced information table
if show_labels and barstate.islast
    var table info_table = table.new(position.top_right, 3, math.min(array.size(wed_highs) + 1, 9), 
                                   bgcolor=color.white, border_width=1)
    
    if array.size(wed_highs) > 0
        // Header
        table.cell(info_table, 0, 0, "Wed", text_color=color.black, bgcolor=color.gray)
        table.cell(info_table, 1, 0, "High", text_color=color.black, bgcolor=color.gray)
        table.cell(info_table, 2, 0, "Low", text_color=color.black, bgcolor=color.gray)
        
        // Data rows
        for i = 0 to math.min(array.size(wed_highs) - 1, 7)
            wed_high = array.get(wed_highs, i)
            wed_low = array.get(wed_lows, i)
            wed_time = array.get(wed_times, i)
            
            date_str = str.format("{0}/{1}", month(wed_time), dayofmonth(wed_time))
            colors = get_colors(i + 1)
            
            table.cell(info_table, 0, i + 1, date_str, text_color=color.black)
            table.cell(info_table, 1, i + 1, str.tostring(wed_high, "#.##"), text_color=array.get(colors, 0))
            table.cell(info_table, 2, i + 1, str.tostring(wed_low, "#.##"), text_color=array.get(colors, 1))

// Plot background highlight for Wednesday 13:30 periods
bgcolor(is_wednesday_1330() ? color.new(color.yellow, 95) : na, title="Wednesday 13:30 Highlight")
```


## Key Improvements in This Complete Version:

### **Multiple Wednesday Tracking**

- **Stores all Wednesdays** of the current month in arrays
- **Color-coded system**: Each Wednesday gets distinct colors (W1=Red/Blue, W2=Orange/Purple, W3=Green/Maroon, etc.)
- **Automatic cleanup**: Removes old Wednesdays when switching months


### **Enhanced Visualization**

- **Information table** showing all Wednesday levels with dates
- **Smart labeling** with Wednesday number and date
- **Optional range boxes** for each Wednesday
- **Background highlighting** during Wednesday 13:30 periods


### **Advanced Features**

- **Configurable limits**: Set maximum number of Wednesdays to display
- **Current month filter**: Option to show only current month's Wednesdays
- **Multiple alerts**: Separate breakout alerts for each Wednesday level
- **Memory management**: Automatically cleans up old lines/boxes to prevent overcrowding


## How to Use All Wednesday Levels:

### **Confluence Trading**

- Look for **price reactions** at multiple Wednesday levels
- **Strongest support/resistance** occurs where multiple Wednesday levels cluster together
- Use **breakouts** from one Wednesday level to target the next Wednesday level


### **Range Identification**

- **Weekly ranges** often form between consecutive Wednesday levels
- **Breakout targets**: When price breaks one Wednesday level, next target is usually the next Wednesday level up/down


### **Example Strategy**

1. **Identify the range** between current week's Wednesday levels and previous Wednesday levels
2. **Wait for breakout** with confirmation
3. **Target** the next Wednesday level in the breakout direction
4. **Use closest Wednesday level** as stop-loss reference

This complete indicator now gives you a comprehensive view of all Wednesday 13:30 EST levels for the month, creating a **multi-layered support and resistance map** that's much more powerful for gold trading analysis.

