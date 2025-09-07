# CRT Expert Advisor for MetaTrader 5 (Institutional "9 AM CRT" Model)

This Expert Advisor (EA) implements the Institutional "9 AM CRT" Model, a sophisticated trading strategy designed for multi-timeframe analysis, hierarchical decision-making, and precise trade execution. It incorporates advanced filtering, dynamic risk management, and an interactive real-time dashboard.

## Features

- **Hierarchical Trade Framing Protocol**:
    - **Higher Timeframe Bias & Draw on Liquidity (DOL)**: Determines daily bias (bullish/bearish) and identifies the direction of expected manipulation.
    - **Higher Timeframe Key Level (KL) Identification**: Pinpoints significant H4/Daily PD Arrays (Orderblocks, Fair Value Gaps, Breaker Blocks, Liquidity Voids) in the direction of expected manipulation.
    - **The Timed Range (8 AM NY ET 1-Hour candle CRT High/Low)**: Captures and visualizes the high and low of the 8 AM New York ET 1-hour candle, crucial for identifying liquidity sweeps.
- **Multiple Entry Methods**:
    - **Confirmation Entry (Order Block / CSD Model)**: Strict three-part sequence: Liquidity Purge, Market Structure Shift (M15), and retracement into M15 Orderblock/Breaker Block/FVG.
    - **Aggressive Entry (Turtle Soup Model)**: Identifies false breakouts of previous highs/lows with immediate reversals.
    - **3-Candle Pattern Entry**: Detects strong directional momentum based on three consecutive bullish or bearish candles.
- **Dynamic Risk & Trade Management**:
    - **Position Sizing**: Calculates optimal lot size based on configurable risk percentage and stop loss.
    - **CRT-Based SL/TP**: Sets Stop Loss and Take Profit levels dynamically based on CRT levels and a defined Risk-Reward ratio.
    - **Breakeven Functionality**: Automatically moves Stop Loss to breakeven after a specified profit target is reached.
    - **Trailing Stop**: Implements a trailing stop loss to protect profits as the trade moves favorably.
- **Advanced Contextual Filters**:
    - **Weekly Profile**: Analyzes the weekly candle structure for broader market context.
    - **SMT Divergence**: Detects Smart Money Tool divergence between correlated assets for confirmation or invalidation.
    - **High-Impact News Filter**: Avoids trading during significant economic news releases using the MQL5 Economic Calendar.
- **Session Management**: Allows trading during specific sessions (Sydney, Tokyo, Frankfurt, London, New York) with automatic GMT adjustment.
- **Operational Modes**:
    - **Auto-Trading Mode**: Fully automated scanning, signal display, and trade execution.
    - **Manual Trading Mode**: User decision with visual setup notifications and one-click BUY/SELL buttons.
    - **Hybrid Mode**: Allows switching between auto and manual, with a "Confirm Trade" button for user intervention.
- **Real-time Dashboard**:
    - Displays current CRT phase, visual CRT range indicators, and multi-timeframe alignment.
    - Live statistics: win rate, profit/loss, trades count, session performance, risk exposure.
    - Trade signals with bullish/bearish notifications and signal strength.
    - Customizable color themes, font sizes, and layout.
- **Alerts and Notifications**: Visual, audio, email, and mobile push notifications.

## Installation and Setup

1.  **Copy the `CRT_EA.mq5` file** to your MetaTrader 5 `MQL5/Experts` folder.
2.  **Restart MetaTrader 5** or refresh the Navigator panel to see the EA.
3.  **Attach the EA to an H4 chart** of any currency pair. It is recommended to use a demo account for initial testing.
4.  **Configure Input Parameters**: Adjust the settings in the EA's input tab according to your preferences and risk tolerance.

## Input Parameters

-   **Operational Mode**: Choose between Auto-Trading, Manual Trading, or Hybrid.
-   **Risk Percentage**: Percentage of account balance to risk per trade (e.g., 1.0 for 1%).
-   **Minimum Risk-Reward**: Minimum acceptable risk-reward ratio for trades.
-   **Max Trades Per Day**: Maximum number of trades allowed in a 24-hour period.
-   **Max Trades Per Session**: Maximum number of trades allowed within a single trading session.
-   **Max Spread**: Maximum allowed spread in pips for trade execution.
-   **Trading Session**: Select the trading session(s) during which the EA should operate (Sydney, Tokyo, Frankfurt, London, New York, or Global).
-   **Enable Monday/Friday Filter**: Enable/disable trading on Mondays and Fridays.
-   **Enable News Filter**: Enable/disable trading during high-impact news events. Uses MQL5 Economic Calendar.
-   **Auto Detect Daily Bias**: Set to `true` to automatically determine daily bias (bullish/bearish) based on higher timeframe analysis. If `false`, use `Manual Daily Bias`.
-   **Manual Daily Bias**: Manually set the daily bias (Bullish, Bearish, or None) if `Auto Detect Daily Bias` is `false`.
-   **Dashboard Theme Color**: Customize the background color of the real-time dashboard.
-   **Dashboard Font Size**: Customize the font size of the dashboard text.
-   **Enable Visual Alerts**: Enable/disable on-screen pop-up alerts.
-   **Enable Audio Alerts**: Enable/disable sound notifications.
-   **Audio File**: Specify the sound file for audio alerts (e.g., "alert.wav").
-   **Enable Email Alerts**: Enable/disable email notifications (requires MetaTrader 5 email settings).
-   **Email Subject**: Subject line for email alerts.
-   **Enable Push Notifications**: Enable/disable mobile push notifications (requires MetaTrader 5 mobile app settings).

## Important Notes

-   **Backtesting**: Thoroughly backtest the EA on historical data to understand its performance characteristics.
-   **Demo Account**: Always test on a demo account before deploying to a live trading account.
-   **Risk Management**: Adhere to proper risk management principles. The EA provides tools, but ultimate responsibility lies with the user.
-   **Optimization**: Optimize input parameters for different currency pairs and market conditions.

## Disclaimer

Trading foreign exchange on margin carries a high level of risk, and may not be suitable for all investors. The high degree of leverage can work against you as well as for you. Before deciding to invest in foreign exchange you should carefully consider your investment objectives, level of experience, and risk appetite. The possibility exists that you could sustain a loss of some or all of your initial investment and therefore you should not invest money that you cannot afford to lose.


