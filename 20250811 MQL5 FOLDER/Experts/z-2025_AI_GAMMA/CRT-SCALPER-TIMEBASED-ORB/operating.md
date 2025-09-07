Below is the operator manual formatted in Markdown:

---

# CRT Session Open Scalper v5.2 – Operator Manual

This manual explains how to install, configure and use the CRT Session Open Scalper expert adviser (EA) in MetaTrader 5. The EA implements a scalping strategy that uses the **15‑minute London or New‑York opening range** to define a “CRT range”, trades on the **1‑minute chart** and requires either a **Market‑Structure‑Shift (MSS)** or **Change‑in‑State‑of‑Delivery (CISD)** confirmation before placing a trade. It includes optional higher‑timeframe and SMT divergence filters and displays a simple dashboard on the chart.

## 1 Installation

1. **Copy the EA file** to your MetaTrader 5 terminal:

   * Locate the file `CRT_Session_Open_Scalper_v5_2.mq5` on your computer.
   * In MetaTrader 5, go to **File → Open Data Folder**.
   * Navigate to `MQL5/Experts` and copy the file into this folder.
   * Close and re‑open MetaTrader 5 (or refresh the Navigator pane) so the EA appears in the **Navigator → Expert Advisors** list.

2. **Attach the EA to a chart**:

   * Open a **1‑minute (M1)** chart of the instrument you wish to trade. The EA is designed to operate on the M1 chart; higher time‑frames are used internally.
   * Drag the EA from the **Navigator → Expert Advisors** tree onto the chart, or right‑click it and choose **Attach to chart**.
   * In the dialog box that appears, check **Allow automated trading** if you plan to let the EA place trades. If you want to receive signals only, leave it unchecked and set the **Operational Mode** input accordingly.

## 2 Input Parameters

The EA exposes several inputs grouped by purpose. These values are set when you attach the EA to the chart, but can be changed later from the **Inputs** tab of the EA properties.

| Group                           | Parameter                        | Description                                                                                                                                                                     |
| ------------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| **CRT Model Settings**          | **SessionToTrade**               | Choose whether to use the 15‑minute London open (03:00) or New‑York open (09:30 New York time) to define the CRT range.                                                         |
|                                 | **EntryLogicModel**              | Select **CONFIRM\_WITH\_MSS** for Market‑Structure‑Shift confirmation or **CONFIRM\_WITH\_CISD** for momentum‑based CISD confirmation.                                          |
|                                 | **Broker\_GMT\_Offset\_Hours**   | Offset between your broker’s server time and GMT. This is used to convert prices to New‑York time for session calculations. Adjust manually when daylight‑savings time changes. |
| **Risk & Trade Management**     | **RiskPercent**                  | Percentage of account balance to risk per trade (0 < RiskPercent ≤ 10). The EA uses this to calculate position size.                                                            |
|                                 | **TakeProfit\_RR**               | Take‑profit in terms of risk\:reward. For example, 2.0 sets TP at twice the stop distance.                                                                                      |
|                                 | **MoveToBE\_At\_1R**             | If `true`, the EA will move the stop loss to break even after price reaches a 1:1 risk\:reward.                                                                                 |
|                                 | **MaxTradesPerDay**              | Maximum number of trades the EA may open per day.                                                                                                                               |
| **Advanced Contextual Filters** | **Filter\_By\_Weekly\_Profile**  | Enable to restrict trades based on an assumed weekly profile (Classic Expansion or Midweek Reversal).                                                                           |
|                                 | **Assumed\_Weekly\_Profile**     | Select the weekly profile hypothesis if the above filter is enabled.                                                                                                            |
|                                 | **Use\_SMT\_Divergence\_Filter** | Enable to check for SMT divergence between the trading instrument and a correlated symbol (e.g. the DXY index).                                                                 |
|                                 | **SMT\_Correlated\_Symbol**      | The symbol used for SMT divergence (e.g. `DXY`). The EA must have data for this symbol loaded.                                                                                  |
| **Operational Mode & UI**       | **OperationalMode**              | Choose **SIGNALS\_ONLY** to receive alerts without placing trades, or **FULLY\_AUTOMATED** to let the EA send orders automatically.                                             |
|                                 | **i\_theme**                     | Select a colour theme for the dashboard: dark (default), light or blueprint.                                                                                                    |
|                                 | **i\_table\_pos**                | Position of the dashboard on the chart (top‑right, top‑left, middle‑right, middle‑left, bottom‑right or bottom‑left).                                                           |
|                                 | **EnableVerboseLogging**         | If `true`, the EA will print detailed log messages to the MetaTrader log. Useful for debugging.                                                                                 |

**Note:** The EA copies your inputs into internal variables (`gRiskPercent`, `gTakeProfitRR`, `gMaxTradesPerDay`) during initialisation. If an input is outside an acceptable range, a default value is used and a warning is printed.

## 3 Using the EA

1. **Select the correct time‑frame**: The EA must be attached to a 1‑minute chart. Ensure that history data is loaded for M1, M15 and H4 time‑frames so the EA can calculate the CRT range and bias.

2. **Check the dashboard**: Once loaded, the EA draws a small table showing the symbol name, the detected H4 bias (▲ for bullish, ▼ for bearish, ↔ for neutral) and the current state (`Idle`, `Awaiting_Sweep`, `Awaiting_Confirmation`, `Awaiting_Entry` or `Invalid`). The colour of the status cell changes as the state evolves (orange for sweep, blue for confirmation, green for entry).

3. **Monitor session times**: The EA only looks for setups during the “kill zone” of the chosen session (03:00–05:00 for London or 09:30–11:00 New York time). If the CRT range has not been established (e.g. due to missing data), the EA will print a message and wait until it can identify the range.

4. **Signals vs. automation**: In **SIGNALS\_ONLY** mode the EA raises an alert when a valid setup occurs. You must place the trade manually if desired. In **FULLY\_AUTOMATED** mode the EA will open positions with calculated lot size, stop loss and take profit. It will not open more than `MaxTradesPerDay` trades per day.

5. **Stop‑loss to breakeven**: If `MoveToBE_At_1R` is enabled, the EA moves the stop loss to the entry price once price has moved one risk unit in your favour. It does not trail the stop or scale out.

6. **Advanced filters**: When `Filter_By_Weekly_Profile` is enabled, the EA uses the selected weekly profile to decide whether bullish or bearish setups are valid on a given day. The SMT divergence filter checks whether the trading symbol sweeps a high/low while a correlated symbol does not. If data for the correlated symbol is not available, the filter passes.

## 4 Best Practices

* **Test on a demo account** before running the EA on live capital. Observe how often trades occur, how the state machine behaves, and whether the logic matches your expectations.
* **Use appropriate risk**: Even though the default risk (0.5%) is conservative, you should adjust the `RiskPercent` and `MaxTradesPerDay` inputs to suit your risk tolerance and account size.
* **Update the broker GMT offset** when daylight‑saving time changes. The EA does not automatically adjust for DST.
* **Monitor logs**: Enabling `EnableVerboseLogging` will provide detailed printouts in the MetaTrader journal, helping you understand how the EA reaches its decisions.
* **Keep price data up to date**: The EA requires recent M1, M15 and H4 data. If charts are not updated, the EA may skip trades.

## 5 Troubleshooting

* **Dashboard not showing**: Ensure that “Allow DLL imports” is checked (if your broker requires it) and that the chart is not too small. Switch the dashboard position via `i_table_pos` if it overlaps important chart elements.
* **No trades or signals**: Verify that the CRT range lines are drawn at the session open, that you are within the kill zone and that filters are not excluding setups. Check the log for messages about missing data or filters.
* **Order rejection errors**: Some brokers require minimum stop distances or have specific volume steps. If you see errors like “Invalid volumes” in the journal, consult your broker’s symbol specifications and adjust risk or tick size accordingly.

---

Let me know if you need the file version of this manual or any further adjustments!
