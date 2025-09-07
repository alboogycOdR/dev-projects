# Expert Advisor (EA) Development Guide

This guide outlines our approach to building MetaTrader Expert Advisors (EAs) with a focus on modularity, maintainability, and clear structure.

## Table of Contents
1. [Project Structure](#project-structure)
2. [Code Organization](#code-organization)
3. [Helper Modules](#helper-modules)
4. [EA Core Structure](#ea-core-structure)
5. [Best Practices](#best-practices)
6. [Naming Conventions](#naming-conventions)

## Project Structure

Our EAs follow this directory structure:
```
/Hub
    /Helpers         # Reusable helper functions
      GetRange.mqh
      GetSwingHighLows.mqh
      GetFVGs.mqh
      RiskManagement.mqh
      OrderManagement.mqh
      GetIndicators.mqh
      TextDisplay.mqh
    /Bots        # Example code snippets
      /[Developer Name]  # Individual developer folders
      [EA-Name].mq5    # Main EA files
```

## Code Organization

Each EA should be organized in the following manner:

1. **Metadata & Properties**
   - Copyright information
   - Version
   - Description
   - Strict mode declaration

2. **Includes**
   - Import all necessary helper modules

3. **Enumerations & Structures**
   - Define custom types used in the EA
   - Create state management structures

4. **Global Variables**
   - Declare strategy state and other global instances

5. **Input Parameters**
   - Organized by logical groups with comments
   - Use appropriate default values

6. **Initialization & Deinitialization**
   - Clear setup and cleanup functions

7. **Event Handlers**
   - Timer events
   - Chart events
   - Other triggers

8. **Core Logic Functions**
   - Signal generation
   - Trade execution
   - Position management

9. **Helper Functions**
   - EA-specific utility functions

## Helper Modules

### GetRange.mqh
- Defines `TimeRange` structure
- Functions to calculate and identify time-based ranges (Opening Range, etc.)
- Functions to visualize ranges on the chart

### GetSwingHighLows.mqh
- Defines `SwingPoint` structure
- Functions to identify swing high and low points
- Visualization of swing points on chart

### GetFVGs.mqh
- Defines `FVG` (Fair Value Gap) structure
- Functions to identify bullish and bearish FVGs
- FVG visualization functions

### RiskManagement.mqh
- Functions to calculate position sizing based on risk
- Daily loss/profit tracking
- Account risk management

### OrderManagement.mqh
- Position entry, exit, and modification functions
- Stop loss and take profit management
- Partial close and breakeven functions
- Pip value and lot size calculations

### GetIndicators.mqh
- Technical indicator calculations and conditions
- Trend identification functions

### TextDisplay.mqh
- On-chart information display
- Status updates and debugging information

## EA Core Structure

### 1. State Management
Use a structured approach to store and manage the EA state:

```cpp
struct StrategyState {
   // Market structure
   TimeRange        ranges[];
   FVG              bullishFVGs[];
   FVG              bearishFVGs[];
   SwingPoint       swingHighs[];
   SwingPoint       swingLows[];

   // Position management
   double           entryPrice;
   double           stopLoss;

   // Session management
   double           startDayBalance;
   datetime         lastReset;

   // Constructor with default values
   void StrategyState() {
      // Initialize all fields with default values
   }
};
```

### 2. Initialization Function
```cpp
int OnInit() {
   // Clear chart objects
   // Initialize state
   // Set timer
   // Configure display
   return(INIT_SUCCEEDED);
}
```

### 3. Deinitialization Function
```cpp
void OnDeinit(const int reason) {
   // Clean up resources
   // Remove chart objects
   // Kill timers
}
```

### 4. Timer Event
```cpp
void OnTimer() {
   // Check trading conditions
   // Update market structure
   // Update display
   // Check for entry signals
   // Manage positions
}
```

### 5. Market Structure Analysis
```cpp
void UpdateMarketStructure() {
   // Get swing points
   // Identify ranges
   // Find FVGs
}
```

### 6. Signal Generation
```cpp
TRADE_DIRECTION CheckForEntrySignals() {
   // Apply multi-condition logic to identify trade setups
   return TRADE_DIRECTION; // (LONG, SHORT, NO_DIRECTION)
}
```

### 7. Trade Execution
```cpp
void ExecuteTradeSignal(TRADE_DIRECTION signal) {
   // Validate trading conditions
   // Calculate trade parameters (entry, stop, take profit)
   // Place orders
}
```

### 8. Position Management
```cpp
void ManagePositions() {
   // Move to breakeven if condition met
   // Take partial profits
   // Trail stops
}
```

## Best Practices

### 1. Structure and Organization
- Use structures to group related data
- Implement proper constructors with default values
- Use enumerations for clear state representation

### 2. Risk Management
- Always implement proper risk per trade calculations
- Include daily loss limits and profit targets
- Never hardcode position sizing

### 3. Visualization
- Provide visual feedback on chart
- Display current state and conditions
- Use color coding for positive/negative conditions

### 4. Error Handling
- Always check function return values
- Implement proper error reporting
- Add verbose mode for debugging

### 5. Modularity
- Break complex functions into smaller, reusable ones
- Use helper files for common functionality
- Avoid code duplication

### 6. Comments and Documentation
- Document all functions with clear descriptions
- Comment complex logic
- Add usage examples for helper functions

## Naming Conventions

### Variables
- Use camelCase for variable names
- Use snake_case for function parameters
- Prefix boolean variables with 'is', 'has', etc.

### Functions
- Use PascalCase for public functions
- Prefix private/helper functions with underscore

### Structures and Enumerations
- Use PascalCase for structure and enumeration names
- Use ALL_CAPS for enumeration values

### Input Parameters
- Group related inputs with comments
- Use descriptive names that explain their purpose
- Add appropriate default values

---

By following these guidelines, we ensure our EAs are consistent, maintainable, and robust. This structure promotes code reuse and makes it easier to collaborate on EA development.