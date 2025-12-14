# Shved Supply and Demand - TradingView Pine Script v6

## Overview
This is a complete conversion of the popular Shved Supply and Demand indicator from MQL5 (MetaTrader 5) to Pine Script v6 for TradingView.

## What This Indicator Does

The Shved Supply and Demand indicator identifies and visualizes key support and resistance zones based on fractal analysis. It:

1. **Detects Fractals**: Uses fast and slow fractal periods to identify swing highs and lows
2. **Creates Zones**: Builds supply (resistance) and demand (support) zones from these fractals
3. **Tracks Strength**: Categorizes zones into five strength levels
4. **Merges Zones**: Intelligently combines overlapping zones
5. **Extends Zones**: Projects zones into the future to show potential price reactions
6. **Provides Alerts**: Notifies when price enters a zone

## Zone Strength Categories

1. **Weak**: Fresh zone from a weak fractal (only fast fractal, not slow)
2. **Untested**: Fresh zone from a strong fractal (both fast and slow)
3. **Verified**: Zone that has been tested 1-3 times and held
4. **Proven**: Zone that has been tested 4+ times and held
5. **Turncoat**: Zone that was broken and became the opposite type

## Key Parameters

### Zone Settings
- **Back Limit**: How many bars to look back (default: 1000)
- **Show Weak/Untested/Broken Zones**: Toggle visibility of different zone types
- **Zone ATR Factor**: Controls zone thickness (default: 0.75)
- **Zone Merge**: Combines overlapping zones (default: true)
- **Zone Extend**: Extends zones into the future (default: true)
- **Fractal Fast Factor**: Period for fast fractals (default: 3.0)
- **Fractal Slow Factor**: Period for slow fractals (default: 6.0)

### Drawing Settings
- **Fill Zone with Color**: Solid fill vs. just borders
- **Zone Border Width**: Line thickness
- **Show Info Labels**: Display zone information labels
- **Support/Resistance Names**: Customize label text

### Colors
Fully customizable colors for:
- Support zones (5 types: weak, untested, verified, proven, turncoat)
- Resistance zones (5 types: weak, untested, verified, proven, turncoat)

## How to Use

### Installation
1. Open TradingView
2. Click on "Pine Editor" at the bottom of the screen
3. Click "New" to create a new script
4. Copy and paste the entire Pine Script code
5. Click "Save" and give it a name
6. Click "Add to Chart"

### Interpretation

**Support Zones (Green shades)**:
- Located below current price
- Price is expected to bounce up from these levels
- Stronger zones (proven/verified) are more reliable

**Resistance Zones (Red/Purple shades)**:
- Located above current price
- Price is expected to bounce down from these levels
- Stronger zones (proven/verified) are more reliable

**Zone Strength**:
- More tests = stronger zone
- Untested zones are fresh but unproven
- Proven zones have bounced price multiple times
- Turncoat zones switched from support to resistance or vice versa

### Trading Applications

1. **Entry Points**: Look for entries when price approaches strong zones
2. **Stop Loss Placement**: Place stops beyond the opposite zone
3. **Take Profit Targets**: Use opposing zones as targets
4. **Breakout Trading**: Trade when price breaks through turncoat zones
5. **Multi-Timeframe Analysis**: Use different timeframes to see major zones

## Conversion Notes

### What's Different from MQL5 Version

**Retained Features**:
- ✅ All core zone detection logic
- ✅ Fractal calculation (fast and slow)
- ✅ Zone strength categorization
- ✅ Zone merging algorithm
- ✅ Zone extension
- ✅ Visual representation with boxes and labels
- ✅ Alert functionality
- ✅ Data window values for nearest zones

**Adapted Features**:
- 📊 Uses Pine Script boxes instead of OBJ_RECTANGLE objects
- 📊 Uses Pine Script labels instead of OBJ_TEXT objects
- 📊 Alerts use Pine Script alert() function
- 📊 Real-time updates on bar close instead of tick-by-tick

**Not Implemented** (MQL5-specific features):
- ❌ History Mode (double-click to see historical zones) - Pine Script limitation
- ❌ Mobile notifications - Use TradingView's built-in alert system instead
- ❌ Multiple timeframe display - Use multiple chart windows
- ❌ Custom prefix for multiple instances - Pine Script handles this differently

### Technical Differences

1. **Array Indexing**: Pine Script uses 0-based forward indexing, while MQL5 uses backward indexing
2. **Drawing Objects**: Pine Script boxes are limited to ~500, adequate for most use cases
3. **Performance**: Pine Script recalculates on every bar, optimized for efficiency
4. **Data Access**: Pine Script's `[]` operator handles historical data differently

## Performance Considerations

- **Max Boxes**: Limited to 500 boxes. If you see zones disappearing, reduce the back limit
- **Calculation Frequency**: Recalculates on confirmed bars and last bar
- **Back Limit**: Higher values = more zones but slower performance
- **Fractal Periods**: Higher values = fewer but stronger zones

## Tips for Best Results

1. **Start with Defaults**: The default settings work well for most markets
2. **Adjust Fractal Factors**: Increase for swing trading, decrease for scalping
3. **Use Multiple Timeframes**: Weekly zones on daily chart shows major levels
4. **Combine with Price Action**: Use zones with candlestick patterns
5. **Filter by Strength**: Hide weak zones in trending markets
6. **Reduce Back Limit on Lower Timeframes**: Prevents cluttering

## Troubleshooting

**Zones not showing**:
- Increase back limit
- Check if zone types are enabled (weak/untested/turncoat)
- Ensure fractal factors aren't too large

**Too many zones**:
- Decrease back limit
- Hide weak zones
- Increase fractal factors

**Zones disappearing**:
- Reduce back limit (500 box limit)
- Disable zone merge to see individual zones

**Performance issues**:
- Reduce back limit
- Increase fractal factors

## Data Window Values

The indicator provides these values in TradingView's data window:
- Nearest Resistance High/Low
- Nearest Support High/Low
- Resistance Strength (0-4)
- Support Strength (0-4)

These can be used in other scripts via `input.source()`.

## Version History

**v6.0** (2024) - Pine Script v6 Conversion
- Complete rewrite for Pine Script v6
- Enhanced performance with optimized algorithms
- Improved visual representation
- Added data window integration

**Original MQL5 Versions**:
- v1.7: Buffers for data window
- v1.6: Optimization and prefix support
- v1.5: Multi-timeframe support
- v1.4-1.2: Various improvements
- v1.0: Initial release by Behzad.mvr

## Credits

- **Original MQL5 Code**: Behzad.mvr@gmail.com
- **Pine Script Conversion**: Converted for TradingView compatibility
- **Concept**: Shved Supply and Demand zones methodology

## License

This indicator is provided as-is for educational and trading purposes. Use at your own risk.

## Support

For issues or questions about the Pine Script version:
1. Check TradingView's Pine Script documentation
2. Review the troubleshooting section above
3. Test with default settings first
4. Ensure you're using Pine Script v6 compatible TradingView

---

**Disclaimer**: This indicator is for educational purposes only. Past performance does not guarantee future results. Always practice proper risk management and never risk more than you can afford to lose.
