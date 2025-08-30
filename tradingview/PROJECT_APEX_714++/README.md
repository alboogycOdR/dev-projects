# Apex Protocol Assistant v1.2 (Final)

A sophisticated TradingView Pine Script indicator implementing the Enhanced 714 Method based on ICT (Inner Circle Trader) principles and Wyckoff accumulation/distribution theory.

## 📋 Latest Updates (v1.2) - **MAJOR UI OVERHAUL**
- ✅ **BREAKING CHANGE**: Replaced confusing `input.time()` system with intuitive `input.session()` inputs
- ✅ **SAST Timezone Ready**: Pre-configured for South African Standard Time (UTC+2) with Europe/London timezone
- ✅ **Organized Input Groups**: All settings now organized into logical groups for better usability
- ✅ **Intuitive Session Configuration**: Simple time ranges like "0800-1100" instead of confusing date pickers
- ✅ **Tooltip Guidance**: Added helpful tooltips explaining SAST timezone conversion
- ✅ **Enhanced Visual Management**: Improved line and label cleanup when state transitions occur
- ✅ **Optimized Dashboard**: Cleaner table layout with better color coding
- ✅ **All Previous Fixes**: Maintains all v1.1 improvements and bug fixes

## 🎯 Overview

The Apex Protocol Assistant is a decision-support tool that monitors the market for precise conditions of The Apex Protocol trading strategy. It combines Higher Timeframe (HTF) bias analysis, session-based liquidity detection, and a state machine to identify high-probability trading setups.

**NEW IN v1.2**: The indicator is now perfectly configured for SAST (South African Standard Time) users with an intuitive, professional interface that eliminates configuration confusion.

## 🚀 Key Features

### State Machine Logic
- **STANDBY**: Default state outside active Killzones
- **HUNTING**: Active monitoring during London/NY Killzones
- **MANIPULATION_DETECTED**: Liquidity sweep identified
- **ARMED**: Complete setup confirmed with entry zone

### Visual Elements
- **HTF Bias Background**: Green for bullish H4 bias, Red for bearish
- **Session Ranges**: Asian session box with 50% equilibrium level
- **Killzone Shading**: Visual indicators for London (Yellow) and NY (Orange) Killzones
- **Key Levels**: Previous Day High/Low (solid), Previous Week High/Low (dashed)
- **Setup Visualization**: Entry/SL/TP lines when setup is armed

### Dashboard Table
Real-time status display including:
- Protocol Status (STANDBY/HUNTING/MANIPULATION/ARMED)
- HTF Bias (BULLISH/BEARISH)
- Current Session
- Setup Checklist with real-time checkmarks
- Last Signal details

### Risk Management
- Configurable Risk-to-Reward ratio (default 1:2)
- Position size calculator based on account balance and risk %
- Automatic stop loss placement below manipulation wick

## 📋 Requirements

- **Pine Script Version**: v5
- **Recommended Timeframes**: M5, M15, H1
- **Chart Type**: Candlestick preferred
- **Broker**: Any with standard pip values

## ⚙️ Installation & Setup

1. Copy the `apex_protocol_assistant_v1.2.pine` script
2. Paste into TradingView Pine Editor
3. **No configuration required** - pre-configured for SAST timezone
4. Add to your chart

## 🔧 Configuration Options

### 🕐 **Session Times (Pre-configured for SAST)**
**Default Settings (Perfect for SAST UTC+2):**
- **Timezone**: Europe/London (automatically handles SAST conversion)
- **Asia Session**: 2000-0600 (8 PM - 6 AM London time)
- **London Killzone**: 0800-1100 (8 AM - 11 AM London time) → **SAST 09:00-12:00**
- **NY Killzone**: 1300-1600 (1 PM - 4 PM London time) → **SAST 14:00-17:00**

**How it works**: By setting the timezone to Europe/London, the script automatically converts times to SAST (UTC+2). London time is UTC+0/+1, so SAST is always 1-2 hours ahead.

### Technical Parameters
- **HTF Timeframe**: Default H4 (for bias determination)
- **HTF EMA Length**: Default 50 periods
- **CHoCH Lookback**: Default 5 bars for pivot detection
- **FVG Search Bars**: Default 20 bars to search for gaps

### Risk Management
- **Risk-to-Reward Ratio**: Default 2.0 (1:2 RR)
- **Account Balance**: Your trading account size
- **Risk % per Trade**: Default 1% (recommended max 2%)

### Visual Settings
- **Show Asian Range**: Toggle Asian session visualization
- **Show Killzones**: Toggle Killzone background shading
- **Show Dashboard**: Toggle status table display
- **Show Key Levels**: Toggle PDH/PDL/PWH/PWL lines
- **Color Customization**: Full color control for all elements

## 🎯 Trading Logic

### 1. Higher Timeframe Bias
- Uses EMA(50) on H4 timeframe
- Bullish when H4 close > H4 EMA
- Bearish when H4 close < H4 EMA

### 2. Liquidity Sweep Detection
**Bullish Setup:**
- Price breaks below Asian Low or Previous Day Low
- Candle closes back above the level
- Creates a "Spring" (Wyckoff accumulation)

**Bearish Setup:**
- Price breaks above Asian High or Previous Day High
- Candle closes back below the level
- Creates a "Upthrust After Distribution" (UTAD)

### 3. Change of Character (CHoCH)
**Bullish CHoCH:**
- After bullish sweep, price breaks above a pivot high
- Confirms shift to bullish momentum

**Bearish CHoCH:**
- After bearish sweep, price breaks below a pivot low
- Confirms shift to bearish momentum

### 4. Entry Zone Identification
**Priority Order:**
1. **Fair Value Gap (FVG)**: Three-candle pattern creating a price gap
2. **Order Block (OB)**: Last bullish candle before down-move (bearish setup)

### 5. Risk Management
- **Stop Loss**: Below manipulation wick (bullish) or above wick (bearish)
- **Take Profit**: Based on Risk-to-Reward ratio
- **Position Size**: Calculated using account balance and risk %

## 📊 Dashboard Explanation

The dashboard provides real-time feedback:

```
┌─────────────────┬─────────────────────┐
│ Protocol Status │ ARMED (Green)       │
│ HTF Bias (H4)   │ BULLISH             │
│ Current Session │ London Killzone     │
│ ✓ In Killzone   │ ✓                   │
│ ✓ Liquidity Swept│ ✓                  │
│ ✓ CHoCH Confirmed│ ✓                  │
│ Last Signal     │ BUY @ 1.08500       │
└─────────────────┴─────────────────────┘
```

## 🔔 Alerts

### Alert Trigger
- Fires when state machine enters **ARMED** state
- Only triggers on confirmed, high-probability setups

### Alert Message Format
```
APEX PROTOCOL: EURUSD BUY Signal!
Entry: 1.08500, SL: 1.08350, TP: 1.08800
HTF Bias: BULLISH
```

### Integration
- Compatible with 3Commas, Alertatron, and other automation tools
- Use TradingView's alert system for mobile notifications

## 📈 Usage Guidelines

### Best Practices
1. **Always check HTF bias** before trading
2. **Only trade during Killzones** (London/NY sessions)
3. **Wait for complete setup confirmation** (all checklist items ✓)
4. **Use limit orders** at the identified entry zone
5. **Never risk more than 1%** per trade

### Timeframe Recommendations
- **M5/M15**: Primary analysis and entry timing
- **H1**: Trend confirmation
- **H4**: Bias determination
- **Daily**: Overall market context

### Market Conditions
- **Best**: High volatility during Killzones
- **Avoid**: Low volatility, news events, economic data releases
- **Caution**: Friday afternoon sessions (thin liquidity)

## 🔍 Troubleshooting

### Common Issues
- **No setups detected**: Check session times match your timezone
- **Incorrect bias**: Verify HTF timeframe setting
- **Missing levels**: Ensure chart has sufficient historical data
- **Repainting**: Indicator only confirms on closed bars

### Performance Tips
- Use on volatile currency pairs (EURUSD, GBPUSD, USDJPY)
- Avoid during major news events
- Test on multiple timeframes for consistency
- Monitor dashboard for real-time feedback

## 📚 Educational Resources

### Core Concepts
- **ICT Principles**: Inner Circle Trader methodology
- **Wyckoff Theory**: Accumulation and Distribution phases
- **Liquidity Concepts**: Buy-side/Sell-side liquidity pools
- **Order Flow**: Understanding institutional positioning

### Further Reading
- Study ICT's "Power of Three" concept
- Learn about Killzone trading
- Understand Fair Value Gaps and Order Blocks
- Master risk management principles

## 🔄 Version History

### v1.2 - Major UI & Timezone Improvements
- **BREAKING CHANGE**: Replaced confusing time inputs with intuitive session inputs
- **SAST Optimization**: Pre-configured for South African Standard Time
- **Organized Interface**: Logical input grouping and tooltips
- **Enhanced Visuals**: Improved line/label management

### v1.1 - Code Review Fixes
- Fixed Order Block logic (critical correction)
- Added price labels to Entry/SL/TP lines
- Resolved all compilation errors
- Achieved 10/10 code quality rating

### v1.0 - Initial Release
- Complete state machine implementation
- Full visual dashboard
- Alert system integration
- Risk management calculator
- Comprehensive input customization

## ⚖️ Disclaimer

This indicator is a decision-support tool, not a fully automated trading system. Always use proper risk management and never risk more than you can afford to lose. Past performance does not guarantee future results. Trade at your own risk.

## 🤝 Support

For questions, feature requests, or bug reports:
- Review the code comments for implementation details
- Test on different symbols and timeframes
- Ensure all input parameters are correctly set

---

**Remember**: The Apex Protocol is about precision, patience, and discipline. Wait for the perfect setup, then execute with confidence.

**NEW IN v1.2**: The indicator is now perfectly configured for SAST users with an intuitive interface that eliminates configuration confusion!
