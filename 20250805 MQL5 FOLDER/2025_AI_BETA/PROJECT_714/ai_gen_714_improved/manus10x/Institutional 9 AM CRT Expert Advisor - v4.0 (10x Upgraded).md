# Institutional 9 AM CRT Expert Advisor - v4.0 (10x Upgraded)

This document provides comprehensive information about the **Institutional 9 AM CRT Expert Advisor (v4.0)**, a significantly enhanced and upgraded version of the original EA. This version focuses on a professional-grade graphical user interface, an intelligent decision-making layer, and dynamic multi-stage trade management.

## Table of Contents
1.  [Overview](#1-overview)
2.  [Key Features (10x Upgrades)](#2-key-features-10x-upgrades)
3.  [Installation](#3-installation)
4.  [Configuration](#4-configuration)
5.  [Usage](#5-usage)
6.  [Troubleshooting](#6-troubleshooting)
7.  [Disclaimer](#7-disclaimer)

## 1. Overview

The Institutional 9 AM CRT Expert Advisor (EA) is an automated trading system designed for MetaTrader 5 (MT5) that implements the advanced Candle Range Theory (CRT) methodology, specifically focusing on the 9 AM New York session. This 10x upgraded version (v4.0) incorporates significant enhancements across its user interface, core trading logic, and risk management capabilities, aiming to provide a more robust, intelligent, and user-friendly trading experience.

## 2. Key Features (10x Upgrades)

### 2.1 GUI Revolution (Interactive Dashboard)

*   **Dynamic Information Display:** Real-time updates on market bias, CRT range, key levels, trade states, and active signals directly on the chart.
*   **Tabbed Interface:** Organized sections for Overview, Settings, Performance, and Logs, allowing for a cleaner and more intuitive user experience.
*   **Interactive Controls:** Buttons and input fields directly on the chart for quick adjustments to operational modes and other parameters (future expansion).

### 2.2 Intelligence Layer

*   **Enhanced Higher Timeframe Analysis:** More sophisticated algorithms for determining daily bias and identifying Higher Timeframe Key Levels (HTF KL) and Draw on Liquidity (DOL) targets.
*   **Advanced Contextual Filters:** Integration of:
    *   **Weekly Profile Analysis:** Filter trades based on the current week's price action (trending, ranging, reversal).
    *   **SMT Divergence Detection:** Identify Smart Money Tool (SMT) divergences between correlated assets to confirm trade setups.
    *   **High-Impact News Avoidance:** Automatically pause trading during high-impact news events to mitigate risk.
*   **Confluence Scoring (Future Integration):** A system to assign a score based on the alignment of multiple indicators and filters, providing a clearer picture of trade validity.

### 2.3 Dynamic Management

*   **Multi-Stage Take Profit:** Implement up to three distinct Take Profit (TP) levels with customizable Risk:Reward (RR) ratios and partial close percentages.
*   **Advanced Breakeven:** Automatically move Stop Loss (SL) to breakeven after the first Take Profit level is hit.
*   **Intelligent Trailing Stop:** A more adaptive trailing stop mechanism to lock in profits as the trade moves favorably.
*   **Position Sizing:** Robust calculation of lot size based on a defined risk percentage per trade.

### 2.4 Robust Logging and Error Handling

*   **Custom Logging System:** A dedicated logging function (`LogMessage`) with different message types (INFO, WARNING, ERROR, DEBUG) for better traceability and debugging.
*   **Comprehensive Error Reporting:** Detailed error messages for trade execution failures and data retrieval issues.
*   **Performance Optimization:** Underlying code optimizations for efficient execution and minimal resource consumption.

## 3. Installation

1.  **Download:** Download the `Institutional_9AM_CRT_v4.0.mq5` file.
2.  **Open MetaTrader 5:** Launch your MT5 terminal.
3.  **Open Data Folder:** Go to `File -> Open Data Folder`.
4.  **Navigate to MQL5:** In the opened folder, navigate to `MQL5 -> Experts`.
5.  **Paste EA:** Paste the `Institutional_9AM_CRT_v4.0.mq5` file into the `Experts` folder.
6.  **Refresh Navigato**r: Close the Data Folder. In MT5, go to the `Navigator` panel (Ctrl+N). Right-click on `Expert Advisors` and select `Refresh`.
7.  **Attach to Chart:** Drag and drop the `Institutional 9 AM CRT Expert Advisor v4.0` from the `Navigator` panel onto the desired currency pair chart (e.g., EURUSD, GBPUSD) with a **M15 timeframe**.
8.  **Allow Algo Trading:** In the EA settings window (Common tab), ensure `Allow Algo Trading` is checked.

## 4. Configuration

Upon attaching the EA to a chart, the input parameters window will appear. Configure the following settings:

### CRT Core Settings
*   **CRTModelSelection:** Select the desired CRT model (e.g., `CRT_9AM_NY` for 9 AM New York session).
*   **EntryLogicModel:** Choose your preferred entry model (`CONFIRMATION_MSS` for Market Structure Shift + FVG/OB, or `AGGRESSIVE_TURTLE_SOUP` for immediate entry on sweep).
*   **Broker_GMT_Offset_Hours:** **IMPORTANT:** Set this to your broker's GMT offset (e.g., 3 for GMT+3). This is crucial for accurate time calculations.

### Risk & Trade Management
*   **RiskPercent:** Percentage of your account balance to risk per trade (e.g., 0.5 for 0.5%).
*   **TakeProfit1_RR:** Risk:Reward ratio for the first Take Profit level (e.g., 1.0 for 1:1 RR).
*   **MoveToBE_After_TP1:** Set to `true` to move Stop Loss to breakeven after TP1 is hit.
*   **Daily_Max_Trades:** Maximum number of trades the EA will take per day.
*   **NY_Killzone_Start / NY_Killzone_End:** Define the New York Killzone trading window (e.g., 09:00 to 12:00).

### Advanced Contextual Filters
*   **Filter_By_Daily_Bias:** Set to `true` to strictly enforce the daily bias filter.
*   **Filter_By_HTF_KL:** Set to `true` to require the sweep to occur at a Higher Timeframe Key Level.
*   **Filter_By_WeeklyProfile:** Enable/disable the weekly profile filter.
*   **WeeklyProfileType:** Expected weekly profile type (Trending, Range, Reversal) if `Filter_By_WeeklyProfile` is enabled.
*   **Filter_By_SMTDivergence:** Enable/disable the SMT Divergence filter.
*   **CorrelatedSymbol:** Specify the correlated symbol for SMT Divergence analysis (e.g., EURUSD for GBPUSD).
*   **Filter_By_HighImpactNews:** Enable/disable trading during high-impact news events.
*   **NewsLookbackMinutes:** Minutes before/after news to avoid trading.

### Advanced Trade Management
*   **UseMultiTP:** Enable multi-stage Take Profit.
*   **TakeProfit2_RR / TakeProfit3_RR:** Risk:Reward ratios for TP2 and TP3.
*   **PartialClose1_Percent / PartialClose2_Percent:** Percentage of volume to close at TP1 and TP2.
*   **UseTrailingStop:** Enable intelligent trailing stop.
*   **TrailingStopPips / TrailingStepPips:** Parameters for the trailing stop.

### Operational Mode
*   **OperationalMode:** Choose between `SIGNALS_ONLY` (EA provides signals but doesn't trade), `FULLY_AUTOMATED` (EA executes trades automatically), or `HYBRID_MODE` (EA provides signals and allows manual confirmation).

## 5. Usage

Once configured, the EA will operate according to the selected `OperationalMode`.

*   **Signals Only:** The EA will display potential trade setups and signals on the chart and in the Experts tab of the Terminal window. You will need to manually execute trades.
*   **Fully Automated:** The EA will automatically identify setups, apply filters, and execute trades based on your defined risk and trade management settings.
*   **Hybrid Mode:** The EA will identify setups and provide signals, but will wait for your manual confirmation before executing a trade (future UI integration for confirmation button).

**Dashboard Interaction:**

*   **Tabs:** Click on the 


tabs (Overview, Settings, Performance, Logs) at the bottom of the dashboard to switch between different views.
*   **Dynamic Values:** Observe real-time updates on the Overview tab for market bias, DOL target, HTF KL zone, and trade states.
*   **Toggle Auto Mode:** On the Settings tab, you can click the "Toggle Auto Mode" button to switch between `FULLY_AUTOMATED` and `SIGNALS_ONLY` modes.

## 6. Troubleshooting

*   **EA not trading:**
    *   Ensure `Allow Algo Trading` is checked in the EA settings and the Algo Trading button in MT5 toolbar is green.
    *   Check the `Experts` tab in the Terminal window for any error messages.
    *   Verify your internet connection.
    *   Ensure your broker allows automated trading.
    *   Check if `Daily_Max_Trades` has been reached.
    *   Verify that the current time is within the `NY_Killzone_Start` and `NY_Killzone_End`.
    *   Review the `LogMessage` output for any filtering reasons (e.g., Weekly Profile, SMT Divergence, High-Impact News).
*   **Dashboard not appearing:**
    *   Ensure the EA is successfully attached to the chart.
    *   Check for any errors in the `Experts` tab that might prevent object creation.
*   **Incorrect time calculations:**
    *   Double-check your `Broker_GMT_Offset_Hours` input parameter. This is critical.

## 7. Disclaimer

Trading foreign exchange on margin carries a high level of risk, and may not be suitable for all investors. The high degree of leverage can work against you as well as for you. Before deciding to invest in foreign exchange you should carefully consider your investment objectives, level of experience, and risk appetite. The possibility exists that you could sustain a loss of some or all of your initial investment and therefore you should not invest money that you cannot afford to lose. You should be aware of all the risks associated with foreign exchange trading, and seek advice from an independent financial advisor if you have any doubts.

This Expert Advisor is provided for educational and informational purposes only. Past performance is not indicative of future results. The developer is not responsible for any losses incurred from the use of this software.


