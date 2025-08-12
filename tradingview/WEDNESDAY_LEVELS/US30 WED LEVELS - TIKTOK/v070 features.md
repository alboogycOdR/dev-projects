New Optimization Features Added:
1. Level Optimization Settings
Enable Level Filtering: Master switch to turn the optimization on/off
Levels Above Price: Number of levels to show above current ASK price (default: 3)
Levels Below Price: Number of levels to show below current ASK price (default: 3)
2. Smart Filtering Logic
Dynamic Price Tracking: Uses current close price as ASK price approximation
Proximity-Based Sorting: Levels are sorted by distance from current price
Real-time Updates: Filtering updates on every new bar as price moves
Comprehensive Coverage: Works with both Wednesday and Midnight levels
3. How It Works
When enabled, the script calculates the distance of each level from current price
Shows only the closest X levels above and below current price
Automatically hides levels that are too far from current price
Maintains all original functionality when filtering is disabled
4. Benefits
Reduces Chart Noise: Only shows relevant levels near current price
Improves Performance: Fewer lines to render and update
Better Focus: Traders can concentrate on actionable levels
Adaptive: Automatically adjusts as price moves
5. Usage
Set Enable Level Filtering to true to activate
Adjust Levels Above Price and Levels Below Price as needed (1-20 range)
The script will automatically show only the closest levels to current price
Disable the feature to show all levels as before