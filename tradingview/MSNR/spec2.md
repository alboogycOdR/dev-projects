This indicator combines the Malaysian Support & Resistance (SnR) method with a Multi-Timeframe Storyline view.

🔹 Malaysian SnR (A/V levels)

Plots Support & Resistance using candlestick bodies only (close → open).

“A” shape = Resistance (bullish close → bearish open).

“V” shape = Support (bearish close → bullish open).

Supports Fresh/Unfresh logic with wick-touch validation.

🔹 Storyline (W/D/H4/H1 bias lines)

Weekly = Big map / macro bias.

Daily = Medium trend / retracement.

H4 = Intraday bias confirmation.

H1 = Execution bias (entry filter).

Lines extend forward and only update when a new pivot confirms.

🔹 Extra Features

Alignment Rule: option to hide A/V levels when TF biases don’t align (e.g. W=D=H4=H1).

Story Labels: optional text labels describing each TF storyline.

History filter: show storyline for the last X days only, for cleaner charts.

This script is designed for price action traders who want to combine body-based SnR levels with a clear multi-timeframe bias storyline, making it easier to align intraday execution with higher timeframe context.
Sep 26
Release Notes
This indicator combines two key concepts into a single framework:

Malaysian SnR (A/V levels)

Detects resistance (A levels) and support (V levels) from pivot-based body structures.

Levels are drawn as horizontal lines that extend forward in time.

Includes “fresh/unfresh” logic — fresh levels are shown solid, once price interacts they fade/dash.

Optional filters hide SnR when higher-timeframe bias is misaligned.

Storyline (Multi-Timeframe Bias)

Plots bias lines for Weekly, Daily, H4, and H1.

Each storyline is drawn from confirmed swing points (pivot highs/lows).

Shows macro bias (W), medium trend (D), intraday bias (H4), and execution bias (H1).

Lines extend forward, optionally labeled (“Weekly storyline”, “H4 storyline”, etc.).

Can keep only the latest storyline per timeframe, or display historical storylines.

Old storylines automatically prune after X days (user setting).

✅ Validity Filters

To help filter noise and highlight only higher-probability storylines:

Liquidity sweep / wick rejection: storyline is valid only if rejection occurred within the last N bars.

2-TF confirmation: Weekly must agree with H4, or Daily with H1 (optional).

Roadblock spacing: ensures there’s ATR-based space to the next opposing pivot.

Only valid storylines option: shows only filtered storylines.

🎨 Styling

Adjustable colors and opacity for resistance, support, and each timeframe storyline.

Fresh lines = solid, Valid storylines = bright.

Unfresh / invalid lines = faded with optional dashed style.

🔑 Use Cases

Identify key support/resistance zones with freshness logic.

Track multi-timeframe bias at a glance (Weekly = big map, Daily = trend, H4 = intraday, H1 = execution).

Filter out weak signals with liquidity sweep + alignment rules.

Combine with your trading strategy for confluence entries.

image.png