Write MQL5 code for an Expert Advisor (EA) that implements the Candle Range Theory (CRT) trading strategy as described below.

The EA should embody the full CRT cycle methodology involving three distinct phases: Accumulation (identifying institutional position building), Manipulation (detecting false breakouts and liquidity grabs), and Distribution (recognizing profit taking and reversals by institutions). It must perform multi-timeframe analysis combining the H4 timeframe for CRT pattern identification and M15 timeframe for precise entry timing.

Entry methods supported should include:
- Turtle Soup Entry (advanced fake breakout reversal detection)
- Order Block/Change of State Demand/Supply Entry (recommended institutional order block detection)
- Third Candle Entry (beginner-friendly 3-candle confirmation pattern)
- Auto Best (automatic selection of optimal entry approach based on market conditions)

The EA should allow configuration of trading sessions (Sydney, Tokyo, Frankfurt, London, New York) with automatic GMT adjustment for the broker server time and enable trading during specified sessions or globally.

Risk management features must be integrated, including:
- Risk percentage per trade (1-2%, never exceeding 2%)
- Minimum risk-reward ratio enforcement
- Maximum trades per day and session
- Maximum allowable spread filter
- Partial take profit capabilities
- Dynamic position sizing based on account balance and margin checks

Develop an advanced filtering system supporting technical filters (Inside Bar, Key Level confluence, CRT Plus, Nested CRT multi-timeframe alignment) and session/day filters (Monday/Friday filters, high-impact news avoidance, spread protection).

Enable operational modes:
- Auto-Trading Mode (fully automated scanning, signal display, and trade execution with risk management)
- Manual Trading Mode (user decision with visual setup notifications and one-click BUY/SELL buttons, automatic stop loss and take profit calculation)
- Hybrid Mode for switching between auto and manual as needed

Create a real-time dashboard displaying:
- Current CRT phase with visual CRT range indicators and multi-timeframe alignment
- Live statistics including win rate, profit/loss, trades count, session performance, risk exposure
- Trade signals with clear bullish/bearish notifications and signal strength

Support dashboard customization for color themes, font sizes, sound alert settings, layout adaptations, and alerts via visual, audio, email, or (if supported) mobile push notifications.

Include robust risk management protocols with position sizing, stop loss/take profit according to CRT ranges and entry methods, daily/session trade limits, drawdown protection, and automatic trading suspension if limits are breached.

Ensure the EA is optimized for attaching on H4 charts, with guidance to users for initial setup, session selection strategy, risk guidelines, and performance monitoring.

Structure the code with clear and maintainable modular functions, comprehensive comments, and adherence to MQL5 best practices.

# Steps

1. Implement CRT phase detection using multi-timeframe analysis on H4 and M15.
2. Code each entry method (Turtle Soup, Order Block/CSD, Third Candle, Auto Best) with precise entry conditions.
3. Build session management with GMT auto-adjust for broker time and session filters.
4. Develop risk management modules including dynamic position sizing and trade limits.
5. Integrate advanced technical and session filters.
6. Create operational mode controls allowing switching between auto, manual, and hybrid.
7. Design and code an interactive graphical dashboard with all required real-time data and controls.
8. Implement alert and notification systems.
9. Test thoroughly with demo account recommended setups.

# Output Format

Provide the complete, compilable MQL5 Expert Advisor source code file (.mq5) with all functionalities described above fully implemented, including comments and structured modular design. The code should be ready to attach to the H4 chart of any currency pair and support configuration via input parameters for all key settings.