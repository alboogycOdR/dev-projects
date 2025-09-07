# MQL5 Expert Advisor Architecture Design for the 9 AM CRT Model

## 1. Overview

This document outlines the revised architecture for the MQL5 Expert Advisor (EA) implementing the Institutional "9 AM CRT" trading model. The EA will strictly adhere to the hierarchical **Bias, Setup, and Entry** protocol, ensuring a disciplined decision-making process. The design emphasizes modularity, maintainability, and extensibility, following MQL5 best practices.

## 2. Core Components

The EA will be structured around several key components, each responsible for a specific set of functionalities, aligning with the hierarchical CRT trade framing protocol:

### 2.1. `CRT_Core` Class
- **Purpose**: Encapsulate the core hierarchical logic for Bias, Setup, and Entry, and manage the overall trade framing process.
- **Key Methods**:
    - `DetermineDailyBias()`: Identifies the directional bias (Bullish/Bearish) based on Daily Draw on Liquidity or user input.
    - `IdentifyHTFKeyLevel()`: Locates the nearest significant H4 or Daily PD Array (Orderblock, FVG, Breaker Block, Liquidity Void).
    - `CaptureTimedRange()`: Captures the High and Low of the 8:00 AM NY (ET) 1-Hour candle as CRT High/Low.
    - `CheckEntryConditions()`: Evaluates entry logic (Confirmation, Aggressive, 3-Candle) within the NY Killzone.

### 2.2. `Entry_Methods` Class (Revised)
- **Purpose**: Implement the specific entry methods for the 9 AM CRT model.
- **Key Methods**:
    - `CheckConfirmationEntry()`: Implements Liquidity Purge, Market Structure Shift (M15), and retracement into OB/Breaker/FVG.
    - `CheckAggressiveEntry()`: Implements Turtle Soup model for immediate reversal after range sweep.
    - `CheckThreeCandleEntry()`: Implements the 3-candle pattern entry on M15.

### 2.3. `Risk_Management` Class (Enhanced)
- **Purpose**: Handle dynamic position sizing, CRT-based stop loss/take profit, breakeven, and trailing stop.
- **Key Methods**:
    - `CalculatePositionSize()`: Dynamic lot sizing based on risk percentage and SL distance.
    - `SetCRTBasedStopLoss()`: Places SL just beyond the manipulation candle wick.
    - `SetMultiTargetTakeProfit()`: Implements TP1 (50% Equilibrium) and TP2 (opposite CRT end).
    - `ManageBreakeven()`: Moves SL to breakeven after TP1 hit.
    - `ManageTrailingStop()`: Trails SL based on M15 market structure.

### 2.4. `Filter_System` Class (New/Enhanced)
- **Purpose**: Implement advanced contextual filters for A+ setups.
- **Key Methods**:
    - `ApplyWeeklyProfileFilter()`: Filters setups based on user-selected weekly profile (Classic Expansion, Midweek Reversal, Consolidation Reversal).
    - `ApplySMTDivergenceFilter()`: Monitors correlated asset for SMT divergence (requires external library integration).
    - `ApplyHighImpactNewsFilter()`: Avoids trading around high-impact news events (requires external data source like forexfactory.com).

### 2.5. `Operational_Modes` Class (Revised)
- **Purpose**: Manage the different operational modes (Fully-Automated, Signals-Only, Manual).
- **Key Methods**:
    - `SetFullyAutomatedMode()`: Fully automated scanning and execution.
    - `SetSignalsOnlyMode()`: Visual/sound alerts with 


"Confirm Trade" button.
    - `SetManualMode()`: One-click trade panel with pre-calculated SL/TP.

### 2.6. `Dashboard_Manager` Class (Enhanced)
- **Purpose**: Provide a clean, non-intrusive on-chart display with real-time information and controls.
- **Key Methods**:
    - `UpdateDashboard()`: Refreshes dashboard with live data.
    - `DisplayBiasAndDOL()`: Shows current Daily Bias & DOL Target.
    - `DisplayHTFKeyLevel()`: Shows relevant HTF Key Level Zone.
    - `PlotCRTHighLow()`: Plots the 8 AM CRT High & Low on the chart.
    - `DisplayFilterStatus()`: Shows status of News and SMT Filters.
    - `DisplayRealtimeStats()`: Shows P/L, spread, session info.
    - `CreateTradeButtons()`: Creates BUY/SELL buttons for semi-automated execution.

### 2.7. `Notification_System` Class (Retained)
- **Purpose**: Manage alerts and notifications (visual, audio, email, push).
- **Key Methods**:
    - `SendVisualAlert()`: Displays on-screen alerts.
    - `PlayAudioAlert()`: Plays sound notifications.
    - `SendEmailNotification()`: Sends email alerts.
    - `SendPushNotification()`: Sends mobile push notifications.

## 3. Main EA Structure (`OnTick`, `OnInit`, `OnDeinit`)

### `OnInit()`
- Initialize all classes and their respective parameters.
- Load historical data for multi-timeframe analysis.
- Set up initial dashboard display and trade buttons.
- Adjust GMT offset.

### `OnTick()`
- Main execution loop, triggered on every tick.
- **Hierarchical Trade Framing Protocol Execution:**
    1.  Call `CRT_Core.DetermineDailyBias()`.
    2.  Call `CRT_Core.IdentifyHTFKeyLevel()`.
    3.  Call `CRT_Core.CaptureTimedRange()` (at 8 AM NY ET close).
    4.  Call `Filter_System` to apply all contextual filters.
    5.  If all hierarchical steps and filters pass, proceed to `CRT_Core.CheckEntryConditions()`.
- Based on `Operational_Modes`:
    - If Fully-Automated: Execute trades via `Risk_Management`.
    - If Signals-Only: Display visual/sound alerts and enable "Confirm Trade" button.
    - If Manual: Update trade panel with pre-calculated SL/TP.
- Call `Dashboard_Manager` to update real-time display.
- Call `Notification_System` for alerts.

### `OnDeinit()`
- Clean up resources (e.g., delete graphical objects from dashboard, drawn lines).
- Save any persistent data.

## 4. Global Variables and Inputs

- **Global Variables**: For shared data between functions and classes (e.g., current daily bias, CRT High/Low, trade status).
- **Input Parameters (`input` keyword)**: All configurable settings will be exposed as input parameters for user customization in the EA properties window, including:
    - Daily Bias (manual/auto)
    - NY Killzone start/end times
    - Weekly Profile selection
    - Correlated asset for SMT Divergence
    - News filter window
    - Risk percentage, TP targets, breakeven/trailing stop options
    - Dashboard customization options

## 5. Helper Functions/Utilities

- Common utility functions (e.g., time conversions, string manipulation, error logging, drawing objects) will be placed in separate helper files or within a dedicated utility class.

## 6. MQL5 Best Practices

- **Modular Code**: Each component will be a separate class or set of functions.
- **Error Handling**: Robust error checking and logging.
- **Resource Management**: Proper handling of graphical objects, indicators, and memory.
- **Performance Optimization**: Efficient data access and calculation, especially for multi-timeframe analysis.
- **Clear Comments**: Comprehensive comments for all functions, classes, and complex logic.
- **Consistent Naming Conventions**: Adherence to MQL5 naming standards.

This revised architecture provides a robust framework for developing the sophisticated 9 AM CRT Expert Advisor.

