# 📊 CRT Bias Scanner Pro v4.0
## Quick Start User Manual

---

## 🎯 What is CRT Bias Scanner?

The **CRT Bias Scanner Pro** is a multi-timeframe market scanner that analyzes 16 assets simultaneously using the **Candle Range Theory (CRT)** to identify potential trading biases based on 4-hour candle patterns.

### Key Features:
- 📈 Scans 16 assets in real-time
- ⚡ Performance-optimized with configurable scan frequency
- 🎨 5 professional color themes
- 📊 Live statistics dashboard
- 🔔 Smart alert system
- 🕐 Trading session visualization

---

## 🚀 Quick Setup

### Step 1: Add to Chart
1. Open TradingView and select any chart
2. Click Indicators → Search for "CRT Bias Scanner v4"
3. Add to your chart

### Step 2: Initial Configuration
1. **Position**: Top Right (default) - change if needed
2. **Scan Frequency**: 5 minutes (recommended for balance)
3. **Theme**: Choose your preferred color scheme
4. **Enable Scanner**: ✅ (should be checked)

---

## 📖 Understanding the Signals

### CRT Bias Indicators:

| Icon | Bias | Description | Action |
|------|------|-------------|--------|
| ⬆ | **BULL** | Low sweep with close above | Consider long positions |
| ⬇ | **BEAR** | High sweep with close below | Consider short positions |
| ⚡ | **S&D** | Both high & low swept (Seek & Destroy) | Volatile - wait for direction |
| ○ | **WAIT** | No clear bias | No action - wait for setup |

### How CRT Works:
- Compares current 4H candle with previous candle
- Identifies liquidity sweeps (highs/lows taken)
- Determines bias based on close position after sweep

---

## ⚙️ Settings Guide

### 🔥 Performance & Alerts
- **Scan Frequency** (1-60 min): How often to update
  - 1-5 min: Day trading (high CPU)
  - 5-15 min: Swing trading (balanced)
  - 15-60 min: Position trading (low CPU)
- **Enable Alerts**: Get notifications on bias changes
- **Bull/Bear Only**: Filter alerts by direction

### 🎨 Visual Settings
- **Themes Available**:
  - **Dark Pro**: Professional dark theme
  - **Light Pro**: Clean light theme
  - **Matrix**: Terminal green style
  - **Ocean**: Blue aquatic theme
  - **Monochrome**: Grayscale minimal

- **Table Size**: Compact / Normal / Large
- **Compact Mode**: Shows shortened symbols (EUR vs EURUSD)

### 💱 Symbol Configuration
Default includes 16 major assets:
- **Forex**: EUR, GBP, JPY, CAD, AUD, NZD, CHF pairs
- **Indices**: NAS100, DOW30, SP500
- **Commodities**: Gold, Silver
- **Crypto**: Bitcoin, Ethereum

*Customize any slot with your preferred symbols*

### 🕐 Trading Sessions
Visual session boxes on chart:
- 🗽 **New York**: 13:00-22:00 UTC
- 🏰 **London**: 07:00-16:00 UTC
- 🗾 **Tokyo**: 00:00-09:00 UTC
- 🏖 **Sydney**: 21:00-06:00 UTC

---

## 📊 Reading the Scanner Table

```
┌────────────────────────────────┐
│     CRT BIAS SCANNER PRO       │  ← Title
│     🟢 ACTIVE | 14:35:22       │  ← Status & Last Scan
├────────────────────────────────┤
│ Symbol │ Bias │ Symbol │ %Δ    │  ← Headers
├────────┼──────┼────────┼───────┤
│ EURUSD │  ⬆   │ GOLD   │ +1.2% │  ← Asset & Signal
│ GBPUSD │  ⬇   │ BTC    │ -0.5% │
│  ...   │ ...  │  ...   │  ...  │
├────────────────────────────────┤
│   ↗ 5 | ↘ 3 | ⚡ 2 | ○ 6      │  ← Statistics
└────────────────────────────────┘
```

### Table Components:
- **Symbol**: Asset being scanned
- **Bias**: Current CRT signal (⬆⬇⚡○)
- **%Δ**: Price change percentage
- **Statistics**: Count of each bias type

---

## 💡 Trading Tips

### Best Practices:
1. **Confluence**: Use with your existing strategy
2. **Multiple Timeframes**: CRT scans 4H, confirm on your trading timeframe
3. **Session Alignment**: Best signals often at session opens
4. **Risk Management**: CRT shows bias, not entry/exit points

### Optimal Settings by Trading Style:

| Style | Scan Freq | Alerts | Sessions |
|-------|-----------|--------|----------|
| **Scalping** | 1 min | ON | OFF |
| **Day Trading** | 5 min | ON | ON |
| **Swing Trading** | 15 min | ON | ON |
| **Position Trading** | 30-60 min | OFF | OFF |

---

## 🔔 Alert Setup

1. Right-click on chart → "Add Alert"
2. Condition: "CRT Bias Scanner v4"
3. Configure:
   - **Bull Alerts**: Long opportunities
   - **Bear Alerts**: Short opportunities
   - **Both**: All directional changes

---

## 🛠️ Troubleshooting

| Issue | Solution |
|-------|----------|
| **Scanner not updating** | Check "Scanner Active" is enabled |
| **High CPU usage** | Increase scan frequency (10-15 min) |
| **No signals showing** | Verify symbols are correct format |
| **Sessions not visible** | Enable "Show Sessions on Chart" |
| **Table too small/large** | Adjust "Table Size" setting |

---

## 📈 Advanced Features

### Debug Mode
Enable to see:
- Current timeframe
- Bar count
- Next scan countdown
- Technical diagnostics

### Performance Optimization
- **Cached Results**: Reduces server requests
- **Time-Based Scanning**: Updates only when needed
- **Dynamic Requests**: Optimizes multi-symbol queries

---

## 🎯 Strategy Integration

### Entry Confirmation:
1. Wait for CRT bias signal (⬆ or ⬇)
2. Confirm on your trading timeframe
3. Check session timing
4. Enter with your normal strategy

### Risk Management:
- CRT shows bias, not stop loss levels
- Use ATR or structure for stops
- Consider opposite bias as potential reversal

---

## 📝 Quick Reference

### Keyboard Shortcuts:
- **Alt + Click**: Move table position
- **Double Click**: Open settings

### Color Coding:
- 🟢 Green: Bullish bias
- 🔴 Red: Bearish bias
- ⚡ Yellow/Gray: Neutral/S&D
- ⚪ Gray: Waiting/No bias

---

## 🚨 Important Notes

1. **4H Timeframe**: CRT analyzes 4-hour candles regardless of your chart timeframe
2. **Lookback**: Uses previous two 4H candles for analysis
3. **Not Financial Advice**: Use as one tool in your analysis
4. **Internet Required**: Needs connection for multi-symbol data

---

## 📞 Support

- **Version**: 4.0
- **Compatibility**: TradingView Pine Script v5
- **Updates**: Auto-updates with script
- **Documentation**: Check script comments for technical details

---

*Happy Trading! May the bias be with you! 📊✨*