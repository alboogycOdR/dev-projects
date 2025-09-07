# Strength Meter + Order Block Expert Advisor

## Overview

This Expert Advisor (EA) implements a sophisticated trading strategy that combines **Currency Strength Analysis** with **Order Block Detection** for MetaTrader 5. The EA scans multiple currency pairs and timeframes to identify high-probability trading opportunities based on currency strength divergence and institutional order blocks.

## Strategy Components

### 1. Currency Strength Meter
- Calculates real-time strength for 8 major currencies (USD, EUR, GBP, JPY, CHF, CAD, AUD, NZD)
- Uses 28 major/minor currency pairs for comprehensive analysis
- Only considers pairs with strength difference ≥ 5 points
- Updates continuously for accurate market assessment

### 2. Order Block Detection
- Identifies institutional order blocks on M5 and M15 timeframes
- Only detects OBs that form **after a valid Break of Structure (BOS)**
- Prefers OBs that occur **after Liquidity Sweeps**
- Validates order blocks with minimum size requirements

### 3. Entry Conditions
- **BUY**: Strong base currency + Weak quote currency + Price at bullish OB
- **SELL**: Weak base currency + Strong quote currency + Price at bearish OB
- **M1 Confirmation**: Waits for rejection candle or engulfing pattern
- Maximum 2 trades per pair per day

### 4. Risk Management
- User-defined risk percentage per trade (default: 1% of balance)
- Fixed Risk-to-Reward ratio (default: 1:2)
- Stop Loss placed beyond Order Block with buffer
- Automatic position sizing based on account balance

## Features

### Interactive Dashboard
- Real-time currency strength display with color coding
- Active trading signals with detailed reasoning
- Daily trade statistics per symbol
- Auto-trading toggle button
- Trade log export functionality

### Monitored Instruments
- **Forex**: EURUSD, GBPUSD, USDJPY, GBPJPY, EURJPY
- **Commodities**: XAUUSD (Gold)
- **Indices**: NAS100, US30

### Advanced Logic
- Break of Structure validation
- Liquidity sweep detection
- M1 timeframe confirmation
- Daily trade limits
- Automatic symbol selection

## Installation Instructions

### Step 1: Download and Place Files
1. Copy `StrengthMeter_OB_EA.mq5` to your MetaTrader 5 data folder:
   ```
   C:\Users\[Username]\AppData\Roaming\MetaQuotes\Terminal\[Terminal_ID]\MQL5\Experts\
   ```

### Step 2: Compile the EA
1. Open MetaTrader 5
2. Press `F4` to open MetaEditor
3. Navigate to `Experts` folder in the Navigator
4. Double-click `StrengthMeter_OB_EA.mq5`
5. Press `F7` or click `Compile` button
6. Ensure compilation is successful (no errors)

### Step 3: Enable Auto-Trading
1. In MetaTrader 5, click the `Auto Trading` button in the toolbar
2. Ensure the button is highlighted (green)

### Step 4: Attach EA to Chart
1. Open any chart (recommended: EURUSD M5 or M15)
2. Drag `StrengthMeter_OB_EA` from Navigator to the chart
3. Configure parameters in the settings dialog
4. Click `OK` to start the EA

## Configuration Parameters

### Trading Settings
- **RiskPercent**: Risk per trade as % of balance (default: 1.0)
- **RiskReward**: Risk to Reward ratio (default: 2.0)
- **StopLossPips**: Additional pips beyond OB for SL (default: 10)
- **MaxTradesPerPair**: Maximum trades per pair per day (default: 2)
- **AutoTrading**: Enable/disable automatic trading (default: true)

### Strength Meter Settings
- **MinStrengthDiff**: Minimum strength difference required (default: 5.0)
- **StrengthPeriod**: Period for strength calculation (default: 14)

### Order Block Settings
- **OB_LookbackBars**: Bars to look back for OB detection (default: 50)
- **BOS_LookbackBars**: Bars to look back for BOS detection (default: 20)
- **OB_MinSize**: Minimum OB size in pips (default: 10.0)

### Dashboard Settings
- **DashboardX/Y**: Dashboard position on chart
- **PanelColor**: Background color of dashboard
- **TextColor**: Text color for dashboard elements

## Usage Guide

### Dashboard Controls

#### Auto Trading Button
- **Green "Auto: ON"**: EA will execute trades automatically
- **Red "Auto: OFF"**: EA will only show signals without trading
- Click to toggle between modes

#### Export Logs Button
- Exports trade history to CSV file
- Includes last 24 hours of EA trades
- File saved in MetaTrader data folder

### Signal Interpretation

#### Currency Strength Display
- **Green**: Strong currency (>3 points)
- **Red**: Weak currency (<-3 points)
- **White**: Neutral currency

#### Active Signals
- **Green "BUY"**: Long signal with entry reasoning
- **Red "SELL"**: Short signal with entry reasoning
- **Gray "No Signal"**: No valid setup found

#### Trade Statistics
- Shows current daily trade count vs. maximum allowed
- Resets automatically at midnight

### Best Practices

1. **Market Hours**: EA works best during active trading sessions
2. **News Events**: Monitor high-impact news that may affect currency strength
3. **Backtesting**: Test on historical data before live trading
4. **Risk Management**: Start with lower risk percentage (0.5-1%)
5. **Monitoring**: Regularly check dashboard for signal quality

## Strategy Logic Flow

```
1. Calculate Currency Strength (all 28 pairs)
   ↓
2. Check Strength Difference ≥ 5 points
   ↓
3. Detect Break of Structure (M5/M15)
   ↓
4. Identify Order Block after BOS
   ↓
5. Validate Price at Order Block
   ↓
6. Wait for M1 Confirmation
   ↓
7. Execute Trade with Risk Management
```

## Risk Warnings

- **High-Risk Trading**: Forex trading involves substantial risk
- **No Guarantee**: Past performance doesn't guarantee future results
- **Demo Testing**: Always test on demo account first
- **Market Conditions**: EA performance varies with market volatility
- **Broker Compatibility**: Ensure your broker supports all symbols

## Troubleshooting

### Common Issues

1. **EA Not Trading**
   - Check if Auto Trading is enabled
   - Verify symbol availability with broker
   - Ensure sufficient account balance
   - Check if daily trade limit reached

2. **Dashboard Not Showing**
   - Verify chart has enough space
   - Check dashboard position parameters
   - Restart EA if necessary

3. **Compilation Errors**
   - Ensure MetaTrader 5 is updated
   - Check file path and permissions
   - Verify all required libraries are available

### Support

For technical support or questions:
- Check MetaTrader 5 Expert tab for error messages
- Review trade logs for execution details
- Ensure broker provides all required symbols

## Version History

- **v1.00**: Initial release with full strategy implementation
  - Currency strength calculation
  - Order block detection
  - Interactive dashboard
  - Risk management system
  - Trade logging and export

## License

This Expert Advisor is provided for educational and trading purposes. Use at your own risk and ensure compliance with your broker's terms of service.

---

**Disclaimer**: Trading foreign exchange and CFDs carries a high level of risk and may not be suitable for all investors. The high degree of leverage can work against you as well as for you. Before deciding to trade, you should carefully consider your investment objectives, level of experience, and risk appetite. 