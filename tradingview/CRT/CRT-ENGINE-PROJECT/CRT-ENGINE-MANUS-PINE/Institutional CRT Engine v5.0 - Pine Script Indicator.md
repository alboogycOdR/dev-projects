# Institutional CRT Engine v5.0 - Pine Script Indicator

This document provides comprehensive information about the **Institutional CRT Engine v5.0** Pine Script indicator. This updated version includes accurate 4-hour and 1-hour CRT range drawing, as well as detection and visualization of various 3-candle models, aligning the indicator more closely with institutional Candle Range Theory (CRT) methodologies.

## Table of Contents
1.  [Overview](#1-overview)
2.  [Key Features (v5.0 Updates)](#2-key-features-v50-updates)
3.  [Installation](#3-installation)
4.  [Configuration](#4-configuration)
5.  [Usage](#5-usage)
6.  [Troubleshooting](#6-troubleshooting)
7.  [Disclaimer](#7-disclaimer)

## 1. Overview

The Institutional CRT Engine v5.0 is a Pine Script indicator designed for TradingView that helps traders identify high-probability Candle Range Theory (CRT) setups. It focuses on the core principles of Time, Liquidity, and Market Structure Shifts, now with enhanced accuracy for CRT range identification and the addition of powerful 3-candle pattern recognition.

## 2. Key Features (v5.0 Updates)

### 2.1 Accurate CRT Range Drawing

*   **Precise Time Synchronization:** The indicator now uses robust time synchronization to accurately identify and draw CRT ranges based on specific New York session hours (1 AM, 5 AM, 9 AM for 1-hour; 00:00, 04:00, 08:00 for 4-hour).
*   **Dynamic Visualization:** The CRT range is drawn as a persistent box on the chart, extending to the right, and includes clear labels for CRT High and CRT Low, improving visual clarity.
*   **Daily Reset:** The CRT range automatically resets at the start of each new trading day (New York time) to ensure relevance to the current session.

### 2.2 3-Candle Model Detection

*   **Comprehensive Pattern Recognition:** The indicator can now detect and visualize the following 3-candle patterns:
    *   **Three White Soldiers:** Bullish reversal pattern.
    *   **Three Black Crows:** Bearish reversal pattern.
    *   **Morning Star:** Bullish reversal pattern.
    *   **Evening Star:** Bearish reversal pattern.
    *   **Three Inside Up:** Bullish continuation/reversal pattern.
    *   **Three Inside Down:** Bearish continuation/reversal pattern.
*   **Visual Cues:** When a 3-candle pattern is detected, a label indicating the pattern name is displayed on the chart.
*   **Configurable Alerts:** Users can enable alerts for each specific 3-candle pattern, providing timely notifications.

### 2.3 Existing Features (from v3.4)

*   **CRT Model Selection:** Choose between various 1-hour and 4-hour CRT models based on different session times.
*   **Entry Logic:** Supports 


MSS + FVG (Market Structure Shift + Fair Value Gap) and Aggressive Turtle Soup entry logics.
*   **Advanced Filters:** Includes options for Higher Timeframe Key Level (HTF KL) confluence and Smart Money Technique (SMT) Divergence filtering.
*   **Display & Alerts:** Customizable options to show CRT range boxes, buy/sell signals, and enable alerts.

## 3. Installation

1.  **Open TradingView:** Go to [TradingView.com](https://www.tradingview.com/) and open your chart.
2.  **Open Pine Editor:** Click on the `Pine Editor` tab at the bottom of your chart.
3.  **Create New Indicator:** Delete any existing code in the editor. Copy the entire code from `CRT_Engine_v5.0.pine` and paste it into the Pine Editor.
4.  **Save:** Click the `Save` button and give your indicator a name (e.g., "Institutional CRT Engine v5.0").
5.  **Add to Chart:** Click the `Add to Chart` button. The indicator will now appear on your chart.

## 4. Configuration

After adding the indicator to your chart, you can configure its settings by double-clicking on the indicator name on the chart or by clicking the gear icon next to its name.

### CRT Core Settings
*   **CRT Model:** Select the session candle to base the CRT range on (e.g., "1H - 9 AM NY", "4H - London Open (00:00)").
*   **Entry Logic:** Choose your preferred entry model ("MSS + FVG" or "Aggressive Turtle Soup").

### Advanced Filters
*   **Require HTF Key Level Confluence:** If checked, setups are valid only if the manipulation sweep occurs within a pre-identified H4 FVG or Orderblock.
*   **HTF Key Level Lookback (H4 Bars):** Number of H4 bars to look back for Key Levels.
*   **Enable SMT Divergence Filter:** Filters for SMT divergence between the current asset and a correlated one.
*   **SMT Correlated Symbol:** Specify the correlated symbol for SMT analysis (e.g., "ES1!").

### Display & Alert Settings
*   **Show CRT Range Box:** Toggle visibility of the CRT range box.
*   **Show Buy/Sell Signals:** Toggle visibility of buy/sell signal labels.
*   **Enable Alerts:** Master switch for all alerts.
*   **Alert Frequency:** Choose between "Once Per Bar" or "Once Per Bar Close".

### 3-Candle Pattern Settings
*   **Enable Three White Soldiers:** Enable/disable detection of this bullish pattern.
*   **Enable Three Black Crows:** Enable/disable detection of this bearish pattern.
*   **Enable Morning Star:** Enable/disable detection of this bullish pattern.
*   **Enable Evening Star:** Enable/disable detection of this bearish pattern.
*   **Enable Three Inside Up:** Enable/disable detection of this bullish pattern.
*   **Enable Three Inside Down:** Enable/disable detection of this bearish pattern.

## 5. Usage

Once configured, the indicator will automatically draw the selected CRT range and identify 3-candle patterns on your chart. 

*   **CRT Range:** The gray box represents the CRT range. The `CRT High` and `CRT Low` labels indicate the boundaries of this range. A new range will be drawn each day based on your selected model.
*   **Buy/Sell Signals:** These labels (▲ BUY, ▼ SELL) indicate potential entry points based on the CRT methodology and your chosen entry logic.
*   **3-Candle Patterns:** When a configured 3-candle pattern is detected, a label with the pattern name will appear above/below the candles forming the pattern.

## 6. Troubleshooting

*   **Indicator not appearing:** Ensure you have correctly saved and added the indicator to your chart in the Pine Editor.
*   **CRT Range not drawing:**
    *   Verify your `CRT Model` selection. Ensure the chosen session time has passed for the current day.
    *   Check the chart timeframe. The indicator works best on lower timeframes (e.g., M15, M5) while requesting higher timeframe data.
*   **3-Candle Patterns not appearing:** Ensure you have enabled the specific 3-candle patterns you wish to detect in the indicator settings.
*   **Alerts not firing:**
    *   Ensure `Enable Alerts` is checked.
    *   Ensure you have set up alerts in TradingView (right-click on the chart -> `Add alert` -> select the indicator).

## 7. Disclaimer

Trading financial instruments carries a high level of risk, and may not be suitable for all investors. The high degree of leverage can work against you as well as for you. Before deciding to invest in financial instruments, you should carefully consider your investment objectives, level of experience, and risk appetite. The possibility exists that you could sustain a loss of some or all of your initial investment and therefore you should not invest money that you cannot afford to lose. You should be aware of all the risks associated with trading, and seek advice from an independent financial advisor if you have any doubts.

This Pine Script indicator is provided for educational and informational purposes only. Past performance is not indicative of future results. The developer is not responsible for any losses incurred from the use of this software.


