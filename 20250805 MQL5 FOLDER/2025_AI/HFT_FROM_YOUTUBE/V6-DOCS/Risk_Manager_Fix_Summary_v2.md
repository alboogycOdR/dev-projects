# Risk Manager Daily Limit Issue - Fix Summary v2

## Problem Identified

The EA was immediately hitting the daily risk limit upon startup with messages like:
```
GBPUSD RiskCalc DEBUG: SLPips=454813.7, PipSize=0.00010, SLPriceUnits=45.48137, TickSize=0.00001, TickValue=1.00, LotSize=0.01, RiskAmount=45481.37
GBPUSD RiskManager: Daily risk limit would be exceeded. Current: 0.00, Potential: 45481.37, Max: 200.00
```

The stop loss was being calculated as 454,813.7 pips instead of the expected ~30 pips.

## Root Cause Analysis

### The Problem Chain:
1. **PriceToPipRatio Initialization**: At EA startup (especially in backtest), there are no historical deals yet
2. **PriceToPipRatio = 0**: The `CalculatePriceToPipRatioAsync()` function never finds deals to calculate from
3. **CommissionPerPip Calculation**: `CommissionPerPip = -commission / PriceToPipRatio` with PriceToPipRatio=0 causes issues
4. **AverageSpread Calculation**: In `UpdateMarketAndTradeParameters()`: `AverageSpread = MathMax(SpreadMultiplier * _Point, CurrentSpread + CommissionPerPip)`
5. **CalculatedStopLoss**: `CalculatedStopLoss = MathMax(AverageSpread * workingStop, MinStopDistance)` becomes huge due to huge AverageSpread

### The Optimized OnTick Issue:
The optimized OnTick function bypassed `UpdateMarketAndTradeParameters()` and used a simple EMA for AverageSpread:
```mql5
AverageSpread = (AverageSpread * 0.9) + ((Ask - Bid) * 0.1);
```

But `CalculatedStopLoss` was never updated in OnTick, so it remained at the huge value calculated during initialization.

## Fixes Applied

### 1. Risk Manager Calculation Fix (Already Applied)
- Fixed `CalculateTradeRiskAmount()` to properly handle pip-to-price conversion
- Removed double conversion in `IsTradeAllowed()` and `RegisterTradeRisk()`

### 2. OnTick CalculatedStopLoss Update (New Fix)
Added proper `CalculatedStopLoss` calculation in the optimized OnTick function:
```mql5
// Ensure CalculatedStopLoss is updated with current AverageSpread
if(CalculatedStopLoss <= 0) {
   CalculatedStopLoss = MathMax(AverageSpread * workingStop, MinStopDistance);
}
```

### 3. Debug Logging Added
Added debug logging to track the actual values:
- `UpdateMarketAndTradeParameters()` now logs AverageSpread, workingStop, CalculatedStopLoss
- `OnTick()` now logs CalculatedStopLoss, pipSize, stopLossPips for first few calculations

### 4. Pip Conversion Fix
Improved the pip conversion in OnTick to be more explicit:
```mql5
double pipSize = (_Digits == 3 || _Digits == 5) ? _Point * 10 : _Point;
double stopLossPips = CalculatedStopLoss / pipSize;
```

## Expected Results

With these fixes:
- **CalculatedStopLoss**: Should be around 0.0045 price units for GBPUSD (AverageSpread ~0.00015 * workingStop 30)
- **stopLossPips**: Should be around 45 pips (0.0045 / 0.0001)
- **Risk Amount**: Should be around 4.5 USD for 0.01 lot (45 pips * 0.01 lot * $1 per pip)
- **Daily Risk Limit**: 200 USD should easily accommodate multiple trades

## Testing Recommendations

1. **Monitor Debug Logs**: Check that the new debug logs show reasonable values
2. **Verify Risk Calculations**: Ensure risk amounts are in the expected range (single digits for 0.01 lots)
3. **Check Trade Execution**: Verify that trades are now being placed instead of being blocked by risk limits

## Long-term Improvements

1. **PriceToPipRatio Fallback**: Implement a fallback calculation for PriceToPipRatio when no historical data is available
2. **CommissionPerPip Input**: Consider making CommissionPerPip an input parameter instead of calculating it dynamically
3. **AverageSpread Validation**: Add validation to prevent AverageSpread from becoming unreasonably large 