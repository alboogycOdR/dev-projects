Core Strategy: Time-Based Range Breakout
The fundamental goal of this EA is to capitalize on price movements that break out of a trading range established during a specific, user-defined time window at the beginning of the trading day (or a chosen session).


#Core Functionality - Step-by-Step:#
Define Range Time: The user specifies a start time (Range Start Hour/Minute) and an end time (Range End Hour/Minute) using the broker's server time.
Identify Range: During this defined time window, the EA continuously monitors the price action (using the specified Timeframe Range Calculation, typically M1 for precision) and determines the absolute highest high and lowest low price reached within that window. This High-Low pair defines the day's initial range.
Filter Range (Optional): At the Range End Time, before placing orders, the EA checks if the calculated range size (High - Low) meets the user's criteria set in the Range Filter Settings (minimum/maximum size in points and/or percentage of the price). If the range is deemed too small or too large based on these filters, the EA skips trading for that day.
Place Breakout Orders: If the range passes the filters, the EA immediately places two pending orders:
    A Buy Stop order placed Order Buffer Points above the identified Range High.
    A Sell Stop order placed Order Buffer Points below the identified Range Low.
Calculate Order Parameters:
    Lot Size: Calculated based on the chosen Trading Volume mode (Fixed, Managed, Percent Risk, Money Risk). Risk-based modes require a Stop Loss to function correctly.
    Stop Loss (SL): Set according to the Stop Calc Mode (e.g., a factor of the range size, fixed points, percentage of entry price, or placed at the opposite range boundary). Can be turned off (not recommended).
    Take Profit (TP): Optionally set according to the Target Calc Mode (e.g., factor of range, fixed points, percentage, or turned off).
Order Activation & Management:
    When the market price hits either the Buy Stop or Sell Stop, that order is filled, creating an open position. The other pending order is automatically cancelled by the broker/platform (standard pending stop behavior).
    The open position is then managed:
    The initial SL and TP are active.
    If Break-Even (BE Stop Calc Mode) is enabled, the SL will be moved to protect the entry price (plus a buffer) once a specified profit target is hit. This happens only once per trade.
    If Trailing Stop (TSL Calc Mode) is enabled, the SL will trail behind the price (at the specified distance and step) once a trigger profit level is met.
Cleanup and Timing:
    Any untriggered pending orders are automatically deleted at the Delete Orders Hour/Minute.
    If Close Positions is enabled, all open positions managed by this EA (identified by its Magic Number) are closed at the Close Positions Hour/Minute.
Daily Cycle & Repetition: The process resets at the beginning of each new trading day, identifying a new range and potentially placing new orders.
Visuals & Context (Enhanced):
    Draws a rectangle on the chart visually representing the calculated range.
    Plots horizontal lines for the Previous Day High/Low and Previous Week High/Low for market context.
    Displays status information in the chart comment.

##Key Pillars of Robustness/Compatibility##:
Flexibility: Numerous input parameters allow tailoring to different instruments, strategies, risk appetites, and time preferences.
Dynamic Symbol Data: Uses functions to get symbol-specific properties (digits, point size, stops level, etc.) rather than hardcoding, improving compatibility.
Time Control: Explicit time settings for range, order deletion, and position closure provide control over the EA's activity window.
Filtering: Range size filters help avoid trading in potentially unfavorable (too choppy or too volatile) conditions.
Unique Identification: The Magic Number ensures the EA only manages its own trades, crucial when running multiple EAs or instances.
Contextual Lines: Plotting previous key levels aids visual analysis and potential future strategy logic integration.