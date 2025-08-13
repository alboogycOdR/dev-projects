# CRT State Engine - Professional Operational Manual

**Version 1.0 | For Intermediate to Advanced Algorithmic Traders**

---

## Table of Contents

1. [System Overview](#system-overview)
2. [Installation & Setup](#installation--setup)
3. [Core Components](#core-components)
4. [Understanding the Dashboard](#understanding-the-dashboard)
5. [Trading Methodology](#trading-methodology)
6. [Alert System & Interpretation](#alert-system--interpretation)
7. [Operational Workflow](#operational-workflow)
8. [Risk Management](#risk-management)
9. [Performance Optimization](#performance-optimization)
10. [Troubleshooting](#troubleshooting)
11. [Advanced Features](#advanced-features)

---

## System Overview

### What is the CRT State Engine?

The **Candle Range Theory (CRT) State Engine** is a comprehensive institutional trading system that programmatically detects and trades high-probability market manipulation patterns used by institutional traders. The system combines real-time market analysis, session-based state tracking, and precise entry signal generation.

### Core Methodology

The system is built on three fundamental pillars:

1. **Draw on Liquidity (DOL) Analysis** - Determines institutional bias and target zones
2. **Session State Machine** - Tracks market behavior across trading sessions
3. **Multi-Model CRT Detection** - Identifies 1AM, 5AM, and 9AM institutional patterns

### Key Features

- **Real-time DOL detection** with automatic bias calculation
- **Session behavior classification** (Consolidation, Manipulation, Expansion)
- **Three CRT models** covering different institutional time windows
- **Order Block and FVG detection** for precise entry timing
- **Comprehensive alert system** with detailed market context
- **Risk management integration** with automatic R:R calculations

---

## Installation & Setup

### Prerequisites

- TradingView Pro account (for real-time data and alerts)
- Access to 4-hour timeframe charts
- Basic understanding of institutional trading concepts

### Installation Steps

1. **Copy the Pine Script code** from the provided file
2. **Open TradingView** and navigate to Chart → Pine Script Editor
3. **Paste the code** and click "Add to Chart"
4. **Configure initial settings** according to your trading preferences
5. **Test on historical data** to verify proper installation

### Initial Configuration

#### Essential Settings:

```
Core System:
✅ Enable DOL Analysis Engine
✅ Enable Session State Machine  
✅ Enable Live Entry Signals
❌ Debug Mode (disable for live trading)

DOL Analysis:
• DOL Pivot Strength: 10 (default, increase for less sensitive detection)

CRT Models:
✅ 1AM CRT Model (London manipulation)
✅ 5AM CRT Model (London lunch transition)  
✅ 9AM CRT Model (NY session commitment)
```

#### Recommended Visual Settings:

```
Visuals:
✅ Show DOL Lines
✅ Show Session Boxes
✅ Show Key Levels
✅ Show Entry Signals
```

---

## Core Components

### 1. DOL (Draw on Liquidity) Analysis Engine

**Purpose:** Determines the institutional directional bias by identifying the nearest significant liquidity pool.

**How it Works:**
- Scans for major swing highs and lows using configurable pivot strength
- Calculates distance from current price to each liquidity zone
- Determines bias based on "path of least resistance" principle
- Updates automatically as new swing points are confirmed

**Dashboard Display:**
```
DOL Bias: BULLISH → 1.0980
```
- **BULLISH**: Price likely to move toward swing high target
- **BEARISH**: Price likely to move toward swing low target
- **Target Price**: Specific level where liquidity resides

### 2. Session State Machine

**Purpose:** Classifies market behavior across different trading sessions to understand institutional intent.

**Session Windows (GMT):**
- **CBDR**: 17:00-21:00 (Close, Reversal, Discount, Premium)
- **ASIA**: 21:00-01:00 (Asian session activity)
- **LONDON**: 01:00-05:00 (London session manipulation)
- **LUNCH**: 05:00-09:00 (London lunch, NY preparation)
- **NY**: 09:00-13:00 (New York session expansion)

**Behavior Classification:**
- **CONSOLIDATION**: Range-bound, accumulation phase
- **MANIPULATION**: False breakouts, liquidity sweeps
- **EXPANSION**: Directional movement, trend continuation

### 3. CRT Pattern Detection

#### 1AM CRT Model
**Target Window:** London session (01:00-05:00 GMT)
**Patterns:**
- **Normal Protraction**: CBDR consolidation → Asia consolidation → London manipulation
- **Delayed Protraction**: CBDR consolidation → Asia manipulation → London expansion

**States:**
- **A_FORMING**: Accumulation phase beginning
- **M_LIVE**: Manipulation in progress
- **D_READY**: Distribution phase, entry zone active

#### 5AM CRT Model  
**Target Window:** London lunch transition (05:00-09:00 GMT)
**Patterns:**
- **London Lunch Low**: Market establishes daily low during lunch
- **NY Continuation**: Continuation of London direction into NY
- **NY Reversal**: Reversal of prior session trend

#### 9AM CRT Model
**Target Window:** NY session opening (09:00-13:00 GMT)
**Patterns:**
- **NY Continuation**: DOL not reached, London made HOD/LOD
- **NY Reversal**: DOL reached, protected session highs/lows

---

## Understanding the Dashboard

### Main Dashboard Layout

```
┌─────────────────────────────────┐
│        CRT STATE ENGINE         │
├─────────────┬─────────┬─────────┤
│ DOL Bias    │ BULLISH │ 1.0980  │
│ Session     │ LONDON  │ MANIP   │
│ 1AM CRT     │ D_READY │ NORMAL  │
│ 5AM CRT     │ INACTIVE│         │
│ 9AM CRT     │ INACTIVE│         │
│ Entry Signal│ NONE    │ -       │
│ Key Levels  │ OB BULL │ FVG BEAR│
└─────────────┴─────────┴─────────┘
```

### Dashboard Interpretation

#### DOL Status Row
- **Left**: Always shows "DOL Bias"
- **Middle**: Current bias direction (BULLISH/BEARISH/NEUTRAL)  
- **Right**: Target price level
- **Color**: Green (bullish), Red (bearish), Gray (neutral)

#### Session Status Row
- **Left**: Always shows "Session"
- **Middle**: Current session name
- **Right**: Session behavior type
- **Color**: Gray (consolidation), Orange (manipulation), Blue (expansion)

#### CRT Model Rows
- **Left**: Model name (1AM/5AM/9AM CRT)
- **Middle**: Current state (INACTIVE/A_FORMING/M_LIVE/D_READY)
- **Right**: Active profile type (when applicable)
- **Color**: Green (D_READY), Gray (other states)

#### Entry Signal Row  
- **Left**: Always shows "Entry Signal"
- **Middle**: Signal type (NONE/BUY/SELL)
- **Right**: Entry price (when signal active)
- **Color**: Green (BUY), Red (SELL), Gray (NONE)

#### Key Levels Row
- **Left**: Always shows "Key Levels"  
- **Middle**: Order Block status
- **Right**: Fair Value Gap status
- **Color**: Orange (OB detected), Purple (FVG detected), Gray (none)

---

## Trading Methodology

### The Complete Trading Process

#### Phase 1: Market Context Analysis (H4 Timeframe)

**Step 1: DOL Assessment**
```
✅ Identify current DOL bias and target
✅ Confirm bias aligns with your directional assumption
✅ Note target price for profit-taking considerations
```

**Step 2: Session Analysis**  
```
✅ Determine current session and behavior
✅ Confirm session aligns with trading model
✅ Wait for appropriate session transitions
```

**Step 3: CRT Model Selection**
```
✅ Choose primary model based on time availability
✅ Enable relevant model in settings
✅ Monitor state progression (A → M → D)
```

#### Phase 2: Pattern Recognition

**1AM CRT Trading:**
- **Best for:** London session traders (01:00-09:00 GMT)
- **Entry window:** 02:00-03:00 GMT during D_READY state
- **Profile consideration:** Normal vs Delayed Protraction affects risk/reward

**5AM CRT Trading:**
- **Best for:** London lunch and NY open traders
- **Entry windows:** 06:00-07:00 GMT (lunch) or 07:00-08:30 GMT (NY prep)
- **Profile consideration:** Three distinct scenarios require different approaches

**9AM CRT Trading:**
- **Best for:** NY session traders
- **Entry windows:** 09:00-10:00 GMT or 09:30-10:30 GMT
- **Profile consideration:** Continuation vs Reversal based on DOL status

#### Phase 3: Entry Execution

**Entry Conditions (All must align):**
```
✅ CRT model in D_READY state
✅ DOL bias matches intended direction
✅ Within appropriate time window
✅ Order Block detected in favor of bias
✅ Session behavior supports the move
```

**Entry Methodology:**
1. **Monitor dashboard** for D_READY state activation
2. **Switch to M15 timeframe** for precise entry timing
3. **Wait for Order Block formation** in direction of bias
4. **Enter on M15 confirmation** above/below OB levels
5. **Set stops below/above OB** with auto-calculated R:R

#### Phase 4: Risk Management

**Stop Loss Placement:**
- **1AM CRT**: Below/above manipulation candle extremes
- **5AM CRT**: Beyond session highs/lows
- **9AM CRT**: Outside 8AM candle range (for H1 version)

**Take Profit Targets:**
- **Primary**: 1:2 Risk/Reward (default)
- **Extended**: 1:3 Risk/Reward for strong setups
- **Dynamic**: Move to breakeven after 1:1 achieved

---

## Alert System & Interpretation

### Alert Priority Levels

#### 🔥 CRITICAL (Immediate Action Required)
```
🚀 BUY SIGNAL GENERATED
🚀 SELL SIGNAL GENERATED
🔥 ENTRY ZONE ACTIVE (D_READY states)
```

#### ⚡ HIGH (Prepare for Action)
```
🎯 DOL BIAS CHANGED
📅 NEW SESSION STARTED
⚡ SESSION BEHAVIOR CHANGE
```

#### 📊 MEDIUM (Monitor Closely)
```
📊 NEW ORDER BLOCK DETECTED
🔄 CRT STATE CHANGE
```

### Alert Message Structure

Every alert contains comprehensive market context:

```
🚨 CRT STATE ENGINE ALERT 🚨
━━━━━━━━━━━━━━━━━━━━━━━━━
📊 EURUSD | 240 | 2025-08-13 09:00:00
💰 Price: 1.0955

🎯 MARKET ANALYSIS:
• DOL Bias: BEARISH → 1.0920
• Session: NY (MANIPULATION)
• Active Profile: NORMAL_PROTRACTION

🔄 CRT MODEL STATUS:
• 1AM CRT: D_READY
• 5AM CRT: INACTIVE  
• 9AM CRT: INACTIVE

📈 KEY LEVELS:
• Order Block: BEARISH Active
• FVG: None

⚡ ALERT: 🔥 ENTRY ZONE ACTIVE 🔥
📋 Details: 1AM CRT ready for distribution
━━━━━━━━━━━━━━━━━━━━━━━━━
🤖 CRT State Engine v1.0
```

### Alert Interpretation Guide

#### DOL Bias Change Alert
**When:** Swing point analysis determines new institutional target
**Action:** Reassess directional bias, adjust trading plan
**Significance:** Fundamental shift in market structure

#### Session Transition Alert  
**When:** New trading session begins (e.g., London → Lunch)
**Action:** Prepare for behavior change, monitor for patterns
**Significance:** Different sessions have distinct characteristics

#### CRT State Change Alert
**When:** Pattern progresses through A → M → D states
**Action:** Increase monitoring intensity, prepare for entries
**Significance:** Pattern development in real-time

#### Entry Zone Active Alert
**When:** Any CRT model reaches D_READY state
**Action:** Switch to execution timeframe, monitor for signals
**Significance:** High-probability entry window opening

#### Entry Signal Alert
**When:** All conditions align for trade execution
**Action:** Execute trade immediately or within 15 minutes
**Significance:** Highest conviction trade setup

---

## Operational Workflow

### Daily Routine

#### Pre-Market Setup (30 minutes before target session)
1. **Check DOL status** - Confirm current bias and targets
2. **Review overnight session behavior** - Understand market context
3. **Enable relevant CRT models** - Based on your trading schedule
4. **Set up alerts** - Ensure all notifications are active
5. **Prepare trading platform** - Ready for quick execution

#### During Trading Hours
1. **Monitor dashboard continuously** - Watch for state changes
2. **Respond to alerts promptly** - Critical signals require immediate attention
3. **Document decisions** - Keep trading journal with reasoning
4. **Manage open positions** - Follow risk management protocols
5. **Update market analysis** - Adjust strategy based on new information

#### Post-Session Review (15 minutes after session close)
1. **Review alert history** - Analyze signal accuracy
2. **Document session behavior** - Build pattern recognition
3. **Assess performance** - Compare actual vs expected outcomes
4. **Plan next session** - Identify opportunities and risks
5. **Update settings** - Optimize based on market conditions

### Weekly Optimization

#### Performance Analysis
- **Track alert accuracy** - Hit rate of DOL targets
- **Measure signal quality** - Entry signal win/loss ratio
- **Analyze session classification** - Behavior prediction accuracy
- **Review risk/reward** - Actual vs theoretical R:R ratios

#### System Tuning
- **Adjust pivot strength** - Based on market volatility
- **Optimize time windows** - Refine entry timing
- **Update alert thresholds** - Reduce noise, increase signal
- **Refine risk parameters** - Adapt to changing market conditions

---

## Risk Management

### Position Sizing

#### Conservative Approach (Recommended for beginners)
- **Risk per trade:** 0.5-1% of account
- **Maximum concurrent positions:** 2-3
- **Maximum daily risk:** 2% of account

#### Aggressive Approach (For experienced traders)
- **Risk per trade:** 1-2% of account  
- **Maximum concurrent positions:** 3-5
- **Maximum daily risk:** 5% of account

### Stop Loss Management

#### Static Stops
- **1AM CRT**: 20-30 pips beyond manipulation extremes
- **5AM CRT**: 25-40 pips beyond session boundaries
- **9AM CRT**: 15-25 pips beyond pattern invalidation

#### Dynamic Stops
- **Breakeven move**: After 1:1 R:R achieved
- **Trailing stops**: Follow favorable price action
- **Time-based exits**: Close if setup doesn't develop within 2-4 hours

### Risk Scenarios

#### High-Risk Conditions (Reduce position size or avoid)
- **Major news events** within 2 hours of entry window
- **Low liquidity sessions** (late Friday, holidays)
- **Conflicting DOL signals** (recent bias changes)
- **Multiple failed signals** in same session

#### Optimal Risk Conditions (Standard position size)
- **Clear DOL bias** maintained for 24+ hours
- **Clean session transitions** with expected behavior
- **Confluence of multiple models** agreeing on direction
- **Strong Order Block formations** supporting bias

---

## Performance Optimization

### System Tuning Parameters

#### DOL Pivot Strength
- **Low volatility markets**: Increase to 12-15 (fewer, stronger signals)
- **High volatility markets**: Decrease to 7-10 (more responsive signals)
- **Range-bound markets**: Increase to 15-20 (avoid noise)

#### Time Window Adjustments
- **Fast-moving markets**: Narrow windows by 15-30 minutes
- **Slow-moving markets**: Expand windows by 15-30 minutes
- **Holiday sessions**: Expand windows, reduce position size

#### Alert Sensitivity
- **High-frequency trading**: Enable all alerts, immediate notifications
- **Swing trading**: Focus on D_READY and entry signals only
- **Position trading**: DOL changes and major session transitions

### Market Condition Adaptations

#### Trending Markets
- **Favor continuation models** (9AM NY Continuation)
- **Increase take profits** to 1:3 or 1:4 R:R
- **Trail stops more aggressively**
- **Focus on breakout Order Blocks**

#### Range-Bound Markets  
- **Favor reversal models** (9AM NY Reversal)
- **Take profits earlier** at 1:2 R:R
- **Use tighter stops**
- **Focus on rejection Order Blocks**

#### High-Impact News Days
- **Avoid trading 2 hours before/after major releases**
- **If already in position**, move to breakeven before news
- **Wait for new DOL establishment** after news impact
- **Reduce position sizes** by 50%

---

## Troubleshooting

### Common Issues and Solutions

#### Dashboard Not Updating
**Symptoms:** Static values, no state changes
**Causes:** 
- Timeframe not set to 4H
- Real-time data feed interrupted
- Browser/platform memory issues

**Solutions:**
1. Refresh chart and re-add indicator
2. Verify timeframe is exactly "240" (4 hours)  
3. Check TradingView connection status
4. Clear browser cache if using web platform

#### Missing Alerts
**Symptoms:** Expected alerts not firing
**Causes:**
- Alert conditions not properly configured
- TradingView alert limits reached
- Notification permissions disabled

**Solutions:**
1. Check TradingView alert list for active alerts
2. Verify alert conditions match indicator states
3. Test with one alert first, then add others
4. Ensure sufficient alert quota in account

#### Incorrect DOL Detection
**Symptoms:** DOL targets seem unrealistic or change too frequently
**Causes:**
- Pivot strength too low for market conditions
- Insufficient historical data
- Major market event disrupted swing analysis

**Solutions:**
1. Increase pivot strength to 12-15
2. Allow 2-3 days for swing point establishment
3. Manually verify swing points align with visual analysis
4. Reset during major market structure changes

#### Entry Signals Not Generating
**Symptoms:** D_READY state active but no entry signals
**Causes:**
- No Order Block detected in bias direction
- Outside entry time windows
- Risk/reward parameters too strict

**Solutions:**
1. Switch to M15 timeframe to verify Order Block formation
2. Confirm current time is within model's entry window
3. Check if DOL bias matches expected entry direction
4. Manually verify Order Block criteria on chart

### Performance Issues

#### Slow Chart Loading
**Solutions:**
- Reduce history days limit to 3-5 days
- Decrease max instances per pattern to 50-100
- Disable debug mode during live trading
- Use shorter lookback periods for calculations

#### Memory Warnings
**Solutions:**
- Restart TradingView platform
- Reduce number of active models (use 1-2 instead of all 3)
- Clear browser cache and cookies
- Upgrade to TradingView Pro+ if using basic account

---

## Advanced Features

### Multi-Symbol Analysis

#### Setup Process
1. **Create separate chart windows** for each major pair
2. **Apply CRT Engine** to each chart independently  
3. **Monitor correlations** between EUR/USD, GBP/USD, USD/JPY
4. **Look for SMT divergences** when signals conflict

#### Correlation Trading
- **When EU and GU signals align**: High-confidence trades
- **When EU and GU diverge**: Look for SMT setups
- **When USD pairs conflict**: Wait for clarity or trade individual pairs

### Custom Alert Integration

#### Webhook Setup (Advanced Users)
```json
{
  "symbol": "{{ticker}}",
  "alert_type": "{{strategy.order.alert_message}}",
  "price": "{{close}}",
  "timestamp": "{{time}}",
  "timeframe": "{{interval}}"
}
```

#### Integration with Trading Bots
- **MT4/MT5**: Use webhook-to-EA bridges
- **TradingView**: Direct strategy conversion (contact support)
- **Third-party platforms**: API integration via webhook services

### Historical Analysis Tools

#### Backtesting Approach
1. **Scroll back 30-60 days** on chart
2. **Enable debug mode** to see all historical states
3. **Document signal accuracy** manually
4. **Calculate win/loss ratios** per model
5. **Identify optimal market conditions** for each pattern

#### Performance Metrics to Track
- **DOL accuracy**: % of times target reached within 48 hours
- **Session classification**: Accuracy of consolidation/manipulation/expansion predictions
- **Entry signal quality**: Win rate of actual trade entries
- **Risk/reward achievement**: % of trades reaching take profit targets

### Customization Options

#### Visual Modifications
```pinescript
// Modify these lines in the code for custom appearance:
col_bullish_dol = input.color(color.new(color.blue, 20), "Custom Bull Color")
col_bearish_dol = input.color(color.new(color.orange, 20), "Custom Bear Color")
```

#### Time Zone Adjustments
```pinescript
// For different broker time zones, adjust session hours:
// GMT+2 broker: add 2 hours to all session times
// GMT-5 broker: subtract 5 hours from all session times
```

#### Sensitivity Tuning
```pinescript
// Adjust these parameters for different market conditions:
pivot_strength = 15 // Higher = less sensitive, fewer signals
risk_reward_ratio = 2.5 // Higher = larger targets, potentially fewer wins
```

---

## Appendices

### Appendix A: Alert Message Templates

#### Critical Entry Signal Template
```
🚨 CRITICAL: {{alert_type}} 🚨
Symbol: {{ticker}}
Price: {{close}}
DOL: {{dol_bias}} → {{dol_target}}
Entry: {{entry_price}}
Stop: {{stop_loss}}
Target: {{take_profit}}
Time Window: {{time_window}}
```

#### State Change Template  
```
⚡ CRT STATE UPDATE ⚡
Model: {{crt_model}}
Previous: {{prev_state}}
Current: {{current_state}}
Session: {{session}} ({{behavior}})
Next Action: {{recommended_action}}
```

### Appendix B: Session Time Reference

#### GMT Time Zone (Standard)
```
CBDR:   17:00 - 21:00
ASIA:   21:00 - 01:00
LONDON: 01:00 - 05:00  
LUNCH:  05:00 - 09:00
NY:     09:00 - 13:00
```

#### EST Time Zone (GMT-5)
```
CBDR:   12:00 - 16:00
ASIA:   16:00 - 20:00
LONDON: 20:00 - 00:00
LUNCH:  00:00 - 04:00
NY:     04:00 - 08:00
```

#### CET Time Zone (GMT+1)  
```
CBDR:   18:00 - 22:00
ASIA:   22:00 - 02:00
LONDON: 02:00 - 06:00
LUNCH:  06:00 - 10:00
NY:     10:00 - 14:00
```

### Appendix C: Risk Management Calculator

#### Position Size Formula
```
Position Size = (Account Size × Risk %) ÷ (Entry Price - Stop Loss)

Example:
Account: $10,000
Risk: 1% = $100
Entry: 1.0950
Stop: 1.0920
Difference: 30 pips = $30 per lot

Position Size = $100 ÷ $30 = 3.33 mini lots
```

#### Risk/Reward Calculation
```
Risk = Entry Price - Stop Loss
Reward = Take Profit - Entry Price
R:R Ratio = Reward ÷ Risk

Example:
Entry: 1.0950
Stop: 1.0920  
Target: 1.1010
Risk: 30 pips
Reward: 60 pips
R:R = 60 ÷ 30 = 2:1
```

---

## Support and Updates

### Getting Help
- **Documentation**: Refer to this manual first
- **Community**: Access user forum for peer support
- **Technical Support**: Contact support team for system issues
- **Training**: Advanced training sessions available quarterly

### System Updates
- **Version notifications**: Automatic alerts for new releases  
- **Update procedure**: Simple copy/paste code replacement
- **Backward compatibility**: Settings preserved between versions
- **Change log**: Detailed documentation of improvements

### Feedback and Improvements
- **Feature requests**: Submit via support portal
- **Bug reports**: Include chart screenshots and detailed description
- **Performance data**: Share backtesting results for system optimization
- **Success stories**: Help improve system through real-world feedback

---

**© 2025 CRT State Engine | Professional Trading System**
**Version 1.0 | Last Updated: August 2025**

*This manual is proprietary and confidential. Distribution is limited to licensed users only.*