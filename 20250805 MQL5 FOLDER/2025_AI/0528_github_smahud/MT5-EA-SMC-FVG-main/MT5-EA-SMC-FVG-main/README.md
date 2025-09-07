# MT5-EA-SMC-FVG
MT5 EA (Smart Money Concept and Fair Value Gap) - average return ≈ 10.8% per year.

Enhanced SMC + FVG EA for XAUUSDm (Risk-Managed)
An automated MetaTrader 5 Expert Advisor (EA) that trades XAUUSDm based on Smart Money Concepts (SMC) and Fair Value Gap (FVG) logic, with strict risk management and dynamic trailing stop after structure breaks.

## **Features**
Smart Money Structure (BOS-based) entry logic

- Fair Value Gap zone filtering with min body confirmation

- Dynamic lot sizing based on risk % of account equity

- Reward-to-Risk ratio configuration

- Daily trade limit to avoid overtrading

- Trailing stop after Break of Structure (BOS)

- Configurable timeframes for structure and entry

## **Inputs**
Parameter	Description
RiskPercent	Risk per trade (% of equity)
MaxTradesPerDay	Daily trade cap to prevent overtrading
StructureTF	Timeframe for SMC structure analysis
EntryTF	Timeframe for entry conditions
RRR	Reward-to-risk ratio
ATRPeriod	ATR period for SL buffer calculation
TrailBufferPoints	Trailing SL buffer in points
MinCandleBodyPoints	Min candle body size for confirmation

## **Strategy Overview**
The EA detects bullish/bearish structure shifts using a 3-bar high/low pattern on the higher timeframe, validates recent candle body size on entry timeframe, and places pending trades with calculated SL/TP and dynamic lot size.

Trailing Stop activates only after structure continuation, improving trade management by locking profits intelligently.

## **Files Included**
EnhancedSMC_FVG_EA.mq5 – main EA code

(Optional) .set files for preconfigured settings

## **How to Use**
1. Open MetaEditor (MT5)

2. Paste or compile the .mq5 file into Experts/

3. Attach the EA to XAUUSDm chart

4. Adjust inputs as needed

5. Run in demo or strategy tester first

## **⚠️ Disclaimer**
This EA is designed for educational and research purposes. Trading involves risk. Backtest thoroughly before using on live accounts.

## **📌 About**
Created by Yanapatara Boonyamas, built using native MQL5 with structured logic for future extensibility and potential integration with research in AI-assisted trading agents or quantitative finance.

“Profit is not guaranteed—but structure, discipline, and precision are.”
