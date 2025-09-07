//+------------------------------------------------------------------+
//|                                                      ProjectName |
//|                                      Copyright 2020, CompanyName |
//|                                       http://www.companyname.net |
//+------------------------------------------------------------------+


// Define variables for trendline parameters
double trendline_slope, trendline_intercept;

// Define variables for trendline drawn on the chart
double chart_trendline_x1, chart_trendline_y1, chart_trendline_x2, chart_trendline_y2;

// Define variables for rectangle corners
double rectangle_x1, rectangle_y1, rectangle_x2, rectangle_y2;
bool   in_rectangle = false; // Track if price is currently within rectangle



// Function to detect rectangles drawn on the chart
bool DetectRectangleOnChart()
  {
   int totalObjects = ObjectsTotal(0,0,-1);
   for(int i = 0; i < totalObjects; i++)
     {
      string name = ObjectName(0,i,0);

      ENUM_OBJECT type=(ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE);


      if(type == OBJ_RECTANGLE)
        {
         //Print("found a rectangle");
         //rectangle_x1 = ObjectGetInteger(0, name, OBJPROP_TIME1);
         //rectangle_y1 = ObjectGetDouble(0, name, OBJPROP_PRICE1);

         //rectangle_x2 = ObjectGetInteger(0, name, OBJPROP_TIME2);
         //rectangle_y2 = ObjectGetDouble(0, name, OBJPROP_PRICE2);

         rectangle_x1=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,0);
         rectangle_x2=(datetime)ObjectGetInteger(0,name,OBJPROP_TIME,1);
         rectangle_y1=NormalizeDouble(ObjectGetDouble(0,name,OBJPROP_PRICE,0),2);
         rectangle_y2=NormalizeDouble(ObjectGetDouble(0,name,OBJPROP_PRICE,1),2);

         string   rectname=ObjectGetString(0,name,OBJPROP_NAME);
         string   rectdesc=ObjectGetString(0,name,OBJPROP_TEXT);

         Print("Obj rect found . Name is:"+rectname);
         Print("Obj rect found . Desc is:"+rectdesc);


         return true;
        }
     }
   return false;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool isNewBar()
  {
//--- memorize the time of opening of the last bar in the static variable
   static datetime last_time=0;
//--- current time
   datetime lastbar_time=(datetime)SeriesInfoInteger(Symbol(),Period(),SERIES_LASTBAR_DATE);

//--- if it is the first call of the function
   if(last_time==0)
     {
      //--- set the time and exit
      last_time=lastbar_time;
      return(false);
     }

//--- if the time differs
   if(last_time!=lastbar_time)
     {
      //--- memorize the time and return true
      last_time=lastbar_time;
      return(true);
     }
//--- if we passed to this line, then the bar is not new; return false
   return(false);
  }
// Function to detect trendlines drawn on the chart
bool DetectTrendlineOnChart()
  {
   int totalObjects = ObjectsTotal(0,0);
   for(int i = 0; i < totalObjects; i++)
     {
      string name = ObjectName(0,i,0);
      ENUM_OBJECT type=(ENUM_OBJECT)ObjectGetInteger(0,name,OBJPROP_TYPE);

      if(type == OBJ_TREND)
        {
         chart_trendline_x1 = ObjectGetInteger(0, name, OBJPROP_TIME,0);
         //chart_trendline_y1 = ObjectGetDouble(0, name, OBJPROP_PRICE1);
         chart_trendline_x2 = ObjectGetInteger(0, name, OBJPROP_TIME,1);
         //chart_trendline_y2 = ObjectGetDouble(0, name, OBJPROP_PRICE2);

         chart_trendline_y1=NormalizeDouble(ObjectGetDouble(0,name,OBJPROP_PRICE,0),Digits());
         chart_trendline_y2=NormalizeDouble(ObjectGetDouble(0,name,OBJPROP_PRICE,1),Digits());


         return true;
        }
     }
   return false;
  }

// Check if price is within rectangle
bool IsInRectangle()
  {
   double current_price = NormalizeDouble(iClose(NULL, PERIOD_CURRENT, 1),2);

   bool priceIsInRect=((current_price >= rectangle_y1 && current_price <= rectangle_y2) &&
                       (iTime(_Symbol,PERIOD_CURRENT,1)>=rectangle_x2&& iTime(_Symbol,PERIOD_CURRENT,0)<=rectangle_x1 /* &&<=*/));

   if(priceIsInRect)
      Print("Price entered a rectangle "+current_price+"  y1:"+rectangle_y1+"  y2:"+   rectangle_y2);

   return (priceIsInRect);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool IsNearTrendline()
  {
   double current_price = iClose(NULL, PERIOD_CURRENT, 0);
   double trendline_price = ((current_price - chart_trendline_x1) * (chart_trendline_y2 - chart_trendline_y1) /
                             (chart_trendline_x2 - chart_trendline_x1)) + chart_trendline_y1;
// Check if the current price is near the trendline price (replace with your threshold)
   return MathAbs(current_price - trendline_price) <= (iATR(NULL, PERIOD_CURRENT, 14) * 0.5);
  }

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void OnTick()
  {

   if(!isNewBar())
      return;


   bool rectangle_identified = DetectRectangleOnChart();
//bool chart_trendline_identified = DetectTrendlineOnChart();

   if(rectangle_identified)
     {
      in_rectangle = IsInRectangle();
     }

//if(trendline_identified)
//  {
//   double trendline_price = trendline_slope * (iBars(NULL, PERIOD_CURRENT) - 1) + trendline_intercept;
//   if(iClose(NULL, PERIOD_CURRENT, 0) <= trendline_price && iClose(NULL, PERIOD_CURRENT, 1) > trendline_price)  // Price goes up from touching trendline
//     {
//      Print("Alert: Price touched trendline (going up)");
//     }
//   else
//      if(iClose(NULL, PERIOD_CURRENT, 0) >= trendline_price && iClose(NULL, PERIOD_CURRENT, 1) < trendline_price)  // Price goes down from touching trendline
//        {
//         Print("Alert: Price touched trendline (going down)");
//        }
//  }
//
//   if(chart_trendline_identified /*&& IsNearTrendline()*/)
//     {
//      Print("Alert: Price is near the chart trendline");
//     }
//
//   if(chart_trendline_identified /*&& IsNearTrendline()*/)
//     {
//      Print("Alert:  chart trendline found");
//     }
  }
//+------------------------------------------------------------------+
