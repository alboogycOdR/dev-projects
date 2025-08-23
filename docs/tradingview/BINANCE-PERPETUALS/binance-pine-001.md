## Liquidity Sweep + Market Structure Shift

- **Type**: Strategy
- **Path**: `tradingview/BINANCE-PERPETUALS/binance-pine-001.pine`
- **Pine version**: (unspecified)

### Overview
This document summarizes public inputs, plots, alerts, and strategy order calls discovered in the script.

No user inputs.

- **Plots**:
  - plot: (untitled)
  - plot: (untitled)
  - plot: High zone upper
  - plot: Low zone lower
  - plotshape: High Sweep
  - plotshape: Low Sweep
  - plotshape: Enter Long
  - plotshape: Enter Short
  - plot: Stop Long
  - plot: TP Long
  - plot: Stop Short
  - plot: TP Short

- **Alerts**:
  - LS Enter Long Alert — LS Enter Long
  - LS Enter Short Alert — LS Enter Short

- **Strategy orders**:
  - entry: Long_LS
  - entry: Long_LS
  - exit: Exit_Long
  - entry: Short_LS
  - entry: Short_LS
  - exit: Exit_Short

### Usage
- **Add to chart**: Open the Pine editor in TradingView, paste the script, click Add to chart.
- **Backtest**: Open Strategy Tester, configure initial capital/commission, and time range.
- **Configure inputs**: Adjust the inputs listed above to suit your market and timeframe.
- **Alerts**: If alerts exist, create an alert and select one of this strategy's alert conditions.

### Example
```text
Add 'Liquidity Sweep + Market Structure Shift' to the chart and enable relevant inputs.
Create an alert using one of the documented conditions.
Backtest using Strategy Tester if this is a strategy.
```
