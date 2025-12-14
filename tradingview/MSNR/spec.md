# Malaysian SNR Levels - Fixed Range

This indicator displays support and resistance levels based on Malaysian SnR methodology, but calculates levels exclusively from a **user-defined time range** instead of a fixed number of bars lookback.

## What is Malaysian SnR?

Malaysian SnR defines Support and Resistance not as areas but as precise levels based on a line chart's peaks and valleys. There are three types of horizontal levels:

### Level Types

**A-Level**: Located at the peak of the line chart, shaped like the letter "A"
**V-Level**: Located at the valley of the line chart, shaped like the letter "V"
**Gap Level**: Located at the Close/Open gap between two candles of the same color

## Fresh vs. Unfresh Levels

What makes Malaysian SnR unique is the **Fresh/Unfresh state** of levels:

- **Fresh Level** (solid line): Has not been tested by a wick yet, or has been crossed by a candle body since the last wick touch
- **Unfresh Level** (dashed line): Has been touched by a wick

Fresh levels are considered more significant as they have a higher probability of causing price reactions.

## Fixed Range Innovation

Unlike the standard Malaysian SNR indicator that uses a bars lookback period, this **Fixed Range version** allows you to:

- Select a specific **Start Time** and **End Time** to define your analysis period
- Calculate levels exclusively from bars within this time range
- Analyze historical periods precisely (e.g., "levels from Q1 2024")
- Study how levels from specific market phases perform
- Visualize the selected time range with a transparent background overlay

This is particularly useful for:
- Analyzing levels from specific market events or sessions
- Studying quarterly or monthly ranges
- Backtesting level significance from defined periods
- Forward-testing levels formed during key accumulation/distribution phases

## Parameters

### TIME RANGE SELECTION
- **Start Time**: Beginning of the time range for level calculation
- **End Time**: End of the time range for level calculation
- **Extend Levels Right**: Extend levels to the right edge of the chart

### LEVEL SETTINGS
- **Display Gap Levels**: Show/hide gap levels
- **Display Opening Gaps**: Show/hide gap visualization boxes
- **Display Fresh Levels Only**: Hide unfresh/tested levels
- **Display Break Count**: Show how many times each level has been broken
- **Evaluate Current Bar**: Use the current bar to evaluate level freshness

### LEVEL DISPLAY
- **Level Regions**: Calculate levels relative to current Price or bar's High/Low
- **Levels Above**: Number of closest levels to display above price/high
- **Levels Below**: Number of closest levels to display below price/low
- **Max Level Breaks**: Hide levels broken more than this number of times

### VISUAL SETTINGS
- **Line Color**: Color of the level lines
- **Line Width**: Thickness of level lines
- **Show Time Zone Background**: Display transparent background for selected range
- **Zone Background Color**: Customize background color and transparency
- **Timeframe**: The timeframe used for calculating SNR levels

## Trading Applications

### Example Strategy:
1. Select a significant time range (e.g., a major accumulation zone)
2. Identify fresh levels from that period
3. Wait for price to approach these levels on a higher timeframe
4. Switch to lower timeframe to confirm price reaction
5. Fresh support + bullish reaction = potential buy signal
6. Fresh resistance + bearish reaction = potential sell signal

### Use Cases:
- **Session Analysis**: Study levels from Asian/European/US sessions
- **Event-Based Levels**: Analyze levels formed during specific news events
- **Quarterly Ranges**: Track levels from previous quarters
- **Accumulation Zones**: Identify key levels from consolidation periods

## Visual Features

- **Solid lines** = Fresh levels (untested or re-validated)
- **Dashed lines** = Unfresh levels (tested by wicks)
- **Numbers on levels** = Break count (how many times broken)
- **Transparent boxes** = Opening gaps between same-colored candles
- **Background shading** = Selected time range visualization

## Notes

- The indicator processes only bars within the selected time range
- Levels are tested for freshness using all available bars (including those outside the range)
- Break count shows how many times the level has been broken by candle bodies
- The background helps visualize which time period was used for level formation

---

**Tip**: Combine this with the standard Malaysian SNR indicator to compare recent levels (bars lookback) with historical levels (fixed range) for comprehensive multi-timeframe analysis.