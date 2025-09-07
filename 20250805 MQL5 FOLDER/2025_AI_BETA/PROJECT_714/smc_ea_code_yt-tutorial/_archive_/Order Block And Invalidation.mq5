//+------------------------------------------------------------------+
//|                                 Order Block And Invalidation.mq5 |
//|                                          Copyright 2024, Usiola. |
//|                                   https://www.trenddaytrader.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Usiola."
#property link      "https://www.trenddaytrader.com"
#property version   "1.00"

int barsTotal;

//Order Block CURRENT

double bullishOrderBlockHigh[];
double bullishOrderBlockLow[];
datetime bullishOrderBlockTime[];


double bearishOrderBlockHigh[];
double bearishOrderBlockLow[];
datetime bearishOrderBlockTime[];

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {

   ArraySetAsSeries(bullishOrderBlockHigh,true);
   ArraySetAsSeries(bullishOrderBlockLow,true);
   ArraySetAsSeries(bullishOrderBlockTime,true);

   ArraySetAsSeries(bearishOrderBlockHigh,true);
   ArraySetAsSeries(bearishOrderBlockLow,true);
   ArraySetAsSeries(bearishOrderBlockTime,true);

   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {

   int bars = iBars(_Symbol, PERIOD_CURRENT);

   if(barsTotal != bars)
     {
      barsTotal = bars;

      orderBlock();

     }
  }
//+------------------------------------------------------------------+
//| Create rectangle by the given coordinates                        |
//+------------------------------------------------------------------+
void createRect(const long            chart_ID=0,        // chart's ID
                const string          name="rectangleName",  // rectangle name
                const int             sub_window=0,      // subwindow index
                datetime time1=0, double price1=0,
                datetime time2=0, double price2=0,
                color colorRect=clrRed,int direction=0,
                string txt=0,
                const ENUM_LINE_STYLE style=STYLE_SOLID, // style of rectangle lines
                const int             width=1,           // width of rectangle lines
                const bool            fill=false,        // filling rectangle with color
                const bool            back=false,        // in the background
                const bool            selection=true,    // highlight to move
                const bool            hidden=true,       // hidden in the object list
                const long            z_order=0          // priority for mouse click
               )
  {
   string rectangleName ="";
   datetime time3 = iTime(_Symbol,PERIOD_CURRENT,2);
   StringConcatenate(rectangleName, "FVG @", time1,"at",DoubleToString(price1,_Digits));
   if(ObjectCreate(0,rectangleName,OBJ_RECTANGLE,0,time1,price1,time2,price2,colorRect,style,width,fill))
     {

      //--- set rectangle color
      ObjectSetInteger(0,rectangleName,OBJPROP_COLOR,colorRect);
      //--- set the style of rectangle lines
      ObjectSetInteger(0,rectangleName,OBJPROP_STYLE,style);
      //--- set width of the rectangle lines
      ObjectSetInteger(0,rectangleName,OBJPROP_WIDTH,width);
      //--- enable (true) or disable (false) the mode of filling the rectangle
      ObjectSetInteger(0,rectangleName,OBJPROP_FILL,fill);
      //--- display in the foreground (false) or background (true)
      //--- display in the foreground (false) or background (true)
      ObjectSetInteger(0,rectangleName,OBJPROP_BACK,back);
      //--- enable (true) or disable (false) the mode of highlighting the rectangle for moving
      //--- when creating a graphical object using ObjectCreate function, the object cannot be
      //--- highlighted and moved by default. Inside this method, selection parameter
      //--- is true by default making it possible to highlight and move the object
      ObjectSetInteger(0,rectangleName,OBJPROP_SELECTABLE,selection);
      ObjectSetInteger(0,rectangleName,OBJPROP_SELECTED,selection);
      //--- hide (true) or display (false) graphical object name in the object list
      ObjectSetInteger(0,rectangleName,OBJPROP_HIDDEN,hidden);
      //--- set the priority for receiving the event of a mouse click in the chart
      ObjectSetInteger(0,rectangleName,OBJPROP_ZORDER,z_order);
      //--- successful execution
     }

  }
//+------------------------------------------------------------------+
//| Function to delete rectangles created by createRect             |
//+------------------------------------------------------------------+
void deleteRectangle(datetime time, double price1)
  {
// Construct the rectangle name using the same format as in createRect
   string rectangleName = "";
   StringConcatenate(rectangleName, "FVG @", time, "at", DoubleToString(price1, _Digits));

// Check if the rectangle object exists
   if(ObjectFind(0, rectangleName) != -1)
     {
      if(ObjectDelete(0, rectangleName))
         ;

     }
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int orderBlock()
  {
   MqlRates rates[];
   ArraySetAsSeries(rates, true);
   int copied = CopyRates(_Symbol, PERIOD_CURRENT, 0, 50, rates);


// Bullish Order Block
   if(
      rates[3].low < rates[4].low &&
      rates[3].low < rates[2].low &&
      rates[1].low > rates[3].high

   )
     {
      double bullishOrderBlockHighValue = rates[3].open;
      double bullishOrderBlockLowValue = rates[3].low;
      datetime bullishOrderBlockTimeValue = rates[3].time;

      // Store bullishOrderBlockHighValue in bullishOrderBlockHigh[]

      // Shift existing elements in bullishOrderBlockHigh[] to make space for the new value
      ArrayResize(bullishOrderBlockHigh, ArraySize(bullishOrderBlockHigh) + 1);
      for(int i = ArraySize(bullishOrderBlockHigh) - 1; i > 0; --i)
        {
         bullishOrderBlockHigh[i] = bullishOrderBlockHigh[i - 1];
        }

      // Store bullishOrderBlockHighValue in bullishOrderBlockHigh[0], the first position
      bullishOrderBlockHigh[0] = bullishOrderBlockHighValue;

      // Store bullishOrderBlockLowValue in bullishOrderBlockLow[]

      // Shift existing elements in bullishOrderBlockLow[] to make space for the new value
      ArrayResize(bullishOrderBlockLow, ArraySize(bullishOrderBlockLow) + 1);
      for(int i = ArraySize(bullishOrderBlockLow) - 1; i > 0; --i)
        {
         bullishOrderBlockLow[i] = bullishOrderBlockLow[i - 1];
        }

      // Store bullishOrderBlockLowValue in bullishOrderBlockLow[0], the first position
      bullishOrderBlockLow[0] = bullishOrderBlockLowValue;

      // Store bullishOrderBlockTimeValue in bullishOrderBlockTime[]

      // Shift existing elements in bullishOrderBlockTime[] to make space for the new value
      ArrayResize(bullishOrderBlockTime, ArraySize(bullishOrderBlockTime) + 1);
      for(int i = ArraySize(bullishOrderBlockTime) - 1; i > 0; --i)
        {
         bullishOrderBlockTime[i] = bullishOrderBlockTime[i - 1];
        }

      // Store bullishOrderBlockTimeValue in bullishOrderBlockTime[0], the first position
      bullishOrderBlockTime[0] = bullishOrderBlockTimeValue;

      createRect(0, "Bu.OB", 0, bullishOrderBlockTimeValue, bullishOrderBlockLowValue, rates[0].time, bullishOrderBlockHighValue, clrTeal, 1, "Bu.OB", STYLE_SOLID, 3, false, false, true, false);
      return 1;
     }


// Bearish Order Block
   if(
      rates[3].high > rates[4].low &&
      rates[3].low > rates[2].low &&
      rates[1].high < rates[3].low

   )
     {
      double bearishOrderBlockLowValue = rates[3].close;
      double bearishOrderBlockHighValue = rates[3].high;
      datetime bearishOrderBlockTimeValue = rates[3].time;

      // Store bearishOrderBlockLowValue in bearishOrderBlockLow[]

      // Shift existing elements in bearishOrderBlockLow[] to make space for the new value
      ArrayResize(bearishOrderBlockLow, ArraySize(bearishOrderBlockLow) + 1);
      for(int i = ArraySize(bearishOrderBlockLow) - 1; i > 0; --i)
        {
         bearishOrderBlockLow[i] = bearishOrderBlockLow[i - 1];
        }

      // Store bearishOrderBlockLowValue in bearishOrderBlockLow[0], the first position
      bearishOrderBlockLow[0] = bearishOrderBlockLowValue;

      // Store bearishOrderBlockHighValue in bearishOrderBlockHigh[]

      // Shift existing elements in bearishOrderBlockHigh[] to make space for the new value
      ArrayResize(bearishOrderBlockHigh, ArraySize(bearishOrderBlockHigh) + 1);
      for(int i = ArraySize(bearishOrderBlockHigh) - 1; i > 0; --i)
        {
         bearishOrderBlockHigh[i] = bearishOrderBlockHigh[i - 1];
        }

      // Store bearishOrderBlockHighValue in bearishOrderBlockHigh[0], the first position
      bearishOrderBlockHigh[0] = bearishOrderBlockHighValue;

      // Store bearishOrderBlockTimeValue in bearishOrderBlockTime[]

      // Shift existing elements in bearishOrderBlockTime[] to make space for the new value
      ArrayResize(bearishOrderBlockTime, ArraySize(bearishOrderBlockTime) + 1);
      for(int i = ArraySize(bearishOrderBlockTime) - 1; i > 0; --i)
        {
         bearishOrderBlockTime[i] = bearishOrderBlockTime[i - 1];
        }

      // Store bearishOrderBlockTimeValue in bearishOrderBlockTime[0], the first position
      bearishOrderBlockTime[0] = bearishOrderBlockTimeValue;

      createRect(0, "Be.OB", 0, bearishOrderBlockTimeValue, bearishOrderBlockHighValue, rates[0].time, bearishOrderBlockLowValue, clrDarkRed, -1, "Be.OB", STYLE_SOLID, 3, false, false, true, false);
      return -1;
     }



//Invalidation Logic

//Bullish

   for(int i = ArraySize(bullishOrderBlockLow) - 1; i >= 0; i--)
     {
      if(
         ArraySize(bullishOrderBlockLow) > i &&
         rates[1].low < bullishOrderBlockLow[i] &&
         rates[1].high > bullishOrderBlockLow[i]
      )
        {
         deleteRectangle(bullishOrderBlockTime[i], bullishOrderBlockLow[i]);
         ArrayRemove(bullishOrderBlockLow, i, 1);
         ArrayRemove(bullishOrderBlockHigh, i, 1);
         ArrayRemove(bullishOrderBlockTime, i, 1);
        }
     }

//Bearish

   for(int i = ArraySize(bearishOrderBlockHigh) - 1; i >= 0; i--)
     {
      if(
         ArraySize(bearishOrderBlockHigh) > i &&
         rates[1].low < bearishOrderBlockHigh[i] &&
         rates[1].high > bearishOrderBlockHigh[i]
      )
        {
         deleteRectangle(bearishOrderBlockTime[i], bearishOrderBlockHigh[i]);
         ArrayRemove(bearishOrderBlockLow, i, 1);
         ArrayRemove(bearishOrderBlockHigh, i, 1);
         ArrayRemove(bearishOrderBlockTime, i, 1);
        }
     }


   return 0;
  }
//+------------------------------------------------------------------+
