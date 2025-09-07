//+------------------------------------------------------------------+
//|                                                   GridLines.mq4 |
//|                                       Optimized with Full Cleanup |
//+------------------------------------------------------------------+
#property indicator_chart_window
#property strict

// Define prefixes for object names for easier identification and cleanup
#define MONTHLY_LINES_PREFIX "MGrid"
#define WEEKLY_LINES_PREFIX  "WGrid"
#define MONTHLY_LABEL_PREFIX "MLab"
#define WEEKLY_LABEL_PREFIX  "WLab"
#define MONTHLY_VLINE_PREFIX "MonthlyBoundary_"
#define WEEKLY_VLINE_PREFIX  "WeeklyBoundary_"
#define IMPORTANT_AREA_PREFIX "ImpArea"

// Colors for different elements
color monthly_color = clrYellow;
color weekly_color  = clrBlue;
color above_price_color = clrGreen;
color below_price_color = clrRed;

// Store pairs of important levels (close monthly and weekly levels)
struct ImportantLevelPair
{
   double level1;
   double level2;
};

ImportantLevelPair important_areas[];
int important_areas_count = 0;

// Store current timeframe to detect changes
ENUM_TIMEFRAMES current_timeframe = PERIOD_CURRENT;

//+------------------------------------------------------------------+
//| Custom indicator initialization function                         |
//+------------------------------------------------------------------+
int OnInit()
{
   // --- Ensure minimum bars are loaded for required timeframes ---
   if (iBars(_Symbol, PERIOD_MN1) < 2 || iBars(_Symbol, PERIOD_W1) < 2)
   {
      Print("Not enough bars loaded for initialization. Please wait and refresh.");
      return(INIT_FAILED); // Prevents crashing on startup
   }

   // --- Ensure chart is rendered before drawing objects (optional safety) ---
   if (ChartGetInteger(0, CHART_VISIBLE_BARS) < 10)
   {
      Print("Chart not ready visually. Initialization postponed.");
      return(INIT_FAILED);
   }

   // --- Clear previous objects to avoid duplication ---
   CleanupAllObjects();

   // --- Store initial timeframe ---
   current_timeframe = _Period;

   // --- Draw all grid and boundary elements safely ---
   DrawGridLines(PERIOD_MN1, monthly_color, 2, MONTHLY_LINES_PREFIX, MONTHLY_LABEL_PREFIX, true, "Monthly");
   DrawGridLines(PERIOD_W1,  weekly_color,  1, WEEKLY_LINES_PREFIX,  WEEKLY_LABEL_PREFIX,  true, "Weekly");

   DrawPeriodBoundaries(PERIOD_W1, weekly_color, WEEKLY_VLINE_PREFIX, "Weekly");
   DrawPeriodBoundaries(PERIOD_MN1, monthly_color, MONTHLY_VLINE_PREFIX, "Monthly");

   FindImportantAreas();
   DrawAreaBoxes();

   return(INIT_SUCCEEDED);
}


//+------------------------------------------------------------------+
//| Custom indicator deinitialization function                       |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   // Clean up ALL objects created by this indicator
   CleanupAllObjects();
   
   Print("Indicator successfully removed and all objects cleaned up");
}

//+------------------------------------------------------------------+
//| Function to clean up all objects created by this indicator       |
//+------------------------------------------------------------------+
void CleanupAllObjects()
{
   // Create an array of all prefixes to clean up
   string prefixes[] = {
      MONTHLY_LINES_PREFIX,
      WEEKLY_LINES_PREFIX,
      MONTHLY_LABEL_PREFIX,
      WEEKLY_LABEL_PREFIX,
      MONTHLY_VLINE_PREFIX,
      WEEKLY_VLINE_PREFIX,
      IMPORTANT_AREA_PREFIX
   };
   
   // Remove all objects created by this indicator
   int total_obj = ObjectsTotal(0);
   
   // Loop backward through all objects to avoid index issues when deleting
   for(int i = total_obj - 1; i >= 0; i--)
   {
      if (i >= ObjectsTotal(0)) continue; // Safety check to prevent potential index errors
      
      string obj_name = ObjectName(0, i);
      
      // Check against all prefixes
      for(int p = 0; p < ArraySize(prefixes); p++)
      {
         if(StringFind(obj_name, prefixes[p]) == 0)
         {
            ObjectDelete(0, obj_name);
            break; // No need to check other prefixes for this object
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Function to draw horizontal grid lines                           |
//+------------------------------------------------------------------+
void DrawGridLines(ENUM_TIMEFRAMES tf,
                   color line_color,
                   int thickness,
                   string line_prefix,
                   string label_prefix,
                   bool add_labels,
                   string label_text)
{
   string symbol = _Symbol;
   int bars = iBars(symbol, tf);

   if(bars < 2)
   {
      Print("Not enough bars for timeframe: ", tf);
      return;
   }

   // Delete any existing lines with these prefixes first
   DeleteObjectsByPrefix(line_prefix);
   if(add_labels) DeleteObjectsByPrefix(label_prefix);
   
   double hi = iHigh(symbol, tf, 1);
   double lo = iLow(symbol, tf, 1);
   double step = (hi - lo) / 8.0;

   for(int i = 0; i < 9; i++)
   {
      double level = lo + step * i;
      string name = line_prefix + "_L" + IntegerToString(i);

      if(!ObjectCreate(0, name, OBJ_HLINE, 0, 0, level))
      {
         Print("Failed to create line: ", name);
         continue;
      }

      ObjectSetInteger(0, name, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, name, OBJPROP_WIDTH, thickness);
      ObjectSetInteger(0, name, OBJPROP_STYLE, STYLE_SOLID);
      ObjectSetInteger(0, name, OBJPROP_BACK, true);
      ObjectSetInteger(0, name, OBJPROP_SELECTABLE, false); // Make non-selectable to prevent accidental user modification
      ObjectSetInteger(0, name, OBJPROP_HIDDEN, true);      // Hide from object list for cleaner interface

      if(add_labels)
      {
         string label_name = label_prefix + "_L" + IntegerToString(i);
         
         string text = "(" + IntegerToString(i + 1) + ")";
         if(i == 0)
            text = "Low " + label_text + " (1)";
         else if(i == 8)
            text = "High " + label_text + " (9)";

         ObjectCreate(0, label_name, OBJ_TEXT, 0, TimeCurrent(), level);
         ObjectSetInteger(0, label_name, OBJPROP_COLOR, line_color);
         ObjectSetInteger(0, label_name, OBJPROP_FONTSIZE, 10);
         ObjectSetInteger(0, label_name, OBJPROP_CORNER, CORNER_LEFT_UPPER);
         ObjectSetInteger(0, label_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, label_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, label_name, OBJPROP_HIDDEN, true);
         ObjectSetString(0, label_name, OBJPROP_TEXT, text);
      }
   }
}

//+------------------------------------------------------------------+
//| Function to draw vertical lines showing period boundaries        |
//+------------------------------------------------------------------+
void DrawPeriodBoundaries(ENUM_TIMEFRAMES tf, color line_color, string prefix, string timeframe_label)
{
   string symbol = _Symbol;
   int bars = iBars(symbol, tf);

   if(bars < 3) // Ensure there are enough bars
   {
      Print("Not enough bars for ", timeframe_label, " timeframe.");
      return;
   }

   // Delete existing lines with this prefix
   DeleteObjectsByPrefix(prefix);
   
   // Get current chart timeframe
   ENUM_TIMEFRAMES chart_tf = _Period;
   
   // Times for last closed candle and current candle
   datetime current_start = iTime(symbol, tf, 0);     // Start of current candle
   datetime prev_start = iTime(symbol, tf, 1);        // Start of previous candle (last closed)
   
   // Line names
   string current_line = prefix + "Current_Start";
   string prev_start_line = prefix + "LastClosed_Start";
   string prev_end_line = prefix + "LastClosed_End";
   
   // Style settings
   ENUM_LINE_STYLE current_style = STYLE_SOLID;
   ENUM_LINE_STYLE closed_style = STYLE_DASH;
   int current_width = 2;
   int closed_width = 1;

   // Create vertical line for current candle start
   if(ObjectCreate(0, current_line, OBJ_VLINE, 0, current_start, 0))
   {
      ObjectSetInteger(0, current_line, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, current_line, OBJPROP_WIDTH, current_width);
      ObjectSetInteger(0, current_line, OBJPROP_STYLE, current_style);
      ObjectSetInteger(0, current_line, OBJPROP_BACK, true);
      ObjectSetInteger(0, current_line, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, current_line, OBJPROP_HIDDEN, true);
      ObjectSetString(0, current_line, OBJPROP_TOOLTIP, timeframe_label + " Current Start");
   }

   // Create vertical line for last closed candle start
   if(ObjectCreate(0, prev_start_line, OBJ_VLINE, 0, prev_start, 0))
   {
      ObjectSetInteger(0, prev_start_line, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, prev_start_line, OBJPROP_WIDTH, closed_width);
      ObjectSetInteger(0, prev_start_line, OBJPROP_STYLE, closed_style);
      ObjectSetInteger(0, prev_start_line, OBJPROP_BACK, true);
      ObjectSetInteger(0, prev_start_line, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, prev_start_line, OBJPROP_HIDDEN, true);
      ObjectSetString(0, prev_start_line, OBJPROP_TOOLTIP, timeframe_label + " Last Closed Start");
   }

   // Create vertical line for last closed candle end (same as current start)
   if(ObjectCreate(0, prev_end_line, OBJ_VLINE, 0, current_start, 0))
   {
      ObjectSetInteger(0, prev_end_line, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, prev_end_line, OBJPROP_WIDTH, closed_width);
      ObjectSetInteger(0, prev_end_line, OBJPROP_STYLE, closed_style);
      ObjectSetInteger(0, prev_end_line, OBJPROP_BACK, true);
      ObjectSetInteger(0, prev_end_line, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, prev_end_line, OBJPROP_HIDDEN, true);
      ObjectSetString(0, prev_end_line, OBJPROP_TOOLTIP, timeframe_label + " Last Closed End");
   }
     
   // Add text labels for clarity
   string current_label = prefix + "Current_Label";
   string prev_label = prefix + "LastClosed_Label";
   
   // Calculate y positions (use price range from current chart)
   double upper_price = iHigh(symbol, chart_tf, iHighest(symbol, chart_tf, MODE_HIGH, 50, 0));
   double lower_price = iLow(symbol, chart_tf, iLowest(symbol, chart_tf, MODE_LOW, 50, 0));
   double range = upper_price - lower_price;
   
   // Current candle label
   if(ObjectCreate(0, current_label, OBJ_TEXT, 0, current_start, upper_price - range * 0.05))
   {
      ObjectSetString(0, current_label, OBJPROP_TEXT, "Current " + timeframe_label);
      ObjectSetInteger(0, current_label, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, current_label, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, current_label, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, current_label, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, current_label, OBJPROP_HIDDEN, true);
   }
     
   // Last closed candle label
   if(ObjectCreate(0, prev_label, OBJ_TEXT, 0, prev_start, upper_price - range * 0.1))
   {
      ObjectSetString(0, prev_label, OBJPROP_TEXT, "Last " + timeframe_label);
      ObjectSetInteger(0, prev_label, OBJPROP_COLOR, line_color);
      ObjectSetInteger(0, prev_label, OBJPROP_FONTSIZE, 8);
      ObjectSetInteger(0, prev_label, OBJPROP_ANCHOR, ANCHOR_TOP);
      ObjectSetInteger(0, prev_label, OBJPROP_SELECTABLE, false);
      ObjectSetInteger(0, prev_label, OBJPROP_HIDDEN, true);
   }
}

//+------------------------------------------------------------------+
//| Delete objects by prefix to clean up specific object groups      |
//+------------------------------------------------------------------+
void DeleteObjectsByPrefix(string prefix)
{
   int obj_total = ObjectsTotal(0);
   
   // Loop backward to avoid index shifting problems
   for(int i = obj_total - 1; i >= 0; i--)
   {
      if (i >= ObjectsTotal(0)) continue; // Extra safety check
      
      string obj_name = ObjectName(0, i);
      if(StringFind(obj_name, prefix) == 0)
      {
         ObjectDelete(0, obj_name);
      }
   }
}

//+------------------------------------------------------------------+
//| Function to find important areas - monthly and weekly overlap    |
//+------------------------------------------------------------------+
void FindImportantAreas()
{
   double weekly_levels[9];
   double monthly_levels[9];
   
   string symbol = _Symbol;
   
   // Get Monthly levels
   double month_hi = iHigh(symbol, PERIOD_MN1, 1);
   double month_lo = iLow(symbol, PERIOD_MN1, 1);
   double month_step = (month_hi - month_lo) / 8.0;
   
   for(int i = 0; i < 9; i++)
   {
      monthly_levels[i] = month_lo + month_step * i;
   }
   
   // Get Weekly levels
   double week_hi = iHigh(symbol, PERIOD_W1, 1);
   double week_lo = iLow(symbol, PERIOD_W1, 1);
   double week_step = (week_hi - week_lo) / 8.0;
   
   for(int i = 0; i < 9; i++)
   {
      weekly_levels[i] = week_lo + week_step * i;
   }
   
   // Initialize array for important areas
   ArrayResize(important_areas, 0);
   important_areas_count = 0;
   
   // Find important areas (differences less than 10$)
   for(int m = 0; m < 9; m++)
   {
      for(int w = 0; w < 9; w++)
      {
         double diff = MathAbs(monthly_levels[m] - weekly_levels[w]);
         
         // If difference is less than 10$
         if(diff < 10.0)
         {
            // Store this pair of levels
            ArrayResize(important_areas, important_areas_count + 1);
            important_areas[important_areas_count].level1 = monthly_levels[m];
            important_areas[important_areas_count].level2 = weekly_levels[w];
            important_areas_count++;
         }
      }
   }
   
   Print("Found ", important_areas_count, " important areas");
}

//+------------------------------------------------------------------+
//| Function to draw boxes for each candle in important areas        |
//+------------------------------------------------------------------+
void DrawAreaBoxes()
{
   // First clean up any existing area boxes
   DeleteObjectsByPrefix(IMPORTANT_AREA_PREFIX);
   
   // We'll start from the current weekly candle
   datetime start_time = iTime(_Symbol, PERIOD_W1, 0);
   int start_bar = iBarShift(_Symbol, _Period, start_time);
   
   if(start_bar < 0)
   {
      Print("Could not find the bar for the weekly start time, using fallback");
      start_bar = 100; // Default to 100 bars back as fallback
   }
   
   // For each important area
   for(int area_idx = 0; area_idx < important_areas_count; area_idx++)
   {
      double level_low = MathMin(important_areas[area_idx].level1, important_areas[area_idx].level2);
      double level_high = MathMax(important_areas[area_idx].level1, important_areas[area_idx].level2);
      
      // For each bar from start_bar to current
      for(int i = start_bar; i >= 0; i--)
      {  
         datetime time_start = iTime(_Symbol, _Period, i);
         datetime time_end = i > 0 ? iTime(_Symbol, _Period, i-1) : time_start + PeriodSeconds(_Period);
         
         double close_price = iClose(_Symbol, _Period, i);
         
         string box_name = IMPORTANT_AREA_PREFIX + "_" + IntegerToString(area_idx) + "_" + IntegerToString(i);
         
         // Color based on price position
         color box_color = (close_price > level_high) ? above_price_color : below_price_color;
         
         // Create rectangle
         if(!ObjectCreate(0, box_name, OBJ_RECTANGLE, 0, time_start, level_high, time_end, level_low))
         {
            Print("Failed to create box: ", box_name);
            continue;
         }
         
         // Set box properties
         ObjectSetInteger(0, box_name, OBJPROP_COLOR, box_color);
         ObjectSetInteger(0, box_name, OBJPROP_BGCOLOR, box_color);
         ObjectSetInteger(0, box_name, OBJPROP_BACK, true);
         ObjectSetInteger(0, box_name, OBJPROP_FILL, true);
         ObjectSetInteger(0, box_name, OBJPROP_WIDTH, 1);
         ObjectSetInteger(0, box_name, OBJPROP_SELECTABLE, false);
         ObjectSetInteger(0, box_name, OBJPROP_HIDDEN, true);
      }
   }
}

//+------------------------------------------------------------------+
//| Custom indicator iteration function                              |
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
   // Safety check for data
   if(rates_total <= 0) return(0);
   
   // Check if timeframe has changed
   if(_Period != current_timeframe)
   {
      // Update current timeframe
      current_timeframe = _Period;
      
      // Clean up all objects and redraw everything
      CleanupAllObjects();
      
      // Redraw everything for new timeframe
      DrawGridLines(PERIOD_MN1, monthly_color, 2, MONTHLY_LINES_PREFIX, MONTHLY_LABEL_PREFIX, true, "Monthly");
      DrawGridLines(PERIOD_W1, weekly_color, 1, WEEKLY_LINES_PREFIX, WEEKLY_LABEL_PREFIX, true, "Weekly");
      DrawPeriodBoundaries(PERIOD_W1, weekly_color, WEEKLY_VLINE_PREFIX, "Weekly");
      DrawPeriodBoundaries(PERIOD_MN1, monthly_color, MONTHLY_VLINE_PREFIX, "Monthly");
      DrawAreaBoxes();
   }
   else 
   {
      // Just update the current bar's boxes
      // This is more efficient than redrawing everything
      
      if(rates_total > 0 && important_areas_count > 0)
      {
         datetime time_current = time[0];
         double price_current = close[0];
         
         for(int area_idx = 0; area_idx < important_areas_count; area_idx++)
         {
            double level_low = MathMin(important_areas[area_idx].level1, important_areas[area_idx].level2);
            double level_high = MathMax(important_areas[area_idx].level1, important_areas[area_idx].level2);
            
            string box_name = IMPORTANT_AREA_PREFIX + "_" + IntegerToString(area_idx) + "_0";
            
            // Update or create the box for the current candle
            color box_color = (price_current > level_high) ? above_price_color : below_price_color;
            
            if(ObjectFind(0, box_name) >= 0)
            {
               // Just update color
               ObjectSetInteger(0, box_name, OBJPROP_COLOR, box_color);
               ObjectSetInteger(0, box_name, OBJPROP_BGCOLOR, box_color);
            }
            else
            {
               // Create new box
               datetime time_start = time[0];
               datetime time_end = time[0] + PeriodSeconds(_Period);
               
               if(!ObjectCreate(0, box_name, OBJ_RECTANGLE, 0, time_start, level_high, time_end, level_low))
               {
                  Print("Failed to create box for current bar: ", box_name);
                  continue;
               }
               
               // Set box properties
               ObjectSetInteger(0, box_name, OBJPROP_COLOR, box_color);
               ObjectSetInteger(0, box_name, OBJPROP_BGCOLOR, box_color);
               ObjectSetInteger(0, box_name, OBJPROP_BACK, true);
               ObjectSetInteger(0, box_name, OBJPROP_FILL, true);
               ObjectSetInteger(0, box_name, OBJPROP_WIDTH, 1);
               ObjectSetInteger(0, box_name, OBJPROP_SELECTABLE, false);
               ObjectSetInteger(0, box_name, OBJPROP_HIDDEN, true);
            }
         }
      }
   }
   
   return(rates_total);
}