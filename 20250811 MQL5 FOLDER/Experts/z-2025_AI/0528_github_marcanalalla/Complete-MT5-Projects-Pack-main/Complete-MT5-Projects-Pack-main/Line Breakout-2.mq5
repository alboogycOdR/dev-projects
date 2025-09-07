//+------------------------------------------------------------------+
//|                                            BreakoutIndicator.mq5 |
//|                                  Copyright 2024, Your Name Here  |
//+------------------------------------------------------------------+
#property copyright "Copyright 2024, Your Name Here"
#property version   "1.02"
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots   3
#property indicator_type1   DRAW_LINE
#property indicator_color1  clrGreen
#property indicator_style1  STYLE_SOLID
#property indicator_width1  2
#property indicator_type2   DRAW_LINE
#property indicator_color2  clrRed
#property indicator_style2  STYLE_SOLID
#property indicator_width2  2
#property indicator_type3   DRAW_LINE
#property indicator_color3  clrBlue
#property indicator_style3  STYLE_DOT
#property indicator_width3  2

// Input parameters for customization
input color   HighLineColor = clrLime;  // Color for High Line
input int     HighLineWidth = 1;         // Width for High Line
input ENUM_LINE_STYLE HighLineStyle = STYLE_DASHDOTDOT; // Style for High Line

input color   LowLineColor = clrRed;     // Color for Low Line
input int     LowLineWidth = 1;          // Width for Low Line
input ENUM_LINE_STYLE LowLineStyle = STYLE_DASHDOTDOT; // Style for Low Line

input color   MidLineColor = clrWhite;    // Color for Mid Line
input int     MidLineWidth = 1;          // Width for Mid Line
input ENUM_LINE_STYLE MidLineStyle = STYLE_DASHDOTDOT;   // Style for Mid Line

input int Periods = 160; // Periods for calculating high and low

double HighBuffer[];
double LowBuffer[];
double MidBuffer[];

int OnInit()
  {
   SetIndexBuffer(0, HighBuffer);
   SetIndexBuffer(1, LowBuffer);
   SetIndexBuffer(2, MidBuffer);

   PlotIndexSetInteger(0, PLOT_LINE_COLOR, HighLineColor);
   PlotIndexSetInteger(0, PLOT_LINE_WIDTH, HighLineWidth);
   PlotIndexSetInteger(0, PLOT_LINE_STYLE, HighLineStyle);

   PlotIndexSetInteger(1, PLOT_LINE_COLOR, LowLineColor);
   PlotIndexSetInteger(1, PLOT_LINE_WIDTH, LowLineWidth);
   PlotIndexSetInteger(1, PLOT_LINE_STYLE, LowLineStyle);

   PlotIndexSetInteger(2, PLOT_LINE_COLOR, MidLineColor);
   PlotIndexSetInteger(2, PLOT_LINE_WIDTH, MidLineWidth);
   PlotIndexSetInteger(2, PLOT_LINE_STYLE, MidLineStyle);

   return(INIT_SUCCEEDED);
  }

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
   int start = prev_calculated - 1;
   if(start < 0)
      start = 0;
   for(int i = start; i < rates_total; i++)
     {
      double highest = high[i];
      double lowest = low[i];
      for(int j = i - 1; j >= i - Periods && j >= 0; j--)
        {
         if(high[j] > highest)
            highest = high[j];
         if(low[j] < lowest)
            lowest = low[j];
        }
      HighBuffer[i] = highest;
      LowBuffer[i] = lowest;
      MidBuffer[i] = (highest + lowest) / 2; // Calculate the middle value
     }
   return(rates_total);
  }
//+------------------------------------------------------------------+