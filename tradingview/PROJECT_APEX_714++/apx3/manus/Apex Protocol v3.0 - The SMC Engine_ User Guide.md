# Apex Protocol v3.0 - The SMC Engine: User Guide

**Version:** 3.0  
**Date:** August 31, 2025  
**Author:** Manus AI  

## 📋 Table of Contents

1. [Quick Start Guide](#quick-start-guide)
2. [Installation Instructions](#installation-instructions)
3. [Indicator Settings](#indicator-settings)
4. [Understanding the Dashboard](#understanding-the-dashboard)
5. [Strategy Explanations](#strategy-explanations)
6. [Alert System](#alert-system)
7. [Visual Elements](#visual-elements)
8. [Troubleshooting](#troubleshooting)
9. [Best Practices](#best-practices)

## 🚀 Quick Start Guide

The Apex Protocol v3.0 is a sophisticated Smart Money Concepts (SMC) indicator that automatically detects high-probability trading setups during specific market sessions (Killzones). Here's how to get started:

### Essential Setup Steps:
1. **Install the indicator** on TradingView
2. **Select your Killzone strategies** (London and/or New York)
3. **Configure your risk parameters** (account balance, risk %)
4. **Set up alerts** to be notified of confirmed setups
5. **Monitor the dashboard** for real-time strategy progress

## 📥 Installation Instructions

### Step 1: Access Pine Script Editor
1. Open TradingView in your web browser
2. Click on "Pine Editor" at the bottom of the screen
3. If you don't see it, go to Chart → Indicators → Pine Editor

### Step 2: Import the Code
1. Clear any existing code in the Pine Editor
2. Copy the entire contents of `apex_protocol_v3.pine`
3. Paste the code into the Pine Editor
4. Click "Add to Chart" (or press Ctrl+S)

### Step 3: Initial Configuration
1. The indicator will appear on your chart with default settings
2. Click the gear icon next to "APEX v3.0" in the indicator list
3. Configure your preferred settings (see [Indicator Settings](#indicator-settings))
4. Click "OK" to apply changes

### Step 4: Set Up Alerts
1. Right-click on the chart
2. Select "Add Alert"
3. Choose "APEX v3.0" as the condition
4. Select "Apex Protocol v3.0 Alert"
5. Configure your notification preferences
6. Click "Create"

## ⚙️ Indicator Settings

The indicator settings are organized into five logical groups:

### 🔧 General Settings & Risk
- **Higher Timeframe**: Default "240" (4-hour). Used for trend analysis
- **Account Balance**: Your trading account size for position sizing
- **Risk % per Trade**: Percentage of account to risk per trade (default 1%)
- **Correlated Asset TickerID**: Asset for SMT analysis (default "TVC:DXY")

### 👁️ SMC Engine Visuals (Toggles)
- **Show BOS/MSS Markers**: Display Break of Structure and Market Structure Shift labels
- **Show Fair Value Gaps (M5)**: Display 5-minute Fair Value Gap boxes
- **Show Order Blocks (M5)**: Display 5-minute Order Block highlights
- **Show Session Ranges**: Display key trading session boundaries

### 🎯 Killzone Strategy Selection
- **London Killzone Strategy**: Choose strategy for 3:00-6:00 EST
  - Options: OFF, The Core SMC Model, ICT Silver Bullet
- **New York Killzone Strategy**: Choose strategy for 9:30-11:00 EST
  - Options: OFF, The Core SMC Model, ICT Silver Bullet

### ⏰ Low Timeframe Confirmation
- **LTF Timeframe**: Select timeframe for final confirmation
  - Options: 1 Minute, 30 Second

### 🎨 Visual Customization
- **Bullish FVG Color**: Color for bullish Fair Value Gaps
- **Bearish FVG Color**: Color for bearish Fair Value Gaps
- **Bullish Order Block Color**: Color for bullish Order Blocks
- **Bearish Order Block Color**: Color for bearish Order Blocks
- **BOS Marker Color**: Color for Break of Structure markers
- **MSS Marker Color**: Color for Market Structure Shift markers

## 📊 Understanding the Dashboard

The on-chart dashboard provides real-time information about the indicator's status:

### Dashboard Elements:

#### Protocol Status
- **STANDBY**: Outside of active Killzones
- **HUNTING**: Inside Killzone, looking for Event 1
- **CONFIRMING**: Event 1+ confirmed, waiting for final confirmation
- **ARMED**: All events confirmed, trade setup complete

#### HTF Bias
- **BULLISH**: Higher timeframe trend is bullish (green background)
- **BEARISH**: Higher timeframe trend is bearish (red background)
- **NEUTRAL**: Higher timeframe trend is neutral (gray background)

#### Strategy Checklist
When a strategy is active, the dashboard shows progress through required events:
- **✓**: Event completed
- **☐**: Event pending

## 📈 Strategy Explanations

### The Core SMC Model (4-Event Sequence)

This is the comprehensive strategy following strict Smart Money Concepts principles:

#### Event 1: Manipulation Confirmed
- **Liquidity Sweep**: Price sweeps above/below key levels (Asian H/L, London H/L, PDH/PDL)
- **OR SMT Divergence**: Primary asset makes new high/low but correlated asset doesn't confirm

#### Event 2: Structure Break Confirmed
- **Market Structure Shift (MSS)**: First break against prevailing trend (reversal signal)
- **OR Break of Structure (BOS)**: Break in alignment with trend (continuation signal)

#### Event 3: Return to HTF Point of Interest
- Price retraces into a **5-minute Fair Value Gap** or **Order Block**
- This provides the "discount" entry level

#### Event 4: LTF Entry Confirmation
- Formation of **1-minute or 30-second Inversion Fair Value Gap (IFVG)**
- This is the final trigger confirming rejection from the HTF level

### ICT Silver Bullet (Simplified Model)

This is a faster, simplified strategy for the 10:00-11:00 EST window:

#### Event 1: Liquidity Sweep
- Price sweeps a recent session high/low or swing point

#### Event 2: Price Displacement & FVG
- Strong price move creates a clean Fair Value Gap
- System immediately arms for entry at the FVG

## 🔔 Alert System

### Single Alert Design
The indicator uses **one alert condition** that triggers only when a strategy reaches the **ARMED** state.

### Alert Message Format
```
APEX: [KILLZONE] '[STRATEGY]' [BUY/SELL] Signal!
```

### Example Alert Messages:
- `APEX: LONDON 'The Core SMC Model' BUY Signal!`
- `APEX: NEW_YORK 'ICT Silver Bullet' SELL Signal!`

### Setting Up Alerts:
1. Ensure the indicator is added to your chart
2. Create a new alert with "APEX v3.0" as the condition
3. The alert will only fire when setups are fully confirmed
4. Configure your preferred notification method (email, SMS, webhook, etc.)

## 🎨 Visual Elements

### Fair Value Gaps (FVGs)
- **Green boxes**: Bullish FVGs (potential support)
- **Red boxes**: Bearish FVGs (potential resistance)
- **Extension**: Boxes extend to the right until filled or invalidated

### Order Blocks (OBs)
- **Blue highlights**: Bullish Order Blocks
- **Orange highlights**: Bearish Order Blocks
- **Duration**: Displayed for several bars after formation

### BOS/MSS Markers
- **Green circles**: Break of Structure (BOS) markers
- **Purple diamonds**: Market Structure Shift (MSS) markers
- **Placement**: Above/below the breaking candle

### Session Ranges
- **Horizontal lines**: Mark key session highs and lows
- **Colors**: Customizable for different sessions

## 🔧 Troubleshooting

### Common Issues and Solutions:

#### "No alerts triggering"
- **Check Killzone times**: Ensure you're monitoring during London (3:00-6:00 EST) or New York (9:30-11:00 EST)
- **Verify strategy selection**: Make sure you've selected a strategy (not "OFF")
- **Confirm alert setup**: Ensure the alert condition is properly configured

#### "Dashboard not updating"
- **Refresh chart**: Try refreshing the browser page
- **Check timeframe**: Some features work better on lower timeframes (1-5 minutes)
- **Verify data feed**: Ensure your TradingView data feed is active

#### "Visual elements not showing"
- **Check toggle settings**: Ensure visual toggles are enabled in settings
- **Timeframe compatibility**: Some visuals work better on specific timeframes
- **Chart zoom**: Try zooming in/out to see if elements appear

#### "HTF Bias showing NEUTRAL"
- **Normal behavior**: This can happen during ranging markets
- **Check HTF timeframe**: Default is 4-hour; you may want to adjust
- **Market conditions**: Some market conditions naturally produce neutral bias

### Performance Optimization:
- **Limit visual elements**: Turn off unused visual components
- **Appropriate timeframes**: Use 1-5 minute charts for best performance
- **Clean chart**: Remove unnecessary indicators to improve performance

## 💡 Best Practices

### Chart Setup Recommendations:
1. **Timeframe**: Use 1-minute or 5-minute charts for optimal performance
2. **Market**: Works best on major forex pairs (EUR/USD, GBP/USD, etc.)
3. **Session focus**: Monitor during London and New York sessions for best results
4. **Clean chart**: Minimize other indicators to reduce visual clutter

### Trading Recommendations:
1. **Wait for ARMED status**: Only consider trades when the system shows "ARMED"
2. **Confirm with price action**: Use additional confluence factors
3. **Risk management**: Respect the risk percentage settings
4. **Session awareness**: Different strategies work better in different sessions

### Strategy Selection Guidelines:
- **Core SMC Model**: Best for patient traders wanting high-probability setups
- **ICT Silver Bullet**: Good for active traders during the 10-11 AM EST window
- **Mixed approach**: Use different strategies for different Killzones

### Alert Management:
1. **Test alerts**: Always test alert functionality before live trading
2. **Multiple notifications**: Set up multiple notification methods for redundancy
3. **Alert discipline**: Only act on alerts during your designated trading hours
4. **Review and adjust**: Regularly review alert performance and adjust settings

## 📞 Support and Updates

### Getting Help:
- Review this user guide thoroughly
- Check the troubleshooting section for common issues
- Ensure you're using the latest version of the indicator

### Version Information:
- **Current Version**: 3.0
- **Pine Script Version**: v5
- **Last Updated**: August 31, 2025

---

**Disclaimer**: This indicator is for educational purposes. Always practice proper risk management and never risk more than you can afford to lose. Past performance does not guarantee future results.

