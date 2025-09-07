//+------------------------------------------------------------------+
//| Indicator: Smart Volume Price Action MTF (MT5)                  |
//| Combines: Volume, FVG, OB, Liquidity Zones, Engulfing, MTF      |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property strict
#property indicator_plots 0

//--- INPUTS
input int      FVG_Lookback = 100;
input int      OB_Lookback  = 100;
input double   VolumeMultiplier = 1.5;
input int      LiquidityZoneSensitivity = 3;
input ENUM_TIMEFRAMES MTF_Timeframe = PERIOD_H1; // Higher TF for MTF filter
input double   MTF_Filter_Strength = 0.5;        // % of MTF signals needed for confirmation

//--- COLORS
color FVG_Color           = clrDodgerBlue;
color OB_Bullish_Color    = clrLimeGreen;
color OB_Bearish_Color    = clrOrangeRed;
color EQH_Color           = clrGreen;
color EQL_Color           = clrRed;
color Engulf_Bull_Color   = clrAqua;
color Engulf_Bear_Color   = clrMagenta;
color Vol_Confirm_Color   = clrGold;

//+------------------------------------------------------------------+
//| Custom Utils                                                    |
//+------------------------------------------------------------------+
//--- MTF Helper: Get value from another timeframe
double iHighTF(const string symbol, ENUM_TIMEFRAMES tf, int shift, int type=PRICE_CLOSE)
{
   double arr[];
   if(CopyClose(symbol, tf, shift, 1, arr) > 0 && type == PRICE_CLOSE)
      return arr[0];
   if(CopyOpen(symbol, tf, shift, 1, arr) > 0 && type == PRICE_OPEN)
      return arr[0];
   if(CopyHigh(symbol, tf, shift, 1, arr) > 0 && type == PRICE_HIGH)
      return arr[0];
   if(CopyLow(symbol, tf, shift, 1, arr) > 0 && type == PRICE_LOW)
      return arr[0];
   return 0;
}

//--- Check if current bar aligns with MTF filter
bool IsMTFConfirmed(const datetime &time[], int i)
{
   if(MTF_Timeframe <= Period()) return true; // No filter if same or lower tf

   // Find higher timeframe bar for this candle
   datetime bar_time = iTime(_Symbol, MTF_Timeframe, 0);
   int htf_bar = iBarShift(_Symbol, MTF_Timeframe, time[i], true);

   // Simple filter: Check if current close is above/below HTF close
   double myclose = iClose(_Symbol, Period(), i);
   double mtfclose = iHighTF(_Symbol, MTF_Timeframe, htf_bar, PRICE_CLOSE);

   double myopen = iOpen(_Symbol, Period(), i);
   double mtfopen = iHighTF(_Symbol, MTF_Timeframe, htf_bar, PRICE_OPEN);

   // Filter: Only show if direction matches HTF (bullish/bearish)
   return (myclose>myopen && mtfclose>mtfopen) || (myclose<myopen && mtfclose<mtfopen);
}

//--- FVG
bool IsFVG(const double &low[], const double &high[], int i)
{
   double low1 = low[i+2];
   double high1 = high[i];
   return (low1 > high1);
}

//--- Engulfing
bool IsBullishEngulfing(const double &open[], const double &close[], int i)
{
   return (close[i+1] < open[i+1] && close[i] > open[i] && close[i] > open[i+1] && open[i] < close[i+1]);
}
bool IsBearishEngulfing(const double &open[], const double &close[], int i)
{
   return (close[i+1] > open[i+1] && close[i] < open[i] && close[i] < open[i+1] && open[i] > close[i+1]);
}

//--- OB
bool IsBullOB(const double &open[], const double &close[], int i)
{
   return IsBullishEngulfing(open, close, i);
}
bool IsBearOB(const double &open[], const double &close[], int i)
{
   return IsBearishEngulfing(open, close, i);
}

//--- Liquidity Zones
bool IsEqualHigh(const double &high[], int i, double pt, int sens)
{
   return (MathAbs(high[i] - high[i+1]) <= pt * sens);
}
bool IsEqualLow(const double &low[], int i, double pt, int sens)
{
   return (MathAbs(low[i] - low[i+1]) <= pt * sens);
}

//--- Volume
bool IsHighVolume(const long &volume[], int i, double mult)
{
   double avgVol = 0;
   int bars = 20, real_bars=0;
   for(int j = i+1; j <= i+bars && j < ArraySize(volume); j++) {
      avgVol += (double)volume[j];
      real_bars++;
   }
   if(real_bars > 0)
      avgVol /= real_bars;
   return (volume[i] > (long)(avgVol * mult));
}

//--- Draws
void DrawBox(const datetime &time[], string name, int shift, double high, double low, color c, int style=STYLE_SOLID, int width=1, int transp=50)
{
   datetime time1 = time[shift];
   datetime time2 = time[shift-1];
   uchar alpha = (uchar)MathMin(255, MathMax(0, (int)(255.0 * transp/100.0)));
   uint c_raw = (c & 0x00FFFFFF) | ((uint)alpha << 24);
   color c_trans = (color)c_raw;
   if(ObjectFind(0, name) == -1)
   {
      ObjectCreate(0, name, OBJ_RECTANGLE, 0, time1, high, time2, low);
      ObjectSetInteger(0, name, OBJPROP_COLOR, c_trans);
      ObjectSetInteger(0, name, OBJPROP_STYLE, style);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
   }
}
void DrawLine(const datetime &time[], string name, int shift, double price, color c, int width=2)
{
   if(ObjectFind(0, name) == -1)
   {
      ObjectCreate(0, name, OBJ_HLINE, 0, time[shift], price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, c);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, width);
   }
}
void DrawArrow(const datetime &time[], string name, int shift, double price, color c, int code=234)
{
   if(ObjectFind(0, name) == -1)
   {
      ObjectCreate(0, name, OBJ_ARROW, 0, time[shift], price);
      ObjectSetInteger(0, name, OBJPROP_COLOR, c);
      ObjectSetInteger(0, name, OBJPROP_ARROWCODE, code);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, 2);
   }
}

//+------------------------------------------------------------------+
//| Main Indicator                                                  |
//+------------------------------------------------------------------+
int OnCalculate(const int rates_total,
                const int prev_calculated,
                const datetime &time[],
                const double &open[],
                const double &high[],
                const double &low[],
                const double &close[],
                const long &tick_volume[],
                const long &volume[],
                const int &spread[])
{
   int limit = MathMin(FVG_Lookback, rates_total - 22);
   int obj_total = ObjectsTotal(0, 0, -1);
   for(int i = obj_total - 1; i >= 0; i--)
   {
      string name = ObjectName(0, i);
      if(StringFind(name, "FVG_") == 0 || StringFind(name, "BullOB_") == 0 || StringFind(name, "BearOB_") == 0 ||
         StringFind(name, "EQH_") == 0 || StringFind(name, "EQL_") == 0 || StringFind(name, "EngulfB_") == 0 ||
         StringFind(name, "EngulfS_") == 0 || StringFind(name, "VolConf_") == 0)
      {
         ObjectDelete(0, name);
      }
   }

   for(int i=limit; i>=0; i--)
   {
      if(!IsMTFConfirmed(time, i)) continue;

      //--- FVG
      if(i+2 < rates_total && IsFVG(low, high, i))
      {
         double top = low[i+2];
         double bottom = high[i];
         DrawBox(time, "FVG_"+IntegerToString(i), i, top, bottom, FVG_Color, STYLE_DOT, 2, 20);
      }
      //--- OB: Bull
      if(i+1 < rates_total && IsBullOB(open, close, i) && IsHighVolume(volume, i, VolumeMultiplier))
      {
         double obLow = low[i];
         double obHigh = high[i];
         DrawBox(time, "BullOB_"+IntegerToString(i), i, obHigh, obLow, OB_Bullish_Color, STYLE_SOLID, 2, 10);
         DrawArrow(time, "VolConf_"+IntegerToString(i), i, obHigh, Vol_Confirm_Color, 241);
      }
      //--- OB: Bear
      if(i+1 < rates_total && IsBearOB(open, close, i) && IsHighVolume(volume, i, VolumeMultiplier))
      {
         double obLow = low[i];
         double obHigh = high[i];
         DrawBox(time, "BearOB_"+IntegerToString(i), i, obHigh, obLow, OB_Bearish_Color, STYLE_SOLID, 2, 10);
         DrawArrow(time, "VolConf_"+IntegerToString(i), i, obLow, Vol_Confirm_Color, 242);
      }
      //--- Liquidity Zones
      if(i+1 < rates_total && IsEqualHigh(high, i, _Point, LiquidityZoneSensitivity))
         DrawLine(time, "EQH_"+IntegerToString(i), i, high[i], EQH_Color, 2);
      if(i+1 < rates_total && IsEqualLow(low, i, _Point, LiquidityZoneSensitivity))
         DrawLine(time, "EQL_"+IntegerToString(i), i, low[i], EQL_Color, 2);

      //--- Engulfing
      if(i+1 < rates_total && IsBullishEngulfing(open, close, i))
         DrawArrow(time, "EngulfB_"+IntegerToString(i), i, low[i], Engulf_Bull_Color, 233);
      if(i+1 < rates_total && IsBearishEngulfing(open, close, i))
         DrawArrow(time, "EngulfS_"+IntegerToString(i), i, high[i], Engulf_Bear_Color, 234);
   }
   return(rates_total);
}