/*

mql5 job https://www.mql5.com/en/job/234703/discussion?id=1149187

https://grok.com/share/bGVnYWN5_c2365581-3c24-49bf-be30-cb63f1ebbcc9



Below is a rewritten and improved version of your rough requirement specification. I’ve organized the information to make it clearer, more structured, and easier to understand for both you and potential developers.

---

### Improved Requirement Specification

#### Project Overview
I need enhancements to my Expert Advisor (EA) for a trading platform (likely MetaTrader). The project involves two main tasks:  
1. **Optimize the Trendline Drawing Algorithm**: Complete and speed up the current trendline drawing process.  
2. **Enhance the EA with Trading Rules**: Implement specific trading conditions using the Relative Strength Index (RSI), Bollinger Bands (BB), Stochastic Oscillator (Stoch), and trendlines.  

---

#### Specific Requirements

##### A. Trendline Drawing Algorithm
- **Current State**:  
  - I’ve provided an attached file with unfinished source code.  
  - Trendlines are currently drawn based on peaks and bottoms identified by the ZigZag indicator on the M15 (15-minute) timeframe.  
  - Problem: The drawing process is too slow due to the large number of peaks and bottoms.  

- **Objective**:  
  - Optimize the algorithm to ensure it draws trendlines quickly while remaining fully functional.  

- **Conditions for Trendlines**:  
  - Trendlines must be infinite rays extending to the right.  
  - Trendlines must not intersect with the price to the left of their starting point.  
  - Trendlines must be directed towards the current price position:  
    - If directed towards the current price, draw in **blue**.  
    - If not directed towards the current price, draw in **yellow**.  
  - Trendlines are drawn on the M15 timeframe, using ZigZag indicator data from the same M15 timeframe.  

- **Performance Goal**:  
  - The algorithm must handle a high volume of ZigZag peaks and bottoms efficiently, resulting in fast trendline drawing.  

---

##### B. EA Trading Rules
The EA should execute trades only when **all** of the following conditions are met:  
1. **Bollinger Bands (BB)**:  
   - The price must cross a Bollinger Band line (upper or lower).  
2. **Trendlines**:  
   - The price must either cross or touch a trendline.  
3. **Stochastic Oscillator (Stoch)**:  
   - The Stoch value must be in overbought or oversold territory (e.g., above 80 or below 20, depending on settings).  
4. **Relative Strength Index (RSI)**:  
   - The RSI value must be in overbought or oversold territory (e.g., above 70 or below 30, depending on settings).  

---

#### Additional Notes
- **Source Code**:  
  - The current code for drawing trendlines is included in the attached file.  
- **Demonstration Requirement**:  
  - Before assigning the full project, I require a working demo of the optimized trendline drawing algorithm.  
  - This demo is essential to confirm the solution meets my needs and to avoid wasting time and money.  
  - Without a successful demo, I will not proceed with the job assignment.  

---

#### Deliverables
1. **Optimized Trendline Drawing Algorithm**:  
   - A fast, complete solution that meets all specified conditions.  
2. **Updated EA**:  
   - An EA incorporating the trading rules based on RSI, BB, Stoch, and trendlines.  

---

#### Acceptance Criteria
- The trendline drawing algorithm must:  
  - Draw trendlines quickly and accurately per the conditions.  
  - Perform efficiently on the M15 timeframe with ZigZag data.  
- The EA must:  
  - Correctly implement all specified trading rules.  
- A demo of the trendline drawing must be provided and approved before full project assignment.  

---

This revised specification should now be much clearer, with a logical structure that separates tasks, conditions, and expectations. Let me know if you need further adjustments!


*/


#include <Trade/Trade.mqh>
CTrade trade;

// Demo account and expiry settings
 datetime ExpiryDate = D'2025.03.29 11:59:59';  // Set your desired expiry date
 bool AllowDemoTrading = true;  // Set to true to allow trading on demo accounts

input int Depth = 12;
input int Deviation = 5;
input int Backstep = 3;
input int InpBandsPeriod = 20;
input double InpBandsDeviations = 2.0;
input ENUM_APPLIED_PRICE BBAppliedPrice = PRICE_CLOSE;
input int shift_Bar = 0;
input bool isDrawYellowTrendline = true;
input int MaxTroughs = 20;
input double TrendlineThresholdPips = 10;
input double Lots = 0.1;

int ZigZag_Handle, handle_bb, handle_stoch, handle_rsi;
double ZigZag_Buffer[];
datetime Time_Buffer[];
datetime lastUpdate = 0;

struct TrendlineData
{
    string name;
    double slope;
    datetime x1;
    double y1;
};

void OnInit()
{
    // Check if account is real/live and prevent trading
    if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_REAL)
    {
        Print("Trading is not allowed on real/live accounts. This EA is designed for demo accounts only.");
        ExpertRemove();
        return;
    }
    
    // Check if account is demo and trading is allowed
    if(AccountInfoInteger(ACCOUNT_TRADE_MODE) == ACCOUNT_TRADE_MODE_DEMO && !AllowDemoTrading)
    {
        Print("Trading is not allowed on demo accounts. Please set AllowDemoTrading to true if you want to trade on demo.");
        ExpertRemove();
        return;
    }
    
    // Check if EA has expired
    if(TimeCurrent() > ExpiryDate)
    {
        Print("Expert Advisor has expired. Please contact support for a new version.");
        ExpertRemove();
        return;
    }
    else
    {
        Print("Expert Advisor is active. Trading is allowed until  ", TimeToString(ExpiryDate));
    }

    ChartSetInteger(0, CHART_SHIFT, true);
    ChartSetInteger(0, CHART_SHOW_GRID, false);
    ChartSetInteger(0, CHART_SHOW_ASK_LINE, true);
    ChartSetInteger(0, CHART_SHOW_TRADE_HISTORY, false);

    handle_bb = iBands(Symbol(), PERIOD_CURRENT, InpBandsPeriod, shift_Bar, InpBandsDeviations, BBAppliedPrice);
    if(handle_bb == INVALID_HANDLE) return;
    handle_stoch = iStochastic(_Symbol, _Period, 14, 3, 3, MODE_SMA, STO_LOWHIGH);
    if(handle_stoch == INVALID_HANDLE) { Print("Failed to initialize Stoch"); return; }
    handle_rsi = iRSI(_Symbol, _Period, 14, PRICE_CLOSE);
    if(handle_rsi == INVALID_HANDLE) { Print("Failed to initialize RSI"); return; }
    ZigZag_Handle = iCustom(Symbol(), 0, "ZigZag", Depth, Deviation, Backstep);
    if(ZigZag_Handle == INVALID_HANDLE) { Print("Failed to initialize ZigZag"); return; }
    ChartIndicatorAdd(ChartID(), 0, ZigZag_Handle);
}

void DeleteZigZagObjects()
{
    int total = ObjectsTotal(0, -1, -1);
    for(int i = total - 1; i >= 0; i--)
    {
        string objName = ObjectName(0, i);
        if(StringFind(objName, "Support_") == 0 || StringFind(objName, "Resistance_") == 0)
            ObjectDelete(0, objName);
    }
}

void CollectZigZagPoints(bool isHigh, datetime &times[], double &values[], int &count)
{
    count = 0;
    for(int i = 1; i < ArraySize(ZigZag_Buffer) - 1; i++)
    {
        if(ZigZag_Buffer[i] != 0)
        {
            double zigzagValue = ZigZag_Buffer[i];
            datetime zigzagTime = Time_Buffer[i];
            double candleValue = isHigh ? iHigh(Symbol(), 0, i) : iLow(Symbol(), 0, i);
            if(zigzagValue == candleValue)
            {
                
                ArrayResize(times, count + 1);
ArrayResize(values, count + 1);
                times[count] = zigzagTime;
                values[count] = zigzagValue;
                count++;
            }
        }
    }
}

void DrawTrendlines(datetime &times[], double &values[], int count, string prefix, TrendlineData &trendlines[], int &trendlineCount)
{
    int numToUse = MathMin(count, MaxTroughs);
    trendlineCount = 0;
    for(int i = 0; i < numToUse; i++)
    {
        for(int j = i + 1; j < numToUse; j++)
        {
            datetime x1 = times[i], x2 = times[j];
            double y1 = values[i], y2 = values[j];
            if(x1 > x2)
            {
                datetime tempTime = x1; x1 = x2; x2 = tempTime;
                double tempValue = y1; y1 = y2; y2 = tempValue;
            }
            double slope = (y2 - y1) / (double(x2) - double(x1));
            if(IsTrendlineCrossingPriceOnRight(x1, y1, x2, y2))
                continue;
            datetime currentTime = TimeCurrent();
            double trendlineValueAtCurrentTime = y1 + slope * (double(currentTime) - double(x1));
            double currentPrice = SymbolInfoDouble(Symbol(), SYMBOL_BID);
            bool isConverging = MathAbs(currentPrice - trendlineValueAtCurrentTime) < MathAbs(currentPrice - y2);
            color trendlineColor = isConverging ? clrDarkTurquoise : (isDrawYellowTrendline ? clrRed : clrNONE);
            if(trendlineColor == clrNONE)
                continue;
            string trendlineName = prefix + (string)x1 + "_" + (string)x2;
            if(!ObjectCreate(0, trendlineName, OBJ_TREND, 0, x1, y1, x2, y2))
                continue;
            ObjectSetInteger(0, trendlineName, OBJPROP_COLOR, trendlineColor);
            ObjectSetInteger(0, trendlineName, OBJPROP_WIDTH, 1);
            ObjectSetInteger(0, trendlineName, OBJPROP_STYLE, STYLE_DASH);
            ObjectSetInteger(0, trendlineName, OBJPROP_RAY_RIGHT, true);
            ArrayResize(trendlines, trendlineCount + 1);
            trendlines[trendlineCount].name = trendlineName;
            trendlines[trendlineCount].slope = slope;
            trendlines[trendlineCount].x1 = x1;
            trendlines[trendlineCount].y1 = y1;
            trendlineCount++;
        }
    }
}

void OnTick()
{
    if(ZigZag_Handle == INVALID_HANDLE) return;
    datetime currentTime = iTime(Symbol(), 0, 0);
    if(currentTime == lastUpdate) return;
    lastUpdate = currentTime;

    int bars = Bars(Symbol(), 0);
    if(CopyBuffer(ZigZag_Handle, 0, 0, bars, ZigZag_Buffer) <= 0) return;
    if(CopyTime(Symbol(), 0, 0, bars, Time_Buffer) <= 0) return;
    ArraySetAsSeries(ZigZag_Buffer, true);
    ArraySetAsSeries(Time_Buffer, true);

    DeleteZigZagObjects();

    datetime troughTimes[], peakTimes[];
    double troughValues[], peakValues[];
    int troughCount, peakCount;
    CollectZigZagPoints(false, troughTimes, troughValues, troughCount);
    CollectZigZagPoints(true, peakTimes, peakValues, peakCount);

    TrendlineData supportTrendlines[], resistanceTrendlines[];
    int supportCount, resistanceCount;
    DrawTrendlines(troughTimes, troughValues, troughCount, "Support_", supportTrendlines, supportCount);
    DrawTrendlines(peakTimes, peakValues, peakCount, "Resistance_", resistanceTrendlines, resistanceCount);

    double bbLower[1], bbUpper[1];
    if(CopyBuffer(handle_bb, 2, 0, 1, bbLower) <= 0 || CopyBuffer(handle_bb, 1, 0, 1, bbUpper) <= 0) return;
    double stoch[1];
    if(CopyBuffer(handle_stoch, 0, 0, 1, stoch) <= 0) return;
    double rsi[1];
    if(CopyBuffer(handle_rsi, 0, 0, 1, rsi) <= 0) return;
    double low = iLow(Symbol(), 0, 0);
    double high = iHigh(Symbol(), 0, 0);
    double close = iClose(Symbol(), 0, 0);
    double threshold = TrendlineThresholdPips * 10 * Point();

    bool isNearSupport = false;
    for(int k = 0; k < supportCount; k++)
    {
        double trendlineValue = supportTrendlines[k].y1 + supportTrendlines[k].slope * (double(currentTime) - double(supportTrendlines[k].x1));
        if(MathAbs(low - trendlineValue) < threshold)
        {
            isNearSupport = true;
            break;
        }
    }
    if(isNearSupport && close < bbLower[0] && stoch[0] < 20 && rsi[0] < 30)
        trade.Buy(Lots, Symbol(), 0, 0, 0, "Buy signal");

    bool isNearResistance = false;
    for(int k = 0; k < resistanceCount; k++)
    {
        double trendlineValue = resistanceTrendlines[k].y1 + resistanceTrendlines[k].slope * (double(currentTime) - double(resistanceTrendlines[k].x1));
        if(MathAbs(high - trendlineValue) < threshold)
        {
            isNearResistance = true;
            break;
        }
    }
    if(isNearResistance && close > bbUpper[0] && stoch[0] > 80 && rsi[0] > 70)
        trade.Sell(Lots, Symbol(), 0, 0, 0, "Sell signal");
}

bool IsTrendlineCrossingPriceOnRight(datetime x1, double y1, datetime x2, double y2)
{
    double slope = (y2 - y1) / (x2 - x1);
    int startBar = iBarShift(Symbol(), 0, x1);
    int endBar = iBarShift(Symbol(), 0, TimeCurrent());
    for(int i = startBar; i >= endBar; i--)
    {
        datetime candleTime = iTime(Symbol(), 0, i);
        double trendlineValue = y1 + slope * (candleTime - x1);
        double candleLow = iLow(Symbol(), 0, i);
        double candleHigh = iHigh(Symbol(), 0, i);
        if((trendlineValue > candleLow && trendlineValue < candleHigh) ||
           (trendlineValue < candleLow && trendlineValue > candleHigh))
            return true;
    }
    return false;
}