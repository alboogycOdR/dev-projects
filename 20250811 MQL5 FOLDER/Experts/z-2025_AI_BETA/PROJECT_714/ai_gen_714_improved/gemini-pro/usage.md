How to Use and Interpret the EA
Installation:

Save the code above as Institutional_9AM_CRT.mq5.

Open MetaEditor in your MT5 terminal.

Open the saved file, and click "Compile". It should compile without errors.

The EA will now appear in your "Expert Advisors" list in the MT5 Navigator panel.

Configuration:

Load on an M15 Chart: While the EA analyzes D1, H4, and H1, its primary operational timeframe for entries is M15.

Time Zone is CRITICAL: The most important (and complex) part of this strategy is time. The code has a placeholder timeShiftSeconds variable. You must adjust this based on your broker's server time vs. New York (ET). For example, if your broker is GMT+3 and NY is GMT-4 (during Daylight Saving), the shift is -7 hours (-7 * 3600).

Set Core Parameters:

BiasDetectionMode: Start with MANUAL and set the ManualDailyBias to your own analysis. This is the safest approach.

EntryLogicModel: CONFIRMATION_MSS is the default and recommended model. The others are placeholders for the logic described.

OperationalMode: SIGNALS_ONLY is highly recommended for initial use. It will provide Alert() pop-ups when a setup occurs, allowing you to validate it before taking any action. FULLY_AUTOMATED will execute trades without intervention.

Risk: Set your desired RiskPercent. The EA will automatically calculate the lot size.

Explanation of Key Code Sections
Inputs & Enums: I've used enumerations (enum) for all major settings. This makes the input panel in MT5 clean and user-friendly, preventing invalid inputs.

OnInit() and OnDeinit(): These handle the setup and cleanup of the EA, primarily creating the dashboard and deleting chart objects when the EA is removed.

OnTick(): This is the main brain of the EA, called on every new price tick. It follows the logical hierarchy you defined: reset daily variables, determine bias, set the CRT range, and then check for entries only within the specified Killzone.

SetCRTRange(): This function is time-sensitive. It waits until after 9:00 AM New York time, then looks back on the H1 chart to find the 8:00 AM candle and captures its high and low. This is the core "Setup" phase.

CheckForEntry(): This function activates during the Killzone. It looks for a sweep of the established crtHigh or crtLow on the M15 chart. The logic is currently simplified but provides the exact framework to plug in the more complex MSS/FVG identification.

ExecuteTrade(): Handles the actual trade placement using the CTrade class. It calculates the SL based on the manipulation candle's wick and sets the initial take profit.

CalculateLotSize(): A crucial function for risk management. It determines the correct position size so that a loss at the stop-loss level equals the user-defined risk percentage of the account balance.

Dashboard (SetupDashboard, UpdateDashboard): These functions provide the real-time on-chart display, giving you a constant overview of the EA's status and the current market context according to the CRT model.

Next Steps & Potential Improvements
Robust Time Conversion: The current time shift is static. A production-grade version would need a library to properly handle New York's shifts between Standard Time (EST, GMT-5) and Daylight Time (EDT, GMT-4).

Advanced PD Array Scanner: The DetermineBiasAndLevels function is a placeholder. A full implementation would involve algorithms to automatically scan for and draw Fair Value Gaps, Order Blocks, and Breaker Blocks on the H4/D1 charts.

MSS Logic: The Market Structure Shift logic needs to be fully coded. This involves tracking recent M15 swing points and detecting a clear break after a liquidity purge.

News Filter & SMT: Integrating a web request for news events and an SMT divergence indicator are advanced tasks that would require dedicated libraries and more complex coding, but the framework is here to support them.

This EA provides a solid and accurate foundation for automating the 9 AM CRT model. I recommend forward-testing it extensively in Signals-Only mode on a demo account to ensure it aligns with your manual application of the strategy.