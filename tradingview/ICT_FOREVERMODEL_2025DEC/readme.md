Forever Model is a comprehensive trading framework that visualizes market structure through Fair Value Gaps (FVGs), Smart Money Technique (SMT) divergences, and order block confirmations. The indicator identifies potential price rotations by tracking internal liquidity zones, correlation breaks between assets, and confirmation signals across multiple timeframes.

Designed for clarity and repeatability, the model presents a structured visual logic that supports manual analysis while maintaining flexibility across different assets and timeframes. All components are non-repainting, ensuring historical accuracy and reliable backtesting.

Description

The model operates through a three-part sequence that forms the visual foundation for identifying potential market rotations:

Fair Value Gaps (FVGs)

FVGs are price imbalances detected on higher timeframes—areas where price moved rapidly between candles, leaving an inefficiency that may be revisited. The indicator identifies both bullish and bearish FVGs, displaying them with color-coded levels that extend until mitigated.

snapshot
: Chart showing FVG detection with colored lines indicating bullish (green) and bearish (red) gaps

Smart Money Technique (SMT)

SMT detects divergence between the current chart asset and a correlated pair. When one asset makes a higher high while the other forms a lower high (or vice versa), it indicates a potential shift in delivery. The indicator draws visual lines connecting these divergence points and can filter SMTs to only display those occurring within FVG ranges.

snapshot
: Chart showing SMT divergence lines between two correlated assets with labels indicating the pair name]

Order Block Confirmations (OB)

When price confirms a signal by crossing a pivot level, an Order Block is created. The confirmation line extends from the pivot point, labeled as "OB+" for bullish signals or "OB-" for bearish signals. The latest OB extends to the current bar, while previous OBs remain fixed at their confirmation points.

snapshot
snapshot
: Chart showing OB confirmation lines with OB+ and OB- labels at confirmation points]

Key Features

Higher Timeframe (HTF) Detection

FVGs are detected on a higher timeframe than the current chart, with automatic HTF selection based on the current timeframe or manual override options. This ensures that internal liquidity zones are identified from the appropriate structural context.


External Range Liquidity (ERL)

Tracks the latest higher timeframe pivot highs and lows, marking external liquidity levels that may be revisited. ERL levels are displayed as horizontal lines with optional labels, providing context for potential continuation targets.

snapshot
: Chart showing ERL lines at recent HTF pivot points

Signal Creation and Confirmation System

The model creates pending signals when FVG levels are mitigated. Signals confirm when price closes beyond a pivot level, creating the OB confirmation line. Stop levels are automatically calculated from the maximum (bearish) or minimum (bullish) price between signal creation and confirmation.

SMT Filtering Options

Display all SMTs or only those within FVG ranges
Require SMT for signal confirmation (optional filter)
Automatic or manual SMT pair selection
Support for both correlated and inverse correlated pairs


Directional Bias Filter

Filter FVG detection to show only bullish bias, bearish bias, or both. This allows analysts to align with higher timeframe structure or focus on unidirectional setups.


Confirmation Line Management

Toggle to extend only the latest confirmation line or all confirmation lines
Transparent label backgrounds with colored text (red for bearish, green for bullish)
Automatic cleanup of old confirmation lines (keeps last 50)
Labels positioned at line end (latest) or middle (older lines)


Position Sizing Calculator

Optional position sizing based on account balance, risk percentage or fixed amount, and instrument-specific contract sizes. Supports prop firm calculations and can display position size, entry, and stop levels in the dashboard.


Information Dashboard

A customizable floating table displays:
Current timeframe and HTF
Remaining time in current bar
Current bias direction
Latest confirmed signal details (type, size, entry, stop)
Pending signal status

The dashboard can be repositioned, resized, and styled to match your preferences.

snapshot

Special Range Creation

When signals confirm, the model can automatically create special range levels from stop prices. These levels persist on the chart as important reference points, even after mitigation, serving as potential reversal zones for future signals.


Label and Visualization Controls

Toggle FVG labels on/off
Toggle confirmation lines on/off
Customizable colors for bullish and bearish FVGs
ERL color customization
SMT line width adjustment


Order Flow Integration (Optional)

The indicator includes optional Open Interest (OI) based special range detection, allowing integration with order flow analysis for enhanced context.



Technical Notes

All components are non-repainting—once formed, they remain on the chart
FVGs cannot be mitigated on their creation bar
Signal-based special ranges persist even after mitigation (important stop levels)
SMT detection supports both HTF and chart timeframe modes
Maximum 50 confirmation lines are maintained for performance

The model is designed to work across all asset classes and timeframes, providing a consistent framework for identifying potential market rotations through the interaction of internal liquidity, correlation breaks, and confirmation signals, this does not constitute as trading advice, past performance is no indication of future performance , this is entirely done for entertainment and educational purposes