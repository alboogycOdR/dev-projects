## Session Background

- **Type**: Indicator
- **Path**: `tradingview/ORB/ORBICT_CLAUDE/orb_ict_indicator.pine`
- **Pine version**: (unspecified)

### Overview
This document summarizes public inputs, plots, alerts, and strategy order calls discovered in the script.

No user inputs.

- **Plots**:
  - plot: ORB High
  - plot: ORB Low
  - plot: Prev Day High
  - plot: Prev Day Low
  - plot: Premarket High
  - plot: Premarket Low

- **Alerts**:
  - Long breakout with volume confirmation. ORB High: {{plot_0}} — Long breakout with volume confirmation. ORB High: {{plot_0}}
  - Short breakout with volume confirmation. ORB Low: {{plot_1}} — Short breakout with volume confirmation. ORB Low: {{plot_1}}
  - Bullish liquidity grab detected below ORB — Bullish liquidity grab detected below ORB
  - Bearish liquidity grab detected above ORB — Bearish liquidity grab detected above ORB
  - Breakout confirmed, waiting for pullback entry — Breakout confirmed, waiting for pullback entry
  - Narrow Range Detected — Narrow range detected - potential for explosive move
  - Wide Range Detected — Wide range detected - caution advised

No strategy orders.

### Usage
- **Add to chart**: Open the Pine editor in TradingView, paste the script, click Add to chart.
- **Configure inputs**: Adjust the inputs listed above to suit your market and timeframe.
- **Alerts**: If alerts exist, create an alert and select one of this indicator's alert conditions.

### Example
```text
Add 'Session Background' to the chart and enable relevant inputs.
Create an alert using one of the documented conditions.
Backtest using Strategy Tester if this is a strategy.
```
