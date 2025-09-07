 The Strategy Tester **cannot** execute functions that rely on external communications (`WebRequest`) or writing files outside its sandboxed environment (`ChartScreenShot`).

Therefore, we absolutely need to find a way to **simulate these alerts visually on the backtesting chart** so we can verify the trigger logic is working correctly.

This is an excellent next step. We will now add a new visual alerting system that works within the Strategy Tester.

## Plan Update: Adding Visual On-Chart Alerts for Backtesting

We will introduce a new system that draws visual cues on the chart whenever an alert trigger is met in **"Analysis & Alert Mode"**. This will allow us to see the exact bar where an alert *would have been sent* via Telegram.

### 1. New Input Parameter: Backtest Visual Alerts

First, we need a way to turn this specific feature on or off.

```mql5
// Add to the "Visual Display Settings" input group in the EA
input bool     visual_on_chart_alerts   = true;  // Show visual alerts on chart during backtest/live
```
This flag will control whether the new drawing functions are called.

### 2. Implementation: The `DrawAlertSymbol` Function

We'll create a new master function responsible for drawing a symbol and text on the chart to represent a triggered alert. This function will be called *instead of* or *in addition to* the `TakeScreenshot` and `SendTelegramAlert` functions when an alert condition is met.

```mql5
// This will be a new function in the "VISUALIZATION & UTILITY FUNCTIONS" section

// --- Draws a symbol and text on the chart to indicate a triggered alert ---
void DrawAlertSymbol(int bar_index, double price, string description, color symbol_color, uint symbol_code)
{
    // Do not draw if visuals are disabled or the on-chart alerts are disabled
    if(!visual_enabled || !visual_on_chart_alerts) return;

    // Create a unique name for the alert object using its time and description type
    datetime alert_time = iTime(_Symbol, Period(), bar_index);
    string obj_name = "Alert_" + description + "_" + TimeToString(alert_time, TIME_DATE|TIME_MINUTES|TIME_SECONDS);

    // --- Create the Arrow Symbol ---
    if(ObjectCreate(0, obj_name, OBJ_ARROW, 0, alert_time, price))
    {
        ObjectSetInteger(0, obj_name, OBJPROP_ARROWCODE, symbol_code);
        ObjectSetInteger(0, obj_name, OBJPROP_COLOR, symbol_color);
        ObjectSetInteger(0, obj_name, OBJPROP_WIDTH, 2);
        ObjectSetInteger(0, obj_name, OBJPROP_SELECTABLE, false);
        
        // --- Create a Corresponding Text Label ---
        string label_name = "AlertLabel_" + description + "_" + TimeToString(alert_time, TIME_DATE|TIME_MINUTES|TIME_SECONDS);
        double label_price = price + 50 * _Point; // Position the text slightly above/below the arrow (adjust as needed)

        if(ObjectCreate(0, label_name, OBJ_TEXT, 0, alert_time, label_price))
        {
            ObjectSetString(0, label_name, OBJPROP_TEXT, description);
            ObjectSetInteger(0, label_name, OBJPROP_COLOR, symbol_color);
            ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 8);
            ObjectSetInteger(0, label_name, OBJPROP_ANCHOR, ANCHOR_BOTTOM); // Anchor text below the price point
            ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
        }
        
        ChartRedraw(0); // Update the chart to show the new alert symbol
    }
}
```

*Symbol Codes Note:* MQL5 has a standard set of "Wingdings" font symbols we can use for arrows. For example:
*   `241`: Up arrow (for bullish alerts)
*   `242`: Down arrow (for bearish alerts)
*   `159`: A simple square (for neutral alerts, like retest)

### 3. Modifying the Alert Trigger Functions to Use `DrawAlertSymbol`

Now, we update the logic in `CheckAnchorPriceInteraction` and similar future functions. When a trigger condition is met, we'll call this new drawing function.

```mql5
// Revised version of the CheckAnchorPriceInteraction function (excerpt)

void CheckAnchorPriceInteraction(int bar_idx)
{
    if (g_DailyAnchorPrice <= 0) return;
    
    // Get bar data...
    double close = iClose(_Symbol, _Period, 1);
    // ...get other prices...
    
    // --- Alert Trigger 1: Close Across Anchor ---
    if (alert_on_close_across_anchor && !g_close_across_alert_sent)
    {
        if (prev_close < g_DailyAnchorPrice && close > g_DailyAnchorPrice)
        {
            // ... set flags as before ...
            string desc = Symbol() + ": Closed above Anchor";
            
            // Log to journal AND Draw Visual Alert
            Print(desc); 
            DrawAlertSymbol(bar_idx, close, "Close Above", clrDodgerBlue, 241); // Draw a blue up arrow at the close price
            
            // External alerts would follow (and be skipped in backtest)
            string screenshot_path = TakeScreenshot();
            SendTelegramAlert(desc, screenshot_path);
            return;
        }
        // ... similar logic for closing below, but draw a down arrow...
        if (prev_close > g_DailyAnchorPrice && close < g_DailyAnchorPrice)
        {
            // ... set flags ...
            string desc = Symbol() + ": Closed below Anchor";
            Print(desc);
            DrawAlertSymbol(bar_idx, close, "Close Below", clrMediumVioletRed, 242); // Draw a red down arrow
            //... external alerts ...
            return;
        }
    }
    
    // --- Alert Trigger 2: Rejection of Anchor ---
    if(alert_on_rejection_of_anchor)
    {
        bool bullish_rejection = (low < g_DailyAnchorPrice && close > g_DailyAnchorPrice);
        bool bearish_rejection = (high > g_DailyAnchorPrice && close < g_DailyAnchorPrice);

        if(bullish_rejection || bearish_rejection)
        {
            string desc;
            uint symbol_code;
            color symbol_color;
            double price_point;

            if(bullish_rejection) {
                desc = "Bullish Rejection";
                symbol_code = 241; // Up Arrow
                symbol_color = clrLimeGreen;
                price_point = low; // Place the alert symbol at the low of the rejection candle
            } else {
                desc = "Bearish Rejection";
                symbol_code = 242; // Down Arrow
                symbol_color = clrRed;
                price_point = high; // Place the alert symbol at the high of the rejection candle
            }

            // ... Use cooldown logic to prevent spam ...
            static datetime last_rejection_alert_time = 0;
            if(TimeCurrent() > last_rejection_alert_time + 60 * 5) 
            {
                 Print(Symbol() + " ALERT: " + desc + " of Daily Anchor Price.");
                 DrawAlertSymbol(bar_idx, price_point, desc, symbol_color, symbol_code);
                 //... external alerts ...
                 last_rejection_alert_time = TimeCurrent();
            }
        }
    }

    // --- Alert Trigger 3: Break and Retest ---
    if (alert_on_break_and_retest_of_anchor && g_anchor_price_broken && !g_retest_alert_sent)
    {
        if (low <= g_DailyAnchorPrice && high >= g_DailyAnchorPrice)
        {
             //... set retest_alert_sent flag ...
             string desc = "Break & Retest";
             Print(Symbol() + " ALERT: " + desc + " of Daily Anchor Price.");
             DrawAlertSymbol(bar_idx, g_DailyAnchorPrice, desc, clrGold, 159); // Draw a Gold Square at the anchor price
             //... external alerts ...
        }
    }
}
```

This updated plan fully addresses your requirement. It adds a crucial layer of visual feedback that is indispensable for strategy testing. When you run a backtest now with `visual_on_chart_alerts` enabled, your chart will be populated with clear arrow and text markers at the exact candles where alerts would have been sent, allowing you to instantly validate if the logic is capturing the intended price action correctly, without needing the Telegram/screenshot functions to work. This makes development and refinement significantly faster and more efficient.