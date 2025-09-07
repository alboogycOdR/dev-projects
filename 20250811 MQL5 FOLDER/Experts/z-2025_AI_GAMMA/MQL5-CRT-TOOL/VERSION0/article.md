Here is the article “Price Action Analysis Toolkit Development (Part 33): Candle Range Theory Tool” converted into Markdown:

# Price Action Analysis Toolkit Development (Part 33): Candle Range Theory Tool

**Published:** 25 July 2025  
**Author:** Christian Benjamin

## Table of Contents

- [Introduction](#introduction)
- [Strategy Overview](#strategy-overview)
- [Code Breakdown](#code-breakdown)
- [Testing and Results](#testing-and-results)
- [Conclusion](#conclusion)

## Introduction

Volatility is the market’s primary language. Before any oscillator turns, before most trend-following filters react, price has already expressed a clear opinion through the simple distance it travels within a single bar.

A sudden range expansion often indicates aggressive participation from large players; a prolonged contraction suggests liquidity is being withdrawn.  
A bar that stays inside its predecessor reveals indecision; a bar that engulfs the previous range shows decisive order-flow. These behaviors are apparent but rarely formalized into a robust, machine-readable process.
image.png
**Candle-Range Theory (CRT)** classifies every completed candle into one of four mutually exclusive categories:

- **Large-Range (LR):** The candle’s range exceeds a multiple of recent ATR.
- **Small-Range (SR):** The candle’s range is below a lower multiple of ATR.
- **Inside Bar (IB):** The candle stays within the high-low boundaries of its predecessor.
- **Outside Bar (OB):** The candle breaches both the prior high and low.

Rather than introduce another opaque indicator, CRT focuses on delivering these concepts through a lean, production-ready toolset for MetaTrader 5.

### Toolkit Components

- **CRangePattern.mqh**: Header-only class for candle classification.
- **CRT Indicator.mq5**: Overlay highlights LR, SR, IB, and OB candles.
- **CRT Expert Advisor.mq5**: Alert engine for closed bars, supports filtering and automatic indicator attachment.

**All components compile without warnings under MetaTrader 5 build 4180 or later.**  
Processing occurs strictly on closed bars, ensuring stable outputs across timeframes and testing modes.

**Objectives:**

- Provide mathematical definitions for LR, SR, IB, and OB.
- Demonstrate integration of CRangePattern class.
- Explain indicator design.
- Show how the Expert Advisor delivers non-repainting signals.

### Advantages of the Candle-Range Theory Toolkit

| Advantage             | Description                                                                      | Practical Impact                                               |
|-----------------------|----------------------------------------------------------------------------------|---------------------------------------------------------------|
| Precise definitions   | LR, SR, IB, and OB calculated with ATR-based and price-relation formulas         | Removes ambiguity; every candle belongs to one category        |
| Non-repainting logic  | Calculations on closed bars only                                                 | Signals stay stable across reloads and live trading            |
| Minimal data footprint| Only ATR_Period + 3 bars used                                                    | Negligible RAM/CPU usage, fast Strategy Tester runs            |
| Buffer-free display   | Visuals drawn with chart objects, not buffers                                    | Avoids buffer limit, easy integration with other indicators    |
| Full customization    | Colors, ATR period, multipliers, etc. are user inputs                            | Adapts to any chart style                                     |
| Modular architecture  | Class, indicator, EA are independent, with defined interfaces                    | Easily embedded or swapped                                    |
| Strict compliance     | #property strict & MetaTrader 5 build compatibility                              | Ensures forward compatibility                                 |
| ATR normalization     | Thresholds adjust to instrument volatility                                       | Ensures portability across asset classes                      |

## Strategy Overview

Candle-Range Theory classifies completed candles:

- **Large-Range (LR):** True range ≥ largeMult × ATR
- **Small-Range (SR):** True range ≤ smallMult × ATR
- **Inside Bar (IB):** High  previous low
- **Outside Bar (OB):** High > previous high **and** Low = largeMult * atrCurrent);
```

### Small-Range Test

```cpp
bool isSmallRange = (trueRange  Low[shift+1]);
```

### Outside Bar Test

```cpp
bool isOutsideBar = (High[shift] > High[shift+1]) && (Low[shift] = largeMult × atr` → isLarge = true
    - Else if `trueRange  prevLow` → isInside = true
    - Else if `High > prevHigh` & `Low = largeMult × ATR  |
| Small-Range   | Yellow         | Yellow Dot               | True range  prev low|
| Outside Bar   | Magenta        | Magenta Dot              | High > prev high, Low  prev low          |
| OB            | Magenta        | Magenta Dot       | High > prev high and Low  The toolkit is intended for educational purposes only. All rights reserved by MetaQuotes Ltd. Do not copy or reprint without permission.

### Further Reading

- [Chart Projector](https://www.mql5.com/en/articles/16014)
- [Analytical Comment](https://www.mql5.com/en/articles/15927)
- [Candlestick Recognition](https://www.mql5.com/en/articles/18789)
- ...and many more in the MQL5 Articles library.

End of document.

[1] https://www.mql5.com/en/articles/18911?utm_source=mql5.com.tg&utm_medium=message&utm_campaign=articles.codes.repost