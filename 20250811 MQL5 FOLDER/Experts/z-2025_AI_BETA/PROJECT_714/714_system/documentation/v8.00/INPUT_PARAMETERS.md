# 714EA V8.00 - Input Parameters Reference

This document provides a complete reference for all input parameters available in the EA. They are grouped by their category as seen in the EA's input settings window.

---

### `=== Operating Mode ===`
*   **Operating_Mode**: Sets the EA's main behavior.
    *   `ANALYSIS_ALERTS` (Default): The EA only analyzes and sends alerts, no trading.
    *   `TRADING`: The EA will attempt to execute trades based on its logic.

---

### `=== Trade Management Settings ===`
*   **magic_Number**: A unique number to identify trades opened by this EA.
*   **risk_Percent_Placeholder**: The percentage of your account equity to risk on a single trade. *Note: Only active in `TRADING` mode.*
*   **stop_Loss_Buffer_Pips**: Extra pips to add to the Stop Loss beyond the calculated high/low of an Order Block.
*   **take_Profit_Pips_Placeholder**: A fixed Take Profit in pips from the entry price.

---

### `=== Screenshot & Telegram Settings ===`
*   **enable_screenshot**: `true` to take a chart screenshot when an alert is triggered; `false` to disable.
*   **screenshot_subfolder**: The name of the subfolder within `MQL5/Files/` where screenshots will be saved (e.g., "714_Alerts").
*   **enable_telegram_alert**: `true` to send alerts to Telegram; `false` to disable.
*   **telegram_bot_token**: Your personal Telegram Bot API token.
*   **telegram_chat_id**: The Chat ID for your personal account or channel.
*   **telegram_message_prefix**: A custom text prefix to add to all Telegram alert messages.

---

### `--- Anchor Price Alert Triggers ---`
*   **alert_on_close_across_anchor**: `true` to enable alerts when a candle closes on the opposite side of the anchor price.
*   **alert_on_rejection_of_anchor**: `true` to enable alerts for high-quality rejection candles at the anchor price.
*   **alert_on_break_and_retest_of_anchor**: `true` to enable alerts when price breaks and subsequently retests the anchor price.

---

### `=== Confluence Alert Filter Settings ===`
*   **require_confluence_for_alert**: This is a master switch for alert quality.
    *   `true` (Default): The EA will **only** send an alert if multiple conditions align on the same candle (e.g., Anchor Rejection + OB Interaction).
    *   `false`: The EA will send an alert for every single valid event it detects.

---

### `=== Price Action Filter Settings ===`
*(These settings primarily apply to the `alert_on_rejection_of_anchor` logic)*
*   **min_wick_to_body_ratio**: Defines a "high-quality" rejection. E.g., a value of `1.5` means the wick must be at least 1.5 times the size of the candle's body.
*   **min_candle_size_pips**: The minimum total size of a candle (from high to low) in pips for it to be considered for a rejection alert. This filters out insignificant doji candles.
*   **use_atr_filter**: `true` to enable an additional volatility filter. The total size of the candle must also be greater than the current ATR value.
*   **atr_period**: The period used for the Average True Range (ATR) calculation if `use_atr_filter` is true.

---

### `=== Broker Timezone Settings ===`
*   **auto_detect_gmt_offset**: `true` to automatically calculate your broker's GMT offset. `false` to use the manual setting.
*   **manual_gmt_offset_hours**: Manually set your broker's GMT offset if auto-detect fails or is disabled.

---

### `=== Custom Indicator Settings ===`
*This section controls the underlying `SmartMoneyConcepts` indicator that the EA uses. These settings primarily affect the visual display of the indicator itself, not the EA's core logic.*
*   **indicator_mode**: `Historical` for backtesting, `Present` for live.
*   **indicator_style**: `Colored` or `Monochrome` style for indicator drawings.
*   **ColorCandles**: `true` to allow the indicator to color the chart's candles.
*   **ShowInternalStructure**: `true` to show internal market structure breaks.
*   ... (and other visual settings for the indicator) ...

---

### `=== Primary Key Time Settings (UTC+2) ===`
*   **utcPlus2_KeyHour_1300**: The primary hour for the daily anchor price (Default: 13 for 13:00).
*   **utcPlus2_KeyMinute_1300**: The primary minute for the daily anchor price.
*   **observation_Duration_Minutes**: How many minutes after the key time the EA should observe price action to determine the daily bias.
*   **entry_Candlestick_Index**: Deprecated/less relevant in v8.00.
*   **use_entry_search_window**: `true` to define a specific window of time each day when the EA should look for signals.

---

### `=== Morning Zone Settings (UTC+2) ===`
*   **enable_morning_zone**: `true` to draw and monitor the morning session timebox.
*   **morning_zone_start_hour_utc2**: Start hour (UTC+2) for the morning zone.
*   **morning_zone_end_hour_utc2**: End hour (UTC+2) for the morning zone.
*   **morning_zone_color**: Color for the morning zone visuals.

---

### `=== Afternoon Zone Settings (UTC+2) ===`
*   **enable_afternoon_zone**: `true` to draw and monitor the afternoon session timebox.
*   **afternoon_zone_start_hour_utc2**: Start hour (UTC+2) for the afternoon zone.
*   **afternoon_zone_end_hour_utc2**: End hour (UTC+2) for the afternoon zone.
*   **afternoon_zone_color**: Color for the afternoon zone visuals.
*   **entry_search_end_hour_utc2**: The hour (UTC+2) to stop looking for any signals for the day.
*   **entry_search_end_minute_utc2**: The minute to stop looking for any signals.
*   **session_End_UTC2_Hour**: The hour (UTC+2) when all open trades managed by the EA should be closed.
*   **session_End_UTC2_Minute**: The minute for the session end.

---

### `=== Order Block Detection Settings ===`
*   **ob_Lookback_Bars_For_Impulse**: The number of bars to look at after a potential OB candle to find a confirming impulsive move.
*   **ob_MinMovePips**: The minimum size in pips of the impulsive move required to validate an OB.
*   **ob_MaxBlockCandles**: Maximum number of consolidated candles that can form an OB.
*   **scan_before_obs_end_only**: `true` to only detect OBs that form before the main observation window ends.

---

### `=== Visual Display Settings ===`
*   **visual_enabled**: The master switch. `false` disables ALL visual drawings by the EA.
*   **visual_main_timing_lines**: `true` to draw the vertical lines for Key Time and Observation End.
*   **visual_order_blocks**: `true` to draw the detected Order Block rectangles on the chart.
*   **visual_obs_price_line**: `true` to draw the horizontal anchor price line.
*   **visual_on_chart_alerts**: `true` to display visual alert symbols on the chart, crucial for backtesting.
*   **historic_view_enabled**: `true` to draw the time zones for previous days on the chart.
*   **historic_view_days**: How many past days to draw the historic zones for.
*   ...(other color and style settings)...

---

### `=== Labeling Settings ===`
*   **label_scan_interval_seconds**: How often the EA should rescan for indicator objects to apply labels to.
*   **chart_refresh_delay_ms**: A small delay to wait before scanning for tooltips, allowing the chart to fully render. 