# 714EA V8.00 - Features Explained

This document provides a detailed breakdown of the key features implemented in the 714EA V8.00.

## 1. Operating Modes

The EA has two primary modes, selectable via the `Operating_Mode` input parameter.

### Analysis & Alerts Mode (Default)

This is the EA's intended primary function. In this mode, the EA will:
*   Perform all its analysis of price action, time, and structure.
*   Scan for Anchor Price interactions, Order Blocks, and potential FVG fills.
*   Generate highly detailed alerts and send them to your Telegram (with a chart screenshot).
*   Draw visual indicators on the chart for backtesting and live analysis.
*   **It will NOT execute any trades.**

This mode turns the EA into a powerful, automated market scanner that finds high-probability setups for you to review as a discretionary trader.

### Trading Mode

This is a more traditional EA mode. If a valid setup is detected according to the EA's logic (e.g., interaction with a valid Order Block after bias is set), it will attempt to open a market order automatically. This mode is less emphasized and is secondary to the Analysis & Alerts functionality.

---

## 2. The Confluence Alert System

This is the flagship feature of V8.00 and represents the EA's core intelligence. It is controlled by the `require_confluence_for_alert` input.

### How It Works

Instead of sending an alert every time a single event occurs (like a price touch of an OB), the EA's new "brain," `CheckForConfluenceAlert`, analyzes each candle for multiple events happening at once.

The primary high-confluence scenario currently implemented is:
**Anchor Price Interaction + Order Block Interaction**

When the EA detects a candle that, for example, forms a high-quality rejection of the Daily Anchor Price AND simultaneously touches a valid, unmitigated Order Block, it will fire a **"HIGH CONFLUENCE ALERT!"**.

### Why This is Powerful

This method dramatically reduces the number of "low-quality" alerts. As a discretionary trader, you are always looking for multiple reasons to enter a trade. This system automates that process, only notifying you when the most significant factors align, saving you screen time and focusing your attention on A+ setups.

If `require_confluence_for_alert` is set to `false`, the EA will revert to sending alerts for every single event it detects (e.g., an OB touch, an anchor rejection), which can be useful for studying the market but may be noisier.

---

## 3. Anchor Price Interaction Alerts

The EA closely monitors the **Daily Anchor Price** (the 13:00 UTC+2 key price level) after the observation window has ended. It can trigger alerts for three specific types of interaction:

*   **Close Across Anchor**: The bar closes decisively on the other side of the anchor price line.
*   **Rejection of Anchor**: The bar wicks into the anchor price and closes back on the other side, forming a pin bar or rejection candle.
*   **Break and Retest**: Price first breaks the anchor price and then, on a subsequent candle, comes back to touch it again.

### Intelligent Rejection Filtering

To combat the "noise" of small, insignificant rejection candles on the M5 timeframe, the rejection alert logic includes advanced filters:

*   **Minimum Candle Size**: Ignores tiny doji-like candles that aren't meaningful.
*   **Wick-to-Body Ratio**: Ensures the rejecting wick is significantly larger than the candle's body, indicating a strong rejection.
*   **ATR Filter (Optional)**: Can be enabled to require that the total size of the rejection candle is larger than the current Average True Range, meaning it's a candle with significant volatility and conviction.

---

## 4. Visual On-Chart Alerts

To make backtesting and strategy refinement possible, all Telegram alerts have a corresponding visual representation on the chart, controlled by `visual_on_chart_alerts`.

When an alert is triggered (either single or confluence), the EA will:
1.  Draw a **symbol** (e.g., an arrow, diamond, or star) at the price and time of the event.
2.  Place a **text label** next to the symbol describing the event (e.g., "High-Quality Bearish Rejection", "CONF A+OB").

This allows you to run the EA in the Strategy Tester and see exactly where and why alerts would have been generated over historical data, which is invaluable for fine-tuning the parameters. 