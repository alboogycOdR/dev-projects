//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+
#include <Trade\Trade.mqh>

//--- Inputs for Trading Strategy
input double lotSize = 0.1;                  // Lot size for trades
input int retestPips = 10;                   // Proximity in pips for retest detection
input int maxBarsForRetest = 10;             // Max bars to wait for a retest
input bool useVolumeConfirmation = true;     // Use volume confirmation for breakouts
input double volumeMultiplier = 1.5;         // Volume must be this times the average volume
input int volumePeriod = 20;                 // Period for average volume calculation
input bool useCandlestickConfirmation = true;// Use candlestick patterns for confirmation
input bool useEngulfingPattern = true;       // Use engulfing patterns for retest confirmation
input bool singlePosition = true;            // Allow only one open position at a time

//--- Inputs for Zone Calculation (from Shved Supply and Demand)
input ENUM_TIMEFRAMES _Timeframe_ = PERIOD_CURRENT; // Timeframe for zone calculation
ENUM_TIMEFRAMES Timeframe=_Timeframe_;
input int BackLimit = 1000;                       // Back Limit for zone calculation
input bool zone_show_weak = false;                // Show Weak Zones
input bool zone_show_untested = true;             // Show Untested Zones
input bool zone_show_turncoat = true;             // Show Broken Zones
input double zone_fuzzfactor = 0.75;              // Zone ATR Factor
input bool zone_merge = true;                     // Zone Merge
input bool zone_extend = true;                    // Zone Extend
input double fractal_fast_factor = 3.0;           // Fractal Fast Factor
input double fractal_slow_factor = 6.0;           // Fractal Slow Factor

//--- Global Variables
double resistanceLevels[];
double supportLevels[];
struct BrokenLevel
  {
   double            price;
   bool              isResistance;
   int               breakBarIndex;
  };
BrokenLevel brokenLevels[];
CTrade trade;
int handleVolume;
int handleATR;


input bool drawZones = true;                // Draw zones on chart
input color supportColor = clrLightGreen;   // Color for support zones
input color resistanceColor = clrLightCoral;// Color for resistance zones
input bool zoneSolid = true;                // Fill zones with color
input int zoneLineWidth = 1;
input ENUM_LINE_STYLE zoneStyle = STYLE_SOLID;




//--- Zone-related Variables
double FastDnPts[], FastUpPts[];
double SlowDnPts[], SlowUpPts[];
double zone_hi[1000], zone_lo[1000];
int zone_start[1000], zone_hits[1000], zone_type[1000], zone_strength[1000], zone_count = 0;
bool zone_turn[1000];
#define ZONE_SUPPORT 1
#define ZONE_RESIST  2
#define ZONE_WEAK      0
#define ZONE_TURNCOAT  1
#define ZONE_UNTESTED  2
#define ZONE_VERIFIED  3
#define ZONE_PROVEN    4
#define UP_POINT 1
#define DN_POINT -1
void DeleteZoneObjects()
  {
   string prefix = "EA_Zone_";
   for(int i = ObjectsTotal(0, 0, -1) - 1; i >= 0; i--)
     {
      string name = ObjectName(0, i, 0, -1);
      if(StringFind(name, prefix) == 0)
        {
         ObjectDelete(0, name);
        }
     }
  }
//+------------------------------------------------------------------+
//| Expert Initialization Function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   if(Timeframe == PERIOD_CURRENT)
      Timeframe = Period();
   handleATR = iATR(NULL, Timeframe, 7);
   if(handleATR == INVALID_HANDLE)
     {
      Print("Failed to create ATR handle");
      return INIT_FAILED;
     }
   if(useVolumeConfirmation)
     {
      handleVolume = iVolumes(_Symbol, Period(), VOLUME_TICK);
      if(handleVolume == INVALID_HANDLE)
        {
         Print("Failed to create volume handle");
         return INIT_FAILED;
        }
     }
   ArraySetAsSeries(FastDnPts, true);
   ArraySetAsSeries(FastUpPts, true);
   ArraySetAsSeries(SlowDnPts, true);
   ArraySetAsSeries(SlowUpPts, true);
   ArrayResize(FastDnPts, BackLimit + 1);
   ArrayResize(FastUpPts, BackLimit + 1);
   ArrayResize(SlowDnPts, BackLimit + 1);
   ArrayResize(SlowUpPts, BackLimit + 1);
   return INIT_SUCCEEDED;
  }

//+------------------------------------------------------------------+
//| Expert Deinitialization Function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   if(handleATR != INVALID_HANDLE)
      IndicatorRelease(handleATR);
   if(useVolumeConfirmation && handleVolume != INVALID_HANDLE)
      IndicatorRelease(handleVolume);
  }

//+------------------------------------------------------------------+
//| Expert Tick Function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   static datetime lastBarTime = 0;
   datetime currentBarTime = iTime(_Symbol, Timeframe, 0);

   CalculateFractals();
   FindZones();

   if(currentBarTime != lastBarTime)
     {
      lastBarTime = currentBarTime;

      UpdateSupportResistanceLevels();
      CheckBreaksAndRetests();
     }
  }

//+------------------------------------------------------------------+
//| Calculate Fast and Slow Fractals                                 |
//+------------------------------------------------------------------+
void CalculateFractals()
  {
   int limit = MathMin(Bars(_Symbol, Timeframe) - 1, BackLimit);
   int P1 = (int)(Timeframe * fractal_fast_factor);
   int P2 = (int)(Timeframe * fractal_slow_factor);
   double High[], Low[];
   ArraySetAsSeries(High, true);
   ArraySetAsSeries(Low, true);
   CopyHigh(_Symbol, Timeframe, 0, limit + P2 + 1, High);
   CopyLow(_Symbol, Timeframe, 0, limit + P2 + 1, Low);

   for(int shift = limit; shift > P2; shift--)
     {
      // Fast Fractals
      if(Fractal(UP_POINT, P1, shift, High, Low))
         FastUpPts[shift] = High[shift];
      else
         FastUpPts[shift] = 0.0;
      if(Fractal(DN_POINT, P1, shift, High, Low))
         FastDnPts[shift] = Low[shift];
      else
         FastDnPts[shift] = 0.0;
      // Slow Fractals
      if(Fractal(UP_POINT, P2, shift, High, Low))
         SlowUpPts[shift] = High[shift];
      else
         SlowUpPts[shift] = 0.0;
      if(Fractal(DN_POINT, P2, shift, High, Low))
         SlowDnPts[shift] = Low[shift];
      else
         SlowDnPts[shift] = 0.0;
     }
  }

//+------------------------------------------------------------------+
//| Fractal Detection Function                                       |
//+------------------------------------------------------------------+
bool Fractal(int mode, int period, int shift, double &High[], double &Low[])
  {
   if(shift < period || shift >= ArraySize(High) - period)
      return false;
   for(int i = 1; i <= period; i++)
     {
      if(mode == UP_POINT)
        {
         if(High[shift - i] >= High[shift] || High[shift + i] > High[shift])
            return false;
        }
      else
         if(mode == DN_POINT)
           {
            if(Low[shift - i] <= Low[shift] || Low[shift + i] < Low[shift])
               return false;
           }
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Find Supply and Demand Zones                                     |
//+------------------------------------------------------------------+
void FindZones()
  {
   zone_count = 0;
   int limit = MathMin(Bars(_Symbol, Timeframe) - 1, BackLimit);
   double High[], Low[], ATR[];
   ArraySetAsSeries(High, true);
   ArraySetAsSeries(Low, true);
   ArraySetAsSeries(ATR, true);
   CopyHigh(_Symbol, Timeframe, 0, limit + 1, High);
   CopyLow(_Symbol, Timeframe, 0, limit + 1, Low);
   CopyBuffer(handleATR, 0, 0, limit + 1, ATR);

   for(int i = limit; i > 0; i--)
     {
      if(FastUpPts[i] > 0 || SlowUpPts[i] > 0)    // Resistance Zone
        {
         double hi = MathMax(FastUpPts[i], SlowUpPts[i]);
         double lo = hi - ATR[i] * zone_fuzzfactor;
         int strength = (SlowUpPts[i] > 0) ? ZONE_VERIFIED : ZONE_UNTESTED;
         AddZone(ZONE_RESIST, lo, hi, i, strength);
        }
      if(FastDnPts[i] > 0 || SlowDnPts[i] > 0)    // Support Zone
        {
         double lo = MathMin(FastDnPts[i], SlowDnPts[i]);
         double hi = lo + ATR[i] * zone_fuzzfactor;
         int strength = (SlowDnPts[i] > 0) ? ZONE_VERIFIED : ZONE_UNTESTED;
         AddZone(ZONE_SUPPORT, lo, hi, i, strength);
        }
     }
   if(zone_merge)
      MergeZones();
  }

//+------------------------------------------------------------------+
//| Add a Zone to the Array                                          |
//+------------------------------------------------------------------+
void AddZone(int type, double lo, double hi, int start, int strength)
  {
   if(zone_count >= 1000)
      return;
   zone_type[zone_count] = type;
   zone_lo[zone_count] = NormalizeDouble(lo, _Digits);
   zone_hi[zone_count] = NormalizeDouble(hi, _Digits);
   zone_start[zone_count] = start;
   zone_strength[zone_count] = strength;
   zone_hits[zone_count] = 0;
   zone_turn[zone_count] = false;
   zone_count++;
  }

//+------------------------------------------------------------------+
//| Merge Overlapping Zones                                          |
//+------------------------------------------------------------------+
void MergeZones()
  {
   for(int i = zone_count - 1; i >= 0; i--)
     {
      for(int j = i - 1; j >= 0; j--)
        {
         if(zone_type[i] == zone_type[j] &&
            ((zone_lo[i] <= zone_hi[j] && zone_hi[i] >= zone_lo[j]) ||
             (zone_lo[j] <= zone_hi[i] && zone_hi[j] >= zone_lo[i])))
           {
            zone_lo[i] = MathMin(zone_lo[i], zone_lo[j]);
            zone_hi[i] = MathMax(zone_hi[i], zone_hi[j]);
            zone_strength[i] = MathMax(zone_strength[i], zone_strength[j]);
            for(int k = j; k < zone_count - 1; k++)
              {
               zone_lo[k] = zone_lo[k + 1];
               zone_hi[k] = zone_hi[k + 1];
               zone_type[k] = zone_type[k + 1];
               zone_strength[k] = zone_strength[k + 1];
               zone_start[k] = zone_start[k + 1];
              }
            zone_count--;
            i--;
            break;
           }
        }
     }
  }

//+------------------------------------------------------------------+
//| Update Support and Resistance Levels                             |
//+------------------------------------------------------------------+
void UpdateSupportResistanceLevels()
  {
//ArrayFree(supportLevels);
//ArrayFree(resistanceLevels);
//int supportCount = 0, resistanceCount = 0;
//for (int i = 0; i < zone_count; i++) {
//   if (zone_strength[i] == ZONE_WEAK && !zone_show_weak) continue;
//   if (zone_strength[i] == ZONE_UNTESTED && !zone_show_untested) continue;
//   if (zone_strength[i] == ZONE_TURNCOAT && !zone_show_turncoat) continue;
//   double level = NormalizeDouble((zone_hi[i] + zone_lo[i]) / 2, _Digits);
//   if (zone_type[i] == ZONE_SUPPORT) {
//      ArrayResize(supportLevels, supportCount + 1);
//      supportLevels[supportCount++] = level;
//   } else if (zone_type[i] == ZONE_RESIST) {
//      ArrayResize(resistanceLevels, resistanceCount + 1);
//      resistanceLevels[resistanceCount++] = level;
//   }
//}
//ArraySort(supportLevels);
//ArraySort(resistanceLevels);

//updated
   ArrayFree(supportLevels);
   ArrayFree(resistanceLevels);
   int supportCount = 0, resistanceCount = 0;

// Delete existing zone objects if drawing is enabled
   if(drawZones)
      DeleteZoneObjects();

// Loop through all zones and filter them
   for(int i = 0; i < zone_count; i++)
     {
      // Skip zones based on user settings
      if(zone_strength[i] == ZONE_WEAK && !zone_show_weak)
         continue;
      if(zone_strength[i] == ZONE_UNTESTED && !zone_show_untested)
         continue;
      if(zone_strength[i] == ZONE_TURNCOAT && !zone_show_turncoat)
         continue;

      // Calculate midpoint for levels
      double level = NormalizeDouble((zone_hi[i] + zone_lo[i]) / 2, _Digits);

      if(zone_type[i] == ZONE_SUPPORT)
        {
         // Add to support levels
         ArrayResize(supportLevels, supportCount + 1);
         supportLevels[supportCount++] = level;

         // Draw support zone if enabled
         if(drawZones)
           {
            string objName = "EA_Zone_S" + IntegerToString(i);
            datetime startTime = iTime(_Symbol, Timeframe, zone_start[i]);
            datetime endTime = iTime(_Symbol, Timeframe, 0)+ PeriodSeconds(Timeframe) * 100;
            ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, zone_hi[i], endTime, zone_lo[i]);
            ObjectSetInteger(0, objName, OBJPROP_COLOR, supportColor);
            ObjectSetInteger(0, objName, OBJPROP_FILL, zoneSolid);
            ObjectSetInteger(0, objName, OBJPROP_BACK, true);
            ObjectSetInteger(0, objName, OBJPROP_WIDTH, zoneLineWidth);
            ObjectSetInteger(0, objName, OBJPROP_STYLE, zoneStyle);
           }
        }
      else
         if(zone_type[i] == ZONE_RESIST)
           {
            // Add to resistance levels
            ArrayResize(resistanceLevels, resistanceCount + 1);
            resistanceLevels[resistanceCount++] = level;

            // Draw resistance zone if enabled
            if(drawZones)
              {
               string objName = "EA_Zone_R" + IntegerToString(i);
               datetime startTime = iTime(_Symbol, Timeframe, zone_start[i]);
               datetime endTime = iTime(_Symbol, Timeframe, 0)+ PeriodSeconds(Timeframe) * 100;
               ObjectCreate(0, objName, OBJ_RECTANGLE, 0, startTime, zone_hi[i], endTime, zone_lo[i]);
               ObjectSetInteger(0, objName, OBJPROP_COLOR, resistanceColor);
               ObjectSetInteger(0, objName, OBJPROP_FILL, zoneSolid);
               ObjectSetInteger(0, objName, OBJPROP_BACK, true);
               ObjectSetInteger(0, objName, OBJPROP_WIDTH, zoneLineWidth);
               ObjectSetInteger(0, objName, OBJPROP_STYLE, zoneStyle);
              }
           }
     }

// Sort levels for consistency
   ArraySort(supportLevels);
   ArraySort(resistanceLevels);
  }

//+------------------------------------------------------------------+
//| Check Breaks and Retests                                         |
//+------------------------------------------------------------------+
void CheckBreaksAndRetests()
  {
   double closePrice = iClose(_Symbol, Timeframe, 1);
   double openPrice = iOpen(_Symbol, Timeframe, 1);
   double highPrice = iHigh(_Symbol, Timeframe, 1);
   double lowPrice = iLow(_Symbol, Timeframe, 1);

// Check Resistance Breaks
   for(int i = 0; i < ArraySize(resistanceLevels); i++)
     {
      double level = resistanceLevels[i];
      if(closePrice > level && iClose(_Symbol, Timeframe, 2) <= level)
        {
         if(ConfirmBreakout(true, highPrice, lowPrice, closePrice, openPrice))
           {
            BrokenLevel bl = {level, true, iBars(_Symbol, Timeframe) - 1};
            ArrayResize(brokenLevels, ArraySize(brokenLevels) + 1);
            brokenLevels[ArraySize(brokenLevels) - 1] = bl;
            Print("Resistance broken at: ", DoubleToString(level, _Digits));
           }
        }
     }

// Check Support Breaks
   for(int i = 0; i < ArraySize(supportLevels); i++)
     {
      double level = supportLevels[i];
      if(closePrice < level && iClose(_Symbol, Timeframe, 2) >= level)
        {
         if(ConfirmBreakout(false, highPrice, lowPrice, closePrice, openPrice))
           {
            BrokenLevel bl = {level, false, iBars(_Symbol, Timeframe) - 1};
            ArrayResize(brokenLevels, ArraySize(brokenLevels) + 1);
            brokenLevels[ArraySize(brokenLevels) - 1] = bl;
            Print("Support broken at: ", DoubleToString(level, _Digits));
           }
        }
     }

// Check Retests
   for(int i = ArraySize(brokenLevels) - 1; i >= 0; i--)
     {
      BrokenLevel bl = brokenLevels[i];
      int barsSinceBreak = iBars(_Symbol, Timeframe) - 1 - bl.breakBarIndex;
      if(barsSinceBreak > maxBarsForRetest)
        {
         ArrayRemove(brokenLevels, i, 1);
         continue;
        }
      double pipRange = retestPips * _Point;
      if(bl.isResistance && lowPrice >= bl.price - pipRange && lowPrice <= bl.price + pipRange && closePrice > openPrice)
        {
         if(ConfirmRetest(true, closePrice, openPrice, highPrice, lowPrice))
           {
            if(!singlePosition || !PositionSelect(_Symbol))
              {
               double sl = NormalizeDouble(lowPrice - 10 * _Point, _Digits);
               double tp = NormalizeDouble(bl.price + 50 * _Point, _Digits);
               trade.Buy(lotSize, _Symbol, 0, sl, tp);
               Print("Buy after resistance retest at: ", DoubleToString(bl.price, _Digits));
               ArrayRemove(brokenLevels, i, 1);
              }
           }
        }
      else
         if(!bl.isResistance && highPrice >= bl.price - pipRange && highPrice <= bl.price + pipRange && closePrice < openPrice)
           {
            if(ConfirmRetest(false, closePrice, openPrice, highPrice, lowPrice))
              {
               if(!singlePosition || !PositionSelect(_Symbol))
                 {
                  double sl = NormalizeDouble(highPrice + 10 * _Point, _Digits);
                  double tp = NormalizeDouble(bl.price - 50 * _Point, _Digits);
                  trade.Sell(lotSize, _Symbol, 0, sl, tp);
                  Print("Sell after support retest at: ", DoubleToString(bl.price, _Digits));
                  ArrayRemove(brokenLevels, i, 1);
                 }
              }
           }
     }
  }

//+------------------------------------------------------------------+
//| Confirm Breakout                                                 |
//+------------------------------------------------------------------+
bool ConfirmBreakout(bool isResistance, double high, double low, double close, double open)
  {
   bool volumeConfirmed = true;
   if(useVolumeConfirmation)
     {
      double volume[];
      ArraySetAsSeries(volume, true);
      CopyBuffer(handleVolume, 0, 1, volumePeriod + 1, volume);
      double currentVolume = volume[0];
      double avgVolume = 0;
      for(int i = 1; i <= volumePeriod; i++)
         avgVolume += volume[i];
      avgVolume /= volumePeriod;
      volumeConfirmed = currentVolume > avgVolume * volumeMultiplier;
     }
   bool candleConfirmed = true;
   if(useCandlestickConfirmation)
     {
      candleConfirmed = isResistance ? (close > open && (close - open) > (high - low) * 0.5) :
                        (close < open && (open - close) > (high - low) * 0.5);
     }
   return volumeConfirmed && candleConfirmed;
  }

//+------------------------------------------------------------------+
//| Confirm Retest                                                   |
//+------------------------------------------------------------------+
bool ConfirmRetest(bool isBuy, double close, double open, double high, double low)
  {
   bool candleConfirmed = true;
   if(useCandlestickConfirmation)
     {
      if(isBuy)
        {
         bool hammer = (close > open && (open - low) > (close - open) * 2);
         bool engulfing = useEngulfingPattern && IsBullishEngulfing(1);
         candleConfirmed = hammer || engulfing;
        }
      else
        {
         bool shootingStar = (close < open && (high - open) > (open - close) * 2);
         bool engulfing = useEngulfingPattern && IsBearishEngulfing(1);
         candleConfirmed = shootingStar || engulfing;
        }
     }
   return candleConfirmed;
  }

//+------------------------------------------------------------------+
//| Bullish Engulfing Pattern                                        |
//+------------------------------------------------------------------+
bool IsBullishEngulfing(int shift)
  {
   double prevOpen = iOpen(_Symbol, Timeframe, shift + 1);
   double prevClose = iClose(_Symbol, Timeframe, shift + 1);
   double currOpen = iOpen(_Symbol, Timeframe, shift);
   double currClose = iClose(_Symbol, Timeframe, shift);
   return prevClose < prevOpen && currClose > currOpen && currClose > prevOpen && currOpen < prevClose;
  }

//+------------------------------------------------------------------+
//| Bearish Engulfing Pattern                                        |
//+------------------------------------------------------------------+
bool IsBearishEngulfing(int shift)
  {
   double prevOpen = iOpen(_Symbol, Timeframe, shift + 1);
   double prevClose = iClose(_Symbol, Timeframe, shift + 1);
   double currOpen = iOpen(_Symbol, Timeframe, shift);
   double currClose = iClose(_Symbol, Timeframe, shift);
   return prevClose > prevOpen && currClose < currOpen && currClose < prevOpen && currOpen > prevClose;
  }

//+------------------------------------------------------------------+
//| Array Remove Function                                            |
//+------------------------------------------------------------------+
void ArrayRemove(BrokenLevel &arr[], int index, int count)
  {
   int size = ArraySize(arr);
   if(index < 0 || index + count > size)
      return;
   for(int i = index; i < size - count; i++)
      arr[i] = arr[i + count];
   ArrayResize(arr, size - count);
  }
//+------------------------------------------------------------------+
