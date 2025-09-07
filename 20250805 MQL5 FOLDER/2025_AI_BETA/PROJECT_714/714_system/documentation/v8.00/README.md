# 714 Method EA - Version 8.00

## Overview

Welcome to the documentation for the **SevenOneFourEA V8.00**, an expert advisor for MetaTrader 5 based on the "714 Method" by Mashaya.

This EA has evolved from a simple trade execution tool into a sophisticated **market analysis and high-confluence alert system**. It is designed to be a powerful assistant for the discretionary trader, automating the tedious aspects of market monitoring while leaving the final trade decisions to you.

Version 8.00 introduces a powerful **Confluence Filter**, which represents a major leap in the EA's intelligence. It can now identify high-probability setups where multiple technical conditions—such as an Anchor Price rejection and an Order Block interaction—align on the same candle.

## Key Features in Version 8.00

*   **Dual Operating Modes**:
    *   **Analysis & Alerts Mode**: The default and primary mode. The EA performs all analysis and sends detailed alerts without executing any trades.
    *   **Trading Mode**: A basic auto-trading mode for executing trades based on detected setups (less emphasis on this mode).

*   **Advanced Confluence Alert System**:
    *   The EA can now detect when an **Anchor Price** interaction occurs at the same time as an **Order Block** interaction, providing the highest quality alerts.
    *   A new input `require_confluence_for_alert` allows you to choose between these high-confluence alerts or alerts on single events.

*   **Intelligent Rejection Filtering**:
    *   Rejection candle alerts are now filtered for quality using candle anatomy (Wick-to-Body Ratio) and market volatility (ATR) to eliminate noise from the M5 timeframe.

*   **Visual Backtesting Alerts**:
    *   All alerts now draw symbols directly on the backtesting chart, allowing you to visually verify and refine the EA's logic without needing live alerts.

*   **Comprehensive Timezone & Session Management**:
    *   Automatically detects your broker's GMT offset.
    *   Draws key time windows (Morning, Afternoon, Primary) on the chart.

## Documentation Files

*   **[Installation Guide](./INSTALLATION.md)**: Step-by-step instructions for setting up the EA and its dependencies.
*   **[Features Explained](./FEATURES.md)**: A detailed look at what the EA does and how its core features work.
*   **[Input Parameters Reference](./INPUT_PARAMETERS.md)**: A complete guide to every setting in the EA.

---

This documentation will guide you through installing, configuring, and maximizing the potential of the 714 Method EA V8.00. 