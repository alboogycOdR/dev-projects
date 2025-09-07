# CRT Expert Advisor for MetaTrader 5

This Expert Advisor (EA) implements the Candle Range Theory (CRT) trading strategy, designed for multi-timeframe analysis and precise trade execution. It incorporates various entry methods, robust risk management, session management, filtering, and a real-time dashboard.

## Features

- **CRT Strategy Implementation**: Detects Accumulation, Manipulation, and Distribution phases based on H4 and M15 timeframes.
- **Multiple Entry Methods**:
    - Turtle Soup Entry
    - Order Block/Change of State Demand/Supply Entry
    - Third Candle Entry
    - Auto Best (automatic selection of optimal entry approach)
- **Risk Management**:
    - Configurable risk percentage per trade.
    - Minimum risk-reward ratio enforcement.
    - Maximum trades per day and session.
    - Maximum allowable spread filter.
    - Dynamic position sizing based on account balance and margin checks.
- **Session Management**: Allows trading during specific sessions (Sydney, Tokyo, Frankfurt, London, New York) with automatic GMT adjustment.
- **Advanced Filtering**: Technical filters (Inside Bar, Key Level confluence, CRT Plus, Nested CRT) and session/day filters (Monday/Friday filters, high-impact news avoidance, spread protection).
- **Operational Modes**:
    - Auto-Trading Mode: Fully automated scanning, signal display, and trade execution.
    - Manual Trading Mode: User decision with visual setup notifications and one-click BUY/SELL buttons.
    - Hybrid Mode: Allows switching between auto and manual.
- **Real-time Dashboard**:
    - Displays current CRT phase, visual CRT range indicators, and multi-timeframe alignment.
    - Live statistics: win rate, profit/loss, trades count, session performance, risk exposure.
    - Trade signals with bullish/bearish notifications and signal strength.
    - Customizable color themes, font sizes, and layout.
- **Alerts and Notifications**: Visual, audio, email, and mobile push notifications.

## Installation and Setup

1.  **Copy the `CRT_EA.mq5` file** to your MetaTrader 5 `MQL5/Experts` folder.
2.  **Restart MetaTrader 5** or refresh the 


Navigator panel to see the EA.
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
-   **Enable News Filter**: (Requires manual implementation/integration with a news calendar) Enable/disable trading during high-impact news events.
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


