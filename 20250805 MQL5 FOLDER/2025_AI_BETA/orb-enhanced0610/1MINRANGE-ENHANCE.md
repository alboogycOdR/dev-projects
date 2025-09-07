Here is the requirement in a short technical specification format, designed to be clear and actionable for an AI-assisted IDE.

Technical Spec: Synchronize EA Range Calculation

1. Objective

Refactor the range calculation logic to ensure consistent behavior between live trading and all MQL5 backtesting modes (Every Tick, 1-minute OHLC, and Open Prices Only).

2. Problem Statement

The current implementation calculates the trading range by analyzing every incoming tick (SymbolInfoTick). While this is precise in a live environment, backtesting modes that do not use "every tick" data will produce a different, less accurate range. This inconsistency leads to unreliable test results that do not match live performance.

3. Proposed Solution

Instead of calculating the range incrementally with live ticks, implement a one-time calculation that occurs immediately after the defined range period has concluded. This calculation will use historical 1-minute bar data (MqlRates) for the period. This method is deterministic and yields the same result whether run live or in any backtesting mode.

4. Implementation Steps

Step 1: Remove Live Tick-based Range Calculation

In the OnTick() function, locate and remove the entire code block responsible for calculating the range during the period.

--- Code to Remove from OnTick() ---

// During the open range period: update range high/low using the BID price
   if(now >= g_rangeStartTime && now <= g_rangeEndTime && !g_rangeCalculated)
   {
      MqlTick current_tick;
      if(!SymbolInfoTick(_Symbol, current_tick))
      {
         // Could not get tick, skip this iteration
         return;
      }

      if(g_openRangeHigh == 0.0) // First tick within the range period
      {
         g_openRangeHigh = current_tick.ask; // Start high with Ask
         g_openRangeLow  = current_tick.bid; // Start low with Bid
         g_openPrice     = current_tick.bid;
      }
      else
      {
         // Highest price is the highest Ask
         if(current_tick.ask > g_openRangeHigh)
            g_openRangeHigh = current_tick.ask;
         // Lowest price is the lowest Bid
         if(current_tick.bid < g_openRangeLow)
            g_openRangeLow = current_tick.bid;
      }
      DrawRange();
   }

Step 2: Create New Helper Functions

Add the following two C++ functions to the EA. These functions will encapsulate the new logic for calculating and validating the range.

--- New Function 1: CalculateFinalRange ---```cpp
//+------------------------------------------------------------------+
//| Calculate the range high/low based on M1 bar data. |
//+------------------------------------------------------------------+
bool CalculateFinalRange()
{
// Get the M1 bar data covering the entire range period
MqlRates rates[];
int ratesCopied = CopyRates(_Symbol, PERIOD_M1, g_rangeStartTime, g_rangeEndTime, rates);

if(ratesCopied <= 0)
{
Print("Could not copy M1 rates to determine final range. Error: ", GetLastError());
return false;
}

// Find the highest high and lowest low from the copied rates
double range_high = 0;
double range_low = 0;

for(int i = 0; i < ratesCopied; i++)
{
if(range_high == 0 || rates[i].high > range_high)
{
range_high = rates[i].high;
}
if(range_low == 0 || rates[i].low < range_low)
{
range_low = rates[i].low;
}
}

g_openRangeHigh = range_high;
g_openRangeLow = range_low;

PrintFormat("Final Range Calculated from M1 bars: High=%.5f, Low=%.5f", g_openRangeHigh, g_openRangeLow);
return true;
}

**`--- New Function 2: ValidateFinalRange ---`**
```cpp
//+------------------------------------------------------------------+
//| Validate the final range against user-defined min/max points.    |
//+------------------------------------------------------------------+
void ValidateFinalRange()
{
    double pointVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
    double measuredRangePoints = (g_openRangeHigh - g_openRangeLow) / pointVal;

    // Check if the range is valid
    if(g_openRangeHigh > g_openRangeLow && measuredRangePoints >= MinRangePoints && measuredRangePoints <= MaxRangePoints)
    {
       g_rangeValid = true;
       Print("Measured range (", measuredRangePoints, " points) is valid.");
       Comment("Range size: ", measuredRangePoints, " points - VALID (Min: ", MinRangePoints, ", Max: ", MaxRangePoints, ")");
    }
    else
    {
       g_rangeValid = false;
       Print("Measured range (", measuredRangePoints, " points) is outside the allowed bounds.");
       Comment("Range size: ", measuredRangePoints, " points - INVALID (Min: ", MinRangePoints, ", Max: ", MaxRangePoints, ")");
    }
}
IGNORE_WHEN_COPYING_START
content_copy
download
Use code with caution.
IGNORE_WHEN_COPYING_END
Step 3: Integrate New Logic into OnTick()

In the OnTick() function, modify the block that runs after the range period to call the new helper functions.

--- Location: OnTick() ---
Replace this existing block:

// Once the range period is over, finalize and validate the range
   if(now > g_rangeEndTime && !g_rangeCalculated)
   {
      g_rangeCalculated = true;
      double pointVal = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
      double measuredRangePoints = (g_openRangeHigh - g_openRangeLow) / pointVal;
      
      // Check if the range is valid based on min/max criteria
      if(measuredRangePoints >= MinRangePoints && measuredRangePoints <= MaxRangePoints)
      {
         g_rangeValid = true;
         // ... (print/comment logic)
      }
      else
      {
         g_rangeValid = false;
         // ... (print/comment logic)
      }
   }
IGNORE_WHEN_COPYING_START
content_copy
download
Use code with caution.
C++
IGNORE_WHEN_COPYING_END

With this new block:

// Once the range period is over, calculate and validate the final range
   if(now > g_rangeEndTime && !g_rangeCalculated)
   {
      if(CalculateFinalRange())
      {
         ValidateFinalRange();
         DrawRange(); // Draw the final, definitive range on the chart
      }
      g_rangeCalculated = true; // Mark as calculated to prevent re-running
   }
IGNORE_WHEN_COPYING_START
content_copy
download
Use code with caution.
C++
IGNORE_WHEN_COPYING_END

5. Acceptance Criteria

The OnTick function no longer contains the live, tick-by-tick range calculation logic.

The new functions CalculateFinalRange and ValidateFinalRange are present in the code.

When the EA is run in the backtester, the calculated range (and whether it's "VALID" or "INVALID") is identical when using "Every Tick" mode versus "1 minute OHLC" mode.

Chart objects for the range are drawn only after the range period is complete.