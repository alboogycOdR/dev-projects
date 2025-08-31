https://aistudio.google.com/prompts/1dWxQxAR5YQFk6_LLPf4VmStM49HTh_TV

Of course. It is crucial to have the complete and final specification in a single, clean document. This version formally integrates the "Four Commandments" of your trading logic into the core design, creating a definitive blueprint.

Here is the complete, final Technical Specification for the **Apex Protocol v3.0 - The SMC Engine**.

***

# Technical Specification: Apex Protocol v3.0 - The SMC Engine

**Document Version:** 3.1
**Date:** August 31, 2025
**Author:** Gemini AI & System Architect
**Status:** FINAL

## **1. High-Level System Design & Architecture**

### 1.1 Project Goal
To create a modular, multi-strategy TradingView indicator built on a pure Smart Money Concepts foundation. The system will empower the user to select specific ICT/SMC trading models to be hunted for during pre-defined market sessions (Killzones).

### 1.2 Core Philosophy
The system's architecture is **modular**, separating the **Analysis Engine** from the **Strategy Logic**.

*   **The SMC Engine (The Foundation):** Its sole responsibility is to analyze raw price action and identify a library of fundamental SMC "Points of Interest" (POIs). It does not look for trades itself.
*   **The Strategy Modules (The "Apps"):** These are user-selectable modules containing the specific, step-by-step logic for a named ICT setup. They use the data provided by the SMC Engine to find valid trade entries during their assigned Killzone.

### 1.3 System Architecture Data Flow
```mermaid
graph TD
    A[Market Data <br> (Price, Time, Volume)] --> B(SMC ENGINE <br> Core Analysis);
    B --> C{Labeled SMC POIs <br> (FVGs, OBs, BOS, Sweeps...)};
    C --> D[STRATEGY SELECTOR <br> (User Input)];
    D --> E((London Killzone <br> e.g., 'Core SMC Model'));
    D --> F((New York Killzone <br> e.g., 'ICT Silver Bullet'));
    E --> G{State Machine};
    F --> G;
    G --> H[Final Action <br> (Status: ARMED & Alert)];
```

---

## **2. The SMC Engine: POI Detection Requirements**

The Engine must be coded to detect and continuously track the following SMC Points of Interest.

### 2.1 Market Structure
*   **Break of Structure (`BOS`):** A candle closes decisively above a validated swing high (bullish) or below a validated swing low (bearish) in alignment with the Higher Timeframe trend.
*   **Market Structure Shift (`MSS` / `CHoCH`):** The first `BOS` that occurs against the prevailing trend, signaling a potential reversal. Coded as `Change of Character`.

### 2.2 Liquidity
*   **Session Liquidity:**
    *   `Asian Session High` & `Low`
    *   `London Session High` & `Low`
*   **Structural Liquidity:**
    *   `Previous Day High (PDH)` & `Low (PDL)`
    *   `Previous Week High (PWH)` & `Low (PWL)`
    *   All validated swing highs (Buy-side) and swing lows (Sell-side).

### 2.3 Price Imbalances & Key Zones
*   **Fair Value Gap (`FVG`):** A three-candle pattern creating an imbalance. Must detect on all user-relevant timeframes (e.g., M5, M1, 30s).
*   **Order Block (`OB`):** The last opposing candle before a strong, structure-breaking price move.
*   **Inversion Fair Value Gap (`IFVG`):** A Fair Value Gap that is first disrespected and traded through, then re-offered as a new level of support/resistance.

### 2.4 Correlated Asset Divergence
*   **Smart Money Technique (`SMT`) Divergence:** Requires a secondary data feed (e.g., `TVC:DXY`). The Engine must detect divergences where the primary asset makes a new high/low, but the correlated asset fails to confirm it.

---

## **3. The Strategy Modules (Selectable Setups)**

These modules represent the selectable "apps" in the indicator's settings.

### 3.1 Module A: "The Core SMC Model"
This is the primary, most comprehensive model, following a strict four-step validation sequence.
*   **Event 1: Manipulation Confirmed.** One of the following must occur:
    *   **a) Liquidity Sweep:** Price sweeps one of the key monitored liquidity levels (`Asian H/L`, `London H/L`, `PDH/PDL`).
    *   **b) SMT Divergence:** An SMT Divergence is confirmed between the traded asset and its correlated pair.
*   **Event 2: Structure Break Confirmed.** Following `Event 1`, a clear `MSS` (for reversals) or `BOS` (for continuations) must be printed on the chart.
*   **Event 3: Return to HTF Point of Interest.** After the structure break, price must retrace into a valid **5-Minute FVG or Order Block**.
*   **Event 4: LTF Entry Confirmation.** As price interacts with the 5-Minute POI, the final trigger is the formation of a **1-Minute (or 30s) Inversion FVG (`IFVG`)** that signals a rejection from the level.
*   **Result:** The system becomes `ARMED` only after all four events occur in sequence.

### 3.2 Module B: "ICT Silver Bullet" (Simplified Model)
*   **Primary Condition:** Current time must be within a specific window (e.g., 10:00-11:00 EST).
*   **Event 1:** A Liquidity Sweep of a recent session or swing high/low.
*   **Event 2:** A price displacement that creates a clean Fair Value Gap (`FVG`).
*   **Result:** The system becomes `ARMED` immediately after `Event 2`, with the entry being the FVG. This model bypasses the multi-timeframe confirmation of the Core Model for faster entry.

*(Further modules like "Breaker Block Entry" can be added following this same specification format.)*

---

## **4. State Machine & User Interface**

### 4.1 State Machine Logic
The global State Machine will be simple and clear, driven by the logic of the selected Strategy Module.
1.  **`STANDBY`**: Outside of designated Killzones.
2.  **`HUNTING`**: Inside a Killzone; the system is actively monitoring for `Event 1` of the selected strategy.
3.  **`CONFIRMING`**: The system has completed one or more initial events and is now waiting for the final confirmation events (e.g., waiting for `Event 4` after `Event 3` is complete).
4.  **`ARMED`**: All sequential events of the selected Strategy Module have been confirmed. A single alert is fired, and the trade visuals are plotted on the chart.

### 4.2 UI Design - Indicator Settings
The settings must be organized into logical groups.

*   **Group: General Settings & Risk**
    *   `HTF Timeframe`: Timeframe input (default: "240").
    *   `Account Balance`, `Risk % per Trade`: Float inputs.
    *   `Correlated Asset TickerID`: String input for SMT (default: "TVC:DXY").
    *   Color customizations for all visual elements.

*   **Group: SMC Engine Visuals (Toggles)**
    *   `Show BOS/MSS Markers`: Boolean.
    *   `Show Fair Value Gaps (M5)`: Boolean.
    *   `Show Order Blocks (M5)`: Boolean.
    *   `Show Session Ranges`: Boolean.

*   **Group: Killzone Strategy Selection**
    *   `London Killzone Strategy`: **Dropdown Menu** [Options: `OFF`, `The Core SMC Model`, `ICT Silver Bullet`].
    *   `New York Killzone Strategy`: **Dropdown Menu** [Options: `OFF`, `The Core SMC Model`, `ICT Silver Bullet`].

*   **Group: Low Timeframe Confirmation**
    *   `LTF Timeframe`: **Dropdown Menu** [Options: `1 Minute`, `30 Second`].

### 4.3 UI Design - On-Chart Dashboard
The dashboard must be clean and provide an at-a-glance summary of the system's status.
```
┌───────────────────┬────────────────────────┐
│ Protocol Status   │ HUNTING                │
│ HTF Bias          │ BULLISH                │
├───────────────────┴────────────────────────┤
│ ▼ CORE SMC MODEL CHECKLIST                 │
│ [ ] Event 1: Manipulation Confirmed      │
│ [ ] Event 2: Structure Break Confirmed   │
│ [ ] Event 3: Return to HTF POI           │
│ [ ] Event 4: LTF Entry Confirmation      │
├───────────────────┬────────────────────────┤
│ Last Signal       │ None                   │
└───────────────────┴────────────────────────┘
```
The checklist will update with green checkmarks in real-time as the State Machine progresses through a setup.

## **5. Guidance for the AI Developer**

*   **Modular Functions are Key:** Build the detection logic for each SMC element (BOS, FVG, etc.) as a separate, robust function.
*   **Multi-Timeframe Handling:** The system requires data from multiple timeframes (`HTF`, `M5`, `M1`/`30s`, `Correlated Asset`). Use the `request.security()` function efficiently to manage these data streams without repainting issues.
*   **Stateful Logic:** Use `var` variables to maintain the state of the system and the progress of the active trade setup's checklist.
*   **Single, Definitive Alert:** There must only be **one** `alertcondition()`. It triggers when the state becomes `ARMED`. The alert message should be dynamic, stating which Strategy Module was triggered (e.g., "APEX: London 'Core SMC Model' BUY Signal!").