# MQL5 Expert Advisor Architecture Design

## 1. Overview

This document outlines the proposed architecture for the MQL5 Expert Advisor (EA) implementing the Candle Range Theory (CRT) trading strategy. The EA will be designed with modularity, maintainability, and extensibility in mind, adhering to MQL5 best practices.

## 2. Core Components

The EA will be structured around several key components, each responsible for a specific set of functionalities:

### 2.1. `CRT_Strategy` Class
- **Purpose**: Encapsulate the logic for CRT phase detection (Accumulation, Manipulation, Distribution) and multi-timeframe analysis (H4 for patterns, M15 for entry).
- **Key Methods**:
    - `DetectCRTPhase()`: Identifies the current CRT phase based on H4 and M15 data.
    - `GetCRTLevels()`: Calculates and returns CRT range levels (e.g., highs, lows, midpoints).
    - `CheckMultiTimeframeAlignment()`: Verifies alignment across H4 and M15 for CRT patterns.

### 2.2. `Entry_Methods` Class
- **Purpose**: Implement the various entry methods specified (Turtle Soup, Order Block/CSD, Third Candle, Auto Best).
- **Key Methods**:
    - `CheckTurtleSoupEntry()`: Logic for Turtle Soup entry.
    - `CheckOrderBlockEntry()`: Logic for Order Block/CSD entry.
    - `CheckThirdCandleEntry()`: Logic for Third Candle entry.
    - `SelectAutoBestEntry()`: Determines the optimal entry method based on market conditions.

### 2.3. `Risk_Management` Class
- **Purpose**: Handle all aspects of risk management, including position sizing, stop loss/take profit calculation, and trade limits.
- **Key Methods**:
    - `CalculatePositionSize()`: Determines lot size based on risk percentage and account balance.
    - `SetStopLossTakeProfit()`: Calculates SL/TP levels based on CRT ranges and entry method.
    - `CheckTradeLimits()`: Enforces daily/session trade limits and drawdown protection.
    - `PerformMarginCheck()`: Ensures sufficient margin before opening trades.

### 2.4. `Session_Manager` Class
- **Purpose**: Manage trading sessions (Sydney, Tokyo, Frankfurt, London, New York) with automatic GMT adjustment.
- **Key Methods**:
    - `IsTradingSessionActive()`: Checks if the current time falls within an active trading session.
    - `AdjustGMT()`: Automatically adjusts for broker server time GMT offset.

### 2.5. `Filter_System` Class
- **Purpose**: Implement technical and session-based filters to refine trade signals.
- **Key Methods**:
    - `ApplyTechnicalFilters()`: Checks for Inside Bar, Key Level confluence, CRT Plus, Nested CRT.
    - `ApplySessionFilters()`: Checks for Monday/Friday filters, high-impact news avoidance, spread protection.

### 2.6. `Operational_Modes` Class
- **Purpose**: Manage the different operational modes (Auto-Trading, Manual Trading, Hybrid).
- **Key Methods**:
    - `SetAutoTradingMode()`: Activates fully automated trading.
    - `SetManualTradingMode()`: Activates manual trading with notifications.
    - `SetHybridMode()`: Allows switching between auto and manual.

### 2.7. `Dashboard_Manager` Class
- **Purpose**: Handle the real-time graphical dashboard display and customization.
- **Key Methods**:
    - `UpdateDashboard()`: Refreshes dashboard with live data.
    - `DisplayCRTViz()`: Visualizes CRT phases and ranges.
    - `DisplayStats()`: Shows win rate, P/L, trade count, etc.
    - `DisplaySignals()`: Shows bullish/bearish signals and strength.
    - `ApplyCustomization()`: Handles color themes, font sizes, layout.

### 2.8. `Notification_System` Class
- **Purpose**: Manage alerts and notifications (visual, audio, email, push).
- **Key Methods**:
    - `SendVisualAlert()`: Displays on-screen alerts.
    - `PlayAudioAlert()`: Plays sound notifications.
    - `SendEmailNotification()`: Sends email alerts.
    - `SendPushNotification()`: Sends mobile push notifications (if supported).

## 3. Main EA Structure (`OnTick`, `OnInit`, `OnDeinit`)

### `OnInit()`
- Initialize all classes and their respective parameters.
- Load historical data for multi-timeframe analysis.
- Set up initial dashboard display.

### `OnTick()`
- Main execution loop, triggered on every tick.
- Get latest market data.
- Call `CRT_Strategy` to detect phase and levels.
- Call `Filter_System` to apply filters.
- Based on `Operational_Modes`:
    - If Auto-Trading: Call `Entry_Methods` to check for signals and `Risk_Management` to execute trades.
    - If Manual Trading: Display visual notifications; await user input for BUY/SELL.
- Call `Dashboard_Manager` to update real-time display.
- Call `Notification_System` for alerts.

### `OnDeinit()`
- Clean up resources (e.g., delete graphical objects from dashboard).
- Save any persistent data.

## 4. Global Variables and Inputs

- **Global Variables**: For shared data between functions and classes (e.g., current CRT phase, trade status).
- **Input Parameters (`input` keyword)**: All configurable settings will be exposed as input parameters for user customization in the EA properties window.

## 5. Helper Functions/Utilities

- Common utility functions (e.g., time conversions, string manipulation, error logging) will be placed in separate helper files or within a dedicated utility class.

## 6. MQL5 Best Practices

- **Modular Code**: Each component will be a separate class or set of functions.
- **Error Handling**: Robust error checking and logging.
- **Resource Management**: Proper handling of graphical objects and indicators.
- **Performance Optimization**: Efficient data access and calculation.
- **Clear Comments**: Comprehensive comments for all functions, classes, and complex logic.
- **Consistent Naming Conventions**: Adherence to MQL5 naming standards.

This architecture provides a solid foundation for developing a robust and feature-rich MQL5 Expert Advisor.

