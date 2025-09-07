 
//+------------------------------------------------------------------+
#property copyright "Copyright 2024"
 
// Define variables for trendline parameters
double trendline_slope, trendline_intercept;

// Define variables for rectangle corners
double rectangle_x1, rectangle_y1, rectangle_x2, rectangle_y2;
bool   in_rectangle = false; // Track if price is currently within rectangle

// Function to identify trendline based on recent price movement
bool IdentifyTrendline(int period)
  {
    // Perform linear regression on recent closing prices (replace with your strategy)
    // This is a simplified example, consider using dedicated libraries for trendline fitting
    double sum_x = 0, sum_y = 0, sum_xy = 0, sum_x2 = 0;
    for (int i = 0; i < period; i++)
    {
      int bar = iBarShift(NULL,PERIOD_CURRENT,);
      double x = i;
      double y = Close[bar];
      sum_x += x;
      sum_y += y;
      sum_xy += x * y;
      sum_x2 += x * x;
    }
    
    trendline_slope = (period * sum_xy - sum_x * sum_y) / (period * sum_x2 - sum_x * sum_x);
    trendline_intercept = (sum_y - trendline_slope * sum_x) / period;
    
    // Check for statistically significant slope (replace with your threshold)
    return (MathAbs(trendline_slope) > 0.1);
  }

// Function to identify rectangle based on price movement (basic example)
bool IdentifyRectangle(int period)
  {
    // This is a simplified example, consider using additional logic for rectangle detection
    double highest = Double.MIN_POSITIVE;
    double lowest = Double.MAX_NEGATIVE;
    for (int i = 0; i < period; i++)
    {
      int bar = iBarShift(0, i);
      highest = MathMax(highest, High[bar]);
      lowest = MathMin(lowest, Low[bar]);
    }
    
    rectangle_x1 = 0;  // Replace with logic to define rectangle start bar
    rectangle_y1 = highest;
    rectangle_x2 = period - 1; // Replace with logic to define rectangle end bar
    rectangle_y2 = lowest;
    
    // Check for a significant price range (replace with your threshold)
    return (highest - lowest > AverageTrueRange(NULL, 0, period) * 2);
  }

// Check if price is within rectangle
bool IsInRectangle()
{
  double current_price = Close[0];
  return (current_price >= rectangle_y1 && current_price <= rectangle_y2);
}

// Entry logic (replace with your trading strategy)
int OnTick()
  {
 
    
    // Identify trendline and rectangle
    bool trendline_identified = IdentifyTrendline(20); // Replace 20 with your period
    bool rectangle_identified = IdentifyRectangle(20); // Replace 20 with your period
    
    // Update rectangle state
    in_rectangle = IsInRectangle();
    
    // Check for trendline touch and send alert (replace with trade logic)
    if (trendline_identified)
    {
      double trendline_price = trendline_slope * (iBars() - 1) + trendline_intercept;
      if (Close[0] <= trendline_price && Close[1] > trendline_price) // Price goes up from touching trendline
      {
        Print("Alert: Price touched trendline (going up)");
      }
      else if (Close[0] >= trendline_price && Close[1] < trendline_price) // Price goes down from touching trendline
      {
        Print("Alert: Price touched trendline (going down)");
      }
    }
    
    return(0);
  }
