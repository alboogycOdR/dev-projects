How to Use the Candle Range Theory (CRT) Expert Advisor
1. Introduction
Welcome to the Candle Range Theory (CRT) Expert Advisor for MetaTrader 5. This guide will walk you through the necessary steps to install, configure, and effectively use the EA for automated, semi-automated, or manual trading based on the powerful CRT methodology.

2. Installation & Compilation
Open MetaEditor: In your MT5 terminal, click the IDE icon in the toolbar or press F4 to open the MetaEditor.

Create New File: In the MetaEditor, go to File > New. In the MQL Wizard, select "Expert Advisor (template)" and click "Next".

Name the File: Name your EA CandleRangeTheory_EA and click "Finish".

Paste the Code: A new .mq5 file will open. Delete the default template code and paste the entire source code of the CRT EA into this file.

Compile: Click the Compile button in the toolbar (or press F7). Check the "Errors" tab at the bottom. If there are no errors, the EA is ready to be used in your MT5 terminal.

3. Chart Setup
Timeframe: This EA is specifically designed for multi-timeframe analysis, with the core logic running on the H4 (4-Hour) chart.

Attachment: Open an H4 chart for any currency pair you wish to trade. In the MT5 Navigator window (press Ctrl+N if it's not visible), find CandleRangeTheory_EA under the "Expert Advisors" section.

Drag and Drop: Drag the EA from the Navigator onto your H4 chart.

4. Configuration (Input Parameters)
When you attach the EA, the settings window will appear. The "Inputs" tab is where you customize the EA's behavior.

General Settings
inpOperationalMode: Choose your trading style:

AUTO_TRADING: The EA handles everything—scanning, entering, and managing trades.

MANUAL_TRADING: The EA provides signals and visuals on the dashboard, but you must click the BUY/SELL buttons to execute trades. SL/TP are calculated automatically.

HYBRID_MODE: The EA trades automatically but also allows you to place manual trades using the dashboard buttons.

inpMagicNumber: A unique ID for the EA's trades. Keep this different for each EA instance you run.

inpRiskPercent: The percentage of your account balance to risk per trade. It is strongly recommended to keep this between 0.5 and 2.0.

inpMinRiskReward: The minimum reward-to-risk ratio for a trade (e.g., 2.0 means the Take Profit will be at least twice as far as the Stop Loss).

inpMaxTradesPerDay: Limits the number of trades the EA can open in a single day.

inpMaxSpread: Prevents trading if the current spread (in points) is higher than this value.

Trading Session Management
inpEnableSessionTrading: Set to true to only trade during specific sessions.

inpTrade[SessionName]: Enable or disable trading for Sydney, Tokyo, Frankfurt, London, and New York sessions.

inpGmtOffset: The EA attempts to auto-detect your broker's GMT offset. If you notice session times are incorrect, you can manually set the offset here.

Entry Method Settings
inpEntryMethod: Select the entry logic:

AUTO_BEST: The EA will scan for all entry types and take the first valid signal it finds.

TURTLE_SOUP: A false breakout reversal strategy.

ORDER_BLOCK_CSD: A strategy based on institutional supply/demand zones.

THIRD_CANDLE: A simple 3-candle confirmation pattern.

Advanced Filtering System
Enable (true) or disable (false) various filters to refine trade entries, such as avoiding trading on Mondays/Fridays or looking for specific chart patterns.

Dashboard & Alerts
Customize the on-chart dashboard colors and enable/disable sound, email, or push notifications for trade signals and actions.

5. The On-Chart Dashboard
The dashboard provides a real-time overview:

CRT Phase: Shows the current market phase (Accumulation, Manipulation).

Signal: Notifies you of potential bullish or bearish setups.

Stats: Displays your running Profit/Loss, Win Rate, and daily trade count.

Risk: Reminds you of your current risk settings.

BUY/SELL Buttons: For executing trades in Manual or Hybrid modes.

6. Best Practices & Recommendations
Backtest Thoroughly: Before going live, use the MT5 Strategy Tester to backtest the EA on historical data. Experiment with different settings and currency pairs to find what works best.

Start with a Demo Account: Always run a new EA on a demo account for at least a few weeks. This helps you understand its real-time behavior without risking capital.

Risk Management is Key: Never risk more than you are willing to lose on a single trade. Start with a low risk percentage (e.g., 1%).

Enable "Algo Trading": Make sure the "Algo Trading" button in your main MT5 toolbar is enabled (green). Otherwise, the EA will not be able to execute trades.