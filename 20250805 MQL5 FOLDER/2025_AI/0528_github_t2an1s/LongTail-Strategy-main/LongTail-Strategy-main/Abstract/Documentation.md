### Purpose of research
To validate and structure the LongTail strategy

# Documentation 
LongTails is modified version of the Remora strategy, designed to capitalize on trends and last through ranges. Parent versions were based on a 1:1 reward system, but this is a 1:R; where R is greater that 1. For this study our focus is on 1:3.

### Strength and weakness

Like every other MarketCrusher, LongTails thrives in a trending market and dies in a ranging market. This model seems to outlive other models in ranging markets although we’re yet to discover the maximum range it survives.

### Dependencies and Market analysis

- none

### **Scope**

- Study was performed on XAU/USD pair, hence **grid_spread**/**range_spread** = 40*points*
- Potentially Volatility 75 and 75(1s)

### Entry rules

- set trading time(daily session)
    - Start time = 7:30am
    - EndSession = False

### Exit rules

- end of trading day, no new cycle.
    - End time = 5:30pm
    - EndSession = True(default)

### Worrisome events

These events create unforeseen circumstances 

- Slippage
- Spread

### Assumptions
- ***The grid is either progressing or in a range***
---

## Strategy definition
- -

# Strategy Guide

- **Core guides**
    1. *Progression sequence is predefine by a function, initiated on start.*
    2. *Only one position can be open at a time.* 
    3. *Only two pending order can be present at a time.* 
    4. *All buy stops are to be placed 40points(range_spread) above the supposed price. Two consecutive buy stops will not be placed on the same price.* 
    5. *Fatal error error is raised when unforeseen event occurs.*

- **Glossary**
    - What is a progression cycle?
        *All the trades it takes to hit TP once.*
        *Each cycle is independent from predecessors, but references position type and volume only.*
    - Continuation delay:  
        *situation where buy stops are placed higher(fixed distance) than the take profit of a long position*
        *price would hit take profit and not trigger a new position because of our range_spread, leaving us with no open position and two pending orders(tap and reverse response).*
    - Range delay:  
        *situation where buy stops are placed higher(fixed distance) than the stop loss of a short position*
        *Price would be within a range and hit range ceiling but not trigger a buy stop because of our range_spread, therefore there’s no open position but two pending orders.*
    - **These delays ensure that the grid is not fixed buy constantly moving; the grid moves upward in response to a range**

- **Likely events within a progression cycle?**
    - Extended range: *Price might stay within a worrisome range where our stop loss falls for an extended period incurring unnecessary losses* 
    - Tap and reverse: *A pending order might be triggered by spread when a position is still open therefore leaving two active positions. Sometimes the older positions reverses and closes a loss, leaving us with two grudges to deal with a creating chaos in the system.* 
    - Misplaced orders: *An order may be left mis-priced as the grid progresses or ranges, due to slippage(all orders needs to be renewed as grid moves).* 
    - Replacement order: *during range delay a continuation order is to be removed and replaced by a recovery order.* 
    - Carry over: *some market days are slow, those days we don't hit daily target. running progression cycles are held running unto the next day.* 

- **Risk management caution**
    - Ensure progression sequence is accurate and relative to account balance. 🏁
    - Ensure lot sizes are pricked properly from the sequence.
    - Ensure take profit and stop loss is set on all positions.

- **General Caution**
    - ensure no continuation order outside daily session.
    - ensure this is no Forgotten order. *An order may be forgotten after a daily session ends, leading to unintended outcomes.*

---

## Session report logging

report to telegram daily by 11:30pm about;
- all closed positions,
- the total number of progression cycles (accounts for running progressions if any),
- the total hours and sessions traded,
- the percentage profit or loss of the day (accounts opening and closing balance).

