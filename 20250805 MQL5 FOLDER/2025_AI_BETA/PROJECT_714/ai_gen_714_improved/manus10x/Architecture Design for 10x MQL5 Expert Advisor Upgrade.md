# Architecture Design for 10x MQL5 Expert Advisor Upgrade

This document outlines the architectural design for integrating the "10x" enhancements into the existing `Institutional_9AM_CRT_v3.0.mq5` Expert Advisor. The design prioritizes modularity and scalability within the current procedural structure, avoiding a full Object-Oriented Programming (OOP) refactoring as per user request.

## Core Principles

1.  **Modularity:** New functionalities will be encapsulated into logical blocks (functions or groups of related functions) to minimize interdependencies and facilitate future modifications.
2.  **Data Flow:** Clear definition of how data flows between different modules, especially for UI updates, filter application, and trade management decisions.
3.  **Event-Driven UI:** Leverage `OnChartEvent` for all interactive UI elements to ensure responsiveness and efficient resource usage.
4.  **External Communication:** Establish a dedicated module for communication with external AI/ML services (e.g., Python via ZeroMQ).
5.  **Performance:** Ensure that new features do not significantly degrade the EA's performance, especially within the `OnTick` function.

## High-Level Architecture Overview

The EA will retain its single `.mq5` file structure. The enhancements will be integrated by:

*   **Expanding Existing Functions:** Modifying existing functions (e.g., `OnTick`, `CreateDashboard`, `UpdateDashboard`, `ManageOpenPositions`) to incorporate new logic.
*   **Adding New Helper Functions:** Introducing new functions for specific tasks (e.g., advanced filter calculations, multi-TP logic, UI element handling).
*   **Introducing Global Variables:** Using global variables to manage the state of new features and pass data between functions.
*   **Utilizing MQL5 Standard Library:** Heavily relying on `ChartObjects` and `Trade` classes for UI and trade operations.

```mermaid
graph TD
    A[OnTick Function] --> B{New Bar / Tick Event}
    B --> C[Reset Daily Variables (if new day)]
    C --> D[AnalyzeHigherTimeframes (Bias, DOL, KL)]
    D --> E[SetCRTRange (Timed Range)]
    E --> F{Is within Killzone & Trade Conditions Met?}
    F -- Yes --> G[Apply Advanced Contextual Filters]
    G --> H[CheckForEntry (MSS State Machine)]
    H -- Entry Signal --> I[ExecuteTrade (with Dynamic Lot Sizing)]
    I --> J[ManageOpenPositions (Breakeven, Trailing Stop, Multi-TP)]
    J --> K[UpdateDashboard (UI & Performance)]
    K --> L[Handle OnChartEvent (UI Interactions)]

    subgraph UI & Interactivity
        L --> M[Interactive Dashboard Controls]
        M --> N[Visual Feedback & Chart Objects]
    end

    subgraph Intelligence Layer
        G --> O[Confluence Scoring Engine]
        O --> P[External AI/ML Communication (ZeroMQ)]
        P --> Q[Market Regime Detection]
    end

    subgraph Trade & Risk Management
        I --> R[Multi-Tiered Take Profit]
        J --> S[Advanced Trailing Stops]
        J --> T[Time-Based Exits]
        I --> U[Dynamic Risk Adjustment]
    end

    subgraph Core Logic (Existing)
        D
        E
        H
        I
    end

    subgraph New Modules
        M
        N
        O
        P
        Q
        R
        S
        T
        U
    end

    style A fill:#f9f,stroke:#333,stroke-width:2px
    style B fill:#bbf,stroke:#333,stroke-width:2px
    style C fill:#bbf,stroke:#333,stroke-width:2px
    style D fill:#bbf,stroke:#333,stroke-width:2px
    style E fill:#bbf,stroke:#333,stroke-width:2px
    style F fill:#bbf,stroke:#333,stroke-width:2px
    style G fill:#bbf,stroke:#333,stroke-width:2px
    style H fill:#bbf,stroke:#333,stroke-width:2px
    style I fill:#bbf,stroke:#333,stroke-width:2px
    style J fill:#bbf,stroke:#333,stroke-width:2px
    style K fill:#bbf,stroke:#333,stroke-width:2px
    style L fill:#bbf,stroke:#333,stroke-width:2px
    style M fill:#ccf,stroke:#333,stroke-width:2px
    style N fill:#ccf,stroke:#333,stroke-width:2px
    style O fill:#ccf,stroke:#333,stroke-width:2px
    style P fill:#ccf,stroke:#333,stroke-width:2px
    style Q fill:#ccf,stroke:#333,stroke-width:2px
    style R fill:#ccf,stroke:#333,stroke-width:2px
    style S fill:#ccf,stroke:#333,stroke-width:2px
    style T fill:#ccf,stroke:#333,stroke-width:2px
    style U fill:#ccf,stroke:#333,stroke-width:2px
```

## Detailed Module Design

### 1. UI/UX & Interactivity Module

*   **Dashboard Management:**
    *   `CreateDashboard()`: Will be significantly expanded to create various `OBJ_BUTTON`, `OBJ_EDIT`, `OBJ_CHECK`, `OBJ_LABEL` objects. These will be organized into logical panels or simulated tabs using visibility toggles.
    *   `UpdateDashboard()`: Will update the text and visual properties of all UI elements based on the EA's internal state.
    *   `OnChartEvent()`: This crucial function will be the central handler for all user interactions with the on-chart GUI. It will detect clicks on buttons, changes in input fields, etc., and trigger corresponding EA logic.
*   **Visual Feedback:**
    *   New helper functions (e.g., `DrawRectangle`, `DrawArrow`) will be created to visualize HTF Key Levels, DOL targets, and trade entry points directly on the chart.
    *   Existing `DrawRangeLines()` will be enhanced.

### 2. Intelligence Layer Module

*   **Confluence Scoring Engine:**
    *   A new function, `CalculateConfluenceScore()`, will be introduced. It will take into account various factors (Daily Bias alignment, HTF KL proximity, SMT Divergence, News Impact) and return a weighted score.
    *   Input parameters will be added to allow users to configure the weight of each confluence factor and the minimum score threshold for a valid trade.
*   **External AI/ML Communication:**
    *   A dedicated set of functions (e.g., `SendMarketDataToAI()`, `ReceiveAISignal()`) will be developed. These functions will utilize the `WebRequest()` function (or potentially a custom DLL if ZeroMQ is implemented directly in MQL5, though `WebRequest` is simpler for initial integration with an external server).
    *   The external Python script (running on the user's local machine or a server) will act as the ZeroMQ client/server, communicating with the DeepSeek API and processing data.
    *   The EA will send relevant market data (e.g., current price, indicator values, CRT levels) to the external script and receive a probabilistic entry confirmation or market regime classification.
*   **Market Regime Detection:**
    *   This can be integrated with the external AI/ML module, where the AI provides the market regime classification.
    *   Alternatively, simpler rule-based detection (e.g., based on ATR for volatility, moving average slopes for trend) can be implemented directly in MQL5 if external AI is not used for this specific purpose.

### 3. Trade & Risk Management Module

*   **Position Sizing:** The existing `CalculateLotSize()` will be enhanced to consider dynamic risk adjustments based on performance.
*   **Multi-Tiered Take Profit:**
    *   `ExecuteTrade()` will be modified to set multiple TP levels if configured.
    *   `ManageOpenPositions()` will be updated to handle partial closes at each TP level.
*   **Advanced Trailing Stops:**
    *   `ManageOpenPositions()` will include logic for ATR-based or Parabolic SAR-based trailing stops. New helper functions (e.g., `CalculateATRTrailingStop()`, `CalculateParabolicSAR()`) will be added.
*   **Time-Based Exits:**
    *   `ManageOpenPositions()` will check the duration of open trades and close them if they exceed a predefined time limit without reaching TP.
*   **Dynamic Risk Adjustment:**
    *   A new function, `AdjustRiskBasedOnPerformance()`, will be called periodically (e.g., daily reset). It will track recent trade outcomes and modify the `RiskPercent` input parameter (or an internal variable) based on a predefined logic (e.g., reduce risk after X consecutive losses).

### 4. Logging, Error Handling & Performance Optimization

*   **Enhanced Logging:** Implement a more detailed logging system using `Print()` and `Comment()` functions, possibly with different log levels (e.g., INFO, WARNING, ERROR) to aid debugging and monitoring.
*   **Robust Error Handling:** Add more checks for function return values (e.g., `OrderSend`, `PositionModify`) and handle potential errors gracefully.
*   **Performance Review:** Review all loops and calculations, especially in `OnTick`, to ensure they are optimized. Minimize redundant calculations and object creations.

## Data Flow Considerations

*   **Global Variables:** Key state variables (e.g., `determinedBias`, `dol_target_price`, `htf_kl_high`, `htf_kl_low`, `crtHigh`, `crtLow`, `bullish_state`, `bearish_state`, `m15_fvg_high`, `m15_fvg_low`) will continue to be global for easy access across functions.
*   **UI Data:** UI elements will read directly from these global state variables and update their display. User input from UI elements will directly modify relevant global input parameters or state variables.
*   **AI Data:** A structured `struct` or `array` will be used to package market data for sending to the external AI. The received AI signal will update a global variable that the `CheckForEntry` or `CalculateConfluenceScore` functions will then use.

## Development Approach

1.  **Phase 1: UI/UX Infrastructure:** Focus on building the interactive dashboard framework and basic controls, ensuring `OnChartEvent` is correctly handling interactions.
2.  **Phase 2: Integrate Advanced Filters & Confluence:** Implement the `CalculateConfluenceScore()` and integrate the re-introduced filters.
3.  **Phase 3: External AI Communication:** Set up the `WebRequest` (or DLL) based communication for AI integration.
4.  **Phase 4: Dynamic Trade Management:** Implement multi-TP, advanced trailing stops, and time-based exits.
5.  **Phase 5: Performance & Robustness:** Refine logging, error handling, and optimize code.

This architectural design provides a clear roadmap for integrating the desired "10x" enhancements into the existing EA, maintaining its structure while significantly boosting its capabilities and user experience.

