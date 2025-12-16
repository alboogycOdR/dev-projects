"""
Strategy v3 Converter
Automatically converts WR-SR v2 indicator to v3 strategy with:
- Auto trading
- TP calculations
- Alert automation
"""

# Read the indicator file
with open('wick_rejection_sr_strategy_v2.pine', 'r', encoding='utf-8') as f:
    code = f.read()

# Step 1: Change indicator() to strategy()
code = code.replace(
    'indicator("Wick Rejection S/R Strategy v2", shorttitle="WR-SR v2", overlay=true, max_lines_count=100, max_boxes_count=100, max_labels_count=100)',
    '''strategy("Wick Rejection S/R Strategy v3", shorttitle="WR-SR v3", overlay=true,
         max_lines_count=100, max_boxes_count=100, max_labels_count=100,
         initial_capital=10000,
         default_qty_type=strategy.percent_of_equity,
         default_qty_value=100,
         commission_type=strategy.commission.percent,
         commission_value=0.05,
         slippage=2,
         pyramiding=1,
         close_entries_rule="ANY")'''
)

# Step 2: Update version comment
code = code.replace('// Version: 2.0 (Optimized & Bug-Fixed)', '// Version: 3.0 (STRATEGY with Alerts, TP Calculations, Auto-Trading)')

# Step 3: Add strategy inputs after alerts section (line 76)
strategy_inputs = '''
// ═══════════════════════════════════════════════════════════════════════════════
// INPUTS - STRATEGY & RISK MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════════
grp_strategy = "══════ Strategy & Risk Management ══════"
enable_strategy     = input.bool(true, "Enable Auto Trading", group=grp_strategy, tooltip="Enable automatic trade execution")
risk_reward_ratio   = input.float(2.0, "Risk:Reward Ratio", minval=1.0, maxval=5.0, step=0.5, group=grp_strategy, tooltip="TP calculation multiplier (2.0 = 2x risk)")
use_dynamic_tp      = input.bool(true, "Use Dynamic TP", group=grp_strategy, tooltip="Calculate TP based on next S/R level")
tp_buffer           = input.float(0.5, "TP Buffer (points)", minval=0.0, maxval=5.0, step=0.5, group=grp_strategy, tooltip="Distance before next S/R for TP")
use_trailing_stop   = input.bool(false, "Use Trailing Stop", group=grp_strategy, tooltip="Enable trailing stop after TP1 hit")
trail_activation    = input.float(1.0, "Trail Activation (R)", minval=0.5, maxval=3.0, step=0.5, group=grp_strategy, tooltip="Activate trailing after X times risk")
trail_offset        = input.float(0.5, "Trail Offset (R)", minval=0.1, maxval=2.0, step=0.1, group=grp_strategy, tooltip="Trailing stop offset in risk multiples")
close_on_opposite   = input.bool(true, "Close on Opposite Signal", group=grp_strategy, tooltip="Close position when opposite signal appears")
max_trades_per_day  = input.int(10, "Max Trades Per Day", minval=0, maxval=50, group=grp_strategy, tooltip="0 = unlimited")

// ═══════════════════════════════════════════════════════════════════════════════
// INPUTS - TAKE PROFIT LEVELS
// ═══════════════════════════════════════════════════════════════════════════════
grp_tp = "══════ Take Profit Settings ══════"
use_multiple_tp     = input.bool(true, "Use Multiple TP Levels", group=grp_tp, tooltip="Close position in stages")
tp1_percent         = input.int(50, "TP1 Close %", minval=10, maxval=100, group=grp_tp, tooltip="% of position to close at TP1")
tp1_rr              = input.float(1.5, "TP1 R:R", minval=0.5, maxval=5.0, step=0.5, group=grp_tp, tooltip="TP1 at X times risk")
tp2_percent         = input.int(30, "TP2 Close %", minval=10, maxval=100, group=grp_tp, tooltip="% of remaining position to close at TP2")
tp2_rr              = input.float(2.5, "TP2 R:R", minval=1.0, maxval=10.0, step=0.5, group=grp_tp, tooltip="TP2 at X times risk")
tp3_rr              = input.float(4.0, "TP3 R:R", minval=2.0, maxval=20.0, step=1.0, group=grp_tp, tooltip="TP3 (final) at X times risk")

// ═══════════════════════════════════════════════════════════════════════════════
// INPUTS - ALERT AUTOMATION
// ═══════════════════════════════════════════════════════════════════════════════
grp_alert_auto = "══════ Alert Automation ══════"
alert_on_entry      = input.bool(true, "Alert on Entry Signal", group=grp_alert_auto)
alert_on_tp         = input.bool(true, "Alert on TP Hit", group=grp_alert_auto)
alert_on_sl         = input.bool(true, "Alert on SL Hit", group=grp_alert_auto)
alert_on_cisd       = input.bool(false, "Alert on CISD Signal", group=grp_alert_auto, tooltip="Alert when CISD momentum shift detected")
alert_prefix        = input.string("WR-SR", "Alert Prefix", group=grp_alert_auto, tooltip="Prefix for all alerts")
show_tp_lines       = input.bool(true, "Show TP Lines", group=grp_alert_auto, tooltip="Display TP level lines on chart")

'''

# Find the alerts section and insert strategy inputs before it
insert_point = code.find('// ═══════════════════════════════════════════════════════════════════════════════\n// INPUTS - ALERTS\n')
code = code[:insert_point] + strategy_inputs + code[insert_point:]

# Step 4: Add TP calculation functions before signal detection
tp_functions = '''
// ═══════════════════════════════════════════════════════════════════════════════
// TAKE PROFIT CALCULATION FUNCTIONS
// ═══════════════════════════════════════════════════════════════════════════════

// Calculate TP levels based on risk distance
f_calculate_tp_levels(float entry, float sl, bool is_long) =>
    risk_distance = math.abs(entry - sl)
    
    tp1 = 0.0
    tp2 = 0.0
    tp3 = 0.0
    
    if is_long
        tp1 := entry + (risk_distance * tp1_rr)
        tp2 := entry + (risk_distance * tp2_rr)
        tp3 := entry + (risk_distance * tp3_rr)
    else
        tp1 := entry - (risk_distance * tp1_rr)
        tp2 := entry - (risk_distance * tp2_rr)
        tp3 := entry - (risk_distance * tp3_rr)
    
    [tp1, tp2, tp3]

// Find next resistance level above price (for long TP)
f_find_next_resistance(float current_price) =>
    nearest_res = 0.0
    min_dist = 99999.0
    
    if array.size(resistance_data) > 0
        for i = 0 to array.size(resistance_data) - 1
            r = array.get(resistance_data, i)
            dist = r.price - current_price
            if dist > 0 and dist < min_dist
                min_dist := dist
                nearest_res := r.price
    
    nearest_res

// Find next support level below price (for short TP)
f_find_next_support(float current_price) =>
    nearest_sup = 0.0
    min_dist = 99999.0
    
    if array.size(support_data) > 0
        for i = 0 to array.size(support_data) - 1
            s = array.get(support_data, i)
            dist = current_price - s.price
            if dist > 0 and dist < min_dist
                min_dist := dist
                nearest_sup := s.price
    
    nearest_sup

// Calculate dynamic TP based on next S/R level
f_calculate_dynamic_tp(float entry, float sl, bool is_long) =>
    if use_dynamic_tp
        if is_long
            next_level = f_find_next_resistance(entry)
            if next_level > 0
                next_level - (tp_buffer)
            else
                entry + (math.abs(entry - sl) * risk_reward_ratio)
        else
            next_level = f_find_next_support(entry)
            if next_level > 0
                next_level + (tp_buffer)
            else
                entry - (math.abs(entry - sl) * risk_reward_ratio)
    else
        risk_distance = math.abs(entry - sl)
        is_long ? entry + (risk_distance * risk_reward_ratio) : entry - (risk_distance * risk_reward_ratio)

'''

# Insert TP functions before the asymmetric zone buffers section
tp_insert_point = code.find('// ═══════════════════════════════════════════════════════════════════════════════\n// ASYMMETRIC ZONE BUFFERS\n')
code = code[:tp_insert_point] + tp_functions + code[tp_insert_point:]

# Step 5: Add trade execution logic before visualization section
trade_execution = '''
// ═══════════════════════════════════════════════════════════════════════════════
// TRADE EXECUTION & MANAGEMENT
// ═══════════════════════════════════════════════════════════════════════════════

// Track daily trades
var int trades_today = 0
var int last_trade_day = 0

// Reset counter at start of new day
if dayofweek != dayofweek[1]
    trades_today := 0
    last_trade_day := dayofweek

// Check if max daily trades reached
max_trades_reached = max_trades_per_day > 0 and trades_today >= max_trades_per_day

// Track TP levels for current position
var float entry_price = 0.0
var float stop_loss = 0.0
var float tp1_price = 0.0
var float tp2_price = 0.0
var float tp3_price = 0.0
var bool tp1_hit = false
var bool tp2_hit = false
var bool is_long_position = false

// Close opposite position if enabled
if close_on_opposite and enable_strategy
    if buy_signal and strategy.position_size < 0
        strategy.close("Short", alert_message=alert_prefix + " | Closed SHORT on opposite BUY signal")
    
    if sell_signal and strategy.position_size > 0
        strategy.close("Long", alert_message=alert_prefix + " | Closed LONG on opposite SELL signal")

// LONG ENTRY
if buy_signal and enable_strategy and not max_trades_reached and strategy.position_size == 0
    if use_multiple_tp
        [tp1, tp2, tp3] = f_calculate_tp_levels(close, suggested_sl, true)
        tp1_price := tp1
        tp2_price := tp2
        tp3_price := tp3
    else
        tp1_price := f_calculate_dynamic_tp(close, suggested_sl, true)
        tp2_price := tp1_price
        tp3_price := tp1_price
    
    entry_price := close
    stop_loss := suggested_sl
    is_long_position := true
    tp1_hit := false
    tp2_hit := false
    trades_today += 1
    
    alert_msg = alert_prefix + " BUY | " + signal_type + " (Conf:" + str.tostring(signal_confidence) + ") | Entry:" + str.tostring(close, format.mintick) + " | SL:" + str.tostring(suggested_sl, format.mintick) + " | TP1:" + str.tostring(tp1_price, format.mintick) + (use_multiple_tp ? " | TP2:" + str.tostring(tp2_price, format.mintick) + " | TP3:" + str.tostring(tp3_price, format.mintick) : "")
    
    strategy.entry("Long", strategy.long, stop=suggested_sl, alert_message=alert_msg)

// SHORT ENTRY
if sell_signal and enable_strategy and not max_trades_reached and strategy.position_size == 0
    if use_multiple_tp
        [tp1, tp2, tp3] = f_calculate_tp_levels(close, suggested_sl, false)
        tp1_price := tp1
        tp2_price := tp2
        tp3_price := tp3
    else
        tp1_price := f_calculate_dynamic_tp(close, suggested_sl, false)
        tp2_price := tp1_price
        tp3_price := tp1_price
    
    entry_price := close
    stop_loss := suggested_sl
    is_long_position := false
    tp1_hit := false
    tp2_hit := false
    trades_today += 1
    
    alert_msg = alert_prefix + " SELL | " + signal_type + " (Conf:" + str.tostring(signal_confidence) + ") | Entry:" + str.tostring(close, format.mintick) + " | SL:" + str.tostring(suggested_sl, format.mintick) + " | TP1:" + str.tostring(tp1_price, format.mintick) + (use_multiple_tp ? " | TP2:" + str.tostring(tp2_price, format.mintick) + " | TP3:" + str.tostring(tp3_price, format.mintick) : "")
    
    strategy.entry("Short", strategy.short, stop=suggested_sl, alert_message=alert_msg)

// MANAGE OPEN POSITIONS (TP & Trailing)
if strategy.position_size != 0
    // Check TP levels for LONG
    if is_long_position and strategy.position_size > 0
        if use_multiple_tp
            if not tp1_hit and high >= tp1_price
                strategy.close("Long", qty_percent=tp1_percent, comment="TP1", alert_message=alert_prefix + " TP1 HIT | Closed " + str.tostring(tp1_percent) + "% at " + str.tostring(tp1_price, format.mintick))
                tp1_hit := true
            
            if tp1_hit and not tp2_hit and high >= tp2_price
                strategy.close("Long", qty_percent=tp2_percent, comment="TP2", alert_message=alert_prefix + " TP2 HIT | Closed " + str.tostring(tp2_percent) + "% at " + str.tostring(tp2_price, format.mintick))
                tp2_hit := true
            
            if tp2_hit and high >= tp3_price
                strategy.close("Long", comment="TP3", alert_message=alert_prefix + " TP3 HIT | Full exit at " + str.tostring(tp3_price, format.mintick))
        else
            if high >= tp1_price
                strategy.close("Long", comment="TP", alert_message=alert_prefix + " TP HIT | Exit at " + str.tostring(tp1_price, format.mintick))
        
        if use_trailing_stop and tp1_hit
            risk_distance = math.abs(entry_price - stop_loss)
            trail_trigger = entry_price + (risk_distance * trail_activation)
            if high >= trail_trigger
                trail_stop = high - (risk_distance * trail_offset)
                strategy.exit("Trail", "Long", stop=trail_stop)
    
    // Check TP levels for SHORT
    if not is_long_position and strategy.position_size < 0
        if use_multiple_tp
            if not tp1_hit and low <= tp1_price
                strategy.close("Short", qty_percent=tp1_percent, comment="TP1", alert_message=alert_prefix + " TP1 HIT | Closed " + str.tostring(tp1_percent) + "% at " + str.tostring(tp1_price, format.mintick))
                tp1_hit := true
            
            if tp1_hit and not tp2_hit and low <= tp2_price
                strategy.close("Short", qty_percent=tp2_percent, comment="TP2", alert_message=alert_prefix + " TP2 HIT | Closed " + str.tostring(tp2_percent) + "% at " + str.tostring(tp2_price, format.mintick))
                tp2_hit := true
            
            if tp2_hit and low <= tp3_price
                strategy.close("Short", comment="TP3", alert_message=alert_prefix + " TP3 HIT | Full exit at " + str.tostring(tp3_price, format.mintick))
        else
            if low <= tp1_price
                strategy.close("Short", comment="TP", alert_message=alert_prefix + " TP HIT | Exit at " + str.tostring(tp1_price, format.mintick))
        
        if use_trailing_stop and tp1_hit
            risk_distance = math.abs(entry_price - stop_loss)
            trail_trigger = entry_price - (risk_distance * trail_activation)
            if low <= trail_trigger
                trail_stop = low + (risk_distance * trail_offset)
                strategy.exit("Trail", "Short", stop=trail_stop)

// Alert on stop loss hit
if strategy.position_size[1] != 0 and strategy.position_size == 0 and alert_on_sl
    if not tp1_hit
        alert(alert_prefix + " STOP LOSS HIT | Closed at " + str.tostring(close, format.mintick), alert.freq_once_per_bar)

// Alert on CISD signals
if alert_on_cisd and use_cisd
    if cisd_bullish_signal
        alert(alert_prefix + " CISD BULLISH 🔥 | Momentum shift detected", alert.freq_once_per_bar)
    if cisd_bearish_signal
        alert(alert_prefix + " CISD BEARISH 🔥 | Momentum shift detected", alert.freq_once_per_bar)

// ═══════════════════════════════════════════════════════════════════════════════
// VISUALIZE TP LEVELS
// ═══════════════════════════════════════════════════════════════════════════════

if show_tp_lines and strategy.position_size != 0 and barstate.islast
    // TP1 line
    line.new(bar_index - 10, tp1_price, bar_index + 10, tp1_price, color=color.new(color.green, 30), width=2, style=line.style_dashed, extend=extend.right)
    label.new(bar_index + 5, tp1_price, "TP1", style=label.style_label_left, color=color.new(color.green, 50), textcolor=color.white, size=size.tiny)
    
    if use_multiple_tp
        // TP2 line
        line.new(bar_index - 10, tp2_price, bar_index + 10, tp2_price, color=color.new(color.green, 50), width=1, style=line.style_dotted, extend=extend.right)
        label.new(bar_index + 5, tp2_price, "TP2", style=label.style_label_left, color=color.new(color.green, 70), textcolor=color.white, size=size.tiny)
        
        // TP3 line
        line.new(bar_index - 10, tp3_price, bar_index + 10, tp3_price, color=color.new(color.green, 70), width=1, style=line.style_dotted, extend=extend.right)
        label.new(bar_index + 5, tp3_price, "TP3", style=label.style_label_left, color=color.new(color.green, 80), textcolor=color.white, size=size.tiny)
    
    // SL line
    line.new(bar_index - 10, stop_loss, bar_index + 10, stop_loss, color=color.new(color.red, 30), width=2, style=line.style_solid, extend=extend.right)
    label.new(bar_index + 5, stop_loss, "SL", style=label.style_label_left, color=color.new(color.red, 50), textcolor=color.white, size=size.tiny)

'''

# Insert trade execution before visualization
exec_insert_point = code.find('// ═══════════════════════════════════════════════════════════════════════════════\n// VISUALIZATION (OPTIMIZED: Only redraw when needed)\n')
code = code[:exec_insert_point] + trade_execution + code[exec_insert_point:]

# Write the converted strategy file
with open('wick_rejection_sr_strategy_v3.pine', 'w', encoding='utf-8') as f:
    f.write(code)

print("✅ Strategy v3 created successfully!")
print("📁 File: wick_rejection_sr_strategy_v3.pine")
print("\n🎯 Features added:")
print("  ✓ Auto trading with strategy.entry() / strategy.close()")
print("  ✓ Multiple TP levels (TP1, TP2, TP3)")
print("  ✓ Dynamic TP based on next S/R level")
print("  ✓ Trailing stop logic")
print("  ✓ Daily trade limits")
print("  ✓ Comprehensive alert messages")
print("  ✓ TP/SL lines visualization")
print("\n📊 Ready to backtest and deploy!")

