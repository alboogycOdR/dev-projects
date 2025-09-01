Here is a complete professional design specification for **"The Apex Protocol Assistant"** indicator for TradingView. This document could be handed directly to a Pine Script developer for coding.

***

## Pine Script Indicator Design: The Apex Protocol Assistant

### **1. Core Concept & Philosophy**

This is a **decision-support tool**, not a fully automated trading bot. Its purpose is to monitor the market for the precise conditions of The Apex Protocol, visualize the entire process on the chart, and alert the user when a high-probability setup is armed. The final execution decision always rests with the trader.

The indicator will operate using a **State Machine** to track the progression of a potential trade setup, from initial session analysis to final execution signal.

### **2. On-Chart Visual Elements**

The indicator will plot the following elements directly onto the user's chart (all colors user-configurable):

*   **Higher Timeframe (HTF) Bias Background:** The chart background color will be subtly tinted Green for a Bullish H4 bias and Red for a Bearish H4 bias (determined by price relation to a 50 EMA on the H4 chart). This provides an instant environmental check.
*   **Key Structural Levels:**
    *   Dotted lines for Previous Day High (PDH) & Previous Day Low (PDL).
    *   Dashed lines for Previous Week High (PWH) & Previous Week Low (PWL).
*   **Session Ranges:**
    *   **Asian Session:** A semi-transparent box drawn around the Asian range high and low. The 50% equilibrium level will be plotted as a line within the box.
    *   **Killzones (London & New York):** The background will be shaded with a distinct color during these hours to indicate "active hunting zones."
*   **Setup Visualization (The "Money Shot"):** When a setup is fully armed, the indicator will draw:
    *   A clean, shaded rectangle over the **Entry Zone** (the identified Fair Value Gap or Order Block).
    *   Clearly labeled horizontal lines for **Entry Price**, **Stop Loss**, and **Target Price (1:2 R:R)**.
    *   An icon (e.g., a green rocket for buy, red target for sell) where the setup was confirmed.

### **3. The State Machine Logic**

The core of the indicator. It ensures a logical, step-by-step validation of every setup.

*   **`State 0: STANDBY`**
    *   **Description:** The default state outside of active Killzones.
    *   **Action:** Plots HTF levels and the completed Asian Range. Awaits the start of a Killzone.

*   **`State 1: HUNTING`**
    *   **Description:** The London or New York Killzone is active.
    *   **Action:** The indicator is now actively searching for a manipulation move. The Dashboard will indicate "AWAITING LIQUIDITY SWEEP."

*   **`State 2: MANIPULATION_DETECTED`**
    *   **Description:** Price has officially swept the Asian High/Low or another key liquidity level.
    *   **Action:** The indicator logs the price high/low of the sweep ("manipulation wick"). The Dashboard updates to "AWAITING CONFIRMATION (CHoCH)."

*   **`State 3: ARMED`**
    *   **Description:** A Change of Character (CHoCH) has been confirmed, validating the manipulation. A high-probability setup is now live.
    *   **Action:**
        1.  Scans the price leg between the manipulation wick and the CHoCH to identify the highest-probability FVG/Order Block.
        2.  Plots the full **Setup Visualization** (Entry/SL/TP) on the chart.
        3.  Updates the Dashboard to "SETUP ARMED."
        4.  **Triggers an Alert.**
        5.  The indicator then resets to `STANDBY` until the next session.

### **4. The UI Dashboard**

A clean, non-intrusive table displayed on the corner of the chart, providing a complete at-a-glance summary.

| Feature               | Value / Status                                    |
| --------------------- | ------------------------------------------------- |
| **Protocol Status**   | `ARMED` (colored Green/Red) / `HUNTING` (Yellow) |
| **HTF Bias (H4)**     | **BULLISH** / **BEARISH**                         |
| **Current Session**   | London Killzone (Countdown: 01:23:45)             |
|                       |                                                   |
| **Trade Setup Checklist** |                                                   |
| ✅ In Killzone          |                                                   |
| ✅ Liquidity Swept      | *(Checkmarks appear in real-time)*               |
| ✅ CHoCH Confirmed      |                                                   |
|                       |                                                   |
| **Last Signal**       | Bullish: EURUSD @ 1.08500                         |
| **Entry / SL / TP**   | 1.08500 / 1.08350 / 1.08800                       |

### **5. Alerts**

Alerts are critical for a semi-automatic system. The indicator will have a single, powerful, and fully configurable alert condition.

*   **Alert Name:** "Apex Protocol Setup Armed"
*   **Trigger:** Fires only when the state machine enters the **`ARMED`** state.
*   **Configurable Message:** The user can customize the alert message using placeholders.
    *   **Default Message:**
        `APEX PROTOCOL: {{ticker}} {{strategy.order.action}} Signal! Entry: {{plot("Entry")}}, SL: {{plot("Stop Loss")}}, TP: {{plot("Target")}}, HTF Bias: {{plot("HTF Bias")}`
    *   **Example Output:**
        `APEX PROTOCOL: EURUSD BUY Signal! Entry: 1.08500, SL: 1.08350, TP: 1.08800, HTF Bias: BULLISH`

This allows for seamless integration with third-party automation tools like 3Commas or for quick manual entry via a mobile notification.

### **6. User Settings (Inputs)**

The indicator will be highly customizable to fit any trader's specific needs.

*   **Session Times:**
    *   `Asia Session Time` (Input for Start/End)
    *   `London Killzone Time`
    *   `New York Killzone Time`
    *   `Timezone Setting`
*   **Technical Parameters:**
    *   `HTF Timeframe` (Default: "H4")
    *   `HTF EMA Length` (Default: 50)
    *   `CHoCH Lookback Period` (For identifying the swing point to break)
*   **Visual & UI:**
    *   Full color configuration for all plots and backgrounds.
    *   Show/Hide toggles for every visual element (e.g., "Show Asian Range", "Show Dashboard").
*   **Risk Management:**
    *   `Risk-to-Reward Ratio` (Default: 2, for 1:2)
    *   `Position Size Calculator`: The user enters `Account Balance` and `Risk % per Trade`, and the dashboard will suggest a position size based on the armed setup's stop loss distance.

