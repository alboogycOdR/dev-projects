# MarketCrasher EA

This repository contains the MetaTrader 5 implementation of the TradingView strategy described in `TradingView PropStrategy .txt`.

Two EAs are provided:

- **MasterEA** – trades the prop account and writes hedge instructions for the slave.
- **SlaveEA** – reads hedge instructions from file and opens opposite trades on a hedge account.

A dashboard implementation is available in `MQL5/Include/Dashboard.mqh`.


Additional modules include `Synergy.mqh` for the multi-timeframe synergy score
and `Pivots.mqh` providing pivot-based stop-loss/take-profit logic with optional
zigzag drawing.
=======
The hedge engine logic is contained in `MQL5/Include/HedgeEngine.mqh` and
provides cost‑recovery sizing, daily drawdown checks and optional hedge
bleeding when 70 % of the stage target is reached.

The Master EA also supports optional trading sessions, a Heikin-Ashi market
bias filter and an ADX trend filter. Adjust these inputs to mirror the
TradingView strategy.


## Usage
1. Place the files inside your terminal's `MQL5` directory preserving the folder structure.
2. Compile `MQL5/Experts/PropEA/MasterEA.mq5` and `MQL5/Experts/PropEA/SlaveEA.mq5` in MetaEditor.
3. Attach `MasterEA` to the prop account chart and `SlaveEA` to the hedge account chart.

Adjust the input parameters of both EAs to match your desired risk and strategy settings.


The master EA provides optional breakeven management via the following inputs:

- `UseBreakEven` – enable or disable the breakeven move.
- `BETriggerPts` – profit in points required before the stop is moved to entry.
- `BEOffsetPts` – additional points beyond entry for the new stop.


The Master EA now includes optional **scale-out** logic allowing partial profit
taking and breakeven management.

Pivot calculations for stop loss and take profit are implemented in
`MQL5/Include/Pivot.mqh`. The EA can optionally draw a zigzag line showing
recent pivot highs and lows on the chart.

Additional modules provide the multi-timeframe synergy score, market bias
oscillator and ADX filter used by the strategy.

Synergy score logic from the TradingView script is implemented in
`MQL5/Include/Synergy.mqh` and used by the MasterEA to filter trades.


