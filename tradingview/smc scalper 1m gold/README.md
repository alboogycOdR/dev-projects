# SMC Scalping State Engine v2.2.1

## Overview

**SMC Scalping State Engine (SMC-SSE)** is an advanced Smart Money Concept (SMC) trading strategy designed specifically for scalping XAU/USD (Gold) on the 1-minute timeframe. The strategy implements a sophisticated **State Transition Architecture** that guides trades through a structured 4-state progression system, ensuring high-quality setups with multiple confirmation layers.

## Project Timeline

This project evolved from **version 2.1** to the current **version 2.2.1**, with significant improvements in robustness, precision, and feature completeness. The development focused on:

- **v2.2.1** (Current): Critical precedence fixes, logic corrections, and UI improvements
- **v2.2**: Major robustness patch with lookahead bias removal, enhanced sweep detection, and strict ICT mode
- **v2.1**: Foundation with range filters, adaptive sweeps, position sizing, and regime detection

## What This Project Is About

### Core Philosophy

The strategy is built on **Smart Money Concepts (SMC)**, a trading methodology that attempts to identify and follow the actions of institutional traders ("smart money"). Unlike retail traders who react to price movements, smart money often creates liquidity traps, order blocks, and fair value gaps that can be identified and traded.

### Target Market

- **Instrument**: XAU/USD (Gold)
- **Timeframe**: 1-minute charts
- **Trading Style**: Scalping with quick entries and exits
- **Session Focus**: London, New York, and Overlap sessions

## Key Components

### 1. State Transition Engine

The heart of the strategy is a **4-state progression system**:

- **State 0 (IDLE)**: Waiting for market structure break
- **State 1 (STRUCTURE)**: BOS/CHoCH detected, structure validated
- **State 2 (TREND OK)**: Trend confirmed via EMAs, OB/FVG present
- **State 3 (ENTRY READY)**: Liquidity sweep detected, entry conditions met

Each state requires specific conditions to progress, ensuring only high-probability setups reach execution.

### 2. Market Structure Detection

- **BOS (Break of Structure)**: Identifies swing point breaks with minimum ATR distance
- **CHoCH (Change of Character)**: Detects trend reversals using internal and external structure
- **Swing Point Tracking**: Maintains arrays of swing highs/lows for structure analysis

### 3. Order Blocks (OBs) & Fair Value Gaps (FVGs)

- **Order Blocks**: Identifies institutional order zones from previous candle bodies
- **Fair Value Gaps**: Detects price inefficiencies that often get filled
- **Mitigation Tracking**: Monitors when OBs/FVGs are invalidated
- **Ageing System**: Visual opacity changes as OBs/FVGs age

### 4. Liquidity Sweep Detection

- **Anchored Sweeps**: Tracks known liquidity pools (swing points, Asian session levels, PDH/PDL)
- **Displacement Validation**: Requires price movement after sweep
- **Reclaim Confirmation**: Ensures price returns above/below swept level
- **Adaptive Thresholds**: Adjusts sweep sensitivity based on volatility

### 5. Trend Confirmation

- **EMA Stack**: Fast (20) and Slow (50) EMA for trend direction
- **EMA Separation**: Requires minimum 0.35 ATR separation (configurable)
- **EMA Slope**: Validates trend strength via slope direction
- **VWAP Integration**: Uses VWAP bands for premium/discount zones

### 6. Confluence Scoring System

Trades require a minimum confluence score based on:
- Order Block presence
- Fair Value Gap presence
- VWAP alignment
- Key level sweeps
- EMA stack confirmation
- Regime compatibility

### 7. Risk Management

- **Position Sizing**: Multiple methods (Fixed %, Kelly Criterion, Volatility Adjusted, ATR-Based)
- **Stop Loss**: Dynamic based on OB levels or ATR
- **Take Profit**: 3-tier TP system with key level integration
- **Session Limits**: Maximum trades per session (London, NY, Overlap)
- **Daily Limits**: Maximum trades per day with cooldown periods
- **Consecutive Loss Protection**: Automatic halt after max consecutive losses

### 8. Regime Detection

- **Volatility Regimes**: Low, Normal, High Volatility classification
- **ADR Percentile**: Uses Average Daily Range percentile for regime detection
- **VIX Proxy**: Optional VIX integration for volatility confirmation
- **Regime Filtering**: Can restrict trades to specific volatility conditions

### 9. Session Management

- **London Session**: Configurable start/end times
- **New York Session**: Configurable start/end times
- **Overlap Period**: London/NY overlap detection
- **Asian Session**: Tracks Asian session highs/lows for liquidity sweeps

### 10. Visual Dashboard

A comprehensive real-time dashboard displays:
- Current state and direction
- Active session
- Confluence score
- Filter status (Range, Regime, EMA Separation)
- Setup validation status
- Step progression (Structure → Trend → Entry)
- Daily trade count
- Current position

**Color Scheme**: Black background with neon green (#00FF00) for positive/active states and neon yellow (#FFFF00) for warnings/neutral states.

## Trading Modes

### Strict ICT Mode
- Requires sweep of known liquidity pools (PDH/PDL, Asian levels, swing points)
- Enforces displacement and reclaim rules
- More selective, higher precision

### Statistical Mode
- More signals, lower precision
- Uses statistical sweep detection
- Better for ranging markets

## Key Features

### Filters & Gates

1. **Range Filter**: Filters out micro-breaks and ensures minimum candle range
2. **Regime Filter**: Can restrict to specific volatility regimes
3. **EMA Separation Gate**: Ensures sufficient trend strength
4. **Trend Strength Gate**: Combines EMA separation and slope
5. **Session Filter**: Only trades during active sessions
6. **Setup Invalidation**: Monitors OB/FVG penetration for invalidation

### Advanced Features

- **HTF Alignment**: Optional 5M timeframe alignment requirement
- **Internal Structure Tracking**: Micro-structure for CHoCH validation
- **Adaptive Sweep Thresholds**: Volatility-adjusted sweep detection
- **Key Level Integration**: PDH/PDL, Weekly High/Low, Asian levels
- **Optimization Plots**: Visual metrics for strategy optimization

## Technical Specifications

- **Language**: Pine Script v5
- **Strategy Type**: Overlay strategy
- **Max Bars Back**: 500
- **Dynamic Requests**: Enabled (for multi-timeframe data)
- **Drawing Objects**: Up to 500 boxes, labels, and lines

## Configuration

The strategy includes extensive input parameters organized into groups:

- **General Settings**: Visual toggles, dashboard display
- **Trading Mode**: Entry style, HTF alignment
- **Step 1 - Market Structure**: Swing lookbacks, BOS sensitivity, OB settings
- **Step 2 - Trend Confirmation**: EMA periods, trend strength gates
- **Step 3 - Liquidity Sweep**: Sweep detection, displacement rules
- **Order Blocks**: OB formation, mitigation modes, display settings
- **Fair Value Gaps**: FVG detection, mitigation, display
- **VWAP**: Bands, premium/discount zones
- **Confluence**: Scoring weights, minimum thresholds
- **Risk Management**: Position sizing, stop loss, take profit
- **Session Management**: Session times, trade limits
- **Regime Detection**: ADR settings, VIX proxy, regime filtering
- **Range Filter**: Candle range filtering
- **Visual Settings**: Colors, labels, optimization plots

## Usage

1. **Load the Strategy**: Add to TradingView chart (1-minute XAU/USD)
2. **Configure Settings**: Adjust inputs based on your risk tolerance and market conditions
3. **Monitor Dashboard**: Watch the state progression and filter status
4. **Set Alerts**: Configure alerts for state transitions and entry signals
5. **Backtest**: Use TradingView's strategy tester to evaluate performance

## Important Notes

- **Default Settings**: Optimized for 1M Gold scalping
  - EMA Separation: 0.35 ATR (lowered from 0.5 for ranging periods)
  - Regime Filter: "All Regimes" (to avoid blocking trades during volatile periods)
- **Session Trading**: Strategy is most effective during London, NY, and overlap sessions
- **Risk Management**: Always use appropriate position sizing and stop losses
- **Market Conditions**: Performance varies with volatility regimes

## Version History

### v2.2.1 (Current)
- Fixed BOS/CHoCH parentheses grouping
- Fixed State1→2 transition logic precedence
- Renamed "Spread Filter" to "Range Filter" for clarity
- Fixed sweptKnownLevel to find nearest level
- Improved dashboard legibility (black, neon green, yellow theme)
- Lowered EMA separation threshold to 0.35 ATR
- Changed default regime filter to "All Regimes"

### v2.2
- Removed lookahead bias in key levels
- Added minimum BOS break distance filter
- Added EMA separation/slope trend strength gate
- Anchored sweeps to known liquidity pools
- Added displacement and reclaim validation
- Added internal vs external structure tracking
- Added setup invalidation on OB/FVG penetration
- Added Strict ICT vs Statistical mode toggle

### v2.1
- Range Filter implementation
- Adaptive Sweep detection
- Position Sizing methods
- Regime Detection
- Optimization Plots
- OB/FVG Ageing
- Inverse Mode
- Max Orders per session

## Development Notes

This strategy represents a comprehensive implementation of Smart Money Concepts with a focus on:
- **Precision**: Multiple confirmation layers before entry
- **Robustness**: Extensive error handling and edge case management
- **Flexibility**: Extensive configuration options
- **Visualization**: Clear dashboard and chart annotations
- **Performance**: Optimized for 1-minute Gold scalping

## Disclaimer

This strategy is for educational and research purposes. Past performance does not guarantee future results. Always practice proper risk management and never risk more than you can afford to lose. Trading involves substantial risk of loss.

---

**Author**: Developed for 1-minute XAU/USD scalping  
**Version**: 2.2.1  
**Last Updated**: 2024  
**Platform**: TradingView Pine Script v5

