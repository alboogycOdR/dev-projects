# ICT Trading Strategies


Using this guide create a simple straifght forward EA that is simple to read with small functions for each check.
Rules:

1: trade time - 1700 to 19:00
2. store the range of 16:30 to 17:00 - we need the middle
3. start hunting from 17:00 - get swing highs and lows past 17:00 on one minute timeframe
4. Get the first presented fair value gap fvg past 17:31

Buy :
if price is above middle of 16:30 to 17:00  range
price above Moving Average 20 of five minutes
Previous swing low that is past 17:00 has been taken
Price is above the high of the first presented fair value gap
if all this conditions are met: wait for a bearish candle anf enter on the close of it
sl in most recent swing high and rrr for tp is 3


Sell :
if price is below middle of 16:30 to 17:00  range
price below Moving Average 20 of five minutes
Previous swing high that is past 17:00 has been taken
Price is balow the low of the first presented fair value gap
if all this conditions are met: wait for a bullish candle and enter on the close of it
sl in most recent swing low and rrr for tp is 3

make the functions as granular as possible. with so minimal print statements.
make use of addTextOnScreen.
- write as a mql5 expert with simplicity of logic










## Strategy 1: London Open Range Breakout with FVG Confirmation

This strategy targets the volatility of the London session open by identifying a range and trading the breakout with FVG confirmation.

- **Time Component**: London session open (08:00-10:00 GMT)
- **Entry Logic**:
  - Define initial range (first 30 minutes of London) using `GetRanges()`
  - Enter long on breakout of range high with bullish FVG confirmation
  - Enter short on breakout of range low with bearish FVG confirmation
  - Use 13-period SMA as additional filter (price must be above for longs, below for shorts)
- **Macro Analysis**: Identify daily bias using higher timeframe market structure
- **SilverBullet Setup**: Look for Asian session FVG that hasn't been filled prior to London open
- **Stop Loss**: Below/above the most recent swing low/high identified with `GetSwingLows()`/`GetSwingHighs()`
- **Take Profit**: At 1.5R or at opposing FVG
- **Risk Management**: 1% account risk per trade using `CalculateLotSize()`
- **Function Implementation**:
  ```mq5
  // Check for London open range breakout
  void CheckLondonOpenBreakout() {
    // Define London open range (first 30 minutes)
    TimeRange londonRanges[];
    GetRanges("08:00", "08:30", londonRanges, 0, "LondonOpen", true);

    if(londonRanges[0].valid) {
      // Get current SMA value
      double sma = iMA(_Symbol, PERIOD_CURRENT, 13, 0, MODE_SMA, PRICE_CLOSE, 0);

      // Get FVGs for confirmation
      FVG bullFVGs[], bearFVGs[];
      GetBullishFVGs(0, 20, bullFVGs, 10, true, clrGreenYellow);
      GetBearishFVGs(0, 20, bearFVGs, 10, true, clrDeepPink);

      // Get swing points for stop loss placement
      SwingPoint swingLows[];
      GetSwingLows(5, swingLows, PERIOD_CURRENT, 100, false);

      double currentPrice = Close[0];
      // Check for long setup (breakout above range high)
      if(currentPrice > londonRanges[0].high && currentPrice > sma && ArraySize(bullFVGs) > 0 && !bullFVGs[0].isFilled) {
        // Find nearest swing low for stop loss
        double stopLoss = 0;
        for(int i = 0; i < ArraySize(swingLows); i++) {
          if(!swingLows[i].taken) {
            stopLoss = swingLows[i].price;
            break;
          }
        }

        // Calculate position size and take profit
        double tp = CalculateTpPrice(Ask, stopLoss, 1.5);
        double lotSize = CalculateLotSize(AccountInfoDouble(ACCOUNT_BALANCE) * 0.01, Ask, stopLoss);

        // Execute trade (would be implemented in actual EA)
        Print("London Breakout Long Signal: Entry=", Ask, " SL=", stopLoss, " TP=", tp, " Lot=", lotSize);
      }

      // Short setup would be implemented similarly
    }
  }
  ```

## Strategy 2: NY Session Reversal from Asian Range (Venom Strategy)

This strategy looks for reversals during the NY session from extremes established during Asian trading hours, utilizing ICT's Venom strategy concepts.

- **Time Component**: NY session (13:30-15:30 GMT)
- **Entry Logic**:
  - Calculate Asian session range (00:00-08:00 GMT) using `GetRanges()`
  - Enter long if price tests Asian range low during NY session with bullish FVG forming
  - Enter short if price tests Asian range high during NY session with bearish FVG forming
  - Look for 5-period SMA and 13-period SMA crossover in entry direction
- **Venom Setup**:
  - Identify NY session liquidity grab (quick spike beyond range)
  - Wait for 30-second timeframe reaction candle
  - Enter on return to origin of liquidity grab
- **Filters**: Ensure entry is near a major swing high/low
- **Stop Loss**: Beyond the FVG
- **Take Profit**: At midpoint of Asian range
- **Function Implementation**:
  ```mq5
  // Check for NY session venom setup
  void CheckNYVenomSetup() {
    // Define Asian session range
    TimeRange asianRanges[];
    GetRanges("00:00", "08:00", asianRanges, 0, "Asian", true);

    // Check if we're in NY session and have valid Asian range
    if(asianRanges[0].valid && TimeHour(TimeCurrent()) >= 13 && TimeHour(TimeCurrent()) <= 15) {
      // Get SMA values for trend confirmation
      double sma5 = iMA(_Symbol, PERIOD_CURRENT, 5, 0, MODE_SMA, PRICE_CLOSE, 0);
      double sma13 = iMA(_Symbol, PERIOD_CURRENT, 13, 0, MODE_SMA, PRICE_CLOSE, 0);
      double sma5Prev = iMA(_Symbol, PERIOD_CURRENT, 5, 0, MODE_SMA, PRICE_CLOSE, 1);
      double sma13Prev = iMA(_Symbol, PERIOD_CURRENT, 13, 0, MODE_SMA, PRICE_CLOSE, 1);

      // Check for bullish venom setup (price testing Asian low)
      if(Low[0] <= asianRanges[0].low && sma5 > sma13 && sma5Prev <= sma13Prev) {
        // Look for bullish FVG confirmation
        FVG bullFVGs[];
        GetBullishFVGs(0, 10, bullFVGs, 10, true, clrGreenYellow);

        if(ArraySize(bullFVGs) > 0 && !bullFVGs[0].isFilled) {
          // Calculate stop loss below the FVG
          double stopLoss = bullFVGs[0].low - (10 * _Point);

          // Calculate take profit at the midpoint of Asian range
          double takeProfit = asianRanges[0].middle;

          // Calculate position size
          double lotSize = CalculateLotSize(AccountInfoDouble(ACCOUNT_BALANCE) * 0.01, Ask, stopLoss);

          // Execute trade (would be implemented in actual EA)
          Print("NY Venom Long Signal: Entry=", Ask, " SL=", stopLoss, " TP=", takeProfit, " Lot=", lotSize);
        }
      }

      // Bearish setup would be implemented similarly
    }
  }
  ```

## Strategy 3: European Momentum Continuation (30-Second Model)

This strategy captures strong momentum moves during the European session with MA confirmation, incorporating ICT's 30-second model for precision entries.

- **Time Component**: European session (08:00-12:00 GMT)
- **Entry Logic**:
  - Identify trend direction using 20-period SMA and 50-period SMA (trend alignment)
  - Wait for a pullback to create an FVG in trend direction
  - Enter when price returns to test the FVG midpoint
  - Use 30-second timeframe for precision entry timing
- **30-Second Model Implementation**:
  - Wait for momentum candle in trend direction on higher timeframe
  - Drop to 30-second chart and wait for first pullback
  - Enter on break of local high/low with first new 30-second candle
- **Confirmation**: Must have at least one untaken swing point in direction of trade
- **Stop Loss**: Beyond opposing swing high/low
- **Take Profit**: Set at 2:1 R:R or next significant swing level
- **Function Implementation**:
  ```mq5
  // Check for European momentum continuation
  void CheckEuropeanMomentum() {
    // Check if we're in European session
    datetime currentTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);

    if(dt.hour >= 8 && dt.hour < 12) {
      // Get SMA values for trend identification
      double sma20 = iMA(_Symbol, PERIOD_CURRENT, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
      double sma50 = iMA(_Symbol, PERIOD_CURRENT, 50, 0, MODE_SMA, PRICE_CLOSE, 0);

      // Check for bullish trend
      if(sma20 > sma50) {
        // Look for bullish FVG (pullback area)
        FVG bullFVGs[];
        GetBullishFVGs(0, 20, bullFVGs, 10, true, clrGreenYellow);

        // Check for valid FVG and price near midpoint
        if(ArraySize(bullFVGs) > 0 && !bullFVGs[0].isFilled) {
          double currentPrice = Close[0];
          if(MathAbs(currentPrice - bullFVGs[0].midpoint) < (20 * _Point)) {
            // Get swing lows for stop loss placement
            SwingPoint swingLows[];
            GetSwingLows(5, swingLows);

            // Only proceed if we have valid swing points and at least one is untaken
            if(ArraySize(swingLows) > 0) {
              bool hasUntakenPoint = false;
              for(int i = 0; i < ArraySize(swingLows); i++) {
                if(!swingLows[i].taken) {
                  hasUntakenPoint = true;
                  break;
                }
              }

              if(hasUntakenPoint) {
                // Calculate stop loss and position size
                double stopLoss = swingLows[0].price - (5 * _Point);
                double riskPips = MathAbs(Ask - stopLoss) / _Point;
                double takeProfit = Ask + (riskPips * 2 * _Point);
                double lotSize = CalculateLotSize(AccountInfoDouble(ACCOUNT_BALANCE) * 0.01, Ask, stopLoss);

                // Execute trade (would be implemented in actual EA)
                Print("European Momentum Long Signal: Entry=", Ask, " SL=", stopLoss, " TP=", takeProfit, " Lot=", lotSize);
              }
            }
          }
        }
      }

      // Bearish setup would be implemented similarly
    }
  }
  ```

## Strategy 4: Time-Based Session Transitions (MacroSilverBullet)

This strategy focuses on capturing moves at the transitions between major trading sessions, combining ICT's Macro analysis with the SilverBullet technique.

- **Time Component**: Session overlaps (London/NY overlap 13:30-16:00 GMT)
- **Entry Logic**:
  - Identify range of the first hour of overlap using `GetRanges()`
  - Enter in direction of the break with confirmation from FVG
  - Only take trades with sufficient daily range remaining
  - Confirm with 8-period SMA and 21-period SMA alignment (8 above 21 for longs, 8 below 21 for shorts)
- **MacroSilverBullet Implementation**:
  - Identify higher timeframe (H4/D1) imbalances and significant swing points
  - Target entries where SilverBullet setup (FVG) aligns with Macro structure
  - Execute trade during highest liquidity period when both align
- **Filters**:
  - Must be aligned with daily swing structure
  - No trades if daily loss limit is approaching (checked with `CheckMaxDailyLossExceeded()`)
- **Stop Loss**: Previous swing level with buffer
- **Take Profit**: Midpoint between entry and next major swing level
- **Function Implementation**:
  ```mq5
  // Check for session transition setup
  void CheckSessionTransitionSetup() {
    // Check if we're in London/NY overlap
    datetime currentTime = TimeCurrent();
    MqlDateTime dt;
    TimeToStruct(currentTime, dt);

    if(dt.hour >= 13 && dt.hour <= 16) {
      // Define initial range of the overlap session
      TimeRange overlapRanges[];
      GetRanges("13:30", "14:30", overlapRanges, 0, "Overlap", true);

      if(overlapRanges[0].valid) {
        // Get SMA values for trend confirmation
        double sma8 = iMA(_Symbol, PERIOD_CURRENT, 8, 0, MODE_SMA, PRICE_CLOSE, 0);
        double sma21 = iMA(_Symbol, PERIOD_CURRENT, 21, 0, MODE_SMA, PRICE_CLOSE, 0);

        // Check risk management - no trades if daily loss limit exceeded
        double startDayBalance = AccountInfoDouble(ACCOUNT_BALANCE); // This should be stored at day start
        if(CheckMaxDailyLossExceeded(startDayBalance, startDayBalance * 0.02)) {
          Print("Daily loss limit exceeded, no new trades");
          return;
        }

        // Check for bullish setup (breakout above range with SMA alignment)
        if(Close[0] > overlapRanges[0].high && sma8 > sma21) {
          // Get bullish FVGs for confirmation
          FVG bullFVGs[];
          GetBullishFVGs(0, 20, bullFVGs, 10, true, clrGreenYellow);

          // Get macro swing points from higher timeframe
          SwingPoint h4SwingLows[], h4SwingHighs[];
          GetSwingHighs(10, h4SwingHighs, PERIOD_H4, 100, false);
          GetSwingLows(10, h4SwingLows, PERIOD_H4, 100, false);

          // Verify FVG exists and isn't filled yet
          if(ArraySize(bullFVGs) > 0 && !bullFVGs[0].isFilled) {
            // Get current timeframe swing lows for stop loss
            SwingPoint swingLows[];
            GetSwingLows(5, swingLows);

            double stopLoss = 0;
            // Find nearest untaken swing low
            for(int i = 0; i < ArraySize(swingLows); i++) {
              if(!swingLows[i].taken) {
                stopLoss = swingLows[i].price - (15 * _Point);
                break;
              }
            }

            // Find next swing high from higher timeframe for target calculation
            double nextSwingHigh = 0;
            for(int i = 0; i < ArraySize(h4SwingHighs); i++) {
              if(h4SwingHighs[i].price > Ask) {
                nextSwingHigh = h4SwingHighs[i].price;
                break;
              }
            }

            // Calculate midpoint for take profit
            double takeProfit = Ask + (MathAbs(nextSwingHigh - Ask) * 0.5);

            // Calculate position size
            double lotSize = CalculateLotSize(AccountInfoDouble(ACCOUNT_BALANCE) * 0.01, Ask, stopLoss);

            // Execute trade (would be implemented in actual EA)
            Print("Session Transition Long Signal: Entry=", Ask, " SL=", stopLoss, " TP=", takeProfit, " Lot=", lotSize);
          }
        }

        // Bearish setup would be implemented similarly
      }
    }
  }
  ```

## ICT Strategy Components and Implementation Notes

### 1. SMA Usage in ICT Methodology
- 8/21-period SMA: Used to identify trend direction and potential reversals
- 13-period SMA: Key SMAs used by ICT for bias confirmation
- 50-period SMA: Used for overall trend confirmation
- Proper implementation requires checking for SMA alignment on multiple timeframes

### 2. Key ICT Concepts

#### FVG (Fair Value Gap)
- Represents institutional imbalance that creates areas of liquidity
- Implemented via `GetBullishFVGs()` and `GetBearishFVGs()` functions
- Used for both trade entry and target setting

#### SilverBullet Setup
- Precision entry technique targeting untested FVGs
- Strongest when aligned with significant swing points
- Requires exact timing during liquidity windows

#### Venom Strategy
- Specific counter-trend setup targeting stops/liquidity
- Seeks short-term reversals at extreme range levels
- Uses 30-second confirmation for precision entry

#### 30-Second Model
- Precision timing method for entries
- Uses momentum, pullback, and trigger phases
- Implemented by dropping to 30-second timeframe for final entry confirmation

#### Macro Analysis
- Higher timeframe trend and structure identification
- Uses Daily/H4 swing points to determine bias
- Implemented with swing point identification using higher timeframe parameters

### 3. Implementation Guidelines

- All strategies should implement risk management via `CheckMaxDailyLossExceeded()` and `CalculateLotSize()`
- Time windows must be precise and account for broker GMT offset
- SMA combinations should be validated against historical data
- Always move stops to breakeven after 1:1 risk-reward achieved using `MoveSymbolStopLossToBreakeven()`
- Consider using `TakePartialProfit()` at key levels to secure partial gains
